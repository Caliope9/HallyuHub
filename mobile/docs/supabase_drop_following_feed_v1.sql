-- HallyuHub D1B - secure Drops following feed.
-- Prepare only. Requires the existing reposts infrastructure.

create or replace function public.hallyu_following_drops_v1(
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
  audio text,
  filter text,
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
set search_path = pg_catalog
as $$
  with viewer as (
    select auth.uid() as user_id
  ), eligible as (
    select
      d.*,
      author.id as profile_id,
      author.name as profile_name,
      author.username as profile_username,
      author.avatar_asset as profile_avatar_asset,
      author.avatar_url as profile_avatar_url,
      latest_repost.user_id as repost_user_id,
      latest_repost.username as repost_username,
      latest_repost.created_at as repost_created_at
    from public.drops d
    join public.profiles author on author.id = d.author_id
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
      where r.content_type = 'drop'
        and r.content_id = d.id
        and not public.hallyu_users_blocked_v1(v.user_id, r.user_id)
        and public.can_view_profile_content(r.user_id)
      order by r.created_at desc, r.id desc
      limit 1
    ) latest_repost on true
    where v.user_id is not null
      and d.status = 'published'
      and d.deleted_at is null
      and public.can_view_profile_content(d.author_id)
      and not public.hallyu_users_blocked_v1(v.user_id, d.author_id)
      and (
        exists (
          select 1
          from public.follows creator_follow
          where creator_follow.follower_id = v.user_id
            and creator_follow.following_id = d.author_id
        )
        or exists (
          select 1
          from public.kpop_entity_follows entity_follow
          where entity_follow.user_id = v.user_id
            and (
              entity_follow.entity_id::text = d.artist_id
              or entity_follow.entity_id::text = d.group_id
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
    e.audio,
    e.filter,
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
  order by greatest(e.created_at, coalesce(e.repost_created_at, e.created_at)) desc,
           e.created_at desc,
           e.id desc
  limit least(greatest(coalesce(p_limit, 24), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

alter function public.hallyu_following_drops_v1(integer, integer)
  owner to postgres;

revoke all
on function public.hallyu_following_drops_v1(integer, integer)
from public, anon, authenticated;

grant execute
on function public.hallyu_following_drops_v1(integer, integer)
to authenticated;
