import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getNotifications } from '@/services/notification.service'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const notifications = await getNotifications(auth.context.userId)

    return NextResponse.json(notifications)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve notifications')
  }
}
