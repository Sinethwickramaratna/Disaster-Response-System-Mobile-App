import { supabase } from '@/lib/supabase'

export async function getAlerts() {
  try {
    // Using a more flexible query to avoid column name mismatches
    let query = supabase
      .from('Alert')
      .select('*')

    const { data: alerts, error: alertError } = await query

    if (alertError) {
      console.error('[getAlerts] Query Error:', alertError)
      throw alertError
    }

    if (!alerts || alerts.length === 0) {
      console.log('[getAlerts] No records found in Alert table.')
      return []
    }

    // Log the keys of the first record to debug naming conventions
    console.log('[getAlerts] Sample record keys:', Object.keys(alerts[0]))

    // Filter active alerts in memory
    const activeAlerts = alerts.filter(a => {
      const isActive = a.isActive !== undefined ? a.isActive : a.is_active
      // If the column is missing, assume active for now to debug
      return isActive === true || isActive === null || isActive === undefined
    })

    console.log(`[getAlerts] Found ${alerts.length} total, ${activeAlerts.length} active.`)

    const formatted = activeAlerts.map((alert) => ({
      id: alert.id || alert.alert_id,
      type: alert.type || 'GENERAL',
      severity: alert.severity || 'LOW',
      title: alert.title || 'Untitled Alert',
      description: alert.description || alert.message || '',
      district: alert.district || 'All',
      isPublic: alert.isPublic !== undefined ? alert.isPublic : alert.is_public,
      isActive: alert.isActive !== undefined ? alert.isActive : alert.is_active,
      createdAt: alert.createdAt || alert.created_at || new Date().toISOString(),
      source: alert.source,
      expiresAt: alert.expiresAt || alert.expires_at,
      incidentId: alert.incidentId || alert.incident_id,
      scope: 'internal',
      tableSource: 'Alert',
    }))

    // Sort by date
    return formatted.sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    )
  } catch (e) {
    console.error('[getAlerts] Fatal Error:', e)
    return []
  }
}

export async function getAlertById(alertId: string) {
  if (!alertId) return null

  try {
    const { data: alert, error } = await supabase
      .from('Alert')
      .select('*')
      .eq('id', alertId)
      .maybeSingle()

    if (error || !alert) return null

    return {
      ...alert,
      id: alert.id,
      title: alert.title,
      description: alert.description || alert.message,
      severity: alert.severity,
      district: alert.district,
      status: (alert.isActive ?? alert.is_active) ? 'ACTIVE' : 'INACTIVE',
      createdAt: alert.createdAt || alert.created_at,
      type: alert.type,
      isPublic: alert.isPublic ?? alert.is_public
    }
  } catch (e) {
    return null
  }
}
