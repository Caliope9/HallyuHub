-- HallyuHub Beta Real - Noticias profesionales v1
-- Seguro: no borra tablas, filas ni datos existentes.
-- Este archivo crea la fuente editorial real. No inserta noticias demo.

create table if not exists public.news_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text,
  why_it_matters text,
  article_url text,
  canonical_url text,
  google_news_url text,
  source_name text not null default '',
  source_domain text,
  ingestion_source text,
  published_at timestamptz,
  imported_at timestamptz,
  image_url text,
  image_source text,
  image_license text,
  image_attribution text,
  editorial_status text not null default 'developing'
    check (editorial_status in (
      'official',
      'confirmed',
      'developing',
      'rumor',
      'trending'
    )),
  entity_ids uuid[] not null default '{}'::uuid[],
  entity_names text[] not null default '{}'::text[],
  tags text[] not null default '{}'::text[],
  language text not null default 'es',
  is_published boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists news_items_publication_idx
on public.news_items (is_published, published_at desc);

create index if not exists news_items_editorial_status_idx
on public.news_items (editorial_status, published_at desc);

create index if not exists news_items_source_domain_idx
on public.news_items (source_domain);

create index if not exists news_items_entity_ids_idx
on public.news_items using gin (entity_ids);

create or replace function public.news_is_admin_or_moderator()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('admin', 'moderator')
  );
$$;

revoke all on function public.news_is_admin_or_moderator() from public, anon;
grant execute on function public.news_is_admin_or_moderator() to authenticated;

create or replace function public.set_news_item_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists news_items_set_updated_at on public.news_items;
create trigger news_items_set_updated_at
before update on public.news_items
for each row execute function public.set_news_item_updated_at();

alter table public.news_items enable row level security;

drop policy if exists "news items admin read" on public.news_items;
create policy "news items admin read"
on public.news_items
for select
to authenticated
using (public.news_is_admin_or_moderator());

drop policy if exists "news items admin insert" on public.news_items;
create policy "news items admin insert"
on public.news_items
for insert
to authenticated
with check (public.news_is_admin_or_moderator());

drop policy if exists "news items admin update" on public.news_items;
create policy "news items admin update"
on public.news_items
for update
to authenticated
using (public.news_is_admin_or_moderator())
with check (public.news_is_admin_or_moderator());

revoke all on public.news_items from anon, authenticated;
grant select, insert, update on public.news_items to authenticated;

create or replace function public.get_public_news(
  limit_count integer default 60,
  offset_count integer default 0
)
returns table (
  id uuid,
  title text,
  summary text,
  why_it_matters text,
  article_url text,
  canonical_url text,
  google_news_url text,
  source_name text,
  source_domain text,
  ingestion_source text,
  published_at timestamptz,
  image_url text,
  image_source text,
  image_license text,
  image_attribution text,
  editorial_status text,
  entity_ids uuid[],
  entity_names text[],
  tags text[],
  language text
)
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
  select
    n.id,
    n.title,
    n.summary,
    n.why_it_matters,
    n.article_url,
    n.canonical_url,
    n.google_news_url,
    n.source_name,
    n.source_domain,
    n.ingestion_source,
    n.published_at,
    n.image_url,
    n.image_source,
    n.image_license,
    n.image_attribution,
    n.editorial_status,
    n.entity_ids,
    n.entity_names,
    n.tags,
    n.language
  from public.news_items n
  where n.is_published = true
    and n.published_at is not null
    and n.published_at <= now()
    and nullif(btrim(n.title), '') is not null
    and nullif(btrim(coalesce(n.summary, '')), '') is not null
    and nullif(btrim(n.source_name), '') is not null
    and (
      nullif(btrim(coalesce(n.canonical_url, '')), '') is not null
      or nullif(btrim(coalesce(n.article_url, '')), '') is not null
      or nullif(btrim(coalesce(n.google_news_url, '')), '') is not null
    )
  order by n.published_at desc, n.created_at desc
  limit least(greatest(coalesce(limit_count, 60), 1), 100)
  offset greatest(coalesce(offset_count, 0), 0);
$$;

revoke all on function public.get_public_news(integer, integer)
from public, anon;
grant execute on function public.get_public_news(integer, integer)
to authenticated;

comment on table public.news_items is
'Noticias editoriales reales de HallyuHub. No contiene seeds ni contenido demo.';

comment on column public.news_items.article_url is
'URL directa del artículo en el medio original. No usar una búsqueda de Google News aquí.';

comment on column public.news_items.google_news_url is
'URL opcional de resultados relacionados. La app la presenta como búsqueda, no como artículo original.';

comment on column public.news_items.editorial_status is
'Estado editorial asignado de forma explícita. RSS o Google News no confirman una noticia automáticamente.';

-- La importación RSS/API debe ejecutarse en un backend seguro y completar
-- source_name, published_at y article_url/canonical_url antes de publicar.
-- No colocar secretos, service_role ni claves de proveedores en Flutter.
