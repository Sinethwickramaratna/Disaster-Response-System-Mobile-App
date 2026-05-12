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

    const searchParams = new URL(req.url).searchParams
    const district = searchParams.get('district')?.trim() ?? ''
    const zoneIdParam = searchParams.get('zoneId')
    const zoneId = Number.parseInt(zoneIdParam ?? '', 10)

    if (!district && (!Number.isInteger(zoneId) || zoneId <= 0)) {
      return jsonValidationError([
        { field: 'district', message: 'district or zoneId is required' },
      ])
    }

    const shelters = await getNearbyShelters({
      district: district || undefined,
      zoneId: Number.isInteger(zoneId) && zoneId > 0 ? zoneId : undefined,
    })

    return NextResponse.json(shelters)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve shelters')
  }
}
