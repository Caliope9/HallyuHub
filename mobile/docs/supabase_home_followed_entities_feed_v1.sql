-- HallyuHub Beta Real - Inicio/feed con usuarios seguidos y entidades K-pop seguidas.
-- Seguro para correr varias veces. No borra datos reales.

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

create index if not exists content_artist_tags_feed_idx
  on public.content_artist_tags (content_type, entity_id, content_id);

create index if not exists user_blocks_blocker_blocked_idx
  on public.user_blocks (blocker_id, blocked_id);

create index if not exists user_blocks_blocked_blocker_idx
  on public.user_blocks (blocked_id, blocker_id);

alter table public.kpop_entity_follows enable row level security;
alter table public.user_blocks enable row level security;

drop policy if exists "kpop entity follows public read" on public.kpop_entity_follows;
create policy "kpop entity follows public read"
on public.kpop_entity_follows
for select
using (true);

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
with check ((select auth.uid()) = blocker_id and blocker_id <> blocked_id);

drop policy if exists "user blocks delete own" on public.user_blocks;
create policy "user blocks delete own"
on public.user_blocks
for delete
to authenticated
using ((select auth.uid()) = blocker_id);

create or replace function public.is_admin_or_moderator(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles profiles
    where profiles.id = user_id
      and lower(coalesce(profiles.role, 'user')) in ('admin', 'moderator')
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
      select not profiles.private_profile
      from public.profiles profiles
      where profiles.id = owner_id
    ), true)
    or exists (
      select 1
      from public.follows follows
      where follows.follower_id = auth.uid()
        and follows.following_id = owner_id
    );
$$;

grant execute on function public.is_admin_or_moderator(uuid) to authenticated;
grant execute on function public.can_view_profile_content(uuid) to authenticated;

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
    select follows.following_id
    from public.follows follows
    join viewer on viewer.viewer_id = follows.follower_id
  ),
  followed_entities as (
    select kpop_entity_follows.entity_id
    from public.kpop_entity_follows kpop_entity_follows
    join viewer on viewer.viewer_id = kpop_entity_follows.user_id
  ),
  eligible_posts as (
    select
      posts.id as post_id,
      posts.created_at as post_created_at,
      case
        when posts.author_id = viewer.viewer_id then 0
        when exists (
          select 1
          from followed_users
          where followed_users.following_id = posts.author_id
        ) then 1
        when exists (
          select 1
          from public.content_artist_tags content_artist_tags
          join followed_entities
            on followed_entities.entity_id = content_artist_tags.entity_id
          where content_artist_tags.content_type = 'post'
            and content_artist_tags.content_id = posts.id
        ) then 2
        else 9
      end as source_rank
    from public.posts posts
    cross join viewer
    where viewer.viewer_id is not null
      and posts.status = 'published'
      and posts.deleted_at is null
      and public.can_view_profile_content(posts.author_id)
      and not exists (
        select 1
        from public.user_blocks user_blocks
        where (
          user_blocks.blocker_id = viewer.viewer_id
          and user_blocks.blocked_id = posts.author_id
        )
        or (
          user_blocks.blocker_id = posts.author_id
          and user_blocks.blocked_id = viewer.viewer_id
        )
      )
      and (
        posts.author_id = viewer.viewer_id
        or exists (
          select 1
          from followed_users
          where followed_users.following_id = posts.author_id
        )
        or exists (
          select 1
          from public.content_artist_tags content_artist_tags
          join followed_entities
            on followed_entities.entity_id = content_artist_tags.entity_id
          where content_artist_tags.content_type = 'post'
            and content_artist_tags.content_id = posts.id
        )
      )
  )
  select
    eligible_posts.post_id,
    eligible_posts.source_rank,
    eligible_posts.post_created_at as created_at
  from eligible_posts
  order by eligible_posts.post_created_at desc, eligible_posts.source_rank asc
  limit least(greatest(coalesce(limit_count, 12), 1), 50)
  offset greatest(coalesce(offset_count, 0), 0);
$$;

grant execute on function public.get_home_feed(integer, integer) to authenticated;

notify pgrst, 'reload schema';
