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
    raise exception 'Kimlik doğrulama hatası.';
  end if;

  if p_target_user_id is null then
    raise exception 'Alıcı ID belirtilmelidir.';
  end if;

  if v_current_user_id = p_target_user_id then
    raise exception 'Kendi kendinize mesaj gönderemezsiniz.';
  end if;

  -- Verify target user exists
  if not exists (
    select 1
    from public.profiles pr
    where pr.user_id = p_target_user_id
  ) then
    raise exception 'Alıcı kullanıcı bulunamadı.';
  end if;

  -- Block check
  if exists (
    select 1
    from public.blocks b
    where (b.blocker_id = v_current_user_id and b.blocked_id = p_target_user_id)
       or (b.blocker_id = p_target_user_id and b.blocked_id = v_current_user_id)
  ) then
    raise exception 'Bu kullanıcıyla mesajlaşamazsınız.';
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
    raise exception 'Kimlik doğrulama hatası.';
  end if;

  if p_conversation_id is null then
    raise exception 'Konuşma ID belirtilmelidir.';
  end if;

  -- Trim and validate body
  v_trimmed_body := btrim(coalesce(p_body, ''));
  if length(v_trimmed_body) = 0 then
    raise exception 'Boş mesaj gönderilemez.';
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
    raise exception 'Bu konuşmanın katılımcısı değilsiniz.';
  end if;

  -- Verify conversation is a valid 1-to-1 DM (exactly 2 participants)
  if (
    select count(1)
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
  ) <> 2 then
    raise exception 'Geçersiz sohbet tipi.';
  end if;

  -- Find other participant
  select cp.user_id into v_other_user_id
  from public.direct_conversation_participants cp
  where cp.conversation_id = p_conversation_id
    and cp.user_id <> v_current_user_id
  limit 1;

  if v_other_user_id is null then
    raise exception 'Alıcı kullanıcı bulunamadı.';
  end if;

  -- Block check
  if exists (
    select 1
    from public.blocks b
    where (b.blocker_id = v_current_user_id and b.blocked_id = v_other_user_id)
       or (b.blocker_id = v_other_user_id and b.blocked_id = v_current_user_id)
  ) then
    raise exception 'Engellenmiş bir kullanıcıyla mesajlaşamazsınız.';
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
  select coalesce(nullif(btrim(pr.first_name), ''), pr.username, 'Bir kullanıcı')
  into v_sender_name
  from public.profiles pr
  where pr.user_id = v_current_user_id;

  if v_sender_name is null or length(btrim(v_sender_name)) = 0 then
    v_sender_name := 'Bir kullanıcı';
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
    v_sender_name || ' sana mesaj gönderdi',
    'Yeni bir mesajın var',
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
    raise exception 'Kimlik doğrulama hatası.';
  end if;

  if p_conversation_id is null then
    raise exception 'Konuşma ID belirtilmelidir.';
  end if;

  -- Verify current user is participant
  if not exists (
    select 1
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = v_current_user_id
  ) then
    raise exception 'Bu konuşmanın katılımcısı değilsiniz.';
  end if;

  -- Verify p_last_message_id belongs to the same conversation if provided
  if p_last_message_id is not null then
    if not exists (
      select 1
      from public.direct_messages dm
      where dm.id = p_last_message_id
        and dm.conversation_id = p_conversation_id
    ) then
      raise exception 'Geçersiz mesaj referansı.';
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
