# Business Accounts

Business accounts are separate profiles for venues, facilities, studios, and
activity operators on Match A Man.

They do not replace normal user profiles. A normal user can still join the app,
use Events, Feed/Moments, profiles, follow requests, gallery, Trust Score, and
badges as before.

## Collected Fields

Required fields:

- Business name
- Username
- Category
- City
- District

Category examples now include sports facilities, outdoor/adventure operators,
social entertainment venues, trainers, service providers, and organizations.
Examples: Halı Saha, At Çiftliği, Padel Kortu, Yoga Stüdyosu, Kamp Alanı,
Bowling Salonu, Board Game Kafe, Spor Akademisi, Tur / Gezi Organizasyonu, and
Ekipman Kiralama.

If none of the listed categories fit, the owner can choose "Diğer" and enter a
custom business type. Public displays show that custom type instead of only
showing "Diğer".

Optional fields:

- Address
- Description
- Phone
- Website
- Instagram
- Logo URL
- Cover URL

Phone is only a contact field in this foundation. Phone verification, SMS, and
OTP are not implemented yet.

Business account creation requires a signed-in Supabase Auth user. The client
sets `owner_user_id` to the current authenticated user id and does not send
moderation fields such as `is_verified` or `status`.

## Business Profile

The business profile shows:

- Logo/avatar fallback
- Business name
- Handle
- Category
- City/district
- Address
- Description
- Public contact fields
- Business badge
- Verified business badge only when `is_verified = true`

For development, new business accounts default to `status = active` and
`is_verified = false`. This keeps the feature usable before moderation tooling
exists. Suspended, rejected, or pending accounts are visible to their owner but
not treated as public profiles.

RLS allows owners to create, read, and update their own editable business
fields. Authenticated users can read active business profiles. Verification and
status moderation fields are not user-controlled.

## User Vs Business

Personal profiles represent people.

Business profiles represent venues or organizations. Business accounts are
clearly labeled with an "Isletme" badge, and verified businesses can later be
shown with "Dogrulanmis Isletme".

## Postponed

Business event creation is postponed to a later prompt. Normal user events are
still personal/community events for now.

Also postponed:

- Sponsored events
- Check-in and no-show flows
- Business event double confirmation
- Waitlists
- Ratings
- Business analytics/statistics
- Phone verification
- SMS/OTP
- Push notifications
