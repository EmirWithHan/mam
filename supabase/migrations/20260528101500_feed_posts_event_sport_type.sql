drop function if exists public.get_visible_feed_posts_with_stats();

create function public.get_visible_feed_posts_with_stats()
returns table (
  id uuid,
  user_id uuid,
  event_id uuid,
  image_url text,
  caption text,
  comments_hidden boolean,
  is_archived boolean,
  event_sport_type text,
  author_username text,
  author_tag text,
  author_avatar_url text,
  created_at timestamptz,
  updated_at timestamptz,
  like_count bigint,
  comment_count bigint,
  is_liked_by_me boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    post.id,
    post.user_id,
    post.event_id,
    post.image_url::text,
    post.caption::text,
    coalesce(post.comments_hidden, false) as comments_hidden,
    coalesce(post.is_archived, false) as is_archived,
    linked_event.sport_type::text as event_sport_type,
    author_profile.username::text as author_username,
    author_profile.tag::text as author_tag,
    author_profile.avatar_url::text as author_avatar_url,
    post.created_at,
    post.updated_at,
    (
      select count(*)
      from public.post_likes like_rows
      where like_rows.post_id = post.id
    ) as like_count,
    case
      when coalesce(post.comments_hidden, false)
        and post.user_id <> auth.uid()
      then 0
      else (
        select count(*)
        from public.post_comments comment_rows
        where comment_rows.post_id = post.id
      )
    end as comment_count,
    exists (
      select 1
      from public.post_likes my_like_rows
      where my_like_rows.post_id = post.id
        and my_like_rows.user_id = auth.uid()
    ) as is_liked_by_me
  from public.posts post
  join public.profiles author_profile
    on author_profile.user_id = post.user_id
  left join public.events linked_event
    on linked_event.id = post.event_id
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

revoke all on function public.get_visible_feed_posts_with_stats() from public;
grant execute on function public.get_visible_feed_posts_with_stats()
  to authenticated;

notify pgrst, 'reload schema';
