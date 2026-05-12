import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonNotFound, jsonServerError } from '@/lib/response'
import { getReportById } from '@/services/report.service'

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
    const report = await getReportById(auth.context.userId, id)

    if (!report) {
      return jsonNotFound()
    }

    return NextResponse.json(report)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve report')
  }
}
