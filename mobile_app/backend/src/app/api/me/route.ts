import { NextRequest, NextResponse } from 'next/server'
import { supabase } from '@/lib/supabase'
import { authenticateFieldOfficer } from '@/lib/auth'

export async function GET(req: NextRequest) {
  try {
    const auth = authenticateFieldOfficer(req)

    if (!auth.ok) {
      return auth.response
    }

    const { data, error: profileError } = await supabase
      .from('User')
      .select('role, assignedDistrict, name')
      .eq('id', auth.context.userId)
      .maybeSingle()

    if (profileError) {
      return NextResponse.json(
        { error: 'Failed to retrieve user profile' },
        { status: 500 }
      )
    }

    const role = data?.role
    const zone = data?.assignedDistrict
    const name = data?.name

    return NextResponse.json({
      userId: auth.context.userId,
      email: auth.context.email,
      name,
      role,
      zone,
    })

  } catch (error) {
    console.error(error)
    return NextResponse.json(
      { error: 'Failed to retrieve user' },
      { status: 500 }
    )
  }
}