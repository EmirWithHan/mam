-- Reschedule pg_cron push worker job to pass the aligned worker secret securely
SELECT cron.unschedule('mam_push_worker_every_minute');

SELECT cron.schedule(
  'mam_push_worker_every_minute',
  '* * * * *',
  $$
  SELECT net.http_post(
    url := 'https://exzwwvjfudevpycpypkf.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-worker-secret', COALESCE((SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'reconcile_push_worker_secret'), '')
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);

-- Update check constraint on public.notifications to support the 'message' notification type
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
      'message'
    )
  );

-- Redefine send_direct_message to insert into both push_notification_outbox AND notifications
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
  v_message_id uuid;
  v_created_at timestamptz;
  v_sender_name text;
  v_trimmed_body text;
  v_result jsonb;
BEGIN
  v_current_user_id := auth.uid();
  if v_current_user_id is null then
    raise exception 'Kimlik doğrulama hatası.';
  end if;

  v_trimmed_body := btrim(p_body);
  if v_trimmed_body is null or length(v_trimmed_body) = 0 then
    raise exception 'Mesaj boş olamaz.';
  end if;

  if length(v_trimmed_body) > 2000 then
    raise exception 'Mesaj çok uzun (en fazla 2000 karakter).';
  end if;

  -- Get other participant
  SELECT user_id
  INTO v_other_user_id
  FROM public.direct_conversation_participants
  WHERE conversation_id = p_conversation_id
    AND user_id <> v_current_user_id;

  if v_other_user_id is null then
    raise exception 'Konuşma bulunamadı veya katılımcı değilsiniz.';
  end if;

  -- Check blocks
  if exists (
    SELECT 1
    from public.blocks b
    where (b.blocker_id = v_current_user_id and b.blocked_id = v_other_user_id)
       or (b.blocker_id = v_other_user_id and b.blocked_id = v_current_user_id)
  ) then
    raise exception 'Engellenmiş bir kullanıcıyla mesajlaşamazsınız.';
  end if;

  if p_reply_to_message_id is not null then
    if not exists (
      SELECT 1
      from public.direct_messages dm
      where dm.id = p_reply_to_message_id
        and dm.conversation_id = p_conversation_id
    ) then
      raise exception 'Geçersiz yanıt mesajı.';
    end if;
  end if;

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
    last_message_preview = substring(v_trimmed_body from 1 for 100),
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

  if v_sender_name is null or length(btrim(v_sender_name)) = 0 then
    v_sender_name := 'Bir kullanıcı';
  end if;

  -- Insert in-app notification (deduplicated by message_id in metadata)
  if to_regclass('public.notifications') is not null then
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
      v_other_user_id,
      v_current_user_id,
      'message',
      v_sender_name,
      'Sana bir mesaj gönderdi',
      'direct_message',
      p_conversation_id,
      jsonb_build_object('conversation_id', p_conversation_id, 'message_id', v_message_id),
      false
    );
  end if;

  -- Insert push notification to outbox
  if to_regclass('public.push_notification_outbox') is not null then
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
  end if;

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

REVOKE EXECUTE ON FUNCTION public.send_direct_message(uuid, text, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.send_direct_message(uuid, text, uuid) TO authenticated;

-- Create trigger on public.event_messages for in-app and push notifications
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
    SELECT DISTINCT u.user_id from (
      SELECT user_id from public.event_participants WHERE event_id = new.event_id AND removed_at IS NULL
      UNION
      SELECT host_id as user_id from public.events WHERE id = new.event_id
    ) u WHERE u.user_id <> new.sender_id
  LOOP
    -- Insert in-app notification (deduplicated by message_id in metadata)
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
      v_recipient_id,
      new.sender_id,
      'message',
      v_sender_name,
      COALESCE(v_event_title, 'Etkinlik') || ' grubunda yeni bir mesaj gönderdi',
      'event',
      new.event_id,
      jsonb_build_object('event_id', new.event_id, 'message_id', new.id),
      false
    );

    -- Insert push notification
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
  END LOOP;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_event_message_insert ON public.event_messages;
CREATE TRIGGER trg_on_event_message_insert
AFTER INSERT ON public.event_messages
FOR EACH ROW
EXECUTE FUNCTION public.on_event_message_insert();

REVOKE EXECUTE ON FUNCTION public.on_event_message_insert() FROM public;
