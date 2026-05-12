import { NextRequest, NextResponse } from 'next/server'

const PUBLIC_PATHS = new Set([
  '/api/auth/login',
  '/api/hello',
  '/api/socket/health',
])

export function proxy(request: NextRequest) {
  const pathname = request.nextUrl.pathname

  if (PUBLIC_PATHS.has(pathname)) {
    return NextResponse.next()
  }

  if (pathname.startsWith('/api/')) {
    const authorization = request.headers.get('authorization')

    if (!authorization || !authorization.toLowerCase().startsWith('bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/api/:path*'],
}