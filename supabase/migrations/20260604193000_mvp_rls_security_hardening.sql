alter table if exists public.profiles enable row level security;
alter table if exists public.posts enable row level security;
alter table if exists public.post_comments enable row level security;
alter table if exists public.post_likes enable row level security;
alter table if exists public.events enable row level security;
alter table if exists public.event_participants enable row level security;
alter table if exists public.event_join_requests enable row level security;
alter table if exists public.follows enable row level security;
alter table if exists public.follow_requests enable row level security;
alter table if exists public.business_accounts enable row level security;
alter table if exists public.business_applications enable row level security;
alter table if exists public.user_feedback enable row level security;
alter table if exists public.reports enable row level security;
alter table if exists public.blocks enable row level security;
alter table if exists public.notifications enable row level security;
alter table if exists public.rate_limit_events enable row level security;
alter table if exists public.admin_users enable row level security;

revoke all on public.profiles from anon;
revoke all on public.posts from anon;
revoke all on public.post_comments from anon;
revoke all on public.post_likes from anon;
revoke all on public.events from anon;
revoke all on public.event_participants from anon;
revoke all on public.event_join_requests from anon;
revoke all on public.follows from anon;
revoke all on public.follow_requests from anon;
revoke all on public.business_accounts from anon;
revoke all on public.business_applications from anon;
revoke all on public.user_feedback from anon;
revoke all on public.reports from anon;
revoke all on public.blocks from anon;
revoke all on public.notifications from anon;
revoke all on public.rate_limit_events from anon;
revoke all on public.admin_users from anon;

revoke all on public.rate_limit_events from authenticated;
revoke all on public.admin_users from authenticated;

drop policy if exists "Profiles are owner writable" on public.profiles;
create policy "Profiles are owner writable"
on public.profiles
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Posts are visible through social graph" on public.posts;
create policy "Posts are visible through social graph"
on public.posts
for select
to authenticated
using (
  user_id = auth.uid()
  or (
    coalesce(is_archived, false) = false
    and exists (
      select 1
      from public.profiles author_profile
      where author_profile.user_id = posts.user_id
        and (
          coalesce(author_profile.is_private, false) = false
          or exists (
            select 1
            from public.follows viewer_follow
            where viewer_follow.follower_id = auth.uid()
              and viewer_follow.following_id = posts.user_id
          )
        )
    )
  )
);

drop policy if exists "Users can create own posts" on public.posts;
create policy "Users can create own posts"
on public.posts
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can update own posts" on public.posts;
create policy "Users can update own posts"
on public.posts
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can delete own posts" on public.posts;
create policy "Users can delete own posts"
on public.posts
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "Comments follow post visibility" on public.post_comments;
create policy "Comments follow post visibility"
on public.post_comments
for select
to authenticated
using (
  exists (
    select 1
    from public.posts post
    where post.id = post_comments.post_id
      and (
        post.user_id = auth.uid()
        or coalesce(post.comments_hidden, false) = false
      )
  )
);

drop policy if exists "Users can create own comments" on public.post_comments;
create policy "Users can create own comments"
on public.post_comments
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.posts post
    where post.id = post_comments.post_id
      and (
        post.user_id = auth.uid()
        or coalesce(post.comments_hidden, false) = false
      )
  )
);

drop policy if exists "Users can update own comments" on public.post_comments;
create policy "Users can update own comments"
on public.post_comments
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can delete own comments" on public.post_comments;
create policy "Users can delete own comments"
on public.post_comments
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can read own likes" on public.post_likes;
create policy "Users can read own likes"
on public.post_likes
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can create own likes" on public.post_likes;
create policy "Users can create own likes"
on public.post_likes
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can delete own likes" on public.post_likes;
create policy "Users can delete own likes"
on public.post_likes
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "Events are visible to members or public list" on public.events;
create policy "Events are visible to members or public list"
on public.events
for select
to authenticated
using (
  host_id = auth.uid()
  or status in ('active', 'completed')
  or exists (
    select 1
    from public.event_participants participant
    where participant.event_id = events.id
      and participant.user_id = auth.uid()
  )
);

drop policy if exists "Users can create personal or active business events" on public.events;
create policy "Users can create personal or active business events"
on public.events
for insert
to authenticated
with check (
  host_id = auth.uid()
  and (
    coalesce(organizer_type, 'user') = 'user'
    or exists (
      select 1
      from public.business_accounts business
      where business.id = events.organizer_business_id
        and business.owner_user_id = auth.uid()
        and business.status = 'active'
    )
  )
);

drop policy if exists "Hosts can update own events" on public.events;
create policy "Hosts can update own events"
on public.events
for update
to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

drop policy if exists "Hosts can delete own events" on public.events;
create policy "Hosts can delete own events"
on public.events
for delete
to authenticated
using (host_id = auth.uid());

drop policy if exists "Participants and hosts can read event participants" on public.event_participants;
create policy "Participants and hosts can read event participants"
on public.event_participants
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.events event
    where event.id = event_participants.event_id
      and event.host_id = auth.uid()
  )
);

drop policy if exists "Event requests are visible to requester or host" on public.event_join_requests;
create policy "Event requests are visible to requester or host"
on public.event_join_requests
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.events event
    where event.id = event_join_requests.event_id
      and event.host_id = auth.uid()
  )
);

drop policy if exists "Users can create own event requests" on public.event_join_requests;
create policy "Users can create own event requests"
on public.event_join_requests
for insert
to authenticated
with check (user_id = auth.uid() and status = 'pending');

drop policy if exists "Users can cancel own pending event requests" on public.event_join_requests;
create policy "Users can cancel own pending event requests"
on public.event_join_requests
for update
to authenticated
using (user_id = auth.uid() and status = 'pending')
with check (user_id = auth.uid() and status = 'cancelled');

drop policy if exists "Follow rows are visible to participants" on public.follows;
create policy "Follow rows are visible to participants"
on public.follows
for select
to authenticated
using (follower_id = auth.uid() or following_id = auth.uid());

drop policy if exists "Users can create own follows" on public.follows;
create policy "Users can create own follows"
on public.follows
for insert
to authenticated
with check (follower_id = auth.uid());

drop policy if exists "Users can delete own follows" on public.follows;
create policy "Users can delete own follows"
on public.follows
for delete
to authenticated
using (follower_id = auth.uid());

drop policy if exists "Reports can be created by reporter" on public.reports;
create policy "Reports can be created by reporter"
on public.reports
for insert
to authenticated
with check (reporter_id = auth.uid());

drop policy if exists "Reporters can read own reports" on public.reports;
create policy "Reporters can read own reports"
on public.reports
for select
to authenticated
using (reporter_id = auth.uid() or public.is_current_user_admin());

drop policy if exists "Users can manage own blocks" on public.blocks;
create policy "Users can manage own blocks"
on public.blocks
for all
to authenticated
using (blocker_id = auth.uid())
with check (blocker_id = auth.uid());

drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
on public.notifications
for select
to authenticated
using (recipient_id = auth.uid());

drop policy if exists "Users can update own notifications" on public.notifications;
create policy "Users can update own notifications"
on public.notifications
for update
to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

drop policy if exists "Business accounts are visible when active or owned" on public.business_accounts;
create policy "Business accounts are visible when active or owned"
on public.business_accounts
for select
to authenticated
using (status = 'active' or owner_user_id = auth.uid());

drop policy if exists "Owners can update own business account" on public.business_accounts;
create policy "Owners can update own business account"
on public.business_accounts
for update
to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

notify pgrst, 'reload schema';
