CREATE OR REPLACE FUNCTION private.invoke_business_plus_reconciliation()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_configured_url text;
  v_base_url text;
  v_function_url text;
  v_worker_secret text;
  v_supabase_apikey text;
BEGIN
  SELECT NULLIF(btrim(decrypted_secret), '')
  INTO v_configured_url
  FROM vault.decrypted_secrets
  WHERE name = 'reconcile_supabase_url'
  LIMIT 1;

  SELECT NULLIF(btrim(decrypted_secret), '')
  INTO v_worker_secret
  FROM vault.decrypted_secrets
  WHERE name = 'reconcile_push_worker_secret'
  LIMIT 1;

  SELECT NULLIF(btrim(decrypted_secret), '')
  INTO v_supabase_apikey
  FROM vault.decrypted_secrets
  WHERE name = 'reconcile_supabase_apikey'
  LIMIT 1;

  IF v_configured_url IS NULL
    OR v_worker_secret IS NULL
    OR v_supabase_apikey IS NULL THEN
    RAISE EXCEPTION 'business_plus_reconciliation_configuration_missing';
  END IF;

  IF v_configured_url !~
    $url_regex$^https://[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*(/(rest/v1|functions/v1(/reconcile-business-plus-subscription)?))?/?$$url_regex$
  THEN
    RAISE EXCEPTION 'business_plus_reconciliation_configuration_invalid_url';
  END IF;

  v_configured_url := rtrim(v_configured_url, '/');

  IF v_configured_url ~
    '/functions/v1/reconcile-business-plus-subscription$'
  THEN
    v_base_url := regexp_replace(
      v_configured_url,
      '/functions/v1/reconcile-business-plus-subscription$',
      ''
    );
    v_function_url := v_configured_url;
  ELSE
    v_base_url := regexp_replace(
      v_configured_url,
      '/(rest/v1|functions/v1)$',
      ''
    );
    v_function_url := v_base_url ||
      '/functions/v1/reconcile-business-plus-subscription';
  END IF;

  PERFORM net.http_post(
    url := v_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_supabase_apikey,
      'x-reconcile-worker-secret', v_worker_secret
    ),
    body := jsonb_build_object('limit', 500)
  );
END;
$function$;

REVOKE ALL ON FUNCTION private.invoke_business_plus_reconciliation()
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_job_id bigint;
BEGIN
  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname = 'reconcile-business-plus-subscriptions';

  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;
END;
$$;

SELECT cron.schedule(
  'reconcile-business-plus-subscriptions',
  '0 4 * * *',
  'SELECT private.invoke_business_plus_reconciliation();'
);
