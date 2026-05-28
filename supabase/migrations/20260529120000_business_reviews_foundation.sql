create table if not exists public.business_reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.business_accounts(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_reviews_rating_check check (rating between 1 and 5),
  constraint business_reviews_comment_length_check
    check (comment is null or length(comment) <= 300),
  constraint business_reviews_one_per_event_user
    unique (business_id, event_id, user_id)
);

create index if not exists business_reviews_business_id_idx
  on public.business_reviews (business_id);

create or replace function public.set_business_reviews_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists business_reviews_set_updated_at
  on public.business_reviews;
create trigger business_reviews_set_updated_at
before update on public.business_reviews
for each row execute function public.set_business_reviews_updated_at();

alter table public.business_reviews enable row level security;

drop policy if exists "Users can read own business reviews"
  on public.business_reviews;
create policy "Users can read own business reviews"
on public.business_reviews
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Business owners can read own business reviews"
  on public.business_reviews;
create policy "Business owners can read own business reviews"
on public.business_reviews
for select
to authenticated
using (
  exists (
    select 1
    from public.business_accounts business
    where business.id = business_reviews.business_id
      and business.owner_user_id = auth.uid()
  )
);

revoke insert, update, delete on public.business_reviews from authenticated;
grant select on public.business_reviews to authenticated;

create or replace function public.submit_business_review(
  p_event_id uuid,
  p_business_id uuid,
  p_rating integer,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_rating < 1 or p_rating > 5 then
    raise exception 'invalid_rating';
  end if;

  if v_comment is not null then
    v_comment := regexp_replace(v_comment, '\s+', ' ', 'g');
    if length(v_comment) > 300 then
      raise exception 'comment_too_long';
    end if;
  end if;

  if not exists (
    select 1
    from public.events event
    where event.id = p_event_id
      and coalesce(event.organizer_type, 'user') = 'business'
      and event.organizer_business_id = p_business_id
  ) then
    raise exception 'not_business_event';
  end if;

  if exists (
    select 1
    from public.business_accounts business
    where business.id = p_business_id
      and business.owner_user_id = v_user_id
  ) then
    raise exception 'cannot_rate_own_business';
  end if;

  if not exists (
    select 1
    from public.event_participants participant
    where participant.event_id = p_event_id
      and participant.user_id = v_user_id
      and participant.role = 'participant'
      and participant.attendance_status in ('checked_in', 'confirmed')
  ) then
    raise exception 'event_not_attended';
  end if;

  insert into public.business_reviews (
    business_id,
    event_id,
    user_id,
    rating,
    comment
  )
  values (
    p_business_id,
    p_event_id,
    v_user_id,
    p_rating,
    v_comment
  );
end;
$$;

create or replace function public.get_business_rating_summary(
  p_business_id uuid
)
returns table (
  average_rating numeric,
  rating_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(round(avg(review.rating)::numeric, 1), 0)::numeric
      as average_rating,
    count(review.id)::integer as rating_count
  from public.business_accounts business
  left join public.business_reviews review
    on review.business_id = business.id
  where business.id = p_business_id
    and auth.uid() is not null
    and (
      business.status = 'active'
      or business.owner_user_id = auth.uid()
    );
$$;

revoke all on function public.submit_business_review(uuid, uuid, integer, text)
  from public;
revoke all on function public.get_business_rating_summary(uuid) from public;

grant execute on function public.submit_business_review(uuid, uuid, integer, text)
  to authenticated;
grant execute on function public.get_business_rating_summary(uuid)
  to authenticated;

notify pgrst, 'reload schema';
