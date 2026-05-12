import { NextApiRequest, NextApiResponse } from 'next'
import { Server } from 'socket.io'
import { getIO } from '@/socket'

export default function handler(req: NextApiRequest, res: NextApiResponse & { socket: any }) {
  if (res.socket.server.io) {
    console.log('[socket.api] socket.io already initialized')
    res.end()
    return
  }

  console.log('[socket.api] initializing socket.io...')
  
  // getIO(res.socket.server) will attach it to the main Next.js HTTP server
  const io = getIO(res.socket.server)
  res.socket.server.io = io

  res.end()
}

export const config = {
  api: {
    bodyParser: false,
  },
}
