import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { PaymentsService } from './payments.service';

type PaymentStatusJob = {
  paymentId: string;
};

@Processor('payment-status-check')
export class PaymentStatusProcessor extends WorkerHost {
  constructor(private readonly payments: PaymentsService) {
    super();
  }

  process(job: Job<PaymentStatusJob>) {
    return this.payments.checkAndSyncStatus(job.data.paymentId);
  }
}

