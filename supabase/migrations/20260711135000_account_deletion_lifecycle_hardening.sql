create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

create table if not exists private.account_deletion_attendance_audit (
  request_id uuid not null,
  event_id uuid not null,
  subject_hash text not null,
  role text not null,
  attendance_status text not null,
  checked_in_at timestamptz,
  recorded_at timestamptz not null default now(),
  primary key (request_id, event_id)
);

create table if not exists private.account_deletion_safety_audit (
  request_id uuid not null,
  source_table text not null,
  source_row_id uuid not null,
  subject_role text not null,
  subject_hash text not null,
  evidence jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now(),
  primary key (request_id, source_table, source_row_id, subject_role)
);

revoke all on private.account_deletion_attendance_audit
  from public, anon, authenticated;
revoke all on private.account_deletion_safety_audit
  from public, anon, authenticated;

alter table public.account_deletion_requests
  add column if not exists eligible_at timestamptz,
  add column if not exists deletion_deadline_at timestamptz,
  add column if not exists attempt_count integer not null default 0,
  add column if not exists next_attempt_at timestamptz,
  add column if not exists processing_started_at timestamptz,
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by text,
  add column if not exists last_error_code text,
  add column if not exists completed_at timestamptz,
  add column if not exists auth_deleted_at timestamptz,
  add column if not exists storage_deleted_at timestamptz,
  add column if not exists data_finalized_at timestamptz,
  add column if not exists subject_hash text,
  add column if not exists subject_user_id_snapshot uuid;

update public.account_deletion_requests
set
  status = case
    when status = 'requested' then 'pending'
    when status in ('rejected', 'cancelled') then 'failed'
    else status
  end,
  eligible_at = coalesce(eligible_at, requested_at, created_at, now()),
  deletion_deadline_at = coalesce(
    deletion_deadline_at,
    coalesce(requested_at, created_at, now()) + interval '24 hours'
  ),
  next_attempt_at = coalesce(next_attempt_at, requested_at, created_at, now()),
  subject_hash = coalesce(subject_hash, encode(
    extensions.digest(coalesce(user_id::text, 'legacy:' || id::text), 'sha256'),
    'hex'
  )),
  subject_user_id_snapshot = coalesce(subject_user_id_snapshot, user_id),
  completed_at = case
    when status = 'completed' then coalesce(completed_at, processed_at, updated_at)
    else completed_at
  end;

alter table public.account_deletion_requests
  alter column eligible_at set default now(),
  alter column eligible_at set not null,
  alter column deletion_deadline_at set default (now() + interval '24 hours'),
  alter column deletion_deadline_at set not null,
  alter column next_attempt_at set default now(),
  alter column next_attempt_at set not null,
  alter column subject_hash set not null;

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_requests_attempt_count_check;
alter table public.account_deletion_requests
  add constraint account_deletion_requests_attempt_count_check
  check (attempt_count >= 0);

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_requests_completed_at_check;
alter table public.account_deletion_requests
  add constraint account_deletion_requests_completed_at_check
  check (status <> 'completed' or completed_at is not null);

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_requests_status_check;

alter table public.account_deletion_requests
  add constraint account_deletion_requests_status_check
  check (status in ('pending', 'processing', 'retry', 'completed', 'failed'));

drop index if exists public.account_deletion_requests_one_active_per_user_idx;

create unique index account_deletion_requests_one_open_subject_idx
  on public.account_deletion_requests (subject_hash)
  where status in ('pending', 'processing', 'retry');

create index account_deletion_requests_queue_idx
  on public.account_deletion_requests (
    status,
    next_attempt_at,
    requested_at,
    id
  );

create index account_deletion_requests_deadline_idx
  on public.account_deletion_requests (deletion_deadline_at)
  where status in ('pending', 'processing', 'retry', 'failed');

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_requests_user_id_fkey;
alter table public.account_deletion_requests alter column user_id drop not null;
alter table public.account_deletion_requests
  add constraint account_deletion_requests_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_requests_processed_by_fkey;
alter table public.account_deletion_requests
  add constraint account_deletion_requests_processed_by_fkey
  foreign key (processed_by) references auth.users(id) on delete set null;

alter table public.business_accounts
  drop constraint if exists business_accounts_owner_user_id_fkey;
alter table public.business_accounts alter column owner_user_id drop not null;
alter table public.business_accounts
  add constraint business_accounts_owner_user_id_fkey
  foreign key (owner_user_id) references auth.users(id) on delete set null;

alter table public.business_plus_subscriptions
  drop constraint if exists business_plus_subscriptions_owner_user_id_fkey;
alter table public.business_plus_subscriptions
  alter column owner_user_id drop not null;
alter table public.business_plus_subscriptions
  add constraint business_plus_subscriptions_owner_user_id_fkey
  foreign key (owner_user_id) references auth.users(id) on delete set null;

alter table public.business_plus_purchase_contexts
  drop constraint if exists business_plus_purchase_contexts_user_id_fkey;
alter table public.business_plus_purchase_contexts
  alter column user_id drop not null;
alter table public.business_plus_purchase_contexts
  add constraint business_plus_purchase_contexts_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

alter table public.communities
  drop constraint if exists communities_owner_user_id_fkey;
alter table public.communities alter column owner_user_id drop not null;
alter table public.communities
  add constraint communities_owner_user_id_fkey
  foreign key (owner_user_id) references auth.users(id) on delete set null;

alter table public.message_reports
  drop constraint if exists message_reports_reporter_id_fkey;
alter table public.message_reports alter column reporter_id drop not null;
alter table public.message_reports
  add constraint message_reports_reporter_id_fkey
  foreign key (reporter_id) references auth.users(id) on delete set null;

do $reports_fk$
declare
  v_reporter_fk_name text;
  v_reporter_fk_delete_action "char";
begin
  select constraint_record.conname, constraint_record.confdeltype
  into v_reporter_fk_name, v_reporter_fk_delete_action
  from pg_catalog.pg_constraint constraint_record
  join pg_catalog.pg_attribute column_record
    on column_record.attrelid = constraint_record.conrelid
    and column_record.attnum = any(constraint_record.conkey)
  where constraint_record.conrelid = 'public.reports'::regclass
    and constraint_record.confrelid = 'auth.users'::regclass
    and constraint_record.contype = 'f'
    and cardinality(constraint_record.conkey) = 1
    and column_record.attname = 'reporter_id'
  limit 1;

  alter table public.reports alter column reporter_id drop not null;

  if v_reporter_fk_name is not null and v_reporter_fk_delete_action <> 'n' then
    execute format(
      'alter table public.reports drop constraint %I',
      v_reporter_fk_name
    );
    execute format(
      'alter table public.reports add constraint %I foreign key (reporter_id) references auth.users(id) on delete set null',
      v_reporter_fk_name
    );
  end if;
end;
$reports_fk$;

alter table public.business_applications
  drop constraint if exists business_applications_reviewed_by_fkey;
alter table public.business_applications
  add constraint business_applications_reviewed_by_fkey
  foreign key (reviewed_by) references auth.users(id) on delete set null;

alter table public.event_moderation_logs
  drop constraint if exists event_moderation_logs_admin_user_id_fkey;
alter table public.event_moderation_logs
  add constraint event_moderation_logs_admin_user_id_fkey
  foreign key (admin_user_id) references auth.users(id) on delete set null;

alter table public.events
  drop constraint if exists events_moderation_removed_by_fkey;
alter table public.events
  add constraint events_moderation_removed_by_fkey
  foreign key (moderation_removed_by) references auth.users(id)
  on delete set null;

alter table public.events
  drop constraint if exists events_host_id_fkey;
alter table public.events alter column host_id drop not null;
alter table public.events
  add constraint events_host_id_fkey
  foreign key (host_id) references auth.users(id) on delete set null;

alter table public.direct_messages
  drop constraint if exists direct_messages_sender_user_id_fkey;
alter table public.direct_messages alter column sender_user_id drop not null;
alter table public.direct_messages
  add constraint direct_messages_sender_user_id_fkey
  foreign key (sender_user_id) references auth.users(id) on delete set null;

alter table private.business_plus_admin_audit_logs
  drop constraint if exists business_plus_admin_audit_logs_acting_admin_id_fkey;
alter table private.business_plus_admin_audit_logs
  add constraint business_plus_admin_audit_logs_acting_admin_id_fkey
  foreign key (acting_admin_id) references auth.users(id) on delete set null;

alter table public.account_deletion_requests enable row level security;

drop policy if exists "Users can create own account deletion request"
  on public.account_deletion_requests;
drop policy if exists "Admins can update account deletion requests"
  on public.account_deletion_requests;
drop policy if exists "Users can read own account deletion requests"
  on public.account_deletion_requests;

revoke all on public.account_deletion_requests
  from public, anon, authenticated;

create or replace function public.request_my_account_deletion()
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_subject_hash text;
  v_request_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  v_subject_hash := encode(
    extensions.digest(v_user_id::text, 'sha256'),
    'hex'
  );

  insert into public.account_deletion_requests (
    user_id,
    subject_hash,
    subject_user_id_snapshot,
    status,
    requested_at,
    eligible_at,
    deletion_deadline_at,
    attempt_count,
    next_attempt_at,
    updated_at
  )
  values (
    v_user_id,
    v_subject_hash,
    v_user_id,
    'pending',
    now(),
    now(),
    now() + interval '24 hours',
    0,
    now(),
    now()
  )
  on conflict (subject_hash)
    where status in ('pending', 'processing', 'retry')
  do update set updated_at = now()
  returning id into v_request_id;

  update public.profiles
  set
    account_status = 'deletion_requested',
    deletion_requested_at = coalesce(deletion_requested_at, now()),
    is_private = true,
    is_profile_completed = false,
    username = null,
    tag = null,
    first_name = 'Silinmiş kullanıcı',
    last_name = null,
    avatar_url = null,
    bio = null,
    city = null,
    district = null,
    phone = null,
    phone_number = null,
    phone_verified = false,
    phone_verified_at = null,
    account_type = 'user',
    business_account_id = null,
    updated_at = now()
  where user_id = v_user_id
    and coalesce(account_status, 'active') <> 'deletion_requested';

  perform set_config('app.bypass_business_moderation', 'on', true);

  update public.business_accounts business
  set
    status = 'deleted',
    name = 'Silinmiş işletme',
    username = 'deleted_' || substr(encode(
      extensions.digest(business.id::text, 'sha256'),
      'hex'
    ), 1, 16),
    address = null,
    description = null,
    phone = null,
    website = null,
    instagram = null,
    logo_url = null,
    cover_url = null,
    gallery_urls = '{}',
    latitude = null,
    longitude = null,
    is_verified = false,
    is_plus_active = false,
    pinned_event_id = null,
    updated_at = now()
  where owner_user_id = v_user_id
    and status in ('pending', 'active', 'suspended');

  update public.business_plus_subscriptions
  set
    auto_renew_enabled = false,
    revocation_time = coalesce(revocation_time, now()),
    updated_at = now()
  where (
    owner_user_id = v_user_id
    or business_account_id in (
      select business.id
      from public.business_accounts business
      where business.owner_user_id = v_user_id
    )
  )
    and revocation_time is null;

  update public.events
  set
    status = 'cancelled',
    description = null,
    location_text = null,
    location_description = null,
    is_sponsored = false,
    sponsored_until = null,
    sponsored_priority = 0,
    updated_at = now()
  where (
    host_id = v_user_id
    or organizer_business_id in (
      select business.id
      from public.business_accounts business
      where business.owner_user_id = v_user_id
    )
  )
    and status = 'active'
    and event_date >= now();

  update public.posts
  set is_archived = true, updated_at = now()
  where user_id = v_user_id
    and coalesce(is_archived, false) = false;

  delete from public.user_push_tokens where user_id = v_user_id;
  delete from public.notifications where recipient_id = v_user_id;

  return v_request_id is not null;
end;
$function$;

revoke all on function public.request_my_account_deletion()
  from public, anon, authenticated;
grant execute on function public.request_my_account_deletion() to authenticated;

create or replace function public.service_claim_account_deletion_requests(
  p_limit integer,
  p_worker_id text
)
returns table (
  request_id uuid,
  subject_user_id uuid,
  deletion_deadline_at timestamptz,
  attempt_count integer,
  storage_deleted_at timestamptz,
  data_finalized_at timestamptz,
  auth_deleted_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 20);
  v_worker_id text := nullif(btrim(p_worker_id), '');
begin
  if v_worker_id is null or length(v_worker_id) > 100 then
    raise exception 'invalid_worker_id';
  end if;

  update public.account_deletion_requests
  set
    status = 'retry',
    next_attempt_at = now(),
    locked_at = null,
    locked_by = null,
    last_error_code = 'unexpected_worker_failure',
    updated_at = now()
  where status = 'processing'
    and locked_at < now() - interval '1 hour';

  return query
  with selected as (
    select request.id
    from public.account_deletion_requests request
    where request.status in ('pending', 'retry')
      and request.subject_user_id_snapshot is not null
      and request.eligible_at <= now()
      and request.next_attempt_at <= now()
    order by
      request.next_attempt_at asc nulls first,
      request.requested_at asc,
      request.id asc
    for update skip locked
    limit v_limit
  ), claimed as (
    update public.account_deletion_requests request
    set
      status = 'processing',
      attempt_count = request.attempt_count + 1,
      processing_started_at = now(),
      locked_at = now(),
      locked_by = v_worker_id,
      last_error_code = null,
      updated_at = now()
    from selected
    where request.id = selected.id
    returning
      request.id,
      request.subject_user_id_snapshot,
      request.deletion_deadline_at,
      request.attempt_count,
      request.storage_deleted_at,
      request.data_finalized_at,
      request.auth_deleted_at
  )
  select
    claimed.id,
    claimed.subject_user_id_snapshot,
    claimed.deletion_deadline_at,
    claimed.attempt_count,
    claimed.storage_deleted_at,
    claimed.data_finalized_at,
    claimed.auth_deleted_at
  from claimed;
end;
$function$;

create or replace function public.service_list_account_deletion_storage_objects(
  p_request_id uuid,
  p_subject_user_id uuid,
  p_worker_id text,
  p_limit integer default 500
)
returns table (bucket_id text, object_name text)
language plpgsql
security definer
set search_path = ''
stable
as $function$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 500), 1), 500);
begin
  if not exists (
    select 1
    from public.account_deletion_requests request
    where request.id = p_request_id
      and request.status = 'processing'
      and request.locked_by = nullif(btrim(p_worker_id), '')
      and request.locked_at is not null
      and request.subject_user_id_snapshot = p_subject_user_id
      and request.subject_hash = encode(
        extensions.digest(p_subject_user_id::text, 'sha256'),
        'hex'
      )
  ) then
    raise exception 'invalid_request_state';
  end if;

  return query
  select object_row.bucket_id, object_row.name
  from storage.objects object_row
  where (
      object_row.owner_id::text = p_subject_user_id::text
      or (
        object_row.bucket_id in ('avatars', 'post-images')
        and (storage.foldername(object_row.name))[1] =
          p_subject_user_id::text
      )
    )
  order by object_row.bucket_id, object_row.name
  limit v_limit;
end;
$function$;

create or replace function public.service_mark_account_deletion_storage_complete(
  p_request_id uuid,
  p_subject_user_id uuid,
  p_worker_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not exists (
    select 1
    from public.account_deletion_requests request
    where request.id = p_request_id
      and request.status = 'processing'
      and request.locked_by = nullif(btrim(p_worker_id), '')
      and request.locked_at is not null
      and request.subject_user_id_snapshot = p_subject_user_id
      and request.subject_hash = encode(
        extensions.digest(p_subject_user_id::text, 'sha256'),
        'hex'
      )
  ) then
    raise exception 'invalid_request_state';
  end if;

  if exists (
    select 1
    from storage.objects object_row
    where object_row.owner_id::text = p_subject_user_id::text
      or (
        object_row.bucket_id in ('avatars', 'post-images')
        and (storage.foldername(object_row.name))[1] =
          p_subject_user_id::text
      )
  ) then
    raise exception 'storage_objects_remaining';
  end if;

  update public.account_deletion_requests request
  set storage_deleted_at = coalesce(storage_deleted_at, now()),
      updated_at = now()
  where request.id = p_request_id
    and request.status = 'processing'
    and request.locked_by = nullif(btrim(p_worker_id), '')
    and request.locked_at is not null
    and request.subject_user_id_snapshot = p_subject_user_id
    and request.subject_hash = encode(
      extensions.digest(p_subject_user_id::text, 'sha256'),
      'hex'
    );

  return found;
end;
$function$;

create or replace function public.service_finalize_account_deletion_data(
  p_request_id uuid,
  p_subject_user_id uuid,
  p_worker_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_request public.account_deletion_requests%rowtype;
  v_counts jsonb := '{}'::jsonb;
  v_count integer;
  v_participant_event_ids uuid[];
  v_report_target_nullable boolean;
begin
  select * into v_request
  from public.account_deletion_requests request
  where request.id = p_request_id
  for update;

  if v_request.id is null or v_request.status <> 'processing' then
    raise exception 'invalid_request_state';
  end if;
  if v_request.locked_at is null
    or v_request.locked_by is distinct from nullif(btrim(p_worker_id), '') then
    raise exception 'worker_lock_mismatch';
  end if;
  if v_request.subject_user_id_snapshot is distinct from p_subject_user_id
    or v_request.subject_hash <> encode(
    extensions.digest(p_subject_user_id::text, 'sha256'),
    'hex'
  ) then
    raise exception 'subject_mismatch';
  end if;
  if v_request.storage_deleted_at is null then
    raise exception 'storage_not_finalized';
  end if;
  if v_request.data_finalized_at is not null then
    return jsonb_build_object('already_finalized', true);
  end if;

  delete from public.user_push_tokens where user_id = p_subject_user_id;
  get diagnostics v_count = row_count;
  v_counts := v_counts || jsonb_build_object('push_tokens', v_count);

  delete from public.user_hidden_conversations
  where user_id = p_subject_user_id;
  delete from public.follows
  where follower_id = p_subject_user_id
    or following_id = p_subject_user_id;
  delete from public.follow_requests
  where requester_id = p_subject_user_id
    or target_user_id = p_subject_user_id;
  delete from public.blocks
  where blocker_id = p_subject_user_id
    or blocked_id = p_subject_user_id;
  delete from public.notifications where recipient_id = p_subject_user_id;
  delete from public.event_join_requests where user_id = p_subject_user_id;
  delete from public.rate_limit_events where user_id = p_subject_user_id;
  delete from public.chat_mutes where user_id = p_subject_user_id;
  delete from public.chat_poll_votes where user_id = p_subject_user_id;
  delete from public.chat_polls where creator_id = p_subject_user_id;
  delete from public.chat_notifications_queue
  where sender_id = p_subject_user_id or recipient_id = p_subject_user_id;
  delete from public.push_notification_outbox
  where recipient_id = p_subject_user_id;
  delete from public.user_badges where user_id = p_subject_user_id;
  delete from public.business_reviews where user_id = p_subject_user_id;
  delete from public.user_feedback where user_id = p_subject_user_id;
  delete from public.business_plus_support_requests
  where user_id = p_subject_user_id;

  update public.account_deletion_requests
  set processed_by = null
  where processed_by = p_subject_user_id;
  update public.business_applications
  set reviewed_by = null
  where reviewed_by = p_subject_user_id;
  update private.business_plus_admin_audit_logs
  set acting_admin_id = null
  where acting_admin_id = p_subject_user_id;
  update public.event_moderation_logs
  set admin_user_id = null
  where admin_user_id = p_subject_user_id;
  update public.events
  set moderation_removed_by = null
  where moderation_removed_by = p_subject_user_id;
  update public.admin_moderation_actions
  set admin_user_id = null
  where admin_user_id = p_subject_user_id;

  insert into private.account_deletion_safety_audit (
    request_id, source_table, source_row_id, subject_role, subject_hash, evidence
  )
  select p_request_id, 'reports', report.id, 'reporter', v_request.subject_hash,
    to_jsonb(report) - 'reporter_id' - 'target_id'
  from public.reports report
  where report.reporter_id = p_subject_user_id
  on conflict do nothing;

  insert into private.account_deletion_safety_audit (
    request_id, source_table, source_row_id, subject_role, subject_hash, evidence
  )
  select p_request_id, 'reports', report.id, 'reported', v_request.subject_hash,
    to_jsonb(report) - 'reporter_id' - 'target_id'
  from public.reports report
  where report.target_type = 'user'
    and report.target_id = p_subject_user_id
  on conflict do nothing;

  update public.reports
  set reporter_id = null
  where reporter_id = p_subject_user_id;

  select not column_record.attnotnull
  into v_report_target_nullable
  from pg_catalog.pg_attribute column_record
  where column_record.attrelid = 'public.reports'::regclass
    and column_record.attname = 'target_id'
    and not column_record.attisdropped;

  if coalesce(v_report_target_nullable, false) then
    update public.reports
    set target_id = null
    where target_type = 'user' and target_id = p_subject_user_id;
  else
    delete from public.reports
    where target_type = 'user' and target_id = p_subject_user_id;
  end if;

  insert into private.account_deletion_safety_audit (
    request_id, source_table, source_row_id, subject_role, subject_hash
  )
  select p_request_id, 'message_reports', report.id, 'reporter',
    v_request.subject_hash
  from public.message_reports report
  where report.reporter_id = p_subject_user_id
  on conflict do nothing;
  update public.message_reports
  set reporter_id = null
  where reporter_id = p_subject_user_id;
  update public.message_reports
  set reported_user_id = null
  where reported_user_id = p_subject_user_id;

  insert into private.account_deletion_safety_audit (
    request_id, source_table, source_row_id, subject_role, subject_hash
  )
  select p_request_id, 'trust_score_logs', trust_log.id, 'subject',
    v_request.subject_hash
  from public.trust_score_logs trust_log
  where trust_log.user_id = p_subject_user_id
  on conflict do nothing;
  delete from public.trust_score_logs where user_id = p_subject_user_id;

  delete from public.post_comments where user_id = p_subject_user_id;
  delete from public.post_likes where user_id = p_subject_user_id;
  delete from public.posts where user_id = p_subject_user_id;
  get diagnostics v_count = row_count;
  v_counts := v_counts || jsonb_build_object('posts', v_count);

  update public.direct_conversations conversation
  set last_message_preview = null, updated_at = now()
  where exists (
    select 1
    from public.direct_conversation_participants participant
    where participant.conversation_id = conversation.id
      and participant.user_id = p_subject_user_id
  );
  update public.direct_messages
  set body = '[silindi]', sender_user_id = null
  where sender_user_id = p_subject_user_id;
  delete from public.direct_conversation_participants
  where user_id = p_subject_user_id;

  delete from public.message_reactions where user_id = p_subject_user_id;
  insert into private.account_deletion_safety_audit (
    request_id, source_table, source_row_id, subject_role, subject_hash
  )
  select p_request_id, 'event_messages', message.id, 'sender',
    v_request.subject_hash
  from public.event_messages message
  where message.sender_id = p_subject_user_id
  on conflict do nothing;
  delete from public.event_messages where sender_id = p_subject_user_id;

  delete from public.community_follows where user_id = p_subject_user_id;
  delete from public.community_memberships where user_id = p_subject_user_id;
  delete from public.community_chat_reactions
  where user_id = p_subject_user_id;
  delete from public.community_post_reactions
  where user_id = p_subject_user_id;
  delete from public.community_comments
  where user_id = p_subject_user_id;
  delete from public.community_chat_messages
  where user_id = p_subject_user_id;
  delete from public.community_posts
  where user_id = p_subject_user_id;

  update public.communities
  set
    name = 'Arşivlenmiş topluluk',
    normalized_name = 'deleted-' || substr(encode(
      extensions.digest(id::text, 'sha256'),
      'hex'
    ), 1, 16),
    slug = 'deleted-' || substr(encode(
      extensions.digest(id::text, 'sha256'),
      'hex'
    ), 1, 16),
    description = 'Arşivlenmiş topluluk',
    short_description = 'Arşivlendi',
    avatar_url = null,
    cover_image_url = null,
    city = 'Silindi',
    district = null,
    location_label = null,
    status = 'archived',
    archived_at = coalesce(archived_at, now()),
    owner_user_id = null,
    updated_at = now()
  where owner_user_id = p_subject_user_id;

  select array_agg(distinct participant.event_id)
  into v_participant_event_ids
  from public.event_participants participant
  where participant.user_id = p_subject_user_id;

  insert into private.account_deletion_attendance_audit (
    request_id,
    event_id,
    subject_hash,
    role,
    attendance_status,
    checked_in_at
  )
  select
    p_request_id,
    participant.event_id,
    v_request.subject_hash,
    participant.role,
    participant.attendance_status,
    participant.checked_in_at
  from public.event_participants participant
  where participant.user_id = p_subject_user_id
    and participant.attendance_status in ('attended', 'checked_in', 'no_show')
  on conflict do nothing;

  delete from public.event_participants
  where user_id = p_subject_user_id;

  update public.events event
  set approved_count = (
    select count(*)::integer
    from public.event_participants participant
    where participant.event_id = event.id
      and participant.role = 'participant'
      and participant.attendance_status in (
        'planned', 'attended', 'confirmed', 'checked_in'
      )
  )
  where event.id = any(coalesce(v_participant_event_ids, '{}'::uuid[]));

  update public.events
  set
    status = case
      when event_date >= now() and status = 'active'
        then 'cancelled'
      else status
    end,
    description = null,
    location_text = null,
    location_description = null,
    host_id = null,
    organizer_user_id = null,
    is_sponsored = false,
    sponsored_until = null,
    sponsored_priority = 0,
    updated_at = now()
  where host_id = p_subject_user_id
    or organizer_business_id in (
      select business.id
      from public.business_accounts business
      where business.owner_user_id = p_subject_user_id
    );

  update public.business_plus_subscriptions
  set
    auto_renew_enabled = false,
    revocation_time = coalesce(revocation_time, now()),
    owner_user_id = null,
    updated_at = now()
  where (
    owner_user_id = p_subject_user_id
    or business_account_id in (
      select business.id
      from public.business_accounts business
      where business.owner_user_id = p_subject_user_id
    )
  );

  update public.business_plus_purchase_contexts
  set user_id = null
  where user_id = p_subject_user_id;

  update public.business_accounts
  set
    status = 'deleted',
    address = null,
    description = null,
    phone = null,
    website = null,
    instagram = null,
    logo_url = null,
    cover_url = null,
    gallery_urls = '{}',
    latitude = null,
    longitude = null,
    is_verified = false,
    is_plus_active = false,
    pinned_event_id = null,
    owner_user_id = null,
    updated_at = now()
  where owner_user_id = p_subject_user_id;
  get diagnostics v_count = row_count;
  v_counts := v_counts || jsonb_build_object('business_accounts', v_count);

  update public.account_deletion_requests
  set data_finalized_at = now(), updated_at = now()
  where id = p_request_id
    and status = 'processing'
    and locked_by = nullif(btrim(p_worker_id), '')
    and locked_at is not null;

  return v_counts;
end;
$function$;

create or replace function public.service_record_account_deletion_failure(
  p_request_id uuid,
  p_subject_user_id uuid,
  p_worker_id text,
  p_error_code text,
  p_terminal boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_safe_code text;
  v_request public.account_deletion_requests%rowtype;
begin
  select * into v_request
  from public.account_deletion_requests request
  where request.id = p_request_id
  for update;

  if v_request.id is null or v_request.status <> 'processing' then
    raise exception 'invalid_request_state';
  end if;
  if v_request.locked_at is null
    or v_request.locked_by is distinct from nullif(btrim(p_worker_id), '') then
    raise exception 'worker_lock_mismatch';
  end if;
  if v_request.subject_user_id_snapshot is distinct from p_subject_user_id
    or v_request.subject_hash <> encode(
      extensions.digest(p_subject_user_id::text, 'sha256'),
      'hex'
    ) then
    raise exception 'subject_mismatch';
  end if;

  v_safe_code := case p_error_code
    when 'invalid_request_state' then p_error_code
    when 'worker_lock_mismatch' then p_error_code
    when 'subject_mismatch' then p_error_code
    when 'storage_list_failed' then p_error_code
    when 'storage_delete_failed' then p_error_code
    when 'storage_objects_remaining' then p_error_code
    when 'data_finalization_failed' then p_error_code
    when 'auth_delete_failed' then p_error_code
    when 'auth_user_lookup_failed' then p_error_code
    when 'completion_failed' then p_error_code
    when 'configuration_error' then p_error_code
    else 'unexpected_worker_failure'
  end;

  update public.account_deletion_requests request
  set
    status = case
      when p_terminal or request.attempt_count >= 8 then 'failed'
      else 'retry'
    end,
    next_attempt_at = now() + case
      when request.attempt_count <= 2 then interval '15 minutes'
      when request.attempt_count <= 4 then interval '1 hour'
      when request.attempt_count <= 6 then interval '6 hours'
      else interval '24 hours'
    end,
    locked_at = null,
    locked_by = null,
    processing_started_at = null,
    last_error_code = v_safe_code,
    updated_at = now()
  where request.id = p_request_id
    and request.status = 'processing'
    and request.locked_by = nullif(btrim(p_worker_id), '')
    and request.locked_at is not null
    and request.subject_user_id_snapshot = p_subject_user_id
    and request.subject_hash = encode(
      extensions.digest(p_subject_user_id::text, 'sha256'),
      'hex'
    );

  return found;
end;
$function$;

create or replace function public.service_mark_account_deletion_auth_complete(
  p_request_id uuid,
  p_subject_user_id uuid,
  p_worker_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update public.account_deletion_requests request
  set auth_deleted_at = coalesce(auth_deleted_at, now()),
      updated_at = now()
  where request.id = p_request_id
    and request.status = 'processing'
    and request.locked_by = nullif(btrim(p_worker_id), '')
    and request.locked_at is not null
    and request.subject_user_id_snapshot = p_subject_user_id
    and request.storage_deleted_at is not null
    and request.data_finalized_at is not null
    and request.subject_hash = encode(
      extensions.digest(p_subject_user_id::text, 'sha256'),
      'hex'
    );

  if not found then
    raise exception 'invalid_request_state';
  end if;
  return true;
end;
$function$;

create or replace function public.service_complete_account_deletion(
  p_request_id uuid,
  p_subject_user_id uuid,
  p_worker_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update public.account_deletion_requests request
  set
    status = 'completed',
    completed_at = coalesce(completed_at, now()),
    processed_at = coalesce(processed_at, now()),
    user_id = null,
    subject_user_id_snapshot = null,
    locked_at = null,
    locked_by = null,
    processing_started_at = null,
    last_error_code = null,
    updated_at = now()
  where request.id = p_request_id
    and request.status = 'processing'
    and request.storage_deleted_at is not null
    and request.data_finalized_at is not null
    and request.auth_deleted_at is not null
    and request.locked_by = nullif(btrim(p_worker_id), '')
    and request.locked_at is not null
    and request.subject_user_id_snapshot = p_subject_user_id
    and request.subject_hash = encode(
      extensions.digest(p_subject_user_id::text, 'sha256'),
      'hex'
    );

  if not found then
    raise exception 'invalid_request_state';
  end if;
  return true;
end;
$function$;

revoke all on function public.service_claim_account_deletion_requests(integer, text)
  from public, anon, authenticated;
revoke all on function public.service_list_account_deletion_storage_objects(uuid, uuid, text, integer)
  from public, anon, authenticated;
revoke all on function public.service_mark_account_deletion_storage_complete(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.service_finalize_account_deletion_data(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.service_record_account_deletion_failure(uuid, uuid, text, text, boolean)
  from public, anon, authenticated;
revoke all on function public.service_mark_account_deletion_auth_complete(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.service_complete_account_deletion(uuid, uuid, text)
  from public, anon, authenticated;

grant execute on function public.service_claim_account_deletion_requests(integer, text)
  to service_role;
grant execute on function public.service_list_account_deletion_storage_objects(uuid, uuid, text, integer)
  to service_role;
grant execute on function public.service_mark_account_deletion_storage_complete(uuid, uuid, text)
  to service_role;
grant execute on function public.service_finalize_account_deletion_data(uuid, uuid, text)
  to service_role;
grant execute on function public.service_record_account_deletion_failure(uuid, uuid, text, text, boolean)
  to service_role;
grant execute on function public.service_mark_account_deletion_auth_complete(uuid, uuid, text)
  to service_role;
grant execute on function public.service_complete_account_deletion(uuid, uuid, text)
  to service_role;
