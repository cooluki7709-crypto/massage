import { AdminBooking, AdminEarningSummary, AdminPayment, AdminProvider, adminGet } from '../lib/admin-api';

export default async function DashboardPage() {
  const [providers, bookings, payments, earnings] = await Promise.all([
    adminGet<AdminProvider[]>('/admin/providers', []),
    adminGet<AdminBooking[]>('/admin/bookings', []),
    adminGet<AdminPayment[]>('/admin/payments', []),
    adminGet<AdminEarningSummary>('/admin/earnings/summary', {
      count: 0,
      grossAmount: 0,
      platformFee: 0,
      tipAmount: 0,
      netAmount: 0,
      pendingNetAmount: 0,
      availableNetAmount: 0,
      paidNetAmount: 0,
      currency: 'VND',
    }),
  ]);

  const metrics = [
    ['Open matching', bookings.filter((booking) => booking.status === 'OPEN_MATCHING').length.toString()],
    ['Online providers', providers.filter((provider) => provider.status.startsWith('ONLINE')).length.toString()],
    [
      'Pending verification',
      providers.filter((provider) => provider.verification?.status === 'SUBMITTED').length.toString(),
    ],
    ['Payment holds', payments.filter((payment) => payment.status === 'AUTHORIZED').length.toString()],
    ['Provider net', `${earnings.netAmount} ${earnings.currency}`],
  ];

  return (
    <>
      <h1>Dashboard</h1>
      <section className="grid">
        {metrics.map(([label, value]) => (
          <div className="card" key={label}>
            <p>{label}</p>
            <h2>{value}</h2>
          </div>
        ))}
      </section>
      <section className="card" style={{ marginTop: 20 }}>
        <h2>Realtime Operations</h2>
        <table className="table">
          <tbody>
            <tr>
              <td>Matching monitor</td>
              <td>Provider joins, timeout, final customer selection</td>
            </tr>
            <tr>
              <td>Location monitor</td>
              <td>Provider heartbeat and active booking traces</td>
            </tr>
            <tr>
              <td>Payment monitor</td>
              <td>MoMo/VNPay authorizations, captures, refunds</td>
            </tr>
          </tbody>
        </table>
      </section>
      <p className="muted">API source: {process.env.ADMIN_API_BASE_URL ?? 'http://localhost:3000/api'}</p>
    </>
  );
}
