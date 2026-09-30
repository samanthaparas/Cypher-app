import { Controller, Get, Post, Delete, Param, Body, UseGuards, Query } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Role } from '../../../c705_db/generated/prisma/enums';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /**
   * Get dashboard overview statistics
   */
  @Get('dashboard')
  async getDashboard(@CurrentUser() user: any) {
    return this.adminService.getDashboardStats();
  }

  /**
   * Get all users with pagination
   */
  @Get('users')
  async getUsers(
    @CurrentUser() user: any,
  ) {
    return this.adminService.getAllUsers();
  }

  /**
   * Get all journalists
   */
  @Get('journalists')
  async getJournalists(@CurrentUser() user: any) {
    return this.adminService.getJournalists();
  }

  /**
   * Get admin user info
   */
  @Get('me')
  async getAdminInfo(@CurrentUser() user: any) {
    return {
      id: user.id,
      email: user.email,
      role: user.role,
    };
  }

  /**
   * Get pending reports
   */
  @Get('reports')
  async getReports(@CurrentUser() user: any) {
    return this.adminService.getPendingReports();
  }

  /**
   * Resolve a report
   */
  @Post('reports/:id/resolve')
  async resolveReport(
    @Param('id') reportId: string,
    @Body() body: { action: 'dismiss' | 'resolve' },
    @CurrentUser() user: any,
  ) {
    return this.adminService.resolveReport(reportId, body.action);
  }

  /**
   * Delete a cypher
   */
  @Delete('cyphers/:id')
  async deleteCypher(
    @Param('id') cypherId: string,
    @CurrentUser() user: any,
  ) {
    return this.adminService.deleteCypher(cypherId);
  }

  /**
   * Unpublish an article
   */
  @Delete('articles/:id')
  async unpublishArticle(
    @Param('id') articleId: string,
    @CurrentUser() user: any,
  ) {
    return this.adminService.unpublishArticle(articleId);
  }

  /**
   * Get recent cyphers
   */
  @Get('recent-cyphers')
  async getRecentCyphers(
    @CurrentUser() user: any,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getRecentCyphers(limit ? parseInt(limit) : 4);
  }

  /**
   * Get upcoming events
   */
  @Get('events')
  async getEvents(
    @CurrentUser() user: any,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getUpcomingEvents(limit ? parseInt(limit) : 6);
  }
}
