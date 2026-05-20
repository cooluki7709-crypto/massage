import { AdminProvider, adminGet } from '../../lib/admin-api';
import { approveProvider, enablePushDevice, rejectProvider } from './actions';

type AdminPushDevice = NonNullable<NonNullable<AdminProvider['user']>['pushDevices']>[number];

export default async function ProvidersPage() {
  const providers = await adminGet<AdminProvider[]>('/admin/providers', []);
  const fileReadUrls = new Map<string, string>();
  await Promise.all(
    providers.flatMap((provider) =>
      (provider.verification?.files ?? []).map(async (file) => {
        const result = await adminGet<{ read?: { url?: string } }>(`/files/${file.id}/read-url`, {});
        if (result.read?.url) {
          fileReadUrls.set(file.id, result.read.url);
        }
      }),
    ),
  );

  return (
    <>
      <h1>Provider Verification</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Provider</th>
              <th>Status</th>
              <th>Push Devices</th>
              <th>Files</th>
              <th>Services</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {providers.map((provider) => (
              <tr key={provider.id}>
                <td>{provider.displayName || provider.user?.fullName || provider.user?.phone}</td>
                <td>
                  {provider.verification?.status ?? 'DRAFT'}
                  {provider.verification?.rejectionReason ? (
                    <p className="muted">{provider.verification.rejectionReason}</p>
                  ) : null}
                </td>
                <td>
                  {provider.user?.pushDevices?.length ? (
                    provider.user.pushDevices.map((device) => (
                      <div key={device.id} style={{ marginBottom: 8 }}>
                        <p className="muted" style={{ marginBottom: 4 }}>
                          {device.platform} / {device.enabled ? 'enabled' : 'disabled'} / {maskToken(device.token)}
                        </p>
                        {!device.enabled ? (
                          <p className="muted" style={{ marginBottom: 4 }}>
                            Last failure: {readFailureCode(device) ?? 'Unknown'} / {readFailureStatus(device) ?? 'FAILED'}
                          </p>
                        ) : null}
                        {readLastAttempt(device) ? (
                          <p className="muted" style={{ marginBottom: 4 }}>
                            Last attempt: {new Date(readLastAttempt(device) as string).toLocaleString()}
                          </p>
                        ) : null}
                        {!device.enabled ? (
                          <form action={enablePushDevice}>
                            <input type="hidden" name="pushDeviceId" value={device.id} />
                            <button type="submit">Re-enable</button>
                          </form>
                        ) : null}
                      </div>
                    ))
                  ) : (
                    'None'
                  )}
                </td>
                <td>
                  {provider.verification?.files?.length ? (
                    provider.verification.files.map((file) => (
                      <p key={file.id} className="muted">
                        {file.contentType} /{' '}
                        {fileReadUrls.get(file.id) ? (
                          <a href={fileReadUrls.get(file.id)} target="_blank" rel="noreferrer">
                            {file.key}
                          </a>
                        ) : (
                          file.key
                        )}
                      </p>
                    ))
                  ) : (
                    'None'
                  )}
                </td>
                <td>{provider.services?.map((item) => item.service?.name).filter(Boolean).join(', ') || 'None'}</td>
                <td>
                  <div className="actions">
                    <form action={approveProvider}>
                      <input type="hidden" name="providerId" value={provider.id} />
                      <button type="submit">Approve</button>
                    </form>
                    <form action={rejectProvider}>
                      <input type="hidden" name="providerId" value={provider.id} />
                      <input type="hidden" name="reason" value="Rejected from admin dashboard" />
                      <button type="submit">Reject</button>
                    </form>
                  </div>
                </td>
              </tr>
            ))}
            {providers.length === 0 && (
              <tr>
                <td colSpan={6}>No providers loaded. Start the API and seed data to populate this table.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

function maskToken(token: string) {
  if (token.length <= 10) {
    return token;
  }
  return `${token.slice(0, 6)}...${token.slice(-4)}`;
}

function readFailureCode(device: AdminPushDevice) {
  return device.deliveries?.[0]?.response?.body?.error?.details?.[0]?.errorCode;
}

function readFailureStatus(device: AdminPushDevice) {
  return device.deliveries?.[0]?.status;
}

function readLastAttempt(device: AdminPushDevice) {
  return device.deliveries?.[0]?.attemptedAt;
}
