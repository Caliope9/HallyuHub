-- HallyuHub Beta Real - performance indexes v1
-- Safe migration: creates indexes only when the target tables/columns exist.
-- No data is deleted or modified.

do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'posts' and column_name = 'author_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'posts' and column_name = 'created_at') then
    create index if not exists posts_author_created_idx on public.posts (author_id, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'posts' and column_name = 'status')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'posts' and column_name = 'created_at') then
    create index if not exists posts_status_created_idx on public.posts (status, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'post_media' and column_name = 'post_id') then
    create index if not exists post_media_post_id_idx on public.post_media (post_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'comments' and column_name = 'content_type')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'comments' and column_name = 'content_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'comments' and column_name = 'created_at') then
    create index if not exists comments_content_created_idx on public.comments (content_type, content_id, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drops' and column_name = 'author_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drops' and column_name = 'created_at') then
    create index if not exists drops_author_created_idx on public.drops (author_id, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drops' and column_name = 'status')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drops' and column_name = 'deleted_at')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drops' and column_name = 'created_at') then
    create index if not exists drops_status_deleted_created_idx on public.drops (status, deleted_at, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancams' and column_name = 'author_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancams' and column_name = 'created_at') then
    create index if not exists fancams_author_created_idx on public.fancams (author_id, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancams' and column_name = 'status')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancams' and column_name = 'deleted_at')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancams' and column_name = 'created_at') then
    create index if not exists fancams_status_deleted_created_idx on public.fancams (status, deleted_at, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'stories' and column_name = 'author_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'stories' and column_name = 'expires_at') then
    create index if not exists stories_author_expires_idx on public.stories (author_id, expires_at);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'story_media' and column_name = 'story_id') then
    create index if not exists story_media_story_id_idx on public.story_media (story_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'story_views' and column_name = 'story_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'story_views' and column_name = 'user_id') then
    create index if not exists story_views_story_user_idx on public.story_views (story_id, user_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'follows' and column_name = 'follower_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'follows' and column_name = 'following_id') then
    create index if not exists follows_follower_following_idx on public.follows (follower_id, following_id);
    create index if not exists follows_following_idx on public.follows (following_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'post_likes' and column_name = 'post_id') then
    create index if not exists post_likes_post_id_idx on public.post_likes (post_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'post_saves' and column_name = 'post_id') then
    create index if not exists post_saves_post_id_idx on public.post_saves (post_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drop_likes' and column_name = 'drop_id') then
    create index if not exists drop_likes_drop_id_idx on public.drop_likes (drop_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drop_saves' and column_name = 'drop_id') then
    create index if not exists drop_saves_drop_id_idx on public.drop_saves (drop_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drop_comments' and column_name = 'drop_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'drop_comments' and column_name = 'created_at') then
    create index if not exists drop_comments_drop_created_idx on public.drop_comments (drop_id, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancam_likes' and column_name = 'fancam_id') then
    create index if not exists fancam_likes_fancam_id_idx on public.fancam_likes (fancam_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancam_saves' and column_name = 'fancam_id') then
    create index if not exists fancam_saves_fancam_id_idx on public.fancam_saves (fancam_id);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancam_comments' and column_name = 'fancam_id')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'fancam_comments' and column_name = 'created_at') then
    create index if not exists fancam_comments_fancam_created_idx on public.fancam_comments (fancam_id, created_at desc);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'beta_access' and column_name = 'status') then
    create index if not exists beta_access_status_idx on public.beta_access (status);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'username') then
    create index if not exists profiles_username_idx on public.profiles (username);
  end if;

  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'private_profile') then
    create index if not exists profiles_private_profile_idx on public.profiles (private_profile);
  end if;
end $$;
