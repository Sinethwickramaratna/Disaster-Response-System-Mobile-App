import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError, jsonValidationError } from '@/lib/response'
import { createResourceRequest } from '@/services/resource.service'
import { emitNotificationNew, emitResourceRequestUpdated } from '@/lib/socket'

export async function POST(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const body = await req.json()
    const incidentId = typeof body?.incidentId === 'string' ? body.incidentId.trim() : ''
    const resourceType = typeof body?.resourceType === 'string' ? body.resourceType.trim() : ''
    const quantity = Number(body?.quantity)
    const priority = typeof body?.priority === 'string' ? body.priority.trim() : ''
    const notes = typeof body?.notes === 'string' ? body.notes.trim() : null

    const validationErrors = []

    if (!incidentId) {
      validationErrors.push({ field: 'incidentId', message: 'Incident ID is required' })
    }

    if (!resourceType) {
      validationErrors.push({ field: 'resourceType', message: 'Resource type is required' })
    }

    if (!Number.isInteger(quantity) || quantity <= 0) {
      validationErrors.push({ field: 'quantity', message: 'Quantity must be greater than 0' })
    }

    if (!priority) {
      validationErrors.push({ field: 'priority', message: 'Priority is required' })
    }

    if (validationErrors.length > 0) {
      return jsonValidationError(validationErrors)
    }

    const result = await createResourceRequest(auth.context.userId, {
      incidentId,
      resourceType,
      quantity,
      priority,
      notes,
    })

    emitResourceRequestUpdated(auth.context.userId, incidentId, {
      requestId: result.requestId,
      status: result.status,
      createdAt: result.createdAt,
    })

    emitNotificationNew(auth.context.userId, {
      title: 'Resource request submitted',
      message: 'Your resource request has been submitted successfully.',
      type: 'RESOURCE_REQUEST',
    })

    return NextResponse.json(
      {
        message: 'Resource request submitted successfully',
        requestId: result.requestId,
        status: result.status,
        createdAt: result.createdAt,
      },
      { status: 201 }
    )
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to submit resource request')
  }
}
