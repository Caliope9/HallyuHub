-- Historical grants bypass or exceed the intended read-only catalog API.
-- Keep SELECT for anon/authenticated; keep full service_role access.
revoke truncate, trigger, references on table public.kpop_entities
  from anon, authenticated;
