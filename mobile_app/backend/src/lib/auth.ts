import jwt from 'jsonwebtoken'
import type { NextRequest } from 'next/server'
import type { AuthContext, JwtClaims } from '@/types/auth'
import { jsonUnauthorized } from '@/lib/response'

const FIELD_OFFICER_ROLE = 'FIELD_OFFICER'
const RESPONSE_TEAM_MEMBER_ROLE = 'RESPONSE_TEAM_MEMBER'
const LOGISTICS_STAFF_ROLE = 'LOGISTICS_STAFF'

function readBearerToken(request: NextRequest) {
  const authHeader = request.headers.get('authorization')

  if (!authHeader) {
    return null
  }

  const [scheme, token] = authHeader.split(' ')

  if (!scheme || scheme.toLowerCase() !== 'bearer' || !token) {
    return null
  }

  return token.trim()
}

export function verifyJwtToken(token: string): AuthContext | null {
  const secret = process.env.JWT_SECRET_KEY

  if (!secret) {
    return null
  }

  try {
    const decoded = jwt.verify(token, secret) as Partial<JwtClaims>

    if (
      !decoded ||
      typeof decoded.userId !== 'string' ||
      typeof decoded.email !== 'string' ||
      typeof decoded.role !== 'string'
    ) {
      return null
    }

    if (
      decoded.role !== FIELD_OFFICER_ROLE &&
      decoded.role !== RESPONSE_TEAM_MEMBER_ROLE &&
      decoded.role !== LOGISTICS_STAFF_ROLE
    ) {
      return null
    }

    return {
      userId: decoded.userId,
      email: decoded.email,
      role: decoded.role,
    }
  } catch {
    return null
  }
}

export function authenticateFieldOfficer(request: NextRequest) {
  const token = readBearerToken(request)

  if (!token) {
    return { ok: false as const, response: jsonUnauthorized() }
  }

  const context = verifyJwtToken(token)

  if (!context) {
    return { ok: false as const, response: jsonUnauthorized() }
  }

  return { ok: true as const, context }
}

export function signFieldOfficerToken(context: AuthContext) {
  const secret = process.env.JWT_SECRET_KEY

  if (!secret) {
    throw new Error('Missing JWT secret')
  }

  return jwt.sign(context, secret, { expiresIn: '7d' })
}
