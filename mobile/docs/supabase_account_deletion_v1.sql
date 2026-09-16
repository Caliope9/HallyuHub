-- HallyuHub account deletion requests v1
-- Apply manually in Supabase SQL Editor. Never put service_role keys in the app.

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null default '',
  reason text not null default '',
  requested_scope text not null default 'account_and_personal_data',
  status text not null default 'pending' check (status in ('pending', 'in_review', 'completed', 'canceled')),
  export_requested boolean not null default false,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  completed_at timestamptz,
  canceled_at timestamptz,
  admin_notes text not null default '',
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists account_deletion_one_open_request
  on public.account_deletion_requests(user_id)
  where status in ('pending', 'in_review');

alter table public.account_deletion_requests enable row level security;

drop policy if exists account_deletion_select_own on public.account_deletion_requests;
create policy account_deletion_select_own on public.account_deletion_requests
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists account_deletion_insert_own on public.account_deletion_requests;
create policy account_deletion_insert_own on public.account_deletion_requests
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists account_deletion_cancel_own on public.account_deletion_requests;
create policy account_deletion_cancel_own on public.account_deletion_requests
  for update to authenticated
  using (auth.uid() = user_id and status = 'pending')
  with check (auth.uid() = user_id and status = 'canceled');

create or replace function public.hallyu_request_account_deletion(
  p_reason text default '', p_export_requested boolean default false
)
returns public.account_deletion_requests
language plpgsql security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := '';
  v_existing public.account_deletion_requests;
  v_created public.account_deletion_requests;
begin
  if v_user_id is null then raise exception 'authentication_required'; end if;
  select coalesce(email, '') into v_email from auth.users where id = v_user_id;
  select * into v_existing from public.account_deletion_requests
    where user_id = v_user_id and status in ('pending', 'in_review')
    order by requested_at desc limit 1;
  if v_existing.id is not null then return v_existing; end if;
  insert into public.account_deletion_requests (user_id, email, reason, export_requested)
    values (v_user_id, v_email, left(coalesce(p_reason, ''), 2000), coalesce(p_export_requested, false))
    returning * into v_created;
  return v_created;
end;
$$;

revoke all on function public.hallyu_request_account_deletion(text, boolean) from public;
grant execute on function public.hallyu_request_account_deletion(text, boolean) to authenticated;
