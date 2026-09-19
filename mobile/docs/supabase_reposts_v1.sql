-- HallyuHub R1: isolated repost infrastructure.
-- Review/apply manually in Supabase. This file intentionally contains no
-- Story Audience, Home, Drops, or Android changes.

create table if not exists public.reposts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null
    check (content_type in ('post', 'drop', 'fancam')),
  content_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

create index if not exists reposts_content_idx
  on public.reposts(content_type, content_id, created_at desc);

create index if not exists reposts_user_created_idx
  on public.reposts(user_id, created_at desc);

alter table public.reposts enable row level security;

-- Reposts are intentionally not exposed as a writable Data API table. The
-- authenticated RPCs below are the only client entry points.
revoke all on table public.reposts from public, anon, authenticated;

create or replace function public.hallyu_repost_content_available_v1(
  p_content_type text,
  p_content_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  owner_id uuid;
  content_status text;
  content_deleted_at timestamptz;
begin
  if auth.uid() is null
     or p_content_id is null
     or p_content_type not in ('post', 'drop', 'fancam') then
    return false;
  end if;

  owner_id := public.hallyu_content_owner_v1(p_content_type, p_content_id);
  if owner_id is null
     or public.hallyu_users_blocked_v1(auth.uid(), owner_id)
     or not public.can_view_profile_content(owner_id) then
    return false;
  end if;

  if p_content_type = 'post' then
    select status, deleted_at
      into content_status, content_deleted_at
      from public.posts
     where id = p_content_id;
  elsif p_content_type = 'drop' then
    select status, deleted_at
      into content_status, content_deleted_at
      from public.drops
     where id = p_content_id;
  else
    select status, deleted_at
      into content_status, content_deleted_at
      from public.fancams
     where id = p_content_id;
  end if;

  return content_status = 'published' and content_deleted_at is null;
end;
$$;

create or replace function public.hallyu_create_repost_v1(
  p_content_type text,
  p_content_id uuid
)
returns public.reposts
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  result_row public.reposts;
begin
  if auth.uid() is null
     or not public.hallyu_repost_content_available_v1(
       p_content_type,
       p_content_id
     ) then
    raise exception 'content is not available for repost';
  end if;

  insert into public.reposts(user_id, content_type, content_id)
  values (auth.uid(), p_content_type, p_content_id)
  on conflict (user_id, content_type, content_id) do nothing
  returning * into result_row;

  if result_row.id is null then
    select *
      into result_row
      from public.reposts
     where user_id = auth.uid()
       and content_type = p_content_type
       and content_id = p_content_id;
  end if;

  return result_row;
end;
$$;

create or replace function public.hallyu_remove_repost_v1(
  p_content_type text,
  p_content_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null
     or p_content_type not in ('post', 'drop', 'fancam') then
    raise exception 'invalid repost request';
  end if;

  delete from public.reposts
   where user_id = auth.uid()
     and content_type = p_content_type
     and content_id = p_content_id;
end;
$$;

create or replace function public.hallyu_has_reposted_v1(
  p_content_type text,
  p_content_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null
     and p_content_type in ('post', 'drop', 'fancam')
     and exists (
       select 1
         from public.reposts
        where user_id = auth.uid()
          and content_type = p_content_type
          and content_id = p_content_id
     );
$$;

-- One row per Fancam. A followed creator/entity makes the original eligible;
-- a followed reposter makes the original eligible and supplies the latest
-- repost metadata. greatest(created_at, reposted_at) lets a new repost bring
-- an older Fancam back into Siguiendo without duplicating the Fancam.
create or replace function public.hallyu_following_fancams_v1(
  p_limit integer default 24,
  p_offset integer default 0
)
returns table (
  id uuid,
  author_id uuid,
  caption text,
  artist_name text,
  group_name text,
  group_id text,
  artist_id text,
  event_name text,
  song_name text,
  tags text[],
  audio text,
  location text,
  video_url text,
  storage_bucket text,
  storage_path text,
  duration_seconds integer,
  file_size integer,
  thumbnail_url text,
  created_at timestamptz,
  view_count bigint,
  profiles jsonb,
  reposted_by_user_id uuid,
  reposted_by_username text,
  reposted_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with viewer as (
    select auth.uid() as user_id
  ), eligible as (
    select
      f.*,
      author.id as profile_id,
      author.name as profile_name,
      author.username as profile_username,
      author.avatar_asset as profile_avatar_asset,
      author.avatar_url as profile_avatar_url,
      latest_repost.user_id as repost_user_id,
      latest_repost.username as repost_username,
      latest_repost.created_at as repost_created_at
    from public.fancams f
    join public.profiles author on author.id = f.author_id
    cross join viewer v
    left join lateral (
      select
        r.user_id,
        reposter.username,
        r.created_at
      from public.reposts r
      join public.follows followed_reposter
        on followed_reposter.following_id = r.user_id
       and followed_reposter.follower_id = v.user_id
      join public.profiles reposter on reposter.id = r.user_id
      where r.content_type = 'fancam'
        and r.content_id = f.id
        and not public.hallyu_users_blocked_v1(v.user_id, r.user_id)
        and public.can_view_profile_content(r.user_id)
      order by r.created_at desc
      limit 1
    ) latest_repost on true
    where v.user_id is not null
      and f.status = 'published'
      and f.deleted_at is null
      and public.can_view_profile_content(f.author_id)
      and not public.hallyu_users_blocked_v1(v.user_id, f.author_id)
      and (
        exists (
          select 1
            from public.follows creator_follow
           where creator_follow.follower_id = v.user_id
             and creator_follow.following_id = f.author_id
        )
        or exists (
          select 1
            from public.kpop_entity_follows entity_follow
           where entity_follow.user_id = v.user_id
             and (
               entity_follow.entity_id::text = f.artist_id
               or entity_follow.entity_id::text = f.group_id
             )
        )
        or latest_repost.user_id is not null
      )
  )
  select
    e.id,
    e.author_id,
    e.caption,
    e.artist_name,
    e.group_name,
    e.group_id,
    e.artist_id,
    e.event_name,
    e.song_name,
    e.tags,
    e.audio,
    e.location,
    e.video_url,
    e.storage_bucket,
    e.storage_path,
    e.duration_seconds,
    e.file_size,
    e.thumbnail_url,
    e.created_at,
    e.view_count,
    jsonb_build_object(
      'id', e.profile_id,
      'name', e.profile_name,
      'username', e.profile_username,
      'avatar_asset', e.profile_avatar_asset,
      'avatar_url', e.profile_avatar_url
    ),
    e.repost_user_id,
    e.repost_username,
    e.repost_created_at
  from eligible e
  order by greatest(e.created_at, e.repost_created_at) desc, e.created_at desc
  limit least(greatest(coalesce(p_limit, 24), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

alter function public.hallyu_repost_content_available_v1(text, uuid)
  owner to postgres;

alter function public.hallyu_create_repost_v1(text, uuid)
  owner to postgres;

alter function public.hallyu_remove_repost_v1(text, uuid)
  owner to postgres;

alter function public.hallyu_has_reposted_v1(text, uuid)
  owner to postgres;

alter function public.hallyu_following_fancams_v1(integer, integer)
  owner to postgres;

revoke all on function public.hallyu_repost_content_available_v1(text, uuid)
  from public, anon, authenticated;
revoke all on function public.hallyu_create_repost_v1(text, uuid)
  from public, anon, authenticated;
revoke all on function public.hallyu_remove_repost_v1(text, uuid)
  from public, anon, authenticated;
revoke all on function public.hallyu_has_reposted_v1(text, uuid)
  from public, anon, authenticated;
revoke all on function public.hallyu_following_fancams_v1(integer, integer)
  from public, anon, authenticated;

grant execute on function public.hallyu_create_repost_v1(text, uuid)
  to authenticated;
grant execute on function public.hallyu_remove_repost_v1(text, uuid)
  to authenticated;
grant execute on function public.hallyu_has_reposted_v1(text, uuid)
  to authenticated;
grant execute on function public.hallyu_following_fancams_v1(integer, integer)
  to authenticated;
