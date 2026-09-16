-- HallyuHub Beta Real v1 - Real posts + carousel media
-- Run in Supabase SQL Editor. Safe to run again.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'post_media',
  'post_media',
  true,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'video/webm']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  location text not null default '',
  privacy text not null default 'Todos',
  artist_id text not null default '',
  group_id text not null default '',
  music text not null default '',
  filter_index integer not null default 0,
  tagged_people text[] not null default '{}',
  tags text[] not null default '{}',
  status text not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  media_type text not null check (media_type in ('image', 'video')),
  storage_bucket text not null default 'post_media',
  storage_path text not null,
  public_url text,
  sort_order integer not null default 0,
  transform jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.post_saves (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('post', 'drop', 'fancam')),
  content_id uuid not null,
  parent_id uuid references public.comments(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_saves enable row level security;
alter table public.comments enable row level security;

drop policy if exists "posts public read" on public.posts;
create policy "posts public read" on public.posts
for select using (status = 'published');

drop policy if exists "posts owner insert" on public.posts;
create policy "posts owner insert" on public.posts
for insert to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "posts owner update" on public.posts;
create policy "posts owner update" on public.posts
for update to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

drop policy if exists "posts owner delete" on public.posts;
create policy "posts owner delete" on public.posts
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "post media public read" on public.post_media;
create policy "post media public read" on public.post_media
for select using (true);

drop policy if exists "post media owner insert" on public.post_media;
create policy "post media owner insert" on public.post_media
for insert to authenticated
with check (
  exists (
    select 1
    from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);

drop policy if exists "post media owner update" on public.post_media;
create policy "post media owner update" on public.post_media
for update to authenticated
using (
  exists (
    select 1
    from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);

drop policy if exists "post media owner delete" on public.post_media;
create policy "post media owner delete" on public.post_media
for delete to authenticated
using (
  exists (
    select 1
    from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);

drop policy if exists "post reactions public read" on public.post_likes;
create policy "post reactions public read" on public.post_likes
for select using (true);

drop policy if exists "post likes self manage" on public.post_likes;
create policy "post likes self manage" on public.post_likes
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "post saves public read" on public.post_saves;
create policy "post saves public read" on public.post_saves
for select using (true);

drop policy if exists "post saves self manage" on public.post_saves;
create policy "post saves self manage" on public.post_saves
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "comments public read" on public.comments;
create policy "comments public read" on public.comments
for select using (true);

drop policy if exists "comments owner insert" on public.comments;
create policy "comments owner insert" on public.comments
for insert to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "comments owner delete" on public.comments;
create policy "comments owner delete" on public.comments
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "public post media read" on storage.objects;
create policy "public post media read" on storage.objects
for select using (bucket_id = 'post_media');

drop policy if exists "post media upload own folder" on storage.objects;
create policy "post media upload own folder" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'post_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "post media update own folder" on storage.objects;
create policy "post media update own folder" on storage.objects
for update to authenticated
using (
  bucket_id = 'post_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'post_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "post media delete own folder" on storage.objects;
create policy "post media delete own folder" on storage.objects
for delete to authenticated
using (
  bucket_id = 'post_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

