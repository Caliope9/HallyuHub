# HallyuHub - procesamiento seguro de eliminacion de cuenta v1

Este documento es una propuesta de backend. No ejecuta eliminaciones y no debe
implementarse dentro de Flutter.

## Principios

- Una Edge Function procesa una solicitud por `request_id`.
- La funcion valida un JWT de servicio interno y carga la solicitud mediante
  una operacion protegida del backend.
- `service_role` existe solamente como secreto de la Edge Function; nunca se
  entrega a Flutter, al cliente web ni a logs.
- Se usa un bloqueo por fila y una clave de idempotencia basada en
  `request_id`, para que dos ejecuciones no procesen la misma cuenta.
- No se usan `DELETE FROM` masivos, `TRUNCATE`, `DROP TABLE` ni consultas con
  nombres de tabla recibidos del cliente.
- Los fallos dejan la solicitud en `in_review` con un evento interno de error;
  no se marca `completed` si una etapa obligatoria falla.

## Orden propuesto por solicitud

1. Validar que la solicitud sea `pending` o `in_review` y cambiarla a
   `in_review` dentro de una operacion idempotente.
2. Identificar el `user_id` desde la solicitud, no desde un parámetro libre del
   cliente.
3. Eliminar o anonimizar los datos de perfil según la política aprobada,
   conservando solo el mínimo necesario para auditoría y seguridad.
4. Anonimizar o eliminar el contenido del usuario usando las columnas y tablas
   conocidas por el esquema: posts, comments, follows, blocks, messages,
   stories, drops y fancams. Los reportes se conservan de forma limitada y se
   anonimizan cuando ya no sean necesarios para una obligación legal o de
   seguridad.
5. Eliminar objetos de Storage cuyo path haya sido validado como perteneciente
   al usuario. No borrar un bucket completo ni paths recibidos sin validar.
6. Revocar sesiones y, como último paso irreversible, eliminar el usuario de
   `auth.users` mediante la API administrativa de Supabase desde la Edge
   Function.
7. Marcar la solicitud `completed` con `completed_at` solo después de que todas
   las etapas obligatorias hayan terminado correctamente.

## Tratamiento por dominio

| Dominio | Tratamiento propuesto |
| --- | --- |
| `profiles` | Anonimizar datos visibles y conservar únicamente el registro mínimo requerido por integridad/auditoría, según la política final aprobada. |
| `posts`, `drops`, `fancams`, `stories` | Retirar de la vista pública mediante el soft-delete existente y luego eliminar o anonimizar de forma controlada según la retención aprobada. |
| `comments` y comentarios de Drops/Fancams | Anonimizar autor y cuerpo cuando deban conservarse para el contexto de una conversación o reporte; retirar de la vista pública cuando corresponda. |
| `follows` y `blocks` | Eliminar las relaciones del usuario en ambos sentidos. |
| `messages` | Eliminar los mensajes propios cuando sea legalmente posible; conservar solo metadatos mínimos si son imprescindibles para abuso, seguridad o una obligación legal. |
| `content_reports` | Conservar o anonimizar el reporte solo cuando exista una razón legítima de seguridad, fraude, abuso o legal; nunca conservar más datos de los necesarios. |
| Storage | Borrar únicamente archivos que puedan atribuirse al usuario mediante rutas verificadas y una lista explícita de buckets. |
| `auth.users` | Eliminar al final, desde la Edge Function con la API administrativa; nunca desde Flutter ni desde una RPC pública. |

La decisión final entre eliminar y anonimizar por cada dominio debe aprobarse
junto con la política de retención. Este documento no inventa plazos.

## Pruebas obligatorias antes de producción

- solicitud inexistente, duplicada, cancelada y ya completada;
- dos ejecuciones concurrentes del mismo `request_id`;
- fallo en cada etapa y reintento idempotente;
- usuario sin media, con media y con reportes activos;
- comprobación de que el usuario ya no puede iniciar sesión después del paso
  final;
- comprobación de que no se procesan otras cuentas.

No activar el paso de `auth.users` ni usar usuarios reales hasta completar una
prueba aislada con datos sintéticos y revisión legal.
