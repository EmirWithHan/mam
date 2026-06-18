alter table public.events
  add column if not exists generic_capacity integer,
  add column if not exists male_capacity integer,
  add column if not exists female_capacity integer;

update public.events
set generic_capacity = coalesce(generic_capacity, capacity_total, 0),
    male_capacity = coalesce(male_capacity, 0),
    female_capacity = coalesce(female_capacity, 0)
where generic_capacity is null
   or male_capacity is null
   or female_capacity is null;

alter table public.events
  alter column generic_capacity set default 0,
  alter column male_capacity set default 0,
  alter column female_capacity set default 0;

alter table public.events
  drop constraint if exists events_capacity_buckets_non_negative;

alter table public.events
  add constraint events_capacity_buckets_non_negative
  check (
    coalesce(generic_capacity, 0) >= 0
    and coalesce(male_capacity, 0) >= 0
    and coalesce(female_capacity, 0) >= 0
  ) not valid;

alter table public.event_participants
  add column if not exists capacity_bucket text;

update public.event_participants
set capacity_bucket = 'generic'
where capacity_bucket is null
  and role = 'participant'
  and attendance_status in ('planned', 'attended', 'confirmed', 'checked_in');

alter table public.event_participants
  drop constraint if exists event_participants_capacity_bucket_check;

alter table public.event_participants
  add constraint event_participants_capacity_bucket_check
  check (
    capacity_bucket is null
    or capacity_bucket in ('generic', 'male', 'female')
  ) not valid;

create or replace function public.event_capacity_bucket_for(
  p_event_id uuid,
  p_user_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events%rowtype;
  v_gender text;
  v_generic_used integer := 0;
  v_male_used integer := 0;
  v_female_used integer := 0;
  v_generic_capacity integer := 0;
  v_male_capacity integer := 0;
  v_female_capacity integer := 0;
begin
  select *
  into v_event
  from public.events
  where id = p_event_id;

  if v_event.id is null then
    raise exception 'event_not_found';
  end if;

  v_generic_capacity := greatest(coalesce(v_event.generic_capacity, v_event.capacity_total, 0), 0);
  v_male_capacity := greatest(coalesce(v_event.male_capacity, 0), 0);
  v_female_capacity := greatest(coalesce(v_event.female_capacity, 0), 0);

  select lower(coalesce(profile.gender, ''))
  into v_gender
  from public.profiles profile
  where profile.user_id = p_user_id;

  select
    count(*) filter (where coalesce(participant.capacity_bucket, 'generic') = 'generic')::integer,
    count(*) filter (where participant.capacity_bucket = 'male')::integer,
    count(*) filter (where participant.capacity_bucket = 'female')::integer
  into v_generic_used, v_male_used, v_female_used
  from public.event_participants participant
  where participant.event_id = p_event_id
    and participant.role = 'participant'
    and participant.attendance_status in ('planned', 'attended', 'confirmed', 'checked_in');

  if v_gender in ('erkek', 'male') and v_male_used < v_male_capacity then
    return 'male';
  end if;

  if v_gender in ('kadın', 'kadin', 'female') and v_female_used < v_female_capacity then
    return 'female';
  end if;

  if v_generic_used < v_generic_capacity then
    return 'generic';
  end if;

  return null;
end;
$$;

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
  v_capacity_bucket text;
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

    if coalesce(v_event.capacity_total, 0) > 0
       and v_confirmed_count >= coalesce(v_event.capacity_total, 0) then
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
        attendance_status = v_next_status,
        capacity_bucket = null
    where event_id = v_event.id
      and user_id = v_request.user_id;

    if not found then
      insert into public.event_participants (
        event_id,
        user_id,
        role,
        attendance_status,
        capacity_bucket
      )
      values (
        v_event.id,
        v_request.user_id,
        'participant',
        v_next_status,
        null
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
        v_event.id,
        jsonb_build_object(
          'request_id', v_request.id,
          'request_status', v_next_status,
          'event_id', v_event.id::text
        ),
        false
      );
    end if;

    return;
  end if;

  if v_event.host_id <> v_actor_id then
    raise exception 'not_event_host';
  end if;

  v_capacity_bucket := public.event_capacity_bucket_for(v_event.id, v_request.user_id);
  if v_capacity_bucket is null then
    raise exception 'no_eligible_capacity';
  end if;

  update public.event_join_requests
  set status = 'approved',
      updated_at = now()
  where id = v_request.id;

  update public.event_participants
  set role = 'participant',
      attendance_status = 'planned',
      capacity_bucket = v_capacity_bucket
  where event_id = v_event.id
    and user_id = v_request.user_id;

  if not found then
    insert into public.event_participants (
      event_id,
      user_id,
      role,
      attendance_status,
      capacity_bucket
    )
    values (
      v_event.id,
      v_request.user_id,
      'participant',
      'planned',
      v_capacity_bucket
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
    v_event.id,
    jsonb_build_object(
      'request_id', v_request.id,
      'request_status', 'approved',
      'event_id', v_event.id::text
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
  v_capacity_bucket text;
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

  v_capacity_bucket := public.event_capacity_bucket_for(p_event_id, v_user_id);

  if v_capacity_bucket is null then
    update public.event_participants
    set attendance_status = 'waitlisted',
        capacity_bucket = null
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
  set attendance_status = 'confirmed',
      capacity_bucket = v_capacity_bucket
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

revoke all on function public.event_capacity_bucket_for(uuid, uuid) from public;
revoke all on function public.approve_event_join_request(uuid) from public;
revoke all on function public.confirm_business_event_participation(uuid)
  from public;

grant execute on function public.approve_event_join_request(uuid)
  to authenticated;
grant execute on function public.confirm_business_event_participation(uuid)
  to authenticated;

notify pgrst, 'reload schema';
