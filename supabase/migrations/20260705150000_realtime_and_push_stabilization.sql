-- Realtime and Push Stabilization Migration
-- 1. Enable realtime publication for missing required tables
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'direct_conversations'
  ) then
    alter publication supabase_realtime add table public.direct_conversations;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'direct_conversation_participants'
  ) then
    alter publication supabase_realtime add table public.direct_conversation_participants;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'event_participants'
  ) then
    alter publication supabase_realtime add table public.event_participants;
  end if;
end $$;

-- 2. Update RLS policies and trigger for public.event_participants
-- Drop existing update policy if any
drop policy if exists "Users can update own participant row" on public.event_participants;

-- Create update policy
create policy "Users can update own participant row"
on public.event_participants
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Redefine check_participant_update_rules to enforce column-level updates
create or replace function public.check_participant_update_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events%rowtype;
  v_business_id uuid;
  v_is_authorized boolean := false;
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();

  -- If updated by the participant themselves, restrict columns
  if v_actor_id is not null and v_actor_id = old.user_id then
    if new.role is distinct from old.role or
       new.attendance_status is distinct from old.attendance_status or
       new.capacity_bucket is distinct from old.capacity_bucket or
       new.event_id is distinct from old.event_id or
       new.user_id is distinct from old.user_id then
      raise exception 'unauthorized_column_change';
    end if;
  end if;

  -- Excuse status validation
  if new.excuse_status is distinct from old.excuse_status and new.excuse_status in ('accepted', 'rejected') then
    select * into v_event from public.events where id = old.event_id;
    
    if coalesce(v_event.organizer_type, 'user') = 'business' then
      select id into v_business_id
      from public.business_accounts
      where owner_user_id = v_actor_id and status = 'active'
      limit 1;

      if v_business_id is not null and v_event.organizer_business_id = v_business_id then
        v_is_authorized := true;
      end if;
    else
      if v_event.host_id = v_actor_id then
        v_is_authorized := true;
      end if;
    end if;

    if not v_is_authorized then
      raise exception 'unauthorized_excuse_status_change';
    end if;
  end if;

  return new;
end;
$$;

-- 3. Update queue_push_for_notification() to support 'follow_request', 'follow_request_approved', 'follow_request_rejected', 'follow', and 'message'
create or replace function public.queue_push_for_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_body text;
  v_title text;
  v_community_id uuid;
  v_is_muted boolean := false;
begin
  -- Exclude trigger updates if not in eligible list
  if new.type not in (
    'event_join_request',
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
  ) then
    return new;
  end if;

  -- Mute check for community chat mentions
  if new.type in ('community_chat_mention', 'community_announcement', 'community_members_only_event') then
    v_community_id := (new.metadata->>'community_id')::uuid;
    if v_community_id is not null then
      select exists (
        select 1
        from public.community_chat_mutes
        where community_id = v_community_id
          and user_id = new.recipient_id
      ) into v_is_muted;
    end if;
  end if;

  -- Mute check for event messages
  if new.type = 'message' and new.entity_type = 'event' then
    select exists (
      select 1
      from public.chat_mutes
      where event_id = new.entity_id::uuid
        and user_id = new.recipient_id
    ) into v_is_muted;
  end if;

  if v_is_muted then
    return new;
  end if;

  v_body := nullif(btrim(coalesce(new.body, '')), '');
  v_title := nullif(btrim(coalesce(new.title, '')), '');

  if v_body is null then
    v_body := 'Yeni bir bildiriminiz var.';
  end if;
  if v_title is null then
    v_title := 'Akanzi';
  end if;

  -- Customize titles/bodies for message push notifications
  if new.type = 'message' then
    if new.entity_type = 'direct_message' then
      v_title := v_title || ' sana mesaj gönderdi';
      v_body := 'Yeni bir mesajın var';
    elsif new.entity_type = 'event' then
      v_title := v_title || ' (' || coalesce((select title from public.events where id = new.entity_id::uuid), 'Etkinlik') || ')';
      v_body := 'Yeni bir grup mesajın var';
    end if;
  end if;

  insert into public.push_notification_outbox (
    notification_id,
    recipient_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    metadata
  )
  values (
    new.id,
    new.recipient_id,
    new.type,
    v_title,
    v_body,
    new.entity_type,
    new.entity_id,
    coalesce(new.metadata, '{}'::jsonb)
  )
  on conflict do nothing;

  return new;
end;
$$;

-- 4. Redefine send_direct_message to insert into notifications only, and NOT directly to push outbox
create or replace function public.send_direct_message(
  p_conversation_id uuid,
  p_body text,
  p_reply_to_message_id uuid default null
)
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

  v_trimmed_body := btrim(coalesce(p_body, ''));
  if length(v_trimmed_body) = 0 then
    raise exception 'Boş mesaj gönderilemez.';
  end if;

  if length(v_trimmed_body) > 2000 then
    raise exception 'Mesaj 2000 karakterden uzun olamaz.';
  end if;

  if not exists (
    select 1
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = v_current_user_id
  ) then
    raise exception 'Bu konuşmanın katılımcısı değilsiniz.';
  end if;

  if (
    select count(1)
    from public.direct_conversation_participants cp
    where cp.conversation_id = p_conversation_id
  ) <> 2 then
    raise exception 'Geçersiz sohbet tipi.';
  end if;

  select cp.user_id
  into v_other_user_id
  from public.direct_conversation_participants cp
  where cp.conversation_id = p_conversation_id
    and cp.user_id <> v_current_user_id
  limit 1;

  if v_other_user_id is null then
    raise exception 'Alıcı kullanıcı bulunamadı.';
  end if;

  if exists (
    select 1
    from public.blocks b
    where (b.blocker_id = v_current_user_id and b.blocked_id = v_other_user_id)
       or (b.blocker_id = v_other_user_id and b.blocked_id = v_current_user_id)
  ) then
    raise exception 'Engellenmiş bir kullanıcıyla mesajlaşamazsınız.';
  end if;

  if p_reply_to_message_id is not null then
    if not exists (
      select 1
      from public.direct_messages dm
      where dm.id = p_reply_to_message_id
        and dm.conversation_id = p_conversation_id
    ) then
      raise exception 'Geçersiz yanıt mesajı.';
    end if;
  end if;

  insert into public.direct_messages (
    conversation_id,
    sender_user_id,
    body,
    reply_to_message_id
  )
  values (
    p_conversation_id,
    v_current_user_id,
    v_trimmed_body,
    p_reply_to_message_id
  )
  returning id, created_at into v_message_id, v_created_at;

  update public.direct_conversations
  set
    last_message_at = v_created_at,
    last_message_preview = substring(v_trimmed_body from 1 for 100),
    updated_at = now()
  where id = p_conversation_id;

  update public.direct_conversation_participants
  set
    last_read_at = v_created_at,
    last_read_message_id = v_message_id
  where conversation_id = p_conversation_id
    and user_id = v_current_user_id;

  select coalesce(nullif(btrim(pr.first_name), ''), pr.username, 'Bir kullanıcı')
  into v_sender_name
  from public.profiles pr
  where pr.user_id = v_current_user_id;

  if v_sender_name is null or length(btrim(v_sender_name)) = 0 then
    v_sender_name := 'Bir kullanıcı';
  end if;

  -- Insert in-app notification (which triggers queue_push_for_notification)
  if to_regclass('public.notifications') is not null then
    insert into public.notifications (
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
    values (
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

  v_result := jsonb_build_object(
    'id', v_message_id,
    'conversation_id', p_conversation_id,
    'sender_user_id', v_current_user_id,
    'body', v_trimmed_body,
    'reply_to_message_id', p_reply_to_message_id,
    'created_at', v_created_at
  );

  return v_result;
end;
$$;

-- 5. Redefine public.on_event_message_insert to insert into notifications only, and NOT directly to push outbox
create or replace function public.on_event_message_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient_id uuid;
  v_sender_name text;
  v_event_title text;
begin
  -- Fetch sender name
  select coalesce(nullif(btrim(pr.first_name), ''), pr.username, 'Bir kullanıcı')
  into v_sender_name
  from public.profiles pr
  where pr.user_id = new.sender_id;

  -- Fetch event title
  select title
  into v_event_title
  from public.events
  where id = new.event_id;

  -- Loop through all active participants + host (excluding sender)
  for v_recipient_id in
    select distinct u.user_id from (
      select user_id from public.event_participants where event_id = new.event_id and removed_at is null
      union
      select host_id as user_id from public.events where id = new.event_id
    ) u where u.user_id <> new.sender_id
  loop
    -- Insert in-app notification (which triggers queue_push_for_notification)
    insert into public.notifications (
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
    values (
      v_recipient_id,
      new.sender_id,
      'message',
      v_sender_name,
      coalesce(v_event_title, 'Etkinlik') || ' grubunda yeni bir mesaj gönderdi',
      'event',
      new.event_id,
      jsonb_build_object('event_id', new.event_id, 'message_id', new.id),
      false
    );
  end loop;

  return new;
end;
$$;

notify pgrst, 'reload schema';
