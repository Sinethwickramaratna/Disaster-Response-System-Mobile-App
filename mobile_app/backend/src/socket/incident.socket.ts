import { emitToIncident, emitToOfficer } from '@/socket'

export function emitIncidentAssigned(userId: string, incidentId: string, payload: unknown) {
  emitToOfficer(userId, 'incident:assigned', payload)
  emitToIncident(incidentId, 'incident:assigned', payload)
}

export function emitIncidentUpdated(incidentId: string, payload: unknown) {
  emitToIncident(incidentId, 'incident:updated', payload)
}
