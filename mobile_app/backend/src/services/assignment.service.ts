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
    supabase.from('PersonnelAssignment').select('assignment_id', { count: 'exact', head: true }).eq('user_id', userId).eq('status', 'ACTIVE'),
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

export async function getAssignmentAlerts(userId: string, scope: 'citizen' | 'internal' | 'all' = 'all') {
  const officerAssignments = await getOfficerAssignmentRows(userId)
  const districts = Array.from(
    new Set(
      officerAssignments
        .map((row) => unwrapRelation(row.ConfirmedIncident)?.district)
        .filter((district): district is string => Boolean(district))
    )
  )

  let alertQuery = supabase
    .from('Alert')
    .select('id, type, severity, title, description, district, isPublic, isActive, createdAt, expiresAt, incidentId, source')
    .eq('isActive', true)
    .order('createdAt', { ascending: false })

  if (scope === 'citizen') {
    alertQuery = alertQuery.eq('isPublic', true)
  } else if (scope === 'internal') {
    alertQuery = alertQuery.eq('isPublic', false)
  }

  if (districts.length > 0) {
    alertQuery = alertQuery.in('district', districts)
  }

  const publicAlertQuery = supabase
    .from('PublicAlert')
    .select('alert_id, incident_id, title, message, severity_level, status, issued_at')
    .order('issued_at', { ascending: false })

  const [{ data: alerts, error: alertError }, { data: publicAlerts, error: publicAlertError }] = await Promise.all([
    alertQuery,
    publicAlertQuery,
  ])

  if (alertError) {
    throw alertError
  }

  if (publicAlertError) {
    throw publicAlertError
  }

  return [
    ...(alerts ?? []).map((alert) => ({
      id: alert.id,
      scope: alert.isPublic ? 'citizen' : 'internal',
      title: alert.title,
      severity: alert.severity,
      status: alert.isActive ? 'ACTIVE' : 'INACTIVE',
      district: alert.district,
      createdAt: alert.createdAt,
      incidentId: alert.incidentId ?? null,
    })),
    ...(publicAlerts ?? []).map((alert) => ({
      id: alert.alert_id,
      scope: 'citizen',
      title: alert.title,
      severity: alert.severity_level,
      status: alert.status,
      district: districts[0] ?? null,
      issuedAt: alert.issued_at,
      incidentId: alert.incident_id ?? null,
    })),
  ]
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
  const { data: assignmentRows, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('incident_id, assigned_at, assigned_role')
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (assignmentError) {
    throw assignmentError
  }

  const incidentIds = Array.from(
    new Set((assignmentRows ?? []).map((row) => row.incident_id).filter(Boolean))
  )

  if (incidentIds.length === 0) {
    return []
  }

  const { data, error } = await supabase
    .from('Report')
    .select(
      'report_id, source_channel, reporter_name, contact_info, description, media_url, latitude, longitude, status, created_at, updated_at, incident_id'
    )
    .in('incident_id', incidentIds)
    .order('created_at', { ascending: false })

  if (error) {
    throw error
  }

  // Create a map for quick lookup of assignment details by incident_id
  const assignmentMap = (assignmentRows ?? []).reduce((acc, row) => {
    acc[row.incident_id] = row
    return acc
  }, {} as Record<string, any>)

  const incidentIdsForQuery = Array.from(
    new Set((data ?? []).map((report) => report.incident_id).filter(Boolean))
  )

  const { data: incidentsData } = await supabase
    .from('ConfirmedIncident')
    .select('id, disasterType, district')
    .in('id', incidentIdsForQuery)

  const incidentMapById = (incidentsData ?? []).reduce((acc, incident) => {
    acc[incident.id] = incident
    return acc
  }, {} as Record<string, any>)

  return (data ?? []).map((report) => {
    const assignment = assignmentMap[report.incident_id]
    const incident = incidentMapById[report.incident_id]

    return {
      reportId: report.report_id.toString(),
      id: report.report_id.toString(),
      source: report.source_channel,
      reporterName: report.reporter_name,
      contact: report.contact_info,
      description: report.description,
      mediaUrls: report.media_url ? [report.media_url] : [],
      status: report.status,
      verificationStatus: report.status,
      createdAt: report.created_at,
      updatedAt: report.updated_at,
      incidentId: report.incident_id,
      latitude: toNumber(report.latitude),
      longitude: toNumber(report.longitude),
      assignedAt: assignment?.assigned_at,
      assignedRole: assignment?.assigned_role,
      disasterType: incident?.disasterType || 'UNKNOWN',
      district: incident?.district || 'UNKNOWN',
    }
  })
}


