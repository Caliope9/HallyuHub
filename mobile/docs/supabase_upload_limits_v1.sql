-- HallyuHub Beta Real - limites de subida para buckets
-- Ejecutar en Supabase SQL Editor. Seguro para correr sobre datos existentes.
-- No borra tablas, archivos ni filas reales.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'avatars',
    'avatars',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'post_media',
    'post_media',
    true,
    104857600,
    array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'video/mp4',
      'video/quicktime',
      'video/webm'
    ]
  ),
  (
    'drop_media',
    'drop_media',
    true,
    104857600,
    array['video/mp4', 'video/quicktime', 'video/webm']
  ),
  (
    'fancam_media',
    'fancam_media',
    true,
    104857600,
    array['video/mp4', 'video/quicktime', 'video/webm']
  ),
  (
    'story_media',
    'story_media',
    true,
    52428800,
    array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'video/mp4',
      'video/quicktime',
      'video/webm'
    ]
  )
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
