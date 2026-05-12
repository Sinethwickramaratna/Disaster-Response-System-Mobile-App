import { supabase } from '@/lib/supabase'

type ConfirmedIncidentRow = {
  id: string
  title: string
  severity: string
  status: string
  latitude: number
  longitude: number
  district: string
  publicVisibility: boolean
}

type IncidentAssignmentRow = {
  incident_id: string
  status: string
  assigned_at: string
  ConfirmedIncident: ConfirmedIncidentRow[] | ConfirmedIncidentRow | null
}

function unwrapRelation<T>(relation: T[] | T | null | undefined): T | null {
  if (!relation) {
    return null
  }

  return Array.isArray(relation) ? relation[0] ?? null : relation
}

export async function getAssignedIncidentMap(userId: string) {
  const { data, error } = await supabase
    .from('PersonnelAssignment')
    .select(
      `
        incident_id,
        status,
        assigned_at,
        ConfirmedIncident:incident_id (
          id,
          title,
          severity,
          status,
          latitude,
          longitude,
          district,
          publicVisibility
        )
      `
    )
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (error) {
    throw error
  }

  return ((data ?? []) as IncidentAssignmentRow[])
    .filter((row) => unwrapRelation(row.ConfirmedIncident))
    .map((row) => ({
      incidentId: unwrapRelation(row.ConfirmedIncident)!.id,
      title: unwrapRelation(row.ConfirmedIncident)!.title,
      severity: unwrapRelation(row.ConfirmedIncident)!.severity,
      status: unwrapRelation(row.ConfirmedIncident)!.status,
      latitude: unwrapRelation(row.ConfirmedIncident)!.latitude,
      longitude: unwrapRelation(row.ConfirmedIncident)!.longitude,
    }))
}

export async function getIncidentDetail(userId: string, incidentId: string) {
  const { data: assignment, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('incident_id, user_id')
    .eq('user_id', userId)
    .eq('incident_id', incidentId)
    .maybeSingle()

  if (assignmentError) {
    throw assignmentError
  }

  if (!assignment) {
    return null
  }

  const [{ data: incident, error: incidentError }, { data: alerts, error: alertsError }, { data: deployments, error: deploymentsError }] = await Promise.all([
    supabase
      .from('ConfirmedIncident')
      .select('id, title, disasterType, district, severity, status, latitude, longitude, description, publicVisibility, affectedPeople, createdAt, updatedAt')
      .eq('id', incidentId)
      .maybeSingle(),
    supabase
      .from('Alert')
      .select('id, title, severity, district, incidentId, isActive')
      .eq('incidentId', incidentId)
      .eq('isActive', true)
      .order('createdAt', { ascending: false }),
    supabase
      .from('LogisticsDeployment')
      .select('deployment_id, status, incident_id, dispatched_at, completed_at, items_dispatched')
      .eq('incident_id', incidentId)
      .order('dispatched_at', { ascending: false }),
  ])

  if (incidentError) {
    throw incidentError
  }

  if (alertsError) {
    throw alertsError
  }

  if (deploymentsError) {
    throw deploymentsError
  }

  if (!incident) {
    return null
  }

  return {
    incidentId: incident.id,
    title: incident.title,
    severity: incident.severity,
    status: incident.status,
    affectedPopulation: incident.affectedPeople,
    description: incident.description,
    location: {
      latitude: incident.latitude,
      longitude: incident.longitude,
    },
    division: {
      divisionId: null,
      divisionName: incident.district,
      district: incident.district,
      province: null,
    },
    alerts: (alerts ?? []).map((alert) => ({
      alertId: alert.id,
      title: alert.title,
      severity: alert.severity,
    })),
    resources: (deployments ?? []).map((deployment) => ({
      deploymentId: deployment.deployment_id,
      status: deployment.status,
    })),
  }
}

export async function getAssignedIncidentList(userId: string) {
  const { data, error } = await supabase
    .from('PersonnelAssignment')
    .select('incident_id, status, assigned_at, ConfirmedIncident:incident_id (id, title, severity, status, latitude, longitude)')
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (error) {
    throw error
  }

  return ((data ?? []) as IncidentAssignmentRow[])
    .filter((row) => unwrapRelation(row.ConfirmedIncident))
    .map((row) => ({
      incidentId: unwrapRelation(row.ConfirmedIncident)!.id,
      title: unwrapRelation(row.ConfirmedIncident)!.title,
      severity: unwrapRelation(row.ConfirmedIncident)!.severity,
      status: unwrapRelation(row.ConfirmedIncident)!.status,
      latitude: unwrapRelation(row.ConfirmedIncident)!.latitude,
      longitude: unwrapRelation(row.ConfirmedIncident)!.longitude,
    }))
}
