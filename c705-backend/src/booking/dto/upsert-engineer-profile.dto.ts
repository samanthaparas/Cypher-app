import { IsString, IsOptional, IsInt, Min, IsUrl } from 'class-validator';

export class UpsertEngineerProfileDto {
  @IsString()
  @IsOptional()
  bio?: string;

  @IsString()
  @IsOptional()
  studioName?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsUrl()
  @IsOptional()
  avatarUrl?: string;

  @IsInt()
  @Min(0)
  @IsOptional()
  hourlyRate?: number; // in cents
}
