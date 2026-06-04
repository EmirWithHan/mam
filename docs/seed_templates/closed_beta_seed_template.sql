-- Closed beta seed template for Match A Man.
--
-- SAFETY:
-- - Do not run this against production.
-- - Do not commit real auth user IDs, passwords, tokens, service keys, or
--   personal data.
-- - Replace every <PLACEHOLDER_ID> with a real auth.users.id from the staging
--   Supabase project before running.
-- - Prefer creating user-owned rows through the app when validating RLS.
-- - This template intentionally contains placeholders so it fails if run
--   without review.

begin;

-- Required auth user placeholders:
-- <USER_A_ID>             normal_user_a
-- <USER_B_ID>             normal_user_b
-- <PRIVATE_USER_ID>       private_user
-- <BUSINESS_APPLICANT_ID> business_applicant
-- <BUSINESS_USER_ID>      approved_business_user
-- <ADMIN_USER_ID>         admin_user

-- 1. Admin marker.
insert into public.admin_users (user_id)
values ('<ADMIN_USER_ID>')
on conflict (user_id) do nothing;

-- 2. Profile states.
-- Run after the users have been created in Supabase Auth. Adjust column names
-- if your live schema differs from the current migrations.
update public.profiles
set
  username = 'tester_a',
  first_name = 'Tester A',
  city = 'Istanbul',
  district = 'Kadikoy',
  birth_date = date '1995-01-01',
  is_private = false,
  is_profile_completed = true,
  account_type = 'user'
where user_id = '<USER_A_ID>';

update public.profiles
set
  username = 'tester_b',
  first_name = 'Tester B',
  city = 'Istanbul',
  district = 'Besiktas',
  birth_date = date '1996-02-02',
  is_private = false,
  is_profile_completed = true,
  account_type = 'user'
where user_id = '<USER_B_ID>';

update public.profiles
set
  username = 'private_user',
  first_name = 'Private User',
  city = 'Istanbul',
  district = 'Uskudar',
  birth_date = date '1994-03-03',
  is_private = true,
  is_profile_completed = true,
  account_type = 'user'
where user_id = '<PRIVATE_USER_ID>';

-- 3. Pending private follow request.
insert into public.follow_requests (
  requester_id,
  target_user_id,
  status
)
values (
  '<USER_A_ID>',
  '<PRIVATE_USER_ID>',
  'pending'
)
on conflict do nothing;

-- 4. Pending business application.
insert into public.business_applications (
  user_id,
  business_name,
  business_phone,
  full_address,
  website,
  description,
  status
)
values (
  '<BUSINESS_APPLICANT_ID>',
  'Closed Beta Spor Salonu',
  '+905551112233',
  'Kapali beta test adresi, Istanbul',
  'https://example.com',
  'Closed beta test business application.',
  'pending'
)
on conflict do nothing;

-- 5. Approved business user state.
-- If possible, prefer approving through the app/admin RPC instead of direct SQL.
insert into public.business_accounts (
  owner_user_id,
  name,
  username,
  business_tag,
  category,
  city,
  district,
  address,
  description,
  phone,
  website,
  is_verified,
  status
)
values (
  '<BUSINESS_USER_ID>',
  'Closed Beta Arena',
  'closed_beta_arena',
  '9001',
  'Spor Salonu',
  'Istanbul',
  'Kadikoy',
  'Closed beta business address, Istanbul',
  'Closed beta approved business account.',
  '+905559998877',
  'https://example.com',
  true,
  'active'
)
on conflict do nothing;

update public.profiles
set
  username = 'closed_beta_arena',
  first_name = 'Closed Beta Arena',
  city = 'Istanbul',
  district = 'Kadikoy',
  birth_date = date '1990-04-04',
  is_private = false,
  is_profile_completed = true,
  account_type = 'business'
where user_id = '<BUSINESS_USER_ID>';

-- 6. Feedback sample.
insert into public.user_feedback (
  user_id,
  rating,
  category,
  message,
  source
)
values (
  '<USER_B_ID>',
  5,
  'closed_beta',
  'Closed beta feedback seed sample.',
  'seed_template'
);

-- 7. Optional report sample.
-- Uncomment only after confirming the current reports schema and target entity.
-- insert into public.reports (
--   reporter_id,
--   target_type,
--   target_id,
--   reason,
--   description
-- )
-- values (
--   '<USER_A_ID>',
--   'profile',
--   '<USER_B_ID>',
--   'closed_beta_test',
--   'Closed beta report seed sample.'
-- );

-- 8. Normal/business events and posts are safest to create through the app so
-- RLS, RPC validation, media upload, and UI refresh behavior are tested.

commit;
