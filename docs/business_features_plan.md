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
- Business events now use double confirmation: owner approval moves the
  requester to pending confirmation, the user confirms from event detail, and
  only confirmed users count as final participants.
- Waitlist foundation exists for business events when confirmed capacity is
  full.
- Business owners can open participant check-in for their own business events
  and mark confirmed participants as `Geldi` or `Gelmedi`.
- No-show foundation is in place: `Gelmedi` marks the participant as `no_show`,
  applies a small idempotent Trust Score penalty, and writes through the trust
  score log system.
- Business star rating foundation exists. Users can rate a business after they
  attended a business event, with check-in preferred and confirmed attendance
  accepted as the current fallback.
- Business profiles show average stars and rating count, or an empty state when
  there are no ratings yet.
- Business statistics foundation exists for owners: total/upcoming events,
  requests, confirmed participants, check-ins, no-shows, ratings, and sponsored
  event counts.

## Current Development Choice

Business account `status` defaults to `active` for this foundation so the flow
can be tested without moderation tooling. `is_verified` defaults to `false`.

## Not Implemented Yet

- Payment/ad dashboard for sponsored placement
- Waitlist expiry/automation
- QR check-in
- Phone verification
- SMS/OTP
- Advanced analytics/statistics
- Push notifications

Normal user events remain personal/community events. Business event creation is
now explicit, sponsored placement is label-first/manual-admin for now, and
business events use a double-confirmation join lifecycle. Check-in, no-show
handling, and business ratings now have a safe foundation; QR check-in, phone
verification, payments/ad dashboards, advanced analytics/statistics, and push
notifications are still later steps.
