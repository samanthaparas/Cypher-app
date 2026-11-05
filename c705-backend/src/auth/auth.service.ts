import { Injectable, UnauthorizedException, ConflictException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { SignupDto } from './dto/signup.dto';
import { LoginDto } from './dto/login.dto';
import { OAuthSignInDto } from './dto/oauth-signin.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { Role as RoleEnum } from '../../../c705_db/generated/prisma/enums';
import { JournalistInvitesService } from '../journalist-invites/journalist-invites.service';
import { OAuthTokenVerifier, VerifiedIdentity } from './oauth-token-verifier.service';
import { isSelfServiceRole } from './constants/self-service-roles';

type OAuthProvider = 'apple' | 'google';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private journalistInvitesService: JournalistInvitesService,
    private oauthTokenVerifier: OAuthTokenVerifier,
  ) {}

  async signup(signupDto: SignupDto): Promise<AuthResponseDto> {
    const { username, email, password, role, accessCode } = signupDto;

    // Check if user already exists by email
    const existingUserByEmail = await this.prisma.user.findUnique({
      where: { email },
    });

    if (existingUserByEmail) {
      throw new ConflictException('User with this email already exists');
    }

    // Check if username is taken (if provided)
    if (username) {
      const existingUserByUsername = await this.prisma.user.findUnique({
        where: { username },
      });

      if (existingUserByUsername) {
        throw new ConflictException('Username is already taken');
      }
    }

    // Role: ARTIST unless the person picks another self-service role. JOURNALIST needs a valid
    // invite code. ADMIN can never be chosen here; it is only granted by scripts/create-admin.ts.
    const userRole: RoleEnum = role ?? RoleEnum.ARTIST;

    if (userRole === RoleEnum.JOURNALIST) {
      if (!accessCode) {
        throw new ForbiddenException('Journalist accounts require a valid access code');
      }

      try {
        await this.journalistInvitesService.verifyAndUseInvite(
          { accessCode },
          email
        );
      } catch (error) {
        throw new ForbiddenException('Invalid or expired access code. Journalist accounts require a valid access code.');
      }
    } else if (!isSelfServiceRole(userRole)) {
      throw new ForbiddenException('This account type cannot be chosen at signup');
    }

    // Hash password - NEVER store raw passwords
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user in database
    const user = await this.prisma.user.create({
      data: {
        username: username || null,
        email,
        password: hashedPassword,
        role: userRole,
      },
    });

    // Link invite to user if journalist signup
    if (userRole === RoleEnum.JOURNALIST && accessCode) {
      try {
        await this.journalistInvitesService.linkInviteToUser(accessCode, user.id);
      } catch (error) {
        // Log error but don't fail signup - user is already created
        console.error('Failed to link invite to user:', error);
      }
    }

    // Generate JWT token
    const payload = { sub: user.id, email: user.email, role: user.role };
    const access_token = await this.jwtService.signAsync(payload);

    return {
      access_token,
      user: {
        id: user.id,
        username: user.username || null,
        email: user.email,
        role: user.role,
      },
    };
  }

  async login(loginDto: LoginDto): Promise<AuthResponseDto> {
    const { email, password } = loginDto;

    // Check if email exists
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Compare password
    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Generate JWT token
    const payload = { sub: user.id, email: user.email, role: user.role };
    const access_token = await this.jwtService.signAsync(payload);

    return {
      access_token,
      user: {
        id: user.id,
        username: user.username || null,
        email: user.email,
        role: user.role,
      },
      isNewUser: false, // Existing user from login
    };
  }

  async signInWithApple(oauthDto: OAuthSignInDto): Promise<AuthResponseDto> {
    // Check the token before anything else. Nothing the client sends is trusted until
    // Apple's signature, issuer, audience (our bundle ID) and expiry all check out.
    this.requireToken(oauthDto.identityToken);
    const identity = await this.oauthTokenVerifier.verifyApple(oauthDto.identityToken);
    return this.signInWithProvider('apple', identity, oauthDto);
  }

  async signInWithGoogle(oauthDto: OAuthSignInDto): Promise<AuthResponseDto> {
    this.requireToken(oauthDto.identityToken);
    const identity = await this.oauthTokenVerifier.verifyGoogle(oauthDto.identityToken);
    return this.signInWithProvider('google', identity, oauthDto);
  }

  private requireToken(identityToken: string | undefined) {
    if (!identityToken || identityToken.trim().length === 0) {
      throw new BadRequestException('Identity token is required');
    }
  }

  // Finds or creates the account for a verified Apple/Google identity.
  // The account is keyed on the provider's `sub`, which never changes for that person.
  // The email in the request body is ignored: only an email the provider verified is used.
  private async signInWithProvider(
    provider: OAuthProvider,
    identity: VerifiedIdentity,
    oauthDto: OAuthSignInDto,
  ): Promise<AuthResponseDto> {
    const subField = provider === 'apple' ? 'appleSub' : 'googleSub';

    // 1. Returning user: same provider account as before.
    const existing = await this.prisma.user.findUnique({
      where: provider === 'apple' ? { appleSub: identity.sub } : { googleSub: identity.sub },
    });
    if (existing) {
      return this.buildAuthResponse(existing, false);
    }

    // 2. New provider account. Pick a role only from the self-service list.
    const role = oauthDto.role ?? RoleEnum.ARTIST;
    if (!isSelfServiceRole(role)) {
      throw new ForbiddenException('This account type cannot be chosen at sign-in');
    }

    // 3. Never attach a provider sign-in to an account that already uses this email.
    //    Linking needs the person to prove they own that account first (planned later).
    //    Providers that hide or don't verify the email get a unique placeholder address.
    const email = identity.email ?? `${provider}.${identity.sub}@users.c705.invalid`;
    const emailTaken = await this.prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
      select: { id: true },
    });
    if (emailTaken) {
      throw new ConflictException(
        'An account with this email already exists. Sign in the way you did before.',
      );
    }

    const username = await this.suggestUsername(oauthDto.fullName);
    // OAuth accounts never log in with a password, but the column is required.
    // A random secret nobody knows keeps password login impossible for them.
    const unusablePassword = await bcrypt.hash(randomBytes(32).toString('hex'), 10);

    try {
      const user = await this.prisma.user.create({
        data: {
          username,
          email,
          password: unusablePassword,
          role,
          [subField]: identity.sub,
        },
      });
      return this.buildAuthResponse(user, true);
    } catch (error: any) {
      if (error?.code === 'P2002') {
        // Unique clash: the same sign-in raced itself, or the email was just taken.
        throw new ConflictException(
          'An account with this email already exists. Sign in the way you did before.',
        );
      }
      throw new BadRequestException('Failed to create user. Please try again.');
    }
  }

  // Builds "fullname-ab12c" style usernames; returns null if no free one is found quickly.
  private async suggestUsername(fullName?: string): Promise<string | null> {
    const base = fullName?.replace(/\s/g, '').toLowerCase();
    if (!base) return null;
    for (let attempt = 0; attempt < 5; attempt++) {
      const candidate = `${base}-${Math.random().toString(36).substring(2, 7)}`;
      const taken = await this.prisma.user.findUnique({ where: { username: candidate } });
      if (!taken) return candidate;
    }
    return null;
  }

  private async buildAuthResponse(
    user: { id: string; email: string; role: RoleEnum; username: string | null },
    isNewUser: boolean,
  ): Promise<AuthResponseDto> {
    const payload = { sub: user.id, email: user.email, role: user.role, username: user.username };
    const access_token = await this.jwtService.signAsync(payload);
    return {
      access_token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
      isNewUser,
    };
  }

  async updateUserRole(userId: string, newRole: string): Promise<AuthResponseDto> {
    // Only self-service roles can be picked here. ADMIN and JOURNALIST are granted elsewhere.
    if (!isSelfServiceRole(newRole)) {
      throw new ForbiddenException('This account type cannot be chosen');
    }

    // Update user role
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { role: newRole as RoleEnum },
    });

    // Generate new JWT token with updated role
    const payload = { sub: user.id, email: user.email, role: user.role, username: user.username };
    const access_token = await this.jwtService.signAsync(payload);

    return {
      access_token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
      isNewUser: false,
    };
  }

  async updateUsername(userId: string, newUsername: string): Promise<AuthResponseDto> {
    const trimmed = newUsername?.trim();
    if (!trimmed || trimmed.length < 2) {
      throw new BadRequestException('Username must be at least 2 characters');
    }
    const existing = await this.prisma.user.findUnique({
      where: { username: trimmed },
    });
    if (existing && existing.id !== userId) {
      throw new ConflictException('Username is already taken');
    }
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { username: trimmed },
    });
    const payload = { sub: user.id, email: user.email, role: user.role, username: user.username };
    const access_token = await this.jwtService.signAsync(payload);
    return {
      access_token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
      isNewUser: false,
    };
  }

  async deleteAccount(userId: string): Promise<{ message: string }> {
    await this.prisma.$transaction(async (tx) => {
      // 1. Remember which entries this user voted on. Their votes will
      //    cascade away when the user is deleted, but each entry stores
      //    a precomputed averageScore and voteCount that would go stale.
      const votedEntries = await tx.cypherVote.findMany({
        where: { userId },
        select: { entryId: true },
      });
      const entryIds = votedEntries.map((vote) => vote.entryId);

      // 2. Delete the records that do NOT cascade from User.
      //    Tracks point at ArtistProfile, so they go first.
      const artistProfile = await tx.artistProfile.findUnique({
        where: { userId },
        select: { id: true },
      });
      if (artistProfile) {
        await tx.track.deleteMany({ where: { artistId: artistProfile.id } });
        await tx.artistProfile.delete({ where: { id: artistProfile.id } });
      }
      await tx.engineerProfile.deleteMany({ where: { userId } });

      // 3. Delete the user. Comments, follows, entries, votes, reports,
      //    beats, hosted cyphers and the rest cascade automatically.
      await tx.user.delete({ where: { id: userId } });

      // 4. Recompute the stored score for each entry that lost a vote.
      //    updateMany is used so an entry already removed by a cascade
      //    (for example, in a cypher this user hosted) is skipped quietly.
      for (const entryId of entryIds) {
        const votes = await tx.cypherVote.findMany({
          where: { entryId },
          select: { score: true },
        });
        const totalScore = votes.reduce((sum, vote) => sum + vote.score, 0);
        const averageScore = votes.length > 0 ? totalScore / votes.length : 0;

        await tx.cypherEntry.updateMany({
          where: { id: entryId },
          data: { averageScore, voteCount: votes.length },
        });
      }
    });

    return { message: 'Account deleted' };
  }
}
