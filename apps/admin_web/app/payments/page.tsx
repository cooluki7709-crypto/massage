import { AdminPayment, adminGet } from '../../lib/admin-api';
import Link from 'next/link';
import { capturePayment, refundPayment, releasePayment, syncPayment } from './actions';

export default async function PaymentsPage() {
  const payments = sortPayments(await adminGet<AdminPayment[]>('/admin/payments', []));

  return (
    <>
      <h1>Payments</h1>
      <section className="grid" style={{ marginBottom: 16 }}>
        <div className="card">
          <p>Authorized</p>
          <h2>{payments.filter((payment) => payment.status === 'AUTHORIZED').length}</h2>
        </div>
        <div className="card">
          <p>Pending cash</p>
          <h2>{payments.filter((payment) => payment.method === 'CASH' && payment.status === 'PENDING').length}</h2>
        </div>
        <div className="card">
          <p>Captured</p>
          <h2>{payments.filter((payment) => payment.status === 'CAPTURED').length}</h2>
        </div>
        <div className="card">
          <p>Refunded</p>
          <h2>{payments.filter((payment) => payment.status === 'REFUNDED').length}</h2>
        </div>
        <div className="card">
          <p>Needs action</p>
          <h2>{payments.filter((payment) => paymentOpsState(payment) !== 'settled').length}</h2>
        </div>
        <div className="card">
          <p>Linked refunds</p>
          <h2>{payments.reduce((total, payment) => total + (payment.refunds?.length ?? 0), 0)}</h2>
        </div>
      </section>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Payment</th>
              <th>Method</th>
              <th>Status</th>
              <th>Amount</th>
              <th>Booking</th>
              <th>Ops hint</th>
              <th>Provider ref</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {payments.map((payment) => (
              <tr id={`payment-${payment.id}`} key={payment.id}>
                <td>{payment.id}</td>
                <td>{payment.method}</td>
                <td>
                  {payment.status}
                  <div className="muted">{paymentStateLabel(payment)}</div>
                </td>
                <td>
                  {payment.amount} {payment.currency}
                </td>
                <td>
                  {shortId(payment.bookingId)}
                  <div className="muted">{payment.booking?.status ?? 'UNKNOWN'}</div>
                  <div className="muted">{payment.booking?.customerProfile?.user?.phone ?? 'No customer phone'}</div>
                  <div className="actions" style={{ marginTop: 8 }}>
                    <Link className="text-link" href={`/bookings#booking-${payment.bookingId}`}>
                      Open booking
                    </Link>
                    {payment.refunds?.at(0)?.id && (
                      <Link className="text-link" href={`/refunds#refund-${payment.refunds[0].id}`}>
                        Open refund
                      </Link>
                    )}
                  </div>
                </td>
                <td>
                  <div>{paymentOpsSignal(payment)}</div>
                  <div className="muted" style={{ marginTop: 8 }}>
                    {paymentOpsHint(payment)}
                  </div>
                </td>
                <td>{payment.providerRef ?? 'NONE'}</td>
                <td>
                  <div className="actions">
                    <PaymentAction action={syncPayment} paymentId={payment.id} label="Sync" disabled={!payment.providerRef} />
                    <PaymentAction
                      action={capturePayment}
                      paymentId={payment.id}
                      label="Capture"
                      disabled={payment.status === 'CAPTURED' || payment.status === 'REFUNDED' || payment.status === 'RELEASED'}
                    />
                    <PaymentAction
                      action={releasePayment}
                      paymentId={payment.id}
                      label="Release"
                      disabled={payment.status === 'CAPTURED' || payment.status === 'REFUNDED' || payment.status === 'RELEASED'}
                    />
                    <PaymentAction
                      action={refundPayment}
                      paymentId={payment.id}
                      label="Refund"
                      disabled={payment.status === 'REFUNDED' || payment.status === 'RELEASED'}
                    />
                  </div>
                </td>
              </tr>
            ))}
            {payments.length === 0 && (
              <tr>
                <td colSpan={8}>No payments loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

function sortPayments(payments: AdminPayment[]) {
  return [...payments].sort((left, right) => {
    const leftScore = paymentPriority(left);
    const rightScore = paymentPriority(right);
    if (leftScore !== rightScore) {
      return rightScore - leftScore;
    }

    return (right.id || '').localeCompare(left.id || '');
  });
}

function paymentPriority(payment: AdminPayment) {
  if (payment.status === 'AUTHORIZED') {
    return 5;
  }
  if (payment.method === 'CASH' && payment.status === 'PENDING') {
    return 4;
  }
  if (payment.status === 'REFUNDED') {
    return 2;
  }
  if (payment.status === 'CAPTURED' || payment.status === 'RELEASED') {
    return 1;
  }
  return 3;
}

function paymentOpsState(payment: AdminPayment) {
  if (payment.status === 'CAPTURED' || payment.status === 'RELEASED' || payment.status === 'REFUNDED') {
    return 'settled';
  }
  if (payment.status === 'AUTHORIZED') {
    return 'capture';
  }
  if (payment.method === 'CASH' && payment.status === 'PENDING') {
    return 'collect-cash';
  }
  return 'monitor';
}

function paymentStateLabel(payment: AdminPayment) {
  if (payment.status === 'AUTHORIZED') {
    return 'Hold placed, waiting for service completion.';
  }
  if (payment.method === 'CASH' && payment.status === 'PENDING') {
    return 'Collect cash when the service starts or completes.';
  }
  if (payment.status === 'CAPTURED') {
    return 'Funds captured successfully.';
  }
  if (payment.status === 'RELEASED') {
    return 'Hold released without capture.';
  }
  if (payment.status === 'REFUNDED') {
    return 'Refund path already started.';
  }
  return 'Monitor payment progression.';
}

function paymentOpsSignal(payment: AdminPayment) {
  if (payment.status === 'AUTHORIZED') {
    return <span className="signal signal-warn">Capture after service</span>;
  }
  if (payment.method === 'CASH' && payment.status === 'PENDING') {
    return <span className="signal signal-info">Cash collection</span>;
  }
  if (payment.status === 'REFUNDED') {
    return <span className="signal signal-warn">Refund in motion</span>;
  }
  if (payment.status === 'CAPTURED' || payment.status === 'RELEASED') {
    return <span className="signal signal-ok">Settled</span>;
  }
  return <span className="signal signal-info">Watch payment</span>;
}

function paymentOpsHint(payment: AdminPayment) {
  if (payment.status === 'AUTHORIZED') {
    return 'Keep this on hold until the therapist completes the service, then capture or refund.';
  }
  if (payment.method === 'CASH' && payment.status === 'PENDING') {
    return 'Cash booking. Confirm therapist arrival and mark the booking complete after payment is collected.';
  }
  if (payment.status === 'REFUNDED') {
    return 'Check the linked refund record and customer communication.';
  }
  if (payment.status === 'RELEASED') {
    return 'Booking did not convert. Confirm the customer sees the hold release.';
  }
  return 'No urgent action required.';
}

function shortId(value: string) {
  return value.slice(0, 8);
}

function PaymentAction({
  action,
  paymentId,
  label,
  disabled,
}: {
  action: (...args: [FormData]) => Promise<void>;
  paymentId: string;
  label: string;
  disabled?: boolean;
}) {
  return (
    <form action={action}>
      <input type="hidden" name="paymentId" value={paymentId} />
      <button type="submit" disabled={disabled}>
        {label}
      </button>
    </form>
  );
}
