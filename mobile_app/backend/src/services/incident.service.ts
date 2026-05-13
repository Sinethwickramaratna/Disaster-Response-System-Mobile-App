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
    .select('assignment_id, incident_id, status')
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

  let finalResult: any = null

  // 2. Handle status updates
  if (updates.status) {
    const rawStatus = updates.status.trim().toUpperCase().replace('-', '_')
    const personnelStatuses = ['ASSIGNED', 'EN_ROUTE', 'ON_SITE', 'RELEASED', 'ATTHEINCIDENT']
    
    if (personnelStatuses.includes(rawStatus)) {
      // Map legacy/app strings to DB check constraint values
      let dbStatus = rawStatus
      if (dbStatus === 'ATTHEINCIDENT') dbStatus = 'ON_SITE'
      
      console.log(`[incident.service] Updating PersonnelAssignment status to ${dbStatus}`)
      const { data, error } = await supabase
        .from('PersonnelAssignment')
        .update({ status: dbStatus })
        .eq('user_id', userId)
        .eq('incident_id', incidentId)
        .select()
        .single()
        
      if (error) {
        console.error('[incident.service] PersonnelAssignment status update failed:', error)
        throw error
      }
      finalResult = data
    } else {
      // It's an incident-level status update (e.g. ACTIVE, CLOSED, RESOLVED)
      // Check if user has permission to update incident-level status
      // (For now, we allow if they are assigned, but ideally we'd check roles)
      const { data, error } = await supabase
        .from('ConfirmedIncident')
        .update({ status: rawStatus, updatedAt: new Date().toISOString() })
        .eq('id', incidentId)
        .select()
        .single()
        
      if (error) {
        console.error('[incident.service] ConfirmedIncident status update failed:', error)
        throw error
      }
      finalResult = data
    }
  }

  // 3. Handle other incident-level fields (description, affected people, severity)
  if (updates.description !== undefined || updates.affectedPeople !== undefined || updates.severity !== undefined) {
    const incidentPayload: any = { updatedAt: new Date().toISOString() }
    
    if (updates.description !== undefined) incidentPayload.description = updates.description
    if (updates.severity !== undefined) incidentPayload.severity = updates.severity.toUpperCase()
    
    // Handle affectedPeople with possible naming variations
    if (updates.affectedPeople !== undefined) {
      incidentPayload.affectedPeople = updates.affectedPeople
    }

    console.log('[incident.service] Updating ConfirmedIncident fields:', incidentPayload)
    const { data, error } = await supabase
      .from('ConfirmedIncident')
      .update(incidentPayload)
      .eq('id', incidentId)
      .select()
      .single()

    if (error) {
      console.error('[incident.service] ConfirmedIncident fields update failed:', error)
      
      // Fallback for naming variations
      if (error.code === 'PGRST204' || error.message?.includes('column')) {
        const fallbackPayload: any = { updated_at: new Date().toISOString() }
        if (updates.description !== undefined) fallbackPayload.description = updates.description
        if (updates.severity !== undefined) fallbackPayload.severity = updates.severity.toUpperCase()
        if (updates.affectedPeople !== undefined) fallbackPayload.affected_population = updates.affectedPeople
        
        const { data: retryData, error: retryError } = await supabase
          .from('ConfirmedIncident')
          .update(fallbackPayload)
          .eq('id', incidentId)
          .select()
          .single()
          
        if (retryError) throw retryError
        finalResult = retryData
      } else {
        throw error
      }
    } else {
      finalResult = data
    }
  }

  // 4. Emit socket event
  const io = getIO()
  if (io) {
    io.emit('assignment:updated', { 
      userId, 
      incidentId, 
      event: 'status_update' 
    })
  }

  return finalResult
}
