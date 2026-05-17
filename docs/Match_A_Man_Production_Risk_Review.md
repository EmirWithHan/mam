# Match A Man Production Risk Review

## Current Readiness Estimate

- Demo readiness: 80%
- Public beta readiness: 55%
- Production launch readiness: 35%

The MVP appears strong enough for a controlled demo if the environment is prepared and the core flows are manually checked first. Public beta needs stronger confidence in RLS, privacy behavior, storage exposure, error handling, pagination, and moderation operations. Production launch requires more operational maturity: policies, terms, observability, test coverage, support flows, and real moderation handling.

## Demo Blockers

- App does not open on the demo device or fails because Supabase dart-define values are missing.
- Login/register fails for prepared test users.
- Profile completion or avatar upload blocks the event flow.
- Event creation fails or created events do not appear in Events.
- Join request, host approval, or participant status fails.
- Event chat cannot be opened by host/approved participant.
- Feed photo creation or image upload fails.
- Create Post linked event picker crashes or blocks posting without an event.
- Major visible UI overflow on the demo device.
- Navigation breaks between Home, Events, Create, Social, Profile, Settings, Notifications, and detail pages.
- Phone, birth date, or private profile fields are visibly exposed in public UI.
- Report/block actions appear on the current user's own content.

## Public Beta Blockers

- RLS policies are not independently reviewed for profiles, events, participants, posts, comments, follows, reports, blocks, trust logs, and storage.
- Storage privacy is unclear for avatars and post images.
- Phone/call access is not fully verified server-side.
- Blocked user behavior is inconsistent across feed, events, comments, social chat groups, and public previews.
- Reports are collected but there is no realistic moderation review process.
- Trust score is visible but may not be clearly explained or auditable.
- Lists lack pagination/limits and may become slow or expensive.
- Error states may expose raw backend errors to users.
- Email confirmation setting is not decided for beta.
- Privacy policy, terms, community rules, and safety language are missing.

## Security and Privacy Risks

- The `service_role` key must never appear in Flutter code, `.env`, launch configs committed to source, screenshots, or demo docs.
- Supabase anon/public key is expected in Flutter, but all sensitive access must be protected by RLS and RPC checks.
- Profile privacy needs careful verification: public previews should not expose phone, birth date, private identifiers, or unsafe metadata.
- Phone numbers should only be reachable through the controlled call flow for allowed host/approved participant cases.
- Birth date should be used for profile completion/trust context only, not public display.
- Public profile preview RPC should be reviewed to confirm it returns only safe fields.
- Post image bucket visibility must be intentional. Public buckets are simpler for MVP but increase exposure risk.
- Avatar bucket visibility must be intentional. Public avatars are acceptable only if the product treats avatars as public identity.
- Call RPC access must enforce event relationship and approved status on the backend, not only in UI.
- Linked event post creation has been hardened with RLS, but it should be tested with host, approved participant, pending participant, and unrelated user accounts.
- Reports and blocks tables should not expose reporter/blocker private relationships to unrelated users.
- Trust score logs should be private to the relevant user unless a public summary is explicitly intended.

## Backend/RLS Risks

- Verify policies for `profiles`, `events`, `event_participants`, `join_requests`, `event_messages`, `posts`, `post_likes`, `post_comments`, `follows`, `reports`, `blocks`, `trust_score_logs`, and storage buckets.
- RPC functions for call access, public profile preview, and trust score behavior need careful permission checks.
- Client-side filtering for blocked users is acceptable for MVP demos but weak for scale; backend should eventually enforce visibility.
- UI hiding self-report/self-block is good, but backend should also reject self-report/self-block if not already enforced.
- Event creation and join request eligibility should be enforced server-side, not only through profile-completion UI.
- Linked event association should be enforced server-side so users cannot attach posts to unrelated events.

## UX Risks

- First-user empty state risk is reduced, but a totally empty database can still feel thin in a live demo.
- Create Event is more capable now, but location permission and date/time selection can still create friction.
- Profile completion is required for important actions and may feel heavy if copy or validation is unclear.
- The name "Match A Man" can be misread as dating; sports/event-centered copy must remain consistent.
- Feed can overpower Events if Home becomes the perceived main product. Events should remain the clearest product loop.
- Trust score may confuse users if the score source and effects are not explained.
- Notifications page is a static shell; users may assume notifications are real unless the copy stays subtle.
- Social page must not imply direct messages are active before they exist.

## Technical Debt

- Shallow feature-first architecture is still appropriate, but some UI patterns are duplicated across sheets, selectors, cards, and empty/error states.
- Providers are manageable now, but feature state may become harder to reason about as flows grow.
- Automated test coverage is limited.
- Integration tests for auth, event creation, join approval, chat, feed posting, and safety flows are missing.
- Pagination and query limits are not consistently implemented.
- No crash reporting or structured logging.
- No analytics for funnel/drop-off visibility.
- Manual QA is carrying too much confidence.

## Must Fix Before Demo

- Confirm demo Supabase URL/anon key run config works.
- Run the manual demo script end to end with two test accounts.
- Verify no private phone or birth date appears publicly.
- Verify event create, join request, approval, chat, feed post, like/comment, report/block, and blocked users page do not crash.
- Prepare at least one clean event, one approved participant, one chat, and one feed post.

## Should Fix Before Public Beta

- Complete a written RLS/storage audit.
- Decide email confirmation behavior.
- Add pagination/limits to public lists.
- Add privacy policy, terms, and community/safety rules.
- Add moderation handling for reports.
- Improve user-facing error messages and reduce raw backend error exposure.
- Verify blocked user consistency across all major surfaces.
- Add basic crash/error logging.

## Can Wait Until Later

- Realtime chat.
- Push notifications.
- Direct messages.
- Embedded maps view.
- Business panel.
- Payments.
- Admin dashboard.
- Algorithmic feed.
- Advanced recommendations.

## Recommended Next 10 Prompts

- Prompt 73: Final Manual QA Bugfix Pass
  - Why it matters: catches demo-breaking route, UI, and callback issues.
  - Scope boundary: only fix bugs found while walking the manual checklist.

- Prompt 74: Storage Privacy Decision
  - Why it matters: avatars and post images need an intentional public/private model.
  - Scope boundary: document and verify behavior; no bucket migrations unless explicitly requested.

- Prompt 75: RLS Audit SQL Checklist
  - Why it matters: public beta depends on server-side enforcement.
  - Scope boundary: create checklist/docs only, not SQL changes.

- Prompt 76: Pagination and Query Limits
  - Why it matters: prevents slow screens and excessive reads.
  - Scope boundary: add simple limits/pagination to feed, events, comments, chat, and social lists.

- Prompt 77: Crash and Error Logging Plan
  - Why it matters: beta users will hit errors that manual QA misses.
  - Scope boundary: document or add minimal logging only if a tool is chosen.

- Prompt 78: Privacy Policy and Terms Draft
  - Why it matters: needed before real users submit profile, phone, images, and safety reports.
  - Scope boundary: draft documents, not legal finalization.

- Prompt 79: Demo Data Preparation Checklist
  - Why it matters: keeps demos repeatable and prevents awkward empty screens.
  - Scope boundary: checklist only, no seed data or SQL.

- Prompt 80: Release Build Checklist
  - Why it matters: separates dev success from installable release readiness.
  - Scope boundary: build/signing checklist only.

- Prompt 81: Store Asset Checklist
  - Why it matters: branding, screenshots, descriptions, and privacy disclosures take time.
  - Scope boundary: asset/document checklist only.

- Prompt 82: Public Beta Readiness Gate
  - Why it matters: creates a go/no-go decision before inviting real users.
  - Scope boundary: review checklist and risk status, no feature implementation.

## One Hard Recommendation

Before adding any big new feature, complete a strict RLS/storage/privacy audit and run the full manual QA checklist with fresh test users. The product is demoable, but public beta confidence should come from backend enforcement and privacy verification, not from UI behavior alone.
