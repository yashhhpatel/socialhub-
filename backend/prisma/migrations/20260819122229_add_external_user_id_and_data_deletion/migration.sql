-- AlterTable
ALTER TABLE "social_account" ADD COLUMN     "externalUserId" TEXT;

-- CreateTable
CREATE TABLE "data_deletion_request" (
    "id" TEXT NOT NULL,
    "platform" "Platform" NOT NULL,
    "externalUserId" TEXT NOT NULL,
    "confirmationCode" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'completed',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "data_deletion_request_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "data_deletion_request_confirmationCode_key" ON "data_deletion_request"("confirmationCode");

-- CreateIndex
CREATE INDEX "social_account_platform_externalUserId_idx" ON "social_account"("platform", "externalUserId");
