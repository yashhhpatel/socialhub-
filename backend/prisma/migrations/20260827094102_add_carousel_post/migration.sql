-- AlterTable
ALTER TABLE "publish_job" ADD COLUMN     "carouselPostId" TEXT,
ALTER COLUMN "variantId" DROP NOT NULL;

-- CreateTable
CREATE TABLE "carousel_post" (
    "id" TEXT NOT NULL,
    "orgId" TEXT NOT NULL,
    "mediaUrls" TEXT[],
    "caption" TEXT,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "carousel_post_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "carousel_post_orgId_idx" ON "carousel_post"("orgId");

-- CreateIndex
CREATE INDEX "publish_job_carouselPostId_idx" ON "publish_job"("carouselPostId");

-- AddForeignKey
ALTER TABLE "publish_job" ADD CONSTRAINT "publish_job_carouselPostId_fkey" FOREIGN KEY ("carouselPostId") REFERENCES "carousel_post"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "carousel_post" ADD CONSTRAINT "carousel_post_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;
