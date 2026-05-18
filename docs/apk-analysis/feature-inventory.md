# Feature Inventory From Reference APK

## Customer Features

- Splash, onboarding carousel, language and region choice
- Phone OTP auth and password reset/create flows
- Location and push permission prompts
- Home with service categories, banners, nearby staff/spas
- Service list, service detail, therapist list, therapist detail
- Saved addresses with map pin/search
- Booking form with time, address, contact, notes, coupon
- Checkout with wallet/card/cash-like methods and gateway WebView
- Booking complete and live order detail/status timeline
- Cancellation reason and penalty flows
- Chat list and chat detail with media/location affordances
- Notifications, favorites, order history
- Profile, wallet, transactions, recharge/withdraw, VIP/subscription, referral

## Provider/Staff Features

- Staff registration entry and role selection
- Staff profile form and introduction
- Identity verification with ID/passport/self image
- Verification pending/approved/denied states
- Staff home/dashboard with quality/rank/earnings signals
- Availability, schedule/work time, services and pricing
- Staff order list and order detail
- Accept/reject/confirm/check-in/complete-style actions
- Customer chat, support chat, review list, wallet/reward/withdrawal

## Store/Manager Features

- Store/station list and detail
- Store orders
- Store members
- Store service/program tree
- Store owner chat

## MVP Translation

The MVP keeps the broad screen order and navigation hierarchy, but changes the core booking model into open matching:

`service -> provider list/detail -> booking confirmation -> open matching -> provider participants -> customer selects final provider -> chat/location/service lifecycle -> review/tip`

