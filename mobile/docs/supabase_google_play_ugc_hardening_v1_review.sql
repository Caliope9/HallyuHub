-- HallyuHub Google Play UGC hardening v1
-- REVIEW ONLY: do not execute without reviewing the deployed schema.
-- Adds backend authority for bilateral blocks, teen privacy and moderation.

begin;
set local search_path = pg_catalog, public;

do $$
declare
  required_table text;
begin
  foreach required_table in array array[
    'profiles', 'user_blocks', 'content_reports', 'posts', 'comments',
    'stories', 'drops', 'drop_comments', 'fancams', 'fancam_comments',
    'content_user_tags', 'conversations',
    'messages', 'communities', 'community_members', 'community_messages'
  ] loop
    if to_regclass('public.' || required_table) is null then
      raise exception 'required table is missing: public.%', required_table;
    end if;
  end loop;
end;
$$;

-- Prechecks de columnas críticas. No se crean columnas implícitamente aquí:
-- si el esquema base no coincide, la revisión se detiene con un error claro.
do $$
declare
  required_column record;
begin
  for required_column in
    select * from (values
      ('profiles', 'id'), ('profiles', 'birth_date'),
      ('profiles', 'private_profile'), ('profiles', 'message_privacy'),
      ('profiles', 'story_privacy'), ('profiles', 'enforcement_status'),
      ('profiles', 'enforcement_until'), ('profiles', 'role'),
      ('posts', 'author_id'), ('posts', 'status'), ('posts', 'deleted_at'),
      ('posts', 'updated_at'),
      ('comments', 'content_type'), ('comments', 'content_id'),
      ('comments', 'author_id'), ('comments', 'deleted_at'),
      ('comments', 'updated_at'),
      ('drop_comments', 'drop_id'), ('drop_comments', 'author_id'),
      ('drop_comments', 'deleted_at'), ('drop_comments', 'updated_at'),
      ('fancam_comments', 'fancam_id'), ('fancam_comments', 'author_id'),
      ('fancam_comments', 'deleted_at'), ('fancam_comments', 'updated_at'),
      ('stories', 'author_id'), ('stories', 'deleted_at'),
      ('stories', 'expires_at'), ('stories', 'archived_at'),
      ('stories', 'updated_at'),
      ('drops', 'author_id'), ('drops', 'status'), ('drops', 'deleted_at'),
      ('drops', 'updated_at'),
      ('fancams', 'author_id'), ('fancams', 'status'),
      ('fancams', 'deleted_at'), ('fancams', 'updated_at'),
      ('content_reports', 'id'), ('content_reports', 'reporter_id'),
      ('content_reports', 'reported_user_id'), ('content_reports', 'content_type'),
      ('content_reports', 'content_id'), ('content_reports', 'status'),
      ('content_reports', 'reason'), ('content_reports', 'metadata'),
      ('conversations', 'id'), ('conversations', 'created_by'),
      ('conversations', 'recipient_id'),
      ('messages', 'id'), ('messages', 'conversation_id'),
      ('community_members', 'community_id'), ('community_members', 'user_id'),
      ('community_messages', 'id'), ('community_messages', 'community_id'),
      ('community_messages', 'sender_id'),
      ('content_user_tags', 'tagged_by'), ('content_user_tags', 'tagged_user_id')
    ) as columns(table_name, column_name)
  loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = required_column.table_name
        and column_name = required_column.column_name
    ) then
      raise exception 'required column is missing: public.%.%',
        required_column.table_name, required_column.column_name;
    end if;
  end loop;
end;
$$;

create or replace function public.hallyu_users_blocked_v1(p_left uuid, p_right uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
    when auth.uid() is null
      or p_left is null or p_right is null or p_left = p_right
      or (p_left <> auth.uid() and p_right <> auth.uid()) then false
    else exists (
      select 1 from public.user_blocks
      where (blocker_id = p_left and blocked_id = p_right)
         or (blocker_id = p_right and blocked_id = p_left)
    )
  end;
$$;

create or replace function public.hallyu_conversation_blocked_v1(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.conversations c
    where c.id = p_conversation_id
      and (c.created_by = auth.uid() or c.recipient_id = auth.uid())
      and public.hallyu_users_blocked_v1(c.created_by, c.recipient_id)
  );
$$;

create or replace function public.hallyu_content_owner_v1(p_type text, p_content_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare v_owner uuid;
begin
  case p_type
    when 'post' then select author_id into v_owner from public.posts where id=p_content_id;
    when 'drop' then select author_id into v_owner from public.drops where id=p_content_id;
    when 'fancam' then select author_id into v_owner from public.fancams where id=p_content_id;
    else v_owner := null;
  end case;
  return v_owner;
end;
$$;

revoke all on function public.hallyu_users_blocked_v1(uuid, uuid) from public, anon, authenticated;
revoke all on function public.hallyu_conversation_blocked_v1(uuid) from public, anon, authenticated;
revoke all on function public.hallyu_content_owner_v1(text, uuid) from public, anon, authenticated;
grant execute on function public.hallyu_users_blocked_v1(uuid, uuid) to authenticated;
grant execute on function public.hallyu_conversation_blocked_v1(uuid) to authenticated;
grant execute on function public.hallyu_content_owner_v1(text, uuid) to authenticated;

-- Restrictive policies are ANDed with existing visibility/ownership policies.
-- They do not broaden access and preserve anonymous public pages.
drop policy if exists "blocks restrict posts" on public.posts;
create policy "blocks restrict posts" on public.posts as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), author_id));

drop policy if exists "blocks restrict comments" on public.comments;
create policy "blocks restrict comments" on public.comments as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), author_id));

drop policy if exists "blocks restrict comments insert" on public.comments;
create policy "blocks restrict comments insert" on public.comments as restrictive
for insert to authenticated
with check (
  content_type in ('post', 'drop', 'fancam')
  and not public.hallyu_users_blocked_v1(
    author_id,
    public.hallyu_content_owner_v1(content_type, content_id)
  )
);

drop policy if exists "blocks restrict drop comments" on public.drop_comments;
create policy "blocks restrict drop comments" on public.drop_comments as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), author_id));

drop policy if exists "blocks restrict drop comments insert" on public.drop_comments;
create policy "blocks restrict drop comments insert" on public.drop_comments as restrictive
for insert to authenticated
with check (
  not public.hallyu_users_blocked_v1(
    author_id,
    public.hallyu_content_owner_v1('drop', drop_id)
  )
);

drop policy if exists "blocks restrict fancam comments" on public.fancam_comments;
create policy "blocks restrict fancam comments" on public.fancam_comments as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), author_id));

drop policy if exists "blocks restrict fancam comments insert" on public.fancam_comments;
create policy "blocks restrict fancam comments insert" on public.fancam_comments as restrictive
for insert to authenticated
with check (
  not public.hallyu_users_blocked_v1(
    author_id,
    public.hallyu_content_owner_v1('fancam', fancam_id)
  )
);

drop policy if exists "blocks restrict stories" on public.stories;
create policy "blocks restrict stories" on public.stories as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), author_id));

drop policy if exists "blocks restrict drops" on public.drops;
create policy "blocks restrict drops" on public.drops as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), author_id));

drop policy if exists "blocks restrict fancams" on public.fancams;
create policy "blocks restrict fancams" on public.fancams as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), author_id));

drop policy if exists "blocks restrict user tags read" on public.content_user_tags;
create policy "blocks restrict user tags read" on public.content_user_tags as restrictive
for select to authenticated
using (
  not public.hallyu_users_blocked_v1(auth.uid(), tagged_by)
  and not public.hallyu_users_blocked_v1(auth.uid(), tagged_user_id)
);

drop policy if exists "blocks restrict user tags insert" on public.content_user_tags;
create policy "blocks restrict user tags insert" on public.content_user_tags as restrictive
for insert to authenticated
with check (not public.hallyu_users_blocked_v1(tagged_by, tagged_user_id));

drop policy if exists "blocks restrict conversations" on public.conversations;
create policy "blocks restrict conversations" on public.conversations as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(created_by, recipient_id));

drop policy if exists "blocks restrict conversation writes" on public.conversations;
create policy "blocks restrict conversation writes" on public.conversations as restrictive
for insert to authenticated
with check (not public.hallyu_users_blocked_v1(created_by, recipient_id));

drop policy if exists "blocks restrict messages read" on public.messages;
create policy "blocks restrict messages read" on public.messages as restrictive
for select to authenticated
using (not public.hallyu_conversation_blocked_v1(conversation_id));

drop policy if exists "blocks restrict messages insert" on public.messages;
create policy "blocks restrict messages insert" on public.messages as restrictive
for insert to authenticated
with check (not public.hallyu_conversation_blocked_v1(conversation_id));

drop policy if exists "blocks restrict communities" on public.communities;
create policy "blocks restrict communities" on public.communities as restrictive
for select to authenticated
using (
  owner_id is null
  or not public.hallyu_users_blocked_v1(auth.uid(), owner_id)
);

drop policy if exists "moderation hides communities anon" on public.communities;
create policy "moderation hides communities anon" on public.communities as restrictive
for select to anon
using (status = 'active');

drop policy if exists "moderation hides communities authenticated" on public.communities;
create policy "moderation hides communities authenticated" on public.communities as restrictive
for select to authenticated
using (
  status = 'active'
  or owner_id = auth.uid()
  or public.is_admin_or_moderator()
);

drop policy if exists "blocks restrict community membership" on public.community_members;
create policy "blocks restrict community membership" on public.community_members as restrictive
for insert to authenticated
with check (
  not exists (
    select 1 from public.communities c
    where c.id = community_id
      and public.hallyu_users_blocked_v1(user_id, c.owner_id)
  )
);

drop policy if exists "blocks restrict community membership read" on public.community_members;
create policy "blocks restrict community membership read" on public.community_members as restrictive
for select to authenticated
using (
  not exists (
    select 1
    from public.communities c
    where c.id = community_id
      and public.hallyu_users_blocked_v1(auth.uid(), c.owner_id)
  )
  and not public.hallyu_users_blocked_v1(auth.uid(), user_id)
);

drop policy if exists "blocks restrict community messages read" on public.community_messages;
create policy "blocks restrict community messages read" on public.community_messages as restrictive
for select to authenticated
using (not public.hallyu_users_blocked_v1(auth.uid(), sender_id));

drop policy if exists "blocks restrict community messages insert" on public.community_messages;
create policy "blocks restrict community messages insert" on public.community_messages as restrictive
for insert to authenticated
with check (
  not exists (
    select 1 from public.communities c
    where c.id = community_id
      and public.hallyu_users_blocked_v1(sender_id, c.owner_id)
  )
);

-- The deployed v1.3 trigger already protects INSERT. Add only the missing
-- UPDATE coverage, without creating a second INSERT enforcement trigger.
create or replace function public.hallyu_reject_non_active_ugc_updates_v1_3()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is not null and coalesce((
    select enforcement_status from public.profiles where id=auth.uid()
  ), 'banned') <> 'active' then
    raise exception 'account_not_allowed_to_update_ugc' using errcode='42501';
  end if;
  return new;
end;
$$;

do $$
declare target_table text;
begin
  foreach target_table in array array[
    'posts', 'comments', 'stories', 'drops', 'drop_comments', 'fancams',
    'fancam_comments', 'conversations', 'messages', 'communities',
    'community_members', 'community_messages', 'content_user_tags'
  ] loop
    execute format(
      'drop trigger if exists reject_non_active_ugc_updates_v1_3 on public.%I',
      target_table
    );
    execute format(
      'create trigger reject_non_active_ugc_updates_v1_3 before update on public.%I for each row execute function public.hallyu_reject_non_active_ugc_updates_v1_3()',
      target_table
    );
  end loop;
end;
$$;

revoke all on function public.hallyu_reject_non_active_ugc_updates_v1_3() from public, anon, authenticated;

-- Moderation fields for UGC that did not previously support soft removal.
alter table public.content_reports
  add column if not exists resolution_action text,
  add column if not exists resolution_note text not null default '',
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewer_id uuid references public.profiles(id) on delete set null;

alter table public.messages
  add column if not exists moderation_status text not null default 'active';
alter table public.community_messages
  add column if not exists moderation_status text not null default 'active';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.messages'::regclass
      and conname = 'messages_moderation_status_v1_check'
  ) then
    alter table public.messages add constraint messages_moderation_status_v1_check
      check (moderation_status in ('active', 'hidden')) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.community_messages'::regclass
      and conname = 'community_messages_moderation_status_v1_check'
  ) then
    alter table public.community_messages add constraint community_messages_moderation_status_v1_check
      check (moderation_status in ('active', 'hidden')) not valid;
  end if;
end;
$$;

drop policy if exists "moderation hides direct messages" on public.messages;
create policy "moderation hides direct messages" on public.messages as restrictive
for select to authenticated using (moderation_status = 'active');

drop policy if exists "moderation hides community messages" on public.community_messages;
create policy "moderation hides community messages" on public.community_messages as restrictive
for select to authenticated using (moderation_status = 'active');

drop policy if exists "moderation hides comments" on public.comments;
create policy "moderation hides comments" on public.comments as restrictive
for select using (deleted_at is null);

drop policy if exists "moderation hides drop comments" on public.drop_comments;
create policy "moderation hides drop comments" on public.drop_comments as restrictive
for select using (deleted_at is null);

drop policy if exists "moderation hides fancam comments" on public.fancam_comments;
create policy "moderation hides fancam comments" on public.fancam_comments as restrictive
for select using (deleted_at is null);

-- El worker anonimiza reporter_id antes de eliminar auth.users. La denuncia
-- conserva id, timestamps, status, motivo, metadata y el usuario reportado;
-- reporter_id NULL evita retener PII y no rompe la FK.
do $$
declare reporter_type text;
begin
  select udt_name into reporter_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'content_reports'
    and column_name = 'reporter_id';
  if reporter_type <> 'uuid' then
    raise exception 'content_reports.reporter_id must be uuid, found %', reporter_type;
  end if;
end;
$$;
alter table public.content_reports alter column reporter_id drop not null;

-- Reemplaza únicamente la FK reporter_id -> profiles(id), conservando la
-- fila de auditoría cuando el usuario reportante sea eliminado.
do $$
declare
  reporter_fk_name text;
  reporter_fk_count integer;
begin
  select count(*) into reporter_fk_count
  from pg_constraint c
  join pg_attribute child
    on child.attrelid = c.conrelid
   and child.attnum = any(c.conkey)
   and child.attname = 'reporter_id'
  join pg_attribute parent
    on parent.attrelid = c.confrelid
   and parent.attnum = any(c.confkey)
   and parent.attname = 'id'
  where c.conrelid = 'public.content_reports'::regclass
    and c.confrelid = 'public.profiles'::regclass
    and c.contype = 'f';
  if reporter_fk_count <> 1 then
    raise exception 'expected exactly one content_reports.reporter_id -> profiles(id) FK';
  end if;

  select c.conname into reporter_fk_name
  from pg_constraint c
  join pg_attribute child
    on child.attrelid = c.conrelid
   and child.attnum = any(c.conkey)
   and child.attname = 'reporter_id'
  join pg_attribute parent
    on parent.attrelid = c.confrelid
   and parent.attnum = any(c.confkey)
   and parent.attname = 'id'
  where c.conrelid = 'public.content_reports'::regclass
    and c.confrelid = 'public.profiles'::regclass
    and c.contype = 'f';

  if not exists (
    select 1 from pg_constraint c
    where c.conrelid = 'public.content_reports'::regclass
      and c.conname = 'content_reports_reporter_id_profiles_set_null_fkey'
      and c.confdeltype = 'n'
  ) then
    execute format(
      'alter table public.content_reports drop constraint %I', reporter_fk_name
    );
    alter table public.content_reports
      add constraint content_reports_reporter_id_profiles_set_null_fkey
      foreign key (reporter_id) references public.profiles(id) on delete set null;
  end if;
end;
$$;

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  report_id uuid references public.content_reports(id) on delete set null,
  target_user_id uuid references public.profiles(id) on delete set null,
  content_type text not null default '',
  content_id uuid,
  action text not null,
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.moderation_actions enable row level security;
revoke all on table public.moderation_actions from public, anon, authenticated;

create table if not exists public.user_enforcement_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  status text not null check (status in ('active', 'restricted', 'suspended', 'banned')),
  reason text not null,
  enforcement_until timestamptz,
  created_at timestamptz not null default now()
);
alter table public.user_enforcement_events enable row level security;
revoke all on table public.user_enforcement_events from public, anon, authenticated;

-- Los actores y el usuario sancionado se anonimizan al eliminar una cuenta;
-- la auditoría queda retenida sin una FK RESTRICT ni PII obligatoria.
alter table public.moderation_actions alter column actor_id drop not null;
alter table public.user_enforcement_events alter column user_id drop not null;
alter table public.user_enforcement_events alter column actor_id drop not null;

do $$
declare
  target record;
  fk_name text;
  fk_count integer;
begin
  for target in
    select * from (values
      ('moderation_actions', 'actor_id', 'moderation_actions_actor_id_profiles_set_null_fkey'),
      ('user_enforcement_events', 'user_id', 'user_enforcement_events_user_id_profiles_set_null_fkey'),
      ('user_enforcement_events', 'actor_id', 'user_enforcement_events_actor_id_profiles_set_null_fkey')
    ) as expected(table_name, column_name, constraint_name)
  loop
    select count(*) into fk_count
    from pg_constraint c
    join pg_attribute child
      on child.attrelid = c.conrelid
     and child.attnum = any(c.conkey)
     and child.attname = target.column_name
    join pg_attribute parent
      on parent.attrelid = c.confrelid
     and parent.attnum = any(c.confkey)
     and parent.attname = 'id'
    where c.conrelid = ('public.' || target.table_name)::regclass
      and c.confrelid = 'public.profiles'::regclass
      and c.contype = 'f';
    if fk_count <> 1 then
      raise exception 'expected exactly one %.% -> profiles(id) FK',
        target.table_name, target.column_name;
    end if;

    select c.conname into fk_name
    from pg_constraint c
    join pg_attribute child
      on child.attrelid = c.conrelid
     and child.attnum = any(c.conkey)
     and child.attname = target.column_name
    join pg_attribute parent
      on parent.attrelid = c.confrelid
     and parent.attnum = any(c.confkey)
     and parent.attname = 'id'
    where c.conrelid = ('public.' || target.table_name)::regclass
      and c.confrelid = 'public.profiles'::regclass
      and c.contype = 'f';

    if not exists (
      select 1 from pg_constraint c
      where c.conrelid = ('public.' || target.table_name)::regclass
        and c.conname = target.constraint_name
        and c.confdeltype = 'n'
    ) then
      execute format(
        'alter table public.%I drop constraint %I',
        target.table_name, fk_name
      );
      execute format(
        'alter table public.%I add constraint %I foreign key (%I) references public.profiles(id) on delete set null',
        target.table_name, target.constraint_name, target.column_name
      );
    end if;
  end loop;
end;
$$;

-- Si cualquiera de las tablas de auditoría ya existe con otra forma, no se
-- altera silenciosamente: el preflight falla antes de crear los RPC.
do $$
declare
  expected record;
  actual_type text;
begin
  for expected in
    select * from (values
      ('moderation_actions', 'id', 'uuid'),
      ('moderation_actions', 'actor_id', 'uuid'),
      ('moderation_actions', 'report_id', 'uuid'),
      ('moderation_actions', 'target_user_id', 'uuid'),
      ('moderation_actions', 'content_type', 'text'),
      ('moderation_actions', 'content_id', 'uuid'),
      ('moderation_actions', 'action', 'text'),
      ('moderation_actions', 'reason', 'text'),
      ('moderation_actions', 'metadata', 'jsonb'),
      ('moderation_actions', 'created_at', 'timestamptz'),
      ('user_enforcement_events', 'id', 'uuid'),
      ('user_enforcement_events', 'user_id', 'uuid'),
      ('user_enforcement_events', 'actor_id', 'uuid'),
      ('user_enforcement_events', 'status', 'text'),
      ('user_enforcement_events', 'reason', 'text'),
      ('user_enforcement_events', 'enforcement_until', 'timestamptz'),
      ('user_enforcement_events', 'created_at', 'timestamptz')
    ) as columns(table_name, column_name, expected_type)
  loop
    select udt_name into actual_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = expected.table_name
      and column_name = expected.column_name;
    if actual_type is null then
      raise exception 'incompatible audit table: public.%.% is missing',
        expected.table_name, expected.column_name;
    end if;
    if actual_type <> expected.expected_type then
      raise exception 'incompatible audit table: public.%.% must be %, found %',
        expected.table_name, expected.column_name, expected.expected_type, actual_type;
    end if;
  end loop;
end;
$$;

create or replace function public.hallyu_moderate_report_v1(
  p_report_id uuid,
  p_status text,
  p_action text default '',
  p_note text default ''
)
returns setof public.content_reports
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  r public.content_reports;
  v_now timestamptz := now();
begin
  if not public.is_admin_or_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'invalid_report_status';
  end if;
  select * into r from public.content_reports where id = p_report_id for update;
  if r.id is null then raise exception 'report_not_found'; end if;

  if p_action = 'hidden' then
    case lower(r.content_type)
      when 'post' then update public.posts set status='deleted', deleted_at=coalesce(deleted_at, v_now), updated_at=v_now where id=r.content_id;
      when 'drop' then update public.drops set status='deleted', deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'fancam' then update public.fancams set status='deleted', deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'comment' then update public.comments set deleted_at=coalesce(deleted_at, v_now), updated_at=v_now where id=r.content_id;
      when 'drop_comment' then update public.drop_comments set deleted_at=coalesce(deleted_at, v_now), updated_at=v_now where id=r.content_id;
      when 'fancam_comment' then update public.fancam_comments set deleted_at=coalesce(deleted_at, v_now), updated_at=v_now where id=r.content_id;
      when 'story' then update public.stories set deleted_at=coalesce(deleted_at, v_now), archived_at=coalesce(archived_at, v_now), expires_at=v_now, updated_at=v_now where id=r.content_id;
      when 'direct_message' then update public.messages set moderation_status='hidden' where id=r.content_id;
      when 'community_message' then update public.community_messages set moderation_status='hidden' where id=r.content_id;
      when 'community' then update public.communities set status='moderated', updated_at=v_now where id=r.content_id;
      else raise exception 'unsupported_content_type';
    end case;
  end if;

  update public.content_reports
  set status=p_status,
      reviewer_id=auth.uid(),
      reviewed_at=v_now,
      resolution_action=nullif(btrim(coalesce(p_action, '')), ''),
      resolution_note=btrim(coalesce(p_note, ''))
  where id=r.id;

  insert into public.moderation_actions(
    actor_id, report_id, target_user_id, content_type, content_id, action, reason
  ) values (
    auth.uid(), r.id, r.reported_user_id, r.content_type, r.content_id,
    coalesce(nullif(btrim(p_action), ''), 'report_' || p_status),
    coalesce(nullif(btrim(p_note), ''), 'Moderation report update')
  );

  return query select * from public.content_reports where id=r.id;
end;
$$;

create or replace function public.hallyu_admin_set_enforcement_v1(
  p_user_id uuid,
  p_status text,
  p_until timestamptz default null,
  p_reason text default ''
)
returns table(user_id uuid, status text, enforcement_until timestamptz)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.is_admin_or_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if p_user_id is null or p_user_id = auth.uid() then raise exception 'invalid_target_user'; end if;
  if p_status not in ('active', 'restricted', 'suspended', 'banned') then raise exception 'invalid_enforcement_status'; end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then raise exception 'enforcement_reason_required'; end if;
  if p_until is not null and p_until <= now() then raise exception 'enforcement_until_must_be_future'; end if;

  insert into public.user_enforcement_events(user_id, actor_id, status, reason, enforcement_until)
  values (p_user_id, auth.uid(), p_status, btrim(p_reason), p_until);

  insert into public.moderation_actions(actor_id, target_user_id, action, reason, metadata)
  values (auth.uid(), p_user_id, 'enforcement_' || p_status, btrim(p_reason), jsonb_build_object('until', p_until));

  return query
  update public.profiles p
  set enforcement_status=p_status, enforcement_until=p_until, updated_at=now()
  where p.id=p_user_id
  returning p.id, p.enforcement_status, p.enforcement_until;
end;
$$;

revoke all on function public.hallyu_moderate_report_v1(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.hallyu_admin_set_enforcement_v1(uuid, text, timestamptz, text) from public, anon, authenticated;
grant execute on function public.hallyu_moderate_report_v1(uuid, text, text, text) to authenticated;
grant execute on function public.hallyu_admin_set_enforcement_v1(uuid, text, timestamptz, text) to authenticated;

commit;
