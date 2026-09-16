# HallyuHub Beta Real v1 - auditoria inicial

## Estado general

La app Flutter ya esta bien separada en pantallas, modelos y servicios locales. Eso permite migrar de forma gradual a Supabase sin borrar los datos demo ni romper la experiencia actual.

## Demo-only por ahora

| Modulo | Estado actual | Riesgo |
| --- | --- | --- |
| Home feed demo | Mezcla datos de `demo_data.dart` con posts locales publicados desde el editor. | Bajo si se mantiene fallback demo mientras Supabase se llena. |
| Buscar/Discover | Catalogo local en `discover_data.dart`: grupos, idols, noticias, comunidades, eventos, shop y K-pop 101. | Medio si se intenta mover todo de golpe; conviene migrar lectura por etapas. |
| Sugerencias de personas | Usa perfiles demo y estado local de seguir. | Medio: necesita tabla `follows` y perfiles reales para coherencia global. |
| Likes/estrellas en varias pantallas | La mayoria vive en sets de estado de pantalla o SharedPreferences. | Medio: hay que centralizar acciones sociales para que reflejen en toda la app. |
| Solicitudes de mensajes demo | La lista de solicitudes iniciales esta hardcodeada en `MessagesInboxScreen`. | Bajo: ya hay UI; necesita `message_requests`/`conversations` real. |
| Comunidades creadas en Buscar | Estado local de pantalla. | Medio: necesita tabla real y miembros. |
| Shop, eventos y K-pop 101 | Curadoria demo/local. | Bajo para beta visual; medio si usuarios reales crean contenido. |

## Listo para conectar

| Modulo | Base existente | Siguiente paso |
| --- | --- | --- |
| Auth/perfil | `AuthService` ya abstrae login, registro, guardar usuario y cerrar sesion. | `SupabaseAuthService` queda activo cuando hay credenciales. |
| Posts | `LocalPostService` ya persiste `HubPost`, carrusel, video, tags, ubicacion y autor. | Crear `SupabasePostService` con Storage y tablas `posts/post_media`. |
| Stories | `LocalStoryService` ya guarda historias, archivo, vistas y estrellas locales. | Crear `SupabaseStoryService` con `stories/story_media/story_views/story_likes`. |
| DMs | `LocalChatService` ya modela conversaciones, mensajes y respuestas a historias. | Crear servicio real con `conversations/messages/message_requests` y realtime. |
| Drops/Fancams | Servicios locales separados y metadata de video. | Subir videos a Storage y metadata a `drops`/`fancams`. |
| Perfil | `AuthUser` ya concentra datos editables y privacidad basica. | Sincronizar foto/nombre/bio con `profiles` y Storage `avatars`. |
| Legal/seguridad | Ajustes ya tiene privacidad, terminos, reportes, bloqueos y eliminar cuenta como estructura UI. | Conectar `content_reports`, `user_blocks` y proceso real de borrado. |

## Necesita modelo nuevo o ampliado

| Necesidad beta | Modelo/tabla |
| --- | --- |
| Persistencia global de follows | `follows` con follower/following y contadores calculados. |
| Acciones sociales coherentes | `post_likes`, `post_saves`, `story_likes`, tablas equivalentes para drops/fancams. |
| Comentarios con respuestas | `comments` con `content_type`, `content_id` y `parent_id`. |
| Solicitudes de mensajes | `conversations.request_status` y `message_requests` o campo equivalente. |
| Storage multimedia | Buckets `avatars`, `post_media`, `story_media`, `drop_media`, `fancam_media`, `collection_media`. |
| Comunidades reales | `communities`, `community_members`, `community_messages`. |
| Moderacion | `content_reports`, `user_blocks`, `content_status`. |
| Contenido coleccion/trade/venta | `collection_items` con estado, precio, privacidad y owner. |

## Fallback demo temporal

- Mantener `demo_data.dart`, `discover_data.dart` y servicios locales como fallback cuando no haya `HALLYUHUB_SUPABASE_URL` y `HALLYUHUB_SUPABASE_ANON_KEY`.
- No mezclar datos reales y demo en escritura. La regla debe ser: si Supabase esta configurado, escribir real; si no, escribir local.
- El catalogo K-pop puede seguir local al principio, pero los perfiles reales, posts, historias y mensajes deben pasar primero a Supabase.

## Riesgo de romper

- Alto: migrar todas las pantallas a la vez.
- Medio: permitir avatares remotos sin actualizar widgets de imagen.
- Medio: usar Supabase sin RLS completo.
- Medio: subir videos sin validacion de duracion/compresion y sin reglas de Storage.
- Bajo: activar Auth/perfil real detras de `dart-define`, porque si no hay credenciales el flujo local sigue igual.

## Primer corte implementado

- Se agrego configuracion de backend por `--dart-define`.
- Se agrego inicializacion opcional de Supabase.
- Se agrego `SupabaseAuthService` para login, registro, restaurar sesion y guardar perfil real.
- Se mantuvo `LocalAuthService` como fallback automatico si no hay credenciales.
- `HubAvatar` ahora soporta assets locales, base64 y URLs remotas de Storage.

## Como compilar con Supabase

```bash
flutter run \
  --dart-define=HALLYUHUB_SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=HALLYUHUB_SUPABASE_ANON_KEY=TU_ANON_KEY
```

Para web/Vercel, esas variables deben estar en el build command o en variables de entorno que el pipeline transforme en `--dart-define`.
