import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonNotFound, jsonServerError } from '@/lib/response'
import { getIncidentDetail } from '@/services/incident.service'

type RouteContext = {
  params: Promise<{ id: string }>
}

export async function GET(req: NextRequest, context: RouteContext) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const { id } = await context.params
    const incident = await getIncidentDetail(auth.context.userId, id)

    if (!incident) {
      return jsonNotFound()
    }

    return NextResponse.json(incident)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve incident')
  }
}
