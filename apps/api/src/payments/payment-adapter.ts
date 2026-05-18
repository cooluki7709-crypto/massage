import { PaymentMethod, PaymentStatus } from '@prisma/client';

export type PaymentAuthorization = {
  method: PaymentMethod;
  status: PaymentStatus;
  providerRef: string | null;
  rawMeta?: Record<string, unknown>;
};

export type PaymentCallbackResult = {
  providerRef: string;
  status: PaymentStatus;
  rawMeta: Record<string, unknown>;
};

export interface PaymentAdapter {
  readonly method: PaymentMethod;
  authorize(input: { bookingId: string; amount: number; currency: string }): PaymentAuthorization;
  parseCallback(payload: unknown): PaymentCallbackResult;
  checkStatus(providerRef: string): PaymentStatus;
  release(providerRef: string | null): PaymentStatus;
}

