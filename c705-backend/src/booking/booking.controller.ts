import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { BookingService } from './booking.service';
import { UpsertEngineerProfileDto } from './dto/upsert-engineer-profile.dto';
import { CreateBookingDto } from './dto/create-booking.dto';
import { RespondBookingDto } from './dto/respond-booking.dto';

@Controller('booking')
export class BookingController {
  constructor(private readonly bookingService: BookingService) {}

  /**
   * Create or update the current user's engineer profile
   */
  @Post('engineer-profile')
  @UseGuards(JwtAuthGuard)
  async upsertEngineerProfile(
    @CurrentUser() user: any,
    @Body() dto: UpsertEngineerProfileDto,
  ) {
    return this.bookingService.upsertEngineerProfile(user.id, dto);
  }

  /**
   * Browse engineers (GUEST ACCESS, like browsing artists/beats)
   */
  @Get('engineers')
  async getEngineers(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
    @Query('city') city?: string,
  ) {
    return this.bookingService.getEngineers(page, limit, city || undefined);
  }

  /**
   * Get a single engineer's profile
   */
  @Get('engineers/:id')
  async getEngineerById(@Param('id') id: string) {
    return this.bookingService.getEngineerById(id);
  }

  /**
   * Request a booking with an engineer
   */
  @Post()
  @UseGuards(JwtAuthGuard)
  async createBooking(@CurrentUser() user: any, @Body() dto: CreateBookingDto) {
    return this.bookingService.createBooking(user.id, dto);
  }

  /**
   * Bookings I've made as an artist
   */
  @Get('my')
  @UseGuards(JwtAuthGuard)
  async getMyBookings(
    @CurrentUser() user: any,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.bookingService.getMyBookings(user.id, page, limit);
  }

  /**
   * Booking requests I've received as an engineer
   */
  @Get('received')
  @UseGuards(JwtAuthGuard)
  async getReceivedBookings(
    @CurrentUser() user: any,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.bookingService.getReceivedBookings(user.id, page, limit);
  }

  /**
   * Engineer confirms or declines a booking request
   */
  @Patch(':id/respond')
  @UseGuards(JwtAuthGuard)
  async respondToBooking(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: RespondBookingDto,
  ) {
    return this.bookingService.respondToBooking(id, user.id, dto);
  }

  /**
   * Either party cancels a booking
   */
  @Patch(':id/cancel')
  @UseGuards(JwtAuthGuard)
  async cancelBooking(@Param('id') id: string, @CurrentUser() user: any) {
    return this.bookingService.cancelBooking(id, user.id);
  }

  /**
   * Engineer marks a confirmed booking as completed
   */
  @Patch(':id/complete')
  @UseGuards(JwtAuthGuard)
  async completeBooking(@Param('id') id: string, @CurrentUser() user: any) {
    return this.bookingService.completeBooking(id, user.id);
  }
}
