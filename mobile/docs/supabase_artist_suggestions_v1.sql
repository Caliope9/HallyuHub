-- HallyuHub Beta Real - Sugerencias reales de grupos, idols y artistas.
-- Seguro para correr varias veces. No borra datos reales.

create extension if not exists "pgcrypto";

create table if not exists public.artist_suggestions (
  id uuid primary key default gen_random_uuid(),
  suggested_by uuid references public.profiles(id) on delete set null,
  name text not null,
  normalized_name text,
  type text not null default 'artist',
  fandom text,
  country text,
  agency text,
  official_url text,
  note text,
  status text not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  admin_notes text,
  approved_entity_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.artist_suggestions
  add column if not exists suggested_by uuid references public.profiles(id) on delete set null,
  add column if not exists name text,
  add column if not exists normalized_name text,
  add column if not exists type text not null default 'artist',
  add column if not exists fandom text,
  add column if not exists country text,
  add column if not exists agency text,
  add column if not exists official_url text,
  add column if not exists note text,
  add column if not exists status text not null default 'pending',
  add column if not exists reviewed_by uuid references public.profiles(id) on delete set null,
  add column if not exists reviewed_at timestamptz,
  add column if not exists admin_notes text,
  add column if not exists approved_entity_id uuid,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.kpop_entities (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null default 'artist',
  name text not null,
  normalized_name text not null,
  aliases text[] not null default '{}',
  bio text not null default '',
  image_url text not null default '',
  image_source text not null default '',
  image_license text not null default '',
  attribution text not null default '',
  official_url text not null default '',
  is_verified boolean not null default false,
  status text not null default 'community',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kpop_entities
  add column if not exists entity_type text not null default 'artist',
  add column if not exists name text,
  add column if not exists normalized_name text not null default '',
  add column if not exists aliases text[] not null default '{}',
  add column if not exists bio text not null default '',
  add column if not exists image_url text not null default '',
  add column if not exists image_source text not null default '',
  add column if not exists image_license text not null default '',
  add column if not exists attribution text not null default '',
  add column if not exists official_url text not null default '',
  add column if not exists is_verified boolean not null default false,
  add column if not exists status text not null default 'community',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'artist_suggestions_type_check'
      and conrelid = 'public.artist_suggestions'::regclass
  ) then
    alter table public.artist_suggestions
      add constraint artist_suggestions_type_check
      check (type in ('group', 'idol', 'soloist', 'artist', 'other'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'artist_suggestions_status_check'
      and conrelid = 'public.artist_suggestions'::regclass
  ) then
    alter table public.artist_suggestions
      add constraint artist_suggestions_status_check
      check (status in ('pending', 'approved', 'rejected', 'duplicate'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'kpop_entities_entity_type_check'
      and conrelid = 'public.kpop_entities'::regclass
  ) then
    alter table public.kpop_entities
      add constraint kpop_entities_entity_type_check
      check (entity_type in ('group', 'idol', 'artist'));
  end if;
end $$;

create or replace function public.hallyuhub_normalize_artist_name(p_value text)
returns text
language sql
immutable
as $$
  select lower(regexp_replace(trim(coalesce(p_value, '')), '\s+', ' ', 'g'));
$$;

-- No se normalizan filas existentes con UPDATE masivo para evitar modificar
-- datos reales previos. El trigger normaliza cada insert/update nuevo.

create index if not exists artist_suggestions_status_created_idx
  on public.artist_suggestions (status, created_at desc);

create index if not exists artist_suggestions_type_status_idx
  on public.artist_suggestions (type, status);

create index if not exists artist_suggestions_suggested_by_idx
  on public.artist_suggestions (suggested_by, created_at desc);

create index if not exists artist_suggestions_normalized_name_idx
  on public.artist_suggestions (normalized_name);

create unique index if not exists kpop_entities_normalized_name_uidx
  on public.kpop_entities (normalized_name);

create index if not exists kpop_entities_type_name_idx
  on public.kpop_entities (entity_type, name);

alter table public.profiles
  add column if not exists role text not null default 'user';

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.role
      from public.profiles as p
      where p.id = auth.uid()
      limit 1
    ),
    'user'
  );
$$;

create or replace function public.is_admin_or_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() in ('admin', 'moderator');
$$;

grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_admin_or_moderator() to authenticated;

create or replace function public.artist_suggestions_before_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.name := trim(coalesce(new.name, ''));

  if new.name = '' then
    raise exception 'artist suggestion name is required';
  end if;

  new.normalized_name := public.hallyuhub_normalize_artist_name(new.name);

  if new.type is null
     or new.type not in ('group', 'idol', 'soloist', 'artist', 'other') then
    new.type := 'artist';
  end if;

  if new.status is null
     or new.status not in ('pending', 'approved', 'rejected', 'duplicate') then
    new.status := 'pending';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists artist_suggestions_before_write_trigger
  on public.artist_suggestions;

create trigger artist_suggestions_before_write_trigger
before insert or update
on public.artist_suggestions
for each row
execute function public.artist_suggestions_before_write();

create or replace function public.approve_artist_suggestion(
  p_suggestion_id uuid,
  p_name text default null,
  p_type text default null,
  p_admin_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
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

  select *
  into suggestion
  from public.artist_suggestions
  where id = p_suggestion_id
  for update;

  if not found then
    raise exception 'artist suggestion not found';
  end if;

  final_name := trim(coalesce(nullif(p_name, ''), suggestion.name));
  final_type := coalesce(nullif(p_type, ''), suggestion.type, 'artist');

  if final_type not in ('group', 'idol', 'soloist', 'artist', 'other') then
    final_type := 'artist';
  end if;

  catalog_type := case
    when final_type = 'group' then 'group'
    when final_type = 'idol' then 'idol'
    else 'artist'
  end;

  normalized := public.hallyuhub_normalize_artist_name(final_name);

  insert into public.kpop_entities (
    entity_type,
    name,
    normalized_name,
    aliases,
    bio,
    official_url,
    is_verified,
    status,
    created_at,
    updated_at
  ) values (
    catalog_type,
    final_name,
    normalized,
    '{}',
    '',
    coalesce(suggestion.official_url, ''),
    false,
    'community',
    now(),
    now()
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

  update public.artist_suggestions
  set
    name = final_name,
    normalized_name = normalized,
    type = final_type,
    status = 'approved',
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    admin_notes = coalesce(nullif(p_admin_notes, ''), admin_notes),
    approved_entity_id = entity_id,
    updated_at = now()
  where id = p_suggestion_id;

  return entity_id;
end;
$$;

grant execute on function public.approve_artist_suggestion(uuid, text, text, text)
  to authenticated;

alter table public.artist_suggestions enable row level security;
alter table public.kpop_entities enable row level security;

drop policy if exists "artist suggestions self insert" on public.artist_suggestions;
create policy "artist suggestions self insert"
on public.artist_suggestions
for insert
to authenticated
with check ((select auth.uid()) = suggested_by);

drop policy if exists "artist suggestions self read" on public.artist_suggestions;
create policy "artist suggestions self read"
on public.artist_suggestions
for select
to authenticated
using ((select auth.uid()) = suggested_by);

drop policy if exists "artist suggestions admin read" on public.artist_suggestions;
create policy "artist suggestions admin read"
on public.artist_suggestions
for select
to authenticated
using (public.is_admin_or_moderator());

drop policy if exists "artist suggestions admin update" on public.artist_suggestions;
create policy "artist suggestions admin update"
on public.artist_suggestions
for update
to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

drop policy if exists "kpop entities public read" on public.kpop_entities;
create policy "kpop entities public read"
on public.kpop_entities
for select
using (true);

revoke all on public.artist_suggestions from anon;
revoke all on public.artist_suggestions from authenticated;
grant select, insert, update on public.artist_suggestions to authenticated;

-- El catalogo K-pop queda de solo lectura para clientes comunes.
-- Las altas/correcciones por sugerencias aprobadas pasan por
-- approve_artist_suggestion(), que es SECURITY DEFINER y valida admin/mod.
revoke insert, update, delete on public.kpop_entities from anon, authenticated;
grant select on public.kpop_entities to anon, authenticated;
