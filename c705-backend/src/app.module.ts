import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { PrismaService } from './prisma/prisma.service';
import { S3Module } from './s3/s3.module';
import { TracksModule } from './tracks/tracks.module';
import { ArticlesModule } from './articles/articles.module';
import { FeedModule } from './feed/feed.module';
import { CommentsModule } from './comments/comments.module';
import { LikesModule } from './likes/likes.module';
import { ArtistsModule } from './artists/artists.module';
import { CyphersModule } from './cyphers/cyphers.module';
import { BeatsModule } from './beats/beats.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { PayoutsModule } from './payouts/payouts.module';
import { NewsModule } from './news/news.module';
import { JournalistInvitesModule } from './journalist-invites/journalist-invites.module';
import { AdminModule } from './admin/admin.module';
import { HealthController } from './health/health.controller';
import { SearchModule } from './search/search.module';
import { BookingModule } from './booking/booking.module';

@Module({
  imports: [AuthModule, S3Module, TracksModule, ArticlesModule, FeedModule, CommentsModule, LikesModule, ArtistsModule, CyphersModule, BeatsModule, SubscriptionsModule, PayoutsModule, NewsModule, JournalistInvitesModule, AdminModule, SearchModule, BookingModule],
  controllers: [AppController, HealthController],
  providers: [AppService, PrismaService],
})
export class AppModule {}
