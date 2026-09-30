import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { S3Service } from '../s3/s3.service';
import { CreateCypherDto, CypherType } from './dto/create-cypher.dto';
import { VoteEntryDto } from './dto/vote-entry.dto';
import { ReportEntryDto } from './dto/report-entry.dto';
import { InviteArtistDto, RespondToInviteDto } from './dto/invite-artist.dto';

@Injectable()
export class CyphersService {
  constructor(
    private prisma: PrismaService,
    private s3Service: S3Service,
  ) {}

  /**
   * Get all active cyphers
   */
  async getActiveCyphers(page: number = 1, limit: number = 20) {
    const skip = (page - 1) * limit;
    
    const [cyphers, total] = await Promise.all([
      this.prisma.cypher.findMany({
        where: {
          isActive: true,
          OR: [
            { endDate: null },
            { endDate: { gte: new Date() } },
          ],
        },
        orderBy: { startDate: 'desc' },
        skip,
        take: limit,
        include: {
          _count: {
            select: { entries: true },
          },
        },
      }),
      this.prisma.cypher.count({
        where: {
          isActive: true,
          OR: [
            { endDate: null },
            { endDate: { gte: new Date() } },
          ],
        },
      }),
    ]);

    return {
      cyphers,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Search cyphers by title or description
   */
  async searchCyphers(query: string, limit: number = 20) {
    const cyphers = await this.prisma.cypher.findMany({
      where: {
        isActive: true,
        OR: [
          { title: { contains: query, mode: 'insensitive' } },
          { description: { contains: query, mode: 'insensitive' } },
        ],
      },
      take: limit,
      orderBy: { startDate: 'desc' },
      include: {
        host: {
          select: {
            id: true,
            username: true,
            email: true,
          },
        },
        _count: {
          select: { entries: true },
        },
      },
    });

    return cyphers;
  }

  /**
   * Get cypher by ID with entries
   */
  async getCypherById(cypherId: string, userId?: string) {
    const cypher = await this.prisma.cypher.findUnique({
      where: { id: cypherId },
      include: {
        entries: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                email: true,
              },
            },
            _count: {
              select: { votes: true },
            },
          },
          orderBy: { averageScore: 'desc' },
        },
      },
    });

    if (!cypher) {
      throw new NotFoundException('Cypher not found');
    }

    // Check if user has already submitted
    const userEntry = userId
      ? await this.prisma.cypherEntry.findUnique({
          where: {
            cypherId_userId: {
              cypherId,
              userId,
            },
          },
        })
      : null;

    return {
      ...cypher,
      userEntry,
    };
  }

  /**
   * Create a new cypher (All users can create)
   */
  async createCypher(createDto: CreateCypherDto, userId: string) {
    return this.prisma.cypher.create({
      data: {
        title: createDto.title,
        description: createDto.description,
        beatUrl: createDto.beatUrl,
        cypherType: createDto.cypherType,
        startDate: new Date(createDto.startDate),
        endDate: createDto.endDate ? new Date(createDto.endDate) : null,
        hostArtistId: userId, // Set the creator as the host
        visibility: 'INVITE_ONLY', // Set to INVITE_ONLY for created cyphers
      },
    });
  }

  /**
   * Submit entry to cypher
   * Rules: One submission per user per cypher, cypher must be active
   */
  async submitEntry(
    cypherId: string,
    userId: string,
    file: Express.Multer.File,
    title?: string,
  ) {
    // Check if cypher exists and is active
    const cypher = await this.prisma.cypher.findUnique({
      where: { id: cypherId },
    });

    if (!cypher) {
      throw new NotFoundException('Cypher not found');
    }

    if (!cypher.isActive) {
      throw new BadRequestException('Cypher is not active');
    }

    // Check if cypher has ended
    if (cypher.endDate && new Date() > cypher.endDate) {
      throw new BadRequestException('Cypher has ended');
    }

    // Check if user already submitted
    const existingEntry = await this.prisma.cypherEntry.findUnique({
      where: {
        cypherId_userId: {
          cypherId,
          userId,
        },
      },
    });

    if (existingEntry) {
      throw new BadRequestException('You have already submitted an entry to this cypher');
    }

    // Validate audio file
    if (!file) {
      throw new BadRequestException('No audio file provided');
    }

    const allowedMimeTypes = [
      'audio/mpeg',
      'audio/mp3',
      'audio/wav',
      'audio/wave',
      'audio/x-wav',
      'audio/mp4',
      'audio/m4a',
      'audio/aac',
    ];

    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new BadRequestException(`Invalid file type. Allowed types: ${allowedMimeTypes.join(', ')}`);
    }

    // Upload to S3
    const fileExtension = file.originalname.split('.').pop() || 'm4a';
    const s3Key = this.s3Service.generateKey(userId, `cypher-${cypherId}-${Date.now()}.${fileExtension}`, 'cyphers');
    const audioUrl = await this.s3Service.uploadPublicFile(file.buffer, s3Key, file.mimetype);

    // Create entry
    return this.prisma.cypherEntry.create({
      data: {
        cypherId,
        userId,
        audioUrl,
        title: title || null,
      },
    });
  }

  /**
   * Get entries for a cypher
   */
  async getCypherEntries(cypherId: string, page: number = 1, limit: number = 20) {
    const skip = (page - 1) * limit;

    const [entries, total] = await Promise.all([
      this.prisma.cypherEntry.findMany({
        where: { cypherId },
        include: {
          user: {
            select: {
              id: true,
              username: true,
              email: true,
            },
          },
          _count: {
            select: { votes: true },
          },
        },
        orderBy: { averageScore: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.cypherEntry.count({
        where: { cypherId },
      }),
    ]);

    return {
      entries,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Vote on a cypher entry
   * Rules: One vote per user per entry, no self-voting
   * Score calculation: (bars + flow + creativity) / 3
   */
  async voteEntry(entryId: string, userId: string, voteDto: VoteEntryDto) {
    // Check if entry exists
    const entry = await this.prisma.cypherEntry.findUnique({
      where: { id: entryId },
      include: { user: true },
    });

    if (!entry) {
      throw new NotFoundException('Entry not found');
    }

    // Check if user is voting on their own entry
    if (entry.userId === userId) {
      throw new ForbiddenException('You cannot vote on your own entry');
    }

    // Calculate final score: (bars + flow + creativity) / 3
    const finalScore = (voteDto.bars + voteDto.flow + voteDto.creativity) / 3;

    // Check if user already voted
    const existingVote = await this.prisma.cypherVote.findUnique({
      where: {
        entryId_userId: {
          entryId,
          userId,
        },
      },
    });

    if (existingVote) {
      // Update existing vote
      await this.prisma.cypherVote.update({
        where: { id: existingVote.id },
        data: { score: finalScore },
      });
    } else {
      // Create new vote
      await this.prisma.cypherVote.create({
        data: {
          entryId,
          userId,
          score: finalScore,
        },
      });
    }

    // Recalculate average score from all votes
    const votes = await this.prisma.cypherVote.findMany({
      where: { entryId },
      select: { score: true },
    });

    const totalScore = votes.reduce((sum, vote) => sum + vote.score, 0);
    const averageScore = votes.length > 0 ? totalScore / votes.length : 0;

    // Update entry with new average score
    await this.prisma.cypherEntry.update({
      where: { id: entryId },
      data: {
        averageScore,
        voteCount: votes.length,
      },
    });

    return {
      message: 'Vote recorded successfully',
      averageScore,
      voteCount: votes.length,
    };
  }

  /**
   * Report a cypher entry
   */
  async reportEntry(entryId: string, userId: string, reportDto: ReportEntryDto) {
    const entry = await this.prisma.cypherEntry.findUnique({
      where: { id: entryId },
    });

    if (!entry) {
      throw new NotFoundException('Entry not found');
    }

    return this.prisma.cypherReport.create({
      data: {
        entryId,
        userId,
        reason: reportDto.reason,
      },
    });
  }

  /**
   * Get leaderboard for a cypher
   */
  async getLeaderboard(cypherId: string, limit: number = 50) {
    const entries = await this.prisma.cypherEntry.findMany({
      where: { cypherId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            email: true,
          },
        },
      },
      orderBy: [
        { averageScore: 'desc' },
        { voteCount: 'desc' },
        { createdAt: 'asc' },
      ],
      take: limit,
    });

    return entries.map((entry, index) => ({
      rank: index + 1,
      entry: {
        id: entry.id,
        title: entry.title,
        audioUrl: entry.audioUrl,
        averageScore: entry.averageScore,
        voteCount: entry.voteCount,
        createdAt: entry.createdAt,
        user: entry.user,
      },
    }));
  }

  /**
   * Invite a user to a cypher
   * Rules: Any user can invite any other user, cannot invite same user twice, cannot invite after closed
   */
  async inviteArtist(cypherId: string, inviterId: string, inviteDto: InviteArtistDto) {
    const cypher = await this.prisma.cypher.findUnique({
      where: { id: cypherId },
    });

    if (!cypher) {
      throw new NotFoundException('Cypher not found');
    }

    // Check if cypher is closed
    if (cypher.status === 'CLOSED') {
      throw new BadRequestException('Cannot invite to a closed cypher');
    }

    // Check if trying to invite self
    if (inviterId === inviteDto.artistId) {
      throw new BadRequestException('You cannot invite yourself');
    }

    // Check if invited user exists
    const invitedUser = await this.prisma.user.findUnique({
      where: { id: inviteDto.artistId },
    });

    if (!invitedUser) {
      throw new NotFoundException('User to invite not found');
    }

    // Check if already invited
    const existingInvite = await this.prisma.cypherInvite.findUnique({
      where: {
        cypherId_invitedArtistId: {
          cypherId,
          invitedArtistId: inviteDto.artistId,
        },
      },
    });

    if (existingInvite) {
      throw new BadRequestException('User has already been invited');
    }

    // Create invite
    return this.prisma.cypherInvite.create({
      data: {
        cypherId,
        invitedArtistId: inviteDto.artistId,
        invitedByArtistId: inviterId,
        status: 'pending',
      },
      include: {
        invitedArtist: {
          select: {
            id: true,
            username: true,
            email: true,
          },
        },
        cypher: {
          select: {
            id: true,
            title: true,
          },
        },
      },
    });
  }

  /**
   * Get user's cypher invites
   */
  async getUserInvites(userId: string) {
    return this.prisma.cypherInvite.findMany({
      where: {
        invitedArtistId: userId,
        status: 'pending',
      },
      include: {
        cypher: {
          include: {
            host: {
              select: {
                id: true,
                username: true,
                email: true,
              },
            },
            _count: {
              select: { entries: true },
            },
          },
        },
        invitedBy: {
          select: {
            id: true,
            username: true,
            email: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Respond to a cypher invite (accept or decline)
   */
  async respondToInvite(inviteId: string, userId: string, respondDto: RespondToInviteDto) {
    const invite = await this.prisma.cypherInvite.findUnique({
      where: { id: inviteId },
      include: { cypher: true },
    });

    if (!invite) {
      throw new NotFoundException('Invite not found');
    }

    // Check if user is the invited artist
    if (invite.invitedArtistId !== userId) {
      throw new ForbiddenException('You can only respond to your own invites');
    }

    // Check if already responded
    if (invite.status !== 'pending') {
      throw new BadRequestException('Invite has already been responded to');
    }

    // Update invite status
    const updatedInvite = await this.prisma.cypherInvite.update({
      where: { id: inviteId },
      data: {
        status: respondDto.response,
        respondedAt: new Date(),
      },
    });

    return updatedInvite;
  }

  /**
   * Get top cyphers based on scoring algorithm
   * Score = (entries × 3) + (votes × 1) + (unique artists × 2)
   * Range: trending (24-48h), week, all-time
   */
  async getTopCyphers(range: 'trending' | 'week' | 'all-time' = 'week', limit: number = 20) {
    // Calculate date range
    let startDate: Date | null = null;
    if (range === 'trending') {
      startDate = new Date(Date.now() - 48 * 60 * 60 * 1000); // Last 48 hours
    } else if (range === 'week') {
      startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000); // Last week
    }

    // Build where clause
    const where: any = {
      isActive: true,
      visibility: 'PUBLIC', // Only show public cyphers in top list
    };

    if (startDate) {
      where.createdAt = { gte: startDate };
    }

    // Get all cyphers matching criteria
    const cyphers = await this.prisma.cypher.findMany({
      where,
      include: {
        host: {
          select: {
            id: true,
            username: true,
            email: true,
          },
        },
        entries: {
          include: {
            _count: {
              select: { votes: true },
            },
          },
        },
        _count: {
          select: { entries: true },
        },
      },
    });

    // Calculate scores for each cypher
    const scoredCyphers = cyphers.map((cypher) => {
      const entryCount = cypher._count.entries;
      const totalVotes = cypher.entries.reduce((sum, entry) => sum + entry._count.votes, 0);
      const uniqueArtists = new Set(cypher.entries.map((e) => e.userId)).size;

      // Score formula: (entries × 3) + (votes × 1) + (unique artists × 2)
      const score = entryCount * 3 + totalVotes * 1 + uniqueArtists * 2;

      return {
        id: cypher.id,
        title: cypher.title,
        description: cypher.description,
        beatUrl: cypher.beatUrl,
        host: cypher.host,
        entryCount,
        voteCount: totalVotes,
        uniqueArtists,
        score,
        createdAt: cypher.createdAt,
        startDate: cypher.startDate,
        endDate: cypher.endDate,
      };
    });

    // Sort by score (descending) and return top results
    return scoredCyphers
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }
}

