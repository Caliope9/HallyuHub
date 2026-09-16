# HallyuHub Brand Assets

Los assets de marca viven en:

```text
mobile/assets/brand/
```

## Archivos principales

| Archivo | Uso recomendado |
| --- | --- |
| `hallyuhub_logo_full.png` | Logo completo de referencia: icono + wordmark sobre fondo dark/neon. |
| `hallyuhub_icon.png` | Icono principal cuadrado redondeado para UI, splash y materiales de marca. |
| `hallyuhub_icon_small.png` | Variante ligera para topbar, favicon y usos chicos. |
| `hallyuhub_wordmark.png` | Wordmark raster de referencia para piezas graficas futuras. |
| `hallyuhub_splash.png` | Composicion cuadrada para splash/loading y materiales promocionales. |
| `hallyuhub_topbar.png` | Composicion vertical recortada para headers o pruebas visuales. |
| `hallyuhub_app_icon.png` | Candidato futuro para app icon iOS/Android. |

## Uso actual en Flutter

- Login / crear cuenta: `HallyuBrandLockup`.
- Topbar: `HallyuBrandIcon` + `HallyuBrandWordmark`.
- Web favicon y PWA icons: derivados de `hallyuhub_icon.png`.

Los widgets reutilizables estan en:

```text
mobile/lib/src/widgets/brand_mark.dart
```

## App Store / Play Store

Para la fase de tiendas, usar `hallyuhub_app_icon.png` como base. Antes de subir:

- generar tamaños finales nativos para iOS y Android;
- verificar legibilidad en tamaños chicos;
- evitar texto dentro del app icon;
- mantener el icono centrado, sin bordes cortados;
- revisar que no haya transparencia problematica;
- conservar una copia fuente editable si se crea una version final vectorial o de mayor resolucion.

## Nota legal

Estos assets son propios de HallyuHub y no usan imagenes de terceros. No reemplazar por imagenes de idols, agencias, fansites o marcas externas sin licencia clara.
