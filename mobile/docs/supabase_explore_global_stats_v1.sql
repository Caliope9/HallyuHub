-- HallyuHub Beta Real - metricas globales de Buscar/Explorar.
-- Seguro para correr varias veces. No borra datos reales.
-- Evita que los contadores dependan de las filas visibles por RLS para cada usuario.

create or replace function public.get_explore_global_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  total_beta_fans integer := null;
  total_events integer := null;
  total_drops_today integer := null;
  total_community_members integer := null;
  total_verified_stores integer := null;
  total_kpop_questions integer := null;
  has_created_at boolean := false;
  has_status boolean := false;
  has_deleted_at boolean := false;
  has_verified boolean := false;
  has_is_verified boolean := false;
begin
  if to_regclass('public.beta_access') is not null then
    select count(*)::integer
    into total_beta_fans
    from public.beta_access as ba
    where ba.status = 'approved';
  elsif to_regclass('public.profiles') is not null then
    select count(*)::integer
    into total_beta_fans
    from public.profiles as p;
  end if;

  if to_regclass('public.fan_events') is not null then
    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'fan_events'
        and column_name = 'status'
    )
    into has_status;

    if has_status then
      execute
        'select count(*)::integer from public.fan_events as fe where fe.status = ''published'''
      into total_events;
    else
      execute 'select count(*)::integer from public.fan_events as fe'
      into total_events;
    end if;
  end if;

  if to_regclass('public.drops') is not null then
    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'drops'
        and column_name = 'created_at'
    )
    into has_created_at;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'drops'
        and column_name = 'status'
    )
    into has_status;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'drops'
        and column_name = 'deleted_at'
    )
    into has_deleted_at;

    if has_created_at and has_status and has_deleted_at then
      execute
        'select count(*)::integer
         from public.drops as d
         where d.created_at >= date_trunc(''day'', now())
           and d.status = ''published''
           and d.deleted_at is null'
      into total_drops_today;
    elsif has_created_at and has_status then
      execute
        'select count(*)::integer
         from public.drops as d
         where d.created_at >= date_trunc(''day'', now())
           and d.status = ''published'''
      into total_drops_today;
    elsif has_created_at and has_deleted_at then
      execute
        'select count(*)::integer
         from public.drops as d
         where d.created_at >= date_trunc(''day'', now())
           and d.deleted_at is null'
      into total_drops_today;
    elsif has_created_at then
      execute
        'select count(*)::integer
         from public.drops as d
         where d.created_at >= date_trunc(''day'', now())'
      into total_drops_today;
    end if;
  end if;

  if to_regclass('public.community_members') is not null then
    select count(*)::integer
    into total_community_members
    from public.community_members as cm;
  end if;

  if to_regclass('public.verified_stores') is not null then
    execute 'select count(*)::integer from public.verified_stores as vs'
    into total_verified_stores;
  elsif to_regclass('public.stores') is not null then
    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'stores'
        and column_name = 'verified'
    )
    into has_verified;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'stores'
        and column_name = 'is_verified'
    )
    into has_is_verified;

    if has_verified then
      execute
        'select count(*)::integer from public.stores as s where s.verified = true'
      into total_verified_stores;
    elsif has_is_verified then
      execute
        'select count(*)::integer from public.stores as s where s.is_verified = true'
      into total_verified_stores;
    end if;
  elsif to_regclass('public.shops') is not null then
    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'shops'
        and column_name = 'verified'
    )
    into has_verified;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'shops'
        and column_name = 'is_verified'
    )
    into has_is_verified;

    if has_verified then
      execute
        'select count(*)::integer from public.shops as s where s.verified = true'
      into total_verified_stores;
    elsif has_is_verified then
      execute
        'select count(*)::integer from public.shops as s where s.is_verified = true'
      into total_verified_stores;
    end if;
  end if;

  if to_regclass('public.kpop101_questions') is not null then
    select count(*)::integer
    into total_kpop_questions
    from public.kpop101_questions as kq;
  end if;

  return jsonb_build_object(
    'total_beta_fans', total_beta_fans,
    'total_events', total_events,
    'total_drops_today', total_drops_today,
    'total_community_members', total_community_members,
    'total_verified_stores', total_verified_stores,
    'total_kpop_questions', total_kpop_questions
  );
end;
$$;

grant execute on function public.get_explore_global_stats() to anon;
grant execute on function public.get_explore_global_stats() to authenticated;

do $$
begin
  if to_regclass('public.beta_access') is not null
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'beta_access'
        and column_name = 'status'
    )
  then
    execute 'create index if not exists beta_access_status_idx on public.beta_access (status)';
  end if;

  if to_regclass('public.drops') is not null
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'drops'
        and column_name = 'created_at'
    )
  then
    execute 'create index if not exists drops_created_at_idx on public.drops (created_at desc)';
  end if;

  if to_regclass('public.fan_events') is not null
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'fan_events'
        and column_name = 'status'
    )
  then
    execute 'create index if not exists fan_events_status_idx on public.fan_events (status)';
  end if;
end;
$$;
