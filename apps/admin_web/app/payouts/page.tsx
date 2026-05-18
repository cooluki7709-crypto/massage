import { AdminPayoutBatch, adminGet } from '../../lib/admin-api';

export default async function PayoutsPage() {
  const batches = await adminGet<AdminPayoutBatch[]>('/admin/payout-batches', []);

  return (
    <>
      <h1>Payout Batches</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Batch</th>
              <th>Provider</th>
              <th>Status</th>
              <th>Transfer Ref</th>
              <th>Earnings</th>
              <th>Total</th>
              <th>Paid At</th>
            </tr>
          </thead>
          <tbody>
            {batches.map((batch) => (
              <tr key={batch.id}>
                <td>{batch.id}</td>
                <td>{batch.providerProfile?.displayName ?? batch.providerProfile?.user?.phone ?? 'Unknown'}</td>
                <td>{batch.status}</td>
                <td>{batch.transferRef ?? '-'}</td>
                <td>{batch.earnings?.length ?? 0}</td>
                <td>
                  {batch.totalNetAmount} {batch.currency}
                </td>
                <td>{batch.paidAt ? new Date(batch.paidAt).toLocaleString() : '-'}</td>
              </tr>
            ))}
            {batches.length === 0 && (
              <tr>
                <td colSpan={7}>No payout batches loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
