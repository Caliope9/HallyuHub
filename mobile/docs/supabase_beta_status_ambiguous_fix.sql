-- HallyuHub Beta Real - fix ambiguous status references in beta signup/access RPCs.
-- Safe to run over the existing beta schema.
-- No table drops, truncates, deletes, user resets, or automatic approvals are performed here.

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

  select existing_signup.*
  into existing
  from public.beta_signups as existing_signup
  where lower(existing_signup.email) = normalized_email
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
      returning bs.* into existing;
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

  -- New public beta requests remain waiting so Leandro can review them in Admin Panel > Beta.
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
      when bs.value ~ '^[0-9]+$' then greatest(bs.value::integer, 0)
      else 100
    end
  into limit_value
  from public.beta_settings as bs
  where bs.key = 'beta_user_limit';

  limit_value := coalesce(limit_value, 100);

  select p.email, p.name
  into profile_email, profile_name
  from public.profiles as p
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
  from public.beta_access as ba
  where ba.user_id = current_user_id;

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  if existing_status is not null then
    update public.beta_access as ba
    set
      email = coalesce(nullif(profile_email, ''), ba.email),
      updated_at = now()
    where ba.user_id = current_user_id;

    return query select existing_status, limit_value, approved_total;
    return;
  end if;

  select bs.status
  into signup_status
  from public.beta_signups as bs
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

grant execute on function public.submit_beta_signup(text, text, text, text, text, boolean) to anon;
grant execute on function public.submit_beta_signup(text, text, text, text, text, boolean) to authenticated;
grant execute on function public.claim_beta_access() to authenticated;
grant execute on function public.refresh_beta_signup_positions() to authenticated;
