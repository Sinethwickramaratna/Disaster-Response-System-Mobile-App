import { getIO } from '@/socket'

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    try {
      getIO()
      console.log('[socket.io] initialized during backend startup')
    } catch (error) {
      console.error('[socket.io] startup initialization failed', error)
    }
  }
}
