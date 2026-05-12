import { emitToIncident, emitToOfficer } from '@/socket'

export function emitResourceAssigned(userId: string, incidentId: string, payload: unknown) {
  emitToOfficer(userId, 'resource:assigned', payload)
  emitToIncident(incidentId, 'resource:assigned', payload)
}

export function emitResourceStatusUpdated(incidentId: string, payload: unknown) {
  emitToIncident(incidentId, 'resource:statusUpdated', payload)
}

export function emitResourceRequestUpdated(userId: string, incidentId: string | null, payload: unknown) {
  emitToOfficer(userId, 'resourceRequest:updated', payload)

  if (incidentId) {
    emitToIncident(incidentId, 'resourceRequest:updated', payload)
  }
}
