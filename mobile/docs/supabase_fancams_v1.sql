-- HallyuHub Beta Real v1 - Fancams reales
-- Ejecutar en Supabase SQL Editor antes de probar Fancams reales.
-- No borra datos existentes: crea bucket/tablas si faltan y ajusta RLS.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'fancam_media',
  'fancam_media',
  true,
  52428800,
  array['video/mp4', 'video/quicktime', 'video/webm']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.fancams (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  tags text[] not null default '{}',
  artist_id text not null default '',
  artist_name text not null default '',
  group_id text not null default '',
  group_name text not null default '',
  event_name text not null default '',
  song_name text not null default '',
  audio text not null default 'Audio original',
  location text not null default '',
  duration_seconds integer,
  file_size integer,
  storage_bucket text not null default 'fancam_media',
  storage_path text not null default '',
  video_url text not null default '',
  thumbnail_url text not null default '',
  status text not null default 'published' check (status in ('uploading', 'published', 'deleted')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.fancams
  add column if not exists tags text[] not null default '{}',
  add column if not exists artist_id text not null default '',
  add column if not exists artist_name text not null default '',
  add column if not exists group_id text not null default '',
  add column if not exists group_name text not null default '',
  add column if not exists event_name text not null default '',
  add column if not exists song_name text not null default '',
  add column if not exists audio text not null default 'Audio original',
  add column if not exists location text not null default '',
  add column if not exists duration_seconds integer,
  add column if not exists file_size integer,
  add column if not exists storage_bucket text not null default 'fancam_media',
  add column if not exists storage_path text not null default '',
  add column if not exists video_url text not null default '',
  add column if not exists thumbnail_url text not null default '',
  add column if not exists status text not null default 'published',
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.fancam_likes (
  fancam_id uuid not null references public.fancams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (fancam_id, user_id)
);

create table if not exists public.fancam_saves (
  fancam_id uuid not null references public.fancams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (fancam_id, user_id)
);

create table if not exists public.fancam_comments (
  id uuid primary key default gen_random_uuid(),
  fancam_id uuid not null references public.fancams(id) on delete cascade,
  parent_id uuid references public.fancam_comments(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fancams_author_created_idx
  on public.fancams(author_id, created_at desc);
create index if not exists fancams_artist_created_idx
  on public.fancams(artist_id, created_at desc)
  where deleted_at is null;
create index if not exists fancams_group_created_idx
  on public.fancams(group_id, created_at desc)
  where deleted_at is null;
create index if not exists fancams_published_created_idx
  on public.fancams(status, created_at desc)
  where deleted_at is null;
create index if not exists fancam_comments_fancam_created_idx
  on public.fancam_comments(fancam_id, created_at);

alter table public.fancams enable row level security;
alter table public.fancam_likes enable row level security;
alter table public.fancam_saves enable row level security;
alter table public.fancam_comments enable row level security;

drop policy if exists "fancams public read" on public.fancams;
create policy "fancams public read" on public.fancams
for select using (status = 'published' and deleted_at is null);

drop policy if exists "fancams owner insert" on public.fancams;
create policy "fancams owner insert" on public.fancams
for insert to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "fancams owner update" on public.fancams;
create policy "fancams owner update" on public.fancams
for update to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

drop policy if exists "fancams owner delete" on public.fancams;
create policy "fancams owner delete" on public.fancams
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "fancam likes public read" on public.fancam_likes;
create policy "fancam likes public read" on public.fancam_likes
for select using (true);

drop policy if exists "fancam likes self manage" on public.fancam_likes;
create policy "fancam likes self manage" on public.fancam_likes
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "fancam saves public read" on public.fancam_saves;
create policy "fancam saves public read" on public.fancam_saves
for select using (true);

drop policy if exists "fancam saves self manage" on public.fancam_saves;
create policy "fancam saves self manage" on public.fancam_saves
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "fancam comments public read" on public.fancam_comments;
create policy "fancam comments public read" on public.fancam_comments
for select using (
  exists (
    select 1
    from public.fancams fancams
    where fancams.id = public.fancam_comments.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
  )
);

drop policy if exists "fancam comments owner insert" on public.fancam_comments;
create policy "fancam comments owner insert" on public.fancam_comments
for insert to authenticated
with check (
  (select auth.uid()) = author_id
  and exists (
    select 1
    from public.fancams fancams
    where fancams.id = public.fancam_comments.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
  )
);

drop policy if exists "fancam comments owner delete" on public.fancam_comments;
create policy "fancam comments owner delete" on public.fancam_comments
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "public fancam media read" on storage.objects;
create policy "public fancam media read" on storage.objects
for select using (bucket_id = 'fancam_media');

drop policy if exists "fancam media upload own folder" on storage.objects;
create policy "fancam media upload own folder" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'fancam_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "fancam media update own folder" on storage.objects;
create policy "fancam media update own folder" on storage.objects
for update to authenticated
using (
  bucket_id = 'fancam_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'fancam_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "fancam media delete own folder" on storage.objects;
create policy "fancam media delete own folder" on storage.objects
for delete to authenticated
using (
  bucket_id = 'fancam_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
