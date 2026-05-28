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
      and rel.relname = 'event_join_requests'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%status%'
  loop
    execute format(
      'alter table public.event_join_requests drop constraint if exists %I',
      constraint_row.conname
    );
  end loop;
end $$;

alter table public.event_join_requests
  add constraint event_join_requests_status_check
  check (
    status in (
      'pending',
      'approved',
      'rejected',
      'cancelled',
      'left',
      'pending_confirmation',
      'confirmed',
      'waitlisted'
    )
  ) not valid;

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
      and rel.relname = 'event_participants'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%attendance_status%'
  loop
    execute format(
      'alter table public.event_participants drop constraint if exists %I',
      constraint_row.conname
    );
  end loop;
end $$;

alter table public.event_participants
  add constraint event_participants_attendance_status_check
  check (
    attendance_status in (
      'pending',
      'approved',
      'rejected',
      'cancelled',
      'left',
      'planned',
      'attended',
      'pending_confirmation',
      'confirmed',
      'waitlisted'
    )
  ) not valid;

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
      and pg_get_constraintdef(con.oid) ilike '%type%'
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
      'business_event_confirm_required',
      'event_join_rejected',
      'event_join_cancelled',
      'event_left',
      'follow',
      'follow_request',
      'follow_request_approved',
      'follow_request_rejected',
      'system'
    )
  ) not valid;

create or replace function public.approve_event_join_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_request public.event_join_requests%rowtype;
  v_event public.events%rowtype;
  v_business_status text;
  v_confirmed_count integer;
  v_next_status text;
begin
  if v_actor_id is null then
    raise exception 'not_authenticated';
  end if;

  select *
  into v_request
  from public.event_join_requests
  where id = $1
  for update;

  if v_request.id is null then
    raise exception 'join_request_not_found';
  end if;

  select *
  into v_event
  from public.events
  where id = v_request.event_id
  for update;

  if v_event.id is null then
    raise exception 'event_not_found';
  end if;

  if v_event.host_id <> v_actor_id then
    raise exception 'not_event_host';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'join_request_not_pending';
  end if;

  if coalesce(v_event.organizer_type, 'user') = 'business' then
    select business.status
    into v_business_status
    from public.business_accounts business
    where business.id = v_event.organizer_business_id
      and business.owner_user_id = v_actor_id;

    if v_business_status <> 'active' then
      raise exception 'business_event_not_owned';
    end if;

    select count(*)::integer
    into v_confirmed_count
    from public.event_participants participant
    where participant.event_id = v_event.id
      and participant.role = 'participant'
      and participant.attendance_status = 'confirmed';

    if v_event.capacity_total > 0 and v_confirmed_count >= v_event.capacity_total then
      v_next_status := 'waitlisted';
    else
      v_next_status := 'pending_confirmation';
    end if;

    update public.event_join_requests
    set status = v_next_status,
        updated_at = now()
    where id = v_request.id;

    update public.event_participants
    set role = 'participant',
        attendance_status = v_next_status
    where event_id = v_event.id
      and user_id = v_request.user_id;

    if not found then
      insert into public.event_participants (
        event_id,
        user_id,
        role,
        attendance_status
      )
      values (
        v_event.id,
        v_request.user_id,
        'participant',
        v_next_status
      );
    end if;

    if v_next_status = 'pending_confirmation' then
      insert into public.notifications (
        recipient_id,
        actor_id,
        type,
        title,
        body,
        entity_type,
        entity_id,
        metadata,
        is_read
      )
      values (
        v_request.user_id,
        v_actor_id,
        'business_event_confirm_required',
        'Katılımını doğrula',
        'İşletme etkinliğine katılımın onaylandı. Yerini ayırmak için katılımını doğrula.',
        'event',
        v_event.id::text,
        jsonb_build_object(
          'request_id', v_request.id,
          'request_status', v_next_status
        ),
        false
      );
    end if;

    return;
  end if;

  if v_event.capacity_total > 0 and coalesce(v_event.approved_count, 0) >= v_event.capacity_total then
    raise exception 'event_full';
  end if;

  update public.event_join_requests
  set status = 'approved',
      updated_at = now()
  where id = v_request.id;

  update public.event_participants
  set role = 'participant',
      attendance_status = 'planned'
  where event_id = v_event.id
    and user_id = v_request.user_id;

  if not found then
    insert into public.event_participants (
      event_id,
      user_id,
      role,
      attendance_status
    )
    values (
      v_event.id,
      v_request.user_id,
      'participant',
      'planned'
    );
  end if;

  update public.events
  set approved_count = (
    select count(*)::integer
    from public.event_participants participant
    where participant.event_id = v_event.id
      and participant.role = 'participant'
      and participant.attendance_status in ('planned', 'attended')
  )
  where id = v_event.id;

  insert into public.notifications (
    recipient_id,
    actor_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    metadata,
    is_read
  )
  values (
    v_request.user_id,
    v_actor_id,
    'event_join_approved',
    'Katılım isteğin onaylandı',
    'Katılım isteğin ev sahibi tarafından onaylandı.',
    'event',
    v_event.id::text,
    jsonb_build_object(
      'request_id', v_request.id,
      'request_status', 'approved'
    ),
    false
  );
end;
$$;

create or replace function public.confirm_business_event_participation(
  p_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_confirmed_count integer;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select *
  into v_event
  from public.events
  where id = p_event_id
  for update;

  if v_event.id is null then
    raise exception 'event_not_found';
  end if;

  if coalesce(v_event.organizer_type, 'user') <> 'business' then
    raise exception 'not_business_event';
  end if;

  if not exists (
    select 1
    from public.event_participants participant
    where participant.event_id = p_event_id
      and participant.user_id = v_user_id
      and participant.role = 'participant'
      and participant.attendance_status = 'pending_confirmation'
    for update
  ) then
    raise exception 'participation_not_pending_confirmation';
  end if;

  select count(*)::integer
  into v_confirmed_count
  from public.event_participants participant
  where participant.event_id = p_event_id
    and participant.role = 'participant'
    and participant.attendance_status = 'confirmed';

  if v_event.capacity_total > 0 and v_confirmed_count >= v_event.capacity_total then
    update public.event_participants
    set attendance_status = 'waitlisted'
    where event_id = p_event_id
      and user_id = v_user_id
      and role = 'participant';

    update public.event_join_requests
    set status = 'waitlisted',
        updated_at = now()
    where event_id = p_event_id
      and user_id = v_user_id;

    return;
  end if;

  update public.event_participants
  set attendance_status = 'confirmed'
  where event_id = p_event_id
    and user_id = v_user_id
    and role = 'participant';

  update public.event_join_requests
  set status = 'confirmed',
      updated_at = now()
  where event_id = p_event_id
    and user_id = v_user_id;

  update public.events
  set approved_count = (
    select count(*)::integer
    from public.event_participants participant
    where participant.event_id = p_event_id
      and participant.role = 'participant'
      and participant.attendance_status = 'confirmed'
  )
  where id = p_event_id;
end;
$$;

drop function if exists public.confirm_business_event_participation(text);

revoke all on function public.approve_event_join_request(uuid) from public;
revoke all on function public.confirm_business_event_participation(uuid)
  from public;

grant execute on function public.approve_event_join_request(uuid)
  to authenticated;
grant execute on function public.confirm_business_event_participation(uuid)
  to authenticated;

create or replace function public.get_event_public_participants(p_event_id text)
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
  join public.events event
    on event.id = participant.event_id
  join public.profiles profile
    on profile.user_id = participant.user_id
  where participant.event_id::text = p_event_id
    and auth.uid() is not null
    and (
      participant.role = 'host'
      or (
        participant.role = 'participant'
        and (
          (
            coalesce(event.organizer_type, 'user') = 'business'
            and participant.attendance_status = 'confirmed'
          )
          or (
            coalesce(event.organizer_type, 'user') <> 'business'
            and participant.attendance_status in ('planned', 'attended')
          )
        )
      )
    );
$$;

revoke all on function public.get_event_public_participants(text) from public;
grant execute on function public.get_event_public_participants(text)
  to authenticated;
