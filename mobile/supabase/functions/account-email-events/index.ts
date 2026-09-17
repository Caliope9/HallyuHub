import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { sendAccountEmail, type AccountEmailEvent } from '../_shared/account_email.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const eventToken = Deno.env.get('EMAIL_EVENTS_TOKEN')
if (!supabaseUrl || !serviceRoleKey || !eventToken) throw new Error('backend configuration missing')

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
})

type WebhookPayload = {
  event?: AccountEmailEvent
  type?: string
  table?: string
  record?: Record<string, unknown>
  old_record?: Record<string, unknown> | null
}

function stringValue(record: Record<string, unknown> | undefined, key: string): string | null {
  const value = record?.[key]
  return typeof value === 'string' && value.trim() ? value.trim() : null
}

async function resolveEmail(record: Record<string, unknown> | undefined): Promise<string | null> {
  const direct = stringValue(record, 'email')
  if (direct) return direct
  const userId = stringValue(record, 'user_id') ?? stringValue(record, 'id')
  if (!userId) return null
  const { data, error } = await admin.auth.admin.getUserById(userId)
  if (error) return null
  return data.user.email ?? null
}

function inferEvent(payload: WebhookPayload): AccountEmailEvent | null {
  if (payload.event) return payload.event
  if (payload.table === 'profiles' && payload.type === 'INSERT') return 'welcome'
  if (payload.table !== 'account_deletion_requests') return null
  const status = stringValue(payload.record, 'status')
  const oldStatus = stringValue(payload.old_record ?? undefined, 'status')
  if (!oldStatus && status === 'pending') return 'account_deletion_requested'
  if (oldStatus !== 'canceled' && status === 'canceled') return 'account_deletion_canceled'
  return null
}

Deno.serve(async (request) => {
  if (request.method !== 'POST' || request.headers.get('x-hallyuhub-email-events-token') !== eventToken) {
    return new Response(JSON.stringify({ error: 'backend_only' }), { status: 401 })
  }
  try {
    const payload = await request.json() as WebhookPayload
    const event = inferEvent(payload)
    if (!event) return new Response(JSON.stringify({ status: 'ignored' }), { status: 202 })
    const record = payload.record
    const to = await resolveEmail(record)
    const requestId = stringValue(record, 'id')
    if (!to || !requestId) return new Response(JSON.stringify({ status: 'skipped' }), { status: 202 })
    await sendAccountEmail({
      event,
      to,
      requestId,
      displayName: stringValue(record, 'name'),
      username: stringValue(record, 'username'),
      recoverableUntil: stringValue(record, 'recoverable_until'),
    })
    return new Response(JSON.stringify({ status: 'sent' }), { status: 200 })
  } catch (error) {
    console.error('account email event failed', error instanceof Error ? error.message : 'unknown_error')
    return new Response(JSON.stringify({ error: 'email_delivery_failed' }), { status: 503 })
  }
})
