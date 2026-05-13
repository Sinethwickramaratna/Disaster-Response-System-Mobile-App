import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError, jsonNotFound } from '@/lib/response'
import { getResourceRequestDetails } from '@/services/resource.service'

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const { id } = params
    const details = await getResourceRequestDetails(id)

    if (!details) {
      return jsonNotFound('Resource request not found')
    }

    return NextResponse.json(details)
  } catch (error) {
    console.error(error)
    return jsonServerError('Failed to retrieve resource request details')
  }
}
