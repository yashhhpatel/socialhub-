-- CreateEnum
CREATE TYPE "IngestionStatus" AS ENUM ('running', 'success', 'failed');

-- CreateTable
CREATE TABLE "post_metric" (
    "id" TEXT NOT NULL,
    "publishJobId" TEXT NOT NULL,
    "impressions" INTEGER NOT NULL DEFAULT 0,
    "reach" INTEGER NOT NULL DEFAULT 0,
    "likes" INTEGER NOT NULL DEFAULT 0,
    "comments" INTEGER NOT NULL DEFAULT 0,
    "shares" INTEGER NOT NULL DEFAULT 0,
    "clicks" INTEGER NOT NULL DEFAULT 0,
    "capturedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "post_metric_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ingestion_run" (
    "id" TEXT NOT NULL,
    "status" "IngestionStatus" NOT NULL DEFAULT 'running',
    "postsProcessed" INTEGER NOT NULL DEFAULT 0,
    "postsFailed" INTEGER NOT NULL DEFAULT 0,
    "error" TEXT,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" TIMESTAMP(3),

    CONSTRAINT "ingestion_run_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "post_metric_publishJobId_key" ON "post_metric"("publishJobId");

-- CreateIndex
CREATE INDEX "ingestion_run_startedAt_idx" ON "ingestion_run"("startedAt");

-- AddForeignKey
ALTER TABLE "post_metric" ADD CONSTRAINT "post_metric_publishJobId_fkey" FOREIGN KEY ("publishJobId") REFERENCES "publish_job"("id") ON DELETE CASCADE ON UPDATE CASCADE;
