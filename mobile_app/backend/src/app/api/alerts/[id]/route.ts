import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonNotFound, jsonServerError } from '@/lib/response'
import { getAlertById } from '@/services/alert.service'

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
    const alert = await getAlertById(id)

    if (!alert) {
      return jsonNotFound()
    }

    return NextResponse.json(alert)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve alert')
  }
}
