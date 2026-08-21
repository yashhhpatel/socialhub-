-- CreateTable
CREATE TABLE "media_asset" (
    "id" TEXT NOT NULL,
    "orgId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "publicId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "posterUrl" TEXT,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_asset_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "media_asset_orgId_createdAt_idx" ON "media_asset"("orgId", "createdAt");

-- AddForeignKey
ALTER TABLE "media_asset" ADD CONSTRAINT "media_asset_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;
