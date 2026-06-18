grant usage on schema public to service_role;

grant select, update on table public.push_notification_outbox to service_role;
grant select on table public.user_push_tokens to service_role;
