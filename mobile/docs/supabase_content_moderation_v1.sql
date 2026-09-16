-- HallyuHub moderation v1
-- Proposal only. Do not execute before reviewing the deployed schema.
-- No suspend_user action is included.

begin;
set local search_path = pg_catalog, public;

do $$
begin
  if to_regclass('public.content_reports') is null then
    raise exception 'content_reports does not exist';
  end if;

  if exists (
    select 1 from public.content_reports
    where status not in ('pending', 'reviewing', 'resolved', 'dismissed')
  ) then
    raise exception 'content_reports contains an incompatible status';
  end if;
end;
$$;

alter table public.content_reports
  add constraint content_reports_status_v1_check
  check (status in ('pending', 'reviewing', 'resolved', 'dismissed'))
  not valid;

alter table public.content_reports validate constraint content_reports_status_v1_check;

alter table public.content_reports
  add column if not exists resolution_action text,
  add column if not exists resolution_note text not null default '',
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references public.profiles(id) on delete set null;

create index if not exists content_reports_status_created_idx
  on public.content_reports(status, created_at desc);

create index if not exists content_reports_content_idx
  on public.content_reports(content_type, content_id);

revoke delete, truncate, trigger, references
on table public.content_reports from authenticated;

grant insert, select, update on table public.content_reports to authenticated;

commit;
