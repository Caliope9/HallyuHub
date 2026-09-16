# HallyuHub Beta Real v1 - Auth + Perfil en Supabase

Este documento conecta solo Auth + Perfil. No migra posts, stories, mensajes, follows, drops ni fancams.

## 1. Crear proyecto Supabase

1. Entrar a https://supabase.com/dashboard.
2. Crear una organizacion si todavia no existe.
3. Crear un proyecto nuevo, por ejemplo `HallyuHub Beta`.
4. Elegir region cercana a los usuarios de prueba. Para Latam suele convenir revisar Brasil/US East segun disponibilidad y latencia.
5. Guardar la password de base de datos en un lugar seguro.
6. Esperar a que el proyecto quede activo.

## 2. Ejecutar schema SQL

1. Abrir el proyecto en Supabase.
2. Ir a SQL Editor.
3. Abrir en este repo:

```text
mobile/docs/supabase_beta_real_v1_schema.sql
```

4. Copiar el contenido completo.
5. Ejecutarlo una vez.
6. Verificar que existan:
   - `profiles`
   - `follows`
   - `posts`
   - `post_media`
   - `stories`
   - `story_media`
   - `story_views`
   - `story_likes`
   - `conversations`
   - `messages`
   - `communities`
   - `drops`
   - `fancams`
   - `collection_items`
   - buckets de Storage como `avatars`, `post_media`, `story_media`, etc.

Para esta tanda solo se usan `profiles` y `avatars`.

Si el usuario aparece en `Authentication > Users` pero no aparece en
`Table Editor > profiles`, ejecutar esta migracion corta en SQL Editor:

```text
mobile/docs/supabase_auth_profile_trigger.sql
```

Ese trigger crea la fila inicial en `public.profiles` apenas Supabase crea el
usuario en `auth.users`, incluso cuando la confirmacion por email esta activa y
Flutter todavia no tiene una sesion autenticada. La misma migracion tambien
crea perfiles faltantes para usuarios que ya existian en `Authentication`.

## 3. Revisar Auth

En Supabase:

1. Ir a Authentication > Providers.
2. Confirmar que Email este habilitado.
3. Para pruebas rapidas, se puede desactivar temporalmente email confirmation.
4. Para beta real con usuarios externos, conviene activar confirmacion por email y luego configurar redirects.

## 4. Conseguir URL y key

En Supabase:

1. Ir a Project Settings.
2. Ir a API Keys o usar el dialogo Connect.
3. Copiar:
   - Project URL, con formato `https://xxxx.supabase.co`
   - Publishable key `sb_publishable_...`

Tambien puede funcionar la legacy anon key, pero Supabase recomienda publishable key para clientes nuevos.

No usar nunca `service_role` ni `sb_secret_...` en Flutter, Web, Vercel publico ni chats.

## 5. Correr en Chrome/Web

Desde `mobile/`:

```bash
/Users/leandronorbertopaletta/development/flutter/bin/flutter run -d chrome \
  --dart-define=HALLYUHUB_SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=HALLYUHUB_SUPABASE_ANON_KEY=TU_PUBLISHABLE_KEY
```

## 6. Correr en iPhone Simulator

Desde `mobile/`:

```bash
/Users/leandronorbertopaletta/development/flutter/bin/flutter devices
```

Copiar el id o nombre del simulador y correr:

```bash
/Users/leandronorbertopaletta/development/flutter/bin/flutter run -d "iPhone 15 Pro Max" \
  --dart-define=HALLYUHUB_SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=HALLYUHUB_SUPABASE_ANON_KEY=TU_PUBLISHABLE_KEY
```

## 7. Build web con Supabase

```bash
/Users/leandronorbertopaletta/development/flutter/bin/flutter build web --release \
  --dart-define=HALLYUHUB_SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=HALLYUHUB_SUPABASE_ANON_KEY=TU_PUBLISHABLE_KEY
```

Para Vercel, el build command debe incluir esos mismos `--dart-define`.

## 8. Pruebas manuales Auth + Perfil

1. Abrir app con credenciales Supabase.
2. Crear cuenta nueva desde `Crear cuenta`.
3. Si la confirmacion por email esta activa, la app queda en login y muestra que
   hay que confirmar el email antes de entrar.
4. Revisar Supabase > Authentication > Users: debe aparecer el usuario.
5. Revisar Table Editor > `profiles`: debe existir una fila con:
   - `id`
   - `email`
   - `name`
   - `username`
   - `fandom`
6. Confirmar el email si corresponde.
7. Iniciar sesion con el email y password reales.
8. Cerrar y volver a abrir la app: la sesion debe mantenerse.
9. Ir a Perfil > Editar perfil / Ajustes.
10. Cambiar:
   - nombre
   - username
   - bio
   - pais
   - fandom
11. Guardar.
12. Revisar `profiles` en Supabase: los campos deben actualizarse.
13. Cambiar foto de perfil.
14. Revisar Storage > `avatars`: debe aparecer archivo en carpeta del user id.
15. Revisar `profiles.avatar_url`: debe quedar una URL publica.

## 9. Fallback demo

Si no se pasan estos valores:

```text
HALLYUHUB_SUPABASE_URL
HALLYUHUB_SUPABASE_ANON_KEY
```

la app usa automaticamente `LocalAuthService`, con el modo demo/local actual.

## 10. Alcance de esta tanda

Real:

- registro/login con Supabase Auth
- restaurar sesion
- cerrar sesion
- guardar perfil en `profiles`
- subir foto de perfil a bucket `avatars`
- leer avatar remoto por URL

Todavia demo/local:

- posts
- stories
- follows
- mensajes
- comunidades
- drops
- fancams
- likes/comentarios/guardados globales
