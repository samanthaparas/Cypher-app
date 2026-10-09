/*
  Warnings:

  - A unique constraint covering the columns `[username]` on the table `User` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "CypherType" AS ENUM ('OPEN', 'COMPETITIVE', 'BEAT_LOCKED');

-- CreateEnum
CREATE TYPE "CypherVisibility" AS ENUM ('PUBLIC', 'INVITE_ONLY');

-- CreateEnum
CREATE TYPE "CypherStatus" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "SubscriptionTier" AS ENUM ('FREE', 'CREATOR_PLUS', 'PRO_CREATOR');

-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('PENDING', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'COMPLETED');

-- AlterTable
ALTER TABLE "ArtistProfile" ADD COLUMN     "avatarUrl" TEXT,
ADD COLUMN     "city" TEXT,
ADD COLUMN     "instagramUrl" TEXT,
ADD COLUMN     "tiktokUrl" TEXT,
ADD COLUMN     "xUrl" TEXT,
ADD COLUMN     "youtubeUrl" TEXT;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "username" TEXT;

-- CreateTable
CREATE TABLE "Cypher" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "beatUrl" TEXT,
    "beatId" TEXT,
    "hostArtistId" TEXT NOT NULL,
    "visibility" "CypherVisibility" NOT NULL DEFAULT 'PUBLIC',
    "status" "CypherStatus" NOT NULL DEFAULT 'OPEN',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "cypherType" "CypherType" NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Cypher_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CypherInvite" (
    "id" TEXT NOT NULL,
    "cypherId" TEXT NOT NULL,
    "invitedArtistId" TEXT NOT NULL,
    "invitedByArtistId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "respondedAt" TIMESTAMP(3),

    CONSTRAINT "CypherInvite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CypherEntry" (
    "id" TEXT NOT NULL,
    "cypherId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "audioUrl" TEXT NOT NULL,
    "title" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "averageScore" DOUBLE PRECISION DEFAULT 0,
    "voteCount" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "CypherEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CypherVote" (
    "id" TEXT NOT NULL,
    "entryId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "score" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CypherVote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CypherReport" (
    "id" TEXT NOT NULL,
    "entryId" TEXT,
    "cypherId" TEXT,
    "userId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CypherReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Beat" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "genre" TEXT NOT NULL,
    "bpm" INTEGER NOT NULL,
    "mood" TEXT,
    "previewUrl" TEXT NOT NULL,
    "fullUrl" TEXT NOT NULL,
    "price" INTEGER NOT NULL,
    "producerId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Beat_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BeatPurchase" (
    "id" TEXT NOT NULL,
    "beatId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "receipt" TEXT NOT NULL,
    "grossAmount" INTEGER NOT NULL,
    "appleFee" INTEGER NOT NULL,
    "platformFee" INTEGER NOT NULL,
    "producerEarning" INTEGER NOT NULL,
    "payoutStatus" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BeatPurchase_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BeatReport" (
    "id" TEXT NOT NULL,
    "beatId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BeatReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Subscription" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tier" "SubscriptionTier" NOT NULL DEFAULT 'FREE',
    "productId" TEXT,
    "receipt" TEXT,
    "expiresAt" TIMESTAMP(3),
    "autoRenew" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Subscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProducerPayout" (
    "id" TEXT NOT NULL,
    "producerId" TEXT NOT NULL,
    "totalAmount" INTEGER NOT NULL,
    "platformFee" INTEGER NOT NULL,
    "netAmount" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "paymentMethod" TEXT,
    "transactionId" TEXT,
    "processedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProducerPayout_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EngineerProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "bio" TEXT,
    "studioName" TEXT,
    "city" TEXT,
    "avatarUrl" TEXT,
    "hourlyRate" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EngineerProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Booking" (
    "id" TEXT NOT NULL,
    "artistId" TEXT NOT NULL,
    "engineerId" TEXT NOT NULL,
    "startTime" TIMESTAMP(3) NOT NULL,
    "endTime" TIMESTAMP(3) NOT NULL,
    "status" "BookingStatus" NOT NULL DEFAULT 'PENDING',
    "rate" INTEGER,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "respondedAt" TIMESTAMP(3),

    CONSTRAINT "Booking_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "JournalistInvite" (
    "id" TEXT NOT NULL,
    "email" TEXT,
    "accessCode" TEXT NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "expiresAt" TIMESTAMP(3),
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "usedAt" TIMESTAMP(3),
    "usedBy" TEXT,

    CONSTRAINT "JournalistInvite_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Cypher_isActive_idx" ON "Cypher"("isActive");

-- CreateIndex
CREATE INDEX "Cypher_startDate_idx" ON "Cypher"("startDate");

-- CreateIndex
CREATE INDEX "Cypher_endDate_idx" ON "Cypher"("endDate");

-- CreateIndex
CREATE INDEX "Cypher_cypherType_idx" ON "Cypher"("cypherType");

-- CreateIndex
CREATE INDEX "Cypher_hostArtistId_idx" ON "Cypher"("hostArtistId");

-- CreateIndex
CREATE INDEX "Cypher_visibility_idx" ON "Cypher"("visibility");

-- CreateIndex
CREATE INDEX "Cypher_status_idx" ON "Cypher"("status");

-- CreateIndex
CREATE INDEX "CypherInvite_cypherId_idx" ON "CypherInvite"("cypherId");

-- CreateIndex
CREATE INDEX "CypherInvite_invitedArtistId_idx" ON "CypherInvite"("invitedArtistId");

-- CreateIndex
CREATE INDEX "CypherInvite_invitedByArtistId_idx" ON "CypherInvite"("invitedByArtistId");

-- CreateIndex
CREATE INDEX "CypherInvite_status_idx" ON "CypherInvite"("status");

-- CreateIndex
CREATE UNIQUE INDEX "CypherInvite_cypherId_invitedArtistId_key" ON "CypherInvite"("cypherId", "invitedArtistId");

-- CreateIndex
CREATE INDEX "CypherEntry_cypherId_idx" ON "CypherEntry"("cypherId");

-- CreateIndex
CREATE INDEX "CypherEntry_userId_idx" ON "CypherEntry"("userId");

-- CreateIndex
CREATE INDEX "CypherEntry_createdAt_idx" ON "CypherEntry"("createdAt");

-- CreateIndex
CREATE INDEX "CypherEntry_averageScore_idx" ON "CypherEntry"("averageScore");

-- CreateIndex
CREATE UNIQUE INDEX "CypherEntry_cypherId_userId_key" ON "CypherEntry"("cypherId", "userId");

-- CreateIndex
CREATE INDEX "CypherVote_entryId_idx" ON "CypherVote"("entryId");

-- CreateIndex
CREATE INDEX "CypherVote_userId_idx" ON "CypherVote"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "CypherVote_entryId_userId_key" ON "CypherVote"("entryId", "userId");

-- CreateIndex
CREATE INDEX "CypherReport_entryId_idx" ON "CypherReport"("entryId");

-- CreateIndex
CREATE INDEX "CypherReport_cypherId_idx" ON "CypherReport"("cypherId");

-- CreateIndex
CREATE INDEX "CypherReport_userId_idx" ON "CypherReport"("userId");

-- CreateIndex
CREATE INDEX "CypherReport_status_idx" ON "CypherReport"("status");

-- CreateIndex
CREATE INDEX "Beat_producerId_idx" ON "Beat"("producerId");

-- CreateIndex
CREATE INDEX "Beat_genre_idx" ON "Beat"("genre");

-- CreateIndex
CREATE INDEX "Beat_bpm_idx" ON "Beat"("bpm");

-- CreateIndex
CREATE INDEX "Beat_createdAt_idx" ON "Beat"("createdAt");

-- CreateIndex
CREATE INDEX "BeatPurchase_beatId_idx" ON "BeatPurchase"("beatId");

-- CreateIndex
CREATE INDEX "BeatPurchase_userId_idx" ON "BeatPurchase"("userId");

-- CreateIndex
CREATE INDEX "BeatPurchase_createdAt_idx" ON "BeatPurchase"("createdAt");

-- CreateIndex
CREATE INDEX "BeatPurchase_payoutStatus_idx" ON "BeatPurchase"("payoutStatus");

-- CreateIndex
CREATE UNIQUE INDEX "BeatPurchase_beatId_userId_key" ON "BeatPurchase"("beatId", "userId");

-- CreateIndex
CREATE INDEX "BeatReport_beatId_idx" ON "BeatReport"("beatId");

-- CreateIndex
CREATE INDEX "BeatReport_userId_idx" ON "BeatReport"("userId");

-- CreateIndex
CREATE INDEX "BeatReport_status_idx" ON "BeatReport"("status");

-- CreateIndex
CREATE UNIQUE INDEX "Subscription_userId_key" ON "Subscription"("userId");

-- CreateIndex
CREATE INDEX "Subscription_userId_idx" ON "Subscription"("userId");

-- CreateIndex
CREATE INDEX "Subscription_tier_idx" ON "Subscription"("tier");

-- CreateIndex
CREATE INDEX "Subscription_expiresAt_idx" ON "Subscription"("expiresAt");

-- CreateIndex
CREATE INDEX "ProducerPayout_producerId_idx" ON "ProducerPayout"("producerId");

-- CreateIndex
CREATE INDEX "ProducerPayout_status_idx" ON "ProducerPayout"("status");

-- CreateIndex
CREATE INDEX "ProducerPayout_createdAt_idx" ON "ProducerPayout"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "EngineerProfile_userId_key" ON "EngineerProfile"("userId");

-- CreateIndex
CREATE INDEX "EngineerProfile_city_idx" ON "EngineerProfile"("city");

-- CreateIndex
CREATE INDEX "Booking_artistId_idx" ON "Booking"("artistId");

-- CreateIndex
CREATE INDEX "Booking_engineerId_idx" ON "Booking"("engineerId");

-- CreateIndex
CREATE INDEX "Booking_status_idx" ON "Booking"("status");

-- CreateIndex
CREATE INDEX "Booking_startTime_idx" ON "Booking"("startTime");

-- CreateIndex
CREATE UNIQUE INDEX "JournalistInvite_accessCode_key" ON "JournalistInvite"("accessCode");

-- CreateIndex
CREATE INDEX "JournalistInvite_accessCode_idx" ON "JournalistInvite"("accessCode");

-- CreateIndex
CREATE INDEX "JournalistInvite_used_idx" ON "JournalistInvite"("used");

-- CreateIndex
CREATE INDEX "JournalistInvite_expiresAt_idx" ON "JournalistInvite"("expiresAt");

-- CreateIndex
CREATE INDEX "JournalistInvite_createdBy_idx" ON "JournalistInvite"("createdBy");

-- CreateIndex
CREATE UNIQUE INDEX "User_username_key" ON "User"("username");

-- AddForeignKey
ALTER TABLE "Cypher" ADD CONSTRAINT "Cypher_hostArtistId_fkey" FOREIGN KEY ("hostArtistId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherInvite" ADD CONSTRAINT "CypherInvite_cypherId_fkey" FOREIGN KEY ("cypherId") REFERENCES "Cypher"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherInvite" ADD CONSTRAINT "CypherInvite_invitedArtistId_fkey" FOREIGN KEY ("invitedArtistId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherInvite" ADD CONSTRAINT "CypherInvite_invitedByArtistId_fkey" FOREIGN KEY ("invitedByArtistId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherEntry" ADD CONSTRAINT "CypherEntry_cypherId_fkey" FOREIGN KEY ("cypherId") REFERENCES "Cypher"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherEntry" ADD CONSTRAINT "CypherEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherVote" ADD CONSTRAINT "CypherVote_entryId_fkey" FOREIGN KEY ("entryId") REFERENCES "CypherEntry"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherVote" ADD CONSTRAINT "CypherVote_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherReport" ADD CONSTRAINT "CypherReport_entryId_fkey" FOREIGN KEY ("entryId") REFERENCES "CypherEntry"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherReport" ADD CONSTRAINT "CypherReport_cypherId_fkey" FOREIGN KEY ("cypherId") REFERENCES "Cypher"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CypherReport" ADD CONSTRAINT "CypherReport_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Beat" ADD CONSTRAINT "Beat_producerId_fkey" FOREIGN KEY ("producerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BeatPurchase" ADD CONSTRAINT "BeatPurchase_beatId_fkey" FOREIGN KEY ("beatId") REFERENCES "Beat"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BeatPurchase" ADD CONSTRAINT "BeatPurchase_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BeatReport" ADD CONSTRAINT "BeatReport_beatId_fkey" FOREIGN KEY ("beatId") REFERENCES "Beat"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BeatReport" ADD CONSTRAINT "BeatReport_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProducerPayout" ADD CONSTRAINT "ProducerPayout_producerId_fkey" FOREIGN KEY ("producerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EngineerProfile" ADD CONSTRAINT "EngineerProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_artistId_fkey" FOREIGN KEY ("artistId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_engineerId_fkey" FOREIGN KEY ("engineerId") REFERENCES "EngineerProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
