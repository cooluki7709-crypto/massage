import { AdminRefund, adminGet } from '../../lib/admin-api';

export default async function RefundsPage() {
  const refunds = await adminGet<AdminRefund[]>('/admin/refunds', []);

  return (
    <>
      <h1>Refunds</h1>
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
            </tr>
          </thead>
          <tbody>
            {refunds.map((refund) => (
              <tr key={refund.id}>
                <td>{refund.id}</td>
                <td>
                  {refund.booking?.customerProfile?.user?.fullName ??
                    refund.booking?.customerProfile?.user?.phone ??
                    'Unknown'}
                </td>
                <td>{refund.booking?.selectedProvider?.displayName ?? 'Unmatched'}</td>
                <td>
                  {refund.payment?.method} / {refund.payment?.status}
                </td>
                <td>{refund.booking?.status ?? refund.bookingId}</td>
                <td>
                  {refund.amount} {refund.payment?.currency ?? 'VND'}
                </td>
                <td>{refund.status}</td>
              </tr>
            ))}
            {refunds.length === 0 && (
              <tr>
                <td colSpan={7}>No refunds loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
