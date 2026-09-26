# GokuEnREPO

Repositorio APT público para **Sileo**, centrado en tweaks para **iOS 16**, **Dopamine** y **RootHide**.

Public APT repository for **Sileo**, focused on tweaks for **iOS 16**, **Dopamine** and **RootHide**.

## Páginas de los tweaks / Tweak pages

- **[BandLock — LTE/4G Band Lock](BANDLOCK.md)** — descripción completa en español e inglés, funciones, compatibilidad e instalación.
- **[BetterWiFi RH — Wi-Fi Tools](BETTERWIFI-RH.md)** — descripción completa en español e inglés, funciones, compatibilidad e instalación.

Estas páginas están pensadas también como enlaces directos para compartir cada tweak con la comunidad.
These pages are also intended as direct shareable links for each tweak.

## Fuente / Repository URL

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

---

# BandLock

## Español

**BandLock Global 0.6.1** es una aplicación de jailbreak para controlar manualmente las bandas LTE/4G del iPhone con **Dopamine + RootHide**. Desde 0.6.0 aparece como una app independiente en la pantalla de inicio, en lugar de vivir dentro de Ajustes. La 0.6.1 corrige los permisos CoreTelephony y los cierres detectados al preparar o editar bandas.

La app tiene dos pestañas:

- **Control**: estado del módem, red y banda servidora, Automático/Solo LTE, editor de bandas, aplicar/restaurar y Field Test.
- **Países**: buscador con 160 países y territorios y sus bandas LTE de referencia. Cada banda muestra FDD/TDD/SDL y si también está soportada por el módem del iPhone.

Elegir un país no cambia el módem automáticamente. **Preparar bandas compatibles** calcula la intersección entre las bandas del país y las bandas soportadas por el iPhone; el resultado queda pendiente hasta que el usuario lo revise y pulse **Aplicar selección**.

### Funciones principales

- App UIKit independiente con icono en SpringBoard.
- Selección manual de todas las bandas LTE reportadas como soportadas por el módem.
- Frecuencia y clasificación FDD/TDD/SDL para bandas conocidas.
- Catálogo offline de países y buscador.
- Modo **Automático** y **Solo LTE / 4G**.
- Restaurar selección anterior o todas las bandas soportadas.
- Verificación CoreTelephony y un reintento de CommCenter.
- Revalidación de bandas soportadas antes de cada escritura.
- Bloqueo de listas vacías y selecciones solo-SDL.
- Acceso a FTMInternal / Field Test Mode y logs.
- Sin daemon residente y sin escrituras automáticas al abrir o arrancar.

### Compatibilidad

- iOS 16.x
- Dopamine / RootHide
- iPhone arm64e
- Sileo
- Paquete: `iphoneos-arm64e`

[Changelog de BandLock](changelogs/BandLock.md)

## English

**BandLock Global 0.6.1** is a jailbreak application for manual LTE/4G band control on **Dopamine + RootHide**. Starting with 0.6.0 it is a standalone Home Screen app rather than a Settings PreferenceBundle. Version 0.6.1 fixes the standalone CoreTelephony permissions and the crashes found while preparing or editing bands.

The app has two tabs:

- **Control**: modem status, current network and serving band, Automatic/LTE-only mode, band editor, apply/restore actions and Field Test.
- **Countries**: searchable catalogue of 160 countries and territories with reference LTE bands. Each band shows FDD/TDD/SDL metadata and whether it is also supported by the current iPhone modem.

Choosing a country never changes the modem automatically. **Prepare compatible bands** computes the intersection between the country profile and the iPhone's modem-supported bands; the result remains pending until the user reviews it and explicitly taps **Apply selection**.

### Main features

- Standalone UIKit app with a SpringBoard icon.
- Manual selection of every LTE band reported as supported by the modem.
- Frequency and FDD/TDD/SDL metadata for known bands.
- Offline searchable country catalogue.
- **Automatic** and **LTE / 4G only** network modes.
- Restore previous selection or all supported LTE bands.
- CoreTelephony verification plus one CommCenter retry.
- Fresh supported-band validation before each write.
- Empty and SDL-only selections are rejected.
- FTMInternal / Field Test Mode access and diagnostic logs.
- No resident daemon and no automatic writes at app launch or boot.

### Compatibility

- iOS 16.x
- Dopamine / RootHide
- arm64e iPhones
- Sileo
- Package architecture: `iphoneos-arm64e`

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

- **BandLock Global 0.6.1** — `iphoneos-arm64e`
- **BetterWiFi RH 0.3.8** — `iphoneos-arm64e`

El índice `Packages` y `Packages.gz` se regenera automáticamente cuando cambia un paquete dentro de `debs/`.

The `Packages` and `Packages.gz` indexes are automatically regenerated when a package inside `debs/` changes.

---

## Keywords / Search terms

`jailbreak` · `ios jailbreak` · `jailbreak tweak` · `ios tweak` · `theos` · `roothide` · `dopamine` · `sileo` · `apt repo` · `iphone tweak` · `ios 16 jailbreak` · `lte band lock` · `lte band selection` · `4g only` · `coretelephony` · `field test mode` · `ftminternal` · `wifi tweak` · `wifi analyzer` · `wifi signal monitor` · `betterwifi` · `arm64e`

## GitHub Topics recomendados / Recommended GitHub Topics

`jailbreak`, `ios-jailbreak`, `jailbreak-tweak`, `ios-tweak`, `theos`, `roothide`, `dopamine`, `sileo`, `apt-repository`, `ios16`, `iphone`, `arm64e`, `coretelephony`, `lte`, `band-locking`, `field-test`, `wifi`, `wifi-tools`, `network-monitoring`, `betterwifi`

---

## GitHub Pages

El workflow de Pages está preparado. Si GitHub Pages está habilitado, `index.html` ofrece una portada bilingüe con metadatos SEO para ambos tweaks.
