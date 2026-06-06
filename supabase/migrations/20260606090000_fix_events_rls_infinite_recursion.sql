create or replace function public.event_business_is_active(p_business_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.business_accounts business
    where business.id = p_business_id
      and business.status = 'active'
  );
$$;

create or replace function public.event_business_is_owned_active(
  p_business_id uuid,
  p_user_id uuid
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.business_accounts business
    where business.id = p_business_id
      and business.owner_user_id = p_user_id
      and business.status = 'active'
  );
$$;

grant execute on function public.event_business_is_active(uuid)
  to authenticated;
grant execute on function public.event_business_is_owned_active(uuid, uuid)
  to authenticated;

drop policy if exists "Events are visible to members or public list"
  on public.events;
create policy "Events are visible without recursive participant checks"
on public.events
for select
to authenticated
using (
  public.is_current_user_admin()
  or host_id = auth.uid()
  or (
    status in ('active', 'completed')
    and (
      coalesce(organizer_type, 'user') <> 'business'
      or public.event_business_is_active(organizer_business_id)
    )
  )
);

drop policy if exists "Users can create personal or owned business events"
  on public.events;
drop policy if exists "Users can create personal or active business events"
  on public.events;
create policy "Users can create personal or active business events"
on public.events
for insert
to authenticated
with check (
  host_id = auth.uid()
  and (
    coalesce(organizer_type, 'user') = 'user'
    or public.event_business_is_owned_active(organizer_business_id, auth.uid())
  )
);

notify pgrst, 'reload schema';
