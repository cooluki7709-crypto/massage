import { AdminCoupon, adminGet } from '../../lib/admin-api';
import { createCoupon, toggleCoupon } from './actions';

export default async function CouponsPage() {
  const coupons = await adminGet<AdminCoupon[]>('/admin/coupons', []);
  const orderedCoupons = [...coupons].sort((left, right) => couponPriority(right) - couponPriority(left));
  const activeCoupons = orderedCoupons.filter((coupon) => coupon.active && couponWindowState(coupon) !== 'expired');
  const scheduledCoupons = orderedCoupons.filter((coupon) => coupon.active && couponWindowState(coupon) === 'scheduled');
  const expiredCoupons = orderedCoupons.filter((coupon) => couponWindowState(coupon) === 'expired');

  return (
    <>
      <h1>Coupons</h1>
      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 16,
          marginBottom: 20,
        }}
      >
        <SummaryCard label="Total" value={String(orderedCoupons.length)} hint="Coupons loaded for admin review." />
        <SummaryCard label="Active" value={String(activeCoupons.length)} hint="Live or upcoming discounts." />
        <SummaryCard label="Scheduled" value={String(scheduledCoupons.length)} hint="Approved, but start time is still ahead." />
        <SummaryCard label="Expired" value={String(expiredCoupons.length)} hint="Candidates for pause or cleanup." />
      </section>
      <section className="card">
        <h2>Create Coupon</h2>
        <form className="form-row" action={createCoupon}>
          <input name="code" placeholder="WELCOME10" />
          <input name="description" placeholder="Description" />
          <input name="percent" type="number" min="1" max="100" placeholder="%" />
          <input name="startsAt" type="datetime-local" />
          <input name="endsAt" type="datetime-local" />
          <button type="submit">Create</button>
        </form>
      </section>
      <section className="card" style={{ marginTop: 20 }}>
        <table className="table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Description</th>
              <th>Discount</th>
              <th>Status</th>
              <th>Window</th>
              <th>Ops hint</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {orderedCoupons.map((coupon) => (
              <tr key={coupon.id}>
                <td>{coupon.code}</td>
                <td>{coupon.description ?? '-'}</td>
                <td>{formatDiscount(coupon.discount)}</td>
                <td>
                  <div>{couponStatusLabel(coupon)}</div>
                  <div style={{ color: '#6b7280', fontSize: 12 }}>{couponWindowSignal(coupon)}</div>
                </td>
                <td>{couponWindowLabel(coupon)}</td>
                <td>{couponOpsHint(coupon)}</td>
                <td>
                  <form action={toggleCoupon}>
                    <input type="hidden" name="couponId" value={coupon.id} />
                    <input type="hidden" name="active" value={String(coupon.active)} />
                    <button type="submit">{coupon.active ? 'Pause' : 'Activate'}</button>
                  </form>
                </td>
              </tr>
            ))}
            {coupons.length === 0 && (
              <tr>
                <td colSpan={7}>No coupons loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </section>
    </>
  );
}

function SummaryCard({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <section className="card" style={{ marginTop: 0 }}>
      <div style={{ color: '#6b7280', fontSize: 12, textTransform: 'uppercase', letterSpacing: '0.08em' }}>{label}</div>
      <div style={{ fontSize: 32, fontWeight: 700, marginTop: 8 }}>{value}</div>
      <div style={{ color: '#6b7280', marginTop: 8 }}>{hint}</div>
    </section>
  );
}

function couponPriority(coupon: AdminCoupon) {
  const windowState = couponWindowState(coupon);
  if (coupon.active && windowState === 'live') {
    return 5;
  }
  if (coupon.active && windowState === 'scheduled') {
    return 4;
  }
  if (coupon.active && windowState === 'expired') {
    return 3;
  }
  return 1;
}

function couponWindowState(coupon: AdminCoupon): 'draft' | 'scheduled' | 'live' | 'expired' {
  const now = Date.now();
  const startsAt = coupon.startsAt ? new Date(coupon.startsAt).getTime() : null;
  const endsAt = coupon.endsAt ? new Date(coupon.endsAt).getTime() : null;

  if (endsAt && endsAt < now) {
    return 'expired';
  }
  if (startsAt && startsAt > now) {
    return 'scheduled';
  }
  if (!coupon.active) {
    return 'draft';
  }
  return 'live';
}

function couponStatusLabel(coupon: AdminCoupon) {
  const windowState = couponWindowState(coupon);
  if (!coupon.active) {
    return 'PAUSED';
  }
  if (windowState === 'scheduled') {
    return 'SCHEDULED';
  }
  if (windowState === 'expired') {
    return 'EXPIRED';
  }
  return 'ACTIVE';
}

function couponWindowSignal(coupon: AdminCoupon) {
  const windowState = couponWindowState(coupon);
  if (windowState === 'scheduled') {
    return 'Waiting for start window.';
  }
  if (windowState === 'expired') {
    return 'Past end date.';
  }
  if (!coupon.active) {
    return 'Paused by admin.';
  }
  return 'Live for booking checkout.';
}

function couponWindowLabel(coupon: AdminCoupon) {
  const start = coupon.startsAt ? formatDate(coupon.startsAt) : 'Immediate';
  const end = coupon.endsAt ? formatDate(coupon.endsAt) : 'No end date';
  return `${start} -> ${end}`;
}

function couponOpsHint(coupon: AdminCoupon) {
  const windowState = couponWindowState(coupon);
  if (windowState === 'expired') {
    return coupon.active ? 'Pause or replace this expired code.' : 'Ready for cleanup or replacement.';
  }
  if (windowState === 'scheduled') {
    return 'Leave active so it goes live on schedule.';
  }
  if (!coupon.active) {
    return 'Re-activate when the campaign should return.';
  }
  return 'Safe to use in customer checkout now.';
}

function formatDiscount(discount: unknown) {
  if (!discount || typeof discount !== 'object') {
    return 'Unknown';
  }
  const input = discount as { type?: string; value?: number | string };
  const value = typeof input.value === 'string' ? Number(input.value) : input.value;
  if (input.type === 'percent' && Number.isFinite(value)) {
    return `${value}% off`;
  }
  return JSON.stringify(discount);
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en-GB', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}
