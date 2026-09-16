-- HallyuHub Beta Real - profiles without fake defaults.
-- Safe to run more than once.
-- Does not delete, truncate, reset, or mass-update existing user data.

alter table if exists public.profiles
  add column if not exists avatar_asset text,
  add column if not exists country text,
  add column if not exists region text,
  add column if not exists city text,
  add column if not exists fandom text,
  add column if not exists favorite_group text,
  add column if not exists bias text,
  add column if not exists content_region text;

do $$
declare
  profile_column text;
begin
  foreach profile_column in array array[
    'avatar_asset',
    'country',
    'region',
    'city',
    'fandom',
    'favorite_group',
    'bias',
    'content_region'
  ] loop
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = profile_column
    ) then
      execute format(
        'alter table public.profiles alter column %I drop default',
        profile_column
      );
      execute format(
        'alter table public.profiles alter column %I drop not null',
        profile_column
      );
    end if;
  end loop;
end $$;

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
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
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
    nullif(trim(new.raw_user_meta_data ->> 'avatar_asset'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'fandom'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'country'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'region'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'city'), ''),
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'language'), ''), 'Español'),
    nullif(trim(new.raw_user_meta_data ->> 'favorite_group'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'bias'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'content_region'), '')
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
