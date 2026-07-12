-- AG-30: server-authoritative direct-message reporting.

alter table public.message_reports
  add column if not exists reported_user_id uuid,
  add column if not exists message_type text not null default 'event_chat',
  add column if not exists event_id uuid,
  add column if not exists conversation_id uuid,
  add column if not exists status text not null default 'pending';

alter table public.message_reports
  alter column message_id drop not null,
  add column if not exists direct_message_id uuid,
  add column if not exists details text,
  add column if not exists reported_message_snapshot text,
  add column if not exists reported_message_created_at timestamptz;

alter table public.message_reports
  drop constraint if exists message_reports_reported_user_id_fkey;
alter table public.message_reports
  add constraint message_reports_reported_user_id_fkey
  foreign key (reported_user_id) references auth.users(id)
  on delete set null not valid;

alter table public.message_reports
  drop constraint if exists message_reports_message_id_fkey;
alter table public.message_reports
  add constraint message_reports_message_id_fkey
  foreign key (message_id) references public.event_messages(id)
  on delete set null not valid;

alter table public.message_reports
  drop constraint if exists message_reports_event_id_fkey;
alter table public.message_reports
  add constraint message_reports_event_id_fkey
  foreign key (event_id) references public.events(id)
  on delete set null not valid;

alter table public.message_reports
  drop constraint if exists message_reports_direct_message_id_fkey;
alter table public.message_reports
  add constraint message_reports_direct_message_id_fkey
  foreign key (direct_message_id) references public.direct_messages(id)
  on delete set null;

alter table public.message_reports alter column conversation_id drop not null;
do $conversation_fk$
declare
  v_constraint_name text;
begin
  for v_constraint_name in
    select constraint_record.conname
    from pg_catalog.pg_constraint constraint_record
    join pg_catalog.pg_attribute column_record
      on column_record.attrelid = constraint_record.conrelid
      and column_record.attnum = any(constraint_record.conkey)
    where constraint_record.conrelid = 'public.message_reports'::regclass
      and constraint_record.contype = 'f'
      and cardinality(constraint_record.conkey) = 1
      and column_record.attname = 'conversation_id'
  loop
    execute format(
      'alter table public.message_reports drop constraint %I',
      v_constraint_name
    );
  end loop;
end;
$conversation_fk$;
alter table public.message_reports
  add constraint message_reports_conversation_id_fkey
  foreign key (conversation_id) references public.direct_conversations(id)
  on delete set null;

alter table public.message_reports
  drop constraint if exists message_reports_direct_dm_consistency;
alter table public.message_reports
  add constraint message_reports_direct_dm_consistency check (
    message_type <> 'direct_dm'
    or (event_id is null and message_id is null
      and reported_message_snapshot is not null
      and reported_message_created_at is not null)
  ) not valid;

alter table public.message_reports
  drop constraint if exists message_reports_message_type_check;
alter table public.message_reports
  add constraint message_reports_message_type_check check (
    message_type in ('event_chat', 'direct_dm')
  ) not valid;

alter table public.message_reports
  drop constraint if exists message_reports_status_check;
alter table public.message_reports
  add constraint message_reports_status_check check (
    status in ('pending', 'resolved', 'rejected')
  ) not valid;

alter table public.message_reports
  drop constraint if exists message_reports_event_chat_direct_message_null;
alter table public.message_reports
  add constraint message_reports_event_chat_direct_message_null check (
    message_type <> 'event_chat' or direct_message_id is null
  ) not valid;

alter table public.message_reports
  drop constraint if exists message_reports_details_length;
alter table public.message_reports
  add constraint message_reports_details_length check (
    details is null or length(details) <= 500
  ) not valid;

alter table public.message_reports
  drop constraint if exists message_reports_snapshot_length;
alter table public.message_reports
  add constraint message_reports_snapshot_length check (
    reported_message_snapshot is null
    or length(reported_message_snapshot) <= 2000
  ) not valid;

create unique index if not exists message_reports_reporter_direct_message_uidx
  on public.message_reports (reporter_id, direct_message_id)
  where message_type = 'direct_dm'
    and reporter_id is not null and direct_message_id is not null;

create unique index if not exists message_reports_reporter_event_message_uidx
  on public.message_reports (reporter_id, message_id)
  where message_type = 'event_chat'
    and reporter_id is not null and message_id is not null;

alter table public.message_reports enable row level security;
do $message_report_policies$
declare
  v_policy_name text;
begin
  for v_policy_name in
    select policy.policyname
    from pg_catalog.pg_policies policy
    where policy.schemaname = 'public'
      and policy.tablename = 'message_reports'
  loop
    execute format(
      'drop policy if exists %I on public.message_reports',
      v_policy_name
    );
  end loop;
end;
$message_report_policies$;
revoke all on table public.message_reports from public, anon, authenticated;

create or replace function public.report_event_message(
  p_message_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reporter_id uuid := auth.uid();
  v_message public.event_messages%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_report_id uuid;
begin
  if v_reporter_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  if length(v_reason) < 3 or length(v_reason) > 100 then
    raise exception using errcode = '22023', message = 'invalid_report_reason';
  end if;

  select message.* into v_message
  from public.event_messages message
  where message.id = p_message_id;

  if v_message.id is null then
    raise exception using errcode = 'P0002', message = 'event_message_not_found';
  end if;
  if v_message.event_id is null or v_message.sender_id is null
      or coalesce(v_message.moderation_status, 'approved') <> 'approved' then
    raise exception using errcode = '22023', message = 'event_message_not_found';
  end if;
  if not exists (
    select 1 from public.event_participants participant
    where participant.event_id = v_message.event_id
      and participant.user_id = v_reporter_id
      and (
        participant.role = 'host'
        or participant.attendance_status in (
          'planned', 'confirmed', 'checked_in', 'attended'
        )
      )
  ) and not exists (
    select 1 from public.events event
    where event.id = v_message.event_id
      and (
        event.host_id = v_reporter_id
        or event.organizer_user_id = v_reporter_id
        or exists (
          select 1 from public.business_members member
          where member.business_id = event.organizer_business_id
            and member.user_id = v_reporter_id
        )
      )
  ) then
    raise exception using errcode = '42501', message = 'not_event_chat_participant';
  end if;
  if v_message.sender_id = v_reporter_id then
    raise exception using errcode = '22023', message = 'cannot_report_own_message';
  end if;

  select report.id into v_report_id
  from public.message_reports report
  where report.message_type = 'event_chat'
    and report.reporter_id = v_reporter_id
    and report.message_id = v_message.id;
  if v_report_id is not null then
    return jsonb_build_object('report_id', v_report_id, 'already_reported', true);
  end if;

  insert into public.message_reports (
    message_id, direct_message_id, reporter_id, reported_user_id,
    message_type, conversation_id, event_id, reason, status
  ) values (
    v_message.id, null, v_reporter_id, v_message.sender_id,
    'event_chat', null, v_message.event_id, v_reason, 'pending'
  )
  on conflict (reporter_id, message_id)
    where message_type = 'event_chat'
      and reporter_id is not null and message_id is not null
  do nothing
  returning id into v_report_id;

  if v_report_id is null then
    select report.id into v_report_id
    from public.message_reports report
    where report.message_type = 'event_chat'
      and report.reporter_id = v_reporter_id
      and report.message_id = v_message.id;
    if v_report_id is null then
      raise exception using errcode = 'P0001', message = 'event_report_conflict';
    end if;
    return jsonb_build_object('report_id', v_report_id, 'already_reported', true);
  end if;
  return jsonb_build_object('report_id', v_report_id, 'already_reported', false);
end;
$function$;

revoke all on function public.report_event_message(uuid, text) from public, anon;
grant execute on function public.report_event_message(uuid, text) to authenticated;

create or replace function public.report_direct_message(
  p_direct_message_id uuid,
  p_reason text,
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reporter_id uuid := auth.uid();
  v_message public.direct_messages%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_details text := nullif(btrim(coalesce(p_details, '')), '');
  v_existing_report_id uuid;
  v_report_id uuid;
begin
  if v_reporter_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  if length(v_reason) < 3 or length(v_reason) > 100 then
    raise exception using errcode = '22023', message = 'invalid_report_reason';
  end if;
  if v_details is not null and length(v_details) > 500 then
    raise exception using errcode = '22001', message = 'report_details_too_long';
  end if;

  select message.* into v_message
  from public.direct_messages message
  where message.id = p_direct_message_id;

  if v_message.id is null then
    raise exception using errcode = 'P0002', message = 'direct_message_not_found';
  end if;
  if v_message.conversation_id is null or v_message.sender_user_id is null
      or v_message.created_at is null or v_message.body is null
      or length(v_message.body) > 2000 then
    raise exception using errcode = '22023', message = 'direct_message_not_found';
  end if;
  if not exists (
    select 1 from public.direct_conversation_participants participant
    where participant.conversation_id = v_message.conversation_id
      and participant.user_id = v_reporter_id
  ) then
    raise exception using errcode = '42501', message = 'not_conversation_participant';
  end if;
  if v_message.sender_user_id = v_reporter_id then
    raise exception using errcode = '22023', message = 'cannot_report_own_message';
  end if;

  select report.id into v_existing_report_id
  from public.message_reports report
  where report.message_type = 'direct_dm'
    and report.reporter_id = v_reporter_id
    and report.direct_message_id = v_message.id;
  if v_existing_report_id is not null then
    return jsonb_build_object('report_id', v_existing_report_id, 'already_reported', true);
  end if;

  insert into public.message_reports (
    message_id, direct_message_id, reporter_id, reported_user_id,
    message_type, conversation_id, event_id, reason, details, status,
    reported_message_snapshot, reported_message_created_at
  ) values (
    null, v_message.id, v_reporter_id, v_message.sender_user_id,
    'direct_dm', v_message.conversation_id, null, v_reason, v_details, 'pending',
    v_message.body, v_message.created_at
  )
  on conflict (reporter_id, direct_message_id)
    where message_type = 'direct_dm'
      and reporter_id is not null and direct_message_id is not null
  do nothing returning id into v_report_id;

  if v_report_id is null then
    select report.id into v_report_id
    from public.message_reports report
    where report.message_type = 'direct_dm'
      and report.reporter_id = v_reporter_id
      and report.direct_message_id = v_message.id;
    if v_report_id is null then
      raise exception using
        errcode = 'P0001',
        message = 'direct_message_report_conflict';
    end if;
    return jsonb_build_object('report_id', v_report_id, 'already_reported', true);
  end if;
  return jsonb_build_object('report_id', v_report_id, 'already_reported', false);
end;
$function$;

revoke all on function public.report_direct_message(uuid, text, text) from public, anon;
grant execute on function public.report_direct_message(uuid, text, text) to authenticated;

create or replace function public.admin_list_direct_message_reports(
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid, direct_message_id uuid, message_type text,
  reporter_id uuid, reported_user_id uuid,
  conversation_id uuid, reason text, details text, status text,
  reported_message_snapshot text, reported_message_created_at timestamptz,
  created_at timestamptz, reporter_name text, reported_user_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.is_current_user_admin() then
    raise exception using errcode = '42501', message = 'not_admin';
  end if;
  if p_status is not null and p_status not in ('pending', 'resolved', 'rejected') then
    raise exception using errcode = '22023', message = 'invalid_status';
  end if;
  return query
  select report.id, report.direct_message_id, report.message_type,
    report.reporter_id,
    report.reported_user_id, report.conversation_id, report.reason,
    report.details, report.status, report.reported_message_snapshot,
    report.reported_message_created_at, report.created_at,
    (select coalesce(profile.first_name || ' ' || profile.last_name, profile.username)
      from public.profiles profile where profile.user_id = report.reporter_id),
    (select coalesce(profile.first_name || ' ' || profile.last_name, profile.username)
      from public.profiles profile where profile.user_id = report.reported_user_id)
  from public.message_reports report
  where report.message_type = 'direct_dm'
    and (p_status is null or report.status = p_status)
  order by report.created_at desc, report.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

revoke all on function public.admin_list_direct_message_reports(text, integer, integer)
  from public, anon;
grant execute on function public.admin_list_direct_message_reports(text, integer, integer)
  to authenticated;

create or replace function public.remove_reported_content_as_admin(
  p_report_type text,
  p_report_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_admin_id uuid := auth.uid();
  v_target_id uuid;
  v_target_type text;
  v_message_type text;
begin
  if v_admin_id is null or not public.is_current_user_admin() then
    raise exception 'not_admin';
  end if;

  if p_report_type = 'message' then
    select
      case
        when report.message_type = 'direct_dm' then report.direct_message_id
        else report.message_id
      end,
      report.message_type
    into v_target_id, v_message_type
    from public.message_reports report
    where report.id = p_report_id;

    if v_target_id is null then
      raise exception 'report_not_found';
    end if;

    if v_message_type = 'direct_dm' then
      update public.direct_messages
      set moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      where id = v_target_id;
    elsif exists (select 1 from public.event_messages where id = v_target_id) then
      update public.event_messages
      set moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      where id = v_target_id;
    elsif exists (
      select 1 from public.community_chat_messages where id = v_target_id
    ) then
      update public.community_chat_messages
      set is_deleted = true
      where id = v_target_id;
    else
      raise exception 'reported_message_not_found';
    end if;

    if not found then
      raise exception 'reported_message_not_found';
    end if;

    update public.message_reports
    set status = 'resolved'
    where id = p_report_id;

    insert into public.admin_moderation_actions (
      admin_user_id, action, target_type, target_id, reason
    ) values (
      v_admin_id, 'message_report_removed', 'message_report', p_report_id,
      p_reason
    );
  else
    select report.target_id, report.target_type
    into v_target_id, v_target_type
    from public.reports report
    where report.id = p_report_id;

    if v_target_id is null then
      raise exception 'report_not_found';
    end if;

    if v_target_type = 'event' then
      perform public.set_event_moderation_status_as_admin(
        v_target_id, 'removed_by_admin', p_reason
      );
    elsif v_target_type = 'post' then
      update public.posts
      set moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      where id = v_target_id;
    elsif v_target_type in ('comment', 'post_comment') then
      update public.post_comments
      set moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      where id = v_target_id;
    else
      raise exception 'unsupported_report_target_type';
    end if;

    update public.reports
    set status = 'resolved', updated_at = now()
    where id = p_report_id;

    insert into public.admin_moderation_actions (
      admin_user_id, action, target_type, target_id, reason
    ) values (
      v_admin_id, 'user_report_removed', 'report', p_report_id, p_reason
    );
  end if;
end;
$function$;

revoke all on function public.remove_reported_content_as_admin(text, uuid, text)
  from public, anon;
grant execute on function public.remove_reported_content_as_admin(text, uuid, text)
  to authenticated;

comment on function public.report_direct_message(uuid, text, text) is
  'Creates an idempotent, server-authoritative direct-message moderation report.';
comment on function public.admin_list_direct_message_reports(text, integer, integer) is
  'Returns bounded direct-message report evidence to canonical admins only.';

notify pgrst, 'reload schema';
