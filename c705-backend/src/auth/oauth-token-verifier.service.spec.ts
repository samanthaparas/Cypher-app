import { ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { createLocalJWKSet, exportJWK, generateKeyPair, JWTPayload, KeyLike, SignJWT } from 'jose';
import { OAuthTokenVerifier } from './oauth-token-verifier.service';

// These tests sign tokens with a local key pair and hand the verifier the matching public key,
// so nothing calls Apple or Google.
describe('OAuthTokenVerifier', () => {
  const APPLE_ISS = 'https://appleid.apple.com';
  const BUNDLE_ID = 'online.c705.cypher';
  const GOOGLE_CLIENT = 'test-client.apps.googleusercontent.com';

  let goodKey: KeyLike;
  let otherKey: KeyLike;
  let verifier: OAuthTokenVerifier;
  const savedEnv = { ...process.env };

  beforeAll(async () => {
    const good = await generateKeyPair('RS256');
    const other = await generateKeyPair('RS256');
    goodKey = good.privateKey;
    otherKey = other.privateKey;
    const jwks = createLocalJWKSet({
      keys: [{ ...(await exportJWK(good.publicKey)), kid: 'good', alg: 'RS256' }],
    });
    verifier = new OAuthTokenVerifier({ apple: jwks, google: jwks });
  });

  beforeEach(() => {
    delete process.env.APPLE_CLIENT_IDS;
    delete process.env.GOOGLE_CLIENT_IDS;
  });

  afterAll(() => {
    process.env = savedEnv;
  });

  function sign(
    claims: JWTPayload,
    { key = goodKey, kid = 'good', iss = APPLE_ISS, aud = BUNDLE_ID, sub = 'apple-user-1', exp = '5m' as string | number } = {},
  ) {
    return new SignJWT(claims)
      .setProtectedHeader({ alg: 'RS256', kid })
      .setIssuer(iss)
      .setAudience(aud)
      .setSubject(sub)
      .setIssuedAt()
      .setExpirationTime(exp)
      .sign(key);
  }

  describe('Apple', () => {
    it('accepts a valid token and returns sub plus verified email', async () => {
      const token = await sign({ email: 'a@example.test', email_verified: 'true' });
      await expect(verifier.verifyApple(token)).resolves.toEqual({ sub: 'apple-user-1', email: 'a@example.test' });
    });

    it('drops an email Apple did not verify', async () => {
      const token = await sign({ email: 'a@example.test', email_verified: 'false' });
      await expect(verifier.verifyApple(token)).resolves.toEqual({ sub: 'apple-user-1', email: null });
    });

    it('works without any email claim (returning users)', async () => {
      const token = await sign({});
      await expect(verifier.verifyApple(token)).resolves.toEqual({ sub: 'apple-user-1', email: null });
    });

    it.each([
      ['junk string', async () => 'not-a-real-token'],
      ['signed by a different key', async () => sign({}, { key: otherKey })],
      ['wrong audience', async () => sign({}, { aud: 'com.someone.else' })],
      ['wrong issuer', async () => sign({}, { iss: 'https://evil.example' })],
      ['expired', async () => sign({}, { exp: Math.floor(Date.now() / 1000) - 60 })],
      ['unknown key id', async () => sign({}, { kid: 'nope' })],
      ['unsigned (alg none)', async () => unsignedToken({ iss: APPLE_ISS, aud: BUNDLE_ID, sub: 'x' })],
    ])('rejects a token that is %s', async (_label, makeToken) => {
      await expect(verifier.verifyApple(await makeToken())).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('honours APPLE_CLIENT_IDS when set', async () => {
      process.env.APPLE_CLIENT_IDS = 'com.other.app';
      const token = await sign({});
      await expect(verifier.verifyApple(token)).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('Google', () => {
    it('is unavailable until GOOGLE_CLIENT_IDS is set', async () => {
      const token = await sign({}, { iss: 'https://accounts.google.com', aud: GOOGLE_CLIENT });
      await expect(verifier.verifyGoogle(token)).rejects.toBeInstanceOf(ServiceUnavailableException);
    });

    it('accepts a valid token when configured', async () => {
      process.env.GOOGLE_CLIENT_IDS = GOOGLE_CLIENT;
      const token = await sign(
        { email: 'g@example.test', email_verified: true },
        { iss: 'https://accounts.google.com', aud: GOOGLE_CLIENT, sub: 'google-user-1' },
      );
      await expect(verifier.verifyGoogle(token)).resolves.toEqual({ sub: 'google-user-1', email: 'g@example.test' });
    });

    it('rejects an Apple token sent to the Google route', async () => {
      process.env.GOOGLE_CLIENT_IDS = GOOGLE_CLIENT;
      const token = await sign({});
      await expect(verifier.verifyGoogle(token)).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('required claims', () => {
    // Builds an otherwise valid, correctly signed token and leaves out one claim, so the only
    // thing wrong with it is the missing claim.
    function signWithout(missing: 'sub' | 'exp' | 'iat', iss: string, aud: string) {
      const now = Math.floor(Date.now() / 1000);
      const claims: JWTPayload = { iss, aud, sub: 'user-1', iat: now, exp: now + 300 };
      delete claims[missing];
      return new SignJWT(claims).setProtectedHeader({ alg: 'RS256', kid: 'good' }).sign(goodKey);
    }

    const providers = [
      { name: 'Apple', iss: APPLE_ISS, aud: BUNDLE_ID, verify: (t: string) => verifier.verifyApple(t) },
      { name: 'Google', iss: 'https://accounts.google.com', aud: GOOGLE_CLIENT, verify: (t: string) => verifier.verifyGoogle(t) },
    ];

    beforeEach(() => {
      process.env.GOOGLE_CLIENT_IDS = GOOGLE_CLIENT;
    });

    it.each(providers)('$name: accepts the control token with all claims present', async ({ iss, aud, verify }) => {
      const now = Math.floor(Date.now() / 1000);
      const token = await new SignJWT({ iss, aud, sub: 'user-1', iat: now, exp: now + 300 })
        .setProtectedHeader({ alg: 'RS256', kid: 'good' })
        .sign(goodKey);
      await expect(verify(token)).resolves.toEqual({ sub: 'user-1', email: null });
    });

    describe.each(providers)('$name', ({ iss, aud, verify }) => {
      it.each(['sub', 'exp', 'iat'] as const)('rejects a token with no %s claim', async (missing) => {
        const token = await signWithout(missing, iss, aud);
        await expect(verify(token)).rejects.toBeInstanceOf(UnauthorizedException);
      });
    });
  });
});

function unsignedToken(payload: object): string {
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({ ...payload, iat: now, exp: now + 300 })}.`;
}
