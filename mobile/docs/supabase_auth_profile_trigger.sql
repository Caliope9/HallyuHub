-- HallyuHub Beta Real v1 - Auth profile trigger
-- Run this in Supabase SQL Editor when auth.users are created but public.profiles
-- is not created automatically. It is safe to run again.

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
    'Chile',
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
  'Chile',
  'Español',
  'Por definir',
  'Bias secreto',
  'Latam'
from prepared_profiles
on conflict (id) do nothing;
