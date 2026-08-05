-- CreateEnum
CREATE TYPE "Platform" AS ENUM ('instagram', 'facebook', 'threads', 'x', 'linkedin');

-- CreateEnum
CREATE TYPE "SocialAccountStatus" AS ENUM ('connected', 'expired', 'revoked', 'error');

-- CreateEnum
CREATE TYPE "ContentAssetType" AS ENUM ('image', 'video');

-- CreateEnum
CREATE TYPE "ApprovalStatus" AS ENUM ('draft', 'pending_approval', 'approved', 'rejected');

-- CreateTable
CREATE TABLE "social_account" (
    "id" TEXT NOT NULL,
    "orgId" TEXT NOT NULL,
    "platform" "Platform" NOT NULL,
    "externalAccountId" TEXT NOT NULL,
    "accessTokenEnc" TEXT NOT NULL,
    "refreshTokenEnc" TEXT,
    "expiresAt" TIMESTAMP(3),
    "status" "SocialAccountStatus" NOT NULL DEFAULT 'connected',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "social_account_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "content_asset" (
    "id" TEXT NOT NULL,
    "orgId" TEXT NOT NULL,
    "createdById" TEXT NOT NULL,
    "type" "ContentAssetType" NOT NULL,
    "canvasJson" JSONB NOT NULL,
    "approvalStatus" "ApprovalStatus" NOT NULL DEFAULT 'draft',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "content_asset_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "social_account_orgId_idx" ON "social_account"("orgId");

-- CreateIndex
CREATE UNIQUE INDEX "social_account_orgId_platform_externalAccountId_key" ON "social_account"("orgId", "platform", "externalAccountId");

-- CreateIndex
CREATE INDEX "content_asset_orgId_idx" ON "content_asset"("orgId");

-- CreateIndex
CREATE INDEX "content_asset_orgId_approvalStatus_idx" ON "content_asset"("orgId", "approvalStatus");

-- AddForeignKey
ALTER TABLE "social_account" ADD CONSTRAINT "social_account_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organization"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "content_asset" ADD CONSTRAINT "content_asset_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organization"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "content_asset" ADD CONSTRAINT "content_asset_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "user"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
