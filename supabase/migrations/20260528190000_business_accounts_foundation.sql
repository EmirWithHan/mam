create table if not exists public.business_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  username text not null,
  business_tag text not null default lpad(floor(random() * 10000)::int::text, 4, '0'),
  category text not null,
  city text not null,
  district text not null,
  address text,
  description text,
  phone text,
  website text,
  instagram text,
  logo_url text,
  cover_url text,
  is_verified boolean not null default false,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_accounts_status_check
    check (status in ('pending', 'active', 'rejected', 'suspended')),
  constraint business_accounts_name_check check (length(trim(name)) > 0),
  constraint business_accounts_username_check
    check (username = lower(username) and username ~ '^[a-z0-9_]{2,24}$'),
  constraint business_accounts_category_check check (length(trim(category)) > 0),
  constraint business_accounts_city_check check (length(trim(city)) > 0),
  constraint business_accounts_district_check check (length(trim(district)) > 0),
  constraint business_accounts_tag_check check (business_tag ~ '^[0-9]{4}$')
);

create unique index if not exists business_accounts_username_business_tag_key
  on public.business_accounts (username, business_tag);

create unique index if not exists business_accounts_owner_one_account_idx
  on public.business_accounts (owner_user_id)
  where status in ('pending', 'active');

create table if not exists public.business_members (
  business_id uuid not null references public.business_accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner',
  created_at timestamptz not null default now(),
  primary key (business_id, user_id),
  constraint business_members_role_check check (role in ('owner', 'admin', 'staff'))
);

alter table public.business_accounts enable row level security;
alter table public.business_members enable row level security;

create or replace function public.set_business_accounts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  new.username = lower(trim(new.username));
  return new;
end;
$$;

drop trigger if exists business_accounts_set_updated_at on public.business_accounts;
create trigger business_accounts_set_updated_at
before insert or update on public.business_accounts
for each row execute function public.set_business_accounts_updated_at();

create or replace function public.protect_business_account_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and (
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

drop trigger if exists business_accounts_protect_moderation_fields
  on public.business_accounts;
create trigger business_accounts_protect_moderation_fields
before update on public.business_accounts
for each row execute function public.protect_business_account_moderation_fields();

drop policy if exists "Business accounts are visible when active or owned"
  on public.business_accounts;
create policy "Business accounts are visible when active or owned"
on public.business_accounts
for select
to authenticated
using (status = 'active' or owner_user_id = auth.uid());

drop policy if exists "Users can create their own business account"
  on public.business_accounts;
create policy "Users can create their own business account"
on public.business_accounts
for insert
to authenticated
with check (
  owner_user_id = auth.uid() and
  status = 'active' and
  is_verified = false
);

drop policy if exists "Owners can update basic business fields"
  on public.business_accounts;
create policy "Owners can update basic business fields"
on public.business_accounts
for update
to authenticated
using (owner_user_id = auth.uid() and status in ('pending', 'active'))
with check (owner_user_id = auth.uid() and status in ('pending', 'active'));

drop policy if exists "Business members can read their memberships"
  on public.business_members;
create policy "Business members can read their memberships"
on public.business_members
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Business owners can create owner membership"
  on public.business_members;
create policy "Business owners can create owner membership"
on public.business_members
for insert
to authenticated
with check (
  user_id = auth.uid() and
  role = 'owner' and
  exists (
    select 1
    from public.business_accounts b
    where b.id = business_id
      and b.owner_user_id = auth.uid()
  )
);

create or replace function public.add_business_owner_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.business_members (business_id, user_id, role)
  values (new.id, new.owner_user_id, 'owner')
  on conflict (business_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists business_accounts_add_owner_member
  on public.business_accounts;
create trigger business_accounts_add_owner_member
after insert on public.business_accounts
for each row execute function public.add_business_owner_member();
