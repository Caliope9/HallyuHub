-- HallyuHub Beta Real - contadores agregados de seguidores K-pop.
-- Seguro para correr varias veces. No expone user_id ni perfiles seguidores.
-- No modifica ni borra follows existentes.

begin;

do $$
begin
  if to_regclass('public.kpop_entity_follows') is null then
    raise exception 'Falta public.kpop_entity_follows. Corré primero la migración de follows de entidades K-pop.';
  end if;
end $$;

create index if not exists kpop_entity_follows_entity_user_idx
  on public.kpop_entity_follows (entity_id, user_id);

create or replace function public.get_kpop_entity_follower_count(
  p_entity_id uuid
)
returns table (
  entity_id uuid,
  follower_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_entity_id as entity_id,
    (
      select count(*)::bigint
      from public.kpop_entity_follows as kef
      where kef.entity_id = p_entity_id
    ) as follower_count
  where p_entity_id is not null;
$$;

create or replace function public.get_kpop_entity_follower_counts(
  p_entity_ids uuid[]
)
returns table (
  entity_id uuid,
  follower_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with requested_entities as (
    select distinct requested.entity_id
    from unnest(coalesce(p_entity_ids, array[]::uuid[]))
      as requested(entity_id)
    where requested.entity_id is not null
  )
  select
    requested_entities.entity_id,
    count(kef.user_id)::bigint as follower_count
  from requested_entities
  left join public.kpop_entity_follows as kef
    on kef.entity_id = requested_entities.entity_id
  group by requested_entities.entity_id
  order by requested_entities.entity_id;
$$;

revoke all on function public.get_kpop_entity_follower_count(uuid)
  from public, anon, authenticated;
revoke all on function public.get_kpop_entity_follower_counts(uuid[])
  from public, anon, authenticated;

grant execute on function public.get_kpop_entity_follower_count(uuid)
  to authenticated;
grant execute on function public.get_kpop_entity_follower_counts(uuid[])
  to authenticated;

comment on function public.get_kpop_entity_follower_count(uuid) is
  'Devuelve únicamente el total agregado de seguidores para una entidad K-pop.';
comment on function public.get_kpop_entity_follower_counts(uuid[]) is
  'Devuelve únicamente totales agregados para varias entidades K-pop, incluyendo cero.';

commit;

-- Verificación segura posterior a la migración. No lista seguidores.
select
  to_regprocedure('public.get_kpop_entity_follower_count(uuid)') is not null
    as single_count_rpc_ready,
  to_regprocedure('public.get_kpop_entity_follower_counts(uuid[])') is not null
    as batch_count_rpc_ready,
  to_regclass('public.kpop_entity_follows_entity_user_idx') is not null
    as entity_user_index_ready;
