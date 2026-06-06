grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.profiles to authenticated;
grant select, insert, update, delete on table public.posts to authenticated;
grant select, insert, update, delete on table public.post_comments to authenticated;
grant select, insert, update, delete on table public.post_likes to authenticated;
grant select, insert, update, delete on table public.events to authenticated;
grant select, insert, update, delete on table public.event_participants to authenticated;
grant select, insert, update, delete on table public.event_join_requests to authenticated;
grant select, insert, update, delete on table public.follows to authenticated;
grant select, insert, update, delete on table public.follow_requests to authenticated;
grant select, insert, update, delete on table public.blocks to authenticated;
grant select, insert on table public.reports to authenticated;
grant select, update on table public.notifications to authenticated;
grant select, insert, update, delete on table public.business_accounts to authenticated;
grant select, insert, update on table public.business_applications to authenticated;
grant select, insert on table public.user_feedback to authenticated;

drop policy if exists "Owners can create own business account"
  on public.business_accounts;
create policy "Owners can create own business account"
on public.business_accounts
for insert
to authenticated
with check (
  owner_user_id = auth.uid()
  and status in ('active', 'pending')
);

drop policy if exists "Users can create own business applications"
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

drop policy if exists "Users can read own business applications"
  on public.business_applications;
create policy "Users can read own business applications"
on public.business_applications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Admins can read all business applications"
  on public.business_applications;
create policy "Admins can read all business applications"
on public.business_applications
for select
to authenticated
using (public.is_current_user_admin());

drop policy if exists "Users can cancel own pending business applications"
  on public.business_applications;
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

grant execute on function public.is_current_user_admin() to authenticated;
grant execute on function public.search_profiles_by_username(text, integer)
  to authenticated;
grant execute on function public.get_visible_feed_posts(integer, integer)
  to authenticated;
grant execute on function public.get_visible_feed_posts_with_stats(integer, integer)
  to authenticated;
grant execute on function public.get_public_profile_detail(uuid)
  to authenticated;
grant execute on function public.get_public_profile_gallery(uuid, integer, integer)
  to authenticated;
grant execute on function public.get_public_profile_event_history(uuid)
  to authenticated;
grant execute on function public.get_public_profile_preview(text)
  to authenticated;
grant execute on function public.get_public_profile_previews(text[])
  to authenticated;
grant execute on function public.get_public_profile_followers(text, integer, integer)
  to authenticated;
grant execute on function public.get_public_profile_following(text, integer, integer)
  to authenticated;
grant execute on function public.list_pending_business_applications(integer, integer)
  to authenticated;

notify pgrst, 'reload schema';
