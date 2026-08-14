-- CreateTable
CREATE TABLE "brand_kit" (
    "id" TEXT NOT NULL,
    "orgId" TEXT NOT NULL,
    "colors" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "fonts" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "logoUrl" TEXT,
    "logoPublicId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "brand_kit_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "brand_kit_orgId_key" ON "brand_kit"("orgId");

-- AddForeignKey
ALTER TABLE "brand_kit" ADD CONSTRAINT "brand_kit_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organization"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
