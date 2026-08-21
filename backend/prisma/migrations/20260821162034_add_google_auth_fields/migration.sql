-- AlterEnum
ALTER TYPE "UserTokenType" ADD VALUE 'google_login_handoff';

-- AlterTable
ALTER TABLE "user" ADD COLUMN     "googleId" TEXT,
ALTER COLUMN "passwordHash" DROP NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "user_googleId_key" ON "user"("googleId");
