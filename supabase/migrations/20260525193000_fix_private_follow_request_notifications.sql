do $$
declare
  constraint_row record;
begin
  for constraint_row in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'notifications'
      and con.contype = 'c'
      and (
        pg_get_constraintdef(con.oid) ilike '%type%'
        or pg_get_constraintdef(con.oid) ilike '%entity_type%'
      )
  loop
    execute format(
      'alter table public.notifications drop constraint if exists %I',
      constraint_row.conname
    );
  end loop;
end $$;

alter table public.notifications
  add constraint notifications_type_check
  check (
    type in (
      'event_join_request',
      'event_join_approved',
      'event_join_rejected',
      'event_join_cancelled',
      'event_left',
      'follow',
      'follow_request',
      'follow_request_approved',
      'follow_request_rejected',
      'system'
    )
  );

drop function if exists public.follow_or_request_user(uuid);
drop function if exists public.approve_follow_request(uuid);
drop function if exists public.reject_follow_request(uuid);

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

create function public.approve_follow_request(p_request_id uuid)
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
  set is_read = true,
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('request_status', 'approved')
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
  set is_read = true,
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('request_status', 'rejected')
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

revoke all on function public.follow_or_request_user(uuid) from public;
revoke all on function public.approve_follow_request(uuid) from public;
revoke all on function public.reject_follow_request(uuid) from public;

grant execute on function public.follow_or_request_user(uuid)
  to authenticated, service_role;
grant execute on function public.approve_follow_request(uuid)
  to authenticated, service_role;
grant execute on function public.reject_follow_request(uuid)
  to authenticated, service_role;
