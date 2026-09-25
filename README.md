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

**BandLock Global** es la edición pública de BandLock para controlar manualmente bandas LTE/4G desde Ajustes. La lista se genera en tiempo real a partir de las bandas que el propio módem del iPhone reporta como soportadas, sin asumir España, un país concreto ni un operador concreto.

Las bandas conocidas se muestran con su frecuencia nominal y clasificación **FDD, TDD o SDL**. BandLock mantiene también los modos **Automático** y **Solo LTE / 4G**, restauración de configuración, acceso a **FTMInternal / Field Test Mode**, verificación posterior de los cambios y logs de diagnóstico.

### Funciones principales

- Selección manual de todas las bandas LTE reportadas como soportadas por el módem.
- Clasificación **FDD / TDD / SDL** y frecuencia nominal para bandas conocidas.
- Grupos dinámicos y filtros rápidos FDD/TDD, sin perfiles de país u operador.
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

The public **Global** edition reads the LTE bands reported as supported by the iPhone modem at runtime and builds the selector from that device-specific set instead of assuming a country or carrier. Known bands are labelled with nominal frequency and **FDD, TDD or SDL** classification.

BandLock also provides **Automatic** and **LTE / 4G only** radio modes, restore actions, direct **FTMInternal / Field Test Mode** access, post-write verification and diagnostic logging.

### Main features

- Manual selection of every modem-reported supported LTE band.
- **FDD / TDD / SDL** classification and frequency labels for known bands.
- Dynamic grouping and generic FDD/TDD helpers instead of country/carrier presets.
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

- **BandLock Global 0.5.0** — `iphoneos-arm64e`
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
