import {
  Inject,
  Injectable,
  Optional,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { createRemoteJWKSet, errors, jwtVerify, JWTPayload, JWTVerifyGetKey } from 'jose';

// What we trust from a provider after its signature, issuer, audience and expiry all check out.
export interface VerifiedIdentity {
  // The provider's permanent ID for this person. Accounts are keyed on this, never on email.
  sub: string;
  // Only set when the provider says the address is verified.
  email: string | null;
}

// Lets tests supply local signing keys instead of fetching Apple's and Google's public keys.
export const OAUTH_KEY_SETS = 'OAUTH_KEY_SETS';
export interface OAuthKeySets {
  apple: JWTVerifyGetKey;
  google: JWTVerifyGetKey;
}

const APPLE_ISSUER = 'https://appleid.apple.com';
const GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];
// The iOS app's bundle ID is the audience Apple puts in identity tokens for it.
const DEFAULT_APPLE_CLIENT_IDS = 'online.c705.cypher';

function listFromEnv(value: string | undefined): string[] {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

@Injectable()
export class OAuthTokenVerifier {
  private readonly keySets: OAuthKeySets;

  constructor(@Optional() @Inject(OAUTH_KEY_SETS) keySets?: OAuthKeySets) {
    // createRemoteJWKSet downloads the provider's public keys on first use and caches them.
    this.keySets = keySets ?? {
      apple: createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys')),
      google: createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs')),
    };
  }

  async verifyApple(identityToken: string): Promise<VerifiedIdentity> {
    const audience = listFromEnv(process.env.APPLE_CLIENT_IDS ?? DEFAULT_APPLE_CLIENT_IDS);
    const payload = await this.verify(identityToken, this.keySets.apple, APPLE_ISSUER, audience, 'Apple');
    return this.toIdentity(payload);
  }

  async verifyGoogle(idToken: string): Promise<VerifiedIdentity> {
    const audience = listFromEnv(process.env.GOOGLE_CLIENT_IDS);
    if (audience.length === 0) {
      throw new ServiceUnavailableException('Google sign-in is not available');
    }
    const payload = await this.verify(idToken, this.keySets.google, GOOGLE_ISSUERS, audience, 'Google');
    return this.toIdentity(payload);
  }

  private async verify(
    token: string,
    keys: JWTVerifyGetKey,
    issuer: string | string[],
    audience: string[],
    providerName: string,
  ): Promise<JWTPayload> {
    try {
      const { payload } = await jwtVerify(token, keys, {
        issuer,
        audience,
        // Both providers sign with RS256. Pinning it blocks "alg: none" and HMAC tricks.
        algorithms: ['RS256'],
        // A token missing any of these is rejected outright. jose already rejects an exp in
        // the past and a non-numeric iat; iss and aud are required by the options above.
        requiredClaims: ['sub', 'exp', 'iat'],
      });
      if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
        throw new UnauthorizedException(`Invalid ${providerName} identity token`);
      }
      return payload;
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      // A timeout fetching the provider's keys is our problem, not a bad token.
      if (error instanceof errors.JWKSTimeout || !(error instanceof errors.JOSEError)) {
        throw new ServiceUnavailableException(`Could not reach ${providerName} to check the sign-in`);
      }
      throw new UnauthorizedException(`Invalid ${providerName} identity token`);
    }
  }

  private toIdentity(payload: JWTPayload): VerifiedIdentity {
    // Apple sends email_verified as "true"/"false" strings; Google sends booleans.
    const verified = payload.email_verified === true || payload.email_verified === 'true';
    const email = typeof payload.email === 'string' && verified ? payload.email : null;
    return { sub: payload.sub as string, email };
  }
}
