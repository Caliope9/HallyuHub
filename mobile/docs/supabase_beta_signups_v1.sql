-- HallyuHub Beta Real - Public beta signups v1
-- Safe to run multiple times. Does not drop, truncate, or delete real data.
-- Public visitors submit through submit_beta_signup(); only admin/moderator can list or edit signups.

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
on conflict (key) do update
set
  value = public.beta_settings.value,
  updated_at = public.beta_settings.updated_at;

create table if not exists public.beta_signups (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  nickname text,
  country text,
  fandom text,
  platform text default 'other',
  status text not null default 'waiting',
  "position" integer,
  invited_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  admin_notes text
);

alter table public.beta_signups
  add column if not exists email text,
  add column if not exists nickname text,
  add column if not exists country text,
  add column if not exists fandom text,
  add column if not exists platform text default 'other',
  add column if not exists status text not null default 'waiting',
  add column if not exists "position" integer,
  add column if not exists invited_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists admin_notes text;

update public.beta_signups
set
  platform = coalesce(nullif(platform, ''), 'other'),
  status = coalesce(nullif(status, ''), 'waiting'),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, now());

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'beta_signups_platform_check'
      and conrelid = 'public.beta_signups'::regclass
  ) then
    alter table public.beta_signups
      add constraint beta_signups_platform_check
      check (platform in ('android', 'ios', 'other'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'beta_signups_status_check'
      and conrelid = 'public.beta_signups'::regclass
  ) then
    alter table public.beta_signups
      add constraint beta_signups_status_check
      check (status in ('approved', 'waiting', 'blocked'));
  end if;
end $$;

create unique index if not exists beta_signups_email_lower_key
  on public.beta_signups (lower(email));

create unique index if not exists beta_signups_email_key
  on public.beta_signups (email);

create index if not exists beta_signups_status_idx
  on public.beta_signups (status);

create index if not exists beta_signups_platform_idx
  on public.beta_signups (platform);

create index if not exists beta_signups_country_idx
  on public.beta_signups (lower(coalesce(country, '')));

create index if not exists beta_signups_created_at_idx
  on public.beta_signups (created_at desc);

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
end $$;

create unique index if not exists beta_access_user_id_key
  on public.beta_access (user_id);

create index if not exists beta_access_email_idx
  on public.beta_access (lower(coalesce(email, '')));

create index if not exists beta_access_status_idx
  on public.beta_access (status);

alter table public.profiles
  add column if not exists role text not null default 'user';

update public.profiles
set role = 'user'
where role is null
   or role not in ('user', 'moderator', 'admin');

alter table public.profiles
  alter column role set default 'user',
  alter column role set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check
      check (role in ('user', 'moderator', 'admin'));
  end if;
end $$;

create index if not exists profiles_role_idx
  on public.profiles (role);

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.role
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    ),
    'user'
  );
$$;

create or replace function public.is_admin_or_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() in ('admin', 'moderator');
$$;

grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_admin_or_moderator() to authenticated;

create or replace function public.refresh_beta_signup_positions()
returns void
language sql
security definer
set search_path = public
as $$
  with ordered as (
    select
      bs.id,
      row_number() over (order by bs.created_at asc, bs.id asc)::integer as next_position
    from public.beta_signups as bs
    where bs.status = 'waiting'
  )
  update public.beta_signups as signup
  set "position" = ordered.next_position
  from ordered
  where signup.id = ordered.id
    and signup."position" is distinct from ordered.next_position;

  update public.beta_signups as bs
  set "position" = null
  where bs.status <> 'waiting'
    and bs."position" is not null;
$$;

create or replace function public.beta_signups_before_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.email := lower(trim(new.email));
  new.nickname := nullif(trim(coalesce(new.nickname, '')), '');
  new.country := nullif(trim(coalesce(new.country, '')), '');
  new.fandom := nullif(trim(coalesce(new.fandom, '')), '');
  new.platform := coalesce(nullif(trim(new.platform), ''), 'other');
  new.status := coalesce(nullif(trim(new.status), ''), 'waiting');
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists beta_signups_before_write_trigger
  on public.beta_signups;

create trigger beta_signups_before_write_trigger
before insert or update
on public.beta_signups
for each row
execute function public.beta_signups_before_write();

create or replace function public.beta_signups_after_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if pg_trigger_depth() <= 1 then
    perform public.refresh_beta_signup_positions();
  end if;
  update public.beta_access access
  set
    status = case new.status
      when 'approved' then 'approved'
      when 'blocked' then 'blocked'
      else 'waitlist'
    end,
    approved_at = case
      when new.status = 'approved' then coalesce(access.approved_at, now())
      else access.approved_at
    end,
    waitlisted_at = case
      when new.status = 'waiting' then coalesce(access.waitlisted_at, now())
      else access.waitlisted_at
    end,
    updated_at = now()
  from public.profiles profile
  where profile.id = access.user_id
    and lower(coalesce(profile.email, access.email, '')) = lower(new.email);
  return coalesce(new, old);
end;
$$;

drop trigger if exists beta_signups_after_write_trigger
  on public.beta_signups;

create trigger beta_signups_after_write_trigger
after insert or update of status, created_at
on public.beta_signups
for each row
execute function public.beta_signups_after_write();

create or replace function public.submit_beta_signup(
  p_email text,
  p_nickname text default null,
  p_country text default null,
  p_fandom text default null,
  p_platform text default 'other',
  p_accept_beta boolean default false
)
returns table (
  status text,
  "position" integer,
  approved_count integer,
  beta_user_limit integer,
  duplicate boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  normalized_platform text := lower(trim(coalesce(p_platform, 'other')));
  limit_value integer := 100;
  existing public.beta_signups%rowtype;
  target_status text := 'waiting';
  approved_total integer := 0;
  waiting_position integer;
begin
  if not p_accept_beta then
    raise exception 'Necesitas aceptar participar en la beta.'
      using errcode = '22023';
  end if;

  if normalized_email = ''
     or normalized_email !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' then
    raise exception 'Email invalido.'
      using errcode = '22023';
  end if;

  if normalized_platform not in ('android', 'ios', 'other') then
    normalized_platform := 'other';
  end if;

  perform pg_advisory_xact_lock(hashtext('hallyuhub_beta_signups_v1'));

  select
    case
      when value ~ '^[0-9]+$' then greatest(value::integer, 0)
      else 100
    end
  into limit_value
  from public.beta_settings
  where key = 'beta_user_limit';

  limit_value := coalesce(limit_value, 100);

  select *
  into existing
  from public.beta_signups as bs
  where lower(bs.email) = normalized_email
  limit 1;

  if existing.id is not null then
    if existing.status <> 'blocked' then
      update public.beta_signups as bs
      set
        nickname = coalesce(nullif(trim(coalesce(p_nickname, '')), ''), bs.nickname),
        country = coalesce(nullif(trim(coalesce(p_country, '')), ''), bs.country),
        fandom = coalesce(nullif(trim(coalesce(p_fandom, '')), ''), bs.fandom),
        platform = normalized_platform
      where bs.id = existing.id;
    end if;

    perform public.refresh_beta_signup_positions();

    select count(*)::integer
    into approved_total
    from public.beta_signups as bs
    where bs.status = 'approved';

    select bs."position"
    into waiting_position
    from public.beta_signups as bs
    where bs.id = existing.id;

    return query
    select existing.status, waiting_position, approved_total, limit_value, true;
    return;
  end if;

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  target_status := 'waiting';

  insert into public.beta_signups (
    email,
    nickname,
    country,
    fandom,
    platform,
    status,
    created_at,
    updated_at
  )
  values (
    normalized_email,
    nullif(trim(coalesce(p_nickname, '')), ''),
    nullif(trim(coalesce(p_country, '')), ''),
    nullif(trim(coalesce(p_fandom, '')), ''),
    normalized_platform,
    target_status,
    now(),
    now()
  )
  returning * into existing;

  perform public.refresh_beta_signup_positions();

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  select bs."position"
  into waiting_position
  from public.beta_signups as bs
  where bs.id = existing.id;

  return query
  select target_status, waiting_position, approved_total, limit_value, false;
end;
$$;

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
  profile_name text;
  existing_status text;
  signup_status text;
  access_status text := 'waitlist';
  limit_value integer := 100;
  approved_total integer := 0;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtext('hallyuhub_beta_access_v2'));

  select
    case
      when value ~ '^[0-9]+$' then greatest(value::integer, 0)
      else 100
    end
  into limit_value
  from public.beta_settings
  where key = 'beta_user_limit';

  limit_value := coalesce(limit_value, 100);

  select p.email, p.name
  into profile_email, profile_name
  from public.profiles p
  where p.id = current_user_id;

  if profile_email is null or profile_email = '' then
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
      coalesce(nullif(profile_name, ''), 'Hallyu Fan'),
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
  from public.beta_signups as bs
  where bs.status = 'approved';

  if existing_status is not null then
    update public.beta_access
    set
      email = coalesce(nullif(profile_email, ''), email),
      updated_at = now()
    where user_id = current_user_id;

    return query select existing_status, limit_value, approved_total;
    return;
  end if;

  select bs.status
  into signup_status
  from public.beta_signups bs
  where lower(bs.email) = lower(profile_email)
  limit 1;

  if signup_status is null then
    insert into public.beta_signups (
      email,
      nickname,
      platform,
      status,
      created_at,
      updated_at
    )
    values (
      lower(profile_email),
      coalesce(nullif(profile_name, ''), 'Hallyu Fan'),
      'other',
      'waiting',
      now(),
      now()
    )
    on conflict (email) do nothing;

    perform public.refresh_beta_signup_positions();
    signup_status := 'waiting';
  end if;

  access_status := case signup_status
    when 'approved' then 'approved'
    when 'blocked' then 'blocked'
    else 'waitlist'
  end;

  insert into public.beta_access (
    user_id,
    email,
    status,
    approved_at,
    waitlisted_at,
    created_at,
    updated_at
  )
  values (
    current_user_id,
    profile_email,
    access_status,
    case when access_status = 'approved' then now() else null end,
    case when access_status = 'waitlist' then now() else null end,
    now(),
    now()
  )
  on conflict (user_id) do update
  set
    email = coalesce(excluded.email, public.beta_access.email),
    status = case
      when public.beta_access.status = 'blocked' then 'blocked'
      else excluded.status
    end,
    approved_at = coalesce(public.beta_access.approved_at, excluded.approved_at),
    waitlisted_at = coalesce(public.beta_access.waitlisted_at, excluded.waitlisted_at),
    updated_at = now()
  returning public.beta_access.status into access_status;

  return query select access_status, limit_value, approved_total;
end;
$$;

-- Keep current owner accounts approved in both the public signup list and app access.
insert into public.beta_signups (
  email,
  nickname,
  country,
  fandom,
  platform,
  status,
  created_at,
  updated_at
)
values
  ('leopaletta9@gmail.com', 'Leandro', 'Argentina', 'HallyuHub', 'ios', 'approved', now(), now()),
  ('palettabelen62@gmail.com', 'Cami', 'Argentina', 'HallyuHub', 'ios', 'approved', now(), now())
on conflict (email) do update
set
  status = 'approved',
  updated_at = now();

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

alter table public.beta_settings enable row level security;
alter table public.beta_access enable row level security;
alter table public.beta_signups enable row level security;

drop policy if exists "beta settings authenticated read" on public.beta_settings;
create policy "beta settings authenticated read"
on public.beta_settings
for select
to authenticated
using (true);

drop policy if exists "beta settings admin update" on public.beta_settings;
create policy "beta settings admin update"
on public.beta_settings
for update
to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

drop policy if exists "beta access self read" on public.beta_access;
create policy "beta access self read"
on public.beta_access
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "beta access admin read" on public.beta_access;
create policy "beta access admin read"
on public.beta_access
for select
to authenticated
using (public.is_admin_or_moderator());

drop policy if exists "beta access admin update" on public.beta_access;
create policy "beta access admin update"
on public.beta_access
for update
to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

drop policy if exists "beta signups admin read" on public.beta_signups;
create policy "beta signups admin read"
on public.beta_signups
for select
to authenticated
using (public.is_admin_or_moderator());

drop policy if exists "beta signups admin update" on public.beta_signups;
create policy "beta signups admin update"
on public.beta_signups
for update
to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

revoke all on public.beta_signups from anon;
revoke all on public.beta_signups from authenticated;
grant select, update on public.beta_signups to authenticated;

grant execute on function public.submit_beta_signup(text, text, text, text, text, boolean) to anon;
grant execute on function public.submit_beta_signup(text, text, text, text, text, boolean) to authenticated;
grant execute on function public.claim_beta_access() to authenticated;
grant execute on function public.refresh_beta_signup_positions() to authenticated;

select public.refresh_beta_signup_positions();

-- Approve a user manually:
-- update public.beta_signups
-- set status = 'approved', updated_at = now()
-- where lower(email) = lower('fan@example.com');
--
-- Change the public beta limit from 100 to 250:
-- insert into public.beta_settings (key, value, updated_at)
-- values ('beta_user_limit', '250', now())
-- on conflict (key) do update
-- set value = excluded.value,
--     updated_at = now();

notify pgrst, 'reload schema';
