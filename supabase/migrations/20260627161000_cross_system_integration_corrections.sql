-- Migration: Cross-System Integration Security and RLS Loop Corrections
-- Resolves circular RLS policy loops and secures RPC execution grants from public/anon.

-- 1. Helper function to check community membership without triggering RLS recursion
CREATE OR REPLACE FUNCTION public.is_community_active_member(p_community_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.community_memberships
    WHERE community_id = p_community_id
      AND user_id = p_user_id
      AND status = 'active'
  );
$$;

-- 2. Helper function to check community visibility without triggering RLS recursion
CREATE OR REPLACE FUNCTION public.community_is_public(p_community_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.communities
    WHERE id = p_community_id
      AND visibility = 'public'
  );
$$;

-- Grant execute rights to authenticated role (needed because they are run inside SELECT policies)
GRANT EXECUTE ON FUNCTION public.is_community_active_member(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_is_public(uuid) TO authenticated;

-- 3. Redefine SELECT policies to utilize non-recursive helper functions

-- A. Table: public.communities
DROP POLICY IF EXISTS "Communities are visible to members or if public" ON public.communities;
CREATE POLICY "Communities are visible to members or if public"
ON public.communities
FOR SELECT
TO authenticated
USING (
  visibility = 'public'
  OR owner_user_id = auth.uid()
  OR public.is_community_active_member(id, auth.uid())
);

-- B. Table: public.community_memberships
DROP POLICY IF EXISTS "Memberships are visible to members or if public" ON public.community_memberships;
CREATE POLICY "Memberships are visible to members or if public"
ON public.community_memberships
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR (
    business_account_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = business_account_id
        AND (ba.owner_user_id = auth.uid() OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = ba.id AND bm.user_id = auth.uid()
        ))
    )
  )
  OR public.community_is_public(community_id)
  OR public.is_community_active_member(community_id, auth.uid())
);

-- C. Table: public.events (member-only check non-recursive bypass)
DROP POLICY IF EXISTS "Events are visible to members or public list" ON public.events;
CREATE POLICY "Events are visible to members or public list"
ON public.events
FOR SELECT
TO authenticated
USING (
  host_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.event_participants participant
    WHERE participant.event_id = events.id
      AND participant.user_id = auth.uid()
  )
  OR (
    status IN ('active', 'completed')
    AND (
      community_id IS NULL
      OR community_access = 'public'
      OR public.is_community_active_member(community_id, auth.uid())
    )
  )
);

-- D. Table: public.community_chat_messages
DROP POLICY IF EXISTS "Members can select community chat messages" ON public.community_chat_messages;
CREATE POLICY "Members can select community chat messages"
ON public.community_chat_messages
FOR SELECT
TO authenticated
USING (
  public.is_community_active_member(community_id, auth.uid())
);

-- E. Table: public.community_chat_reactions
DROP POLICY IF EXISTS "Members can select chat reactions" ON public.community_chat_reactions;
CREATE POLICY "Members can select chat reactions"
ON public.community_chat_reactions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.community_chat_messages msg
    WHERE msg.id = message_id
      AND public.is_community_active_member(msg.community_id, auth.uid())
  )
);

-- F. Table: public.community_posts
DROP POLICY IF EXISTS "Select posts based on community privacy" ON public.community_posts;
CREATE POLICY "Select posts based on community privacy"
ON public.community_posts
FOR SELECT
TO authenticated
USING (
  public.community_is_public(community_id)
  OR EXISTS (
    SELECT 1 FROM public.communities c
    WHERE c.id = community_id
      AND c.owner_user_id = auth.uid()
  )
  OR public.is_community_active_member(community_id, auth.uid())
);


-- 4. Tighten RPC Function Execution Grants
-- Revoke execution rights from public/anon on all new RPC functions to ensure secure authenticated-only execution.

-- Foundation RPCs
REVOKE EXECUTE ON FUNCTION public.create_community(text, text, text, text, text, text[], text, text, text, text, text, text, text, text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_community(uuid, text, text, text, text, text, text[], text, text, text, text, text, text, text, text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.archive_community(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.join_community(uuid, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.leave_community(uuid, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.follow_community(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.unfollow_community(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.manage_membership_request(uuid, text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.moderate_member(uuid, text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_community_role(uuid, text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.transfer_community_ownership(uuid, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.has_current_user_community_permission(uuid, text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.recompute_community_counts(uuid) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.create_community(text, text, text, text, text, text[], text, text, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_community(uuid, text, text, text, text, text, text[], text, text, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_community(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_community(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_community(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.follow_community(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unfollow_community(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manage_membership_request(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_member(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_community_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_community_ownership(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_current_user_community_permission(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_community_counts(uuid) TO authenticated;

-- Social & Chat RPCs
REVOKE EXECUTE ON FUNCTION public.send_community_chat_message(uuid, text, uuid, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.delete_community_chat_message(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_community_post(uuid, text, text, text[], uuid, boolean, boolean) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_community_post(uuid, text, text[]) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.delete_community_post(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.pin_community_post(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.unpin_community_post(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_community_comment(uuid, text, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.delete_community_comment(uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.toggle_community_post_reaction(uuid, text, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.toggle_community_chat_reaction(uuid, text, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.mute_community_chat(uuid, boolean) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.mark_community_chat_read(uuid, uuid) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_community_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[], text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reconcile_event_visibility_change(uuid, text, boolean) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.send_community_chat_message(uuid, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_community_chat_message(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_community_post(uuid, text, text, text[], uuid, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_community_post(uuid, text, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_community_post(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pin_community_post(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unpin_community_post(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_community_comment(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_community_comment(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_community_post_reaction(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_community_chat_reaction(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mute_community_chat(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_community_chat_read(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_community_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_event_visibility_change(uuid, text, boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';
