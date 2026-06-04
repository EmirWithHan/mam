# Business Features Plan

## Implemented Foundation

- A user can create one business account.
- Business account mode works like Instagram professional mode: the same auth
  account and same `profiles` row gain extra business fields, not a second
  social account.
- One auth account has one public identity. `profiles` is the canonical public
  identity source for names, username/tag, avatar, bio, follows, feed authors,
  event hosts, comments, actors, and public profile routes.
- Business accounts are not separately followable and `/business/:id` is
  owner/manage oriented; public surfaces resolve to the owner profile identity.
- Business conversion links the profile to the business account, saves previous
  personal display fields when missing, and writes the selected business display
  fields onto the same profile row.
- Business upgrade now starts with a user application and requires admin
  approval. Users cannot instantly switch themselves to business mode.
- Admin panel foundation exists at `/admin` for reviewing pending business
  applications.
- Business account deletion/deactivation returns the same profile to normal
  user mode. The business account row stays stored as `deleted`, personal
  identity fields are restored when available, and the user keeps the same auth
  account.
- Future active business events owned by the deleted/deactivated business are
  cancelled/hidden, and sponsored flags are cleared so deleted businesses do
  not receive sponsored placement.
- Re-applying for business mode after deletion requires a new admin approval.
- Business profiles show a business badge.
- Business verification is admin/manual DB only through `is_verified`; users and
  business owners cannot mark themselves verified.
- Settings links to business creation or business profile management.
- Business accounts create official business events by default; normal user
  accounts keep normal personal event creation.
- Business event activities are category-based. Mapped categories show relevant
  activities, and categories that include `Diğer` allow validated custom
  activity text.
- Business events are linked to the business account and can be marked free or
  paid in TRY.
- Business events are not sponsored by default. Sponsorship appears only for
  verified businesses when the database/admin marks `is_sponsored=true` and the
  sponsorship is still active. Deleted businesses cannot be sponsored.
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
- Phone OTP/verification
- SMS/OTP
- Advanced analytics/statistics
- Push notifications

Normal user events remain personal/community events. Business identities now
replace the public personal profile for converted accounts, sponsored placement
is manual-admin and verified-business only for now, and deleting/deactivating a
business account returns the profile to user mode while disabling/hiding future
active business events. Business events use a double-confirmation join
lifecycle. Check-in, no-show handling, and business ratings now have a safe
foundation; phone OTP, QR check-in, payments/ad dashboards, advanced
analytics/statistics, and push notifications are still later steps.
