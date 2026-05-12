import { emitToDistrict, emitToOfficer } from '@/socket'

export function emitCriticalAlert(userId: string, district: string, payload: unknown) {
  emitToOfficer(userId, 'alert:critical', payload)
  emitToDistrict(district, 'alert:critical', payload)
}

export function emitPublicAlert(district: string, payload: unknown) {
  emitToDistrict(district, 'alert:public', payload)
}
