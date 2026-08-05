-- CreateEnum
CREATE TYPE "VariantStatus" AS ENUM ('pending', 'ready', 'failed');

-- AlterTable
ALTER TABLE "content_asset" ADD COLUMN     "masterImagePublicId" TEXT,
ADD COLUMN     "masterImageUrl" TEXT;

-- CreateTable
CREATE TABLE "content_variant" (
    "id" TEXT NOT NULL,
    "assetId" TEXT NOT NULL,
    "platform" "Platform" NOT NULL,
    "renderedMediaUrl" TEXT,
    "caption" TEXT,
    "hashtags" TEXT,
    "status" "VariantStatus" NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "content_variant_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "content_variant_assetId_idx" ON "content_variant"("assetId");

-- CreateIndex
CREATE UNIQUE INDEX "content_variant_assetId_platform_key" ON "content_variant"("assetId", "platform");

-- AddForeignKey
ALTER TABLE "content_variant" ADD CONSTRAINT "content_variant_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "content_asset"("id") ON DELETE CASCADE ON UPDATE CASCADE;
