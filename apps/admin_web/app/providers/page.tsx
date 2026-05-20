import { AdminProvider, adminGet } from '../../lib/admin-api';
import { approveProvider, rejectProvider } from './actions';

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
                      <p key={device.id} className="muted">
                        {device.platform} / {device.enabled ? 'enabled' : 'disabled'} / {maskToken(device.token)}
                      </p>
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
