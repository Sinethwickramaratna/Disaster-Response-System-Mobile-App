import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError, jsonNotFound } from '@/lib/response'
import { updateLogisticsDeployment } from '@/services/resource.service'

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const body = await req.json()
    const { status, deliveryNotes } = body

    if (!status) {
      return NextResponse.json({ message: 'Status is required' }, { status: 400 })
    }

    const updated = await updateLogisticsDeployment(id, auth.context.userId, status, deliveryNotes)

    if (!updated) {
      return jsonNotFound('Deployment not found')
    }

    return NextResponse.json(updated)
  } catch (error) {
    console.error(error)
    return jsonServerError('Failed to update deployment')
  }
}
