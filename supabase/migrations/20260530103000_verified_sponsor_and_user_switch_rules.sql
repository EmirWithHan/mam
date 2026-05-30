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
  is 'Business mode works like a professional account mode on the same profile. Switching back to user restores the personal public identity and cancels future active business events without touching admin-only sponsorship fields.';

update public.events event
set is_sponsored = false,
    sponsored_until = null,
    sponsored_priority = 0,
    updated_at = now()
from public.business_accounts business
where event.organizer_business_id = business.id
  and coalesce(event.is_sponsored, false)
  and coalesce(business.is_verified, false) = false;

create or replace function public.protect_event_sponsorship_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_is_verified boolean;
begin
  if auth.uid() is not null then
    raise exception 'event_sponsorship_fields_are_admin_only';
  end if;

  if new.is_sponsored and new.organizer_type <> 'business' then
    raise exception 'sponsored_event_must_be_business';
  end if;

  if new.is_sponsored then
    select coalesce(business.is_verified, false)
    into v_business_is_verified
    from public.business_accounts business
    where business.id = new.organizer_business_id;

    if coalesce(v_business_is_verified, false) = false then
      raise exception 'sponsored_event_requires_verified_business';
    end if;
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';
