import { AdminEarning, AdminEarningSummary, adminGet } from '../../lib/admin-api';
import { createProviderPayout, markEarningPaid } from './actions';

const emptySummary: AdminEarningSummary = {
  count: 0,
  grossAmount: 0,
  platformFee: 0,
  tipAmount: 0,
  netAmount: 0,
  pendingNetAmount: 0,
  availableNetAmount: 0,
  paidNetAmount: 0,
  currency: 'VND',
};

export default async function EarningsPage() {
  const [summary, earnings] = await Promise.all([
    adminGet<AdminEarningSummary>('/admin/earnings/summary', emptySummary),
    adminGet<AdminEarning[]>('/admin/earnings', []),
  ]);

  const metrics = [
    ['Gross', summary.grossAmount],
    ['Platform fee', summary.platformFee],
    ['Tips', summary.tipAmount],
    ['Provider net', summary.netAmount],
  ];

  return (
    <>
      <h1>Provider Earnings</h1>
      <section className="grid">
        {metrics.map(([label, value]) => (
          <div className="card" key={label}>
            <p>{label}</p>
            <h2>
              {value} {summary.currency}
            </h2>
          </div>
        ))}
      </section>
      <div className="card" style={{ marginTop: 20 }}>
        <table className="table">
          <thead>
            <tr>
              <th>Provider</th>
              <th>Booking</th>
              <th>Status</th>
              <th>Gross</th>
              <th>Fee</th>
              <th>Tip</th>
              <th>Net</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {earnings.map((earning) => (
              <tr key={earning.id}>
                <td>{earning.providerProfile?.displayName ?? earning.providerProfile?.user?.phone ?? 'Unknown'}</td>
                <td>{earning.bookingId}</td>
                <td>{earning.status}</td>
                <td>{earning.grossAmount}</td>
                <td>{earning.platformFee}</td>
                <td>{earning.tipAmount}</td>
                <td>
                  {earning.netAmount} {earning.currency}
                </td>
                <td>
                  <form action={markEarningPaid}>
                    <input type="hidden" name="earningId" value={earning.id} />
                    <button type="submit" disabled={earning.status === 'PAID' || earning.status === 'CANCELLED'}>
                      Mark paid
                    </button>
                  </form>
                  {earning.providerProfile && earning.status !== 'PAID' && earning.status !== 'CANCELLED' && (
                    <form action={createProviderPayout} style={{ marginTop: 6 }}>
                      <input type="hidden" name="providerProfileId" value={earning.providerProfileId} />
                      <input type="hidden" name="transferRef" value={`MVP-${earning.providerProfileId}`} />
                      <button type="submit">Batch payout</button>
                    </form>
                  )}
                </td>
              </tr>
            ))}
            {earnings.length === 0 && (
              <tr>
                <td colSpan={8}>No earnings loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
