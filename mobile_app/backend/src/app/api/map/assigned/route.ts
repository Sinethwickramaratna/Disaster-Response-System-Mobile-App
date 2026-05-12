import { NextRequest, NextResponse } from 'next/server'
import { authenticateFieldOfficer } from '@/lib/auth'
import { jsonServerError } from '@/lib/response'
import { getAssignedIncidentMap } from '@/services/incident.service'
import { supabase } from '@/lib/supabase'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const incidents = await getAssignedIncidentMap(auth.context.userId)
    const { data: alerts } = await supabase
      .from('Alert')
      .select('id, severity, district, isActive')
      .eq('isActive', true)
      .limit(25)

    const alertDistricts = Array.from(
      new Set(
        (alerts ?? [])
          .map((alert) => alert.district)
          .filter((district): district is string => Boolean(district))
      )
    )

    const { data: divisions } = alertDistricts.length > 0
      ? await supabase
          .from('Division')
          .select('district, latitude, longitude')
          .in('district', alertDistricts)
      : { data: [] as Array<{ district: string | null; latitude: number | null; longitude: number | null }> }

    const divisionLookup = new Map(
      (divisions ?? [])
        .filter((division) => Boolean(division.district))
        .map((division) => [division.district as string, division])
    )

    const mapData = [
      ...incidents.map((incident) => ({
        id: incident.incidentId,
        type: 'INCIDENT',
        severity: incident.severity,
        lat: incident.latitude,
        lng: incident.longitude,
        status: incident.status,
      })),
      ...(alerts ?? []).map((alert) => {
        const division = alert.district ? divisionLookup.get(alert.district) : null

        return {
          id: alert.id,
          type: 'ALERT',
          severity: alert.severity,
          lat: division?.latitude ?? null,
          lng: division?.longitude ?? null,
          status: alert.isActive ? 'ACTIVE' : 'INACTIVE',
        }
      }),
    ]

    return NextResponse.json(mapData)
  } catch (error) {
    console.error(error)

    return jsonServerError('Failed to retrieve map data')
  }
}
