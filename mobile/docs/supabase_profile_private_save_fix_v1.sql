-- HallyuHub Beta Real - private profile save fix.
-- Safe to run more than once. Does not delete or reset existing data.

alter table if exists public.profiles
  add column if not exists private_profile boolean not null default false;

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
