-- HallyuHub Beta Real v1 - Drops reales
-- Ejecutar en Supabase SQL Editor antes de probar Drops reales.
-- No borra datos existentes: crea bucket/tablas si faltan y ajusta RLS.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'drop_media',
  'drop_media',
  true,
  52428800,
  array['video/mp4', 'video/quicktime', 'video/webm']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.drops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  tags text[] not null default '{}',
  artist_id text not null default '',
  artist_name text not null default '',
  group_id text not null default '',
  group_name text not null default '',
  audio text not null default 'Audio original',
  filter text not null default 'Original',
  location text not null default '',
  duration_seconds integer,
  file_size integer,
  storage_bucket text not null default 'drop_media',
  storage_path text not null default '',
  video_url text not null default '',
  thumbnail_url text not null default '',
  status text not null default 'published' check (status in ('uploading', 'published', 'deleted')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.drops
  add column if not exists tags text[] not null default '{}',
  add column if not exists artist_id text not null default '',
  add column if not exists artist_name text not null default '',
  add column if not exists group_id text not null default '',
  add column if not exists group_name text not null default '',
  add column if not exists audio text not null default 'Audio original',
  add column if not exists filter text not null default 'Original',
  add column if not exists location text not null default '',
  add column if not exists duration_seconds integer,
  add column if not exists file_size integer,
  add column if not exists storage_bucket text not null default 'drop_media',
  add column if not exists storage_path text not null default '',
  add column if not exists video_url text not null default '',
  add column if not exists thumbnail_url text not null default '',
  add column if not exists status text not null default 'published',
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.drop_likes (
  drop_id uuid not null references public.drops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (drop_id, user_id)
);

create table if not exists public.drop_saves (
  drop_id uuid not null references public.drops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (drop_id, user_id)
);

create table if not exists public.drop_comments (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops(id) on delete cascade,
  parent_id uuid references public.drop_comments(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists drops_author_created_idx
  on public.drops(author_id, created_at desc);
create index if not exists drops_published_created_idx
  on public.drops(status, created_at desc)
  where deleted_at is null;
create index if not exists drop_comments_drop_created_idx
  on public.drop_comments(drop_id, created_at);

alter table public.drops enable row level security;
alter table public.drop_likes enable row level security;
alter table public.drop_saves enable row level security;
alter table public.drop_comments enable row level security;

drop policy if exists "drops public read" on public.drops;
create policy "drops public read" on public.drops
for select using (status = 'published' and deleted_at is null);

drop policy if exists "drops owner insert" on public.drops;
create policy "drops owner insert" on public.drops
for insert to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "drops owner update" on public.drops;
create policy "drops owner update" on public.drops
for update to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

drop policy if exists "drops owner delete" on public.drops;
create policy "drops owner delete" on public.drops
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "drop likes public read" on public.drop_likes;
create policy "drop likes public read" on public.drop_likes
for select using (true);

drop policy if exists "drop likes self manage" on public.drop_likes;
create policy "drop likes self manage" on public.drop_likes
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "drop saves public read" on public.drop_saves;
create policy "drop saves public read" on public.drop_saves
for select using (true);

drop policy if exists "drop saves self manage" on public.drop_saves;
create policy "drop saves self manage" on public.drop_saves
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "drop comments public read" on public.drop_comments;
create policy "drop comments public read" on public.drop_comments
for select using (
  exists (
    select 1
    from public.drops drops
    where drops.id = public.drop_comments.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
  )
);

drop policy if exists "drop comments owner insert" on public.drop_comments;
create policy "drop comments owner insert" on public.drop_comments
for insert to authenticated
with check (
  (select auth.uid()) = author_id
  and exists (
    select 1
    from public.drops drops
    where drops.id = public.drop_comments.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
  )
);

drop policy if exists "drop comments owner delete" on public.drop_comments;
create policy "drop comments owner delete" on public.drop_comments
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "public drop media read" on storage.objects;
create policy "public drop media read" on storage.objects
for select using (bucket_id = 'drop_media');

drop policy if exists "drop media upload own folder" on storage.objects;
create policy "drop media upload own folder" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'drop_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "drop media update own folder" on storage.objects;
create policy "drop media update own folder" on storage.objects
for update to authenticated
using (
  bucket_id = 'drop_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'drop_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "drop media delete own folder" on storage.objects;
create policy "drop media delete own folder" on storage.objects
for delete to authenticated
using (
  bucket_id = 'drop_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
