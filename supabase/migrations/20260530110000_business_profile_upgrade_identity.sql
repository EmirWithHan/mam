alter table public.profiles
  add column if not exists personal_full_name text,
  add column if not exists personal_username text,
  add column if not exists personal_bio text,
  add column if not exists personal_avatar_url text;

create or replace function public.switch_profile_account_type(p_account_type text)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_business public.business_accounts%rowtype;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_account_type not in ('user', 'business') then
    raise exception 'invalid_account_type';
  end if;

  if p_account_type = 'business' then
    select *
    into v_business
    from public.business_accounts business
    where business.owner_user_id = v_user_id
      and business.status in ('active', 'pending')
    order by
      case business.status when 'active' then 0 when 'pending' then 1 else 2 end,
      business.created_at desc,
      business.id desc
    limit 1;

    if v_business.id is null then
      raise exception 'business_account_missing';
    end if;

    update public.profiles profile
    set personal_full_name = coalesce(profile.personal_full_name, profile.first_name),
        personal_username = coalesce(profile.personal_username, profile.username),
        personal_bio = coalesce(profile.personal_bio, profile.bio),
        personal_avatar_url = coalesce(profile.personal_avatar_url, profile.avatar_url),
        account_type = 'business',
        business_account_id = v_business.id,
        first_name = v_business.name,
        username = v_business.username,
        bio = coalesce(nullif(v_business.description, ''), profile.bio),
        city = coalesce(nullif(v_business.city, ''), profile.city),
        district = coalesce(nullif(v_business.district, ''), profile.district),
        is_profile_completed = true,
        updated_at = now()
    where profile.user_id = v_user_id;
  else
    update public.profiles profile
    set account_type = 'user',
        first_name = coalesce(profile.personal_full_name, profile.first_name),
        username = coalesce(profile.personal_username, profile.username),
        bio = coalesce(profile.personal_bio, profile.bio),
        avatar_url = coalesce(profile.personal_avatar_url, profile.avatar_url),
        updated_at = now()
    where profile.user_id = v_user_id;

    update public.events event
    set status = 'cancelled',
        updated_at = now()
    where event.host_id = v_user_id
      and coalesce(event.organizer_type, 'user') = 'business'
      and event.status = 'active'
      and event.event_date >= now();
  end if;

  return query
  select *
  from public.profiles
  where user_id = v_user_id;
end;
$$;

comment on function public.switch_profile_account_type(text)
  is 'Business mode is a profile upgrade. Public identity stays in profiles; switching to business writes business display fields onto the same profile and switching back restores saved personal fields when present.';

create or replace function public.set_profile_business_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('active', 'pending') then
    update public.profiles profile
    set personal_full_name = coalesce(profile.personal_full_name, profile.first_name),
        personal_username = coalesce(profile.personal_username, profile.username),
        personal_bio = coalesce(profile.personal_bio, profile.bio),
        personal_avatar_url = coalesce(profile.personal_avatar_url, profile.avatar_url),
        account_type = 'business',
        business_account_id = new.id,
        first_name = new.name,
        username = new.username,
        bio = coalesce(nullif(new.description, ''), profile.bio),
        city = coalesce(nullif(new.city, ''), profile.city),
        district = coalesce(nullif(new.district, ''), profile.district),
        is_profile_completed = true,
        updated_at = now()
    where profile.user_id = new.owner_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists business_accounts_set_profile_identity
  on public.business_accounts;
create trigger business_accounts_set_profile_identity
after insert or update of status
on public.business_accounts
for each row execute function public.set_profile_business_identity();

drop function if exists public.get_public_profile_detail(uuid);
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
  account_type text,
  business_account_id uuid,
  business_name text,
  business_username text,
  business_tag text,
  business_category text,
  business_custom_category text,
  business_city text,
  business_district text,
  business_description text,
  business_logo_url text,
  business_cover_url text,
  business_is_verified boolean,
  followers_count bigint,
  following_count bigint,
  is_following boolean,
  is_followed_by boolean,
  pending_follow_request_by_me boolean,
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
    coalesce(profile.is_private, false),
    profile.account_type::text,
    business.id,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    business.category::text,
    business.custom_category::text,
    business.city::text,
    business.district::text,
    business.description::text,
    business.logo_url::text,
    business.cover_url::text,
    coalesce(business.is_verified, false),
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
    exists (
      select 1
      from public.follow_requests request_rows
      where request_rows.requester_id = auth.uid()
        and request_rows.target_user_id = profile.user_id
        and request_rows.status = 'pending'
    ) as pending_follow_request_by_me,
    (
      auth.uid() = profile.user_id
      or coalesce(profile.is_private, false) = false
      or exists (
        select 1
        from public.follows viewer_follow_rows
        where viewer_follow_rows.follower_id = auth.uid()
          and viewer_follow_rows.following_id = profile.user_id
      )
    ) as can_view_extended_profile
  from public.profiles profile
  left join public.business_accounts business
    on profile.account_type = 'business'
    and business.id = profile.business_account_id
    and business.status in ('active', 'pending')
  where profile.user_id = p_user_id
    and auth.uid() is not null;
$$;

drop function if exists public.get_public_profile_preview(text);
create function public.get_public_profile_preview(p_user_id text)
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean,
  account_type text,
  business_name text,
  business_username text,
  business_tag text,
  business_logo_url text,
  business_is_verified boolean
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
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    null::text as business_logo_url,
    coalesce(business.is_verified, false)
  from public.profiles profile
  left join public.business_accounts business
    on profile.account_type = 'business'
    and business.id = profile.business_account_id
    and business.status in ('active', 'pending')
  where profile.user_id::text = p_user_id
    and auth.uid() is not null;
$$;

drop function if exists public.get_public_profile_previews(text[]);
create function public.get_public_profile_previews(p_user_ids text[])
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean,
  account_type text,
  business_name text,
  business_username text,
  business_tag text,
  business_logo_url text,
  business_is_verified boolean
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
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    null::text as business_logo_url,
    coalesce(business.is_verified, false)
  from public.profiles profile
  left join public.business_accounts business
    on profile.account_type = 'business'
    and business.id = profile.business_account_id
    and business.status in ('active', 'pending')
  where profile.user_id::text = any(p_user_ids)
    and auth.uid() is not null;
$$;

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

revoke all on function public.switch_profile_account_type(text) from public;
revoke all on function public.get_public_profile_detail(uuid) from public;
revoke all on function public.get_public_profile_preview(text) from public;
revoke all on function public.get_public_profile_previews(text[]) from public;
revoke all on function public.get_visible_feed_posts_with_stats() from public;

grant execute on function public.switch_profile_account_type(text) to authenticated;
grant execute on function public.get_public_profile_detail(uuid) to authenticated;
grant execute on function public.get_public_profile_preview(text) to authenticated;
grant execute on function public.get_public_profile_previews(text[]) to authenticated;
grant execute on function public.get_visible_feed_posts_with_stats() to authenticated;

notify pgrst, 'reload schema';
