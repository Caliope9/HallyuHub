-- HallyuHub D1A - secure persistent Drop playback views.
-- Prepare only. Do not apply to a remote project without approval.

alter table public.drops
  add column if not exists view_count bigint not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.drops'::regclass
      and conname = 'drops_view_count_nonnegative'
  ) then
    alter table public.drops
      add constraint drops_view_count_nonnegative
      check (view_count >= 0);
  end if;
end
$$;

-- A Drop owner may edit content fields, but never the aggregate counter or
-- immutable/audit fields. Table-level UPDATE is revoked first because a
-- column-level grant does not override an existing table-level grant.
revoke update
on table public.drops
from public, anon, authenticated;

grant update (
  caption,
  tags,
  artist_id,
  artist_name,
  group_id,
  group_name,
  audio,
  filter,
  location,
  duration_seconds,
  file_size,
  storage_bucket,
  storage_path,
  video_url,
  thumbnail_url,
  status,
  deleted_at
)
on table public.drops
to authenticated;

create table if not exists public.drop_view_events (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null
    references public.drops(id) on delete cascade,
  viewer_id uuid not null
    references auth.users(id) on delete cascade,
  playback_session_id uuid not null,
  counting_window bigint not null,
  created_at timestamptz not null default now(),
  constraint drop_view_events_once
    unique (drop_id, viewer_id, playback_session_id),
  constraint drop_view_events_window_once
    unique (drop_id, viewer_id, counting_window)
);

create index if not exists drop_view_events_drop_idx
  on public.drop_view_events(drop_id, created_at desc);

create index if not exists drop_view_events_viewer_idx
  on public.drop_view_events(viewer_id, created_at desc);

create index if not exists drops_published_view_count_idx
  on public.drops(view_count desc)
  where status = 'published'
    and deleted_at is null;

alter table public.drop_view_events enable row level security;

-- Events are backend-only. The client only invokes the RPC.
revoke all
on table public.drop_view_events
from public, anon, authenticated;

grant select, insert, update, delete
on table public.drop_view_events
to service_role;

create or replace function public.record_drop_view(
  p_drop_id uuid,
  p_playback_session_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_author_id uuid;
  v_view_count bigint;
  v_counting_window bigint;
  v_inserted integer;
begin
  if v_viewer_id is null then
    raise exception 'authentication_required'
      using errcode = '42501';
  end if;

  if p_drop_id is null or p_playback_session_id is null then
    raise exception 'drop_view_parameters_required'
      using errcode = '22023';
  end if;

  -- Lock the Drop row so concurrent new events cannot increment it twice
  -- from a stale counter read.
  select d.author_id, d.view_count
  into v_author_id, v_view_count
  from public.drops d
  where d.id = p_drop_id
    and d.status = 'published'
    and d.deleted_at is null
    and public.can_view_profile_content(d.author_id)
    and not public.hallyu_users_blocked_v1(v_viewer_id, d.author_id)
  for update;

  if not found then
    raise exception 'drop_not_available'
      using errcode = 'P0002';
  end if;

  -- Authors can watch their own Drops, but self-views are not counted.
  if v_viewer_id = v_author_id then
    return coalesce(v_view_count, 0);
  end if;

  v_counting_window := floor(
    extract(epoch from clock_timestamp()) / 1800
  )::bigint;

  insert into public.drop_view_events (
    drop_id,
    viewer_id,
    playback_session_id,
    counting_window
  )
  values (
    p_drop_id,
    v_viewer_id,
    p_playback_session_id,
    v_counting_window
  )
  on conflict do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 1 then
    update public.drops
    set view_count = view_count + 1
    where id = p_drop_id
    returning view_count into v_view_count;
  end if;

  return coalesce(v_view_count, 0);
end;
$$;

alter function public.record_drop_view(uuid, uuid)
  owner to postgres;

revoke all
on function public.record_drop_view(uuid, uuid)
from public, anon, authenticated;

grant execute
on function public.record_drop_view(uuid, uuid)
to authenticated;
