import { supabase } from '@/lib/supabase'

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
  const { data, error } = await supabase
    .from('LogisticsDeployment')
    .select('deployment_id, incident_id, status, dispatched_at, completed_at, items_dispatched')
    .eq('user_id', userId)
    .order('dispatched_at', { ascending: false })

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

  return {
    requestId: data.request_id,
    status: data.status,
    createdAt: data.created_at,
    incidentId: data.incident_id,
  }
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

export async function getNearbyShelters(zoneId: number) {
  const [{ data: division, error: divisionError }, { data: shelters, error: sheltersError }] = await Promise.all([
    supabase
      .from('Division')
      .select('division_id, division_name, district, province, latitude, longitude')
      .eq('division_id', zoneId)
      .maybeSingle(),
    supabase
      .from('Shelter')
      .select('shelter_id, name, latitude, longitude, max_capacity, current_occupancy, status, contact_person, contact_phone, division_id')
      .eq('division_id', zoneId),
  ])

  if (divisionError) {
    throw divisionError
  }

  if (sheltersError) {
    throw sheltersError
  }

  const sheltersWithDistance = (shelters ?? []).map((shelter) => {
    const shelterLatitude = shelter.latitude != null ? Number(shelter.latitude) : null
    const shelterLongitude = shelter.longitude != null ? Number(shelter.longitude) : null

    const distanceKm =
      division?.latitude != null &&
      division?.longitude != null &&
      shelterLatitude != null &&
      shelterLongitude != null
        ? Number(haversineDistanceKm(
            Number(division.latitude),
            Number(division.longitude),
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
