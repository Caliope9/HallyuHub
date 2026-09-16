-- HallyuHub safety/age/deletion v1.3 — CANDIDATO FINAL, NO EJECUTAR.
-- Autocontenido desde el estado real v1/v1.1/v1.2. No deploy, no datos reales.
-- La transacción no contiene DELETE de datos, TRUNCATE ni UPDATE masivo.

begin;
set local search_path = pg_catalog, public;

do $$
begin
  if to_regclass('public.profiles') is null then raise exception 'profiles no existe'; end if;
  if to_regclass('public.account_deletion_requests') is null then raise exception 'account_deletion_requests no existe'; end if;
  if to_regprocedure('gen_random_uuid()') is null then raise exception 'gen_random_uuid() no disponible'; end if;
end;
$$;

-- Edad y enforcement, sin tocar filas existentes.
alter table public.profiles
  add column if not exists birth_date date,
  add column if not exists enforcement_status text not null default 'active',
  add column if not exists enforcement_until timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.profiles'::regclass and conname='profiles_enforcement_status_v1_3_check') then
    alter table public.profiles add constraint profiles_enforcement_status_v1_3_check
      check (enforcement_status in ('active','restricted','suspended','banned')) not valid;
  end if;
end;
$$;

create or replace function public.hallyu_age_years_v1_3(p_birth_date date)
returns integer language sql stable strict set search_path=pg_catalog
as $$ select extract(year from age(current_date,p_birth_date))::integer $$;

create or replace function public.hallyu_validate_profile_security_v1_3()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$
declare v_birth_date date := new.birth_date;
begin
  if v_birth_date is null then
    select nullif(u.raw_user_meta_data->>'birth_date','')::date into v_birth_date from auth.users u where u.id=new.id;
    new.birth_date := v_birth_date;
  end if;
  if tg_op='INSERT' and v_birth_date is null then raise exception 'birth_date_required' using errcode='23514'; end if;
  if v_birth_date is not null and v_birth_date>current_date then raise exception 'birth_date_in_future' using errcode='23514'; end if;
  if v_birth_date is not null and public.hallyu_age_years_v1_3(v_birth_date)<16 then raise exception 'minimum_age_required' using errcode='23514'; end if;
  if tg_op='UPDATE' and old.birth_date is not null and new.birth_date is distinct from old.birth_date then raise exception 'birth_date_immutable' using errcode='42501'; end if;
  if v_birth_date is not null and public.hallyu_age_years_v1_3(v_birth_date) between 16 and 17 then
    new.private_profile:=true; new.message_privacy:='Seguidores'; new.story_privacy:='Seguidores';
  end if;
  if new.enforcement_status is null then new.enforcement_status:='active'; end if;
  return new;
end;
$$;
do $$
begin
  if not exists (select 1 from pg_trigger where tgrelid='public.profiles'::regclass and tgname='profiles_validate_security_v1_3') then
    create trigger profiles_validate_security_v1_3 before insert or update on public.profiles for each row execute function public.hallyu_validate_profile_security_v1_3();
  end if;
end;
$$;

-- SELECT por columnas: evita que SELECT * exponga birth_date.
revoke select on table public.profiles from public,anon,authenticated;
grant select (id,name,username,bio,avatar_asset,avatar_url,fandom,country,region,city,language,bias,favorite_group,phrase,content_region,location_visibility,private_profile,created_at,updated_at) on table public.profiles to anon,authenticated;
revoke select (birth_date,enforcement_status,enforcement_until) on table public.profiles from public,anon,authenticated;
revoke update on table public.profiles from public,anon,authenticated;
grant update (name,username,bio,avatar_asset,avatar_url,fandom,country,region,city,language,bias,favorite_group,phrase,content_region,location_visibility,location_updated_at,private_profile,notifications_enabled,message_privacy,story_privacy,app_theme,profile_background,notify_messages,notify_stars,notify_comments,notify_followers,notify_drops,terms_accepted_at,privacy_accepted_at,community_guidelines_accepted_at,beta_notice_accepted_at,legal_version) on table public.profiles to authenticated;
create or replace view public.public_profiles_v1_3 with (security_invoker=true) as
  select id,name,username,bio,avatar_asset,avatar_url,fandom,country,region,city,language,bias,favorite_group,phrase,content_region,location_visibility,private_profile,created_at,updated_at from public.profiles;
revoke all on public.public_profiles_v1_3 from public;
grant select on public.public_profiles_v1_3 to anon,authenticated;

-- RPC existente para el propio usuario: permite leer los campos privados solo
-- al dueño sin concederlos en profiles ni exponerlos por select(*).
create or replace function public.get_my_profile_settings()
returns jsonb language sql stable security definer set search_path=pg_catalog,public
as $$
  select to_jsonb(profile_row) from (
    select id,email,name,username,bio,avatar_asset,avatar_url,fandom,country,region,city,language,phone,bias,favorite_group,phrase,content_region,location_visibility,location_updated_at,private_profile,notifications_enabled,message_privacy,story_privacy,app_theme,profile_background,notify_messages,notify_stars,notify_comments,notify_followers,notify_drops,two_factor_enabled,login_alerts,account_verified,blocked_users,terms_accepted_at,privacy_accepted_at,community_guidelines_accepted_at,beta_notice_accepted_at,legal_version,role,birth_date,enforcement_status,enforcement_until,created_at,updated_at
    from public.profiles where id=auth.uid() limit 1
  ) profile_row;
$$;
revoke all on function public.get_my_profile_settings() from public,anon;
grant execute on function public.get_my_profile_settings() to authenticated;

-- Supabase Auth Before User Created Hook. Preparado, pero no activado.
create or replace function public.hallyu_before_user_created_v1_3(p_event jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public
as $$
declare
  raw_birth_date text := nullif(p_event #>> '{user,user_metadata,birth_date}','');
  birth_date_value date;
begin
  if raw_birth_date is null then
    return jsonb_build_object('error',jsonb_build_object('http_code',400,'message','birth_date is required'));
  end if;
  if raw_birth_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return jsonb_build_object('error',jsonb_build_object('http_code',400,'message','birth_date is invalid'));
  end if;
  begin
    birth_date_value := substring(raw_birth_date from 1 for 10)::date;
  exception when others then
    return jsonb_build_object('error',jsonb_build_object('http_code',400,'message','birth_date is invalid'));
  end;
  if birth_date_value > current_date then
    return jsonb_build_object('error',jsonb_build_object('http_code',400,'message','birth_date cannot be in the future'));
  end if;
  if extract(year from age(current_date,birth_date_value))::integer < 16 then
    return jsonb_build_object('error',jsonb_build_object('http_code',403,'message','HallyuHub is available from age 16'));
  end if;
  return '{}'::jsonb;
end;
$$;
revoke all on function public.hallyu_before_user_created_v1_3(jsonb) from public,anon,authenticated;
grant execute on function public.hallyu_before_user_created_v1_3(jsonb) to supabase_auth_admin;

-- FK puntual: conserva solicitudes y permite que el worker ponga user_id NULL.
do $$
declare c text; fk_count integer;
begin
  select count(*) into fk_count
  from pg_constraint c
  join pg_attribute child on child.attrelid=c.conrelid and child.attnum=any(c.conkey) and child.attname='user_id'
  join pg_attribute parent on parent.attrelid=c.confrelid and parent.attnum=any(c.confkey) and parent.attname='id'
  where c.conrelid='public.account_deletion_requests'::regclass and c.confrelid='auth.users'::regclass and c.contype='f';
  if fk_count <> 1 then raise exception 'expected exactly one account_deletion_requests.user_id -> auth.users(id) FK'; end if;
  select c.conname into c
  from pg_constraint c
  join pg_attribute child on child.attrelid=c.conrelid and child.attnum=any(c.conkey) and child.attname='user_id'
  join pg_attribute parent on parent.attrelid=c.confrelid and parent.attnum=any(c.confkey) and parent.attname='id'
  where c.conrelid='public.account_deletion_requests'::regclass and c.confrelid='auth.users'::regclass and c.contype='f';
  if not exists (select 1 from pg_constraint c where c.conrelid='public.account_deletion_requests'::regclass and c.conname='account_deletion_requests_user_id_set_null_fkey' and c.confdeltype='n') then
    execute format('alter table public.account_deletion_requests drop constraint %I', c);
    alter table public.account_deletion_requests add constraint account_deletion_requests_user_id_set_null_fkey foreign key(user_id) references auth.users(id) on delete set null;
  end if;
end;
$$;
alter table public.account_deletion_requests alter column user_id drop not null;
alter table public.account_deletion_requests add column if not exists recoverable_until timestamptz;
alter table public.account_deletion_requests add column if not exists processing_token uuid;
alter table public.account_deletion_requests add column if not exists processing_started_at timestamptz;

-- Solo pendientes/en revisión antiguos reciben deadline server-side. No se
-- tocan completed ni canceled y cada fila se actualiza individualmente.
do $$
declare r record;
begin
  for r in select id,requested_at from public.account_deletion_requests where status in ('pending','in_review') and recoverable_until is null loop
    update public.account_deletion_requests set recoverable_until=r.requested_at+interval '30 days' where id=r.id and status in ('pending','in_review') and recoverable_until is null;
  end loop;
end;
$$;

create or replace function public.hallyu_set_deletion_deadline_v1_3()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$
begin
  if new.requested_at is null then new.requested_at:=now(); end if;
  if new.recoverable_until is null then new.recoverable_until:=new.requested_at+interval '30 days'; end if;
  if new.recoverable_until<>new.requested_at+interval '30 days' then raise exception 'recoverable_until_must_be_server_derived'; end if;
  return new;
end;
$$;
do $$
begin
  if not exists (select 1 from pg_trigger where tgrelid='public.account_deletion_requests'::regclass and tgname='account_deletion_deadline_v1_3') then
    create trigger account_deletion_deadline_v1_3 before insert on public.account_deletion_requests for each row execute function public.hallyu_set_deletion_deadline_v1_3();
  end if;
end;
$$;

-- RPC de usuario: mismos nombres y parámetros; retorno ampliado con deadline.
drop function if exists public.hallyu_request_account_deletion(text,boolean);
create function public.hallyu_request_account_deletion(p_reason text default '',p_export_requested boolean default false)
returns table(id uuid,status text,requested_at timestamptz,reviewed_at timestamptz,completed_at timestamptz,canceled_at timestamptz,requested_scope text,export_requested boolean,recoverable_until timestamptz)
language plpgsql security definer set search_path=pg_catalog,public
as $$
declare u uuid:=auth.uid(); r public.account_deletion_requests;
begin
  if u is null then raise exception 'authentication_required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
  select * into r from public.account_deletion_requests where user_id=u and status in ('pending','in_review') order by requested_at desc limit 1 for update;
  if r.id is null then insert into public.account_deletion_requests(user_id,reason,export_requested) values (u,left(coalesce(p_reason,''),2000),coalesce(p_export_requested,false)) returning * into r; end if;
  return query select r.id,r.status,r.requested_at,r.reviewed_at,r.completed_at,r.canceled_at,r.requested_scope,r.export_requested,r.recoverable_until;
end;
$$;

drop function if exists public.hallyu_get_account_deletion_status();
create function public.hallyu_get_account_deletion_status()
returns table(id uuid,status text,requested_at timestamptz,reviewed_at timestamptz,completed_at timestamptz,canceled_at timestamptz,requested_scope text,export_requested boolean,recoverable_until timestamptz)
language sql stable security definer set search_path=pg_catalog,public
as $$ select r.id,r.status,r.requested_at,r.reviewed_at,r.completed_at,r.canceled_at,r.requested_scope,r.export_requested,r.recoverable_until from public.account_deletion_requests r where r.user_id=auth.uid() order by r.requested_at desc limit 1 $$;

drop function if exists public.hallyu_cancel_account_deletion(uuid);
create function public.hallyu_cancel_account_deletion(p_request_id uuid)
returns table(id uuid,status text,canceled_at timestamptz,requested_at timestamptz,reviewed_at timestamptz,completed_at timestamptz,requested_scope text,export_requested boolean,recoverable_until timestamptz)
language plpgsql security definer set search_path=pg_catalog,public
as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  return query update public.account_deletion_requests r set status='canceled',canceled_at=now(),processing_token=null,processing_started_at=null
    where r.id=p_request_id and r.user_id=auth.uid() and r.status in ('pending','in_review') and r.recoverable_until is not null and now()<=r.recoverable_until and r.processing_token is null
    returning r.id,r.status,r.canceled_at,r.requested_at,r.reviewed_at,r.completed_at,r.requested_scope,r.export_requested,r.recoverable_until;
end;
$$;
revoke all on function public.hallyu_request_account_deletion(text,boolean) from public,anon,authenticated;
revoke all on function public.hallyu_get_account_deletion_status() from public,anon,authenticated;
revoke all on function public.hallyu_cancel_account_deletion(uuid) from public,anon,authenticated;
grant execute on function public.hallyu_request_account_deletion(text,boolean) to authenticated;
grant execute on function public.hallyu_get_account_deletion_status() to authenticated;
grant execute on function public.hallyu_cancel_account_deletion(uuid) to authenticated;

-- Claim exclusivo backend. completed retorna la fila para retry idempotente;
-- pending/in_review activo obtiene token único bajo FOR UPDATE.
create or replace function public.hallyu_claim_account_deletion_v1_2(p_request_id uuid)
returns table(id uuid,user_id uuid,status text,requested_at timestamptz,recoverable_until timestamptz,processing_token uuid,audit_fk_on_delete text)
language plpgsql security definer set search_path=pg_catalog,public
as $$
declare r public.account_deletion_requests; token uuid;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'backend_only' using errcode='42501'; end if;
  select * into r from public.account_deletion_requests where id=p_request_id for update;
  if r.id is null then return; end if;
  if r.status='completed' then return query select r.id,r.user_id,r.status,r.requested_at,r.recoverable_until,r.processing_token,case when exists(select 1 from pg_constraint c join pg_attribute child on child.attrelid=c.conrelid and child.attnum=any(c.conkey) and child.attname='user_id' join pg_attribute parent on parent.attrelid=c.confrelid and parent.attnum=any(c.confkey) and parent.attname='id' where c.conrelid='public.account_deletion_requests'::regclass and c.confrelid='auth.users'::regclass and c.confdeltype='n') then 'set_null' else 'other' end; return; end if;
  if r.status='canceled' or r.recoverable_until is null or now()<r.recoverable_until then return; end if;
  if r.processing_token is not null
     and r.processing_started_at is not null
     and r.processing_started_at > now()-interval '15 minutes' then return; end if;
  token:=gen_random_uuid();
  update public.account_deletion_requests set status='in_review',processing_token=token,processing_started_at=now() where id=r.id;
  return query select r.id,r.user_id,'in_review',r.requested_at,r.recoverable_until,token,case when exists(select 1 from pg_constraint c join pg_attribute child on child.attrelid=c.conrelid and child.attnum=any(c.conkey) and child.attname='user_id' join pg_attribute parent on parent.attrelid=c.confrelid and parent.attnum=any(c.confkey) and parent.attname='id' where c.conrelid='public.account_deletion_requests'::regclass and c.confrelid='auth.users'::regclass and c.confdeltype='n') then 'set_null' else 'other' end;
end;
$$;
revoke all on function public.hallyu_claim_account_deletion_v1_2(uuid) from public,anon,authenticated;
grant execute on function public.hallyu_claim_account_deletion_v1_2(uuid) to service_role;

-- Enforcement de escritura para todas las entidades de contenido/mensajería.
create or replace function public.hallyu_current_enforcement_status_v1_3() returns text language sql stable security definer set search_path=pg_catalog,public
as $$ select coalesce((select enforcement_status from public.profiles where id=auth.uid()),'banned') $$;
create or replace function public.hallyu_reject_non_active_writes_v1_3() returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$ begin if auth.uid() is not null and public.hallyu_current_enforcement_status_v1_3()<>'active' then raise exception 'account_not_allowed_to_create_content' using errcode='42501'; end if; return new; end; $$;
do $$ declare t text; begin foreach t in array array['posts','stories','comments','drops','drop_comments','fancams','fancam_comments','conversations','messages'] loop if to_regclass('public.'||t) is not null and not exists(select 1 from pg_trigger where tgrelid=('public.'||t)::regclass and tgname='reject_non_active_writes_v1_3') then execute format('create trigger reject_non_active_writes_v1_3 before insert on public.%I for each row execute function public.hallyu_reject_non_active_writes_v1_3()',t); end if; end loop; end; $$;

commit;
