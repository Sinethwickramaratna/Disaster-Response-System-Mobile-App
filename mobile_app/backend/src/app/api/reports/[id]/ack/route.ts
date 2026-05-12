import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonNotFound, jsonServerError } from '@/lib/response'
import { acknowledgeReport } from '@/services/report.service'

type RouteContext = {
  params: Promise<{ id: string }>
}

export async function POST(req: NextRequest, context: RouteContext) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const { id } = await context.params
    const result = await acknowledgeReport(auth.context.userId, id)

    if (!result) {
      return jsonNotFound()
    }

    return NextResponse.json({
      message: 'Report acknowledged successfully',
      reportId: result.reportId,
      acknowledgedAt: result.acknowledgedAt,
    })
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to acknowledge report')
  }
}
