alter table public.event_participants
  add column if not exists checked_in_at timestamptz;

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

create or replace function public.trust_score_delta_for_event(p_event_type text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_event_type
    when 'profile_event_ready' then 2
    when 'first_event_approved' then 3
    when 'event_join_approved' then 1
    when 'host_event_with_participant' then 2
    when 'event_linked_post' then 1
    when 'business_event_checked_in' then 1
    when 'approved_event_left' then -2
    when 'business_event_no_show' then -5
    when 'event_join_cancelled' then 0
    when 'event_join_rejected' then 0
    else 0
  end;
$$;

create or replace function public.mark_business_event_attendance(
  p_event_id uuid,
  p_participant_user_id uuid,
  p_attendance_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_event_type text;
begin
  if v_actor_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_attendance_status not in ('checked_in', 'no_show') then
    raise exception 'invalid_attendance_status';
  end if;

  if p_participant_user_id = v_actor_id then
    raise exception 'cannot_mark_own_attendance';
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
    from public.business_accounts business
    where business.id = v_event.organizer_business_id
      and business.owner_user_id = v_actor_id
      and business.status = 'active'
  ) then
    raise exception 'business_event_not_owned';
  end if;

  select *
  into v_participant
  from public.event_participants participant
  where participant.event_id = p_event_id
    and participant.user_id = p_participant_user_id
    and participant.role = 'participant'
  for update;

  if v_participant.user_id is null then
    raise exception 'participant_not_found';
  end if;

  if v_participant.attendance_status = p_attendance_status then
    return;
  end if;

  if v_participant.attendance_status <> 'confirmed' then
    raise exception 'participant_not_confirmed';
  end if;

  update public.event_participants
  set attendance_status = p_attendance_status,
      checked_in_at = case
        when p_attendance_status = 'checked_in' then now()
        else checked_in_at
      end
  where event_id = p_event_id
    and user_id = p_participant_user_id
    and role = 'participant';

  update public.events
  set approved_count = (
    select count(*)::integer
    from public.event_participants participant
    where participant.event_id = p_event_id
      and participant.role = 'participant'
      and participant.attendance_status in ('confirmed', 'checked_in')
  )
  where id = p_event_id;

  v_event_type := case
    when p_attendance_status = 'checked_in' then 'business_event_checked_in'
    else 'business_event_no_show'
  end;

  perform public.apply_trust_score_event(
    p_participant_user_id,
    v_actor_id,
    v_event_type,
    'event',
    p_event_id,
    jsonb_build_object('attendance_status', p_attendance_status)
  );
end;
$$;

create or replace function public.get_business_event_check_in_participants(
  p_event_id uuid
)
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  avatar_url text,
  attendance_status text,
  checked_in_at timestamptz
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
    profile.avatar_url::text,
    participant.attendance_status::text,
    participant.checked_in_at
  from public.events event
  join public.business_accounts business
    on business.id = event.organizer_business_id
    and business.owner_user_id = auth.uid()
    and business.status = 'active'
  join public.event_participants participant
    on participant.event_id = event.id
    and participant.role = 'participant'
    and participant.attendance_status in ('confirmed', 'checked_in', 'no_show')
  join public.profiles profile
    on profile.user_id = participant.user_id
  where event.id = p_event_id
    and auth.uid() is not null
    and coalesce(event.organizer_type, 'user') = 'business'
  order by
    participant.attendance_status = 'confirmed' desc,
    profile.first_name,
    profile.username;
$$;

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
            and participant.attendance_status in ('confirmed', 'checked_in')
          )
          or (
            coalesce(event.organizer_type, 'user') <> 'business'
            and participant.attendance_status in ('planned', 'attended')
          )
        )
      )
    );
$$;

revoke all on function public.mark_business_event_attendance(uuid, uuid, text)
  from public;
revoke all on function public.get_business_event_check_in_participants(uuid)
  from public;
revoke all on function public.get_event_public_participants(text) from public;
revoke all on function public.trust_score_delta_for_event(text) from public;

grant execute on function public.mark_business_event_attendance(uuid, uuid, text)
  to authenticated;
grant execute on function public.get_business_event_check_in_participants(uuid)
  to authenticated;
grant execute on function public.get_event_public_participants(text)
  to authenticated;

notify pgrst, 'reload schema';
