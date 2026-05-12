import { supabase } from '@/lib/supabase'

export async function getAssignedReports(userId: string) {
  const { data, error } = await supabase
    .from('IncomingReport')
    .select('report_id, incident_id, title, description, status, acknowledged, created_at, assigned_to')
    .eq('assigned_to', userId)
    .order('created_at', { ascending: false })

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
    reportId: report.report_id,
    incidentId: report.incident_id,
    title: report.title,
    status: report.status,
    acknowledged: report.acknowledged ?? false,
    createdAt: report.created_at,
  }))
}

export async function getReportById(userId: string, reportId: string) {
  const { data, error } = await supabase
    .from('IncomingReport')
    .select('report_id, incident_id, assigned_to, title, description, status, acknowledged, created_at')
    .eq('report_id', reportId)
    .eq('assigned_to', userId)
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

  return {
    reportId: data.report_id,
    title: data.title,
    description: data.description,
    status: data.status,
    incidentId: data.incident_id,
    assignedTo: data.assigned_to,
    acknowledged: data.acknowledged ?? false,
    createdAt: data.created_at,
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
