export type AccountEmailEvent =
  | 'welcome'
  | 'account_deletion_requested'
  | 'account_deletion_canceled'
  | 'account_deletion_completed'

export type AccountEmailInput = {
  event: AccountEmailEvent
  to: string
  requestId: string
  displayName?: string | null
  username?: string | null
  recoverableUntil?: string | null
}

const APP_URL = 'https://www.hallyuhub.net'

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character] ?? character)
}

function greeting(input: AccountEmailInput): string {
  const name = input.displayName?.trim() || input.username?.trim()
  return name ? `Hola, ${escapeHtml(name)}.` : 'Hola.'
}

function dateLabel(value: string | null | undefined): string {
  if (!value) return 'dentro de 30 días'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'dentro de 30 días'
  return new Intl.DateTimeFormat('es-AR', {
    dateStyle: 'long',
    timeZone: 'UTC',
  }).format(date)
}

export function renderAccountEmail(input: AccountEmailInput): {
  subject: string
  html: string
  text: string
} {
  const hello = greeting(input)
  let subject: string
  let title: string
  let body: string
  let text: string

  switch (input.event) {
    case 'welcome':
      subject = '¡Bienvenido/a a HallyuHub! 💜'
      title = 'Bienvenido/a a HallyuHub'
      body = `${hello}<p>Gracias por sumarte a HallyuHub. Hally te acompaña para descubrir grupos y artistas, seguir noticias, participar en comunidades y compartir posts, Stories, Drops y Fancams.</p><p>También podés conectar con otros fans mediante mensajes. Recordá respetar las reglas de comunidad y cuidar la privacidad de las demás personas.</p><p><a href="${APP_URL}/terms">Términos</a> · <a href="${APP_URL}/privacy">Privacidad</a> · <a href="${APP_URL}/community-guidelines">Normas de comunidad</a></p>`
      text = `${hello}\n\nGracias por sumarte a HallyuHub. Hally te acompaña para descubrir grupos y artistas, seguir noticias, participar en comunidades y compartir posts, Stories, Drops y Fancams.\n\nTambién podés conectar con otros fans mediante mensajes. Recordá respetar las reglas de comunidad y cuidar la privacidad de las demás personas.\n\nTérminos: ${APP_URL}/terms\nPrivacidad: ${APP_URL}/privacy\nNormas de comunidad: ${APP_URL}/community-guidelines`
      break
    case 'account_deletion_requested':
      subject = 'Solicitud de eliminación de tu cuenta de HallyuHub'
      title = 'Recibimos tu solicitud'
      body = `${hello}<p>Recibimos tu solicitud de eliminación. Tu cuenta todavía <strong>no fue eliminada definitivamente</strong>.</p><p>Podés cancelar la solicitud desde HallyuHub hasta el <strong>${escapeHtml(dateLabel(input.recoverableUntil))}</strong>. La ventana recuperable es de 30 días.</p><p>Ayuda: <a href="${APP_URL}/delete-account">${APP_URL}/delete-account</a></p>`
      text = `${hello}\n\nRecibimos tu solicitud de eliminación. Tu cuenta todavía no fue eliminada definitivamente.\n\nPodés cancelarla desde HallyuHub hasta el ${dateLabel(input.recoverableUntil)}. La ventana recuperable es de 30 días.\n\nAyuda: ${APP_URL}/delete-account`
      break
    case 'account_deletion_canceled':
      subject = 'Tu cuenta de HallyuHub seguirá activa'
      title = 'Eliminación cancelada'
      body = `${hello}<p>La solicitud de eliminación fue cancelada correctamente. Tu cuenta seguirá activa y podrás continuar usando HallyuHub.</p>`
      text = `${hello}\n\nLa solicitud de eliminación fue cancelada correctamente. Tu cuenta seguirá activa y podrás continuar usando HallyuHub.`
      break
    case 'account_deletion_completed':
      subject = 'Tu cuenta de HallyuHub fue eliminada'
      title = 'Cuenta eliminada'
      body = `${hello}<p>Confirmamos que tu cuenta de HallyuHub fue eliminada.</p><p>Algunos registros anonimizados pueden conservarse por motivos de seguridad, moderación o cumplimiento legal, según nuestra política.</p><p><a href="${APP_URL}/privacy">Privacidad</a> · <a href="${APP_URL}/delete-account">Información sobre eliminación</a></p>`
      text = `${hello}\n\nConfirmamos que tu cuenta de HallyuHub fue eliminada.\n\nAlgunos registros anonimizados pueden conservarse por motivos de seguridad, moderación o cumplimiento legal, según nuestra política.\n\nPrivacidad: ${APP_URL}/privacy\nInformación sobre eliminación: ${APP_URL}/delete-account`
      break
  }

  const html = `<!doctype html><html lang="es"><body style="margin:0;background:#080b18;color:#f7f5ff;font-family:Arial,sans-serif"><main style="max-width:600px;margin:0 auto;padding:32px 20px"><div style="border:1px solid #7c3aed;border-radius:20px;background:linear-gradient(145deg,#171238,#10182d);padding:28px"><div style="font-size:26px;font-weight:700;margin-bottom:24px">Hallyu<span style="color:#ff2f9f">Hub</span> 💜</div><h1 style="font-size:24px;margin:0 0 18px">${title}</h1><div style="font-size:16px;line-height:1.65;color:#e9e5f5">${body}</div></div><p style="font-size:12px;line-height:1.5;color:#aaa6ba;margin:18px 4px">Este es un email transaccional de HallyuHub. No contiene publicidad.</p></main></body></html>`
  return { subject, html, text }
}

export async function sendAccountEmail(input: AccountEmailInput): Promise<void> {
  const apiKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('EMAIL_FROM')
  if (!apiKey || !from) throw new Error('email_provider_not_configured')

  const rendered = renderAccountEmail(input)
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `hallyuhub-${input.event}-${input.requestId}`,
    },
    body: JSON.stringify({
      from,
      to: [input.to],
      subject: rendered.subject,
      html: rendered.html,
      text: rendered.text,
    }),
  })
  if (!response.ok) throw new Error(`email_provider_http_${response.status}`)
}
