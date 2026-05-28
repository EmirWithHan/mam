# Business Features Plan

## Implemented Foundation

- A user can create one business account.
- Business accounts have a separate business profile.
- Business profiles show a business badge.
- Verified-style display is available through `is_verified`, but users cannot
  mark themselves verified.
- Settings links to business creation or business profile management.
- Business owners can choose between personal events and official business
  events during event creation.
- Business events are linked to the business account and can be marked free or
  paid in TRY.
- Sponsored business event placement is available. Sponsored content is clearly
  labeled and the events list can place one active sponsored business event
  after every four normal events.

## Current Development Choice

Business account `status` defaults to `active` for this foundation so the flow
can be tested without moderation tooling. `is_verified` defaults to `false`.

## Not Implemented Yet

- Payment/ad dashboard for sponsored placement
- Business event double confirmation
- Check-in
- Waitlists
- No-show penalties
- Phone verification
- SMS/OTP
- Star ratings
- Business analytics/statistics
- Push notifications

Normal user events remain personal/community events. Business event creation is
now explicit, and sponsored placement is label-first/manual-admin for now. Double
confirmation, check-in, no-show handling, payments/ad dashboards, ratings, and
statistics are still later steps.
