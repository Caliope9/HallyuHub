-- HallyuHub Beta Real v1 - Stories reales
-- Ejecutar en Supabase SQL Editor antes de probar stories reales.
-- No borra datos existentes: crea tablas/bucket si faltan y ajusta RLS.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'story_media',
  'story_media',
  true,
  52428800,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'video/webm'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default '',
  detail text not null default '',
  text text not null default '',
  music text not null default '',
  music_asset text not null default '',
  content_type text not null default 'image' check (content_type in ('image', 'text', 'video')),
  duration_seconds integer not null default 5,
  visual_filter text not null default 'original',
  background_colors integer[] not null default '{}',
  elements jsonb not null default '[]'::jsonb,
  media_transform jsonb not null default '{}'::jsonb,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.story_media (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories(id) on delete cascade,
  media_type text not null check (media_type in ('image', 'video')),
  storage_bucket text not null default 'story_media',
  storage_path text not null,
  public_url text,
  sort_order integer not null default 0,
  transform jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

create table if not exists public.story_likes (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

create index if not exists stories_author_created_idx
  on public.stories(author_id, created_at desc);
create index if not exists stories_active_idx
  on public.stories(expires_at, created_at desc);
create index if not exists story_media_story_order_idx
  on public.story_media(story_id, sort_order);

alter table public.stories enable row level security;
alter table public.story_media enable row level security;
alter table public.story_views enable row level security;
alter table public.story_likes enable row level security;

drop policy if exists "stories public read" on public.stories;
drop policy if exists "stories own or followed active read" on public.stories;
create policy "stories own or followed active read"
on public.stories for select to authenticated
using (
  author_id = (select auth.uid())
  or (
    expires_at > now()
    and exists (
      select 1
      from public.follows follows
      where follows.follower_id = (select auth.uid())
        and follows.following_id = public.stories.author_id
    )
  )
);

drop policy if exists "stories owner insert" on public.stories;
create policy "stories owner insert"
on public.stories for insert to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "stories owner update" on public.stories;
create policy "stories owner update"
on public.stories for update to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

drop policy if exists "stories owner delete" on public.stories;
create policy "stories owner delete"
on public.stories for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "story media public read" on public.story_media;
drop policy if exists "story media own or followed read" on public.story_media;
create policy "story media own or followed read"
on public.story_media for select to authenticated
using (
  exists (
    select 1
    from public.stories stories
    where stories.id = public.story_media.story_id
      and (
        stories.author_id = (select auth.uid())
        or (
          stories.expires_at > now()
          and exists (
            select 1
            from public.follows follows
            where follows.follower_id = (select auth.uid())
              and follows.following_id = stories.author_id
          )
        )
      )
  )
);

drop policy if exists "story media owner insert" on public.story_media;
create policy "story media owner insert"
on public.story_media for insert to authenticated
with check (
  exists (
    select 1
    from public.stories stories
    where stories.id = public.story_media.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story media owner update" on public.story_media;
create policy "story media owner update"
on public.story_media for update to authenticated
using (
  exists (
    select 1
    from public.stories stories
    where stories.id = public.story_media.story_id
      and stories.author_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.stories stories
    where stories.id = public.story_media.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story media owner delete" on public.story_media;
create policy "story media owner delete"
on public.story_media for delete to authenticated
using (
  exists (
    select 1
    from public.stories stories
    where stories.id = public.story_media.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story views self manage" on public.story_views;
drop policy if exists "story views readable by viewer or author" on public.story_views;
create policy "story views readable by viewer or author"
on public.story_views for select to authenticated
using (
  viewer_id = (select auth.uid())
  or exists (
    select 1
    from public.stories stories
    where stories.id = public.story_views.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story views owner insert" on public.story_views;
create policy "story views owner insert"
on public.story_views for insert to authenticated
with check ((select auth.uid()) = viewer_id);

drop policy if exists "story views owner update" on public.story_views;
create policy "story views owner update"
on public.story_views for update to authenticated
using ((select auth.uid()) = viewer_id)
with check ((select auth.uid()) = viewer_id);

drop policy if exists "story views owner delete" on public.story_views;
create policy "story views owner delete"
on public.story_views for delete to authenticated
using ((select auth.uid()) = viewer_id);

drop policy if exists "story likes self manage" on public.story_likes;
drop policy if exists "story likes readable by liker or author" on public.story_likes;
create policy "story likes readable by liker or author"
on public.story_likes for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.stories stories
    where stories.id = public.story_likes.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story likes owner insert" on public.story_likes;
create policy "story likes owner insert"
on public.story_likes for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "story likes owner update" on public.story_likes;
create policy "story likes owner update"
on public.story_likes for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "story likes owner delete" on public.story_likes;
create policy "story likes owner delete"
on public.story_likes for delete to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "public story media read" on storage.objects;
drop policy if exists "story media public read" on storage.objects;
create policy "story media public read"
on storage.objects for select
using (bucket_id = 'story_media');

drop policy if exists "story media upload own folder" on storage.objects;
create policy "story media upload own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "story media update own folder" on storage.objects;
create policy "story media update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "story media delete own folder" on storage.objects;
create policy "story media delete own folder"
on storage.objects for delete to authenticated
using (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
