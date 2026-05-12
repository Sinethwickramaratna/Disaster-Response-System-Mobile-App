import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { markNotificationsRead } from '@/services/notification.service'

export async function POST(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    let notificationIds: string[] | undefined

    try {
      const body = await req.json()
      if (Array.isArray(body?.notificationIds)) {
        notificationIds = body.notificationIds.filter((value: unknown): value is string => typeof value === 'string')
      }
    } catch {
      notificationIds = undefined
    }

    const result = await markNotificationsRead(auth.context.userId, notificationIds)

    return NextResponse.json({
      message: 'Notifications marked as read',
      updatedCount: result.updatedCount,
    })
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to update notifications')
  }
}
