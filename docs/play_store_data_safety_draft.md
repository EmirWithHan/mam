# Play Store Data Safety Draft

Date: 2026-06-06

## Important Note

This is a developer draft for Play Console preparation. It is not legal advice
and must not be treated as final store-submission text.

Final Play Console answers must match the actual app behavior, privacy policy,
SDKs, backend configuration, and store build at submission time. If any package,
SDK, analytics tool, crash reporter, payment provider, push provider, or backend
flow changes, review this document again.

## Data Collected

| Data category | Exact examples | Why collected | Required or optional | User-visible purpose | Shared with third parties | Encrypted in transit | Deletion status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Account identifiers | Supabase Auth user id, profile `user_id` | Auth/session, ownership, RLS, profile linkage | Required for signed-in use | Account login and app identity | Processed by Supabase as backend provider | Yes, HTTPS/TLS | In-app deletion request/deactivation exists; final Auth deletion TODO |
| Email address | Auth email | Login/register, account recovery through Supabase Auth | Required for email auth | Sign in and account access | Processed by Supabase as auth provider | Yes, HTTPS/TLS | In-app deletion request/deactivation exists; final Auth deletion TODO |
| Display/profile info | Username, tag, display name/first name, bio, avatar URL, account type, trust score | Public profile, search, events, feed, social identity | Username/name required; bio/avatar optional | Public identity and profile | Processed by Supabase; visible to other users based on app rules | Yes, HTTPS/TLS | Profile edit and in-app deletion request/deactivation exist; final deletion TODO |
| Profile details | Birth date, gender, city, district, phone/phone number, phone verification state, privacy status | Event readiness, local matching, profile controls, future verification | Some fields required only for event actions; phone optional/postponed verification | Event eligibility, location context, privacy settings | Processed by Supabase; phone/email should not be public | Yes, HTTPS/TLS | Profile edit exists; full deletion TODO |
| User-generated content | Posts, captions, comments, event titles/descriptions, business descriptions, feedback messages, reports | Core feed/events/social/moderation/support flows | Optional except where user chooses to submit | Sharing activity, event planning, support and safety | Processed by Supabase; visible to users/admins depending context | Yes, HTTPS/TLS | Delete/edit partial; full deletion TODO |
| Social graph/activity | Follows, follow requests, event join requests, participants, approvals/rejections, blocks, notifications | Social/event participation, privacy, safety, in-app state | Created by user actions | Follow/private profile/event workflows | Processed by Supabase; visibility controlled by RLS/RPCs | Yes, HTTPS/TLS | Flow-specific cancel/delete exists in places; full deletion TODO |
| Location-related data | User-selected city/district, event city/district/location text, optional event latitude/longitude from current location helper | Event discovery, event creation, map links | City/district required for event actions; precise location only when user taps helper | Show and create local events | Processed by Supabase; event location may be visible to event viewers | Yes, HTTPS/TLS | Event edit/delete partial; full deletion TODO |
| Photos/images | Profile avatar, post images, public image URLs | Profile and post media | Optional, user initiated | Avatar and feed/gallery sharing | Stored/processed by Supabase Storage; visibility depends on bucket/app rules | Yes, HTTPS/TLS | User delete partial for gallery/posts; full deletion TODO |
| Business data | Business name, phone, address, category, custom category, website, description, application status, admin note/review status, verification/status fields | Business application, approval, business events, moderation | Required for business application | Business account and event identity | Processed by Supabase; admin-only fields should not be public | Yes, HTTPS/TLS | Business account delete/passivation exists; full user deletion TODO |
| Chat/messages | Event group chat messages if chat tables/screens are enabled | Event participant communication | Optional, event/member context | Chat inside event/social flows | Processed by Supabase; should be restricted to eligible event users | Yes, HTTPS/TLS | Deletion policy TODO before public launch |
| Diagnostics/debug logs | Local developer debug prints with code/message only | Development troubleshooting | Not a user submission | Debugging during development/beta | No third-party analytics/crash SDK found in repo | N/A or platform transport if logs exported manually | Logs should not include secrets or raw personal data |

## Likely Play Console Categories

### Personal Info

- Name/display name.
- Email address.
- Phone number if user enters it or business application requires it.
- Profile photo/avatar if uploaded.
- Approximate age-related data if birth date is collected for event readiness.

### App Activity

- Posts, comments, event creation/join activity.
- Follow/request activity.
- Feedback and reports.
- In-app notification state.
- Blocks and moderation-related user actions.

### Location

- Approximate location: city/district and event city/district.
- Precise location: only if the user taps the current-location helper and the
  app stores latitude/longitude for an event.
- Do not declare background location unless it is added later.

### Photos And Videos

- Uploaded profile avatars.
- Uploaded post images.
- Event/business images only if later implemented. Current event covers appear
  generated from sport type, not user-uploaded event media.

### Messages

- Include chat messages if event chat is enabled in the submitted build.
- If chat is only for event groups, describe it as in-app/event chat.

### App Info And Performance

- No third-party analytics or crash-reporting SDK was found in `pubspec.yaml`.
- Do not claim app performance/crash data is collected by a third-party SDK
  unless a SDK is added later.
- Platform/store crash diagnostics may still exist outside app code; answer the
  Play Console form according to Google's definitions at submission time.

### Payment Or Financial Data

- No payment provider, Stripe, in-app purchase, or financial data flow was found.
- Payment/paid features are postponed unless explicitly implemented later.

### Push Tokens

- Firebase/FCM push is not implemented.
- No push notification token collection was found.
- In-app Supabase notifications are app database records, not device push tokens.

## Data Sharing

Supabase is the backend/service provider used for Auth, Database, Storage, and
Realtime. App data is sent to Supabase so the app can function.

Do not simply answer "not shared" without checking Google's current definition
of sharing. Some service-provider processing may or may not count as sharing
depending on Play Console rules and contracts. Final answers must follow
Google's definitions at submission time.

No Firebase, push provider, analytics SDK, crash reporting SDK, or payment SDK
was found in the current Flutter dependency list.

## Security Practices Draft

- Data is transmitted over HTTPS/TLS through Supabase and normal network APIs.
- Supabase Auth is used for authentication.
- Database access is controlled with RLS policies and RPCs.
- The Supabase `service_role` key is not in the Flutter client.
- Public search/profile models should not expose email, phone, auth metadata, or
  moderation-only fields.
- Admin actions are restricted through admin checks backed by `admin_users`.

Do not claim end-to-end encryption, independent security review, formal
certification, or full legal compliance unless those are actually completed.

## Data Deletion

Current status:

- Logout exists.
- Profile editing and privacy controls exist.
- Business account delete/passivation exists.
- Account deletion request/deactivation exists for closed beta. It creates an
  `account_deletion_requests` row, anonymizes/deactivates the public profile,
  cancels future events, archives posts, and blocks new user activity through
  app routing/RLS.
- Some content/action-specific deletion or cancellation flows exist.

Public launch blocker:

- Final Supabase Auth deletion, storage/content retention rules, and public web
  deletion request URL must be finalized before public Play Store submission if
  required by policy/law.
- The privacy policy and Play Console Data Safety answers must match the final
  deletion process.
