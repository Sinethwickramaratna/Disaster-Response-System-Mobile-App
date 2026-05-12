import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAssignmentSummary } from '@/services/assignment.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const summaryPayload = await getAssignmentSummary(auth.context.userId)

    return NextResponse.json(summaryPayload)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve dashboard summary')
  }
}
