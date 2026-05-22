import { Role } from '@prisma/client';

export type AuthenticatedUser = {
  id: string;
  roles: Role[];
  authProvider?: 'nest' | 'supabase';
  externalUserId?: string;
};
