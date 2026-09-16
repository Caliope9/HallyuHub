-- HallyuHub Beta Real - Delete own content v1.
-- Safe to run more than once.
-- Soft delete only: no DROP TABLE, no TRUNCATE, no DELETE FROM, no storage cleanup.

alter table if exists public.posts
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.drops
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.fancams
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.stories
  add column if not exists deleted_at timestamptz,
  add column if not exists archived_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.comments
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.drop_comments
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.fancam_comments
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists posts_deleted_created_idx
  on public.posts (deleted_at, created_at desc);

create index if not exists posts_author_deleted_created_idx
  on public.posts (author_id, deleted_at, created_at desc);

create index if not exists comments_content_deleted_created_idx
  on public.comments (content_type, content_id, deleted_at, created_at);

create index if not exists drops_deleted_created_idx
  on public.drops (deleted_at, created_at desc);

create index if not exists drops_author_deleted_created_idx
  on public.drops (author_id, deleted_at, created_at desc);

create index if not exists drop_comments_deleted_created_idx
  on public.drop_comments (drop_id, deleted_at, created_at);

create index if not exists fancams_deleted_created_idx
  on public.fancams (deleted_at, created_at desc);

create index if not exists fancams_author_deleted_created_idx
  on public.fancams (author_id, deleted_at, created_at desc);

create index if not exists fancam_comments_deleted_created_idx
  on public.fancam_comments (fancam_id, deleted_at, created_at);

create index if not exists stories_author_deleted_expires_idx
  on public.stories (author_id, deleted_at, expires_at desc);

alter table if exists public.posts enable row level security;
alter table if exists public.post_media enable row level security;
alter table if exists public.comments enable row level security;
alter table if exists public.drops enable row level security;
alter table if exists public.drop_comments enable row level security;
alter table if exists public.fancams enable row level security;
alter table if exists public.fancam_comments enable row level security;
alter table if exists public.stories enable row level security;
alter table if exists public.story_media enable row level security;

create or replace function public.hallyu_can_moderate_or_own(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() = p_owner_id
    or exists (
      select 1
      from public.profiles profiles
      where profiles.id = auth.uid()
        and lower(coalesce(profiles.role, 'user')) in ('admin', 'moderator')
    );
$$;

grant execute on function public.hallyu_can_moderate_or_own(uuid)
to authenticated;

drop policy if exists "posts owner soft delete update" on public.posts;
create policy "posts owner soft delete update"
on public.posts
for update
to authenticated
using (public.hallyu_can_moderate_or_own(author_id))
with check (public.hallyu_can_moderate_or_own(author_id));

drop policy if exists "comments owner soft delete update" on public.comments;
create policy "comments owner soft delete update"
on public.comments
for update
to authenticated
using (public.hallyu_can_moderate_or_own(author_id))
with check (public.hallyu_can_moderate_or_own(author_id));

drop policy if exists "drops owner soft delete update" on public.drops;
create policy "drops owner soft delete update"
on public.drops
for update
to authenticated
using (public.hallyu_can_moderate_or_own(author_id))
with check (public.hallyu_can_moderate_or_own(author_id));

drop policy if exists "drop comments owner soft delete update" on public.drop_comments;
create policy "drop comments owner soft delete update"
on public.drop_comments
for update
to authenticated
using (public.hallyu_can_moderate_or_own(author_id))
with check (public.hallyu_can_moderate_or_own(author_id));

drop policy if exists "fancams owner soft delete update" on public.fancams;
create policy "fancams owner soft delete update"
on public.fancams
for update
to authenticated
using (public.hallyu_can_moderate_or_own(author_id))
with check (public.hallyu_can_moderate_or_own(author_id));

drop policy if exists "fancam comments owner soft delete update" on public.fancam_comments;
create policy "fancam comments owner soft delete update"
on public.fancam_comments
for update
to authenticated
using (public.hallyu_can_moderate_or_own(author_id))
with check (public.hallyu_can_moderate_or_own(author_id));

drop policy if exists "stories owner soft delete update" on public.stories;
create policy "stories owner soft delete update"
on public.stories
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
  where posts.id = p_post_id
    and posts.deleted_at is null;

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

create or replace function public.delete_my_drop(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesion para eliminar Drops.';
  end if;

  select drops.author_id
  into v_author_id
  from public.drops drops
  where drops.id = p_drop_id
    and drops.deleted_at is null;

  if v_author_id is null then
    raise exception 'No encontramos el Drop.';
  end if;

  if not public.hallyu_can_moderate_or_own(v_author_id) then
    raise exception 'No tenes permiso para eliminar este Drop.';
  end if;

  update public.drops
  set deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  where id = p_drop_id;
end;
$$;

create or replace function public.delete_my_fancam(p_fancam_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesion para eliminar Fancams.';
  end if;

  select fancams.author_id
  into v_author_id
  from public.fancams fancams
  where fancams.id = p_fancam_id
    and fancams.deleted_at is null;

  if v_author_id is null then
    raise exception 'No encontramos la Fancam.';
  end if;

  if not public.hallyu_can_moderate_or_own(v_author_id) then
    raise exception 'No tenes permiso para eliminar esta Fancam.';
  end if;

  update public.fancams
  set deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  where id = p_fancam_id;
end;
$$;

create or replace function public.delete_my_story(p_story_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesion para eliminar historias.';
  end if;

  select stories.author_id
  into v_author_id
  from public.stories stories
  where stories.id = p_story_id
    and stories.deleted_at is null;

  if v_author_id is null then
    raise exception 'No encontramos la historia.';
  end if;

  if not public.hallyu_can_moderate_or_own(v_author_id) then
    raise exception 'No tenes permiso para eliminar esta historia.';
  end if;

  update public.stories
  set deleted_at = coalesce(deleted_at, now()),
      archived_at = coalesce(archived_at, now()),
      expires_at = coalesce(least(expires_at, now()), now()),
      updated_at = now()
  where id = p_story_id;
end;
$$;

create or replace function public.delete_my_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesion para borrar comentarios.';
  end if;

  select comments.author_id
  into v_author_id
  from public.comments comments
  where comments.id = p_comment_id
    and comments.deleted_at is null;

  if v_author_id is null then
    raise exception 'No encontramos el comentario.';
  end if;

  if not public.hallyu_can_moderate_or_own(v_author_id) then
    raise exception 'No tenes permiso para borrar este comentario.';
  end if;

  update public.comments
  set deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  where id = p_comment_id;
end;
$$;

create or replace function public.delete_my_drop_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesion para borrar comentarios.';
  end if;

  select drop_comments.author_id
  into v_author_id
  from public.drop_comments drop_comments
  where drop_comments.id = p_comment_id
    and drop_comments.deleted_at is null;

  if v_author_id is null then
    raise exception 'No encontramos el comentario.';
  end if;

  if not public.hallyu_can_moderate_or_own(v_author_id) then
    raise exception 'No tenes permiso para borrar este comentario.';
  end if;

  update public.drop_comments
  set deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  where id = p_comment_id;
end;
$$;

create or replace function public.delete_my_fancam_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesion para borrar comentarios.';
  end if;

  select fancam_comments.author_id
  into v_author_id
  from public.fancam_comments fancam_comments
  where fancam_comments.id = p_comment_id
    and fancam_comments.deleted_at is null;

  if v_author_id is null then
    raise exception 'No encontramos el comentario.';
  end if;

  if not public.hallyu_can_moderate_or_own(v_author_id) then
    raise exception 'No tenes permiso para borrar este comentario.';
  end if;

  update public.fancam_comments
  set deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  where id = p_comment_id;
end;
$$;

grant execute on function public.delete_my_post(uuid) to authenticated;
grant execute on function public.delete_my_drop(uuid) to authenticated;
grant execute on function public.delete_my_fancam(uuid) to authenticated;
grant execute on function public.delete_my_story(uuid) to authenticated;
grant execute on function public.delete_my_comment(uuid) to authenticated;
grant execute on function public.delete_my_drop_comment(uuid) to authenticated;
grant execute on function public.delete_my_fancam_comment(uuid) to authenticated;
