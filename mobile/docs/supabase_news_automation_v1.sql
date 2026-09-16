-- HallyuHub Beta Real - Importacion automatica de noticias v1
-- Seguro: no borra tablas, filas ni noticias existentes.
-- Requisito: ejecutar antes docs/supabase_news_professional_v1.sql.
-- La Edge Function news-auto-import debe estar desplegada antes de correr esto.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

do $$
begin
  if to_regclass('public.news_items') is null then
    raise exception
      'Falta public.news_items. Ejecuta primero docs/supabase_news_professional_v1.sql';
  end if;

  if to_regprocedure('public.news_is_admin_or_moderator()') is null then
    raise exception
      'Falta public.news_is_admin_or_moderator(). Ejecuta primero docs/supabase_news_professional_v1.sql';
  end if;
end;
$$;

create table if not exists public.news_import_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running'
    check (status in ('running', 'success', 'partial', 'failed')),
  imported_count integer not null default 0,
  published_count integer not null default 0,
  rumor_count integer not null default 0,
  skipped_count integer not null default 0,
  error_message text,
  details jsonb not null default '{}'::jsonb
);

alter table public.news_items
  add column if not exists import_key text,
  add column if not exists content_fingerprint text,
  add column if not exists auto_published boolean not null default false,
  add column if not exists auto_update_locked boolean not null default false,
  add column if not exists quality_score integer,
  add column if not exists last_seen_at timestamptz,
  add column if not exists import_run_id uuid
    references public.news_import_runs(id) on delete set null,
  add column if not exists rejection_reason text;

create unique index if not exists news_items_import_key_unique_idx
on public.news_items (import_key)
where import_key is not null;

create unique index if not exists news_items_content_fingerprint_unique_idx
on public.news_items (content_fingerprint)
where content_fingerprint is not null;

create index if not exists news_items_auto_publication_idx
on public.news_items (auto_published, is_published, published_at desc);

create index if not exists news_items_import_run_idx
on public.news_items (import_run_id);

create index if not exists news_import_runs_started_idx
on public.news_import_runs (started_at desc);

create index if not exists news_import_runs_status_idx
on public.news_import_runs (status, started_at desc);

alter table public.news_import_runs enable row level security;

drop policy if exists "news import runs admin read"
on public.news_import_runs;

create policy "news import runs admin read"
on public.news_import_runs
for select
to authenticated
using (public.news_is_admin_or_moderator());

revoke all on public.news_import_runs from public, anon, authenticated;
grant select on public.news_import_runs to authenticated;

-- El backend seguro de Supabase escribe las importaciones.
-- Estos permisos no se entregan a Flutter ni a usuarios comunes.
grant select, insert, update on public.news_import_runs to service_role;
grant select, insert, update on public.news_items to service_role;

-- Se genera un secreto aleatorio dentro de Supabase Vault.
-- No se imprime, no se guarda en Flutter y no es la service_role key.
do $$
begin
  if not exists (
    select 1
    from vault.secrets s
    where s.name = 'news_cron_secret'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'news_cron_secret',
      'Secreto interno para el cron de noticias de HallyuHub'
    );
  end if;
end;
$$;

create or replace function public.verify_news_cron_secret(
  provided_secret text
)
returns boolean
language sql
stable
security definer
set search_path = public, vault, pg_temp
set row_security = off
as $$
  select
    nullif(provided_secret, '') is not null
    and exists (
      select 1
      from vault.decrypted_secrets s
      where s.name = 'news_cron_secret'
        and s.decrypted_secret = provided_secret
    );
$$;

revoke all on function public.verify_news_cron_secret(text)
from public, anon, authenticated;
grant execute on function public.verify_news_cron_secret(text)
to service_role;

-- Reemplaza solamente los jobs de noticias de esta migracion si ya existian.
do $$
begin
  if exists (
    select 1
    from cron.job j
    where j.jobname = 'hallyuhub-news-auto-import-40m'
  ) then
    perform cron.unschedule('hallyuhub-news-auto-import-40m');
  end if;

  if exists (
    select 1
    from cron.job j
    where j.jobname = 'hallyuhub-news-auto-import-hourly'
  ) then
    perform cron.unschedule('hallyuhub-news-auto-import-hourly');
  end if;
end;
$$;

select cron.schedule(
  'hallyuhub-news-auto-import-hourly',
  '0 * * * *',
  $cron$
    select net.http_post(
      url := 'https://utohoznutswcofruuong.supabase.co/functions/v1/news-auto-import',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          select s.decrypted_secret
          from vault.decrypted_secrets s
          where s.name = 'news_cron_secret'
          limit 1
        )
      ),
      body := jsonb_build_object(
        'trigger', 'scheduled',
        'requested_at', now()
      ),
      timeout_milliseconds := 60000
    ) as request_id;
  $cron$
);

-- Primera ejecucion inmediata para verificar la instalacion sin esperar 60 minutos.
select net.http_post(
  url := 'https://utohoznutswcofruuong.supabase.co/functions/v1/news-auto-import',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'x-cron-secret', (
      select s.decrypted_secret
      from vault.decrypted_secrets s
      where s.name = 'news_cron_secret'
      limit 1
    )
  ),
  body := jsonb_build_object(
    'trigger', 'installation',
    'requested_at', now()
  ),
  timeout_milliseconds := 60000
) as first_import_request_id;

comment on table public.news_import_runs is
'Registro tecnico de cada importacion automatica de noticias de HallyuHub.';

comment on column public.news_items.auto_published is
'True cuando una noticia completa fue publicada automaticamente por el backend.';

comment on column public.news_items.auto_update_locked is
'Permite al equipo editorial impedir que el importador modifique manualmente una noticia.';

comment on column public.news_items.quality_score is
'Puntaje interno de integridad y confiabilidad usado antes de publicar automaticamente.';

comment on column public.news_items.rejection_reason is
'Motivo por el cual una noticia importada quedo sin publicar.';
