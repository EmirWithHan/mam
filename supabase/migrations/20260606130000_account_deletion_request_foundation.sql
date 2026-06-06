alter table public.profiles
  add column if not exists account_status text not null default 'active',
  add column if not exists deletion_requested_at timestamptz,
  add column if not exists deleted_at timestamptz;

alter table public.profiles
  alter column account_status set default 'active';

update public.profiles
set account_status = 'active'
where account_status is null;

alter table public.profiles
  alter column account_status set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_account_status_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_account_status_check
      check (account_status in ('active', 'deletion_requested', 'deleted', 'suspended'));
  end if;
end $$;

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'requested',
  reason text,
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references auth.users(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_deletion_requests_status_check
    check (status in ('requested', 'processing', 'completed', 'rejected', 'cancelled'))
);

alter table public.account_deletion_requests enable row level security;

create unique index if not exists account_deletion_requests_one_active_per_user_idx
  on public.account_deletion_requests (user_id)
  where status in ('requested', 'processing');

drop policy if exists "Users can create own account deletion request"
  on public.account_deletion_requests;
create policy "Users can create own account deletion request"
on public.account_deletion_requests
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can read own account deletion requests"
  on public.account_deletion_requests;
create policy "Users can read own account deletion requests"
on public.account_deletion_requests
for select
to authenticated
using (user_id = auth.uid() or public.is_current_user_admin());

drop policy if exists "Admins can update account deletion requests"
  on public.account_deletion_requests;
create policy "Admins can update account deletion requests"
on public.account_deletion_requests
for update
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

grant select, insert, update on public.account_deletion_requests to authenticated;

create or replace function public.is_current_profile_active()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.user_id = auth.uid()
      and coalesce(profile.account_status, 'active') = 'active'
  );
$$;

revoke all on function public.is_current_profile_active() from public;
grant execute on function public.is_current_profile_active() to authenticated;

create or replace function public.request_my_account_deletion()
returns boolean
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

  if not exists (
    select 1
    from public.account_deletion_requests request
    where request.user_id = v_user_id
      and request.status in ('requested', 'processing')
  ) then
    insert into public.account_deletion_requests (user_id, status)
    values (v_user_id, 'requested');
  end if;

  update public.profiles
  set
    account_status = 'deletion_requested',
    deletion_requested_at = coalesce(deletion_requested_at, now()),
    is_private = true,
    is_profile_completed = false,
    username = null,
    tag = null,
    first_name = 'Silinmiş kullanıcı',
    avatar_url = null,
    bio = null,
    phone = null,
    phone_number = null,
    phone_verified = false,
    phone_verified_at = null,
    account_type = 'user',
    business_account_id = null,
    updated_at = now()
  where user_id = v_user_id;

  perform set_config('app.bypass_business_moderation', 'on', true);

  update public.business_accounts
  set
    status = 'deleted',
    is_verified = false,
    updated_at = now()
  where owner_user_id = v_user_id
    and status in ('pending', 'active', 'suspended');

  update public.events
  set
    status = 'cancelled',
    is_sponsored = false,
    sponsored_until = null,
    sponsored_priority = 0,
    updated_at = now()
  where host_id = v_user_id
    and status in ('draft', 'active')
    and event_date >= now();

  update public.events
  set
    is_sponsored = false,
    sponsored_until = null,
    sponsored_priority = 0,
    updated_at = now()
  where organizer_business_id in (
    select business.id
    from public.business_accounts business
    where business.owner_user_id = v_user_id
  );

  update public.posts
  set
    is_archived = true,
    updated_at = now()
  where user_id = v_user_id
    and coalesce(is_archived, false) = false;

  update public.notifications
  set
    is_read = true,
    updated_at = now()
  where recipient_id = v_user_id;

  return true;
end;
$$;

revoke all on function public.request_my_account_deletion() from public;
grant execute on function public.request_my_account_deletion() to authenticated;

drop policy if exists "Users can create own posts" on public.posts;
create policy "Users can create own posts"
on public.posts
for insert
to authenticated
with check (user_id = auth.uid() and public.is_current_profile_active());

drop policy if exists "Users can create own comments" on public.post_comments;
create policy "Users can create own comments"
on public.post_comments
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_current_profile_active()
  and exists (
    select 1
    from public.posts post
    where post.id = post_comments.post_id
      and (
        post.user_id = auth.uid()
        or coalesce(post.comments_hidden, false) = false
      )
  )
);

drop policy if exists "Users can create own likes" on public.post_likes;
create policy "Users can create own likes"
on public.post_likes
for insert
to authenticated
with check (user_id = auth.uid() and public.is_current_profile_active());

drop policy if exists "Users can create personal or active business events"
  on public.events;
create policy "Users can create personal or active business events"
on public.events
for insert
to authenticated
with check (
  host_id = auth.uid()
  and public.is_current_profile_active()
  and (
    coalesce(organizer_type, 'user') = 'user'
    or public.event_business_is_owned_active(organizer_business_id, auth.uid())
  )
);

drop policy if exists "Users can create own event requests"
  on public.event_join_requests;
create policy "Users can create own event requests"
on public.event_join_requests
for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'pending'
  and public.is_current_profile_active()
);

drop policy if exists "Users can create own follows" on public.follows;
create policy "Users can create own follows"
on public.follows
for insert
to authenticated
with check (follower_id = auth.uid() and public.is_current_profile_active());

drop policy if exists "Requesters can create follow requests"
  on public.follow_requests;
create policy "Requesters can create follow requests"
on public.follow_requests
for insert
to authenticated
with check (
  requester_id = auth.uid()
  and requester_id <> target_user_id
  and public.is_current_profile_active()
);

drop policy if exists "Reports can be created by reporter" on public.reports;
create policy "Reports can be created by reporter"
on public.reports
for insert
to authenticated
with check (reporter_id = auth.uid() and public.is_current_profile_active());

drop policy if exists "Users can create own business applications"
  on public.business_applications;
create policy "Users can create own business applications"
on public.business_applications
for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'pending'
  and public.is_current_profile_active()
);

create or replace function public.search_profiles_by_username(
  p_query text,
  p_limit integer default 20
)
returns table (
  user_id uuid,
  display_name text,
  username text,
  tag text,
  avatar_url text,
  account_type text,
  is_private boolean,
  business_category text,
  business_is_verified boolean,
  follow_state text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := lower(nullif(btrim(coalesce(p_query, '')), ''));
  v_username text;
  v_tag text;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 20);
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if v_query is null or length(v_query) < 2 then
    return;
  end if;

  if position('#' in v_query) > 1 then
    v_username := split_part(v_query, '#', 1);
    v_tag := nullif(split_part(v_query, '#', 2), '');
  end if;

  return query
  select
    profile.user_id,
    coalesce(
      nullif(btrim(profile.first_name), ''),
      nullif(btrim(profile.username), ''),
      'MaM User'
    )::text as display_name,
    profile.username::text,
    profile.tag::text,
    profile.avatar_url::text,
    coalesce(profile.account_type, 'user')::text as account_type,
    coalesce(profile.is_private, false)::boolean as is_private,
    case
      when coalesce(profile.account_type, 'user') = 'business'
        then coalesce(business.custom_category, business.category)
      else null
    end::text as business_category,
    coalesce(business.is_verified, false)::boolean as business_is_verified,
    case
      when profile.user_id = v_user_id then 'self'
      when exists (
        select 1
        from public.follows follow_rows
        where follow_rows.follower_id = v_user_id
          and follow_rows.following_id = profile.user_id
      ) then 'following'
      when exists (
        select 1
        from public.follow_requests request_rows
        where request_rows.requester_id = v_user_id
          and request_rows.target_user_id = profile.user_id
          and request_rows.status = 'pending'
      ) then 'pending'
      else 'none'
    end::text as follow_state
  from public.profiles profile
  left join public.business_accounts business
    on business.id = profile.business_account_id
    and business.status = 'active'
  where nullif(btrim(profile.username), '') is not null
    and coalesce(profile.account_status, 'active') = 'active'
    and (
      (
        v_tag is null
        and (
          lower(profile.username) like replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%' escape '\'
          or lower(coalesce(profile.first_name, '')) like replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%' escape '\'
        )
      )
      or (
        v_tag is not null
        and lower(profile.username) = v_username
        and lower(coalesce(profile.tag, '')) like replace(replace(replace(v_tag, '\', '\\'), '%', '\%'), '_', '\_') || '%' escape '\'
      )
    )
  order by
    profile.user_id = v_user_id desc,
    lower(profile.username) = coalesce(v_username, v_query) desc,
    lower(profile.username),
    profile.user_id
  limit v_limit;
end;
$$;

revoke all on function public.search_profiles_by_username(text, integer)
  from public;

grant execute on function public.search_profiles_by_username(text, integer)
  to authenticated;

notify pgrst, 'reload schema';
