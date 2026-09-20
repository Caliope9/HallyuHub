-- HallyuHub O1A - Outfit feeds over existing Posts.
-- Prepare only. Do not apply remotely without explicit approval.

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.content_categories'::regclass
      and conname = 'content_categories_category_key_check'
  ) then
    alter table public.content_categories
      drop constraint content_categories_category_key_check;
  end if;

  alter table public.content_categories
    add constraint content_categories_category_key_check
    check (
      category_key in (
        'concerts',
        'bias',
        'photocards',
        'outfit',
        'outfit_stage',
        'outfit_airport',
        'outfit_casual',
        'collection',
        'trades',
        'merch',
        'fanart',
        'other'
      )
    );
end
$$;

create index if not exists content_categories_outfit_feed_idx
  on public.content_categories (content_type, category_key, created_at desc);

create or replace function public.hallyu_outfit_feed_v1(
  p_mode text default 'for_you',
  p_category text default 'all',
  p_limit integer default 24,
  p_offset integer default 0
)
returns table (
  id uuid,
  author_id uuid,
  caption text,
  location text,
  privacy text,
  artist_id text,
  music text,
  filter_index integer,
  tagged_people text[],
  tags text[],
  created_at timestamptz,
  category_key text,
  profiles jsonb,
  post_media jsonb,
  reposted_by_user_id uuid,
  reposted_by_username text,
  reposted_at timestamptz,
  likes_count bigint,
  saves_count bigint,
  comments_count bigint,
  repost_count bigint
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  with viewer as (
    select auth.uid() as user_id
  ),
  outfit_posts as (
    select cc.content_id, min(cc.category_key) as category_key
    from public.content_categories cc
    where cc.content_type = 'post'
      and (
        (coalesce(p_category, 'all') = 'all' and cc.category_key = 'outfit')
        or (
          p_category in ('stage', 'airport', 'casual')
          and cc.category_key = concat('outfit_', p_category)
          and exists (
            select 1
            from public.content_categories base_category
            where base_category.content_type = 'post'
              and base_category.content_id = cc.content_id
              and base_category.category_key = 'outfit'
          )
        )
      )
    group by cc.content_id
  ),
  followed_users as (
    select f.following_id
    from public.follows f
    join viewer v on v.user_id = f.follower_id
  ),
  followed_entities as (
    select kef.entity_id
    from public.kpop_entity_follows kef
    join viewer v on v.user_id = kef.user_id
  ),
  eligible as (
    select
      p.*,
      op.category_key,
      author.id as profile_id,
      author.name as profile_name,
      author.username as profile_username,
      author.avatar_asset as profile_avatar_asset,
      author.avatar_url as profile_avatar_url,
      latest_repost.user_id as repost_user_id,
      latest_repost.username as repost_username,
      latest_repost.created_at as repost_created_at,
      like_stats.total as likes_total,
      save_stats.total as saves_total,
      comment_stats.total as comments_total,
      repost_stats.total as reposts_total,
      case
        when p.author_id = v.user_id then 0
        when exists (
          select 1
          from followed_users fu
          where fu.following_id = p.author_id
        ) then 1
        when exists (
          select 1
          from public.content_artist_tags cat
          join followed_entities fe on fe.entity_id = cat.entity_id
          where cat.content_type = 'post'
            and cat.content_id = p.id
        ) then 2
        else 9
      end as source_rank
    from public.posts p
    join outfit_posts op on op.content_id = p.id
    join public.profiles author on author.id = p.author_id
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
      where r.content_type = 'post'
        and r.content_id = p.id
        and not public.hallyu_users_blocked_v1(v.user_id, r.user_id)
        and public.can_view_profile_content(r.user_id)
      order by r.created_at desc, r.id desc
      limit 1
    ) latest_repost on true
    left join lateral (
      select count(*)::bigint as total
      from public.post_likes pl
      where pl.post_id = p.id
    ) like_stats on true
    left join lateral (
      select count(*)::bigint as total
      from public.post_saves ps
      where ps.post_id = p.id
    ) save_stats on true
    left join lateral (
      select count(*)::bigint as total
      from public.comments c
      where c.content_type = 'post'
        and c.content_id = p.id
        and c.deleted_at is null
    ) comment_stats on true
    left join lateral (
      select count(*)::bigint as total
      from public.reposts rr
      where rr.content_type = 'post'
        and rr.content_id = p.id
    ) repost_stats on true
    where v.user_id is not null
      and p.status = 'published'
      and p.deleted_at is null
      and public.can_view_profile_content(p.author_id)
      and not public.hallyu_users_blocked_v1(v.user_id, p.author_id)
      and coalesce(p_mode, 'for_you') in ('for_you', 'popular', 'following')
      and (
        coalesce(p_mode, 'for_you') <> 'following'
        or exists (
          select 1
          from followed_users fu
          where fu.following_id = p.author_id
        )
        or exists (
          select 1
          from public.content_artist_tags cat
          join followed_entities fe on fe.entity_id = cat.entity_id
          where cat.content_type = 'post'
            and cat.content_id = p.id
        )
        or latest_repost.user_id is not null
      )
  )
  select
    e.id,
    e.author_id,
    e.caption,
    e.location,
    e.privacy,
    e.artist_id,
    e.music,
    e.filter_index,
    e.tagged_people,
    e.tags,
    e.created_at,
    e.category_key,
    jsonb_build_object(
      'id', e.profile_id,
      'name', e.profile_name,
      'username', e.profile_username,
      'avatar_asset', e.profile_avatar_asset,
      'avatar_url', e.profile_avatar_url
    ),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', pm.id,
          'media_type', pm.media_type,
          'storage_bucket', pm.storage_bucket,
          'storage_path', pm.storage_path,
          'public_url', pm.public_url,
          'sort_order', pm.sort_order,
          'transform', pm.transform
        ) order by pm.sort_order
      )
      from public.post_media pm
      where pm.post_id = e.id
    ), '[]'::jsonb),
    e.repost_user_id,
    e.repost_username,
    e.repost_created_at,
    e.likes_total,
    e.saves_total,
    e.comments_total,
    e.reposts_total
  from eligible e
  order by
    case when coalesce(p_mode, 'for_you') = 'popular'
      then e.likes_total + e.saves_total + e.comments_total + e.reposts_total
      else 0
    end desc,
    case when coalesce(p_mode, 'for_you') = 'following'
      then greatest(e.created_at, coalesce(e.repost_created_at, e.created_at))
      else e.created_at
    end desc,
    case when coalesce(p_mode, 'for_you') = 'for_you'
      then e.source_rank
      else 0
    end asc,
    case when coalesce(p_mode, 'for_you') = 'for_you'
      then e.likes_total + e.saves_total + e.comments_total + e.reposts_total
      else 0
    end desc,
    e.created_at desc,
    e.id desc
  limit least(greatest(coalesce(p_limit, 24), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

alter function public.hallyu_outfit_feed_v1(text, text, integer, integer)
  owner to postgres;

revoke all
on function public.hallyu_outfit_feed_v1(text, text, integer, integer)
from public, anon, authenticated;

grant execute
on function public.hallyu_outfit_feed_v1(text, text, integer, integer)
to authenticated;
