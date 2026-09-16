-- HallyuHub Beta Real v1 - profile location fields
-- Safe to run more than once. This migration removes the fixed "Chile" default
-- for new profiles and adds optional approximate/manual location fields.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default 'Hallyu Fan',
  username text not null unique,
  avatar_asset text not null default 'assets/demo-users/ai-luna-rivas.png',
  avatar_url text,
  fandom text not null default 'Nuevo fandom',
  country text not null default '',
  region text not null default '',
  city text not null default '',
  location_visibility text not null default 'country',
  location_updated_at timestamptz,
  language text not null default 'Español',
  favorite_group text not null default 'Por definir',
  bias text not null default 'Bias secreto',
  bio text not null default '',
  content_region text not null default 'Latam',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists name text not null default 'Hallyu Fan',
  add column if not exists username text,
  add column if not exists avatar_asset text not null default 'assets/demo-users/ai-luna-rivas.png',
  add column if not exists avatar_url text,
  add column if not exists fandom text not null default 'Nuevo fandom',
  add column if not exists country text not null default '',
  add column if not exists region text not null default '',
  add column if not exists city text not null default '',
  add column if not exists location_visibility text not null default 'country',
  add column if not exists location_updated_at timestamptz,
  add column if not exists language text not null default 'Español',
  add column if not exists favorite_group text not null default 'Por definir',
  add column if not exists bias text not null default 'Bias secreto',
  add column if not exists bio text not null default '',
  add column if not exists content_region text not null default 'Latam',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.profiles
  alter column country set default '',
  alter column region set default '',
  alter column city set default '',
  alter column location_visibility set default 'country';

update public.profiles
set
  country = coalesce(country, ''),
  region = coalesce(region, ''),
  city = coalesce(city, ''),
  location_visibility = case
    when location_visibility in ('country', 'city', 'hidden') then location_visibility
    else 'country'
  end;

do $$
begin
  alter table public.profiles
    add constraint profiles_location_visibility_check
    check (location_visibility in ('country', 'city', 'hidden'));
exception
  when duplicate_object then null;
end $$;

create index if not exists profiles_location_country_idx
  on public.profiles(country);

create index if not exists profiles_location_region_idx
  on public.profiles(region);

create index if not exists profiles_location_city_idx
  on public.profiles(city);

create or replace function public.handle_new_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username text;
  candidate_username text;
  suffix integer := 0;
begin
  base_username := lower(
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
      nullif(split_part(new.email, '@', 1), ''),
      'fan'
    )
  );
  base_username := regexp_replace(base_username, '[^a-z0-9_]+', '', 'g');

  if length(base_username) < 3 then
    base_username := 'fan_' || substring(replace(new.id::text, '-', ''), 1, 8);
  end if;

  candidate_username := left(base_username, 24);
  while exists (
    select 1
    from public.profiles
    where username = candidate_username
      and id <> new.id
  ) loop
    suffix := suffix + 1;
    candidate_username := left(base_username, 20)
      || '_'
      || substring(replace(new.id::text, '-', ''), 1, 6)
      || case when suffix > 1 then suffix::text else '' end;
  end loop;

  insert into public.profiles (
    id,
    email,
    name,
    username,
    avatar_asset,
    fandom,
    country,
    region,
    city,
    location_visibility,
    language,
    favorite_group,
    bias,
    content_region
  )
  values (
    new.id,
    new.email,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'Hallyu Fan'),
    candidate_username,
    'assets/demo-users/ai-luna-rivas.png',
    'Nuevo fandom',
    '',
    '',
    '',
    'country',
    'Español',
    'Por definir',
    'Bias secreto',
    'Latam'
  )
  on conflict (id) do update set
    email = excluded.email,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_auth_user_profile();

with missing_profiles as (
  select
    auth_user.id,
    auth_user.email,
    auth_user.raw_user_meta_data,
    lower(
      coalesce(
        nullif(trim(auth_user.raw_user_meta_data ->> 'username'), ''),
        nullif(split_part(auth_user.email, '@', 1), ''),
        'fan'
      )
    ) as raw_username
  from auth.users auth_user
  left join public.profiles profile on profile.id = auth_user.id
  where profile.id is null
),
prepared_profiles as (
  select
    id,
    email,
    raw_user_meta_data,
    case
      when length(regexp_replace(raw_username, '[^a-z0-9_]+', '', 'g')) < 3
        then 'fan_' || substring(replace(id::text, '-', ''), 1, 8)
      else regexp_replace(raw_username, '[^a-z0-9_]+', '', 'g')
    end as base_username
  from missing_profiles
)
insert into public.profiles (
  id,
  email,
  name,
  username,
  avatar_asset,
  fandom,
  country,
  region,
  city,
  location_visibility,
  language,
  favorite_group,
  bias,
  content_region
)
select
  id,
  email,
  coalesce(nullif(trim(raw_user_meta_data ->> 'name'), ''), 'Hallyu Fan'),
  left(base_username, 20) || '_' || substring(replace(id::text, '-', ''), 1, 6),
  'assets/demo-users/ai-luna-rivas.png',
  'Nuevo fandom',
  '',
  '',
  '',
  'country',
  'Español',
  'Por definir',
  'Bias secreto',
  'Latam'
from prepared_profiles
on conflict (id) do nothing;
