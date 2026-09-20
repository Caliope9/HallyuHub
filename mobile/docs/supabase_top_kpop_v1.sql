-- HallyuHub Top K-pop ranking.
-- Prepare locally; do not apply until the production schema is approved.
-- Counts come only from public.kpop_entity_follows.

create or replace function public.hallyu_top_kpop_v1(
  p_type text,
  p_limit integer,
  p_offset integer
)
returns table (
  entity_id uuid,
  entity_type text,
  name text,
  image_url text,
  is_verified boolean,
  follower_count bigint,
  is_following boolean
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  with requested as (
    select
      p_type as requested_type,
      p_limit as requested_limit,
      p_offset as requested_offset
  ),
  ranked as (
    select
      e.id as entity_id,
      e.entity_type,
      e.name,
      e.image_url,
      e.is_verified,
      count(f.user_id)::bigint as follower_count,
      exists (
        select 1
        from public.kpop_entity_follows mine
        where mine.entity_id = e.id
          and mine.user_id = auth.uid()
      ) as is_following
    from public.kpop_entities e
    left join public.kpop_entity_follows f
      on f.entity_id = e.id
    cross join requested r
    where auth.uid() is not null
      and r.requested_type in ('group', 'artist')
      and r.requested_limit between 1 and 50
      and r.requested_offset >= 0
      and e.status = 'verified'
      and (
        (r.requested_type = 'group' and e.entity_type = 'group')
        or (
          r.requested_type = 'artist'
          and e.entity_type in ('artist', 'idol')
        )
      )
    group by e.id, e.entity_type, e.name, e.image_url, e.is_verified
  )
  select
    ranked.entity_id,
    ranked.entity_type,
    ranked.name,
    ranked.image_url,
    ranked.is_verified,
    ranked.follower_count,
    ranked.is_following
  from ranked
  order by ranked.follower_count desc, ranked.name asc, ranked.entity_id asc
  limit (select requested_limit from requested)
  offset (select requested_offset from requested);
$$;

alter function public.hallyu_top_kpop_v1(text, integer, integer)
  owner to postgres;

revoke all on function public.hallyu_top_kpop_v1(text, integer, integer)
  from public;
revoke all on function public.hallyu_top_kpop_v1(text, integer, integer)
  from anon;
revoke all on function public.hallyu_top_kpop_v1(text, integer, integer)
  from authenticated;
grant execute on function public.hallyu_top_kpop_v1(text, integer, integer)
  to authenticated;
