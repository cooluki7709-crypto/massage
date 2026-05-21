import { AdminRefund, adminGet } from '../../lib/admin-api';
import Link from 'next/link';

export default async function RefundsPage() {
  const refunds = sortRefunds(await adminGet<AdminRefund[]>('/admin/refunds', []));

  return (
    <>
      <h1>Refunds</h1>
      <section className="grid" style={{ marginBottom: 16 }}>
        <div className="card">
          <p>Total refunds</p>
          <h2>{refunds.length}</h2>
        </div>
        <div className="card">
          <p>Requested</p>
          <h2>{refunds.filter((refund) => refund.status === 'REQUESTED').length}</h2>
        </div>
        <div className="card">
          <p>Refunded bookings</p>
          <h2>{refunds.filter((refund) => refund.booking?.status === 'REFUNDED').length}</h2>
        </div>
        <div className="card">
          <p>Needs update</p>
          <h2>{refunds.filter((refund) => refund.status === 'REQUESTED' && refund.payment?.status !== 'REFUNDED').length}</h2>
        </div>
      </section>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Refund</th>
              <th>Customer</th>
              <th>Provider</th>
              <th>Payment</th>
              <th>Booking</th>
              <th>Amount</th>
              <th>Status</th>
              <th>Ops hint</th>
            </tr>
          </thead>
          <tbody>
            {refunds.map((refund) => (
              <tr id={`refund-${refund.id}`} key={refund.id}>
                <td>{shortId(refund.id)}</td>
                <td>
                  {refund.booking?.customerProfile?.user?.fullName ??
                    refund.booking?.customerProfile?.user?.phone ??
                    'Unknown'}
                </td>
                <td>{refund.booking?.selectedProvider?.displayName ?? 'Unmatched'}</td>
                <td>
                  {refund.payment?.method} / {refund.payment?.status}
                </td>
                <td>
                  {refund.booking?.status ?? refund.bookingId}
                  <div className="muted">Booking {shortId(refund.bookingId)}</div>
                  <div className="actions" style={{ marginTop: 8 }}>
                    <Link className="text-link" href={`/bookings/${refund.bookingId}`}>
                      Open booking
                    </Link>
                    <Link className="text-link" href={`/payments#payment-${refund.paymentId}`}>
                      Open payment
                    </Link>
                  </div>
                </td>
                <td>
                  {refund.amount} {refund.payment?.currency ?? 'VND'}
                </td>
                <td>{refund.status}</td>
                <td>
                  <div>{refundOpsSignal(refund)}</div>
                  <div className="muted" style={{ marginTop: 8 }}>
                    {refundOpsHint(refund)}
                  </div>
                </td>
              </tr>
            ))}
            {refunds.length === 0 && (
              <tr>
                <td colSpan={8}>No refunds loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

function sortRefunds(refunds: AdminRefund[]) {
  return [...refunds].sort((left, right) => (right.createdAt || '').localeCompare(left.createdAt || ''));
}

function refundOpsSignal(refund: AdminRefund) {
  if (refund.status === 'REQUESTED') {
    return <span className="signal signal-warn">Customer refund requested</span>;
  }
  if (refund.status === 'COMPLETED' || refund.booking?.status === 'REFUNDED') {
    return <span className="signal signal-ok">Refund settled</span>;
  }
  return <span className="signal signal-info">Review refund</span>;
}

function refundOpsHint(refund: AdminRefund) {
  if (refund.status === 'REQUESTED') {
    return 'Confirm the payment reversal path and notify the guest once the refund is complete.';
  }
  if (refund.booking?.status === 'REFUNDED') {
    return 'Booking is already marked as refunded. Check payment ledger and customer notes.';
  }
  return 'Review this refund before closing the case.';
}

function shortId(value: string) {
  return value.slice(0, 8);
}
