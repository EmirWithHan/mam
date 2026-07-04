CREATE OR REPLACE FUNCTION public.get_host_event_analytics(p_event_id uuid)
RETURNS TABLE (
  user_id text,
  username text,
  first_name text,
  avatar_url text,
  joined_at timestamptz,
  checked_in_at timestamptz,
  message_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_is_host boolean;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Verify if the actor is the host of the event by checking the events table directly
  SELECT EXISTS (
    SELECT 1 FROM public.events ev
    WHERE ev.id = p_event_id
      AND ev.host_id = v_actor_id
  ) INTO v_is_host;

  IF NOT v_is_host THEN
    -- Or if they are owner of the business organizing the event
    SELECT EXISTS (
      SELECT 1 FROM public.events ev
      JOIN public.business_accounts ba ON ba.id = ev.organizer_business_id
      WHERE ev.id = p_event_id
        AND ba.owner_user_id = v_actor_id
        AND ba.status = 'active'
    ) INTO v_is_host;
  END IF;

  IF NOT v_is_host THEN
    RAISE EXCEPTION 'not_authorized_host_only';
  END IF;

  RETURN QUERY
  SELECT
    p.user_id::text,
    pr.username::text,
    pr.first_name::text,
    pr.avatar_url::text,
    p.joined_at,
    p.checked_in_at,
    COALESCE(
      (
        SELECT COUNT(*)::integer
        FROM public.event_messages m
        WHERE m.event_id = p_event_id
          AND m.sender_id = p.user_id
      ),
      0
    ) as message_count
  FROM public.event_participants p
  JOIN public.profiles pr ON pr.user_id = p.user_id
  WHERE p.event_id = p_event_id
    AND p.role = 'participant'
    AND p.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in', 'no_show')
  ORDER BY message_count DESC, pr.first_name;
END;
$$;

REVOKE ALL ON FUNCTION public.get_host_event_analytics(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_host_event_analytics(uuid) TO authenticated;
