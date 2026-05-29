create or replace function public.get_business_stats(p_business_id uuid)
returns table (
  total_events integer,
  upcoming_events integer,
  past_events integer,
  total_join_requests integer,
  confirmed_participants integer,
  checked_in_count integer,
  no_show_count integer,
  waitlisted_count integer,
  average_rating numeric,
  rating_count integer,
  sponsored_events_count integer
)
language plpgsql
stable
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
    from public.business_accounts business
    where business.id = p_business_id
      and business.owner_user_id = v_user_id
  ) and not exists (
    select 1
    from public.business_members member
    where member.business_id = p_business_id
      and member.user_id = v_user_id
      and member.role in ('owner', 'admin', 'staff')
  ) then
    raise exception 'business_stats_not_allowed';
  end if;

  return query
  with business_events as (
    select event.id,
           event.event_date,
           coalesce(event.is_sponsored, false) as is_sponsored
    from public.events event
    where coalesce(event.organizer_type, 'user') = 'business'
      and event.organizer_business_id = p_business_id
  ),
  event_counts as (
    select
      count(*)::integer as total_events,
      count(*) filter (where event_date >= now())::integer as upcoming_events,
      count(*) filter (where event_date < now())::integer as past_events,
      count(*) filter (where is_sponsored)::integer as sponsored_events_count
    from business_events
  ),
  request_counts as (
    select count(request.id)::integer as total_join_requests
    from public.event_join_requests request
    join business_events event on event.id = request.event_id
  ),
  participant_counts as (
    select
      count(*) filter (
        where participant.role = 'participant'
          and participant.attendance_status in ('confirmed', 'checked_in')
      )::integer as confirmed_participants,
      count(*) filter (
        where participant.role = 'participant'
          and participant.attendance_status = 'checked_in'
      )::integer as checked_in_count,
      count(*) filter (
        where participant.role = 'participant'
          and participant.attendance_status = 'no_show'
      )::integer as no_show_count,
      count(*) filter (
        where participant.role = 'participant'
          and participant.attendance_status = 'waitlisted'
      )::integer as waitlisted_count
    from public.event_participants participant
    join business_events event on event.id = participant.event_id
  ),
  rating_counts as (
    select
      coalesce(round(avg(review.rating)::numeric, 1), 0)::numeric
        as average_rating,
      count(review.id)::integer as rating_count
    from public.business_reviews review
    where review.business_id = p_business_id
  )
  select
    coalesce(event_counts.total_events, 0),
    coalesce(event_counts.upcoming_events, 0),
    coalesce(event_counts.past_events, 0),
    coalesce(request_counts.total_join_requests, 0),
    coalesce(participant_counts.confirmed_participants, 0),
    coalesce(participant_counts.checked_in_count, 0),
    coalesce(participant_counts.no_show_count, 0),
    coalesce(participant_counts.waitlisted_count, 0),
    coalesce(rating_counts.average_rating, 0),
    coalesce(rating_counts.rating_count, 0),
    coalesce(event_counts.sponsored_events_count, 0)
  from event_counts
  cross join request_counts
  cross join participant_counts
  cross join rating_counts;
end;
$$;

revoke all on function public.get_business_stats(uuid) from public;
grant execute on function public.get_business_stats(uuid) to authenticated;

notify pgrst, 'reload schema';
