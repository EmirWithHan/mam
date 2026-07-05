-- Migration: Push-only messages and faster push dispatch trigger
-- Idempotency: Drop and recreate functions/triggers safely

-- 1. Create immediate push dispatch trigger function
CREATE OR REPLACE FUNCTION public.trigger_immediate_push_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
BEGIN
  -- Safe best-effort execution to prevent blocking original transaction
  BEGIN
    SELECT decrypted_secret
    INTO v_secret
    FROM vault.decrypted_secrets
    WHERE name = 'reconcile_push_worker_secret'
    LIMIT 1;

    PERFORM net.http_post(
      url := 'https://exzwwvjfudevpycpypkf.supabase.co/functions/v1/send-push-notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-worker-secret', COALESCE(v_secret, '')
      ),
      body := '{}'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    -- Best-effort only: raise warning but do not raise exception
    RAISE WARNING 'Immediate push dispatch failed: %', SQLERRM;
  END;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_immediate_push_dispatch ON public.push_notification_outbox;
CREATE TRIGGER trg_immediate_push_dispatch
AFTER INSERT ON public.push_notification_outbox
FOR EACH STATEMENT
EXECUTE FUNCTION public.trigger_immediate_push_dispatch();

-- 2. Redefine queue_push_for_notification to whitelist all approved push-eligible types (non-message types)
CREATE OR REPLACE FUNCTION public.queue_push_for_notification()
RETURNS trigger
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
  -- Exclude trigger updates if not in eligible list
  IF new.type NOT IN (
    'event_join_request',
    'event_join_approved',
    'event_join_rejected',
    'event_join_cancelled',
    'event_left',
    'event_updated',
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
    'follow_request',
    'follow_request_approved',
    'follow_request_rejected',
    'follow',
    'message'
  ) THEN
    RETURN new;
  END IF;

  -- Mute check for community chat mentions
  IF new.type IN ('community_chat_mention', 'community_announcement', 'community_members_only_event') THEN
    v_community_id := (new.metadata->>'community_id')::uuid;
    IF v_community_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.community_chat_mutes
        WHERE community_id = v_community_id
          AND user_id = new.recipient_id
      ) INTO v_is_muted;
    END IF;
  END IF;

  -- Mute check for event messages
  IF new.type = 'message' AND new.entity_type = 'event' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.chat_mutes
      WHERE event_id = new.entity_id::uuid
        AND user_id = new.recipient_id
    ) INTO v_is_muted;
  END IF;

  IF v_is_muted THEN
    RETURN new;
  END IF;

  v_body := nullif(btrim(coalesce(new.body, '')), '');
  v_title := nullif(btrim(coalesce(new.title, '')), '');

  IF v_body IS NULL THEN
    v_body := 'Yeni bir bildiriminiz var.';
  END IF;
  IF v_title IS NULL THEN
    v_title := 'Akanzi';
  END IF;

  -- Customize titles/bodies for message push notifications (retaining historical fallback check)
  IF new.type = 'message' THEN
    IF new.entity_type = 'direct_message' THEN
      v_title := v_title || ' sana mesaj gönderdi';
      v_body := 'Yeni bir mesajın var';
    ELSIF new.entity_type = 'event' THEN
      v_title := v_title || ' (' || COALESCE((SELECT title FROM public.events WHERE id = new.entity_id::uuid), 'Etkinlik') || ')';
      v_body := 'Yeni bir grup mesajın var';
    END IF;
  END IF;

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
    COALESCE(new.metadata, '{}'::jsonb)
  )
  ON CONFLICT DO NOTHING;

  RETURN new;
END;
$$;

-- 3. Redefine send_direct_message to insert push directly to outbox and completely bypass in-app notifications
CREATE OR REPLACE FUNCTION public.send_direct_message(
  p_conversation_id uuid,
  p_body text,
  p_reply_to_message_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_current_user_id uuid;
  v_other_user_id uuid;
  v_sender_name text;
  v_message_id uuid;
  v_created_at timestamptz;
  v_trimmed_body text;
  v_result jsonb;
BEGIN
  v_current_user_id := auth.uid();
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'Kimlik doğrulama hatası.';
  END IF;

  IF p_conversation_id IS NULL THEN
    RAISE EXCEPTION 'Konuşma ID belirtilmelidir.';
  END IF;

  v_trimmed_body := btrim(COALESCE(p_body, ''));
  IF length(v_trimmed_body) = 0 THEN
    RAISE EXCEPTION 'Boş mesaj gönderilemez.';
  END IF;

  IF length(v_trimmed_body) > 2000 THEN
    RAISE EXCEPTION 'Mesaj çok uzun (en fazla 2000 karakter).';
  END IF;

  -- Verify current user participation
  IF NOT EXISTS (
    SELECT 1
    FROM public.direct_conversation_participants cp
    WHERE cp.conversation_id = p_conversation_id
      AND cp.user_id = v_current_user_id
  ) THEN
    RAISE EXCEPTION 'Konuşma bulunamadı veya katılımcı değilsiniz.';
  END IF;

  -- Ensure DM has exactly 2 participants
  IF (
    SELECT count(1)
    FROM public.direct_conversation_participants cp
    WHERE cp.conversation_id = p_conversation_id
  ) <> 2 THEN
    RAISE EXCEPTION 'Geçersiz sohbet tipi.';
  END IF;

  -- Get other participant
  SELECT cp.user_id
  INTO v_other_user_id
  FROM public.direct_conversation_participants cp
  WHERE cp.conversation_id = p_conversation_id
    AND cp.user_id <> v_current_user_id
  LIMIT 1;

  IF v_other_user_id IS NULL THEN
    RAISE EXCEPTION 'Alıcı kullanıcı bulunamadı.';
  END IF;

  -- Check blocks
  IF EXISTS (
    SELECT 1
    FROM public.blocks b
    WHERE (b.blocker_id = v_current_user_id AND b.blocked_id = v_other_user_id)
       OR (b.blocker_id = v_other_user_id AND b.blocked_id = v_current_user_id)
  ) THEN
    RAISE EXCEPTION 'Engellenmiş bir kullanıcıyla mesajlaşamazsınız.';
  END IF;

  IF p_reply_to_message_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.direct_messages dm
      WHERE dm.id = p_reply_to_message_id
        AND dm.conversation_id = p_conversation_id
    ) THEN
      RAISE EXCEPTION 'Geçersiz yanıt mesajı.';
    END IF;
  END IF;

  INSERT INTO public.direct_messages (
    conversation_id,
    sender_user_id,
    body,
    reply_to_message_id
  )
  VALUES (
    p_conversation_id,
    v_current_user_id,
    v_trimmed_body,
    p_reply_to_message_id
  )
  RETURNING id, created_at INTO v_message_id, v_created_at;

  UPDATE public.direct_conversations
  SET
    last_message_at = v_created_at,
    last_message_preview = substring(v_trimmed_body FROM 1 FOR 100),
    updated_at = now()
  WHERE id = p_conversation_id;

  UPDATE public.direct_conversation_participants
  SET
    last_read_at = v_created_at,
    last_read_message_id = v_message_id
  WHERE conversation_id = p_conversation_id
    AND user_id = v_current_user_id;

  SELECT COALESCE(NULLIF(btrim(pr.first_name), ''), pr.username, 'Bir kullanıcı')
  INTO v_sender_name
  FROM public.profiles pr
  WHERE pr.user_id = v_current_user_id;

  IF v_sender_name IS NULL OR length(btrim(v_sender_name)) = 0 THEN
    v_sender_name := 'Bir kullanıcı';
  END IF;

  -- Insert push notification directly into outbox (avoid public.notifications)
  IF to_regclass('public.push_notification_outbox') IS NOT NULL THEN
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
      NULL,
      v_other_user_id,
      'direct_message',
      v_sender_name || ' sana mesaj gönderdi',
      'Yeni bir mesajın var',
      'direct_message',
      p_conversation_id::text,
      jsonb_build_object('conversation_id', p_conversation_id, 'message_id', v_message_id)
    );
  END IF;

  v_result := jsonb_build_object(
    'id', v_message_id,
    'conversation_id', p_conversation_id,
    'sender_user_id', v_current_user_id,
    'body', v_trimmed_body,
    'reply_to_message_id', p_reply_to_message_id,
    'created_at', v_created_at
  );

  RETURN v_result;
END;
$$;

-- 4. Redefine on_event_message_insert trigger function to insert push directly to outbox and completely bypass in-app notifications
CREATE OR REPLACE FUNCTION public.on_event_message_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_recipient_id uuid;
  v_sender_name text;
  v_event_title text;
  v_is_muted boolean;
BEGIN
  -- Fetch sender name
  SELECT COALESCE(NULLIF(btrim(pr.first_name), ''), pr.username, 'Bir kullanıcı')
  INTO v_sender_name
  FROM public.profiles pr
  WHERE pr.user_id = new.sender_id;

  -- Fetch event title
  SELECT title
  INTO v_event_title
  FROM public.events
  WHERE id = new.event_id;

  -- Loop through all active participants + host (excluding sender)
  FOR v_recipient_id IN
    SELECT DISTINCT u.user_id FROM (
      SELECT user_id FROM public.event_participants WHERE event_id = new.event_id AND removed_at IS NULL
      UNION
      SELECT host_id AS user_id FROM public.events WHERE id = new.event_id
    ) u WHERE u.user_id <> new.sender_id
  LOOP
    -- Chat mute check
    SELECT EXISTS (
      SELECT 1
      FROM public.chat_mutes
      WHERE event_id = new.event_id
        AND user_id = v_recipient_id
    ) INTO v_is_muted;

    IF NOT COALESCE(v_is_muted, false) THEN
      -- Insert push notification directly into outbox (avoid public.notifications)
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
        NULL,
        v_recipient_id,
        'event_chat',
        v_sender_name || ' (' || COALESCE(v_event_title, 'Etkinlik') || ')',
        'Yeni bir grup mesajın var',
        'event',
        new.event_id::text,
        jsonb_build_object('event_id', new.event_id, 'message_id', new.id)
      );
    END IF;
  END LOOP;

  RETURN new;
END;
$$;
