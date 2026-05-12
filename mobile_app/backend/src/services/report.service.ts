import { supabase } from '@/lib/supabase'
import { toNumber } from './assignment.service'

export async function getAssignedReports(userId: string) {
  // Fetch latest 20 reports globally so the dashboard always has data
  const { data, error } = await supabase
    .from('IncidentReport')
    .select(
      'report_id, incident_id, assigned_to, title, description, status, acknowledged, acknowledged_at, created_at, updated_at'
    )
    .order('created_at', { ascending: false })
    .limit(20)

  if (error) {
    console.error('[report.service] getAssignedReports failed', {
      userId,
      code: error.code,
      message: error.message,
    })
    throw error
  }

  const incidentIds = Array.from(
    new Set((data ?? []).map((row) => row.incident_id).filter(Boolean))
  )

  const { data: incidentsData } = await supabase
    .from('ConfirmedIncident')
    .select('id, disasterType, district')
    .in('id', incidentIds)

  const incidentMapById = (incidentsData ?? []).reduce((acc, incident) => {
    acc[incident.id] = incident
    return acc
  }, {} as Record<string, any>)

  // We also want to know if the user is assigned to the incident
  const { data: assignmentRows } = await supabase
    .from('PersonnelAssignment')
    .select('incident_id, assigned_at, assigned_role')
    .eq('user_id', userId)
    .in('incident_id', incidentIds)

  const assignmentMap = (assignmentRows ?? []).reduce((acc, row) => {
    acc[row.incident_id] = row
    return acc
  }, {} as Record<string, any>)

  return (data ?? []).map((report) => {
    const assignment = assignmentMap[report.incident_id]
    const incident = incidentMapById[report.incident_id]
    return {
      reportId: report.report_id.toString(),
      id: report.report_id.toString(),
      source: 'incident_report',
      reporterName: report.title || 'Field Report',
      contact: null,
      description: report.description,
      mediaUrls: [],
      status: report.status,
      verificationStatus: report.status,
      createdAt: report.created_at,
      updatedAt: report.updated_at,
      incidentId: report.incident_id,
      latitude: null,
      longitude: null,
      assignedAt: assignment?.assigned_at,
      assignedRole: assignment?.assigned_role,
      disasterType: incident?.disasterType || 'PENDING',
      district: incident?.district || 'UNCATEGORIZED',
    }
  })
}

export async function getReportById(userId: string, reportId: string) {
  const { data, error } = await supabase
    .from('IncidentReport')
    .select(
      'report_id, incident_id, assigned_to, title, description, status, acknowledged, acknowledged_at, created_at, updated_at'
    )
    .eq('report_id', reportId)
    .maybeSingle()

  if (error) {
    console.error('[report.service] getReportById failed', {
      userId,
      reportId,
      code: error.code,
      message: error.message,
    })
    throw error
  }

  if (!data) {
    return null
  }

  const incidentId = data.incident_id
  if (!incidentId) {
    return null
  }

  const { data: assignmentRow, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('assignment_id, assigned_at, assigned_role')
    .eq('user_id', userId)
    .eq('incident_id', incidentId)
    .maybeSingle()

  if (assignmentError) {
    console.error('[report.service] report access check failed', {
      userId,
      reportId,
      incidentId,
      code: assignmentError.code,
      message: assignmentError.message,
    })
    throw assignmentError
  }

  if (!assignmentRow) {
    return null
  }

  let incident = null
  if (incidentId) {
    const { data: incidentData } = await supabase
      .from('ConfirmedIncident')
      .select('disasterType, district')
      .eq('id', incidentId)
      .maybeSingle()
    incident = incidentData
  }

  return {
    reportId: data.report_id.toString(),
    id: data.report_id.toString(),
    source: 'incident_report',
    reporterName: 'Field Officer',
    contact: null,
    description: data.description,
    mediaUrls: [],
    status: data.status,
    verificationStatus: data.status,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    incidentId: data.incident_id,
    latitude: null,
    longitude: null,
    assignedAt: assignmentRow.assigned_at,
    assignedRole: assignmentRow.assigned_role,
    disasterType: incident?.disasterType || 'UNKNOWN',
    district: incident?.district || 'UNKNOWN',
  }
}


export async function acknowledgeReport(userId: string, reportId: string) {
  // We need to verify if the user is assigned to the incident this report belongs to
  const { data: report, error: reportError } = await supabase
    .from('IncidentReport')
    .select('incident_id')
    .eq('report_id', reportId)
    .maybeSingle()

  if (reportError || !report) {
    return null
  }

  const { data: assignment, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('assignment_id')
    .eq('user_id', userId)
    .eq('incident_id', report.incident_id)
    .maybeSingle()

  if (assignmentError || !assignment) {
    return null
  }

  const { data, error } = await supabase
    .from('IncidentReport')
    .update({
      status: 'ACKNOWLEDGED',
      acknowledged: true,
      acknowledged_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('report_id', reportId)
    .select('report_id, updated_at')
    .maybeSingle()

  if (error) {
    console.error('[report.service] acknowledgeReport failed', {
      userId,
      reportId,
      code: error.code,
      message: error.message,
    })
    throw error
  }

  if (!data) {
    return null
  }

  return {
    reportId: data.report_id.toString(),
    acknowledgedAt: data.updated_at,
  }
}

