import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAssignedIncidentList } from '@/services/incident.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const incidents = await getAssignedIncidentList(auth.context.userId)

    return NextResponse.json(incidents)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve incidents')
  }
}
