# HallyuHub - Google Play Readiness v1

## Decisiones cerradas

- Dominio público: `https://www.hallyuhub.net`
- Distribución: Internal testing, luego closed testing, y producción después de validar Android real.
- `minSdk`: 24
- `compileSdk`: 36
- `targetSdk`: 36
- Etiqueta de aplicación: HallyuHub
- Sin GPS/ubicación precisa en esta versión.

## Permisos declarados

Se mantienen únicamente cámara, micrófono y acceso a fotos/videos para acciones iniciadas por el usuario. Se agregó `INTERNET`. Se quitaron ubicación y notificaciones del manifest; la galería mantiene compatibilidad legacy hasta Android 12.

## Pendientes antes de producción

1. Aplicar `docs/supabase_account_deletion_v1.sql` en Supabase y conectar el estado de solicitud.
2. Completar Data Safety con SDK y proveedores definitivos.
3. Crear una clave de firma de release fuera del repositorio y guardar valores solo en `android/key.properties` local.
4. Instalar/verificar Android SDK Platform 36 y Build Tools compatibles.
5. Ejecutar `flutter analyze`, tests y `flutter build appbundle --release` con firma configurada.
6. Validar media, cámara, RLS, reportes, bloqueo y borrado en Android real.
