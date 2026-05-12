import { supabase } from '@/lib/supabase'
import { toNumber } from './assignment.service'

export async function getAssignedReports(userId: string) {
  // Get assignments for the officer
  const { data: assignments, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select(`
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
    `)
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (assignmentError) {
    console.error('[report.service] getAssignedReports failed', {
      userId,
      code: assignmentError.code,
      message: assignmentError.message,
    })
    throw assignmentError
  }

  return (assignments ?? []).map((row: any) => {
    const incident = row.ConfirmedIncident
    return {
      reportId: row.assignment_id,
      id: row.assignment_id,
      source: 'personnel_assignment',
      reporterName: incident?.title || 'Unknown Incident',
      contact: null,
      description: row.notes || incident?.description || '',
      mediaUrls: [],
      status: row.status, // Assignment status (ASSIGNED, EN_ROUTE, etc.)
      verificationStatus: incident?.status || 'ACTIVE', // Incident status
      createdAt: row.assigned_at,
      updatedAt: incident?.updatedAt || row.assigned_at,
      incidentId: row.incident_id,
      latitude: incident?.latitude || null,
      longitude: incident?.longitude || null,
      assignedAt: row.assigned_at,
      assignedRole: row.assigned_role,
      disasterType: incident?.disasterType || 'UNKNOWN',
      district: incident?.district || 'UNKNOWN',
    }
  })
}

export async function getReportById(userId: string, reportId: string) {
  const { data: assignment, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select(`
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
    `)
    .eq('assignment_id', reportId)
    .eq('user_id', userId)
    .maybeSingle()

  if (assignmentError) {
    console.error('[report.service] getReportById failed', {
      userId,
      reportId,
      code: assignmentError.code,
      message: assignmentError.message,
    })
    throw assignmentError
  }

  if (!assignment) {
    return null
  }

  const incident: any = assignment.ConfirmedIncident
  return {
    reportId: assignment.assignment_id,
    id: assignment.assignment_id,
    source: 'personnel_assignment',
    reporterName: incident?.title || 'Unknown Incident',
    contact: null,
    description: assignment.notes || incident?.description || '',
    mediaUrls: [],
    status: assignment.status,
    verificationStatus: incident?.status || 'ACTIVE',
    createdAt: assignment.assigned_at,
    updatedAt: incident?.updatedAt || assignment.assigned_at,
    incidentId: assignment.incident_id,
    latitude: incident?.latitude || null,
    longitude: incident?.longitude || null,
    assignedAt: assignment.assigned_at,
    assignedRole: assignment.assigned_role,
    disasterType: incident?.disasterType || 'UNKNOWN',
    district: incident?.district || 'UNKNOWN',
  }
}


export async function acknowledgeReport(userId: string, reportId: string) {
  // Update the assignment status to 'EN_ROUTE' to indicate acknowledgment/start of response
  const { data, error } = await supabase
    .from('PersonnelAssignment')
    .update({
      status: 'EN_ROUTE',
    })
    .eq('assignment_id', reportId)
    .eq('user_id', userId)
    .select('assignment_id, status')
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
    reportId: data.assignment_id,
    status: data.status,
    acknowledgedAt: new Date().toISOString(),
  }
}

