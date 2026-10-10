import { Injectable, UnauthorizedException, ConflictException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { SignupDto } from './dto/signup.dto';
import { LoginDto } from './dto/login.dto';
import { OAuthSignInDto } from './dto/oauth-signin.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { Role as RoleEnum } from '../../../c705_db/generated/prisma/enums';
import { JournalistInvitesService } from '../journalist-invites/journalist-invites.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private journalistInvitesService: JournalistInvitesService,
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

    // Validate and set role (default to ARTIST if not provided)
    let userRole = role && Object.values(RoleEnum).includes(role as RoleEnum) 
      ? (role as RoleEnum) 
      : RoleEnum.ARTIST;

    // SECURITY: Journalist role requires access code
    if (userRole === RoleEnum.JOURNALIST) {
      if (!accessCode) {
        throw new ForbiddenException('Journalist accounts require a valid access code');
      }

      // Verify the access code
      try {
        await this.journalistInvitesService.verifyAndUseInvite(
          { accessCode },
          email
        );
      } catch (error) {
        throw new ForbiddenException('Invalid or expired access code. Journalist accounts require a valid access code.');
      }
    } else {
      // If trying to sign up as journalist without access code, block it
      if (role === RoleEnum.JOURNALIST && !accessCode) {
        throw new ForbiddenException('Journalist accounts require a valid access code');
      }

      // If access code is provided but role is not journalist, ignore the code
      // (This allows flexibility for future use cases)
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

  async signInWithOAuth(oauthDto: OAuthSignInDto): Promise<AuthResponseDto> {
    const { provider, identityToken, email, fullName, role } = oauthDto;

    // Log incoming request for debugging
    console.log('🔐 OAuth Sign In Request:', {
      provider,
      hasEmail: !!email,
      hasFullName: !!fullName,
      role: role || 'ARTIST',
      tokenLength: identityToken?.length || 0
    });

    // Validate provider
    if (provider !== 'apple' && provider !== 'google') {
      console.error('❌ Invalid OAuth provider:', provider);
      throw new BadRequestException('Invalid OAuth provider. Must be "apple" or "google"');
    }

    // Validate identity token
    if (!identityToken || identityToken.trim().length === 0) {
      console.error('❌ Missing or empty identity token');
      throw new BadRequestException('Identity token is required');
    }

    // For OAuth sign-in, don't require role - allow user to select later
    // Only use provided role if it's valid, otherwise default to ARTIST (can be changed later)
    const userRole = role && Object.values(RoleEnum).includes(role as RoleEnum)
      ? (role as RoleEnum)
      : RoleEnum.ARTIST; // Default to ARTIST, but user can change it

    // For OAuth, we need to verify the token and extract user info
    // In a production app, you would verify the identity token with Apple/Google
    // For now, we'll use the email from the token to find or create the user
    
    // Generate a secure password for OAuth users (they won't use it, but we need it in the DB)
    // In production, you might want to make password optional for OAuth users
    const oauthPassword = await bcrypt.hash(identityToken + Date.now(), 10);

    // Determine user email - handle Apple Sign In where email may not be provided
    let userEmail = email;
    
    if (!userEmail) {
      // For Apple Sign In, email may not be provided on subsequent sign-ins
      // Generate a placeholder email based on the identity token
      // In production, you should decode the JWT to get the user ID (sub claim)
      // and use that to identify users consistently
      const tokenPrefix = identityToken.substring(0, 20).replace(/[^a-zA-Z0-9]/g, '');
      userEmail = `${provider}_${tokenPrefix}@${provider}-signin.local`;
    }

    // Try to find existing user by email
    let user: any;
    try {
      user = await this.prisma.user.findUnique({
        where: { email: userEmail },
      });
      console.log('🔍 User lookup result:', user ? 'User found' : 'New user');
    } catch (error) {
      console.error('❌ Database error during user lookup:', error);
      throw new BadRequestException('Database error. Please try again.');
    }

    if (user) {
      // User exists (either from previous OAuth signup or email/password signup)
      // Allow them to sign in - this handles both signup and signin scenarios
      console.log('✅ Existing user found, generating token');
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
        isNewUser: false, // Existing user
      };
    }

    // User doesn't exist - create new account (signup scenario)
    // Generate a unique username if fullName is available, otherwise leave null
    let userUsername: string | null = null;
    if (fullName) {
      const baseUsername = fullName.replace(/\s/g, '').toLowerCase();
      userUsername = baseUsername + '-' + Math.random().toString(36).substring(2, 7);
      
      // Check if username already exists and generate a new one if needed
      let attempts = 0;
      while (attempts < 5) {
        const existingUsername = await this.prisma.user.findUnique({ 
          where: { username: userUsername } 
        });
        if (!existingUsername) {
          break; // Username is available
        }
        userUsername = baseUsername + '-' + Math.random().toString(36).substring(2, 7);
        attempts++;
      }
      
      // If we couldn't generate a unique username after 5 attempts, set to null
      if (attempts >= 5) {
        userUsername = null;
      }
    }

    // Create new user with OAuth credentials
    try {
      console.log('📝 Creating new user with email:', userEmail);
      user = await this.prisma.user.create({
        data: {
          username: userUsername,
          email: userEmail,
          password: oauthPassword, // OAuth users have a generated password
          role: userRole,
        },
      });
      console.log('✅ New user created:', user.id);
    } catch (error: any) {
      console.error('❌ Database error during user creation:', error);
      if (error.code === 'P2002') {
        // Unique constraint violation
        throw new ConflictException('User with this email already exists');
      }
      throw new BadRequestException('Failed to create user. Please try again.');
    }

    // Generate JWT token
    try {
      const payload = { sub: user.id, email: user.email, role: user.role, username: user.username };
      const access_token = await this.jwtService.signAsync(payload);
      console.log('✅ JWT token generated successfully');

      return {
        access_token,
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          role: user.role,
        },
        isNewUser: true, // New user created - they may want to select account type
      };
    } catch (error) {
      console.error('❌ Error generating JWT token:', error);
      throw new BadRequestException('Failed to generate authentication token. Please try again.');
    }
  }

  async updateUserRole(userId: string, newRole: string): Promise<AuthResponseDto> {
    // Validate role
    if (!Object.values(RoleEnum).includes(newRole as RoleEnum)) {
      throw new BadRequestException(`Invalid role. Must be one of: ${Object.values(RoleEnum).join(', ')}`);
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
