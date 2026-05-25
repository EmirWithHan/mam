drop function if exists public.get_public_profile_followers(uuid, integer, integer);
drop function if exists public.get_public_profile_followers(text, integer, integer);
drop function if exists public.get_public_profile_following(uuid, integer, integer);
drop function if exists public.get_public_profile_following(text, integer, integer);
drop function if exists public.get_public_profile_event_history(uuid);

create function public.get_public_profile_followers(
  p_user_id text,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id text,
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
    follower_profile.user_id::text,
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
      where follower_count_rows.following_id::text = follower_profile.user_id::text
    ) as follower_count,
    (
      select count(*)
      from public.follows following_count_rows
      where following_count_rows.follower_id::text = follower_profile.user_id::text
    ) as following_count,
    exists (
      select 1
      from public.follows my_follow_rows
      where my_follow_rows.follower_id::text = auth.uid()::text
        and my_follow_rows.following_id::text = follower_profile.user_id::text
    ) as is_following_by_me,
    exists (
      select 1
      from public.follows follows_me_rows
      where follows_me_rows.follower_id::text = follower_profile.user_id::text
        and follows_me_rows.following_id::text = auth.uid()::text
    ) as follows_me,
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
    following_profile.user_id::text,
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
      where follower_count_rows.following_id::text = following_profile.user_id::text
    ) as follower_count,
    (
      select count(*)
      from public.follows following_count_rows
      where following_count_rows.follower_id::text = following_profile.user_id::text
    ) as following_count,
    exists (
      select 1
      from public.follows my_follow_rows
      where my_follow_rows.follower_id::text = auth.uid()::text
        and my_follow_rows.following_id::text = following_profile.user_id::text
    ) as is_following_by_me,
    exists (
      select 1
      from public.follows follows_me_rows
      where follows_me_rows.follower_id::text = following_profile.user_id::text
        and follows_me_rows.following_id::text = auth.uid()::text
    ) as follows_me,
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

create function public.get_public_profile_event_history(p_user_id uuid)
returns table (
  event_id uuid,
  title text,
  sport_type text,
  city text,
  district text,
  location_text text,
  status text,
  approved_count integer,
  capacity_total integer,
  event_date timestamptz,
  created_at timestamptz,
  role text
)
language sql
stable
security definer
set search_path = ''
as $$
  with target_profile as (
    select profile.user_id, coalesce(profile.is_private, false) as is_private
    from public.profiles profile
    where profile.user_id = p_user_id
  ),
  visibility as (
    select
      target_profile.user_id,
      (
        auth.uid() = target_profile.user_id
        or target_profile.is_private = false
        or exists (
          select 1
          from public.follows viewer_follow_rows
          where viewer_follow_rows.follower_id = auth.uid()
            and viewer_follow_rows.following_id = target_profile.user_id
        )
      ) as can_view
    from target_profile
    where auth.uid() is not null
  ),
  hosted_events as (
    select
      event.id as event_id,
      event.title::text,
      event.sport_type::text,
      event.city::text,
      event.district::text,
      event.location_text::text,
      event.status::text,
      event.approved_count::integer,
      event.capacity_total::integer,
      event.event_date,
      event.created_at,
      'host'::text as role
    from public.events event
    join visibility on visibility.user_id = event.host_id
    where visibility.can_view
  ),
  participant_events as (
    select
      event.id as event_id,
      event.title::text,
      event.sport_type::text,
      event.city::text,
      event.district::text,
      event.location_text::text,
      event.status::text,
      event.approved_count::integer,
      event.capacity_total::integer,
      event.event_date,
      event.created_at,
      'participant'::text as role
    from public.event_participants participant
    join public.events event
      on event.id = participant.event_id
    join visibility
      on visibility.user_id = participant.user_id
    where visibility.can_view
      and participant.attendance_status in ('planned', 'attended')
      and participant.role = 'participant'
  )
  select *
  from hosted_events
  union all
  select *
  from participant_events
  order by event_date desc;
$$;

revoke all on function public.get_public_profile_followers(text, integer, integer)
  from public;
revoke all on function public.get_public_profile_following(text, integer, integer)
  from public;
revoke all on function public.get_public_profile_event_history(uuid)
  from public;

grant execute on function public.get_public_profile_followers(text, integer, integer)
  to authenticated, service_role;
grant execute on function public.get_public_profile_following(text, integer, integer)
  to authenticated, service_role;
grant execute on function public.get_public_profile_event_history(uuid)
  to authenticated, service_role;
