import { AdminNotification, adminGet } from '../../lib/admin-api';
import { retryNotification } from './actions';

export default async function NotificationsPage() {
  const notifications = await adminGet<AdminNotification[]>('/admin/notifications', []);

  return (
    <>
      <h1>Notifications</h1>
      <section className="grid" style={{ marginBottom: 16 }}>
        <div className="card">
          <p>Total</p>
          <h2>{notifications.length}</h2>
        </div>
        <div className="card">
          <p>Sent</p>
          <h2>{countDeliveries(notifications, 'SENT')}</h2>
        </div>
        <div className="card">
          <p>Skipped</p>
          <h2>{countDeliveries(notifications, 'SKIPPED')}</h2>
        </div>
        <div className="card">
          <p>Failed</p>
          <h2>{countDeliveries(notifications, 'FAILED')}</h2>
        </div>
      </section>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>User</th>
              <th>Type</th>
              <th>Title</th>
              <th>Delivery</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {notifications.map((notification) => (
              <tr key={notification.id}>
                <td>{new Date(notification.createdAt).toLocaleString()}</td>
                <td>{notification.user?.fullName ?? notification.user?.phone ?? '-'}</td>
                <td>{notification.type}</td>
                <td>{notification.title}</td>
                <td>
                  {notification.deliveries && notification.deliveries.length > 0
                    ? notification.deliveries
                        .map((delivery) => `${delivery.provider}:${delivery.status}:${delivery.pushDevice?.platform ?? 'device'}`)
                        .join(', ')
                    : 'No devices / not attempted'}
                </td>
                <td>
                  <form action={retryNotification}>
                    <input type="hidden" name="notificationId" value={notification.id} />
                    <button type="submit">Retry</button>
                  </form>
                </td>
              </tr>
            ))}
            {notifications.length === 0 && (
              <tr>
                <td colSpan={6}>No notifications loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

function countDeliveries(notifications: AdminNotification[], status: string) {
  return notifications.reduce(
    (total, notification) => total + (notification.deliveries ?? []).filter((delivery) => delivery.status === status).length,
    0,
  );
}
