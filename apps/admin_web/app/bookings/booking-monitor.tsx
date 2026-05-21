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

  const summary = useMemo(() => {
    const open = bookings.filter((booking) => booking.status === 'OPEN_MATCHING');
    const matched = bookings.filter((booking) => booking.status === 'MATCHED');
    const active = bookings.filter((booking) => activeStatuses.has(booking.status));
    const noParticipants = open.filter((booking) => (booking.participants?.length ?? 0) === 0);
    const waitingSelection = open.filter((booking) => fallbackParticipants(booking).length > 0);
    const preferredPending = open.filter((booking) => booking.selectedProvider && !isSelectedProviderParticipant(booking));
    return [
      ['Active bookings', active.length.toString()],
      ['Open matching', open.length.toString()],
      ['Matched', matched.length.toString()],
      ['No providers yet', noParticipants.length.toString()],
      ['Preferred pending', preferredPending.length.toString()],
      ['Fallback options', waitingSelection.length.toString()],
    ];
  }, [bookings]);

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
            {bookings.map((booking) => (
              <tr key={booking.id}>
                <td>
                  <strong>{shortId(booking.id)}</strong>
                  <div className="muted">{booking.services?.[0]?.service?.name ?? 'Service pending'}</div>
                  <div className="muted">{formatDate(booking.scheduledStartAt)}</div>
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
                  <div className="muted">Preferred {booking.selectedProvider?.displayName ?? 'none'}</div>
                  <div className="muted">
                    {booking.selectedProvider?.user?.phone ? `Preferred phone ${booking.selectedProvider.user.phone}` : 'Preferred provider not set'}
                  </div>
                  <div className="participant-list" style={{ marginTop: 8 }}>
                    <span className={`pill ${selectionToneClass(booking)}`}>{selectionLabel(booking)}</span>
                    {booking.chatRoom && <span className="pill pill-success">Chat ready</span>}
                  </div>
                  <div className="participant-list" style={{ marginTop: 8 }}>
                    {booking.selectedProvider && (
                      <span className="pill" style={{ background: '#eef6e8', borderColor: '#b9d4a8' }}>
                        Preferred: {booking.selectedProvider.displayName ?? 'Provider'}
                        {isSelectedProviderParticipant(booking) ? ' joined' : ' pending'}
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
            {bookings.length === 0 && (
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

function StatusBadge({ status }: { status: string }) {
  return <span className={`status-badge status-${status.toLowerCase()}`}>{status}</span>;
}

function opsSignal(booking: AdminBooking) {
  const participantCount = fallbackParticipants(booking).length;
  if (booking.status === 'OPEN_MATCHING' && booking.selectedProvider && !isSelectedProviderParticipant(booking)) {
    return <span className="signal signal-warn">Preferred provider pending</span>;
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount === 0) {
    return <span className="signal signal-warn">No fallback providers yet</span>;
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount > 0) {
    return <span className="signal signal-info">Fallback options ready</span>;
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
  if (booking.status === 'OPEN_MATCHING' && booking.selectedProvider && !isSelectedProviderParticipant(booking)) {
    return 'Wait for the preferred provider, but monitor fallback therapist supply.';
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount === 0) {
    return 'Watch notifications and nearby provider supply.';
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount > 0) {
    return 'Customer can keep waiting or switch to a backup therapist.';
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

function isSelectedProviderParticipant(booking: AdminBooking) {
  const selectedProviderId = booking.selectedProvider?.id;
  if (!selectedProviderId) {
    return false;
  }

  return (booking.participants ?? []).some(
    (participant) => participant.providerProfile?.id === selectedProviderId && participant.status !== 'REJECTED',
  );
}

function fallbackParticipants(booking: AdminBooking) {
  const preferredId = booking.selectedProvider?.id;
  return (booking.participants ?? []).filter(
    (participant) =>
      participant.status !== 'REJECTED' &&
      participant.providerProfile?.id &&
      participant.providerProfile.id !== preferredId,
  );
}

function selectionLabel(booking: AdminBooking) {
  if (!booking.selectedProvider) {
    return 'No preferred therapist';
  }

  if (booking.status === 'OPEN_MATCHING' && !isSelectedProviderParticipant(booking)) {
    return 'Preferred therapist pending';
  }

  if (booking.status === 'MATCHED') {
    return 'Final therapist selected';
  }

  if (isSelectedProviderParticipant(booking)) {
    return 'Preferred therapist is active';
  }

  return 'Preferred therapist requested';
}

function selectionToneClass(booking: AdminBooking) {
  if (!booking.selectedProvider) {
    return 'pill-neutral';
  }

  if (booking.status === 'OPEN_MATCHING' && !isSelectedProviderParticipant(booking)) {
    return 'pill-warn';
  }

  if (booking.status === 'MATCHED') {
    return 'pill-success';
  }

  if (isSelectedProviderParticipant(booking)) {
    return 'pill-success';
  }

  return 'pill-neutral';
}
