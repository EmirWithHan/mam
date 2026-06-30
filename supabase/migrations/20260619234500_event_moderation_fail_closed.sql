-- Fail-closed deterministic moderation for direct event writes and a corrected
-- admin listing RPC. This migration intentionally uses no external/AI service.

create or replace function public.normalize_event_moderation_text(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(
    translate(
      btrim(coalesce(p_value, '')),
      'çğıöşüÇĞİÖŞÜ',
      'cgiosuCGIOSU'
    )
  );
$$;

create or replace function public.enforce_event_rule_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_material_change boolean;
  v_title text;
  v_compact text;
  v_letters text;
  v_vowels text;
  v_flags text[] := '{}'::text[];
  v_rejected boolean := false;
begin
  if tg_op = 'INSERT' then
    v_material_change := true;
  else
    v_material_change := new.title is distinct from old.title
      or new.description is distinct from old.description
      or new.sport_type is distinct from old.sport_type
      or new.city is distinct from old.city
      or new.district is distinct from old.district
      or new.location_text is distinct from old.location_text
      or new.event_date is distinct from old.event_date
      or new.capacity_total is distinct from old.capacity_total;
  end if;

  if not v_material_change then
    if (
      new.moderation_status is distinct from old.moderation_status
      or new.moderation_reason is distinct from old.moderation_reason
      or new.moderation_flags is distinct from old.moderation_flags
      or new.moderation_score is distinct from old.moderation_score
      or new.moderation_source is distinct from old.moderation_source
      or new.moderation_removed_at is distinct from old.moderation_removed_at
      or new.moderation_removed_by is distinct from old.moderation_removed_by
    ) and not public.is_current_user_admin() then
      raise exception 'event_moderation_fields_are_protected';
    end if;
    return new;
  end if;

  v_title := public.normalize_event_moderation_text(new.title);
  v_compact := regexp_replace(v_title, '[^a-z0-9]', '', 'g');
  v_letters := regexp_replace(v_compact, '[^a-z]', '', 'g');
  v_vowels := regexp_replace(v_letters, '[^aeiou]', '', 'g');

  if char_length(v_title) < 4 then
    v_flags := array_append(v_flags, 'title_too_short');
  end if;
  if v_title = any(array['test', 'deneme', 'event', 'etkinlik'])
    or v_compact like '%asdf%'
    or v_compact like '%qwerty%'
    or v_compact like '%sjsjsj%'
    or v_compact ~ '(.)\1{4,}'
    or v_compact ~ '^(.{2,3})\1{2,}$'
    or char_length(v_letters) < 3
    or (
      char_length(v_compact) >= 4
      and char_length(v_letters) * 2 < char_length(v_compact)
    )
    or v_letters ~ '[bcdfghjklmnprstvyz]{7,}'
    or (
      char_length(v_letters) >= 6
      and char_length(v_vowels) * 4 <= char_length(v_letters)
    ) then
    v_flags := array_append(v_flags, 'title_spam');
  end if;
  if v_title ~ '(seks|cinsel|escort|uyusturucu|kokain|esrar|silah|bicak|kavga|nefret|dolandir|bahis|casino)' then
    v_flags := array_append(v_flags, 'unsafe_title');
    v_rejected := true;
  end if;
  if nullif(btrim(coalesce(new.city, '')), '') is null
    or nullif(btrim(coalesce(new.district, '')), '') is null
    or char_length(btrim(coalesce(new.location_text, ''))) < 4 then
    v_flags := array_append(v_flags, 'location_missing');
  end if;
  if new.event_date < now() then
    v_flags := array_append(v_flags, 'date_past');
  end if;
  if coalesce(new.capacity_total, 0) < 1 then
    v_flags := array_append(v_flags, 'capacity_invalid');
  end if;

  v_flags := array(select distinct unnest(v_flags));
  new.moderation_source := 'rule_based';
  new.moderation_checked_at := now();
  new.moderation_updated_at := now();
  new.moderation_flags := v_flags;
  new.moderation_score := greatest(0, 100 - cardinality(v_flags) * 25);

  if v_rejected then
    new.moderation_status := 'rejected';
    new.moderation_reason := 'Bu etkinlik kurallarımıza uygun görünmüyor.';
  elsif cardinality(v_flags) > 0 then
    new.moderation_status := 'needs_edit';
    new.moderation_reason := case
      when 'title_spam' = any(v_flags) or 'title_too_short' = any(v_flags)
        then 'Etkinlik adı anlamlı ve açıklayıcı olmalı.'
      else 'Etkinliği yayınlamadan önce birkaç şeyi düzeltmen gerekiyor.'
    end;
  else
    new.moderation_status := 'approved';
    new.moderation_reason := 'Etkinlik yayınlanabilir.';
  end if;

  return new;
exception
  when others then
    raise exception 'event_moderation_unavailable: %', sqlerrm;
end;
$$;

drop trigger if exists trg_enforce_event_rule_moderation on public.events;
create trigger trg_enforce_event_rule_moderation
before insert or update on public.events
for each row
execute function public.enforce_event_rule_moderation();

create or replace function public.list_admin_events(
  p_filter text default 'all',
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid, host_id uuid, title text, description text, sport_type text,
  city text, district text, location_text text, location_lat double precision,
  location_lng double precision, event_date timestamptz, capacity_total integer,
  generic_capacity integer, male_capacity integer, female_capacity integer,
  approved_count integer, status text, is_sponsored boolean,
  sponsored_until timestamptz, sponsored_priority integer, organizer_type text,
  organizer_user_id uuid, organizer_business_id uuid, is_paid boolean,
  price_amount numeric, price_currency text, created_at timestamptz,
  updated_at timestamptz, listing_expires_at timestamptz,
  business_open_time text, business_close_time text, event_start_time text,
  event_end_time text, price_type text, min_age integer,
  require_completed_profile boolean, moderation_status text,
  moderation_reason text, moderation_flags text[], moderation_score integer,
  moderation_source text, moderation_checked_at timestamptz,
  moderation_removed_at timestamptz, moderation_removed_by uuid,
  moderation_updated_at timestamptz, host_name text, business_name text
)
language sql
security definer
set search_path = ''
as $$
  select
    e.id, e.host_id, e.title, e.description, e.sport_type, e.city, e.district,
    e.location_text, e.location_lat::double precision,
    e.location_lng::double precision, e.event_date, e.capacity_total,
    e.generic_capacity, e.male_capacity, e.female_capacity, e.approved_count,
    e.status, e.is_sponsored, e.sponsored_until, e.sponsored_priority,
    e.organizer_type, e.organizer_user_id, e.organizer_business_id, e.is_paid,
    e.price_amount, e.price_currency, e.created_at, e.updated_at,
    e.listing_expires_at, e.business_open_time::text,
    e.business_close_time::text, e.event_start_time::text,
    e.event_end_time::text, e.price_type, e.min_age,
    e.require_completed_profile, e.moderation_status, e.moderation_reason,
    e.moderation_flags, e.moderation_score, e.moderation_source,
    e.moderation_checked_at, e.moderation_removed_at,
    e.moderation_removed_by, e.moderation_updated_at,
    coalesce(nullif(p.first_name, ''), p.username) as host_name,
    b.name as business_name
  from public.events e
  left join public.profiles p on p.user_id = e.host_id
  left join public.business_accounts b on b.id = e.organizer_business_id
  where public.is_current_user_admin()
    and (
      p_filter = 'all'
      or (p_filter = 'high_risk' and coalesce(e.moderation_score, 100) < 70)
      or e.moderation_status = p_filter
    )
  order by e.created_at desc nulls last, e.event_date desc
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.list_admin_events(text, integer, integer) from public;
grant execute on function public.list_admin_events(text, integer, integer)
  to authenticated;

notify pgrst, 'reload schema';
