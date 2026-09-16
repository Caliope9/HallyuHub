-- HallyuHub Beta Real v1 - Adjuntos en Mensajes/DM
-- Ejecutar en Supabase SQL Editor. Seguro para correr sobre datos existentes.
-- No borra conversaciones, mensajes ni archivos existentes.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'message_media',
  'message_media',
  false,
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

alter table public.messages
  add column if not exists media_type text not null default '',
  add column if not exists storage_bucket text not null default '',
  add column if not exists storage_path text not null default '',
  add column if not exists file_name text not null default '',
  add column if not exists file_size integer not null default 0,
  add column if not exists mime_type text not null default '';

alter table public.messages
  add column if not exists media_url text;

create index if not exists messages_media_path_idx
  on public.messages(storage_bucket, storage_path)
  where storage_path <> '';

drop policy if exists "messages member insert" on public.messages;
create policy "messages member insert"
on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and char_length(body) <= 1000
  and (
    body <> ''
    or coalesce(storage_path, '') <> ''
    or coalesce(media_url, '') <> ''
  )
  and media_type in ('', 'image', 'video')
  and (
    mime_type = ''
    or mime_type in (
      'image/jpeg',
      'image/png',
      'image/webp',
      'video/mp4',
      'video/quicktime',
      'video/webm'
    )
  )
  and file_size <= 52428800
  and exists (
    select 1
    from public.conversation_members members
    join public.conversations conversations
      on conversations.id = members.conversation_id
    where members.conversation_id = public.messages.conversation_id
      and members.user_id = (select auth.uid())
      and conversations.request_status in ('pending', 'accepted')
  )
);

drop policy if exists "message media member read" on storage.objects;
create policy "message media member read"
on storage.objects for select to authenticated
using (
  bucket_id = 'message_media'
  and array_length(storage.foldername(name), 1) >= 2
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1
    from public.conversation_members members
    where members.conversation_id = ((storage.foldername(name))[2])::uuid
      and members.user_id = (select auth.uid())
  )
);

drop policy if exists "message media upload conversation member" on storage.objects;
create policy "message media upload conversation member"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'message_media'
  and array_length(storage.foldername(name), 1) >= 2
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1
    from public.conversation_members members
    join public.conversations conversations
      on conversations.id = members.conversation_id
    where members.conversation_id = ((storage.foldername(name))[2])::uuid
      and members.user_id = (select auth.uid())
      and conversations.request_status in ('pending', 'accepted')
  )
);

drop policy if exists "message media update own folder" on storage.objects;
create policy "message media update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'message_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'message_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "message media delete own folder" on storage.objects;
create policy "message media delete own folder"
on storage.objects for delete to authenticated
using (
  bucket_id = 'message_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
