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

alter table public.content_reports
  drop constraint if exists content_reports_reason_check;

alter table public.content_reports
  drop constraint if exists content_reports_reason_v1_1_check;

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

create index if not exists content_reports_child_safety_priority_idx
  on public.content_reports (status, created_at desc)
  where metadata->>'safety_category' = 'child_safety';

notify pgrst, 'reload schema';
