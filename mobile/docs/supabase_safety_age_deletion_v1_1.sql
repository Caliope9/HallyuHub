-- HallyuHub safety/age/deletion v1.1 — PREPARACIÓN, NO EJECUTAR AUTOMÁTICAMENTE.
-- Revisar contra el esquema desplegado antes de aplicar manualmente.
-- No contiene DELETE, TRUNCATE, DROP, UPDATE masivo ni service_role.

begin;
set local search_path = pg_catalog, public;

do $$
begin
  if to_regclass('public.profiles') is null then
    raise exception 'profiles no existe; detener y revisar el esquema';
  end if;
  if to_regclass('public.account_deletion_requests') is null then
    raise exception 'account_deletion_requests no existe; aplicar primero su migración aprobada';
  end if;
  if to_regprocedure('public.hallyu_request_account_deletion(text,boolean)') is null
     or to_regprocedure('public.hallyu_get_account_deletion_status()') is null
     or to_regprocedure('public.hallyu_cancel_account_deletion(uuid)') is null then
    raise exception 'Falta uno de los RPC de eliminación existentes; no continuar';
  end if;
end;
$$;

-- Columnas nuevas, nullable salvo enforcement_status, para no reescribir ni
-- cambiar usuarios existentes. birth_date no se devuelve en perfiles públicos.
alter table public.profiles
  add column if not exists birth_date date,
  add column if not exists enforcement_status text not null default 'active',
  add column if not exists enforcement_until timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.profiles'::regclass
                 and conname = 'profiles_enforcement_status_v1_1_check') then
    alter table public.profiles add constraint profiles_enforcement_status_v1_1_check
      check (enforcement_status in ('active', 'restricted', 'suspended', 'banned')) not valid;
  end if;
end;
$$;

-- Column-level privileges prevent anon/authenticated from selecting or
-- updating birth_date, even if a caller requests profiles.* directly.
revoke select (birth_date) on public.profiles from public, anon, authenticated;
revoke update (birth_date, enforcement_status, enforcement_until)
  on public.profiles from public, anon, authenticated;

-- Server-side validation. Existing rows remain untouched; only future writes
-- with a birth_date are validated. The auth profile trigger must provide the
-- date from raw_user_meta_data for new accounts before this is applied.
create or replace function public.hallyu_validate_profile_security_v1_1()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.birth_date is null then
    select nullif(u.raw_user_meta_data ->> 'birth_date', '')::date
      into new.birth_date
      from auth.users u where u.id = new.id;
  end if;
  if tg_op = 'INSERT' and new.birth_date is null then
    raise exception 'birth_date_required' using errcode = '23514';
  end if;
  if new.birth_date is not null and
     (new.birth_date > current_date - interval '16 years') then
    raise exception 'minimum_age_required' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and new.birth_date is distinct from old.birth_date
     and old.birth_date is not null then
    raise exception 'birth_date_immutable' using errcode = '42501';
  end if;
  if new.birth_date > (current_date - interval '18 years')::date
     and new.birth_date <= (current_date - interval '16 years')::date then
    new.private_profile := true;
    new.message_privacy := 'Seguidores';
    new.story_privacy := 'Seguidores';
  end if;
  if new.enforcement_status is null then new.enforcement_status := 'active'; end if;
  return new;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgrelid = 'public.profiles'::regclass
                 and tgname = 'profiles_validate_security_v1_1') then
    create trigger profiles_validate_security_v1_1
    before insert or update of birth_date, enforcement_status, enforcement_until
    on public.profiles for each row
    execute function public.hallyu_validate_profile_security_v1_1();
  end if;
end;
$$;

-- The existing auth profile trigger must be reviewed and updated to insert
-- birth_date plus teen defaults from auth.users.raw_user_meta_data. This file
-- intentionally does not replace that trigger because several historical
-- migrations use different profile column sets.

-- Server-owned deletion deadline. Existing requests are not mass-updated;
-- the backend must treat NULL as legacy/non-recoverable until reviewed.
alter table public.account_deletion_requests
  add column if not exists recoverable_until timestamptz;

create or replace function public.hallyu_set_deletion_deadline_v1_1()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.requested_at is null then new.requested_at := now(); end if;
  if new.recoverable_until is null then
    new.recoverable_until := new.requested_at + interval '30 days';
  end if;
  return new;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgrelid = 'public.account_deletion_requests'::regclass
                 and tgname = 'account_deletion_deadline_v1_1') then
    create trigger account_deletion_deadline_v1_1
    before insert on public.account_deletion_requests for each row
    execute function public.hallyu_set_deletion_deadline_v1_1();
  end if;
end;
$$;

-- No direct table access for enforcement or safety verdicts.
create table if not exists public.content_safety_checks (
  id uuid primary key default gen_random_uuid(),
  content_type text not null,
  content_id uuid,
  verdict text not null check (verdict in ('safe', 'unsafe', 'needs_review', 'unavailable')),
  categories text[] not null default '{}',
  provider text not null default '',
  error_code text not null default '',
  created_at timestamptz not null default now()
);
alter table public.content_safety_checks enable row level security;
revoke all on public.content_safety_checks from public, anon, authenticated;

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
revoke all on public.user_enforcement_events from public, anon, authenticated;

create or replace function public.hallyu_admin_set_enforcement_v1_1(
  p_user_id uuid, p_status text, p_until timestamptz default null, p_reason text default ''
)
returns table (user_id uuid, status text, enforcement_until timestamptz)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not exists (select 1 from public.profiles me
                 where me.id = auth.uid() and lower(coalesce(me.role, 'user')) in ('admin', 'moderator')) then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if p_status not in ('active', 'restricted', 'suspended', 'banned') then
    raise exception 'invalid_enforcement_status';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'enforcement_reason_required';
  end if;
  insert into public.user_enforcement_events
    (user_id, actor_id, status, reason, enforcement_until)
    values (p_user_id, auth.uid(), p_status, btrim(p_reason), p_until);
  return query update public.profiles p
    set enforcement_status = p_status, enforcement_until = p_until, updated_at = now()
    where p.id = p_user_id
    returning p.id, p.enforcement_status, p.enforcement_until;
end;
$$;

revoke all on function public.hallyu_admin_set_enforcement_v1_1(uuid, text, timestamptz, text)
  from public, anon, authenticated;
grant execute on function public.hallyu_admin_set_enforcement_v1_1(uuid, text, timestamptz, text)
  to authenticated;

-- IMPORTANT: existing deletion RPC signatures are intentionally not replaced
-- here. Before applying, update them in a separately reviewed migration so
-- their server-side return includes recoverable_until and cancel checks it
-- against now(), including in_review. Never authorize recovery by client time.

commit;
