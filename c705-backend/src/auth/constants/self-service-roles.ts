import { Role } from '../../../../c705_db/generated/prisma/enums';

// Roles a person may give themselves at signup, at first Apple/Google sign-in, or through
// POST /auth/update-role. ADMIN is only granted by scripts/create-admin.ts. JOURNALIST is only
// granted at email signup with a valid invite code.
export const SELF_SERVICE_ROLES: readonly Role[] = [Role.ARTIST, Role.PRODUCER, Role.ENGINEER];

export function isSelfServiceRole(role: unknown): role is Role {
  return typeof role === 'string' && (SELF_SERVICE_ROLES as readonly string[]).includes(role);
}
