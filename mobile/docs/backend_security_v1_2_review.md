# HallyuHub backend security v1.2 — revisión final pendiente

Este documento y `supabase_safety_age_deletion_v1_2.sql` son preparación. No se
ejecutaron SQL, no hubo deploy y no se borraron usuarios ni contenido.

La app valida la fecha completa: 15 o menos bloqueado, 16/17 permitido, 18+
permitido, fecha futura o inválida rechazada. El trigger v1.2 repite esas reglas
en PostgreSQL e impide cambiar `birth_date`. El age gate de Flutter evita el flujo
normal; solo backend/RLS puede impedir bypass.

La privacidad real usa revocación de SELECT de tabla más grants por columna y la
vista `public_profiles_v1_2`; `birth_date`, `enforcement_status` y
`enforcement_until` no quedan expuestos por perfiles públicos. La migración debe
verificar en staging que las columnas enumeradas existan y que las consultas de
perfil sean explícitas.

Una cuenta teen nueva queda privada, con mensajes e historias para Seguidores,
sin fecha pública, badge de menor ni GPS automático. El backend debe imponer los
defaults; no se modifican cuentas existentes.

La eliminación distingue `pending`/`in_review` recuperable, `canceled` al
reactivar y `completed` irreversible. El deadline lo fija el servidor a 30 días;
NULL legado no autoriza recuperación. Los RPC actuales se mantienen por
compatibilidad, pero sus firmas pueden no devolver `recoverable_until`. Actualizar
sus `RETURNS TABLE` y permitir cancelación de `in_review` requiere una migración
controlada que puede necesitar `DROP FUNCTION`; no se ejecutó.

`ContentSafetyService` es arquitectura, no moderación automática real: sin
proveedor devuelve `unavailable`, nunca `safe`; sexual explícito, explotación
sexual, gore extremo y violencia gráfica extrema son prohibidos y los dudosos van
a `needs_review`/revisión humana. No se bloquean publicaciones actuales por falta
de proveedor.

El enforcement preparado es `active`, `restricted`, `suspended`, `banned`.
Usuarios normales no pueden editarlo; la decisión debe venir de RPC/RLS/admin.
El trigger candidate bloquea nuevas escrituras de estados no activos, pero no
aplica sanciones reales hasta revisarlo y aplicarlo en backend.

El worker de Edge Function procesa un request por invocación, usa `service_role`
solo en el entorno backend, valida deadline, limita tablas/buckets a un mapa
explícito, usa idempotencia y deja `auth.admin.deleteUser` como último paso. La FK
histórica de la solicitud debe cambiarse a `ON DELETE SET NULL` antes de activar
el borrado final para conservar auditoría mínima. El worker falla cerrado antes
de mutar datos si el RPC de claim no confirma ese modo.

El RPC `hallyu_claim_account_deletion_v1_2` que el worker necesita para `FOR UPDATE`
e idempotencia no está definido en este paquete; por eso el worker no puede
activarse todavía sin la migración backend controlada correspondiente. Esto es un
bloqueador deliberado, no una simulación de locking.

Auditoría SQL: no contiene DROP TABLE, TRUNCATE, DELETE masivo, UPDATE masivo,
borrado de `auth.users`, secretos ni service_role en Flutter. Las funciones usan
`SECURITY DEFINER`, `search_path` fijo y `auth.uid()`. Faltan pruebas staging de
grants/RLS, firmas RPC, concurrencia, idempotencia y retención por tabla antes de
aplicar v1.2.
