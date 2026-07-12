-- 20260712105000_supabase_security_hardening.sql
-- Security hardening: Add fixed search_path to public security definer functions, qualify references, and restrict execute permissions.

-- 1. normalize_sport_type
create or replace function public.normalize_sport_type(p_val text)
 returns text
 language sql
 immutable security definer
 set search_path = ''
as $function$
  select pg_catalog.lower(pg_catalog.translate(p_val, 'çğıöşüÇĞİÖŞÜ', 'cgiosucgiosu'));
$function$;

revoke all on function public.normalize_sport_type(text) from public, anon;
grant execute on function public.normalize_sport_type(text) to authenticated, service_role;


-- 2. ensure_check_in_token_exists
create or replace function public.ensure_check_in_token_exists()
 returns trigger
 language plpgsql
 security definer
 set search_path = ''
as $function$
begin
  if NEW.role = 'participant' 
     and NEW.attendance_status in ('planned', 'confirmed', 'attended', 'checked_in', 'approved', 'pending_confirmation')
     and NEW.check_in_token is null then
    NEW.check_in_token := extensions.gen_random_uuid()::text;
  end if;
  return NEW;
end;
$function$;

revoke all on function public.ensure_check_in_token_exists() from public, anon, authenticated;


-- 3. cron_reconcile_subscriptions
create or replace function public.cron_reconcile_subscriptions(
  p_project_ref text,
  p_secret text,
  p_limit integer default 50,
  p_offset integer default 0
)
 returns void
 language plpgsql
 security definer
 set search_path = ''
as $function$
begin
  perform net.http_post(
    url := 'https://' || p_project_ref || '.supabase.co/functions/v1/reconcile-business-plus-subscription',
    headers := pg_catalog.jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || p_secret
    ),
    body := pg_catalog.jsonb_build_object(
      'limit', p_limit,
      'offset', p_offset
    )
  );
end;
$function$;

revoke all on function public.cron_reconcile_subscriptions(text, text, integer, integer) from public, anon, authenticated;
grant execute on function public.cron_reconcile_subscriptions(text, text, integer, integer) to service_role;


-- 4. submit_business_review
create or replace function public.submit_business_review(
  p_event_id uuid,
  p_business_id uuid,
  p_rating integer,
  p_comment text
)
 returns void
 language plpgsql
 security definer
 set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_comment text := pg_catalog.nullif(pg_catalog.btrim(pg_catalog.coalesce(p_comment, '')), '');
  v_event public.events%rowtype;
  v_event_end timestamptz;
  v_event_start timestamptz;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_rating < 1 or p_rating > 5 then
    raise exception 'invalid_rating';
  end if;

  if v_comment is not null then
    v_comment := pg_catalog.regexp_replace(v_comment, '\s+', ' ', 'g');
    if pg_catalog.length(v_comment) > 300 then
      raise exception 'comment_too_long';
    end if;
  end if;

  select *
  into v_event
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'event_not_found';
  end if;

  if pg_catalog.coalesce(v_event.organizer_type, 'user') <> 'business' or v_event.organizer_business_id <> p_business_id then
    raise exception 'not_business_event';
  end if;

  if exists (
    select 1
    from public.business_accounts business
    where business.id = p_business_id
      and business.owner_user_id = v_user_id
  ) then
    raise exception 'cannot_rate_own_business';
  end if;

  if not exists (
    select 1
    from public.event_participants participant
    where participant.event_id = p_event_id
      and participant.user_id = v_user_id
      and participant.role = 'participant'
      and participant.attendance_status in ('checked_in', 'confirmed')
  ) then
    raise exception 'event_not_attended';
  end if;

  -- Timing check: Enforce that review can only be submitted after the event has ended
  if v_event.event_end_time is not null then
    v_event_start := pg_catalog.coalesce(
      case when v_event.event_start_time is not null then
        pg_catalog.timezone('UTC', v_event.event_date::date + v_event.event_start_time)
      else v_event.event_date end,
      v_event.event_date
    );
    v_event_end := pg_catalog.timezone('UTC', v_event.event_date::date + v_event.event_end_time);
    if v_event_end <= v_event_start then
      v_event_end := v_event_end + interval '1 day';
    end if;
  else
    v_event_end := v_event.event_date + interval '2 hours';
  end if;

  if pg_catalog.now() < v_event_end then
    raise exception 'event_not_ended';
  end if;

  insert into public.business_reviews (
    business_id,
    event_id,
    user_id,
    rating,
    comment
  )
  values (
    p_business_id,
    p_event_id,
    v_user_id,
    p_rating,
    v_comment
  );
end;
$function$;

revoke all on function public.submit_business_review(uuid, uuid, integer, text) from public, anon;
grant execute on function public.submit_business_review(uuid, uuid, integer, text) to authenticated;


-- 5. get_admin_dashboard
create or replace function public.get_admin_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_total_users integer := 0;
  v_total_events integer := 0;
  v_pending_business_apps integer := 0;
  v_pending_reports_count integer := 0;
  v_pending_message_reports_count integer := 0;
  v_recent_events jsonb := '[]'::jsonb;
  v_pending_business_apps_list jsonb := '[]'::jsonb;
  v_recent_moderation_actions jsonb := '[]'::jsonb;
  v_recent_reports jsonb := '[]'::jsonb;
  v_recent_message_reports jsonb := '[]'::jsonb;
begin
  if v_admin_id is null or not public.is_current_user_admin() then
    raise exception 'not_admin';
  end if;

  -- 1. General counts
  select count(*)::integer into v_total_users from public.profiles;
  select count(*)::integer into v_total_events from public.events;
  select count(*)::integer into v_pending_business_apps
  from public.business_applications
  where status = 'pending';
  
  select count(*)::integer into v_pending_reports_count
  from public.reports
  where status = 'open';

  select count(*)::integer into v_pending_message_reports_count
  from public.message_reports
  where status = 'pending';

  -- 2. Recent events list (limit 15)
  select pg_catalog.coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(rec_evs)), '[]'::jsonb) into v_recent_events
  from (
    select
      e.id,
      e.title,
      e.host_id,
      e.organizer_business_id,
      e.event_date,
      e.moderation_status,
      e.created_at,
      pg_catalog.count(ep.id) filter (where ep.role = 'participant' and ep.attendance_status in ('confirmed', 'checked_in'))::integer as participant_count
    from public.events e
    left join public.event_participants ep on ep.event_id = e.id
    group by e.id, e.title, e.host_id, e.organizer_business_id, e.event_date, e.moderation_status, e.created_at
    order by e.created_at desc
    limit 15
  ) rec_evs;

  -- 3. Pending business applications list (limit 15)
  select pg_catalog.coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(pend_apps)), '[]'::jsonb) into v_pending_business_apps_list
  from (
    select
      ba.id,
      ba.user_id,
      ba.business_name,
      ba.category,
      ba.full_address,
      ba.business_phone,
      ba.website,
      ba.description,
      ba.status,
      ba.created_at
    from public.business_applications ba
    where ba.status = 'pending'
    order by ba.created_at desc
    limit 15
  ) pend_apps;

  -- 4. Recent moderation actions list (limit 15)
  select pg_catalog.coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(mod_acts)), '[]'::jsonb) into v_recent_moderation_actions
  from (
    select
      ma.id,
      ma.admin_user_id,
      ma.action,
      ma.target_type,
      ma.target_id,
      ma.reason,
      ma.created_at
    from public.admin_moderation_actions ma
    order by ma.created_at desc
    limit 15
  ) mod_acts;

  -- 5. Recent reports list with enriched human-readable fields (limit 15)
  select pg_catalog.coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(recs)), '[]'::jsonb) into v_recent_reports
  from (
    select
      r.id,
      r.reporter_id,
      r.target_type,
      r.target_id,
      r.reason,
      r.description,
      r.status,
      r.created_at,
      -- Reporter Name
      (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.profiles p where p.user_id = r.reporter_id) as reporter_name,
      -- Target Name (e.g. reported user's name or event title)
      case 
        when r.target_type = 'user' then (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.profiles p where p.user_id = r.target_id)
        when r.target_type = 'event' then (select title from public.events where id = r.target_id)
        when r.target_type = 'post' then (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.posts post join public.profiles p on p.user_id = post.user_id where post.id = r.target_id)
        when r.target_type = 'comment' or r.target_type = 'post_comment' then (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.post_comments c join public.profiles p on p.user_id = c.user_id where c.id = r.target_id)
        else null
      end as target_name,
      -- Target Content Preview
      case 
        when r.target_type = 'post' then (select caption from public.posts where id = r.target_id)
        when r.target_type = 'comment' or r.target_type = 'post_comment' then (select comment from public.post_comments where id = r.target_id)
        else null
      end as target_content,
      -- Event fields
      case
        when r.target_type = 'event' then (select title from public.events where id = r.target_id)
        else null
      end as target_title,
      case
        when r.target_type = 'event' then (select description from public.events where id = r.target_id)
        else null
      end as target_description,
      case
        when r.target_type = 'event' then (select event_date::text from public.events where id = r.target_id)
        else null
      end as target_date,
      case
        when r.target_type = 'event' then (select event_start_time::text from public.events where id = r.target_id)
        else null
      end as target_start_time,
      case
        when r.target_type = 'event' then (select location_text from public.events where id = r.target_id)
        else null
      end as target_location,
      case
        when r.target_type = 'event' then (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.events e join public.profiles p on p.user_id = e.host_id where e.id = r.target_id)
        else null
      end as target_host_name,
      -- Post/Comment fields
      case
        when r.target_type = 'post' then (select image_url from public.posts where id = r.target_id)
        else null
      end as target_image_url,
      case
        when r.target_type = 'post' then (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.posts post join public.profiles p on p.user_id = post.user_id where post.id = r.target_id)
        when r.target_type = 'comment' or r.target_type = 'post_comment' then (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.post_comments c join public.profiles p on p.user_id = c.user_id where c.id = r.target_id)
        else null
      end as target_author_name,
      case
        when r.target_type = 'comment' or r.target_type = 'post_comment' then (select pg_catalog.coalesce(pg_catalog.substring(caption, 1, 60), 'Görsel Postu') from public.posts post join public.post_comments c on c.post_id = post.id where c.id = r.target_id)
        else null
      end as parent_post_preview
    from public.reports r
    order by r.created_at desc
    limit 15
  ) recs;

  -- 6. Recent message reports list with enriched human-readable fields (limit 15)
  select pg_catalog.coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(msgs)), '[]'::jsonb) into v_recent_message_reports
  from (
    select
      mr.id,
      mr.message_id,
      mr.reporter_id,
      mr.reason,
      mr.created_at,
      mr.reported_user_id,
      mr.message_type,
      mr.event_id,
      mr.conversation_id,
      mr.status,
      -- Reporter Name
      (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.profiles p where p.user_id = mr.reporter_id) as reporter_name,
      -- Reported User Name
      (select pg_catalog.coalesce(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') from public.profiles p where p.user_id = mr.reported_user_id) as reported_user_name,
      -- Message Content Snapshot
      pg_catalog.coalesce(
        (select message from public.event_messages where id = mr.message_id),
        (select body from public.direct_messages where id = mr.message_id),
        (select message from public.community_chat_messages where id = mr.message_id)
      ) as message_content,
      -- Event Title Context
      (select title from public.events where id = mr.event_id) as event_title
    from public.message_reports mr
    order by mr.created_at desc
    limit 15
  ) msgs;

  return pg_catalog.jsonb_build_object(
    'total_users', v_total_users,
    'total_events', v_total_events,
    'pending_business_apps', v_pending_business_apps,
    'pending_reports_count', v_pending_reports_count,
    'pending_message_reports_count', v_pending_message_reports_count,
    'recent_events', v_recent_events,
    'pending_business_apps_list', v_pending_business_apps_list,
    'recent_moderation_actions', v_recent_moderation_actions,
    'recent_reports', v_recent_reports,
    'recent_message_reports', v_recent_message_reports
  );
end;
$$;

revoke all on function public.get_admin_dashboard() from public, anon;
grant execute on function public.get_admin_dashboard() to authenticated;
