# Changelog — BetterWiFi RH

Este archivo documenta las versiones de BetterWiFi RH publicadas actualmente en **GokuEnREPO**.

**Descripción:** tweak para ampliar la información y las herramientas Wi‑Fi de iOS, con detalles de la red conectada, monitorización, diagnóstico, filtros e integración con Shuffle.

**Compatibilidad actual:** RootHide iOS 16 (`iphoneos-arm64e`), Dopamine rootless iOS 15–18 (`iphoneos-arm64`) y rootful iOS 15–17 (`iphoneos-arm`).

## 0.3.15

### Packaging
- Split BetterWiFi RH into unique package IDs so Sileo can no longer select the wrong jailbreak variant:
  - com.betterwifirh.tweak.roothide
  - com.betterwifirh.tweak.dopamine
  - com.betterwifirh.tweak.rootful
- Added architecture-specific com.betterwifirh.tweak 0.3.15 transitional packages so users upgrading from 0.3.14 are automatically migrated to the correct variant.
- Added Conflicts, Breaks and Replaces metadata to prevent incompatible variants from being installed together.
- Kept the 0.3.14 codebase and modern arm64e fix unchanged; 0.3.15 is primarily a package-selection/migration fix.

## 0.3.14

### Fixed
- Rebuilt the **Dopamine rootless** package cleanly from source on macOS instead of reusing converted RootHide binaries.
- Both BetterWiFiRH.dylib and BetterWiFiRHPrefs now contain native **arm64 + modern arm64e** slices (0x80000002) for current Dopamine environments.
- Added build-time validation that rejects legacy arm64e ABI slices before a Dopamine package can be published.
- Kept executable permissions at 0755 for the tweak dylib and PreferenceBundle executable.
- Corrected package architecture metadata for all three variants: iphoneos-arm64e (RootHide), iphoneos-arm64 (Dopamine rootless), and iphoneos-arm (rootful).
- This rebuild addresses reported PreferenceBundle loading failures on iOS 16 Dopamine and pointer-authentication crashes reported on iOS 18 Dopamine.

## 0.3.13

### Fixed
- Fixed executable permissions in the **Dopamine rootless** and **rootful** packages.
- `BetterWiFiRH.dylib` and `BetterWiFiRHPrefs` are now packaged with mode `0755`.
- Fixes PreferenceLoader reporting that `BetterWiFiRHPrefs.bundle` could not be loaded because its executable could not be located.
- Added build-time protection so future packages are created with the correct executable permissions.

## 0.3.12

### Publicación multiplataforma
- Añadida build para **RootHide** (`iphoneos-arm64e`, iOS 16).
- Añadida build para **Dopamine rootless** (`iphoneos-arm64`, iOS 15–18).
- Añadida build para **rootful** (`iphoneos-arm`, iOS 15–17).

### Corregido
- Ajustado el espaciado de la sección de créditos para que **Gokuencinar / GokuEn** no tape el texto de créditos de BetterWiFi RH.
- Completada la traducción al inglés de la sección **Advanced Filters**.

### Conservado
- Información ampliada de la red conectada.
- Monitor de señal e historial/gráfica.
- Analizador de canales de 2,4 y 5 GHz.
- Filtros, diagnóstico, Shuffle y PreferenceLoader.
- Selector de idioma Automático / Español / Inglés.
- Funcionamiento bajo demanda sin daemon residente dedicado.

## 0.3.11

### Nuevo
- Sección de créditos integrada al final de las preferencias.
- Avatar de Gokuencinar / GokuEn, el mismo utilizado en otros tweaks.
- Botón para abrir GokuEnREPO.
- Botón **Buy Me a Coffee** enlazado a https://buymeacoffee.com/gokuen.
- Los textos de créditos respetan el selector Español / Inglés / Automático.

### Conservado
- Selector de idioma inline de 0.3.10.
- Todas las correcciones de filtros, monitor, analizador, estabilidad y consumo.

## 0.3.10

### Corregido
- El selector de idioma ya no abre una pantalla secundaria vacía/negra.
- Se sustituye `PSLinkListCell` por un selector `PSSegmentCell` integrado en la propia página.
- La recarga de preferencias tras cambiar el idioma se difiere al siguiente ciclo de la cola principal para evitar conflictos durante el evento del control.

### Conservado
- Modos **Automático**, **Español** e **Inglés**.
- El cambio sigue afectando únicamente a BetterWiFi RH.

## 0.3.9

### Nuevo
- Selector de idioma dentro de las preferencias de BetterWiFi RH.
- Modos **Automático**, **Español** e **Inglés**.
- El modo Automático sigue el idioma configurado en iOS.
- Español e Inglés fuerzan únicamente el idioma de BetterWiFi RH, sin cambiar el idioma global de Ajustes.
- El panel de preferencias se recarga al cambiar el idioma, sin requerir respring.
- Las pantallas propias del tweak adoptan el idioma seleccionado al volver a abrirlas.

### Conservado
- Todas las correcciones de estabilidad, filtros, monitor de señal, analizador de canales y optimizaciones de consumo de 0.3.8.

## 0.3.8

### Nuevo
- Compatibilidad con RootHide.
- Detalles estables de la red Wi‑Fi conectada.
- Monitorización en vivo.
- Herramientas de diagnóstico.
- Filtros adicionales para redes.
- Integración con Shuffle.
- PreferenceBundle para configuración desde Ajustes.

### Cambiado
- Adaptación del tweak y su PreferenceBundle al esquema `iphoneos-arm64e` usado por RootHide.
- Ajuste del paquete para iOS 16.x.

### Nota
- 0.3.8 se mantiene documentada como la versión anterior a 0.3.9.
