-- HallyuHub Beta Real - Home feed with followed users and followed K-pop entities.
-- Safe to run more than once.
-- Does not delete, truncate, reset users, or touch Storage.
--
-- Important:
-- The Flutter app already uses public.content_artist_tags for K-pop entity tags.
-- This migration creates it safely if the production schema is missing it.

create extension if not exists pgcrypto;

create table if not exists public.kpop_entities (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null default 'artist',
  name text not null,
  normalized_name text not null,
  aliases text[] not null default '{}',
  bio text not null default '',
  image_url text not null default '',
  image_source text not null default '',
  image_license text not null default '',
  attribution text not null default '',
  official_url text not null default '',
  is_verified boolean not null default false,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kpop_entities
  add column if not exists entity_type text not null default 'artist',
  add column if not exists normalized_name text not null default '',
  add column if not exists aliases text[] not null default '{}',
  add column if not exists bio text not null default '',
  add column if not exists image_url text not null default '',
  add column if not exists image_source text not null default '',
  add column if not exists image_license text not null default '',
  add column if not exists attribution text not null default '',
  add column if not exists official_url text not null default '',
  add column if not exists is_verified boolean not null default false,
  add column if not exists status text not null default 'pending',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists kpop_entities_normalized_name_idx
  on public.kpop_entities (normalized_name);

create index if not exists kpop_entities_type_name_idx
  on public.kpop_entities (entity_type, name);

create index if not exists kpop_entities_verified_name_idx
  on public.kpop_entities (is_verified desc, name);

create table if not exists public.content_artist_tags (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('post', 'story', 'drop', 'fancam')),
  content_id uuid not null,
  entity_id uuid not null references public.kpop_entities(id) on delete cascade,
  tagged_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (content_type, content_id, entity_id)
);

create index if not exists content_artist_tags_content_idx
  on public.content_artist_tags (content_type, content_id);

create index if not exists content_artist_tags_entity_idx
  on public.content_artist_tags (entity_id, created_at desc);

create index if not exists content_artist_tags_tagged_by_idx
  on public.content_artist_tags (tagged_by, created_at desc);

create index if not exists content_artist_tags_feed_idx
  on public.content_artist_tags (content_type, entity_id, content_id);

create table if not exists public.kpop_entity_follows (
  entity_id uuid not null references public.kpop_entities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (entity_id, user_id)
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_check check (blocker_id <> blocked_id)
);

create index if not exists posts_home_feed_published_idx
  on public.posts (status, deleted_at, created_at desc);

create index if not exists posts_home_feed_author_idx
  on public.posts (author_id, status, deleted_at, created_at desc);

create index if not exists follows_follower_following_idx
  on public.follows (follower_id, following_id);

create index if not exists kpop_entity_follows_user_entity_idx
  on public.kpop_entity_follows (user_id, entity_id);

create index if not exists kpop_entity_follows_entity_user_idx
  on public.kpop_entity_follows (entity_id, user_id);

create index if not exists user_blocks_blocker_blocked_idx
  on public.user_blocks (blocker_id, blocked_id);

create index if not exists user_blocks_blocked_blocker_idx
  on public.user_blocks (blocked_id, blocker_id);

alter table public.kpop_entities enable row level security;
alter table public.content_artist_tags enable row level security;
alter table public.kpop_entity_follows enable row level security;
alter table public.user_blocks enable row level security;

create or replace function public.is_admin_or_moderator(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = user_id
      and lower(coalesce(p.role, 'user')) in ('admin', 'moderator')
  );
$$;

create or replace function public.can_view_profile_content(owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    owner_id = auth.uid()
    or public.is_admin_or_moderator(auth.uid())
    or coalesce((
      select not p.private_profile
      from public.profiles p
      where p.id = owner_id
    ), true)
    or exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = owner_id
    );
$$;

grant execute on function public.is_admin_or_moderator(uuid) to authenticated;
grant execute on function public.can_view_profile_content(uuid) to authenticated;

drop policy if exists "kpop entities public read" on public.kpop_entities;
create policy "kpop entities public read"
on public.kpop_entities
for select
using (true);

drop policy if exists "content_artist_tags_select_visible" on public.content_artist_tags;
create policy "content_artist_tags_select_visible"
on public.content_artist_tags
for select
to authenticated
using (
  (
    content_type = 'post'
    and exists (
      select 1
      from public.posts p
      where p.id = content_artist_tags.content_id
        and p.status = 'published'
        and p.deleted_at is null
        and public.can_view_profile_content(p.author_id)
    )
  )
  or (
    content_type = 'story'
    and exists (
      select 1
      from public.stories s
      where s.id = content_artist_tags.content_id
        and s.expires_at > now()
        and public.can_view_profile_content(s.author_id)
    )
  )
  or (
    content_type = 'drop'
    and exists (
      select 1
      from public.drops d
      where d.id = content_artist_tags.content_id
        and d.status = 'published'
        and d.deleted_at is null
        and public.can_view_profile_content(d.author_id)
    )
  )
  or (
    content_type = 'fancam'
    and exists (
      select 1
      from public.fancams f
      where f.id = content_artist_tags.content_id
        and f.status = 'published'
        and f.deleted_at is null
        and public.can_view_profile_content(f.author_id)
    )
  )
);

drop policy if exists "content_artist_tags_insert_own_content" on public.content_artist_tags;
create policy "content_artist_tags_insert_own_content"
on public.content_artist_tags
for insert
to authenticated
with check (
  tagged_by = (select auth.uid())
  and exists (
    select 1
    from public.kpop_entities e
    where e.id = content_artist_tags.entity_id
  )
  and (
    (
      content_type = 'post'
      and exists (
        select 1
        from public.posts p
        where p.id = content_artist_tags.content_id
          and p.author_id = (select auth.uid())
      )
    )
    or (
      content_type = 'story'
      and exists (
        select 1
        from public.stories s
        where s.id = content_artist_tags.content_id
          and s.author_id = (select auth.uid())
      )
    )
    or (
      content_type = 'drop'
      and exists (
        select 1
        from public.drops d
        where d.id = content_artist_tags.content_id
          and d.author_id = (select auth.uid())
      )
    )
    or (
      content_type = 'fancam'
      and exists (
        select 1
        from public.fancams f
        where f.id = content_artist_tags.content_id
          and f.author_id = (select auth.uid())
      )
    )
  )
);

drop policy if exists "content_artist_tags_delete_own_tags" on public.content_artist_tags;
create policy "content_artist_tags_delete_own_tags"
on public.content_artist_tags
for delete
to authenticated
using (tagged_by = (select auth.uid()));

drop policy if exists "kpop entity follows public read" on public.kpop_entity_follows;
drop policy if exists "kpop entity follows own read" on public.kpop_entity_follows;
create policy "kpop entity follows own read"
on public.kpop_entity_follows
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "kpop entity follows self insert" on public.kpop_entity_follows;
create policy "kpop entity follows self insert"
on public.kpop_entity_follows
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "kpop entity follows self delete" on public.kpop_entity_follows;
create policy "kpop entity follows self delete"
on public.kpop_entity_follows
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "user blocks read own edges" on public.user_blocks;
create policy "user blocks read own edges"
on public.user_blocks
for select
to authenticated
using (
  (select auth.uid()) = blocker_id
  or (select auth.uid()) = blocked_id
);

drop policy if exists "user blocks insert own" on public.user_blocks;
create policy "user blocks insert own"
on public.user_blocks
for insert
to authenticated
with check (
  (select auth.uid()) = blocker_id
  and blocker_id <> blocked_id
);

drop policy if exists "user blocks delete own" on public.user_blocks;
create policy "user blocks delete own"
on public.user_blocks
for delete
to authenticated
using ((select auth.uid()) = blocker_id);

revoke all on public.content_artist_tags from anon;
revoke all on public.content_artist_tags from authenticated;
grant select, insert, delete on public.content_artist_tags to authenticated;

revoke all on public.kpop_entity_follows from anon;
revoke all on public.kpop_entity_follows from authenticated;
grant select, insert, delete on public.kpop_entity_follows to authenticated;

revoke all on public.user_blocks from anon;
revoke all on public.user_blocks from authenticated;
grant select, insert, delete on public.user_blocks to authenticated;

grant select on public.kpop_entities to anon, authenticated;

create or replace function public.get_home_feed(
  limit_count integer default 12,
  offset_count integer default 0
)
returns table (
  post_id uuid,
  source_rank integer,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with viewer as (
    select auth.uid() as viewer_id
  ),
  followed_users as (
    select f.following_id
    from public.follows f
    join viewer v on v.viewer_id = f.follower_id
  ),
  followed_entities as (
    select kef.entity_id
    from public.kpop_entity_follows kef
    join viewer v on v.viewer_id = kef.user_id
  ),
  eligible_posts as (
    select
      p.id as post_id,
      p.created_at as post_created_at,
      case
        when p.author_id = v.viewer_id then 0
        when exists (
          select 1
          from followed_users fu
          where fu.following_id = p.author_id
        ) then 1
        when exists (
          select 1
          from public.content_artist_tags cat
          join followed_entities fe
            on fe.entity_id = cat.entity_id
          where cat.content_type = 'post'
            and cat.content_id = p.id
        ) then 2
        else 9
      end as source_rank
    from public.posts p
    cross join viewer v
    where v.viewer_id is not null
      and p.status = 'published'
      and p.deleted_at is null
      and public.can_view_profile_content(p.author_id)
      and not exists (
        select 1
        from public.user_blocks ub
        where (
          ub.blocker_id = v.viewer_id
          and ub.blocked_id = p.author_id
        )
        or (
          ub.blocker_id = p.author_id
          and ub.blocked_id = v.viewer_id
        )
      )
      and (
        p.author_id = v.viewer_id
        or exists (
          select 1
          from followed_users fu
          where fu.following_id = p.author_id
        )
        or exists (
          select 1
          from public.content_artist_tags cat
          join followed_entities fe
            on fe.entity_id = cat.entity_id
          where cat.content_type = 'post'
            and cat.content_id = p.id
        )
      )
  )
  select
    ep.post_id,
    ep.source_rank,
    ep.post_created_at as created_at
  from eligible_posts ep
  order by ep.post_created_at desc, ep.source_rank asc
  limit least(greatest(coalesce(limit_count, 12), 1), 50)
  offset greatest(coalesce(offset_count, 0), 0);
$$;

grant execute on function public.get_home_feed(integer, integer) to authenticated;

notify pgrst, 'reload schema';
