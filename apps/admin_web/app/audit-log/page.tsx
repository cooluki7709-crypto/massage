import { AdminAuditLog, adminGet } from '../../lib/admin-api';

export default async function AuditLogPage() {
  const logs = await adminGet<AdminAuditLog[]>('/admin/audit-logs', []);

  return (
    <>
      <h1>Audit Log</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Actor</th>
              <th>Action</th>
              <th>Target</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id}>
                <td>{new Date(log.createdAt).toLocaleString()}</td>
                <td>{log.actor?.fullName ?? log.actor?.phone ?? '-'}</td>
                <td>{log.action}</td>
                <td>{log.target}</td>
              </tr>
            ))}
            {logs.length === 0 && (
              <tr>
                <td colSpan={4}>No audit logs loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
