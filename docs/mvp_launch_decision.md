# MVP Launch Decision

Date: 2026-06-04

## Final Recommendation

Decision: Ready for internal testing.

The MVP is strong enough for a controlled internal test release with known
tester accounts, a prepared Supabase environment, and manual QA recording. It
is not ready for wider public beta or real store submission until the listed
blockers and high-risk follow-ups are cleared.

## Current MVP Status

### Works

- Email auth, registration, login, logout, and session restore paths are wired.
- Profile completion and own/public profile screens are available.
- Feed opens, paginates, and supports post creation.
- Event list, event detail, normal event creation, join request, approve,
  reject, and leave flows are wired.
- Username search, public follow/add friend, and private follow request flows
  are present.
- Business application, admin approve/reject, business account mode, business
  event creation, and business delete flows are present.
- Feedback form is available from settings.
- Settings includes legal/support pages.
- Responsive layout guardrails and manual QA scripts exist.
- Android debug APK and app bundle builds passed in the release-candidate
  build check.

### Partially Ready

- RLS/security audit was done, but some older/base policies and RPC definitions
  still need direct Supabase dashboard verification before broader beta.
- Admin tools cover business applications and feedback review, but advanced
  moderation analytics and operational dashboards are postponed.
- Reports and blocks are implemented enough for MVP safety, but moderation
  operations need production process review.
- Legal pages contain MVP placeholder copy and need professional review before
  real store submission.
- Release builds compile, but Android release signing still uses debug signing
  config and must be replaced for store submission.

### Intentionally Postponed

- Firebase push notifications.
- Real OTP phone verification.
- Payment system.
- Apple login until Apple Developer setup is ready.
- Advanced admin analytics.
- True IP rate limiting and production-grade abuse detection.

## Launch Blockers

### BLOCKER

- Run the full final manual QA script on the target devices before any external
  tester group.
- Verify staging/production Supabase migrations, RLS policies, storage rules,
  and security-definer RPC ownership checks directly in Supabase.
- Configure real Android release signing before Play Store submission.

### HIGH

- Replace placeholder legal/privacy/support copy with reviewed final content
  before store submission.
- Confirm account deletion/support process and public privacy/data deletion
  URLs for store review.
- Verify report/block data cannot be read, modified, or deleted by other users.
- Confirm comments, feed visibility, private profile visibility, and event
  participant visibility are enforced by RLS/RPC, not only by client checks.
- Confirm normal users cannot edit admin/business moderation fields.

### MEDIUM

- Production-grade abuse detection and true IP rate limiting are not yet
  implemented.
- Push/realtime notifications are absent and must be communicated to testers.
- Apple login remains disabled/coming soon until Apple Developer setup.
- Store screenshots, reviewer notes, and listing copy need final review.
- Advanced moderation/admin analytics are postponed.

### LOW

- Add deeper widget tests for search result cards.
- Add keyboard-overlay widget tests for small form viewports.
- Polish final store assets and copy after manual QA feedback.

## Required MVP Flows

| Flow | Status | Notes |
| --- | --- | --- |
| Auth/login/register | Ready for internal testing | Automated auth/onboarding tests pass; manual Supabase project verification still required. |
| Profile completion | Ready for internal testing | Required-field and route behavior covered by tests. |
| Feed | Ready for internal testing | Feed helpers and visibility tests pass; RLS should be rechecked in Supabase before broader beta. |
| Post creation | Ready for internal testing | Friendly error handling and refresh behavior covered by tests. |
| Event creation | Ready for internal testing | Normal and business event helper behavior covered by tests. |
| Event join/approve/reject | Ready for internal testing | Participant state helpers and visibility behavior covered by tests. |
| Profile | Ready for internal testing | Own/public/private profile paths need final manual QA on real accounts. |
| Username search/add friend | Ready for internal testing | Manual QA still required for public/private follow states. |
| Business application | Ready for internal testing | Application lifecycle is present. |
| Admin approval/reject | Ready for internal testing | Admin route and RPC paths are present; verify with real admin/non-admin accounts. |
| Business delete | Ready for internal testing | Delete flow and sponsored/deleted business safeguards are documented/tested. |
| Feedback | Ready for internal testing | User feedback form and admin feedback read path are present. |
| Settings/legal pages | Ready for internal testing | Pages exist with MVP placeholder legal copy. |
| Responsive layout | Ready for internal testing | Responsive tests and manual device matrix exist; full manual pass still required. |
| Android debug build | Passed | Debug APK and debug app bundle passed in RC build check. |

## Security Notes

- No Supabase `service_role` key was found in client runtime code.
- RLS/client exposure audit was completed for the MVP surface.
- Admin route is protected by app checks and admin RPCs are expected to verify
  `admin_users`.
- Search/profile/feed/event data should not expose email, phone, auth metadata,
  or private moderation fields; this still needs real-account manual QA.
- Sensitive raw Supabase error messages should not be shown to users.
- Before broader beta, verify the live Supabase project matches the audited
  migrations and policies.

## Remaining TODOs Before Closed Beta

- Run `docs/final_manual_qa_script.md` end to end on the responsive matrix.
- Record pass/fail evidence for auth, session restore, feed, events, business,
  admin, feedback, legal pages, report/block, and notifications.
- Verify Supabase RLS/RPC/storage behavior in the actual staging project.
- Prepare tester account instructions without exposing secrets.
- Confirm no user-facing raw `PostgrestException`, SQLSTATE, PGRST, or stack
  trace appears during manual QA.

## Decision Summary

Internal testing can start now with clear scope limits and prepared test
accounts. Closed beta should wait until manual QA and live Supabase policy
verification are complete. Public store submission should wait for production
signing, legal review, store assets, public privacy/data deletion URLs, and
final operational moderation/support readiness.
