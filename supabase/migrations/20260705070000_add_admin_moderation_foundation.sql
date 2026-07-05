-- Drop and recreate notifications_type_check check constraint to add admin/business moderation notification types
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (
    type IN (
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
      'community_membership_revocation',
      'message',
      'admin_event_removed',
      'business_application_approved',
      'business_application_rejected'
    )
  );

-- Create moderation audit log table
CREATE TABLE IF NOT EXISTS public.admin_moderation_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_moderation_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can select moderation actions" ON public.admin_moderation_actions;
CREATE POLICY "Admins can select moderation actions"
  ON public.admin_moderation_actions
  FOR SELECT
  TO authenticated
  USING (public.is_current_user_admin());

-- Redefine set_event_moderation_status_as_admin to include notifications and moderation log inserts
CREATE OR REPLACE FUNCTION public.set_event_moderation_status_as_admin(
  p_event_id uuid,
  p_new_status text,
  p_reason text default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_previous_status text;
  v_host_id uuid;
  v_action text;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  IF p_new_status NOT IN ('approved', 'rejected', 'removed_by_admin') THEN
    RAISE EXCEPTION 'invalid_moderation_status';
  END IF;

  SELECT moderation_status, host_id
  INTO v_previous_status, v_host_id
  FROM public.events
  WHERE id = p_event_id
  FOR UPDATE;

  IF v_previous_status IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  v_action := CASE p_new_status
    WHEN 'approved' THEN 'admin_restored'
    WHEN 'rejected' THEN 'admin_rejected'
    WHEN 'removed_by_admin' THEN 'admin_removed'
    ELSE 'admin_updated'
  END;

  -- Apply status change
  UPDATE public.events
  SET moderation_status = p_new_status,
      moderation_source = 'admin',
      moderation_reason = nullif(btrim(p_reason), ''),
      moderation_removed_by = CASE
        WHEN p_new_status = 'removed_by_admin' THEN v_admin_id
        ELSE null
      END,
      moderation_removed_at = CASE
        WHEN p_new_status = 'removed_by_admin' THEN now()
        ELSE null
      END,
      moderation_updated_at = now()
  WHERE id = p_event_id;

  -- Write moderation history log
  INSERT INTO public.event_moderation_logs (
    event_id,
    admin_user_id,
    action,
    previous_status,
    new_status,
    reason
  )
  VALUES (
    p_event_id,
    v_admin_id,
    v_action,
    v_previous_status,
    p_new_status,
    nullif(btrim(p_reason), '')
  );

  -- Write moderation audit action
  INSERT INTO public.admin_moderation_actions (
    admin_user_id,
    action,
    target_type,
    target_id,
    reason
  )
  VALUES (
    v_admin_id,
    v_action,
    'event',
    p_event_id,
    nullif(btrim(p_reason), '')
  );

  -- Send notification if removed by admin
  IF p_new_status = 'removed_by_admin' AND v_host_id IS NOT NULL THEN
    INSERT INTO public.notifications (
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
    VALUES (
      v_host_id,
      v_admin_id,
      'admin_event_removed',
      'Etkinliğin kaldırıldı',
      COALESCE('Etkinliğin platform kurallarına uygun olmadığı için kaldırıldı: ' || nullif(btrim(p_reason), ''), 'Etkinliğin platform kurallarına uygun olmadığı için kaldırıldı.'),
      'event',
      p_event_id,
      jsonb_build_object(
        'event_id', p_event_id::text,
        'reason', nullif(btrim(p_reason), '')
      ),
      false
    );
  END IF;
END;
$$;

-- Redefine approve_business_application to include notifications and moderation log inserts
CREATE OR REPLACE FUNCTION public.approve_business_application(
  p_application_id uuid,
  p_admin_note text default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_application public.business_applications%rowtype;
  v_business_id uuid;
  v_username text;
  v_category text;
  v_custom_category text;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  SELECT *
  INTO v_application
  FROM public.business_applications
  WHERE id = p_application_id
  FOR UPDATE;

  IF v_application.id IS NULL THEN
    RAISE EXCEPTION 'business_application_not_found';
  END IF;

  IF v_application.status = 'approved' THEN
    RETURN;
  END IF;

  IF v_application.status <> 'pending' THEN
    RAISE EXCEPTION 'business_application_not_pending';
  END IF;

  v_category := nullif(btrim(v_application.category), '');
  v_custom_category := nullif(btrim(v_application.custom_category), '');

  IF v_category IS NULL THEN
    v_category := 'Diğer';
    v_custom_category := COALESCE(
      v_custom_category,
      nullif(left(btrim(v_application.business_name), 40), ''),
      'İşletme'
    );
  ELSIF v_category = 'Diğer' AND v_custom_category IS NULL THEN
    v_custom_category := COALESCE(
      nullif(left(btrim(v_application.business_name), 40), ''),
      'İşletme'
    );
  ELSIF v_category <> 'Diğer' THEN
    v_custom_category := null;
  END IF;

  v_username := left(
    public.business_application_username(v_application.business_name)
    || '_'
    || left(replace(v_application.id::text, '-', ''), 4),
    24
  );

  INSERT INTO public.business_accounts (
    owner_user_id,
    name,
    username,
    category,
    custom_category,
    city,
    district,
    address,
    description,
    phone,
    website,
    is_verified,
    status
  )
  VALUES (
    v_application.user_id,
    v_application.business_name,
    v_username,
    v_category,
    v_custom_category,
    'Belirtilmedi',
    'Belirtilmedi',
    v_application.full_address,
    v_application.description,
    v_application.business_phone,
    v_application.website,
    false,
    'active'
  )
  ON CONFLICT (owner_user_id)
    WHERE status IN ('pending', 'active')
  DO UPDATE SET
    name = excluded.name,
    username = excluded.username,
    category = excluded.category,
    custom_category = excluded.custom_category,
    address = excluded.address,
    description = excluded.description,
    phone = excluded.phone,
    website = excluded.website,
    status = 'active',
    is_verified = false,
    updated_at = now()
  RETURNING id INTO v_business_id;

  UPDATE public.profiles profile
  SET personal_full_name = COALESCE(profile.personal_full_name, profile.first_name),
      personal_username = COALESCE(profile.personal_username, profile.username),
      personal_bio = COALESCE(profile.personal_bio, profile.bio),
      personal_avatar_url = COALESCE(profile.personal_avatar_url, profile.avatar_url),
      account_type = 'business',
      business_account_id = v_business_id,
      first_name = v_application.business_name,
      username = v_username,
      bio = COALESCE(v_application.description, profile.bio),
      phone = v_application.business_phone,
      is_profile_completed = true,
      updated_at = now()
  WHERE profile.user_id = v_application.user_id;

  UPDATE public.business_applications
  SET status = 'approved',
      category = v_category,
      custom_category = v_custom_category,
      admin_note = nullif(btrim(p_admin_note), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      updated_at = now()
  WHERE id = v_application.id;

  -- Write moderation audit action
  INSERT INTO public.admin_moderation_actions (
    admin_user_id,
    action,
    target_type,
    target_id,
    reason
  )
  VALUES (
    v_admin_id,
    'business_application_approved',
    'business_application',
    p_application_id,
    nullif(btrim(p_admin_note), '')
  );

  -- Send notification to owner
  INSERT INTO public.notifications (
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
  VALUES (
    v_application.user_id,
    v_admin_id,
    'business_application_approved',
    'İşletme başvurun onaylandı',
    'İşletme hesabın artık kullanılabilir.',
    'business_application',
    p_application_id,
    jsonb_build_object(
      'application_id', p_application_id::text,
      'business_id', v_business_id::text,
      'admin_note', nullif(btrim(p_admin_note), '')
    ),
    false
  );
END;
$$;

-- Redefine reject_business_application to include notifications and moderation log inserts
CREATE OR REPLACE FUNCTION public.reject_business_application(
  p_application_id uuid,
  p_admin_note text default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_application public.business_applications%rowtype;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  SELECT *
  INTO v_application
  FROM public.business_applications
  WHERE id = p_application_id
    AND status = 'pending'
  FOR UPDATE;

  IF v_application.id IS NULL THEN
    RAISE EXCEPTION 'business_application_not_pending';
  END IF;

  UPDATE public.business_applications
  SET status = 'rejected',
      admin_note = nullif(btrim(p_admin_note), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      updated_at = now()
  WHERE id = p_application_id;

  -- Write moderation audit action
  INSERT INTO public.admin_moderation_actions (
    admin_user_id,
    action,
    target_type,
    target_id,
    reason
  )
  VALUES (
    v_admin_id,
    'business_application_rejected',
    'business_application',
    p_application_id,
    nullif(btrim(p_admin_note), '')
  );

  -- Send notification to owner
  INSERT INTO public.notifications (
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
  VALUES (
    v_application.user_id,
    v_admin_id,
    'business_application_rejected',
    'İşletme başvurun reddedildi',
    COALESCE('İşletme başvurun incelendi ve reddedildi: ' || nullif(btrim(p_admin_note), ''), 'İşletme başvurun incelendi ve reddedildi.'),
    'business_application',
    p_application_id,
    jsonb_build_object(
      'application_id', p_application_id::text,
      'admin_note', nullif(btrim(p_admin_note), '')
    ),
    false
  );
END;
$$;

-- Create secure admin dashboard RPC function
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
  v_recent_events jsonb := '[]'::jsonb;
  v_pending_business_apps_list jsonb := '[]'::jsonb;
  v_recent_moderation_actions jsonb := '[]'::jsonb;
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

  -- 2. Recent events list (limit 15)
  SELECT COALESCE(json_agg(row_to_json(rec_evs)), '[]'::jsonb) INTO v_recent_events
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
  SELECT COALESCE(json_agg(row_to_json(pend_apps)), '[]'::jsonb) INTO v_pending_business_apps_list
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
  SELECT COALESCE(json_agg(row_to_json(mod_acts)), '[]'::jsonb) INTO v_recent_moderation_actions
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

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'total_events', v_total_events,
    'pending_business_apps', v_pending_business_apps,
    'recent_events', v_recent_events,
    'pending_business_apps_list', v_pending_business_apps_list,
    'recent_moderation_actions', v_recent_moderation_actions
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_dashboard() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_admin_dashboard() TO authenticated;
