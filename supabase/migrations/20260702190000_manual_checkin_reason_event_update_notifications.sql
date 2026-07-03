-- Build 6 hardening: require manual check-in reasons and notify participants on event edits.

alter table public.event_participants
  add column if not exists manual_check_in_reason text,
  add column if not exists manual_checked_in_by uuid references auth.users(id) on delete set null,
  add column if not exists manual_checked_in_at timestamptz;

comment on column public.event_participants.manual_check_in_reason
  is 'Required host/business explanation for manual attendance verification.';
comment on column public.event_participants.manual_checked_in_by
  is 'Authenticated user who manually verified attendance.';
comment on column public.event_participants.manual_checked_in_at
  is 'Server time when attendance was manually verified.';

drop function if exists public.mark_event_attendance(uuid, uuid, text);

create or replace function public.mark_event_attendance(
  p_event_id uuid,
  p_participant_user_id uuid,
  p_attendance_status text,
  p_manual_reason text default null
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
  v_is_authorized boolean := false;
  v_business_id uuid;
  v_target_status text;
  v_manual_reason text := nullif(btrim(coalesce(p_manual_reason, '')), '');
begin
  if v_actor_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_attendance_status not in ('checked_in', 'attended', 'no_show') then
    raise exception 'invalid_attendance_status';
  end if;

  if p_participant_user_id = v_actor_id then
    raise exception 'cannot_mark_own_attendance';
  end if;

  select * into v_event
  from public.events
  where id = p_event_id
  for update;

  if v_event.id is null then
    raise exception 'event_not_found';
  end if;

  if coalesce(v_event.organizer_type, 'user') = 'business' then
    select id into v_business_id
    from public.business_accounts
    where owner_user_id = v_actor_id
      and status = 'active'
    limit 1;

    if v_business_id is not null
       and v_event.organizer_business_id = v_business_id then
      v_is_authorized := true;
    end if;
    v_target_status := case
      when p_attendance_status = 'no_show' then 'no_show'
      else 'checked_in'
    end;
  else
    if v_event.host_id = v_actor_id then
      v_is_authorized := true;
    end if;
    v_target_status := case
      when p_attendance_status = 'no_show' then 'no_show'
      else 'attended'
    end;
  end if;

  if not v_is_authorized then
    raise exception 'not_authorized';
  end if;

  select * into v_participant
  from public.event_participants
  where event_id = p_event_id
    and user_id = p_participant_user_id
    and role = 'participant'
  for update;

  if v_participant.user_id is null then
    raise exception 'participant_not_found';
  end if;

  if v_participant.attendance_status in ('checked_in', 'attended') then
    return;
  end if;

  if p_attendance_status in ('checked_in', 'attended')
     and char_length(coalesce(v_manual_reason, '')) < 5 then
    raise exception 'manual_check_in_reason_required';
  end if;

  if p_attendance_status = 'no_show' then
    if v_event.event_end_time is not null then
      declare
        v_event_end timestamptz;
      begin
        if v_event.event_start_time is not null then
          if v_event.event_end_time >= v_event.event_start_time then
            v_event_end := v_event.event_date + (v_event.event_end_time - v_event.event_start_time);
          else
            v_event_end := v_event.event_date + (v_event.event_end_time - v_event.event_start_time) + interval '24 hours';
          end if;
        else
          v_event_end := timezone('Europe/Istanbul', timezone('UTC', v_event.event_date))::date + v_event.event_end_time;
          v_event_end := timezone('Europe/Istanbul', v_event_end);
        end if;

        if now() < v_event_end then
          raise exception 'cannot_mark_no_show_before_event_end';
        end if;
      end;
    else
      if now() < v_event.event_date then
        raise exception 'cannot_mark_no_show_before_event_start';
      end if;
    end if;
  end if;

  update public.event_participants
  set attendance_status = v_target_status,
      checked_in_at = case
        when p_attendance_status in ('checked_in', 'attended') then now()
        else checked_in_at
      end,
      checked_in_by = case
        when coalesce(v_event.organizer_type, 'user') = 'business' then v_business_id
        else null
      end,
      checked_in_by_user_id = case
        when coalesce(v_event.organizer_type, 'user') = 'business' then null
        else v_actor_id
      end,
      verification_method = case
        when p_attendance_status in ('checked_in', 'attended') then 'manual'
        else verification_method
      end,
      manual_check_in_reason = case
        when p_attendance_status in ('checked_in', 'attended') then v_manual_reason
        else manual_check_in_reason
      end,
      manual_checked_in_by = case
        when p_attendance_status in ('checked_in', 'attended') then v_actor_id
        else manual_checked_in_by
      end,
      manual_checked_in_at = case
        when p_attendance_status in ('checked_in', 'attended') then now()
        else manual_checked_in_at
      end,
      on_time = false
  where event_id = p_event_id
    and user_id = p_participant_user_id;

  update public.events
  set approved_count = (
    select count(*)::integer
    from public.event_participants
    where event_id = p_event_id
      and role = 'participant'
      and attendance_status in ('confirmed', 'checked_in', 'planned', 'attended')
  )
  where id = p_event_id;

  if p_attendance_status = 'no_show' then
    perform public.apply_trust_score_event(
      p_participant_user_id,
      v_actor_id,
      'event_no_show',
      'event',
      p_event_id,
      jsonb_build_object('attendance_status', 'no_show', 'verification_method', 'manual')
    );
  else
    perform public.apply_trust_score_event(
      p_participant_user_id,
      v_actor_id,
      'event_manual_attended',
      'event',
      p_event_id,
      jsonb_build_object(
        'attendance_status', v_target_status,
        'verification_method', 'manual',
        'has_manual_reason', true
      )
    );
  end if;

  perform public.refresh_user_badges(p_participant_user_id);

  if coalesce(v_event.organizer_type, 'user') = 'business'
     and v_business_id is not null then
    perform public.recalculate_business_badges(v_business_id);
  end if;
end;
$$;

revoke all on function public.mark_event_attendance(uuid, uuid, text, text)
  from public, anon;
grant execute on function public.mark_event_attendance(uuid, uuid, text, text)
  to authenticated;

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
      'event_updated',
      'follow',
      'follow_request',
      'follow_request_approved',
      'follow_request_rejected',
      'system',
      'community_membership_approved',
      'community_membership_rejected',
      'community_role_assigned',
      'community_role_removed',
      'community_announcement',
      'community_chat_mention',
      'community_post_mention',
      'community_comment_mention',
      'community_comment_reply',
      'community_members_only_event',
      'community_membership_revocation'
    )
  ) not valid;

create or replace function public.queue_push_for_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_body text;
  v_title text;
  v_community_id uuid;
  v_is_muted boolean := false;
begin
  if new.type not in (
    'event_join_request',
    'event_updated',
    'community_membership_approved',
    'community_membership_rejected',
    'community_role_assigned',
    'community_role_removed',
    'community_announcement',
    'community_chat_mention',
    'community_post_mention',
    'community_comment_mention',
    'community_comment_reply',
    'community_members_only_event',
    'community_membership_revocation'
  ) then
    return new;
  end if;

  if new.type in ('community_chat_mention', 'community_announcement', 'community_members_only_event') then
    v_community_id := (new.metadata->>'community_id')::uuid;
    if v_community_id is not null then
      select exists (
        select 1
        from public.community_chat_mutes
        where community_id = v_community_id
          and user_id = new.recipient_id
      ) into v_is_muted;
    end if;
  end if;

  if v_is_muted and new.type = 'community_chat_mention' then
    return new;
  end if;

  v_body := nullif(btrim(coalesce(new.body, '')), '');
  v_title := nullif(btrim(coalesce(new.title, '')), '');

  if v_body is null then
    v_body := 'Yeni bir bildiriminiz var.';
  end if;
  if v_title is null then
    v_title := 'Akanzi';
  end if;

  insert into public.push_notification_outbox (
    notification_id,
    recipient_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    metadata
  )
  values (
    new.id,
    new.recipient_id,
    new.type,
    v_title,
    v_body,
    new.entity_type,
    new.entity_id,
    coalesce(new.metadata, '{}'::jsonb)
  )
  on conflict do nothing;

  return new;
end;
$$;

revoke all on function public.queue_push_for_notification() from public;

create or replace function public.notify_event_participants_on_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_time_changed boolean;
  v_location_changed boolean;
  v_participant_changed boolean;
  v_title text := 'Etkinlik güncellendi';
  v_body text := 'Katıldığın etkinlikte değişiklik yapıldı.';
  v_change_key text;
begin
  v_time_changed :=
    old.event_date is distinct from new.event_date
    or old.event_start_time is distinct from new.event_start_time
    or old.event_end_time is distinct from new.event_end_time;

  v_location_changed :=
    old.city is distinct from new.city
    or old.district is distinct from new.district
    or old.location_text is distinct from new.location_text
    or old.location_description is distinct from new.location_description
    or old.location_lat is distinct from new.location_lat
    or old.location_lng is distinct from new.location_lng;

  v_participant_changed :=
    old.title is distinct from new.title
    or old.description is distinct from new.description
    or old.capacity_total is distinct from new.capacity_total
    or old.generic_capacity is distinct from new.generic_capacity
    or old.male_capacity is distinct from new.male_capacity
    or old.female_capacity is distinct from new.female_capacity
    or old.require_completed_profile is distinct from new.require_completed_profile
    or old.min_age is distinct from new.min_age
    or old.status is distinct from new.status;

  if not (v_time_changed or v_location_changed or v_participant_changed) then
    return new;
  end if;

  if v_time_changed then
    v_body := 'Katıldığın etkinliğin saati güncellendi.';
  elsif v_location_changed then
    v_body := 'Katıldığın etkinliğin konumu güncellendi.';
  end if;

  v_change_key := md5(concat_ws(
    '|',
    new.id::text,
    coalesce(new.title, ''),
    coalesce(new.description, ''),
    coalesce(new.event_date::text, ''),
    coalesce(new.event_start_time::text, ''),
    coalesce(new.event_end_time::text, ''),
    coalesce(new.city, ''),
    coalesce(new.district, ''),
    coalesce(new.location_text, ''),
    coalesce(new.location_description, ''),
    coalesce(new.location_lat::text, ''),
    coalesce(new.location_lng::text, ''),
    coalesce(new.capacity_total::text, ''),
    coalesce(new.generic_capacity::text, ''),
    coalesce(new.male_capacity::text, ''),
    coalesce(new.female_capacity::text, ''),
    coalesce(new.require_completed_profile::text, ''),
    coalesce(new.min_age::text, ''),
    coalesce(new.status, '')
  ));

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
  select
    participant.user_id,
    v_actor_id,
    'event_updated',
    v_title,
    v_body,
    'event',
    new.id,
    jsonb_build_object(
      'event_id', new.id::text,
      'event_update_key', v_change_key,
      'time_changed', v_time_changed,
      'location_changed', v_location_changed
    ),
    false
  from public.event_participants participant
  where participant.event_id = new.id
    and participant.role = 'participant'
    and participant.attendance_status in (
      'planned',
      'approved',
      'confirmed',
      'checked_in',
      'attended'
    )
    and participant.user_id <> new.host_id
    and not exists (
      select 1
      from public.notifications existing
      where existing.recipient_id = participant.user_id
        and existing.type = 'event_updated'
        and existing.entity_type = 'event'
        and existing.entity_id = new.id
        and existing.metadata->>'event_update_key' = v_change_key
    );

  return new;
end;
$$;

drop trigger if exists trg_notify_event_participants_on_update
  on public.events;

create trigger trg_notify_event_participants_on_update
after update of
  title,
  description,
  event_date,
  event_start_time,
  event_end_time,
  location_text,
  location_description,
  city,
  district,
  location_lat,
  location_lng,
  capacity_total,
  generic_capacity,
  male_capacity,
  female_capacity,
  require_completed_profile,
  min_age,
  status
on public.events
for each row
execute function public.notify_event_participants_on_update();

revoke all on function public.notify_event_participants_on_update()
  from public;

notify pgrst, 'reload schema';
