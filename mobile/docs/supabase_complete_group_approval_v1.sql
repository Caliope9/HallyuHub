-- Require a verified editorial record before approving any NEW group.
-- Existing catalog rows and existing approvals are left untouched.
alter table public.kpop_entities
  add column if not exists discography jsonb not null default '[]'::jsonb,
  add column if not exists editorial_source_url text not null default '';

create or replace function public.approve_artist_suggestion(
  p_suggestion_id uuid,
  p_name text default null,
  p_type text default null,
  p_admin_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  suggestion public.artist_suggestions%rowtype;
  final_name text;
  final_type text;
  catalog_type text;
  normalized text;
  entity_id uuid;
begin
  if not public.is_admin_or_moderator() then
    raise exception 'not allowed';
  end if;
  select * into suggestion from public.artist_suggestions
    where id = p_suggestion_id for update;
  if not found then
    raise exception 'artist suggestion not found';
  end if;
  final_name := trim(coalesce(nullif(p_name, ''), suggestion.name));
  final_type := coalesce(nullif(p_type, ''), suggestion.type, 'artist');
  if final_type = 'group' or suggestion.type = 'group' then
    raise exception 'groups require approve_complete_group_suggestion';
  end if;
  if final_type not in ('idol', 'soloist', 'artist', 'other') then
    final_type := 'artist';
  end if;
  catalog_type := case when final_type = 'idol' then 'idol' else 'artist' end;
  normalized := public.hallyuhub_normalize_artist_name(final_name);
  if length(final_name) < 2 or normalized = '' then
    raise exception 'valid artist name required';
  end if;
  if exists (
    select 1 from public.kpop_entities
    where normalized_name = normalized and entity_type = 'group'
  ) then
    raise exception 'existing group cannot be changed by artist approval';
  end if;
  insert into public.kpop_entities (
    entity_type, name, normalized_name, aliases, bio, official_url,
    is_verified, status, created_at, updated_at
  ) values (
    catalog_type, final_name, normalized, '{}', '',
    coalesce(suggestion.official_url, ''), false, 'community', now(), now()
  )
  on conflict (normalized_name) do update set
    name = excluded.name,
    entity_type = excluded.entity_type,
    official_url = case
      when coalesce(public.kpop_entities.official_url, '') = ''
        then excluded.official_url
      else public.kpop_entities.official_url
    end,
    updated_at = now()
  returning id into entity_id;
  update public.artist_suggestions set
    name = final_name, normalized_name = normalized, type = final_type,
    status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(),
    admin_notes = coalesce(nullif(p_admin_notes, ''), admin_notes),
    approved_entity_id = entity_id, updated_at = now()
  where id = p_suggestion_id;
  return entity_id;
end;
$$;

alter function public.approve_artist_suggestion(uuid, text, text, text) owner to postgres;
revoke execute on function public.approve_artist_suggestion(uuid, text, text, text)
  from public, anon;
grant execute on function public.approve_artist_suggestion(uuid, text, text, text)
  to authenticated;

create or replace function public.approve_complete_group_suggestion(
  p_suggestion_id uuid,
  p_name text,
  p_bio text,
  p_source_url text,
  p_members text[],
  p_discography text[],
  p_admin_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  suggestion public.artist_suggestions%rowtype;
  final_name text;
  normalized text;
  group_id uuid;
  member_id uuid;
  member_name text;
  member_normalized text;
  member_type text;
  member_position integer := 0;
  seen_names text[] := '{}';
begin
  if not public.is_admin_or_moderator() then
    raise exception 'not allowed';
  end if;
  select * into suggestion from public.artist_suggestions
    where id = p_suggestion_id for update;
  if not found or suggestion.status <> 'pending' then
    raise exception 'pending suggestion not found';
  end if;
  final_name := trim(coalesce(nullif(p_name, ''), suggestion.name));
  normalized := public.hallyuhub_normalize_artist_name(final_name);
  if length(final_name) < 2 or normalized = ''
     or length(trim(coalesce(p_bio, ''))) < 40
     or coalesce(p_source_url, '') !~ '^https://[^ ]+$'
     or coalesce(array_length(p_members, 1), 0) = 0
     or coalesce(array_length(p_discography, 1), 0) = 0
     or exists (select 1 from unnest(p_discography) item where length(trim(coalesce(item, ''))) < 2)
  then
    raise exception 'complete group profile and HTTPS source are required';
  end if;
  if exists (select 1 from public.kpop_entities where normalized_name = normalized) then
    raise exception 'group already exists; mark suggestion duplicate';
  end if;
  -- All writes are atomic: a bad member aborts the entire approval.
  insert into public.kpop_entities (
    entity_type, name, normalized_name, bio, discography,
    editorial_source_url, official_url, is_verified, status
  ) values (
    'group', final_name, normalized, trim(p_bio),
    to_jsonb(p_discography), trim(p_source_url),
    coalesce(suggestion.official_url, ''), false, 'community'
  ) returning id into group_id;
  foreach member_name in array p_members loop
    member_name := trim(coalesce(member_name, ''));
    member_normalized := public.hallyuhub_normalize_artist_name(member_name);
    if length(member_name) < 2 or member_normalized = any(seen_names)
       or member_normalized = normalized then
      raise exception 'invalid or duplicate member name';
    end if;
    seen_names := array_append(seen_names, member_normalized);
    select id, entity_type into member_id, member_type
      from public.kpop_entities where normalized_name = member_normalized;
    if member_id is null then
      insert into public.kpop_entities (
        entity_type, name, normalized_name, bio, is_verified, status
      ) values ('idol', member_name, member_normalized, '', false, 'community')
      returning id into member_id;
    elsif member_type <> 'idol' then
      raise exception 'member name belongs to a non-idol entity';
    end if;
    insert into public.kpop_entity_members (
      group_id, member_id, position, stage_name, is_active
    ) values (group_id, member_id, member_position, member_name, true);
    member_position := member_position + 1;
    member_id := null;
  end loop;
  update public.artist_suggestions set
    name = final_name, normalized_name = normalized, type = 'group',
    status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(),
    admin_notes = coalesce(nullif(p_admin_notes, ''), admin_notes),
    approved_entity_id = group_id, updated_at = now()
  where id = p_suggestion_id;
  return group_id;
end;
$$;

alter function public.approve_complete_group_suggestion(
  uuid, text, text, text, text[], text[], text
) owner to postgres;
revoke execute on function public.approve_complete_group_suggestion(
  uuid, text, text, text, text[], text[], text
) from public, anon;
grant execute on function public.approve_complete_group_suggestion(
  uuid, text, text, text, text[], text[], text
) to authenticated;
