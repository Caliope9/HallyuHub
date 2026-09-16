-- HallyuHub Beta Real v1 - schema fix 2026-06-13
-- Safe migration for the current Flutter web deploy.
-- Run in Supabase SQL Editor. It does not drop/truncate data.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'post_media',
    'post_media',
    true,
    52428800,
    array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'video/webm']
  ),
  (
    'story_media',
    'story_media',
    true,
    52428800,
    array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'video/webm']
  )
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default 'Hallyu Fan',
  username text,
  bio text not null default '',
  avatar_asset text not null default 'assets/demo-users/ai-luna-rivas.png',
  avatar_url text,
  fandom text not null default 'Nuevo fandom',
  country text not null default 'Chile',
  language text not null default 'Español',
  phone text not null default '',
  bias text not null default 'Jungkook',
  favorite_group text not null default 'BTS',
  phrase text not null default 'Compartiendo mi mundo fandom.',
  content_region text not null default 'Latam',
  private_profile boolean not null default false,
  notifications_enabled boolean not null default true,
  message_privacy text not null default 'Seguidores',
  story_privacy text not null default 'Seguidores',
  app_theme text not null default 'Sistema',
  profile_background text not null default 'Pastel neon',
  notify_messages boolean not null default true,
  notify_stars boolean not null default true,
  notify_comments boolean not null default true,
  notify_followers boolean not null default true,
  notify_drops boolean not null default true,
  two_factor_enabled boolean not null default false,
  login_alerts boolean not null default true,
  account_verified boolean not null default false,
  blocked_users jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists name text not null default 'Hallyu Fan',
  add column if not exists username text,
  add column if not exists bio text not null default '',
  add column if not exists avatar_asset text not null default 'assets/demo-users/ai-luna-rivas.png',
  add column if not exists avatar_url text,
  add column if not exists fandom text not null default 'Nuevo fandom',
  add column if not exists country text not null default 'Chile',
  add column if not exists language text not null default 'Español',
  add column if not exists phone text not null default '',
  add column if not exists bias text not null default 'Jungkook',
  add column if not exists favorite_group text not null default 'BTS',
  add column if not exists phrase text not null default 'Compartiendo mi mundo fandom.',
  add column if not exists content_region text not null default 'Latam',
  add column if not exists private_profile boolean not null default false,
  add column if not exists notifications_enabled boolean not null default true,
  add column if not exists message_privacy text not null default 'Seguidores',
  add column if not exists story_privacy text not null default 'Seguidores',
  add column if not exists app_theme text not null default 'Sistema',
  add column if not exists profile_background text not null default 'Pastel neon',
  add column if not exists notify_messages boolean not null default true,
  add column if not exists notify_stars boolean not null default true,
  add column if not exists notify_comments boolean not null default true,
  add column if not exists notify_followers boolean not null default true,
  add column if not exists notify_drops boolean not null default true,
  add column if not exists two_factor_enabled boolean not null default false,
  add column if not exists login_alerts boolean not null default true,
  add column if not exists account_verified boolean not null default false,
  add column if not exists blocked_users jsonb not null default '[]'::jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'avatar'
  ) then
    execute $sql$
      update public.profiles
      set
        avatar_asset = coalesce(nullif(avatar_asset, ''), nullif(avatar, ''), 'assets/demo-users/ai-luna-rivas.png'),
        avatar_url = case
          when coalesce(avatar_url, '') = '' and avatar like 'http%' then avatar
          else avatar_url
        end
    $sql$;
  end if;
end;
$$;

update public.profiles
set
  name = coalesce(nullif(name, ''), 'Hallyu Fan'),
  username = coalesce(nullif(username, ''), 'fan_' || substring(replace(id::text, '-', ''), 1, 8)),
  bio = coalesce(bio, ''),
  avatar_asset = coalesce(nullif(avatar_asset, ''), 'assets/demo-users/ai-luna-rivas.png'),
  fandom = coalesce(nullif(fandom, ''), 'Nuevo fandom'),
  country = coalesce(nullif(country, ''), 'Chile'),
  language = coalesce(nullif(language, ''), 'Español'),
  phone = coalesce(phone, ''),
  bias = coalesce(nullif(bias, ''), 'Jungkook'),
  favorite_group = coalesce(nullif(favorite_group, ''), 'BTS'),
  phrase = coalesce(nullif(phrase, ''), 'Compartiendo mi mundo fandom.'),
  content_region = coalesce(nullif(content_region, ''), country, 'Latam'),
  blocked_users = coalesce(blocked_users, '[]'::jsonb),
  updated_at = coalesce(updated_at, now());

create index if not exists profiles_updated_at_idx on public.profiles(updated_at desc);
create index if not exists profiles_username_idx on public.profiles(username);
create index if not exists profiles_email_idx on public.profiles(email);

create or replace function public.handle_new_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username text;
  candidate_username text;
  suffix integer := 0;
begin
  base_username := lower(
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
      nullif(split_part(new.email, '@', 1), ''),
      'fan'
    )
  );
  base_username := regexp_replace(base_username, '[^a-z0-9_]+', '', 'g');

  if length(base_username) < 3 then
    base_username := 'fan_' || substring(replace(new.id::text, '-', ''), 1, 8);
  end if;

  candidate_username := left(base_username, 24);
  while exists (
    select 1
    from public.profiles
    where username = candidate_username
      and id <> new.id
  ) loop
    suffix := suffix + 1;
    candidate_username := left(base_username, 20)
      || '_'
      || substring(replace(new.id::text, '-', ''), 1, 6)
      || case when suffix > 1 then suffix::text else '' end;
  end loop;

  insert into public.profiles (
    id,
    email,
    name,
    username,
    avatar_asset,
    fandom,
    country,
    language,
    favorite_group,
    bias,
    content_region
  )
  values (
    new.id,
    new.email,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'Hallyu Fan'),
    candidate_username,
    'assets/demo-users/ai-luna-rivas.png',
    'Nuevo fandom',
    'Chile',
    'Español',
    'Por definir',
    'Bias secreto',
    'Latam'
  )
  on conflict (id) do update set
    email = excluded.email,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_auth_user_profile();

with missing_profiles as (
  select
    auth_user.id,
    auth_user.email,
    auth_user.raw_user_meta_data,
    lower(
      coalesce(
        nullif(trim(auth_user.raw_user_meta_data ->> 'username'), ''),
        nullif(split_part(auth_user.email, '@', 1), ''),
        'fan'
      )
    ) as raw_username
  from auth.users auth_user
  left join public.profiles profile on profile.id = auth_user.id
  where profile.id is null
),
prepared_profiles as (
  select
    id,
    email,
    raw_user_meta_data,
    case
      when length(regexp_replace(raw_username, '[^a-z0-9_]+', '', 'g')) < 3
        then 'fan_' || substring(replace(id::text, '-', ''), 1, 8)
      else regexp_replace(raw_username, '[^a-z0-9_]+', '', 'g')
    end as base_username
  from missing_profiles
)
insert into public.profiles (
  id,
  email,
  name,
  username,
  avatar_asset,
  fandom,
  country,
  language,
  favorite_group,
  bias,
  content_region
)
select
  id,
  email,
  coalesce(nullif(trim(raw_user_meta_data ->> 'name'), ''), 'Hallyu Fan'),
  left(base_username, 20) || '_' || substring(replace(id::text, '-', ''), 1, 6),
  'assets/demo-users/ai-luna-rivas.png',
  'Nuevo fandom',
  'Chile',
  'Español',
  'Por definir',
  'Bias secreto',
  'Latam'
from prepared_profiles
on conflict (id) do nothing;

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create index if not exists follows_follower_idx on public.follows(follower_id);
create index if not exists follows_following_idx on public.follows(following_id);

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

alter table public.posts
  add column if not exists author_id uuid references public.profiles(id) on delete cascade,
  add column if not exists caption text not null default '',
  add column if not exists location text not null default '',
  add column if not exists privacy text not null default 'Todos',
  add column if not exists artist_id text not null default '',
  add column if not exists group_id text not null default '',
  add column if not exists music text not null default '',
  add column if not exists filter_index integer not null default 0,
  add column if not exists tagged_people text[] not null default '{}',
  add column if not exists tags text[] not null default '{}',
  add column if not exists status text not null default 'published',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

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

alter table public.post_media
  add column if not exists post_id uuid references public.posts(id) on delete cascade,
  add column if not exists media_type text not null default 'image',
  add column if not exists storage_bucket text not null default 'post_media',
  add column if not exists storage_path text not null default '',
  add column if not exists public_url text,
  add column if not exists sort_order integer not null default 0,
  add column if not exists transform jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz not null default now();

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

alter table public.comments
  add column if not exists content_type text not null default 'post',
  add column if not exists content_id uuid,
  add column if not exists parent_id uuid references public.comments(id) on delete cascade,
  add column if not exists author_id uuid references public.profiles(id) on delete cascade,
  add column if not exists body text not null default '',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists posts_author_created_idx on public.posts(author_id, created_at desc);
create index if not exists posts_status_created_idx on public.posts(status, created_at desc);
create index if not exists post_media_post_order_idx on public.post_media(post_id, sort_order);
create index if not exists comments_content_created_idx on public.comments(content_type, content_id, created_at);

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
  background_colors bigint[] not null default '{}',
  elements jsonb not null default '[]'::jsonb,
  media_transform jsonb not null default '{}'::jsonb,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.stories
  add column if not exists author_id uuid references public.profiles(id) on delete cascade,
  add column if not exists title text not null default '',
  add column if not exists detail text not null default '',
  add column if not exists text text not null default '',
  add column if not exists music text not null default '',
  add column if not exists music_asset text not null default '',
  add column if not exists content_type text not null default 'image',
  add column if not exists duration_seconds integer not null default 5,
  add column if not exists visual_filter text not null default 'original',
  add column if not exists background_colors bigint[] not null default '{}',
  add column if not exists elements jsonb not null default '[]'::jsonb,
  add column if not exists media_transform jsonb not null default '{}'::jsonb,
  add column if not exists expires_at timestamptz not null default (now() + interval '24 hours'),
  add column if not exists archived_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

alter table public.stories
  alter column background_colors type bigint[]
  using background_colors::bigint[];

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

alter table public.story_media
  add column if not exists story_id uuid references public.stories(id) on delete cascade,
  add column if not exists media_type text not null default 'image',
  add column if not exists storage_bucket text not null default 'story_media',
  add column if not exists storage_path text not null default '',
  add column if not exists public_url text,
  add column if not exists sort_order integer not null default 0,
  add column if not exists transform jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz not null default now();

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

create index if not exists stories_author_created_idx on public.stories(author_id, created_at desc);
create index if not exists stories_active_idx on public.stories(expires_at, created_at desc);
create index if not exists story_media_story_order_idx on public.story_media(story_id, sort_order);

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_saves enable row level security;
alter table public.comments enable row level security;
alter table public.stories enable row level security;
alter table public.story_media enable row level security;
alter table public.story_views enable row level security;
alter table public.story_likes enable row level security;

drop policy if exists "profiles public read" on public.profiles;
create policy "profiles public read" on public.profiles
for select using (true);

drop policy if exists "profiles owner insert" on public.profiles;
create policy "profiles owner insert" on public.profiles
for insert to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "profiles owner update" on public.profiles;
create policy "profiles owner update" on public.profiles
for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "follows public read" on public.follows;
create policy "follows public read" on public.follows
for select using (true);

drop policy if exists "follows self manage" on public.follows;
create policy "follows self manage" on public.follows
for all to authenticated
using ((select auth.uid()) = follower_id)
with check ((select auth.uid()) = follower_id);

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
    from public.posts posts
    where posts.id = public.post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);

drop policy if exists "post media owner update" on public.post_media;
create policy "post media owner update" on public.post_media
for update to authenticated
using (
  exists (
    select 1
    from public.posts posts
    where posts.id = public.post_media.post_id
      and posts.author_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.posts posts
    where posts.id = public.post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);

drop policy if exists "post media owner delete" on public.post_media;
create policy "post media owner delete" on public.post_media
for delete to authenticated
using (
  exists (
    select 1
    from public.posts posts
    where posts.id = public.post_media.post_id
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
with check (
  (select auth.uid()) = author_id
  and body <> ''
  and char_length(body) <= 1000
);

drop policy if exists "comments owner delete" on public.comments;
create policy "comments owner delete" on public.comments
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "stories own or followed active read" on public.stories;
create policy "stories own or followed active read" on public.stories
for select to authenticated
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
create policy "stories owner insert" on public.stories
for insert to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "stories owner update" on public.stories;
create policy "stories owner update" on public.stories
for update to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

drop policy if exists "stories owner delete" on public.stories;
create policy "stories owner delete" on public.stories
for delete to authenticated
using ((select auth.uid()) = author_id);

drop policy if exists "story media own or followed read" on public.story_media;
create policy "story media own or followed read" on public.story_media
for select to authenticated
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
create policy "story media owner insert" on public.story_media
for insert to authenticated
with check (
  exists (
    select 1
    from public.stories stories
    where stories.id = public.story_media.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story media owner update" on public.story_media;
create policy "story media owner update" on public.story_media
for update to authenticated
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
create policy "story media owner delete" on public.story_media
for delete to authenticated
using (
  exists (
    select 1
    from public.stories stories
    where stories.id = public.story_media.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story views readable by viewer or author" on public.story_views;
create policy "story views readable by viewer or author" on public.story_views
for select to authenticated
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
create policy "story views owner insert" on public.story_views
for insert to authenticated
with check ((select auth.uid()) = viewer_id);

drop policy if exists "story views owner update" on public.story_views;
create policy "story views owner update" on public.story_views
for update to authenticated
using ((select auth.uid()) = viewer_id)
with check ((select auth.uid()) = viewer_id);

drop policy if exists "story views owner delete" on public.story_views;
create policy "story views owner delete" on public.story_views
for delete to authenticated
using ((select auth.uid()) = viewer_id);

drop policy if exists "story likes readable by liker or author" on public.story_likes;
create policy "story likes readable by liker or author" on public.story_likes
for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.stories stories
    where stories.id = public.story_likes.story_id
      and stories.author_id = (select auth.uid())
  )
);

drop policy if exists "story likes self manage" on public.story_likes;
create policy "story likes self manage" on public.story_likes
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

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

drop policy if exists "public story media read" on storage.objects;
create policy "public story media read" on storage.objects
for select using (bucket_id = 'story_media');

drop policy if exists "story media upload own folder" on storage.objects;
create policy "story media upload own folder" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "story media update own folder" on storage.objects;
create policy "story media update own folder" on storage.objects
for update to authenticated
using (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "story media delete own folder" on storage.objects;
create policy "story media delete own folder" on storage.objects
for delete to authenticated
using (
  bucket_id = 'story_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

notify pgrst, 'reload schema';
