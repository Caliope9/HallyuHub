-- HallyuHub Beta Real - Legal acceptance fields
-- Safe to run multiple times. Does not delete or rewrite existing data.

alter table public.profiles
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz,
  add column if not exists community_guidelines_accepted_at timestamptz,
  add column if not exists beta_notice_accepted_at timestamptz,
  add column if not exists legal_version text not null default '';

create index if not exists profiles_legal_version_idx
  on public.profiles (legal_version);

create index if not exists profiles_terms_accepted_at_idx
  on public.profiles (terms_accepted_at);
