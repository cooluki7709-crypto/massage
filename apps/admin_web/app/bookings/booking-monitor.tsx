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
    const waitingSelection = open.filter((booking) => (booking.participants?.length ?? 0) > 0);
    return [
      ['Active bookings', active.length.toString()],
      ['Open matching', open.length.toString()],
      ['Matched', matched.length.toString()],
      ['No providers yet', noParticipants.length.toString()],
      ['Waiting selection', waitingSelection.length.toString()],
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
                  <div className="muted">Selected {booking.selectedProvider?.displayName ?? 'none'}</div>
                  <div className="muted">
                    {booking.selectedProvider?.user?.phone ? `Provider phone ${booking.selectedProvider.user.phone}` : 'Provider not selected'}
                  </div>
                  <div className="participant-list">
                    {(booking.participants ?? []).slice(0, 3).map((participant) => (
                      <span className="pill" key={participant.id}>
                        {participant.providerProfile?.displayName ?? 'Provider'}: {participant.status}
                      </span>
                    ))}
                  </div>
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
  const participantCount = booking.participants?.length ?? 0;
  if (booking.status === 'OPEN_MATCHING' && participantCount === 0) {
    return <span className="signal signal-warn">Needs provider attention</span>;
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount > 0) {
    return <span className="signal signal-info">Waiting customer selection</span>;
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
  const participantCount = booking.participants?.length ?? 0;
  if (booking.status === 'OPEN_MATCHING' && participantCount === 0) {
    return 'Watch provider supply and notification response.';
  }
  if (booking.status === 'OPEN_MATCHING' && participantCount > 0) {
    return 'Customer can choose one provider now.';
  }
  if (booking.status === 'MATCHED') {
    return 'Check chat creation, route tracking, and provider departure.';
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
