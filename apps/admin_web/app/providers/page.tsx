import { AdminProvider, adminGet } from '../../lib/admin-api';
import { approveProvider, enablePushDevice, rejectProvider, syncSupabaseProviderRole } from './actions';

type AdminPushDevice = NonNullable<NonNullable<AdminProvider['user']>['pushDevices']>[number];

export default async function ProvidersPage() {
  const providers = sortProviders(await adminGet<AdminProvider[]>('/admin/providers', []));
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
  const summary = buildProviderSummary(providers);

  return (
    <>
      <h1>Provider Verification</h1>
      <div className="grid" style={{ marginBottom: 16 }}>
        {summary.map(([label, value]) => (
          <div className="card" key={label}>
            <p>{label}</p>
            <h2>{value}</h2>
          </div>
        ))}
      </div>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Provider</th>
              <th>Status</th>
              <th>Ops readiness</th>
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
                  <p className="muted" style={{ marginTop: 4 }}>
                    Queue status: {provider.status}
                  </p>
                </td>
                <td>
                  <div className="participant-list" style={{ marginBottom: 8 }}>
                    <span
                      className={`pill ${provider.verification?.status === 'APPROVED' ? 'pill-success' : 'pill-warn'}`}
                    >
                      {provider.verification?.status === 'APPROVED' ? 'Verified' : 'Needs review'}
                    </span>
                    <span
                      className={`pill ${provider.status === 'ONLINE_AVAILABLE' ? 'pill-success' : 'pill-neutral'}`}
                    >
                      {provider.status === 'ONLINE_AVAILABLE' ? 'Online now' : 'Not live'}
                    </span>
                    <span className={`pill ${hasHealthyPush(provider) ? 'pill-success' : 'pill-info'}`}>
                      {hasHealthyPush(provider) ? 'Push ready' : 'Push missing'}
                    </span>
                    <span
                      className={`pill ${provider.user?.supabaseUserId ? 'pill-success' : 'pill-neutral'}`}
                    >
                      {provider.user?.supabaseUserId ? 'Supabase linked' : 'Nest auth only'}
                    </span>
                  </div>
                  <p className="muted">{providerActionHint(provider)}</p>
                </td>
                <td>
                  {provider.user?.pushDevices?.length
                    ? provider.user.pushDevices.map((device) => (
                        <div key={device.id} style={{ marginBottom: 8 }}>
                          <p className="muted" style={{ marginBottom: 4 }}>
                            {device.platform} / {device.enabled ? 'enabled' : 'disabled'} /{' '}
                            {maskToken(device.token)}
                          </p>
                          {!device.enabled ? (
                            <p className="muted" style={{ marginBottom: 4 }}>
                              Last failure: {readFailureCode(device) ?? 'Unknown'} /{' '}
                              {readFailureStatus(device) ?? 'FAILED'}
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
                    : 'None'}
                </td>
                <td>
                  {provider.verification?.files?.length
                    ? provider.verification.files.map((file) => (
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
                    : 'None'}
                </td>
                <td>
                  {provider.services
                    ?.map((item) => item.service?.name)
                    .filter(Boolean)
                    .join(', ') || 'None'}
                </td>
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
                    <form action={syncSupabaseProviderRole}>
                      <input type="hidden" name="providerId" value={provider.id} />
                      <button type="submit" disabled={provider.verification?.status !== 'APPROVED'}>
                        Sync Supabase role
                      </button>
                    </form>
                  </div>
                </td>
              </tr>
            ))}
            {providers.length === 0 && (
              <tr>
                <td colSpan={7}>No providers loaded. Start the API and seed data to populate this table.</td>
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

function hasHealthyPush(provider: AdminProvider) {
  return (provider.user?.pushDevices ?? []).some((device) => device.enabled);
}

function providerActionHint(provider: AdminProvider) {
  if (provider.verification?.status !== 'APPROVED') {
    return 'Review verification before this therapist can safely take customer requests.';
  }
  if (provider.status !== 'ONLINE_AVAILABLE') {
    return 'Therapist is approved but not currently online for direct or backup requests.';
  }
  if (!hasHealthyPush(provider)) {
    return 'Therapist is live, but push registration should be checked before relying on alerts.';
  }
  if (!provider.user?.supabaseUserId) {
    return 'Therapist is operational in Nest auth. Supabase role sync will become available after Supabase OTP login links this phone.';
  }
  return 'Therapist is ready for direct requests and fallback matching.';
}

function buildProviderSummary(providers: AdminProvider[]) {
  const approved = providers.filter((provider) => provider.verification?.status === 'APPROVED').length;
  const online = providers.filter((provider) => provider.status === 'ONLINE_AVAILABLE').length;
  const pushReady = providers.filter((provider) => hasHealthyPush(provider)).length;
  const pushDisabled = providers.filter((provider) =>
    (provider.user?.pushDevices ?? []).some((device) => !device.enabled),
  ).length;
  const readyNow = providers.filter(
    (provider) =>
      provider.verification?.status === 'APPROVED' &&
      provider.status === 'ONLINE_AVAILABLE' &&
      hasHealthyPush(provider),
  ).length;

  return [
    ['Total therapists', providers.length.toString()],
    ['Approved', approved.toString()],
    ['Online now', online.toString()],
    ['Push ready', pushReady.toString()],
    ['Push needs review', pushDisabled.toString()],
    ['Ready for dispatch', readyNow.toString()],
  ] as const;
}

function sortProviders(providers: AdminProvider[]) {
  return [...providers].sort((left, right) => {
    const leftScore = providerPriority(left);
    const rightScore = providerPriority(right);
    if (leftScore !== rightScore) {
      return rightScore - leftScore;
    }

    return (left.displayName || left.user?.fullName || left.user?.phone || '').localeCompare(
      right.displayName || right.user?.fullName || right.user?.phone || '',
    );
  });
}

function providerPriority(provider: AdminProvider) {
  if (
    provider.verification?.status === 'APPROVED' &&
    provider.status === 'ONLINE_AVAILABLE' &&
    hasHealthyPush(provider)
  ) {
    return 4;
  }
  if (provider.verification?.status === 'APPROVED' && provider.status === 'ONLINE_AVAILABLE') {
    return 3;
  }
  if (provider.verification?.status === 'APPROVED') {
    return 2;
  }
  return 1;
}
