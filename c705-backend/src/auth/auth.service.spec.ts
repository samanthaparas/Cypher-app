import { ConflictException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createLocalJWKSet, exportJWK, generateKeyPair, KeyLike, SignJWT } from 'jose';
import { AuthService } from './auth.service';
import { OAuthTokenVerifier } from './oauth-token-verifier.service';

// A small in-memory stand-in for the parts of Prisma that AuthService uses.
type FakeUser = {
  id: string;
  email: string;
  username: string | null;
  password: string;
  role: string;
  appleSub: string | null;
  googleSub: string | null;
};
const UNIQUE_FIELDS = ['id', 'email', 'username', 'appleSub', 'googleSub'] as const;

function createFakePrisma() {
  const users: FakeUser[] = [];
  let nextId = 1;
  const match = (where: Record<string, unknown>) =>
    users.find((user) =>
      Object.entries(where).every(([key, value]) => value !== undefined && user[key as keyof FakeUser] === value),
    ) ?? null;
  return {
    users,
    user: {
      findUnique: jest.fn(async ({ where }) => match(where)),
      findFirst: jest.fn(async ({ where }) => {
        const wanted = String(where.email.equals).toLowerCase();
        return users.find((user) => user.email.toLowerCase() === wanted) ?? null;
      }),
      create: jest.fn(async ({ data }) => {
        const user: FakeUser = { id: `user-${nextId++}`, username: null, appleSub: null, googleSub: null, ...data };
        for (const field of UNIQUE_FIELDS) {
          if (user[field] != null && users.some((other) => other[field] === user[field])) {
            throw Object.assign(new Error('Unique constraint failed'), { code: 'P2002' });
          }
        }
        users.push(user);
        return user;
      }),
      update: jest.fn(async ({ where, data }) => {
        const user = match(where);
        if (!user) throw new Error('Record not found');
        Object.assign(user, data);
        return user;
      }),
    },
  };
}

describe('AuthService', () => {
  const APPLE_ISS = 'https://appleid.apple.com';
  const BUNDLE_ID = 'online.c705.cypher';
  let signingKey: KeyLike;
  let verifier: OAuthTokenVerifier;
  let prisma: ReturnType<typeof createFakePrisma>;
  let invites: { verifyAndUseInvite: jest.Mock; linkInviteToUser: jest.Mock };
  let service: AuthService;

  beforeAll(async () => {
    const { publicKey, privateKey } = await generateKeyPair('RS256');
    signingKey = privateKey;
    const jwks = createLocalJWKSet({ keys: [{ ...(await exportJWK(publicKey)), kid: 'k', alg: 'RS256' }] });
    verifier = new OAuthTokenVerifier({ apple: jwks, google: jwks });
  });

  beforeEach(() => {
    delete process.env.APPLE_CLIENT_IDS;
    prisma = createFakePrisma();
    invites = { verifyAndUseInvite: jest.fn(), linkInviteToUser: jest.fn() };
    service = new AuthService(
      prisma as any,
      new JwtService({ secret: 'unit-test-only' }),
      invites as any,
      verifier,
    );
  });

  function appleToken(sub: string, email?: string) {
    const claims = email ? { email, email_verified: 'true' } : {};
    return new SignJWT(claims)
      .setProtectedHeader({ alg: 'RS256', kid: 'k' })
      .setIssuer(APPLE_ISS)
      .setAudience(BUNDLE_ID)
      .setSubject(sub)
      .setIssuedAt()
      .setExpirationTime('5m')
      .sign(signingKey);
  }

  describe('signup roles', () => {
    it('defaults to ARTIST', async () => {
      const res = await service.signup({ email: 'a@example.test', password: 'secret1' });
      expect(res.user.role).toBe('ARTIST');
    });

    it.each(['ARTIST', 'PRODUCER', 'ENGINEER'])('allows %s', async (role) => {
      const res = await service.signup({ email: `${role}@example.test`, password: 'secret1', role: role as any });
      expect(res.user.role).toBe(role);
    });

    it('refuses ADMIN and creates nobody', async () => {
      await expect(
        service.signup({ email: 'x@example.test', password: 'secret1', role: 'ADMIN' as any }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma.users).toHaveLength(0);
    });

    it('refuses JOURNALIST without an access code', async () => {
      await expect(
        service.signup({ email: 'j@example.test', password: 'secret1', role: 'JOURNALIST' as any }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('allows JOURNALIST with a valid access code', async () => {
      const res = await service.signup({
        email: 'j@example.test',
        password: 'secret1',
        role: 'JOURNALIST' as any,
        accessCode: 'CODE',
      });
      expect(res.user.role).toBe('JOURNALIST');
      expect(invites.verifyAndUseInvite).toHaveBeenCalled();
    });
  });

  describe('updateUserRole', () => {
    it.each(['ADMIN', 'JOURNALIST', 'NOT_A_ROLE'])('refuses %s', async (role) => {
      const { user } = await service.signup({ email: 'b@example.test', password: 'secret1' });
      await expect(service.updateUserRole(user.id, role)).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma.users[0].role).toBe('ARTIST');
    });

    it('allows switching to PRODUCER', async () => {
      const { user } = await service.signup({ email: 'b@example.test', password: 'secret1' });
      const res = await service.updateUserRole(user.id, 'PRODUCER');
      expect(res.user.role).toBe('PRODUCER');
    });
  });

  describe('Sign in with Apple', () => {
    it('rejects a junk token and creates nobody', async () => {
      await expect(
        service.signInWithApple({ identityToken: 'not-a-real-token', email: 'victim@example.test' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(prisma.users).toHaveLength(0);
    });

    it('cannot take over an existing account by sending its email', async () => {
      await service.signup({ email: 'victim@example.test', password: 'secret1' });
      const token = await appleToken('attacker-sub');
      const res = await service.signInWithApple({ identityToken: token, email: 'victim@example.test' });
      expect(res.user.email).not.toBe('victim@example.test');
      expect(res.user.id).not.toBe(prisma.users[0].id);
    });

    it('creates an account from the verified token, ignoring the body email', async () => {
      const token = await appleToken('sub-1', 'real@example.test');
      const res = await service.signInWithApple({ identityToken: token, email: 'other@example.test' });
      expect(res.isNewUser).toBe(true);
      expect(res.user.email).toBe('real@example.test');
      expect(prisma.users[0].appleSub).toBe('sub-1');
    });

    it('signs a returning user (no email in token) into the same account', async () => {
      const first = await service.signInWithApple({ identityToken: await appleToken('sub-1', 'real@example.test') });
      const again = await service.signInWithApple({ identityToken: await appleToken('sub-1') });
      expect(again.isNewUser).toBe(false);
      expect(again.user.id).toBe(first.user.id);
    });

    it('keeps two different Apple users apart even without emails', async () => {
      const one = await service.signInWithApple({ identityToken: await appleToken('sub-1') });
      const two = await service.signInWithApple({ identityToken: await appleToken('sub-2') });
      expect(one.user.id).not.toBe(two.user.id);
      const oneAgain = await service.signInWithApple({ identityToken: await appleToken('sub-1') });
      expect(oneAgain.user.id).toBe(one.user.id);
    });

    it('returns a conflict, and leaves the account alone, when the email already has an account', async () => {
      await service.signup({ email: 'Owner@Example.test', password: 'secret1', username: 'owner' });
      const before = { ...prisma.users[0] };
      await expect(
        service.signInWithApple({ identityToken: await appleToken('sub-9', 'owner@example.test') }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(prisma.users).toHaveLength(1);
      expect(prisma.users[0]).toEqual(before);
    });

    it('refuses ADMIN as the starting role', async () => {
      await expect(
        service.signInWithApple({ identityToken: await appleToken('sub-1'), role: 'ADMIN' as any }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma.users).toHaveLength(0);
    });

    it('accepts a self-service starting role', async () => {
      const res = await service.signInWithApple({ identityToken: await appleToken('sub-1'), role: 'PRODUCER' as any });
      expect(res.user.role).toBe('PRODUCER');
    });
  });
});
