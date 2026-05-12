import { supabase } from '@/lib/supabase'

export async function getNotifications(userId: string) {
  const { data, error } = await supabase
    .from('Notification')
    .select('notification_id, title, message, type, is_read, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(100)

  if (error) {
    throw error
  }

  return (data ?? []).map((notification) => ({
    notificationId: notification.notification_id,
    title: notification.title,
    message: notification.message,
    type: notification.type,
    isRead: notification.is_read,
    createdAt: notification.created_at,
  }))
}

export async function markNotificationsRead(userId: string, notificationIds?: string[]) {
  const baseQuery = supabase
    .from('Notification')
    .update({ is_read: true })
    .eq('user_id', userId)
    .eq('is_read', false)

  const query = notificationIds && notificationIds.length > 0
    ? baseQuery.in('notification_id', notificationIds)
    : baseQuery

  const { data, error } = await query.select('notification_id')

  if (error) {
    throw error
  }

  return {
    updatedCount: data?.length ?? 0,
  }
}
