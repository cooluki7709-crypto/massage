'use server';

import { revalidatePath } from 'next/cache';
import { adminPatch, adminPost } from '../../lib/admin-api';

export async function createCoupon(formData: FormData) {
  const code = String(formData.get('code') || '').trim();
  const description = String(formData.get('description') || '').trim();
  const percent = Number(formData.get('percent') || 0);
  const startsAt = String(formData.get('startsAt') || '').trim();
  const endsAt = String(formData.get('endsAt') || '').trim();

  if (!code || !Number.isFinite(percent) || percent <= 0) {
    return;
  }

  if (startsAt && endsAt && new Date(startsAt).getTime() > new Date(endsAt).getTime()) {
    return;
  }

  await adminPost(
    '/admin/coupons',
    {
      code,
      description,
      discount: { type: 'percent', value: percent },
      active: true,
      startsAt: startsAt || undefined,
      endsAt: endsAt || undefined,
    },
    null,
  );
  revalidatePath('/coupons');
}

export async function toggleCoupon(formData: FormData) {
  const couponId = String(formData.get('couponId'));
  const active = String(formData.get('active')) === 'true';
  await adminPatch(`/admin/coupons/${couponId}`, { active: !active }, null);
  revalidatePath('/coupons');
}
