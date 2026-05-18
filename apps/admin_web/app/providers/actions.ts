'use server';

import { revalidatePath } from 'next/cache';
import { adminPost } from '../../lib/admin-api';

export async function approveProvider(formData: FormData) {
  const providerId = String(formData.get('providerId'));
  await adminPost(`/admin/providers/${providerId}/approve`, {}, null);
  revalidatePath('/providers');
}

export async function rejectProvider(formData: FormData) {
  const providerId = String(formData.get('providerId'));
  const reason = String(formData.get('reason') || 'Rejected by admin');
  await adminPost(`/admin/providers/${providerId}/reject`, { reason }, null);
  revalidatePath('/providers');
}

