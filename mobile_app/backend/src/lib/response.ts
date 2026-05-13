import { NextResponse } from 'next/server'
import type { ValidationIssue } from '@/types/auth'

export function jsonOk<T>(data: T, status = 200) {
  return NextResponse.json(data, { status })
}

export function jsonCreated<T>(data: T) {
  return NextResponse.json(data, { status: 201 })
}

export function jsonUnauthorized() {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
}

export function jsonForbidden() {
  return NextResponse.json({ error: 'Access denied' }, { status: 403 })
}

export function jsonNotFound(message = 'Resource not found') {
  return NextResponse.json({ error: message }, { status: 404 })
}

export function jsonValidationError(details: ValidationIssue[]) {
  return NextResponse.json(
    { error: 'Validation failed', details },
    { status: 400 }
  )
}

export function jsonServerError(message = 'Internal server error') {
  return NextResponse.json({ error: message }, { status: 500 })
}