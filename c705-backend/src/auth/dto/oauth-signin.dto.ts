import { IsString, IsOptional, IsEnum, IsIn } from 'class-validator';
import { Role as RoleEnum } from '../../../../c705_db/generated/prisma/enums';

export class OAuthSignInDto {
  // Kept for older app builds. The route (/auth/oauth/apple or /google) decides the provider.
  @IsOptional()
  @IsIn(['apple', 'google'])
  provider?: string;

  @IsString()
  identityToken: string;

  // Ignored by the server: only an email inside the verified token is used.
  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  fullName?: string;

  // Only ARTIST, PRODUCER or ENGINEER are accepted (checked in AuthService).
  @IsOptional()
  @IsEnum(RoleEnum)
  role?: RoleEnum;
}
