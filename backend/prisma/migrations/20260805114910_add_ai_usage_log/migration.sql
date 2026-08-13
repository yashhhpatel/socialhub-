-- CreateEnum
CREATE TYPE "AIFeature" AS ENUM ('caption', 'hashtags', 'tone', 'viral_score', 'best_time');

-- CreateTable
CREATE TABLE "ai_usage_log" (
    "id" TEXT NOT NULL,
    "orgId" TEXT NOT NULL,
    "userId" TEXT,
    "feature" "AIFeature" NOT NULL,
    "inputTokens" INTEGER NOT NULL DEFAULT 0,
    "outputTokens" INTEGER NOT NULL DEFAULT 0,
    "model" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_usage_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ai_usage_log_orgId_createdAt_idx" ON "ai_usage_log"("orgId", "createdAt");

-- AddForeignKey
ALTER TABLE "ai_usage_log" ADD CONSTRAINT "ai_usage_log_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organization"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
