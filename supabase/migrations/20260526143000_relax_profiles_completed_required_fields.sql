alter table public.profiles
  drop constraint if exists profiles_completed_required_fields;

alter table public.profiles
  add constraint profiles_completed_required_fields
  check (
    coalesce(is_profile_completed, false) = false
    or (
      nullif(trim(username), '') is not null
      and nullif(trim(first_name), '') is not null
    )
  ) not valid;
