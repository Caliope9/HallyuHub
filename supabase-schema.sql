-- HallyuHub Supabase schema
-- 1. Create a Supabase project.
-- 2. Open SQL Editor and run this file.
-- 3. This file creates public Storage buckets named: avatars, post-media, trend-media.
-- 4. Put your project URL and anon key in supabase-config.js.

create extension if not exists "pgcrypto";

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('post-media', 'post-media', true),
  ('trend-media', 'trend-media', true)
on conflict (id) do update set public = excluded.public;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default 'Hallyu Fan',
  username text unique not null,
  bio text default '',
  avatar text default 'berry',
  avatar_url text,
  ambience text default 'hallyu',
  accent text default '#fbbcdb',
  mode text default 'dark',
  notifications boolean default true,
  private_profile boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  media_url text,
  media_type text check (media_type in ('image', 'video')),
  category text default 'post',
  created_at timestamptz default now()
);

create table if not exists public.follows (
  follower_id uuid references public.profiles(id) on delete cascade,
  following_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.likes (
  user_id uuid references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, post_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);

create table if not exists public.private_threads (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  accepted boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.private_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.private_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  media_url text,
  created_at timestamptz default now()
);

create table if not exists public.trends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  challenge text not null,
  song text not null,
  description text default '',
  media_url text,
  media_type text check (media_type in ('image', 'video')),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.follows enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.private_threads enable row level security;
alter table public.private_messages enable row level security;
alter table public.trends enable row level security;

create policy "profiles visible" on public.profiles for select using (true);
create policy "profile owner insert" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "profile owner update" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "posts visible" on public.posts for select using (true);
create policy "posts owner insert" on public.posts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "posts owner update" on public.posts for update to authenticated using ((select auth.uid()) = user_id);
create policy "posts owner delete" on public.posts for delete to authenticated using ((select auth.uid()) = user_id);

create policy "follows visible" on public.follows for select using (true);
create policy "follow self action" on public.follows for all to authenticated using ((select auth.uid()) = follower_id) with check ((select auth.uid()) = follower_id);

create policy "likes visible" on public.likes for select using (true);
create policy "like self action" on public.likes for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "comments visible" on public.comments for select using (true);
create policy "comments owner insert" on public.comments for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "comments owner delete" on public.comments for delete to authenticated using ((select auth.uid()) = user_id);

create policy "threads participants visible" on public.private_threads for select to authenticated using (
  (select auth.uid()) = created_by or (select auth.uid()) = recipient_id
);
create policy "threads creator insert" on public.private_threads for insert to authenticated with check ((select auth.uid()) = created_by);
create policy "threads recipient accept" on public.private_threads for update to authenticated using ((select auth.uid()) = recipient_id);

create policy "messages participants visible" on public.private_messages for select to authenticated using (
  exists (
    select 1 from public.private_threads t
    where t.id = thread_id
    and ((select auth.uid()) = t.created_by or (select auth.uid()) = t.recipient_id)
  )
);
create policy "messages participants insert when accepted" on public.private_messages for insert to authenticated with check (
  (select auth.uid()) = sender_id
  and exists (
    select 1 from public.private_threads t
    where t.id = thread_id
    and t.accepted = true
    and ((select auth.uid()) = t.created_by or (select auth.uid()) = t.recipient_id)
  )
);

create policy "trends visible" on public.trends for select using (true);
create policy "trends owner insert" on public.trends for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "trends owner update" on public.trends for update to authenticated using ((select auth.uid()) = user_id);
create policy "trends owner delete" on public.trends for delete to authenticated using ((select auth.uid()) = user_id);

create policy "avatar files are public" on storage.objects for select using (bucket_id = 'avatars');
create policy "post media files are public" on storage.objects for select using (bucket_id = 'post-media');
create policy "trend media files are public" on storage.objects for select using (bucket_id = 'trend-media');

create policy "users upload own avatars" on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "users update own avatars" on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "users upload own post media" on storage.objects for insert to authenticated
with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "users upload own trend media" on storage.objects for insert to authenticated
with check (bucket_id = 'trend-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
