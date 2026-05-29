create or replace function public.switch_profile_account_type(p_account_type text)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_business_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_account_type not in ('user', 'business') then
    raise exception 'invalid_account_type';
  end if;

  if p_account_type = 'business' then
    select business.id
    into v_business_id
    from public.business_accounts business
    where business.owner_user_id = v_user_id
      and business.status in ('active', 'pending')
    order by business.created_at desc
    limit 1;

    if v_business_id is null then
      raise exception 'business_account_missing';
    end if;

    update public.profiles
    set account_type = 'business',
        business_account_id = v_business_id,
        updated_at = now()
    where user_id = v_user_id;
  else
    update public.profiles
    set account_type = 'user',
        updated_at = now()
    where user_id = v_user_id;
  end if;

  return query
  select *
  from public.profiles
  where user_id = v_user_id;
end;
$$;

create or replace function public.normalized_business_rule_text(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(
    translate(
      coalesce(p_value, ''),
      'ÇĞİÖŞÜçğıöşü',
      'CGIOSUcgiosu'
    )
  );
$$;

create or replace function public.business_category_allows_activity(
  p_category text,
  p_custom_category text,
  p_activity text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_is_other boolean := btrim(coalesce(p_category, '')) in ('Diğer', 'DiÄŸer');
  v_category text := public.normalized_business_rule_text(
    case
      when btrim(coalesce(p_category, '')) in ('Diğer', 'DiÄŸer')
      then p_custom_category
      else p_category
    end
  );
  v_activity text := public.normalized_business_rule_text(p_activity);
  v_custom_ok boolean := false;
begin
  if v_is_other then
    return length(btrim(coalesce(p_activity, ''))) between 2 and 40;
  end if;

  if v_category like '%at ciftligi%' then
    return v_activity in ('at binme', 'doga gezisi', 'outdoor', 'kamp');
  end if;
  if v_category like '%hali saha%' or v_category like '%futbol sahasi%' then
    return v_activity = 'futbol';
  end if;
  if v_category like '%basketbol%' then return v_activity = 'basketbol'; end if;
  if v_category like '%voleybol%' then return v_activity = 'voleybol'; end if;
  if v_category like '%tenis%' then return v_activity = 'tenis'; end if;
  if v_category like '%padel%' then return v_activity = 'padel'; end if;
  if v_category like '%yoga%' then return v_activity = 'yoga'; end if;
  if v_category like '%pilates%' then return v_activity = 'pilates'; end if;
  if v_category like '%spor salonu%' or v_category like '%fitness%' or
     v_category like '%crossfit%' then
    return v_activity in ('fitness', 'crossfit');
  end if;

  if v_category like '%board game%' or v_category like '%kafe%' or
     v_category like '%etkinlik mekani%' or v_category like '%workshop%' or
     v_category like '%dans%' then
    v_custom_ok := length(btrim(coalesce(p_activity, ''))) between 2 and 40;
    return v_activity in ('board game', 'sosyal bulusma', 'workshop', 'dans')
      or v_custom_ok;
  end if;

  if v_category like '%outdoor%' or v_category like '%doga%' or
     v_category like '%kamp%' or v_category like '%trekking%' or
     v_category like '%yuruyus%' then
    return v_activity in ('trekking', 'kamp', 'outdoor', 'bisiklet');
  end if;

  return length(btrim(coalesce(p_activity, ''))) between 2 and 40;
end;
$$;

drop function if exists public.get_visible_feed_posts_with_stats();

create or replace function public.get_visible_feed_posts_with_stats()
returns table (
  id uuid,
  user_id uuid,
  event_id uuid,
  image_url text,
  caption text,
  comments_hidden boolean,
  is_archived boolean,
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
    case
      when author_profile.account_type = 'business'
      then business.username::text
      else author_profile.username::text
    end as author_username,
    case
      when author_profile.account_type = 'business'
      then business.business_tag::text
      else author_profile.tag::text
    end as author_tag,
    case
      when author_profile.account_type = 'business'
      then business.logo_url::text
      else author_profile.avatar_url::text
    end as author_avatar_url,
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
  left join public.business_accounts business
    on author_profile.account_type = 'business'
    and business.id = author_profile.business_account_id
    and business.status = 'active'
  where auth.uid() is not null
    and coalesce(post.is_archived, false) = false
    and (
      author_profile.account_type = 'business'
      or author_profile.user_id = auth.uid()
      or coalesce(author_profile.is_private, false) = false
      or exists (
        select 1
        from public.follows viewer_follow_rows
        where viewer_follow_rows.follower_id = auth.uid()
          and viewer_follow_rows.following_id = author_profile.user_id
      )
    )
  order by post.created_at desc;
$$;

revoke all on function public.switch_profile_account_type(text) from public;
grant execute on function public.switch_profile_account_type(text) to authenticated;

revoke all on function public.get_visible_feed_posts_with_stats() from public;
grant execute on function public.get_visible_feed_posts_with_stats()
  to authenticated;

notify pgrst, 'reload schema';
