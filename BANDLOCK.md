# BandLock Global — LTE/4G Band Control App for iOS 16

**BandLock Global** is the public worldwide edition of BandLock for **iOS 16**. Starting with 0.6.34 it is published as two separate packages: one for **RootHide** and one for **normal Dopamine rootless**.

**BandLock Global** es la edición pública internacional de BandLock para **iOS 16**. Desde 0.6.34 se publica como dos paquetes independientes: uno para **RootHide** y otro para **Dopamine rootless normal**.

> Current public version / Versión pública actual: **0.6.34** · RootHide: **iphoneos-arm64e** · Dopamine: **iphoneos-arm64**

## Español

### Interfaz

BandLock se divide en tres pestañas. CoreTelephony/CommCenter se ejecuta dentro de un LaunchDaemon separado (`BandLockDaemon`) y la app se comunica con él por un socket Unix local. La interfaz no crea procesos mediante `posix_spawn`:

- **Control** — estado del módem, red actual, banda servidora, modo Automático/Solo LTE, selección manual de bandas, aplicar, restaurar y Field Test.
- **Países** — buscador con 160 países y territorios. Cada país muestra sus bandas LTE de referencia, frecuencia, FDD/TDD/SDL y cuáles de ellas son compatibles con el módem del iPhone.
- **Info** — créditos, comprobación de actualizaciones, notas de versión, GokuEnREPO, glosario técnico y selector de idioma.

### Cómo funcionan los perfiles de país

Los perfiles de país son una **referencia**, no una orden automática al módem. Al pulsar **Preparar bandas compatibles**, BandLock calcula:

`bandas LTE del país ∩ bandas LTE soportadas por el iPhone`

El resultado se copia a **Selección pendiente**. Después debes ir a Control, revisarlo y pulsar **Aplicar selección**. Elegir un país nunca cambia el módem automáticamente.

Que una banda figure para un país no garantiza que todos los operadores la utilicen, ni que esté desplegada en tu ubicación. Los despliegues pueden variar por operador, zona, roaming y fecha.

### Funciones

- App UIKit independiente con icono en SpringBoard.
- Selección de todas las bandas LTE que el módem reporta como soportadas.
- Metadatos de frecuencia y clasificación **FDD / TDD / SDL**.
- Selector agrupado por FDD, TDD, SDL y otras bandas.
- Atajos: selección activa, todas las soportadas, solo FDD y solo TDD.
- Catálogo offline y buscador de países.
- Botón **Gestionar frecuencias de <país>** en Control tras preparar un país; solo modifica la selección pendiente.
- Intersección segura entre bandas del país y capacidades reales del iPhone.
- Modo **Automático** y **Solo LTE / 4G**.
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

El snapshot incluido en 0.6.0 contiene **160 países y territorios**, de los cuales **156 tienen bandas LTE de referencia** en la fuente utilizada el 26-09-2026. BandLock conserva el dataset dentro de la app para que la consulta funcione sin conexión.

El dataset no sustituye la información oficial de cada operador. El módem del propio iPhone sigue siendo la fuente de verdad para determinar qué bandas se pueden seleccionar en ese dispositivo.

### Compatibilidad y variantes

- iOS 16.x
- Sileo
- **RootHide**: `com.gokuencinar.bandlock` · `iphoneos-arm64e` · validado en iPhone XS con iOS 16.3.1.
- **Dopamine rootless**: `com.gokuencinar.bandlock.dopamine` · `iphoneos-arm64` · binarios arm64 + arm64e.
- Las variantes declaran `Conflicts:` entre sí para impedir una instalación cruzada accidental.
- App bundle: `com.gokuencinar.bandlock.app`
- Control de bandas: LTE/4G; BandLock no declara bloqueo de bandas 5G NR.
- La variante Dopamine ha pasado compilación, firma, validación de entitlements y estructura rootless en CI; la prueba física completa en un dispositivo con Dopamine normal queda pendiente.

## English

### Interface

BandLock uses three main tabs. CoreTelephony/CommCenter runs inside a separate LaunchDaemon (`BandLockDaemon`) and communicates with the app through a local Unix socket. The UI does not create child processes with `posix_spawn`:

- **Control** — modem status, current network, serving band, Automatic/LTE-only mode, manual band editing, apply/restore actions and Field Test.
- **Countries** — searchable list of 160 countries and territories. Each country shows reference LTE bands, frequency, FDD/TDD/SDL metadata, and which bands are also supported by the current iPhone modem.
- **Info** — credits, update checking, release notes, GokuEnREPO, technical glossary and language selector.

### Country profiles

Country profiles are **reference data**, not automatic modem commands. Tapping **Prepare compatible bands** computes:

`country LTE bands ∩ iPhone modem-supported LTE bands`

The result becomes the **pending selection**. The user must then review it in Control and explicitly tap **Apply selection**. Selecting a country never writes to the modem automatically.

A band being listed for a country does not mean every carrier uses it or that it is deployed at the current location. Deployments vary by carrier, region, roaming and time.

### Features

- Standalone UIKit app with a Home Screen icon.
- Manual selection of every LTE band reported as supported by the modem.
- Frequency and **FDD / TDD / SDL** metadata.
- Dynamic FDD, TDD, SDL and other-LTE groups.
- Quick actions for current active, all supported, FDD-only and TDD-only selections.
- Offline searchable country catalogue.
- **Manage frequencies for <country>** in Control after preparing a country; it only changes the pending selection.
- Safe intersection of country bands with actual iPhone modem capabilities.
- **Automatic** and **LTE / 4G only** network modes.
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

The 0.6.0 offline snapshot contains **160 countries and territories**, with LTE reference bands available for **156** of them in the source snapshot collected on 2026-09-26.

The dataset does not replace carrier-specific official information. The iPhone modem remains the source of truth for which LTE bands can actually be selected on the device.

### Compatibility and variants

- iOS 16.x
- Sileo
- **RootHide**: `com.gokuencinar.bandlock` · `iphoneos-arm64e` · real-device validated on iPhone XS / iOS 16.3.1.
- **Dopamine rootless**: `com.gokuencinar.bandlock.dopamine` · `iphoneos-arm64` · arm64 + arm64e binaries.
- The variants declare mutual `Conflicts:` to prevent accidental cross-installation.
- App bundle: `com.gokuencinar.bandlock.app`
- LTE/4G band control only; BandLock does not claim 5G NR band locking.
- The Dopamine variant has passed CI compilation, signing, entitlement validation and rootless package-layout checks; complete physical validation on a normal Dopamine device is still pending.

## Install / Instalación

Add this repository to Sileo / Añade este repositorio a Sileo:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Then install **BandLock (RootHide)** or **BandLock (Dopamine)** according to your jailbreak. The app will appear on the Home Screen after installation.

Después instala **BandLock (RootHide)** o **BandLock (Dopamine)** según tu jailbreak. La app aparecerá en la pantalla de inicio tras la instalación.

## Community testing / Pruebas comunitarias

Compatibility reports from different iPhone models, carriers and countries are useful, especially corrections to country reference data:

**[BandLock Global — community compatibility reports / pruebas de compatibilidad](https://github.com/Gokuencinar/GokuEnREPO/issues/1)**

Please never publish IMEI, IMSI, ICCID, phone numbers or other personal identifiers.

## Changelog

See / Ver: [BandLock changelog](changelogs/BandLock.md)

## Search terms

iOS jailbreak app · iOS 16 jailbreak · RootHide app · Dopamine tweak · LTE band lock · global LTE band selector · LTE bands by country · LTE FDD · LTE TDD · supplemental downlink · 4G band lock · 4G only · iPhone LTE bands · CoreTelephony · CommCenter · Field Test Mode · FTMInternal · arm64e · Sileo · Theos
