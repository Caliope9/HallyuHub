-- HallyuHub account deletion lease heartbeat v1.3.
-- REVIEW ONLY: do not execute until the deployed v1.3 schema is approved.
-- No data deletion, table changes, or user changes are performed here.

create or replace function public.hallyu_touch_account_deletion_lease_v1_3(
  p_request_id uuid,
  p_processing_token uuid
)
returns table(success boolean)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'backend_only' using errcode = '42501';
  end if;

  -- UPDATE takes the row lock atomically. An expired or replaced token
  -- cannot renew a lease, so an old worker cannot continue processing.
  return query
  update public.account_deletion_requests
     set processing_started_at = now()
   where id = p_request_id
     and processing_token = p_processing_token
     and status = 'in_review'
     and processing_started_at is not null
     and processing_started_at >= now() - interval '15 minutes'
  returning true;

  if not found then
    return query select false;
  end if;
end;
$$;

revoke all on function public.hallyu_touch_account_deletion_lease_v1_3(uuid, uuid)
from public, anon, authenticated;
grant execute on function public.hallyu_touch_account_deletion_lease_v1_3(uuid, uuid)
to service_role;
