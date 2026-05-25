create table if not exists public.follow_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint follow_requests_not_self check (requester_id <> target_user_id),
  constraint follow_requests_status_check check (
    status in ('pending', 'approved', 'rejected', 'cancelled')
  )
);

create unique index if not exists follow_requests_one_pending_idx
  on public.follow_requests (requester_id, target_user_id)
  where status = 'pending';

alter table public.follow_requests enable row level security;

drop policy if exists "Follow request participants can read" on public.follow_requests;
create policy "Follow request participants can read"
  on public.follow_requests
  for select
  to authenticated
  using (requester_id = auth.uid() or target_user_id = auth.uid());

drop policy if exists "Requesters can create follow requests" on public.follow_requests;
create policy "Requesters can create follow requests"
  on public.follow_requests
  for insert
  to authenticated
  with check (requester_id = auth.uid() and requester_id <> target_user_id);

drop policy if exists "Requesters can cancel follow requests" on public.follow_requests;
create policy "Requesters can cancel follow requests"
  on public.follow_requests
  for update
  to authenticated
  using (requester_id = auth.uid() and status = 'pending')
  with check (requester_id = auth.uid() and status = 'cancelled');

drop function if exists public.follow_or_request_user(uuid);
drop function if exists public.approve_follow_request(uuid);
drop function if exists public.reject_follow_request(uuid);
drop function if exists public.cancel_follow_request(uuid);
drop function if exists public.get_public_profile_detail(uuid);
drop function if exists public.get_public_profile_followers(text, integer, integer);
drop function if exists public.get_public_profile_following(text, integer, integer);

create function public.follow_or_request_user(p_target_user_id uuid)
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

  select coalesce(profile.is_private, false)
  into v_target_is_private
  from public.profiles profile
  where profile.user_id = p_target_user_id;

  if v_target_is_private is null then
    raise exception 'profile_not_found';
  end if;

  select coalesce(
    nullif(concat_ws(' ', nullif(trim(profile.first_name), ''), nullif(trim(profile.last_name), '')), ''),
    nullif(trim(profile.username), ''),
    'Bir kullanıcı'
  )
  into v_actor_name
  from public.profiles profile
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
    on conflict (requester_id, target_user_id)
      where status = 'pending'
    do update set updated_at = excluded.updated_at
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

create function public.approve_follow_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_id uuid := auth.uid();
  v_requester_id uuid;
  v_actor_name text;
begin
  if v_target_id is null then
    raise exception 'not_authenticated';
  end if;

  select request_rows.requester_id
  into v_requester_id
  from public.follow_requests request_rows
  where request_rows.id = p_request_id
    and request_rows.target_user_id = v_target_id
    and request_rows.status = 'pending'
  for update;

  if v_requester_id is null then
    raise exception 'follow_request_not_found';
  end if;

  insert into public.follows (follower_id, following_id)
  select v_requester_id, v_target_id
  where not exists (
    select 1
    from public.follows follow_rows
    where follow_rows.follower_id = v_requester_id
      and follow_rows.following_id = v_target_id
  );

  update public.follow_requests
  set status = 'approved',
      updated_at = now(),
      responded_at = now()
  where id = p_request_id;

  update public.notifications
  set type = 'follow_request_approved',
      title = 'Takip isteği onaylandı',
      body = 'Takip isteği onaylandı.',
      is_read = true
  where recipient_id = v_target_id
    and entity_type = 'follow_request'
    and entity_id = p_request_id;

  select coalesce(
    nullif(concat_ws(' ', nullif(trim(profile.first_name), ''), nullif(trim(profile.last_name), '')), ''),
    nullif(trim(profile.username), ''),
    'Bir kullanıcı'
  )
  into v_actor_name
  from public.profiles profile
  where profile.user_id = v_target_id;

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
    v_requester_id,
    v_target_id,
    'follow_request_approved',
    'Takip isteğin onaylandı',
    'Takip isteğin onaylandı.',
    'profile',
    v_target_id
  );
end;
$$;

create function public.reject_follow_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_id uuid := auth.uid();
  v_requester_id uuid;
begin
  if v_target_id is null then
    raise exception 'not_authenticated';
  end if;

  select request_rows.requester_id
  into v_requester_id
  from public.follow_requests request_rows
  where request_rows.id = p_request_id
    and request_rows.target_user_id = v_target_id
    and request_rows.status = 'pending'
  for update;

  if v_requester_id is null then
    raise exception 'follow_request_not_found';
  end if;

  update public.follow_requests
  set status = 'rejected',
      updated_at = now(),
      responded_at = now()
  where id = p_request_id;

  update public.notifications
  set type = 'follow_request_rejected',
      title = 'Takip isteği reddedildi',
      body = 'Takip isteği reddedildi.',
      is_read = true
  where recipient_id = v_target_id
    and entity_type = 'follow_request'
    and entity_id = p_request_id;

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
    v_requester_id,
    v_target_id,
    'follow_request_rejected',
    'Takip isteğin reddedildi',
    'Takip isteğin reddedildi.',
    'profile',
    v_target_id
  );
end;
$$;

create function public.cancel_follow_request(p_target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  update public.follow_requests
  set status = 'cancelled',
      updated_at = now()
  where requester_id = auth.uid()
    and target_user_id = p_target_user_id
    and status = 'pending';
end;
$$;

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
  where profile.user_id = p_user_id
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
    nullif(concat_ws(' ', nullif(trim(follower_profile.first_name), ''), nullif(trim(follower_profile.last_name), '')), '') as full_name,
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
    nullif(concat_ws(' ', nullif(trim(following_profile.first_name), ''), nullif(trim(following_profile.last_name), '')), '') as full_name,
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

revoke all on function public.follow_or_request_user(uuid) from public;
revoke all on function public.approve_follow_request(uuid) from public;
revoke all on function public.reject_follow_request(uuid) from public;
revoke all on function public.cancel_follow_request(uuid) from public;
revoke all on function public.get_public_profile_detail(uuid) from public;
revoke all on function public.get_public_profile_followers(text, integer, integer) from public;
revoke all on function public.get_public_profile_following(text, integer, integer) from public;

grant execute on function public.follow_or_request_user(uuid)
  to authenticated, service_role;
grant execute on function public.approve_follow_request(uuid)
  to authenticated, service_role;
grant execute on function public.reject_follow_request(uuid)
  to authenticated, service_role;
grant execute on function public.cancel_follow_request(uuid)
  to authenticated, service_role;
grant execute on function public.get_public_profile_detail(uuid)
  to authenticated, service_role;
grant execute on function public.get_public_profile_followers(text, integer, integer)
  to authenticated, service_role;
grant execute on function public.get_public_profile_following(text, integer, integer)
  to authenticated, service_role;
