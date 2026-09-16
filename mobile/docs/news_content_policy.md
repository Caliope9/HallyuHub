# HallyuHub News Content Policy

Noticias en HallyuHub deben funcionar como una capa editorial y de
descubrimiento, no como copia de medios externos.

Reglas para beta, App Store y Play Store:

- No copiar articulos completos ni parrafos largos de medios.
- Mostrar solo resumen breve en espanol, redactado con palabras propias.
- Mantener siempre `originalUrl`, `source`, `publishedAt` y boton para abrir la
  fuente original.
- Usar imagenes solo si hay permiso claro, press kit autorizado, Creative
  Commons con atribucion correcta, dominio publico o contenido subido por
  usuarios con derechos suficientes.
- Si no hay imagen legal, usar placeholders premium HallyuHub.
- Guardar metadatos de imagen: `imageSource`, `imageLicense`, `attribution`,
  `author` y `licenseUrl`.

Arquitectura futura recomendada:

1. Ingesta cada 1 a 3 horas desde RSS/API autorizadas o una Vercel Function
   equivalente a `api/news.js`.
2. Normalizacion backend a `news_items` con `originalTitle`, `originalUrl`,
   `source`, `publishedAt`, `language`, `relatedGroups` y `relatedArtists`.
3. Generacion de `generatedSummary` breve en espanol, sin copiar texto literal.
4. Revision de confianza/estado: `pending`, `approved`, `rejected`,
   `detectedEntity` o `needsReview`.
5. Sincronizacion a Supabase para lectura rapida desde Flutter.

Tablas futuras sugeridas:

- `news_items`
- `news_sources`
- `news_entity_mentions`
- `groups`
- `artists`
- `artist_aliases`
- `community_suggestions`
