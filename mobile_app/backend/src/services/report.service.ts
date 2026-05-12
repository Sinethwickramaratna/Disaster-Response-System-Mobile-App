import { supabase } from '@/lib/supabase'

export async function getAssignedReports(userId: string) {
  const { data: assignmentRows, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('incident_id, assigned_at, assigned_role')
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (assignmentError) {
    console.error('[report.service] assignment lookup failed', {
      userId,
      code: assignmentError.code,
      message: assignmentError.message,
    })
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
    console.error('[report.service] getAssignedReports failed', {
      userId,
      code: error.code,
      message: error.message,
    })
    throw error
  }

  const assignmentMap = (assignmentRows ?? []).reduce((acc, row) => {
    acc[row.incident_id] = row
    return acc
  }, {} as Record<string, any>)

  return (data ?? []).map((report) => {
    const assignment = assignmentMap[report.incident_id]
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
      latitude: report.latitude,
      longitude: report.longitude,
      assignedAt: assignment?.assigned_at,
      assignedRole: assignment?.assigned_role,
    }
  })
}

export async function getReportById(userId: string, reportId: string) {
  const { data, error } = await supabase
    .from('Report')
    .select(
      `
        report_id, 
        source_channel, 
        reporter_name, 
        contact_info, 
        description, 
        media_url, 
        latitude, 
        longitude, 
        status, 
        created_at, 
        updated_at, 
        incident_id,
        ConfirmedIncident:incident_id (
          disasterType,
          district
        )
      `
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

  const incident = unwrapRelation(data.ConfirmedIncident) as any

  return {
    reportId: data.report_id.toString(),
    id: data.report_id.toString(),
    source: data.source_channel,
    reporterName: data.reporter_name,
    contact: data.contact_info,
    description: data.description,
    mediaUrls: data.media_url ? [data.media_url] : [],
    status: data.status,
    verificationStatus: data.status,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    incidentId: data.incident_id,
    latitude: data.latitude,
    longitude: data.longitude,
    assignedAt: assignmentRow.assigned_at,
    assignedRole: assignmentRow.assigned_role,
    disasterType: incident?.disasterType || 'UNKNOWN',
    district: incident?.district || 'UNKNOWN',
  }
}


export async function acknowledgeReport(userId: string, reportId: string) {
  // We need to verify if the user is assigned to the incident this report belongs to
  const { data: report, error: reportError } = await supabase
    .from('Report')
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
    .from('Report')
    .update({
      status: 'ACKNOWLEDGED',
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

