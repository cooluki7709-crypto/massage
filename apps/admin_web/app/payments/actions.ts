'use server';

import { revalidatePath } from 'next/cache';
import { adminPost } from '../../lib/admin-api';

export async function refundPayment(formData: FormData) {
  const paymentId = String(formData.get('paymentId'));
  await adminPost(`/admin/payments/${paymentId}/refund`, {}, null);
  revalidatePath('/payments');
}

export async function syncPayment(formData: FormData) {
  const paymentId = String(formData.get('paymentId'));
  await adminPost(`/admin/payments/${paymentId}/sync`, {}, null);
  revalidatePath('/payments');
}

export async function capturePayment(formData: FormData) {
  const paymentId = String(formData.get('paymentId'));
  await adminPost(`/admin/payments/${paymentId}/capture`, {}, null);
  revalidatePath('/payments');
}

export async function releasePayment(formData: FormData) {
  const paymentId = String(formData.get('paymentId'));
  await adminPost(`/admin/payments/${paymentId}/release`, {}, null);
  revalidatePath('/payments');
}
