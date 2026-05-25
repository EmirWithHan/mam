alter table public.profiles
  add column if not exists is_private boolean not null default false;

alter table public.posts
  add column if not exists comments_hidden boolean not null default false,
  add column if not exists is_archived boolean not null default false;

drop function if exists public.get_public_profile_detail(uuid);
drop function if exists public.get_public_profile_gallery(uuid);
drop function if exists public.get_public_profile_event_history(uuid);
drop function if exists public.update_my_gallery_post_controls(uuid, boolean, boolean);

create function public.get_public_profile_detail(p_user_id uuid)
returns table (
  user_id uuid,
  username text,
  tag text,
  first_name text,
  last_name text,
  city text,
  district text,
  avatar_url text,
  bio text,
  trust_score integer,
  is_private boolean,
  followers_count bigint,
  following_count bigint,
  is_following boolean,
  is_followed_by boolean,
  can_view_extended_profile boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.user_id,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.last_name::text,
    profile.city::text,
    profile.district::text,
    profile.avatar_url::text,
    profile.bio::text,
    profile.trust_score::integer,
    profile.is_private,
    (
      select count(*)
      from public.follows follower_rows
      where follower_rows.following_id = profile.user_id
    ) as followers_count,
    (
      select count(*)
      from public.follows following_rows
      where following_rows.follower_id = profile.user_id
    ) as following_count,
    exists (
      select 1
      from public.follows my_follow_rows
      where my_follow_rows.follower_id = auth.uid()
        and my_follow_rows.following_id = profile.user_id
    ) as is_following,
    exists (
      select 1
      from public.follows follows_me_rows
      where follows_me_rows.follower_id = profile.user_id
        and follows_me_rows.following_id = auth.uid()
    ) as is_followed_by,
    (
      auth.uid() = profile.user_id
      or profile.is_private = false
      or exists (
        select 1
        from public.follows viewer_follow_rows
        where viewer_follow_rows.follower_id = auth.uid()
          and viewer_follow_rows.following_id = profile.user_id
      )
    ) as can_view_extended_profile
  from public.profiles profile
  where profile.user_id = p_user_id
    and auth.uid() is not null;
$$;

create function public.get_public_profile_gallery(p_user_id uuid)
returns table (
  post_id uuid,
  image_url text,
  caption text,
  event_id uuid,
  comments_hidden boolean,
  is_archived boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    post.id as post_id,
    post.image_url::text,
    post.caption::text,
    post.event_id,
    post.comments_hidden,
    post.is_archived,
    post.created_at
  from public.posts post
  join public.profiles profile
    on profile.user_id = post.user_id
  where post.user_id = p_user_id
    and auth.uid() is not null
    and (
      auth.uid() = profile.user_id
      or (
        post.is_archived = false
        and (
          profile.is_private = false
          or exists (
            select 1
            from public.follows viewer_follow_rows
            where viewer_follow_rows.follower_id = auth.uid()
              and viewer_follow_rows.following_id = profile.user_id
          )
        )
      )
    )
  order by post.created_at desc;
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
  created_at timestamptz,
  role text
)
language sql
stable
security definer
set search_path = ''
as $$
  with target_profile as (
    select profile.user_id, profile.is_private
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
  order by created_at desc;
$$;

create function public.update_my_gallery_post_controls(
  p_post_id uuid,
  p_comments_hidden boolean default null,
  p_is_archived boolean default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  update public.posts
  set
    comments_hidden = coalesce(p_comments_hidden, comments_hidden),
    is_archived = coalesce(p_is_archived, is_archived),
    updated_at = now()
  where id = p_post_id
    and user_id = auth.uid();

  if not found then
    raise exception 'post_not_found';
  end if;
end;
$$;

revoke all on function public.get_public_profile_detail(uuid) from public;
revoke all on function public.get_public_profile_gallery(uuid) from public;
revoke all on function public.get_public_profile_event_history(uuid) from public;
revoke all on function public.update_my_gallery_post_controls(uuid, boolean, boolean) from public;

grant execute on function public.get_public_profile_detail(uuid)
  to authenticated, service_role;
grant execute on function public.get_public_profile_gallery(uuid)
  to authenticated, service_role;
grant execute on function public.get_public_profile_event_history(uuid)
  to authenticated, service_role;
grant execute on function public.update_my_gallery_post_controls(uuid, boolean, boolean)
  to authenticated, service_role;
