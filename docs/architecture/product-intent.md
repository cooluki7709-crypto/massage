# Product Intent

## Product Summary

`HANDS` is a realtime on-demand massage platform serving all of Vietnam.

The target users are:

- people living in Vietnam who want to book massage services on demand
- travelers visiting Vietnam who need a simple, trustworthy booking flow

This is not a generic salon-booking app. The core product behavior is:

- a customer opens a booking request
- multiple providers can join the open request in realtime
- the customer chooses the final provider
- chat, location sharing, and service-state updates continue after selection

## Reference-App Alignment

Phase 1 intentionally stays close to the reference app in:

- navigation order
- screen hierarchy
- interaction sequence
- service-first browsing flow
- provider list before booking action
- auth gate placement

This is for speed, clarity, and lower product ambiguity during MVP validation.

Phase 1 does **not** copy:

- branding
- proprietary images or assets
- logos
- exact visual styling
- copyrighted copy

## What Must Feel Similar

The customer experience should keep this broad order:

1. explore / choose service
2. see nearby providers
3. confirm booking
4. open realtime matching
5. wait while providers join
6. select final provider
7. continue with chat and service tracking

The provider experience should keep this broad order:

1. login
2. verification / profile readiness
3. online presence
4. open request participation
5. wait for customer selection
6. chat, travel, arrival, service, completion

## What We Intentionally Change

Compared with the reference app:

- matching is made more explicit
- provider participation is visible
- customer choice is central
- waiting anxiety is reduced with realtime updates
- payment and refund states are exposed more clearly

## UX Direction For Current MVP

Until the final Figma design arrives, the product should stay:

- simple to read
- easy to demo
- easy to reason about
- operationally obvious

That means:

- straightforward labels
- minimal decorative styling
- visible state transitions
- obvious primary actions
- fewer nested flows

## UX Direction After Figma Handoff

When the final design file is provided later, we should update:

- brand identity
- spacing and layout density
- typography system
- color system
- icons and illustrations
- animation details

But we should preserve the validated MVP flow unless a business decision changes it.

## Current Product Check

The current implementation is aligned with the intended Phase 1 direction:

- customer app: service list -> nearby providers -> booking confirmation -> open matching
- provider app: request feed -> login/online state -> join open matching
- admin web: bookings, providers, notifications, payments, reviews, coupons, audit visibility
- backend: realtime matching, chat, payment lifecycle, push registration, refund and audit flows

## Known Gaps Before Final UX Pass

- customer app still uses English-only UI copy today
- provider app still uses English-only UI copy today
- admin web still uses English-only UI copy today
- location-first entry and region/language onboarding are not yet fully modeled
- the final visual system is still placeholder-grade, by design
