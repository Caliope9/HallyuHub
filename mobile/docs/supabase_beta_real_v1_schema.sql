-- HallyuHub Beta Real v1 schema
-- Run manually in Supabase SQL Editor after reviewing.
-- Non-destructive data policy: this file creates tables/buckets if missing.
-- If policies already exist in your project, review names before re-running.

create extension if not exists "pgcrypto";

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('post_media', 'post_media', true),
  ('story_media', 'story_media', true),
  ('drop_media', 'drop_media', true),
  ('fancam_media', 'fancam_media', true),
  ('collection_media', 'collection_media', true)
on conflict (id) do nothing;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  name text not null default 'Hallyu Fan',
  username text unique not null,
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

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

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

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  request_status text not null default 'pending' check (request_status in ('pending', 'accepted', 'rejected', 'blocked')),
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  unique (created_by, recipient_id),
  check (created_by <> recipient_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  story_id uuid references public.stories(id) on delete set null,
  media_url text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  name text not null,
  country text not null default '',
  region text not null default '',
  city text not null default '',
  fandom text not null default '',
  description text not null default '',
  privacy text not null default 'public' check (privacy in ('public', 'private')),
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

create table if not exists public.community_messages (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  community_id uuid references public.communities(id) on delete set null,
  title text not null,
  country text not null default '',
  region text not null default '',
  city text not null default '',
  starts_at timestamptz,
  description text not null default '',
  fandom text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.event_attendees (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'going',
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create table if not exists public.drops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  artist_id text not null default '',
  group_id text not null default '',
  location text not null default '',
  audio text not null default 'Audio original',
  storage_bucket text not null default 'drop_media',
  storage_path text not null,
  public_url text,
  duration_seconds numeric,
  trim_start_seconds numeric not null default 0,
  trim_end_seconds numeric,
  optimized_for_upload boolean not null default false,
  status text not null default 'published',
  created_at timestamptz not null default now()
);

create table if not exists public.fancams (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  artist_id text not null default '',
  group_id text not null default '',
  location text not null default '',
  storage_bucket text not null default 'fancam_media',
  storage_path text not null,
  public_url text,
  duration_seconds numeric,
  status text not null default 'published',
  created_at timestamptz not null default now()
);

create table if not exists public.collection_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  group_artist text not null default '',
  era_album text not null default '',
  category text not null default 'photocard',
  status text not null default 'in_collection',
  description text not null default '',
  storage_bucket text not null default 'collection_media',
  storage_path text,
  public_url text,
  price text not null default '',
  currency text not null default '',
  city text not null default '',
  country text not null default '',
  visibility text not null default 'public',
  trade_looking_for text not null default '',
  tags text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default '',
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  content_type text not null,
  content_id text not null,
  reason text not null,
  details text not null default '',
  status text not null default 'open',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_saves enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.stories enable row level security;
alter table public.story_media enable row level security;
alter table public.story_views enable row level security;
alter table public.story_likes enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.community_messages enable row level security;
alter table public.events enable row level security;
alter table public.event_attendees enable row level security;
alter table public.drops enable row level security;
alter table public.fancams enable row level security;
alter table public.collection_items enable row level security;
alter table public.user_blocks enable row level security;
alter table public.content_reports enable row level security;

create policy "profiles public read" on public.profiles for select using (true);
create policy "profiles owner insert" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "profiles owner update" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "follows public read" on public.follows for select using (true);
create policy "follows self manage" on public.follows for all to authenticated using ((select auth.uid()) = follower_id) with check ((select auth.uid()) = follower_id);

create policy "posts public read" on public.posts for select using (status = 'published');
create policy "posts owner insert" on public.posts for insert to authenticated with check ((select auth.uid()) = author_id);
create policy "posts owner update" on public.posts for update to authenticated using ((select auth.uid()) = author_id);
create policy "posts owner delete" on public.posts for delete to authenticated using ((select auth.uid()) = author_id);

create policy "post media public read" on public.post_media for select using (true);
create policy "post media owner insert" on public.post_media for insert to authenticated
with check (
  exists (
    select 1 from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);
create policy "post media owner update" on public.post_media for update to authenticated
using (
  exists (
    select 1 from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);
create policy "post media owner delete" on public.post_media for delete to authenticated
using (
  exists (
    select 1 from public.posts
    where posts.id = post_media.post_id
      and posts.author_id = (select auth.uid())
  )
);
create policy "post reactions public read" on public.post_likes for select using (true);
create policy "post likes self manage" on public.post_likes for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "post saves self manage" on public.post_saves for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "comments public read" on public.comments for select using (true);
create policy "comments owner insert" on public.comments for insert to authenticated with check ((select auth.uid()) = author_id);
create policy "comments owner delete" on public.comments for delete to authenticated using ((select auth.uid()) = author_id);
create policy "comment likes self manage" on public.comment_likes for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "stories public read" on public.stories for select using (expires_at > now() or archived_at is not null);
create policy "stories owner insert" on public.stories for insert to authenticated with check ((select auth.uid()) = author_id);
create policy "stories owner update" on public.stories for update to authenticated using ((select auth.uid()) = author_id);
create policy "stories owner delete" on public.stories for delete to authenticated using ((select auth.uid()) = author_id);
create policy "story media public read" on public.story_media for select using (true);
create policy "story views self manage" on public.story_views for all to authenticated using ((select auth.uid()) = viewer_id) with check ((select auth.uid()) = viewer_id);
create policy "story likes self manage" on public.story_likes for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "conversations participant read" on public.conversations for select to authenticated using ((select auth.uid()) = created_by or (select auth.uid()) = recipient_id);
create policy "conversations creator insert" on public.conversations for insert to authenticated with check ((select auth.uid()) = created_by);
create policy "conversations participant update" on public.conversations for update to authenticated using ((select auth.uid()) = created_by or (select auth.uid()) = recipient_id);
create policy "messages participant read" on public.messages for select to authenticated using (
  exists (
    select 1 from public.conversations c
    where c.id = conversation_id
    and ((select auth.uid()) = c.created_by or (select auth.uid()) = c.recipient_id)
  )
);
create policy "messages participant insert" on public.messages for insert to authenticated with check (
  (select auth.uid()) = sender_id
  and exists (
    select 1 from public.conversations c
    where c.id = conversation_id
    and ((select auth.uid()) = c.created_by or (select auth.uid()) = c.recipient_id)
    and c.request_status in ('pending', 'accepted')
  )
);

create policy "communities public read" on public.communities for select using (privacy = 'public' or owner_id = (select auth.uid()));
create policy "communities owner insert" on public.communities for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "community members public read" on public.community_members for select using (true);
create policy "community members self manage" on public.community_members for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "community messages member read" on public.community_messages for select to authenticated using (
  exists (
    select 1 from public.community_members m
    where m.community_id = community_messages.community_id
    and m.user_id = (select auth.uid())
  )
);
create policy "community messages member insert" on public.community_messages for insert to authenticated with check (
  (select auth.uid()) = sender_id
  and exists (
    select 1 from public.community_members m
    where m.community_id = community_messages.community_id
    and m.user_id = (select auth.uid())
  )
);

create policy "events public read" on public.events for select using (true);
create policy "event attendees self manage" on public.event_attendees for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "drops public read" on public.drops for select using (status = 'published');
create policy "drops owner insert" on public.drops for insert to authenticated with check ((select auth.uid()) = author_id);
create policy "drops owner update" on public.drops for update to authenticated using ((select auth.uid()) = author_id);
create policy "fancams public read" on public.fancams for select using (status = 'published');
create policy "fancams owner insert" on public.fancams for insert to authenticated with check ((select auth.uid()) = author_id);
create policy "fancams owner update" on public.fancams for update to authenticated using ((select auth.uid()) = author_id);
create policy "collection public read" on public.collection_items for select using (visibility = 'public' or owner_id = (select auth.uid()));
create policy "collection owner manage" on public.collection_items for all to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "blocks self manage" on public.user_blocks for all to authenticated using ((select auth.uid()) = blocker_id) with check ((select auth.uid()) = blocker_id);
create policy "reports insert authenticated" on public.content_reports for insert to authenticated with check ((select auth.uid()) = reporter_id);

create policy "public avatar read" on storage.objects for select using (bucket_id = 'avatars');
create policy "public post media read" on storage.objects for select using (bucket_id = 'post_media');
create policy "public story media read" on storage.objects for select using (bucket_id = 'story_media');
create policy "public drop media read" on storage.objects for select using (bucket_id = 'drop_media');
create policy "public fancam media read" on storage.objects for select using (bucket_id = 'fancam_media');
create policy "public collection media read" on storage.objects for select using (bucket_id = 'collection_media');

create policy "users upload own media folders" on storage.objects for insert to authenticated
with check (
  bucket_id in ('avatars', 'post_media', 'story_media', 'drop_media', 'fancam_media', 'collection_media')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "users update own media folders" on storage.objects for update to authenticated
using (
  bucket_id in ('avatars', 'post_media', 'story_media', 'drop_media', 'fancam_media', 'collection_media')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "users delete own media folders" on storage.objects for delete to authenticated
using (
  bucket_id in ('avatars', 'post_media', 'story_media', 'drop_media', 'fancam_media', 'collection_media')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
