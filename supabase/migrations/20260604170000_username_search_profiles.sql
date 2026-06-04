create index if not exists profiles_username_search_idx
  on public.profiles (lower(username) text_pattern_ops)
  where username is not null;

create index if not exists profiles_first_name_search_idx
  on public.profiles (lower(first_name) text_pattern_ops)
  where first_name is not null;

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
