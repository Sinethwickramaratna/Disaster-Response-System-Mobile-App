import { supabase } from '@/lib/supabase'
import { getIO } from '@/socket'

type ResourceRequestInput = {
  incidentId: string
  resourceType: string
  quantity: number
  priority: string
  notes?: string | null
}

function haversineDistanceKm(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number
) {
  const toRadians = (value: number) => (value * Math.PI) / 180
  const earthRadiusKm = 6371
  const deltaLatitude = toRadians(latitudeB - latitudeA)
  const deltaLongitude = toRadians(longitudeB - longitudeA)

  const a =
    Math.sin(deltaLatitude / 2) ** 2 +
    Math.cos(toRadians(latitudeA)) *
      Math.cos(toRadians(latitudeB)) *
      Math.sin(deltaLongitude / 2) ** 2

  return 2 * earthRadiusKm * Math.asin(Math.sqrt(a))
}

export async function getAssignedResources(userId: string) {
  // First, find any resource requests made by this user
  const { data: userRequests } = await supabase
    .from('ResourceRequest')
    .select('request_id')
    .eq('requested_by', userId)

  const requestIds = (userRequests ?? []).map((r) => r.request_id)

  // Fetch deployments assigned directly to the user OR linked to their requests
  let query = supabase
    .from('LogisticsDeployment')
    .select('deployment_id, incident_id, status, dispatched_at, completed_at, items_dispatched, delivery_notes, resource_request_id, user_id')

  if (requestIds.length > 0) {
    // PostgREST syntax for OR with multiple conditions
    query = query.or(`user_id.eq.${userId},resource_request_id.in.(${requestIds.join(',')})`)
  } else {
    query = query.eq('user_id', userId)
  }

  const { data, error } = await query.order('dispatched_at', { ascending: false })

  if (error) {
    throw error
  }

  return (data ?? []).map((deployment) => ({
    deploymentId: deployment.deployment_id,
    incidentId: deployment.incident_id,
    status: deployment.status,
    dispatchedAt: deployment.dispatched_at,
    completedAt: deployment.completed_at,
    items: Array.isArray(deployment.items_dispatched) ? deployment.items_dispatched : deployment.items_dispatched ?? [],
    deliveryNotes: deployment.delivery_notes,
    requestId: deployment.resource_request_id,
  }))
}

export async function createResourceRequest(userId: string, input: ResourceRequestInput) {
  const items = [
    {
      resourceType: input.resourceType,
      quantity: input.quantity,
      priority: input.priority,
    },
  ]

  const { data, error } = await supabase
    .from('ResourceRequest')
    .insert({
      incident_id: input.incidentId,
      requested_by: userId,
      status: 'PENDING',
      items,
      notes: input.notes ?? null,
    })
    .select('request_id, status, created_at, incident_id')
    .single()

  if (error) {
    throw error
  }

  const result = {
    requestId: data.request_id,
    status: data.status,
    createdAt: data.created_at,
    incidentId: data.incident_id,
  }

  // Emit socket event for real-time update
  const io = getIO()
  if (io) {
    io.emit('resourceRequest:created', {
      requestId: data.request_id,
      userId,
      incidentId: data.incident_id,
      status: data.status,
      items
    })
  }

  return result
}

export async function getMyResourceRequests(userId: string) {
  const { data, error } = await supabase
    .from('ResourceRequest')
    .select('request_id, incident_id, status, created_at, reviewed_at, items')
    .eq('requested_by', userId)
    .order('created_at', { ascending: false })

  if (error) {
    throw error
  }

  return (data ?? []).map((request) => ({
    requestId: request.request_id,
    incidentId: request.incident_id,
    status: request.status,
    createdAt: request.created_at,
    reviewedAt: request.reviewed_at,
    items: Array.isArray(request.items) ? request.items : request.items ?? [],
  }))
}

export async function deleteResourceRequest(userId: string, requestId: string) {
  const { data, error } = await supabase
    .from('ResourceRequest')
    .delete()
    .eq('request_id', requestId)
    .eq('requested_by', userId) // Ensure user only deletes their own requests
    .select('request_id, incident_id')
    .single()

  if (error) {
    throw error
  }

  // Emit socket event for real-time update
  const io = getIO()
  if (io) {
    io.emit('resourceRequest:deleted', {
      requestId,
      userId,
      incidentId: data?.incident_id
    })
  }

  return { success: true, requestId }
}

export async function updateResourceRequestStatus(requestId: string, status: string, userId: string) {
  const { data, error } = await supabase
    .from('ResourceRequest')
    .update({ 
      status,
      reviewed_at: new Date().toISOString()
    })
    .eq('request_id', requestId)
    .select('request_id, requested_by, incident_id, status')
    .single()

  if (error) {
    throw error
  }

  // Emit socket event for real-time update
  const io = getIO()
  if (io) {
    io.emit('resourceRequest:updated', {
      requestId: data.request_id,
      userId: data.requested_by,
      incidentId: data.incident_id,
      status: data.status
    })
  }

  return data
}

type NearbySheltersQuery = {
  userId: string
  zoneId?: number
  district?: string
}

type DivisionRow = {
  division_id: number
  division_name: string
  district: string | null
  province: string | null
  latitude: number | string | null
  longitude: number | string | null
}

function parsePositiveInteger(value: string | undefined) {
  const normalized = value?.trim()

  if (!normalized || !/^\d+$/.test(normalized)) {
    return null
  }

  const parsed = Number.parseInt(normalized, 10)
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null
}

function districtLookupVariants(value: string) {
  const normalized = value.trim()
  const withoutDistrictSuffix = normalized.replace(/\s+district$/i, '').trim()
  const variants = [normalized, withoutDistrictSuffix]

  return Array.from(new Set(variants.filter(Boolean)))
}

async function getDivisionById(divisionId: number) {
  const { data, error } = await supabase
    .from('Division')
    .select('division_id, division_name, district, province, latitude, longitude')
    .eq('division_id', divisionId)
    .maybeSingle()

  if (error) {
    throw error
  }

  return data as DivisionRow | null
}

async function getUserAssignedDistrict(userId: string) {
  const { data, error } = await supabase
    .from('User')
    .select('assignedDistrict')
    .eq('id', userId)
    .maybeSingle()

  if (error) {
    throw error
  }

  const assignedDistrict = data?.assignedDistrict
  return typeof assignedDistrict === 'string' ? assignedDistrict.trim() : ''
}

async function getDivisionByName(divisionName: string) {
  const exactResult = await supabase
    .from('Division')
    .select('division_id, division_name, district, province, latitude, longitude')
    .eq('division_name', divisionName)
    .maybeSingle()

  if (exactResult.error) {
    throw exactResult.error
  }

  if (exactResult.data) {
    return exactResult.data as DivisionRow
  }

  const { data, error } = await supabase
    .from('Division')
    .select('division_id, division_name, district, province, latitude, longitude')
    .ilike('division_name', divisionName)
    .limit(1)

  if (error) {
    throw error
  }

  return (data?.[0] ?? null) as DivisionRow | null
}

async function getDivisionsByDistrict(district: string) {
  for (const variant of districtLookupVariants(district)) {
    const exactResult = await supabase
      .from('Division')
      .select('division_id, division_name, district, province, latitude, longitude')
      .eq('district', variant)

    if (exactResult.error) {
      throw exactResult.error
    }

    if (exactResult.data && exactResult.data.length > 0) {
      return exactResult.data.filter((division) => division.division_id != null) as DivisionRow[]
    }
  }

  for (const variant of districtLookupVariants(district)) {
    const { data, error } = await supabase
      .from('Division')
      .select('division_id, division_name, district, province, latitude, longitude')
      .ilike('district', variant)

    if (error) {
      throw error
    }

    if (data && data.length > 0) {
      return data.filter((division) => division.division_id != null) as DivisionRow[]
    }
  }

  return []
}

async function getShelterDivisionScope(query: NearbySheltersQuery) {
  const assignedDistrict = await getUserAssignedDistrict(query.userId)
  const normalizedDistrict = assignedDistrict || query.district?.trim()
  const assignedDivisionId = query.zoneId ?? parsePositiveInteger(normalizedDistrict)
  const assignedDivision = assignedDivisionId != null ? await getDivisionById(assignedDivisionId) : null

  if (assignedDivision?.district?.trim()) {
    return {
      divisions: await getDivisionsByDistrict(assignedDivision.district.trim()),
      originDivision: assignedDivision,
    }
  }

  if (normalizedDistrict) {
    const districtDivisions = await getDivisionsByDistrict(normalizedDistrict)

    if (districtDivisions.length > 0) {
      return {
        divisions: districtDivisions,
        originDivision: null,
      }
    }

    const divisionByName = await getDivisionByName(normalizedDistrict)

    if (divisionByName?.district?.trim()) {
      return {
        divisions: await getDivisionsByDistrict(divisionByName.district.trim()),
        originDivision: divisionByName,
      }
    }

    return {
      divisions: divisionByName ? [divisionByName] : [],
      originDivision: divisionByName,
    }
  }

  return {
    divisions: assignedDivision ? [assignedDivision] : [],
    originDivision: assignedDivision,
  }
}

export async function getNearbyShelters(query: NearbySheltersQuery) {
  const { divisions: divisionRows, originDivision } = await getShelterDivisionScope(query)
  const divisionIds = divisionRows.map((division) => division.division_id)

  if (divisionIds.length === 0) {
    return []
  }

  const { data: shelters, error: sheltersError } = await supabase
    .from('Shelter')
    .select('shelter_id, name, latitude, longitude, max_capacity, current_occupancy, status, contact_person, contact_phone, division_id')
    .in('division_id', divisionIds)

  if (sheltersError) {
    throw sheltersError
  }

  const sheltersWithDistance = (shelters ?? []).map((shelter) => {
    const shelterLatitude = shelter.latitude != null ? Number(shelter.latitude) : null
    const shelterLongitude = shelter.longitude != null ? Number(shelter.longitude) : null
    const shelterDivision = divisionRows.find((division) => division.division_id === shelter.division_id)
    const distanceOrigin = originDivision ?? shelterDivision

    const distanceKm =
      distanceOrigin?.latitude != null &&
      distanceOrigin?.longitude != null &&
      shelterLatitude != null &&
      shelterLongitude != null
        ? Number(haversineDistanceKm(
            Number(distanceOrigin.latitude),
            Number(distanceOrigin.longitude),
            shelterLatitude,
            shelterLongitude
          ).toFixed(1))
        : null

    return {
      shelterId: shelter.shelter_id,
      name: shelter.name,
      latitude: shelterLatitude,
      longitude: shelterLongitude,
      capacity: shelter.max_capacity,
      occupancy: shelter.current_occupancy,
      distanceKm,
      status: shelter.status,
      contactPerson: shelter.contact_person,
      contactPhone: shelter.contact_phone,
    }
  })

  return sheltersWithDistance.sort((left, right) => {
    if (left.distanceKm == null && right.distanceKm == null) {
      return 0
    }

    if (left.distanceKm == null) {
      return 1
    }

    if (right.distanceKm == null) {
      return -1
    }

    return left.distanceKm - right.distanceKm
  })
}
export async function updateLogisticsDeployment(deploymentId: string, userId: string, status: string, deliveryNotes?: string) {
  const { data, error } = await supabase
    .from('LogisticsDeployment')
    .update({ 
      status, 
      delivery_notes: deliveryNotes,
      completed_at: status === 'DELIVERED' ? new Date().toISOString() : null
    })
    .eq('deployment_id', deploymentId)
    .select('deployment_id, incident_id, user_id, status, delivery_notes')
    .single()

  if (error) {
    throw error
  }

  // Emit socket event for real-time update
  const io = getIO()
  if (io) {
    io.emit('logisticsDeployment:updated', {
      deploymentId: data.deployment_id,
      userId: data.user_id,
      incidentId: data.incident_id,
      status: data.status,
      deliveryNotes: data.delivery_notes
    })
  }

  return data
}

export async function getResourceRequestDetails(requestId: string) {
  const { data: request, error: requestError } = await supabase
    .from('ResourceRequest')
    .select('request_id, incident_id, status, created_at, reviewed_at, items, notes')
    .eq('request_id', requestId)
    .single()

  if (requestError) throw requestError

  // Fetch incident details
  const { data: incident, error: incidentError } = await supabase
    .from('ConfirmedIncident')
    .select('id, title, district, latitude, longitude, description')
    .eq('id', request.incident_id)
    .single()

  if (incidentError) throw incidentError

  // Fetch assigned Field Officer
  const { data: assignments, error: assignmentError } = await supabase
    .from('PersonnelAssignment')
    .select('user_id, assigned_role')
    .eq('incident_id', request.incident_id)
    .eq('assigned_role', 'FIELD_OFFICER')
    .neq('status', 'RELEASED')

  let fieldOfficer = null
  if (!assignmentError && assignments && assignments.length > 0) {
    const { data: user } = await supabase
      .from('User')
      .select('id, name, email')
      .eq('id', assignments[0].user_id)
      .single()
    
    if (user) fieldOfficer = user
  }

  return {
    ...request,
    incident,
    fieldOfficer
  }
}
