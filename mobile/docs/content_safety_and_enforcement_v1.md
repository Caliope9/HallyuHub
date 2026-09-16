# Content safety y enforcement

La app no inventa una clasificación automática. `ContentSafetyService` devuelve
`unavailable` cuando no existe un proveedor configurado o cuando el proveedor
falla; ese resultado no habilita publicar. Un proveedor real debe clasificar
como `safe`, `unsafe` o `needs_review` y distinguir contenido sexual explícito,
explotación sexual, gore extremo y violencia gráfica extrema.

Todo caso dudoso se deriva a revisión humana mediante `content_reports`. El
equipo autorizado puede emitir `warning`, `restriction`, `suspension` o `ban`,
con motivo y, cuando corresponda, fecha de finalización. La UI nunca recibe ni
almacena `service_role`.

El archivo `supabase_safety_age_deletion_v1.sql` solo prepara el contrato de
backend. Debe revisarse y ejecutarse por el equipo de Supabase; no se ejecutó
durante esta fase.
