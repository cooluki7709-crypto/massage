import { AdminExternalReadiness, apiGet } from '../../lib/admin-api';

const setupOrder = [
  {
    id: 'mobile',
    title: 'Mobile Firebase removal guard',
    purpose: 'Required to keep the Flutter apps Firebase-free while Supabase migration continues.',
    env: ['customer_app', 'provider_app'],
    notes: [
      'The Flutter apps should not contain Firebase packages.',
      'Android builds should not use the Google Services Gradle plugin.',
      'Do not restore google-services.json unless the push strategy changes intentionally.',
    ],
    commands: ['node infra\\scripts\\check-mobile-firebase.mjs', 'npm.cmd run verify:local'],
  },
  {
    id: 'supabase',
    title: 'Supabase Auth and database',
    purpose: 'Required before Firebase-free production login and direct client data access.',
    env: [
      'AUTH_BACKEND',
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SUPABASE_JWT_SECRET',
      'SUPABASE_SERVICE_ROLE_KEY',
    ],
    notes: [
      'Create one Supabase project for HANDS staging first.',
      'Set AUTH_BACKEND=supabase only when Supabase Phone Auth is ready to test.',
      'Copy the project URL and anon key from Supabase project settings.',
      'Set the JWT secret on the API so access tokens can be verified server-side.',
      'Keep the service role key server-side only; it is used by admin operations to sync approved provider roles.',
    ],
    commands: [
      'npm.cmd run external:pack',
      'npm.cmd run external:check:supabase',
      '$env:SUPABASE_JWT_SECRET="<project-jwt-secret>"; $env:API_BASE_URL="http://localhost:3100/api"; npm.cmd run auth:supabase-smoke',
    ],
  },
  {
    id: 'maps',
    title: 'MapTiler and Geoapify',
    purpose: 'Required for customer address search, map pin confirmation, and nearby provider display.',
    env: ['MAPTILER_API_KEY', 'GEOAPIFY_API_KEY'],
    notes: [
      'Use MapTiler only for map tiles.',
      'Use Geoapify only for geocoding/search.',
      'No routing, directions, or realtime streaming API is needed for MVP cost control.',
    ],
    commands: [
      'npm.cmd run external:pack',
      'npm.cmd run external:check:maps',
      'powershell -ExecutionPolicy Bypass -File .\\infra\\scripts\\run-hands-emulator.ps1 -App customer',
    ],
  },
  {
    id: 'payments',
    title: 'Vietnam payment gateways',
    purpose: 'Required for real MoMo/VNPay E2E authorization, capture, release, and refund testing.',
    env: ['MOMO_PARTNER_CODE', 'MOMO_ACCESS_KEY', 'MOMO_SECRET_KEY', 'VNPAY_TMN_CODE', 'VNPAY_HASH_SECRET'],
    notes: [
      'Local smoke tests can run without merchant credentials.',
      'Use gateway sandbox credentials before any production merchant key.',
      'Keep cash payment available as an operational fallback.',
    ],
    commands: ['npm.cmd run external:check:payments', 'node infra\\scripts\\api-smoke.mjs'],
  },
  {
    id: 'notifications',
    title: 'SMS and OS push',
    purpose: 'Required before real OTP delivery and native push notifications.',
    env: ['SMS_PROVIDER', 'SMS_API_URL', 'SMS_API_KEY', 'ONESIGNAL_APP_ID'],
    notes: [
      'Local OTP can stay on SMS_PROVIDER=dev.',
      'Production OTP needs a Vietnam-capable SMS vendor.',
      'Firebase Messaging has been removed; choose OneSignal or another push provider later.',
    ],
    commands: ['npm.cmd run external:check:production', 'npm.cmd run verify:local'],
  },
  {
    id: 'storage',
    title: 'File storage and CDN',
    purpose: 'Required for provider verification files, public profile media, and moderation evidence.',
    env: ['S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY', 'S3_REGION', 'S3_PUBLIC_BASE_URL'],
    notes: [
      'Local MinIO is enough for development.',
      'Use private reads for verification files.',
      'Serve approved public provider media through a CDN base URL.',
    ],
    commands: [
      'npm.cmd run external:check:storage',
      'powershell -ExecutionPolicy Bypass -File .\\infra\\scripts\\verify-local.ps1 -WithServices',
    ],
  },
];

export default async function SetupPage() {
  const readiness = await apiGet<AdminExternalReadiness>('/health/external', {
    ok: false,
    timestamp: new Date(0).toISOString(),
    checks: [],
  });

  const summary = buildSummary(readiness);

  return (
    <>
      <section className="toolbar">
        <div>
          <h1>External setup</h1>
          <p className="muted">
            One checklist for credentials, account setup, and external services needed before production-like
            E2E.
          </p>
        </div>
        <div className="actions">
          <span className={`signal ${readiness.ok ? 'signal-ok' : 'signal-warn'}`}>
            {readiness.ok ? 'Ready for E2E' : 'Needs setup'}
          </span>
          <span className="pill pill-info">Updated {formatDate(readiness.timestamp)}</span>
        </div>
      </section>

      <section className="grid" style={{ marginBottom: 16 }}>
        <SummaryCard
          label="Ready"
          value={summary.ready}
          helper="External groups configured enough for local/E2E use."
        />
        <SummaryCard
          label="Partial"
          value={summary.partial}
          helper="Some values exist, but production values are missing."
        />
        <SummaryCard
          label="Blocked"
          value={summary.blocked}
          helper="Cannot run real E2E until required values are set."
        />
        <SummaryCard
          label="Missing values"
          value={summary.missing}
          helper="Secret values are never displayed here."
        />
      </section>

      <section className="detail-grid">
        <div className="card">
          <h2>Live readiness</h2>
          <p className="muted">
            This panel is backed by the API endpoint, so it reflects the current `.env` and process
            environment.
          </p>
          <div className="stack">
            {readiness.checks.map((check) => (
              <ReadinessRow check={check} key={`${check.category}-${check.name}`} />
            ))}
            {readiness.checks.length === 0 && (
              <div className="ops-row">
                <div>
                  <strong>Readiness API unavailable</strong>
                  <p className="muted">Start the HANDS API and refresh this page.</p>
                </div>
                <span className="pill pill-warn">BLOCKED</span>
              </div>
            )}
          </div>
        </div>

        <div className="card">
          <h2>Recommended order</h2>
          <div className="timeline">
            {setupOrder.map((group, index) => (
              <a className="timeline-step" href={`#${group.id}`} key={group.id}>
                <span>Step {index + 1}</span>
                <strong>{group.title}</strong>
                <p className="muted">{group.purpose}</p>
              </a>
            ))}
          </div>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="risk-watch-header">
          <div>
            <h2>What still needs external registration</h2>
            <p className="muted">
              This is the human-action backlog. Code checks stay green while these production keys are not
              filled.
            </p>
          </div>
          <span className={`signal ${summary.missing === 0 ? 'signal-ok' : 'signal-warn'}`}>
            {summary.missing === 0 ? 'No missing values' : `${summary.missing} value(s) pending`}
          </span>
        </div>
        <div className="setup-backlog">
          {buildExternalBacklog(readiness).map((item) => (
            <a className="setup-backlog-item" href={`#${item.groupId}`} key={`${item.groupId}-${item.name}`}>
              <span>{item.groupTitle}</span>
              <strong>{item.name}</strong>
              <p className="muted">{item.reason}</p>
            </a>
          ))}
          {buildExternalBacklog(readiness).length === 0 && (
            <p className="muted">All external readiness values are configured for the current environment.</p>
          )}
        </div>
      </section>

      <section className="stack" style={{ marginTop: 16 }}>
        {setupOrder.map((group) => {
          const relatedChecks = readiness.checks.filter((check) =>
            setupGroupMatches(group.id, check.category),
          );
          return (
            <div className="card" id={group.id} key={group.id}>
              <div className="risk-watch-header">
                <div>
                  <h2>{group.title}</h2>
                  <p className="muted">{group.purpose}</p>
                </div>
                <span className={setupGroupSignalClass(relatedChecks)}>
                  {setupGroupStatus(relatedChecks)}
                </span>
              </div>
              <div className="detail-grid" style={{ marginTop: 12 }}>
                <div>
                  <h3>Environment values</h3>
                  <div className="participant-list">
                    {group.env.map((name) => (
                      <span className={envPillClass(name, relatedChecks)} key={name}>
                        {name}
                      </span>
                    ))}
                  </div>
                </div>
                <div>
                  <h3>Implementation notes</h3>
                  <ul className="muted">
                    {group.notes.map((note) => (
                      <li key={note}>{note}</li>
                    ))}
                  </ul>
                </div>
              </div>
              <div className="setup-command-block">
                <h3>Verification commands</h3>
                <p className="muted">
                  Run from <code>C:\dev\massage-vn-workspace\repo</code>. Values inside angle brackets must be
                  replaced locally.
                </p>
                <div className="setup-command-list">
                  {group.commands.map((command) => (
                    <code key={command}>{command}</code>
                  ))}
                </div>
              </div>
            </div>
          );
        })}
      </section>
    </>
  );
}

function SummaryCard({ label, value, helper }: { label: string; value: number; helper: string }) {
  return (
    <div className="card">
      <p>{label}</p>
      <h2>{value}</h2>
      <p className="muted">{helper}</p>
    </div>
  );
}

function ReadinessRow({ check }: { check: AdminExternalReadiness['checks'][number] }) {
  return (
    <div className="ops-row">
      <div>
        <strong>{check.name}</strong>
        <p className="muted">{check.detail}</p>
        {check.configured.length > 0 && <p className="muted">Configured: {check.configured.join(', ')}</p>}
        {check.missing.length > 0 && <p className="muted">Missing: {check.missing.join(', ')}</p>}
        {(check.invalid ?? []).length > 0 && (
          <p className="muted">Invalid: {(check.invalid ?? []).join(', ')}</p>
        )}
      </div>
      <span className={`pill ${check.status === 'READY' ? 'pill-success' : 'pill-warn'}`}>
        {check.status}
      </span>
    </div>
  );
}

function buildSummary(readiness: AdminExternalReadiness) {
  return readiness.checks.reduce(
    (summary, check) => ({
      ready: summary.ready + (check.status === 'READY' ? 1 : 0),
      partial: summary.partial + (check.status === 'PARTIAL' ? 1 : 0),
      blocked: summary.blocked + (check.status === 'BLOCKED' ? 1 : 0),
      missing: summary.missing + check.missing.length + (check.invalid?.length ?? 0),
    }),
    { ready: 0, partial: 0, blocked: 0, missing: 0 },
  );
}

function buildExternalBacklog(readiness: AdminExternalReadiness) {
  return readiness.checks.flatMap((check) => {
    const group = setupOrder.find((setupGroup) => setupGroupMatches(setupGroup.id, check.category));
    const groupId = group?.id ?? 'setup';
    const groupTitle = group?.title ?? check.category;
    const missing = [...check.missing, ...(check.invalid ?? [])];
    return missing.map((name) => ({
      groupId,
      groupTitle,
      name,
      reason: check.detail,
    }));
  });
}

function setupGroupMatches(groupId: string, category: string) {
  if (groupId === 'supabase') {
    return category === 'supabase';
  }
  if (groupId === 'mobile') {
    return category === 'mobile';
  }
  if (groupId === 'notifications') {
    return category === 'sms' || category === 'push';
  }
  if (groupId === 'payments') {
    return category === 'payments';
  }
  return groupId === category;
}

function setupGroupStatus(checks: AdminExternalReadiness['checks']) {
  if (checks.length === 0) {
    return 'Not checked';
  }
  if (checks.some((check) => check.status === 'BLOCKED')) {
    return 'Blocked';
  }
  if (checks.some((check) => check.status === 'PARTIAL')) {
    return 'Partial';
  }
  return 'Ready';
}

function setupGroupSignalClass(checks: AdminExternalReadiness['checks']) {
  const status = setupGroupStatus(checks);
  return `signal ${status === 'Ready' ? 'signal-ok' : status === 'Partial' ? 'signal-info' : 'signal-warn'}`;
}

function envPillClass(name: string, checks: AdminExternalReadiness['checks']) {
  const configured = checks.some((check) => check.configured.includes(name));
  const missing = checks.some(
    (check) => check.missing.includes(name) || (check.invalid ?? []).includes(name),
  );
  if (configured) {
    return 'pill pill-success';
  }
  if (missing) {
    return 'pill pill-warn';
  }
  return 'pill pill-neutral';
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return 'unknown';
  }
  return date.toLocaleString('en-US');
}
