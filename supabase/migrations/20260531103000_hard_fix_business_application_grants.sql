grant usage on schema public to authenticated;

grant select, insert, update
on table public.business_applications
to authenticated;

revoke select on table public.admin_users from authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users admin_user
    where admin_user.user_id = auth.uid()
  );
$$;

create or replace function public.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin();
$$;

alter table public.business_applications enable row level security;

drop policy if exists "Users can create own business applications"
  on public.business_applications;
drop policy if exists "Users can read own business applications"
  on public.business_applications;
drop policy if exists "Users can cancel own pending business applications"
  on public.business_applications;
drop policy if exists "Admins can read all business applications"
  on public.business_applications;

create policy "Users can create own business applications"
on public.business_applications
for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
);

create policy "Users can read own business applications"
on public.business_applications
for select
to authenticated
using (user_id = auth.uid());

create policy "Admins can read all business applications"
on public.business_applications
for select
to authenticated
using (public.is_admin());

create policy "Users can cancel own pending business applications"
on public.business_applications
for update
to authenticated
using (
  user_id = auth.uid()
  and status in ('pending', 'cancelled')
)
with check (
  user_id = auth.uid()
  and status in ('pending', 'cancelled')
  and reviewed_by is null
  and reviewed_at is null
);

revoke all on function public.is_admin() from public;
revoke all on function public.is_current_user_admin() from public;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_current_user_admin() to authenticated;

notify pgrst, 'reload schema';
