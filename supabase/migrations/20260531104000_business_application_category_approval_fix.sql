alter table public.business_applications
  add column if not exists category text,
  add column if not exists custom_category text;

alter table public.business_applications
  drop constraint if exists business_applications_category_check;

alter table public.business_applications
  add constraint business_applications_category_check
  check (
    category is null or
    length(trim(category)) > 0
  ) not valid;

alter table public.business_applications
  drop constraint if exists business_applications_other_custom_category_check;

alter table public.business_applications
  add constraint business_applications_other_custom_category_check
  check (
    category is null or
    category <> 'Diğer' or
    (custom_category is not null and length(trim(custom_category)) > 0)
  ) not valid;

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
  v_category text;
  v_custom_category text;
begin
  if not public.is_current_user_admin() then
    raise exception 'not_admin';
  end if;

  select *
  into v_application
  from public.business_applications
  where id = p_application_id
  for update;

  if v_application.id is null then
    raise exception 'business_application_not_found';
  end if;

  if v_application.status = 'approved' then
    return;
  end if;

  if v_application.status <> 'pending' then
    raise exception 'business_application_not_pending';
  end if;

  v_category := nullif(btrim(v_application.category), '');
  v_custom_category := nullif(btrim(v_application.custom_category), '');

  if v_category is null then
    v_category := 'Diğer';
    v_custom_category := coalesce(
      v_custom_category,
      nullif(left(btrim(v_application.business_name), 40), ''),
      'İşletme'
    );
  elsif v_category = 'Diğer' and v_custom_category is null then
    v_custom_category := coalesce(
      nullif(left(btrim(v_application.business_name), 40), ''),
      'İşletme'
    );
  elsif v_category <> 'Diğer' then
    v_custom_category := null;
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
    custom_category,
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
    v_category,
    v_custom_category,
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
    category = excluded.category,
    custom_category = excluded.custom_category,
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
      category = v_category,
      custom_category = v_custom_category,
      admin_note = nullif(btrim(p_admin_note), ''),
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      updated_at = now()
  where id = v_application.id;
end;
$$;

grant execute on function public.approve_business_application(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
