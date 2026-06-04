create table if not exists public.user_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer,
  category text,
  message text,
  source text,
  created_at timestamptz not null default now(),
  constraint user_feedback_rating_check
    check (rating is null or rating between 1 and 5),
  constraint user_feedback_message_length_check
    check (message is null or length(message) <= 1000)
);

create index if not exists user_feedback_user_created_at_idx
  on public.user_feedback (user_id, created_at desc);

create index if not exists user_feedback_created_at_idx
  on public.user_feedback (created_at desc);

alter table public.user_feedback enable row level security;

drop policy if exists "Users can insert own feedback"
  on public.user_feedback;
create policy "Users can insert own feedback"
on public.user_feedback
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can read own feedback"
  on public.user_feedback;
create policy "Users can read own feedback"
on public.user_feedback
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Admins can read all feedback"
  on public.user_feedback;
create policy "Admins can read all feedback"
on public.user_feedback
for select
to authenticated
using (public.is_current_user_admin());

revoke all on public.user_feedback from anon;
revoke all on public.user_feedback from authenticated;
grant insert, select on public.user_feedback to authenticated;

notify pgrst, 'reload schema';
