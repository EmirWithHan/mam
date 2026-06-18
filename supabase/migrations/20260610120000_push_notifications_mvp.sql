create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint user_push_tokens_platform_check
    check (platform in ('android', 'ios', 'web')),
  constraint user_push_tokens_token_check
    check (length(btrim(token)) > 20),
  unique (user_id, token)
);

create index if not exists user_push_tokens_user_id_idx
  on public.user_push_tokens (user_id);

alter table public.user_push_tokens enable row level security;

drop policy if exists "Users can manage own push tokens"
  on public.user_push_tokens;
create policy "Users can manage own push tokens"
on public.user_push_tokens
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

revoke all on public.user_push_tokens from anon;
revoke all on public.user_push_tokens from authenticated;
grant select, insert, update, delete on public.user_push_tokens to authenticated;

create table if not exists public.push_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz,
  constraint push_notification_outbox_status_check
    check (status in ('pending', 'processing', 'sent', 'failed', 'skipped'))
);

create index if not exists push_notification_outbox_pending_idx
  on public.push_notification_outbox (status, created_at)
  where status = 'pending';

alter table public.push_notification_outbox enable row level security;

revoke all on public.push_notification_outbox from anon;
revoke all on public.push_notification_outbox from authenticated;

create or replace function public.queue_push_for_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_body text;
begin
  if new.type <> 'event_join_request' then
    return new;
  end if;

  v_body := nullif(btrim(coalesce(new.body, '')), '');
  if v_body is null then
    v_body := 'Etkinliğine yeni bir katılım isteği geldi.';
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
    coalesce(nullif(btrim(new.title), ''), 'Yeni katılım isteği'),
    v_body,
    new.entity_type,
    new.entity_id,
    coalesce(new.metadata, '{}'::jsonb)
  )
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists queue_push_for_notification_after_insert
  on public.notifications;
create trigger queue_push_for_notification_after_insert
after insert on public.notifications
for each row
execute function public.queue_push_for_notification();

revoke all on function public.queue_push_for_notification() from public;

notify pgrst, 'reload schema';
