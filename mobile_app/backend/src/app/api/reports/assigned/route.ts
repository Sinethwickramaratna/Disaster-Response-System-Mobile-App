import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAssignedReports } from '@/services/report.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const reports = await getAssignedReports(auth.context.userId)

    return NextResponse.json(reports)
  } catch (error) {
    console.error(error)

    const message = error instanceof Error ? error.message : 'Failed to retrieve reports'
    return jsonServerError(message)
  }
}
