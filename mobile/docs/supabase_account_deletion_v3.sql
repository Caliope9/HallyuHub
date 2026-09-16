-- HallyuHub account deletion v3
-- Proposal only. Apply manually after review; never from Flutter.
-- This migration is atomic and intentionally does not delete users or content.

begin;

set local search_path = pg_catalog, public;

do $$
begin
  if to_regclass('public.account_deletion_requests') is not null then
    raise exception 'account_deletion_requests already exists; review v1/v2 before applying v3';
  end if;
  if to_regclass('public.account_deletion_one_open_request') is not null then
    raise exception 'account deletion index already exists; review v1/v2 before applying v3';
  end if;
  if to_regprocedure('public.hallyu_request_account_deletion(text,boolean)') is not null then
    raise exception 'hallyu_request_account_deletion(text,boolean) already exists; do not replace its return type automatically';
  end if;
  if to_regprocedure('public.hallyu_get_account_deletion_status()') is not null then
    raise exception 'hallyu_get_account_deletion_status() already exists; review v1/v2 before applying v3';
  end if;
  if to_regprocedure('public.hallyu_cancel_account_deletion(uuid)') is not null then
    raise exception 'hallyu_cancel_account_deletion(uuid) already exists; review v1/v2 before applying v3';
  end if;
  if to_regprocedure('public.gen_random_uuid()') is null then
    raise exception 'gen_random_uuid() is unavailable; enable the approved UUID provider in Supabase before applying v3';
  end if;
end;
$$;

create table public.account_deletion_requests (
  id uuid primary key default public.gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  requested_scope text not null default 'account_and_personal_data',
  reason text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'in_review', 'completed', 'canceled')),
  export_requested boolean not null default false,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  completed_at timestamptz,
  canceled_at timestamptz,
  admin_notes text not null default '',
  metadata jsonb not null default '{}'::jsonb
);

create unique index account_deletion_one_open_request
  on public.account_deletion_requests(user_id)
  where user_id is not null and status in ('pending', 'in_review');

alter table public.account_deletion_requests enable row level security;
revoke all on table public.account_deletion_requests from public, anon, authenticated;

create or replace function public.hallyu_request_account_deletion(
  p_reason text default '',
  p_export_requested boolean default false
)
returns table (
  id uuid, status text, requested_at timestamptz, reviewed_at timestamptz,
  completed_at timestamptz, canceled_at timestamptz,
  requested_scope text, export_requested boolean
)
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_request_id uuid;
begin
  if v_user_id is null then raise exception 'authentication_required'; end if;
  select r.id into v_request_id
  from public.account_deletion_requests r
  where r.user_id = v_user_id and r.status in ('pending', 'in_review')
  order by r.requested_at desc limit 1;
  if v_request_id is null then
    insert into public.account_deletion_requests (user_id, reason, export_requested)
    values (v_user_id, left(coalesce(p_reason, ''), 2000), coalesce(p_export_requested, false))
    returning account_deletion_requests.id into v_request_id;
  end if;
  return query select r.id, r.status, r.requested_at, r.reviewed_at,
    r.completed_at, r.canceled_at, r.requested_scope, r.export_requested
  from public.account_deletion_requests r where r.id = v_request_id;
end;
$$;

create or replace function public.hallyu_get_account_deletion_status()
returns table (
  id uuid, status text, requested_at timestamptz, reviewed_at timestamptz,
  completed_at timestamptz, canceled_at timestamptz,
  requested_scope text, export_requested boolean
)
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select r.id, r.status, r.requested_at, r.reviewed_at,
    r.completed_at, r.canceled_at, r.requested_scope, r.export_requested
  from public.account_deletion_requests r
  where r.user_id = auth.uid()
  order by r.requested_at desc limit 1;
$$;

create or replace function public.hallyu_cancel_account_deletion(p_request_id uuid)
returns table (id uuid, status text, canceled_at timestamptz)
language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  return query update public.account_deletion_requests r
  set status = 'canceled', canceled_at = now()
  where r.id = p_request_id and r.user_id = auth.uid() and r.status = 'pending'
  returning r.id, r.status, r.canceled_at;
end;
$$;

revoke all on function public.hallyu_request_account_deletion(text, boolean) from public, anon, authenticated;
revoke all on function public.hallyu_get_account_deletion_status() from public, anon, authenticated;
revoke all on function public.hallyu_cancel_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.hallyu_request_account_deletion(text, boolean) to authenticated;
grant execute on function public.hallyu_get_account_deletion_status() to authenticated;
grant execute on function public.hallyu_cancel_account_deletion(uuid) to authenticated;

commit;
