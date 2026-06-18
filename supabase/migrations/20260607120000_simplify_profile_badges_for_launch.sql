update public.badges
set title = 'Tamamlanmış Profil',
    description = 'Profil bilgilerini tamamladı.',
    icon_key = 'verified',
    sort_order = 10,
    is_active = true
where id = 'first_step';

update public.badges
set title = 'Aktif',
    description = '10 etkinliğe katıldı.',
    icon_key = 'run',
    sort_order = 20,
    is_active = true
where id = 'active_player';

update public.badges
set is_active = false
where id not in ('first_step', 'active_player');

create or replace function public.refresh_user_badges(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_ready boolean;
  v_approved_count integer;
begin
  select
    nullif(trim(coalesce(profile.username, '')), '') is not null
      and nullif(trim(coalesce(profile.first_name, '')), '') is not null
      and nullif(trim(coalesce(profile.city, '')), '') is not null
      and nullif(trim(coalesce(profile.district, '')), '') is not null
      and profile.birth_date is not null
  into v_profile_ready
  from public.profiles profile
  where profile.user_id = p_user_id;

  if not found then
    return;
  end if;

  select count(distinct participant.event_id)
  into v_approved_count
  from public.event_participants participant
  where participant.user_id = p_user_id
    and participant.role = 'participant'
    and participant.attendance_status in (
      'approved',
      'planned',
      'attended',
      'confirmed',
      'checked_in'
    );

  if v_profile_ready then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'first_step')
    on conflict do nothing;
  end if;

  if v_approved_count >= 10 then
    insert into public.user_badges (user_id, badge_id)
    values (p_user_id, 'active_player')
    on conflict do nothing;
  end if;
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
  ),
  activity_counts as (
    select count(distinct participant.event_id) as approved_count
    from public.event_participants participant
    where participant.user_id = p_user_id
      and participant.role = 'participant'
      and participant.attendance_status in (
        'approved',
        'planned',
        'attended',
        'confirmed',
        'checked_in'
      )
  )
  select
    badge_rows.id,
    badge_rows.title,
    badge_rows.description,
    badge_rows.icon_key,
    badge_rows.sort_order,
    badge_rows.earned_at
  from (
    select
      badge.id,
      badge.title,
      badge.description,
      badge.icon_key,
      badge.sort_order,
      case
        when badge.id = 'active_player'
          and coalesce(activity_counts.approved_count, 0) < 10
          then null
        else user_badge.earned_at
      end as earned_at
    from visibility
    cross join activity_counts
    join public.badges badge
      on badge.is_active
    left join public.user_badges user_badge
      on user_badge.user_id = visibility.user_id
      and user_badge.badge_id = badge.id
    where visibility.can_view
  ) badge_rows
  order by
    badge_rows.earned_at is null,
    coalesce(badge_rows.earned_at, 'infinity'::timestamptz),
    badge_rows.sort_order,
    badge_rows.id;
$$;

revoke all on function public.refresh_user_badges(uuid) from public;
revoke all on function public.get_profile_badges(uuid) from public;

grant execute on function public.get_profile_badges(uuid)
  to authenticated;

notify pgrst, 'reload schema';
