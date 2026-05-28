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
      'waitlisted',
      'checked_in',
      'no_show'
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
  v_is_owned_business_event boolean := false;
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

  if v_request.status <> 'pending' then
    raise exception 'join_request_not_pending';
  end if;

  if coalesce(v_event.organizer_type, 'user') = 'business' then
    select exists (
      select 1
      from public.business_accounts business
      where business.id = v_event.organizer_business_id
        and business.owner_user_id = v_actor_id
        and business.status = 'active'
    )
    into v_is_owned_business_event;

    if not v_is_owned_business_event then
      raise exception 'business_event_not_owned';
    end if;

    select count(*)::integer
    into v_confirmed_count
    from public.event_participants participant
    where participant.event_id = v_event.id
      and participant.role = 'participant'
      and participant.attendance_status in ('confirmed', 'checked_in');

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

  if v_event.host_id <> v_actor_id then
    raise exception 'not_event_host';
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

revoke all on function public.approve_event_join_request(uuid) from public;
grant execute on function public.approve_event_join_request(uuid)
  to authenticated;

notify pgrst, 'reload schema';
