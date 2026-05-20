'use server';

import { revalidatePath } from 'next/cache';
import { adminPost } from '../../lib/admin-api';

export async function retryNotification(formData: FormData) {
  const notificationId = String(formData.get('notificationId'));
  await adminPost(`/admin/notifications/${notificationId}/retry`, {}, null);
  revalidatePath('/notifications');
}
