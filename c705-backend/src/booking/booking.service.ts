import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertEngineerProfileDto } from './dto/upsert-engineer-profile.dto';
import { CreateBookingDto } from './dto/create-booking.dto';
import { RespondBookingDto } from './dto/respond-booking.dto';

const engineerUserSelect = {
  id: true,
  username: true,
  email: true,
};

@Injectable()
export class BookingService {
  constructor(private prisma: PrismaService) {}

  /**
   * Create or update the current user's engineer profile.
   * Any user can have one (role isn't enforced here, same as how the app
   * lets any role upload a beat for cyphers) — an artist just won't show up
   * in the engineer browse list unless they've filled one out.
   */
  async upsertEngineerProfile(userId: string, dto: UpsertEngineerProfileDto) {
    return this.prisma.engineerProfile.upsert({
      where: { userId },
      update: { ...dto },
      create: { userId, ...dto },
    });
  }

  /**
   * Browse engineers (like browsing barbers)
   */
  async getEngineers(page: number = 1, limit: number = 20, city?: string) {
    const skip = (page - 1) * limit;
    const where = city ? { city } : {};

    const [engineers, total] = await Promise.all([
      this.prisma.engineerProfile.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: engineerUserSelect } },
      }),
      this.prisma.engineerProfile.count({ where }),
    ]);

    return {
      engineers,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getEngineerById(engineerId: string) {
    const engineer = await this.prisma.engineerProfile.findUnique({
      where: { id: engineerId },
      include: { user: { select: engineerUserSelect } },
    });

    if (!engineer) {
      throw new NotFoundException('Engineer not found');
    }

    return engineer;
  }

  /**
   * Request a booking with an engineer
   */
  async createBooking(artistId: string, dto: CreateBookingDto) {
    const engineer = await this.prisma.engineerProfile.findUnique({
      where: { id: dto.engineerId },
    });

    if (!engineer) {
      throw new NotFoundException('Engineer not found');
    }

    if (engineer.userId === artistId) {
      throw new BadRequestException('You cannot book yourself');
    }

    const startTime = new Date(dto.startTime);
    const endTime = new Date(dto.endTime);

    if (endTime <= startTime) {
      throw new BadRequestException('endTime must be after startTime');
    }

    return this.prisma.booking.create({
      data: {
        artistId,
        engineerId: engineer.id,
        startTime,
        endTime,
        notes: dto.notes,
        rate: engineer.hourlyRate,
      },
      include: {
        engineer: { include: { user: { select: engineerUserSelect } } },
      },
    });
  }

  /**
   * Bookings the current user made as an artist (requester)
   */
  async getMyBookings(userId: string, page: number = 1, limit: number = 20) {
    const skip = (page - 1) * limit;

    const [bookings, total] = await Promise.all([
      this.prisma.booking.findMany({
        where: { artistId: userId },
        skip,
        take: limit,
        orderBy: { startTime: 'desc' },
        include: {
          engineer: { include: { user: { select: engineerUserSelect } } },
        },
      }),
      this.prisma.booking.count({ where: { artistId: userId } }),
    ]);

    return { bookings, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  /**
   * Booking requests the current user has received as an engineer
   */
  async getReceivedBookings(userId: string, page: number = 1, limit: number = 20) {
    const engineer = await this.prisma.engineerProfile.findUnique({
      where: { userId },
    });

    if (!engineer) {
      return { bookings: [], total: 0, page, limit, totalPages: 0 };
    }

    const skip = (page - 1) * limit;
    const where = { engineerId: engineer.id };

    const [bookings, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        skip,
        take: limit,
        orderBy: { startTime: 'desc' },
        include: { artist: { select: engineerUserSelect } },
      }),
      this.prisma.booking.count({ where }),
    ]);

    return { bookings, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  /**
   * Engineer confirms or declines a booking request
   */
  async respondToBooking(bookingId: string, userId: string, dto: RespondBookingDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { engineer: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    if (booking.engineer.userId !== userId) {
      throw new ForbiddenException('Only the engineer can respond to this booking');
    }

    if (booking.status !== 'PENDING') {
      throw new BadRequestException('This booking has already been responded to');
    }

    return this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: dto.status, respondedAt: new Date() },
    });
  }

  /**
   * Either the artist or the engineer can cancel
   */
  async cancelBooking(bookingId: string, userId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { engineer: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    const isParticipant =
      booking.artistId === userId || booking.engineer.userId === userId;

    if (!isParticipant) {
      throw new ForbiddenException('You are not part of this booking');
    }

    if (booking.status === 'COMPLETED' || booking.status === 'CANCELLED') {
      throw new BadRequestException(`Booking is already ${booking.status.toLowerCase()}`);
    }

    return this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'CANCELLED' },
    });
  }

  /**
   * Engineer marks a confirmed booking as completed
   */
  async completeBooking(bookingId: string, userId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { engineer: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    if (booking.engineer.userId !== userId) {
      throw new ForbiddenException('Only the engineer can complete this booking');
    }

    if (booking.status !== 'CONFIRMED') {
      throw new BadRequestException('Only confirmed bookings can be marked complete');
    }

    return this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'COMPLETED' },
    });
  }
}
