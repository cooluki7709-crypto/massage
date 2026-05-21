-- Store the last known provider location timestamp and customer-selected pins.
ALTER TABLE "ProviderProfile"
ADD COLUMN "currentLocationUpdatedAt" TIMESTAMP(3);

CREATE TABLE "CustomerSelectedLocation" (
  "id" TEXT NOT NULL,
  "customerProfileId" TEXT NOT NULL,
  "latitude" DECIMAL(10,7) NOT NULL,
  "longitude" DECIMAL(10,7) NOT NULL,
  "addressText" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CustomerSelectedLocation_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "CustomerSelectedLocation_customerProfileId_createdAt_idx"
ON "CustomerSelectedLocation"("customerProfileId", "createdAt");

ALTER TABLE "CustomerSelectedLocation"
ADD CONSTRAINT "CustomerSelectedLocation_customerProfileId_fkey"
FOREIGN KEY ("customerProfileId") REFERENCES "CustomerProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
