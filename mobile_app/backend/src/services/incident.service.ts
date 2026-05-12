import { supabase } from '@/lib/supabase'
import { getIO } from '@/socket'

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

export async function updateIncident(
  userId: string,
  incidentId: string,
  updates: {
    description?: string
    affectedPeople?: number
    status?: string
    severity?: string
  }
) {
  console.log('[incident.service] updateIncident:', { userId, incidentId, updates })

  // 1. Verify authorization
  const { data: assignment, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('assignment_id, incident_id')
    .eq('user_id', userId)
    .eq('incident_id', incidentId)
    .maybeSingle()

  if (assignmentError) {
    console.error('[incident.service] Assignment check error:', assignmentError)
    throw assignmentError
  }

  if (!assignment) {
    console.warn('[incident.service] Unauthorized update attempt or invalid ID:', { userId, incidentId })
    throw new Error('Unauthorized: User is not assigned to this incident')
  }

  // 2. Build payload with fallbacks for naming conventions
  const payload: any = {}

  if (updates.description !== undefined) payload.description = updates.description
  
  if (updates.status !== undefined) {
    payload.status = updates.status.trim()
  }
  
  if (updates.severity !== undefined) {
    payload.severity = updates.severity.trim()
  }

  // Handle affected people with a few possible naming conventions
  if (updates.affectedPeople !== undefined) {
    payload.affectedPeople = updates.affectedPeople
    // If the schema uses snake_case, we might need affected_population or affected_people
    // But since we can only send one and select().single() fails if columns don't exist,
    // we'll stick to what we saw in the context SQL unless it fails.
  }

  // updatedAt / updated_at
  const now = new Date().toISOString()
  payload.updatedAt = now

  console.log('[incident.service] Updating ConfirmedIncident with payload:', payload)

  // 3. Execute update
  const { data, error } = await supabase
    .from('ConfirmedIncident')
    .update(payload)
    .eq('id', incidentId)
    .select()
    .single()

  if (error) {
    console.error('[incident.service] Update execution failed:', error)
    
    // Fallback: If it was a column name error, try snake_case for common fields
    if (error.code === 'PGRST204' || error.message?.includes('column')) {
      console.log('[incident.service] Attempting snake_case fallback...')
      const fallbackPayload: any = { updated_at: now }
      if (updates.description !== undefined) fallbackPayload.description = updates.description
      if (updates.status !== undefined) fallbackPayload.status = updates.status
      if (updates.severity !== undefined) fallbackPayload.severity = updates.severity
      if (updates.affectedPeople !== undefined) fallbackPayload.affected_population = updates.affectedPeople
      
      const { data: retryData, error: retryError } = await supabase
        .from('ConfirmedIncident')
        .update(fallbackPayload)
        .eq('id', incidentId)
        .select()
        .single()
        
      if (retryError) {
        console.error('[incident.service] Retry failed:', retryError)
        throw retryError
      }
      return retryData
    }
    
    throw error
  }

  console.log('[incident.service] Update successful:', data)

  // Emit socket event for real-time update
  const io = getIO()
  if (io) {
    io.emit('incident:updated', {
      incidentId,
      userId,
      updates: data
    })
  }

  return data
}
