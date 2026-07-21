# Dejen Stays Host

Native Flutter companion app for Dejen Stays property owners and managers.

## Host workflows

- Shared Dejen account authentication and secure token storage
- Portfolio dashboard and listing status
- Booking approval, decline, check-in, check-out, and completion
- Guest identity verification status without private file exposure
- Availability blocking and pricing visibility
- Earnings, commission, and payout summaries
- Pull-to-refresh plus a 12-second resilient live-data fallback

The production API defaults to `https://dejen.techiveet.com`. Override it with
`--dart-define=RIDE_API_URL=https://host` for local testing.
