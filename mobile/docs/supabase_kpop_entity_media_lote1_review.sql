-- REVIEW ONLY — NO EJECUTAR AUTOMÁTICAMENTE.
-- Preparación de infraestructura para portadas de entidades K-pop.
-- No crea ni modifica perfiles, no carga archivos y no actualiza datos.

-- Bucket público únicamente para lectura de portadas ya publicadas.
-- Las cargas deben realizarse desde un proceso backend autorizado; Flutter
-- no debe recibir ni usar service_role.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'kpop_entity_media',
  'kpop_entity_media',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do nothing;

-- Lectura pública limitada al bucket dedicado.
create policy "kpop entity media public read"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'kpop_entity_media');

-- No se conceden INSERT, UPDATE ni DELETE a clientes.
-- La carga/reemplazo/eliminación debe ejecutarse exclusivamente desde backend.

-- Rutas previstas por el manifiesto:
-- kpop-entities/<normalized_name>/cover.<ext>
