-- HallyuHub Child Safety Reports v1
-- Preparación local solamente. No aplicar sin revisar el schema remoto.
-- Extiende content_reports para identificar reportes críticos de child safety.

do $$
begin
  if to_regclass('public.content_reports') is null then
    raise exception 'public.content_reports must exist before child safety reports';
  end if;
end;
$$;

do $$
begin
  -- Replace only the known legacy reason constraints. Existing data is kept.
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.content_reports'::regclass
      and conname = 'content_reports_reason_check'
  ) then
    alter table public.content_reports
      drop constraint content_reports_reason_check;
  end if;

  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.content_reports'::regclass
      and conname = 'content_reports_reason_v1_1_check'
  ) then
    alter table public.content_reports
      drop constraint content_reports_reason_v1_1_check;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.content_reports'::regclass
      and conname = 'content_reports_child_safety_reason_check'
  ) then
    alter table public.content_reports
      add constraint content_reports_child_safety_reason_check
      check (
        reason in (
          'spam',
          'harassment',
          'child_safety',
          'sexual_content',
          'violence_threats',
          'hate_discrimination',
          'scam_suspicious_sale',
          'misinformation',
          'copyright',
          'other'
        )
      );
  end if;
end;
$$;

create or replace function public.hallyu_normalize_child_safety_report_metadata()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  -- These fields are server-owned; preserve unrelated client metadata only.
  new.metadata := coalesce(new.metadata, '{}'::jsonb)
    - 'safety_category'
    - 'severity'
    - 'priority'
    - 'requires_immediate_review';

  if new.reason = 'child_safety' then
    new.metadata := new.metadata || jsonb_build_object(
      'safety_category', 'child_safety',
      'severity', 'critical',
      'priority', 'urgent',
      'requires_immediate_review', true
    );
  end if;

  return new;
end;
$$;

alter function public.hallyu_normalize_child_safety_report_metadata()
  owner to postgres;

revoke all on function public.hallyu_normalize_child_safety_report_metadata()
  from public, anon, authenticated;

drop trigger if exists content_reports_child_safety_metadata_trigger
  on public.content_reports;

create trigger content_reports_child_safety_metadata_trigger
before insert or update of reason, metadata
on public.content_reports
for each row
execute function public.hallyu_normalize_child_safety_report_metadata();

create index if not exists content_reports_child_safety_priority_idx
  on public.content_reports (status, created_at desc)
  where metadata->>'safety_category' = 'child_safety';

notify pgrst, 'reload schema';
