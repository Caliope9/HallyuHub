-- HallyuHub Beta Real - referral links for /beta.
-- Safe migration: no DROP TABLE, no TRUNCATE, no DELETE FROM.

alter table if exists public.beta_signups
  add column if not exists referral_code text,
  add column if not exists referred_by uuid references public.beta_signups(id) on delete set null,
  add column if not exists referral_count integer not null default 0,
  add column if not exists referral_score integer not null default 0,
  add column if not exists priority_score integer not null default 0,
  add column if not exists last_referral_at timestamptz,
  add column if not exists share_url text,
  add column if not exists source text;

create unique index if not exists beta_signups_referral_code_key
  on public.beta_signups (referral_code)
  where referral_code is not null;

create index if not exists beta_signups_referred_by_idx
  on public.beta_signups (referred_by);

create index if not exists beta_signups_priority_waiting_idx
  on public.beta_signups (status, priority_score desc, created_at asc);

create table if not exists public.beta_referral_events (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references public.beta_signups(id) on delete cascade,
  referred_signup_id uuid not null references public.beta_signups(id) on delete cascade,
  points integer not null default 1,
  created_at timestamptz not null default now(),
  unique (referred_signup_id)
);

alter table public.beta_referral_events enable row level security;

drop policy if exists "beta referral events admin read" on public.beta_referral_events;
create policy "beta referral events admin read"
on public.beta_referral_events
for select
to authenticated
using (public.is_admin_or_moderator());

drop policy if exists "beta referral events admin update" on public.beta_referral_events;
create policy "beta referral events admin update"
on public.beta_referral_events
for update
to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

create or replace function public.generate_beta_referral_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  candidate text;
begin
  loop
    candidate := lower(substring(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    exit when not exists (
      select 1
      from public.beta_signups as bs
      where bs.referral_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

update public.beta_signups as bs
set referral_code = public.generate_beta_referral_code()
where bs.referral_code is null or trim(bs.referral_code) = '';

update public.beta_signups as bs
set share_url = 'https://web-hallyuhub.vercel.app/beta?ref=' || bs.referral_code
where bs.referral_code is not null
  and (bs.share_url is null or trim(bs.share_url) = '');

create or replace function public.refresh_beta_signup_positions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  with ordered_waiting as (
    select
      bs.id,
      row_number() over (
        order by
          coalesce(bs.priority_score, 0) desc,
          bs.created_at asc,
          bs.id asc
      )::integer as waiting_position
    from public.beta_signups as bs
    where bs.status = 'waiting'
  )
  update public.beta_signups as target
  set "position" = ordered_waiting.waiting_position,
      updated_at = now()
  from ordered_waiting
  where target.id = ordered_waiting.id;

  update public.beta_signups as bs
  set "position" = null,
      updated_at = now()
  where bs.status <> 'waiting'
    and bs."position" is not null;
end;
$$;

create or replace function public.submit_beta_signup_v2(
  p_email text,
  p_nickname text default null,
  p_country text default null,
  p_fandom text default null,
  p_platform text default 'other',
  p_accept_beta boolean default false,
  p_referral_code text default null,
  p_source text default null
)
returns table (
  status text,
  "position" integer,
  approved_count integer,
  beta_user_limit integer,
  duplicate boolean,
  referral_code text,
  referral_count integer,
  referral_score integer,
  priority_score integer,
  share_url text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  normalized_platform text := lower(trim(coalesce(p_platform, 'other')));
  normalized_referral_code text := lower(trim(coalesce(p_referral_code, '')));
  limit_value integer := 100;
  signup_row public.beta_signups%rowtype;
  referrer_id uuid;
  target_status text := 'waiting';
  approved_total integer := 0;
  daily_points integer := 0;
  inserted_events integer := 0;
  max_daily_referral_points integer := 10;
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

  perform pg_advisory_xact_lock(hashtext('hallyuhub_beta_signups_v2'));

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
  into signup_row
  from public.beta_signups as bs
  where lower(bs.email) = normalized_email
  limit 1;

  if signup_row.id is not null then
    if signup_row.status <> 'blocked' then
      update public.beta_signups as bs
      set
        nickname = coalesce(nullif(trim(coalesce(p_nickname, '')), ''), bs.nickname),
        country = coalesce(nullif(trim(coalesce(p_country, '')), ''), bs.country),
        fandom = coalesce(nullif(trim(coalesce(p_fandom, '')), ''), bs.fandom),
        platform = normalized_platform,
        referral_code = coalesce(nullif(bs.referral_code, ''), public.generate_beta_referral_code()),
        source = coalesce(nullif(trim(coalesce(p_source, '')), ''), bs.source),
        updated_at = now()
      where bs.id = signup_row.id
      returning * into signup_row;

      update public.beta_signups as bs
      set share_url = 'https://web-hallyuhub.vercel.app/beta?ref=' || bs.referral_code,
          updated_at = now()
      where bs.id = signup_row.id
        and (bs.share_url is null or trim(bs.share_url) = '')
      returning * into signup_row;
    end if;

    perform public.refresh_beta_signup_positions();

    select count(*)::integer
    into approved_total
    from public.beta_signups as bs
    where bs.status = 'approved';

    return query
    select
      signup_row.status::text,
      signup_row."position",
      approved_total,
      limit_value,
      true,
      signup_row.referral_code,
      coalesce(signup_row.referral_count, 0),
      coalesce(signup_row.referral_score, 0),
      coalesce(signup_row.priority_score, 0),
      coalesce(signup_row.share_url, 'https://web-hallyuhub.vercel.app/beta?ref=' || signup_row.referral_code);
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

  if normalized_referral_code <> '' then
    select bs.id
    into referrer_id
    from public.beta_signups as bs
    where lower(bs.referral_code) = normalized_referral_code
      and lower(bs.email) <> normalized_email
      and bs.status <> 'blocked'
    limit 1;
  end if;

  insert into public.beta_signups (
    email,
    nickname,
    country,
    fandom,
    platform,
    status,
    referral_code,
    referred_by,
    share_url,
    source,
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
    public.generate_beta_referral_code(),
    referrer_id,
    null,
    nullif(trim(coalesce(p_source, '')), ''),
    case when target_status = 'approved' then now() else null end,
    now(),
    now()
  )
  returning * into signup_row;

  update public.beta_signups as bs
  set share_url = 'https://web-hallyuhub.vercel.app/beta?ref=' || bs.referral_code
  where bs.id = signup_row.id
  returning * into signup_row;

  if referrer_id is not null and signup_row.status <> 'blocked' then
    select coalesce(sum(bre.points), 0)::integer
    into daily_points
    from public.beta_referral_events as bre
    where bre.referrer_id = referrer_id
      and bre.created_at >= date_trunc('day', now());

    if daily_points < max_daily_referral_points then
      insert into public.beta_referral_events (
        referrer_id,
        referred_signup_id,
        points,
        created_at
      )
      values (
        referrer_id,
        signup_row.id,
        1,
        now()
      )
      on conflict (referred_signup_id) do nothing;

      get diagnostics inserted_events = row_count;

      if inserted_events > 0 then
        update public.beta_signups as bs
        set
          referral_count = coalesce(bs.referral_count, 0) + 1,
          referral_score = coalesce(bs.referral_score, 0) + 1,
          priority_score = coalesce(bs.priority_score, 0) + 1,
          last_referral_at = now(),
          updated_at = now()
        where bs.id = referrer_id;
      end if;
    end if;
  end if;

  perform public.refresh_beta_signup_positions();

  select *
  into signup_row
  from public.beta_signups as bs
  where bs.id = signup_row.id;

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  return query
  select
    signup_row.status::text,
    signup_row."position",
    approved_total,
    limit_value,
    false,
    signup_row.referral_code,
    coalesce(signup_row.referral_count, 0),
    coalesce(signup_row.referral_score, 0),
    coalesce(signup_row.priority_score, 0),
    coalesce(signup_row.share_url, 'https://web-hallyuhub.vercel.app/beta?ref=' || signup_row.referral_code);
end;
$$;

create or replace function public.get_beta_signup_status_v2(
  p_email text
)
returns table (
  status text,
  "position" integer,
  approved_count integer,
  beta_user_limit integer,
  duplicate boolean,
  referral_code text,
  referral_count integer,
  referral_score integer,
  priority_score integer,
  share_url text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  signup_row public.beta_signups%rowtype;
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
  into signup_row
  from public.beta_signups as bs
  where lower(bs.email) = normalized_email
  limit 1;

  if signup_row.id is null then
    return;
  end if;

  if signup_row.referral_code is null or trim(signup_row.referral_code) = '' then
    update public.beta_signups as bs
    set referral_code = public.generate_beta_referral_code(),
        updated_at = now()
    where bs.id = signup_row.id
    returning * into signup_row;
  end if;

  if signup_row.share_url is null or trim(signup_row.share_url) = '' then
    update public.beta_signups as bs
    set share_url = 'https://web-hallyuhub.vercel.app/beta?ref=' || signup_row.referral_code,
        updated_at = now()
    where bs.id = signup_row.id
    returning * into signup_row;
  end if;

  perform public.refresh_beta_signup_positions();

  select *
  into signup_row
  from public.beta_signups as bs
  where bs.id = signup_row.id;

  select count(*)::integer
  into approved_total
  from public.beta_signups as bs
  where bs.status = 'approved';

  return query
  select
    signup_row.status::text,
    signup_row."position",
    approved_total,
    limit_value,
    true,
    signup_row.referral_code,
    coalesce(signup_row.referral_count, 0),
    coalesce(signup_row.referral_score, 0),
    coalesce(signup_row.priority_score, 0),
    coalesce(signup_row.share_url, 'https://web-hallyuhub.vercel.app/beta?ref=' || signup_row.referral_code);
end;
$$;

grant execute on function public.submit_beta_signup_v2(text, text, text, text, text, boolean, text, text) to anon;
grant execute on function public.submit_beta_signup_v2(text, text, text, text, text, boolean, text, text) to authenticated;
grant execute on function public.get_beta_signup_status_v2(text) to anon;
grant execute on function public.get_beta_signup_status_v2(text) to authenticated;
grant execute on function public.generate_beta_referral_code() to authenticated;
grant execute on function public.refresh_beta_signup_positions() to authenticated;
