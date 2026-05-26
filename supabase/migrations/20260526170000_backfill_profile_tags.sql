alter table public.profiles
  add column if not exists tag text;

alter table public.profiles
  alter column tag set default lpad(floor(random() * 10000)::int::text, 4, '0');

update public.profiles
set tag = lpad(floor(random() * 10000)::int::text, 4, '0')
where tag is null
   or trim(tag) = ''
   or tag !~ '^\d{4}$';

alter table public.profiles
  alter column tag set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_tag_four_digits'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_tag_four_digits check (tag ~ '^\d{4}$');
  end if;
end $$;

create unique index if not exists profiles_username_tag_unique
  on public.profiles (username, tag)
  where username is not null and tag is not null;

drop function if exists public.get_public_profile_preview(text);
drop function if exists public.get_public_profile_preview(uuid);
drop function if exists public.get_public_profile_previews(text[]);
drop function if exists public.get_public_profile_followers(text, integer, integer);
drop function if exists public.get_public_profile_following(text, integer, integer);
drop function if exists public.get_event_public_participants(text);
drop function if exists public.get_event_public_participants(uuid);

create function public.get_public_profile_preview(p_user_id text)
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    profile.trust_score::integer,
    coalesce(profile.is_profile_completed, false)
  from public.profiles profile
  where profile.user_id::text = p_user_id
    and auth.uid() is not null;
$$;

create function public.get_public_profile_previews(p_user_ids text[])
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    profile.trust_score::integer,
    coalesce(profile.is_profile_completed, false)
  from public.profiles profile
  where profile.user_id::text = any(p_user_ids)
    and auth.uid() is not null;
$$;

create function public.get_public_profile_followers(
  p_user_id text,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id text,
  username text,
  tag text,
  full_name text,
  avatar_url text,
  city text,
  district text,
  bio text,
  trust_score integer,
  follower_count bigint,
  following_count bigint,
  is_following_by_me boolean,
  follows_me boolean,
  is_private boolean,
  pending_follow_request_by_me boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    follower_profile.user_id::text,
    follower_profile.username::text,
    follower_profile.tag::text,
    nullif(trim(follower_profile.first_name), '') as full_name,
    follower_profile.avatar_url::text,
    follower_profile.city::text,
    follower_profile.district::text,
    follower_profile.bio::text,
    follower_profile.trust_score::integer,
    (select count(*) from public.follows rows where rows.following_id::text = follower_profile.user_id::text) as follower_count,
    (select count(*) from public.follows rows where rows.follower_id::text = follower_profile.user_id::text) as following_count,
    exists (
      select 1 from public.follows rows
      where rows.follower_id::text = auth.uid()::text
        and rows.following_id::text = follower_profile.user_id::text
    ) as is_following_by_me,
    exists (
      select 1 from public.follows rows
      where rows.follower_id::text = follower_profile.user_id::text
        and rows.following_id::text = auth.uid()::text
    ) as follows_me,
    coalesce(follower_profile.is_private, false) as is_private,
    exists (
      select 1 from public.follow_requests rows
      where rows.requester_id::text = auth.uid()::text
        and rows.target_user_id::text = follower_profile.user_id::text
        and rows.status = 'pending'
    ) as pending_follow_request_by_me,
    null::timestamptz as created_at
  from public.follows follow_rows
  join public.profiles follower_profile
    on follower_profile.user_id::text = follow_rows.follower_id::text
  where follow_rows.following_id::text = p_user_id
    and auth.uid() is not null
  order by lower(coalesce(follower_profile.username, '')), follower_profile.user_id::text
  limit least(greatest(coalesce(p_limit, 50), 0), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create function public.get_public_profile_following(
  p_user_id text,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id text,
  username text,
  tag text,
  full_name text,
  avatar_url text,
  city text,
  district text,
  bio text,
  trust_score integer,
  follower_count bigint,
  following_count bigint,
  is_following_by_me boolean,
  follows_me boolean,
  is_private boolean,
  pending_follow_request_by_me boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    following_profile.user_id::text,
    following_profile.username::text,
    following_profile.tag::text,
    nullif(trim(following_profile.first_name), '') as full_name,
    following_profile.avatar_url::text,
    following_profile.city::text,
    following_profile.district::text,
    following_profile.bio::text,
    following_profile.trust_score::integer,
    (select count(*) from public.follows rows where rows.following_id::text = following_profile.user_id::text) as follower_count,
    (select count(*) from public.follows rows where rows.follower_id::text = following_profile.user_id::text) as following_count,
    exists (
      select 1 from public.follows rows
      where rows.follower_id::text = auth.uid()::text
        and rows.following_id::text = following_profile.user_id::text
    ) as is_following_by_me,
    exists (
      select 1 from public.follows rows
      where rows.follower_id::text = following_profile.user_id::text
        and rows.following_id::text = auth.uid()::text
    ) as follows_me,
    coalesce(following_profile.is_private, false) as is_private,
    exists (
      select 1 from public.follow_requests rows
      where rows.requester_id::text = auth.uid()::text
        and rows.target_user_id::text = following_profile.user_id::text
        and rows.status = 'pending'
    ) as pending_follow_request_by_me,
    null::timestamptz as created_at
  from public.follows follow_rows
  join public.profiles following_profile
    on following_profile.user_id::text = follow_rows.following_id::text
  where follow_rows.follower_id::text = p_user_id
    and auth.uid() is not null
  order by lower(coalesce(following_profile.username, '')), following_profile.user_id::text
  limit least(greatest(coalesce(p_limit, 50), 0), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create function public.get_event_public_participants(p_event_id text)
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  role text,
  attendance_status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    participant.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    participant.role::text,
    participant.attendance_status::text
  from public.event_participants participant
  join public.profiles profile
    on profile.user_id = participant.user_id
  where participant.event_id::text = p_event_id
    and auth.uid() is not null;
$$;

revoke all on function public.get_public_profile_preview(text) from public;
revoke all on function public.get_public_profile_previews(text[]) from public;
revoke all on function public.get_public_profile_followers(text, integer, integer) from public;
revoke all on function public.get_public_profile_following(text, integer, integer) from public;
revoke all on function public.get_event_public_participants(text) from public;

grant execute on function public.get_public_profile_preview(text) to authenticated;
grant execute on function public.get_public_profile_previews(text[]) to authenticated;
grant execute on function public.get_public_profile_followers(text, integer, integer) to authenticated;
grant execute on function public.get_public_profile_following(text, integer, integer) to authenticated;
grant execute on function public.get_event_public_participants(text) to authenticated;
