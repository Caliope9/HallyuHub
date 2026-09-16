-- HallyuHub Beta Real - deleted posts global filter v1
-- Safe to run again. Does not delete data, storage files, users, or content.
-- Purpose: posts with deleted_at set must be invisible everywhere.

alter table if exists public.profiles
  add column if not exists private_profile boolean not null default false,
  add column if not exists role text not null default 'user';

alter table if exists public.posts
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz;

alter table if exists public.comments
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz;

create index if not exists posts_visible_published_idx
  on public.posts (status, deleted_at, created_at desc);

create index if not exists posts_author_visible_published_idx
  on public.posts (author_id, status, deleted_at, created_at desc);

create index if not exists post_media_post_id_idx
  on public.post_media (post_id);

create index if not exists post_likes_post_id_idx
  on public.post_likes (post_id);

create index if not exists post_saves_post_id_idx
  on public.post_saves (post_id);

create index if not exists comments_post_visible_idx
  on public.comments (content_type, content_id, deleted_at, created_at);

alter table if exists public.posts enable row level security;
alter table if exists public.post_media enable row level security;
alter table if exists public.post_likes enable row level security;
alter table if exists public.post_saves enable row level security;
alter table if exists public.comments enable row level security;

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

create or replace function public.hallyu_can_moderate_or_own(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() = p_owner_id
    or public.is_admin_or_moderator(auth.uid());
$$;

create or replace function public.hallyu_can_read_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.posts posts
    where posts.id = p_post_id
      and posts.status = 'published'
      and posts.deleted_at is null
      and public.can_view_profile_content(posts.author_id)
  );
$$;

grant execute on function public.is_admin_or_moderator(uuid) to authenticated;
grant execute on function public.can_view_profile_content(uuid) to authenticated;
grant execute on function public.hallyu_can_moderate_or_own(uuid) to authenticated;
grant execute on function public.hallyu_can_read_post(uuid) to authenticated;

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
        'comments'
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
create policy "posts visible read"
on public.posts
for select
using (
  status = 'published'
  and deleted_at is null
  and public.can_view_profile_content(author_id)
);

drop policy if exists "post media public read" on public.post_media;
create policy "post media visible read"
on public.post_media
for select
using (public.hallyu_can_read_post(post_id));

drop policy if exists "post reactions public read" on public.post_likes;
create policy "post likes visible read"
on public.post_likes
for select
using (public.hallyu_can_read_post(post_id));

drop policy if exists "post saves public read" on public.post_saves;
create policy "post saves visible read"
on public.post_saves
for select
using (
  user_id = auth.uid()
  and public.hallyu_can_read_post(post_id)
);

drop policy if exists "comments public read" on public.comments;
create policy "comments visible read"
on public.comments
for select
using (
  deleted_at is null
  and (
    (
      content_type = 'post'
      and public.hallyu_can_read_post(content_id)
    )
    or (
      content_type = 'drop'
      and exists (
        select 1
        from public.drops drops
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
        from public.fancams fancams
        where fancams.id = public.comments.content_id
          and fancams.status = 'published'
          and fancams.deleted_at is null
          and public.can_view_profile_content(fancams.author_id)
      )
    )
  )
);

drop policy if exists "post likes self manage" on public.post_likes;
create policy "post likes self manage"
on public.post_likes
for all
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and public.hallyu_can_read_post(post_id)
);

drop policy if exists "post saves self manage" on public.post_saves;
create policy "post saves self manage"
on public.post_saves
for all
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and public.hallyu_can_read_post(post_id)
);

drop policy if exists "comments owner insert" on public.comments;
create policy "comments owner insert"
on public.comments
for insert
to authenticated
with check (
  author_id = auth.uid()
  and btrim(coalesce(body, '')) <> ''
  and char_length(body) <= 1000
  and (
    (
      content_type = 'post'
      and public.hallyu_can_read_post(content_id)
    )
    or (
      content_type = 'drop'
      and exists (
        select 1
        from public.drops drops
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
        from public.fancams fancams
        where fancams.id = public.comments.content_id
          and fancams.status = 'published'
          and fancams.deleted_at is null
          and public.can_view_profile_content(fancams.author_id)
      )
    )
  )
);

drop policy if exists "posts owner soft delete update" on public.posts;
create policy "posts owner soft delete update"
on public.posts
for update
to authenticated
using (public.hallyu_can_moderate_or_own(author_id))
with check (public.hallyu_can_moderate_or_own(author_id));

create or replace function public.delete_my_post(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesion para eliminar publicaciones.';
  end if;

  select posts.author_id
  into v_author_id
  from public.posts posts
  where posts.id = p_post_id;

  if v_author_id is null then
    raise exception 'No encontramos la publicacion.';
  end if;

  if not public.hallyu_can_moderate_or_own(v_author_id) then
    raise exception 'No tenes permiso para eliminar esta publicacion.';
  end if;

  update public.posts
  set deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  where id = p_post_id;
end;
$$;

grant execute on function public.delete_my_post(uuid) to authenticated;

notify pgrst, 'reload schema';
