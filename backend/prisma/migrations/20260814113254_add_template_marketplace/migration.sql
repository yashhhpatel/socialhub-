-- AlterTable
ALTER TABLE "template" ADD COLUMN     "isPublic" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "publishedById" TEXT;

-- CreateIndex
CREATE INDEX "template_isPublic_category_idx" ON "template"("isPublic", "category");
