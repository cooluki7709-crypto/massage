import { AdminBooking, adminGet } from '../../lib/admin-api';

export default async function BookingsPage() {
  const bookings = await adminGet<AdminBooking[]>('/admin/bookings', []);

  return (
    <>
      <h1>Booking Monitor</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Booking</th>
              <th>Status</th>
              <th>Participants</th>
              <th>Payment</th>
            </tr>
          </thead>
          <tbody>
            {bookings.map((booking) => (
              <tr key={booking.id}>
                <td>{booking.id}</td>
                <td>{booking.status}</td>
                <td>{booking.participants?.length ?? 0} joined</td>
                <td>{booking.payment?.status ?? 'NONE'}</td>
              </tr>
            ))}
            {bookings.length === 0 && (
              <tr>
                <td colSpan={4}>No bookings loaded. Start the API and run the smoke flow to populate this table.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
