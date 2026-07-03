create or replace function public.follow_or_request_user(p_target_user_id uuid)
returns table (
  status text,
  follower_count bigint,
  following_count bigint,
  pending_request_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester_id uuid := auth.uid();
  v_target_is_private boolean;
  v_request_id uuid;
  v_request_status text;
  v_actor_name text;
  v_follow_created boolean;
begin
  if v_requester_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_target_user_id is null or p_target_user_id = v_requester_id then
    raise exception 'invalid_follow_target';
  end if;

  if exists (
    select 1
    from public.business_accounts business
    where business.id = p_target_user_id
  ) then
    raise exception 'invalid_follow_target';
  end if;

  select coalesce(profile.is_private, false)
  into v_target_is_private
  from public.profiles profile
  where profile.user_id = p_target_user_id;

  if v_target_is_private is null then
    raise exception 'profile_not_found';
  end if;

  select coalesce(
    nullif(trim(business.name), ''),
    nullif(concat_ws(' ', nullif(trim(profile.first_name), ''), nullif(trim(profile.last_name), '')), ''),
    nullif(trim(profile.username), ''),
    'Bir kullanıcı'
  )
  into v_actor_name
  from public.profiles profile
  left join public.business_accounts business
    on profile.account_type = 'business'
    and business.id = profile.business_account_id
    and business.status = 'active'
  where profile.user_id = v_requester_id;

  if exists (
    select 1
    from public.follows follow_rows
    where follow_rows.follower_id = v_requester_id
      and follow_rows.following_id = p_target_user_id
  ) then
    return query
    select
      'following'::text,
      (select count(*) from public.follows rows where rows.following_id = p_target_user_id),
      (select count(*) from public.follows rows where rows.follower_id = p_target_user_id),
      null::uuid;
    return;
  end if;

  if v_target_is_private then
    select request_rows.id, request_rows.status
    into v_request_id, v_request_status
    from public.follow_requests request_rows
    where request_rows.requester_id = v_requester_id
      and request_rows.target_user_id = p_target_user_id
    order by
      case when request_rows.status = 'pending' then 0 else 1 end,
      request_rows.updated_at desc nulls last,
      request_rows.created_at desc
    limit 1;

    if v_request_id is null then
      insert into public.follow_requests (
        requester_id,
        target_user_id,
        status,
        updated_at
      )
      values (
        v_requester_id,
        p_target_user_id,
        'pending',
        now()
      )
      returning id into v_request_id;

      v_request_status := 'created';
    elsif v_request_status <> 'pending' then
      update public.follow_requests
      set status = 'pending',
          responded_at = null,
          updated_at = now()
      where id = v_request_id;
    end if;

    if v_request_status <> 'pending' then
      update public.notifications
      set type = 'follow_request',
          title = 'Takip isteği',
          body = v_actor_name || ' seni takip etmek istiyor.',
          is_read = false,
          created_at = now(),
          metadata = jsonb_build_object('request_status', 'pending')
      where recipient_id = p_target_user_id
        and actor_id = v_requester_id
        and entity_type = 'follow_request'
        and entity_id = v_request_id;

      if not found then
        insert into public.notifications (
          recipient_id,
          actor_id,
          type,
          title,
          body,
          entity_type,
          entity_id,
          metadata
        )
        values (
          p_target_user_id,
          v_requester_id,
          'follow_request',
          'Takip isteği',
          v_actor_name || ' seni takip etmek istiyor.',
          'follow_request',
          v_request_id,
          jsonb_build_object('request_status', 'pending')
        );
      end if;
    end if;

    return query
    select
      'requested'::text,
      (select count(*) from public.follows rows where rows.following_id = p_target_user_id),
      (select count(*) from public.follows rows where rows.follower_id = p_target_user_id),
      v_request_id;
    return;
  end if;

  insert into public.follows (follower_id, following_id)
  select v_requester_id, p_target_user_id
  where not exists (
    select 1
    from public.follows follow_rows
    where follow_rows.follower_id = v_requester_id
      and follow_rows.following_id = p_target_user_id
  )
  returning true into v_follow_created;

  if coalesce(v_follow_created, false) then
    insert into public.notifications (
      recipient_id,
      actor_id,
      type,
      title,
      body,
      entity_type,
      entity_id
    )
    values (
      p_target_user_id,
      v_requester_id,
      'follow',
      'Yeni takipçi',
      v_actor_name || ' seni takip etti.',
      'profile',
      v_requester_id
    );
  end if;

  return query
  select
    'following'::text,
    (select count(*) from public.follows rows where rows.following_id = p_target_user_id),
    (select count(*) from public.follows rows where rows.follower_id = p_target_user_id),
    null::uuid;
end;
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
  business_is_verified boolean,
  business_custom_theme_color text,
  business_pinned_event_id uuid,
  business_gallery_urls text[],
  business_is_plus_active boolean,
  is_private boolean,
  can_view_extended_profile boolean
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
    case
      when coalesce(profile.account_type, 'user') = 'business'
        or profile.user_id = auth.uid()
        or coalesce(profile.is_private, false) = false
        or exists (
          select 1
          from public.follows follow_rows
          where follow_rows.follower_id = auth.uid()
            and follow_rows.following_id = profile.user_id
        )
      then profile.avatar_url::text
      else null::text
    end as avatar_url,
    profile.trust_score::integer,
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    null::text as business_logo_url,
    coalesce(business.is_verified, false),
    business.custom_theme_color::text as business_custom_theme_color,
    business.pinned_event_id as business_pinned_event_id,
    business.gallery_urls as business_gallery_urls,
    exists (
      select 1
      from public.business_plus_subscriptions bps
      where bps.business_account_id = business.id
        and bps.status = 'active'
        and bps.starts_at <= now()
        and (bps.ends_at is null or bps.ends_at >= now())
    ) as business_is_plus_active,
    coalesce(profile.is_private, false)::boolean as is_private,
    (
      coalesce(profile.account_type, 'user') = 'business'
      or profile.user_id = auth.uid()
      or coalesce(profile.is_private, false) = false
      or exists (
        select 1
        from public.follows follow_rows
        where follow_rows.follower_id = auth.uid()
          and follow_rows.following_id = profile.user_id
      )
    )::boolean as can_view_extended_profile
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
  business_is_verified boolean,
  business_custom_theme_color text,
  business_pinned_event_id uuid,
  business_gallery_urls text[],
  business_is_plus_active boolean,
  is_private boolean,
  can_view_extended_profile boolean
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
    case
      when coalesce(profile.account_type, 'user') = 'business'
        or profile.user_id = auth.uid()
        or coalesce(profile.is_private, false) = false
        or exists (
          select 1
          from public.follows follow_rows
          where follow_rows.follower_id = auth.uid()
            and follow_rows.following_id = profile.user_id
        )
      then profile.avatar_url::text
      else null::text
    end as avatar_url,
    profile.trust_score::integer,
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    null::text as business_logo_url,
    coalesce(business.is_verified, false),
    business.custom_theme_color::text as business_custom_theme_color,
    business.pinned_event_id as business_pinned_event_id,
    business.gallery_urls as business_gallery_urls,
    exists (
      select 1
      from public.business_plus_subscriptions bps
      where bps.business_account_id = business.id
        and bps.status = 'active'
        and bps.starts_at <= now()
        and (bps.ends_at is null or bps.ends_at >= now())
    ) as business_is_plus_active,
    coalesce(profile.is_private, false)::boolean as is_private,
    (
      coalesce(profile.account_type, 'user') = 'business'
      or profile.user_id = auth.uid()
      or coalesce(profile.is_private, false) = false
      or exists (
        select 1
        from public.follows follow_rows
        where follow_rows.follower_id = auth.uid()
          and follow_rows.following_id = profile.user_id
      )
    )::boolean as can_view_extended_profile
  from public.profiles profile
  left join public.business_accounts business
    on profile.account_type = 'business'
    and business.id = profile.business_account_id
    and business.status in ('active', 'pending')
  where profile.user_id::text = any(p_user_ids)
    and auth.uid() is not null;
$$;

revoke all on function public.follow_or_request_user(uuid) from public;
grant execute on function public.follow_or_request_user(uuid) to authenticated;

revoke all on function public.get_public_profile_preview(text) from public;
grant execute on function public.get_public_profile_preview(text) to authenticated;

revoke all on function public.get_public_profile_previews(text[]) from public;
grant execute on function public.get_public_profile_previews(text[]) to authenticated;
