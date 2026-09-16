-- HallyuHub Beta Real - notifications repair 2026-06-25.
-- Safe to run more than once. Does not delete users, content, messages or notifications.
-- Purpose:
-- 1) keep the existing trigger/RPC notification path callable from the app
-- 2) allow the authenticated app client to create a notification as a fallback
--    only when actor_id is the current user and recipient_id is another profile.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  entity_type text not null default '',
  entity_id uuid,
  title text not null default 'Notificación',
  body text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications
  add column if not exists actor_id uuid references public.profiles(id) on delete set null,
  add column if not exists type text not null default 'activity',
  add column if not exists entity_type text not null default '',
  add column if not exists entity_id uuid,
  add column if not exists title text not null default 'Notificación',
  add column if not exists body text not null default '',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists is_read boolean not null default false,
  add column if not exists read_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

create index if not exists notifications_recipient_created_idx
  on public.notifications (recipient_id, created_at desc);

create index if not exists notifications_recipient_unread_idx
  on public.notifications (recipient_id, is_read, created_at desc);

create index if not exists notifications_entity_idx
  on public.notifications (entity_type, entity_id);

alter table public.notifications enable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update on public.notifications to authenticated;

drop policy if exists "notifications self read" on public.notifications;
create policy "notifications self read"
on public.notifications
for select
to authenticated
using (recipient_id = auth.uid());

drop policy if exists "notifications self mark read" on public.notifications;
create policy "notifications self mark read"
on public.notifications
for update
to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

drop policy if exists "notifications actor insert fallback" on public.notifications;
create policy "notifications actor insert fallback"
on public.notifications
for insert
to authenticated
with check (
  actor_id = auth.uid()
  and recipient_id <> auth.uid()
);

do $$
begin
  if to_regprocedure(
    'public.hallyu_create_notification(uuid,uuid,text,text,uuid,text,text,jsonb,boolean)'
  ) is not null then
    grant execute on function public.hallyu_create_notification(
      uuid,
      uuid,
      text,
      text,
      uuid,
      text,
      text,
      jsonb,
      boolean
    ) to anon, authenticated;
  end if;
end;
$$;

notify pgrst, 'reload schema';

-- Optional checks after running:
-- select id, recipient_id, actor_id, type, entity_type, entity_id, title, body, is_read, created_at
-- from public.notifications
-- order by created_at desc
-- limit 20;
--
-- select tgname, tgrelid::regclass::text as table_name
-- from pg_trigger
-- where tgname like 'hallyu_notifications_%'
--   and not tgisinternal
-- order by table_name, tgname;
