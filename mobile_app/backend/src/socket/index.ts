import { createServer, type Server as HttpServer } from 'http'
import { Server, type Socket } from 'socket.io'
import jwt from 'jsonwebtoken'
import type { JwtClaims } from '@/types/auth'

type SocketStore = {
  io?: Server
  httpServer?: HttpServer
  started?: boolean
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
