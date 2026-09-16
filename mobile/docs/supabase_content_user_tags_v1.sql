-- HallyuHub Beta Real v1 - User tags for posts, stories, drops and fancams.
-- Safe to run more than once. Does not delete real data.

create table if not exists public.content_user_tags (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('post', 'story', 'drop', 'fancam')),
  content_id uuid not null,
  tagged_user_id uuid not null references public.profiles(id) on delete cascade,
  tagged_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (content_type, content_id, tagged_user_id)
);

create index if not exists content_user_tags_content_idx
  on public.content_user_tags (content_type, content_id);

create index if not exists content_user_tags_tagged_user_idx
  on public.content_user_tags (tagged_user_id, created_at desc);

create index if not exists content_user_tags_tagged_by_idx
  on public.content_user_tags (tagged_by, created_at desc);

alter table public.content_user_tags enable row level security;

drop policy if exists "content_user_tags_select_visible" on public.content_user_tags;
create policy "content_user_tags_select_visible"
on public.content_user_tags
for select
to authenticated
using (
  tagged_user_id = auth.uid()
  or tagged_by = auth.uid()
  or (
    content_type = 'post'
    and exists (
      select 1
      from public.posts p
      where p.id = content_user_tags.content_id
        and coalesce(p.status, 'published') = 'published'
    )
  )
  or (
    content_type = 'story'
    and exists (
      select 1
      from public.stories s
      where s.id = content_user_tags.content_id
        and s.expires_at > now()
        and (
          s.author_id = auth.uid()
          or exists (
            select 1
            from public.follows f
            where f.follower_id = auth.uid()
              and f.following_id = s.author_id
          )
        )
    )
  )
  or (
    content_type = 'drop'
    and exists (
      select 1
      from public.drops d
      where d.id = content_user_tags.content_id
        and coalesce(d.status, 'published') = 'published'
        and d.deleted_at is null
    )
  )
  or (
    content_type = 'fancam'
    and exists (
      select 1
      from public.fancams f
      where f.id = content_user_tags.content_id
        and coalesce(f.status, 'published') = 'published'
        and f.deleted_at is null
    )
  )
);

drop policy if exists "content_user_tags_insert_own_content" on public.content_user_tags;
create policy "content_user_tags_insert_own_content"
on public.content_user_tags
for insert
to authenticated
with check (
  tagged_by = auth.uid()
  and tagged_user_id <> auth.uid()
  and exists (
    select 1
    from public.profiles p
    where p.id = content_user_tags.tagged_user_id
  )
  and (
    (
      content_type = 'post'
      and exists (
        select 1
        from public.posts p
        where p.id = content_user_tags.content_id
          and p.author_id = auth.uid()
      )
    )
    or (
      content_type = 'story'
      and exists (
        select 1
        from public.stories s
        where s.id = content_user_tags.content_id
          and s.author_id = auth.uid()
      )
    )
    or (
      content_type = 'drop'
      and exists (
        select 1
        from public.drops d
        where d.id = content_user_tags.content_id
          and d.author_id = auth.uid()
      )
    )
    or (
      content_type = 'fancam'
      and exists (
        select 1
        from public.fancams f
        where f.id = content_user_tags.content_id
          and f.author_id = auth.uid()
      )
    )
  )
);

drop policy if exists "content_user_tags_delete_own_tags" on public.content_user_tags;
create policy "content_user_tags_delete_own_tags"
on public.content_user_tags
for delete
to authenticated
using (tagged_by = auth.uid());
