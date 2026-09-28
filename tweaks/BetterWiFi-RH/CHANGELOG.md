# Changelog — BetterWiFi RH

Este archivo documenta las versiones de BetterWiFi RH publicadas actualmente en **GokuEnREPO**.

**Descripción:** tweak para ampliar la información y las herramientas Wi‑Fi de iOS, con detalles de la red conectada, monitorización, diagnóstico, filtros e integración con Shuffle.

**Compatibilidad:** iOS 16.x con RootHide (`iphoneos-arm64e`). El paquete declara compatibilidad con firmware iOS >= 16.0 y < 17.0.

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
