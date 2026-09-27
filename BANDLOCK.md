# BandLock Global — LTE/4G + 5G NR Band Control App for iOS 16

**BandLock Global** is the public worldwide edition of BandLock for **iOS 16**. Starting with 1.0 it is published in three jailbreak variants: **RootHide**, **Dopamine rootless**, and **classic rootful**.

**BandLock Global** es la edición pública internacional de BandLock para **iOS 16**. Desde 1.0 se publica en tres variantes de jailbreak: **RootHide**, **Dopamine rootless** y **rootful clásico**.

> Current public version / Versión pública actual: **1.1** · RootHide: **iphoneos-arm64e** · Dopamine: **iphoneos-arm64** · Rootful: **iphoneos-arm**

> Development / Desarrollo: **1.2 beta 1** broadens the deployment target to iOS 15 and adds guarded runtime compatibility through iOS 18. It remains private until device validation is complete.

## Español

### Interfaz

BandLock se divide en tres pestañas. CoreTelephony/CommCenter se ejecuta dentro de un LaunchDaemon separado (`BandLockDaemon`) y la app se comunica con él por un socket Unix local. La interfaz no crea procesos mediante `posix_spawn`:

- **Control** — estado del módem, red actual, banda servidora, modos Automático/Solo LTE/5G Auto/5G On/5G Only, selección independiente LTE y 5G NR, aplicar/restaurar y Field Test. El selector de idioma aparece arriba a la derecha junto al idioma actual.
- **Países** — buscador con 160 países y territorios. Cada país muestra bandas LTE y 5G NR de referencia y su intersección con lo que reporta el módem del iPhone.
- **Info** — versión actual, créditos, comprobación de actualizaciones, notas de versión, GokuEnREPO, glosario técnico y **Buy Me a Coffee**.

### Cómo funcionan los perfiles de país

Los perfiles de país son una **referencia**, no una orden automática al módem. Al pulsar **Preparar bandas compatibles**, BandLock calcula:

`bandas LTE/NR del país ∩ bandas LTE/NR soportadas por el iPhone`

El resultado se copia a **Selección pendiente**. Después debes ir a Control, revisarlo y pulsar **Aplicar selección**. Elegir un país nunca cambia el módem automáticamente.

Que una banda figure para un país no garantiza que todos los operadores la utilicen, ni que esté desplegada en tu ubicación. Los despliegues pueden variar por operador, zona, roaming y fecha.

### Funciones

- App UIKit independiente con icono en SpringBoard.
- Módulo 1×1 para Control Center con selector rápido de **Auto / 3G / 4G / 5G**. El estado visual se actualiza al instante y los cambios Auto/3G/4G usan la ruta directa de CoreTelephony para no quedar bloqueados durante las transiciones por 3G.
- Selección de todas las bandas LTE que el módem reporta como soportadas.
- Selección independiente de bandas 5G NR que el módem reporte como configurables.
- Metadatos de frecuencia y clasificación **FDD / TDD / SDL**.
- Selector agrupado por FDD, TDD, SDL y otras bandas.
- Atajos: selección activa, todas las soportadas, solo FDD y solo TDD.
- Catálogo offline y buscador de países.
- Botón **Gestionar frecuencias de <país>** en Control tras preparar un país; solo modifica la selección pendiente.
- Intersección segura entre bandas del país y capacidades reales del iPhone.
- Modos **Automático**, **Solo LTE / 4G**, **5G Auto**, **5G On** y **5G Only (SA)**.
- Las selecciones pendientes LTE y NR se conservan al actualizar estado y entre reinicios de la app.
- La fila **Resultado** permanece vacía hasta pulsar explícitamente **Actualizar estado**.
- Restauración de la selección anterior o de todas las bandas soportadas.
- Verificación posterior mediante **CoreTelephony** y un reintento si CommCenter todavía devuelve el estado anterior.
- Relectura de `supportedBands` justo antes de escribir.
- Bloqueo de selecciones vacías y de selecciones compuestas únicamente por SDL.
- Lectura experimental de la banda LTE servidora.
- Acceso a **FTMInternal / Field Test Mode**.
- Logs de diagnóstico.
- Interfaz traducible desde la propia app a español, inglés, francés, alemán, chino tradicional, chino simplificado/mandarín y japonés.
- Créditos con avatar integrado para **Gokuencinar · GokuEn**.
- Sin cambios automáticos del módem al abrir la app o al arrancar.

### Datos de países

El snapshot incluido contiene **160 países y territorios**; **156** tienen bandas LTE de referencia y **99** tienen datos 5G NR explícitos en el snapshot del 27-09-2026. BandLock conserva el dataset dentro de la app para que la consulta funcione sin conexión.

El dataset no sustituye la información oficial de cada operador. El módem del propio iPhone sigue siendo la fuente de verdad para determinar qué bandas se pueden seleccionar en ese dispositivo.

### Compatibilidad y variantes

- **RootHide:** iOS 15.0–17.0. The package remains `iphoneos-arm64e` as required by RootHide, while its binaries contain both arm64 and arm64e slices for older iOS 15 hardware.
- **Dopamine rootless:** iOS 15.0–18.x where the installed Dopamine version supports the device/firmware combination.
- **Rootful:** iOS 15.x–16.x on supported classic/rootful jailbreaks.
- Sileo
- **RootHide**: `com.gokuencinar.bandlock` · `iphoneos-arm64e` · validado en iPhone XS con iOS 16.3.1.
- **Dopamine rootless**: `com.gokuencinar.bandlock.dopamine` · `iphoneos-arm64` · binarios arm64 + arm64e.
- **Rootful**: `com.gokuencinar.bandlock.rootful` · `iphoneos-arm` · binarios arm64, rutas clásicas `/Applications`, `/usr/libexec` y `/Library/LaunchDaemons`.
- Las variantes declaran `Conflicts:` entre sí para impedir una instalación cruzada accidental.
- App bundle: `com.gokuencinar.bandlock.app`
- Control de bandas: LTE/4G y rutas de selección 5G NR cuando el módem las reporta como configurables. Los cambios NR dependen del hardware, operador y comportamiento privado de CoreTelephony.
- La variante Dopamine ha pasado compilación, firma, validación de entitlements y estructura rootless en CI; la prueba física completa en un dispositivo con Dopamine normal queda pendiente.

## English

### Interface

BandLock uses three main tabs. CoreTelephony/CommCenter runs inside a separate LaunchDaemon (`BandLockDaemon`) and communicates with the app through a local Unix socket. The UI does not create child processes with `posix_spawn`:

- **Control** — modem status, current network, serving band, Automatic/LTE-only/5G Auto/5G On/5G Only modes, independent LTE and 5G NR selections, apply/restore actions and Field Test. The language selector is shown at the top right beside the current language.
- **Countries** — searchable list of 160 countries and territories with LTE and 5G NR reference bands and modem-supported intersections.
- **Info** — current version, credits, update checking, release notes, GokuEnREPO, technical glossary and **Buy Me a Coffee**.

### Country profiles

Country profiles are **reference data**, not automatic modem commands. Tapping **Prepare compatible bands** computes:

`country LTE/NR bands ∩ iPhone modem-supported LTE/NR bands`

The result becomes the **pending selection**. The user must then review it in Control and explicitly tap **Apply selection**. Selecting a country never writes to the modem automatically.

A band being listed for a country does not mean every carrier uses it or that it is deployed at the current location. Deployments vary by carrier, region, roaming and time.

### Features

- Standalone UIKit app with a Home Screen icon.
- 1×1 Control Center module with a quick **Auto / 3G / 4G / 5G** picker. Visual state updates immediately, and Auto/3G/4G use the direct CoreTelephony RAT path so 3G transitions do not block subsequent selections.
- Manual selection of every LTE band reported as supported by the modem.
- Independent 5G NR selection for bands reported as configurable by the modem.
- Frequency and **FDD / TDD / SDL** metadata.
- Dynamic FDD, TDD, SDL and other-LTE groups.
- Quick actions for current active, all supported, FDD-only and TDD-only selections.
- Offline searchable country catalogue.
- **Manage frequencies for <country>** in Control after preparing a country; it only changes the pending selection.
- Safe intersection of country bands with actual iPhone modem capabilities.
- **Automatic**, **LTE / 4G only**, **5G Auto**, **5G On** and **5G Only (SA)** network modes.
- Pending LTE/NR selections survive status refreshes and app restarts.
- The **Result** row stays empty until **Refresh status** is explicitly tapped.
- Restore previous selection or every modem-supported LTE band.
- **CoreTelephony** write verification plus one retry when CommCenter still reports the previous state.
- Fresh `supportedBands` check immediately before a write.
- Empty and SDL-only selections are rejected.
- Experimental serving-cell LTE band reading.
- Direct **FTMInternal / Field Test Mode** launcher.
- Diagnostic logs.
- In-app language selection for Spanish, English, French, German, Traditional Chinese, Simplified Chinese/Mandarin and Japanese.
- Bundled avatar and **Gokuencinar · GokuEn** credits.
- No automatic modem writes at launch or boot.

### Country data

The bundled offline snapshot contains **160 countries and territories**; **156** include LTE reference bands and **99** include explicit 5G NR data in the snapshot dated 2026-09-27.

The dataset does not replace carrier-specific official information. The iPhone modem remains the source of truth for which LTE bands can actually be selected on the device.

### Compatibility and variants

- **RootHide:** iOS 15.0–17.0. The package remains `iphoneos-arm64e` as required by RootHide, while its binaries contain both arm64 and arm64e slices for older iOS 15 hardware.
- **Dopamine rootless:** iOS 15.0–18.x where the installed Dopamine version supports the device/firmware combination.
- **Rootful:** iOS 15.x–16.x on supported classic/rootful jailbreaks.
- Sileo
- **RootHide**: `com.gokuencinar.bandlock` · `iphoneos-arm64e` · real-device validated on iPhone XS / iOS 16.3.1.
- **Dopamine rootless**: `com.gokuencinar.bandlock.dopamine` · `iphoneos-arm64` · arm64 + arm64e binaries.
- **Rootful**: `com.gokuencinar.bandlock.rootful` · `iphoneos-arm` · arm64 binaries with classic `/Applications`, `/usr/libexec`, and `/Library/LaunchDaemons` paths.
- The three variants declare mutual `Conflicts:` to prevent accidental cross-installation.
- App bundle: `com.gokuencinar.bandlock.app`
- LTE/4G plus 5G NR selection paths where the modem reports configurable NR bands. NR behavior depends on hardware, carrier and private CoreTelephony behavior.
- The Dopamine variant has passed CI compilation, signing, entitlement validation and rootless package-layout checks; complete physical validation on a normal Dopamine device is still pending.

## Install / Instalación

Add this repository to Sileo / Añade este repositorio a Sileo:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Then install **BandLock (RootHide)**, **BandLock (Dopamine)**, or **BandLock (Rootful)** according to your jailbreak. The app will appear on the Home Screen after installation.

Después instala **BandLock (RootHide)**, **BandLock (Dopamine)** o **BandLock (Rootful)** según tu jailbreak. La app aparecerá en la pantalla de inicio tras la instalación.

## Community testing / Pruebas comunitarias

Compatibility reports from different iPhone models, carriers and countries are useful, especially corrections to country reference data:

**[BandLock Global — community compatibility reports / pruebas de compatibilidad](https://github.com/Gokuencinar/GokuEnREPO/issues/1)**

Please never publish IMEI, IMSI, ICCID, phone numbers or other personal identifiers.

## Support / Apoyo

☕ [Buy Me a Coffee](https://buymeacoffee.com/gokuen)

## Changelog

See / Ver: [BandLock changelog](changelogs/BandLock.md)

## Search terms

iOS jailbreak app · iOS 16 jailbreak · RootHide app · Dopamine tweak · LTE band lock · global LTE band selector · LTE bands by country · LTE FDD · LTE TDD · supplemental downlink · 4G band lock · 4G only · iPhone LTE bands · CoreTelephony · CommCenter · Field Test Mode · FTMInternal · arm64e · Sileo · Theos
