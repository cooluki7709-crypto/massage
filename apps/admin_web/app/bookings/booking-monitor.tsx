'use client';

import { useEffect, useMemo, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { AdminBooking } from '../../lib/admin-api';

type Props = {
  bookings: AdminBooking[];
};

const activeStatuses = new Set(['OPEN_MATCHING', 'MATCHED', 'PROVIDER_ON_THE_WAY', 'ARRIVED', 'IN_SERVICE']);

export function BookingMonitor({ bookings }: Props) {
  const router = useRouter();
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [lastRefresh, setLastRefresh] = useState(() => new Date());
  const [isPending, startTransition] = useTransition();

  const orderedBookings = useMemo(
    () =>
      [...bookings].sort((left, right) => {
        const leftScore = bookingPriority(left);
        const rightScore = bookingPriority(right);
        if (leftScore !== rightScore) {
          return rightScore - leftScore;
        }

        return bookingTimestamp(right) - bookingTimestamp(left);
      }),
    [bookings],
  );

  const summary = useMemo(() => {
    const open = orderedBookings.filter((booking) => booking.status === 'OPEN_MATCHING');
    const matched = orderedBookings.filter((booking) => booking.status === 'MATCHED');
    const active = orderedBookings.filter((booking) => activeStatuses.has(booking.status));
    const noParticipants = open.filter((booking) => (booking.participants?.length ?? 0) === 0);
    const waitingSelection = open.filter((booking) => fallbackParticipants(booking).length > 0);
    const preferredPending = open.filter((booking) => booking.preferredProvider && isPreferredAwaitingDecision(booking));
    const backupChosen = orderedBookings.filter((booking) => isBackupSelected(booking));
    const chatLive = orderedBookings.filter((booking) => Boolean(booking.chatRoom));
    return [
      ['Active bookings', active.length.toString()],
      ['Open matching', open.length.toString()],
      ['Matched', matched.length.toString()],
      ['No providers yet', noParticipants.length.toString()],
      ['Preferred pending', preferredPending.length.toString()],
      ['Fallback options', waitingSelection.length.toString()],
      ['Backup selected', backupChosen.length.toString()],
      ['Chat live', chatLive.length.toString()],
    ];
  }, [orderedBookings]);

  useEffect(() => {
    if (!autoRefresh) {
      return;
    }

    const timer = window.setInterval(() => {
      startTransition(() => {
        router.refresh();
        setLastRefresh(new Date());
      });
    }, 10000);

    return () => window.clearInterval(timer);
  }, [autoRefresh, router]);

  return (
    <>
      <section className="toolbar">
        <div>
          <h1>Booking Monitor</h1>
          <p className="muted">Live operational view for matching, provider selection, chat, and payment readiness.</p>
        </div>
        <div className="actions">
          <button type="button" onClick={() => setAutoRefresh((value) => !value)}>
            {autoRefresh ? 'Pause refresh' : 'Resume refresh'}
          </button>
          <button
            type="button"
            onClick={() => {
              startTransition(() => {
                router.refresh();
                setLastRefresh(new Date());
              });
            }}
          >
            Refresh now
          </button>
        </div>
      </section>

      <section className="grid">
        {summary.map(([label, value]) => (
          <div className="card" key={label}>
            <p>{label}</p>
            <h2>{value}</h2>
          </div>
        ))}
      </section>

      <div className="monitor-meta">
        <span>{isPending ? 'Refreshing...' : 'Ready'}</span>
        <span>Last refresh {lastRefresh.toLocaleTimeString()}</span>
      </div>

      <section className="card" style={{ marginTop: 16 }}>
        <table className="table">
          <thead>
            <tr>
              <th>Booking</th>
              <th>Flow</th>
              <th>Customer</th>
              <th>Providers</th>
              <th>Payment</th>
              <th>Ops signal</th>
            </tr>
          </thead>
          <tbody>
            {orderedBookings.map((booking) => (
              <tr key={booking.id}>
                <td>
                  <strong>{shortId(booking.id)}</strong>
                  <div className="muted">{booking.services?.[0]?.service?.name ?? 'Service pending'}</div>
                  <div className="muted">{formatDate(booking.scheduledStartAt)}</div>
                  <div className="muted">{recencyLabel(booking)}</div>
                </td>
                <td>
                  <StatusBadge status={booking.status} />
                  <div className="muted">Chat {booking.chatRoom ? 'ready' : 'not ready'}</div>
                  <div className="muted">{booking.expiresAt ? `Expires ${formatDate(booking.expiresAt)}` : 'No expiry set'}</div>
                </td>
                <td>
                  {booking.customerProfile?.user?.fullName ?? 'Customer'}
                  <div className="muted">{booking.customerProfile?.user?.phone ?? 'No phone'}</div>
                </td>
                <td>
                  <strong>{booking.participants?.length ?? 0} joined</strong>
                  <div className="muted">Preferred {booking.preferredProvider?.displayName ?? 'none'}</div>
                  <div className="muted">
                    {booking.preferredProvider?.user?.phone ? `Preferred phone ${booking.preferredProvider.user.phone}` : 'Preferred provider not set'}
                  </div>
                  <div className="muted">{selectionPathLabel(booking)}</div>
                  <div className="participant-list" style={{ marginTop: 8 }}>
                    <span className={`pill ${selectionToneClass(booking)}`}>{selectionLabel(booking)}</span>
                    {booking.chatRoom && <span className="pill pill-success">Chat ready</span>}
                  </div>
                  <div className="participant-list" style={{ marginTop: 8 }}>
                    {booking.preferredProvider && (
                      <span className="pill" style={{ background: '#eef6e8', borderColor: '#b9d4a8' }}>
                        Preferred: {booking.preferredProvider.displayName ?? 'Provider'}
                        {' '}
                        {preferredProviderStateLabel(booking)}
                      </span>
                    )}
                    {booking.selectedProvider && booking.selectedProvider.id !== booking.preferredProvider?.id && (
                      <span className="pill pill-success">
                        Final: {booking.selectedProvider.displayName ?? 'Provider'}
                      </span>
                    )}
                    {fallbackParticipants(booking).slice(0, 4).map((participant) => (
                      <span className="pill" key={participant.id}>
                        Backup: {participant.providerProfile?.displayName ?? 'Provider'} ({participant.status})
                      </span>
                    ))}
                  </div>
                  {fallbackParticipants(booking).length > 4 && (
                    <div className="muted" style={{ marginTop: 6 }}>
                      +{fallbackParticipants(booking).length - 4} more backup therapist(s)
                    </div>
                  )}
                </td>
                <td>
                  {booking.payment?.status ?? 'NONE'}
                  <div className="muted">
                    {booking.payment ? `${booking.payment.amount} VND - ${booking.payment.method}` : 'No payment'}
                  </div>
                </td>
                <td>
                  <div>{opsSignal(booking)}</div>
                  <div className="muted" style={{ marginTop: 8 }}>
                    {nextAction(booking)}
                  </div>
                </td>
              </tr>
            ))}
            {orderedBookings.length === 0 && (
              <tr>
                <td colSpan={6}>No bookings loaded. Start the API and run the smoke flow to populate this table.</td>
              </tr>
            )}
          </tbody>
        </table>
      </section>
    </>
  );
}

function bookingPriority(booking: AdminBooking) {
  if (booking.status === 'IN_SERVICE') {
    return 5;
  }
  if (booking.status === 'PROVIDER_ON_THE_WAY' || booking.status === 'ARRIVED') {
    return 4;
  }
  if (booking.status === 'MATCHED') {
    return 3;
  }
  if (booking.status === 'OPEN_MATCHING') {
    return 2;
  }
  return 1;
}

function bookingTimestamp(booking: AdminBooking) {
  return new Date(booking.createdAt ?? booking.scheduledStartAt ?? booking.expiresAt ?? 0).getTime();
}

function StatusBadge({ status }: { status: string }) {
  return <span className={`status-badge status-${status.toLowerCase()}`}>{status}</span>;
}

function opsSignal(booking: AdminBooking) {
  const participantCount = fallbackParticipants(booking).length;
  if (booking.status === 'OPEN_MATCHING' && booking.preferredProvider && isPreferredAwaitingDecision(booking)) {
    return <span className="signal signal-warn">Preferred provider pending</span>;
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount === 0) {
    return <span className="signal signal-warn">No fallback providers yet</span>;
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount > 0) {
    return <span className="signal signal-info">Fallback options ready</span>;
  }
  if (booking.status === 'MATCHED' && isBackupSelected(booking)) {
    return <span className="signal signal-info">Backup therapist selected</span>;
  }
  if (booking.status === 'MATCHED' && !booking.chatRoom) {
    return <span className="signal signal-warn">Chat missing</span>;
  }
  if (booking.payment?.status === 'REFUNDED') {
    return <span className="signal signal-warn">Refunded</span>;
  }
  return <span className="signal signal-ok">Normal</span>;
}

function nextAction(booking: AdminBooking) {
  const participantCount = fallbackParticipants(booking).length;
  if (booking.status === 'OPEN_MATCHING' && booking.preferredProvider && isPreferredAwaitingDecision(booking)) {
    return 'Wait for the preferred provider, but monitor fallback therapist supply.';
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount === 0) {
    return 'Watch notifications and nearby provider supply.';
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount > 0) {
    return 'Customer can keep waiting or switch to a backup therapist.';
  }
  if (booking.status === 'MATCHED' && isBackupSelected(booking)) {
    return 'Customer switched away from the preferred therapist. Confirm chat, route, and provider handoff.';
  }
  if (booking.status === 'MATCHED') {
    return 'Customer selection is locked. Check chat creation, route tracking, and provider departure.';
  }
  if (booking.status === 'PROVIDER_ON_THE_WAY') {
    return 'Monitor live location and arrival progress.';
  }
  if (booking.status === 'IN_SERVICE') {
    return 'Watch completion and payment capture.';
  }
  if (booking.status === 'COMPLETED') {
    return 'Review payment, tip, and follow-up review.';
  }
  return 'Normal operating state.';
}

function shortId(id: string) {
  return id.slice(0, 8);
}

function formatDate(value?: string | null) {
  if (!value) {
    return 'No schedule';
  }
  return new Date(value).toLocaleString();
}

function recencyLabel(booking: AdminBooking) {
  const timestamp = booking.createdAt ?? booking.scheduledStartAt ?? booking.expiresAt;
  if (!timestamp) {
    return 'Created time unavailable';
  }

  const minutesAgo = Math.max(0, Math.round((Date.now() - new Date(timestamp).getTime()) / 60000));
  if (minutesAgo < 1) {
    return 'Updated just now';
  }
  if (minutesAgo < 60) {
    return `Updated ${minutesAgo}m ago`;
  }
  const hoursAgo = Math.round(minutesAgo / 60);
  if (hoursAgo < 24) {
    return `Updated ${hoursAgo}h ago`;
  }
  const daysAgo = Math.round(hoursAgo / 24);
  return `Updated ${daysAgo}d ago`;
}

function isSelectedProviderParticipant(booking: AdminBooking) {
  const selectedProviderId = booking.selectedProvider?.id;
  if (!selectedProviderId) {
    return false;
  }

  return (booking.participants ?? []).some(
    (participant) => participant.providerProfile?.id === selectedProviderId && participant.status !== 'REJECTED',
  );
}

function isBackupSelected(booking: AdminBooking) {
  return Boolean(
    booking.selectedProvider?.id &&
      booking.preferredProvider?.id &&
      booking.selectedProvider.id !== booking.preferredProvider.id,
  );
}

function fallbackParticipants(booking: AdminBooking) {
  const preferredId = booking.preferredProvider?.id;
  return (booking.participants ?? []).filter(
    (participant) =>
      participant.status !== 'REJECTED' &&
      participant.providerProfile?.id &&
      participant.providerProfile.id !== preferredId,
  );
}

function selectionLabel(booking: AdminBooking) {
  if (!booking.preferredProvider) {
    return 'No preferred therapist';
  }

  if (booking.status === 'OPEN_MATCHING' && isPreferredAwaitingDecision(booking)) {
    return 'Preferred therapist pending';
  }

  if (preferredProviderStateLabel(booking) == 'declined') {
    return 'Preferred therapist declined';
  }

  if (booking.status === 'MATCHED') {
    return 'Final therapist selected';
  }

  if (isSelectedProviderParticipant(booking)) {
    return 'Preferred therapist is active';
  }

  return 'Preferred therapist requested';
}

function selectionPathLabel(booking: AdminBooking) {
  const fallbackCount = fallbackParticipants(booking).length;

  if (!booking.preferredProvider) {
    return fallbackCount > 0 ? 'Open pool request with backup supply' : 'Open pool request';
  }

  if (booking.status === 'OPEN_MATCHING' && isPreferredAwaitingDecision(booking)) {
    return fallbackCount > 0
      ? 'Direct request first, with backup therapists already waiting'
      : 'Direct request first, waiting on the preferred therapist';
  }

  if (isBackupSelected(booking)) {
    return 'Direct request escalated to backup, then the guest chose a backup therapist';
  }

  if (booking.status === 'MATCHED') {
    return 'Direct request confirmed by the preferred therapist';
  }

  if (fallbackCount > 0) {
    return 'Backup therapists are available while the preferred therapist stays in the flow';
  }

  return 'Direct request remains the active path';
}

function selectionToneClass(booking: AdminBooking) {
  if (!booking.preferredProvider) {
    return 'pill-neutral';
  }

  if (booking.status === 'OPEN_MATCHING' && isPreferredAwaitingDecision(booking)) {
    return 'pill-warn';
  }

  if (preferredProviderStateLabel(booking) == 'declined') {
    return 'pill-info';
  }

  if (booking.status === 'MATCHED') {
    return 'pill-success';
  }

  if (isSelectedProviderParticipant(booking)) {
    return 'pill-success';
  }

  return 'pill-neutral';
}

function preferredParticipantState(booking: AdminBooking) {
  const preferredProviderId = booking.preferredProvider?.id;
  if (!preferredProviderId) {
    return null;
  }

  return (booking.participants ?? []).find((participant) => participant.providerProfile?.id === preferredProviderId) ?? null;
}

function isPreferredAwaitingDecision(booking: AdminBooking) {
  const participant = preferredParticipantState(booking);
  if (!booking.preferredProvider) {
    return false;
  }
  if (!participant) {
    return true;
  }
  return participant.status !== 'ACCEPTED' && participant.status !== 'SELECTED' && participant.status !== 'REJECTED';
}

function preferredProviderStateLabel(booking: AdminBooking) {
  const participant = preferredParticipantState(booking);
  if (!participant) {
    return 'requested';
  }
  if (participant.status === 'REJECTED') {
    return 'declined';
  }
  if (participant.status === 'ACCEPTED' || participant.status === 'SELECTED') {
    return 'confirmed';
  }
  return 'pending';
}
