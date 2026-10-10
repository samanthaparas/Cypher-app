import { IsString, IsDateString, IsOptional } from 'class-validator';

export class CreateBookingDto {
  @IsString()
  engineerId: string; // EngineerProfile id

  @IsDateString()
  startTime: string;

  @IsDateString()
  endTime: string;

  @IsString()
  @IsOptional()
  notes?: string;
}
