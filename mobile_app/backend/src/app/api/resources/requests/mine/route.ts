import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getMyResourceRequests } from '@/services/resource.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const requests = await getMyResourceRequests(auth.context.userId)

    return NextResponse.json(requests)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve resource requests')
  }
}
