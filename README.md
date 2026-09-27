# GokuEnREPO

Repositorio APT público para **Sileo**, centrado en tweaks para **iOS 16**, **Dopamine** y **RootHide**.

Public APT repository for **Sileo**, focused on tweaks for **iOS 16**, **Dopamine** and **RootHide**.

## Páginas de los tweaks / Tweak pages

- **[BandLock — LTE/4G Band Lock](BANDLOCK.md)** — descripción completa en español e inglés, funciones, compatibilidad e instalación.
- **[BetterWiFi RH — Wi-Fi Tools](BETTERWIFI-RH.md)** — descripción completa en español e inglés, funciones, compatibilidad e instalación.
- **[Nuke Wireless — Wi-Fi Tools](NUKE-WIRELESS.md)** — dispositivos de la red Wi-Fi, alias y controles de bloqueo ARP para RootHide.

Estas páginas están pensadas también como enlaces directos para compartir cada tweak con la comunidad.
These pages are also intended as direct shareable links for each tweak.

## Fuente / Repository URL

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

---

# BandLock

## Español

**BandLock Global 0.6.34** es una aplicación de jailbreak para controlar manualmente las bandas LTE/4G del iPhone. Se publica en dos variantes separadas: **BandLock (RootHide)** y **BandLock (Dopamine)**. Ambas comparten la misma interfaz y funciones; únicamente cambia la capa de integración con el jailbreak y el empaquetado.

La app tiene tres pestañas:

- **Control**: estado del módem, red y banda servidora, Automático/Solo LTE, editor de bandas, aplicar/restaurar y Field Test.
- **Países**: buscador con 160 países y territorios y sus bandas LTE de referencia. Cada banda muestra FDD/TDD/SDL y si también está soportada por el módem del iPhone.
- **Info**: créditos, versión instalada, búsqueda de actualizaciones, notas de versión, acceso a GokuEnREPO, glosario de frecuencias y selector de idioma.

Elegir un país no cambia el módem automáticamente. **Preparar bandas compatibles** calcula la intersección entre las bandas del país y las bandas soportadas por el iPhone; el resultado queda pendiente hasta que el usuario lo revise y pulse **Aplicar selección**.

### Funciones principales

- App UIKit independiente con icono en SpringBoard.
- Selección manual de todas las bandas LTE reportadas como soportadas por el módem.
- Frecuencia y clasificación FDD/TDD/SDL para bandas conocidas.
- Catálogo offline de países y buscador.
- Gestión de frecuencias del país seleccionado desde Control, limitada a `bandas del país ∩ bandas soportadas por el iPhone` y sin autoaplicar cambios.
- Modo **Automático** y **Solo LTE / 4G**.
- Restaurar selección anterior o todas las bandas soportadas.
- Verificación CoreTelephony y un reintento de CommCenter.
- Revalidación de bandas soportadas antes de cada escritura.
- Bloqueo de listas vacías y selecciones solo-SDL.
- Acceso a FTMInternal / Field Test Mode y logs.
- Selector interno de idioma: español, inglés, francés, alemán, chino tradicional, chino simplificado/mandarín y japonés.
- Pestaña Info con créditos **Gokuencinar · GokuEn** y avatar integrado.
- Sin escrituras automáticas al módem al abrir o arrancar la app.

### Compatibilidad

- iOS 16.x
- **RootHide:** paquete `com.gokuencinar.bandlock`, arquitectura `iphoneos-arm64e`.
- **Dopamine rootless:** paquete `com.gokuencinar.bandlock.dopamine`, arquitectura `iphoneos-arm64` con binarios arm64 + arm64e.
- Los dos paquetes se marcan como incompatibles entre sí para evitar mezclar entornos.
- Sileo

[Changelog de BandLock](changelogs/BandLock.md)

## English

**BandLock Global 0.6.34** is a jailbreak application for manual LTE/4G band control. It is distributed as two separate variants: **BandLock (RootHide)** and **BandLock (Dopamine)**. Both share the same UI and feature set; only the jailbreak integration and packaging layer differ.

The app has three tabs:

- **Control**: modem status, current network and serving band, Automatic/LTE-only mode, band editor, apply/restore actions and Field Test.
- **Countries**: searchable catalogue of 160 countries and territories with reference LTE bands. Each band shows FDD/TDD/SDL metadata and whether it is also supported by the current iPhone modem.
- **Info**: credits, installed version, update checking, release notes, GokuEnREPO link, frequency glossary and language selector.

Choosing a country never changes the modem automatically. **Prepare compatible bands** computes the intersection between the country profile and the iPhone's modem-supported bands; the result remains pending until the user reviews it and explicitly taps **Apply selection**.

### Main features

- Standalone UIKit app with a SpringBoard icon.
- Manual selection of every LTE band reported as supported by the modem.
- Frequency and FDD/TDD/SDL metadata for known bands.
- Offline searchable country catalogue.
- Country-frequency management from Control, restricted to `country bands ∩ iPhone-supported bands`, without automatic modem writes.
- **Automatic** and **LTE / 4G only** network modes.
- Restore previous selection or all supported LTE bands.
- CoreTelephony verification plus one CommCenter retry.
- Fresh supported-band validation before each write.
- Empty and SDL-only selections are rejected.
- FTMInternal / Field Test Mode access and diagnostic logs.
- In-app language selector: Spanish, English, French, German, Traditional Chinese, Simplified Chinese/Mandarin and Japanese.
- Info tab with **Gokuencinar · GokuEn** credits and bundled avatar.
- No automatic modem writes at app launch or boot.

### Compatibility

- iOS 16.x
- **RootHide:** package `com.gokuencinar.bandlock`, `iphoneos-arm64e`.
- **Dopamine rootless:** package `com.gokuencinar.bandlock.dopamine`, `iphoneos-arm64`, containing arm64 + arm64e binaries.
- The two packages conflict with each other to prevent mixing jailbreak environments.
- Sileo

[BandLock changelog](changelogs/BandLock.md)

---

# BetterWiFi RH

## Español

**BetterWiFi RH** es una adaptación para **RootHide** de un tweak orientado a ampliar la información y las herramientas Wi-Fi disponibles en iOS.

Añade más detalles de la red Wi-Fi conectada, monitorización de señal, herramientas de diagnóstico, análisis de canales y filtros adicionales en la interfaz Wi-Fi de Ajustes. Está diseñado para ejecutarse únicamente cuando se utilizan sus pantallas de configuración, evitando procesos residentes innecesarios.

### Funciones principales

- Información ampliada de la red Wi-Fi conectada.
- Monitor de señal en tiempo real.
- Historial/gráfica de señal mientras la pantalla está abierta.
- Analizador de canales Wi-Fi.
- Información para redes de 2,4 GHz y 5 GHz.
- Filtros clásicos para la lista de redes.
- Herramientas de diagnóstico.
- Integración con Shuffle.
- Compatibilidad con RootHide.
- PreferenceBundle para Ajustes.
- Sin daemon residente dedicado.

### Compatibilidad

- iOS 16.x
- Dopamine / RootHide
- iPhone arm64e
- PreferenceLoader
- Paquete: `iphoneos-arm64e`

[Changelog de BetterWiFi RH](changelogs/BetterWiFi-RH.md)

## English

**BetterWiFi RH** is a **RootHide-compatible** Wi-Fi enhancement tweak that expands the network information and tools available in iOS.

It adds richer information about the currently connected Wi-Fi network, live signal monitoring, diagnostic tools, channel analysis and additional filtering options inside the Wi-Fi section of Settings. It is designed to do its work while its relevant Settings pages are open instead of relying on a dedicated resident daemon.

### Main features

- Extended information for the connected Wi-Fi network.
- Live Wi-Fi signal monitor.
- Signal history/graph while the relevant page is open.
- Wi-Fi channel analyzer.
- 2.4 GHz and 5 GHz network information.
- Classic network filtering options.
- Diagnostic tools.
- Shuffle integration.
- RootHide compatibility.
- Settings PreferenceBundle.
- No dedicated resident daemon.

### Compatibility

- iOS 16.x
- Dopamine / RootHide
- arm64e iPhones
- PreferenceLoader
- Package architecture: `iphoneos-arm64e`

[BetterWiFi RH changelog](changelogs/BetterWiFi-RH.md)

---

## Paquetes actuales / Current packages

- **BandLock (RootHide) 0.6.34** — `iphoneos-arm64e`
- **BandLock (Dopamine) 0.6.34** — `iphoneos-arm64`
- **BetterWiFi RH 0.3.8** — `iphoneos-arm64e`
- **Nuke Wireless 1.0.26** — `iphoneos-arm64e`

El índice `Packages` y `Packages.gz` se regenera automáticamente cuando cambia un paquete dentro de `debs/`.

The `Packages` and `Packages.gz` indexes are automatically regenerated when a package inside `debs/` changes.

---

## Keywords / Search terms

`jailbreak` · `ios jailbreak` · `jailbreak tweak` · `ios tweak` · `theos` · `roothide` · `dopamine` · `sileo` · `apt repo` · `iphone tweak` · `ios 16 jailbreak` · `lte band lock` · `lte band selection` · `4g only` · `coretelephony` · `field test mode` · `ftminternal` · `wifi tweak` · `wifi analyzer` · `wifi signal monitor` · `betterwifi` · `arm64e`

## GitHub Topics recomendados / Recommended GitHub Topics

`jailbreak`, `ios-jailbreak`, `jailbreak-tweak`, `ios-tweak`, `theos`, `roothide`, `dopamine`, `sileo`, `apt-repository`, `ios16`, `iphone`, `arm64e`, `coretelephony`, `lte`, `band-locking`, `field-test`, `wifi`, `wifi-tools`, `network-monitoring`, `betterwifi`, `nuke-wireless`, `arp-blocking`

---

## GitHub Pages

El workflow de Pages está preparado. Si GitHub Pages está habilitado, `index.html` ofrece una portada bilingüe con metadatos SEO para todos los tweaks.
