create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists personal_full_name text,
  add column if not exists personal_username text,
  add column if not exists personal_bio text,
  add column if not exists personal_avatar_url text;

create table if not exists public.business_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  business_name text not null,
  business_phone text not null,
  full_address text not null,
  website text,
  description text,
  status text not null default 'pending',
  admin_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_applications_status_check
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  constraint business_applications_name_check
    check (length(trim(business_name)) > 0),
  constraint business_applications_address_check
    check (length(trim(full_address)) >= 10)
);

create unique index if not exists business_applications_one_pending_per_user
  on public.business_applications (user_id)
  where status = 'pending';

create or replace function public.normalize_turkey_business_phone(p_phone text)
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
  elsif left(v_compact, 1) in ('3', '5') then
    v_national := v_digits;
  else
    return null;
  end if;

  if v_national !~ '^(3[0-9]{9}|5[0-9]{9})$' then
    return null;
  end if;

  if v_national ~ '^([0-9])\1{9}$' then
    return null;
  end if;

  return '+90' || v_national;
end;
$$;

create or replace function public.set_business_applications_defaults()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.business_name := btrim(new.business_name);
  new.business_phone := public.normalize_turkey_business_phone(
    new.business_phone
  );
  new.full_address := btrim(new.full_address);
  new.website := nullif(btrim(new.website), '');
  new.description := nullif(btrim(new.description), '');

  if new.business_phone is null then
    raise exception 'invalid_business_application_phone';
  end if;

  return new;
end;
$$;

drop trigger if exists business_applications_set_defaults
  on public.business_applications;
create trigger business_applications_set_defaults
before insert or update on public.business_applications
for each row execute function public.set_business_applications_defaults();

alter table public.admin_users enable row level security;
alter table public.business_applications enable row level security;

grant select on table public.admin_users to authenticated;
grant select, insert, update on table public.business_applications to authenticated;

revoke insert on table public.business_accounts from authenticated;

drop policy if exists "Users can create their own business account"
  on public.business_accounts;

create or replace function public.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users admin_user
    where admin_user.user_id = auth.uid()
  );
$$;

drop policy if exists "Users can create own business applications"
  on public.business_applications;
create policy "Users can create own business applications"
on public.business_applications
for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
);

drop policy if exists "Users can read own business applications"
  on public.business_applications;
create policy "Users can read own business applications"
on public.business_applications
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_current_user_admin()
);

drop policy if exists "Users can cancel own pending business applications"
  on public.business_applications;
create policy "Users can cancel own pending business applications"
on public.business_applications
for update
to authenticated
using (user_id = auth.uid() and status = 'pending')
with check (
  user_id = auth.uid()
  and status = 'cancelled'
  and reviewed_by is null
);

create or replace function public.business_application_username(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select left(
    coalesce(
      nullif(
        regexp_replace(
          lower(
            translate(
              p_name,
              'çğıöşüÇĞİÖŞÜ',
              'cgiosuCGIOSU'
            )
          ),
          '[^a-z0-9]+',
          '_',
          'g'
        ),
        ''
      ),
      'business'
    ),
    18
  );
$$;

create or replace function public.list_pending_business_applications()
returns setof public.business_applications
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'not_admin';
  end if;

  return query
  select *
  from public.business_applications
  where status = 'pending'
  order by created_at asc;
end;
$$;

create or replace function public.approve_business_application(
  p_application_id uuid,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_application public.business_applications%rowtype;
  v_business_id uuid;
  v_username text;
begin
  if not public.is_current_user_admin() then
    raise exception 'not_admin';
  end if;

  select *
  into v_application
  from public.business_applications
  where id = p_application_id
    and status = 'pending'
  for update;

  if v_application.id is null then
    raise exception 'business_application_not_pending';
  end if;

  v_username := left(
    public.business_application_username(v_application.business_name)
    || '_'
    || left(replace(v_application.id::text, '-', ''), 4),
    24
  );

  insert into public.business_accounts (
    owner_user_id,
    name,
    username,
    category,
    city,
    district,
    address,
    description,
    phone,
    website,
    is_verified,
    status
  )
  values (
    v_application.user_id,
    v_application.business_name,
    v_username,
    'Diğer',
    'Belirtilmedi',
    'Belirtilmedi',
    v_application.full_address,
    v_application.description,
    v_application.business_phone,
    v_application.website,
    false,
    'active'
  )
  on conflict (owner_user_id)
    where status in ('pending', 'active')
  do update set
    name = excluded.name,
    username = excluded.username,
    address = excluded.address,
    description = excluded.description,
    phone = excluded.phone,
    website = excluded.website,
    status = 'active',
    is_verified = false,
    updated_at = now()
  returning id into v_business_id;

  update public.profiles profile
  set personal_full_name = coalesce(profile.personal_full_name, profile.first_name),
      personal_username = coalesce(profile.personal_username, profile.username),
      personal_bio = coalesce(profile.personal_bio, profile.bio),
      personal_avatar_url = coalesce(profile.personal_avatar_url, profile.avatar_url),
      account_type = 'business',
      business_account_id = v_business_id,
      first_name = v_application.business_name,
      username = v_username,
      bio = coalesce(v_application.description, profile.bio),
      phone = v_application.business_phone,
      is_profile_completed = true,
      updated_at = now()
  where profile.user_id = v_application.user_id;

  update public.business_applications
  set status = 'approved',
      admin_note = nullif(btrim(p_admin_note), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      updated_at = now()
  where id = v_application.id;
end;
$$;

create or replace function public.reject_business_application(
  p_application_id uuid,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_current_user_admin() then
    raise exception 'not_admin';
  end if;

  update public.business_applications
  set status = 'rejected',
      admin_note = nullif(btrim(p_admin_note), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      updated_at = now()
  where id = p_application_id
    and status = 'pending';

  if not found then
    raise exception 'business_application_not_pending';
  end if;
end;
$$;

create or replace function public.protect_business_account_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.is_current_user_admin()
     and (
       new.owner_user_id is distinct from old.owner_user_id or
       new.business_tag is distinct from old.business_tag or
       new.is_verified is distinct from old.is_verified or
       new.status is distinct from old.status
     ) then
    raise exception 'Business moderation fields cannot be changed by clients.';
  end if;

  return new;
end;
$$;

create or replace function public.switch_profile_account_type(p_account_type text)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_account_type not in ('user', 'business') then
    raise exception 'invalid_account_type';
  end if;

  if p_account_type = 'business' then
    raise exception 'business_application_required';
  end if;

  update public.profiles profile
  set account_type = 'user',
      first_name = coalesce(profile.personal_full_name, profile.first_name),
      username = coalesce(profile.personal_username, profile.username),
      bio = coalesce(profile.personal_bio, profile.bio),
      avatar_url = coalesce(profile.personal_avatar_url, profile.avatar_url),
      updated_at = now()
  where profile.user_id = v_user_id;

  update public.events event
  set status = 'cancelled',
      updated_at = now()
  where event.host_id = v_user_id
    and coalesce(event.organizer_type, 'user') = 'business'
    and event.status = 'active'
    and event.event_date >= now();

  return query
  select *
  from public.profiles
  where user_id = v_user_id;
end;
$$;

revoke all on function public.is_current_user_admin() from public;
revoke all on function public.list_pending_business_applications() from public;
revoke all on function public.approve_business_application(uuid, text) from public;
revoke all on function public.reject_business_application(uuid, text) from public;

grant execute on function public.is_current_user_admin() to authenticated;
grant execute on function public.list_pending_business_applications()
  to authenticated;
grant execute on function public.approve_business_application(uuid, text)
  to authenticated;
grant execute on function public.reject_business_application(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
