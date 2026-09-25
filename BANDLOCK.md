# BandLock — LTE/4G Band Lock for iOS 16 RootHide

**BandLock** is a jailbreak tweak for **iOS 16**, **Dopamine** and **RootHide** that lets you inspect and manually control the LTE/4G bands allowed by the iPhone modem from the Settings app.

**BandLock** es un tweak de jailbreak para **iOS 16**, **Dopamine** y **RootHide** que permite consultar y controlar manualmente desde Ajustes las bandas LTE/4G permitidas por el módem del iPhone.

> Current version / Versión actual: **0.4.4** · Architecture / Arquitectura: **iphoneos-arm64e**

## Español

### Qué hace

BandLock permite seleccionar individualmente las bandas LTE que quieres dejar disponibles para el módem, por ejemplo **B1, B3, B7, B8, B20, B28 y B38**, mostrando también sus frecuencias. Incluye perfiles rápidos orientados a redes españolas, restauración del modo automático y un control independiente para usar **Automático** o **Solo LTE / 4G**.

Los cambios se realizan bajo demanda desde Ajustes. BandLock verifica con CoreTelephony lo que reporta el módem después de una escritura y, si CommCenter todavía devuelve el estado anterior, realiza un único reintento automático antes de mostrar el resultado.

### Funciones

- Selección manual de bandas LTE/4G.
- Lista de bandas y frecuencias usadas habitualmente en España.
- Perfiles rápidos, incluyendo Orange España y combinaciones frecuentes.
- Modo de red **Automático** y **Solo LTE / 4G**.
- Restauración de la selección anterior.
- Restauración de todas las bandas LTE soportadas por el módem.
- Verificación posterior de cambios mediante **CoreTelephony**.
- Reintento automático cuando CommCenter tarda en consolidar la escritura.
- Intento de lectura de la banda LTE de la celda servidora.
- Acceso directo a **FTMInternal / Field Test Mode**.
- Logs de diagnóstico.
- Sin daemon residente.
- Sin inyección en SpringBoard.
- Sin cambios automáticos del módem al arrancar.

### Importante

BandLock controla el **conjunto de bandas LTE permitidas**. La banda servidora final, la agregación de portadoras y otros parámetros de radio siguen dependiendo del módem, el operador y la red disponible. Si una selección provoca pérdida de servicio, utiliza la opción de restaurar el modo automático.

### Compatibilidad

- iOS 16.x
- Dopamine / RootHide
- iPhone arm64e
- PreferenceLoader
- Sileo
- Paquete: `iphoneos-arm64e`

## English

### What it does

BandLock lets you individually choose which LTE bands remain available to the modem, including commonly used bands such as **B1, B3, B7, B8, B20, B28 and B38**, with frequency labels. It includes quick presets focused on Spanish networks, automatic-mode restoration, and an independent **Automatic / LTE-4G only** radio-mode control.

Changes are only made when requested from Settings. BandLock reads back the modem state through CoreTelephony after a write and performs one automatic retry when CommCenter has not yet committed the requested band set.

### Features

- Manual LTE/4G band selection.
- Frequency labels for displayed LTE bands.
- Spain-focused presets and common band combinations.
- **Automatic** and **LTE / 4G only** network modes.
- Restore the previous LTE selection.
- Restore every LTE band supported by the modem.
- Post-write verification through **CoreTelephony**.
- Automatic retry when CommCenter still reports the previous configuration.
- Experimental serving-cell LTE band reading.
- Direct **FTMInternal / Field Test Mode** launcher.
- Diagnostic logs.
- No resident daemon.
- No SpringBoard injection.
- No automatic modem changes at boot.

### Important

BandLock controls the modem's **allowed LTE band set**. The final serving band, carrier aggregation and other radio decisions still depend on the modem, carrier and available network. If a selection causes loss of service, restore automatic mode.

### Compatibility

- iOS 16.x
- Dopamine / RootHide
- arm64e iPhones
- PreferenceLoader
- Sileo
- Package architecture: `iphoneos-arm64e`

## Install / Instalación

Add this repository to Sileo / Añade este repositorio a Sileo:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Then install **BandLock**.

## Community testing / Pruebas comunitarias

BandLock is looking for reports from other iPhone models, carriers and countries. Share results in the official compatibility thread:

**[BandLock 0.4.4 — community compatibility reports / pruebas de compatibilidad](https://github.com/Gokuencinar/GokuEnREPO/issues/1)**

Please never include IMEI, IMSI, ICCID, phone numbers or other personal identifiers in public reports.

Si BandLock te resulta útil, puedes marcar el repositorio con una **Star** y compartir esta página con otros usuarios de jailbreak. / If BandLock is useful to you, consider giving the repository a **Star** and sharing this page with other jailbreak users.

## Changelog

See / Ver: [BandLock changelog](changelogs/BandLock.md)

## Search terms

iOS jailbreak tweak · iOS 16 jailbreak · RootHide tweak · Dopamine tweak · LTE band lock · LTE band selection · 4G band lock · 4G only · iPhone LTE bands · CoreTelephony · CommCenter · Field Test Mode · FTMInternal · arm64e · Sileo · Theos
