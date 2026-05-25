drop function if exists public.get_public_profile_followers(uuid, integer, integer);
drop function if exists public.get_public_profile_following(uuid, integer, integer);

create function public.get_public_profile_followers(
  p_user_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id uuid,
  username text,
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
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    follower_profile.user_id,
    follower_profile.username::text,
    nullif(
      concat_ws(
        ' ',
        nullif(trim(follower_profile.first_name), ''),
        nullif(trim(follower_profile.last_name), '')
      ),
      ''
    ) as full_name,
    follower_profile.avatar_url::text,
    follower_profile.city::text,
    follower_profile.district::text,
    follower_profile.bio::text,
    follower_profile.trust_score::integer,
    (
      select count(*)
      from public.follows follower_count_rows
      where follower_count_rows.following_id = follower_profile.user_id
    ) as follower_count,
    (
      select count(*)
      from public.follows following_count_rows
      where following_count_rows.follower_id = follower_profile.user_id
    ) as following_count,
    exists (
      select 1
      from public.follows my_follow_rows
      where my_follow_rows.follower_id = auth.uid()
        and my_follow_rows.following_id = follower_profile.user_id
    ) as is_following_by_me,
    exists (
      select 1
      from public.follows follows_me_rows
      where follows_me_rows.follower_id = follower_profile.user_id
        and follows_me_rows.following_id = auth.uid()
    ) as follows_me,
    follow_rows.created_at
  from public.follows follow_rows
  join public.profiles follower_profile
    on follower_profile.user_id = follow_rows.follower_id
  where follow_rows.following_id = p_user_id
    and auth.uid() is not null
  order by follow_rows.created_at desc, follower_profile.user_id
  limit least(greatest(coalesce(p_limit, 50), 0), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create function public.get_public_profile_following(
  p_user_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id uuid,
  username text,
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
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    following_profile.user_id,
    following_profile.username::text,
    nullif(
      concat_ws(
        ' ',
        nullif(trim(following_profile.first_name), ''),
        nullif(trim(following_profile.last_name), '')
      ),
      ''
    ) as full_name,
    following_profile.avatar_url::text,
    following_profile.city::text,
    following_profile.district::text,
    following_profile.bio::text,
    following_profile.trust_score::integer,
    (
      select count(*)
      from public.follows follower_count_rows
      where follower_count_rows.following_id = following_profile.user_id
    ) as follower_count,
    (
      select count(*)
      from public.follows following_count_rows
      where following_count_rows.follower_id = following_profile.user_id
    ) as following_count,
    exists (
      select 1
      from public.follows my_follow_rows
      where my_follow_rows.follower_id = auth.uid()
        and my_follow_rows.following_id = following_profile.user_id
    ) as is_following_by_me,
    exists (
      select 1
      from public.follows follows_me_rows
      where follows_me_rows.follower_id = following_profile.user_id
        and follows_me_rows.following_id = auth.uid()
    ) as follows_me,
    follow_rows.created_at
  from public.follows follow_rows
  join public.profiles following_profile
    on following_profile.user_id = follow_rows.following_id
  where follow_rows.follower_id = p_user_id
    and auth.uid() is not null
  order by follow_rows.created_at desc, following_profile.user_id
  limit least(greatest(coalesce(p_limit, 50), 0), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.get_public_profile_followers(uuid, integer, integer)
  from public;
revoke all on function public.get_public_profile_following(uuid, integer, integer)
  from public;

grant execute on function public.get_public_profile_followers(uuid, integer, integer)
  to authenticated, service_role;
grant execute on function public.get_public_profile_following(uuid, integer, integer)
  to authenticated, service_role;
