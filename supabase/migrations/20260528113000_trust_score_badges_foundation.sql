alter table public.profiles
  alter column trust_score set default 50;

update public.profiles
set trust_score = 50
where trust_score is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_trust_score_bounds'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_trust_score_bounds
      check (trust_score between 0 and 100) not valid;
  end if;
end $$;

create table if not exists public.trust_score_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  delta integer not null,
  previous_score integer not null,
  new_score integer not null,
  reason text not null,
  source_type text,
  source_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.trust_score_logs
  add column if not exists actor_id uuid references auth.users(id) on delete set null,
  add column if not exists source_type text,
  add column if not exists source_id uuid,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create unique index if not exists trust_score_logs_once_per_source
  on public.trust_score_logs (user_id, reason, source_type, source_id)
  where source_id is not null;

alter table public.trust_score_logs enable row level security;

drop policy if exists "Users can read own trust score logs" on public.trust_score_logs;
create policy "Users can read own trust score logs"
  on public.trust_score_logs
  for select
  to authenticated
  using (user_id = auth.uid());

create table if not exists public.badges (
  id text primary key,
  title text not null,
  description text not null,
  icon_key text,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

create table if not exists public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id text not null references public.badges(id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

alter table public.badges enable row level security;
alter table public.user_badges enable row level security;

drop policy if exists "Anyone authenticated can read active badge catalog" on public.badges;
create policy "Anyone authenticated can read active badge catalog"
  on public.badges
  for select
  to authenticated
  using (is_active);

drop policy if exists "Authenticated users can read visible user badges" on public.user_badges;
create policy "Authenticated users can read visible user badges"
  on public.user_badges
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.profiles profile
      where profile.user_id = user_badges.user_id
        and (
          coalesce(profile.is_private, false) = false
          or exists (
            select 1
            from public.follows follow_rows
            where follow_rows.follower_id = auth.uid()
              and follow_rows.following_id = profile.user_id
          )
        )
    )
  );

revoke insert, update, delete on public.badges from authenticated;
revoke insert, update, delete on public.user_badges from authenticated;
revoke insert, update, delete on public.trust_score_logs from authenticated;

insert into public.badges (id, title, description, icon_key, sort_order, is_active)
values
  ('first_step', 'İlk Adım', 'Profilini tamamladı.', 'flag', 10, true),
  ('first_event', 'İlk Etkinlik', 'İlk etkinliğine katıldı.', 'event', 20, true),
  ('reliable_participant', 'Güvenilir Katılımcı', 'Toplulukta güven kazandı.', 'verified', 30, true),
  ('active_player', 'Aktif Oyuncu', 'Birden fazla etkinlikte yer aldı.', 'run', 40, true),
  ('organizer', 'Organizatör', 'Etkinlik organize etti.', 'groups', 50, true),
  ('social', 'Sosyal', 'Toplulukta aktif paylaşım yaptı.', 'chat', 60, true)
on conflict (id) do update
set title = excluded.title,
    description = excluded.description,
    icon_key = excluded.icon_key,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active;

create or replace function public.trust_score_delta_for_event(p_event_type text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_event_type
    when 'profile_event_ready' then 2
    when 'first_event_approved' then 3
    when 'event_join_approved' then 1
    when 'host_event_with_participant' then 2
    when 'event_linked_post' then 1
    when 'approved_event_left' then -2
    when 'event_join_cancelled' then 0
    when 'event_join_rejected' then 0
    else 0
  end;
$$;

create or replace function public.refresh_user_badges(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trust_score integer;
  v_profile_ready boolean;
  v_approved_count integer;
  v_hosted_with_participants integer;
  v_post_count integer;
begin
  select
    coalesce(profile.trust_score, 50),
    nullif(trim(coalesce(profile.username, '')), '') is not null
      and nullif(trim(coalesce(profile.first_name, '')), '') is not null
      and nullif(trim(coalesce(profile.city, '')), '') is not null
      and nullif(trim(coalesce(profile.district, '')), '') is not null
      and profile.birth_date is not null
  into v_trust_score, v_profile_ready
  from public.profiles profile
  where profile.user_id = p_user_id;

  if not found then
    return;
  end if;

  select count(*)
  into v_approved_count
  from public.event_participants participant
  where participant.user_id = p_user_id
    and participant.role = 'participant'
    and participant.attendance_status in ('planned', 'attended');

  select count(*)
  into v_hosted_with_participants
  from public.events event
  where event.host_id = p_user_id
    and coalesce(event.approved_count, 0) > 0;

  select count(*)
  into v_post_count
  from public.posts post
  where post.user_id = p_user_id
    and coalesce(post.is_archived, false) = false;

  if v_profile_ready then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'first_step')
    on conflict do nothing;
  end if;

  if v_approved_count >= 1 then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'first_event')
    on conflict do nothing;
  end if;

  if v_trust_score >= 70 then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'reliable_participant')
    on conflict do nothing;
  end if;

  if v_approved_count >= 3 then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'active_player')
    on conflict do nothing;
  end if;

  if v_hosted_with_participants >= 1 then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'organizer')
    on conflict do nothing;
  end if;

  if v_post_count >= 3 then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'social')
    on conflict do nothing;
  end if;
end;
$$;

create or replace function public.apply_trust_score_event(
  p_user_id uuid,
  p_actor_id uuid,
  p_event_type text,
  p_source_type text default null,
  p_source_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delta integer;
  v_previous_score integer;
  v_new_score integer;
begin
  v_delta := public.trust_score_delta_for_event(p_event_type);

  if v_delta = 0 then
    perform public.refresh_user_badges(p_user_id);
    select coalesce(profile.trust_score, 50)
    into v_previous_score
    from public.profiles profile
    where profile.user_id = p_user_id;
    return coalesce(v_previous_score, 50);
  end if;

  if p_source_id is not null and exists (
    select 1
    from public.trust_score_logs log
    where log.user_id = p_user_id
      and log.reason = p_event_type
      and log.source_type is not distinct from p_source_type
      and log.source_id = p_source_id
  ) then
    select coalesce(profile.trust_score, 50)
    into v_previous_score
    from public.profiles profile
    where profile.user_id = p_user_id;
    perform public.refresh_user_badges(p_user_id);
    return coalesce(v_previous_score, 50);
  end if;

  if p_event_type = 'approved_event_left'
    and p_source_id is not null
    and exists (
      select 1
      from public.trust_score_logs log
      where log.user_id = p_user_id
        and log.source_id = p_source_id
        and log.reason in ('event_leave', 'leave_approved_event', 'approved_event_left')
    ) then
    select coalesce(profile.trust_score, 50)
    into v_previous_score
    from public.profiles profile
    where profile.user_id = p_user_id;
    perform public.refresh_user_badges(p_user_id);
    return coalesce(v_previous_score, 50);
  end if;

  select coalesce(profile.trust_score, 50)
  into v_previous_score
  from public.profiles profile
  where profile.user_id = p_user_id
  for update;

  if not found then
    return 50;
  end if;

  v_new_score := least(100, greatest(0, v_previous_score + v_delta));

  update public.profiles
  set trust_score = v_new_score,
      updated_at = now()
  where user_id = p_user_id;

  insert into public.trust_score_logs (
    user_id,
    actor_id,
    delta,
    previous_score,
    new_score,
    reason,
    source_type,
    source_id,
    metadata
  )
  values (
    p_user_id,
    p_actor_id,
    v_delta,
    v_previous_score,
    v_new_score,
    p_event_type,
    p_source_type,
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict do nothing;

  perform public.refresh_user_badges(p_user_id);
  return v_new_score;
end;
$$;

create or replace function public.apply_my_trust_score_event(
  p_event_type text,
  p_ref_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_source_id uuid := p_ref_id;
  v_event_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_event_type = 'profile_event_ready' then
    if not exists (
      select 1
      from public.profiles profile
      where profile.user_id = v_user_id
        and nullif(trim(coalesce(profile.username, '')), '') is not null
        and nullif(trim(coalesce(profile.first_name, '')), '') is not null
        and nullif(trim(coalesce(profile.city, '')), '') is not null
        and nullif(trim(coalesce(profile.district, '')), '') is not null
        and profile.birth_date is not null
    ) then
      raise exception 'profile_not_event_ready';
    end if;
    v_source_id := v_user_id;
    return public.apply_trust_score_event(
      v_user_id,
      v_user_id,
      p_event_type,
      'profile',
      v_source_id,
      '{}'::jsonb
    );
  end if;

  if p_event_type = 'event_linked_post' then
    select post.event_id
    into v_event_id
    from public.posts post
    where post.id = p_ref_id
      and post.user_id = v_user_id
      and post.event_id is not null;

    if v_event_id is null then
      raise exception 'post_not_event_linked';
    end if;

    if not exists (
      select 1
      from public.events event
      where event.id = v_event_id
        and event.host_id = v_user_id
    ) and not exists (
      select 1
      from public.event_participants participant
      where participant.event_id = v_event_id
        and participant.user_id = v_user_id
        and participant.attendance_status in ('planned', 'attended')
    ) then
      raise exception 'post_event_not_participated';
    end if;

    return public.apply_trust_score_event(
      v_user_id,
      v_user_id,
      p_event_type,
      'event',
      v_event_id,
      jsonb_build_object('post_id', p_ref_id)
    );
  end if;

  if p_event_type = 'approved_event_left' then
    if not exists (
      select 1
      from public.event_participants participant
      where participant.event_id = p_ref_id
        and participant.user_id = v_user_id
        and participant.role = 'participant'
        and participant.attendance_status = 'left'
    ) then
      raise exception 'approved_event_leave_not_found';
    end if;

    return public.apply_trust_score_event(
      v_user_id,
      v_user_id,
      p_event_type,
      'event',
      p_ref_id,
      '{}'::jsonb
    );
  end if;

  raise exception 'unsupported_trust_score_event';
end;
$$;

create or replace function public.apply_join_approval_trust_event(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request record;
  v_prior_approved_count integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select request.id, request.user_id, request.event_id, request.status, event.host_id
  into v_request
  from public.event_join_requests request
  join public.events event
    on event.id = request.event_id
  where request.id = p_request_id;

  if not found then
    raise exception 'request_not_found';
  end if;

  if v_request.host_id <> auth.uid() then
    raise exception 'not_event_host';
  end if;

  if v_request.status <> 'approved' then
    return;
  end if;

  select count(*)
  into v_prior_approved_count
  from public.event_participants participant
  where participant.user_id = v_request.user_id
    and participant.role = 'participant'
    and participant.attendance_status in ('planned', 'attended')
    and participant.event_id <> v_request.event_id;

  perform public.apply_trust_score_event(
    v_request.user_id,
    auth.uid(),
    'event_join_approved',
    'event',
    v_request.event_id,
    jsonb_build_object('request_id', p_request_id)
  );

  if v_prior_approved_count = 0 then
    perform public.apply_trust_score_event(
      v_request.user_id,
      auth.uid(),
      'first_event_approved',
      'profile',
      v_request.user_id,
      jsonb_build_object('request_id', p_request_id, 'event_id', v_request.event_id)
    );
  end if;

  perform public.apply_trust_score_event(
    auth.uid(),
    auth.uid(),
    'host_event_with_participant',
    'event',
    v_request.event_id,
    jsonb_build_object('request_id', p_request_id, 'participant_id', v_request.user_id)
  );
end;
$$;

create or replace function public.get_profile_badges(p_user_id uuid)
returns table (
  id text,
  title text,
  description text,
  icon_key text,
  sort_order integer,
  earned_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with target_profile as (
    select profile.user_id, coalesce(profile.is_private, false) as is_private
    from public.profiles profile
    where profile.user_id = p_user_id
  ),
  visibility as (
    select
      target_profile.user_id,
      (
        auth.uid() = target_profile.user_id
        or target_profile.is_private = false
        or exists (
          select 1
          from public.follows follow_rows
          where follow_rows.follower_id = auth.uid()
            and follow_rows.following_id = target_profile.user_id
        )
      ) as can_view
    from target_profile
    where auth.uid() is not null
  )
  select
    badge.id,
    badge.title,
    badge.description,
    badge.icon_key,
    badge.sort_order,
    user_badge.earned_at
  from visibility
  join public.badges badge
    on badge.is_active
  left join public.user_badges user_badge
    on user_badge.user_id = visibility.user_id
    and user_badge.badge_id = badge.id
  where visibility.can_view
  order by
    user_badge.earned_at is null,
    coalesce(user_badge.earned_at, 'infinity'::timestamptz),
    badge.sort_order,
    badge.id;
$$;

revoke all on function public.trust_score_delta_for_event(text) from public;
revoke all on function public.refresh_user_badges(uuid) from public;
revoke all on function public.apply_trust_score_event(uuid, uuid, text, text, uuid, jsonb) from public;
revoke all on function public.apply_my_trust_score_event(text, uuid) from public;
revoke all on function public.apply_join_approval_trust_event(uuid) from public;
revoke all on function public.get_profile_badges(uuid) from public;

grant execute on function public.apply_my_trust_score_event(text, uuid)
  to authenticated;
grant execute on function public.apply_join_approval_trust_event(uuid)
  to authenticated;
grant execute on function public.get_profile_badges(uuid)
  to authenticated;

notify pgrst, 'reload schema';
