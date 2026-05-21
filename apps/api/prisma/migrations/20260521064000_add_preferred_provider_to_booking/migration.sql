ALTER TABLE "Booking"
ADD COLUMN "preferredProviderId" TEXT;

UPDATE "Booking"
SET "preferredProviderId" = "selectedProviderId"
WHERE "selectedProviderId" IS NOT NULL;

ALTER TABLE "Booking"
ADD CONSTRAINT "Booking_preferredProviderId_fkey"
FOREIGN KEY ("preferredProviderId") REFERENCES "ProviderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;
