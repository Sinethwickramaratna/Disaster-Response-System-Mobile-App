import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAlerts } from '@/services/alert.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const alerts = await getAlerts()

    return NextResponse.json(alerts)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve alerts')
  }
}
