import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role as RoleEnum } from '../../../c705_db/generated/prisma/enums';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  /**
   * Get dashboard statistics
   */
  async getDashboardStats() {
    const [
      totalUsers,
      artists,
      journalists,
      producers,
      totalArticles,
      totalCyphers,
      activeCyphers,
      totalBeats,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { role: RoleEnum.ARTIST } }),
      this.prisma.user.count({ where: { role: RoleEnum.JOURNALIST } }),
      this.prisma.user.count({ where: { role: RoleEnum.PRODUCER } }),
      this.prisma.article.count(),
      this.prisma.cypher.count(),
      this.prisma.cypher.count({ where: { isActive: true } }),
      this.prisma.beat.count(),
    ]);

    // Get trending cyphers (top 5 by vote count)
    const trendingCyphers = await this.prisma.cypher.findMany({
      where: { isActive: true },
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: {
        entries: {
          select: {
            voteCount: true,
          },
        },
      },
    });

    return {
      stats: {
        totalUsers,
        artists,
        journalists,
        producers,
        totalArticles,
        totalCyphers,
        activeCyphers,
        totalBeats,
      },
      trendingCyphers: trendingCyphers.map((cypher) => ({
        id: cypher.id,
        title: cypher.title,
        entryCount: cypher.entries.length,
        createdAt: cypher.createdAt,
      })),
    };
  }

  /**
   * Get all users
   */
  async getAllUsers() {
    const users = await this.prisma.user.findMany({
      select: {
        id: true,
        email: true,
        username: true,
        role: true,
        createdAt: true,
        _count: {
          select: {
            articles: true,
            cypherEntries: true,
            beats: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return users;
  }

  /**
   * Get all journalists
   */
  async getJournalists() {
    const journalists = await this.prisma.user.findMany({
      where: { role: RoleEnum.JOURNALIST },
      select: {
        id: true,
        email: true,
        username: true,
        createdAt: true,
        _count: {
          select: {
            articles: true,
          },
        },
        articles: {
          take: 5,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            title: true,
            city: true,
            createdAt: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return journalists;
  }

  /**
   * Get pending reports
   */
  async getPendingReports() {
    const reports = await this.prisma.cypherReport.findMany({
      where: { status: 'pending' },
      include: {
        entry: {
          include: {
            user: {
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
        },
        cypher: {
          select: {
            id: true,
            title: true,
          },
        },
        user: {
          select: {
            id: true,
            username: true,
            email: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    return reports;
  }

  /**
   * Resolve a report
   */
  async resolveReport(reportId: string, action: 'dismiss' | 'resolve') {
    const report = await this.prisma.cypherReport.findUnique({
      where: { id: reportId },
    });

    if (!report) {
      throw new NotFoundException('Report not found');
    }

    return this.prisma.cypherReport.update({
      where: { id: reportId },
      data: {
        status: action === 'dismiss' ? 'reviewed' : 'resolved',
      },
    });
  }

  /**
   * Delete a cypher
   */
  async deleteCypher(cypherId: string) {
    const cypher = await this.prisma.cypher.findUnique({
      where: { id: cypherId },
    });

    if (!cypher) {
      throw new NotFoundException('Cypher not found');
    }

    await this.prisma.cypher.delete({
      where: { id: cypherId },
    });

    return { success: true };
  }

  /**
   * Unpublish an article
   */
  async unpublishArticle(articleId: string) {
    const article = await this.prisma.article.findUnique({
      where: { id: articleId },
    });

    if (!article) {
      throw new NotFoundException('Article not found');
    }

    // For now, we'll delete the article. You might want to add a published field instead
    await this.prisma.article.delete({
      where: { id: articleId },
    });

    return { success: true };
  }

  /**
   * Get recent cyphers with details
   */
  async getRecentCyphers(limit: number = 4) {
    const cyphers = await this.prisma.cypher.findMany({
      where: { isActive: true },
      take: limit,
      orderBy: { createdAt: 'desc' },
      include: {
        host: {
          select: {
            id: true,
            username: true,
            email: true,
          },
        },
        _count: {
          select: {
            entries: true,
          },
        },
        entries: {
          select: {
            voteCount: true,
          },
        },
      },
    });

    return cyphers.map((cypher) => ({
      id: cypher.id,
      title: cypher.title,
      description: cypher.description,
      artist: cypher.host.username || cypher.host.email,
      beatType: 'Trap Beat', // You might want to add this to the schema
      entryCount: cypher._count.entries,
      playCount: cypher.entries.reduce((sum, e) => sum + (e.voteCount || 0), 0),
      createdAt: cypher.createdAt,
    }));
  }

  /**
   * Get upcoming events (cyphers with future dates)
   */
  async getUpcomingEvents(limit: number = 6) {
    const events = await this.prisma.cypher.findMany({
      where: {
        isActive: true,
        startDate: { gte: new Date() },
      },
      take: limit,
      orderBy: { startDate: 'asc' },
      include: {
        host: {
          select: {
            username: true,
          },
        },
      },
    });

    return events;
  }
}
