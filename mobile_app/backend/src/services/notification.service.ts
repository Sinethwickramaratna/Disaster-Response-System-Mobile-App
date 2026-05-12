import { supabase } from '@/lib/supabase'

export async function getNotifications(userId: string) {
  // Notification table is not used; notifications are handled purely in-app/memory
  return [];
}

export async function markNotificationsRead(userId: string, notificationIds?: string[]) {
  return {
    updatedCount: 0,
  };
}
