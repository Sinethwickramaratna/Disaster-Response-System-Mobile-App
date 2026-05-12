import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAssignmentAlerts } from '@/services/assignment.service'

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url)
    const scope = (url.searchParams.get('scope') || 'all') as 'citizen' | 'internal' | 'all'

    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const alerts = await getAssignmentAlerts(auth.context.userId, scope)

    return NextResponse.json(alerts)

  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve alerts')
  }
}
