import { supabase } from '@/lib/supabase'

export async function getAlerts(userDistricts: string[] = []) {
  // Alert table uses camelCase (based on assignment.service usage)
  let query = supabase
    .from('Alert')
    .select('id, type, severity, title, description, district, isPublic, isActive, createdAt, source, expiresAt, incidentId')
    .eq('isActive', true)
    .order('createdAt', { ascending: false })

  if (userDistricts.length > 0) {
    query = query.in('district', userDistricts)
  }

  // PublicAlert table uses snake_case (based on migration)
  const publicAlertQuery = supabase
    .from('PublicAlert')
    .select('alert_id, title, message, severity_level, status, issued_at, incident_id')
    .eq('status', 'ACTIVE')
    .order('issued_at', { ascending: false })

  const [{ data: alerts, error: alertError }, { data: publicAlerts, error: publicAlertError }] = await Promise.all([
    query,
    publicAlertQuery
  ])

  if (alertError) {
    console.error('[getAlerts] Alert table query error:', alertError)
    throw alertError
  }
  if (publicAlertError) {
    console.error('[getAlerts] PublicAlert table query error:', publicAlertError)
    throw publicAlertError
  }

  console.log(`[getAlerts] Fetched ${alerts?.length ?? 0} Alert records and ${publicAlerts?.length ?? 0} PublicAlert records for districts:`, userDistricts)

  const formattedAlerts = [
    ...(alerts ?? []).map((alert) => ({
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
    })),
    ...(publicAlerts ?? []).map((alert) => ({
      id: alert.alert_id.toString(),
      alert_id: alert.alert_id,
      type: 'PUBLIC_ADVISORY',
      severity: alert.severity_level,
      title: alert.title,
      description: alert.message,
      message: alert.message,
      district: userDistricts[0] ?? 'Nationwide',
      isPublic: true,
      isActive: alert.status === 'ACTIVE',
      createdAt: alert.issued_at,
      issued_at: alert.issued_at,
      incidentId: alert.incident_id,
      scope: 'citizen',
      tableSource: 'PublicAlert',
    }))
  ]

  return formattedAlerts.sort((a, b) => 
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  )
}

export async function getAlertById(alertId: string) {
  // 1. Try fetching from internal Alert table (UUID based)
  if (alertId.includes('-')) {
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

  // 2. Try fetching from PublicAlert table (Integer based)
  const numericId = parseInt(alertId)
  if (!isNaN(numericId) && /^\d+$/.test(alertId)) {
    const { data: publicAlert } = await supabase
      .from('PublicAlert')
      .select('alert_id, title, message, severity_level, status, issued_at, incident_id')
      .eq('alert_id', numericId)
      .maybeSingle()

    if (publicAlert) {
      return {
        id: publicAlert.alert_id.toString(),
        alert_id: publicAlert.alert_id,
        title: publicAlert.title,
        description: publicAlert.message,
        message: publicAlert.message,
        severity: publicAlert.severity_level,
        severity_level: publicAlert.severity_level,
        status: publicAlert.status,
        createdAt: publicAlert.issued_at,
        issued_at: publicAlert.issued_at,
        incidentId: publicAlert.incident_id,
        incident_id: publicAlert.incident_id,
        type: 'PUBLIC_ADVISORY',
        isPublic: true
      }
    }
  }

  return null
}
