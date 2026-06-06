# Closed Beta Test Accounts And Seed Data

Date: 2026-06-06

## Safety Rules

- Use a closed beta/staging Supabase project, not production.
- Do not commit real passwords, service keys, OAuth secrets, database passwords,
  auth tokens, or real personal data.
- Create passwords manually in Supabase Auth.
- Do not hardcode test account credentials in Flutter code.
- Do not add public admin shortcuts or fake seeded data to the app.
- Do not run seed SQL automatically.
- Prefer creating user-owned content through the app when testing RLS, RPC
  validation, media upload, and realtime refresh behavior.

## Required Test Accounts

### normal_user_a

- Email: `tester_a@example.com`
- Password: set manually in Supabase Auth.
- Purpose: baseline public user, event host, feed author, search/follow source.
- Needed profile state: completed profile with username `tester_a`, display
  name, city, district, birth date, and optional avatar.
- Privacy state: public.
- Business state: normal user, no active business account.
- Flows to test: login, session restore, profile completion, Home/feed, create
  post, create normal event, event detail, approve/reject participant, username
  search, follow public user, feedback, logout/login again.

### normal_user_b

- Email: `tester_b@example.com`
- Password: set manually in Supabase Auth.
- Purpose: participant account and public follow target.
- Needed profile state: completed profile with username `tester_b`.
- Privacy state: public.
- Business state: normal user, no active business account.
- Flows to test: login, Events list, join request, leave event, follow user A,
  public profile view, notifications, comments, feedback.

### private_user

- Email: `private_user@example.com`
- Password: set manually in Supabase Auth.
- Purpose: private profile and private follow request testing.
- Needed profile state: completed profile with username `private_user`.
- Privacy state: private.
- Business state: normal user, no active business account.
- Flows to test: private profile visibility, username search result safety,
  follow request receive/approve/reject, private gallery/event visibility.

### business_applicant

- Email: `business_applicant@example.com`
- Password: set manually in Supabase Auth.
- Purpose: pending business application path.
- Needed profile state: completed normal profile.
- Privacy state: public.
- Business state: no active business account; one pending business application.
- Flows to test: submit business application, duplicate pending application
  prevention, pending application messaging, admin review visibility.

### approved_business_user

- Email: `business_owner@example.com`
- Password: set manually in Supabase Auth.
- Purpose: active business mode and business event testing.
- Needed profile state: completed profile upgraded to business account mode.
- Privacy state: public.
- Business state: active approved business account tied to the same profile.
- Flows to test: business profile mode, create business event, business event
  join/approve/reject/confirmation if enabled, business delete, hidden/deleted
  business event visibility safeguards.

### admin_user

- Email: `admin_user@example.com`
- Password: set manually in Supabase Auth.
- Purpose: admin-only business application and feedback review.
- Needed profile state: completed profile.
- Privacy state: public.
- Business state: normal user is fine.
- Required database state: user ID exists in `public.admin_users`.
- Flows to test: admin route access, non-admin denial comparison,
  approve/reject business applications, feedback review list if available.

## Seed Data Plan

- Sample normal event: create in app as `normal_user_a`; `normal_user_b` sends a
  join request and host approves/rejects in separate passes.
- Sample business event: create in app as `approved_business_user` after the
  business account is active.
- Sample post: create in app as `normal_user_a`; optionally link it to the
  normal event.
- Sample private profile: set `private_user` to private in Settings.
- Sample follow request: `normal_user_a` requests to follow `private_user`.
- Sample business application: submit as `business_applicant`; keep one pending
  application for admin list testing.
- Sample feedback: submit as `normal_user_b` or `business_applicant`.
- Sample report if supported: create one staging-only report against a test
  post/event/profile; do not use real personal data.

## Manual Setup Checklist

- [ ] Confirm the target Supabase project is staging/closed beta, not production.
- [ ] Create users in Supabase Auth.
- [ ] Set passwords manually outside this repo.
- [ ] Log in as each user and complete profiles in the app.
- [ ] Make `private_user` private in Settings.
- [ ] Insert one `admin_users` row for `admin_user`.
- [ ] Create one business application as `business_applicant`.
- [ ] Approve one business user through the admin flow.
- [ ] Create one normal event as `normal_user_a`.
- [ ] Create one business event as `approved_business_user`.
- [ ] Create one sample post as `normal_user_a`.
- [ ] Create one pending follow request to `private_user`.
- [ ] Submit one feedback record.
- [ ] Create one report only if the report flow is supported in the current
      build.
- [ ] Verify search, follow, private request, event join, approve/reject, leave,
      business application, business delete, feedback, notifications, and
      logout/session restore flows on a real Android device.

## App Safety Check

- No test account credentials in Flutter code.
- No public admin shortcut visible to normal users.
- No fake seeded data hardcoded in the app.
- Admin access depends on server-side `admin_users`/RPC checks.
- Supabase Auth remains the source of users; one account remains one profile
  and one public identity.
- iOS cloud no-codesign build has passed; closed beta account setup is still
  Android-first for real-device QA unless a Mac/Xcode device pass is available.
- Firebase/push remains untouched.

## SQL Template

Optional review-only template:

```text
docs/seed_templates/closed_beta_seed_template.sql
```

The template contains placeholders only. Replace every placeholder, review the
target staging project, and run manually only if the team decides SQL seeding is
safer than creating that data through the app.
