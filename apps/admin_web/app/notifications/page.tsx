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
                    ? notification.deliveries.map((delivery) => (
                        <div key={delivery.id ?? `${notification.id}-${delivery.attemptedAt}`} style={{ marginBottom: 8 }}>
                          <p className="muted" style={{ marginBottom: 4 }}>
                            {delivery.provider}:{delivery.status}:{delivery.pushDevice?.platform ?? 'device'} /{' '}
                            {delivery.pushDevice?.enabled === false ? 'device-disabled' : 'device-enabled'}
                          </p>
                          <p className="muted" style={{ marginBottom: 4 }}>
                            Failure: {readFailureCode(delivery) ?? '-'} / HTTP {delivery.response?.statusCode ?? '-'}
                          </p>
                          <p className="muted" style={{ marginBottom: 4 }}>
                            Token: {delivery.pushDevice?.token ? maskToken(delivery.pushDevice.token) : '-'}
                          </p>
                          <p className="muted">Attempted: {new Date(delivery.attemptedAt).toLocaleString()}</p>
                        </div>
                      ))
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

function readFailureCode(delivery: NonNullable<AdminNotification['deliveries']>[number]) {
  return delivery.response?.body?.error?.details?.[0]?.errorCode;
}

function maskToken(token: string) {
  if (token.length <= 10) {
    return token;
  }
  return `${token.slice(0, 6)}...${token.slice(-4)}`;
}
