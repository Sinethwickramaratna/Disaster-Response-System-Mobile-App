import { supabase } from '@/lib/supabase'

type AssignmentFilters = {
  status?: string | null
  severity?: string | null
}

type ConfirmedIncidentRow = {
  id: string
  title: string
  disasterType: string
  district: string
  severity: string
  status: string
  latitude: number
  longitude: number
  description: string | null
  publicVisibility: boolean
  affectedPeople: number
  createdAt: string
  updatedAt: string
}

type AssignmentRow = {
  assignment_id: string
  incident_id: string
  assigned_role: string
  status: string
  assigned_at: string
  notes: string | null
  ConfirmedIncident: ConfirmedIncidentRow[] | ConfirmedIncidentRow | null
}

type DivisionRow = {
  division_id: number
  division_name: string
  district: string | null
  province: string | null
}

export function toNumber(value: number | string | null | undefined) {
  if (value === null || value === undefined) {
    return null
  }

  const parsed = typeof value === 'number' ? value : Number(value)
  return Number.isNaN(parsed) ? null : parsed
}

function clampRatio(numerator: number, denominator: number) {
  if (!denominator || denominator <= 0) {
    return 1
  }

  return Math.max(0, Math.min(numerator / denominator, 1))
}

export function unwrapRelation<T>(relation: T[] | T | null | undefined): T | null {
  if (!relation) {
    return null
  }

  return Array.isArray(relation) ? relation[0] ?? null : relation
}

async function getOfficerAssignmentRows(userId: string) {
  const { data, error } = await supabase
    .from('PersonnelAssignment')
    .select(
      `
        assignment_id,
        incident_id,
        assigned_role,
        status,
        assigned_at,
        notes,
        ConfirmedIncident:incident_id (
          id,
          title,
          disasterType,
          district,
          severity,
          status,
          latitude,
          longitude,
          description,
          publicVisibility,
          affectedPeople,
          createdAt,
          updatedAt
        )
      `
    )
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (error) {
    throw error
  }

  return (data ?? []) as AssignmentRow[]
}

export async function getAssignmentSummary(userId: string) {
  const [{ count: criticalAlerts }, { count: activeAssignments }, { count: totalAssignments }, { count: readyResources }, { count: totalResources }] = await Promise.all([
    supabase.from('Alert').select('id', { count: 'exact', head: true }).eq('severity', 'CRITICAL').eq('isActive', true),
    supabase.from('PersonnelAssignment').select('assignment_id', { count: 'exact', head: true }).eq('user_id', userId).neq('status', 'RELEASED'),
    supabase.from('PersonnelAssignment').select('assignment_id', { count: 'exact', head: true }).eq('user_id', userId),
    supabase.from('LogisticsDeployment').select('deployment_id', { count: 'exact', head: true }).eq('user_id', userId).in('status', ['READY', 'DEPLOYED', 'DELIVERED']),
    supabase.from('LogisticsDeployment').select('deployment_id', { count: 'exact', head: true }).eq('user_id', userId),
  ])

  const assignmentRatio = clampRatio(activeAssignments ?? 0, totalAssignments ?? 0)
  const resourceRatio = clampRatio(readyResources ?? 0, totalResources ?? 0)

  return {
    criticalAlerts: criticalAlerts ?? 0,
    activeIncidents: activeAssignments ?? 0,
    assignedResources: totalResources ?? 0,
    readinessScore: Math.round((assignmentRatio * 60) + (resourceRatio * 40)),
    breakdown: {
      assignmentRatio,
      resourceRatio,
      activeAssignments: activeAssignments ?? 0,
      totalAssignments: totalAssignments ?? 0,
      readyResources: readyResources ?? 0,
      totalResources: totalResources ?? 0,
    },
  }
}

export async function getAssignedIncidents(userId: string, filters: AssignmentFilters = {}) {
  const rows = await getOfficerAssignmentRows(userId)

  const incidentRows = rows
    .filter((row) => {
      const incident = unwrapRelation(row.ConfirmedIncident)

      if (!incident) {
        return false
      }

      if (filters.status && String(row.status) !== filters.status) {
        return false
      }

      if (filters.severity && String(incident.severity) !== filters.severity) {
        return false
      }

      return true
    })
    .map(async (row) => {
      const incident = unwrapRelation(row.ConfirmedIncident) as ConfirmedIncidentRow | null
      const { data: division } = await supabase
        .from('Division')
        .select('division_id, division_name, district, province')
        .eq('district', incident?.district ?? '')
        .maybeSingle()

      return {
        assignmentId: row.assignment_id,
        incidentId: row.incident_id,
        title: incident?.title ?? '',
        severity: incident?.severity ?? 'LOW',
        status: incident?.status ?? row.status,
        assignedRole: row.assigned_role,
        affectedPopulation: incident?.affectedPeople ?? 0,
        description: incident?.description ?? null,
        createdAt: incident?.createdAt ?? null,
        updatedAt: incident?.updatedAt ?? null,
        closedAt: incident?.status?.toUpperCase() === 'CLOSED' ? incident?.updatedAt ?? null : null,
        publicVisibility: incident?.publicVisibility ?? true,
        division: {
          divisionId: division?.division_id ?? null,
          divisionName: division?.division_name ?? incident?.district ?? '',
          district: division?.district ?? incident?.district ?? '',
          province: division?.province ?? null,
        },
        location: {
          latitude: incident?.latitude ?? null,
          longitude: incident?.longitude ?? null,
        },
        assignedAt: row.assigned_at,
      }
    })

  return Promise.all(incidentRows)
}

import { getAlerts as fetchAlertsFromService } from './alert.service'

export async function getAssignmentAlerts(userId: string, scope: 'citizen' | 'internal' | 'all' = 'all') {
  // Fetch ALL active alerts from the Alert table for all users
  const alerts = await fetchAlertsFromService()
  
  console.log(`[getAssignmentAlerts] Fetched ${alerts.length} active alerts for all roles`)

  // Return all alerts since we only use the Alert table now
  return alerts
}

export async function getAssignedResources(userId: string) {
  const { data, error } = await supabase
    .from('LogisticsDeployment')
    .select('deployment_id, incident_id, status, dispatched_at, completed_at, items_dispatched, delivery_notes')
    .eq('user_id', userId)
    .order('dispatched_at', { ascending: false })

  if (error) {
    throw error
  }

  return (data ?? []).map((resource) => ({
    deploymentId: resource.deployment_id,
    incidentId: resource.incident_id,
    status: resource.status,
    dispatchedAt: resource.dispatched_at,
    completedAt: resource.completed_at,
    itemsDispatched: Array.isArray(resource.items_dispatched) ? resource.items_dispatched : resource.items_dispatched ?? [],
  }))
}

export async function getAssignedReports(userId: string) {
  const incidents = await getAssignedIncidents(userId)

  return incidents.map((assignment) => ({
    reportId: assignment.incidentId,
    id: assignment.incidentId,
    incidentId: assignment.incidentId,
    source: 'assigned_incident',
    reporterName: assignment.title,
    contact: null,
    description: assignment.description ?? assignment.title,
    mediaUrls: [],
    status: assignment.status,
    verificationStatus: assignment.status,
    createdAt: assignment.createdAt ?? assignment.assignedAt,
    updatedAt: assignment.updatedAt ?? assignment.assignedAt,
    assignedAt: assignment.assignedAt,
    assignedRole: assignment.assignedRole,
    district: assignment.division.district || 'UNKNOWN',
    disasterType: assignment.title,
    severity: assignment.severity,
    affectedPeople: assignment.affectedPopulation,
    location: assignment.location,
    reportedAt: assignment.createdAt ?? assignment.assignedAt,
    latitude: assignment.location.latitude,
    longitude: assignment.location.longitude,
    division: assignment.division,
  }))
}


