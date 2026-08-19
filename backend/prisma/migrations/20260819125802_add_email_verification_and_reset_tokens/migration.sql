-- CreateEnum
CREATE TYPE "UserTokenType" AS ENUM ('email_verification', 'password_reset');

-- AlterTable
ALTER TABLE "user" ADD COLUMN     "emailVerifiedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "user_token" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" "UserTokenType" NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_token_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_token_tokenHash_key" ON "user_token"("tokenHash");

-- CreateIndex
CREATE INDEX "user_token_userId_type_idx" ON "user_token"("userId", "type");

-- AddForeignKey
ALTER TABLE "user_token" ADD CONSTRAINT "user_token_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
