import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAssignedResources } from '@/services/assignment.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const resources = await getAssignedResources(auth.context.userId)

    return NextResponse.json(resources)

  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve resources')
  }
}
