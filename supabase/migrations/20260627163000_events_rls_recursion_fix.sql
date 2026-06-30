-- Migration: Events and Event Participants RLS Recursion Fix
-- Resolves circular RLS policy loops between events and event_participants.

-- 1. Helper function to check if user is the host of an event without triggering RLS recursion
CREATE OR REPLACE FUNCTION public.is_event_host(p_event_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.events
    WHERE id = p_event_id
      AND host_id = p_user_id
  );
$$;

-- 2. Helper function to check if user is a participant of an event without triggering RLS recursion
CREATE OR REPLACE FUNCTION public.is_event_participant(p_event_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND user_id = p_user_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_event_host(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_event_participant(uuid, uuid) TO authenticated;

-- 3. Redefine SELECT policies on events
DROP POLICY IF EXISTS "Events are visible to members or public list" ON public.events;
CREATE POLICY "Events are visible to members or public list"
ON public.events
FOR SELECT
TO authenticated
USING (
  host_id = auth.uid()
  OR public.is_event_participant(id, auth.uid())
  OR (
    status IN ('active', 'completed')
    AND (
      community_id IS NULL
      OR community_access = 'public'
      OR public.is_community_active_member(community_id, auth.uid())
    )
  )
);

-- 4. Redefine policies on event_participants
DROP POLICY IF EXISTS "Hosts can read participants for their events" ON public.event_participants;
CREATE POLICY "Hosts can read participants for their events"
ON public.event_participants
FOR SELECT
TO authenticated
USING (
  public.is_event_host(event_id, auth.uid())
);

DROP POLICY IF EXISTS "Participants and hosts can read event participants" ON public.event_participants;
CREATE POLICY "Participants and hosts can read event participants"
ON public.event_participants
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.is_event_host(event_id, auth.uid())
);

DROP POLICY IF EXISTS "Hosts can add participants to their events" ON public.event_participants;
CREATE POLICY "Hosts can add participants to their events"
ON public.event_participants
FOR INSERT
TO authenticated
WITH CHECK (
  role = 'participant'
  AND public.is_event_host(event_id, auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.events e
    WHERE e.id = event_participants.event_id
      AND e.status = 'active'
      AND e.approved_count < e.capacity_total
  )
);

DROP POLICY IF EXISTS "Hosts can update participants for their events" ON public.event_participants;
CREATE POLICY "Hosts can update participants for their events"
ON public.event_participants
FOR UPDATE
TO authenticated
USING (
  public.is_event_host(event_id, auth.uid())
)
WITH CHECK (
  public.is_event_host(event_id, auth.uid())
);

NOTIFY pgrst, 'reload schema';
