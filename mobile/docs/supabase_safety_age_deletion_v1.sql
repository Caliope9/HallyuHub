-- Preparación de backend. No ejecutar desde Flutter ni desde este commit.
-- service_role solo debe existir como secreto de una Edge Function de backend.

alter table public.profiles add column if not exists birth_date date;
alter table public.profiles add column if not exists enforcement_status text not null default 'active';
alter table public.profiles add column if not exists enforcement_until timestamptz;
alter table public.account_deletion_requests add column if not exists recoverable_until timestamptz;

-- El backend debe imponer estas invariantes con trigger/RLS:
-- * birth_date <= current_date - interval '16 years';
-- * birth_date nunca se cambia desde cliente una vez verificada;
-- * profiles de 16–17: private_profile=true, message_privacy='Seguidores',
--   story_privacy='Seguidores' (el cliente no puede relajar estas reglas);
-- * request crea recoverable_until = requested_at + interval '30 days';
-- * cancel/reactivate solo antes de recoverable_until y nunca para completed;
-- * una Edge Function procesa el borrado físico al vencer la ventana. Flutter
--   nunca ejecuta DELETE sobre usuarios, auth.users o Storage.

-- Content safety debe escribir safe/unsafe/needs_review/unavailable y conservar
-- provider, categorías, error y timestamps. Un proveedor ausente o fallido es
-- unavailable; jamás se convierte en safe.
