-- Event creation quota based on successfully persisted events.
-- Calendar boundaries use Europe/Istanbul. Generic operation rate limits remain
-- in rate_limit_events, but create_event attempt rows are no longer authoritative.

alter table public.events
  add column if not exists creation_request_id uuid;

create unique index if not exists events_host_creation_request_id_key
  on public.events (host_id, creation_request_id)
  where creation_request_id is not null;

create table if not exists public.event_creation_quota_events (
  event_id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  business_account_id uuid,
  quota_tier text not null check (quota_tier in ('normal', 'business')),
  created_at timestamptz not null
);

create index if not exists event_creation_quota_owner_created_idx
  on public.event_creation_quota_events (owner_user_id, created_at desc);

create index if not exists event_creation_quota_business_created_idx
  on public.event_creation_quota_events (business_account_id, created_at desc)
  where business_account_id is not null;

alter table public.event_creation_quota_events enable row level security;
revoke all on public.event_creation_quota_events from public, anon, authenticated;

insert into public.event_creation_quota_events (
  event_id,
  owner_user_id,
  business_account_id,
  quota_tier,
  created_at
)
select
  event.id,
  event.host_id,
  case
    when coalesce(event.organizer_type, 'user') = 'business'
      then event.organizer_business_id
    else null
  end,
  case
    when coalesce(event.organizer_type, 'user') = 'business'
      then 'business'
    else 'normal'
  end,
  event.created_at
from public.events event
on conflict (event_id) do nothing;

create or replace function public.get_event_creation_quota(
  p_is_business_event boolean,
  p_business_account_id uuid default null,
  p_creation_request_id uuid default null
)
returns table (
  quota_tier text,
  error_code text,
  allowed_limit integer,
  counted_total integer,
  period_start timestamptz,
  period_end timestamptz,
  is_allowed boolean,
  is_business_plus_eligible boolean,
  already_inserted boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_local_now timestamp := timezone('Europe/Istanbul', now());
  v_trust_score integer := 50;
  v_is_active_business boolean := false;
  v_is_plus boolean := false;
  v_quota_tier text;
  v_error_code text;
  v_limit integer;
  v_count integer;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_plus_eligible boolean := false;
  v_already_inserted boolean := false;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_creation_request_id is not null then
    select exists (
      select 1
      from public.events event
      where event.host_id = v_user_id
        and event.creation_request_id = p_creation_request_id
    ) into v_already_inserted;
  end if;

  if coalesce(p_is_business_event, false) then
    select exists (
      select 1
      from public.business_accounts business
      where business.id = p_business_account_id
        and business.owner_user_id = v_user_id
        and business.status = 'active'
    ) into v_is_active_business;

    if not v_is_active_business then
      raise exception 'invalid_active_business_account';
    end if;

    select exists (
      select 1
      from public.business_plus_subscriptions subscription
      where subscription.business_account_id = p_business_account_id
        and subscription.status = 'active'
        and subscription.starts_at <= now()
        and (subscription.ends_at is null or subscription.ends_at >= now())
    ) into v_is_plus;

    v_quota_tier := case when v_is_plus then 'business_plus' else 'business_standard' end;
    v_error_code := case
      when v_is_plus then 'business_plus_monthly_limit'
      else 'business_monthly_limit'
    end;
    v_limit := case when v_is_plus then 30 else 3 end;
    v_plus_eligible := not v_is_plus;
    v_period_start := date_trunc('month', v_local_now) at time zone 'Europe/Istanbul';
    v_period_end := (date_trunc('month', v_local_now) + interval '1 month')
      at time zone 'Europe/Istanbul';

    select count(*)::integer
    into v_count
    from public.event_creation_quota_events quota_event
    where quota_event.business_account_id = p_business_account_id
      and quota_event.created_at >= v_period_start
      and quota_event.created_at < v_period_end;
  else
    select coalesce(profile.trust_score, 50)
    into v_trust_score
    from public.profiles profile
    where profile.user_id = v_user_id;

    v_trust_score := coalesce(v_trust_score, 50);
    v_quota_tier := case
      when v_trust_score >= 60 then 'normal_trusted'
      else 'normal_new'
    end;
    v_error_code := case
      when v_trust_score >= 60 then 'normal_trusted_daily_limit'
      else 'normal_new_daily_limit'
    end;
    v_limit := case when v_trust_score >= 60 then 3 else 2 end;
    v_period_start := date_trunc('day', v_local_now) at time zone 'Europe/Istanbul';
    v_period_end := (date_trunc('day', v_local_now) + interval '1 day')
      at time zone 'Europe/Istanbul';

    select count(*)::integer
    into v_count
    from public.event_creation_quota_events quota_event
    where quota_event.owner_user_id = v_user_id
      and quota_event.business_account_id is null
      and quota_event.created_at >= v_period_start
      and quota_event.created_at < v_period_end;
  end if;

  return query select
    v_quota_tier,
    v_error_code,
    v_limit,
    coalesce(v_count, 0),
    v_period_start,
    v_period_end,
    v_already_inserted or coalesce(v_count, 0) < v_limit,
    v_plus_eligible,
    v_already_inserted;
end;
$$;

create or replace function public.enforce_event_creation_quota()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quota record;
begin
  if tg_op = 'UPDATE' then
    if new.creation_request_id is distinct from old.creation_request_id then
      raise exception 'event_creation_request_id_is_immutable';
    end if;
  end if;

  if coalesce(new.moderation_status, 'pending_review') <> 'approved' then
    return new;
  end if;

  if exists (
    select 1
    from public.event_creation_quota_events quota_event
    where quota_event.event_id = new.id
  ) then
    return new;
  end if;

  if new.creation_request_id is not null and exists (
    select 1
    from public.events event
    where event.host_id = new.host_id
      and event.creation_request_id = new.creation_request_id
      and event.id is distinct from new.id
  ) then
    return new;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      'event_creation_quota:' || new.host_id::text || ':' ||
      coalesce(new.organizer_business_id::text, 'normal'),
      0
    )
  );

  select *
  into v_quota
  from public.get_event_creation_quota(
    coalesce(new.organizer_type, 'user') = 'business',
    new.organizer_business_id,
    new.creation_request_id
  );

  if not v_quota.is_allowed then
    raise exception '%', v_quota.error_code
      using errcode = 'P0001',
        detail = jsonb_build_object(
          'quota_tier', v_quota.quota_tier,
          'allowed_limit', v_quota.allowed_limit,
          'counted_total', v_quota.counted_total,
          'period_start', v_quota.period_start,
          'period_end', v_quota.period_end,
          'already_inserted', false,
          'is_allowed', false
        )::text,
        hint = 'event_creation_quota_exceeded';
  end if;

  return new;
end;
$$;

create or replace function public.record_persisted_event_creation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.moderation_status, 'pending_review') = 'approved' and new.status = 'active' then
    insert into public.event_creation_quota_events (
      event_id,
      owner_user_id,
      business_account_id,
      quota_tier,
      created_at
    ) values (
      new.id,
      new.host_id,
      case
        when coalesce(new.organizer_type, 'user') = 'business'
          then new.organizer_business_id
        else null
      end,
      case
        when coalesce(new.organizer_type, 'user') = 'business'
          then 'business'
        else 'normal'
      end,
      new.created_at
    ) on conflict (event_id) do nothing;
  else
    delete from public.event_creation_quota_events
    where event_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_zz_enforce_event_creation_quota on public.events;
create trigger trg_zz_enforce_event_creation_quota
before insert or update on public.events
for each row execute function public.enforce_event_creation_quota();

drop trigger if exists trg_zz_record_persisted_event_creation on public.events;
create trigger trg_zz_record_persisted_event_creation
after insert or update on public.events
for each row execute function public.record_persisted_event_creation();

revoke all on function public.get_event_creation_quota(boolean, uuid, uuid)
  from public, anon;
grant execute on function public.get_event_creation_quota(boolean, uuid, uuid)
  to authenticated;

revoke all on function public.enforce_event_creation_quota() from public, anon, authenticated;
revoke all on function public.record_persisted_event_creation() from public, anon, authenticated;

notify pgrst, 'reload schema';
