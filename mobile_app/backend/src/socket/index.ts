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
      decoded.role !== 'FIELD_OFFICER'
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
    console.log('[socket.io] setting up supabase realtime bridge...')
    
    supabase
      .channel('db-changes')
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'ResourceRequest' },
        (payload: any) => {
          console.log('[socket.io] supabase: ResourceRequest DELETED', payload.old.request_id)
          io.emit('resourceRequest:deleted', {
            requestId: payload.old.request_id,
            userId: payload.old.requested_by
          })
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'ResourceRequest' },
        (payload: any) => {
          console.log('[socket.io] supabase: ResourceRequest UPDATED', payload.new.request_id)
          io.emit('resourceRequest:updated', {
            requestId: payload.new.request_id,
            userId: payload.new.requested_by,
            incidentId: payload.new.incident_id,
            status: payload.new.status
          })
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'ConfirmedIncident' },
        (payload: any) => {
          console.log('[socket.io] supabase: ConfirmedIncident UPDATED', payload.new.id)
          io.emit('incident:updated', {
            incidentId: payload.new.id,
            updates: payload.new
          })
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
