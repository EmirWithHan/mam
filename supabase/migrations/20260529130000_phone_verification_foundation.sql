alter table public.profiles
  add column if not exists phone_number text,
  add column if not exists phone_verified boolean not null default false,
  add column if not exists phone_verified_at timestamptz;

create or replace function public.normalize_turkey_phone_number(p_phone text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_digits text;
begin
  if p_phone is null or btrim(p_phone) = '' then
    return null;
  end if;

  v_digits := regexp_replace(p_phone, '[^0-9]', '', 'g');

  if length(v_digits) = 12 and left(v_digits, 2) = '90' then
    return '+' || v_digits;
  end if;

  if length(v_digits) = 11 and left(v_digits, 1) = '0' then
    return '+90' || substring(v_digits from 2);
  end if;

  if length(v_digits) = 10 and left(v_digits, 1) = '5' then
    return '+90' || v_digits;
  end if;

  return p_phone;
end;
$$;

update public.profiles
set phone_number = public.normalize_turkey_phone_number(
    coalesce(phone_number, phone)
  )
where coalesce(phone_number, phone) is not null;

update public.profiles
set phone_verified = false,
    phone_verified_at = null
where phone_number is null;

update public.profiles
set phone_number = null,
    phone_verified = false,
    phone_verified_at = null
where phone_number is not null
  and (
    length(regexp_replace(phone_number, '\D', '', 'g')) < 10
    or phone_number !~ '^\+905[0-9]{9}$'
  );

with ranked as (
  select
    id,
    phone_number,
    row_number() over (
      partition by phone_number
      order by id
    ) as rn
  from public.profiles
  where phone_number is not null
)
update public.profiles profile
set phone_number = null,
    phone_verified = false,
    phone_verified_at = null
from ranked
where profile.id = ranked.id
  and ranked.rn > 1;

drop index if exists public.profiles_phone_number_unique;
create unique index profiles_phone_number_unique
  on public.profiles (phone_number)
  where phone_number is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_phone_number_format_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_phone_number_format_check
      check (
        phone_number is null
        or phone_number ~ '^\+905[0-9]{9}$'
      ) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_phone_verified_requires_number'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_phone_verified_requires_number
      check (
        phone_verified = false
        or phone_number is not null
      ) not valid;
  end if;
end $$;

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
