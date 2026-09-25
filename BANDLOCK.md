# BandLock Global — LTE/4G Band Control for iOS 16 RootHide

**BandLock Global** is the public, worldwide edition of BandLock for **iOS 16**, **Dopamine** and **RootHide**. Instead of assuming a country or carrier, it reads the LTE capabilities reported by the iPhone modem and builds the selector from those bands at runtime.

**BandLock Global** es la edición pública e internacional de BandLock para **iOS 16**, **Dopamine** y **RootHide**. En lugar de asumir un país u operador, lee las capacidades LTE que reporta el propio módem del iPhone y genera el selector dinámicamente.

> Current public version / Versión pública actual: **0.5.0 Global** · Architecture / Arquitectura: **iphoneos-arm64e**

## Español

### Qué hace

BandLock Global permite consultar y controlar manualmente las **bandas LTE/4G permitidas** por el módem desde Ajustes. La lista no está limitada a España: muestra todas las bandas LTE que `CoreTelephony` informa como soportadas en ese dispositivo concreto.

Cada banda conocida incluye su frecuencia nominal y el tipo de operación de radio correspondiente (**FDD**, **TDD** o **SDL**). El tipo FDD/TDD pertenece a la definición de la propia banda LTE; lo que cambia entre países, operadores, regiones y celdas es qué bandas están desplegadas y disponibles.

### Funciones

- Selección manual de todas las bandas LTE que el módem reporta como soportadas.
- Etiquetas de frecuencia y clasificación **FDD / TDD / SDL**.
- Grupos dinámicos: FDD, TDD, SDL y otras bandas LTE reportadas.
- Acciones rápidas: selección activa actual, todas las soportadas, solo FDD y solo TDD.
- Modo de red **Automático** y **Solo LTE / 4G**.
- Restauración de la selección anterior.
- Restauración de todas las bandas LTE soportadas por el módem.
- Verificación posterior de la escritura mediante **CoreTelephony**.
- Un reintento automático cuando CommCenter todavía devuelve la configuración anterior.
- Intento de lectura de la banda LTE de la celda servidora.
- Acceso directo a **FTMInternal / Field Test Mode**.
- Logs de diagnóstico.
- Sin daemon residente.
- Sin inyección en SpringBoard.
- Sin cambios automáticos del módem al arrancar.

### Diseño global

BandLock Global **no usa una base de datos rígida de bandas por país u operador**. Esa aproximación puede quedar obsoleta y producir resultados incorrectos con roaming, OMV, variantes regionales de iPhone o despliegues locales. El módem es la fuente de verdad para decidir qué bandas se pueden seleccionar.

Que una banda aparezca como soportada por el iPhone **no significa que tu operador la utilice en tu ubicación**. Si restringes demasiado la selección puedes perder cobertura, datos o llamadas. Las bandas SDL son de bajada suplementaria y normalmente no deben seleccionarse como única banda.

### Separación de la edición privada

La antigua edición **0.4.4 orientada a España** usa el identificador `com.local.bandlock` y queda fuera de la línea pública de nuevas versiones. La edición pública Global usa `com.gokuencinar.bandlock`, un PreferenceBundle diferente y archivos de estado/log independientes para evitar colisiones.

### Compatibilidad

- iOS 16.x
- Dopamine / RootHide
- iPhone arm64e
- PreferenceLoader
- Sileo
- Paquete: `iphoneos-arm64e`
- Control de bandas: LTE/4G. BandLock 0.5.0 no pretende controlar bandas 5G NR.

## English

### What it does

BandLock Global lets you inspect and manually control the **allowed LTE/4G band set** directly from Settings. The selector is not restricted to Spain: it is generated from every LTE band that `CoreTelephony` reports as supported by that specific modem.

Known bands are labelled with their nominal frequency and radio operation type (**FDD**, **TDD** or **SDL**). FDD/TDD is defined by the LTE operating band itself; what differs across countries, carriers, regions and cells is which standardized bands are actually deployed and available.

### Features

- Manual selection of every LTE band reported as supported by the modem.
- Frequency labels and **FDD / TDD / SDL** classification.
- Dynamic FDD, TDD, SDL and other-LTE groups.
- Quick actions for current active selection, all supported, FDD only and TDD only.
- **Automatic** and **LTE / 4G only** network modes.
- Restore the previous LTE selection.
- Restore every LTE band supported by the modem.
- Post-write verification through **CoreTelephony**.
- One automatic retry when CommCenter still reports the previous configuration.
- Experimental serving-cell LTE band reading.
- Direct **FTMInternal / Field Test Mode** launcher.
- Diagnostic logs.
- No resident daemon.
- No SpringBoard injection.
- No automatic modem changes at boot.

### Global design

BandLock Global deliberately **does not use a hard-coded country/carrier band database**. Such databases can become stale and can be wrong for roaming, MVNOs, regional iPhone variants and local deployments. The modem itself is used as the source of truth for which LTE bands can be selected.

A band being supported by the iPhone **does not mean your carrier deploys it where you are**. Restricting the list too aggressively can cause loss of coverage, data or calls. SDL bands are supplemental downlink and normally should not be selected as the only allowed band.

### Private/public split

The former **Spain-focused 0.4.4** edition uses `com.local.bandlock` and is no longer the public development line. The public Global edition uses `com.gokuencinar.bandlock`, a separate PreferenceBundle, and independent state/log files to prevent collisions.

### Compatibility

- iOS 16.x
- Dopamine / RootHide
- arm64e iPhones
- PreferenceLoader
- Sileo
- Package architecture: `iphoneos-arm64e`
- Band control: LTE/4G. BandLock 0.5.0 does not claim 5G NR band control.

## Install / Instalación

Add this repository to Sileo / Añade este repositorio a Sileo:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Then install **BandLock** / Después instala **BandLock**.

## Community testing / Pruebas comunitarias

Reports from different iPhone models, carriers and countries are especially useful for the Global edition:

**[BandLock Global — community compatibility reports / pruebas de compatibilidad](https://github.com/Gokuencinar/GokuEnREPO/issues/1)**

Please never include IMEI, IMSI, ICCID, phone numbers or other personal identifiers in public reports.

## Changelog

See / Ver: [BandLock changelog](changelogs/BandLock.md)

## Search terms

iOS jailbreak tweak · iOS 16 jailbreak · RootHide tweak · Dopamine tweak · LTE band lock · global LTE band selector · LTE FDD · LTE TDD · supplemental downlink · 4G band lock · 4G only · iPhone LTE bands · CoreTelephony · CommCenter · Field Test Mode · FTMInternal · arm64e · Sileo · Theos
