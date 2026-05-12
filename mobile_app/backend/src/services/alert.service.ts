import { supabase } from '@/lib/supabase'

export async function getAlerts(userDistricts: string[] = []) {
  let query = supabase
    .from('Alert')
    .select('id, type, severity, title, district, isPublic, isActive, createdAt')
    .eq('isActive', true)
    .order('createdAt', { ascending: false })

  if (userDistricts.length > 0) {
    query = query.in('district', userDistricts)
  }

  const { data, error } = await query

  if (error) {
    throw error
  }

  return (data ?? []).map((alert) => ({
    id: alert.id,
    type: alert.type,
    severity: alert.severity,
    title: alert.title,
    district: alert.district,
    isPublic: alert.isPublic,
    isActive: alert.isActive,
    createdAt: alert.createdAt,
  }))
}

export async function getAlertById(alertId: string) {
  const { data, error } = await supabase
    .from('Alert')
    .select('id, title, description, severity, district, source, isActive, createdAt, expiresAt')
    .eq('id', alertId)
    .maybeSingle()

  if (error) {
    throw error
  }

  if (!data) {
    return null
  }

  return {
    id: data.id,
    title: data.title,
    description: data.description,
    severity: data.severity,
    district: data.district,
    source: data.source,
    isActive: data.isActive,
    createdAt: data.createdAt,
    expiresAt: data.expiresAt,
  }
}
