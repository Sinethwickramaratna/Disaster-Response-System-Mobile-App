import { NextResponse } from 'next/server'
import { getIO } from '@/lib/socket'

export async function GET() {
  try {
    const port = process.env.SOCKET_PORT || '4001'
    // Lazily start or retrieve the socket server
    try {
      getIO()
    } catch (e) {
      console.error('socket health: failed to start', e)
    }

    return NextResponse.json({ ok: true, socketPort: Number(port) })
  } catch (e) {
    console.error(e)
    return NextResponse.json({ ok: false }, { status: 500 })
  }
}
