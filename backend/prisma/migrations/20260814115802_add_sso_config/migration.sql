-- CreateTable
CREATE TABLE "sso_config" (
    "id" TEXT NOT NULL,
    "orgId" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "entryPoint" TEXT NOT NULL,
    "idpCert" TEXT NOT NULL,
    "issuer" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sso_config_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "sso_config_orgId_key" ON "sso_config"("orgId");

-- AddForeignKey
ALTER TABLE "sso_config" ADD CONSTRAINT "sso_config_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organization"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
