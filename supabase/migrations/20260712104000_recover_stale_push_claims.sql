-- 20260712104000_recover_stale_push_claims.sql
-- Recover stale processing push notifications (lease pattern) and fail those exceeding maximum attempts.

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
language plpgsql
security definer
set search_path = ''
as $function$
begin
  -- 1. Fail any processing rows that have been stuck for more than 5 minutes and have attempts >= 3
  update public.push_notification_outbox outbox
  set status = 'failed',
      last_error = 'max_retries_exceeded',
      updated_at = pg_catalog.now()
  where outbox.id in (
    select o.id
    from public.push_notification_outbox o
    where o.status = 'processing'
      and o.updated_at < (pg_catalog.now() - interval '5 minutes')
      and o.attempts >= 3
    for update skip locked
  );

  -- 2. Claim pending rows OR stale processing rows with attempts < 3
  return query
  with candidates as (
    select o.id
    from public.push_notification_outbox o
    where o.status = 'pending'
       or (o.status = 'processing'
           and o.updated_at < (pg_catalog.now() - interval '5 minutes')
           and o.attempts < 3)
    order by o.created_at, o.id
    for update skip locked
    limit least(greatest(coalesce(p_limit, 25), 1), 100)
  ), claimed as (
    update public.push_notification_outbox outbox
    set status = 'processing',
        attempts = outbox.attempts + 1,
        updated_at = pg_catalog.now()
    from candidates
    where outbox.id = candidates.id
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
end;
$function$;

revoke all on function public.service_claim_push_notification_outbox(integer)
  from public, anon, authenticated;
grant execute on function public.service_claim_push_notification_outbox(integer)
  to service_role;

comment on function public.service_claim_push_notification_outbox(integer) is
  'Claims pending and stale processing push outbox rows atomically and transitions failed ones.';

notify pgrst, 'reload schema';
