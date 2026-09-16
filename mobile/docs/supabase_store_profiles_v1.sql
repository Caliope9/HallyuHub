-- HallyuHub Beta Real - Perfiles tienda / vendedor.
-- Ejecutar en Supabase SQL Editor.
-- Seguro para correr varias veces: no borra datos, no usa DROP TABLE,
-- no usa TRUNCATE y no modifica perfiles reales existentes.

create extension if not exists "pgcrypto";

alter table public.profiles
  add column if not exists role text not null default 'user';

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
      from public.profiles as p
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

create table if not exists public.store_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  store_name text not null,
  description text,
  country text,
  region text,
  city text,
  categories text[] not null default '{}',
  delivery_methods text[] not null default '{}',
  payment_methods text[] not null default '{}',
  contact_url text,
  instagram_url text,
  whatsapp_url text,
  opening_hours text,
  status text not null default 'pending',
  is_verified boolean not null default false,
  verified_by uuid references public.profiles(id) on delete set null,
  verified_at timestamptz,
  profile_views integer not null default 0,
  contact_clicks integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.store_profiles
  add column if not exists owner_id uuid references public.profiles(id) on delete cascade,
  add column if not exists store_name text,
  add column if not exists description text,
  add column if not exists country text,
  add column if not exists region text,
  add column if not exists city text,
  add column if not exists categories text[] not null default '{}',
  add column if not exists delivery_methods text[] not null default '{}',
  add column if not exists payment_methods text[] not null default '{}',
  add column if not exists contact_url text,
  add column if not exists instagram_url text,
  add column if not exists whatsapp_url text,
  add column if not exists opening_hours text,
  add column if not exists status text not null default 'pending',
  add column if not exists is_verified boolean not null default false,
  add column if not exists verified_by uuid references public.profiles(id) on delete set null,
  add column if not exists verified_at timestamptz,
  add column if not exists profile_views integer not null default 0,
  add column if not exists contact_clicks integer not null default 0,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'store_profiles_owner_unique'
      and conrelid = 'public.store_profiles'::regclass
  ) then
    alter table public.store_profiles
      add constraint store_profiles_owner_unique unique (owner_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'store_profiles_status_check'
      and conrelid = 'public.store_profiles'::regclass
  ) then
    alter table public.store_profiles
      add constraint store_profiles_status_check
      check (status in ('pending', 'active', 'paused', 'blocked'));
  end if;
end $$;

create index if not exists store_profiles_owner_id_idx
  on public.store_profiles(owner_id);

create index if not exists store_profiles_status_created_idx
  on public.store_profiles(status, created_at desc);

create index if not exists store_profiles_verified_idx
  on public.store_profiles(is_verified, status);

create index if not exists store_profiles_country_city_idx
  on public.store_profiles(country, city);

create or replace function public.store_profiles_before_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean := public.is_admin_or_moderator();
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  new.store_name := trim(coalesce(new.store_name, ''));
  if new.store_name = '' then
    raise exception 'store_name is required';
  end if;

  new.description := nullif(trim(coalesce(new.description, '')), '');
  new.country := nullif(trim(coalesce(new.country, '')), '');
  new.region := nullif(trim(coalesce(new.region, '')), '');
  new.city := nullif(trim(coalesce(new.city, '')), '');
  new.contact_url := nullif(trim(coalesce(new.contact_url, '')), '');
  new.instagram_url := nullif(trim(coalesce(new.instagram_url, '')), '');
  new.whatsapp_url := nullif(trim(coalesce(new.whatsapp_url, '')), '');
  new.opening_hours := nullif(trim(coalesce(new.opening_hours, '')), '');
  new.categories := coalesce(new.categories, '{}');
  new.delivery_methods := coalesce(new.delivery_methods, '{}');
  new.payment_methods := coalesce(new.payment_methods, '{}');
  new.updated_at := now();

  if not is_admin then
    if TG_OP = 'INSERT' then
      new.owner_id := auth.uid();
      new.status := 'pending';
      new.is_verified := false;
      new.verified_by := null;
      new.verified_at := null;
      new.profile_views := 0;
      new.contact_clicks := 0;
    elsif TG_OP = 'UPDATE' then
      if old.owner_id is distinct from auth.uid() then
        raise exception 'not allowed' using errcode = '42501';
      end if;
      new.owner_id := old.owner_id;
      new.status := old.status;
      new.is_verified := old.is_verified;
      new.verified_by := old.verified_by;
      new.verified_at := old.verified_at;
      new.profile_views := old.profile_views;
      new.contact_clicks := old.contact_clicks;
    end if;
  end if;

  if new.status is null
     or new.status not in ('pending', 'active', 'paused', 'blocked') then
    new.status := 'pending';
  end if;

  if new.is_verified and new.verified_at is null then
    new.verified_at := now();
  end if;

  if not new.is_verified then
    new.verified_by := null;
    new.verified_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists store_profiles_before_write_trigger
  on public.store_profiles;

create trigger store_profiles_before_write_trigger
before insert or update
on public.store_profiles
for each row
execute function public.store_profiles_before_write();

create or replace function public.admin_update_store_profile(
  p_store_id uuid,
  p_status text default null,
  p_is_verified boolean default null
)
returns public.store_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated public.store_profiles%rowtype;
  next_status text;
begin
  if not public.is_admin_or_moderator() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  next_status := nullif(trim(coalesce(p_status, '')), '');
  if next_status is not null
     and next_status not in ('pending', 'active', 'paused', 'blocked') then
    raise exception 'invalid store status';
  end if;

  update public.store_profiles
  set
    status = coalesce(next_status, status),
    is_verified = coalesce(p_is_verified, is_verified),
    verified_by = case
      when coalesce(p_is_verified, is_verified) then auth.uid()
      else null
    end,
    verified_at = case
      when coalesce(p_is_verified, is_verified) then coalesce(verified_at, now())
      else null
    end,
    updated_at = now()
  where id = p_store_id
  returning * into updated;

  if not found then
    raise exception 'store profile not found';
  end if;

  return updated;
end;
$$;

grant execute on function public.admin_update_store_profile(uuid, text, boolean)
  to authenticated;

create or replace function public.set_my_store_profile_paused(
  p_paused boolean
)
returns public.store_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated public.store_profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  update public.store_profiles
  set
    status = case
      when coalesce(p_paused, false) then 'paused'
      else 'pending'
    end,
    updated_at = now()
  where owner_id = auth.uid()
    and status <> 'blocked'
  returning * into updated;

  if not found then
    raise exception 'store profile not found';
  end if;

  return updated;
end;
$$;

grant execute on function public.set_my_store_profile_paused(boolean)
  to authenticated;

alter table public.store_profiles enable row level security;

drop policy if exists "store profiles own insert" on public.store_profiles;
create policy "store profiles own insert"
on public.store_profiles
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

drop policy if exists "store profiles own read" on public.store_profiles;
create policy "store profiles own read"
on public.store_profiles
for select
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "store profiles active read" on public.store_profiles;
create policy "store profiles active read"
on public.store_profiles
for select
to authenticated
using (status = 'active');

drop policy if exists "store profiles own update" on public.store_profiles;
create policy "store profiles own update"
on public.store_profiles
for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

drop policy if exists "store profiles admin read" on public.store_profiles;
create policy "store profiles admin read"
on public.store_profiles
for select
to authenticated
using (public.is_admin_or_moderator());

drop policy if exists "store profiles admin update" on public.store_profiles;
create policy "store profiles admin update"
on public.store_profiles
for update
to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

revoke all on public.store_profiles from anon;
revoke all on public.store_profiles from authenticated;
grant select on public.store_profiles to authenticated;
grant insert (
  owner_id,
  store_name,
  description,
  country,
  region,
  city,
  categories,
  delivery_methods,
  payment_methods,
  contact_url,
  instagram_url,
  whatsapp_url,
  opening_hours
) on public.store_profiles to authenticated;
grant update (
  store_name,
  description,
  country,
  region,
  city,
  categories,
  delivery_methods,
  payment_methods,
  contact_url,
  instagram_url,
  whatsapp_url,
  opening_hours
) on public.store_profiles to authenticated;

notify pgrst, 'reload schema';
