import { AdminPayoutBatch, adminGet } from '../../lib/admin-api';

export default async function PayoutsPage() {
  const batches = sortBatches(await adminGet<AdminPayoutBatch[]>('/admin/payout-batches', []));
  const summary = buildSummary(batches);

  return (
    <>
      <h1>Payout Batches</h1>
      <section className="grid" style={{ marginBottom: 16 }}>
        <div className="card">
          <p>Total batches</p>
          <h2>{summary.total}</h2>
        </div>
        <div className="card">
          <p>Needs review</p>
          <h2>{summary.needsReview}</h2>
        </div>
        <div className="card">
          <p>Ready to transfer</p>
          <h2>{summary.readyToTransfer}</h2>
        </div>
        <div className="card">
          <p>Settled</p>
          <h2>{summary.settled}</h2>
        </div>
        <div className="card">
          <p>Total net</p>
          <h2>
            {summary.totalNetAmount} {summary.currency}
          </h2>
        </div>
      </section>

      <div className="card">
        <div className="toolbar">
          <div>
            <p className="muted">Provider settlement batches ordered so unresolved money movement stays at the top.</p>
          </div>
          <div className="participant-list">
            <span className="pill pill-success">Newest active first</span>
            <span className="pill pill-info">Payout signal</span>
            <span className="pill pill-warn">Transfer readiness</span>
          </div>
        </div>

        <table className="table">
          <thead>
            <tr>
              <th>Batch</th>
              <th>Provider</th>
              <th>Status</th>
              <th>Ops signal</th>
              <th>Transfer ref</th>
              <th>Earnings</th>
              <th>Total</th>
              <th>Paid at</th>
            </tr>
          </thead>
          <tbody>
            {batches.map((batch) => (
              <tr key={batch.id}>
                <td>
                  <div>{shortId(batch.id)}</div>
                  <div className="muted">{relativeTime(batch.createdAt)}</div>
                </td>
                <td>
                  <div>{batch.providerProfile?.displayName ?? batch.providerProfile?.user?.phone ?? 'Unknown'}</div>
                  <div className="muted">{batch.providerProfile?.user?.phone ?? 'No phone on file'}</div>
                </td>
                <td>
                  <div>{humanizeStatus(batch.status)}</div>
                  <div className="muted">{payoutPhase(batch.status)}</div>
                </td>
                <td>
                  <span className={signalClass(batch.status)}>{opsSignal(batch)}</span>
                  <div className="muted" style={{ marginTop: 6 }}>
                    {opsHint(batch)}
                  </div>
                </td>
                <td>
                  <div>{batch.transferRef ?? '-'}</div>
                  <div className="muted">{batch.notes?.trim() ? batch.notes : 'No transfer notes'}</div>
                </td>
                <td>
                  <div>{batch.earnings?.length ?? 0} item(s)</div>
                  <div className="muted">{earningsStatusHint(batch)}</div>
                </td>
                <td>
                  {batch.totalNetAmount} {batch.currency}
                </td>
                <td>
                  <div>{batch.paidAt ? new Date(batch.paidAt).toLocaleString() : '-'}</div>
                  <div className="muted">{batch.paidAt ? relativeTime(batch.paidAt) : 'Awaiting settlement'}</div>
                </td>
              </tr>
            ))}
            {batches.length === 0 && (
              <tr>
                <td colSpan={8}>No payout batches loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

function sortBatches(batches: AdminPayoutBatch[]) {
  return [...batches].sort((left, right) => {
    const scoreDiff = payoutPriority(left.status) - payoutPriority(right.status);
    if (scoreDiff !== 0) {
      return scoreDiff;
    }
    return Date.parse(right.createdAt) - Date.parse(left.createdAt);
  });
}

function payoutPriority(status: string) {
  switch (status) {
    case 'PENDING':
      return 0;
    case 'PROCESSING':
      return 1;
    case 'READY':
      return 2;
    case 'PAID':
      return 3;
    case 'FAILED':
      return 4;
    case 'CANCELLED':
      return 5;
    default:
      return 6;
  }
}

function buildSummary(batches: AdminPayoutBatch[]) {
  const currency = batches[0]?.currency ?? 'VND';
  return {
    total: batches.length,
    needsReview: batches.filter((batch) => batch.status === 'PENDING' || batch.status === 'FAILED').length,
    readyToTransfer: batches.filter((batch) => batch.status === 'READY' || batch.status === 'PROCESSING').length,
    settled: batches.filter((batch) => batch.status === 'PAID').length,
    totalNetAmount: batches.reduce((sum, batch) => sum + batch.totalNetAmount, 0),
    currency,
  };
}

function humanizeStatus(status: string) {
  return status
    .toLowerCase()
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function payoutPhase(status: string) {
  switch (status) {
    case 'PENDING':
      return 'Waiting for finance review';
    case 'PROCESSING':
      return 'Transfer is in motion';
    case 'READY':
      return 'Batch can be sent to banking';
    case 'PAID':
      return 'Settlement finished';
    case 'FAILED':
      return 'Needs payout recovery';
    case 'CANCELLED':
      return 'Batch was stopped';
    default:
      return 'Monitor this payout batch';
  }
}

function signalClass(status: string) {
  switch (status) {
    case 'PAID':
      return 'signal signal-ok';
    case 'READY':
    case 'PROCESSING':
      return 'signal signal-info';
    case 'PENDING':
    case 'FAILED':
      return 'signal signal-warn';
    default:
      return 'signal';
  }
}

function opsSignal(batch: AdminPayoutBatch) {
  switch (batch.status) {
    case 'PENDING':
      return 'Needs review';
    case 'READY':
      return 'Ready to transfer';
    case 'PROCESSING':
      return 'Transfer in progress';
    case 'PAID':
      return 'Settled';
    case 'FAILED':
      return 'Retry payout';
    case 'CANCELLED':
      return 'Stopped';
    default:
      return 'Monitor';
  }
}

function opsHint(batch: AdminPayoutBatch) {
  switch (batch.status) {
    case 'PENDING':
      return 'Check included earnings, confirm the therapist, and release only if totals look right.';
    case 'READY':
      return 'Transfer reference can be attached now and moved to processing.';
    case 'PROCESSING':
      return 'Watch for banking confirmation before marking the batch complete.';
    case 'PAID':
      return 'Payment already landed. Keep this for reconciliation and support follow-up.';
    case 'FAILED':
      return 'Review transfer notes and retry path before earnings age further.';
    case 'CANCELLED':
      return 'Make sure related earnings are reassigned or rebatched if still payable.';
    default:
      return 'Use this row to understand payout readiness and reconcile provider earnings.';
  }
}

function earningsStatusHint(batch: AdminPayoutBatch) {
  if (!batch.earnings?.length) {
    return 'No earnings attached';
  }
  const payoutLinked = batch.earnings.filter((earning) => earning.payoutBatchId === batch.id).length;
  return `${payoutLinked}/${batch.earnings.length} linked to this batch`;
}

function shortId(value: string) {
  return value.length > 12 ? value.slice(0, 12) : value;
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
