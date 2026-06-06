drop function if exists public.mark_notification_read(uuid);
drop function if exists public.mark_all_notifications_read();

create or replace function public.mark_notification_read(
  p_notification_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_updated_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  update public.notifications notification
  set is_read = true
  where notification.id = p_notification_id
    and notification.recipient_id = v_user_id
    and coalesce(notification.is_read, false) = false;

  get diagnostics v_updated_count = row_count;
  return v_updated_count;
end;
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_updated_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  update public.notifications notification
  set is_read = true
  where notification.recipient_id = v_user_id
    and coalesce(notification.is_read, false) = false;

  get diagnostics v_updated_count = row_count;
  return v_updated_count;
end;
$$;

revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.mark_all_notifications_read() from public;

grant execute on function public.mark_notification_read(uuid)
  to authenticated;
grant execute on function public.mark_all_notifications_read()
  to authenticated;

notify pgrst, 'reload schema';
