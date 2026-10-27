import { IsString, IsOptional, IsEnum, IsDateString, IsUrl } from 'class-validator';

export enum CypherType {
  OPEN = 'OPEN',
  COMPETITIVE = 'COMPETITIVE',
  BEAT_LOCKED = 'BEAT_LOCKED',
}

// Who can see a cypher. These words must match the CypherVisibility enum in the database schema.
export enum CypherVisibility {
  PUBLIC = 'PUBLIC',
  INVITE_ONLY = 'INVITE_ONLY',
}

export class CreateCypherDto {
  @IsString()
  title: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsUrl()
  @IsOptional()
  beatUrl?: string;

  @IsEnum(CypherType)
  cypherType: CypherType;

  @IsDateString()
  startDate: string;

  @IsDateString()
  @IsOptional()
  endDate?: string;

  // Optional. If the app does not send it, the server makes the cypher public.
  @IsEnum(CypherVisibility)
  @IsOptional()
  visibility?: CypherVisibility;
}

