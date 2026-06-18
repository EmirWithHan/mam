-- Manual hotfix patch for Prompt 224.
--
-- Apply only after confirming the target Supabase project is dev/test.
-- Do not apply to production/live without an explicit release plan.

-- Preflight inspection: confirm current overloaded RPC signatures before changes.
select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'send_direct_message'
order by p.oid::regprocedure::text;

-- Event chat optional mute state: allow authenticated users to manage only their
-- own mute rows without widening event message access.
alter table public.chat_mutes enable row level security;

revoke all on public.chat_mutes from anon, public;
grant select, insert, update, delete on public.chat_mutes to authenticated;

drop policy if exists "Manage own mutes" on public.chat_mutes;
drop policy if exists "Select own mutes" on public.chat_mutes;
drop policy if exists "Insert own mutes" on public.chat_mutes;
drop policy if exists "Update own mutes" on public.chat_mutes;
drop policy if exists "Delete own mutes" on public.chat_mutes;

create policy "Select own mutes"
on public.chat_mutes
for select
to authenticated
using (user_id = auth.uid());

create policy "Insert own mutes"
on public.chat_mutes
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Update own mutes"
on public.chat_mutes
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Delete own mutes"
on public.chat_mutes
for delete
to authenticated
using (user_id = auth.uid());

-- Align DM replies with the single stable PostgREST RPC contract.
alter table public.direct_messages
  add column if not exists reply_to_message_id uuid
  references public.direct_messages(id) on delete set null;

do $$
begin
  if to_regclass('public.push_notification_outbox') is not null then
    alter table public.push_notification_outbox
      alter column notification_id drop not null;
  end if;
end;
$$;

drop function if exists public.send_direct_message(uuid, text);
drop function if exists public.send_direct_message(uuid, text, uuid);

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

  if to_regclass('public.push_notification_outbox') is not null then
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
      null,
      v_other_user_id,
      'direct_message',
      v_sender_name || ' sana mesaj gönderdi',
      'Yeni bir mesajın var',
      'direct_message',
      p_conversation_id::text,
      jsonb_build_object('conversation_id', p_conversation_id)
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

revoke execute on function public.send_direct_message(uuid, text, uuid) from public, anon;
grant execute on function public.send_direct_message(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';
