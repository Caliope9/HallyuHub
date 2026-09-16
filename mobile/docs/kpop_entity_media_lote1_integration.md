# Imágenes legales de entidades K-pop — lote 1

Este lote contiene metadatos legales para diez portadas de entidades K-pop.
El archivo `kpop_entity_media_lote1_manifest.csv` es el registro de origen,
licencia, atribución y ruta prevista; no contiene los binarios de imagen.

## Estado

- Preparación local solamente: no se ejecutó SQL.
- No se modificó Supabase ni ningún registro de `kpop_entities`.
- No se subieron archivos a Storage.
- No se reemplazaron imágenes existentes.
- No se usa Wikimedia como URL final de producción: `direct_url` es solo el
  origen de descarga/licencia indicado por el material entregado.

## Bucket y rutas

El SQL de revisión propone el bucket dedicado `kpop_entity_media`.
Las rutas son `kpop-entities/<normalized_name>/cover.<ext>` y no se deben
reutilizar para posts, stories, mensajes, drops, fancams ni avatares.

Las cargas no deben salir de Flutter/web: deben ejecutarse mediante un proceso
backend autorizado. La política preparada permite lectura, pero no otorga
escritura a `anon` ni `authenticated`.

## Próximo paso bloqueado

El ZIP entregado solo contiene CSV, README y prompt; faltan los diez binarios.
Antes de cargar o actualizar `kpop_entities` hay que obtener/revisar esos
archivos, confirmar sus hashes y mostrar las URLs finales de Storage. Luego se
puede preparar un cambio separado que escriba `image_url`, `image_source`,
`image_license` y `attribution` únicamente cuando la imagen actual esté vacía,
sin sobrescribir una portada existente.
