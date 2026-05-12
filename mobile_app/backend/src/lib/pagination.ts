export function parseLimit(value: string | null | undefined, fallback = 50) {
  const parsed = Number.parseInt(value ?? '', 10)

  if (Number.isNaN(parsed)) {
    return fallback
  }

  return Math.max(1, Math.min(parsed, 100))
}

export function parsePage(value: string | null | undefined, fallback = 1) {
  const parsed = Number.parseInt(value ?? '', 10)

  if (Number.isNaN(parsed)) {
    return fallback
  }

  return Math.max(1, parsed)
}
