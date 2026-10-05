import { IsEnum } from 'class-validator';

export enum BookingResponse {
  CONFIRMED = 'CONFIRMED',
  DECLINED = 'DECLINED',
}

export class RespondBookingDto {
  @IsEnum(BookingResponse)
  status: BookingResponse;
}
