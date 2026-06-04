create table if not exists public.rate_limit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  target_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists rate_limit_events_user_action_created_at_idx
  on public.rate_limit_events (user_id, action, created_at desc);

create index if not exists rate_limit_events_target_id_idx
  on public.rate_limit_events (target_id)
  where target_id is not null;

alter table public.rate_limit_events enable row level security;

revoke all on public.rate_limit_events from anon;
revoke all on public.rate_limit_events from authenticated;

create or replace function public.check_and_record_rate_limit(
  p_action text,
  p_limit_count integer,
  p_window_seconds integer,
  p_target_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_action text := nullif(btrim(p_action), '');
  v_recent_count integer;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if v_action is null then
    raise exception 'invalid_rate_limit_action';
  end if;

  if p_limit_count is null or p_limit_count < 1 then
    raise exception 'invalid_rate_limit_count';
  end if;

  if p_window_seconds is null or p_window_seconds < 1 then
    raise exception 'invalid_rate_limit_window';
  end if;

  select count(*)::integer
  into v_recent_count
  from public.rate_limit_events event
  where event.user_id = v_user_id
    and event.action = v_action
    and event.created_at >= now() - make_interval(secs => p_window_seconds);

  if v_recent_count >= p_limit_count then
    raise exception 'rate_limit_exceeded'
      using hint = 'Çok fazla işlem yaptın. Biraz sonra tekrar dene.';
  end if;

  insert into public.rate_limit_events (user_id, action, target_id)
  values (v_user_id, v_action, p_target_id);

  return true;
end;
$$;

revoke all on function public.check_and_record_rate_limit(
  text,
  integer,
  integer,
  uuid
) from public;

grant execute on function public.check_and_record_rate_limit(
  text,
  integer,
  integer,
  uuid
) to authenticated;

notify pgrst, 'reload schema';
