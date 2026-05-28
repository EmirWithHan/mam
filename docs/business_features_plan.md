# Business Features Plan

## Implemented Foundation

- A user can create one business account.
- Business accounts have a separate business profile.
- Business profiles show a business badge.
- Verified-style display is available through `is_verified`, but users cannot
  mark themselves verified.
- Settings links to business creation or business profile management.

## Current Development Choice

Business account `status` defaults to `active` for this foundation so the flow
can be tested without moderation tooling. `is_verified` defaults to `false`.

## Not Implemented Yet

- Official business event creation
- Sponsored events
- Every fourth event sponsorship logic
- Business event double confirmation
- Check-in
- Waitlists
- No-show penalties
- Phone verification
- SMS/OTP
- Star ratings
- Business analytics/statistics
- Push notifications

Commercial/business event creation will require business account rules in a
later prompt. Normal user events remain personal/community events until that
separate workflow exists.

The next business-event prompt should separate official business event creation
from the normal user event flow instead of silently treating every business
owner event as an official commercial event.
