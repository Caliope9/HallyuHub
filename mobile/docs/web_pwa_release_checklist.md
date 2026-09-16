# HallyuHub Web/PWA — checklist de release

HallyuHub Web es la misma aplicación Flutter que Android, publicada en
`https://www.hallyuhub.net/`. No se mantiene una implementación web paralela.

Antes de cada release importante hay que verificar, en este orden:

1. Flutter Android: `flutter analyze`, `flutter test` y build firmado de Play.
2. Flutter Web: `flutter analyze`, `flutter test` y un `flutter build web --release`
   nuevo con `HALLYUHUB_SUPABASE_URL` y `HALLYUHUB_SUPABASE_ANON_KEY` de Production.
3. Supabase: Auth Hook, RPC/RLS y migraciones autorizadas según la revisión de
   seguridad vigente. No incluir `service_role` en Flutter ni en el bundle web.
4. Web pública: comprobar `https://www.hallyuhub.net/`, login/registro,
   navegación, conexión al Supabase real y la instalación desde Safari en
   iPhone/iPad mediante “Agregar a pantalla de inicio”.

La PWA prioriza instalación y experiencia app-like (`standalone`, manifest,
íconos maskable y metadatos Apple). No se agrega una estrategia offline propia:
los datos sociales deben seguir siendo actuales y venir del backend real.

Cada release debe confirmar que Android, Web, Supabase y el dominio público
corresponden a la misma versión funcional; la Web no debe quedar atrás de
Android.
