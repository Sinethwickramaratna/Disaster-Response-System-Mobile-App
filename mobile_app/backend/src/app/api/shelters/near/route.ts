import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError, jsonValidationError } from '@/lib/response'
import { getNearbyShelters } from '@/services/resource.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const zoneIdParam = new URL(req.url).searchParams.get('zoneId')
    const zoneId = Number.parseInt(zoneIdParam ?? '', 10)

    if (!Number.isInteger(zoneId) || zoneId <= 0) {
      return jsonValidationError([
        { field: 'zoneId', message: 'zoneId must be a positive integer' },
      ])
    }

    const shelters = await getNearbyShelters(zoneId)

    return NextResponse.json(shelters)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve shelters')
  }
}
