-- HallyuHub Beta Real - profile content categories / collections.
-- Safe to run more than once. Does not delete existing data.

create table if not exists public.content_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (
    content_type in ('post', 'drop', 'fancam', 'story')
  ),
  content_id uuid not null,
  category_key text not null check (
    category_key in (
      'concerts',
      'bias',
      'photocards',
      'outfit',
      'collection',
      'trades',
      'merch',
      'fanart',
      'other'
    )
  ),
  created_at timestamptz not null default now(),
  unique (user_id, content_type, content_id, category_key)
);

create index if not exists content_categories_user_idx
  on public.content_categories (user_id, category_key, created_at desc);

create index if not exists content_categories_content_idx
  on public.content_categories (content_type, content_id);

alter table public.content_categories enable row level security;

drop policy if exists "content_categories_select_visible" on public.content_categories;
create policy "content_categories_select_visible"
on public.content_categories
for select
to authenticated
using (
  user_id = auth.uid()
  or (
    content_type = 'post'
    and exists (
      select 1
      from public.posts p
      where p.id = content_id
        and p.author_id = user_id
        and coalesce(p.status, 'published') = 'published'
        and (
          lower(coalesce(p.privacy, 'todos')) in ('todos', 'publico', 'público', 'public')
          or p.author_id = auth.uid()
          or (
            lower(coalesce(p.privacy, 'todos')) in ('seguidores', 'followers')
            and exists (
              select 1
              from public.follows f
              where f.follower_id = auth.uid()
                and f.following_id = p.author_id
            )
          )
        )
    )
  )
  or (
    content_type = 'drop'
    and exists (
      select 1
      from public.drops d
      where d.id = content_id
        and d.author_id = user_id
        and coalesce(d.status, 'published') = 'published'
    )
  )
  or (
    content_type = 'fancam'
    and exists (
      select 1
      from public.fancams fc
      where fc.id = content_id
        and fc.author_id = user_id
        and coalesce(fc.status, 'published') = 'published'
    )
  )
);

drop policy if exists "content_categories_insert_own_content" on public.content_categories;
create policy "content_categories_insert_own_content"
on public.content_categories
for insert
to authenticated
with check (
  user_id = auth.uid()
  and (
    (
      content_type = 'post'
      and exists (
        select 1
        from public.posts p
        where p.id = content_id
          and p.author_id = auth.uid()
      )
    )
    or (
      content_type = 'drop'
      and exists (
        select 1
        from public.drops d
        where d.id = content_id
          and d.author_id = auth.uid()
      )
    )
    or (
      content_type = 'fancam'
      and exists (
        select 1
        from public.fancams fc
        where fc.id = content_id
          and fc.author_id = auth.uid()
      )
    )
  )
);

drop policy if exists "content_categories_update_own" on public.content_categories;
create policy "content_categories_update_own"
on public.content_categories
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "content_categories_delete_own" on public.content_categories;
create policy "content_categories_delete_own"
on public.content_categories
for delete
to authenticated
using (user_id = auth.uid());
