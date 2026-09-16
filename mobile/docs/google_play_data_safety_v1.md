# HallyuHub - Google Play Data Safety v1

Fecha de referencia: 2026-09-08. Completar el formulario de Play con la configuración final de producción y los SDK realmente incluidos en el release.

## Datos tratados

| Categoría | Uso | Asociado al usuario | Opcional |
| --- | --- | --- | --- |
| Nombre, usuario, email y país | Cuenta, perfil y acceso beta | Sí | El perfil puede completarse gradualmente |
| Fotos, videos, audio y publicaciones | Crear contenido fandom | Sí | Sí, solo cuando el usuario lo sube |
| Mensajes, comentarios, reacciones y follows | Funciones sociales | Sí | Sí, según la acción del usuario |
| Reportes y bloqueos | Seguridad y moderación | Sí | Sí |

## Ubicación y notificaciones

La primera versión no solicita GPS ni ubicación precisa. Ciudad, país y lugar se ingresan manualmente. Android no declara permisos de ubicación ni `POST_NOTIFICATIONS`; las notificaciones quedan para una implementación posterior y contextual.

## Compartición, seguridad y eliminación

Supabase procesa los datos como proveedor de infraestructura cuando la instancia real está configurada. La app usa TLS para conexiones remotas y RLS en tablas sociales. El usuario puede solicitar eliminación desde Ajustes o mediante `soporte@hallyuhub.net`; la migración SQL de solicitudes debe aplicarse en Supabase antes de declarar el flujo automatizado como operativo.

Este documento es una guía interna y no reemplaza la declaración final de Data Safety de Play Console.
