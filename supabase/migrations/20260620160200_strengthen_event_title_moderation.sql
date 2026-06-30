-- Migration to strengthen event title moderation rules in enforce_event_rule_moderation trigger function.
-- Forward-only migration, not applied to remote database.

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
  v_desc text;
  v_flags text[] := '{}'::text[];
  v_rejected boolean := false;
  v_is_category_title boolean;
  v_is_single_token boolean;
  v_is_sport_match boolean;
  v_has_desc_support boolean;
  v_is_yoga_or_kosu_or_pilates_or_futbol boolean;
  v_is_mac_match boolean;
  v_is_supported_short_title boolean;
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

  v_is_category_title := new.sport_type is not null 
    and (
      v_title = public.normalize_event_moderation_text(new.sport_type)
      or public.normalize_event_moderation_text(new.sport_type) like '%' || v_title || '%'
    )
    and char_length(v_title) >= 4;

  -- Validate if description supports short title
  v_desc := public.normalize_event_moderation_text(new.description);
  v_is_yoga_or_kosu_or_pilates_or_futbol := v_title = 'yoga' or v_title = 'kosu' or v_title = 'pilates' or v_title = 'futbol';
  v_is_mac_match := (v_title = 'mac' or v_title = 'maci')
    and new.sport_type is not null
    and (
      lower(new.sport_type) ~ '(futbol|basketbol|voleybol|tenis|padel|masa tenisi|bilardo|satranc|masa oyunlari|bowling|paintball)'
    );
  v_has_desc_support := char_length(v_desc) >= 10 and (v_desc like '%' || v_title || '%');
  v_is_supported_short_title := (v_is_yoga_or_kosu_or_pilates_or_futbol or v_is_mac_match) and v_has_desc_support;

  if char_length(v_title) < 4 and not v_is_supported_short_title then
    v_flags := array_append(v_flags, 'title_too_short');
  end if;

  -- Strengthened spam checks matching Dart EventModerationValidator
  if v_compact ~ '(.{1,4})\1{2,}'
    or v_title ~ '([a-z0-9]{2,})\s+\1'
    or (
      (
        v_compact ~ '(asdf|qwer|zxcv|sjsj|jaja|lol|haha|abab|xyzxyz|deneme|event|etkinlik)'
        or v_title = any(array['test', 'deneme', 'event', 'etkinlik'])
      )
      and not v_is_category_title
    )
    or char_length(v_letters) < 3
    or not (v_title ~ '(^| )[a-z]{3,}( |$)')
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

  -- Single token check
  v_is_single_token := v_title !~ ' ';
  if v_is_single_token then
    v_is_sport_match := new.sport_type is not null 
      and (
        v_title = public.normalize_event_moderation_text(new.sport_type)
        or public.normalize_event_moderation_text(new.sport_type) like '%' || v_title || '%'
      );
      
    if not ((v_is_sport_match or v_is_mac_match) and v_has_desc_support) then
      v_flags := array_append(v_flags, 'title_spam');
    end if;
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
