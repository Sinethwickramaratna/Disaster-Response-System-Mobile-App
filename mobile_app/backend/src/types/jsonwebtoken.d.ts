declare module 'jsonwebtoken' {
  export function sign(payload: string | Buffer | object, secretOrPrivateKey: string, options?: Record<string, unknown>): string;
  export function verify(token: string, secretOrPublicKey: string, options?: Record<string, unknown>): unknown;
}