import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { OtpDeliveryService } from './otp-delivery.service';
import { RolesGuard } from './roles.guard';
import { SocketAuthService } from './socket-auth.service';

@Global()
@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_ACCESS_SECRET ?? 'dev-access-secret',
      signOptions: { expiresIn: '15m' },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, OtpDeliveryService, JwtAuthGuard, RolesGuard, SocketAuthService],
  exports: [AuthService, OtpDeliveryService, JwtModule, JwtAuthGuard, RolesGuard, SocketAuthService],
})
export class AuthModule {}
