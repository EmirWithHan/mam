# Push Worker Runbook

This runbook covers the Supabase-backed FCM push worker for event join request
notifications.

## Required secrets

Set these as Supabase Edge Function secrets. Do not commit real values.

```text
MAM_SUPABASE_SERVICE_KEY
FCM_PROJECT_ID
FCM_CLIENT_EMAIL
FCM_PRIVATE_KEY
```

`MAM_SUPABASE_SERVICE_KEY` must be a server-side Supabase service/secret key,
not an anon or publishable key.

## Deploy

```powershell
supabase db push
supabase functions deploy send-push-notifications --no-verify-jwt
```

The repo also keeps JWT verification disabled in `supabase/config.toml`:

```toml
[functions.send-push-notifications]
verify_jwt = false
```

## Verify device tokens

```sql
select user_id, platform, created_at, updated_at, last_seen_at
from public.user_push_tokens
order by updated_at desc
limit 20;
```

Do not select or share the raw `token` value outside trusted debugging.

## Verify outbox

```sql
select id, recipient_id, type, status, attempts, last_error, sent_at, updated_at
from public.push_notification_outbox
order by created_at desc
limit 20;
```

Status meanings:

- `pending`: queued and waiting for the worker.
- `sent`: at least one FCM send succeeded.
- `skipped` with `last_error = no_push_tokens`: recipient has no saved push token.
- `failed`: worker attempted delivery and stored a safe error summary.

## Self-test

```powershell
curl -i -X POST "https://<project-ref>.functions.supabase.co/send-push-notifications" -H "content-type: application/json" -d "{\"mode\":\"self_test\"}"
```

Expected shape:

```json
{
  "ok": true,
  "mode": "self_test",
  "selectedKeySource": "MAM_SUPABASE_SERVICE_KEY",
  "dbReadable": true
}
```

## Manual processing

```powershell
curl -i -X POST "https://<project-ref>.functions.supabase.co/send-push-notifications"
```

Expected no-work response:

```json
{ "ok": true, "processed": 0 }
```

## Scheduling

No existing Supabase cron, `pg_net`, or scheduled-function pattern is present in
this repo. Do not add database-side scheduling blindly.

For launch, use Supabase's scheduled Edge Function support, Supabase Cron, or an
external trusted scheduler to invoke `send-push-notifications` every 1-2 minutes
after confirming the project supports that scheduling path. The scheduled call
must not require a user JWT and must not expose `MAM_SUPABASE_SERVICE_KEY`.

Recommended Dashboard setup:

1. Confirm the function is deployed with JWT verification disabled.
2. Create a scheduled job named `mam_push_worker_every_minute`.
3. Use interval `* * * * *` or `*/2 * * * *`.
4. POST to:

```text
https://PROJECT_REF.supabase.co/functions/v1/send-push-notifications
```

5. If `PUSH_WORKER_SECRET` is set for the function, add only this header:

```text
x-worker-secret: OPTIONAL_WORKER_SECRET
```

Do not put `MAM_SUPABASE_SERVICE_KEY`, FCM secrets, device tokens, anon keys, or
service-role keys in the scheduled request.

If using Supabase Cron with `pg_net`, use placeholders first and replace them
only inside the Supabase Dashboard or SQL editor for the target project:

```sql
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

select cron.unschedule('mam_push_worker_every_minute')
where exists (
  select 1
  from cron.job
  where jobname = 'mam_push_worker_every_minute'
);

select cron.schedule(
  'mam_push_worker_every_minute',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://PROJECT_REF.supabase.co/functions/v1/send-push-notifications',
    headers := '{"content-type":"application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
```

If `PUSH_WORKER_SECRET` is enabled, include the worker-secret header in the
Dashboard-managed job only:

```sql
headers := '{"content-type":"application/json","x-worker-secret":"OPTIONAL_WORKER_SECRET"}'::jsonb
```

Do not commit SQL containing real `PROJECT_REF` values if the repo should remain
environment-neutral, and never commit real worker secrets.

Verify the cron job:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'mam_push_worker_every_minute';
```

Check recent cron runs if `pg_cron` exposes run details in the project:

```sql
select jobid, status, return_message, start_time, end_time
from cron.job_run_details
where jobid in (
  select jobid
  from cron.job
  where jobname = 'mam_push_worker_every_minute'
)
order by start_time desc
limit 20;
```

Check Edge Function logs in the Supabase Dashboard after creating a join request.
