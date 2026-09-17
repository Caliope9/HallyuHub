-- HallyuHub — story audience + social reposts v1
-- REVIEW ONLY. Do not execute automatically.
-- This migration is intentionally additive. It does not copy media, delete
-- content, or weaken existing RLS. Review against the deployed schema first.

begin;
set local search_path = pg_catalog, public;

do $$
begin
  if to_regclass('public.stories') is null then
    raise exception 'Missing public.stories';
  end if;
  if to_regclass('public.profiles') is null then
    raise exception 'Missing public.profiles';
  end if;
  if to_regclass('public.follows') is null then
    raise exception 'Missing public.follows';
  end if;
  if to_regclass('public.story_media') is null then
    raise exception 'Missing public.story_media';
  end if;
  if to_regprocedure('public.hallyu_users_blocked_v1(uuid,uuid)') is null then
    raise exception 'Missing public.hallyu_users_blocked_v1(uuid,uuid); apply block hardening first';
  end if;
  if to_regprocedure('public.can_view_profile_content(uuid)') is null then
    raise exception 'Missing public.can_view_profile_content(uuid)';
  end if;
end;
$$;

do $$
declare
  required_column record;
begin
  for required_column in
    select * from (values
      ('stories', 'id'), ('stories', 'author_id'), ('stories', 'expires_at'),
      ('stories', 'deleted_at'), ('stories', 'updated_at'),
      ('profiles', 'id'), ('profiles', 'private_profile'),
      ('profiles', 'story_privacy'),
      ('follows', 'follower_id'), ('follows', 'following_id')
    ) as columns(table_name, column_name)
  loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = required_column.table_name
        and column_name = required_column.column_name
    ) then
      raise exception 'Missing required column public.%.%',
        required_column.table_name, required_column.column_name;
    end if;
  end loop;
end;
$$;

alter table public.stories
  add column if not exists audience_type text not null default 'followers',
  add column if not exists shared_content_type text,
  add column if not exists shared_content_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.stories'::regclass
      and conname = 'stories_audience_type_v1_check'
  ) then
    alter table public.stories add constraint stories_audience_type_v1_check
      check (audience_type in ('public', 'followers', 'close_friends', 'exclude', 'include'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.stories'::regclass
      and conname = 'stories_shared_content_type_v1_check'
  ) then
    alter table public.stories add constraint stories_shared_content_type_v1_check
      check (shared_content_type is null or shared_content_type in ('post', 'drop', 'fancam'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.stories'::regclass
      and conname = 'stories_shared_content_pair_v1_check'
  ) then
    alter table public.stories add constraint stories_shared_content_pair_v1_check
      check ((shared_content_type is null and shared_content_id is null)
          or (shared_content_type is not null and shared_content_id is not null));
  end if;
end;
$$;

create table if not exists public.story_audience_users (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

create table if not exists public.close_friends (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, friend_id),
  check (owner_id <> friend_id)
);

create index if not exists story_audience_users_user_idx
  on public.story_audience_users(user_id, story_id);
create index if not exists close_friends_friend_idx
  on public.close_friends(friend_id, owner_id);

create or replace function public.hallyu_story_visible_v1(p_story_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  story_row record;
  viewer uuid := auth.uid();
begin
  if viewer is null then return false; end if;
  select s.id, s.author_id, s.audience_type, s.expires_at,
         s.deleted_at, s.shared_content_type, s.shared_content_id,
         p.private_profile, p.story_privacy
    into story_row
    from public.stories s
    join public.profiles p on p.id = s.author_id
   where s.id = p_story_id;
  if not found or story_row.deleted_at is not null
     or story_row.expires_at <= now() then return false; end if;
  if story_row.author_id = viewer then return true; end if;
  if public.hallyu_users_blocked_v1(viewer, story_row.author_id) then return false; end if;
  if story_row.private_profile and not exists (
    select 1 from public.follows f
     where f.follower_id = viewer and f.following_id = story_row.author_id
  ) then return false; end if;
  if story_row.audience_type = 'public' then return true; end if;
  if story_row.audience_type = 'followers' then
    return exists (
      select 1 from public.follows f
       where f.follower_id = viewer and f.following_id = story_row.author_id
    );
  end if;
  if story_row.audience_type = 'close_friends' then
    return exists (
      select 1 from public.close_friends cf
       where cf.owner_id = story_row.author_id and cf.friend_id = viewer
    );
  end if;
  if story_row.audience_type = 'exclude' then
    return not exists (
      select 1 from public.story_audience_users au
       where au.story_id = p_story_id and au.user_id = viewer
    );
  end if;
  if story_row.audience_type = 'include' then
    return exists (
      select 1 from public.story_audience_users au
       where au.story_id = p_story_id and au.user_id = viewer
    );
  end if;
  return false;
end;
$$;

revoke all on function public.hallyu_story_visible_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.hallyu_story_visible_v1(uuid) to authenticated;

alter table public.story_audience_users enable row level security;
alter table public.close_friends enable row level security;
revoke all on table public.story_audience_users from public, anon, authenticated;
revoke all on table public.close_friends from public, anon, authenticated;
grant select, insert, delete on table public.story_audience_users to authenticated;
grant select, insert, update, delete on table public.close_friends to authenticated;

drop policy if exists "story audience owner manage" on public.story_audience_users;
create policy "story audience owner manage" on public.story_audience_users
  for all to authenticated
  using (exists (
    select 1 from public.stories s
     where s.id = story_id and s.author_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.stories s
     where s.id = story_id and s.author_id = auth.uid()
  ));

drop policy if exists "close friends owner manage" on public.close_friends;
create policy "close friends owner manage" on public.close_friends
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid() and friend_id <> auth.uid());

drop policy if exists "story audience visible stories" on public.stories;
create policy "story audience visible stories" on public.stories as restrictive
  for select to authenticated using (public.hallyu_story_visible_v1(id));

drop policy if exists "story audience visible media" on public.story_media;
create policy "story audience visible media" on public.story_media as restrictive
  for select to authenticated using (
    exists (select 1 from public.stories s
      where s.id = story_id and public.hallyu_story_visible_v1(s.id))
  );

create table if not exists public.reposts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (content_type in ('post', 'drop', 'fancam')),
  content_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

create index if not exists reposts_content_idx
  on public.reposts(content_type, content_id, created_at desc);

create or replace function public.hallyu_repost_content_available_v1(
  p_content_type text, p_content_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare owner_id uuid;
declare hidden boolean := false;
begin
  owner_id := public.hallyu_content_owner_v1(p_content_type, p_content_id);
  if owner_id is null or auth.uid() is null then return false; end if;
  if public.hallyu_users_blocked_v1(auth.uid(), owner_id) then return false; end if;
  if p_content_type = 'post' then
    select (deleted_at is not null or status = 'deleted') into hidden
      from public.posts where id = p_content_id;
  elsif p_content_type = 'drop' then
    select (deleted_at is not null or status = 'deleted') into hidden
      from public.drops where id = p_content_id;
  elsif p_content_type = 'fancam' then
    select (deleted_at is not null or status = 'deleted') into hidden
      from public.fancams where id = p_content_id;
  else
    return false;
  end if;
  return not coalesce(hidden, true)
    and public.can_view_profile_content(owner_id);
end;
$$;

create or replace function public.hallyu_create_repost_v1(
  p_content_type text, p_content_id uuid
)
returns public.reposts
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare result_row public.reposts;
begin
  if auth.uid() is null or p_content_type not in ('post', 'drop', 'fancam')
     or not public.hallyu_repost_content_available_v1(p_content_type, p_content_id) then
    raise exception 'content is not available for repost';
  end if;
  insert into public.reposts(user_id, content_type, content_id)
  values (auth.uid(), p_content_type, p_content_id)
  on conflict (user_id, content_type, content_id) do update
    set created_at = public.reposts.created_at
  returning * into result_row;
  return result_row;
end;
$$;

create or replace function public.hallyu_remove_repost_v1(
  p_content_type text, p_content_id uuid
)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  delete from public.reposts
   where user_id = auth.uid()
     and content_type = p_content_type
     and content_id = p_content_id;
$$;

revoke all on table public.reposts from public, anon, authenticated;
revoke all on function public.hallyu_repost_content_available_v1(text,uuid)
  from public, anon, authenticated;
revoke all on function public.hallyu_create_repost_v1(text,uuid)
  from public, anon, authenticated;
revoke all on function public.hallyu_remove_repost_v1(text,uuid)
  from public, anon, authenticated;
grant execute on function public.hallyu_create_repost_v1(text,uuid) to authenticated;
grant execute on function public.hallyu_remove_repost_v1(text,uuid) to authenticated;

alter table public.reposts enable row level security;
drop policy if exists "reposts visible with original" on public.reposts;
create policy "reposts visible with original" on public.reposts
  for select to authenticated
  using (public.hallyu_repost_content_available_v1(content_type, content_id));

-- Flutter publish code intentionally writes audience_type and references only.
-- This migration must be reviewed/applied before enabling those remote writes.
commit;
