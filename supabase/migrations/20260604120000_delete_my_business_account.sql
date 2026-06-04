alter table public.business_accounts
  drop constraint if exists business_accounts_status_check;

update public.business_accounts
set status = 'deleted',
    updated_at = now()
where status = 'inactive';

alter table public.business_accounts
  add constraint business_accounts_status_check
  check (
    status in (
      'pending',
      'active',
      'deleted',
      'rejected',
      'suspended'
    )
  ) not valid;

create or replace function public.protect_event_sponsorship_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    if coalesce(new.is_sponsored, false) = false
       and new.sponsored_until is null
       and coalesce(new.sponsored_priority, 0) = 0
       and exists (
         select 1
         from public.business_accounts business
         where business.id = new.organizer_business_id
           and business.owner_user_id = auth.uid()
           and business.status = 'deleted'
       ) then
      return new;
    end if;

    raise exception 'event_sponsorship_fields_are_admin_only';
  end if;

  if new.is_sponsored and new.organizer_type <> 'business' then
    raise exception 'sponsored_event_must_be_business';
  end if;

  if new.is_sponsored and not exists (
    select 1
    from public.business_accounts business
    where business.id = new.organizer_business_id
      and business.status = 'active'
      and coalesce(business.is_verified, false)
  ) then
    raise exception 'sponsored_event_requires_verified_business';
  end if;

  return new;
end;
$$;

create or replace function public.protect_business_account_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('app.bypass_business_moderation', true) = 'on' then
    return new;
  end if;

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

create or replace function public.delete_my_business_account()
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_business public.business_accounts%rowtype;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select *
  into v_business
  from public.business_accounts business
  where business.owner_user_id = v_user_id
    and business.status in ('active', 'pending')
  order by
    case business.status when 'active' then 0 when 'pending' then 1 else 2 end,
    business.created_at desc,
    business.id desc
  limit 1
  for update;

  if v_business.id is null then
    update public.profiles profile
    set account_type = 'user',
        business_account_id = null,
        first_name = coalesce(profile.personal_full_name, profile.first_name),
        username = coalesce(profile.personal_username, profile.username),
        bio = coalesce(profile.personal_bio, profile.bio),
        avatar_url = coalesce(profile.personal_avatar_url, profile.avatar_url),
        updated_at = now()
    where profile.user_id = v_user_id
      and profile.account_type = 'business';

    return query
    select *
    from public.profiles
    where user_id = v_user_id;

    return;
  end if;

  update public.profiles profile
  set account_type = 'user',
      business_account_id = null,
      first_name = coalesce(profile.personal_full_name, profile.first_name),
      username = coalesce(profile.personal_username, profile.username),
      bio = coalesce(profile.personal_bio, profile.bio),
      avatar_url = coalesce(profile.personal_avatar_url, profile.avatar_url),
      updated_at = now()
  where profile.user_id = v_user_id;

  perform set_config('app.bypass_business_moderation', 'on', true);

  update public.business_accounts business
  set status = 'deleted',
      is_verified = false,
      updated_at = now()
  where business.id = v_business.id
    and business.owner_user_id = v_user_id;

  update public.events event
  set status = 'cancelled',
      is_sponsored = false,
      sponsored_until = null,
      sponsored_priority = 0,
      updated_at = now()
  where event.host_id = v_user_id
    and event.organizer_business_id = v_business.id
    and coalesce(event.organizer_type, 'user') = 'business'
    and event.status = 'active'
    and event.event_date >= now();

  update public.events event
  set is_sponsored = false,
      sponsored_until = null,
      sponsored_priority = 0,
      updated_at = now()
  where event.host_id = v_user_id
    and event.organizer_business_id = v_business.id
    and coalesce(event.organizer_type, 'user') = 'business'
    and (
      coalesce(event.is_sponsored, false)
      or event.sponsored_until is not null
      or coalesce(event.sponsored_priority, 0) <> 0
    );

  return query
  select *
  from public.profiles
  where user_id = v_user_id;
end;
$$;

comment on function public.delete_my_business_account()
  is 'Deactivates the current user business mode by marking the owned business account deleted, restoring user profile mode, cancelling future active business events, and clearing sponsored flags without hard deleting rows.';

revoke all on function public.delete_my_business_account() from public;
grant execute on function public.delete_my_business_account() to authenticated;

notify pgrst, 'reload schema';
