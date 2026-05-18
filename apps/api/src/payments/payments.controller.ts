import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { PaymentMethod, Role } from '@prisma/client';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { PaymentsService } from './payments.service';

@Controller()
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Post('admin/payments/:id/refund')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  refund(@CurrentUser() user: AuthenticatedUser, @Param('id') paymentId: string) {
    return this.payments.refund(user.id, paymentId);
  }

  @Post('payments/:method/callback')
  callback(@Param('method') method: PaymentMethod, @Body() body: unknown) {
    return this.payments.handleCallback(method, body);
  }
}
