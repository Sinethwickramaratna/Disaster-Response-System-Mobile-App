import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonNotFound, jsonServerError } from '@/lib/response'
import { getIncidentDetail, updateIncident } from '@/services/incident.service'

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

export async function PATCH(req: NextRequest, context: RouteContext) {
  const { id } = await context.params
  try {
    console.log('[api/incidents/PATCH] Request received for ID:', id)
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      console.warn('[api/incidents/PATCH] Auth failed')
      return auth.response
    }

    const body = await req.json()
    console.log('[api/incidents/PATCH] Body:', body)
    
    const updated = await updateIncident(auth.context.userId, id, {
      description: body.description,
      affectedPeople: body.affectedPeople != null ? Number(body.affectedPeople) : undefined,
      status: body.status,
      severity: body.severity,
    })

    console.log('[api/incidents/PATCH] Update successful')
    return NextResponse.json(updated)
  } catch (error: any) {
    console.error('[api/incidents/PATCH] Error:', error)
    return jsonServerError(error.message || 'Failed to update incident')
  }
}
