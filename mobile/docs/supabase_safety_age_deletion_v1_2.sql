-- HallyuHub safety/age/deletion v1.2 — CANDIDATO, NO EJECUTAR.
-- No deploy, no borrado de datos y no service_role. Aplicar manualmente solo
-- después de revisar el esquema desplegado.
begin;
set local search_path = pg_catalog, public;

do $$
begin
  if to_regclass('public.profiles') is null then raise exception 'profiles no existe'; end if;
  if to_regclass('public.account_deletion_requests') is null then raise exception 'account_deletion_requests no existe'; end if;
end;
$$;

alter table public.profiles
  add column if not exists birth_date date,
  add column if not exists enforcement_status text not null default 'active',
  add column if not exists enforcement_until timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_enforcement_status_v1_2_check') then
    alter table public.profiles add constraint profiles_enforcement_status_v1_2_check
      check (enforcement_status in ('active','restricted','suspended','banned')) not valid;
  end if;
end;
$$;

create or replace function public.hallyu_age_years_v1_2(p_birth_date date)
returns integer language sql stable strict set search_path = pg_catalog
as $$ select extract(year from age(current_date, p_birth_date))::integer $$;

create or replace function public.hallyu_validate_profile_security_v1_2()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_birth_date date := new.birth_date;
begin
  if v_birth_date is null then
    select nullif(u.raw_user_meta_data ->> 'birth_date', '')::date into v_birth_date
      from auth.users u where u.id = new.id;
    new.birth_date := v_birth_date;
  end if;
  if tg_op = 'INSERT' and v_birth_date is null then raise exception 'birth_date_required' using errcode = '23514'; end if;
  if v_birth_date is not null and v_birth_date > current_date then raise exception 'birth_date_in_future' using errcode = '23514'; end if;
  if v_birth_date is not null and public.hallyu_age_years_v1_2(v_birth_date) < 16 then raise exception 'minimum_age_required' using errcode = '23514'; end if;
  if tg_op = 'UPDATE' and old.birth_date is not null and new.birth_date is distinct from old.birth_date then raise exception 'birth_date_immutable' using errcode = '42501'; end if;
  if v_birth_date is not null and public.hallyu_age_years_v1_2(v_birth_date) between 16 and 17 then
    new.private_profile := true; new.message_privacy := 'Seguidores'; new.story_privacy := 'Seguidores';
  end if;
  if new.enforcement_status is null then new.enforcement_status := 'active'; end if;
  return new;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgrelid = 'public.profiles'::regclass and tgname = 'profiles_validate_security_v1_2') then
    create trigger profiles_validate_security_v1_2 before insert or update
      on public.profiles for each row execute function public.hallyu_validate_profile_security_v1_2();
  end if;
end;
$$;

-- A column revoke no supera un SELECT grant de tabla. Revocar tabla y conceder
-- solo columnas no sensibles mantiene las consultas explícitas existentes.
revoke select on table public.profiles from public, anon, authenticated;
grant select (id,email,name,username,bio,avatar_asset,avatar_url,fandom,country,language,phone,bias,favorite_group,phrase,content_region,private_profile,notifications_enabled,message_privacy,story_privacy,app_theme,profile_background,notify_messages,notify_stars,notify_comments,notify_followers,notify_drops,two_factor_enabled,login_alerts,account_verified,blocked_users,created_at,updated_at,role) on table public.profiles to authenticated;
grant select (id,name,username,bio,avatar_asset,avatar_url,fandom,country,language,bias,favorite_group,phrase,content_region,private_profile,created_at,updated_at) on table public.profiles to anon;
revoke select (birth_date,enforcement_status,enforcement_until) on table public.profiles from public, anon, authenticated;
revoke update (birth_date,enforcement_status,enforcement_until,role) on table public.profiles from public, anon, authenticated;

create or replace view public.public_profiles_v1_2 as
select id,name,username,bio,avatar_asset,avatar_url,fandom,country,language,bias,favorite_group,phrase,content_region,private_profile,created_at,updated_at from public.profiles;
revoke all on public.public_profiles_v1_2 from public;
grant select on public.public_profiles_v1_2 to anon, authenticated;

alter table public.account_deletion_requests add column if not exists recoverable_until timestamptz;
create or replace function public.hallyu_set_deletion_deadline_v1_2()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if new.requested_at is null then new.requested_at := now(); end if;
  if new.recoverable_until is null then new.recoverable_until := new.requested_at + interval '30 days'; end if;
  if new.recoverable_until <> new.requested_at + interval '30 days' then raise exception 'recoverable_until_must_be_server_derived'; end if;
  return new;
end;
$$;
do $$
begin
  if not exists (select 1 from pg_trigger where tgrelid = 'public.account_deletion_requests'::regclass and tgname = 'account_deletion_deadline_v1_2') then
    create trigger account_deletion_deadline_v1_2 before insert on public.account_deletion_requests for each row execute function public.hallyu_set_deletion_deadline_v1_2();
  end if;
end;
$$;

-- Las firmas RPC existentes no se reemplazan: sus RETURNS TABLE pueden ser
-- incompatibles. La migración controlada posterior debe devolver recoverable_until
-- y cancelar pending/in_review solo antes del deadline. Cambiar RETURNS TABLE
-- requiere DROP FUNCTION explícito en esa ventana; no se incluye ni ejecuta aquí.

create or replace function public.hallyu_current_enforcement_status_v1_2()
returns text language sql stable security definer set search_path = pg_catalog, public
as $$ select coalesce((select p.enforcement_status from public.profiles p where p.id = auth.uid()), 'banned') $$;
revoke all on function public.hallyu_current_enforcement_status_v1_2() from public, anon, authenticated;
grant execute on function public.hallyu_current_enforcement_status_v1_2() to authenticated;

create or replace function public.hallyu_reject_non_active_writes_v1_2()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is not null and public.hallyu_current_enforcement_status_v1_2() <> 'active' then raise exception 'account_not_allowed_to_create_content' using errcode = '42501'; end if;
  return new;
end;
$$;
do $$
declare t text;
begin
  foreach t in array array['posts','stories','comments','drops','drop_comments','fancams','fancam_comments','conversations','messages'] loop
    if to_regclass('public.' || t) is not null and not exists (select 1 from pg_trigger where tgrelid = ('public.' || t)::regclass and tgname = 'reject_non_active_writes_v1_2') then
      execute format('create trigger reject_non_active_writes_v1_2 before insert on public.%I for each row execute function public.hallyu_reject_non_active_writes_v1_2()', t);
    end if;
  end loop;
end;
$$;

create table if not exists public.content_safety_checks (
  id uuid primary key default gen_random_uuid(), content_type text not null, content_id uuid,
  verdict text not null check (verdict in ('safe','unsafe','needs_review','unavailable')),
  categories text[] not null default '{}', provider text not null default '', error_code text not null default '', created_at timestamptz not null default now()
);
alter table public.content_safety_checks enable row level security;
revoke all on table public.content_safety_checks from public, anon, authenticated;
commit;
