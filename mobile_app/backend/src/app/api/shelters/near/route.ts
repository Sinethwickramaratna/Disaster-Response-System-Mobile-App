import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
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

    const shelters = await getNearbyShelters({
      userId: auth.context.userId,
      district: district || undefined,
      zoneId: Number.isInteger(zoneId) && zoneId > 0 ? zoneId : undefined,
    })

    return NextResponse.json(shelters)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve shelters')
  }
}
