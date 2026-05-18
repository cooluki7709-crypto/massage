'use server';

import { revalidatePath } from 'next/cache';
import { adminPatch } from '../../lib/admin-api';

export async function moderateReview(formData: FormData) {
  const reviewId = String(formData.get('reviewId'));
  const status = String(formData.get('status'));
  const reportReason = String(formData.get('reportReason') || '');
  await adminPatch(`/admin/reviews/${reviewId}/moderate`, { status, reportReason }, null);
  revalidatePath('/reviews');
}

