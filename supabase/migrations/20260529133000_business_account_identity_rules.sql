alter table public.profiles
  add column if not exists account_type text not null default 'user',
  add column if not exists business_account_id uuid references public.business_accounts(id);

alter table public.profiles
  drop constraint if exists profiles_account_type_check;

alter table public.profiles
  add constraint profiles_account_type_check
  check (account_type in ('user', 'business')) not valid;

with owner_business as (
  select distinct on (business.owner_user_id)
    business.owner_user_id,
    business.id
  from public.business_accounts business
  where business.status in ('active', 'pending')
  order by business.owner_user_id, business.created_at desc
)
update public.profiles profile
set account_type = 'business',
    business_account_id = owner_business.id,
    updated_at = now()
from owner_business
where profile.user_id = owner_business.owner_user_id;

update public.profiles
set account_type = 'user',
    business_account_id = null
where account_type = 'business'
  and not exists (
    select 1
    from public.business_accounts business
    where business.id = profiles.business_account_id
      and business.owner_user_id = profiles.user_id
      and business.status in ('active', 'pending')
  );

create or replace function public.set_profile_business_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('active', 'pending') then
    update public.profiles
    set account_type = 'business',
        business_account_id = new.id,
        updated_at = now()
    where user_id = new.owner_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists business_accounts_set_profile_identity
  on public.business_accounts;
create trigger business_accounts_set_profile_identity
after insert or update of status
on public.business_accounts
for each row execute function public.set_profile_business_identity();

drop function if exists public.get_public_profile_detail(uuid);
create function public.get_public_profile_detail(p_user_id uuid)
returns table (
  user_id uuid,
  username text,
  tag text,
  first_name text,
  last_name text,
  city text,
  district text,
  avatar_url text,
  bio text,
  trust_score integer,
  is_private boolean,
  account_type text,
  business_account_id uuid,
  business_name text,
  business_username text,
  business_tag text,
  business_category text,
  business_custom_category text,
  business_city text,
  business_district text,
  business_description text,
  business_logo_url text,
  business_cover_url text,
  business_is_verified boolean,
  followers_count bigint,
  following_count bigint,
  is_following boolean,
  is_followed_by boolean,
  pending_follow_request_by_me boolean,
  can_view_extended_profile boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.user_id,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.last_name::text,
    profile.city::text,
    profile.district::text,
    profile.avatar_url::text,
    profile.bio::text,
    case
      when profile.account_type = 'business' then null
      else profile.trust_score::integer
    end,
    case
      when profile.account_type = 'business' then false
      else coalesce(profile.is_private, false)
    end,
    profile.account_type::text,
    business.id,
    business.name::text,
    business.username::text,
    business.business_tag::text,
    business.category::text,
    business.custom_category::text,
    business.city::text,
    business.district::text,
    business.description::text,
    business.logo_url::text,
    business.cover_url::text,
    coalesce(business.is_verified, false),
    (
      select count(*)
      from public.follows follower_rows
      where follower_rows.following_id = profile.user_id
    ) as followers_count,
    (
      select count(*)
      from public.follows following_rows
      where following_rows.follower_id = profile.user_id
    ) as following_count,
    exists (
      select 1
      from public.follows my_follow_rows
      where my_follow_rows.follower_id = auth.uid()
        and my_follow_rows.following_id = profile.user_id
    ) as is_following,
    exists (
      select 1
      from public.follows follows_me_rows
      where follows_me_rows.follower_id = profile.user_id
        and follows_me_rows.following_id = auth.uid()
    ) as is_followed_by,
    exists (
      select 1
      from public.follow_requests request_rows
      where request_rows.requester_id = auth.uid()
        and request_rows.target_user_id = profile.user_id
        and request_rows.status = 'pending'
    ) as pending_follow_request_by_me,
    (
      profile.account_type = 'business'
      or auth.uid() = profile.user_id
      or coalesce(profile.is_private, false) = false
      or exists (
        select 1
        from public.follows viewer_follow_rows
        where viewer_follow_rows.follower_id = auth.uid()
          and viewer_follow_rows.following_id = profile.user_id
      )
    ) as can_view_extended_profile
  from public.profiles profile
  left join lateral (
    select business.*
    from public.business_accounts business
    where business.status = 'active'
      and (
        business.id = profile.business_account_id
        or (
          profile.business_account_id is null
          and business.owner_user_id = profile.user_id
        )
      )
    order by business.created_at desc
    limit 1
  ) business on profile.account_type = 'business'
  where profile.user_id = p_user_id
    and auth.uid() is not null;
$$;

drop function if exists public.get_public_profile_preview(text);
create function public.get_public_profile_preview(p_user_id text)
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean,
  account_type text,
  business_name text,
  business_username text,
  business_tag text,
  business_logo_url text,
  business_is_verified boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    case
      when profile.account_type = 'business' then null
      else profile.trust_score::integer
    end,
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    business.name::text,
    business.username::text,
    business.business_tag::text,
    business.logo_url::text,
    coalesce(business.is_verified, false)
  from public.profiles profile
  left join lateral (
    select business.*
    from public.business_accounts business
    where business.status = 'active'
      and (
        business.id = profile.business_account_id
        or (
          profile.business_account_id is null
          and business.owner_user_id = profile.user_id
        )
      )
    order by business.created_at desc
    limit 1
  ) business on profile.account_type = 'business'
  where profile.user_id::text = p_user_id
    and auth.uid() is not null;
$$;

drop function if exists public.get_public_profile_previews(text[]);
create function public.get_public_profile_previews(p_user_ids text[])
returns table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean,
  account_type text,
  business_name text,
  business_username text,
  business_tag text,
  business_logo_url text,
  business_is_verified boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    case
      when profile.account_type = 'business' then null
      else profile.trust_score::integer
    end,
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    business.name::text,
    business.username::text,
    business.business_tag::text,
    business.logo_url::text,
    coalesce(business.is_verified, false)
  from public.profiles profile
  left join lateral (
    select business.*
    from public.business_accounts business
    where business.status = 'active'
      and (
        business.id = profile.business_account_id
        or (
          profile.business_account_id is null
          and business.owner_user_id = profile.user_id
        )
      )
    order by business.created_at desc
    limit 1
  ) business on profile.account_type = 'business'
  where profile.user_id::text = any(p_user_ids)
    and auth.uid() is not null;
$$;

revoke all on function public.get_public_profile_detail(uuid) from public;
revoke all on function public.get_public_profile_preview(text) from public;
revoke all on function public.get_public_profile_previews(text[]) from public;
grant execute on function public.get_public_profile_detail(uuid) to authenticated;
grant execute on function public.get_public_profile_preview(text) to authenticated;
grant execute on function public.get_public_profile_previews(text[]) to authenticated;

create or replace function public.normalized_business_rule_text(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(
    translate(
      coalesce(p_value, ''),
      'ÇĞİÖŞÜçğıöşü',
      'CGIOSUcgiosu'
    )
  );
$$;

create or replace function public.business_category_allows_activity(
  p_category text,
  p_custom_category text,
  p_activity text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_category text := public.normalized_business_rule_text(
    case
      when btrim(coalesce(p_category, '')) = 'Diğer' then p_custom_category
      else p_category
    end
  );
  v_activity text := public.normalized_business_rule_text(p_activity);
begin
  if btrim(coalesce(p_category, '')) = 'Diğer' then
    return length(btrim(coalesce(p_activity, ''))) between 2 and 40;
  end if;

  if v_category like '%at ciftligi%' then
    return v_activity in ('at binme', 'doga gezisi', 'outdoor');
  end if;
  if v_category like '%hali saha%' or v_category like '%futbol sahasi%' then
    return v_activity = 'futbol';
  end if;
  if v_category like '%basketbol%' then
    return v_activity = 'basketbol';
  end if;
  if v_category like '%voleybol%' then
    return v_activity = 'voleybol';
  end if;
  if v_category like '%tenis%' then
    return v_activity = 'tenis';
  end if;
  if v_category like '%padel%' then
    return v_activity = 'padel';
  end if;
  if v_category like '%yoga%' then
    return v_activity = 'yoga';
  end if;
  if v_category like '%pilates%' then
    return v_activity = 'pilates';
  end if;
  if v_category like '%spor salonu%' or v_category like '%fitness%' or
     v_category like '%crossfit%' then
    return v_activity = 'fitness';
  end if;
  if v_category like '%outdoor%' or v_category like '%doga%' or
     v_category like '%kamp%' or v_category like '%trekking%' or
     v_category like '%yuruyus%' then
    return v_activity in ('trekking', 'kamp', 'outdoor');
  end if;

  return length(btrim(coalesce(p_activity, ''))) between 2 and 40;
end;
$$;

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

  if new.organizer_type = 'user' then
    new.organizer_business_id = null;
    new.is_paid = false;
    new.price_amount = null;
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

drop trigger if exists events_validate_organizer on public.events;
create trigger events_validate_organizer
before insert or update of
  host_id,
  organizer_type,
  organizer_user_id,
  organizer_business_id,
  sport_type,
  is_paid,
  price_amount,
  price_currency
on public.events
for each row execute function public.validate_event_organizer();

notify pgrst, 'reload schema';
