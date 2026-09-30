import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { BeatsService } from './beats.service';
import { UploadBeatDto } from './dto/upload-beat.dto';
import { PurchaseBeatDto } from './dto/purchase-beat.dto';
import { ReportBeatDto } from './dto/report-beat.dto';

@Controller('beats')
export class BeatsController {
  constructor(private readonly beatsService: BeatsService) {}

  /**
   * Upload a beat (Producer only)
   */
  @Post('upload')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(FileInterceptor('file'))
  async uploadBeat(
    @CurrentUser() user: any,
    @Body() uploadDto: UploadBeatDto,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.beatsService.uploadBeat(user.id, uploadDto, file);
  }

  /**
   * GET /beats/search - Search beats by title or genre (GUEST ACCESS)
   */
  @Get('search')
  async searchBeats(
    @Query('q') query: string,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    if (!query || query.trim().length < 2) {
      return { beats: [] };
    }
    return { beats: await this.beatsService.searchBeats(query.trim(), limit) };
  }

  /**
   * Get all beats (browse)
   */
  @Get()
  async getBeats(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
    @Query('bpm', new DefaultValuePipe(0), ParseIntPipe) bpm: number,
    @Query('genre') genre?: string,
    @Query('mood') mood?: string,
  ) {
    return this.beatsService.getBeats(
      page,
      limit,
      genre || undefined,
      bpm > 0 ? bpm : undefined,
      mood || undefined,
    );
  }

  /**
   * Get beat by ID
   */
  @Get(':id')
  async getBeatById(
    @Param('id') beatId: string,
    @CurrentUser() user?: any,
  ) {
    return this.beatsService.getBeatById(beatId, user?.userId);
  }

  /**
   * Get preview URL (public)
   */
  @Get(':id/preview')
  async getPreviewUrl(@Param('id') beatId: string) {
    const url = await this.beatsService.getPreviewUrl(beatId);
    return { previewUrl: url };
  }

  /**
   * Purchase a beat (Apple IAP)
   */
  @Post(':id/purchase')
  @UseGuards(JwtAuthGuard)
  async purchaseBeat(
    @Param('id') beatId: string,
    @CurrentUser() user: any,
    @Body() purchaseDto: PurchaseBeatDto,
  ) {
    return this.beatsService.purchaseBeat(beatId, user.userId, purchaseDto);
  }

  /**
   * Get full beat URL (only if purchased)
   */
  @Get(':id/full')
  @UseGuards(JwtAuthGuard)
  async getFullBeatUrl(
    @Param('id') beatId: string,
    @CurrentUser() user: any,
  ) {
    const url = await this.beatsService.getFullBeatUrl(beatId, user.userId);
    return { fullUrl: url };
  }

  /**
   * Get user's purchased beats
   */
  @Get('purchased/my')
  @UseGuards(JwtAuthGuard)
  async getPurchasedBeats(
    @CurrentUser() user: any,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.beatsService.getPurchasedBeats(user.userId, page, limit);
  }

  /**
   * Report a beat
   */
  @Post(':id/report')
  @UseGuards(JwtAuthGuard)
  async reportBeat(
    @Param('id') beatId: string,
    @CurrentUser() user: any,
    @Body() reportDto: ReportBeatDto,
  ) {
    return this.beatsService.reportBeat(beatId, user.userId, reportDto);
  }
}

