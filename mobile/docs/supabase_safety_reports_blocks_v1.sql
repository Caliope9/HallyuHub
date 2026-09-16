-- HallyuHub Beta Real - Seguridad basica: reportes y bloqueos.
-- Ejecutar en Supabase SQL Editor.
-- Seguro para correr sobre una base existente: no borra datos.

create extension if not exists pgcrypto;

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete set null,
  content_type text not null,
  content_id uuid,
  reason text not null,
  details text not null default '',
  status text not null default 'pending',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewer_id uuid references public.profiles(id) on delete set null,
  constraint content_reports_status_check
    check (status in ('pending', 'reviewing', 'resolved', 'dismissed')),
  constraint content_reports_reason_check
    check (
      reason in (
        'spam',
        'harassment',
        'sexual_content',
        'violence_threats',
        'hate_discrimination',
        'scam_suspicious_sale',
        'misinformation',
        'copyright',
        'other'
      )
    ),
  constraint content_reports_not_self_profile_check
    check (
      content_type <> 'profile'
      or reported_user_id is null
      or reporter_id <> reported_user_id
    )
);

alter table public.content_reports
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table public.content_reports
  add column if not exists reviewed_at timestamptz;

alter table public.content_reports
  add column if not exists reviewer_id uuid references public.profiles(id) on delete set null;

create index if not exists content_reports_reporter_idx
  on public.content_reports (reporter_id, created_at desc);

create index if not exists content_reports_reported_user_idx
  on public.content_reports (reported_user_id, created_at desc);

create index if not exists content_reports_status_idx
  on public.content_reports (status, created_at desc);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_check check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_id, created_at desc);

alter table public.content_reports enable row level security;
alter table public.user_blocks enable row level security;

drop policy if exists "content reports insert own" on public.content_reports;
create policy "content reports insert own"
on public.content_reports
for insert
to authenticated
with check ((select auth.uid()) = reporter_id);

drop policy if exists "content reports read own" on public.content_reports;
create policy "content reports read own"
on public.content_reports
for select
to authenticated
using ((select auth.uid()) = reporter_id);

drop policy if exists "user blocks read own edges" on public.user_blocks;
create policy "user blocks read own edges"
on public.user_blocks
for select
to authenticated
using (
  (select auth.uid()) = blocker_id
  or (select auth.uid()) = blocked_id
);

drop policy if exists "user blocks insert own" on public.user_blocks;
create policy "user blocks insert own"
on public.user_blocks
for insert
to authenticated
with check ((select auth.uid()) = blocker_id and blocker_id <> blocked_id);

drop policy if exists "user blocks delete own" on public.user_blocks;
create policy "user blocks delete own"
on public.user_blocks
for delete
to authenticated
using ((select auth.uid()) = blocker_id);

notify pgrst, 'reload schema';
