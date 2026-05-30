with ranked_businesses as (
  select
    business.id,
    row_number() over (
      partition by business.owner_user_id
      order by
        case business.status when 'active' then 0 when 'pending' then 1 else 2 end,
        business.created_at desc,
        business.id desc
    ) as rn
  from public.business_accounts business
  where business.status in ('active', 'pending')
)
update public.business_accounts business
set status = 'suspended',
    updated_at = now()
from ranked_businesses ranked
where business.id = ranked.id
  and ranked.rn > 1;

drop index if exists public.business_accounts_owner_one_account_idx;
create unique index business_accounts_owner_one_account_idx
  on public.business_accounts (owner_user_id)
  where status in ('pending', 'active');

with canonical_business as (
  select distinct on (business.owner_user_id)
    business.owner_user_id,
    business.id
  from public.business_accounts business
  where business.status in ('active', 'pending')
  order by
    business.owner_user_id,
    case business.status when 'active' then 0 when 'pending' then 1 else 2 end,
    business.created_at desc,
    business.id desc
)
update public.profiles profile
set business_account_id = canonical_business.id,
    updated_at = now()
from canonical_business
where profile.user_id = canonical_business.owner_user_id
  and profile.account_type = 'business';

create or replace function public.switch_profile_account_type(p_account_type text)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_business_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_account_type not in ('user', 'business') then
    raise exception 'invalid_account_type';
  end if;

  if p_account_type = 'business' then
    select business.id
    into v_business_id
    from public.business_accounts business
    where business.owner_user_id = v_user_id
      and business.status in ('active', 'pending')
    order by
      case business.status when 'active' then 0 when 'pending' then 1 else 2 end,
      business.created_at desc,
      business.id desc
    limit 1;

    if v_business_id is null then
      raise exception 'business_account_missing';
    end if;

    update public.profiles
    set account_type = 'business',
        business_account_id = v_business_id,
        updated_at = now()
    where user_id = v_user_id;
  else
    update public.profiles
    set account_type = 'user',
        updated_at = now()
    where user_id = v_user_id;

    update public.events event
    set status = 'cancelled',
        is_sponsored = false,
        sponsored_until = null,
        sponsored_priority = 0,
        updated_at = now()
    where event.host_id = v_user_id
      and coalesce(event.organizer_type, 'user') = 'business'
      and event.status = 'active'
      and event.event_date >= now();
  end if;

  return query
  select *
  from public.profiles
  where user_id = v_user_id;
end;
$$;

comment on function public.switch_profile_account_type(text)
  is 'Business mode works like a professional account mode on the same profile. Business events require profiles.account_type = business; switching back to user cancels future active business events.';

create or replace function public.validate_event_organizer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_account_type text;
  v_business public.business_accounts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if new.host_id is distinct from auth.uid() then
    raise exception 'event_host_must_be_current_user';
  end if;

  select profile.account_type
  into v_profile_account_type
  from public.profiles profile
  where profile.user_id = auth.uid();

  new.organizer_type = coalesce(nullif(new.organizer_type, ''), 'user');
  new.organizer_user_id = auth.uid();
  new.price_currency = coalesce(nullif(new.price_currency, ''), 'TRY');

  if coalesce(v_profile_account_type, 'user') = 'business'
     and new.organizer_type <> 'business' then
    raise exception 'business_accounts_must_create_business_events';
  end if;

  if coalesce(v_profile_account_type, 'user') <> 'business'
     and new.organizer_type = 'business' then
    raise exception 'business_events_require_business_account_type';
  end if;

  if new.organizer_type = 'user' then
    new.organizer_business_id = null;
    new.is_paid = false;
    new.price_amount = null;
    new.price_currency = 'TRY';
    return new;
  end if;

  if new.organizer_type <> 'business' then
    raise exception 'invalid_event_organizer_type';
  end if;

  if new.organizer_business_id is null then
    raise exception 'business_event_requires_business';
  end if;

  select *
  into v_business
  from public.business_accounts business
  where business.id = new.organizer_business_id
    and business.owner_user_id = auth.uid()
    and business.status = 'active';

  if v_business.id is null then
    raise exception 'business_event_not_owned';
  end if;

  if not public.business_category_allows_activity(
    v_business.category,
    v_business.custom_category,
    new.sport_type
  ) then
    raise exception 'business_event_activity_not_allowed';
  end if;

  if new.is_paid then
    if new.price_amount is null or new.price_amount <= 0 then
      raise exception 'business_event_price_required';
    end if;
    new.price_currency = 'TRY';
  else
    new.price_amount = null;
    new.price_currency = 'TRY';
  end if;

  return new;
end;
$$;

create or replace function public.get_public_profile_event_history(p_user_id uuid)
returns table (
  event_id uuid,
  title text,
  sport_type text,
  city text,
  district text,
  location_text text,
  status text,
  approved_count integer,
  capacity_total integer,
  event_date timestamptz,
  created_at timestamptz,
  role text
)
language sql
stable
security definer
set search_path = ''
as $$
  with target_profile as (
    select
      profile.user_id,
      coalesce(profile.is_private, false) as is_private,
      coalesce(profile.account_type, 'user') as account_type
    from public.profiles profile
    where profile.user_id = p_user_id
  ),
  visibility as (
    select
      target_profile.user_id,
      target_profile.account_type,
      (
        auth.uid() = target_profile.user_id
        or target_profile.is_private = false
        or exists (
          select 1
          from public.follows viewer_follow_rows
          where viewer_follow_rows.follower_id = auth.uid()
            and viewer_follow_rows.following_id = target_profile.user_id
        )
      ) as can_view
    from target_profile
    where auth.uid() is not null
  ),
  hosted_events as (
    select
      event.id as event_id,
      event.title::text,
      event.sport_type::text,
      event.city::text,
      event.district::text,
      event.location_text::text,
      event.status::text,
      event.approved_count::integer,
      event.capacity_total::integer,
      event.event_date,
      event.created_at,
      'host'::text as role
    from public.events event
    join visibility on visibility.user_id = event.host_id
    where visibility.can_view
      and event.status in ('active', 'completed')
      and (
        coalesce(event.organizer_type, 'user') <> 'business'
        or visibility.account_type = 'business'
      )
  ),
  participant_events as (
    select
      event.id as event_id,
      event.title::text,
      event.sport_type::text,
      event.city::text,
      event.district::text,
      event.location_text::text,
      event.status::text,
      event.approved_count::integer,
      event.capacity_total::integer,
      event.event_date,
      event.created_at,
      'participant'::text as role
    from public.event_participants participant
    join public.events event
      on event.id = participant.event_id
    join visibility
      on visibility.user_id = participant.user_id
    where visibility.can_view
      and event.status in ('active', 'completed')
      and participant.attendance_status in ('planned', 'attended')
      and participant.role = 'participant'
  )
  select *
  from hosted_events
  union all
  select *
  from participant_events
  order by event_date desc;
$$;

revoke all on function public.switch_profile_account_type(text) from public;
revoke all on function public.get_public_profile_event_history(uuid) from public;
grant execute on function public.switch_profile_account_type(text) to authenticated;
grant execute on function public.get_public_profile_event_history(uuid) to authenticated;

notify pgrst, 'reload schema';
