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

create or replace function public.hallyu_is_admin_or_moderator_v1()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and lower(coalesce(role, 'user')) in ('admin', 'moderator')
  );
$$;

create or replace function public.hallyu_users_blocked_v1(p_left uuid, p_right uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
    when p_left is null or p_right is null or p_left = p_right then false
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

revoke all on function public.hallyu_is_admin_or_moderator_v1() from public, anon, authenticated;
revoke all on function public.hallyu_users_blocked_v1(uuid, uuid) from public, anon, authenticated;
revoke all on function public.hallyu_conversation_blocked_v1(uuid) from public, anon, authenticated;
revoke all on function public.hallyu_content_owner_v1(text, uuid) from public, anon, authenticated;
grant execute on function public.hallyu_users_blocked_v1(uuid, uuid) to authenticated;
grant execute on function public.hallyu_conversation_blocked_v1(uuid) to authenticated;
grant execute on function public.hallyu_content_owner_v1(text, uuid) to authenticated;
grant execute on function public.hallyu_is_admin_or_moderator_v1() to authenticated;

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
  not public.hallyu_users_blocked_v1(
    author_id,
    public.hallyu_content_owner_v1('post', content_id)
  )
  and content_type = 'post'
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
  or public.hallyu_is_admin_or_moderator_v1()
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

-- Teen settings are enforced on every relevant update, not only at signup.
create or replace function public.hallyu_enforce_teen_privacy_v1()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.birth_date is null or new.birth_date > current_date then
    raise exception 'valid_birth_date_required' using errcode = '22007';
  end if;
  if new.birth_date > (current_date - interval '16 years')::date then
    raise exception 'minimum_age_16_required' using errcode = '23514';
  end if;
  if new.birth_date > (current_date - interval '18 years')::date then
    new.private_profile := true;
    new.message_privacy := 'Seguidores';
    new.story_privacy := 'Seguidores';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_enforce_teen_privacy_v1 on public.profiles;
create trigger profiles_enforce_teen_privacy_v1
before insert or update of birth_date, private_profile, message_privacy, story_privacy
on public.profiles
for each row execute function public.hallyu_enforce_teen_privacy_v1();

revoke all on function public.hallyu_enforce_teen_privacy_v1() from public, anon, authenticated;

-- Suspended/banned/restricted accounts cannot bypass Flutter with direct API
-- writes. Deletes remain available so users can remove their own content.
create or replace function public.hallyu_reject_enforced_ugc_writes_v1()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is not null and coalesce((
    select enforcement_status from public.profiles where id=auth.uid()
  ), 'banned') <> 'active' then
    raise exception 'account_not_allowed_to_write_ugc' using errcode='42501';
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
      'drop trigger if exists reject_enforced_ugc_writes_v1 on public.%I',
      target_table
    );
    execute format(
      'create trigger reject_enforced_ugc_writes_v1 before insert or update on public.%I for each row execute function public.hallyu_reject_enforced_ugc_writes_v1()',
      target_table
    );
  end loop;
end;
$$;

revoke all on function public.hallyu_reject_enforced_ugc_writes_v1() from public, anon, authenticated;

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

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id) on delete restrict,
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
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  status text not null check (status in ('active', 'restricted', 'suspended', 'banned')),
  reason text not null,
  enforcement_until timestamptz,
  created_at timestamptz not null default now()
);
alter table public.user_enforcement_events enable row level security;
revoke all on table public.user_enforcement_events from public, anon, authenticated;

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
  if not public.hallyu_is_admin_or_moderator_v1() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'invalid_report_status';
  end if;
  select * into r from public.content_reports where id = p_report_id for update;
  if r.id is null then raise exception 'report_not_found'; end if;

  if p_action = 'hidden' then
    case lower(r.content_type)
      when 'post' then update public.posts set status='deleted', deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'drop' then update public.drops set status='deleted', deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'fancam' then update public.fancams set status='deleted', deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'comment' then update public.comments set deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'drop_comment' then update public.drop_comments set deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'fancam_comment' then update public.fancam_comments set deleted_at=v_now, updated_at=v_now where id=r.content_id;
      when 'story' then update public.stories set deleted_at=v_now, archived_at=v_now, expires_at=v_now, updated_at=v_now where id=r.content_id;
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
  if not public.hallyu_is_admin_or_moderator_v1() then
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
