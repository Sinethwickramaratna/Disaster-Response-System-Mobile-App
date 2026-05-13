import { supabase } from '@/lib/supabase'

export async function getAlerts(userDistricts: string[] = []) {
  // Alert table query
  let query = supabase
    .from('Alert')
    .select('id, type, severity, title, description, district, isPublic, isActive, createdAt, source, expiresAt, incidentId')
    .eq('isActive', true)
    .order('createdAt', { ascending: false })

  if (userDistricts.length > 0) {
    query = query.in('district', userDistricts)
  }

  const { data: alerts, error: alertError } = await query

  if (alertError) {
    console.error('[getAlerts] Alert table query error:', alertError)
    throw alertError
  }

  console.log(`[getAlerts] Fetched ${alerts?.length ?? 0} Alert records for districts:`, userDistricts)

  const formattedAlerts = (alerts ?? []).map((alert) => ({
    id: alert.id,
    type: alert.type,
    severity: alert.severity,
    title: alert.title,
    description: alert.description,
    district: alert.district,
    isPublic: alert.isPublic,
    isActive: alert.isActive,
    createdAt: alert.createdAt,
    source: alert.source,
    expiresAt: alert.expiresAt,
    incidentId: alert.incidentId,
    scope: 'internal',
    tableSource: 'Alert',
  }))

  return formattedAlerts.sort((a, b) => 
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  )
}

export async function getAlertById(alertId: string) {
  // Only fetching from internal Alert table (UUID based)
  // PublicAlert support has been removed as per user request
  if (alertId && (alertId.includes('-') || alertId.length > 8)) {
    const { data: internalAlert } = await supabase
      .from('Alert')
      .select('id, title, description, severity, district, source, isActive, createdAt, expiresAt, type, incidentId, isPublic')
      .eq('id', alertId)
      .maybeSingle()

    if (internalAlert) {
      return {
        ...internalAlert,
        status: internalAlert.isActive ? 'ACTIVE' : 'INACTIVE'
      }
    }
  }

  return null
}
