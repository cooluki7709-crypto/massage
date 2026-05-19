import { AdminPayment, adminGet } from '../../lib/admin-api';
import { capturePayment, refundPayment, releasePayment, syncPayment } from './actions';

export default async function PaymentsPage() {
  const payments = await adminGet<AdminPayment[]>('/admin/payments', []);

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
              <th>Provider ref</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {payments.map((payment) => (
              <tr key={payment.id}>
                <td>{payment.id}</td>
                <td>{payment.method}</td>
                <td>{payment.status}</td>
                <td>
                  {payment.amount} {payment.currency}
                </td>
                <td>
                  {payment.bookingId}
                  <div className="muted">{payment.booking?.status ?? 'UNKNOWN'}</div>
                  <div className="muted">{payment.booking?.customerProfile?.user?.phone ?? 'No customer phone'}</div>
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
                <td colSpan={7}>No payments loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

function PaymentAction({
  action,
  paymentId,
  label,
  disabled,
}: {
  action: (formData: FormData) => Promise<void>;
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
