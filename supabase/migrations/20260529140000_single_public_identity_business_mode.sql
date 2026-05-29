with ranked_businesses as (
  select
    business.id,
    business.owner_user_id,
    row_number() over (
      partition by business.owner_user_id
      order by
        case business.status when 'active' then 0 when 'pending' then 1 else 2 end,
        business.created_at desc,
        business.id desc
    ) as rn
  from public.business_accounts business
  where business.status in ('active', 'pending')
)
update public.business_accounts business
set status = 'suspended',
    updated_at = now()
from ranked_businesses ranked
where business.id = ranked.id
  and ranked.rn > 1;

drop index if exists public.business_accounts_owner_one_account_idx;
create unique index business_accounts_owner_one_account_idx
  on public.business_accounts (owner_user_id)
  where status in ('pending', 'active');

with canonical_business as (
  select distinct on (business.owner_user_id)
    business.owner_user_id,
    business.id
  from public.business_accounts business
  where business.status in ('active', 'pending')
  order by
    business.owner_user_id,
    case business.status when 'active' then 0 when 'pending' then 1 else 2 end,
    business.created_at desc,
    business.id desc
)
update public.profiles profile
set business_account_id = canonical_business.id,
    updated_at = now()
from canonical_business
where profile.user_id = canonical_business.owner_user_id
  and profile.account_type = 'business';

delete from public.follows
where follower_id = following_id;

delete from public.follow_requests
where requester_id = target_user_id;

alter table public.follows
  drop constraint if exists follows_no_self_follow;

alter table public.follows
  add constraint follows_no_self_follow
  check (follower_id <> following_id) not valid;

alter table public.follow_requests
  drop constraint if exists follow_requests_no_self_request;

alter table public.follow_requests
  add constraint follow_requests_no_self_request
  check (requester_id <> target_user_id) not valid;

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
  v_actor_name text;
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
    select request_rows.id
    into v_request_id
    from public.follow_requests request_rows
    where request_rows.requester_id = v_requester_id
      and request_rows.target_user_id = p_target_user_id
      and request_rows.status = 'pending';

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
  );

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

  return query
  select
    'following'::text,
    (select count(*) from public.follows rows where rows.following_id = p_target_user_id),
    (select count(*) from public.follows rows where rows.follower_id = p_target_user_id),
    null::uuid;
end;
$$;

revoke all on function public.follow_or_request_user(uuid) from public;
grant execute on function public.follow_or_request_user(uuid) to authenticated;

notify pgrst, 'reload schema';
