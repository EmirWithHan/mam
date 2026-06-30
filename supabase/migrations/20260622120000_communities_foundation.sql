-- Migration: 20260622120000_communities_foundation.sql
-- Description: Implement secure communities core tables, triggers, policies, and RPCs.

-- 1. Create communities table
create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text not null,
  slug text not null unique,
  description text not null,
  short_description text not null,
  avatar_url text,
  cover_image_url text,
  category text not null,
  sport_interests text[] not null default '{}',
  city text not null,
  district text,
  location_label text,
  visibility text not null default 'public',
  join_policy text not null default 'open',
  status text not null default 'active',
  rules text not null default '',
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  member_count integer not null default 0,
  follower_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,

  constraint communities_name_length check (char_length(trim(name)) >= 3 and char_length(trim(name)) <= 50),
  constraint communities_description_length check (char_length(trim(description)) >= 10),
  constraint communities_slug_check check (slug ~ '^[a-z0-9-]+$'),
  constraint communities_visibility_check check (visibility in ('public', 'private')),
  constraint communities_join_policy_check check (join_policy in ('open', 'approval_required', 'invite_only')),
  constraint communities_status_check check (status in ('active', 'archived', 'suspended')),
  constraint communities_city_check check (char_length(trim(city)) > 0),
  constraint communities_category_check check (char_length(trim(category)) > 0)
);

-- 2. Create memberships table
create table if not exists public.community_memberships (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  business_account_id uuid references public.business_accounts(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint community_memberships_actor_check check (
    (user_id is not null and business_account_id is null) or
    (user_id is null and business_account_id is not null)
  ),
  constraint community_memberships_role_check check (role in ('owner', 'manager', 'assistant_manager', 'member')),
  constraint community_memberships_status_check check (status in ('pending', 'active', 'rejected', 'left', 'banned', 'invited')),
  -- Business actor joins as member only. Owner/manager/assistant roles are forbidden.
  constraint community_memberships_business_role_limit check (
    business_account_id is null or role = 'member'
  )
);

-- 3. Unique indexes to enforce single row per actor per community
create unique index if not exists community_memberships_user_uniq_idx
  on public.community_memberships (community_id, user_id)
  where user_id is not null;

create unique index if not exists community_memberships_business_uniq_idx
  on public.community_memberships (community_id, business_account_id)
  where business_account_id is not null;

-- 4. Create community follows table (only users can follow)
create table if not exists public.community_follows (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

-- 5. Create append-only community membership audit table
create table if not exists public.community_membership_audit (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  membership_id uuid not null,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  old_role text,
  new_role text,
  old_status text,
  new_status text,
  created_at timestamptz not null default now()
);

-- Enable RLS
alter table public.communities enable row level security;
alter table public.community_memberships enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_membership_audit enable row level security;

-- 6. Trigger to sync community membership counts
create or replace function public.sync_community_membership_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta integer := 0;
  v_community_id uuid;
begin
  if TG_OP = 'INSERT' then
    v_community_id := new.community_id;
    if new.status = 'active' then
      v_delta := 1;
    end if;
  elsif TG_OP = 'UPDATE' then
    v_community_id := new.community_id;
    if old.status != 'active' and new.status = 'active' then
      v_delta := 1;
    elsif old.status = 'active' and new.status != 'active' then
      v_delta := -1;
    end if;
  elsif TG_OP = 'DELETE' then
    v_community_id := old.community_id;
    if old.status = 'active' then
      v_delta := -1;
    end if;
  end if;

  if v_delta != 0 and v_community_id is not null then
    update public.communities
    set member_count = greatest(0, member_count + v_delta)
    where id = v_community_id;
  end if;

  return null;
end;
$$;

drop trigger if exists community_memberships_sync_count on public.community_memberships;
create trigger community_memberships_sync_count
after insert or update or delete on public.community_memberships
for each row execute function public.sync_community_membership_count();

-- 7. Trigger to sync community follows count
create or replace function public.sync_community_follower_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta integer := 0;
  v_community_id uuid;
begin
  if TG_OP = 'INSERT' then
    v_community_id := new.community_id;
    v_delta := 1;
  elsif TG_OP = 'DELETE' then
    v_community_id := old.community_id;
    v_delta := -1;
  end if;

  if v_delta != 0 and v_community_id is not null then
    update public.communities
    set follower_count = greatest(0, follower_count + v_delta)
    where id = v_community_id;
  end if;

  return null;
end;
$$;

drop trigger if exists community_follows_sync_count on public.community_follows;
create trigger community_follows_sync_count
after insert or delete on public.community_follows
for each row execute function public.sync_community_follower_count();

-- 8. Trigger to log membership audit
create or replace function public.log_community_membership_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
begin
  if TG_OP = 'INSERT' then
    v_action := 'join_request';
    if new.status = 'active' then
      v_action := 'join_direct';
    end if;
    insert into public.community_membership_audit (
      community_id, membership_id, actor_id, action, new_role, new_status
    ) values (
      new.community_id, new.id, auth.uid(), v_action, new.role, new.status
    );
  elsif TG_OP = 'UPDATE' then
    if old.status != new.status and old.role != new.role then
      v_action := 'status_and_role_change';
    elsif old.status != new.status then
      if new.status = 'active' and old.status = 'pending' then
        v_action := 'approve';
      elsif new.status = 'rejected' and old.status = 'pending' then
        v_action := 'reject';
      elsif new.status = 'banned' then
        v_action := 'ban';
      elsif new.status = 'left' and old.status = 'banned' then
        v_action := 'unban';
      elsif new.status = 'left' and old.status = 'active' then
        v_action := 'leave';
      else
        v_action := 'status_change';
      end if;
    elsif old.role != new.role then
      v_action := 'role_change';
    else
      v_action := 'update';
    end if;

    insert into public.community_membership_audit (
      community_id, membership_id, actor_id, action, old_role, new_role, old_status, new_status
    ) values (
      new.community_id, new.id, auth.uid(), v_action, old.role, new.role, old.status, new.status
    );
  end if;
  return new;
end;
$$;

drop trigger if exists community_memberships_audit_log on public.community_memberships;
create trigger community_memberships_audit_log
after insert or update on public.community_memberships
for each row execute function public.log_community_membership_audit();

-- 9. Authoritative permission helper
create or replace function public.has_community_permission(
  p_community_id uuid,
  p_user_id uuid,
  p_permission text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_owner_id uuid;
begin
  select owner_user_id into v_owner_id from public.communities where id = p_community_id;
  if v_owner_id = p_user_id then
    return true;
  end if;

  select role into v_role 
  from public.community_memberships 
  where community_id = p_community_id 
    and user_id = p_user_id 
    and status = 'active';

  if v_role is null then
    return false;
  end if;

  if v_role = 'owner' then
    return true;
  end if;

  if p_permission = 'edit_profile' then
    return v_role in ('owner', 'manager');
  elsif p_permission = 'manage_requests' then
    return v_role in ('owner', 'manager', 'assistant_manager');
  elsif p_permission = 'manage_members' then
    return v_role in ('owner', 'manager', 'assistant_manager');
  elsif p_permission = 'assign_roles' then
    return v_role in ('owner', 'manager');
  elsif p_permission = 'transfer_ownership' then
    return v_role = 'owner';
  elsif p_permission = 'archive' then
    return v_role = 'owner';
  end if;

  return false;
end;
$$;

-- Revoke execute on internal permission helper to prevent client bypass
revoke execute on function public.has_community_permission(uuid, uuid, text) from public, authenticated, anon;

-- Client-callable permission helper that derives auth.uid() server-side
create or replace function public.has_current_user_community_permission(
  p_community_id uuid,
  p_permission text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.has_community_permission(p_community_id, auth.uid(), p_permission);
end;
$$;

-- 10. Recompute counts helper for counter drift
create or replace function public.recompute_community_counts(p_community_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.communities
  set 
    member_count = (
      select count(*) 
      from public.community_memberships 
      where community_id = p_community_id 
        and status = 'active'
    ),
    follower_count = (
      select count(*) 
      from public.community_follows 
      where community_id = p_community_id
    )
  where id = p_community_id;
end;
$$;

-- 11. Create secure discovery view
create or replace view public.community_discovery as
select
  id,
  name,
  slug,
  avatar_url,
  short_description,
  category,
  sport_interests,
  city,
  district,
  member_count,
  follower_count,
  visibility,
  join_policy,
  status,
  created_at
from public.communities
where status = 'active';

grant select on public.community_discovery to authenticated;

-- 12. RPC Mutations
-- Create Community
create or replace function public.create_community(
  p_name text,
  p_slug text,
  p_description text,
  p_short_description text,
  p_category text,
  p_sport_interests text[],
  p_city text,
  p_district text default null,
  p_location_label text default null,
  p_visibility text default 'public',
  p_join_policy text default 'open',
  p_rules text default '',
  p_avatar_url text default null,
  p_cover_image_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_community_id uuid;
  v_user_id uuid;
  v_normalized_name text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  v_normalized_name := lower(trim(p_name));

  -- Deterministic Moderation Checks
  if v_normalized_name ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' or
     lower(p_description) ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' or
     lower(p_short_description) ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)'
  then
    raise exception 'İçerik kurallarımıza uygun görünmüyor.' using errcode = 'MOD01';
  end if;

  if v_normalized_name ~* '(akanzi|match a man|matchaman)\s*(official|destek|yonetim|yönetim|admin|mod|yönetici)' then
    raise exception 'Bu isimde topluluk oluşturamazsınız.' using errcode = 'MOD02';
  end if;

  if v_normalized_name ~ '([a-z0-9])\1{4,}' or
     lower(p_description) ~ '([a-z0-9])\1{5,}'
  then
    raise exception 'Tekrarlayan veya anlamsız karakterler tespit edildi.' using errcode = 'MOD03';
  end if;

  if length(trim(p_name)) < 3 or length(trim(p_name)) > 50 then
    raise exception 'Topluluk adı 3 ile 50 karakter arasında olmalıdır.' using errcode = 'MOD04';
  end if;
  if length(trim(p_description)) < 10 then
    raise exception 'Açıklama en az 10 karakter olmalıdır.' using errcode = 'MOD05';
  end if;

  if p_city is null or length(trim(p_city)) = 0 then
    raise exception 'Şehir zorunludur.' using errcode = 'MOD06';
  end if;

  if length(trim(p_category)) = 0 then
    raise exception 'Kategori zorunludur.' using errcode = 'MOD07';
  end if;

  if p_slug !~ '^[a-z0-9-]+$' then
    raise exception 'Slug geçersiz formatta.' using errcode = 'SLUG1';
  end if;
  if exists (select 1 from public.communities where slug = p_slug) then
    raise exception 'Bu benzersiz adres zaten alınmış.' using errcode = 'SLUG2';
  end if;

  if exists (
    select 1 from public.communities 
    where normalized_name = v_normalized_name 
      and city = p_city 
      and coalesce(district, '') = coalesce(p_district, '')
      and category = p_category
      and status = 'active'
  ) then
    raise exception 'Bu isimde bir topluluk bu bölgede zaten mevcut.' using errcode = 'DUP01';
  end if;

  insert into public.communities (
    name, normalized_name, slug, description, short_description, category, sport_interests,
    city, district, location_label, visibility, join_policy, rules, owner_user_id,
    avatar_url, cover_image_url, member_count, follower_count
  ) values (
    p_name, v_normalized_name, p_slug, p_description, p_short_description, p_category, p_sport_interests,
    p_city, p_district, p_location_label, p_visibility, p_join_policy, p_rules, v_user_id,
    p_avatar_url, p_cover_image_url, 0, 0
  ) returning id into v_community_id;

  insert into public.community_memberships (
    community_id, user_id, role, status
  ) values (
    v_community_id, v_user_id, 'owner', 'active'
  );

  return v_community_id;
end;
$$;

-- Update Community
create or replace function public.update_community(
  p_id uuid,
  p_name text,
  p_slug text,
  p_description text,
  p_short_description text,
  p_category text,
  p_sport_interests text[],
  p_city text,
  p_district text default null,
  p_location_label text default null,
  p_visibility text default 'public',
  p_join_policy text default 'open',
  p_rules text default '',
  p_avatar_url text default null,
  p_cover_image_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_normalized_name text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  if not public.has_community_permission(p_id, v_user_id, 'edit_profile') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  v_normalized_name := lower(trim(p_name));

  -- Deterministic Moderation Checks
  if v_normalized_name ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' or
     lower(p_description) ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' or
     lower(p_short_description) ~* '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)'
  then
    raise exception 'İçerik kurallarımıza uygun görünmüyor.' using errcode = 'MOD01';
  end if;

  if v_normalized_name ~* '(akanzi|match a man|matchaman)\s*(official|destek|yonetim|yönetim|admin|mod|yönetici)' then
    raise exception 'Bu isimde topluluk oluşturamazsınız.' using errcode = 'MOD02';
  end if;

  if v_normalized_name ~ '([a-z0-9])\1{4,}' or
     lower(p_description) ~ '([a-z0-9])\1{5,}'
  then
    raise exception 'Tekrarlayan veya anlamsız karakterler tespit edildi.' using errcode = 'MOD03';
  end if;

  if length(trim(p_name)) < 3 or length(trim(p_name)) > 50 then
    raise exception 'Topluluk adı 3 ile 50 karakter arasında olmalıdır.' using errcode = 'MOD04';
  end if;
  if length(trim(p_description)) < 10 then
    raise exception 'Açıklama en az 10 karakter olmalıdır.' using errcode = 'MOD05';
  end if;

  if p_city is null or length(trim(p_city)) = 0 then
    raise exception 'Şehir zorunludur.' using errcode = 'MOD06';
  end if;

  if p_slug !~ '^[a-z0-9-]+$' then
    raise exception 'Slug geçersiz formatta.' using errcode = 'SLUG1';
  end if;
  if exists (select 1 from public.communities where slug = p_slug and id is distinct from p_id) then
    raise exception 'Bu benzersiz adres zaten alınmış.' using errcode = 'SLUG2';
  end if;

  if exists (
    select 1 from public.communities 
    where normalized_name = v_normalized_name 
      and city = p_city 
      and coalesce(district, '') = coalesce(p_district, '')
      and category = p_category
      and status = 'active'
      and id is distinct from p_id
  ) then
    raise exception 'Bu isimde bir topluluk bu bölgede zaten mevcut.' using errcode = 'DUP01';
  end if;

  update public.communities
  set
    name = p_name,
    normalized_name = v_normalized_name,
    slug = p_slug,
    description = p_description,
    short_description = p_short_description,
    category = p_category,
    sport_interests = p_sport_interests,
    city = p_city,
    district = p_district,
    location_label = p_location_label,
    visibility = p_visibility,
    join_policy = p_join_policy,
    rules = p_rules,
    avatar_url = p_avatar_url,
    cover_image_url = p_cover_image_url,
    updated_at = now()
  where id = p_id;
end;
$$;

-- Archive Community
create or replace function public.archive_community(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  if not public.has_community_permission(p_id, v_user_id, 'archive') then
    raise exception 'Only the owner can archive the community' using errcode = '42501';
  end if;

  update public.communities
  set
    status = 'archived',
    archived_at = now(),
    updated_at = now()
  where id = p_id;
end;
$$;

-- Join Community
create or replace function public.join_community(
  p_community_id uuid,
  p_business_account_id uuid default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_community_status text;
  v_join_policy text;
  v_existing_membership_id uuid;
  v_existing_status text;
  v_existing_role text;
  v_target_status text;
  v_result json;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  select status, join_policy into v_community_status, v_join_policy
  from public.communities where id = p_community_id;

  if v_community_status is null then
    raise exception 'community_not_found' using errcode = 'C0001';
  end if;

  if v_community_status in ('archived', 'suspended') then
    raise exception 'community_archived' using errcode = 'C0002';
  end if;

  if v_join_policy = 'invite_only' then
    raise exception 'invite_only' using errcode = 'C0003';
  end if;

  if p_business_account_id is not null then
    if not exists (
      select 1 from public.business_accounts 
      where id = p_business_account_id 
        and (owner_user_id = v_user_id or exists (
          select 1 from public.business_members bm 
          where bm.business_id = p_business_account_id and bm.user_id = v_user_id
        ))
    ) then
      raise exception 'business_not_owned' using errcode = 'B0001';
    end if;
  end if;

  if v_join_policy = 'open' then
    v_target_status := 'active';
  else
    v_target_status := 'pending';
  end if;

  if p_business_account_id is not null then
    select id, status, role into v_existing_membership_id, v_existing_status, v_existing_role
    from public.community_memberships
    where community_id = p_community_id and business_account_id = p_business_account_id;
  else
    select id, status, role into v_existing_membership_id, v_existing_status, v_existing_role
    from public.community_memberships
    where community_id = p_community_id and user_id = v_user_id;
  end if;

  if v_existing_membership_id is not null then
    if v_existing_status = 'active' then
      raise exception 'already_member' using errcode = 'M0001';
    elsif v_existing_status = 'pending' then
      raise exception 'request_pending' using errcode = 'M0002';
    elsif v_existing_status = 'banned' then
      raise exception 'banned_from_community' using errcode = 'M0003';
    end if;

    update public.community_memberships
    set
      status = v_target_status,
      updated_at = now()
    where id = v_existing_membership_id
    returning json_build_object('id', id, 'status', status, 'role', role) into v_result;
  else
    insert into public.community_memberships (
      community_id, user_id, business_account_id, role, status
    ) values (
      p_community_id,
      case when p_business_account_id is null then v_user_id else null end,
      p_business_account_id,
      'member',
      v_target_status
    ) returning json_build_object('id', id, 'status', status, 'role', role) into v_result;
  end if;

  return v_result;
end;
$$;

-- Leave Community
create or replace function public.leave_community(
  p_community_id uuid,
  p_business_account_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_membership_id uuid;
  v_status text;
  v_role text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  if p_business_account_id is not null then
    if not exists (
      select 1 from public.business_accounts 
      where id = p_business_account_id 
        and (owner_user_id = v_user_id or exists (
          select 1 from public.business_members bm 
          where bm.business_id = p_business_account_id and bm.user_id = v_user_id
        ))
    ) then
      raise exception 'business_not_owned' using errcode = 'B0001';
    end if;

    select id, status, role into v_membership_id, v_status, v_role
    from public.community_memberships
    where community_id = p_community_id and business_account_id = p_business_account_id;
  else
    select id, status, role into v_membership_id, v_status, v_role
    from public.community_memberships
    where community_id = p_community_id and user_id = v_user_id;
  end if;

  if v_membership_id is null or v_status not in ('active', 'pending') then
    raise exception 'not_member' using errcode = 'M0004';
  end if;

  if v_role = 'owner' then
    raise exception 'owner_cannot_leave_before_transfer' using errcode = 'M0005';
  end if;

  update public.community_memberships
  set
    status = 'left',
    updated_at = now()
  where id = v_membership_id;
end;
$$;

-- Follow Community
create or replace function public.follow_community(p_community_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_status text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  select status into v_status from public.communities where id = p_community_id;
  if v_status is null then
    raise exception 'community_not_found' using errcode = 'C0001';
  end if;
  if v_status in ('archived', 'suspended') then
    raise exception 'community_archived' using errcode = 'C0002';
  end if;

  insert into public.community_follows (community_id, user_id)
  values (p_community_id, v_user_id)
  on conflict do nothing;
end;
$$;

-- Unfollow Community
create or replace function public.unfollow_community(p_community_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  delete from public.community_follows
  where community_id = p_community_id and user_id = v_user_id;
end;
$$;

-- Manage Membership Request
create or replace function public.manage_membership_request(
  p_membership_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_community_id uuid;
  v_status text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  select community_id, status into v_community_id, v_status
  from public.community_memberships where id = p_membership_id;

  if v_community_id is null then
    raise exception 'membership_not_found' using errcode = 'M0006';
  end if;

  if v_status != 'pending' then
    raise exception 'request_not_pending' using errcode = 'M0007';
  end if;

  if not public.has_community_permission(v_community_id, v_user_id, 'manage_requests') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_action = 'approve' then
    update public.community_memberships
    set status = 'active', updated_at = now()
    where id = p_membership_id;
  elsif p_action = 'reject' then
    update public.community_memberships
    set status = 'rejected', updated_at = now()
    where id = p_membership_id;
  else
    raise exception 'invalid_action' using errcode = 'M0008';
  end if;
end;
$$;

-- Moderate Member
create or replace function public.moderate_member(
  p_membership_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_community_id uuid;
  v_status text;
  v_role text;
  v_caller_role text;
  v_caller_is_owner boolean;
  v_target_user_id uuid;
  v_target_business_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  select community_id, status, role, user_id, business_account_id 
  into v_community_id, v_status, v_role, v_target_user_id, v_target_business_id
  from public.community_memberships where id = p_membership_id;

  if v_community_id is null then
    raise exception 'membership_not_found' using errcode = 'M0006';
  end if;

  if not public.has_community_permission(v_community_id, v_user_id, 'manage_members') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select (owner_user_id = v_user_id) into v_caller_is_owner
  from public.communities where id = v_community_id;

  if v_caller_is_owner then
    v_caller_role := 'owner';
  else
    select role into v_caller_role 
    from public.community_memberships 
    where community_id = v_community_id and user_id = v_user_id and status = 'active';
  end if;

  if v_role = 'owner' then
    raise exception 'cannot_moderate_owner' using errcode = 'M0009';
  end if;

  if v_caller_role = 'assistant_manager' and v_role in ('manager', 'assistant_manager') then
    raise exception 'not_authorized_hierarchy' using errcode = 'M0010';
  end if;

  if v_caller_role = 'manager' and v_role = 'manager' then
    raise exception 'not_authorized_hierarchy' using errcode = 'M0010';
  end if;

  if p_action = 'ban' then
    if v_status = 'banned' then
      raise exception 'already_banned' using errcode = 'M0011';
    end if;

    update public.community_memberships
    set status = 'banned', role = 'member', updated_at = now()
    where id = p_membership_id;

    if v_target_user_id is not null then
      delete from public.community_follows where community_id = v_community_id and user_id = v_target_user_id;
    end if;

  elsif p_action = 'unban' then
    if v_status != 'banned' then
      raise exception 'not_banned' using errcode = 'M0012';
    end if;

    update public.community_memberships
    set status = 'left', updated_at = now()
    where id = p_membership_id;

  elsif p_action = 'remove' then
    if v_status != 'active' then
      raise exception 'member_not_active' using errcode = 'M0013';
    end if;

    update public.community_memberships
    set status = 'left', updated_at = now()
    where id = p_membership_id;

  else
    raise exception 'invalid_action' using errcode = 'M0008';
  end if;
end;
$$;

-- Assign Community Role
create or replace function public.assign_community_role(
  p_membership_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_community_id uuid;
  v_target_user_id uuid;
  v_target_business_id uuid;
  v_status text;
  v_role text;
  v_caller_role text;
  v_caller_is_owner boolean;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  select community_id, status, role, user_id, business_account_id 
  into v_community_id, v_status, v_role, v_target_user_id, v_target_business_id
  from public.community_memberships where id = p_membership_id;

  if v_community_id is null then
    raise exception 'membership_not_found' using errcode = 'M0006';
  end if;

  if v_status != 'active' then
    raise exception 'target_member_not_active' using errcode = 'M0014';
  end if;

  if v_target_business_id is not null and p_role in ('owner', 'manager', 'assistant_manager') then
    raise exception 'business_actor_cannot_hold_management_role' using errcode = 'M0015';
  end if;

  if not public.has_community_permission(v_community_id, v_user_id, 'assign_roles') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select (owner_user_id = v_user_id) into v_caller_is_owner
  from public.communities where id = v_community_id;

  if v_caller_is_owner then
    v_caller_role := 'owner';
  else
    select role into v_caller_role 
    from public.community_memberships 
    where community_id = v_community_id and user_id = v_user_id and status = 'active';
  end if;

  if p_role = 'owner' then
    raise exception 'cannot_assign_owner_role_direct' using errcode = 'M0016';
  end if;

  if v_role = 'owner' then
    raise exception 'cannot_modify_owner_role' using errcode = 'M0017';
  end if;

  if v_caller_role = 'manager' and p_role = 'manager' then
    raise exception 'not_authorized_hierarchy' using errcode = 'M0010';
  end if;

  update public.community_memberships
  set role = p_role, updated_at = now()
  where id = p_membership_id;
end;
$$;

-- Transfer Community Ownership
create or replace function public.transfer_community_ownership(
  p_community_id uuid,
  p_target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_owner_user_id uuid;
  v_target_membership_id uuid;
  v_target_status text;
  v_target_business_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  select owner_user_id into v_owner_user_id
  from public.communities where id = p_community_id;

  if v_owner_user_id is null then
    raise exception 'community_not_found' using errcode = 'C0001';
  end if;

  if v_owner_user_id != v_user_id then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select id, status, business_account_id into v_target_membership_id, v_target_status, v_target_business_id
  from public.community_memberships
  where community_id = p_community_id and user_id = p_target_user_id;

  if v_target_membership_id is null or v_target_status != 'active' then
    raise exception 'target_not_active_member' using errcode = 'M0018';
  end if;

  if v_target_business_id is not null then
    raise exception 'business_actor_cannot_hold_management_role' using errcode = 'M0015';
  end if;

  update public.communities
  set owner_user_id = p_target_user_id, updated_at = now()
  where id = p_community_id;

  update public.community_memberships
  set role = 'owner', updated_at = now()
  where id = v_target_membership_id;

  update public.community_memberships
  set role = 'member', updated_at = now()
  where community_id = p_community_id and user_id = v_user_id;
end;
$$;

-- 13. RLS Policies
-- Revoke direct writes from clients
revoke insert, update, delete on table public.communities from authenticated, anon;
revoke insert, update, delete on table public.community_memberships from authenticated, anon;
revoke insert, update, delete on table public.community_follows from authenticated, anon;
revoke insert, update, delete on table public.community_membership_audit from authenticated, anon;

grant select on table public.communities to authenticated;
grant select on table public.community_memberships to authenticated;
grant select on table public.community_follows to authenticated;
grant select on table public.community_membership_audit to authenticated;

-- Policies for public.communities (Select)
drop policy if exists "Communities are visible to members or if public" on public.communities;
create policy "Communities are visible to members or if public"
on public.communities
for select
to authenticated
using (
  visibility = 'public'
  or owner_user_id = auth.uid()
  or exists (
    select 1 from public.community_memberships
    where community_id = id
      and user_id = auth.uid()
      and status = 'active'
  )
);

-- Policies for public.community_memberships (Select)
drop policy if exists "Memberships are visible to members or if public" on public.community_memberships;
create policy "Memberships are visible to members or if public"
on public.community_memberships
for select
to authenticated
using (
  user_id = auth.uid()
  or (
    business_account_id is not null
    and exists (
      select 1 from public.business_accounts ba
      where ba.id = business_account_id
        and (ba.owner_user_id = auth.uid() or exists (
          select 1 from public.business_members bm
          where bm.business_id = ba.id and bm.user_id = auth.uid()
        ))
    )
  )
  or exists (
    select 1 from public.communities c
    where c.id = community_id
      and c.visibility = 'public'
  )
  or exists (
    select 1 from public.community_memberships cm
    where cm.community_id = community_id
      and cm.user_id = auth.uid()
      and cm.status = 'active'
  )
);

-- Policies for public.community_follows (Select)
drop policy if exists "Follows are visible to anyone" on public.community_follows;
create policy "Follows are visible to anyone"
on public.community_follows
for select
to authenticated
using (true);

-- Policies for public.community_membership_audit (Select)
-- Visible to community managers/owners only
drop policy if exists "Audits are visible to community managers" on public.community_membership_audit;
create policy "Audits are visible to community managers"
on public.community_membership_audit
for select
to authenticated
using (
  exists (
    select 1 from public.communities c
    where c.id = community_id
      and c.owner_user_id = auth.uid()
  )
  or exists (
    select 1 from public.community_memberships cm
    where cm.community_id = community_id
      and cm.user_id = auth.uid()
      and cm.status = 'active'
      and cm.role in ('owner', 'manager', 'assistant_manager')
  )
);
