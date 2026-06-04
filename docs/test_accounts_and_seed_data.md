# Closed Beta Test Accounts And Seed Data

Date: 2026-06-04

## Safety Rules

- Use a closed beta/staging Supabase project, not production.
- Do not commit real passwords, service keys, OAuth secrets, database passwords,
  auth tokens, or real personal data.
- Create passwords manually in Supabase Auth or through the app.
- Do not run seed SQL until every placeholder is replaced and the target
  Supabase project is confirmed.
- Prefer creating user-owned content through the app when testing RLS/user flows.

## Required Test Accounts

### normal_user_a

- Email: `tester_a@example.com`
- Password: set manually in Supabase Auth.
- Purpose: baseline public user, event host, feed author, search/follow source.
- Needed profile state: completed profile with username, name, city, district,
  birth date, and optional avatar.
- Needed privacy state: public.
- Needed business state: normal user, no active business account.
- Flows to test: login, session restore, profile completion, feed, create post,
  create normal event, event detail, approve/reject participant, username
  search, follow public user, feedback, logout.

### normal_user_b

- Email: `tester_b@example.com`
- Password: set manually in Supabase Auth.
- Purpose: participant account and public follow target.
- Needed profile state: completed profile.
- Needed privacy state: public.
- Needed business state: normal user, no active business account.
- Flows to test: login, join event, leave event, follow user A, public profile
  view, notifications, feedback.

### private_user

- Email: `private_user@example.com`
- Password: set manually in Supabase Auth.
- Purpose: private profile and private follow request testing.
- Needed profile state: completed profile.
- Needed privacy state: private.
- Needed business state: normal user, no active business account.
- Flows to test: private profile visibility, username search result safety,
  follow request receive/approve/reject, private gallery/event visibility.

### business_applicant

- Email: `business_applicant@example.com`
- Password: set manually in Supabase Auth.
- Purpose: pending business application path.
- Needed profile state: completed normal profile.
- Needed privacy state: public.
- Needed business state: no active business; one pending application.
- Flows to test: submit business application, duplicate pending application
  prevention, pending application messaging, admin review visibility.

### approved_business_user

- Email: `business_owner@example.com`
- Password: set manually in Supabase Auth.
- Purpose: active business mode and business event testing.
- Needed profile state: completed profile upgraded to business mode.
- Needed privacy state: public.
- Needed business state: active approved business account.
- Flows to test: business profile mode, create business event, business event
  join/approve/reject, business delete, sponsored/deleted visibility safeguards.

### admin_user

- Email: `admin_user@example.com`
- Password: set manually in Supabase Auth.
- Purpose: admin-only business application and feedback review.
- Needed profile state: completed profile.
- Needed privacy state: public.
- Needed business state: normal user is fine.
- Required database state: user ID exists in `public.admin_users`.
- Flows to test: admin route access, non-admin denial comparison, approve/reject
  business applications, review feedback list if available.

## Seed Data Plan

- Sample normal event: created by `normal_user_a`; joined by `normal_user_b`.
- Sample business event: created by `approved_business_user` after business
  approval.
- Sample post: created by `normal_user_a`, optionally linked to the normal
  event.
- Sample private profile: `private_user` with `is_private = true`.
- Sample follow request: `normal_user_a` requests to follow `private_user`.
- Sample business application: pending application for `business_applicant`.
- Sample feedback: submitted by `normal_user_b` or `business_applicant`.
- Sample report if supported: one report created by a normal user against a
  test post/event/profile, only in staging.

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
- [ ] Create one report only if report flow is supported in the current build.
- [ ] Verify search, follow, private request, event join, approve/reject, leave,
  business delete, feedback, and logout/session restore flows.

## App Safety Check

- No test account credentials should be present in Flutter code.
- No public admin shortcut should be visible to normal users.
- No seeded fake data should be hardcoded in Flutter.
- Admin access must depend on the server-side `admin_users`/RPC checks.
- Seed data should be created in Supabase staging or through the app, not baked
  into client code.

## SQL Template

Optional template:

```text
docs/seed_templates/closed_beta_seed_template.sql
```

This template is not run automatically. Replace every placeholder, review the
target project, and run only in a staging/closed beta Supabase database.
