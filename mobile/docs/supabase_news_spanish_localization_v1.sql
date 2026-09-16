-- HallyuHub Beta Real - Noticias originalmente en español v1
-- Seguro: no borra tablas ni filas, no usa TRUNCATE y no toca usuarios.
-- Ejecutar antes de desplegar la version en español de news-auto-import.

begin;

do $$
begin
  if to_regclass('public.news_items') is null then
    raise exception
      'Falta public.news_items. Ejecuta primero docs/supabase_news_professional_v1.sql';
  end if;
end;
$$;

alter table public.news_items
  add column if not exists original_title text,
  add column if not exists original_summary text,
  add column if not exists original_language text,
  add column if not exists translation_status text,
  add column if not exists translated_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.news_items'::regclass
      and c.conname = 'news_items_translation_status_check'
  ) then
    alter table public.news_items
      add constraint news_items_translation_status_check
      check (
        translation_status is null
        or translation_status in (
          'not_required',
          'not_supported',
          'pending',
          'translated',
          'failed'
        )
      );
  end if;
end;
$$;

create index if not exists news_items_original_language_idx
on public.news_items (original_language, is_published, published_at desc);

create index if not exists news_items_translation_status_idx
on public.news_items (translation_status, is_published, published_at desc);

-- Conserva el texto que ya llego de cada fuente. No genera traducciones.
update public.news_items n
set
  original_title = coalesce(nullif(btrim(n.original_title), ''), n.title),
  original_summary = coalesce(
    nullif(btrim(n.original_summary), ''),
    nullif(btrim(coalesce(n.summary, '')), '')
  ),
  original_language = coalesce(
    nullif(lower(btrim(n.original_language)), ''),
    nullif(lower(btrim(n.language)), ''),
    'unknown'
  )
where n.original_title is null
   or n.original_summary is null
   or n.original_language is null;

-- Estas fuentes del importador anterior entregaban contenido original en inglés.
-- La corrección evita depender de un default histórico incorrecto en language.
update public.news_items n
set original_language = 'en'
where coalesce(n.rejection_reason, '') <> 'non_kpop'
  and (
    regexp_replace(
      lower(btrim(coalesce(n.source_domain, ''))),
      '^www\.',
      ''
    ) in (
      'soompi.com',
      'nme.com',
      'billboard.com'
    )
    or lower(coalesce(n.source_name, '')) in (
      'soompi',
      'nme',
      'billboard'
    )
  );

-- Las noticias que ya eran originalmente españolas no necesitan traducción.
update public.news_items n
set
  original_language = 'es',
  language = 'es',
  translation_status = 'not_required',
  translated_at = null
where lower(coalesce(nullif(n.original_language, ''), n.language, ''))
        in ('es', 'spa', 'es-es', 'es_419', 'es-419')
  and coalesce(n.rejection_reason, '') <> 'non_kpop';

-- Conserva pero oculta todo contenido cuyo idioma original no sea español.
-- Las filas non_kpop quedan fuera de este cambio para preservar su bloqueo.
update public.news_items n
set
  is_published = false,
  auto_published = false,
  auto_update_locked = true,
  translation_status = 'not_supported',
  translated_at = null,
  rejection_reason = case
    when nullif(btrim(coalesce(n.rejection_reason, '')), '') is null
      then 'language_not_supported'
    when n.rejection_reason = 'language_not_supported'
      then 'language_not_supported'
    else n.rejection_reason
  end
where lower(coalesce(nullif(n.original_language, ''), n.language, 'unknown'))
        not in ('es', 'spa', 'es-es', 'es_419', 'es-419')
  and coalesce(n.rejection_reason, '') <> 'non_kpop';

-- Esta migración no reemplaza get_public_news(integer, integer).
-- Las firmas declaradas en los SQL del proyecto coinciden, pero conservar la
-- función real evita cualquier riesgo si la base desplegada tiene otra firma.
-- La RPC existente deja de devolver noticias no españolas porque todas ellas
-- quedan con is_published = false en esta misma transacción.
do $$
begin
  if to_regprocedure('public.get_public_news(integer,integer)') is null then
    raise exception
      'Falta public.get_public_news(integer, integer). No se modificó la RPC';
  end if;
end;
$$;

comment on column public.news_items.original_title is
'Título exacto recibido de la fuente antes de cualquier limpieza editorial.';

comment on column public.news_items.original_summary is
'Extracto breve recibido del RSS. HallyuHub no almacena el artículo completo.';

comment on column public.news_items.original_language is
'Idioma detectado en el título y resumen originales.';

comment on column public.news_items.translation_status is
'En esta etapa solo se publica not_required. Otros idiomas quedan not_supported.';

do $$
begin
  if exists (
    select 1
    from public.news_items n
    where n.rejection_reason = 'non_kpop'
      and (
        n.is_published = true
        or n.auto_published = true
        or n.auto_update_locked is distinct from true
      )
  ) then
    raise exception
      'Hay noticias non_kpop que no conservan su ocultamiento y bloqueo';
  end if;

  if exists (
    select 1
    from public.news_items n
    where lower(coalesce(nullif(n.original_language, ''), n.language, ''))
          not in ('es', 'spa', 'es-es', 'es_419', 'es-419')
      and coalesce(n.rejection_reason, '') <> 'non_kpop'
      and (n.is_published = true or n.auto_published = true)
  ) then
    raise exception
      'Quedó publicada una noticia cuyo idioma original no es español';
  end if;

  if exists (
    select 1
    from public.news_items n
    where n.rejection_reason = 'language_not_supported'
      and n.auto_update_locked is distinct from true
  ) then
    raise exception
      'Hay noticias language_not_supported sin bloqueo de actualización';
  end if;
end;
$$;

commit;
