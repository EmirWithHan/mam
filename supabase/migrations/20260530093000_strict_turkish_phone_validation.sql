create or replace function public.normalize_turkey_phone_number(p_phone text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_compact text;
  v_digits text;
  v_national text;
begin
  if p_phone is null or btrim(p_phone) = '' then
    return null;
  end if;

  v_compact := regexp_replace(btrim(p_phone), '[\s\-\(\)]', '', 'g');
  v_digits := regexp_replace(p_phone, '[^0-9]', '', 'g');

  if v_digits = '' then
    return null;
  end if;

  if left(v_compact, 3) = '+90' then
    v_national := substring(v_digits from 3);
  elsif left(v_compact, 4) = '0090' then
    v_national := substring(v_digits from 5);
  elsif left(v_compact, 1) = '0' then
    v_national := substring(v_digits from 2);
  elsif left(v_compact, 1) = '5' then
    v_national := v_digits;
  else
    return null;
  end if;

  if v_national !~ '^5[0-9]{9}$' then
    return null;
  end if;

  if v_national ~ '^([0-9])\1{9}$' then
    return null;
  end if;

  if v_national in (
    '5000000000',
    '5111111111',
    '5222222222',
    '5333333333',
    '5444444444',
    '5555555555',
    '5666666666',
    '5777777777',
    '5888888888',
    '5999999999',
    '5123123123',
    '5123456789'
  ) then
    return null;
  end if;

  return '+90' || v_national;
end;
$$;

update public.profiles
set phone_number = public.normalize_turkey_phone_number(
      coalesce(phone_number, phone)
    ),
    phone_verified = false,
    phone_verified_at = null
where coalesce(phone_number, phone) is not null
  and public.normalize_turkey_phone_number(coalesce(phone_number, phone)) is null;

update public.profiles
set phone_number = public.normalize_turkey_phone_number(
      coalesce(phone_number, phone)
    )
where coalesce(phone_number, phone) is not null
  and public.normalize_turkey_phone_number(coalesce(phone_number, phone)) is not null;

update public.profiles
set phone_verified = false,
    phone_verified_at = null
where phone_number is null;

with ranked as (
  select
    id,
    phone_number,
    row_number() over (
      partition by phone_number
      order by updated_at desc nulls last, id
    ) as rn
  from public.profiles
  where phone_number is not null
)
update public.profiles profile
set phone_number = null,
    phone_verified = false,
    phone_verified_at = null,
    updated_at = now()
from ranked
where profile.id = ranked.id
  and ranked.rn > 1;

drop index if exists public.profiles_phone_number_unique;
create unique index profiles_phone_number_unique
  on public.profiles (phone_number)
  where phone_number is not null;

alter table public.profiles
  drop constraint if exists profiles_phone_number_format_check;

alter table public.profiles
  add constraint profiles_phone_number_format_check
  check (
    phone_number is null
    or public.normalize_turkey_phone_number(phone_number) = phone_number
  ) not valid;

alter table public.profiles
  drop constraint if exists profiles_phone_verified_requires_number;

alter table public.profiles
  add constraint profiles_phone_verified_requires_number
  check (
    phone_verified = false
    or phone_number is not null
  ) not valid;

create or replace function public.normalize_profile_phone_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.phone_number := public.normalize_turkey_phone_number(new.phone_number);

  if TG_OP = 'INSERT' or new.phone_number is distinct from old.phone_number then
    new.phone_verified := false;
    new.phone_verified_at := null;
  end if;

  if new.phone_number is null then
    new.phone_verified := false;
    new.phone_verified_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_normalize_phone_fields on public.profiles;
create trigger profiles_normalize_phone_fields
before insert or update on public.profiles
for each row execute function public.normalize_profile_phone_fields();

notify pgrst, 'reload schema';
