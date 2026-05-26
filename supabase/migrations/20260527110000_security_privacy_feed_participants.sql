drop function if exists public.get_visible_feed_posts();

create function public.get_visible_feed_posts()
returns setof public.posts
language sql
stable
security definer
set search_path = ''
as $$
  select post.*
  from public.posts post
  join public.profiles author_profile
    on author_profile.user_id = post.user_id
  where auth.uid() is not null
    and coalesce(post.is_archived, false) = false
    and (
      author_profile.user_id = auth.uid()
      or coalesce(author_profile.is_private, false) = false
      or exists (
        select 1
        from public.follows viewer_follow_rows
        where viewer_follow_rows.follower_id = auth.uid()
          and viewer_follow_rows.following_id = author_profile.user_id
      )
    )
    and not exists (
      select 1
      from public.blocks block_rows
      where (
        block_rows.blocker_id = auth.uid()
        and block_rows.blocked_id = author_profile.user_id
      )
      or (
        block_rows.blocker_id = author_profile.user_id
        and block_rows.blocked_id = auth.uid()
      )
    )
  order by post.created_at desc;
$$;

drop function if exists public.get_event_public_participants(text);

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
    and auth.uid() is not null
    and (
      participant.role = 'host'
      or (
        participant.role = 'participant'
        and participant.attendance_status in ('planned', 'attended')
      )
    );
$$;

revoke all on function public.get_visible_feed_posts() from public;
revoke all on function public.get_event_public_participants(text) from public;

grant execute on function public.get_visible_feed_posts() to authenticated;
grant execute on function public.get_event_public_participants(text) to authenticated;
