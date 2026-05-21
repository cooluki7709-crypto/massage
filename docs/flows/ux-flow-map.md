# UX Flow Map

## Phase 1 Navigation Shape

Customer app uses five tabs:

- Home: location, service categories, nearby providers
- Providers: searchable provider list and provider profile
- Bookings: active booking, matching, history
- Chat: rooms and messages
- Profile: account, addresses, wallet, support

Provider app uses five tabs:

- Requests: open matching jobs and invitations
- Schedule: availability and upcoming services
- Earnings: payouts, completed jobs, tips
- Chat: customer conversations
- Profile: verification, services, online toggle

Admin web uses sidebar navigation:

- Dashboard
- Customers
- Providers
- Verification
- Bookings
- Matching
- Payments
- Reviews/Reports
- Coupons
- Analytics
- Audit Log

## Customer Booking Sequence

```mermaid
flowchart TD
  A["Launch"] --> B["Location Permission"]
  B --> C["Nearby Providers"]
  C --> D["Provider Detail"]
  D --> E["Review Profile / Reviews / Services"]
  E --> F["Customer Selects One Service"]
  F --> G["Direct Booking Request"]
  G --> H["Provider Accepts Or Rejects"]
  H --> I["Provider Starts Service Flow"]
  I --> J["Chat Created"]
  J --> K["Provider Location Shared"]
  K --> L["Provider On The Way"]
  L --> M["In Service"]
  M --> N["Complete"]
  N --> O["Review And Tip"]
```

## Reference Dynamic Flow Notes

Physical-device dynamic analysis confirmed this high-level customer flow shape:

```mermaid
flowchart TD
  A["Explore Home"] --> B["Service Category Card"]
  B --> C["Provider List"]
  C --> D["Search And Filter"]
  C --> E["Provider Card"]
  E --> F["Booking CTA"]
  F --> G["Authentication Gate"]
  G --> H["Google Or Phone Login"]
```

MVP Phase 1 keeps the same broad order: explore first, provider browse second, provider detail third, booking action fourth. The intentional product choice for the first MVP is a simpler direct-booking request instead of multi-provider realtime selection.

## Provider Sequence

```mermaid
flowchart TD
  A["Login"] --> B["Verification Check"]
  B --> C["Online Toggle"]
  C --> D["Realtime Location"]
  D --> E["Direct Booking Request Inbox"]
  E --> F["Accept Or Reject"]
  F --> G["Start Service Flow"]
  G --> H["Chat And Navigate"]
  H --> I["Arrived"]
  I --> J["Start Service"]
  J --> K["Complete Service"]
  K --> L["Earnings Updated"]
```

## UX Comparison Principles

- Preserve: onboarding/auth/location prompts, tab-based IA, provider browsing before booking, booking detail/status timeline, chat placement, provider verification sequence.
- Change: original branding, artwork, copy, colors, icons, and the original matching implementation.
- Improve: make provider response state explicit and keep the booking path easy to understand for customers, providers, and operators.
