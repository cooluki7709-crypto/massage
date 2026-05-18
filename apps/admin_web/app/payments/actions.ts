'use server';

import { revalidatePath } from 'next/cache';
import { adminPost } from '../../lib/admin-api';

export async function refundPayment(formData: FormData) {
  const paymentId = String(formData.get('paymentId'));
  await adminPost(`/admin/payments/${paymentId}/refund`, {}, null);
  revalidatePath('/payments');
}

