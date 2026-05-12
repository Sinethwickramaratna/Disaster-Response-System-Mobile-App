export {
  emitToDistrict,
  emitToIncident,
  emitToOfficer,
  getIO,
} from '@/socket'

export {
  emitCriticalAlert,
  emitPublicAlert,
} from '@/socket/alert.socket'

export {
  emitIncidentAssigned,
  emitIncidentUpdated,
} from '@/socket/incident.socket'

export {
  emitNotificationNew,
} from '@/socket/notification.socket'

export {
  emitResourceAssigned,
  emitResourceRequestUpdated,
  emitResourceStatusUpdated,
} from '@/socket/resource.socket'
