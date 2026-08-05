-- CreateEnum
CREATE TYPE "PublishJobStatus" AS ENUM ('queued', 'scheduled', 'processing', 'published', 'failed', 'cancelled');

-- CreateTable
CREATE TABLE "publish_job" (
    "id" TEXT NOT NULL,
    "variantId" TEXT NOT NULL,
    "socialAccountId" TEXT NOT NULL,
    "scheduledAt" TIMESTAMP(3),
    "status" "PublishJobStatus" NOT NULL DEFAULT 'queued',
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "externalPostId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "publish_job_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "publish_job_status_scheduledAt_idx" ON "publish_job"("status", "scheduledAt");

-- CreateIndex
CREATE INDEX "publish_job_variantId_idx" ON "publish_job"("variantId");

-- AddForeignKey
ALTER TABLE "publish_job" ADD CONSTRAINT "publish_job_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "content_variant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "publish_job" ADD CONSTRAINT "publish_job_socialAccountId_fkey" FOREIGN KEY ("socialAccountId") REFERENCES "social_account"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
