import { AdminPayment, adminGet } from '../../lib/admin-api';
import { refundPayment } from './actions';

export default async function PaymentsPage() {
  const payments = await adminGet<AdminPayment[]>('/admin/payments', []);

  return (
    <>
      <h1>Payments</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Payment</th>
              <th>Method</th>
              <th>Status</th>
              <th>Amount</th>
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
                  <form action={refundPayment}>
                    <input type="hidden" name="paymentId" value={payment.id} />
                    <button type="submit" disabled={payment.status === 'REFUNDED'}>
                      Refund
                    </button>
                  </form>
                </td>
              </tr>
            ))}
            {payments.length === 0 && (
              <tr>
                <td colSpan={5}>No payments loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
