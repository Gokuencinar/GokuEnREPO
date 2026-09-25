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

**BandLock** es un tweak para jailbreak orientado al control manual de la conectividad celular LTE/4G desde Ajustes.

Permite consultar las bandas LTE soportadas y permitidas por el módem, seleccionar manualmente las bandas que quieres utilizar, aplicar perfiles de bandas, restaurar la configuración automática del módem y controlar el modo de red entre **Automático** y **Solo LTE / 4G**.

La interfaz está optimizada para España y muestra las principales bandas LTE utilizadas por operadores españoles, incluyendo **B1, B3, B7, B8, B20, B28 y B38**, con sus frecuencias. También incluye acceso directo a **FTMInternal / Field Test Mode**, verificación posterior de los cambios y logs de diagnóstico.

### Funciones principales

- Selección manual de bandas LTE.
- Bandas LTE utilizadas en España.
- Frecuencia mostrada junto a cada banda.
- Perfiles rápidos para Orange España y combinaciones habituales.
- Modo **Automático** y **Solo LTE / 4G**.
- Restaurar selección anterior.
- Restaurar todas las bandas LTE soportadas por el módem.
- Verificación de escritura mediante CoreTelephony.
- Reintento automático si CommCenter tarda en consolidar un cambio.
- Intento de lectura de la banda LTE de la celda servidora.
- Acceso directo a **FTMInternal-4 / Field Test Mode**.
- Logs de diagnóstico por SSH.
- Sin daemon residente.
- Sin inyección en SpringBoard.
- Sin cambios automáticos del módem al arrancar.

### Compatibilidad

- iOS 16.x
- Dopamine / RootHide
- iPhone arm64e
- PreferenceLoader
- Paquete: `iphoneos-arm64e`

[Changelog de BandLock](changelogs/BandLock.md)

## English

**BandLock** is a jailbreak tweak designed for manual LTE/4G cellular band control directly from the iOS Settings app.

It can read the LTE bands supported and currently allowed by the modem, let the user manually choose which LTE bands may be used, apply band presets, restore the modem's automatic configuration, and switch the radio access mode between **Automatic** and **LTE / 4G only**.

The interface is optimized for Spain and focuses on the main LTE bands used by Spanish mobile operators, including **B1, B3, B7, B8, B20, B28 and B38**, with their frequencies displayed. BandLock also includes direct access to **FTMInternal / Field Test Mode**, post-write verification and diagnostic logging.

### Main features

- Manual LTE band selection.
- Spain-focused LTE band list.
- Frequency labels for every displayed band.
- Quick presets for Orange Spain and common band combinations.
- **Automatic** and **LTE / 4G only** network modes.
- Restore previous LTE selection.
- Restore all LTE bands supported by the modem.
- CoreTelephony write verification.
- Automatic retry when CommCenter has not yet committed a change.
- Experimental serving-cell LTE band reading.
- Direct **FTMInternal-4 / Field Test Mode** launcher.
- SSH diagnostic logs.
- No resident daemon.
- No SpringBoard injection.
- No automatic modem changes at startup.

### Compatibility

- iOS 16.x
- Dopamine / RootHide
- arm64e iPhones
- PreferenceLoader
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

- **BandLock 0.4.4** — `iphoneos-arm64e`
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
