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

export async function syncSupabaseProviderRole(formData: FormData) {
  const providerId = String(formData.get('providerId'));
  await adminPost(`/admin/providers/${providerId}/sync-supabase-role`, {}, null);
  revalidatePath('/providers');
  revalidatePath('/audit-log');
}

export async function enablePushDevice(formData: FormData) {
  const pushDeviceId = String(formData.get('pushDeviceId'));
  await adminPost(`/admin/push-devices/${pushDeviceId}/enable`, {}, null);
  revalidatePath('/providers');
  revalidatePath('/notifications');
}
