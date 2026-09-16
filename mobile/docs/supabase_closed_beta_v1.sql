-- HallyuHub Beta Real - Closed beta access v1
-- Safe to run multiple times. Does not drop, truncate, or delete real data.

create extension if not exists "pgcrypto";

create table if not exists public.beta_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

alter table public.beta_settings
  add column if not exists value text not null default '',
  add column if not exists updated_at timestamptz not null default now();

insert into public.beta_settings (key, value, updated_at)
values
  ('beta_user_limit', '100', now()),
  ('beta_access_enabled', 'true', now())
on conflict (key) do nothing;

create table if not exists public.beta_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  email text,
  status text not null default 'waitlist',
  approved_at timestamptz,
  waitlisted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.beta_access
  add column if not exists user_id uuid references public.profiles(id) on delete cascade,
  add column if not exists email text,
  add column if not exists status text not null default 'waitlist',
  add column if not exists approved_at timestamptz,
  add column if not exists waitlisted_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'beta_access_status_check'
      and conrelid = 'public.beta_access'::regclass
  ) then
    alter table public.beta_access
      add constraint beta_access_status_check
      check (status in ('approved', 'waitlist', 'blocked'));
  end if;
end;
$$;

create unique index if not exists beta_access_user_id_key
  on public.beta_access(user_id);

create index if not exists beta_access_email_idx
  on public.beta_access(lower(coalesce(email, '')));

create index if not exists beta_access_status_idx
  on public.beta_access(status);

create index if not exists beta_access_created_at_idx
  on public.beta_access(created_at desc);

alter table public.beta_settings enable row level security;
alter table public.beta_access enable row level security;

drop policy if exists "beta settings authenticated read" on public.beta_settings;
create policy "beta settings authenticated read"
on public.beta_settings
for select
to authenticated
using (true);

drop policy if exists "beta access self read" on public.beta_access;
create policy "beta access self read"
on public.beta_access
for select
to authenticated
using (user_id = auth.uid());

-- Existing beta users must keep access. This includes Leandro and Belen.
insert into public.beta_access (
  user_id,
  email,
  status,
  approved_at,
  created_at,
  updated_at
)
select
  p.id,
  p.email,
  'approved',
  now(),
  now(),
  now()
from public.profiles p
where lower(coalesce(p.email, '')) in (
  'leopaletta9@gmail.com',
  'palettabelen62@gmail.com'
)
on conflict (user_id) do update
set
  email = coalesce(excluded.email, public.beta_access.email),
  status = 'approved',
  approved_at = coalesce(public.beta_access.approved_at, excluded.approved_at),
  updated_at = now();

-- Approve profiles that already exist when this migration is first applied.
-- New accounts after this point are assigned by claim_beta_access().
insert into public.beta_access (
  user_id,
  email,
  status,
  approved_at,
  created_at,
  updated_at
)
select
  p.id,
  p.email,
  'approved',
  now(),
  now(),
  now()
from public.profiles p
where not exists (
  select 1 from public.beta_access ba where ba.user_id = p.id
)
on conflict (user_id) do nothing;

create or replace function public.claim_beta_access()
returns table (
  status text,
  beta_user_limit integer,
  approved_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  profile_email text;
  existing_status text;
  limit_value integer := 100;
  enabled_value boolean := true;
  approved_total integer := 0;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtext('hallyuhub_beta_access_v1'));

  select
    case
      when bs.value ~ '^[0-9]+$' then greatest(bs.value::integer, 0)
      else 100
    end
  into limit_value
  from public.beta_settings bs
  where bs.key = 'beta_user_limit';

  limit_value := coalesce(limit_value, 100);

  select
    case
      when lower(bs.value) in ('true', '1', 'yes', 'on') then true
      when lower(bs.value) in ('false', '0', 'no', 'off') then false
      else true
    end
  into enabled_value
  from public.beta_settings bs
  where bs.key = 'beta_access_enabled';

  enabled_value := coalesce(enabled_value, true);

  select p.email
  into profile_email
  from public.profiles p
  where p.id = current_user_id;

  if profile_email is null then
    profile_email := coalesce(auth.jwt() ->> 'email', '');

    insert into public.profiles (
      id,
      email,
      name,
      username
    )
    values (
      current_user_id,
      profile_email,
      'Hallyu Fan',
      '@fan_' || substring(replace(current_user_id::text, '-', ''), 1, 8)
    )
    on conflict (id) do nothing;
  end if;

  select ba.status
  into existing_status
  from public.beta_access ba
  where ba.user_id = current_user_id;

  select count(*)::integer
  into approved_total
  from public.beta_access ba
  where ba.status = 'approved';

  if existing_status is not null then
    update public.beta_access
    set
      email = coalesce(nullif(profile_email, ''), email),
      updated_at = now()
    where user_id = current_user_id;

    return query select existing_status, limit_value, approved_total;
    return;
  end if;

  if enabled_value and approved_total < limit_value then
    insert into public.beta_access (
      user_id,
      email,
      status,
      approved_at,
      created_at,
      updated_at
    )
    values (
      current_user_id,
      profile_email,
      'approved',
      now(),
      now(),
      now()
    )
    on conflict (user_id) do update
    set
      email = coalesce(excluded.email, public.beta_access.email),
      status = case
        when public.beta_access.status = 'blocked' then 'blocked'
        else 'approved'
      end,
      approved_at = coalesce(public.beta_access.approved_at, excluded.approved_at),
      updated_at = now()
    returning public.beta_access.status into existing_status;

    select count(*)::integer
    into approved_total
    from public.beta_access ba
    where ba.status = 'approved';

    return query select existing_status, limit_value, approved_total;
    return;
  end if;

  insert into public.beta_access (
    user_id,
    email,
    status,
    waitlisted_at,
    created_at,
    updated_at
  )
  values (
    current_user_id,
    profile_email,
    'waitlist',
    now(),
    now(),
    now()
  )
  on conflict (user_id) do update
  set
    email = coalesce(excluded.email, public.beta_access.email),
    waitlisted_at = coalesce(public.beta_access.waitlisted_at, excluded.waitlisted_at),
    updated_at = now()
  returning public.beta_access.status into existing_status;

  return query select coalesce(existing_status, 'waitlist'), limit_value, approved_total;
end;
$$;

grant execute on function public.claim_beta_access() to authenticated;

-- Manual approval example:
-- insert into public.beta_access (user_id, email, status, approved_at, created_at, updated_at)
-- select id, email, 'approved', now(), now(), now()
-- from public.profiles
-- where lower(email) = lower('fan@example.com')
-- on conflict (user_id) do update
-- set status = 'approved',
--     approved_at = coalesce(public.beta_access.approved_at, excluded.approved_at),
--     updated_at = now();

-- Change beta limit example:
-- insert into public.beta_settings (key, value, updated_at)
-- values ('beta_user_limit', '250', now())
-- on conflict (key) do update
-- set value = excluded.value,
--     updated_at = now();
