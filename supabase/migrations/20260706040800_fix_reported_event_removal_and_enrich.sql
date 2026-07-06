-- Migration: Fix reported event removal and show full reported content context (AG-23)

-- 1. Recreate remove_reported_content_as_admin function
CREATE OR REPLACE FUNCTION public.remove_reported_content_as_admin(
  p_report_type text,
  p_report_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_target_id uuid;
  v_target_type text;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  IF p_report_type = 'message' THEN
    SELECT message_id INTO v_target_id
    FROM public.message_reports
    WHERE id = p_report_id;
    
    IF v_target_id IS NULL THEN
      RAISE EXCEPTION 'report_not_found';
    END IF;

    -- Soft-remove message depending on which table it is in
    IF EXISTS (SELECT 1 FROM public.event_messages WHERE id = v_target_id) THEN
      UPDATE public.event_messages
      SET moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      WHERE id = v_target_id;
    ELSIF EXISTS (SELECT 1 FROM public.direct_messages WHERE id = v_target_id) THEN
      UPDATE public.direct_messages
      SET moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      WHERE id = v_target_id;
    ELSIF EXISTS (SELECT 1 FROM public.community_chat_messages WHERE id = v_target_id) THEN
      UPDATE public.community_chat_messages
      SET is_deleted = true
      WHERE id = v_target_id;
    END IF;

    UPDATE public.message_reports
    SET status = 'resolved'
    WHERE id = p_report_id;

    INSERT INTO public.admin_moderation_actions (
      admin_user_id,
      action,
      target_type,
      target_id,
      reason
    )
    VALUES (
      v_admin_id,
      'message_report_removed',
      'message_report',
      p_report_id,
      p_reason
    );

  ELSE
    SELECT target_id, target_type INTO v_target_id, v_target_type
    FROM public.reports
    WHERE id = p_report_id;

    IF v_target_id IS NULL THEN
      RAISE EXCEPTION 'report_not_found';
    END IF;

    IF v_target_type = 'event' THEN
      -- Call the existing safe function to soft-remove event, log moderation history, and notify host
      PERFORM public.set_event_moderation_status_as_admin(v_target_id, 'removed_by_admin', p_reason);

    ELSIF v_target_type = 'post' THEN
      UPDATE public.posts
      SET moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      WHERE id = v_target_id;

    ELSIF v_target_type = 'comment' OR v_target_type = 'post_comment' THEN
      UPDATE public.post_comments
      SET moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      WHERE id = v_target_id;
    ELSE
      RAISE EXCEPTION 'unsupported_report_target_type';
    END IF;

    UPDATE public.reports
    SET status = 'resolved',
        updated_at = now()
    WHERE id = p_report_id;

    INSERT INTO public.admin_moderation_actions (
      admin_user_id,
      action,
      target_type,
      target_id,
      reason
    )
    VALUES (
      v_admin_id,
      'user_report_removed',
      'report',
      p_report_id,
      p_reason
    );
  END IF;
END;
$$;


-- 2. Recreate get_admin_dashboard function to enrich reports
CREATE OR REPLACE FUNCTION public.get_admin_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
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
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  -- 1. General counts
  SELECT COUNT(*)::integer INTO v_total_users FROM public.profiles;
  SELECT COUNT(*)::integer INTO v_total_events FROM public.events;
  SELECT COUNT(*)::integer INTO v_pending_business_apps
  FROM public.business_applications
  WHERE status = 'pending';
  
  SELECT COUNT(*)::integer INTO v_pending_reports_count
  FROM public.reports
  WHERE status = 'open';

  SELECT COUNT(*)::integer INTO v_pending_message_reports_count
  FROM public.message_reports
  WHERE status = 'pending';

  -- 2. Recent events list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(rec_evs)), '[]'::jsonb) INTO v_recent_events
  FROM (
    SELECT
      e.id,
      e.title,
      e.host_id,
      e.organizer_business_id,
      e.event_date,
      e.moderation_status,
      e.created_at,
      COUNT(ep.id) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status IN ('confirmed', 'checked_in'))::integer as participant_count
    FROM public.events e
    LEFT JOIN public.event_participants ep ON ep.event_id = e.id
    GROUP BY e.id, e.title, e.host_id, e.organizer_business_id, e.event_date, e.moderation_status, e.created_at
    ORDER BY e.created_at DESC
    LIMIT 15
  ) rec_evs;

  -- 3. Pending business applications list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(pend_apps)), '[]'::jsonb) INTO v_pending_business_apps_list
  FROM (
    SELECT
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
    FROM public.business_applications ba
    WHERE ba.status = 'pending'
    ORDER BY ba.created_at DESC
    LIMIT 15
  ) pend_apps;

  -- 4. Recent moderation actions list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(mod_acts)), '[]'::jsonb) INTO v_recent_moderation_actions
  FROM (
    SELECT
      ma.id,
      ma.admin_user_id,
      ma.action,
      ma.target_type,
      ma.target_id,
      ma.reason,
      ma.created_at
    FROM public.admin_moderation_actions ma
    ORDER BY ma.created_at DESC
    LIMIT 15
  ) mod_acts;

  -- 5. Recent reports list with enriched human-readable fields (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(recs)), '[]'::jsonb) INTO v_recent_reports
  FROM (
    SELECT
      r.id,
      r.reporter_id,
      r.target_type,
      r.target_id,
      r.reason,
      r.description,
      r.status,
      r.created_at,
      -- Reporter Name
      (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.profiles p WHERE p.user_id = r.reporter_id) as reporter_name,
      -- Target Name (e.g. reported user's name or event title)
      CASE 
        WHEN r.target_type = 'user' THEN (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.profiles p WHERE p.user_id = r.target_id)
        WHEN r.target_type = 'event' THEN (SELECT title FROM public.events WHERE id = r.target_id)
        WHEN r.target_type = 'post' THEN (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.posts post JOIN public.profiles p ON p.user_id = post.user_id WHERE post.id = r.target_id)
        WHEN r.target_type = 'comment' OR r.target_type = 'post_comment' THEN (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.post_comments c JOIN public.profiles p ON p.user_id = c.user_id WHERE c.id = r.target_id)
        ELSE NULL
      END as target_name,
      -- Target Content Preview
      CASE 
        WHEN r.target_type = 'post' THEN (SELECT caption FROM public.posts WHERE id = r.target_id)
        WHEN r.target_type = 'comment' OR r.target_type = 'post_comment' THEN (SELECT comment FROM public.post_comments WHERE id = r.target_id)
        ELSE NULL
      END as target_content,
      -- Event fields
      CASE
        WHEN r.target_type = 'event' THEN (SELECT title FROM public.events WHERE id = r.target_id)
        ELSE NULL
      END as target_title,
      CASE
        WHEN r.target_type = 'event' THEN (SELECT description FROM public.events WHERE id = r.target_id)
        ELSE NULL
      END as target_description,
      CASE
        WHEN r.target_type = 'event' THEN (SELECT event_date::text FROM public.events WHERE id = r.target_id)
        ELSE NULL
      END as target_date,
      CASE
        WHEN r.target_type = 'event' THEN (SELECT event_start_time::text FROM public.events WHERE id = r.target_id)
        ELSE NULL
      END as target_start_time,
      CASE
        WHEN r.target_type = 'event' THEN (SELECT location_text FROM public.events WHERE id = r.target_id)
        ELSE NULL
      END as target_location,
      CASE
        WHEN r.target_type = 'event' THEN (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.events e JOIN public.profiles p ON p.user_id = e.host_id WHERE e.id = r.target_id)
        ELSE NULL
      END as target_host_name,
      -- Post/Comment fields
      CASE
        WHEN r.target_type = 'post' THEN (SELECT image_url FROM public.posts WHERE id = r.target_id)
        ELSE NULL
      END as target_image_url,
      CASE
        WHEN r.target_type = 'post' THEN (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.posts post JOIN public.profiles p ON p.user_id = post.user_id WHERE post.id = r.target_id)
        WHEN r.target_type = 'comment' OR r.target_type = 'post_comment' THEN (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.post_comments c JOIN public.profiles p ON p.user_id = c.user_id WHERE c.id = r.target_id)
        ELSE NULL
      END as target_author_name,
      CASE
        WHEN r.target_type = 'comment' OR r.target_type = 'post_comment' THEN (SELECT COALESCE(substring(caption from 1 for 60), 'Görsel Postu') FROM public.posts post JOIN public.post_comments c ON c.post_id = post.id WHERE c.id = r.target_id)
        ELSE NULL
      END as parent_post_preview
    FROM public.reports r
    ORDER BY r.created_at DESC
    LIMIT 15
  ) recs;

  -- 6. Recent message reports list with enriched human-readable fields (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(msgs)), '[]'::jsonb) INTO v_recent_message_reports
  FROM (
    SELECT
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
      (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.profiles p WHERE p.user_id = mr.reporter_id) as reporter_name,
      -- Reported User Name
      (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.profiles p WHERE p.user_id = mr.reported_user_id) as reported_user_name,
      -- Message Content Snapshot
      COALESCE(
        (SELECT message FROM public.event_messages WHERE id = mr.message_id),
        (SELECT body FROM public.direct_messages WHERE id = mr.message_id),
        (SELECT message FROM public.community_chat_messages WHERE id = mr.message_id)
      ) as message_content,
      -- Event Title Context
      (SELECT title FROM public.events WHERE id = mr.event_id) as event_title
    FROM public.message_reports mr
    ORDER BY mr.created_at DESC
    LIMIT 15
  ) msgs;

  RETURN jsonb_build_object(
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
END;
$$;
