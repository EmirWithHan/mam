-- Gelişmiş Özellikler Veritabanı Şeması

-- 1. Katılımcı Mazeret ve Okundu Bilgisi Kolonları
ALTER TABLE public.event_participants 
  ADD COLUMN IF NOT EXISTS excuse_text text,
  ADD COLUMN IF NOT EXISTS excuse_submitted_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_read_message_id uuid;

-- 2. Sohbet Yanıt ve Metadata Kolonları
ALTER TABLE public.event_messages 
  ADD COLUMN IF NOT EXISTS reply_to_message_id uuid REFERENCES public.event_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- 3. Emoji İfadeleri Tablosu
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.event_messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (message_id, user_id)
);

-- 4. Mesaj Şikayet Tablosu
CREATE TABLE IF NOT EXISTS public.message_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.event_messages(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- 5. Sohbet Sessize Alma Tablosu
CREATE TABLE IF NOT EXISTS public.chat_mutes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id, event_id)
);

-- 6. Anket Tabloları
CREATE TABLE IF NOT EXISTS public.chat_polls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  creator_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question text NOT NULL,
  created_at timestamptz DEFAULT now(),
  closed_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.chat_poll_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES public.chat_polls(id) ON DELETE CASCADE,
  option_text text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.chat_poll_votes (
  poll_id uuid NOT NULL REFERENCES public.chat_polls(id) ON DELETE CASCADE,
  option_id uuid NOT NULL REFERENCES public.chat_poll_options(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (poll_id, user_id)
);

-- 7. Bildirim Kuyruğu Tablosu
CREATE TABLE IF NOT EXISTS public.chat_notifications_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.event_messages(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- RLS Etkinleştirme
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_notifications_queue ENABLE ROW LEVEL SECURITY;

-- RLS Politikaları
DROP POLICY IF EXISTS "React to messages if participant" ON public.message_reactions;
CREATE policy "React to messages if participant"
  ON public.message_reactions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.event_messages msg
      JOIN public.event_participants part ON part.event_id = msg.event_id
      WHERE msg.id = message_reactions.message_id
        AND part.user_id = auth.uid()
        AND part.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in')
    )
  )
  WITH CHECK (
    user_id = auth.uid()
  );

DROP POLICY IF EXISTS "Report messages if participant" ON public.message_reports;
CREATE policy "Report messages if participant"
  ON public.message_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    reporter_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.event_messages msg
      JOIN public.event_participants part ON part.event_id = msg.event_id
      WHERE msg.id = message_reports.message_id
        AND part.user_id = auth.uid()
        AND part.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in')
    )
  );

DROP POLICY IF EXISTS "Manage own mutes" ON public.chat_mutes;
CREATE policy "Manage own mutes"
  ON public.chat_mutes
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "View polls if participant" ON public.chat_polls;
CREATE policy "View polls if participant"
  ON public.chat_polls
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.event_participants part
      WHERE part.event_id = chat_polls.event_id
        AND part.user_id = auth.uid()
        AND part.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in')
    )
  );

DROP POLICY IF EXISTS "Create polls if participant" ON public.chat_polls;
CREATE policy "Create polls if participant"
  ON public.chat_polls
  FOR INSERT
  TO authenticated
  WITH CHECK (
    creator_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.event_participants part
      WHERE part.event_id = chat_polls.event_id
        AND part.user_id = auth.uid()
        AND part.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in')
    )
  );

DROP POLICY IF EXISTS "View poll options if participant" ON public.chat_poll_options;
CREATE policy "View poll options if participant"
  ON public.chat_poll_options
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_polls poll
      JOIN public.event_participants part ON part.event_id = poll.event_id
      WHERE poll.id = chat_poll_options.poll_id
        AND part.user_id = auth.uid()
        AND part.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in')
    )
  );

DROP POLICY IF EXISTS "Create poll options if poll creator" ON public.chat_poll_options;
CREATE policy "Create poll options if poll creator"
  ON public.chat_poll_options
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.chat_polls poll
      WHERE poll.id = chat_poll_options.poll_id
        AND poll.creator_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "View votes if participant" ON public.chat_poll_votes;
CREATE policy "View votes if participant"
  ON public.chat_poll_votes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_polls poll
      JOIN public.event_participants part ON part.event_id = poll.event_id
      WHERE poll.id = chat_poll_votes.poll_id
        AND part.user_id = auth.uid()
        AND part.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in')
    )
  );

DROP POLICY IF EXISTS "Vote if participant" ON public.chat_poll_votes;
CREATE policy "Vote if participant"
  ON public.chat_poll_votes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.chat_polls poll
      JOIN public.event_participants part ON part.event_id = poll.event_id
      WHERE poll.id = chat_poll_votes.poll_id
        AND part.user_id = auth.uid()
        AND part.attendance_status IN ('planned', 'attended', 'confirmed', 'checked_in')
    )
  );

-- RPC: İşletme Etkinliği Rezervasyonu
CREATE OR REPLACE FUNCTION public.reserve_business_event_participation(
  p_event_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_capacity_bucket text;
  v_next_status text;
  v_token text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT *
  INTO v_event
  FROM public.events
  WHERE id = p_event_id
  FOR UPDATE;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  IF COALESCE(v_event.organizer_type, 'user') <> 'business' THEN
    RAISE EXCEPTION 'not_business_event';
  END IF;

  IF v_event.event_date < now() THEN
    RAISE EXCEPTION 'event_past';
  END IF;

  -- Kapasite bucket hesabı
  v_capacity_bucket := public.event_capacity_bucket_for(p_event_id, v_user_id);

  IF v_capacity_bucket IS NULL THEN
    v_next_status := 'waitlisted';
  ELSE
    v_next_status := 'confirmed';
  END IF;

  -- Güvenli token üretimi
  v_token := md5(random()::text || clock_timestamp()::text)::text;

  -- Katılımcıyı ekle/güncelle
  INSERT INTO public.event_participants (
    event_id,
    user_id,
    role,
    attendance_status,
    capacity_bucket,
    check_in_token
  )
  VALUES (
    p_event_id,
    v_user_id,
    'participant',
    v_next_status,
    v_capacity_bucket,
    v_token
  )
  ON CONFLICT (event_id, user_id) DO UPDATE
  SET role = 'participant',
      attendance_status = v_next_status,
      capacity_bucket = v_capacity_bucket,
      check_in_token = COALESCE(public.event_participants.check_in_token, v_token);

  -- İstek kaydı oluştur/güncelle (tutarlılık için)
  INSERT INTO public.event_join_requests (
    event_id,
    user_id,
    status
  )
  VALUES (
    p_event_id,
    v_user_id,
    v_next_status
  )
  ON CONFLICT (event_id, user_id) DO UPDATE
  SET status = v_next_status,
      updated_at = now();

  -- Etkinliğin onaylı sayısını güncelle
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants participant
    WHERE participant.event_id = p_event_id
      and participant.role = 'participant'
      and participant.attendance_status = 'confirmed'
  )
  WHERE id = p_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_business_event_participation(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.reserve_business_event_participation(uuid) TO authenticated;

-- 8. QR Yoklama Doğrulama Fonksiyonu
CREATE OR REPLACE FUNCTION public.verify_and_check_in_participant(
  p_event_id uuid,
  p_user_id uuid,
  p_token text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_business_id uuid;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT *
  INTO v_event
  FROM public.events
  WHERE id = p_event_id;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  IF COALESCE(v_event.organizer_type, 'user') <> 'business' THEN
    RAISE EXCEPTION 'not_business_event';
  END IF;

  -- Get business account ID and verify ownership
  SELECT id INTO v_business_id
  FROM public.business_accounts
  WHERE owner_user_id = v_actor_id AND status = 'active'
  LIMIT 1;

  IF v_business_id IS NULL OR v_event.organizer_business_id <> v_business_id THEN
    RAISE EXCEPTION 'business_event_not_owned';
  END IF;

  SELECT *
  INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = p_user_id
    AND role = 'participant';

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  IF v_participant.attendance_status = 'checked_in' THEN
    RETURN 'already_checked_in';
  END IF;

  IF v_participant.attendance_status <> 'confirmed' THEN
    RAISE EXCEPTION 'participant_not_confirmed';
  END IF;

  IF v_participant.check_in_token IS NULL OR v_participant.check_in_token <> p_token THEN
    RAISE EXCEPTION 'invalid_token';
  END IF;

  -- Update attendance status
  UPDATE public.event_participants
  SET attendance_status = 'checked_in',
      checked_in_at = now(),
      checked_in_by = v_business_id
  WHERE event_id = p_event_id
    AND user_id = p_user_id
    AND role = 'participant';

  -- Update approved count on event
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in')
  )
  WHERE id = p_event_id;

  -- Apply trust score
  PERFORM public.apply_trust_score_event(
    p_user_id,
    v_actor_id,
    'business_event_checked_in',
    'event',
    p_event_id,
    jsonb_build_object('attendance_status', 'checked_in')
  );

  RETURN 'success';
END;
$$;

REVOKE ALL ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) TO authenticated;

-- Redefine get_event_public_participants with block filtering privacy guard
CREATE OR REPLACE FUNCTION public.get_event_public_participants(p_event_id text)
RETURNS TABLE (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  role text,
  attendance_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    participant.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    participant.role::text,
    participant.attendance_status::text
  FROM public.event_participants participant
  JOIN public.events event
    ON event.id = participant.event_id
  JOIN public.profiles profile
    ON profile.user_id = participant.user_id
  WHERE participant.event_id::text = p_event_id
    AND auth.uid() IS NOT NULL
    AND (
      participant.role = 'host'
      OR (
        participant.role = 'participant'
        AND (
          (
            COALESCE(event.organizer_type, 'user') = 'business'
            AND participant.attendance_status IN ('confirmed', 'checked_in')
          )
          OR (
            COALESCE(event.organizer_type, 'user') <> 'business'
            AND participant.attendance_status IN ('planned', 'attended')
          )
        )
      )
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.blocks block_rows
      WHERE (
        block_rows.blocker_id = auth.uid()
        AND block_rows.blocked_id = participant.user_id
      )
      OR (
        block_rows.blocker_id = participant.user_id
        AND block_rows.blocked_id = auth.uid()
      )
    );
$$;

REVOKE ALL ON FUNCTION public.get_event_public_participants(text) FROM public;
GRANT EXECUTE ON FUNCTION public.get_event_public_participants(text) TO authenticated;

-- 9. Ev Sahibi Yoklama ve Katılımcı Analitik RPC'si
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

  -- Verify if the actor is the host of the event
  SELECT EXISTS (
    SELECT 1 FROM public.event_participants
    WHERE event_id = p_event_id
      AND user_id = v_actor_id
      AND role = 'host'
  ) INTO v_is_host;

  IF NOT v_is_host THEN
    -- Or if they are owner of the business organizing the event
    SELECT EXISTS (
      SELECT 1 FROM public.events e
      JOIN public.business_accounts b ON b.id = e.organizer_business_id
      WHERE e.id = p_event_id
        AND b.owner_user_id = v_actor_id
        AND b.status = 'active'
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
    p.created_at as joined_at,
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

-- Redefine get_business_event_check_in_participants with excuse text and token columns
CREATE OR REPLACE FUNCTION public.get_business_event_check_in_participants(
  p_event_id uuid
)
RETURNS TABLE (
  user_id text,
  username text,
  tag text,
  first_name text,
  avatar_url text,
  attendance_status text,
  checked_in_at timestamptz,
  check_in_token text,
  excuse_text text,
  excuse_submitted_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    participant.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.avatar_url::text,
    participant.attendance_status::text,
    participant.checked_in_at,
    participant.check_in_token,
    participant.excuse_text,
    participant.excuse_submitted_at
  FROM public.events event
  JOIN public.business_accounts business
    ON business.id = event.organizer_business_id
    AND business.owner_user_id = auth.uid()
    AND business.status = 'active'
  JOIN public.event_participants participant
    ON participant.event_id = event.id
    AND participant.role = 'participant'
    AND participant.attendance_status IN ('confirmed', 'checked_in', 'no_show')
  JOIN public.profiles profile
    ON profile.user_id = participant.user_id
  WHERE event.id = p_event_id
    AND auth.uid() IS NOT NULL
    AND COALESCE(event.organizer_type, 'user') = 'business'
  ORDER BY
    participant.attendance_status = 'confirmed' DESC,
    profile.first_name,
    profile.username;
$$;

REVOKE ALL ON FUNCTION public.get_business_event_check_in_participants(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_business_event_check_in_participants(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';



