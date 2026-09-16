-- HallyuHub Beta Real v1 - Artist/group/idol tags for posts, stories, drops and fancams.
-- Safe to run more than once. Does not delete real data.

create table if not exists public.kpop_entities (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('group', 'idol', 'artist')),
  name text not null,
  normalized_name text not null unique,
  aliases text[] not null default '{}',
  bio text not null default '',
  image_url text not null default '',
  image_source text not null default '',
  image_license text not null default '',
  attribution text not null default '',
  official_url text not null default '',
  is_verified boolean not null default false,
  status text not null default 'verified',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kpop_entities
  add column if not exists entity_type text not null default 'artist',
  add column if not exists normalized_name text not null default '',
  add column if not exists aliases text[] not null default '{}',
  add column if not exists bio text not null default '',
  add column if not exists image_url text not null default '',
  add column if not exists image_source text not null default '',
  add column if not exists image_license text not null default '',
  add column if not exists attribution text not null default '',
  add column if not exists official_url text not null default '',
  add column if not exists is_verified boolean not null default false,
  add column if not exists status text not null default 'verified',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists kpop_entities_normalized_name_uidx
  on public.kpop_entities (normalized_name);

create index if not exists kpop_entities_type_name_idx
  on public.kpop_entities (entity_type, name);

create index if not exists kpop_entities_verified_name_idx
  on public.kpop_entities (is_verified desc, name);

create table if not exists public.content_artist_tags (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('post', 'story', 'drop', 'fancam')),
  content_id uuid not null,
  entity_id uuid not null references public.kpop_entities(id) on delete cascade,
  tagged_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (content_type, content_id, entity_id)
);

create index if not exists content_artist_tags_content_idx
  on public.content_artist_tags (content_type, content_id);

create index if not exists content_artist_tags_entity_idx
  on public.content_artist_tags (entity_id, created_at desc);

create index if not exists content_artist_tags_tagged_by_idx
  on public.content_artist_tags (tagged_by, created_at desc);

create table if not exists public.kpop_entity_suggestions (
  id uuid primary key default gen_random_uuid(),
  suggested_name text not null,
  suggested_type text not null default 'artist' check (suggested_type in ('group', 'idol', 'artist')),
  suggested_by uuid references public.profiles(id) on delete set null,
  reference_url text not null default '',
  notes text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create index if not exists kpop_entity_suggestions_status_created_idx
  on public.kpop_entity_suggestions (status, created_at desc);

create index if not exists kpop_entity_suggestions_by_user_idx
  on public.kpop_entity_suggestions (suggested_by, created_at desc);

alter table public.kpop_entities enable row level security;
alter table public.content_artist_tags enable row level security;
alter table public.kpop_entity_suggestions enable row level security;

drop policy if exists "kpop entities public read" on public.kpop_entities;
create policy "kpop entities public read"
on public.kpop_entities
for select
using (true);

drop policy if exists "entity suggestions owner insert" on public.kpop_entity_suggestions;
create policy "entity suggestions owner insert"
on public.kpop_entity_suggestions
for insert
to authenticated
with check ((select auth.uid()) = suggested_by);

drop policy if exists "entity suggestions owner read" on public.kpop_entity_suggestions;
create policy "entity suggestions owner read"
on public.kpop_entity_suggestions
for select
to authenticated
using ((select auth.uid()) = suggested_by);

drop policy if exists "content_artist_tags_select_visible" on public.content_artist_tags;
create policy "content_artist_tags_select_visible"
on public.content_artist_tags
for select
using (
  (content_type = 'post' and exists (
    select 1 from public.posts p
    where p.id = content_artist_tags.content_id
      and p.status = 'published'
  ))
  or
  (content_type = 'story' and exists (
    select 1 from public.stories s
    where s.id = content_artist_tags.content_id
      and s.expires_at > now()
      and (
        s.author_id = (select auth.uid())
        or exists (
          select 1 from public.follows f
          where f.follower_id = (select auth.uid())
            and f.following_id = s.author_id
        )
      )
  ))
  or
  (content_type = 'drop' and exists (
    select 1 from public.drops d
    where d.id = content_artist_tags.content_id
      and d.status = 'published'
      and d.deleted_at is null
  ))
  or
  (content_type = 'fancam' and exists (
    select 1 from public.fancams fc
    where fc.id = content_artist_tags.content_id
      and fc.status = 'published'
      and fc.deleted_at is null
  ))
);

drop policy if exists "content_artist_tags_insert_own_content" on public.content_artist_tags;
create policy "content_artist_tags_insert_own_content"
on public.content_artist_tags
for insert
to authenticated
with check (
  tagged_by = (select auth.uid())
  and exists (
    select 1 from public.kpop_entities e
    where e.id = content_artist_tags.entity_id
  )
  and (
    (content_type = 'post' and exists (
      select 1 from public.posts p
      where p.id = content_artist_tags.content_id
        and p.author_id = (select auth.uid())
    ))
    or
    (content_type = 'story' and exists (
      select 1 from public.stories s
      where s.id = content_artist_tags.content_id
        and s.author_id = (select auth.uid())
    ))
    or
    (content_type = 'drop' and exists (
      select 1 from public.drops d
      where d.id = content_artist_tags.content_id
        and d.author_id = (select auth.uid())
    ))
    or
    (content_type = 'fancam' and exists (
      select 1 from public.fancams fc
      where fc.id = content_artist_tags.content_id
        and fc.author_id = (select auth.uid())
    ))
  )
);

drop policy if exists "content_artist_tags_delete_own_tags" on public.content_artist_tags;
create policy "content_artist_tags_delete_own_tags"
on public.content_artist_tags
for delete
to authenticated
using (tagged_by = (select auth.uid()));

insert into public.kpop_entities (
  entity_type,
  name,
  normalized_name,
  aliases,
  bio,
  is_verified,
  status
) values
  ('group', 'BTS', 'bts', array['Bangtan', 'Bangtan Sonyeondan'], 'Grupo surcoreano reconocido por su impacto global, fandom ARMY y una discografía que mezcla pop, hip-hop y mensajes personales.', true, 'verified'),
  ('group', 'BLACKPINK', 'blackpink', array['BP', 'Blink'], 'Grupo de K-pop con identidad visual fuerte, pop de alto impacto y presencia global en música, moda y performance.', true, 'verified'),
  ('group', 'Stray Kids', 'stray kids', array['SKZ', 'Stay'], 'Grupo con sonido enérgico, producción propia y una comunidad global muy activa.', true, 'verified'),
  ('group', 'NewJeans', 'newjeans', array['NJZ', 'Bunnies'], 'Grupo conocido por una estética fresca, pop nostálgico y propuesta visual moderna.', true, 'verified'),
  ('group', 'TWICE', 'twice', array['Once'], 'Grupo con una trayectoria sólida, canciones pop reconocibles y una comunidad internacional fuerte.', true, 'verified'),
  ('group', 'SEVENTEEN', 'seventeen', array['SVT', 'Carat'], 'Grupo reconocido por performance, producción, coreografías y conexión cercana con su fandom.', true, 'verified'),
  ('idol', 'Jungkook', 'jungkook', array['Jeon Jungkook', 'JK', 'BTS'], 'Artista e integrante de BTS destacado por su voz, performance y carrera solista global.', true, 'verified'),
  ('idol', 'Jimin', 'jimin', array['Park Jimin', 'BTS'], 'Artista e integrante de BTS reconocido por su tono vocal, danza expresiva y presencia escénica.', true, 'verified'),
  ('idol', 'Lisa', 'lisa', array['Lalisa', 'BLACKPINK'], 'Artista e integrante de BLACKPINK reconocida por su baile, presencia escénica y alcance global.', true, 'verified'),
  ('idol', 'Jennie', 'jennie', array['Jennie Kim', 'BLACKPINK'], 'Artista e integrante de BLACKPINK con identidad musical, visual y de performance propia.', true, 'verified')
on conflict (normalized_name) do nothing;
