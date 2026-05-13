import { NextResponse, NextRequest } from 'next/server'
import bcrypt from 'bcryptjs'
import { supabase } from '@/lib/supabase'
import { jsonForbidden, jsonServerError, jsonValidationError } from '@/lib/response'
import { signFieldOfficerToken } from '@/lib/auth'

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()

    const email = typeof body?.email === 'string' ? body.email.trim() : ''
    const password = typeof body?.password === 'string' ? body.password : ''

    if (!email || !password) {
      return jsonValidationError([
        { field: 'email', message: 'Email is required' },
        { field: 'password', message: 'Password is required' },
      ])
    }

    const { data: user, error } = await supabase
      .from('User')
      .select('id, email, password_hash, role, name, assignedDistrict')
      .eq('email', email)
      .maybeSingle()

    if (error) {
      console.error('Login Supabase error:', error)
      return jsonServerError(
        process.env.NODE_ENV === 'development'
          ? `Supabase login query failed: ${error.message}`
          : undefined
      )
    }

    if (!user) {
      return NextResponse.json(
        { error: 'Invalid email or password' },
        { status: 401 }
      )
    }

    if (!user.password_hash) {
      return jsonServerError(
        process.env.NODE_ENV === 'development'
          ? 'User is missing password_hash'
          : undefined
      )
    }

    const isPasswordValid = await bcrypt.compare(
      password,
      user.password_hash
    )

    if (!isPasswordValid) {
      return NextResponse.json(
        { error: 'Invalid email or password' },
        { status: 401 }
      )
    }

    if (
      user.role !== 'FIELD_OFFICER' &&
      user.role !== 'RESPONSE_TEAM_MEMBER' &&
      user.role !== 'LOGISTICS_STAFF'
    ) {
      return jsonForbidden()
    }

    const token = signFieldOfficerToken({
      userId: user.id,
      email: user.email,
      role: user.role,
    })

    return NextResponse.json(
      {
        message: 'Login successful',
        token,
        user: {
          userId: user.id,
          email: user.email,
          role: user.role,
          name: user.name ?? null,
          assignedDistrict: user.assignedDistrict ?? null,
        },
      },
      { status: 200 }
    )
  } catch (error) {
    console.error('Login error:', error)

    return jsonServerError(
      process.env.NODE_ENV === 'development' && error instanceof Error
        ? error.message
        : 'An error occurred during login'
    )
  }
}
