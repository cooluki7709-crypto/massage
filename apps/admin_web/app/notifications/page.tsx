import { AdminNotification, adminGet } from '../../lib/admin-api';

export default async function NotificationsPage() {
  const notifications = await adminGet<AdminNotification[]>('/admin/notifications', []);

  return (
    <>
      <h1>Notifications</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>User</th>
              <th>Type</th>
              <th>Title</th>
              <th>Delivery</th>
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
                        .map((delivery) => `${delivery.provider}:${delivery.status}`)
                        .join(', ')
                    : 'No devices / not attempted'}
                </td>
              </tr>
            ))}
            {notifications.length === 0 && (
              <tr>
                <td colSpan={5}>No notifications loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

