-- Route group approvals through a licensed image check.
-- The v1 curator function remains private to the postgres-owned wrapper.
create or replace function public.approve_licensed_group_suggestion(
  p_suggestion_id uuid,
  p_name text,
  p_bio text,
  p_source_url text,
  p_members text[],
  p_discography text[],
  p_admin_notes text,
  p_image_url text,
  p_image_source text,
  p_image_license text,
  p_image_attribution text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  entity_id uuid;
begin
  if not public.is_admin_or_moderator() then
    raise exception 'not allowed';
  end if;
  if coalesce(p_image_url, '') !~ '^https://[^ ]+$'
     or coalesce(p_image_source, '') !~ '^https://[^ ]+$'
     or length(trim(coalesce(p_image_license, ''))) < 3
     or length(trim(coalesce(p_image_attribution, ''))) < 3
  then
    raise exception 'licensed group image and attribution required';
  end if;

  entity_id := public.approve_complete_group_suggestion(
    p_suggestion_id, p_name, p_bio, p_source_url,
    p_members, p_discography, p_admin_notes
  );
  update public.kpop_entities set
    image_url = trim(p_image_url),
    image_source = trim(p_image_source),
    image_license = trim(p_image_license),
    attribution = trim(p_image_attribution),
    updated_at = now()
  where id = entity_id and entity_type = 'group';
  if not found then
    raise exception 'approved group not found';
  end if;
  return entity_id;
end;
$$;

alter function public.approve_licensed_group_suggestion(
  uuid, text, text, text, text[], text[], text, text, text, text, text
) owner to postgres;
revoke execute on function public.approve_licensed_group_suggestion(
  uuid, text, text, text, text[], text[], text, text, text, text, text
) from public, anon;
grant execute on function public.approve_licensed_group_suggestion(
  uuid, text, text, text, text[], text[], text, text, text, text, text
) to authenticated;

revoke execute on function public.approve_complete_group_suggestion(
  uuid, text, text, text, text[], text[], text
) from public, anon, authenticated;
