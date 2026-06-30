-- Migration: 20260622130000_communities_social_and_events.sql
-- Description: Implement secure community chat, posts, comments, mutes, reactions, member-only event security, and generalized recurrence.

-- 1. Alter public.events to support community linkage and access visibility
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS community_id uuid REFERENCES public.communities(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS community_access text NOT NULL DEFAULT 'public' CHECK (community_access IN ('public', 'members_only'));

-- 2. Redefine SELECT policy on public.events to restrict members_only community events
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
      OR EXISTS (
        SELECT 1 FROM public.community_memberships cm
        WHERE cm.community_id = events.community_id
          AND cm.user_id = auth.uid()
          AND cm.status = 'active'
      )
    )
  )
);

-- 3. Generalize public.event_recurring_series to support community-owned series
ALTER TABLE public.event_recurring_series ALTER COLUMN business_account_id DROP NOT NULL;
ALTER TABLE public.event_recurring_series ADD COLUMN IF NOT EXISTS community_id uuid REFERENCES public.communities(id) ON DELETE CASCADE;

ALTER TABLE public.event_recurring_series DROP CONSTRAINT IF EXISTS event_recurring_series_owner_check;
ALTER TABLE public.event_recurring_series ADD CONSTRAINT event_recurring_series_owner_check CHECK (
  (business_account_id IS NOT NULL AND community_id IS NULL) OR
  (business_account_id IS NULL AND community_id IS NOT NULL)
);

DROP POLICY IF EXISTS "Business owners can manage own series" ON public.event_recurring_series;
DROP POLICY IF EXISTS "Manage event recurring series" ON public.event_recurring_series;
CREATE POLICY "Manage event recurring series"
ON public.event_recurring_series
FOR ALL
TO authenticated
USING (
  (business_account_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.business_accounts ba
    WHERE ba.id = event_recurring_series.business_account_id
      AND ba.owner_user_id = auth.uid()
  ))
  OR
  (community_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.community_memberships cm
    WHERE cm.community_id = event_recurring_series.community_id
      AND cm.user_id = auth.uid()
      AND cm.status = 'active'
      AND cm.role IN ('owner', 'manager', 'assistant_manager')
  ))
);

-- 4. Create community social tables
-- A. Chat Messages
CREATE TABLE IF NOT EXISTS public.community_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  business_account_id uuid REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  message text NOT NULL,
  reply_to_message_id uuid REFERENCES public.community_chat_messages(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT community_chat_messages_actor_check CHECK (
    (user_id IS NOT NULL AND business_account_id IS NULL) OR
    (user_id IS NULL AND business_account_id IS NOT NULL)
  ),
  CONSTRAINT community_chat_messages_length CHECK (char_length(trim(message)) >= 1 AND char_length(message) <= 1000)
);

-- B. Chat Reactions
CREATE TABLE IF NOT EXISTS public.community_chat_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.community_chat_messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  business_account_id uuid REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  emoji text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT community_chat_reactions_actor_check CHECK (
    (user_id IS NOT NULL AND business_account_id IS NULL) OR
    (user_id IS NULL AND business_account_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS community_chat_reactions_user_idx
  ON public.community_chat_reactions(message_id, user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS community_chat_reactions_business_idx
  ON public.community_chat_reactions(message_id, business_account_id) WHERE business_account_id IS NOT NULL;

-- C. Chat Mutes
CREATE TABLE IF NOT EXISTS public.community_chat_mutes (
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (community_id, user_id)
);

-- D. Chat Reads
CREATE TABLE IF NOT EXISTS public.community_chat_reads (
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_read_message_id uuid REFERENCES public.community_chat_messages(id) ON DELETE SET NULL,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (community_id, user_id)
);

-- E. Posts
CREATE TABLE IF NOT EXISTS public.community_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  business_account_id uuid REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'normal' CHECK (type IN ('normal', 'announcement', 'event_share')),
  content text,
  is_pinned boolean NOT NULL DEFAULT false,
  is_deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT community_posts_actor_check CHECK (
    (user_id IS NOT NULL AND business_account_id IS NULL) OR
    (user_id IS NULL AND business_account_id IS NOT NULL)
  ),
  CONSTRAINT community_posts_content_length CHECK (content IS NULL OR (char_length(trim(content)) >= 1 AND char_length(content) <= 5000))
);

-- F. Post Images
CREATE TABLE IF NOT EXISTS public.community_post_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  image_url text not null,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- G. Post Reactions
CREATE TABLE IF NOT EXISTS public.community_post_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  business_account_id uuid REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  emoji text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT community_post_reactions_actor_check CHECK (
    (user_id IS NOT NULL AND business_account_id IS NULL) OR
    (user_id IS NULL AND business_account_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS community_post_reactions_user_idx
  ON public.community_post_reactions(post_id, user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS community_post_reactions_business_idx
  ON public.community_post_reactions(post_id, business_account_id) WHERE business_account_id IS NOT NULL;

-- H. Comments
CREATE TABLE IF NOT EXISTS public.community_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  business_account_id uuid REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  content text NOT NULL,
  is_deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT community_comments_actor_check CHECK (
    (user_id IS NOT NULL AND business_account_id IS NULL) OR
    (user_id IS NULL AND business_account_id IS NOT NULL)
  ),
  CONSTRAINT community_comments_content_length CHECK (char_length(trim(content)) >= 1 AND char_length(content) <= 1000)
);

-- 5. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.community_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_chat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_chat_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_chat_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_post_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_post_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;

-- Revoke direct mutations
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_chat_messages FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_chat_reactions FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_chat_mutes FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_chat_reads FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_posts FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_post_images FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_post_reactions FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_comments FROM authenticated, anon;

-- Grant select and access
GRANT SELECT ON TABLE public.community_chat_messages TO authenticated;
GRANT SELECT ON TABLE public.community_chat_reactions TO authenticated;
GRANT SELECT ON TABLE public.community_chat_mutes TO authenticated;
GRANT SELECT ON TABLE public.community_chat_reads TO authenticated;
GRANT SELECT ON TABLE public.community_posts TO authenticated;
GRANT SELECT ON TABLE public.community_post_images TO authenticated;
GRANT SELECT ON TABLE public.community_post_reactions TO authenticated;
GRANT SELECT ON TABLE public.community_comments TO authenticated;

-- 6. Define SELECT RLS Policies
-- Chat Messages (Members only)
CREATE POLICY "Members can select community chat messages"
ON public.community_chat_messages
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.community_memberships cm
    WHERE cm.community_id = community_chat_messages.community_id
      AND cm.user_id = auth.uid()
      AND cm.status = 'active'
  )
);

-- Chat Reactions (Members only)
CREATE POLICY "Members can select chat reactions"
ON public.community_chat_reactions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.community_chat_messages msg
    JOIN public.community_memberships cm ON cm.community_id = msg.community_id
    WHERE msg.id = message_id
      AND cm.user_id = auth.uid()
      AND cm.status = 'active'
  )
);

-- Chat Mutes/Reads (Own only)
CREATE POLICY "Users can manage own mute state"
ON public.community_chat_mutes
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Users can manage own read state"
ON public.community_chat_reads
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Posts (Based on community visibility)
CREATE POLICY "Select posts based on community privacy"
ON public.community_posts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.communities c
    WHERE c.id = community_id
      AND (
        c.visibility = 'public'
        OR c.owner_user_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.community_memberships cm
          WHERE cm.community_id = c.id
            AND cm.user_id = auth.uid()
            AND cm.status = 'active'
        )
      )
  )
);

-- Post Images (Same as post select)
CREATE POLICY "Select post images based on post select"
ON public.community_post_images
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.community_posts p
    WHERE p.id = post_id
  )
);

-- Post Reactions (Same as post select)
CREATE POLICY "Select post reactions based on post select"
ON public.community_post_reactions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.community_posts p
    WHERE p.id = post_id
  )
);

-- Comments (Same as post select)
CREATE POLICY "Select comments based on post select"
ON public.community_comments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.community_posts p
    WHERE p.id = post_id
  )
);

-- 7. Audit & Enforcements Triggers
-- A. Membership Loss Trigger: Cancel future member-only event accesses without deleting past attendance
CREATE OR REPLACE FUNCTION public.handle_community_membership_loss()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
  v_future_events CURSOR FOR
    SELECT e.id
    FROM public.events e
    WHERE e.community_id = old.community_id
      AND e.community_access = 'members_only'
      AND e.event_date > now();
BEGIN
  IF old.status = 'active' AND new.status IN ('left', 'banned', 'rejected') THEN
    OPEN v_future_events;
    LOOP
      FETCH v_future_events INTO v_event_id;
      EXIT WHEN NOT FOUND;

      -- If personal user membership is lost
      IF old.user_id IS NOT NULL THEN
        -- 1. Cancel pending requests
        UPDATE public.event_join_requests
        SET status = 'cancelled', updated_at = now()
        WHERE event_id = v_event_id
          AND user_id = old.user_id
          AND status = 'pending';

        -- 2. Cancel approved/waitlist entries (leave past attendance intact)
        UPDATE public.event_participants
        SET attendance_status = 'cancelled', updated_at = now(), role = 'left'
        WHERE event_id = v_event_id
          AND user_id = old.user_id
          AND attendance_status IN ('confirmed', 'waitlisted', 'planned', 'checked_in', 'pending_confirmation');

        -- 3. Recount event approved counts
        UPDATE public.events
        SET approved_count = (
          SELECT COUNT(*)
          FROM public.event_participants
          WHERE event_id = v_event_id
            AND role = 'participant'
            AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
        )
        WHERE id = v_event_id;

        -- 4. Send notification regarding the cancelation
        INSERT INTO public.notifications (
          recipient_id,
          actor_id,
          type,
          title,
          body,
          entity_type,
          entity_id,
          metadata
        ) VALUES (
          old.user_id,
          auth.uid(),
          'community_membership_revocation',
          'Üyelik İptali ve Etkinlikler',
          'Topluluk üyeliğiniz sonlandığı için üyeye özel etkinlik katılımlarınız iptal edildi.',
          'community',
          old.community_id::text,
          jsonb_build_object('community_id', old.community_id)
        );
      END IF;
    END LOOP;
    CLOSE v_future_events;
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_community_membership_loss ON public.community_memberships;
CREATE TRIGGER trg_community_membership_loss
AFTER UPDATE OF status ON public.community_memberships
FOR EACH ROW
EXECUTE FUNCTION public.handle_community_membership_loss();

-- B. Trigger to enforce community members-only event participations
CREATE OR REPLACE FUNCTION public.enforce_community_members_only_events()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_community_id uuid;
  v_community_access text;
  v_user_id uuid;
BEGIN
  SELECT community_id, community_access
  INTO v_community_id, v_community_access
  FROM public.events
  WHERE id = new.event_id;

  IF v_community_id IS NULL OR v_community_access <> 'members_only' THEN
    RETURN new;
  END IF;

  v_user_id := new.user_id;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id_required_for_event_participation' USING errcode = 'M0019';
  END IF;

  -- Enforce active membership to join
  IF NOT EXISTS (
    SELECT 1 FROM public.community_memberships
    WHERE community_id = v_community_id
      AND user_id = v_user_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_community_event_participants ON public.event_participants;
CREATE TRIGGER trg_enforce_community_event_participants
BEFORE INSERT OR UPDATE ON public.event_participants
FOR EACH ROW
EXECUTE FUNCTION public.enforce_community_members_only_events();

DROP TRIGGER IF EXISTS trg_enforce_community_event_join_requests ON public.event_join_requests;
CREATE TRIGGER trg_enforce_community_event_join_requests
BEFORE INSERT OR UPDATE ON public.event_join_requests
FOR EACH ROW
EXECUTE FUNCTION public.enforce_community_members_only_events();

-- C. Trigger to enforce community event creation permissions (owner/manager/assistant_manager only)
CREATE OR REPLACE FUNCTION public.enforce_community_event_creation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF new.community_id IS NULL THEN
    RETURN new;
  END IF;

  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  -- Business account check or regular user check
  IF new.organizer_type = 'business' THEN
    RAISE EXCEPTION 'business_actor_cannot_create_community_event' USING errcode = 'C0006';
  END IF;

  IF NOT public.has_community_permission(new.community_id, v_user_id, 'manage_members') THEN
    RAISE EXCEPTION 'community_event_creation_permission_required' USING errcode = 'C0005';
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_community_event_creation ON public.events;
CREATE TRIGGER trg_enforce_community_event_creation
BEFORE INSERT OR UPDATE ON public.events
FOR EACH ROW
EXECUTE FUNCTION public.enforce_community_event_creation();

-- 8. Redefine/Extend push outbox trigger function to process new community types
CREATE OR REPLACE FUNCTION public.queue_push_for_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_body text;
  v_title text;
  v_community_id uuid;
  v_is_muted boolean := false;
BEGIN
  IF new.type NOT IN (
    'event_join_request',
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
    'community_membership_revocation'
  ) THEN
    RETURN new;
  END IF;

  -- Check if community chat or notification is muted
  IF new.type IN ('community_chat_mention', 'community_announcement', 'community_members_only_event') THEN
    v_community_id := (new.metadata->>'community_id')::uuid;
    IF v_community_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1 FROM public.community_chat_mutes
        WHERE community_id = v_community_id AND user_id = new.recipient_id
      ) INTO v_is_muted;
    END IF;
  END IF;

  -- Skip push outbox if muted and it's a regular chat/update push
  IF v_is_muted AND new.type = 'community_chat_mention' THEN
    RETURN new;
  END IF;

  v_body := nullif(btrim(coalesce(new.body, '')), '');
  v_title := nullif(btrim(coalesce(new.title, '')), '');

  IF v_body IS NULL THEN
    v_body := 'Yeni bir bildiriminiz var.';
  END IF;
  IF v_title IS NULL THEN
    v_title := 'Match A Man';
  END IF;

  -- Insert deduplicated push to outbox
  INSERT INTO public.push_notification_outbox (
    notification_id,
    recipient_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    metadata
  )
  VALUES (
    new.id,
    new.recipient_id,
    new.type,
    v_title,
    v_body,
    new.entity_type,
    new.entity_id,
    coalesce(new.metadata, '{}'::jsonb)
  )
  ON CONFLICT DO NOTHING;

  RETURN new;
END;
$$;

-- 9. Secure RPC Mutations
-- A. Chat: Send Message (Includes rate limit and spam checks)
CREATE OR REPLACE FUNCTION public.send_community_chat_message(
  p_community_id uuid,
  p_message text,
  p_reply_to_message_id uuid default null,
  p_business_account_id uuid default null
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_msg_id uuid;
  v_recent_count integer;
  v_normalized_msg text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  -- Membership checks
  IF NOT EXISTS (
    SELECT 1 FROM public.community_memberships
    WHERE community_id = p_community_id AND user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
  END IF;

  -- Business identity authorization checks
  IF p_business_account_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.community_memberships
      WHERE community_id = p_community_id AND business_account_id = p_business_account_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = p_business_account_id
        AND (ba.owner_user_id = v_user_id OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = ba.id AND bm.user_id = v_user_id
        ))
    ) THEN
      RAISE EXCEPTION 'business_identity_invalid' USING errcode = 'B0001';
    END IF;
  END IF;

  -- Rate Limiting: max 5 messages per 10 seconds
  SELECT COUNT(*)::integer INTO v_recent_count
  FROM public.community_chat_messages
  WHERE community_id = p_community_id
    AND user_id = v_user_id
    AND created_at >= (now() - interval '10 seconds');

  IF v_recent_count >= 5 THEN
    RAISE EXCEPTION 'community_content_rate_limited' USING errcode = 'RL001';
  END IF;

  -- Basic Moderation
  v_normalized_msg := trim(p_message);
  IF length(v_normalized_msg) = 0 THEN
    RAISE EXCEPTION 'empty_message' USING errcode = 'MOD08';
  END IF;

  IF v_normalized_msg ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' THEN
    RAISE EXCEPTION 'community_content_moderation_blocked' USING errcode = 'MOD01';
  END IF;

  IF v_normalized_msg ~ '([a-z0-9])\1{5,}' THEN
    RAISE EXCEPTION 'community_content_moderation_blocked' USING errcode = 'MOD03';
  END IF;

  INSERT INTO public.community_chat_messages (
    community_id,
    user_id,
    business_account_id,
    message,
    reply_to_message_id
  ) VALUES (
    p_community_id,
    CASE WHEN p_business_account_id IS NULL THEN v_user_id ELSE NULL END,
    p_business_account_id,
    p_message,
    p_reply_to_message_id
  ) RETURNING id INTO v_msg_id;

  -- Update reads table for self
  INSERT INTO public.community_chat_reads (community_id, user_id, last_read_message_id, last_read_at)
  VALUES (p_community_id, v_user_id, v_msg_id, now())
  ON CONFLICT (community_id, user_id) DO UPDATE
  SET last_read_message_id = v_msg_id, last_read_at = now();

  RETURN v_msg_id;
END;
$$;

-- B. Chat: Delete Own Message or Moderate
CREATE OR REPLACE FUNCTION public.delete_community_chat_message(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_msg_user_id uuid;
  v_community_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT user_id, community_id INTO v_msg_user_id, v_community_id
  FROM public.community_chat_messages
  WHERE id = p_message_id;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'community_message_not_found' USING errcode = 'MSG01';
  END IF;

  -- Owner or Manager deletion
  IF v_msg_user_id = v_user_id OR public.has_community_permission(v_community_id, v_user_id, 'manage_members') THEN
    UPDATE public.community_chat_messages
    SET is_deleted = true, message = '[Bu mesaj silindi]', updated_at = now()
    WHERE id = p_message_id;
  ELSE
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
END;
$$;

-- C. Posts: Create Post (Includes Pin/Push option for Announcements)
CREATE OR REPLACE FUNCTION public.create_community_post(
  p_community_id uuid,
  p_content text,
  p_type text,
  p_image_urls text[],
  p_business_account_id uuid default null,
  p_pin_announcement boolean default false,
  p_send_announcement_push boolean default false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_post_id uuid;
  v_normalized_content text;
  v_image_url text;
  v_role text;
  v_member_rec record;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  -- Membership check
  IF NOT EXISTS (
    SELECT 1 FROM public.community_memberships
    WHERE community_id = p_community_id AND user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
  END IF;

  -- Business identity validation
  IF p_business_account_id IS NOT NULL THEN
    IF p_type = 'announcement' THEN
      RAISE EXCEPTION 'community_announcement_permission_required' USING errcode = 'C0007';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.community_memberships
      WHERE community_id = p_community_id AND business_account_id = p_business_account_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = p_business_account_id
        AND (ba.owner_user_id = v_user_id OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = ba.id AND bm.user_id = v_user_id
        ))
    ) THEN
      RAISE EXCEPTION 'business_identity_invalid' USING errcode = 'B0001';
    END IF;
  END IF;

  -- Content moderation
  v_normalized_content := trim(coalesce(p_content, ''));
  IF length(v_normalized_content) = 0 AND (p_image_urls IS NULL OR array_length(p_image_urls, 1) = 0) THEN
    RAISE EXCEPTION 'empty_post' USING errcode = 'MOD09';
  END IF;

  IF length(v_normalized_content) > 0 THEN
    IF v_normalized_content ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' THEN
      RAISE EXCEPTION 'community_content_moderation_blocked' USING errcode = 'MOD01';
    END IF;

    IF v_normalized_content ~ '([a-z0-9])\1{5,}' THEN
      RAISE EXCEPTION 'community_content_moderation_blocked' USING errcode = 'MOD03';
    END IF;
  END IF;

  -- Announcement authority check
  IF p_type = 'announcement' THEN
    IF NOT public.has_community_permission(p_community_id, v_user_id, 'manage_members') THEN
      RAISE EXCEPTION 'community_announcement_permission_required' USING errcode = 'C0007';
    END IF;

    -- Manage Pinned Announcements Limit: Max 1 pinned announcement
    IF p_pin_announcement THEN
      UPDATE public.community_posts
      SET is_pinned = false
      WHERE community_id = p_community_id AND is_pinned = true;
    END IF;
  END IF;

  INSERT INTO public.community_posts (
    community_id,
    user_id,
    business_account_id,
    type,
    content,
    is_pinned
  ) VALUES (
    p_community_id,
    CASE WHEN p_business_account_id IS NULL THEN v_user_id ELSE NULL END,
    p_business_account_id,
    p_type,
    p_content,
    CASE WHEN p_type = 'announcement' THEN p_pin_announcement ELSE false END
  ) RETURNING id INTO v_post_id;

  -- Insert images
  IF p_image_urls IS NOT NULL AND array_length(p_image_urls, 1) > 0 THEN
    FOREACH v_image_url IN ARRAY p_image_urls LOOP
      INSERT INTO public.community_post_images (post_id, image_url)
      VALUES (v_post_id, v_image_url);
    END LOOP;
  END IF;

  -- Handle announcement notifications
  IF p_type = 'announcement' AND p_send_announcement_push THEN
    FOR v_member_rec IN
      SELECT user_id FROM public.community_memberships
      WHERE community_id = p_community_id AND status = 'active' AND user_id IS NOT NULL AND user_id <> v_user_id
    LOOP
      INSERT INTO public.notifications (
        recipient_id,
        actor_id,
        type,
        title,
        body,
        entity_type,
        entity_id,
        metadata
      ) VALUES (
        v_member_rec.user_id,
        v_user_id,
        'community_announcement',
        'Topluluk Duyurusu',
        substring(v_normalized_content from 1 for 100),
        'community_post',
        v_post_id::text,
        jsonb_build_object('community_id', p_community_id, 'post_id', v_post_id)
      );
    END LOOP;
  END IF;

  RETURN v_post_id;
END;
$$;

-- D. Posts: Edit / Update Post
CREATE OR REPLACE FUNCTION public.update_community_post(
  p_post_id uuid,
  p_content text,
  p_image_urls text[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_post_user_id uuid;
  v_normalized_content text;
  v_image_url text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT user_id INTO v_post_user_id
  FROM public.community_posts
  WHERE id = p_post_id AND is_deleted = false;

  IF v_post_user_id IS NULL THEN
    RAISE EXCEPTION 'community_post_not_found' USING errcode = 'PST01';
  END IF;

  IF v_post_user_id <> v_user_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  v_normalized_content := trim(coalesce(p_content, ''));
  IF length(v_normalized_content) = 0 AND (p_image_urls IS NULL OR array_length(p_image_urls, 1) = 0) THEN
    RAISE EXCEPTION 'empty_post' USING errcode = 'MOD09';
  END IF;

  IF length(v_normalized_content) > 0 THEN
    IF v_normalized_content ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' THEN
      RAISE EXCEPTION 'community_content_moderation_blocked' USING errcode = 'MOD01';
    END IF;
  END IF;

  UPDATE public.community_posts
  SET content = p_content, updated_at = now()
  WHERE id = p_post_id;

  DELETE FROM public.community_post_images WHERE post_id = p_post_id;
  IF p_image_urls IS NOT NULL AND array_length(p_image_urls, 1) > 0 THEN
    FOREACH v_image_url IN ARRAY p_image_urls LOOP
      INSERT INTO public.community_post_images (post_id, image_url)
      VALUES (p_post_id, v_image_url);
    END LOOP;
  END IF;
END;
$$;

-- E. Posts: Soft Delete Post
CREATE OR REPLACE FUNCTION public.delete_community_post(p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_post_user_id uuid;
  v_community_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT user_id, community_id INTO v_post_user_id, v_community_id
  FROM public.community_posts
  WHERE id = p_post_id AND is_deleted = false;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'community_post_not_found' USING errcode = 'PST01';
  END IF;

  IF v_post_user_id = v_user_id OR public.has_community_permission(v_community_id, v_user_id, 'manage_members') THEN
    UPDATE public.community_posts
    SET is_deleted = true, is_pinned = false, updated_at = now()
    WHERE id = p_post_id;
  ELSE
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
END;
$$;

-- F. Posts: Pin / Unpin Post
CREATE OR REPLACE FUNCTION public.pin_community_post(p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_community_id uuid;
  v_type text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT community_id, type INTO v_community_id, v_type
  FROM public.community_posts
  WHERE id = p_post_id AND is_deleted = false;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'community_post_not_found' USING errcode = 'PST01';
  END IF;

  IF v_type <> 'announcement' THEN
    RAISE EXCEPTION 'only_announcements_can_be_pinned' USING errcode = 'C0008';
  END IF;

  IF NOT public.has_community_permission(v_community_id, v_user_id, 'manage_members') THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  -- Unpin all other posts in community
  UPDATE public.community_posts
  SET is_pinned = false
  WHERE community_id = v_community_id AND is_pinned = true;

  UPDATE public.community_posts
  SET is_pinned = true, updated_at = now()
  WHERE id = p_post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.unpin_community_post(p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_community_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.community_posts
  WHERE id = p_post_id AND is_deleted = false;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'community_post_not_found' USING errcode = 'PST01';
  END IF;

  IF NOT public.has_community_permission(v_community_id, v_user_id, 'manage_members') THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  UPDATE public.community_posts
  SET is_pinned = false, updated_at = now()
  WHERE id = p_post_id;
END;
$$;

-- G. Comments: Create Comment
CREATE OR REPLACE FUNCTION public.create_community_comment(
  p_post_id uuid,
  p_content text,
  p_business_account_id uuid default null
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_community_id uuid;
  v_comment_id uuid;
  v_normalized_content text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.community_posts
  WHERE id = p_post_id AND is_deleted = false;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'community_post_not_found' USING errcode = 'PST01';
  END IF;

  -- Membership check
  IF NOT EXISTS (
    SELECT 1 FROM public.community_memberships
    WHERE community_id = v_community_id AND user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
  END IF;

  -- Business identity check
  IF p_business_account_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.community_memberships
      WHERE community_id = v_community_id AND business_account_id = p_business_account_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = p_business_account_id
        AND (ba.owner_user_id = v_user_id OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = ba.id AND bm.user_id = v_user_id
        ))
    ) THEN
      RAISE EXCEPTION 'business_identity_invalid' USING errcode = 'B0001';
    END IF;
  END IF;

  v_normalized_content := trim(p_content);
  IF length(v_normalized_content) = 0 THEN
    RAISE EXCEPTION 'empty_comment' USING errcode = 'MOD10';
  END IF;

  IF v_normalized_content ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' THEN
    RAISE EXCEPTION 'community_content_moderation_blocked' USING errcode = 'MOD01';
  END IF;

  INSERT INTO public.community_comments (
    post_id,
    user_id,
    business_account_id,
    content
  ) VALUES (
    p_post_id,
    CASE WHEN p_business_account_id IS NULL THEN v_user_id ELSE NULL END,
    p_business_account_id,
    p_content
  ) RETURNING id INTO v_comment_id;

  RETURN v_comment_id;
END;
$$;

-- H. Comments: Delete Comment
CREATE OR REPLACE FUNCTION public.delete_community_comment(p_comment_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_comment_user_id uuid;
  v_post_id uuid;
  v_community_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT user_id, post_id INTO v_comment_user_id, v_post_id
  FROM public.community_comments
  WHERE id = p_comment_id AND is_deleted = false;

  IF v_post_id IS NULL THEN
    RAISE EXCEPTION 'community_comment_not_found' USING errcode = 'CMT01';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.community_posts
  WHERE id = v_post_id;

  IF v_comment_user_id = v_user_id OR public.has_community_permission(v_community_id, v_user_id, 'manage_members') THEN
    UPDATE public.community_comments
    SET is_deleted = true, updated_at = now()
    WHERE id = p_comment_id;
  ELSE
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
END;
$$;

-- I. Reactions: Toggle Post Reaction
CREATE OR REPLACE FUNCTION public.toggle_community_post_reaction(
  p_post_id uuid,
  p_emoji text,
  p_business_account_id uuid default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_community_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.community_posts
  WHERE id = p_post_id AND is_deleted = false;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'community_post_not_found' USING errcode = 'PST01';
  END IF;

  -- Membership check
  IF NOT EXISTS (
    SELECT 1 FROM public.community_memberships
    WHERE community_id = v_community_id AND user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
  END IF;

  -- Business account verification
  IF p_business_account_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.community_memberships
      WHERE community_id = v_community_id AND business_account_id = p_business_account_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = p_business_account_id
        AND (ba.owner_user_id = v_user_id OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = ba.id AND bm.user_id = v_user_id
        ))
    ) THEN
      RAISE EXCEPTION 'business_identity_invalid' USING errcode = 'B0001';
    END IF;
  END IF;

  -- Toggle: Delete if exists, insert if not
  IF p_business_account_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.community_post_reactions
      WHERE post_id = p_post_id AND business_account_id = p_business_account_id AND emoji = p_emoji
    ) THEN
      DELETE FROM public.community_post_reactions
      WHERE post_id = p_post_id AND business_account_id = p_business_account_id AND emoji = p_emoji;
    ELSE
      INSERT INTO public.community_post_reactions (post_id, business_account_id, emoji)
      VALUES (p_post_id, p_business_account_id, p_emoji);
    END IF;
  ELSE
    IF EXISTS (
      SELECT 1 FROM public.community_post_reactions
      WHERE post_id = p_post_id AND user_id = v_user_id AND emoji = p_emoji
    ) THEN
      DELETE FROM public.community_post_reactions
      WHERE post_id = p_post_id AND user_id = v_user_id AND emoji = p_emoji;
    ELSE
      INSERT INTO public.community_post_reactions (post_id, user_id, emoji)
      VALUES (p_post_id, v_user_id, p_emoji);
    END IF;
  END IF;
END;
$$;

-- J. Reactions: Toggle Chat Message Reaction
CREATE OR REPLACE FUNCTION public.toggle_community_chat_reaction(
  p_message_id uuid,
  p_emoji text,
  p_business_account_id uuid default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_community_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.community_chat_messages
  WHERE id = p_message_id AND is_deleted = false;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'community_message_not_found' USING errcode = 'MSG01';
  END IF;

  -- Membership check
  IF NOT EXISTS (
    SELECT 1 FROM public.community_memberships
    WHERE community_id = v_community_id AND user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
  END IF;

  -- Business verification
  IF p_business_account_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.community_memberships
      WHERE community_id = v_community_id AND business_account_id = p_business_account_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'community_membership_required' USING errcode = 'C0004';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = p_business_account_id
        AND (ba.owner_user_id = v_user_id OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = ba.id AND bm.user_id = v_user_id
        ))
    ) THEN
      RAISE EXCEPTION 'business_identity_invalid' USING errcode = 'B0001';
    END IF;
  END IF;

  -- Toggle Reaction
  IF p_business_account_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.community_chat_reactions
      WHERE message_id = p_message_id AND business_account_id = p_business_account_id AND emoji = p_emoji
    ) THEN
      DELETE FROM public.community_chat_reactions
      WHERE message_id = p_message_id AND business_account_id = p_business_account_id AND emoji = p_emoji;
    ELSE
      INSERT INTO public.community_chat_reactions (message_id, business_account_id, emoji)
      VALUES (p_message_id, p_business_account_id, p_emoji);
    END IF;
  ELSE
    IF EXISTS (
      SELECT 1 FROM public.community_chat_reactions
      WHERE message_id = p_message_id AND user_id = v_user_id AND emoji = p_emoji
    ) THEN
      DELETE FROM public.community_chat_reactions
      WHERE message_id = p_message_id AND user_id = v_user_id AND emoji = p_emoji;
    ELSE
      INSERT INTO public.community_chat_reactions (message_id, user_id, emoji)
      VALUES (p_message_id, v_user_id, p_emoji);
    END IF;
  END IF;
END;
$$;

-- K. Mute / Unmute Community Chat
CREATE OR REPLACE FUNCTION public.mute_community_chat(
  p_community_id uuid,
  p_mute boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  IF p_mute THEN
    INSERT INTO public.community_chat_mutes (community_id, user_id)
    VALUES (p_community_id, v_user_id)
    ON CONFLICT (community_id, user_id) DO NOTHING;
  ELSE
    DELETE FROM public.community_chat_mutes
    WHERE community_id = p_community_id AND user_id = v_user_id;
  END IF;
END;
$$;

-- L. Mark Chat Read Message
CREATE OR REPLACE FUNCTION public.mark_community_chat_read(
  p_community_id uuid,
  p_message_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_msg_exists boolean;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  INSERT INTO public.community_chat_reads (community_id, user_id, last_read_message_id, last_read_at)
  VALUES (p_community_id, v_user_id, p_message_id, now())
  ON CONFLICT (community_id, user_id) DO UPDATE
  SET last_read_message_id = p_message_id, last_read_at = now();
END;
$$;

-- M. Community Event Recurrence: Atomic Creation of Community Recurring Event Series (quota validated via events trigger)
CREATE OR REPLACE FUNCTION public.create_community_recurring_event_series(
  p_community_id uuid,
  p_pattern_type text,
  p_pattern_metadata jsonb,
  p_event_data jsonb,
  p_dates timestamptz[],
  p_creation_request_ids uuid[],
  p_community_access text DEFAULT 'public'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_series_id uuid;
  v_date timestamptz;
  v_user_id uuid := auth.uid();
  v_idx integer;
  v_req_id uuid;
  v_existing_series_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING errcode = '42501';
  END IF;

  -- Verify community creation permission
  IF NOT public.has_community_permission(p_community_id, v_user_id, 'manage_members') THEN
    RAISE EXCEPTION 'community_event_creation_permission_required' USING errcode = 'C0005';
  END IF;

  -- Idempotency check: if first request ID already exists, return series ID
  IF p_creation_request_ids IS NOT NULL AND array_length(p_creation_request_ids, 1) > 0 THEN
    SELECT series_id INTO v_existing_series_id
    FROM public.events
    WHERE host_id = v_user_id
      AND creation_request_id = p_creation_request_ids[1]
    LIMIT 1;

    IF v_existing_series_id IS NOT NULL THEN
      RETURN v_existing_series_id;
    END IF;
  END IF;

  -- Date checks
  IF p_dates IS NULL OR array_length(p_dates, 1) = 0 THEN
    RAISE EXCEPTION 'empty_dates' USING errcode = 'C0009';
  END IF;

  IF array_length(p_dates, 1) > 30 THEN
    RAISE EXCEPTION 'max_occurrences_exceeded' USING errcode = 'C0010';
  END IF;

  FOREACH v_date IN ARRAY p_dates LOOP
    IF v_date > (now() + interval '180 days') THEN
      RAISE EXCEPTION 'horizon_exceeded' USING errcode = 'C0011';
    END IF;
    IF v_date < now() THEN
      RAISE EXCEPTION 'past_date_not_allowed' USING errcode = 'C0012';
    END IF;
  END LOOP;

  -- Insert recurring series
  INSERT INTO public.event_recurring_series (
    community_id,
    pattern_type,
    pattern_metadata
  ) VALUES (
    p_community_id,
    p_pattern_type,
    p_pattern_metadata
  ) RETURNING id INTO v_series_id;

  -- Insert events (enforces creation trigger and moderation/quota triggers)
  FOR v_idx IN 1..array_length(p_dates, 1) LOOP
    v_date := p_dates[v_idx];
    v_req_id := NULL;
    IF p_creation_request_ids IS NOT NULL AND array_length(p_creation_request_ids, 1) >= v_idx THEN
      v_req_id := p_creation_request_ids[v_idx];
    END IF;

    INSERT INTO public.events (
      host_id,
      organizer_type,
      title,
      description,
      activity_type,
      location_name,
      latitude,
      longitude,
      capacity,
      duration_minutes,
      participant_requirements,
      event_date,
      series_id,
      creation_request_id,
      event_start_time,
      event_end_time,
      community_id,
      community_access
    ) VALUES (
      v_user_id,
      'user', -- hosted personally by creator
      p_event_data->>'title',
      p_event_data->>'description',
      p_event_data->>'activity_type',
      p_event_data->>'location_name',
      (p_event_data->>'latitude')::double precision,
      (p_event_data->>'longitude')::double precision,
      (p_event_data->>'capacity')::integer,
      COALESCE((p_event_data->>'duration_minutes')::integer, 60),
      COALESCE(p_event_data->'participant_requirements', '{}'::jsonb),
      v_date,
      v_series_id,
      v_req_id,
      p_event_data->>'event_start_time',
      p_event_data->>'event_end_time',
      p_community_id,
      p_community_access
    );
  END LOOP;

  RETURN v_series_id;
END;
$$;

-- N. Reconcile Public to Members-only Event change safely (identifies non-members and raises error or reconciles if previewed)
CREATE OR REPLACE FUNCTION public.reconcile_event_visibility_change(
  p_event_id uuid,
  p_new_community_access text,
  p_execute_reconciliation boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_community_id uuid;
  v_non_member_count integer := 0;
  v_non_members jsonb := '[]'::jsonb;
  v_rec record;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING errcode = '42501';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.events
  WHERE id = p_event_id;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'event_not_linked_to_community' USING errcode = 'C0013';
  END IF;

  -- Verify manager permission
  IF NOT public.has_community_permission(v_community_id, v_user_id, 'manage_members') THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  -- Find participants of event who are NOT active members of the community
  FOR v_rec IN
    SELECT ep.user_id, pr.first_name, pr.username
    FROM public.event_participants ep
    LEFT JOIN public.profiles pr ON pr.user_id = ep.user_id
    WHERE ep.event_id = p_event_id
      AND ep.role = 'participant'
      AND ep.attendance_status IN ('confirmed', 'waitlisted', 'planned', 'checked_in', 'pending_confirmation')
      AND NOT EXISTS (
        SELECT 1 FROM public.community_memberships cm
        WHERE cm.community_id = v_community_id
          AND cm.user_id = ep.user_id
          AND cm.status = 'active'
      )
  LOOP
    v_non_member_count := v_non_member_count + 1;
    v_non_members := v_non_members || jsonb_build_object(
      'user_id', v_rec.user_id,
      'first_name', v_rec.first_name,
      'username', v_rec.username
    );
  END LOOP;

  -- If previewing, or count is 0, return details
  IF NOT p_execute_reconciliation OR v_non_member_count = 0 THEN
    RETURN json_build_object(
      'non_member_count', v_non_member_count,
      'non_members', v_non_members,
      'ready_to_switch', v_non_member_count = 0
    );
  END IF;

  -- Reconcile: Cancel requests and status for non-members
  UPDATE public.event_join_requests
  SET status = 'cancelled', updated_at = now()
  WHERE event_id = p_event_id
    AND status = 'pending'
    AND user_id IN (
      SELECT (value->>'user_id')::uuid
      FROM jsonb_array_elements(v_non_members)
    );

  UPDATE public.event_participants
  SET attendance_status = 'cancelled', updated_at = now(), role = 'left'
  WHERE event_id = p_event_id
    AND attendance_status IN ('confirmed', 'waitlisted', 'planned', 'checked_in', 'pending_confirmation')
    AND user_id IN (
      SELECT (value->>'user_id')::uuid
      FROM jsonb_array_elements(v_non_members)
    );

  -- Recount event approved counts
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

  -- Change access type on event
  UPDATE public.events
  SET community_access = p_new_community_access, updated_at = now()
  WHERE id = p_event_id;

  RETURN json_build_object(
    'non_member_count', v_non_member_count,
    'reconciled', true
  );
END;
$$;

-- Grant executes
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
