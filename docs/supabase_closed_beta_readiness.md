# Supabase Closed Beta Readiness

Date: 2026-06-06

## Current Supabase Setup

### Auth

- Supabase Auth is the authentication source.
- Flutter reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `--dart-define`.
- The app does not use or require a `service_role` key.
- One auth account maps to one profile row and one public identity.

### Database

- Core data lives in public schema tables such as `profiles`, `posts`,
  `post_comments`, `events`, `event_participants`, `event_join_requests`,
  `follows`, `follow_requests`, `notifications`, `business_accounts`,
  `business_applications`, `business_reviews`, `user_feedback`, `reports`,
  `blocks`, `rate_limit_events`, and `admin_users`.
- RLS hardening is centralized in
  `20260604193000_mvp_rls_security_hardening.sql`.
- Android real-device blocker grants/policies are in
  `20260605010000_android_device_blocker_fixes.sql`.
- Events recursion was fixed in
  `20260606090000_fix_events_rls_infinite_recursion.sql`.

### Storage

- Flutter uses Supabase Storage buckets named `post-images` and `avatars`.
- No committed storage bucket/policy migration was found in this audit.
- Bucket existence, public/private settings, upload limits, and object policies
  must be verified manually in the Supabase dashboard before closed beta.

### Realtime

- In-app realtime is used for notifications, comments, and selected state
  refreshes.
- Realtime does not replace RLS. Queries and subscriptions must still be scoped
  to the authenticated user or visible public data.
- Manual refresh fallback remains important for beta.

### RLS

- RLS is enabled for audited user-data tables in the latest hardening
  migrations.
- `anon` grants are revoked for user-data tables in the hardening migration.
- `rate_limit_events` and `admin_users` direct table grants are revoked from
  authenticated clients.

### RPCs

- Public profile/search/feed/admin list functions are `SECURITY DEFINER` where
  needed and granted to `authenticated`.
- Admin operations check `admin_users` through `is_current_user_admin()`.
- Business approval/delete and event join/attendance actions are RPC-based.
- Notification mark-read RPCs were added in
  `20260606120000_notification_mark_read_rpcs.sql`.
- That migration drops/recreates the mark-read RPCs first because older
  environments may already have the same function names with a different return
  type.

### Edge Functions

- No Supabase Edge Functions were found in the repo during this audit.

## What Is Safe For Beta

- The anon/publishable key is acceptable in mobile builds when passed by
  `--dart-define`.
- No `service_role` key is used in Flutter source or committed example scripts.
- Normal client access depends on RLS and least-privilege RPCs rather than secret
  client credentials.
- Admin checks are done through `admin_users`; non-admin users should not be
  able to approve/reject applications or read all applications.
- Business approval keeps the same profile/public identity and uses
  `business_accounts` for business mode.
- Business delete is owner-scoped, restores user mode, marks the business row
  deleted, cancels future business events, and clears sponsorship fields.
- Rate limiting is recorded through `check_and_record_rate_limit`; direct table
  access is revoked.
- Username search returns a safe public model and excludes email, phone, auth
  metadata, and moderation fields.
- Events policy no longer queries `events` from inside the `events` policy.

## Audit Findings

### Secret And Config Audit

- No real Supabase URL, anon key, service-role key, JWT secret, OAuth client
  secret, database password, keystore password, or signing password was found in
  source/docs/scripts during this scan.
- Existing build docs and scripts use placeholders only.
- `.gitignore` now ignores `.env`, local env variants, local PowerShell build
  scripts, `key.properties`, `*.jks`, and `*.keystore`.

### RLS And Policy Check

- `profiles`: owner-writable RLS exists. Public profile reads are routed through
  safe RPCs.
- `posts` and `post_comments`: visibility follows social/private profile rules;
  writes are owner-scoped.
- `events`: latest select policy avoids recursion and limits public visibility
  to active/completed personal events or active-business events; owners/admins
  can see needed rows.
- `event_participants` and `event_join_requests`: reads are requester,
  participant, or host-scoped; writes are own/request RPC-based where needed.
- `follows` and `follow_requests`: participant-scoped policies/RPCs exist for
  private follow requests.
- `notifications`: users can read/update own notifications only; mark-read RPCs
  are owner-scoped.
- `business_accounts`: active or owner-visible; owner update is allowed but
  moderation fields are protected by trigger.
- `business_applications`: users can submit/read own application; admins can
  list/review through admin-checked RPCs.
- `business_reviews`: direct reads are scoped to reviewer or business owner;
  submission is RPC-based.
- `user_feedback`: users can submit/read own feedback; admins can read all.
- `reports` and `blocks`: reporter/blocker-scoped policies exist.
- `rate_limit_events`: RLS enabled, direct access revoked, RPC inserts
  owner-scoped rows.
- `admin_users`: RLS enabled and direct authenticated grants revoked in the
  hardening migration.

### RPC And Grant Check

- Public/feed/search/profile RPC grants for authenticated users are present.
- Business application list/approve/reject RPCs check admin status.
- Event participant/attendance RPCs check host or business ownership.
- Notification mark-read RPCs were missing from migrations and were added.
- No broad `anon` table grants were found in the latest hardening pass.

### Client Query Check

- Events list uses explicit selected columns, pagination, status filtering, and
  local blocked-user filtering.
- Username search uses the safe `search_profiles_by_username` RPC.
- Notifications select explicit fields and filter by `recipient_id`.
- Admin application list uses `list_pending_business_applications` RPC rather
  than direct normal-page table reads.
- Some owner-only services still use `.select()` for own rows
  (`profiles`, `business_accounts`, `business_applications`). This is acceptable
  for beta when RLS is correct, but should be narrowed before production if
  columns grow.

## Known Backend Risks

- Storage buckets/policies are not represented in migrations and need manual
  dashboard verification.
- Production/staging separation still needs a manual environment decision.
- Backups/PITR and restore drills are not documented as complete.
- Supabase log monitoring/alerting is not documented as complete.
- Live RLS behavior must still be verified against the actual staging project
  after `supabase db push`.
- Existing historical migrations include older policies/functions that are
  superseded later; verify the final applied schema, not only individual old
  files.

## Manual Supabase Checklist

- [ ] Run pending migrations on staging with `supabase db push`.
- [ ] Confirm RLS is enabled on all user-data tables.
- [ ] Confirm `anon` does not have unnecessary table access.
- [ ] Confirm no `service_role` key is present in Flutter, docs, scripts, CI
      logs, APK build commands, or screenshots.
- [ ] Confirm `admin_users` contains only intended admin accounts.
- [ ] Confirm `business_applications` policies allow own submit/status and
      admin-only list/review.
- [ ] Confirm normal user can open Events, Event detail, Profile, Settings,
      Notifications, Username search, Feedback, and Business application.
- [ ] Confirm Events list excludes cancelled/deleted business events.
- [ ] Confirm sponsored placement only appears for active, verified business
      events with valid sponsorship windows.
- [ ] Confirm `mark_notification_read` and `mark_all_notifications_read` work
      for the current user only.
- [ ] Confirm `rate_limit_events` cannot be read or written directly by normal
      clients.
- [ ] Confirm Storage buckets `post-images` and `avatars` exist.
- [ ] Confirm Storage object policies restrict uploads to the authenticated
      user path and do not expose private files unintentionally.
- [ ] Confirm no fake/test data exists in production unless intentionally used
      for closed beta.

## Manual Commands

Apply the new migration to the linked Supabase project:

```bash
supabase db push
```

Build/run the app with placeholders replaced locally or in CI secrets:

```bash
flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Do not commit real keys, passwords, signing files, or local scripts.
