import { Injectable, ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateJournalistInviteDto } from './dto/create-invite.dto';
import { VerifyJournalistInviteDto } from './dto/verify-invite.dto';
import { Role as RoleEnum } from '../../../c705_db/generated/prisma/enums';
import * as crypto from 'crypto';

@Injectable()
export class JournalistInvitesService {
  constructor(private prisma: PrismaService) {}

  /**
   * Generate a secure random access code
   */
  private generateAccessCode(): string {
    // Generate a 12-character alphanumeric code
    return crypto.randomBytes(6).toString('hex').toUpperCase();
  }

  /**
   * Create a journalist invite code (Admin only)
   */
  async createInvite(adminId: string, createDto: CreateJournalistInviteDto) {
    // Verify admin has permission
    const admin = await this.prisma.user.findUnique({
      where: { id: adminId },
    });

    if (!admin || admin.role !== RoleEnum.ADMIN) {
      throw new ForbiddenException('Only admins can create journalist invite codes');
    }

    // Generate unique access code
    let accessCode: string;
    let isUnique = false;
    let attempts = 0;

    while (!isUnique && attempts < 10) {
      accessCode = this.generateAccessCode();
      const existing = await this.prisma.journalistInvite.findUnique({
        where: { accessCode },
      });
      if (!existing) {
        isUnique = true;
      }
      attempts++;
    }

    if (!isUnique) {
      throw new BadRequestException('Failed to generate unique access code. Please try again.');
    }

    // Parse expiration date if provided
    let expiresAt: Date | null = null;
    if (createDto.expiresAt) {
      expiresAt = new Date(createDto.expiresAt);
      if (isNaN(expiresAt.getTime())) {
        throw new BadRequestException('Invalid expiration date format');
      }
    }

    // Create invite
    const invite = await this.prisma.journalistInvite.create({
      data: {
        email: createDto.email || null,
        accessCode: accessCode!,
        expiresAt,
        createdBy: adminId,
      },
    });

    return {
      id: invite.id,
      accessCode: invite.accessCode,
      email: invite.email,
      expiresAt: invite.expiresAt,
      createdAt: invite.createdAt,
    };
  }

  /**
   * Verify and use an invite code
   * Returns true if valid, throws error if invalid
   */
  async verifyAndUseInvite(verifyDto: VerifyJournalistInviteDto, userEmail?: string): Promise<boolean> {
    const { accessCode } = verifyDto;

    // Find the invite
    const invite = await this.prisma.journalistInvite.findUnique({
      where: { accessCode },
    });

    if (!invite) {
      throw new NotFoundException('Invalid access code');
    }

    // Check if already used
    if (invite.used) {
      throw new BadRequestException('This access code has already been used');
    }

    // Check if expired
    if (invite.expiresAt && new Date() > new Date(invite.expiresAt)) {
      throw new BadRequestException('This access code has expired');
    }

    // If email is specified, verify it matches
    if (invite.email && userEmail && invite.email.toLowerCase() !== userEmail.toLowerCase()) {
      throw new BadRequestException('This access code is not valid for this email address');
    }

    // Mark as used (but don't set usedBy yet - that happens during signup)
    await this.prisma.journalistInvite.update({
      where: { id: invite.id },
      data: {
        used: true,
        usedAt: new Date(),
      },
    });

    return true;
  }

  /**
   * Link invite to user after signup
   */
  async linkInviteToUser(accessCode: string, userId: string) {
    await this.prisma.journalistInvite.updateMany({
      where: {
        accessCode,
        used: true,
      },
      data: {
        usedBy: userId,
      },
    });
  }

  /**
   * Get all invites (Admin only)
   */
  async getAllInvites(adminId: string) {
    // Verify admin
    const admin = await this.prisma.user.findUnique({
      where: { id: adminId },
    });

    if (!admin || admin.role !== RoleEnum.ADMIN) {
      throw new ForbiddenException('Only admins can view invite codes');
    }

    const invites = await this.prisma.journalistInvite.findMany({
      orderBy: { createdAt: 'desc' },
    });

    return invites;
  }

  /**
   * Get unused invites (Admin only)
   */
  async getUnusedInvites(adminId: string) {
    // Verify admin
    const admin = await this.prisma.user.findUnique({
      where: { id: adminId },
    });

    if (!admin || admin.role !== RoleEnum.ADMIN) {
      throw new ForbiddenException('Only admins can view invite codes');
    }

    const invites = await this.prisma.journalistInvite.findMany({
      where: {
        used: false,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });

    return invites;
  }
}
