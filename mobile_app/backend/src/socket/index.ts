import { createServer, type Server as HttpServer } from 'http'
import { Server, type Socket } from 'socket.io'
import jwt from 'jsonwebtoken'
import type { JwtClaims } from '@/types/auth'
import { supabase } from '@/lib/supabase'

type SocketStore = {
  io?: Server
  httpServer?: HttpServer
  started?: boolean
  supabaseSubscribed?: boolean
}

type SocketData = {
  user?: JwtClaims
}

const globalForSocket = globalThis as typeof globalThis & {
  __j3SocketStore?: SocketStore
}

function getStore() {
  if (!globalForSocket.__j3SocketStore) {
    globalForSocket.__j3SocketStore = {}
  }

  return globalForSocket.__j3SocketStore
}

function getSocketPort() {
  return Number(process.env.SOCKET_PORT || process.env.PORT || 4001)
}

function authorizeSocket(socket: Socket) {
  const queryToken = socket.handshake.query?.token
  const headerAuth = socket.handshake.headers?.authorization
  const headerToken = headerAuth ? String(headerAuth).split(' ')[1] : undefined
  const token = String(queryToken ?? headerToken ?? '').trim()

  if (!token || !process.env.JWT_SECRET_KEY) {
    return null
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET_KEY) as Partial<JwtClaims>

    if (
      !decoded ||
      typeof decoded.userId !== 'string' ||
      typeof decoded.email !== 'string' ||
      typeof decoded.role !== 'string' ||
      decoded.role !== 'FIELD_OFFICER' && decoded.role !== 'RESPONSE_TEAM_MEMBER'
    ) {
      return null
    }

    return decoded as JwtClaims
  } catch {
    return null
  }
}

/**
 * Initializes or retrieves the Socket.IO instance.
 * @param existingServer Optional existing HTTP server to attach to.
 */
export function getIO(existingServer?: HttpServer) {
  const store = getStore()

  if (store.io) {
    return store.io
  }

  // If no server is provided and we haven't created one, create a standalone one
  const httpServer = existingServer || createServer()
  const io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    // Required for some hosting providers
    addTrailingSlash: false,
  })

  io.use((socket, next) => {
    const user = authorizeSocket(socket)

    if (!user) {
      return next(new Error('unauthorized'))
    }

    ;(socket.data as SocketData).user = user
    return next()
  })

  io.on('connection', (socket) => {
    const user = (socket.data as SocketData).user

    if (user) {
      socket.join(`officer:${user.userId}`)
      console.log(`[socket.io] frontend connected user=${user.userId} socket=${socket.id}`)
    }

    socket.on('join:incident', (incidentId: string) => {
      if (incidentId) {
        socket.join(`incident:${incidentId}`)
      }
    })

    socket.on('join:district', (district: string) => {
      if (district) {
        socket.join(`district:${district}`)
      }
    })

    socket.on('disconnect', () => {
      console.log(`[socket.io] frontend disconnected socket=${socket.id}`)
    })
  })

  // Setup Supabase Realtime Bridge
  if (!store.supabaseSubscribed) {
    console.log('[socket.io] setting up supabase realtime bridge (SCHEMA WIDE)...')
    
    supabase
      .channel('db-wide-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public' },
        (payload: any) => {
          console.log('[socket.io] Supabase DB EVENT:', payload.eventType, payload.table, JSON.stringify(payload))
          
          const table = payload.table
          const eventType = payload.eventType
          
          if (table.toLowerCase() === 'resourcerequest') {
            const resourceRequest = eventType === 'DELETE' ? payload.old : payload.new
            const requestId = resourceRequest.request_id || resourceRequest.requestId || resourceRequest.id
            
            let eventName = 'resourceRequest:updated'
            if (eventType === 'DELETE') eventName = 'resourceRequest:deleted'
            if (eventType === 'INSERT') eventName = 'resourceRequest:created'
            
            const roomName = `officer:${resourceRequest.requested_by}`
            console.log(`[socket.io] Sending ${eventName} to ${roomName} for request ${requestId}`)
            
            io.to(roomName).emit(eventName, {
              requestId,
              request_id: requestId,
              userId: resourceRequest.requested_by,
              incidentId: resourceRequest.incident_id,
              status: resourceRequest.status,
              updatedAt: resourceRequest.updated_at || resourceRequest.updatedAt,
              event: eventName
            })
          } else if (table.toLowerCase() === 'logisticsdeployment') {
            const logisticsDeployment = eventType === 'DELETE' ? payload.old : payload.new
            const deploymentId = logisticsDeployment.deployment_id || logisticsDeployment.deploymentId || logisticsDeployment.id
            const userId = logisticsDeployment.user_id || logisticsDeployment.userId

            if (!userId) {
              console.warn('[socket.io] Missing userId for LogisticsDeployment event. Skipping broadcast.')
              return
            }

            const status = String(logisticsDeployment.status || '').toUpperCase()
            const roomName = `officer:${userId}`
            const eventName = eventType === 'DELETE' ? 'resource:removed' : 'resource:statusUpdated'
            const broadcastPayload = {
              deploymentId,
              deployment_id: deploymentId,
              userId,
              incidentId: logisticsDeployment.incident_id,
              status,
              itemsDispatched: logisticsDeployment.items_dispatched,
              completedAt: logisticsDeployment.completed_at,
              updatedAt: logisticsDeployment.updated_at || logisticsDeployment.completed_at || logisticsDeployment.dispatched_at || new Date().toISOString(),
              event: eventName,
              type: 'LogisticsDeployment'
            }

            console.log(`[socket.io] Broadcasting ${eventName} to ${roomName} for deployment ${deploymentId} status=${status}`)
            io.to(roomName).emit(eventName, broadcastPayload)
            io.emit('resource:updated', broadcastPayload)
          } else if (table.toLowerCase() === 'personnelassignment') {
            const userId = eventType === 'DELETE' ? payload.old.user_id : payload.new.user_id;
            
            let eventName = 'assignment:updated';
            if (eventType === 'INSERT') eventName = 'assignment:created';
            if (eventType === 'DELETE') eventName = 'assignment:deleted';
            
            console.log(`[socket.io] PersonnelAssignment ${eventType} detected. Targeting officer:${userId}`);
            
            if (!userId) {
              console.warn(`[socket.io] Missing userId for ${eventType} on PersonnelAssignment. Event will not be broadcasted.`);
              return;
            }

            const roomName = `officer:${userId}`;
            const roomSize = io.sockets.adapter.rooms.get(roomName)?.size || 0;
            console.log(`[socket.io] Broadcasting ${eventName} to ${roomName} (Size: ${roomSize})`);

            io.to(roomName).emit(eventName, {
              assignmentId: eventType === 'DELETE' ? payload.old.assignment_id : payload.new.assignment_id,
              assignment_id: eventType === 'DELETE' ? payload.old.assignment_id : payload.new.assignment_id,
              incidentId: eventType === 'DELETE' ? payload.old.incident_id : payload.new.incident_id,
              role: eventType === 'DELETE' ? payload.old.assigned_role : payload.new.assigned_role,
              status: eventType === 'DELETE' ? 'REMOVED' : payload.new.status,
              updatedAt: eventType === 'DELETE' ? new Date().toISOString() : (payload.new.assigned_at || new Date().toISOString()),
              event: eventName,
              type: 'PersonnelAssignment'
            });
            console.log(`[socket.io] Successfully broadcasted ${eventName} to ${roomName}`);
          } else if (table.toLowerCase() === 'confirmedincident' && eventType === 'UPDATE') {
            console.log(`[socket.io] Broadcasting incident:updated for ${payload.new.id}`)
            io.emit('incident:updated', {
              incidentId: payload.new.id,
              status: payload.new.status,
              updatedAt: payload.new.updated_at || payload.new.updatedAt,
              updates: payload.new,
              event: 'incident:updated'
            })
          } else if (table.toLowerCase() === 'alert' && eventType === 'INSERT') {
            console.log(`[socket.io] Broadcasting alert:created for ${payload.new.id}`)
            io.emit('alert:created', {
              alertId: payload.new.id,
              title: payload.new.title,
              severity: payload.new.severity,
              type: payload.new.type,
              district: payload.new.district,
              updatedAt: payload.new.createdAt || payload.new.created_at,
              event: 'alert:created'
            })
          }
        }
      )
      .subscribe((status: string) => {
        console.log(`[socket.io] supabase realtime status: ${status}`)
        if (status === 'SUBSCRIBED') {
          store.supabaseSubscribed = true
        }
      })
  }

  // Only start listening if we created a standalone server
  if (!existingServer) {
    const port = getSocketPort()
    if (!store.started) {
      httpServer.listen(port)
      console.log(`[socket.io] server started on port ${port}`)
      store.started = true
    }
  }

  store.httpServer = httpServer
  store.io = io

  return io
}

export function emitToOfficer(userId: string, event: string, payload: unknown) {
  getIO().to(`officer:${userId}`).emit(event, payload)
}

export function emitToIncident(incidentId: string, event: string, payload: unknown) {
  getIO().to(`incident:${incidentId}`).emit(event, payload)
}

export function emitToDistrict(district: string, event: string, payload: unknown) {
  getIO().to(`district:${district}`).emit(event, payload)
}
