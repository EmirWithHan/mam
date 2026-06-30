-- Participant eligibility requirements for events.
-- Phone verification is intentionally out of scope for this version.

alter table public.events
  add column if not exists min_age integer,
  add column if not exists require_completed_profile boolean not null default true;

alter table public.events
  drop constraint if exists events_min_age_check;

alter table public.events
  add constraint events_min_age_check
  check (min_age is null or (min_age >= 13 and min_age <= 99));

comment on column public.events.min_age is
  'Minimum participant age required to request or reserve participation.';

comment on column public.events.require_completed_profile is
  'When true, participant must have the existing event-required profile fields.';

create or replace function public.assert_event_participant_requirements(
  p_event_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events%rowtype;
  v_profile public.profiles%rowtype;
  v_age integer;
begin
  select *
  into v_event
  from public.events
  where id = p_event_id;

  if v_event.id is null then
    raise exception 'event_not_found';
  end if;

  select *
  into v_profile
  from public.profiles
  where user_id = p_user_id;

  if coalesce(v_event.require_completed_profile, true) then
    if v_profile.user_id is null
      or nullif(trim(coalesce(v_profile.username, '')), '') is null
      or nullif(trim(coalesce(v_profile.city, '')), '') is null
      or nullif(trim(coalesce(v_profile.district, '')), '') is null
      or v_profile.birth_date is null then
      raise exception 'Bu etkinliğe katılmak için profilini tamamlamalısın.';
    end if;
  end if;

  if v_event.min_age is not null then
    if v_profile.birth_date is null then
      raise exception 'Doğum tarihini ekledikten sonra tekrar deneyebilirsin.';
    end if;

    v_age := date_part('year', age(current_date, v_profile.birth_date))::integer;
    if v_age < v_event.min_age then
      raise exception 'Bu etkinlik için % yaş üstü olman gerekiyor.', v_event.min_age;
    end if;
  end if;
end;
$$;

revoke all on function public.assert_event_participant_requirements(uuid, uuid) from public;
grant execute on function public.assert_event_participant_requirements(uuid, uuid) to authenticated;

drop function if exists public.request_event_join(uuid);

create or replace function public.request_event_join(
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

  if coalesce(v_event.organizer_type, 'user') = 'business' then
    raise exception 'business_event_requires_reservation';
  end if;

  if v_event.event_date < now() then
    raise exception 'event_past';
  end if;

  if coalesce(v_event.capacity_total, 0) > 0
    and coalesce(v_event.approved_count, 0) >= coalesce(v_event.capacity_total, 0) then
    raise exception 'event_full';
  end if;

  perform public.assert_event_participant_requirements(p_event_id, v_user_id);

  insert into public.event_join_requests (
    event_id,
    user_id,
    status
  )
  values (
    p_event_id,
    v_user_id,
    'pending'
  )
  on conflict (event_id, user_id) do update
  set status = 'pending',
      updated_at = now()
  where public.event_join_requests.status in ('cancelled', 'rejected');
end;
$$;

revoke all on function public.request_event_join(uuid) from public;
grant execute on function public.request_event_join(uuid) to authenticated;

create or replace function public.reserve_business_event_participation(
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
  v_next_status text;
  v_token text;
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

  if v_event.event_date < now() then
    raise exception 'event_past';
  end if;

  perform public.assert_event_participant_requirements(p_event_id, v_user_id);

  v_capacity_bucket := public.event_capacity_bucket_for(p_event_id, v_user_id);

  if v_capacity_bucket is null then
    v_next_status := 'waitlisted';
  else
    v_next_status := 'confirmed';
  end if;

  v_token := md5(random()::text || clock_timestamp()::text)::text;

  insert into public.event_participants (
    event_id,
    user_id,
    role,
    attendance_status,
    capacity_bucket,
    check_in_token
  )
  values (
    p_event_id,
    v_user_id,
    'participant',
    v_next_status,
    v_capacity_bucket,
    v_token
  )
  on conflict (event_id, user_id) do update
  set role = 'participant',
      attendance_status = v_next_status,
      capacity_bucket = v_capacity_bucket,
      check_in_token = coalesce(public.event_participants.check_in_token, v_token);

  insert into public.event_join_requests (
    event_id,
    user_id,
    status
  )
  values (
    p_event_id,
    v_user_id,
    v_next_status
  )
  on conflict (event_id, user_id) do update
  set status = v_next_status,
      updated_at = now();

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

revoke all on function public.reserve_business_event_participation(uuid) from public;
grant execute on function public.reserve_business_event_participation(uuid) to authenticated;
