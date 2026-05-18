# Provider Earnings

The MVP creates a provider earning record when the selected provider completes a booking.

## Flow

1. Provider calls `POST /provider/bookings/:id/complete`.
2. Booking status changes to `COMPLETED`.
3. Payment status changes to `CAPTURED`.
4. `ProviderEarning` is upserted by `bookingId`.
5. Provider can view earnings in the provider app.
6. Admin can monitor earnings and mark a record as paid.
7. Admin can create a provider payout batch from unpaid earnings.

## Calculation

- `grossAmount`: captured payment amount, falling back to booking service totals.
- `platformFee`: 20% of gross amount for the MVP.
- `tipAmount`: review tip amount, applied after the customer submits a review.
- `netAmount`: `grossAmount - platformFee + tipAmount`.
- `availableAt`: 24 hours after completion for MVP payout review.

## Statuses

- `PENDING`: completed service has been recorded.
- `AVAILABLE`: future payout automation can move reviewed earnings here.
- `PAID`: admin has marked the earning as paid.
- `CANCELLED`: reserved for refunds, disputes, or chargeback handling.

Admin refunds cancel unpaid earnings and set their net amount to zero. If an earning is already paid, the MVP preserves it and records the skip reason in the audit log.

## Payout Batches

`ProviderPayoutBatch` groups one provider's unpaid positive earnings into a single payout record. The MVP marks the batch as `PAID` immediately and links included earnings through `payoutBatchId`.

This keeps the current product simple while preserving the later path for bank transfer references, processing states, failed payouts, and batch-level reconciliation.

## Next Production Work

- Move the fee rate into a versioned platform policy table.
- Add provider payout account verification.
- Add real bank transfer execution and failure retry.
- Add paid-earning reversal entries for post-payout refunds and disputes.
