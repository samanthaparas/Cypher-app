import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { SubscriptionsService } from './subscriptions.service';
import { SubscriptionTier } from '../../../c705_db/generated/prisma/enums';

@Controller('subscriptions')
export class SubscriptionsController {
  constructor(
    private readonly subscriptionsService: SubscriptionsService,
  ) {}

  /**
   * Get current user's subscription
   */
  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getMySubscription(@CurrentUser() user: any) {
    return this.subscriptionsService.getSubscription(user.id);
  }

  /**
   * Create or update subscription (called after Apple IAP)
   */
  @Post('subscribe')
  @UseGuards(JwtAuthGuard)
  async subscribe(
    @CurrentUser() user: any,
    @Body()
    body: {
      tier: SubscriptionTier;
      productId: string;
      receipt: string;
      expiresAt?: string;
    },
  ) {
    return this.subscriptionsService.createOrUpdateSubscription(
      user.id,
      body.tier,
      body.productId,
      body.receipt,
      body.expiresAt ? new Date(body.expiresAt) : undefined,
    );
  }

  /**
   * Cancel subscription
   */
  @Post('cancel')
  @UseGuards(JwtAuthGuard)
  async cancel(@CurrentUser() user: any) {
    return this.subscriptionsService.cancelSubscription(user.id);
  }

  /**
   * Get subscription features for a tier
   */
  @Get('features/:tier')
  async getFeatures(@Body('tier') tier: SubscriptionTier) {
    return {
      tier,
      features: this.subscriptionsService.getTierFeatures(tier),
    };
  }
}

