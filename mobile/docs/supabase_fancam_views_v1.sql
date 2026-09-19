-- HallyuHub F1A.2 - persistent Fancam playback views.
-- Prepare only. Do not apply to a remote project without approval.

alter table public.fancams
  add column if not exists view_count bigint not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.fancams'::regclass
      and conname = 'fancams_view_count_nonnegative'
  ) then
    alter table public.fancams
      add constraint fancams_view_count_nonnegative
      check (view_count >= 0);
  end if;
end
$$;

-- Authors may edit content fields, but never the aggregate view counter.
-- Revoking UPDATE at table level is required because a column-level REVOKE
-- does not override an existing table-level UPDATE grant.
revoke update
on table public.fancams
from public, anon, authenticated;

grant update (
  caption,
  tags,
  artist_id,
  artist_name,
  group_id,
  group_name,
  event_name,
  song_name,
  audio,
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
on table public.fancams
to authenticated;

create table if not exists public.fancam_view_events (
  id uuid primary key default gen_random_uuid(),
  fancam_id uuid not null
    references public.fancams(id) on delete cascade,
  viewer_id uuid not null
    references auth.users(id) on delete cascade,
  playback_session_id uuid not null,
  counting_window bigint not null,
  created_at timestamptz not null default now(),
  constraint fancam_view_events_once
    unique (fancam_id, viewer_id, playback_session_id),
  constraint fancam_view_events_window_once
    unique (fancam_id, viewer_id, counting_window)
);

create index if not exists fancam_view_events_fancam_idx
  on public.fancam_view_events(fancam_id, created_at desc);

create index if not exists fancam_view_events_viewer_idx
  on public.fancam_view_events(viewer_id, created_at desc);

create index if not exists fancams_published_view_count_idx
  on public.fancams(view_count desc)
  where status = 'published'
    and deleted_at is null;

alter table public.fancam_view_events enable row level security;

-- View events are backend-only. The client does not need to read them.
revoke all
on table public.fancam_view_events
from public, anon, authenticated;

grant select, insert, update, delete
on table public.fancam_view_events
to service_role;

create or replace function public.record_fancam_view(
  p_fancam_id uuid,
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
begin
  if v_viewer_id is null then
    raise exception 'authentication_required'
      using errcode = '42501';
  end if;

  if p_fancam_id is null
     or p_playback_session_id is null then
    raise exception 'fancam_view_parameters_required'
      using errcode = '22023';
  end if;

  select f.author_id, f.view_count
  into v_author_id, v_view_count
  from public.fancams f
  where f.id = p_fancam_id
    and f.status = 'published'
    and f.deleted_at is null
    and public.can_view_profile_content(f.author_id)
    and not public.hallyu_users_blocked_v1(
      v_viewer_id,
      f.author_id
    );

  if not found then
    raise exception 'fancam_not_available'
      using errcode = 'P0002';
  end if;

  -- Authors can watch their own Fancams, but self-views are not counted.
  if v_viewer_id = v_author_id then
    return coalesce(v_view_count, 0);
  end if;

  v_counting_window := floor(
    extract(epoch from clock_timestamp()) / 1800
  )::bigint;

  insert into public.fancam_view_events (
    fancam_id,
    viewer_id,
    playback_session_id,
    counting_window
  )
  values (
    p_fancam_id,
    v_viewer_id,
    p_playback_session_id,
    v_counting_window
  )
  on conflict do nothing;

  -- A conflict means either the playback session or the 30-minute window
  -- was already counted. Only a newly inserted event increments the total.
  if found then
    update public.fancams
    set view_count = view_count + 1
    where id = p_fancam_id
    returning view_count into v_view_count;
  end if;

  return coalesce(v_view_count, 0);
end;
$$;

alter function public.record_fancam_view(uuid, uuid)
  owner to postgres;

revoke all
on function public.record_fancam_view(uuid, uuid)
from public, anon, authenticated;

grant execute
on function public.record_fancam_view(uuid, uuid)
to authenticated;
