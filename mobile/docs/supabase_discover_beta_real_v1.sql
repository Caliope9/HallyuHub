-- HallyuHub Beta Real - Discover/Search base real interactiva.
-- Seguro para correr varias veces. No borra datos reales.

create extension if not exists "pgcrypto";

-- Catálogo base K-pop sin actividad falsa.
create table if not exists public.kpop_entities (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null default 'artist' check (entity_type in ('group', 'idol', 'artist')),
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

create table if not exists public.kpop_entity_follows (
  entity_id uuid not null references public.kpop_entities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (entity_id, user_id)
);

create index if not exists kpop_entity_follows_user_idx
  on public.kpop_entity_follows (user_id, created_at desc);

create index if not exists kpop_entity_follows_entity_idx
  on public.kpop_entity_follows (entity_id, created_at desc);

alter table public.kpop_entities enable row level security;
alter table public.kpop_entity_follows enable row level security;

drop policy if exists "kpop entities public read" on public.kpop_entities;
create policy "kpop entities public read"
on public.kpop_entities
for select
using (true);

drop policy if exists "kpop entity follows public read" on public.kpop_entity_follows;
create policy "kpop entity follows public read"
on public.kpop_entity_follows
for select
using (true);

drop policy if exists "kpop entity follows self insert" on public.kpop_entity_follows;
create policy "kpop entity follows self insert"
on public.kpop_entity_follows
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "kpop entity follows self delete" on public.kpop_entity_follows;
create policy "kpop entity follows self delete"
on public.kpop_entity_follows
for delete
to authenticated
using ((select auth.uid()) = user_id);

insert into public.kpop_entities (
  entity_type,
  name,
  normalized_name,
  aliases,
  bio,
  is_verified,
  status
) values
  ('group', 'BTS', 'bts', array['Bangtan', 'Bangtan Sonyeondan', 'ARMY'], 'Grupo surcoreano con impacto global, fandom ARMY y una discografía que mezcla pop, hip-hop y mensajes personales.', true, 'verified'),
  ('group', 'BLACKPINK', 'blackpink', array['BP', 'BLINK'], 'Grupo de K-pop con identidad visual fuerte, pop de alto impacto y presencia global en música, moda y performance.', true, 'verified'),
  ('group', 'Stray Kids', 'stray kids', array['SKZ', 'STAY'], 'Grupo con sonido enérgico, producción propia y una comunidad global muy activa.', true, 'verified'),
  ('group', 'NewJeans', 'newjeans', array['NJZ', 'Bunnies'], 'Grupo conocido por una estética fresca, pop nostálgico y propuesta visual moderna.', true, 'verified'),
  ('group', 'TWICE', 'twice', array['ONCE'], 'Grupo con trayectoria sólida, canciones pop reconocibles y una comunidad internacional fuerte.', true, 'verified'),
  ('group', 'SEVENTEEN', 'seventeen', array['SVT', 'CARAT'], 'Grupo reconocido por performance, producción, coreografías y conexión cercana con su fandom.', true, 'verified'),
  ('group', 'ENHYPEN', 'enhypen', array['ENGENE'], 'Grupo con narrativa visual intensa, performance cuidada y fandom global en crecimiento.', true, 'verified'),
  ('group', 'TXT', 'txt', array['TOMORROW X TOGETHER', 'MOA'], 'Grupo con concepto juvenil, narrativa pop y estética visual cambiante.', true, 'verified'),
  ('group', 'IVE', 'ive', array['DIVE'], 'Grupo con canciones pop elegantes, presencia escénica fuerte y propuesta visual refinada.', true, 'verified'),
  ('group', 'LE SSERAFIM', 'le sserafim', array['LESSERAFIM', 'FEARNOT'], 'Grupo con concepto de confianza, performance potente y estética moderna.', true, 'verified'),
  ('group', 'aespa', 'aespa', array['MY'], 'Grupo con identidad futurista, elementos digitales y sonido pop electrónico.', true, 'verified'),
  ('group', 'NCT', 'nct', array['NCT 127', 'NCT DREAM', 'WayV', 'NCTzen'], 'Proyecto con múltiples unidades, estilos y una base fandom internacional.', true, 'verified'),
  ('group', 'ATEEZ', 'ateez', array['ATINY'], 'Grupo reconocido por performance intensa, narrativa aventurera y fandom activo.', true, 'verified'),
  ('group', 'EXO', 'exo', array['EXO-L'], 'Grupo con trayectoria destacada, voces fuertes y alto impacto en la historia moderna del K-pop.', true, 'verified'),
  ('idol', 'Jungkook', 'jungkook', array['Jeon Jungkook', 'JK', 'BTS'], 'Artista e integrante de BTS destacado por su voz, performance y carrera solista global.', true, 'verified'),
  ('idol', 'Jimin', 'jimin', array['Park Jimin', 'BTS'], 'Artista e integrante de BTS reconocido por su tono vocal, danza expresiva y presencia escénica.', true, 'verified'),
  ('idol', 'Lisa', 'lisa', array['Lalisa', 'BLACKPINK'], 'Artista e integrante de BLACKPINK reconocida por su baile, presencia escénica y alcance global.', true, 'verified'),
  ('idol', 'Jennie', 'jennie', array['Jennie Kim', 'BLACKPINK'], 'Artista e integrante de BLACKPINK con identidad musical, visual y de performance propia.', true, 'verified'),
  ('idol', 'Bang Chan', 'bang chan', array['Christopher Bang', 'Stray Kids', 'SKZ'], 'Artista e integrante de Stray Kids asociado a liderazgo, producción y conexión cercana con fans.', true, 'verified')
on conflict (normalized_name) do update set
  entity_type = excluded.entity_type,
  name = excluded.name,
  aliases = excluded.aliases,
  bio = excluded.bio,
  is_verified = excluded.is_verified,
  status = excluded.status,
  updated_at = now();

-- Comunidades base reales, sin mensajes o miembros inventados.
create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  name text not null,
  country text not null default '',
  region text not null default '',
  city text not null default '',
  fandom text not null default '',
  description text not null default '',
  privacy text not null default 'public',
  status text not null default 'active',
  created_at timestamptz not null default now()
);

alter table public.communities
  add column if not exists slug text,
  add column if not exists owner_id uuid references public.profiles(id) on delete set null,
  add column if not exists country text not null default '',
  add column if not exists region text not null default '',
  add column if not exists city text not null default '',
  add column if not exists fandom text not null default '',
  add column if not exists description text not null default '',
  add column if not exists privacy text not null default 'public',
  add column if not exists status text not null default 'active',
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists communities_slug_uidx
  on public.communities (slug)
  where slug is not null;

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

create table if not exists public.community_messages (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) > 0 and char_length(body) <= 1000),
  created_at timestamptz not null default now()
);

alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.community_messages enable row level security;

drop policy if exists "communities public read" on public.communities;
create policy "communities public read"
on public.communities
for select
using (privacy = 'public' or owner_id = (select auth.uid()));

drop policy if exists "communities owner insert" on public.communities;
create policy "communities owner insert"
on public.communities
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

drop policy if exists "community members public read" on public.community_members;
create policy "community members public read"
on public.community_members
for select
using (true);

drop policy if exists "community members self manage" on public.community_members;
create policy "community members self manage"
on public.community_members
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "community messages member read" on public.community_messages;
create policy "community messages member read"
on public.community_messages
for select
to authenticated
using (
  exists (
    select 1 from public.community_members m
    where m.community_id = community_messages.community_id
      and m.user_id = (select auth.uid())
  )
);

drop policy if exists "community messages member insert" on public.community_messages;
create policy "community messages member insert"
on public.community_messages
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.community_members m
    where m.community_id = community_messages.community_id
      and m.user_id = (select auth.uid())
  )
);

insert into public.communities (
  id,
  slug,
  name,
  country,
  region,
  city,
  fandom,
  description,
  privacy,
  status
) values
  ('00000000-0000-4000-8000-000000000101', 'hallyu-argentina', 'Hallyu Argentina', 'Argentina', '', '', 'Multi fandom', 'Comunidad base para fans de Argentina durante la beta real.', 'public', 'active'),
  ('00000000-0000-4000-8000-000000000102', 'hallyu-buenos-aires', 'Hallyu Buenos Aires', 'Argentina', 'Buenos Aires', '', 'Multi fandom', 'Comunidad base para fans de Buenos Aires durante la beta real.', 'public', 'active'),
  ('00000000-0000-4000-8000-000000000103', 'hallyu-caba', 'Hallyu CABA', 'Argentina', 'CABA', 'CABA', 'Multi fandom', 'Comunidad base para fans de CABA durante la beta real.', 'public', 'active')
on conflict (id) do update set
  slug = excluded.slug,
  name = excluded.name,
  country = excluded.country,
  region = excluded.region,
  city = excluded.city,
  fandom = excluded.fandom,
  description = excluded.description,
  privacy = excluded.privacy,
  status = excluded.status,
  updated_at = now();

-- Preguntas reales K-pop 101.
create table if not exists public.kpop101_questions (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) > 0 and char_length(title) <= 180),
  detail text not null default '',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kpop101_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.kpop101_questions(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) > 0 and char_length(body) <= 1500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kpop101_questions enable row level security;
alter table public.kpop101_answers enable row level security;

drop policy if exists "kpop101 questions public read" on public.kpop101_questions;
create policy "kpop101 questions public read"
on public.kpop101_questions
for select
using (true);

drop policy if exists "kpop101 questions author insert" on public.kpop101_questions;
create policy "kpop101 questions author insert"
on public.kpop101_questions
for insert
to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "kpop101 answers public read" on public.kpop101_answers;
create policy "kpop101 answers public read"
on public.kpop101_answers
for select
using (true);

drop policy if exists "kpop101 answers author insert" on public.kpop101_answers;
create policy "kpop101 answers author insert"
on public.kpop101_answers
for insert
to authenticated
with check ((select auth.uid()) = author_id);

-- Eventos propuestos por fans.
create table if not exists public.fan_events (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  fandom text not null default '',
  country text not null default '',
  city text not null default '',
  place text not null default '',
  starts_at timestamptz not null,
  description text not null default '',
  organizer_contact text not null default '',
  external_link text not null default '',
  category text not null default 'other',
  status text not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fan_event_attendees (
  event_id uuid not null references public.fan_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'interested',
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table public.fan_events enable row level security;
alter table public.fan_event_attendees enable row level security;

drop policy if exists "fan events public read" on public.fan_events;
create policy "fan events public read"
on public.fan_events
for select
using (status = 'published');

drop policy if exists "fan events author insert" on public.fan_events;
create policy "fan events author insert"
on public.fan_events
for insert
to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "fan event attendees public read" on public.fan_event_attendees;
create policy "fan event attendees public read"
on public.fan_event_attendees
for select
using (true);

drop policy if exists "fan event attendees self manage" on public.fan_event_attendees;
create policy "fan event attendees self manage"
on public.fan_event_attendees
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Sugerencias reales de tiendas, sin marketplace ni pagos.
create table if not exists public.shop_suggestions (
  id uuid primary key default gen_random_uuid(),
  suggested_by uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  city text not null default '',
  country text not null default '',
  contact_url text not null default '',
  store_type text not null default 'other',
  description text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.shop_suggestions enable row level security;

drop policy if exists "shop suggestions owner insert" on public.shop_suggestions;
create policy "shop suggestions owner insert"
on public.shop_suggestions
for insert
to authenticated
with check ((select auth.uid()) = suggested_by);

drop policy if exists "shop suggestions owner read" on public.shop_suggestions;
create policy "shop suggestions owner read"
on public.shop_suggestions
for select
to authenticated
using ((select auth.uid()) = suggested_by);
