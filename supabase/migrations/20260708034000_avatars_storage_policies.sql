-- Storage policies for avatars bucket to align with folder-based ownership
do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'storage' 
      and tablename = 'objects' 
      and policyname = 'Avatars are publicly readable'
  ) then
    create policy "Avatars are publicly readable"
    on storage.objects for select to public
    using (bucket_id = 'avatars');
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'storage' 
      and tablename = 'objects' 
      and policyname = 'Users can upload own avatars'
  ) then
    create policy "Users can upload own avatars"
    on storage.objects for insert to authenticated
    with check (
      bucket_id = 'avatars'
      and auth.uid()::text = (storage.foldername(name))[1]
    );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'storage' 
      and tablename = 'objects' 
      and policyname = 'Users can update own avatars'
  ) then
    create policy "Users can update own avatars"
    on storage.objects for update to authenticated
    using (
      bucket_id = 'avatars'
      and auth.uid()::text = (storage.foldername(name))[1]
    )
    with check (
      bucket_id = 'avatars'
      and auth.uid()::text = (storage.foldername(name))[1]
    );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'storage' 
      and tablename = 'objects' 
      and policyname = 'Users can delete own avatars'
  ) then
    create policy "Users can delete own avatars"
    on storage.objects for delete to authenticated
    using (
      bucket_id = 'avatars'
      and auth.uid()::text = (storage.foldername(name))[1]
    );
  end if;
end
$$;

-- Hidden conversations table for Instagram-style delete inbox history
create table if not exists public.user_hidden_conversations (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_type text not null check (conversation_type in ('direct', 'event')),
  conversation_key text not null,
  hidden_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (user_id, conversation_type, conversation_key)
);

alter table public.user_hidden_conversations enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'public' 
      and tablename = 'user_hidden_conversations' 
      and policyname = 'Users can select own hidden conversations'
  ) then
    create policy "Users can select own hidden conversations"
    on public.user_hidden_conversations for select to authenticated
    using (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'public' 
      and tablename = 'user_hidden_conversations' 
      and policyname = 'Users can insert own hidden conversations'
  ) then
    create policy "Users can insert own hidden conversations"
    on public.user_hidden_conversations for insert to authenticated
    with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'public' 
      and tablename = 'user_hidden_conversations' 
      and policyname = 'Users can update own hidden conversations'
  ) then
    create policy "Users can update own hidden conversations"
    on public.user_hidden_conversations for update to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'public' 
      and tablename = 'user_hidden_conversations' 
      and policyname = 'Users can delete own hidden conversations'
  ) then
    create policy "Users can delete own hidden conversations"
    on public.user_hidden_conversations for delete to authenticated
    using (auth.uid() = user_id);
  end if;
end
$$;

grant select, insert, update, delete on table public.user_hidden_conversations to authenticated, anon, service_role;
