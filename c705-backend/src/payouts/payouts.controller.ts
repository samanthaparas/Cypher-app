import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { PayoutsService } from './payouts.service';

@Controller('payouts')
export class PayoutsController {
  constructor(private readonly payoutsService: PayoutsService) {}

  /**
   * Get producer earnings summary
   */
  @Get('earnings')
  @UseGuards(JwtAuthGuard)
  async getEarnings(@CurrentUser() user: any) {
    return this.payoutsService.getProducerEarnings(user.id);
  }

  /**
   * Request payout
   */
  @Post('request')
  @UseGuards(JwtAuthGuard)
  async requestPayout(@CurrentUser() user: any) {
    return this.payoutsService.requestPayout(user.id);
  }

  /**
   * Get payout history
   */
  @Get('history')
  @UseGuards(JwtAuthGuard)
  async getHistory(@CurrentUser() user: any) {
    return this.payoutsService.getPayoutHistory(user.id);
  }

  /**
   * Admin: Process payout
   */
  @Post(':id/process')
  @UseGuards(JwtAuthGuard)
  async processPayout(
    @Param('id') payoutId: string,
    @Body() body: { transactionId: string },
  ) {
    // TODO: Add admin guard
    return this.payoutsService.processPayout(payoutId, body.transactionId);
  }
}

