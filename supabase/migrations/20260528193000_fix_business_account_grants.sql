alter table public.business_accounts enable row level security;
alter table public.business_members enable row level security;

grant select, insert, update on table public.business_accounts to authenticated;
grant select, insert on table public.business_members to authenticated;

revoke delete on table public.business_accounts from authenticated;
revoke update, delete on table public.business_members from authenticated;

drop policy if exists "Business accounts are visible when active or owned"
  on public.business_accounts;
create policy "Business accounts are visible when active or owned"
on public.business_accounts
for select
to authenticated
using (status = 'active' or owner_user_id = auth.uid());

drop policy if exists "Users can create their own business account"
  on public.business_accounts;
create policy "Users can create their own business account"
on public.business_accounts
for insert
to authenticated
with check (
  owner_user_id = auth.uid() and
  status = 'active' and
  is_verified = false
);

drop policy if exists "Owners can update basic business fields"
  on public.business_accounts;
create policy "Owners can update basic business fields"
on public.business_accounts
for update
to authenticated
using (owner_user_id = auth.uid() and status in ('pending', 'active'))
with check (
  owner_user_id = auth.uid() and
  status in ('pending', 'active')
);

drop policy if exists "Business members can read their memberships"
  on public.business_members;
create policy "Business members can read their memberships"
on public.business_members
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Business owners can create owner membership"
  on public.business_members;
create policy "Business owners can create owner membership"
on public.business_members
for insert
to authenticated
with check (
  user_id = auth.uid() and
  role = 'owner' and
  exists (
    select 1
    from public.business_accounts business
    where business.id = business_id
      and business.owner_user_id = auth.uid()
  )
);
