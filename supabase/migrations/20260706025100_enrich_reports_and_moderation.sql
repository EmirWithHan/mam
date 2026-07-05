-- Migration: Enrich Reports and Moderation (AG-21)
-- 1. Add moderation columns idempotently to posts, post_comments, event_messages, and direct_messages.
-- 2. Update SELECT RLS policies on posts, post_comments, event_messages, and direct_messages to restrict visibility of moderated items.
-- 3. Create remove_reported_content_as_admin RPC.
-- 4. Extend get_admin_dashboard RPC to include human-readable user names, event titles, and content previews.

-- 1. Add moderation columns
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS moderation_status text DEFAULT 'approved';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS moderation_removed_at timestamptz;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS moderation_removed_by uuid;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS moderation_reason text;

ALTER TABLE public.post_comments ADD COLUMN IF NOT EXISTS moderation_status text DEFAULT 'approved';
ALTER TABLE public.post_comments ADD COLUMN IF NOT EXISTS moderation_removed_at timestamptz;
ALTER TABLE public.post_comments ADD COLUMN IF NOT EXISTS moderation_removed_by uuid;
ALTER TABLE public.post_comments ADD COLUMN IF NOT EXISTS moderation_reason text;

ALTER TABLE public.event_messages ADD COLUMN IF NOT EXISTS moderation_status text DEFAULT 'approved';
ALTER TABLE public.event_messages ADD COLUMN IF NOT EXISTS moderation_removed_at timestamptz;
ALTER TABLE public.event_messages ADD COLUMN IF NOT EXISTS moderation_removed_by uuid;
ALTER TABLE public.event_messages ADD COLUMN IF NOT EXISTS moderation_reason text;

ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS moderation_status text DEFAULT 'approved';
ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS moderation_removed_at timestamptz;
ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS moderation_removed_by uuid;
ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS moderation_reason text;


-- 2. Update SELECT RLS policies
-- posts
DROP POLICY IF EXISTS "Authenticated users can read posts" ON public.posts;
CREATE POLICY "Authenticated users can read posts"
ON public.posts
FOR SELECT
TO authenticated
USING (
  public.is_current_user_admin()
  OR COALESCE(moderation_status, 'approved') = 'approved'
);

DROP POLICY IF EXISTS "Posts are visible through social graph" ON public.posts;
CREATE POLICY "Posts are visible through social graph"
ON public.posts
FOR SELECT
TO authenticated
USING (
  public.is_current_user_admin()
  OR (
    COALESCE(moderation_status, 'approved') = 'approved'
    AND (
      user_id = auth.uid()
      OR (
        COALESCE(is_archived, false) = false
        AND EXISTS (
          SELECT 1 FROM public.profiles author_profile
          WHERE author_profile.user_id = posts.user_id
            AND (
              COALESCE(author_profile.is_private, false) = false
              OR EXISTS (
                SELECT 1 FROM public.follows viewer_follow
                WHERE viewer_follow.follower_id = auth.uid()
                  AND viewer_follow.following_id = posts.user_id
              )
              OR EXISTS (
                SELECT 1 FROM public.event_participants ep1
                JOIN public.event_participants ep2 ON ep1.event_id = ep2.event_id
                WHERE ep1.user_id = auth.uid()
                  AND ep2.user_id = posts.user_id
                  AND ep1.attendance_status = ANY (ARRAY['planned'::text, 'attended'::text])
                  AND ep2.attendance_status = ANY (ARRAY['planned'::text, 'attended'::text])
              )
            )
        )
      )
    )
  )
);

-- post_comments
DROP POLICY IF EXISTS "Authenticated users can read post comments" ON public.post_comments;
CREATE POLICY "Authenticated users can read post comments"
ON public.post_comments
FOR SELECT
TO authenticated
USING (
  public.is_current_user_admin()
  OR COALESCE(moderation_status, 'approved') = 'approved'
);

DROP POLICY IF EXISTS "Comments follow post visibility" ON public.post_comments;
CREATE POLICY "Comments follow post visibility"
ON public.post_comments
FOR SELECT
TO authenticated
USING (
  public.is_current_user_admin()
  OR (
    COALESCE(moderation_status, 'approved') = 'approved'
    AND EXISTS (
      SELECT 1 FROM public.posts post
      WHERE post.id = post_comments.post_id
        AND (post.user_id = auth.uid() OR COALESCE(post.comments_hidden, false) = false)
    )
  )
);

-- event_messages
DROP POLICY IF EXISTS "Participants can read event messages" ON public.event_messages;
CREATE POLICY "Participants can read event messages"
ON public.event_messages
FOR SELECT
TO authenticated
USING (
  COALESCE(moderation_status, 'approved') = 'approved'
  AND (
    EXISTS (
      SELECT 1 FROM public.event_participants ep
      WHERE ep.event_id = event_messages.event_id
        AND ep.user_id = auth.uid()
        AND (ep.role = 'host'::text OR ep.attendance_status = ANY (ARRAY['planned'::text, 'confirmed'::text, 'checked_in'::text, 'attended'::text]))
    )
    OR EXISTS (
      SELECT 1 FROM public.events e
      WHERE e.id = event_messages.event_id
        AND (
          e.host_id = auth.uid()
          OR e.organizer_user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = e.organizer_business_id
              AND bm.user_id = auth.uid()
          )
        )
    )
  )
);

-- direct_messages (Keep DMs private - do NOT expose all to admins via RLS SELECT)
DROP POLICY IF EXISTS "Select messages in own conversations" ON public.direct_messages;
CREATE POLICY "Select messages in own conversations"
ON public.direct_messages
FOR SELECT
TO authenticated
USING (
  COALESCE(moderation_status, 'approved') = 'approved'
  AND is_direct_conversation_participant(conversation_id)
);


-- 3. Create remove_reported_content_as_admin RPC
CREATE OR REPLACE FUNCTION public.remove_reported_content_as_admin(
  p_report_type text, -- 'post', 'comment', 'event', 'message'
  p_report_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
      UPDATE public.events
      SET moderation_status = 'removed_by_admin'
      WHERE id = v_target_id;
      
      -- Log to event_moderation_logs if exists
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_moderation_logs') THEN
        INSERT INTO public.event_moderation_logs (event_id, admin_user_id, status, reason)
        VALUES (v_target_id, v_admin_id, 'removed_by_admin', p_reason);
      END IF;

    ELSIF v_target_type = 'post' THEN
      UPDATE public.posts
      SET moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      WHERE id = v_target_id;

    ELSIF v_target_type = 'comment' THEN
      UPDATE public.post_comments
      SET moderation_status = 'removed_by_admin',
          moderation_removed_at = now(),
          moderation_removed_by = v_admin_id,
          moderation_reason = p_reason
      WHERE id = v_target_id;
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

GRANT EXECUTE ON FUNCTION public.remove_reported_content_as_admin(text, uuid, text) TO authenticated;


-- 4. Extend get_admin_dashboard RPC to include human-readable user names, event titles, and content previews
CREATE OR REPLACE FUNCTION public.get_admin_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
        WHEN r.target_type = 'comment' THEN (SELECT COALESCE(p.first_name || ' ' || p.last_name, p.username, 'Bilinmeyen Kullanıcı') FROM public.post_comments c JOIN public.profiles p ON p.user_id = c.user_id WHERE c.id = r.target_id)
        ELSE NULL
      END as target_name,
      -- Target Content Preview
      CASE 
        WHEN r.target_type = 'post' THEN (SELECT caption FROM public.posts WHERE id = r.target_id)
        WHEN r.target_type = 'comment' THEN (SELECT comment FROM public.post_comments WHERE id = r.target_id)
        ELSE NULL
      END as target_content
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

GRANT EXECUTE ON FUNCTION public.get_admin_dashboard() TO authenticated;
