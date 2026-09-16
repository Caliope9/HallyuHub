-- HallyuHub Beta Real v1 - Fix seguro de RLS para Mensajes/DM
-- Objetivo: permitir DMs reales entre participantes de una conversacion
-- aunque conversation_members haya quedado incompleto en datos viejos.
-- No borra tablas, conversaciones ni mensajes.

insert into public.conversation_members (conversation_id, user_id, role)
select conversations.id, conversations.created_by, 'owner'
from public.conversations conversations
on conflict (conversation_id, user_id) do nothing;

insert into public.conversation_members (conversation_id, user_id, role)
select conversations.id, conversations.recipient_id, 'member'
from public.conversations conversations
on conflict (conversation_id, user_id) do nothing;

drop policy if exists "conversations member read" on public.conversations;
drop policy if exists "conversations participant read" on public.conversations;
create policy "conversations participant read"
on public.conversations for select to authenticated
using (
  (select auth.uid()) = created_by
  or (select auth.uid()) = recipient_id
);

drop policy if exists "conversations member update" on public.conversations;
drop policy if exists "conversations participant update" on public.conversations;
create policy "conversations participant update"
on public.conversations for update to authenticated
using (
  (select auth.uid()) = created_by
  or (select auth.uid()) = recipient_id
)
with check (
  (select auth.uid()) = created_by
  or (select auth.uid()) = recipient_id
);

drop policy if exists "conversation members self read" on public.conversation_members;
drop policy if exists "conversation members participant read" on public.conversation_members;
create policy "conversation members participant read"
on public.conversation_members for select to authenticated
using (
  exists (
    select 1
    from public.conversations conversations
    where conversations.id = public.conversation_members.conversation_id
      and (
        conversations.created_by = (select auth.uid())
        or conversations.recipient_id = (select auth.uid())
      )
  )
);

drop policy if exists "conversation members creator insert" on public.conversation_members;
drop policy if exists "conversation members participant insert" on public.conversation_members;
create policy "conversation members participant insert"
on public.conversation_members for insert to authenticated
with check (
  exists (
    select 1
    from public.conversations conversations
    where conversations.id = public.conversation_members.conversation_id
      and (
        conversations.created_by = (select auth.uid())
        or conversations.recipient_id = (select auth.uid())
      )
      and (
        public.conversation_members.user_id = (select auth.uid())
        or conversations.created_by = (select auth.uid())
      )
  )
);

drop policy if exists "conversation members self update" on public.conversation_members;
drop policy if exists "conversation members participant update self" on public.conversation_members;
create policy "conversation members participant update self"
on public.conversation_members for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "messages member read" on public.messages;
drop policy if exists "messages participant read" on public.messages;
create policy "messages participant read"
on public.messages for select to authenticated
using (
  exists (
    select 1
    from public.conversations conversations
    where conversations.id = public.messages.conversation_id
      and (
        conversations.created_by = (select auth.uid())
        or conversations.recipient_id = (select auth.uid())
      )
  )
);

drop policy if exists "messages member insert" on public.messages;
drop policy if exists "messages participant insert" on public.messages;
create policy "messages participant insert"
on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and body <> ''
  and char_length(body) <= 1000
  and exists (
    select 1
    from public.conversations conversations
    where conversations.id = public.messages.conversation_id
      and (
        conversations.created_by = (select auth.uid())
        or conversations.recipient_id = (select auth.uid())
      )
      and conversations.request_status in ('pending', 'accepted')
  )
);

drop policy if exists "messages member update read state" on public.messages;
drop policy if exists "messages participant update read state" on public.messages;
create policy "messages participant update read state"
on public.messages for update to authenticated
using (
  exists (
    select 1
    from public.conversations conversations
    where conversations.id = public.messages.conversation_id
      and (
        conversations.created_by = (select auth.uid())
        or conversations.recipient_id = (select auth.uid())
      )
  )
)
with check (
  exists (
    select 1
    from public.conversations conversations
    where conversations.id = public.messages.conversation_id
      and (
        conversations.created_by = (select auth.uid())
        or conversations.recipient_id = (select auth.uid())
      )
  )
);
