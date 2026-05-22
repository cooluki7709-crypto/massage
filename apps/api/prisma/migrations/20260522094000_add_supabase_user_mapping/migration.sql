-- Add optional Supabase Auth user mapping while keeping existing Nest OTP users.
ALTER TABLE "User" ADD COLUMN "supabaseUserId" TEXT;

CREATE UNIQUE INDEX "User_supabaseUserId_key" ON "User"("supabaseUserId");
