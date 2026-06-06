-- Closed beta seed template for Match A Man.
--
-- SAFETY:
-- - Do not run this against production.
-- - Do not run this automatically from scripts or app code.
-- - Do not commit real auth user IDs, passwords, tokens, service keys, or
--   personal data.
-- - Replace every placeholder with a real auth.users.id from the staging
--   Supabase project before manual execution.
-- - Prefer creating user-owned rows through the app when validating RLS,
--   RPC validation, media upload, notifications, and realtime refresh.
-- - This template intentionally contains placeholders so it fails if run
--   without review.

begin;

-- Required auth user placeholders:
-- <USER_A_ID> normal_user_a / tester_a@example.com
-- <USER_B_ID> normal_user_b / tester_b@example.com
-- <PRIVATE_USER_ID> private_user / private_user@example.com
-- <BUSINESS_APPLICANT_ID> business_applicant / business_applicant@example.com
-- <BUSINESS_USER_ID> approved_business_user / business_owner@example.com
-- <ADMIN_USER_ID> admin_user / admin_user@example.com
--
-- Passwords are set manually in Supabase Auth and are never stored here.

-- 1. Admin marker.
insert into public.admin_users (user_id)
values ('<ADMIN_USER_ID>')
on conflict (user_id) do nothing;

-- 2. Profile states.
-- Run after the users have been created in Supabase Auth and profile rows have
-- been created by logging into the app at least once.
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

update public.profiles
set
  username = 'business_applicant',
  first_name = 'Business Applicant',
  city = 'Istanbul',
  district = 'Sisli',
  birth_date = date '1993-04-04',
  is_private = false,
  is_profile_completed = true,
  account_type = 'user'
where user_id = '<BUSINESS_APPLICANT_ID>';

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
  category,
  business_phone,
  full_address,
  website,
  description,
  status
)
values (
  '<BUSINESS_APPLICANT_ID>',
  'Closed Beta Spor Salonu',
  'Spor Salonu',
  '+905551112233',
  'Kapali beta test adresi, Istanbul',
  'https://example.com',
  'Closed beta test business application.',
  'pending'
)
on conflict do nothing;

-- 5. Approved business user state.
-- Prefer approving through the app/admin RPC. Use direct SQL only when the
-- manual admin flow is blocked and the staging schema has been reviewed.
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
  birth_date = date '1990-05-05',
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

-- 7. Sample normal event.
-- Prefer creating this through the app as normal_user_a. Uncomment only after
-- reviewing the live events schema, constraints, and trigger behavior.
-- insert into public.events (
--   host_id,
--   title,
--   description,
--   sport_type,
--   city,
--   district,
--   location_text,
--   event_date,
--   capacity_total,
--   capacity_male,
--   capacity_female,
--   capacity_any,
--   approved_count,
--   status,
--   organizer_type,
--   organizer_user_id
-- )
-- values (
--   '<USER_A_ID>',
--   'Closed Beta Normal Etkinlik',
--   'Closed beta normal event seed sample.',
--   'Futbol',
--   'Istanbul',
--   'Kadikoy',
--   'Closed beta saha',
--   now() + interval '7 days',
--   10,
--   0,
--   0,
--   10,
--   0,
--   'active',
--   'user',
--   '<USER_A_ID>'
-- );

-- 8. Sample business event.
-- Prefer creating this through the app as approved_business_user after the
-- business account is active. The organizer_business_id must be the real
-- business_accounts.id for <BUSINESS_USER_ID>.
-- insert into public.events (
--   host_id,
--   title,
--   description,
--   sport_type,
--   city,
--   district,
--   location_text,
--   event_date,
--   capacity_total,
--   capacity_male,
--   capacity_female,
--   capacity_any,
--   approved_count,
--   status,
--   organizer_type,
--   organizer_user_id,
--   organizer_business_id,
--   is_paid,
--   price_amount,
--   price_currency
-- )
-- values (
--   '<BUSINESS_USER_ID>',
--   'Closed Beta Business Etkinlik',
--   'Closed beta business event seed sample.',
--   'Futbol',
--   'Istanbul',
--   'Kadikoy',
--   'Closed Beta Arena',
--   now() + interval '10 days',
--   20,
--   0,
--   0,
--   20,
--   0,
--   'active',
--   'business',
--   '<BUSINESS_USER_ID>',
--   '<BUSINESS_ACCOUNT_ID>',
--   false,
--   null,
--   'TRY'
-- );

-- 9. Sample post.
-- Prefer creating this through the app so storage/media behavior is tested.
-- If direct SQL is required, replace image_url with a staging-safe test image.
-- insert into public.posts (
--   user_id,
--   image_url,
--   caption,
--   comments_hidden,
--   is_archived
-- )
-- values (
--   '<USER_A_ID>',
--   'https://example.com/closed-beta-placeholder.jpg',
--   'Closed beta post seed sample.',
--   false,
--   false
-- );

-- 10. Optional report sample.
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

commit;
