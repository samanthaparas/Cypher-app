import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  ParseIntPipe,
  DefaultValuePipe,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CyphersService } from './cyphers.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { CreateCypherDto } from './dto/create-cypher.dto';
import { SubmitEntryDto } from './dto/submit-entry.dto';
import { VoteEntryDto } from './dto/vote-entry.dto';
import { ReportEntryDto } from './dto/report-entry.dto';
import { InviteArtistDto, RespondToInviteDto } from './dto/invite-artist.dto';

@Controller('cyphers')
export class CyphersController {
  constructor(private readonly cyphersService: CyphersService) {}

  /**
   * GET /cyphers - Get all active cyphers (GUEST ACCESS - No auth required)
   */
  @Get()
  async getActiveCyphers(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.cyphersService.getActiveCyphers(page, limit);
  }

  // Keep fixed paths (top, search) above ':id' — Nest matches routes in order,
  // so ':id' would otherwise catch "top" and "search" and return 404.

  /**
   * GET /cyphers/top - Get top cyphers based on engagement score (GUEST ACCESS - No auth required)
   */
  @Get('top')
  async getTopCyphers(
    @Query('range', new DefaultValuePipe('week')) range: 'trending' | 'week' | 'all-time',
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.cyphersService.getTopCyphers(range, limit);
  }

  /**
   * GET /cyphers/search - Search cyphers by title or description (GUEST ACCESS)
   */
  @Get('search')
  async searchCyphers(
    @Query('q') query: string,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    if (!query || query.trim().length < 2) {
      return { cyphers: [] };
    }
    return { cyphers: await this.cyphersService.searchCyphers(query.trim(), limit) };
  }

  /**
   * GET /cyphers/:id -Get cypher details with entries (GUEST ACCESS - No auth required)
   */
  @Get(':id')
  async getCypherById(
    @Param('id') id: string,
    @CurrentUser() user?: any,
  ) {
    // Allow guest access - user.id is optional
    return this.cyphersService.getCypherById(id, user?.id);
  }

  /**
   * POST /cyphers - Create a new cypher (AUTH REQUIRED - All users can create)
   */
  @Post()
  @UseGuards(JwtAuthGuard)
  async createCypher(
    @Body() createDto: CreateCypherDto,
    @CurrentUser() user: any,
  ) {
    return this.cyphersService.createCypher(createDto, user.id);
  }

  /**
   * POST /cyphers/:id/submit - Submit entry to cypher (AUTH REQUIRED)
   */
  @Post(':id/submit')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(FileInterceptor('file'))
  async submitEntry(
    @Param('id') cypherId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body() submitDto: SubmitEntryDto,
    @CurrentUser() user: any,
  ) {
    if (!file) {
      throw new BadRequestException('No audio file provided');
    }

    return this.cyphersService.submitEntry(
      cypherId,
      user.id,
      file,
      submitDto.title,
    );
  }

  /**
   * GET /cyphers/:id/entries - Get entries for a cypher (GUEST ACCESS - No auth required)
   */
  @Get(':id/entries')
  async getCypherEntries(
    @Param('id') cypherId: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.cyphersService.getCypherEntries(cypherId, page, limit);
  }

  /**
   * POST /entries/:id/vote - Vote on a cypher entry (AUTH REQUIRED)
   */
  @Post('entries/:id/vote')
  @UseGuards(JwtAuthGuard)
  async voteEntry(
    @Param('id') entryId: string,
    @Body() voteDto: VoteEntryDto,
    @CurrentUser() user: any,
  ) {
    return this.cyphersService.voteEntry(entryId, user.id, voteDto);
  }

  /**
   * POST /entries/:id/report - Report a cypher entry (AUTH REQUIRED)
   */
  @Post('entries/:id/report')
  @UseGuards(JwtAuthGuard)
  async reportEntry(
    @Param('id') entryId: string,
    @Body() reportDto: ReportEntryDto,
    @CurrentUser() user: any,
  ) {
    return this.cyphersService.reportEntry(entryId, user.id, reportDto);
  }

  /**
   * GET /cyphers/:id/leaderboard - Get leaderboard for a cypher (GUEST ACCESS - No auth required)
   */
  @Get(':id/leaderboard')
  async getLeaderboard(
    @Param('id') cypherId: string,
    @Query('limit', new DefaultValuePipe(50), ParseIntPipe) limit: number,
  ) {
    return this.cyphersService.getLeaderboard(cypherId, limit);
  }

  /**
   * POST /cyphers/:id/invite - Invite a user to a cypher (AUTH REQUIRED - Any user can invite)
   */
  @Post(':id/invite')
  @UseGuards(JwtAuthGuard)
  async inviteArtist(
    @Param('id') cypherId: string,
    @Body() inviteDto: InviteArtistDto,
    @CurrentUser() user: any,
  ) {
    return this.cyphersService.inviteArtist(cypherId, user.id, inviteDto);
  }

  /**
   * GET /cyphers/users/invites - Get current user's cypher invites (AUTH REQUIRED)
   */
  @Get('users/invites')
  @UseGuards(JwtAuthGuard)
  async getUserInvites(@CurrentUser() user: any) {
    return this.cyphersService.getUserInvites(user.id);
  }

  /**
   * POST /cyphers/invites/:id/respond - Respond to a cypher invite (AUTH REQUIRED)
   */
  @Post('invites/:id/respond')
  @UseGuards(JwtAuthGuard)
  async respondToInvite(
    @Param('id') inviteId: string,
    @Body() respondDto: RespondToInviteDto,
    @CurrentUser() user: any,
  ) {
    return this.cyphersService.respondToInvite(inviteId, user.id, respondDto);
  }
}

