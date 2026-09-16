-- HallyuHub Beta Real - Feedback reports / support tickets v1
-- Safe to run multiple times. Does not drop, truncate, or delete real data.
-- Users can create and read their own reports. Admin/moderator can review all.

create extension if not exists "pgcrypto";

alter table public.profiles
  add column if not exists role text not null default 'user';

update public.profiles
set role = 'user'
where role is null
   or role not in ('user', 'moderator', 'admin');

alter table public.profiles
  alter column role set default 'user',
  alter column role set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check
      check (role in ('user', 'moderator', 'admin'));
  end if;
end $$;

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
      from public.profiles p
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

create table if not exists public.feedback_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  email text,
  type text not null,
  screen text,
  description text not null,
  status text not null default 'pending',
  priority text not null default 'normal',
  app_version text,
  platform text,
  device_info jsonb,
  related_content_type text,
  related_content_id uuid,
  attachment_url text,
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table public.feedback_reports
  add column if not exists user_id uuid references public.profiles(id) on delete set null,
  add column if not exists email text,
  add column if not exists type text not null default 'otro',
  add column if not exists screen text,
  add column if not exists description text not null default '',
  add column if not exists status text not null default 'pending',
  add column if not exists priority text not null default 'normal',
  add column if not exists app_version text,
  add column if not exists platform text,
  add column if not exists device_info jsonb,
  add column if not exists related_content_type text,
  add column if not exists related_content_id uuid,
  add column if not exists attachment_url text,
  add column if not exists admin_notes text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists resolved_at timestamptz;

update public.feedback_reports
set
  type = coalesce(nullif(type, ''), 'otro'),
  status = coalesce(nullif(status, ''), 'pending'),
  priority = coalesce(nullif(priority, ''), 'normal'),
  description = coalesce(description, ''),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, now());

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'feedback_reports_type_check'
      and conrelid = 'public.feedback_reports'::regclass
  ) then
    alter table public.feedback_reports
      add constraint feedback_reports_type_check
      check (type in (
        'video_audio',
        'upload',
        'login',
        'comentarios',
        'mensajes',
        'perfil',
        'carga_lenta',
        'app_se_cierra',
        'contenido_duplicado',
        'otro'
      ));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'feedback_reports_screen_check'
      and conrelid = 'public.feedback_reports'::regclass
  ) then
    alter table public.feedback_reports
      add constraint feedback_reports_screen_check
      check (
        screen is null
        or screen in (
          'posts',
          'drops',
          'fancams',
          'stories',
          'perfil',
          'mensajes',
          'comunidades',
          'beta_acceso',
          'otro'
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'feedback_reports_status_check'
      and conrelid = 'public.feedback_reports'::regclass
  ) then
    alter table public.feedback_reports
      add constraint feedback_reports_status_check
      check (status in (
        'pending',
        'reviewing',
        'resolved',
        'not_reproducible',
        'rejected'
      ));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'feedback_reports_priority_check'
      and conrelid = 'public.feedback_reports'::regclass
  ) then
    alter table public.feedback_reports
      add constraint feedback_reports_priority_check
      check (priority in ('low', 'normal', 'high', 'urgent'));
  end if;
end $$;

create index if not exists feedback_reports_user_id_idx
  on public.feedback_reports(user_id);

create index if not exists feedback_reports_status_idx
  on public.feedback_reports(status);

create index if not exists feedback_reports_type_idx
  on public.feedback_reports(type);

create index if not exists feedback_reports_screen_idx
  on public.feedback_reports(screen);

create index if not exists feedback_reports_priority_idx
  on public.feedback_reports(priority);

create index if not exists feedback_reports_created_at_idx
  on public.feedback_reports(created_at desc);

create index if not exists feedback_reports_email_idx
  on public.feedback_reports(lower(coalesce(email, '')));

create or replace function public.touch_feedback_reports_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  if new.status = 'resolved' and old.status is distinct from 'resolved' then
    new.resolved_at = coalesce(new.resolved_at, now());
  end if;
  if new.status is distinct from 'resolved' then
    new.resolved_at = null;
  end if;
  return new;
end;
$$;

drop trigger if exists feedback_reports_touch_updated_at
  on public.feedback_reports;

create trigger feedback_reports_touch_updated_at
before update on public.feedback_reports
for each row
execute function public.touch_feedback_reports_updated_at();

alter table public.feedback_reports enable row level security;

grant select, insert, update on public.feedback_reports to authenticated;

drop policy if exists "feedback reports self insert" on public.feedback_reports;
create policy "feedback reports self insert"
on public.feedback_reports
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "feedback reports self read" on public.feedback_reports;
create policy "feedback reports self read"
on public.feedback_reports
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "feedback reports admin read" on public.feedback_reports;
create policy "feedback reports admin read"
on public.feedback_reports
for select
to authenticated
using (public.is_admin_or_moderator());

drop policy if exists "feedback reports admin update" on public.feedback_reports;
create policy "feedback reports admin update"
on public.feedback_reports
for update
to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'feedback_attachments',
  'feedback_attachments',
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
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "feedback attachment owner upload"
  on storage.objects;
create policy "feedback attachment owner upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'feedback_attachments'
  and storage.foldername(name)[1] = auth.uid()::text
);

drop policy if exists "feedback attachment owner read"
  on storage.objects;
create policy "feedback attachment owner read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'feedback_attachments'
  and storage.foldername(name)[1] = auth.uid()::text
);

drop policy if exists "feedback attachment admin read"
  on storage.objects;
create policy "feedback attachment admin read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'feedback_attachments'
  and public.is_admin_or_moderator()
);

drop policy if exists "feedback attachment owner delete"
  on storage.objects;
create policy "feedback attachment owner delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'feedback_attachments'
  and storage.foldername(name)[1] = auth.uid()::text
);

notify pgrst, 'reload schema';
