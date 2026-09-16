# Auditoría backend de seguridad v1.1

## Esquema revisado

- `profiles` se crea desde un trigger `after insert on auth.users`; las
  migraciones históricas no tienen exactamente el mismo conjunto de columnas.
- Privacidad disponible: `private_profile`, `message_privacy` y `story_privacy`.
- Roles: `user`, `moderator`, `admin`, con helpers existentes para comprobarlos.
- Reportes: `content_reports`; la moderación manual existente mantiene el flujo
  reportar → admin → revisar → ocultar → resolver.
- Eliminación: `account_deletion_requests` y los RPC
  `hallyu_request_account_deletion`, `hallyu_get_account_deletion_status` y
  `hallyu_cancel_account_deletion`.
- Contenido: `posts`, `post_media`, `comments`, `stories`, `story_media`,
  `drops`, `drop_comments`, `fancams`, `fancam_comments`.
- Storage declarado: `avatars`, `post_media`, `story_media`, `drop_media`,
  `fancam_media`, `collection_media`.

## Decisiones de la v1.1

La migración agrega solo columnas y contratos nuevos. No hace `DROP`,
`TRUNCATE`, `DELETE`, `UPDATE` masivo ni elimina `auth.users`. No reemplaza a
ciegas los RPC de eliminación porque las migraciones existentes tienen firmas
de retorno distintas; ese cambio requiere una migración específica revisada
contra la firma desplegada.

`birth_date` queda fuera de los permisos de lectura/escritura de
`anon/authenticated`. Los usuarios existentes no se actualizan ni se les
calcula una edad retroactiva. El trigger valida fechas futuras/menores de 16 y
bloquea cambios de `birth_date` después del alta.

La función de enforcement exige sesión y rol `admin`/`moderator`; los estados
permitidos son `active`, `restricted`, `suspended` y `banned`. El motivo es
obligatorio. La autoridad final es backend/RLS, no Flutter.

## Eliminación definitiva

`process-account-deletion` está preparado pero deliberadamente no completa el
borrado hasta que exista el mapeo de esquema aprobado y el locking/idempotency
backend. Debe procesar una solicitud por ejecución, validar vencimiento en el
servidor, limpiar rutas de Storage pertenecientes al usuario, anonimizar lo que
deba retenerse y llamar finalmente a `auth.admin.deleteUser`. Nunca debe
aceptar nombres de tablas o rutas arbitrarias del cliente.

## Content safety

`unavailable` sigue siendo el resultado correcto sin proveedor. La tabla
`content_safety_checks` prepara el contrato para un proveedor real, pero no
concede permisos de escritura al cliente ni afirma que se analizó contenido.
