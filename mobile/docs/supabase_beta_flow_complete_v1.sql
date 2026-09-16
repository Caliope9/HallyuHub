-- HallyuHub Beta Real - complete public beta flow and app gate.
-- Safe migration: no DROP TABLE, no TRUNCATE, no DELETE FROM.

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
      when bs.value ~ '^[0-9]+$' then greatest(bs.value::integer, 0)
      else 100
    end
  into limit_value
  from public.beta_settings as bs
  where bs.key = 'beta_user_limit';

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
        platform = normalized_platform,
        updated_at = now()
      where bs.id = existing.id
      returning * into existing;
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
    select existing.status::text, waiting_position, approved_total, limit_value, true;
    return;
  end if;

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  target_status := case
    when approved_total < limit_value then 'approved'
    else 'waiting'
  end;

  insert into public.beta_signups (
    email,
    nickname,
    country,
    fandom,
    platform,
    status,
    invited_at,
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
    case when target_status = 'approved' then now() else null end,
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

create or replace function public.get_beta_signup_status(
  p_email text
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
  signup public.beta_signups%rowtype;
  limit_value integer := 100;
  approved_total integer := 0;
begin
  if normalized_email = ''
     or normalized_email !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' then
    raise exception 'Email invalido.'
      using errcode = '22023';
  end if;

  select
    case
      when bs.value ~ '^[0-9]+$' then greatest(bs.value::integer, 0)
      else 100
    end
  into limit_value
  from public.beta_settings as bs
  where bs.key = 'beta_user_limit';

  limit_value := coalesce(limit_value, 100);

  select *
  into signup
  from public.beta_signups as bs
  where lower(bs.email) = normalized_email
  limit 1;

  if signup.id is null then
    return;
  end if;

  perform public.refresh_beta_signup_positions();

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  select *
  into signup
  from public.beta_signups as bs
  where bs.id = signup.id;

  return query
  select
    signup.status::text,
    signup."position",
    approved_total,
    limit_value,
    true;
end;
$$;

create or replace function public.claim_beta_access_v2()
returns table (
  status text,
  beta_user_limit integer,
  approved_count integer,
  "position" integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  profile_email text;
  profile_name text;
  profile_role text := 'user';
  signup public.beta_signups%rowtype;
  access_status text := 'waitlist';
  limit_value integer := 100;
  approved_total integer := 0;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtext('hallyuhub_beta_access_v3'));

  select
    case
      when bs.value ~ '^[0-9]+$' then greatest(bs.value::integer, 0)
      else 100
    end
  into limit_value
  from public.beta_settings as bs
  where bs.key = 'beta_user_limit';

  limit_value := coalesce(limit_value, 100);

  select p.email, p.name, coalesce(p.role, 'user')
  into profile_email, profile_name, profile_role
  from public.profiles as p
  where p.id = current_user_id;

  if profile_email is null or trim(profile_email) = '' then
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

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  if lower(coalesce(profile_role, 'user')) in ('admin', 'moderator') then
    return query
    select 'approved'::text, limit_value, approved_total, null::integer;
    return;
  end if;

  select *
  into signup
  from public.beta_signups as bs
  where lower(bs.email) = lower(profile_email)
  limit 1;

  if signup.id is null then
    return query
    select 'waitlist'::text, limit_value, approved_total, null::integer;
    return;
  end if;

  perform public.refresh_beta_signup_positions();

  select *
  into signup
  from public.beta_signups as bs
  where bs.id = signup.id;

  access_status := case signup.status
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
    case when access_status = 'approved' then coalesce(signup.invited_at, now()) else null end,
    case when access_status = 'waitlist' then now() else null end,
    now(),
    now()
  )
  on conflict (user_id) do update
  set
    email = coalesce(excluded.email, public.beta_access.email),
    status = excluded.status,
    approved_at = case
      when excluded.status = 'approved' then coalesce(public.beta_access.approved_at, excluded.approved_at, now())
      else public.beta_access.approved_at
    end,
    waitlisted_at = case
      when excluded.status = 'waitlist' then coalesce(public.beta_access.waitlisted_at, excluded.waitlisted_at, now())
      else public.beta_access.waitlisted_at
    end,
    updated_at = now();

  return query
  select
    access_status,
    limit_value,
    approved_total,
    case when access_status = 'waitlist' then signup."position" else null end;
end;
$$;

grant execute on function public.submit_beta_signup(text, text, text, text, text, boolean) to anon;
grant execute on function public.submit_beta_signup(text, text, text, text, text, boolean) to authenticated;
grant execute on function public.get_beta_signup_status(text) to anon;
grant execute on function public.get_beta_signup_status(text) to authenticated;
grant execute on function public.claim_beta_access_v2() to authenticated;
