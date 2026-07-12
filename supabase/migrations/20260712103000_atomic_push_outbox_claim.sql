-- Backend release blockers: reproducible avatar storage plus atomic push claim.

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'avatars',
  'avatars',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Atomically claim pending push rows so parallel workers cannot send the same
-- outbox item concurrently.

create or replace function public.service_claim_push_notification_outbox(
  p_limit integer default 25
)
returns table (
  id uuid,
  recipient_id uuid,
  title text,
  body text,
  entity_type text,
  entity_id text,
  metadata jsonb,
  attempts integer
)
language sql
security definer
set search_path = ''
as $function$
  with candidates as (
    select outbox.id
    from public.push_notification_outbox outbox
    where outbox.status = 'pending'
    order by outbox.created_at, outbox.id
    for update skip locked
    limit least(greatest(coalesce(p_limit, 25), 1), 100)
  ), claimed as (
    update public.push_notification_outbox outbox
    set status = 'processing',
        attempts = outbox.attempts + 1,
        updated_at = now()
    from candidates
    where outbox.id = candidates.id
      and outbox.status = 'pending'
    returning
      outbox.id,
      outbox.recipient_id,
      outbox.title,
      outbox.body,
      outbox.entity_type,
      outbox.entity_id,
      outbox.metadata,
      outbox.attempts
  )
  select
    claimed.id,
    claimed.recipient_id,
    claimed.title,
    claimed.body,
    claimed.entity_type,
    claimed.entity_id,
    claimed.metadata,
    claimed.attempts
  from claimed
  order by claimed.id;
$function$;

revoke all on function public.service_claim_push_notification_outbox(integer)
  from public, anon, authenticated;
grant execute on function public.service_claim_push_notification_outbox(integer)
  to service_role;

comment on function public.service_claim_push_notification_outbox(integer) is
  'Claims pending push outbox rows atomically for the service-role worker.';

notify pgrst, 'reload schema';
