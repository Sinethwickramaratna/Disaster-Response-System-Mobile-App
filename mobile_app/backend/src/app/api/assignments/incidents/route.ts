import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAssignedIncidents } from '@/services/assignment.service'

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url)
    const statusFilter = url.searchParams.get('status')
    const severityFilter = url.searchParams.get('severity')

    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const incidents = await getAssignedIncidents(auth.context.userId, {
      status: statusFilter,
      severity: severityFilter,
    })

    return NextResponse.json(incidents)

  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve incidents')
  }
}
