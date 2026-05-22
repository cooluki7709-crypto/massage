import { Body, Controller, Post } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AuthService } from './auth.service';

type RequestOtpDto = {
  phone: string;
  role?: Role;
};

type VerifyOtpDto = {
  phone: string;
  otp: string;
  role?: Role;
};

type SupabaseExchangeDto = {
  supabaseAccessToken: string;
  role?: Role;
};

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('request-otp')
  requestOtp(@Body() body: RequestOtpDto) {
    return this.auth.requestOtp(body);
  }

  @Post('verify-otp')
  verifyOtp(@Body() body: VerifyOtpDto) {
    return this.auth.verifyOtp(body);
  }

  @Post('refresh')
  refresh(@Body() body: { refreshToken: string }) {
    return this.auth.refresh(body.refreshToken);
  }

  @Post('supabase/exchange')
  exchangeSupabaseSession(@Body() body: SupabaseExchangeDto) {
    return this.auth.exchangeSupabaseSession(body);
  }
}
