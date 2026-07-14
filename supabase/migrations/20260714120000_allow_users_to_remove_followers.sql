alter table public.follows enable row level security;

drop policy if exists "Users can delete own follows" on public.follows;
drop policy if exists "Users can unfollow their own follows" on public.follows;
drop policy if exists "Follow participants can delete relationship" on public.follows;

create policy "Follow participants can delete relationship"
on public.follows
for delete
to authenticated
using (
  follower_id = auth.uid()
  or following_id = auth.uid()
);

revoke delete on table public.follows from anon;
grant delete on table public.follows to authenticated;

notify pgrst, 'reload schema';
