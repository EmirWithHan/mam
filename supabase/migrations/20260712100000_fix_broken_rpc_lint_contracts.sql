create or replace function public.promote_waitlist_participant(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_waitlist_record record;
  v_capacity_total integer;
  v_confirmed_count integer;
  v_event public.events%rowtype;
  v_user_profile public.profiles%rowtype;
  v_candidate_bucket text;
  v_bucket_capacity integer;
  v_bucket_used integer;
begin
  perform pg_advisory_xact_lock(
    hashtextextended('business_waitlist_promotion:' || p_event_id::text, 0)
  );

  select * into v_event from public.events where id = p_event_id;
  if v_event.id is null then
    return;
  end if;

  v_capacity_total := v_event.capacity_total;
  select count(*)::integer into v_confirmed_count
  from public.event_participants participant
  where participant.event_id = p_event_id
    and participant.role = 'participant'
    and participant.attendance_status in (
      'planned', 'attended', 'confirmed', 'checked_in'
    );

  if v_capacity_total <= 0 or v_confirmed_count < v_capacity_total then
    for v_waitlist_record in
      select participant.*
      from public.event_participants participant
      where participant.event_id = p_event_id
        and participant.role = 'participant'
        and participant.attendance_status = 'waitlisted'
      order by participant.joined_at asc nulls last, participant.id asc
      for update skip locked
    loop
      select * into v_user_profile
      from public.profiles profile
      where profile.user_id = v_waitlist_record.user_id;

      v_candidate_bucket := null;
      v_bucket_capacity := null;
      v_bucket_used := 0;
      v_candidate_bucket := v_waitlist_record.capacity_bucket;
      if v_candidate_bucket is null then
        v_candidate_bucket := public.event_capacity_bucket_for(
          p_event_id,
          v_waitlist_record.user_id
        );
        if v_candidate_bucket is null then
          continue;
        end if;
      end if;

      v_bucket_capacity := case v_candidate_bucket
        when 'male' then greatest(coalesce(v_event.male_capacity, 0), 0)
        when 'female' then greatest(coalesce(v_event.female_capacity, 0), 0)
        when 'generic' then greatest(
          coalesce(v_event.generic_capacity, v_event.capacity_total, 0),
          0
        )
        else null
      end;
      if v_bucket_capacity is null then
        continue;
      end if;

      select count(*)::integer into v_bucket_used
      from public.event_participants participant
      where participant.event_id = p_event_id
        and participant.role = 'participant'
        and participant.attendance_status in (
          'planned', 'attended', 'confirmed', 'checked_in'
        )
        and coalesce(participant.capacity_bucket, 'generic') =
          v_candidate_bucket;
      if v_bucket_used >= v_bucket_capacity then
        continue;
      end if;

      if (v_event.min_age is null or
          extract(year from age(v_user_profile.birth_date)) >= v_event.min_age)
        and (not v_event.require_completed_profile or (
          v_user_profile.first_name is not null and
          v_user_profile.first_name <> '' and
          v_user_profile.birth_date is not null and
          v_user_profile.gender is not null
        ))
        and not exists (
          select 1
          from public.blocks block_record
          where (block_record.blocker_id = v_event.host_id and
                 block_record.blocked_id = v_waitlist_record.user_id)
             or (block_record.blocker_id = v_waitlist_record.user_id and
                 block_record.blocked_id = v_event.host_id)
        ) then
        update public.event_participants participant
        set attendance_status = 'confirmed',
          capacity_bucket = v_candidate_bucket
        where participant.event_id = p_event_id
          and participant.id = v_waitlist_record.id;

        update public.event_join_requests request
        set status = 'approved', updated_at = now()
        where request.event_id = p_event_id
          and request.user_id = v_waitlist_record.user_id;

        update public.events event
        set approved_count = (
          select count(*)::integer
          from public.event_participants participant
          where participant.event_id = p_event_id
            and participant.role = 'participant'
            and participant.attendance_status in (
              'planned', 'attended', 'confirmed', 'checked_in'
            )
        )
        where event.id = p_event_id;

        insert into public.notifications (
          recipient_id, actor_id, type, title, body,
          entity_type, entity_id, metadata, is_read
        ) values (
          v_waitlist_record.user_id,
          v_event.host_id,
          'event_join_approved',
          'Sıran geldi!',
          v_event.title || ' etkinliğinde bekleme listesinden ana listeye alındın.',
          'event',
          p_event_id,
          jsonb_build_object('event_id', p_event_id, 'attendance_status', 'confirmed'),
          false
        );
        exit;
      else
        continue;
      end if;
    end loop;
  end if;
end;
$function$;

revoke all on function public.promote_waitlist_participant(uuid)
  from public, anon, authenticated;
grant execute on function public.promote_waitlist_participant(uuid)
  to service_role;

create or replace function public.reconcile_event_visibility_change(
  p_event_id uuid,
  p_new_community_access text,
  p_execute_reconciliation boolean default false
)
returns json
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_community_id uuid;
  v_non_member_count integer := 0;
  v_non_members jsonb := '[]'::jsonb;
  v_rec record;
begin
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  select event.community_id into v_community_id
  from public.events event
  where event.id = p_event_id;
  if v_community_id is null then
    raise exception 'event_not_linked_to_community' using errcode = 'C0013';
  end if;
  if not public.has_community_permission(
    v_community_id, v_user_id, 'manage_members'
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_new_community_access is null
    or p_new_community_access not in ('public', 'members_only') then
    raise exception 'invalid_community_access' using errcode = '22023';
  end if;

  if p_new_community_access = 'public' then
    if not p_execute_reconciliation then
      return json_build_object(
        'non_member_count', 0,
        'non_members', '[]'::jsonb,
        'ready_to_switch', true
      );
    end if;

    update public.events event
    set community_access = 'public', updated_at = now()
    where event.id = p_event_id;

    return json_build_object(
      'non_member_count', 0,
      'reconciled', true,
      'ready_to_switch', true
    );
  end if;

  for v_rec in
    select participant.user_id, profile.first_name, profile.username
    from public.event_participants participant
    left join public.profiles profile on profile.user_id = participant.user_id
    where participant.event_id = p_event_id
      and participant.role = 'participant'
      and participant.attendance_status in (
        'confirmed', 'waitlisted', 'planned', 'pending_confirmation'
      )
      and not exists (
        select 1
        from public.community_memberships membership
        where membership.community_id = v_community_id
          and membership.user_id = participant.user_id
          and membership.status = 'active'
      )
  loop
    v_non_member_count := v_non_member_count + 1;
    v_non_members := v_non_members || jsonb_build_object(
      'user_id', v_rec.user_id,
      'first_name', v_rec.first_name,
      'username', v_rec.username
    );
  end loop;

  if not p_execute_reconciliation then
    return json_build_object(
      'non_member_count', v_non_member_count,
      'non_members', v_non_members,
      'ready_to_switch', v_non_member_count = 0
    );
  end if;

  update public.event_join_requests request
  set status = 'cancelled', updated_at = now()
  where request.event_id = p_event_id
    and request.status = 'pending'
    and request.user_id in (
      select (member.value->>'user_id')::uuid
      from jsonb_array_elements(v_non_members) member(value)
    );

  update public.event_participants participant
  set attendance_status = 'cancelled'
  where participant.event_id = p_event_id
    and participant.attendance_status in (
      'confirmed', 'waitlisted', 'planned', 'pending_confirmation'
    )
    and participant.user_id in (
      select (member.value->>'user_id')::uuid
      from jsonb_array_elements(v_non_members) member(value)
    );

  update public.events event
  set approved_count = (
    select count(*)
    from public.event_participants participant
    where participant.event_id = p_event_id
      and participant.role = 'participant'
      and participant.attendance_status in (
        'confirmed', 'checked_in', 'planned', 'attended'
      )
  )
  where event.id = p_event_id;

  update public.events event
  set community_access = p_new_community_access, updated_at = now()
  where event.id = p_event_id;

  return json_build_object(
    'non_member_count', v_non_member_count,
    'reconciled', true,
    'ready_to_switch', true
  );
end;
$function$;

revoke all on function public.reconcile_event_visibility_change(uuid, text, boolean)
  from public, anon, authenticated;
grant execute on function public.reconcile_event_visibility_change(uuid, text, boolean)
  to authenticated;

create or replace function public.process_event_reminders()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reminder record;
  v_event public.events%rowtype;
  v_notification_id uuid;
  v_body text;
  v_title text;
begin
  perform pg_advisory_xact_lock(
    hashtextextended('process_scheduled_reminders_lock', 0)
  );

  for v_reminder in
    select schedule.*
    from public.event_reminders_schedule schedule
    where schedule.status = 'pending'
      and schedule.scheduled_for <= now()
    for update skip locked
  loop
    select * into v_event
    from public.events event
    where event.id = v_reminder.event_id;

    if v_event.id is not null
      and v_event.status = 'active'
      and v_event.moderation_status = 'approved'
      and exists (
        select 1
        from public.event_participants participant
        where participant.event_id = v_reminder.event_id
          and participant.user_id = v_reminder.user_id
          and participant.attendance_status in (
            'confirmed', 'planned', 'checked_in'
          )
      ) then
      if v_reminder.reminder_type = '24h' then
        v_title := 'Etkinlik Yarın!';
        v_body := v_event.title || ' etkinliğine son 24 saat. Hazır mısın?';
      else
        v_title := 'Etkinlik Yaklaşıyor!';
        v_body := v_event.title || ' etkinliğine son 1 saat. Hazırlanmaya başla!';
      end if;

      insert into public.notifications (
        recipient_id, actor_id, type, title, body,
        entity_type, entity_id, metadata, is_read
      ) values (
        v_reminder.user_id,
        v_event.host_id,
        'system',
        v_title,
        v_body,
        'event',
        v_reminder.event_id,
        jsonb_build_object(
          'event_id', v_reminder.event_id,
          'reminder_type', v_reminder.reminder_type
        ),
        false
      ) returning id into v_notification_id;

      insert into public.push_notification_outbox (
        notification_id, recipient_id, type, title, body,
        entity_type, entity_id, metadata
      ) values (
        v_notification_id,
        v_reminder.user_id,
        'event_reminder',
        v_title,
        v_body,
        'event',
        v_reminder.event_id::text,
        jsonb_build_object(
          'event_id', v_reminder.event_id,
          'reminder_type', v_reminder.reminder_type
        )
      ) on conflict do nothing;
    end if;

    update public.event_reminders_schedule schedule
    set status = 'sent', updated_at = now()
    where schedule.id = v_reminder.id;
  end loop;
end;
$function$;

revoke all on function public.process_event_reminders()
  from public, anon, authenticated;
grant execute on function public.process_event_reminders()
  to service_role;

create or replace function public.get_business_plus_analytics(
  p_business_account_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_total_events integer := 0;
  v_upcoming_events integer := 0;
  v_past_events integer := 0;
  v_total_participants integer := 0;
  v_total_checked_in integer := 0;
  v_attendance_rate numeric := 0;
  v_pending_join_requests integer := 0;
  v_approved_join_requests integer := 0;
  v_rejected_join_requests integer := 0;
  v_monthly_boosts_used integer := 0;
  v_monthly_boosts_remaining integer := 5;
  v_active_boosts integer := 0;
  v_expired_boosts integer := 0;
  v_top_events jsonb := '[]'::jsonb;
  v_recent_events jsonb := '[]'::jsonb;
  v_local_now timestamp := timezone('Europe/Istanbul', now());
  v_period_start timestamptz;
  v_period_end timestamptz;
begin
  if v_user_id is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.business_accounts business
    where business.id = p_business_account_id
      and business.owner_user_id = v_user_id and business.status = 'active'
  ) and not exists (
    select 1 from public.business_members member_record
    where member_record.business_id = p_business_account_id
      and member_record.user_id = v_user_id
      and member_record.role in ('owner', 'admin', 'staff')
  ) then raise exception 'not_authorized'; end if;
  if not public.check_business_plus_active(p_business_account_id) then
    raise exception 'business_plus_required';
  end if;

  select count(*)::integer,
    count(*) filter (where event.event_date >= now())::integer,
    count(*) filter (where event.event_date < now())::integer
  into v_total_events, v_upcoming_events, v_past_events
  from public.events event
  where event.organizer_business_id = p_business_account_id
    and event.status = 'active';

  select
    count(*) filter (where participant.role = 'participant' and
      participant.attendance_status in ('confirmed', 'checked_in'))::integer,
    count(*) filter (where participant.role = 'participant' and
      participant.attendance_status = 'checked_in')::integer
  into v_total_participants, v_total_checked_in
  from public.event_participants participant
  join public.events event on event.id = participant.event_id
  where event.organizer_business_id = p_business_account_id
    and event.status = 'active';
  if v_total_participants > 0 then
    v_attendance_rate := round(
      (v_total_checked_in * 100.0) / v_total_participants, 1
    );
  end if;

  select
    count(*) filter (where request.status = 'pending')::integer,
    count(*) filter (where request.status = 'approved')::integer,
    count(*) filter (where request.status = 'rejected')::integer
  into v_pending_join_requests, v_approved_join_requests,
    v_rejected_join_requests
  from public.event_join_requests request
  join public.events event on event.id = request.event_id
  where event.organizer_business_id = p_business_account_id
    and event.status = 'active';

  v_period_start := date_trunc('month', v_local_now)
    at time zone 'Europe/Istanbul';
  v_period_end := (date_trunc('month', v_local_now) + interval '1 month')
    at time zone 'Europe/Istanbul';
  select count(*)::integer into v_monthly_boosts_used
  from public.business_event_boosts boost
  where boost.business_account_id = p_business_account_id
    and boost.boosted_at >= v_period_start
    and boost.boosted_at < v_period_end;
  v_monthly_boosts_remaining := greatest(0, 5 - v_monthly_boosts_used);
  select
    count(*) filter (where boost.expires_at >= now())::integer,
    count(*) filter (where boost.expires_at < now())::integer
  into v_active_boosts, v_expired_boosts
  from public.business_event_boosts boost
  where boost.business_account_id = p_business_account_id;

  select coalesce(jsonb_agg(to_jsonb(top_event)), '[]'::jsonb)
  into v_top_events
  from (
    select event.id, event.title, event.event_date,
      count(participant.id) filter (where participant.role = 'participant' and
        participant.attendance_status in ('confirmed', 'checked_in'))::integer
        as participant_count,
      count(participant.id) filter (where participant.role = 'participant' and
        participant.attendance_status = 'checked_in')::integer as check_in_count
    from public.events event
    left join public.event_participants participant
      on participant.event_id = event.id
    where event.organizer_business_id = p_business_account_id
      and event.status = 'active'
    group by event.id, event.title, event.event_date
    order by participant_count desc, event.event_date desc
    limit 5
  ) top_event;

  select coalesce(jsonb_agg(to_jsonb(recent_event)), '[]'::jsonb)
  into v_recent_events
  from (
    select event.id, event.title, event.event_date,
      count(participant.id) filter (where participant.role = 'participant' and
        participant.attendance_status in ('confirmed', 'checked_in'))::integer
        as participant_count,
      count(participant.id) filter (where participant.role = 'participant' and
        participant.attendance_status = 'checked_in')::integer as check_in_count,
      count(participant.id) filter (where participant.role = 'participant' and
        participant.attendance_status = 'no_show')::integer as no_show_count,
      (select count(*)::integer from public.event_join_requests request
       where request.event_id = event.id) as join_requests_count
    from public.events event
    left join public.event_participants participant
      on participant.event_id = event.id
    where event.organizer_business_id = p_business_account_id
      and event.status = 'active' and event.event_date < now()
    group by event.id, event.title, event.event_date
    order by event.event_date desc
    limit 5
  ) recent_event;

  return jsonb_build_object(
    'total_events', v_total_events,
    'upcoming_events', v_upcoming_events,
    'past_events', v_past_events,
    'total_participants', v_total_participants,
    'total_checked_in', v_total_checked_in,
    'attendance_rate', v_attendance_rate,
    'pending_join_requests', v_pending_join_requests,
    'approved_join_requests', v_approved_join_requests,
    'rejected_join_requests', v_rejected_join_requests,
    'monthly_boosts_used', v_monthly_boosts_used,
    'monthly_boosts_remaining', v_monthly_boosts_remaining,
    'active_boosts', v_active_boosts,
    'expired_boosts', v_expired_boosts,
    'top_events', v_top_events,
    'recent_events', v_recent_events
  );
end;
$function$;

revoke all on function public.get_business_plus_analytics(uuid)
  from public, anon, authenticated;
grant execute on function public.get_business_plus_analytics(uuid)
  to authenticated;

create or replace function public.log_verification_failure(
  p_business_account_id uuid,
  p_store text,
  p_environment text,
  p_category text,
  p_identity_hash text,
  p_diagnostic_msg text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_fingerprint text;
  v_diagnostic_hash text;
  v_issue_id uuid;
  v_resolved boolean;
  v_retry_count integer;
  v_alert_msg text;
begin
  v_fingerprint := encode(extensions.digest(
    p_category || ':' || p_store || ':' || p_environment || ':' ||
    coalesce(p_business_account_id::text, 'null') || ':' ||
    coalesce(p_identity_hash, 'null'),
    'sha256'
  ), 'hex');
  v_diagnostic_hash := encode(extensions.digest(
    coalesce(p_diagnostic_msg, ''),
    'sha256'
  ), 'hex');

  select issue.id, issue.resolved, issue.retry_count
  into v_issue_id, v_resolved, v_retry_count
  from public.business_plus_verification_issues issue
  where issue.issue_fingerprint = v_fingerprint;
  if found then
    if v_resolved then
      update public.business_plus_verification_issues issue
      set resolved = false, resolved_at = null, resolved_by = null,
        retry_count = 1,
        diagnostic_metadata = jsonb_build_object(
          'diagnostic_hash', v_diagnostic_hash
        ),
        last_seen = now(), updated_at = now()
      where issue.id = v_issue_id;
    else
      update public.business_plus_verification_issues issue
      set retry_count = issue.retry_count + 1,
        diagnostic_metadata = jsonb_build_object(
          'diagnostic_hash', v_diagnostic_hash
        ),
        last_seen = now(), updated_at = now()
      where issue.id = v_issue_id;
    end if;
  else
    insert into public.business_plus_verification_issues (
      business_account_id, store, environment, category, issue_fingerprint,
      diagnostic_metadata, first_seen, last_seen
    ) values (
      p_business_account_id, p_store, p_environment, p_category, v_fingerprint,
      jsonb_build_object('diagnostic_hash', v_diagnostic_hash), now(), now()
    ) returning id into v_issue_id;
  end if;

  if coalesce(v_retry_count, 0) + 1 >= 3 then
    v_alert_msg := 'repeated_verification_failures: Business ' ||
      coalesce(p_business_account_id::text, 'unknown') ||
      ' failed verification ' || (coalesce(v_retry_count, 0) + 1) || ' times.';
    insert into public.admin_billing_alerts (alert_type, message, metadata)
    values (
      'repeated_verification_failures', v_alert_msg,
      jsonb_build_object('business_account_id', p_business_account_id)
    )
    on conflict (alert_type) do update
    set message = excluded.message, metadata = excluded.metadata,
      last_triggered_at = now(), resolved = false;
  end if;
  return v_issue_id;
end;
$function$;

revoke all on function public.log_verification_failure(uuid, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.log_verification_failure(uuid, text, text, text, text, text)
  to service_role;

create or replace function public.admin_inspect_entitlement_decision(
  p_business_account_id uuid
)
returns table (
  has_active_store_subscription boolean,
  has_active_manual_entitlement boolean,
  current_period_end_valid boolean,
  grace_period_valid boolean,
  revocation_time timestamptz,
  environment text,
  product_id text,
  owner_id uuid,
  stale_cache_status boolean,
  latest_reconciliation_result text,
  outcome_code text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_store_active boolean := false;
  v_manual_active boolean := false;
  v_period_valid boolean := false;
  v_grace_valid boolean := false;
  v_revocation timestamptz := null;
  v_env text := null;
  v_prod text := null;
  v_owner uuid := null;
  v_stale boolean := false;
  v_outcome text := 'no_valid_entitlement';
  v_cached_active boolean := false;
  v_calculated_active boolean := false;
  v_effective_active_store boolean := false;
  v_effective_cancelled_store boolean := false;
  v_representative_status text := null;
begin
  if not public.is_current_user_admin() then
    raise exception 'unauthorized_admin_only';
  end if;

  select exists (
    select 1 from public.business_plus_subscriptions subscription
    where subscription.business_account_id = p_business_account_id
      and subscription.store in ('google_play', 'app_store')
      and subscription.entitlement_status = 'active'
      and subscription.starts_at <= now()
      and subscription.ends_at is not null
      and subscription.ends_at > now()
      and subscription.revocation_time is null
  ) into v_effective_active_store;
  select exists (
    select 1 from public.business_plus_subscriptions subscription
    where subscription.business_account_id = p_business_account_id
      and subscription.store in ('google_play', 'app_store')
      and subscription.entitlement_status = 'cancelled'
      and subscription.starts_at <= now()
      and subscription.ends_at is not null
      and subscription.ends_at > now()
      and subscription.revocation_time is null
  ) into v_effective_cancelled_store;
  v_store_active := v_effective_active_store or v_effective_cancelled_store;
  select exists (
    select 1 from public.business_plus_subscriptions subscription
    where subscription.business_account_id = p_business_account_id
      and subscription.store in ('google_play', 'app_store')
      and subscription.entitlement_status in ('active', 'cancelled', 'grace_period')
      and subscription.starts_at <= now()
      and subscription.ends_at is not null
      and subscription.ends_at > now()
      and subscription.revocation_time is null
  ) into v_period_valid;
  select exists (
    select 1 from public.business_plus_subscriptions subscription
    where subscription.business_account_id = p_business_account_id
      and subscription.store = 'manual_admin'
      and subscription.entitlement_status in ('active', 'grace_period')
      and subscription.starts_at <= now()
      and (subscription.ends_at is null or subscription.ends_at > now())
      and subscription.revocation_time is null
  ) into v_manual_active;
  select exists (
    select 1 from public.business_plus_subscriptions subscription
    where subscription.business_account_id = p_business_account_id
      and subscription.store in ('google_play', 'app_store')
      and subscription.entitlement_status = 'grace_period'
      and subscription.starts_at <= now()
      and subscription.ends_at is not null
      and subscription.ends_at > now()
      and subscription.revocation_time is null
  ) into v_grace_valid;

  select subscription.revocation_time, subscription.environment,
    subscription.product_id, subscription.owner_user_id,
    subscription.entitlement_status
  into v_revocation, v_env, v_prod, v_owner, v_representative_status
  from public.business_plus_subscriptions subscription
  where subscription.business_account_id = p_business_account_id
  order by case
    when subscription.store in ('google_play', 'app_store')
      and subscription.entitlement_status = 'active'
      and subscription.starts_at <= now()
      and subscription.ends_at is not null
      and subscription.ends_at > now()
      and subscription.revocation_time is null then 1
    when subscription.store in ('google_play', 'app_store')
      and subscription.entitlement_status = 'cancelled'
      and subscription.starts_at <= now()
      and subscription.ends_at is not null
      and subscription.ends_at > now()
      and subscription.revocation_time is null then 2
    when subscription.store in ('google_play', 'app_store')
      and subscription.entitlement_status = 'grace_period'
      and subscription.starts_at <= now()
      and subscription.ends_at is not null
      and subscription.ends_at > now()
      and subscription.revocation_time is null then 3
    when subscription.store = 'manual_admin'
      and subscription.entitlement_status in ('active', 'grace_period')
      and subscription.starts_at <= now()
      and (subscription.ends_at is null or subscription.ends_at > now())
      and subscription.revocation_time is null then 4
    else 5
  end,
  subscription.created_at desc,
  subscription.id desc
  limit 1;
  select business.is_plus_active into v_cached_active
  from public.business_accounts business
  where business.id = p_business_account_id;

  v_calculated_active := public.check_business_plus_active(p_business_account_id);
  v_stale := v_cached_active <> v_calculated_active;
  if v_effective_active_store then
    v_outcome := 'active_store_subscription';
  elsif v_effective_cancelled_store then
    v_outcome := 'cancelled_but_period_active';
  elsif v_grace_valid then
    v_outcome := 'grace_period_active';
  elsif v_manual_active then
    v_outcome := 'active_manual_entitlement';
  elsif v_revocation is not null or v_representative_status = 'revoked' then
    v_outcome := 'revoked';
  elsif v_representative_status = 'expired' then
    v_outcome := 'expired';
  end if;

  return query select
    v_store_active, v_manual_active, v_period_valid, v_grace_valid,
    v_revocation, coalesce(v_env, 'none'), coalesce(v_prod, 'none'),
    coalesce(v_owner, '00000000-0000-0000-0000-000000000000'::uuid),
    v_stale, 'Reconciled successfully'::text, v_outcome;
end;
$function$;

revoke all on function public.admin_inspect_entitlement_decision(uuid)
  from public, anon, authenticated;
grant execute on function public.admin_inspect_entitlement_decision(uuid)
  to authenticated;

create or replace function public.create_recurring_event_series(
  p_business_account_id uuid,
  p_pattern_type text,
  p_pattern_metadata jsonb,
  p_event_data jsonb,
  p_dates timestamptz[],
  p_creation_request_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_series_id uuid;
  v_date timestamptz;
  v_user_id uuid := auth.uid();
  v_idx integer;
  v_req_id uuid;
  v_existing_series_id uuid;
  v_event_id uuid;
begin
  if v_user_id is null then raise exception 'not_authenticated'; end if;
  if not public.check_business_plus_active(p_business_account_id) then
    raise exception 'business_plus_required';
  end if;
  if not exists (
    select 1 from public.business_accounts business
    where business.id = p_business_account_id
      and business.owner_user_id = v_user_id and business.status = 'active'
  ) then raise exception 'not_authorized'; end if;

  perform pg_advisory_xact_lock(
    hashtextextended('business_quota_lock:' || p_business_account_id::text, 0)
  );
  if p_creation_request_ids is not null
    and array_length(p_creation_request_ids, 1) > 0 then
    select event.series_id into v_existing_series_id
    from public.events event
    where event.host_id = v_user_id
      and event.creation_request_id = p_creation_request_ids[1]
    limit 1;
    if v_existing_series_id is not null then return v_existing_series_id; end if;
  end if;
  if coalesce(cardinality(p_dates), 0) = 0 then
    raise exception 'empty_dates';
  end if;
  if cardinality(p_dates) > 50 then
    raise exception 'max_occurrences_exceeded';
  end if;
  foreach v_date in array p_dates loop
    if v_date > now() + interval '180 days' then raise exception 'horizon_exceeded'; end if;
    if v_date < now() then raise exception 'past_date_not_allowed'; end if;
  end loop;

  insert into public.event_recurring_series (
    business_account_id, pattern_type, pattern_metadata
  ) values (p_business_account_id, p_pattern_type, p_pattern_metadata)
  returning id into v_series_id;

  for v_idx in 1..cardinality(p_dates) loop
    v_date := p_dates[v_idx];
    v_req_id := case when p_creation_request_ids is not null and
      array_length(p_creation_request_ids, 1) >= v_idx
      then p_creation_request_ids[v_idx] else null end;
    insert into public.events (
      host_id, organizer_type, organizer_user_id, organizer_business_id,
      title, description, sport_type, city, district, location_text,
      location_description, location_lat, location_lng, event_date,
      capacity_total, generic_capacity, male_capacity, female_capacity,
      status, is_paid, price_amount, price_currency, listing_expires_at,
      event_start_time, event_end_time, price_type,
      series_id, creation_request_id
    ) values (
      v_user_id, 'business', v_user_id, p_business_account_id,
      btrim(p_event_data->>'title'), nullif(btrim(p_event_data->>'description'), ''),
      btrim(p_event_data->>'sport_type'), btrim(p_event_data->>'city'),
      nullif(btrim(p_event_data->>'district'), ''),
      nullif(btrim(p_event_data->>'location_text'), ''),
      nullif(btrim(p_event_data->>'location_description'), ''),
      (p_event_data->>'location_lat')::double precision,
      (p_event_data->>'location_lng')::double precision,
      v_date, (p_event_data->>'capacity_total')::integer,
      (p_event_data->>'generic_capacity')::integer,
      (p_event_data->>'male_capacity')::integer,
      (p_event_data->>'female_capacity')::integer,
      'active', coalesce((p_event_data->>'is_paid')::boolean, false),
      (p_event_data->>'price_amount')::numeric, 'TRY',
      now() + interval '24 hours',
      (p_event_data->>'event_start_time')::time,
      (p_event_data->>'event_end_time')::time,
      coalesce(nullif(btrim(p_event_data->>'price_type'), ''),
        case when coalesce((p_event_data->>'is_paid')::boolean, false)
          then 'pay_at_business' else 'free' end),
      v_series_id, v_req_id
    ) returning id into v_event_id;

    insert into public.event_participants (
      event_id, user_id, role, attendance_status
    ) select
      v_event_id, v_user_id, 'host', 'planned'
    where not exists (
      select 1 from public.event_participants participant
      where participant.event_id = v_event_id
        and participant.user_id = v_user_id
    ) on conflict do nothing;
  end loop;
  return v_series_id;
end;
$function$;

revoke all on function public.create_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[])
  from public, anon, authenticated;
grant execute on function public.create_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[])
  to authenticated;

create or replace function public.create_community_recurring_event_series(
  p_community_id uuid,
  p_pattern_type text,
  p_pattern_metadata jsonb,
  p_event_data jsonb,
  p_dates timestamptz[],
  p_creation_request_ids uuid[],
  p_community_access text default 'public'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_series_id uuid;
  v_date timestamptz;
  v_user_id uuid := auth.uid();
  v_idx integer;
  v_req_id uuid;
  v_existing_series_id uuid;
  v_event_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not public.has_community_permission(
    p_community_id, v_user_id, 'manage_members'
  ) then
    raise exception 'community_event_creation_permission_required'
      using errcode = 'C0005';
  end if;
  if p_creation_request_ids is not null
    and array_length(p_creation_request_ids, 1) > 0 then
    select event.series_id into v_existing_series_id
    from public.events event
    where event.host_id = v_user_id
      and event.creation_request_id = p_creation_request_ids[1]
    limit 1;
    if v_existing_series_id is not null then return v_existing_series_id; end if;
  end if;
  if coalesce(cardinality(p_dates), 0) = 0 then
    raise exception 'empty_dates' using errcode = 'C0009';
  end if;
  if cardinality(p_dates) > 30 then
    raise exception 'max_occurrences_exceeded' using errcode = 'C0010';
  end if;
  foreach v_date in array p_dates loop
    if v_date > now() + interval '180 days' then
      raise exception 'horizon_exceeded' using errcode = 'C0011';
    end if;
    if v_date < now() then
      raise exception 'past_date_not_allowed' using errcode = 'C0012';
    end if;
  end loop;

  insert into public.event_recurring_series (
    community_id, pattern_type, pattern_metadata
  ) values (p_community_id, p_pattern_type, p_pattern_metadata)
  returning id into v_series_id;

  for v_idx in 1..cardinality(p_dates) loop
    v_date := p_dates[v_idx];
    v_req_id := case when p_creation_request_ids is not null and
      array_length(p_creation_request_ids, 1) >= v_idx
      then p_creation_request_ids[v_idx] else null end;
    insert into public.events (
      host_id, organizer_type, organizer_user_id,
      title, description, sport_type, city, district, location_text,
      location_description, location_lat, location_lng, event_date,
      capacity_total, generic_capacity, male_capacity, female_capacity,
      status, is_paid, series_id, creation_request_id,
      community_id, community_access
    ) values (
      v_user_id, 'user', v_user_id,
      btrim(p_event_data->>'title'), nullif(btrim(p_event_data->>'description'), ''),
      btrim(p_event_data->>'sport_type'), btrim(p_event_data->>'city'),
      nullif(btrim(p_event_data->>'district'), ''),
      nullif(btrim(p_event_data->>'location_text'), ''),
      nullif(btrim(p_event_data->>'location_description'), ''),
      (p_event_data->>'location_lat')::double precision,
      (p_event_data->>'location_lng')::double precision,
      v_date, (p_event_data->>'capacity_total')::integer,
      (p_event_data->>'generic_capacity')::integer,
      (p_event_data->>'male_capacity')::integer,
      (p_event_data->>'female_capacity')::integer,
      'active', false, v_series_id, v_req_id,
      p_community_id, p_community_access
    ) returning id into v_event_id;

    insert into public.event_participants (
      event_id, user_id, role, attendance_status
    ) select
      v_event_id, v_user_id, 'host', 'planned'
    where not exists (
      select 1 from public.event_participants participant
      where participant.event_id = v_event_id
        and participant.user_id = v_user_id
    ) on conflict do nothing;
  end loop;
  return v_series_id;
end;
$function$;

revoke all on function public.create_community_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[], text)
  from public, anon, authenticated;
grant execute on function public.create_community_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[], text)
  to authenticated;
