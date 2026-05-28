alter table public.events
  add column if not exists organizer_type text not null default 'user',
  add column if not exists organizer_user_id uuid,
  add column if not exists organizer_business_id uuid references public.business_accounts(id),
  add column if not exists price_amount numeric,
  add column if not exists price_currency text not null default 'TRY',
  add column if not exists is_paid boolean not null default false;

update public.events
set organizer_type = 'user'
where organizer_type is null;

update public.events
set organizer_user_id = host_id
where organizer_user_id is null
  and organizer_type = 'user';

alter table public.events
  drop constraint if exists events_organizer_type_check;

alter table public.events
  add constraint events_organizer_type_check
  check (organizer_type in ('user', 'business')) not valid;

alter table public.events
  drop constraint if exists events_organizer_shape_check;

alter table public.events
  add constraint events_organizer_shape_check
  check (
    (
      organizer_type = 'user' and
      organizer_business_id is null
    ) or
    (
      organizer_type = 'business' and
      organizer_business_id is not null
    )
  ) not valid;

alter table public.events
  drop constraint if exists events_price_check;

alter table public.events
  add constraint events_price_check
  check (
    (
      is_paid = false and price_amount is null
    ) or
    (
      is_paid = true and price_amount is not null and price_amount > 0
    )
  ) not valid;

create or replace function public.validate_event_organizer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if new.host_id is distinct from auth.uid() then
    raise exception 'event_host_must_be_current_user';
  end if;

  new.organizer_type = coalesce(nullif(new.organizer_type, ''), 'user');
  new.organizer_user_id = auth.uid();
  new.price_currency = coalesce(nullif(new.price_currency, ''), 'TRY');

  if new.organizer_type = 'user' then
    new.organizer_business_id = null;
    new.is_paid = false;
    new.price_amount = null;
    return new;
  end if;

  if new.organizer_type <> 'business' then
    raise exception 'invalid_event_organizer_type';
  end if;

  if new.organizer_business_id is null then
    raise exception 'business_event_requires_business';
  end if;

  if not exists (
    select 1
    from public.business_accounts business
    where business.id = new.organizer_business_id
      and business.owner_user_id = auth.uid()
      and business.status = 'active'
  ) then
    raise exception 'business_event_not_owned';
  end if;

  if new.is_paid then
    if new.price_amount is null or new.price_amount <= 0 then
      raise exception 'business_event_price_required';
    end if;
    new.price_currency = 'TRY';
  else
    new.price_amount = null;
    new.price_currency = 'TRY';
  end if;

  return new;
end;
$$;

drop trigger if exists events_validate_organizer on public.events;
create trigger events_validate_organizer
before insert or update of
  host_id,
  organizer_type,
  organizer_user_id,
  organizer_business_id,
  is_paid,
  price_amount,
  price_currency
on public.events
for each row execute function public.validate_event_organizer();

drop policy if exists "Users can create personal or owned business events"
  on public.events;
create policy "Users can create personal or owned business events"
on public.events
for insert
to authenticated
with check (
  host_id = auth.uid() and
  (
    organizer_type = 'user' or
    (
      organizer_type = 'business' and
      exists (
        select 1
        from public.business_accounts business
        where business.id = organizer_business_id
          and business.owner_user_id = auth.uid()
          and business.status = 'active'
      )
    )
  )
);
