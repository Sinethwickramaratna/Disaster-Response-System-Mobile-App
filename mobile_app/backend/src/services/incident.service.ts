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
  description?: string
  createdAt?: string
  created_at?: string
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
      .select('*')
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

  // Handle flexible field names for display
  const affectedPopulation = incident.affectedPeople ?? incident.affected_population ?? incident.affectedPeopleCount ?? 0;
  const status = incident.status;
  const severity = incident.severity;

  return {
    incidentId: incident.id,
    title: incident.title,
    severity: severity,
    status: status,
    affectedPopulation: affectedPopulation,
    description: incident.description,
    location: {
      latitude: incident.latitude,
      longitude: incident.longitude,
    },
    division: {
      divisionId: incident.division_id,
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
    .select('incident_id, status, assigned_at, ConfirmedIncident:incident_id (*)')
    .eq('user_id', userId)
    .order('assigned_at', { ascending: false })

  if (error) {
    throw error
  }

  return ((data ?? []) as IncidentAssignmentRow[])
    .filter((row) => unwrapRelation(row.ConfirmedIncident))
    .map((row) => {
      const inc = unwrapRelation(row.ConfirmedIncident)!;
      return {
        incidentId: inc.id,
        title: inc.title,
        severity: inc.severity,
        status: inc.status,
        latitude: inc.latitude,
        longitude: inc.longitude,
        description: inc.description || '',
        createdAt: inc.createdAt || inc.created_at || new Date().toISOString(),
      }
    })
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
  console.log('[incident.service] updateIncident start:', { userId, incidentId, updates })

  // 1. Verify authorization (Officer must be assigned)
  const { data: assignment, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('assignment_id, incident_id, status')
    .eq('user_id', userId)
    .eq('incident_id', incidentId)
    .maybeSingle()

  if (assignmentError) throw assignmentError
  if (!assignment) throw new Error('Unauthorized: User is not assigned to this incident')

  // 2. Prepare normalization for Enums
  const rawStatus = updates.status?.trim().toUpperCase().replace('-', '_') || ''
  const rawSeverity = updates.severity?.trim().toUpperCase() || ''
  
  // Personnel-specific statuses (EN_ROUTE, ON_SITE, etc.)
  const personnelStatuses = ['ASSIGNED', 'EN_ROUTE', 'ON_SITE', 'RELEASED', 'ATTHEINCIDENT']
  
  // Incident-level statuses (The only ones allowed for ConfirmedIncident)
  const allowedIncidentStatuses = ['ACTIVE', 'UNDER_RESPONSE', 'RESOLVED', 'CLOSED']

  let finalResult: any = null

  // 3. Execution Block
  try {
    // --- Update PersonnelAssignment Status if applicable ---
    if (personnelStatuses.includes(rawStatus)) {
      let dbPersonnelStatus = rawStatus === 'ATTHEINCIDENT' ? 'ON_SITE' : rawStatus
      console.log(`[incident.service] Updating PersonnelAssignment status to: ${dbPersonnelStatus}`)
      
      const { data, error } = await supabase
        .from('PersonnelAssignment')
        .update({ status: dbPersonnelStatus })
        .eq('user_id', userId)
        .eq('incident_id', incidentId)
        .select()
        .single()
      
      if (error) throw error
      finalResult = data
    }

    // --- Update ConfirmedIncident Fields ---
    const incidentPayload: any = { updatedAt: new Date().toISOString() }
    let hasIncidentUpdates = false

    if (updates.description !== undefined) {
      incidentPayload.description = updates.description
      hasIncidentUpdates = true
    }

    // Handle Severity (normalize to common values)
    if (rawSeverity) {
      let dbSeverity = rawSeverity
      if (dbSeverity === 'MODERATE') dbSeverity = 'MEDIUM'
      incidentPayload.severity = dbSeverity
      hasIncidentUpdates = true
    }

    // Handle Incident Status (only if it matches the allowed list)
    if (allowedIncidentStatuses.includes(rawStatus)) {
      incidentPayload.status = rawStatus
      hasIncidentUpdates = true
    }

    // Handle Affected People (try different column name variants)
    if (updates.affectedPeople !== undefined) {
      incidentPayload.affectedPeople = updates.affectedPeople
      hasIncidentUpdates = true
    }

    if (hasIncidentUpdates) {
      console.log('[incident.service] Updating ConfirmedIncident:', incidentPayload)
      
      const { data, error } = await supabase
        .from('ConfirmedIncident')
        .update(incidentPayload)
        .eq('id', incidentId)
        .select()
        .single()

      if (error) {
        console.error('[incident.service] ConfirmedIncident update error:', error)
        
        // --- Fallback Strategy for schema variations ---
        const fallbackPayload: any = { updated_at: new Date().toISOString() }
        if (incidentPayload.description) fallbackPayload.description = incidentPayload.description
        if (incidentPayload.severity) fallbackPayload.severity = incidentPayload.severity
        if (incidentPayload.status) fallbackPayload.status = incidentPayload.status
        if (updates.affectedPeople !== undefined) {
          fallbackPayload.affected_population = updates.affectedPeople
          fallbackPayload.affected_people = updates.affectedPeople
        }

        console.log('[incident.service] Retrying with fallback payload:', fallbackPayload)
        const { data: retryData, error: retryError } = await supabase
          .from('ConfirmedIncident')
          .update(fallbackPayload)
          .eq('id', incidentId)
          .select()
          .single()

        if (retryError) throw retryError
        finalResult = retryData
      } else {
        finalResult = data
      }
    }

    return finalResult
  } catch (err) {
    console.error('[incident.service] Final update catch block:', err)
    throw err
  }
}
