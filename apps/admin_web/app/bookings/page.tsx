import { AdminBooking, adminGet } from '../../lib/admin-api';
import { BookingMonitor } from './booking-monitor';

export default async function BookingsPage() {
  const bookings = await adminGet<AdminBooking[]>('/admin/bookings', []);

  return <BookingMonitor bookings={bookings} />;
}
