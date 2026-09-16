-- HallyuHub Beta Real v1 - Mensajes reales
-- Ejecutar en Supabase SQL Editor antes de probar DMs reales.
-- No borra conversaciones ni mensajes existentes.

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  request_status text not null default 'pending' check (request_status in ('pending', 'accepted', 'rejected', 'blocked')),
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  unique (created_by, recipient_id),
  check (created_by <> recipient_id)
);

alter table public.conversations
  add column if not exists request_status text not null default 'pending',
  add column if not exists last_message_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  last_read_at timestamptz,
  muted boolean not null default false,
  archived boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  story_id uuid,
  story_preview text not null default '',
  media_url text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.messages
  add column if not exists story_id uuid,
  add column if not exists story_preview text not null default '',
  add column if not exists media_url text,
  add column if not exists read_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select constraint_info.conname
    from pg_constraint constraint_info
    join pg_attribute attribute_info
      on attribute_info.attrelid = constraint_info.conrelid
      and attribute_info.attnum = any(constraint_info.conkey)
    where constraint_info.conrelid = 'public.messages'::regclass
      and constraint_info.contype = 'f'
      and attribute_info.attname = 'story_id'
  loop
    execute format(
      'alter table public.messages drop constraint if exists %I',
      constraint_name
    );
  end loop;
end;
$$;

create index if not exists conversations_created_by_idx
  on public.conversations(created_by);
create index if not exists conversations_recipient_idx
  on public.conversations(recipient_id);
create index if not exists conversations_last_message_idx
  on public.conversations(last_message_at desc nulls last, created_at desc);
create index if not exists conversation_members_user_idx
  on public.conversation_members(user_id);
create index if not exists messages_conversation_created_idx
  on public.messages(conversation_id, created_at);

create or replace function public.handle_new_conversation_members()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.conversation_members (conversation_id, user_id, role)
  values
    (new.id, new.created_by, 'owner'),
    (new.id, new.recipient_id, 'member')
  on conflict (conversation_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_conversation_created_members on public.conversations;
create trigger on_conversation_created_members
after insert on public.conversations
for each row execute function public.handle_new_conversation_members();

insert into public.conversation_members (conversation_id, user_id, role)
select id, created_by, 'owner'
from public.conversations
on conflict (conversation_id, user_id) do nothing;

insert into public.conversation_members (conversation_id, user_id, role)
select id, recipient_id, 'member'
from public.conversations
on conflict (conversation_id, user_id) do nothing;

create or replace function public.handle_new_message_touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists on_message_touch_conversation on public.messages;
create trigger on_message_touch_conversation
after insert on public.messages
for each row execute function public.handle_new_message_touch_conversation();

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists "conversations participant read" on public.conversations;
drop policy if exists "conversations member read" on public.conversations;
create policy "conversations member read"
on public.conversations for select to authenticated
using (
  exists (
    select 1
    from public.conversation_members members
    where members.conversation_id = public.conversations.id
      and members.user_id = (select auth.uid())
  )
);

drop policy if exists "conversations creator insert" on public.conversations;
create policy "conversations creator insert"
on public.conversations for insert to authenticated
with check ((select auth.uid()) = created_by);

drop policy if exists "conversations participant update" on public.conversations;
drop policy if exists "conversations member update" on public.conversations;
create policy "conversations member update"
on public.conversations for update to authenticated
using (
  exists (
    select 1
    from public.conversation_members members
    where members.conversation_id = public.conversations.id
      and members.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.conversation_members members
    where members.conversation_id = public.conversations.id
      and members.user_id = (select auth.uid())
  )
);

drop policy if exists "conversation members self read" on public.conversation_members;
create policy "conversation members self read"
on public.conversation_members for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "conversation members creator insert" on public.conversation_members;
create policy "conversation members creator insert"
on public.conversation_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.conversations conversations
    where conversations.id = public.conversation_members.conversation_id
      and conversations.created_by = (select auth.uid())
  )
);

drop policy if exists "conversation members self update" on public.conversation_members;
create policy "conversation members self update"
on public.conversation_members for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "messages participant read" on public.messages;
drop policy if exists "messages member read" on public.messages;
create policy "messages member read"
on public.messages for select to authenticated
using (
  exists (
    select 1
    from public.conversation_members members
    where members.conversation_id = public.messages.conversation_id
      and members.user_id = (select auth.uid())
  )
);

drop policy if exists "messages participant insert" on public.messages;
drop policy if exists "messages member insert" on public.messages;
create policy "messages member insert"
on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and body <> ''
  and char_length(body) <= 1000
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

drop policy if exists "messages member update read state" on public.messages;
create policy "messages member update read state"
on public.messages for update to authenticated
using (
  exists (
    select 1
    from public.conversation_members members
    where members.conversation_id = public.messages.conversation_id
      and members.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.conversation_members members
    where members.conversation_id = public.messages.conversation_id
      and members.user_id = (select auth.uid())
  )
);
