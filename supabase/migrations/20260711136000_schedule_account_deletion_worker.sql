create or replace function private.invoke_account_deletion_worker()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_configured_url text;
  v_base_url text;
  v_function_url text;
  v_supabase_apikey text;
  v_worker_secret text;
begin
  select nullif(btrim(decrypted_secret), '')
  into v_configured_url
  from vault.decrypted_secrets
  where name = 'account_deletion_supabase_url'
  limit 1;

  select nullif(btrim(decrypted_secret), '')
  into v_supabase_apikey
  from vault.decrypted_secrets
  where name = 'account_deletion_supabase_apikey'
  limit 1;

  select nullif(btrim(decrypted_secret), '')
  into v_worker_secret
  from vault.decrypted_secrets
  where name = 'account_deletion_worker_secret'
  limit 1;

  if v_configured_url is null
    or v_supabase_apikey is null
    or v_worker_secret is null then
    raise exception 'account_deletion_worker_configuration_missing';
  end if;

  if v_configured_url !~
    $url_regex$^https://[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*(/(rest/v1|functions/v1(/process-account-deletions)?))?/?$$url_regex$
  then
    raise exception 'account_deletion_worker_configuration_invalid_url';
  end if;

  v_configured_url := rtrim(v_configured_url, '/');
  if v_configured_url ~ '/functions/v1/process-account-deletions$' then
    v_function_url := v_configured_url;
  else
    v_base_url := regexp_replace(
      v_configured_url,
      '/(rest/v1|functions/v1)$',
      ''
    );
    v_function_url := v_base_url ||
      '/functions/v1/process-account-deletions';
  end if;

  perform net.http_post(
    url := v_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_supabase_apikey,
      'x-account-deletion-worker-secret', v_worker_secret
    ),
    body := jsonb_build_object('limit', 10)
  );
end;
$function$;

revoke all on function private.invoke_account_deletion_worker()
  from public, anon, authenticated;

do $schedule$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'process-account-deletions';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$schedule$;

select cron.schedule(
  'process-account-deletions',
  '15 * * * *',
  'SELECT private.invoke_account_deletion_worker();'
);
