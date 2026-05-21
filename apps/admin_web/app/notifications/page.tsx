import { AdminNotification, adminGet } from '../../lib/admin-api';
import { retryNotification } from './actions';

export default async function NotificationsPage() {
  const notifications = sortNotifications(await adminGet<AdminNotification[]>('/admin/notifications', []));
  const summary = buildSummary(notifications);

  return (
    <>
      <h1>Notifications</h1>
      <section className="grid" style={{ marginBottom: 16 }}>
        <div className="card">
          <p>Total</p>
          <h2>{notifications.length}</h2>
        </div>
        <div className="card">
          <p>Needs retry</p>
          <h2>{summary.needsRetry}</h2>
        </div>
        <div className="card">
          <p>Sent</p>
          <h2>{summary.sent}</h2>
        </div>
        <div className="card">
          <p>Skipped</p>
          <h2>{summary.skipped}</h2>
        </div>
        <div className="card">
          <p>Failed</p>
          <h2>{summary.failed}</h2>
        </div>
      </section>
      <div className="card">
        <div className="toolbar">
          <div>
            <p className="muted">Delivery board for push retries, disabled devices, and last-mile alert confidence.</p>
          </div>
          <div className="participant-list">
            <span className="pill pill-success">Latest failures first</span>
            <span className="pill pill-info">Delivery signal</span>
            <span className="pill pill-warn">Retry readiness</span>
          </div>
        </div>

        <table className="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>User</th>
              <th>Type</th>
              <th>Title</th>
              <th>Ops signal</th>
              <th>Delivery</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {notifications.map((notification) => (
              <tr key={notification.id}>
                <td>
                  <div>{new Date(notification.createdAt).toLocaleString()}</div>
                  <div className="muted">{relativeTime(notification.createdAt)}</div>
                </td>
                <td>
                  <div>{notification.user?.fullName ?? notification.user?.phone ?? '-'}</div>
                  <div className="muted">{notification.user?.phone ?? 'No phone on file'}</div>
                </td>
                <td>
                  <div>{humanizeType(notification.type)}</div>
                  <div className="muted">{typeMeaning(notification.type)}</div>
                </td>
                <td>
                  <div>{notification.title}</div>
                  <div className="muted" style={{ marginTop: 6 }}>
                    {notification.body}
                  </div>
                </td>
                <td>
                  <span className={signalClass(notification)}>{opsSignal(notification)}</span>
                  <div className="muted" style={{ marginTop: 6 }}>
                    {opsHint(notification)}
                  </div>
                </td>
                <td>
                  {notification.deliveries && notification.deliveries.length > 0
                    ? notification.deliveries.map((delivery) => (
                        <div key={delivery.id ?? `${notification.id}-${delivery.attemptedAt}`} style={{ marginBottom: 10 }}>
                          <div>
                            <strong>{delivery.provider}</strong> - {delivery.status} - {delivery.pushDevice?.platform ?? 'device'}
                          </div>
                          <div className="muted" style={{ marginTop: 4 }}>
                            {delivery.pushDevice?.enabled === false ? 'Device disabled' : 'Device enabled'} - Attempted{' '}
                            {new Date(delivery.attemptedAt).toLocaleString()}
                          </div>
                          <div className="muted" style={{ marginTop: 4 }}>
                            Failure {readFailureCode(delivery) ?? '-'} / HTTP {delivery.response?.statusCode ?? '-'}
                          </div>
                          <div className="muted" style={{ marginTop: 4 }}>
                            Token {delivery.pushDevice?.token ? maskToken(delivery.pushDevice.token) : '-'}
                          </div>
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
                <td colSpan={7}>No notifications loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

function sortNotifications(notifications: AdminNotification[]) {
  return [...notifications].sort((left, right) => {
    const signalDiff = notificationPriority(right) - notificationPriority(left);
    if (signalDiff !== 0) {
      return signalDiff;
    }
    return Date.parse(right.createdAt) - Date.parse(left.createdAt);
  });
}

function notificationPriority(notification: AdminNotification) {
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'FAILED')) {
    return 4;
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.pushDevice?.enabled === false)) {
    return 3;
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'SKIPPED')) {
    return 2;
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'SENT')) {
    return 1;
  }
  return 0;
}

function buildSummary(notifications: AdminNotification[]) {
  return {
    needsRetry: notifications.filter((notification) => needsRetry(notification)).length,
    sent: countDeliveries(notifications, 'SENT'),
    skipped: countDeliveries(notifications, 'SKIPPED'),
    failed: countDeliveries(notifications, 'FAILED'),
  };
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

function relativeTime(value: string) {
  const diffMs = Date.now() - Date.parse(value);
  if (!Number.isFinite(diffMs)) {
    return 'Unknown time';
  }
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) {
    return 'Updated just now';
  }
  if (minutes < 60) {
    return `${minutes}m ago`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours}h ago`;
  }
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function humanizeType(type: string) {
  return type
    .toLowerCase()
    .split(/[_\-.]/g)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function typeMeaning(type: string) {
  if (type.includes('booking')) {
    return 'Booking lifecycle alert';
  }
  if (type.includes('payment')) {
    return 'Payment or refund alert';
  }
  if (type.includes('chat')) {
    return 'Realtime conversation alert';
  }
  return 'Operational customer or therapist alert';
}

function needsRetry(notification: AdminNotification) {
  return (notification.deliveries ?? []).some(
    (delivery) => delivery.status === 'FAILED' || delivery.pushDevice?.enabled === false,
  );
}

function signalClass(notification: AdminNotification) {
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'FAILED')) {
    return 'signal signal-warn';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.pushDevice?.enabled === false)) {
    return 'signal signal-warn';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'SENT')) {
    return 'signal signal-ok';
  }
  return 'signal signal-info';
}

function opsSignal(notification: AdminNotification) {
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'FAILED')) {
    return 'Retry needed';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.pushDevice?.enabled === false)) {
    return 'Device disabled';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'SKIPPED')) {
    return 'Skipped delivery';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'SENT')) {
    return 'Delivered';
  }
  return 'Pending';
}

function opsHint(notification: AdminNotification) {
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'FAILED')) {
    return 'Review failure code, confirm token health, then retry only after the device path makes sense.';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.pushDevice?.enabled === false)) {
    return 'This user has at least one disabled push device. Re-enable only if a fresh token arrives.';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'SKIPPED')) {
    return 'Skipped alerts usually mean no available push path or a delivery decision to avoid duplicate sends.';
  }
  if ((notification.deliveries ?? []).some((delivery) => delivery.status === 'SENT')) {
    return 'Delivery path is healthy. Use this row as a reference if the user still reports a miss.';
  }
  return 'Notification exists, but no delivery attempt was captured yet.';
}
