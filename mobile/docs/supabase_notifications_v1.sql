-- HallyuHub Beta Real v1 - In-app notifications / campanita real.
-- Safe to run more than once. Does not delete users, content or messages.
-- This creates internal notifications only. It does not request native/browser push permissions.

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

create or replace function public.hallyu_profile_display_name(profile_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(nullif(name, ''), nullif(username, ''), 'Una fan')
  from public.profiles
  where id = profile_id
  limit 1
$$;

create or replace function public.hallyu_create_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_title text,
  p_body text,
  p_metadata jsonb default '{}'::jsonb,
  p_dedupe boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient_id is null then
    return;
  end if;

  if p_actor_id is not null and p_actor_id = p_recipient_id then
    return;
  end if;

  if p_dedupe then
    update public.notifications
    set
      title = coalesce(nullif(p_title, ''), title),
      body = coalesce(nullif(p_body, ''), body),
      metadata = coalesce(p_metadata, '{}'::jsonb),
      is_read = false,
      read_at = null,
      created_at = now()
    where recipient_id = p_recipient_id
      and coalesce(actor_id, '00000000-0000-0000-0000-000000000000'::uuid)
        = coalesce(p_actor_id, '00000000-0000-0000-0000-000000000000'::uuid)
      and type = p_type
      and entity_type = p_entity_type
      and (
        entity_id = p_entity_id
        or (entity_id is null and p_entity_id is null)
      )
      and created_at > now() - interval '7 days';

    if found then
      return;
    end if;
  end if;

  insert into public.notifications (
    recipient_id,
    actor_id,
    type,
    entity_type,
    entity_id,
    title,
    body,
    metadata
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_type,
    p_entity_type,
    p_entity_id,
    coalesce(nullif(p_title, ''), 'Notificación'),
    coalesce(nullif(p_body, ''), ''),
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

create or replace function public.hallyu_notify_follow_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  actor_name := public.hallyu_profile_display_name(new.follower_id);
  perform public.hallyu_create_notification(
    new.following_id,
    new.follower_id,
    'follow',
    'profile',
    new.follower_id,
    'Nuevo seguidor',
    actor_name || ' empezó a seguirte.',
    jsonb_build_object('actor_id', new.follower_id),
    true
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_post_comment_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
  actor_name text;
begin
  if new.content_type <> 'post' then
    return new;
  end if;

  select author_id into recipient_id
  from public.posts
  where id = new.content_id;

  actor_name := public.hallyu_profile_display_name(new.author_id);
  perform public.hallyu_create_notification(
    recipient_id,
    new.author_id,
    'post_comment',
    'post',
    new.content_id,
    'Nuevo comentario',
    actor_name || ' comentó tu publicación.',
    jsonb_build_object('comment_id', new.id, 'preview', left(new.body, 140)),
    false
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_drop_comment_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
  actor_name text;
begin
  select author_id into recipient_id
  from public.drops
  where id = new.drop_id;

  actor_name := public.hallyu_profile_display_name(new.author_id);
  perform public.hallyu_create_notification(
    recipient_id,
    new.author_id,
    'drop_comment',
    'drop',
    new.drop_id,
    'Nuevo comentario en tu Drop',
    actor_name || ' comentó tu Drop.',
    jsonb_build_object('comment_id', new.id, 'preview', left(new.body, 140)),
    false
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_fancam_comment_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
  actor_name text;
begin
  select author_id into recipient_id
  from public.fancams
  where id = new.fancam_id;

  actor_name := public.hallyu_profile_display_name(new.author_id);
  perform public.hallyu_create_notification(
    recipient_id,
    new.author_id,
    'fancam_comment',
    'fancam',
    new.fancam_id,
    'Nuevo comentario en tu Fancam',
    actor_name || ' comentó tu Fancam.',
    jsonb_build_object('comment_id', new.id, 'preview', left(new.body, 140)),
    false
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_post_like_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
  actor_name text;
begin
  select author_id into recipient_id
  from public.posts
  where id = new.post_id;

  actor_name := public.hallyu_profile_display_name(new.user_id);
  perform public.hallyu_create_notification(
    recipient_id,
    new.user_id,
    'post_like',
    'post',
    new.post_id,
    'Nueva estrella',
    actor_name || ' le dio una estrella a tu publicación.',
    '{}'::jsonb,
    true
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_drop_like_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
  actor_name text;
begin
  select author_id into recipient_id
  from public.drops
  where id = new.drop_id;

  actor_name := public.hallyu_profile_display_name(new.user_id);
  perform public.hallyu_create_notification(
    recipient_id,
    new.user_id,
    'drop_like',
    'drop',
    new.drop_id,
    'Nueva estrella en tu Drop',
    actor_name || ' le dio una estrella a tu Drop.',
    '{}'::jsonb,
    true
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_fancam_like_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
  actor_name text;
begin
  select author_id into recipient_id
  from public.fancams
  where id = new.fancam_id;

  actor_name := public.hallyu_profile_display_name(new.user_id);
  perform public.hallyu_create_notification(
    recipient_id,
    new.user_id,
    'fancam_like',
    'fancam',
    new.fancam_id,
    'Nueva estrella en tu Fancam',
    actor_name || ' le dio una estrella a tu Fancam.',
    '{}'::jsonb,
    true
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_user_tag_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  actor_name := public.hallyu_profile_display_name(new.tagged_by);
  perform public.hallyu_create_notification(
    new.tagged_user_id,
    new.tagged_by,
    'user_tag',
    new.content_type,
    new.content_id,
    'Te etiquetaron',
    actor_name || ' te etiquetó en contenido.',
    jsonb_build_object('content_type', new.content_type),
    true
  );
  return new;
end;
$$;

create or replace function public.hallyu_notify_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  member_row record;
  actor_name text;
  notification_type text;
  notification_title text;
  notification_body text;
  preview text;
begin
  actor_name := public.hallyu_profile_display_name(new.sender_id);
  notification_type := case
    when coalesce(new.story_preview, '') <> '' or new.story_id is not null
      then 'story_reply'
    else 'dm_message'
  end;
  notification_title := case
    when notification_type = 'story_reply' then 'Respondieron tu story'
    else 'Nuevo mensaje'
  end;
  notification_body := case
    when notification_type = 'story_reply'
      then actor_name || ' respondió a tu story.'
    else actor_name || ' te envió un mensaje.'
  end;
  preview := left(coalesce(nullif(new.body, ''), new.story_preview, ''), 160);

  for member_row in
    select user_id
    from public.conversation_members
    where conversation_id = new.conversation_id
      and user_id <> new.sender_id
  loop
    perform public.hallyu_create_notification(
      member_row.user_id,
      new.sender_id,
      notification_type,
      'conversation',
      new.conversation_id,
      notification_title,
      notification_body,
      jsonb_build_object(
        'message_id', new.id,
        'conversation_id', new.conversation_id,
        'preview', preview
      ),
      true
    );
  end loop;

  return new;
end;
$$;

do $$
begin
  if to_regclass('public.follows') is not null then
    drop trigger if exists hallyu_notifications_follow_insert on public.follows;
    create trigger hallyu_notifications_follow_insert
    after insert on public.follows
    for each row execute function public.hallyu_notify_follow_insert();
  end if;

  if to_regclass('public.comments') is not null then
    drop trigger if exists hallyu_notifications_post_comment_insert on public.comments;
    create trigger hallyu_notifications_post_comment_insert
    after insert on public.comments
    for each row execute function public.hallyu_notify_post_comment_insert();
  end if;

  if to_regclass('public.drop_comments') is not null then
    drop trigger if exists hallyu_notifications_drop_comment_insert on public.drop_comments;
    create trigger hallyu_notifications_drop_comment_insert
    after insert on public.drop_comments
    for each row execute function public.hallyu_notify_drop_comment_insert();
  end if;

  if to_regclass('public.fancam_comments') is not null then
    drop trigger if exists hallyu_notifications_fancam_comment_insert on public.fancam_comments;
    create trigger hallyu_notifications_fancam_comment_insert
    after insert on public.fancam_comments
    for each row execute function public.hallyu_notify_fancam_comment_insert();
  end if;

  if to_regclass('public.post_likes') is not null then
    drop trigger if exists hallyu_notifications_post_like_insert on public.post_likes;
    create trigger hallyu_notifications_post_like_insert
    after insert on public.post_likes
    for each row execute function public.hallyu_notify_post_like_insert();
  end if;

  if to_regclass('public.drop_likes') is not null then
    drop trigger if exists hallyu_notifications_drop_like_insert on public.drop_likes;
    create trigger hallyu_notifications_drop_like_insert
    after insert on public.drop_likes
    for each row execute function public.hallyu_notify_drop_like_insert();
  end if;

  if to_regclass('public.fancam_likes') is not null then
    drop trigger if exists hallyu_notifications_fancam_like_insert on public.fancam_likes;
    create trigger hallyu_notifications_fancam_like_insert
    after insert on public.fancam_likes
    for each row execute function public.hallyu_notify_fancam_like_insert();
  end if;

  if to_regclass('public.content_user_tags') is not null then
    drop trigger if exists hallyu_notifications_user_tag_insert on public.content_user_tags;
    create trigger hallyu_notifications_user_tag_insert
    after insert on public.content_user_tags
    for each row execute function public.hallyu_notify_user_tag_insert();
  end if;

  if to_regclass('public.messages') is not null then
    drop trigger if exists hallyu_notifications_message_insert on public.messages;
    create trigger hallyu_notifications_message_insert
    after insert on public.messages
    for each row execute function public.hallyu_notify_message_insert();
  end if;
end;
$$;

notify pgrst, 'reload schema';
