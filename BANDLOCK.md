# BandLock Global — LTE/4G Band Control App for iOS 16 RootHide

**BandLock Global** is the public worldwide edition of BandLock for **iOS 16**, **Dopamine** and **RootHide**. Version 0.6.0 is a standalone Home Screen app rather than a Settings PreferenceBundle.

**BandLock Global** es la edición pública internacional de BandLock para **iOS 16**, **Dopamine** y **RootHide**. Desde la versión 0.6.0 funciona como una app independiente en la pantalla de inicio y ya no como un panel dentro de Ajustes.

> Current public version / Versión pública actual: **0.6.2 Global App** · Architecture / Arquitectura: **iphoneos-arm64e**

## Español

### Interfaz

BandLock se divide en dos pestañas. La versión 0.6.2 ejecuta CoreTelephony/CommCenter dentro de un helper separado (`BandLockHelper`), para que un fallo de esas APIs privadas no cierre la app principal:

- **Control** — estado del módem, red actual, banda servidora, modo Automático/Solo LTE, selección manual de bandas, aplicar, restaurar y Field Test.
- **Países** — buscador con 160 países y territorios. Cada país muestra sus bandas LTE de referencia, frecuencia, FDD/TDD/SDL y cuáles de ellas son compatibles con el módem del iPhone.

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
- Intersección segura entre bandas del país y capacidades reales del iPhone.
- Modo **Automático** y **Solo LTE / 4G**.
- Restauración de la selección anterior o de todas las bandas soportadas.
- Verificación posterior mediante **CoreTelephony** y un reintento si CommCenter todavía devuelve el estado anterior.
- Relectura de `supportedBands` justo antes de escribir.
- Bloqueo de selecciones vacías y de selecciones compuestas únicamente por SDL.
- Lectura experimental de la banda LTE servidora.
- Acceso a **FTMInternal / Field Test Mode**.
- Logs de diagnóstico.
- Sin daemon residente y sin cambios automáticos al abrir la app o al arrancar.

### Datos de países

El snapshot incluido en 0.6.0 contiene **160 países y territorios**, de los cuales **156 tienen bandas LTE de referencia** en la fuente utilizada el 26-09-2026. BandLock conserva el dataset dentro de la app para que la consulta funcione sin conexión.

El dataset no sustituye la información oficial de cada operador. El módem del propio iPhone sigue siendo la fuente de verdad para determinar qué bandas se pueden seleccionar en ese dispositivo.

### Compatibilidad

- iOS 16.x
- Dopamine / RootHide
- iPhone arm64e
- Sileo
- Paquete: `iphoneos-arm64e`
- Paquete Debian: `com.gokuencinar.bandlock`
- App bundle: `com.gokuencinar.bandlock.app`
- Control de bandas: LTE/4G; 0.6.0 no declara bloqueo de bandas 5G NR.

## English

### Interface

BandLock uses two main tabs. Version 0.6.2 runs CoreTelephony/CommCenter inside a separate helper (`BandLockHelper`), so a private-API failure does not have to terminate the main app UI:

- **Control** — modem status, current network, serving band, Automatic/LTE-only mode, manual band editing, apply/restore actions and Field Test.
- **Countries** — searchable list of 160 countries and territories. Each country shows reference LTE bands, frequency, FDD/TDD/SDL metadata, and which bands are also supported by the current iPhone modem.

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
- Safe intersection of country bands with actual iPhone modem capabilities.
- **Automatic** and **LTE / 4G only** network modes.
- Restore previous selection or every modem-supported LTE band.
- **CoreTelephony** write verification plus one retry when CommCenter still reports the previous state.
- Fresh `supportedBands` check immediately before a write.
- Empty and SDL-only selections are rejected.
- Experimental serving-cell LTE band reading.
- Direct **FTMInternal / Field Test Mode** launcher.
- Diagnostic logs.
- No resident daemon and no automatic modem writes at launch or boot.

### Country data

The 0.6.0 offline snapshot contains **160 countries and territories**, with LTE reference bands available for **156** of them in the source snapshot collected on 2026-09-26.

The dataset does not replace carrier-specific official information. The iPhone modem remains the source of truth for which LTE bands can actually be selected on the device.

### Compatibility

- iOS 16.x
- Dopamine / RootHide
- arm64e iPhones
- Sileo
- Package architecture: `iphoneos-arm64e`
- Debian package: `com.gokuencinar.bandlock`
- App bundle: `com.gokuencinar.bandlock.app`
- LTE/4G band control only; 0.6.0 does not claim 5G NR band locking.

## Install / Instalación

Add this repository to Sileo / Añade este repositorio a Sileo:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Then install **BandLock**. The app will appear on the Home Screen after installation.

Después instala **BandLock**. La app aparecerá en la pantalla de inicio tras la instalación.

## Community testing / Pruebas comunitarias

Compatibility reports from different iPhone models, carriers and countries are useful, especially corrections to country reference data:

**[BandLock Global — community compatibility reports / pruebas de compatibilidad](https://github.com/Gokuencinar/GokuEnREPO/issues/1)**

Please never publish IMEI, IMSI, ICCID, phone numbers or other personal identifiers.

## Changelog

See / Ver: [BandLock changelog](changelogs/BandLock.md)

## Search terms

iOS jailbreak app · iOS 16 jailbreak · RootHide app · Dopamine tweak · LTE band lock · global LTE band selector · LTE bands by country · LTE FDD · LTE TDD · supplemental downlink · 4G band lock · 4G only · iPhone LTE bands · CoreTelephony · CommCenter · Field Test Mode · FTMInternal · arm64e · Sileo · Theos
