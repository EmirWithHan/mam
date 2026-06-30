-- Rule-based event moderation and admin event panel foundation.
-- No AI services or external moderation providers are used.

alter table public.events
  add column if not exists moderation_status text not null default 'approved',
  add column if not exists moderation_reason text,
  add column if not exists moderation_flags text[],
  add column if not exists moderation_score integer,
  add column if not exists moderation_source text,
  add column if not exists moderation_checked_at timestamptz,
  add column if not exists moderation_removed_at timestamptz,
  add column if not exists moderation_removed_by uuid references auth.users(id),
  add column if not exists moderation_updated_at timestamptz;

alter table public.events
  drop constraint if exists events_moderation_status_check;

alter table public.events
  add constraint events_moderation_status_check
  check (
    moderation_status in (
      'pending_review',
      'approved',
      'needs_edit',
      'rejected',
      'removed_by_admin'
    )
  );

alter table public.events
  drop constraint if exists events_moderation_source_check;

alter table public.events
  add constraint events_moderation_source_check
  check (
    moderation_source is null
    or moderation_source in ('rule_based', 'admin', 'system')
  );

alter table public.events
  drop constraint if exists events_moderation_score_check;

alter table public.events
  add constraint events_moderation_score_check
  check (moderation_score is null or moderation_score between 0 and 100);

update public.events
set moderation_status = 'approved',
    moderation_source = coalesce(moderation_source, 'system'),
    moderation_updated_at = coalesce(moderation_updated_at, now())
where moderation_status is null;

create table if not exists public.event_moderation_logs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  admin_user_id uuid references auth.users(id),
  action text not null,
  previous_status text,
  new_status text not null,
  reason text,
  created_at timestamptz not null default now()
);

alter table public.event_moderation_logs enable row level security;

drop policy if exists "Admins can read event moderation logs"
  on public.event_moderation_logs;
create policy "Admins can read event moderation logs"
on public.event_moderation_logs
for select
to authenticated
using (public.is_current_user_admin());

drop policy if exists "Only service/admin can write event moderation logs"
  on public.event_moderation_logs;
create policy "Only service/admin can write event moderation logs"
on public.event_moderation_logs
for insert
to authenticated
with check (public.is_current_user_admin());

create or replace function public.log_event_moderation_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.moderation_source = 'rule_based' then
    insert into public.event_moderation_logs (
      event_id,
      admin_user_id,
      action,
      previous_status,
      new_status,
      reason
    )
    values (
      new.id,
      null,
      case new.moderation_status
        when 'approved' then 'rule_approved'
        when 'needs_edit' then 'rule_needs_edit'
        when 'rejected' then 'rule_rejected'
        else 'rule_checked'
      end,
      null,
      new.moderation_status,
      new.moderation_reason
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_log_event_moderation_insert on public.events;
create trigger trg_log_event_moderation_insert
after insert on public.events
for each row
execute function public.log_event_moderation_insert();

create or replace function public.list_admin_events(
  p_filter text default 'all',
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  host_id uuid,
  title text,
  description text,
  sport_type text,
  city text,
  district text,
  location_text text,
  location_lat double precision,
  location_lng double precision,
  event_date timestamptz,
  capacity_total integer,
  generic_capacity integer,
  male_capacity integer,
  female_capacity integer,
  approved_count integer,
  status text,
  is_sponsored boolean,
  sponsored_until timestamptz,
  sponsored_priority integer,
  organizer_type text,
  organizer_user_id uuid,
  organizer_business_id uuid,
  is_paid boolean,
  price_amount numeric,
  price_currency text,
  created_at timestamptz,
  updated_at timestamptz,
  listing_expires_at timestamptz,
  business_open_time text,
  business_close_time text,
  event_start_time text,
  event_end_time text,
  price_type text,
  min_age integer,
  require_completed_profile boolean,
  moderation_status text,
  moderation_reason text,
  moderation_flags text[],
  moderation_score integer,
  moderation_source text,
  moderation_checked_at timestamptz,
  moderation_removed_at timestamptz,
  moderation_removed_by uuid,
  moderation_updated_at timestamptz,
  host_name text,
  business_name text
)
language sql
security definer
set search_path = ''
as $$
  select
    e.id,
    e.host_id,
    e.title,
    e.description,
    e.sport_type,
    e.city,
    e.district,
    e.location_text,
    e.location_lat,
    e.location_lng,
    e.event_date,
    e.capacity_total,
    e.generic_capacity,
    e.male_capacity,
    e.female_capacity,
    e.approved_count,
    e.status,
    e.is_sponsored,
    e.sponsored_until,
    e.sponsored_priority,
    e.organizer_type,
    e.organizer_user_id,
    e.organizer_business_id,
    e.is_paid,
    e.price_amount,
    e.price_currency,
    e.created_at,
    e.updated_at,
    e.listing_expires_at,
    e.business_open_time,
    e.business_close_time,
    e.event_start_time,
    e.event_end_time,
    e.price_type,
    e.min_age,
    e.require_completed_profile,
    e.moderation_status,
    e.moderation_reason,
    e.moderation_flags,
    e.moderation_score,
    e.moderation_source,
    e.moderation_checked_at,
    e.moderation_removed_at,
    e.moderation_removed_by,
    e.moderation_updated_at,
    coalesce(nullif(p.first_name, ''), p.username) as host_name,
    b.name as business_name
  from public.events e
  left join public.profiles p on p.user_id = e.host_id
  left join public.business_accounts b on b.id = e.organizer_business_id
  where public.is_current_user_admin()
    and (
      p_filter = 'all'
      or (p_filter = 'high_risk' and coalesce(e.moderation_score, 100) < 70)
      or e.moderation_status = p_filter
    )
  order by e.created_at desc nulls last, e.event_date desc
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function public.set_event_moderation_status_as_admin(
  p_event_id uuid,
  p_new_status text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_previous_status text;
  v_action text;
begin
  if v_admin_id is null or not public.is_current_user_admin() then
    raise exception 'not_admin';
  end if;

  if p_new_status not in ('approved', 'rejected', 'removed_by_admin') then
    raise exception 'invalid_moderation_status';
  end if;

  select moderation_status
  into v_previous_status
  from public.events
  where id = p_event_id
  for update;

  if v_previous_status is null then
    raise exception 'event_not_found';
  end if;

  v_action := case p_new_status
    when 'approved' then 'admin_restored'
    when 'rejected' then 'admin_rejected'
    when 'removed_by_admin' then 'admin_removed'
    else 'admin_updated'
  end;

  update public.events
  set moderation_status = p_new_status,
      moderation_source = 'admin',
      moderation_reason = nullif(btrim(p_reason), ''),
      moderation_removed_by = case
        when p_new_status = 'removed_by_admin' then v_admin_id
        else null
      end,
      moderation_removed_at = case
        when p_new_status = 'removed_by_admin' then now()
        else null
      end,
      moderation_updated_at = now()
  where id = p_event_id;

  insert into public.event_moderation_logs (
    event_id,
    admin_user_id,
    action,
    previous_status,
    new_status,
    reason
  )
  values (
    p_event_id,
    v_admin_id,
    v_action,
    v_previous_status,
    p_new_status,
    nullif(btrim(p_reason), '')
  );
end;
$$;

create or replace function public.remove_event_as_admin(
  p_event_id uuid,
  p_reason text default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  select public.set_event_moderation_status_as_admin(
    p_event_id,
    'removed_by_admin',
    p_reason
  );
$$;

create or replace function public.restore_event_as_admin(
  p_event_id uuid,
  p_reason text default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  select public.set_event_moderation_status_as_admin(
    p_event_id,
    'approved',
    p_reason
  );
$$;

create or replace function public.reject_event_as_admin(
  p_event_id uuid,
  p_reason text default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  select public.set_event_moderation_status_as_admin(
    p_event_id,
    'rejected',
    p_reason
  );
$$;

revoke all on function public.list_admin_events(text, integer, integer) from public;
revoke all on function public.set_event_moderation_status_as_admin(uuid, text, text) from public;
revoke all on function public.remove_event_as_admin(uuid, text) from public;
revoke all on function public.restore_event_as_admin(uuid, text) from public;
revoke all on function public.reject_event_as_admin(uuid, text) from public;

grant execute on function public.list_admin_events(text, integer, integer) to authenticated;
grant execute on function public.remove_event_as_admin(uuid, text) to authenticated;
grant execute on function public.restore_event_as_admin(uuid, text) to authenticated;
grant execute on function public.reject_event_as_admin(uuid, text) to authenticated;

drop policy if exists "Events are visible without recursive participant checks"
  on public.events;
drop policy if exists "Events are visible to members or public list"
  on public.events;
create policy "Events are visible with moderation guard"
on public.events
for select
to authenticated
using (
  public.is_current_user_admin()
  or host_id = auth.uid()
  or (
    status in ('active', 'completed')
    and moderation_status = 'approved'
    and (
      coalesce(organizer_type, 'user') <> 'business'
      or public.event_business_is_active(organizer_business_id)
    )
  )
);

notify pgrst, 'reload schema';
