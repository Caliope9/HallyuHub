-- HallyuHub content moderation v1.1
-- Proposal only. Do not execute before reviewing the deployed schema.
-- Preserves existing RLS policies and never changes content tables.

begin;
set local search_path = pg_catalog, public;

do $$
begin
  if to_regclass('public.content_reports') is null then
    raise exception 'content_reports does not exist';
  end if;
  if to_regprocedure('public.is_admin_or_moderator()') is null then
    raise exception 'is_admin_or_moderator() does not exist';
  end if;
end;
$$;

alter table public.content_reports
  add column if not exists resolution_action text,
  add column if not exists resolution_note text not null default '',
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewer_id uuid references public.profiles(id) on delete set null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.content_reports'::regclass
      and conname = 'content_reports_status_v1_1_check'
  ) then
    alter table public.content_reports
      add constraint content_reports_status_v1_1_check
      check (status in ('pending', 'reviewing', 'resolved', 'dismissed'))
      not valid;
  end if;
end;
$$;

alter table public.content_reports
  validate constraint content_reports_status_v1_1_check;

create index if not exists content_reports_status_created_v1_1_idx
  on public.content_reports(status, created_at desc);

create index if not exists content_reports_content_v1_1_idx
  on public.content_reports(content_type, content_id);

revoke all on table public.content_reports from public, anon;
revoke delete, truncate, trigger, references
  on table public.content_reports from authenticated;
grant insert, select, update on table public.content_reports to authenticated;

commit;
