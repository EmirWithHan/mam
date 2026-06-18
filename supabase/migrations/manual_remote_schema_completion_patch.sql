-- Migration to support business event listing visibility and availability hours
-- 1. listing_expires_at: Business event listings should stop appearing in public lists after 24 hours.
-- 2. business_open_time / business_close_time: Opening and closing availability hours for business listings.

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS listing_expires_at timestamptz;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS business_open_time time;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS business_close_time time;

COMMENT ON COLUMN public.events.listing_expires_at IS 'Timestamp when the business listing expires and should be hidden from public discovery feeds (usually 24 hours after creation).';
COMMENT ON COLUMN public.events.business_open_time IS 'Opening hour for the business event availability.';
COMMENT ON COLUMN public.events.business_close_time IS 'Closing hour for the business event availability.';
-- Migration to support business profile defaults and business event creation fields
-- Adding business account defaults
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS longitude double precision;
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS working_hours jsonb;
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS amenities text[];

COMMENT ON COLUMN public.business_accounts.latitude IS 'Latitude of the business location for map default.';
COMMENT ON COLUMN public.business_accounts.longitude IS 'Longitude of the business location for map default.';
COMMENT ON COLUMN public.business_accounts.working_hours IS 'General working hours of the business profile.';
COMMENT ON COLUMN public.business_accounts.amenities IS 'List of facility features / amenities.';

-- Adding event-specific pricing and participation metadata
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_start_time time;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_end_time time;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price_type text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price_amount numeric;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price_currency text DEFAULT 'TRY';
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS listing_expires_at timestamptz;

COMMENT ON COLUMN public.events.event_start_time IS 'Event-specific start time.';
COMMENT ON COLUMN public.events.event_end_time IS 'Event-specific end time.';
COMMENT ON COLUMN public.events.price_type IS 'Pricing type (free, pay_at_business).';
COMMENT ON COLUMN public.events.price_amount IS 'Pricing amount if paid.';
COMMENT ON COLUMN public.events.price_currency IS 'Pricing currency (default TRY).';
COMMENT ON COLUMN public.events.listing_expires_at IS 'Timestamp when the business listing expires and should be hidden from public discovery feeds (usually 24 hours after creation).';
-- KatÄ±lÄ±mcÄ± yoklama ve doÄŸrulama alanlarÄ±
ALTER TABLE public.event_participants 
  ADD COLUMN IF NOT EXISTS check_in_token text UNIQUE,
  ADD COLUMN IF NOT EXISTS checked_in_by uuid REFERENCES public.business_accounts(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.event_participants.check_in_token IS 'KatÄ±lÄ±mcÄ±ya Ã¶zel Ã¼retilen gÃ¼venli QR check-in anahtarÄ±.';
COMMENT ON COLUMN public.event_participants.checked_in_by IS 'YoklamayÄ± alan iÅŸletme hesabÄ± IDsi.';
-- GeliÅŸmiÅŸ Ã–zellikler VeritabanÄ± ÅemasÄ±

-- 1. KatÄ±lÄ±mcÄ± Mazeret ve Okundu Bilgisi KolonlarÄ±
ALTER TABLE public.event_participants 
  ADD COLUMN IF NOT EXISTS excuse_text text,
  ADD COLUMN IF NOT EXISTS excuse_submitted_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_read_message_id uuid;

-- 2. Sohbet YanÄ±t ve Metadata KolonlarÄ±
ALTER TABLE public.event_messages 
  ADD COLUMN IF NOT EXISTS reply_to_message_id uuid REFERENCES public.event_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- 3. Emoji Ä°fadeleri Tablosu
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.event_messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (message_id, user_id)
);

-- 4. Mesaj Åikayet Tablosu
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

-- 6. Anket TablolarÄ±
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

-- 7. Bildirim KuyruÄŸu Tablosu
CREATE TABLE IF NOT EXISTS public.chat_notifications_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.event_messages(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- RLS EtkinleÅŸtirme
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_notifications_queue ENABLE ROW LEVEL SECURITY;

-- RLS PolitikalarÄ±
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

-- RPC: Ä°ÅŸletme EtkinliÄŸi Rezervasyonu
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

  -- Kapasite bucket hesabÄ±
  v_capacity_bucket := public.event_capacity_bucket_for(p_event_id, v_user_id);

  IF v_capacity_bucket IS NULL THEN
    v_next_status := 'waitlisted';
  ELSE
    v_next_status := 'confirmed';
  END IF;

  -- GÃ¼venli token Ã¼retimi
  v_token := md5(random()::text || clock_timestamp()::text)::text;

  -- KatÄ±lÄ±mcÄ±yÄ± ekle/gÃ¼ncelle
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

  -- Ä°stek kaydÄ± oluÅŸtur/gÃ¼ncelle (tutarlÄ±lÄ±k iÃ§in)
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

  -- EtkinliÄŸin onaylÄ± sayÄ±sÄ±nÄ± gÃ¼ncelle
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

-- 8. QR Yoklama DoÄŸrulama Fonksiyonu
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

-- 9. Ev Sahibi Yoklama ve KatÄ±lÄ±mcÄ± Analitik RPC'si
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



-- Direct Messaging tables and functions
create table if not exists public.direct_conversations (
  id uuid primary key default gen_random_uuid(),
  pair_key text not null unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  last_message_preview text
);

create table if not exists public.direct_conversation_participants (
  conversation_id uuid references public.direct_conversations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  last_read_message_id uuid,
  primary key (conversation_id, user_id)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.direct_conversations(id) on delete cascade,
  sender_user_id uuid references auth.users(id) on delete cascade,
  body text not null check (length(btrim(body)) > 0 and length(body) <= 2000),
  created_at timestamptz not null default now()
);

-- Allow notification_id to be null in push_notification_outbox for DM pushes
alter table public.push_notification_outbox alter column notification_id drop not null;

-- Indexes for performance
create index if not exists direct_conversation_participants_user_idx
  on public.direct_conversation_participants (user_id);

create index if not exists direct_messages_conversation_idx
  on public.direct_messages (conversation_id, created_at asc);

-- Enable RLS
alter table public.direct_conversations enable row level security;
alter table public.direct_conversation_participants enable row level security;
alter table public.direct_messages enable row level security;

-- Revoke anon and public table access
revoke all on public.direct_conversations from anon, public;
revoke all on public.direct_conversation_participants from anon, public;
revoke all on public.direct_messages from anon, public;

-- Grant SELECT only to authenticated (Writes are RPC-only)
grant select on public.direct_conversations to authenticated;
grant select on public.direct_conversation_participants to authenticated;
grant select on public.direct_messages to authenticated;

-- Helper function to check if user is participant (avoids RLS recursion)
create or replace function public.is_direct_conversation_participant(p_conversation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  return exists (
    select 1
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = auth.uid()
  );
end;
$$;

revoke execute on function public.is_direct_conversation_participant(uuid) from public, anon;
grant execute on function public.is_direct_conversation_participant(uuid) to authenticated;

-- Watertight RLS Policies using helper function to avoid recursion
drop policy if exists "Select conversations where participant" on public.direct_conversations;
create policy "Select conversations where participant"
on public.direct_conversations
for select
to authenticated
using (
  public.is_direct_conversation_participant(public.direct_conversations.id)
);

drop policy if exists "Select participants of own conversations" on public.direct_conversation_participants;
create policy "Select participants of own conversations"
on public.direct_conversation_participants
for select
to authenticated
using (
  public.is_direct_conversation_participant(public.direct_conversation_participants.conversation_id)
);

drop policy if exists "Update own participant row" on public.direct_conversation_participants;

drop policy if exists "Select messages in own conversations" on public.direct_messages;
create policy "Select messages in own conversations"
on public.direct_messages
for select
to authenticated
using (
  public.is_direct_conversation_participant(public.direct_messages.conversation_id)
);

-- RPC 1: get_or_create_direct_conversation
create or replace function public.get_or_create_direct_conversation(p_target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_user_id uuid;
  v_pair_key text;
  v_conversation_id uuid;
begin
  v_current_user_id := auth.uid();
  if v_current_user_id is null then
    raise exception 'Kimlik doÄŸrulama hatasÄ±.';
  end if;

  if p_target_user_id is null then
    raise exception 'AlÄ±cÄ± ID belirtilmelidir.';
  end if;

  if v_current_user_id = p_target_user_id then
    raise exception 'Kendi kendinize mesaj gÃ¶nderemezsiniz.';
  end if;

  -- Verify target user exists
  if not exists (
    select 1
    from public.profiles pr
    where pr.user_id = p_target_user_id
  ) then
    raise exception 'AlÄ±cÄ± kullanÄ±cÄ± bulunamadÄ±.';
  end if;

  -- Block check
  if exists (
    select 1
    from public.blocks b
    where (b.blocker_id = v_current_user_id and b.blocked_id = p_target_user_id)
       or (b.blocker_id = p_target_user_id and b.blocked_id = v_current_user_id)
  ) then
    raise exception 'Bu kullanÄ±cÄ±yla mesajlaÅŸamazsÄ±nÄ±z.';
  end if;

  -- Deterministic pair_key sorting
  if v_current_user_id < p_target_user_id then
    v_pair_key := v_current_user_id::text || ':' || p_target_user_id::text;
  else
    v_pair_key := p_target_user_id::text || ':' || v_current_user_id::text;
  end if;

  -- Find existing conversation
  select dc.id into v_conversation_id
  from public.direct_conversations dc
  where dc.pair_key = v_pair_key;

  if v_conversation_id is not null then
    return v_conversation_id;
  end if;

  -- Create new conversation
  insert into public.direct_conversations (pair_key, created_by)
  values (v_pair_key, v_current_user_id)
  returning id into v_conversation_id;

  -- Insert participants
  insert into public.direct_conversation_participants (conversation_id, user_id)
  values 
    (v_conversation_id, v_current_user_id),
    (v_conversation_id, p_target_user_id);

  return v_conversation_id;
exception
  when unique_violation then
    -- Handle concurrent insert race condition
    select dc.id into v_conversation_id
    from public.direct_conversations dc
    where dc.pair_key = v_pair_key;
    return v_conversation_id;
end;
$$;

-- RPC 2: send_direct_message
create or replace function public.send_direct_message(p_conversation_id uuid, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_user_id uuid;
  v_other_user_id uuid;
  v_sender_name text;
  v_message_id uuid;
  v_created_at timestamptz;
  v_trimmed_body text;
  v_result jsonb;
begin
  v_current_user_id := auth.uid();
  if v_current_user_id is null then
    raise exception 'Kimlik doÄŸrulama hatasÄ±.';
  end if;

  if p_conversation_id is null then
    raise exception 'KonuÅŸma ID belirtilmelidir.';
  end if;

  -- Trim and validate body
  v_trimmed_body := btrim(coalesce(p_body, ''));
  if length(v_trimmed_body) = 0 then
    raise exception 'BoÅŸ mesaj gÃ¶nderilemez.';
  end if;

  if length(v_trimmed_body) > 2000 then
    raise exception 'Mesaj 2000 karakterden uzun olamaz.';
  end if;

  -- Verify sender is participant
  if not exists (
    select 1
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = v_current_user_id
  ) then
    raise exception 'Bu konuÅŸmanÄ±n katÄ±lÄ±mcÄ±sÄ± deÄŸilsiniz.';
  end if;

  -- Verify conversation is a valid 1-to-1 DM (exactly 2 participants)
  if (
    select count(1)
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
  ) <> 2 then
    raise exception 'GeÃ§ersiz sohbet tipi.';
  end if;

  -- Find other participant
  select cp.user_id into v_other_user_id
  from public.direct_conversation_participants cp
  where cp.conversation_id = p_conversation_id
    and cp.user_id <> v_current_user_id
  limit 1;

  if v_other_user_id is null then
    raise exception 'AlÄ±cÄ± kullanÄ±cÄ± bulunamadÄ±.';
  end if;

  -- Block check
  if exists (
    select 1
    from public.blocks b
    where (b.blocker_id = v_current_user_id and b.blocked_id = v_other_user_id)
       or (b.blocker_id = v_other_user_id and b.blocked_id = v_current_user_id)
  ) then
    raise exception 'EngellenmiÅŸ bir kullanÄ±cÄ±yla mesajlaÅŸamazsÄ±nÄ±z.';
  end if;

  -- Insert message
  insert into public.direct_messages (conversation_id, sender_user_id, body)
  values (p_conversation_id, v_current_user_id, v_trimmed_body)
  returning id, created_at into v_message_id, v_created_at;

  -- Update conversation
  update public.direct_conversations
  set 
    last_message_at = v_created_at,
    last_message_preview = substring(v_trimmed_body from 1 for 100),
    updated_at = now()
  where id = p_conversation_id;

  -- Update sender's read pointer
  update public.direct_conversation_participants
  set 
    last_read_at = v_created_at,
    last_read_message_id = v_message_id
  where conversation_id = p_conversation_id
    and user_id = v_current_user_id;

  -- Fetch sender's display name safely
  select coalesce(nullif(btrim(pr.first_name), ''), pr.username, 'Bir kullanÄ±cÄ±')
  into v_sender_name
  from public.profiles pr
  where pr.user_id = v_current_user_id;

  if v_sender_name is null or length(btrim(v_sender_name)) = 0 then
    v_sender_name := 'Bir kullanÄ±cÄ±';
  end if;

  -- Insert privacy-friendly push notification to outbox
  insert into public.push_notification_outbox (
    recipient_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    metadata
  )
  values (
    v_other_user_id,
    'direct_message',
    v_sender_name || ' sana mesaj gÃ¶nderdi',
    'Yeni bir mesajÄ±n var',
    'direct_message',
    p_conversation_id::text,
    jsonb_build_object('conversation_id', p_conversation_id)
  );

  v_result := jsonb_build_object(
    'id', v_message_id,
    'conversation_id', p_conversation_id,
    'sender_user_id', v_current_user_id,
    'body', v_trimmed_body,
    'created_at', v_created_at
  );

  return v_result;
end;
$$;

-- RPC 3: mark_direct_conversation_read
create or replace function public.mark_direct_conversation_read(p_conversation_id uuid, p_last_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_user_id uuid;
begin
  v_current_user_id := auth.uid();
  if v_current_user_id is null then
    raise exception 'Kimlik doÄŸrulama hatasÄ±.';
  end if;

  if p_conversation_id is null then
    raise exception 'KonuÅŸma ID belirtilmelidir.';
  end if;

  -- Verify current user is participant
  if not exists (
    select 1
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = v_current_user_id
  ) then
    raise exception 'Bu konuÅŸmanÄ±n katÄ±lÄ±mcÄ±sÄ± deÄŸilsiniz.';
  end if;

  -- Verify p_last_message_id belongs to the same conversation if provided
  if p_last_message_id is not null then
    if not exists (
      select 1
      from public.direct_messages dm
      where dm.id = p_last_message_id
        and dm.conversation_id = p_conversation_id
    ) then
      raise exception 'GeÃ§ersiz mesaj referansÄ±.';
    end if;
  end if;

  update public.direct_conversation_participants
  set 
    last_read_at = now(),
    last_read_message_id = p_last_message_id
  where conversation_id = p_conversation_id
    and user_id = v_current_user_id;
end;
$$;

-- Revoke all execute permissions from public/anon/users by default
revoke execute on function public.get_or_create_direct_conversation(uuid) from public, anon;
revoke execute on function public.send_direct_message(uuid, text) from public, anon;
revoke execute on function public.mark_direct_conversation_read(uuid, uuid) from public, anon;

-- Grant execution permission only to authenticated users
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;
grant execute on function public.send_direct_message(uuid, text) to authenticated;
grant execute on function public.mark_direct_conversation_read(uuid, uuid) to authenticated;

-- Add direct_messages to realtime publication safely if publication exists
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1 
      from pg_publication_tables 
      where pubname = 'supabase_realtime' 
        and schemaname = 'public' 
        and tablename = 'direct_messages'
    ) then
      alter publication supabase_realtime add table public.direct_messages;
    end if;
  end if;
exception
  when duplicate_object then
    -- ignore if already exists/duplicate object error
  when others then
    -- raise warning to allow manual configuration instead of silent failure
    raise warning 'Could not add table to supabase_realtime publication: %. Please configure manually if required.', SQLERRM;
end;
$$;

notify pgrst, 'reload schema';
-- Migration: Trust Score V2, Badge Engine, QR Attendance, and Business Plus Foundation
-- Target File: supabase/migrations/20260617030000_trust_badges_attendance.sql

-- 1. Extend event_participants table safely adding missing excuse columns if not exists
ALTER TABLE public.event_participants
  ADD COLUMN IF NOT EXISTS checked_in_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS on_time boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_method text DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS excuse_status text NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancellation_reason text,
  ADD COLUMN IF NOT EXISTS cancellation_window text,
  ADD COLUMN IF NOT EXISTS excuse_text text,
  ADD COLUMN IF NOT EXISTS excuse_submitted_at timestamptz;

COMMENT ON COLUMN public.event_participants.checked_in_by_user_id IS 'Normal etkinliklerde yoklamayÄ± alan kullanÄ±cÄ± IDsi.';
COMMENT ON COLUMN public.event_participants.on_time IS 'KatÄ±lÄ±mcÄ±nÄ±n zamanÄ±nda (etkinlikten 30 dk Ã¶nce ile 15 dk sonraya kadar) giriÅŸ yapÄ±p yapmadÄ±ÄŸÄ±.';
COMMENT ON COLUMN public.event_participants.verification_method IS 'KatÄ±lÄ±m doÄŸrulama yÃ¶ntemi: qr, manual veya unknown.';
COMMENT ON COLUMN public.event_participants.excuse_status IS 'KatÄ±lÄ±mcÄ±nÄ±n mazeret durumu: none, pending, accepted, rejected.';

-- Verification Method Constraint
ALTER TABLE public.event_participants DROP CONSTRAINT IF EXISTS event_participants_verification_method_check;
ALTER TABLE public.event_participants ADD CONSTRAINT event_participants_verification_method_check 
  CHECK (verification_method IN ('qr', 'manual', 'unknown'));

-- 2. Extend badges table
ALTER TABLE public.badges
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS threshold integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.badges.category IS 'Rozet kategorisi: user veya business.';
COMMENT ON COLUMN public.badges.threshold IS 'Rozetin kazanÄ±lmasÄ± iÃ§in gereken eÅŸik sayÄ± deÄŸeri.';

-- 3. Create business_badges table
CREATE TABLE IF NOT EXISTS public.business_badges (
  business_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  badge_id text NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  earned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, badge_id)
);

ALTER TABLE public.business_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read business badges" ON public.business_badges;
CREATE POLICY "Anyone authenticated can read business badges"
  ON public.business_badges
  FOR SELECT
  TO authenticated
  USING (true);

-- Revoke all direct client modifications on business_badges
REVOKE ALL ON public.business_badges FROM public, anon, authenticated;
GRANT SELECT ON public.business_badges TO authenticated;

-- 4. Tighten direct client mutations on other sensitive tables
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.user_badges FROM authenticated, public, anon;
GRANT SELECT ON public.user_badges TO authenticated;

ALTER TABLE public.trust_score_logs ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.trust_score_logs FROM authenticated, public, anon;
GRANT SELECT ON public.trust_score_logs TO authenticated;

DO $$
BEGIN
  IF to_regclass('public.business_plus_subscriptions') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.business_plus_subscriptions ENABLE ROW LEVEL SECURITY';
    EXECUTE 'REVOKE INSERT, UPDATE, DELETE ON public.business_plus_subscriptions FROM authenticated, public, anon';
    EXECUTE 'GRANT SELECT ON public.business_plus_subscriptions TO authenticated';
  END IF;
END $$;

-- 5. Profiles table modifications & trust_score protection trigger
ALTER TABLE public.profiles ALTER COLUMN trust_score SET DEFAULT 70;
UPDATE public.profiles SET trust_score = 70 WHERE trust_score IS NULL;

-- Trigger to prevent client from updating own trust score directly
CREATE OR REPLACE FUNCTION public.protect_profile_trust_score()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.trust_score IS DISTINCT FROM OLD.trust_score THEN
    IF CURRENT_USER IN ('authenticated', 'anon') THEN
      RAISE EXCEPTION 'cannot_update_trust_score_directly';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_trust_score ON public.profiles;
CREATE TRIGGER trg_protect_profile_trust_score
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_trust_score();

-- 6. Insert/Update Badge Definitions
INSERT INTO public.badges (id, title, description, icon_key, sort_order, is_active, category, threshold)
VALUES
  -- User badges
  ('sozunde_duran', 'SÃ¶zÃ¼nde duran', 'KatÄ±ldÄ±ÄŸÄ± etkinliklerin en az %80''ine zamanÄ±nda katÄ±lÄ±m saÄŸladÄ±.', 'verified_user', 10, true, 'user', 80),
  ('onayli_profil', 'OnaylÄ± profil', 'Profil bilgilerini eksiksiz tamamladÄ±.', 'verified', 20, true, 'user', 100),
  ('ilk_etkinlik', 'Ä°lk etkinlik', 'Ä°lk etkinliÄŸine katÄ±ldÄ±.', 'event', 30, true, 'user', 1),
  ('katilimci', 'KatÄ±lÄ±mcÄ±', '5 etkinliÄŸe katÄ±lÄ±m saÄŸladÄ±.', 'run', 40, true, 'user', 5),
  ('ortamci', 'OrtamcÄ±', '25 etkinliÄŸe katÄ±lÄ±m saÄŸladÄ±.', 'group', 50, true, 'user', 25),
  ('mudavim', 'MÃ¼davim', '50 etkinliÄŸe katÄ±lÄ±m saÄŸladÄ±.', 'workspace_premium', 60, true, 'user', 50),
  ('ev_sahibi', 'Ev sahibi', 'En az bir katÄ±lÄ±mcÄ±sÄ± olan 1 etkinlik dÃ¼zenledi.', 'home', 70, true, 'user', 1),
  ('takim_kurucu', 'TakÄ±m kurucu', 'Her biri en az bir katÄ±lÄ±mcÄ±lÄ± 10 etkinlik dÃ¼zenledi.', 'groups', 80, true, 'user', 10),
  ('etkinlik_ustasi', 'Etkinlik Ã¼stadÄ±', 'Her biri en az bir katÄ±lÄ±mcÄ±lÄ± 50 etkinlik dÃ¼zenledi.', 'military_tech', 90, true, 'user', 50),
  ('futbolcu', 'Futbolcu', '5 futbol etkinliÄŸine katÄ±ldÄ±.', 'sports_soccer', 100, true, 'user', 5),
  ('kosucu', 'KoÅŸucu', '5 koÅŸu veya doÄŸa sporlarÄ± etkinliÄŸine katÄ±ldÄ±.', 'directions_run', 110, true, 'user', 5),
  ('yuzucu', 'YÃ¼zÃ¼cÃ¼', '5 yÃ¼zme etkinliÄŸine katÄ±ldÄ±.', 'pool', 120, true, 'user', 5),
  ('raket_ustasi', 'Raket ustasÄ±', '5 raket sporu etkinliÄŸine katÄ±ldÄ±.', 'sports_tennis', 130, true, 'user', 5),
  ('her_alanda_var', 'Her alanda var', 'En az 3 farklÄ± etkinlik tÃ¼rÃ¼ne katÄ±ldÄ±.', 'category', 140, true, 'user', 3),
  ('dakik_oyuncu', 'Dakik oyuncu', '10 etkinliÄŸe tam zamanÄ±nda giriÅŸ yaptÄ±.', 'schedule', 150, true, 'user', 10),
  ('kampci', 'KampÃ§Ä±', '5 Kamp veya Piknik etkinliÄŸine katÄ±ldÄ±.', 'explore', 160, true, 'user', 5),
  ('maceraci', 'MaceracÄ±', '5 macera ve outdoor spor etkinliÄŸine katÄ±ldÄ±.', 'terrain', 170, true, 'user', 5),
  ('doga_insani', 'DoÄŸa insanÄ±', '5 doÄŸa ve aÃ§Ä±k hava etkinliÄŸine katÄ±ldÄ±.', 'hiking', 180, true, 'user', 5),
  ('salon_oyuncusu', 'Salon oyuncusu', '5 bowling, bilardo, masa veya satranÃ§ oyununa katÄ±ldÄ±.', 'casino', 190, true, 'user', 5),
  ('fitness_mudavimi', 'Fitness mÃ¼davimi', '5 fitness, yoga, pilates veya dÃ¶vÃ¼ÅŸ sporu etkinliÄŸine katÄ±ldÄ±.', 'fitness_center', 200, true, 'user', 5),
  ('takim_oyuncu', 'TakÄ±m oyuncusu', '5 futbol, basketbol veya voleybol etkinliÄŸine katÄ±ldÄ±.', 'sports_handball', 210, true, 'user', 5),
  ('dans_tutkunu', 'Dans tutkunu', '5 dans etkinliÄŸine katÄ±ldÄ±.', 'music_note', 220, true, 'user', 5),
  ('bisikletci', 'BisikletÃ§i', '5 bisiklet etkinliÄŸine katÄ±ldÄ±.', 'directions_bike', 230, true, 'user', 5),
  -- Business badges
  ('fast_approval', 'HÄ±zlÄ± onay', 'RezervasyonlarÄ± hÄ±zlÄ± ve sorunsuz yÃ¶neten iÅŸletme.', 'bolt', 10, true, 'business', 20),
  ('verified_business', 'OnaylÄ± iÅŸletme', 'Profil bilgilerini tamamlamÄ±ÅŸ ve doÄŸrulanmÄ±ÅŸ iÅŸletme.', 'verified', 20, true, 'business', 100),
  ('five_star', '10 numara 5 yÄ±ldÄ±z', 'Ortalama deÄŸerlendirmesi 4.0 Ã¼zerinde olan iÅŸletme.', 'star', 30, true, 'business', 4),
  ('popular_business', 'PopÃ¼ler iÅŸletme', '50 Ã¼zerinde katÄ±lÄ±mcÄ± aÄŸÄ±rlayan veya 10 etkinlik tamamlayan iÅŸletme.', 'trending_up', 40, true, 'business', 50)
ON CONFLICT (id) DO UPDATE
SET title = excluded.title,
    description = excluded.description,
    icon_key = excluded.icon_key,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    category = excluded.category,
    threshold = excluded.threshold;

UPDATE public.badges SET is_active = false WHERE id IN ('first_step', 'active_player');

-- 7. Helper: Normalize Sport Type
CREATE OR REPLACE FUNCTION public.normalize_sport_type(p_val text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
AS $$
  SELECT lower(translate(p_val, 'Ã§ÄŸÄ±Ã¶ÅŸÃ¼Ã‡ÄÄ°Ã–ÅÃœ', 'cgiosucgiosu'));
$$;

-- 8. Trust Score delta V2 configuration
CREATE OR REPLACE FUNCTION public.trust_score_delta_for_event(p_event_type text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE p_event_type
    -- Legacy/existing events
    WHEN 'profile_event_ready' THEN 2
    WHEN 'first_event_approved' THEN 3
    WHEN 'event_join_approved' THEN 1
    WHEN 'host_event_with_participant' THEN 2
    WHEN 'event_linked_post' THEN 1
    WHEN 'approved_event_left' THEN -2
    WHEN 'event_join_cancelled' THEN 0
    WHEN 'event_join_rejected' THEN 0
    -- V2 positive events
    WHEN 'event_checked_in' THEN 3
    WHEN 'business_event_checked_in' THEN 3
    WHEN 'event_on_time_bonus' THEN 1
    WHEN 'event_manual_attended' THEN 1
    WHEN 'event_completed_attended' THEN 1
    WHEN 'event_completed_hosted' THEN 2
    WHEN 'attendance_streak_bonus' THEN 2
    -- V2 negative events
    WHEN 'cancel_24h_to_6h' THEN -1
    WHEN 'cancel_6h_to_2h' THEN -3
    WHEN 'cancel_less_than_2h' THEN -6
    WHEN 'event_no_show' THEN -10
    WHEN 'business_event_no_show' THEN -10
    ELSE 0
  END;
$$;

-- 9. Ensure trust_score_logs schema and DB-level unique index for idempotency
ALTER TABLE public.trust_score_logs
  ADD COLUMN IF NOT EXISTS actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS delta integer,
  ADD COLUMN IF NOT EXISTS previous_score integer,
  ADD COLUMN IF NOT EXISTS new_score integer,
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS source_type text,
  ADD COLUMN IF NOT EXISTS source_id uuid,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Handle existing duplicates by backing them up before checking for index
CREATE TABLE IF NOT EXISTS public.trust_score_logs_duplicate_backup (
  LIKE public.trust_score_logs INCLUDING ALL
);

-- Copy all duplicate records to the backup table to preserve audit history
INSERT INTO public.trust_score_logs_duplicate_backup
SELECT a.*
FROM public.trust_score_logs a
JOIN (
  SELECT user_id, source_id, reason
  FROM public.trust_score_logs
  WHERE source_id IS NOT NULL
  GROUP BY user_id, source_id, reason
  HAVING COUNT(*) > 1
) b ON a.user_id = b.user_id
  AND a.source_id = b.source_id
  AND a.reason = b.reason
ON CONFLICT (id) DO NOTHING;

-- Do not delete duplicates from trust_score_logs (V2 Safety Requirement).
-- If duplicates exist, create a non-unique index and skip unique index to avoid DB errors/failures.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.trust_score_logs
    WHERE source_id IS NOT NULL
    GROUP BY user_id, source_id, reason
    HAVING COUNT(*) > 1
  ) THEN
    RAISE NOTICE 'Duplicates found in trust_score_logs. Skipping unique index creation to prevent data loss. Please resolve duplicates manually.';
    IF NOT EXISTS (
      SELECT 1 FROM pg_class WHERE relname = 'trust_score_logs_user_source_reason_idx'
    ) THEN
      CREATE INDEX trust_score_logs_user_source_reason_idx
        ON public.trust_score_logs (user_id, source_id, reason)
        WHERE source_id IS NOT NULL;
    END IF;
  ELSE
    DROP INDEX IF EXISTS public.trust_score_logs_user_source_reason_idx;
    CREATE UNIQUE INDEX trust_score_logs_user_source_reason_idx
      ON public.trust_score_logs (user_id, source_id, reason)
      WHERE source_id IS NOT NULL;
  END IF;
END $$;

-- 10. Redefine apply_trust_score_event with V2 rules
CREATE OR REPLACE FUNCTION public.apply_trust_score_event(
  p_user_id uuid,
  p_actor_id uuid,
  p_event_type text,
  p_source_type text DEFAULT NULL,
  p_source_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_delta integer := 0;
  v_previous_score integer;
  v_new_score integer;
  v_original_log_id uuid;
  v_original_delta integer;
  v_streak_count integer;
BEGIN
  -- Idempotency check for unique rewards/penalties on (user_id, source_id, reason)
  IF p_source_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.trust_score_logs log
    WHERE log.user_id = p_user_id
      AND log.reason = p_event_type
      AND log.source_id = p_source_id
  ) THEN
    SELECT COALESCE(profile.trust_score, 70)
    INTO v_previous_score
    FROM public.profiles profile
    WHERE profile.user_id = p_user_id;
    RETURN COALESCE(v_previous_score, 70);
  END IF;

  -- Dynamic Excuse Reversal Logic
  IF p_event_type = 'excuse_accepted' THEN
    SELECT id, delta INTO v_original_log_id, v_original_delta
    FROM public.trust_score_logs
    WHERE user_id = p_user_id
      AND source_id = p_source_id
      AND delta < 0
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_original_log_id IS NOT NULL THEN
      -- Verify that we haven't already reversed this penalty log
      IF EXISTS (
        SELECT 1
        FROM public.trust_score_logs
        WHERE user_id = p_user_id
          AND (metadata->>'reverses_log_id')::uuid = v_original_log_id
      ) THEN
        SELECT COALESCE(profile.trust_score, 70)
        INTO v_previous_score
        FROM public.profiles profile
        WHERE profile.user_id = p_user_id;
        RETURN COALESCE(v_previous_score, 70);
      END IF;

      -- Reversal delta is positive equivalent of the penalty delta
      v_delta := -v_original_delta;
      p_metadata := COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object('reverses_log_id', v_original_log_id::text);
    ELSE
      v_delta := 0;
    END IF;
  ELSE
    v_delta := public.trust_score_delta_for_event(p_event_type);
  END IF;

  -- Fetch previous trust score
  SELECT COALESCE(profile.trust_score, 70)
  INTO v_previous_score
  FROM public.profiles profile
  WHERE profile.user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 70;
  END IF;

  -- Adjust score and clamp between 0 and 100
  v_new_score := LEAST(100, GREATEST(0, v_previous_score + v_delta));

  -- Update profiles table
  UPDATE public.profiles
  SET trust_score = v_new_score,
      updated_at = now()
  WHERE user_id = p_user_id;

  -- Insert ledger entry
  INSERT INTO public.trust_score_logs (
    user_id,
    actor_id,
    delta,
    previous_score,
    new_score,
    reason,
    source_type,
    source_id,
    metadata
  )
  VALUES (
    p_user_id,
    p_actor_id,
    v_delta,
    v_previous_score,
    v_new_score,
    p_event_type,
    p_source_type,
    p_source_id,
    COALESCE(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT DO NOTHING;

  -- Streak calculations on check-in
  IF p_event_type IN ('event_checked_in', 'business_event_checked_in') THEN
    SELECT count(*)
    INTO v_streak_count
    FROM public.trust_score_logs
    WHERE user_id = p_user_id
      AND created_at > COALESCE(
        (SELECT max(created_at) FROM public.trust_score_logs WHERE user_id = p_user_id AND delta < 0),
        '-infinity'::timestamptz
      )
      AND reason IN ('event_checked_in', 'business_event_checked_in');

    -- Award streak bonus every 5 consecutive successful check-ins
    IF v_streak_count > 0 AND v_streak_count % 5 = 0 THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.trust_score_logs
        WHERE user_id = p_user_id
          AND reason = 'attendance_streak_bonus'
          AND source_id = p_source_id
      ) THEN
        PERFORM public.apply_trust_score_event(
          p_user_id,
          p_actor_id,
          'attendance_streak_bonus',
          p_source_type,
          p_source_id,
          jsonb_build_object('streak_length', v_streak_count)
        );
      END IF;
    END IF;
  END IF;

  -- Refresh User Badges
  PERFORM public.refresh_user_badges(p_user_id);

  RETURN v_new_score;
END;
$$;

-- 11. Excuse Status Security Safeguard Trigger
CREATE OR REPLACE FUNCTION public.check_participant_update_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_event public.events%rowtype;
  v_business_id uuid;
  v_is_authorized boolean := false;
BEGIN
  -- Excuse status validation
  IF NEW.excuse_status IS DISTINCT FROM OLD.excuse_status AND NEW.excuse_status IN ('accepted', 'rejected') THEN
    SELECT * INTO v_event FROM public.events WHERE id = OLD.event_id;
    
    IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
      SELECT id INTO v_business_id
      FROM public.business_accounts
      WHERE owner_user_id = auth.uid() AND status = 'active'
      LIMIT 1;

      IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
        v_is_authorized := true;
      END IF;
    ELSE
      IF v_event.host_id = auth.uid() THEN
        v_is_authorized := true;
      END IF;
    END IF;

    IF NOT v_is_authorized THEN
      RAISE EXCEPTION 'unauthorized_excuse_status_change';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_participant_update_rules ON public.event_participants;
CREATE TRIGGER trg_check_participant_update_rules
BEFORE UPDATE ON public.event_participants
FOR EACH ROW EXECUTE FUNCTION public.check_participant_update_rules();

-- 12. Redefine unified QR check-in RPC verify_and_check_in_participant
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
  v_is_authorized boolean := false;
  v_on_time boolean := false;
  v_business_id uuid;
  v_target_status text;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'cannot_check_in_self';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Authorization Checks
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := 'checked_in';
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := 'attended';
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized_scanner';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = p_user_id
    AND role = 'participant';

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  -- Already Checked In Checks
  IF v_participant.attendance_status IN ('checked_in', 'attended') THEN
    RETURN 'already_checked_in';
  END IF;

  -- Confirm approved status
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    IF v_participant.attendance_status <> 'confirmed' THEN
      RAISE EXCEPTION 'participant_not_confirmed';
    END IF;
  ELSE
    IF v_participant.attendance_status <> 'planned' THEN
      RAISE EXCEPTION 'participant_not_approved';
    END IF;
  END IF;

  IF v_participant.check_in_token IS NULL OR v_participant.check_in_token <> p_token THEN
    RAISE EXCEPTION 'invalid_token';
  END IF;

  -- Calculate On-Time status
  IF now() >= v_event.event_date - interval '30 minutes' AND now() <= v_event.event_date + interval '15 minutes' THEN
    v_on_time := true;
  END IF;

  -- Update Attendance status
  UPDATE public.event_participants
  SET attendance_status = v_target_status,
      checked_in_at = now(),
      checked_in_by = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN v_business_id ELSE NULL END,
      checked_in_by_user_id = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN NULL ELSE v_actor_id END,
      verification_method = 'qr',
      on_time = v_on_time
  WHERE event_id = p_event_id
    AND user_id = p_user_id;

  -- Recalculate event approved count
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

  -- Apply Trust V2 Scores
  PERFORM public.apply_trust_score_event(
    p_user_id,
    v_actor_id,
    'event_checked_in',
    'event',
    p_event_id,
    jsonb_build_object('attendance_status', v_target_status, 'verification_method', 'qr')
  );

  IF v_on_time THEN
    PERFORM public.apply_trust_score_event(
      p_user_id,
      v_actor_id,
      'event_on_time_bonus',
      'event',
      p_event_id,
      jsonb_build_object('on_time', true)
    );
  END IF;

  -- Recalculate User Badges
  PERFORM public.refresh_user_badges(p_user_id);

  -- Recalculate Business Badges (if business event)
  IF COALESCE(v_event.organizer_type, 'user') = 'business' AND v_business_id IS NOT NULL THEN
    PERFORM public.recalculate_business_badges(v_business_id);
  END IF;

  RETURN 'success';
END;
$$;

-- 13. RPC for manual host/business check-in/no-show: mark_event_attendance
CREATE OR REPLACE FUNCTION public.mark_event_attendance(
  p_event_id uuid,
  p_participant_user_id uuid,
  p_attendance_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_is_authorized boolean := false;
  v_business_id uuid;
  v_target_status text;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_attendance_status NOT IN ('checked_in', 'attended', 'no_show') THEN
    RAISE EXCEPTION 'invalid_attendance_status';
  END IF;

  IF p_participant_user_id = v_actor_id THEN
    RAISE EXCEPTION 'cannot_mark_own_attendance';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id FOR UPDATE;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Authorization Checks
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := CASE WHEN p_attendance_status = 'no_show' THEN 'no_show' ELSE 'checked_in' END;
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := CASE WHEN p_attendance_status = 'no_show' THEN 'no_show' ELSE 'attended' END;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = p_participant_user_id
    AND role = 'participant'
  FOR UPDATE;

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  -- Already Checked In Checks
  IF v_participant.attendance_status IN ('checked_in', 'attended') THEN
    RETURN;
  END IF;

  -- No-Show Safety check (Prefer event_end_time if it exists)
  IF p_attendance_status = 'no_show' THEN
    IF v_event.event_end_time IS NOT NULL THEN
      DECLARE
        v_event_end timestamptz;
      BEGIN
        IF v_event.event_start_time IS NOT NULL THEN
          IF v_event.event_end_time >= v_event.event_start_time THEN
            v_event_end := v_event.event_date + (v_event.event_end_time - v_event.event_start_time);
          ELSE
            v_event_end := v_event.event_date + (v_event.event_end_time - v_event.event_start_time) + interval '24 hours';
          END IF;
        ELSE
          -- Fallback: assume event date in Europe/Istanbul local timezone and combine with event_end_time
          v_event_end := timezone('Europe/Istanbul', timezone('UTC', v_event.event_date))::date + v_event.event_end_time;
          v_event_end := timezone('Europe/Istanbul', v_event_end);
        END IF;

        IF now() < v_event_end THEN
          RAISE EXCEPTION 'cannot_mark_no_show_before_event_end';
        END IF;
      END;
    ELSE
      IF now() < v_event.event_date THEN
        RAISE EXCEPTION 'cannot_mark_no_show_before_event_start';
      END IF;
    END IF;
  END IF;

  -- Update Attendance status
  UPDATE public.event_participants
  SET attendance_status = v_target_status,
      checked_in_at = CASE WHEN p_attendance_status IN ('checked_in', 'attended') THEN now() ELSE checked_in_at END,
      checked_in_by = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN v_business_id ELSE NULL END,
      checked_in_by_user_id = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN NULL ELSE v_actor_id END,
      verification_method = CASE WHEN p_attendance_status IN ('checked_in', 'attended') THEN 'manual' ELSE verification_method END,
      on_time = false -- manual check-in does not award on-time bonus
  WHERE event_id = p_event_id
    AND user_id = p_participant_user_id;

  -- Recalculate event approved count
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

  -- Apply Trust V2 Scores (Use event_manual_attended reason for manual checks)
  IF p_attendance_status = 'no_show' THEN
    PERFORM public.apply_trust_score_event(
      p_participant_user_id,
      v_actor_id,
      'event_no_show',
      'event',
      p_event_id,
      jsonb_build_object('attendance_status', 'no_show', 'verification_method', 'manual')
    );
  ELSE
    PERFORM public.apply_trust_score_event(
      p_participant_user_id,
      v_actor_id,
      'event_manual_attended',
      'event',
      p_event_id,
      jsonb_build_object('attendance_status', v_target_status, 'verification_method', 'manual')
    );
  END IF;

  -- Recalculate User Badges
  PERFORM public.refresh_user_badges(p_participant_user_id);

  -- Recalculate Business Badges (if business event)
  IF COALESCE(v_event.organizer_type, 'user') = 'business' AND v_business_id IS NOT NULL THEN
    PERFORM public.recalculate_business_badges(v_business_id);
  END IF;
END;
$$;

-- 14. RPC for participant cancellation and excuse submit: cancel_event_participation
CREATE OR REPLACE FUNCTION public.cancel_event_participation(
  p_event_id uuid,
  p_excuse_text text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_window text;
  v_penalty_reason text;
  v_excuse_status text := 'none';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = v_user_id
    AND role = 'participant';

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  -- Only approved/confirmed participants can trigger cancellation penalty rules
  IF v_participant.attendance_status NOT IN ('planned', 'confirmed') THEN
    RAISE EXCEPTION 'cannot_cancel_unapproved_participation';
  END IF;

  -- Determine cancellation window
  IF now() < v_event.event_date - interval '24 hours' THEN
    v_window := 'more_than_24h';
    v_penalty_reason := NULL;
  ELSIF now() < v_event.event_date - interval '6 hours' THEN
    v_window := '24h_to_6h';
    v_penalty_reason := 'cancel_24h_to_6h';
  ELSIF now() < v_event.event_date - interval '2 hours' THEN
    v_window := '6h_to_2h';
    v_penalty_reason := 'cancel_6h_to_2h';
  ELSE
    v_window := 'less_than_2h';
    v_penalty_reason := 'cancel_less_than_2h';
  END IF;

  IF p_excuse_text IS NOT NULL AND trim(p_excuse_text) <> '' THEN
    v_excuse_status := 'pending';
  END IF;

  -- Update participant record
  UPDATE public.event_participants
  SET attendance_status = 'cancelled',
      cancelled_at = now(),
      cancellation_reason = p_excuse_text,
      cancellation_window = v_window,
      excuse_text = p_excuse_text,
      excuse_submitted_at = CASE WHEN p_excuse_text IS NOT NULL THEN now() ELSE excuse_submitted_at END,
      excuse_status = v_excuse_status
  WHERE event_id = p_event_id
    AND user_id = v_user_id;

  -- Update approved count
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

  -- Apply Trust score penalty if late and event is not cancelled by host/business
  IF v_penalty_reason IS NOT NULL AND COALESCE(v_event.status, 'active') <> 'cancelled' THEN
    PERFORM public.apply_trust_score_event(
      v_user_id,
      v_user_id,
      v_penalty_reason,
      'event',
      p_event_id,
      jsonb_build_object('cancellation_window', v_window, 'has_excuse', (p_excuse_text IS NOT NULL))
    );
  END IF;

  -- Recalculate user badges
  PERFORM public.refresh_user_badges(v_user_id);
END;
$$;

-- RPC for host/business excuse approval: resolve_participant_excuse
CREATE OR REPLACE FUNCTION public.resolve_participant_excuse(
  p_event_id uuid,
  p_user_id uuid,
  p_excuse_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_is_authorized boolean := false;
  v_business_id uuid;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_excuse_status NOT IN ('accepted', 'rejected') THEN
    RAISE EXCEPTION 'invalid_excuse_status';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Authorization Checks
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = p_user_id;

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  IF v_participant.excuse_status <> 'pending' THEN
    RAISE EXCEPTION 'no_pending_excuse';
  END IF;

  -- Update excuse status
  UPDATE public.event_participants
  SET excuse_status = p_excuse_status
  WHERE event_id = p_event_id
    AND user_id = p_user_id;

  -- Revert penalty on accept
  IF p_excuse_status = 'accepted' THEN
    PERFORM public.apply_trust_score_event(
      p_user_id,
      v_actor_id,
      'excuse_accepted',
      'event',
      p_event_id,
      jsonb_build_object('resolved_by', v_actor_id)
    );
  END IF;

  -- Recalculate User Badges
  PERFORM public.refresh_user_badges(p_user_id);
END;
$$;

-- 15. Unified RPC to fetch check-in participants for both host & business
CREATE OR REPLACE FUNCTION public.get_event_check_in_participants(
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
  excuse_submitted_at timestamptz,
  excuse_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_is_authorized boolean := false;
  v_business_id uuid;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RETURN;
  END IF;

  -- Verify scanner/viewer authorization
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  RETURN QUERY
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
    participant.excuse_submitted_at,
    participant.excuse_status::text
  FROM public.event_participants participant
  JOIN public.profiles profile
    ON profile.user_id = participant.user_id
  WHERE participant.event_id = p_event_id
    AND participant.role = 'participant'
    AND participant.attendance_status IN ('confirmed', 'checked_in', 'no_show', 'planned', 'attended', 'cancelled')
  ORDER BY
    participant.attendance_status IN ('confirmed', 'planned') DESC,
    profile.first_name,
    profile.username;
END;
$$;

-- 16. Backward-compatible wrap for get_business_event_check_in_participants
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
  checked_in_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    user_id,
    username,
    tag,
    first_name,
    avatar_url,
    attendance_status,
    checked_in_at
  FROM public.get_event_check_in_participants(p_event_id);
$$;

-- 17. Redefine refresh_user_badges with V2 rules (Requires verification_method = 'qr' for sport/type badges)
CREATE OR REPLACE FUNCTION public.refresh_user_badges(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_ready boolean;
  v_trust_score integer;
  v_qr_attended_count integer;
  v_on_time_count integer;
  v_hosted_completed_with_attendance integer;
  v_total_committed integer;
  v_attended_ratio float := 0.0;
  
  -- Category counts
  v_futbol_count integer := 0;
  v_kosu_count integer := 0;
  v_yuzme_count integer := 0;
  v_raket_count integer := 0;
  v_distinct_types integer := 0;
  v_kamp_count integer := 0;
  v_macera_count integer := 0;
  v_doga_count integer := 0;
  v_salon_count integer := 0;
  v_fitness_count integer := 0;
  v_takim_count integer := 0;
  v_dans_count integer := 0;
  v_bisiklet_count integer := 0;
BEGIN
  -- 1. Check if profile is complete and fetch trust_score
  SELECT
    (NULLIF(trim(coalesce(profile.username, '')), '') IS NOT NULL
      AND NULLIF(trim(coalesce(profile.first_name, '')), '') IS NOT NULL
      AND NULLIF(trim(coalesce(profile.city, '')), '') IS NOT NULL
      AND NULLIF(trim(coalesce(profile.district, '')), '') IS NOT NULL
      AND profile.birth_date IS NOT NULL),
    COALESCE(profile.trust_score, 70)
  INTO v_profile_ready, v_trust_score
  FROM public.profiles profile
  WHERE profile.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 2. Count QR-verified event attendances
  SELECT count(*)
  INTO v_qr_attended_count
  FROM public.event_participants
  WHERE user_id = p_user_id
    AND role = 'participant'
    AND attendance_status IN ('checked_in', 'attended')
    AND verification_method = 'qr';

  -- 3. Count on-time QR check-ins
  SELECT count(*)
  INTO v_on_time_count
  FROM public.event_participants
  WHERE user_id = p_user_id
    AND role = 'participant'
    AND attendance_status IN ('checked_in', 'attended')
    AND verification_method = 'qr'
    AND on_time = true;

  -- 4. Count hosted events with at least one checked-in participant
  -- Note: Host badges count completed hosted events where at least one participant checked in (via either QR or manual verification methods)
  SELECT count(distinct e.id)
  INTO v_hosted_completed_with_attendance
  FROM public.events e
  JOIN public.event_participants ep ON ep.event_id = e.id
  WHERE e.host_id = p_user_id
    AND e.event_date < now()
    AND ep.role = 'participant'
    AND ep.attendance_status IN ('checked_in', 'attended');

  -- 5. Calculate SÃ¶zÃ¼nde Duran ratio
  SELECT count(*)
  INTO v_total_committed
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE ep.user_id = p_user_id
    AND ep.role = 'participant'
    -- Exclude early cancellations (>24h) from the sample
    AND (
      ep.attendance_status IN ('checked_in', 'attended', 'no_show')
      OR (ep.attendance_status = 'cancelled' AND ep.cancellation_window IN ('24h_to_6h', '6h_to_2h', 'less_than_2h'))
    );

  -- 6. Count sport categories for checked-in events (Enforces verification_method = 'qr')
  SELECT count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'futbol') AS futbol,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('kosu', 'doga yuruyusu', 'trekking')) AS kosu,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'yuzme') AS yuzme,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('tenis', 'padel', 'masa tenisi')) AS raket,
         count(distinct public.normalize_sport_type(e.sport_type)) AS distinct_types,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('kamp', 'piknik')) AS kamp,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('paintball', 'karting', 'tirmanis', 'kayak / snowboard', 'kayak', 'snowboard')) AS macera,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('doga yuruyusu', 'trekking', 'kamp', 'balik tutma')) AS doga,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('bowling', 'bilardo', 'masa oyunlari', 'satranc')) AS salon,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('fitness', 'yoga', 'pilates', 'dovus sporlari')) AS fitness,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('futbol', 'basketbol', 'voleybol')) AS takim,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'dans') AS dans,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'bisiklet') AS bisiklet
  INTO v_futbol_count, v_kosu_count, v_yuzme_count, v_raket_count, v_distinct_types, v_kamp_count, v_macera_count, v_doga_count, v_salon_count, v_fitness_count, v_takim_count, v_dans_count, v_bisiklet_count
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE ep.user_id = p_user_id
    AND ep.role = 'participant'
    AND ep.attendance_status IN ('checked_in', 'attended')
    AND ep.verification_method = 'qr';

  -- --- AWARD USER BADGES ---

  -- OnaylÄ± Profil
  IF v_profile_ready THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'onayli_profil') ON CONFLICT DO NOTHING;
  END IF;

  -- SÃ¶zÃ¼nde Duran
  IF v_total_committed >= 5 THEN
    v_attended_ratio := v_qr_attended_count::float / v_total_committed::float;
    IF v_attended_ratio >= 0.8 THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'sozunde_duran') ON CONFLICT DO NOTHING;
    ELSE
      DELETE FROM public.user_badges WHERE user_id = p_user_id AND badge_id = 'sozunde_duran';
    END IF;
  ELSE
    DELETE FROM public.user_badges WHERE user_id = p_user_id AND badge_id = 'sozunde_duran';
  END IF;

  -- Attendance Counts (Ä°lk etkinlik, KatÄ±lÄ±mcÄ±, OrtamcÄ±, MÃ¼davim)
  IF v_qr_attended_count >= 1 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'ilk_etkinlik') ON CONFLICT DO NOTHING;
  END IF;
  IF v_qr_attended_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'katilimci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_qr_attended_count >= 25 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'ortamci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_qr_attended_count >= 50 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'mudavim') ON CONFLICT DO NOTHING;
  END IF;

  -- Host Badges (Ev sahibi, TakÄ±m kurucu, Etkinlik Ã¼stadÄ±)
  IF v_hosted_completed_with_attendance >= 1 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'ev_sahibi') ON CONFLICT DO NOTHING;
  END IF;
  IF v_hosted_completed_with_attendance >= 10 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'takim_kurucu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_hosted_completed_with_attendance >= 50 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'etkinlik_ustasi') ON CONFLICT DO NOTHING;
  END IF;

  -- Sport Type Badges
  IF v_futbol_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'futbolcu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_kosu_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'kosucu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_yuzme_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'yuzucu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_raket_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'raket_ustasi') ON CONFLICT DO NOTHING;
  END IF;
  IF v_distinct_types >= 3 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'her_alanda_var') ON CONFLICT DO NOTHING;
  END IF;
  IF v_on_time_count >= 10 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'dakik_oyuncu') ON CONFLICT DO NOTHING;
  END IF;

  -- Additional Badges
  IF v_kamp_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'kampci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_macera_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'maceraci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_doga_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'doga_insani') ON CONFLICT DO NOTHING;
  END IF;
  IF v_salon_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'salon_oyuncusu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_fitness_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'fitness_mudavimi') ON CONFLICT DO NOTHING;
  END IF;
  IF v_takim_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'takim_oyuncu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_dans_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'dans_tutkunu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_bisiklet_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'bisikletci') ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

-- 18. RPC to recalculate business badges: recalculate_business_badges
CREATE OR REPLACE FUNCTION public.recalculate_business_badges(p_business_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_checked_in_participants integer := 0;
  v_is_verified boolean := false;
  v_reviews_avg float := 0.0;
  v_reviews_count integer := 0;
  v_completed_events_count integer := 0;
BEGIN
  -- Count verified business check-ins (Requiring QR verification as high-quality proof)
  -- Note: We count only participants checked in via QR code (verification_method = 'qr').
  -- Manual attendance is treated as a business correction, not as QR-quality proof for badge progression.
  SELECT count(*)
  INTO v_checked_in_participants
  FROM public.event_participants
  WHERE checked_in_by = p_business_id
    AND attendance_status = 'checked_in'
    AND verification_method = 'qr';

  -- Check verified status safely using inspect columns
  IF exists (
    select 1 
    from information_schema.columns 
    where table_schema = 'public' 
      and table_name = 'business_accounts' 
      and column_name = 'is_verified'
  ) THEN
    EXECUTE 'SELECT COALESCE(is_verified, false) FROM public.business_accounts WHERE id = $1'
    INTO v_is_verified
    USING p_business_id;
  ELSE
    v_is_verified := false;
  END IF;

  -- Count reviews & average rating safely
  IF to_regclass('public.business_reviews') IS NOT NULL THEN
    EXECUTE 'SELECT COALESCE(avg(rating), 0.0), count(*) FROM public.business_reviews WHERE business_id = $1'
    INTO v_reviews_avg, v_reviews_count
    USING p_business_id;
  ELSE
    v_reviews_avg := 0.0;
    v_reviews_count := 0;
  END IF;

  -- Completed business events with checked-in participants (Requiring QR verification)
  -- Note: We count completed events where at least one participant was checked in via QR.
  SELECT count(distinct event_id)
  INTO v_completed_events_count
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE ep.checked_in_by = p_business_id
    AND ep.attendance_status = 'checked_in'
    AND ep.verification_method = 'qr';

  -- --- AWARD BUSINESS BADGES ---

  -- HÄ±zlÄ± Onay (20+ check-ins)
  IF v_checked_in_participants >= 20 THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'fast_approval') ON CONFLICT DO NOTHING;
  END IF;

  -- OnaylÄ± Ä°ÅŸletme (DoÄŸrulanmÄ±ÅŸ)
  IF v_is_verified THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'verified_business') ON CONFLICT DO NOTHING;
  END IF;

  -- 10 Numara 5 YÄ±ldÄ±z (Ortalama > 4.0 ve min 1 deÄŸerlendirme)
  IF v_reviews_count >= 1 AND v_reviews_avg > 4.0 THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'five_star') ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.business_badges WHERE business_id = p_business_id AND badge_id = 'five_star';
  END IF;

  -- PopÃ¼ler Ä°ÅŸletme (50+ katÄ±lÄ±mcÄ± ya da 10+ tamamlanmÄ±ÅŸ etkinlik)
  IF v_checked_in_participants >= 50 OR v_completed_events_count >= 10 THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'popular_business') ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

-- 19. RPC to read business badges: get_business_badges
CREATE OR REPLACE FUNCTION public.get_business_badges(p_business_id uuid)
RETURNS TABLE (
  id text,
  title text,
  description text,
  icon_key text,
  sort_order integer,
  earned_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    badge.id,
    badge.title,
    badge.description,
    badge.icon_key,
    badge.sort_order,
    bus_badge.earned_at
  FROM public.badges badge
  LEFT JOIN public.business_badges bus_badge
    ON bus_badge.business_id = p_business_id
    AND bus_badge.badge_id = badge.id
  WHERE badge.is_active
    AND badge.category = 'business'
  ORDER BY
    bus_badge.earned_at IS NULL,
    COALESCE(bus_badge.earned_at, 'infinity'::timestamptz),
    badge.sort_order,
    badge.id;
$$;

-- 20. Redefine get_profile_badges to fetch user badges only
CREATE OR REPLACE FUNCTION public.get_profile_badges(p_user_id uuid)
RETURNS TABLE (
  id text,
  title text,
  description text,
  icon_key text,
  sort_order integer,
  earned_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_is_private boolean;
  v_can_view boolean := false;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN;
  END IF;

  SELECT coalesce(profile.is_private, false) INTO v_is_private
  FROM public.profiles profile
  WHERE profile.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_actor_id = p_user_id OR v_is_private = false OR EXISTS (
    SELECT 1
    FROM public.follows follow_rows
    WHERE follow_rows.follower_id = v_actor_id
      AND follow_rows.following_id = p_user_id
  ) THEN
    v_can_view := true;
  END IF;

  IF NOT v_can_view THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    badge.id,
    badge.title,
    badge.description,
    badge.icon_key,
    badge.sort_order,
    user_badge.earned_at
  FROM public.badges badge
  LEFT JOIN public.user_badges user_badge
    ON user_badge.user_id = p_user_id
    AND user_badge.badge_id = badge.id
  WHERE badge.is_active
    AND badge.category = 'user'
  ORDER BY
    user_badge.earned_at IS NULL,
    COALESCE(user_badge.earned_at, 'infinity'::timestamptz),
    badge.sort_order,
    badge.id;
END;
$$;

-- 21. Trigger function to ensure check_in_token exists for approved/confirmed participants
CREATE OR REPLACE FUNCTION public.ensure_check_in_token_exists()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role = 'participant' 
     AND NEW.attendance_status IN ('planned', 'confirmed', 'attended', 'checked_in', 'approved', 'pending_confirmation')
     AND NEW.check_in_token IS NULL THEN
    NEW.check_in_token := gen_random_uuid()::text;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_check_in_token ON public.event_participants;
CREATE TRIGGER trg_ensure_check_in_token
BEFORE INSERT OR UPDATE ON public.event_participants
FOR EACH ROW EXECUTE FUNCTION public.ensure_check_in_token_exists();

-- 22. Backfill check_in_tokens for existing approved/confirmed participations using strong gen_random_uuid()
UPDATE public.event_participants
SET check_in_token = gen_random_uuid()::text
WHERE check_in_token IS NULL
  AND role = 'participant'
  AND attendance_status IN ('planned', 'approved', 'confirmed', 'pending_confirmation');

-- 23. Grants
REVOKE ALL ON FUNCTION public.apply_trust_score_event(uuid, uuid, text, text, uuid, jsonb) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_user_badges(uuid) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.recalculate_business_badges(uuid) FROM public, anon, authenticated;

REVOKE ALL ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.mark_event_attendance(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mark_event_attendance(uuid, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_event_participation(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.cancel_event_participation(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_participant_excuse(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.resolve_participant_excuse(uuid, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.get_business_badges(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_business_badges(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_profile_badges(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_badges(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_event_check_in_participants(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_event_check_in_participants(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
