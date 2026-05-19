const apiBaseUrl = process.env.API_BASE_URL ?? 'http://localhost:3000/api';

async function request(path, options = {}) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...options,
    headers: { 'content-type': 'application/json', ...(options.headers ?? {}) },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${path} failed: ${response.status} ${JSON.stringify(body)}`);
  }
  return body;
}

const patchJson = (path, accessToken, body) =>
  request(path, {
    method: 'PATCH',
    headers: { authorization: `Bearer ${accessToken}` },
    body: JSON.stringify(body),
  });

const postJson = (path, accessToken, body = {}) =>
  request(path, {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}` },
    body: JSON.stringify(body),
  });

const getJson = (path, accessToken) =>
  request(path, {
    headers: { authorization: `Bearer ${accessToken}` },
  });

const health = await request('/health');
const readiness = await request('/health/ready');
if (!health.ok || !readiness.ok) {
  throw new Error(`API is not ready: ${JSON.stringify({ health, readiness })}`);
}

const customerAuth = await request('/auth/verify-otp', {
  method: 'POST',
  body: JSON.stringify({ phone: '+84900000001', otp: '123456', role: 'CUSTOMER' }),
});

const providerAuth = await request('/auth/verify-otp', {
  method: 'POST',
  body: JSON.stringify({ phone: '+84900000002', otp: '123456', role: 'PROVIDER' }),
});

const adminAuth = await request('/auth/verify-otp', {
  method: 'POST',
  body: JSON.stringify({ phone: '+84900000099', otp: '123456', role: 'ADMIN' }),
});

await patchJson('/notifications/device-token/register', customerAuth.accessToken, {
  token: 'demo-customer-device-token',
  platform: 'android',
});

await patchJson('/notifications/device-token/register', providerAuth.accessToken, {
  token: 'demo-provider-device-token',
  platform: 'android',
});

const services = await request('/services');
const service = services[0];

const verificationUpload = await postJson('/files/presign', providerAuth.accessToken, {
  contentType: 'image/jpeg',
  visibility: 'PRIVATE',
  purpose: 'provider-verification',
});
await postJson('/provider/verification/submit', providerAuth.accessToken, {
  fileIds: [verificationUpload.file.id],
});
await postJson(`/admin/providers/${providerAuth.user.providerProfile.id}/approve`, adminAuth.accessToken);
const verificationReadUrl = await getJson(`/files/${verificationUpload.file.id}/read-url`, adminAuth.accessToken);

await postJson('/provider/online', providerAuth.accessToken);

await postJson('/provider/location', providerAuth.accessToken, {
  lat: 10.7769,
  lng: 106.7009,
});

const booking = await postJson('/customer/bookings', customerAuth.accessToken, {
  serviceId: service.id,
  scheduledStartAt: new Date(Date.now() + 60 * 60_000).toISOString(),
  address: { line1: 'District 1, Ho Chi Minh City' },
  lat: 10.7769,
  lng: 106.7009,
  paymentMethod: 'CASH',
});

await postJson(`/provider/bookings/${booking.id}/join`, providerAuth.accessToken);

const matched = await postJson(`/customer/bookings/${booking.id}/select-provider`, customerAuth.accessToken, {
  providerId: providerAuth.user.providerProfile.id,
});

const customerBookings = await getJson('/customer/bookings', customerAuth.accessToken);
const providerBookings = await getJson('/provider/bookings', providerAuth.accessToken);
const chatRoomId = matched.booking.chatRoom.id;

const chatMessage = await postJson(`/chat/rooms/${chatRoomId}/messages`, customerAuth.accessToken, {
  body: 'Hello, see you soon.',
});

await postJson(`/provider/bookings/${booking.id}/complete`, providerAuth.accessToken);

const review = await postJson('/customer/reviews', customerAuth.accessToken, {
  bookingId: booking.id,
  rating: 5,
  comment: 'Great service.',
  tipAmount: 50000,
});

const providerEarnings = await getJson('/provider/earnings', providerAuth.accessToken);
const providerEarningsSummary = await getJson('/provider/earnings/summary', providerAuth.accessToken);
const payoutBatch = await postJson('/admin/payout-batches', adminAuth.accessToken, {
  providerProfileId: providerAuth.user.providerProfile.id,
  transferRef: `SMOKE-${Date.now()}`,
  notes: 'Created by smoke test',
});
const adminPayoutBatches = await getJson('/admin/payout-batches', adminAuth.accessToken);
const payment = await getJson('/admin/payments', adminAuth.accessToken).then((payments) =>
  payments.find((item) => item.bookingId === booking.id),
);
const refund = payment ? await postJson(`/admin/payments/${payment.id}/refund`, adminAuth.accessToken) : null;
const adminRefunds = await getJson('/admin/refunds', adminAuth.accessToken);
const notifications = await getJson('/notifications', customerAuth.accessToken);

console.log({
  ok: true,
  bookingId: booking.id,
  chatRoomId,
  customerBookingCount: customerBookings.length,
  providerBookingCount: providerBookings.length,
  chatMessageId: chatMessage.id,
  reviewId: review.id,
  earningCount: providerEarnings.length,
  providerNetAmount: providerEarningsSummary.netAmount,
  payoutBatchId: payoutBatch.id,
  payoutBatchCount: adminPayoutBatches.length,
  refundId: refund?.refunds?.at(-1)?.id ?? null,
  refundCount: adminRefunds.length,
  verificationFileId: verificationUpload.file.id,
  verificationReadStorageMode: verificationReadUrl.storageMode,
  customerNotifications: notifications.length,
  readiness,
});
