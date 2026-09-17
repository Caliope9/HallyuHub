# HallyuHub — emails transaccionales v1

## Proveedor

Se preparó Resend como proveedor transaccional porque su API HTTP funciona
directamente desde Edge Functions y admite `Idempotency-Key`. La API key nunca
entra en Flutter, Web, el repositorio ni los logs.

## Edge Functions

- `supabase/functions/account-email-events/index.ts`: recibe eventos de
  webhooks backend autenticados y envía welcome, solicitud y cancelación.
- `supabase/functions/process-account-deletion/index.ts`: envía el email de
  eliminación completada después de `auth.admin.deleteUser`; si el proveedor
  falla, la eliminación y su auditoría continúan.
- `supabase/functions/_shared/account_email.ts`: plantillas HTML responsive,
  texto plano, escape de valores e idempotencia.

## Secretos requeridos

Configurar únicamente como secretos de Edge Functions:

- `RESEND_API_KEY`
- `EMAIL_FROM`
- `EMAIL_EVENTS_TOKEN`

La función también requiere los secretos backend ya existentes:
`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`.

## Notificaciones nativas de Supabase Auth

Supabase Auth contempla y puede enviar las notificaciones de seguridad
`password_changed` y `email_changed`. Son el camino elegido para estos dos
eventos: HallyuHub no los reenvía desde `account-email-events`, evitando
duplicados. Las plantillas están preparadas en
`supabase/templates/password_changed_notification.html` y
`supabase/templates/email_changed_notification.html`.

La notificación `email_changed` usa las variables nativas `{{ .OldEmail }}` y
`{{ .Email }}` para informar el cambio al destinatario previsto por Supabase.
El template de contraseña no inventa una fecha: Auth no expone una variable de
timestamp para ese template. El texto dice “recientemente” para no presentar
una hora falsa.

Estas notificaciones se envían después de que Supabase Auth confirma el cambio.
Si se activa un Send Email Hook global, debe manejar también esos tipos nativos
y reemplazar el envío incorporado; no se deben activar ambos caminos a la vez.
En un proyecto hosted, `config.toml` sirve como referencia/local config: la
configuración efectiva de templates y security notifications debe verificarse
en Authentication → Email Templates / Security Notifications o mediante la
Management API, sin poner secretos en este repositorio.

## Activación pendiente en Supabase

No se ejecutó ninguna configuración remota. Para automatizar los primeros tres
eventos, crear en Supabase Database Webhooks, apuntando a
`account-email-events`, con el header:

`x-hallyuhub-email-events-token: <EMAIL_EVENTS_TOKEN>`

Configurar:

1. `profiles` — `INSERT` — el evento se infiere como `welcome`.
2. `account_deletion_requests` — `INSERT` — el evento se infiere como
   `account_deletion_requested`.
3. `account_deletion_requests` — `UPDATE` — evento inferido cuando el estado
   cambia a `canceled`.

El webhook debe incluir `type`, `table`, el registro (`record`) y, para
updates, el registro anterior (`old_record`). No se guardan cuerpos de email ni
datos sensibles como logs de aplicación. Resend recibe únicamente el
destinatario y los datos mínimos para personalizar el mensaje. El webhook no
debe configurarse para eventos `password_changed` o `email_changed`, porque
esos ya quedan cubiertos por Auth nativo.

## Idempotencia y fallos

Cada envío usa una clave estable basada en evento + ID de perfil/solicitud.
Reintentos del webhook no generan duplicados cuando Resend conserva la clave.
Los fallos de welcome/deletion requested/canceled devuelven error transitorio
para permitir reintento. El fallo del email de eliminación completada no
revierte ni bloquea el borrado de cuenta.

## Pruebas sin usuarios reales

Usar el modo de prueba del proveedor o un dominio/verificador de sandbox y
cuentas sintéticas. Verificar cada plantilla en HTML y texto plano, repetir el
mismo evento para comprobar idempotencia y simular respuestas 4xx/5xx. No usar
la cuenta principal ni invocar el worker contra usuarios reales.

## Estado

Código preparado y no desplegado en esta tarea. Falta configurar/verificar el
dominio remitente, guardar los tres secretos y crear los tres webhooks en
Supabase antes de producción.
