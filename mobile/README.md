# HallyuHub Mobile

Primer proyecto Flutter para convertir HallyuHub en app Android, iOS y web desde una misma base de codigo.

## Estado

- Flutter SDK usado: `3.44.0`
- Dart SDK: `3.12.0`
- Carpeta de app: `mobile/`
- Prototipo HTML original: queda intacto en la raiz del repo.
- Datos actuales: demo local con assets copiados desde `assets/`.

## Ejecutar

```sh
/Users/leandronorbertopaletta/development/flutter/bin/flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5777
```

Luego abre:

```txt
http://127.0.0.1:5777
```

## Abrir en Xcode

Cuando Xcode completo este instalado:

```sh
open ios/Runner.xcworkspace
```

En Xcode:

1. Selecciona `Runner`.
2. Elige un simulador de iPhone en la barra superior.
3. En `Signing & Capabilities`, elige tu Apple Team.
4. Presiona Run.

Importante: abre siempre `Runner.xcworkspace`, no `Runner.xcodeproj`.

## Verificar

```sh
/Users/leandronorbertopaletta/development/flutter/bin/flutter analyze
/Users/leandronorbertopaletta/development/flutter/bin/flutter test
```

## Pendiente para builds reales

- Android: instalar Android Studio y Android SDK.
- iOS: instalar Xcode completo, ejecutar `xcode-select` hacia Xcode y agregar CocoaPods.
- Agregar `/Users/leandronorbertopaletta/development/flutter/bin` al `PATH` para poder usar `flutter` sin la ruta completa.
