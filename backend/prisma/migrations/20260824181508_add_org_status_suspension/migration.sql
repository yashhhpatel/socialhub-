-- CreateEnum
CREATE TYPE "OrgStatus" AS ENUM ('active', 'suspended');

-- AlterTable
ALTER TABLE "organization" ADD COLUMN     "status" "OrgStatus" NOT NULL DEFAULT 'active',
ADD COLUMN     "suspendedAt" TIMESTAMP(3);
