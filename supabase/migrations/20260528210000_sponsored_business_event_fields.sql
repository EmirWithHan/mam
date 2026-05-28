alter table public.events
  add column if not exists is_sponsored boolean not null default false,
  add column if not exists sponsored_until timestamptz,
  add column if not exists sponsored_priority integer not null default 0;

update public.events
set is_sponsored = false
where is_sponsored is null;

update public.events
set sponsored_priority = 0
where sponsored_priority is null;

alter table public.events
  alter column is_sponsored set default false,
  alter column is_sponsored set not null,
  alter column sponsored_priority set default 0,
  alter column sponsored_priority set not null;

alter table public.events
  drop constraint if exists events_sponsored_business_check;

alter table public.events
  add constraint events_sponsored_business_check
  check (is_sponsored = false or organizer_type = 'business') not valid;

alter table public.events
  drop constraint if exists events_sponsored_priority_check;

alter table public.events
  add constraint events_sponsored_priority_check
  check (sponsored_priority >= 0) not valid;

create or replace function public.protect_event_sponsorship_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    raise exception 'event_sponsorship_fields_are_admin_only';
  end if;

  if new.is_sponsored and new.organizer_type <> 'business' then
    raise exception 'sponsored_event_must_be_business';
  end if;

  return new;
end;
$$;

drop trigger if exists events_protect_sponsorship_fields on public.events;
create trigger events_protect_sponsorship_fields
before update of is_sponsored, sponsored_until, sponsored_priority
on public.events
for each row execute function public.protect_event_sponsorship_fields();

drop policy if exists "Users can create personal or owned business events"
  on public.events;
create policy "Users can create personal or owned business events"
on public.events
for insert
to authenticated
with check (
  host_id = auth.uid() and
  is_sponsored = false and
  sponsored_until is null and
  sponsored_priority = 0 and
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
