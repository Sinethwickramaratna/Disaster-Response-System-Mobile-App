import { supabase } from '@/lib/supabase'

export async function getAssignedReports(userId: string) {
  const { data: assignmentRows, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('incident_id')
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (assignmentError) {
    console.error('[report.service] assignment lookup failed', {
      userId,
      code: assignmentError.code,
      message: assignmentError.message,
      details: assignmentError.details,
      hint: assignmentError.hint,
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
    .from('IncomingReport')
    .select('id, source, disasterType, district, verificationStatus, createdAt, incidentId')
    .in('incidentId', incidentIds)
    .order('createdAt', { ascending: false })

  if (error) {
    console.error('[report.service] getAssignedReports failed', {
      userId,
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint,
    })
    throw error
  }

  return (data ?? []).map((report) => ({
    reportId: report.id,
    source: report.source,
    disasterType: report.disasterType,
    district: report.district,
    verificationStatus: report.verificationStatus,
    createdAt: report.createdAt,
    incidentId: report.incidentId,
  }))
}

export async function getReportById(userId: string, reportId: string) {
  const { data, error } = await supabase
    .from('IncomingReport')
    .select(
      'id, source, disasterType, district, latitude, longitude, description, contact, mediaUrls, verificationStatus, createdAt, sosId, deviceId, officerNotes, reviewedById, reviewedAt, incidentId'
    )
    .eq('id', reportId)
    .maybeSingle()

  if (error) {
    console.error('[report.service] getReportById failed', {
      userId,
      reportId,
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint,
    })
    throw error
  }

  if (!data) {
    return null
  }

  const incidentId = data.incidentId
  if (!incidentId) {
    return null
  }

  const { data: assignmentRow, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('assignment_id')
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

  return {
    reportId: data.id,
    id: data.id,
    source: data.source,
    disasterType: data.disasterType,
    district: data.district,
    latitude: data.latitude,
    longitude: data.longitude,
    description: data.description,
    contact: data.contact,
    mediaUrls: Array.isArray(data.mediaUrls) ? data.mediaUrls : [],
    verificationStatus: data.verificationStatus,
    createdAt: data.createdAt,
    sosId: data.sosId,
    deviceId: data.deviceId,
    officerNotes: data.officerNotes,
    reviewedById: data.reviewedById,
    reviewedAt: data.reviewedAt,
    incidentId: data.incidentId,
  }
}

export async function acknowledgeReport(userId: string, reportId: string) {
  const { data, error } = await supabase
    .from('IncomingReport')
    .update({
      acknowledged: true,
      acknowledged_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('report_id', reportId)
    .eq('assigned_to', userId)
    .select('report_id, acknowledged_at')
    .maybeSingle()

  if (error) {
    console.error('[report.service] acknowledgeReport failed', {
      userId,
      reportId,
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint,
    })
    throw error
  }

  if (!data) {
    return null
  }

  return {
    reportId: data.report_id,
    acknowledgedAt: data.acknowledged_at,
  }
}
