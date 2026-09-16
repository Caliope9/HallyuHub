-- HallyuHub Beta Real - profile settings columns and policies.
-- Safe to run more than once.
-- No DROP TABLE, no TRUNCATE, no DELETE, no mass UPDATE, no auth/storage changes.
-- This keeps profile facts optional and avoids fake defaults like Chile, Latam,
-- Nuevo fandom, Por definir, Bias secreto, or demo avatar assets.

alter table if exists public.profiles
  add column if not exists email text,
  add column if not exists name text,
  add column if not exists username text,
  add column if not exists bio text,
  add column if not exists avatar_asset text,
  add column if not exists avatar_url text,
  add column if not exists fandom text,
  add column if not exists country text,
  add column if not exists region text,
  add column if not exists city text,
  add column if not exists language text,
  add column if not exists phone text,
  add column if not exists bias text,
  add column if not exists favorite_group text,
  add column if not exists phrase text,
  add column if not exists content_region text,
  add column if not exists location_visibility text,
  add column if not exists location_updated_at timestamptz,
  add column if not exists private_profile boolean not null default false,
  add column if not exists notifications_enabled boolean not null default true,
  add column if not exists message_privacy text,
  add column if not exists story_privacy text,
  add column if not exists app_theme text,
  add column if not exists profile_background text,
  add column if not exists notify_messages boolean not null default true,
  add column if not exists notify_stars boolean not null default true,
  add column if not exists notify_comments boolean not null default true,
  add column if not exists notify_followers boolean not null default true,
  add column if not exists notify_drops boolean not null default true,
  add column if not exists two_factor_enabled boolean not null default false,
  add column if not exists login_alerts boolean not null default true,
  add column if not exists account_verified boolean not null default false,
  add column if not exists blocked_users jsonb not null default '[]'::jsonb,
  add column if not exists role text not null default 'user',
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz,
  add column if not exists community_guidelines_accepted_at timestamptz,
  add column if not exists beta_notice_accepted_at timestamptz,
  add column if not exists legal_version text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
declare
  profile_column text;
begin
  foreach profile_column in array array[
    'bio',
    'avatar_asset',
    'avatar_url',
    'fandom',
    'country',
    'region',
    'city',
    'language',
    'phone',
    'bias',
    'favorite_group',
    'phrase',
    'content_region',
    'location_visibility',
    'message_privacy',
    'story_privacy',
    'app_theme',
    'profile_background'
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

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_location_visibility_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_location_visibility_check
      check (
        location_visibility is null
        or location_visibility in ('country', 'city', 'hidden')
      );
  end if;

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

create index if not exists profiles_username_idx
  on public.profiles (lower(coalesce(username, '')));

create index if not exists profiles_country_idx
  on public.profiles (lower(coalesce(country, '')));

create index if not exists profiles_private_profile_idx
  on public.profiles (private_profile);

create index if not exists profiles_role_idx
  on public.profiles (role);

create or replace view public.public_profiles as
select
  id,
  name,
  username,
  bio,
  avatar_asset,
  avatar_url,
  fandom,
  case
    when location_visibility in ('country', 'city') then country
    else null
  end as country,
  case
    when location_visibility = 'city' then region
    else null
  end as region,
  case
    when location_visibility = 'city' then city
    else null
  end as city,
  location_visibility,
  favorite_group,
  bias,
  phrase,
  content_region,
  private_profile,
  created_at
from public.profiles;

grant select on public.public_profiles to authenticated;

create or replace function public.get_my_profile_settings()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select to_jsonb(profile_row)
  from (
    select
      id,
      email,
      name,
      username,
      bio,
      avatar_asset,
      avatar_url,
      fandom,
      country,
      region,
      city,
      language,
      phone,
      bias,
      favorite_group,
      phrase,
      content_region,
      location_visibility,
      location_updated_at,
      private_profile,
      notifications_enabled,
      message_privacy,
      story_privacy,
      app_theme,
      profile_background,
      notify_messages,
      notify_stars,
      notify_comments,
      notify_followers,
      notify_drops,
      two_factor_enabled,
      login_alerts,
      account_verified,
      blocked_users,
      terms_accepted_at,
      privacy_accepted_at,
      community_guidelines_accepted_at,
      beta_notice_accepted_at,
      legal_version,
      role,
      created_at,
      updated_at
    from public.profiles
    where id = auth.uid()
    limit 1
  ) as profile_row;
$$;

grant execute on function public.get_my_profile_settings() to authenticated;

alter table if exists public.profiles
  enable row level security;

drop policy if exists "profiles_select_own_profile" on public.profiles;
create policy "profiles_select_own_profile"
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_public_basic_read" on public.profiles;
create policy "profiles_public_basic_read"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "profiles_update_own_profile" on public.profiles;
create policy "profiles_update_own_profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

do $$
declare
  profile_column record;
begin
  for profile_column in
    select column_name
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
  loop
    execute format(
      'revoke select (%I) on public.profiles from authenticated',
      profile_column.column_name
    );
    execute format(
      'revoke update (%I) on public.profiles from authenticated',
      profile_column.column_name
    );
  end loop;
end $$;

revoke select on public.profiles from authenticated;
revoke update on public.profiles from authenticated;

grant select (
  id,
  name,
  username,
  bio,
  avatar_asset,
  avatar_url,
  fandom,
  location_visibility,
  favorite_group,
  bias,
  phrase,
  content_region,
  private_profile,
  created_at
) on public.profiles to authenticated;

grant update (
  name,
  username,
  bio,
  avatar_asset,
  avatar_url,
  fandom,
  country,
  region,
  city,
  language,
  bias,
  favorite_group,
  phrase,
  content_region,
  location_visibility,
  location_updated_at,
  private_profile,
  notifications_enabled,
  message_privacy,
  story_privacy,
  app_theme,
  profile_background,
  notify_messages,
  notify_stars,
  notify_comments,
  notify_followers,
  notify_drops,
  terms_accepted_at,
  privacy_accepted_at,
  community_guidelines_accepted_at,
  beta_notice_accepted_at,
  legal_version
) on public.profiles to authenticated;

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
    from public.profiles as p
    where p.username = candidate_username
      and p.id <> new.id
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
    content_region,
    location_visibility,
    private_profile,
    created_at,
    updated_at
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
    nullif(trim(new.raw_user_meta_data ->> 'language'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'favorite_group'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'bias'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'content_region'), ''),
    case
      when nullif(trim(new.raw_user_meta_data ->> 'country'), '') is not null
        then 'country'
      else null
    end,
    false,
    now(),
    now()
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
