// Prepared worker. Do not deploy or invoke from Flutter.
// service_role exists only in this Edge Function environment.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const url = Deno.env.get('SUPABASE_URL')
const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
if (!url || !serviceRole) throw new Error('backend configuration missing')
const admin = createClient(url, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } })

type RequestRow = { id: string; user_id: string | null; status: string; requested_at: string; recoverable_until: string | null; processing_token: string | null; audit_fk_on_delete?: string }
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const BUCKETS = ['avatars', 'post_media', 'story_media', 'drop_media', 'fancam_media', 'collection_media'] as const

async function updateOwned(table: string, values: Record<string, unknown>, column: string, userId: string) {
  const { error } = await admin.from(table).update(values).eq(column, userId)
  if (error) throw new Error(`${table}: ${error.message}`)
}
async function deleteOwned(table: string, column: string, userId: string) {
  const { error } = await admin.from(table).delete().eq(column, userId)
  if (error) throw new Error(`${table}: ${error.message}`)
}

async function listOwnedStoragePaths(bucket: (typeof BUCKETS)[number], prefix: string): Promise<string[]> {
  const paths: string[] = []
  const pageSize = 1000
  for (let offset = 0; ; offset += pageSize) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: pageSize,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    })
    if (error) throw new Error(`storage list ${bucket}: ${error.message}`)
    const entries = data ?? []
    for (const entry of entries) {
      if (!entry.name) continue
      const path = `${prefix}/${entry.name}`
      const isFolder = (entry as { id?: string | null }).id === null
      if (isFolder) {
        paths.push(...await listOwnedStoragePaths(bucket, path))
      } else {
        paths.push(path)
      }
    }
    if (entries.length < pageSize) break
  }
  return paths
}

async function removeOwnedStorage(userId: string) {
  for (const bucket of BUCKETS) {
    const paths = await listOwnedStoragePaths(bucket, userId)
    for (let offset = 0; offset < paths.length; offset += 1000) {
      const { error } = await admin.storage.from(bucket).remove(paths.slice(offset, offset + 1000))
      if (error) throw new Error(`storage remove ${bucket}: ${error.message}`)
    }
  }
}
async function claim(requestId: string): Promise<RequestRow> {
  // Backend RPC must use SELECT FOR UPDATE/idempotency. Do not emulate this
  // with a client-side read/update race.
  const { data, error } = await admin.rpc('hallyu_claim_account_deletion_v1_2', { p_request_id: requestId })
  if (error) throw new Error(`claim: ${error.message}`)
  const row = Array.isArray(data) ? data[0] : data
  if (!row) throw new Error('deletion request not found or already processing')
  return row as RequestRow
}
async function touchLease(requestId: string, token: string) {
  const { data, error } = await admin.rpc('hallyu_touch_account_deletion_lease_v1_3', {
    p_request_id: requestId,
    p_processing_token: token,
  })
  if (error) throw new Error('processing lease could not be renewed')
  const row = Array.isArray(data) ? data[0] : data
  if (!row || row.success !== true) throw new Error('processing lease is no longer current')
}
async function markFailed(requestId: string, token: string, message: string) {
  const { error } = await admin.from('account_deletion_requests').update({ status: 'in_review', admin_notes: `worker_failed:${message.slice(0, 1000)}` }).eq('id', requestId).eq('processing_token', token).eq('status', 'in_review')
  if (error) console.error('unable to mark request in_review', error.message)
}

export async function processOne(requestId: string) {
  if (!UUID.test(requestId)) throw new Error('invalid request id')
  const request = await claim(requestId)
  if (request.status === 'completed') return { requestId: request.id, status: 'completed' as const }
  // ON DELETE SET NULL is the durable marker that Auth deletion already ran.
  // This branch lets a retry finish only the audit row after a post-delete
  // network failure, while still requiring the current lease token.
  if (request.status === 'in_review' && request.user_id === null) {
    if (!request.processing_token) throw new Error('request has no processing token')
    const token = request.processing_token
    await touchLease(request.id, token)
    const { data: completed, error } = await admin.from('account_deletion_requests')
      .update({ status: 'completed', completed_at: new Date().toISOString(), processing_token: null, processing_started_at: null })
      .eq('id', request.id).eq('processing_token', token).eq('status', 'in_review')
      .select('id').maybeSingle()
    if (error) throw new Error('completion audit failed')
    if (!completed) throw new Error('completion lease is no longer current')
    return { requestId: request.id, status: 'completed' as const }
  }
  if (!request.user_id || !request.recoverable_until) throw new Error('request has no recoverable deadline/user')
  if (!request.processing_token) throw new Error('request has no processing token')
  if (request.audit_fk_on_delete !== 'set_null') throw new Error('audit FK must be ON DELETE SET NULL before processing')
  if (new Date(request.recoverable_until).getTime() > Date.now()) throw new Error('recovery window has not expired')
  const userId = request.user_id
  const token = request.processing_token
  try {
    const now = new Date().toISOString()
    await touchLease(request.id, token)
    await updateOwned('posts', { status: 'deleted', deleted_at: now, updated_at: now }, 'author_id', userId)
    await touchLease(request.id, token)
    await updateOwned('drops', { status: 'deleted', deleted_at: now, updated_at: now }, 'author_id', userId)
    await touchLease(request.id, token)
    await updateOwned('fancams', { status: 'deleted', deleted_at: now, updated_at: now }, 'author_id', userId)
    await touchLease(request.id, token)
    await updateOwned('stories', { deleted_at: now, archived_at: now, expires_at: now, updated_at: now }, 'author_id', userId)
    await touchLease(request.id, token)
    for (const [table, column] of [
      ['post_likes', 'user_id'], ['post_saves', 'user_id'], ['story_views', 'viewer_id'], ['story_likes', 'user_id'],
      ['drop_likes', 'user_id'], ['drop_saves', 'user_id'], ['fancam_likes', 'user_id'], ['fancam_saves', 'user_id'],
      ['follows', 'follower_id'], ['user_blocks', 'blocker_id'], ['kpop_entity_follows', 'user_id'],
      ['conversation_members', 'user_id'], ['messages', 'sender_id'],
    ] as const) await deleteOwned(table, column, userId)
    await touchLease(request.id, token)
    await deleteOwned('follows', 'following_id', userId)
    await deleteOwned('user_blocks', 'blocked_id', userId)
    await deleteOwned('notifications', 'recipient_id', userId)
    await deleteOwned('notifications', 'actor_id', userId)
    await deleteOwned('comments', 'author_id', userId)
    await deleteOwned('drop_comments', 'author_id', userId)
    await deleteOwned('fancam_comments', 'author_id', userId)
    // Retain report content/reason/status as audit, but remove each user link independently.
    await updateOwned('content_reports', { reporter_id: null }, 'reporter_id', userId)
    await updateOwned('content_reports', { reported_user_id: null }, 'reported_user_id', userId)
    await touchLease(request.id, token)
    await removeOwnedStorage(userId)
    // profiles.id -> auth.users.id is ON DELETE CASCADE in the deployed schema.
    // Do not update birth_date here: the profile trigger could rehydrate it.
    await touchLease(request.id, token)
    // Final irreversible step. Never call this from Flutter.
    const { error: authError } = await admin.auth.admin.deleteUser(userId)
    if (authError) throw new Error(`auth delete: ${authError.message}`)
    const { data: completed, error: completeError } = await admin.from('account_deletion_requests').update({ status: 'completed', completed_at: new Date().toISOString(), user_id: null, processing_token: null, processing_started_at: null }).eq('id', request.id).eq('processing_token', token).eq('status', 'in_review').select('id').maybeSingle()
    if (completeError) throw new Error('completion audit failed')
    if (!completed) throw new Error('completion lease is no longer current')
    return { requestId: request.id, status: 'completed' as const }
  } catch (error) {
    await markFailed(request.id, token, error instanceof Error ? error.message : String(error))
    throw error
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
      status: 405,
      headers: { 'content-type': 'application/json' },
    })
  }

  const authorization = request.headers.get('authorization')
  if (authorization !== `Bearer ${serviceRole}`) {
    return new Response(JSON.stringify({ error: 'backend_only' }), {
      status: 401,
      headers: { 'content-type': 'application/json' },
    })
  }

  try {
    const body = await request.json()
    const requestId = typeof body?.request_id === 'string' ? body.request_id : ''
    const result = await processOne(requestId)
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    })
  } catch (error) {
    console.error('account deletion worker failed', error instanceof Error ? error.message : 'unknown error')
    return new Response(JSON.stringify({ error: 'account_deletion_failed' }), {
      status: 409,
      headers: { 'content-type': 'application/json' },
    })
  }
})
