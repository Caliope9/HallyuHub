-- HallyuHub Beta Real - Roles de administrador.
-- Ejecutar en Supabase SQL Editor.
-- Seguro para correr sobre una base existente: no borra datos.

alter table public.profiles
  add column if not exists role text not null default 'user';

alter table public.profiles
  alter column role set default 'user';

update public.profiles
set role = 'user'
where role is null
   or role not in ('user', 'moderator', 'admin');

alter table public.profiles
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
  on public.profiles(role);

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

create or replace function public.prevent_profile_role_self_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if new.role is distinct from old.role
     and not public.is_admin_or_moderator() then
    raise exception 'No tenes permisos para cambiar roles de perfil.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_self_escalation
  on public.profiles;

create trigger profiles_prevent_role_self_escalation
before update of role on public.profiles
for each row
execute function public.prevent_profile_role_self_escalation();

-- Cuenta owner/admin inicial.
update public.profiles
set role = 'admin'
where lower(email) = lower('leopaletta9@gmail.com');

do $$
begin
  if to_regclass('public.content_reports') is not null then
    execute 'alter table public.content_reports enable row level security';

    execute 'drop policy if exists "content reports admin read" on public.content_reports';
    execute 'create policy "content reports admin read"
      on public.content_reports
      for select
      to authenticated
      using (public.is_admin_or_moderator())';

    execute 'drop policy if exists "content reports admin update" on public.content_reports';
    execute 'create policy "content reports admin update"
      on public.content_reports
      for update
      to authenticated
      using (public.is_admin_or_moderator())
      with check (public.is_admin_or_moderator())';
  end if;
end $$;

do $$
begin
  if to_regclass('public.beta_access') is not null then
    execute 'alter table public.beta_access enable row level security';

    execute 'drop policy if exists "beta access admin read" on public.beta_access';
    execute 'create policy "beta access admin read"
      on public.beta_access
      for select
      to authenticated
      using (public.is_admin_or_moderator())';

    execute 'drop policy if exists "beta access admin update" on public.beta_access';
    execute 'create policy "beta access admin update"
      on public.beta_access
      for update
      to authenticated
      using (public.is_admin_or_moderator())
      with check (public.is_admin_or_moderator())';
  end if;
end $$;

notify pgrst, 'reload schema';
