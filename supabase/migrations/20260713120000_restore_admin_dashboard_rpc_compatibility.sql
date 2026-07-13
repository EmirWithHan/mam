-- Restore the admin dashboard RPC after COALESCE was incorrectly treated as a
-- schema-qualified function by the security-hardening migration.

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

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(rec_evs)), '[]'::jsonb)
  into v_recent_events
  from (
    select
      e.id,
      e.title,
      e.host_id,
      e.organizer_business_id,
      e.event_date,
      e.moderation_status,
      e.created_at,
      pg_catalog.count(ep.id) filter (
        where ep.role = 'participant'
          and ep.attendance_status in ('confirmed', 'checked_in')
      )::integer as participant_count
    from public.events e
    left join public.event_participants ep on ep.event_id = e.id
    group by
      e.id,
      e.title,
      e.host_id,
      e.organizer_business_id,
      e.event_date,
      e.moderation_status,
      e.created_at
    order by e.created_at desc
    limit 15
  ) rec_evs;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(pend_apps)), '[]'::jsonb)
  into v_pending_business_apps_list
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

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(mod_acts)), '[]'::jsonb)
  into v_recent_moderation_actions
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

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(recs)), '[]'::jsonb)
  into v_recent_reports
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
      (
        select coalesce(
          p.first_name || ' ' || p.last_name,
          p.username,
          'Bilinmeyen Kullanıcı'
        )
        from public.profiles p
        where p.user_id = r.reporter_id
      ) as reporter_name,
      case
        when r.target_type = 'user' then (
          select coalesce(
            p.first_name || ' ' || p.last_name,
            p.username,
            'Bilinmeyen Kullanıcı'
          )
          from public.profiles p
          where p.user_id = r.target_id
        )
        when r.target_type = 'event' then (
          select event_record.title
          from public.events event_record
          where event_record.id = r.target_id
        )
        when r.target_type = 'post' then (
          select coalesce(
            p.first_name || ' ' || p.last_name,
            p.username,
            'Bilinmeyen Kullanıcı'
          )
          from public.posts post
          join public.profiles p on p.user_id = post.user_id
          where post.id = r.target_id
        )
        when r.target_type in ('comment', 'post_comment') then (
          select coalesce(
            p.first_name || ' ' || p.last_name,
            p.username,
            'Bilinmeyen Kullanıcı'
          )
          from public.post_comments comment_record
          join public.profiles p on p.user_id = comment_record.user_id
          where comment_record.id = r.target_id
        )
        else null
      end as target_name,
      case
        when r.target_type = 'post' then (
          select post.caption from public.posts post where post.id = r.target_id
        )
        when r.target_type in ('comment', 'post_comment') then (
          select comment_record.comment
          from public.post_comments comment_record
          where comment_record.id = r.target_id
        )
        else null
      end as target_content,
      case when r.target_type = 'event' then (
        select event_record.title
        from public.events event_record
        where event_record.id = r.target_id
      ) else null end as target_title,
      case when r.target_type = 'event' then (
        select event_record.description
        from public.events event_record
        where event_record.id = r.target_id
      ) else null end as target_description,
      case when r.target_type = 'event' then (
        select event_record.event_date::text
        from public.events event_record
        where event_record.id = r.target_id
      ) else null end as target_date,
      case when r.target_type = 'event' then (
        select event_record.event_start_time::text
        from public.events event_record
        where event_record.id = r.target_id
      ) else null end as target_start_time,
      case when r.target_type = 'event' then (
        select event_record.location_text
        from public.events event_record
        where event_record.id = r.target_id
      ) else null end as target_location,
      case when r.target_type = 'event' then (
        select coalesce(
          p.first_name || ' ' || p.last_name,
          p.username,
          'Bilinmeyen Kullanıcı'
        )
        from public.events event_record
        join public.profiles p on p.user_id = event_record.host_id
        where event_record.id = r.target_id
      ) else null end as target_host_name,
      case when r.target_type = 'post' then (
        select post.image_url from public.posts post where post.id = r.target_id
      ) else null end as target_image_url,
      case
        when r.target_type = 'post' then (
          select coalesce(
            p.first_name || ' ' || p.last_name,
            p.username,
            'Bilinmeyen Kullanıcı'
          )
          from public.posts post
          join public.profiles p on p.user_id = post.user_id
          where post.id = r.target_id
        )
        when r.target_type in ('comment', 'post_comment') then (
          select coalesce(
            p.first_name || ' ' || p.last_name,
            p.username,
            'Bilinmeyen Kullanıcı'
          )
          from public.post_comments comment_record
          join public.profiles p on p.user_id = comment_record.user_id
          where comment_record.id = r.target_id
        )
        else null
      end as target_author_name,
      case when r.target_type in ('comment', 'post_comment') then (
        select coalesce(
          pg_catalog.substring(post.caption, 1, 60),
          'Görsel Postu'
        )
        from public.posts post
        join public.post_comments comment_record on comment_record.post_id = post.id
        where comment_record.id = r.target_id
      ) else null end as parent_post_preview
    from public.reports r
    order by r.created_at desc
    limit 15
  ) recs;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(msgs)), '[]'::jsonb)
  into v_recent_message_reports
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
      (
        select coalesce(
          p.first_name || ' ' || p.last_name,
          p.username,
          'Bilinmeyen Kullanıcı'
        )
        from public.profiles p
        where p.user_id = mr.reporter_id
      ) as reporter_name,
      (
        select coalesce(
          p.first_name || ' ' || p.last_name,
          p.username,
          'Bilinmeyen Kullanıcı'
        )
        from public.profiles p
        where p.user_id = mr.reported_user_id
      ) as reported_user_name,
      coalesce(
        (select event_message.message from public.event_messages event_message where event_message.id = mr.message_id),
        (select direct_message.body from public.direct_messages direct_message where direct_message.id = mr.message_id),
        (select community_message.message from public.community_chat_messages community_message where community_message.id = mr.message_id)
      ) as message_content,
      (
        select event_record.title
        from public.events event_record
        where event_record.id = mr.event_id
      ) as event_title
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
