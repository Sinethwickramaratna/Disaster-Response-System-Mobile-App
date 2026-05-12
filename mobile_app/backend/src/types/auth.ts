export interface JwtClaims {
  userId: string
  email: string
  role: string
}

export interface AuthContext extends JwtClaims {}

export interface ValidationIssue {
  field: string
  message: string
}