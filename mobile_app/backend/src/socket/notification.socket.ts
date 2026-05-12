import { emitToOfficer } from '@/socket'

export function emitNotificationNew(userId: string, payload: unknown) {
  emitToOfficer(userId, 'notification:new', payload)
}
