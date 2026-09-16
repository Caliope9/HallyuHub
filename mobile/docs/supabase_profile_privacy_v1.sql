-- HallyuHub Beta Real - profile privacy hardening
-- Safe to run again. Does not delete data.

alter table public.profiles
  add column if not exists private_profile boolean not null default false,
  add column if not exists role text not null default 'user';

create index if not exists profiles_private_profile_idx
  on public.profiles(private_profile);

create index if not exists follows_follower_following_idx
  on public.follows(follower_id, following_id);

create or replace function public.is_admin_or_moderator(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
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
      from public.profiles
      where profiles.id = owner_id
    ), true)
    or exists (
      select 1
      from public.follows
      where follows.follower_id = auth.uid()
        and follows.following_id = owner_id
    );
$$;

create or replace function public.can_view_story(
  story_author_id uuid,
  story_expires_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    story_author_id = auth.uid()
    or public.is_admin_or_moderator(auth.uid())
    or (
      story_expires_at > now()
      and public.can_view_profile_content(story_author_id)
    );
$$;

alter table if exists public.posts enable row level security;
alter table if exists public.post_media enable row level security;
alter table if exists public.post_likes enable row level security;
alter table if exists public.post_saves enable row level security;
alter table if exists public.comments enable row level security;
alter table if exists public.drops enable row level security;
alter table if exists public.drop_likes enable row level security;
alter table if exists public.drop_saves enable row level security;
alter table if exists public.drop_comments enable row level security;
alter table if exists public.fancams enable row level security;
alter table if exists public.fancam_likes enable row level security;
alter table if exists public.fancam_saves enable row level security;
alter table if exists public.fancam_comments enable row level security;
alter table if exists public.stories enable row level security;
alter table if exists public.story_media enable row level security;
alter table if exists public.story_views enable row level security;
alter table if exists public.story_likes enable row level security;

do $$
declare
  policy_row record;
begin
  for policy_row in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = any(array[
        'posts',
        'post_media',
        'post_likes',
        'post_saves',
        'comments',
        'drops',
        'drop_likes',
        'drop_saves',
        'drop_comments',
        'fancams',
        'fancam_likes',
        'fancam_saves',
        'fancam_comments',
        'stories',
        'story_media',
        'story_views',
        'story_likes'
      ])
      and cmd = 'SELECT'
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename
    );
  end loop;
end $$;

drop policy if exists "posts public read" on public.posts;
create policy "posts public read" on public.posts
for select using (
  status = 'published'
  and public.can_view_profile_content(author_id)
);

drop policy if exists "post media public read" on public.post_media;
create policy "post media public read" on public.post_media
for select using (
  exists (
    select 1
    from public.posts
    where posts.id = public.post_media.post_id
      and posts.status = 'published'
      and public.can_view_profile_content(posts.author_id)
  )
);

drop policy if exists "post reactions public read" on public.post_likes;
create policy "post reactions public read" on public.post_likes
for select using (
  exists (
    select 1
    from public.posts
    where posts.id = public.post_likes.post_id
      and posts.status = 'published'
      and public.can_view_profile_content(posts.author_id)
  )
);

drop policy if exists "post saves public read" on public.post_saves;
create policy "post saves public read" on public.post_saves
for select using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.posts
    where posts.id = public.post_saves.post_id
      and posts.status = 'published'
      and public.can_view_profile_content(posts.author_id)
  )
);

drop policy if exists "post likes self manage" on public.post_likes;
create policy "post likes self manage" on public.post_likes
for all to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.posts
    where posts.id = public.post_likes.post_id
      and posts.status = 'published'
      and public.can_view_profile_content(posts.author_id)
  )
);

drop policy if exists "post saves self manage" on public.post_saves;
create policy "post saves self manage" on public.post_saves
for all to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.posts
    where posts.id = public.post_saves.post_id
      and posts.status = 'published'
      and public.can_view_profile_content(posts.author_id)
  )
);

drop policy if exists "comments public read" on public.comments;
create policy "comments public read" on public.comments
for select using (
  (
    content_type = 'post'
    and exists (
      select 1
      from public.posts
      where posts.id = public.comments.content_id
        and posts.status = 'published'
        and public.can_view_profile_content(posts.author_id)
    )
  )
  or (
    content_type = 'drop'
    and exists (
      select 1
      from public.drops
      where drops.id = public.comments.content_id
        and drops.status = 'published'
        and drops.deleted_at is null
        and public.can_view_profile_content(drops.author_id)
    )
  )
  or (
    content_type = 'fancam'
    and exists (
      select 1
      from public.fancams
      where fancams.id = public.comments.content_id
        and fancams.status = 'published'
        and fancams.deleted_at is null
        and public.can_view_profile_content(fancams.author_id)
    )
  )
);

drop policy if exists "comments owner insert" on public.comments;
create policy "comments owner insert" on public.comments
for insert to authenticated
with check (
  auth.uid() = author_id
  and (
    (
      content_type = 'post'
      and exists (
        select 1
        from public.posts
        where posts.id = public.comments.content_id
          and posts.status = 'published'
          and public.can_view_profile_content(posts.author_id)
      )
    )
    or (
      content_type = 'drop'
      and exists (
        select 1
        from public.drops
        where drops.id = public.comments.content_id
          and drops.status = 'published'
          and drops.deleted_at is null
          and public.can_view_profile_content(drops.author_id)
      )
    )
    or (
      content_type = 'fancam'
      and exists (
        select 1
        from public.fancams
        where fancams.id = public.comments.content_id
          and fancams.status = 'published'
          and fancams.deleted_at is null
          and public.can_view_profile_content(fancams.author_id)
      )
    )
  )
);

drop policy if exists "drops public read" on public.drops;
create policy "drops public read" on public.drops
for select using (
  status = 'published'
  and deleted_at is null
  and public.can_view_profile_content(author_id)
);

drop policy if exists "drop likes public read" on public.drop_likes;
create policy "drop likes public read" on public.drop_likes
for select using (
  exists (
    select 1
    from public.drops
    where drops.id = public.drop_likes.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
      and public.can_view_profile_content(drops.author_id)
  )
);

drop policy if exists "drop saves public read" on public.drop_saves;
create policy "drop saves public read" on public.drop_saves
for select using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.drops
    where drops.id = public.drop_saves.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
      and public.can_view_profile_content(drops.author_id)
  )
);

drop policy if exists "drop likes self manage" on public.drop_likes;
create policy "drop likes self manage" on public.drop_likes
for all to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.drops
    where drops.id = public.drop_likes.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
      and public.can_view_profile_content(drops.author_id)
  )
);

drop policy if exists "drop saves self manage" on public.drop_saves;
create policy "drop saves self manage" on public.drop_saves
for all to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.drops
    where drops.id = public.drop_saves.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
      and public.can_view_profile_content(drops.author_id)
  )
);

drop policy if exists "drop comments public read" on public.drop_comments;
create policy "drop comments public read" on public.drop_comments
for select using (
  exists (
    select 1
    from public.drops
    where drops.id = public.drop_comments.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
      and public.can_view_profile_content(drops.author_id)
  )
);

drop policy if exists "drop comments owner insert" on public.drop_comments;
create policy "drop comments owner insert" on public.drop_comments
for insert to authenticated
with check (
  auth.uid() = author_id
  and exists (
    select 1
    from public.drops
    where drops.id = public.drop_comments.drop_id
      and drops.status = 'published'
      and drops.deleted_at is null
      and public.can_view_profile_content(drops.author_id)
  )
);

drop policy if exists "fancams public read" on public.fancams;
create policy "fancams public read" on public.fancams
for select using (
  status = 'published'
  and deleted_at is null
  and public.can_view_profile_content(author_id)
);

drop policy if exists "fancam likes public read" on public.fancam_likes;
create policy "fancam likes public read" on public.fancam_likes
for select using (
  exists (
    select 1
    from public.fancams
    where fancams.id = public.fancam_likes.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
      and public.can_view_profile_content(fancams.author_id)
  )
);

drop policy if exists "fancam saves public read" on public.fancam_saves;
create policy "fancam saves public read" on public.fancam_saves
for select using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.fancams
    where fancams.id = public.fancam_saves.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
      and public.can_view_profile_content(fancams.author_id)
  )
);

drop policy if exists "fancam likes self manage" on public.fancam_likes;
create policy "fancam likes self manage" on public.fancam_likes
for all to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.fancams
    where fancams.id = public.fancam_likes.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
      and public.can_view_profile_content(fancams.author_id)
  )
);

drop policy if exists "fancam saves self manage" on public.fancam_saves;
create policy "fancam saves self manage" on public.fancam_saves
for all to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.fancams
    where fancams.id = public.fancam_saves.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
      and public.can_view_profile_content(fancams.author_id)
  )
);

drop policy if exists "fancam comments public read" on public.fancam_comments;
create policy "fancam comments public read" on public.fancam_comments
for select using (
  exists (
    select 1
    from public.fancams
    where fancams.id = public.fancam_comments.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
      and public.can_view_profile_content(fancams.author_id)
  )
);

drop policy if exists "fancam comments owner insert" on public.fancam_comments;
create policy "fancam comments owner insert" on public.fancam_comments
for insert to authenticated
with check (
  auth.uid() = author_id
  and exists (
    select 1
    from public.fancams
    where fancams.id = public.fancam_comments.fancam_id
      and fancams.status = 'published'
      and fancams.deleted_at is null
      and public.can_view_profile_content(fancams.author_id)
  )
);

drop policy if exists "stories public read" on public.stories;
drop policy if exists "stories own or followed active read" on public.stories;
create policy "stories private-aware active read" on public.stories
for select to authenticated
using (public.can_view_story(author_id, expires_at));

drop policy if exists "story media public read" on public.story_media;
drop policy if exists "story media own or followed read" on public.story_media;
create policy "story media private-aware read" on public.story_media
for select to authenticated
using (
  exists (
    select 1
    from public.stories
    where stories.id = public.story_media.story_id
      and public.can_view_story(stories.author_id, stories.expires_at)
  )
);

drop policy if exists "story views self manage" on public.story_views;
drop policy if exists "story views readable by viewer or author" on public.story_views;
create policy "story views private-aware read" on public.story_views
for select to authenticated
using (
  (
    viewer_id = auth.uid()
    and exists (
      select 1
      from public.stories
      where stories.id = public.story_views.story_id
        and public.can_view_story(stories.author_id, stories.expires_at)
    )
  )
  or exists (
    select 1
    from public.stories
    where stories.id = public.story_views.story_id
      and (
        stories.author_id = auth.uid()
        or public.is_admin_or_moderator(auth.uid())
      )
  )
);

drop policy if exists "story views owner insert" on public.story_views;
create policy "story views owner insert" on public.story_views
for insert to authenticated
with check (
  auth.uid() = viewer_id
  and exists (
    select 1
    from public.stories
    where stories.id = public.story_views.story_id
      and public.can_view_story(stories.author_id, stories.expires_at)
  )
);

drop policy if exists "story views owner update" on public.story_views;
create policy "story views owner update" on public.story_views
for update to authenticated
using (auth.uid() = viewer_id)
with check (
  auth.uid() = viewer_id
  and exists (
    select 1
    from public.stories
    where stories.id = public.story_views.story_id
      and public.can_view_story(stories.author_id, stories.expires_at)
  )
);

drop policy if exists "story likes self manage" on public.story_likes;
drop policy if exists "story likes readable by liker or author" on public.story_likes;
create policy "story likes private-aware read" on public.story_likes
for select to authenticated
using (
  (
    user_id = auth.uid()
    and exists (
      select 1
      from public.stories
      where stories.id = public.story_likes.story_id
        and public.can_view_story(stories.author_id, stories.expires_at)
    )
  )
  or exists (
    select 1
    from public.stories
    where stories.id = public.story_likes.story_id
      and (
        stories.author_id = auth.uid()
        or public.is_admin_or_moderator(auth.uid())
      )
  )
);

drop policy if exists "story likes owner insert" on public.story_likes;
create policy "story likes owner insert" on public.story_likes
for insert to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.stories
    where stories.id = public.story_likes.story_id
      and public.can_view_story(stories.author_id, stories.expires_at)
  )
);

drop policy if exists "story likes owner update" on public.story_likes;
create policy "story likes owner update" on public.story_likes
for update to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.stories
    where stories.id = public.story_likes.story_id
      and public.can_view_story(stories.author_id, stories.expires_at)
  )
);
