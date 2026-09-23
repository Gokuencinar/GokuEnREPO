# Changelog — BandLock

Este archivo documenta las versiones de BandLock que están publicadas actualmente en **GokuEnREPO**.

**Descripción:** tweak RootHide para consultar y seleccionar bandas LTE, aplicar perfiles rápidos y controlar el modo de red desde Ajustes.

**Compatibilidad:** iOS 16.x con jailbreak RootHide/Dopamine y arquitectura `iphoneos-arm64e`. El paquete actual está compilado con target iOS 16.0.

## 0.4.4

### Nuevo
- Verificación diferida de los cambios de bandas LTE.
- Reintento automático único cuando CommCenter todavía devuelve la configuración anterior después de una escritura.

### Cambiado
- Aplicar selección LTE espera aproximadamente 0,8 s antes de comprobar el resultado.
- Si la primera lectura no coincide, BandLock vuelve a escribir la selección y verifica de nuevo aproximadamente 1 s después.
- La comprobación del resultado usa ahora el conjunto LTE completo del módem, no solo las bandas visibles en el filtro de España.
- Restaurar modo automático puede verificar correctamente bandas que no aparecen en el selector español.
- La selección pendiente se conserva cuando la primera escritura no se consolida inmediatamente.

### Corregido
- El caso en el que era necesario pulsar dos veces Aplicar selección LTE.
- El caso en el que era necesario pulsar dos veces Restaurar modo automático.
- La selección manual ya no se sustituye inmediatamente por una lectura antigua del módem.

---

## 0.4.3

### Nuevo
- Controles directos para el modo de red:
  - Automático
  - Solo LTE / 4G
- Indicador ✓ en el modo RAT activo.

### Cambiado
- Se eliminó el selector genérico de Preferences usado en 0.4.2.
- El cambio RAT se ejecuta directamente desde botones nativos.
- Solo LTE / 4G mantiene una confirmación previa antes de modificar la configuración del módem.

### Corregido
- Crash de Preferencias al tocar Tecnología preferida en 0.4.2.

---

## 0.4.2

### Nuevo
- Intento de convertir Tecnología preferida en una lista navegable con:
  - Automático
  - Solo LTE / 4G

### Cambiado
- La UI pasó del PSListItemCell no interactivo de 0.4.1 a un selector basado en PSLinkListCell / PSListItemsController.

### Nota
- En iOS 16.3 / RootHide esta implementación resultó inestable y provocaba un crash al abrir el selector. Se reemplazó completamente en 0.4.3.

---

## 0.4.1

### Nuevo
- Control de tecnología de acceso RAT además del bloqueo de bandas.
- Modo Automático.
- Modo Solo LTE / 4G.
- Lectura de la configuración RAT mediante getRatSelection:completion:.
- Escritura RAT mediante setRatSelection:selection:preferred:completion:.
- Registro de RAT-Selection y RAT-Preferred en los logs.

### Cambiado
- BandLock puede evitar el fallback a 3G/EDGE cuando se solicita Solo LTE / 4G.
- Después de modificar el RAT se vuelve a consultar CoreTelephony para mostrar lo que realmente reporta el sistema.

### Nota
- La primera UI del selector mostraba el valor actual pero no abría correctamente una pantalla de selección. La interacción se revisó en 0.4.2 y finalmente quedó corregida en 0.4.3.

---

## 0.4.0

### Nuevo
- Pantalla independiente Seleccionar bandas.
- Selector centrado en las bandas LTE utilizadas en España y soportadas por el dispositivo:
  - B28 · 700 MHz
  - B20 · 800 MHz
  - B8 · 900 MHz
  - B3 · 1800 MHz
  - B1 · 2100 MHz
  - B7 · 2600 MHz FDD
  - B38 · 2600 MHz TDD
- Agrupación visual por Cobertura, Uso general y Capacidad.
- Perfiles rápidos:
  - Orange España
  - Todas las de España
  - Cobertura
  - B3 + B7
- Persistencia de la selección pendiente al volver a la pantalla principal.

### Cambiado
- Rediseño importante de la UI.
- La pantalla principal se simplificó para mostrar estado y acciones.
- La selección manual dejó de mezclarse con el panel principal.
- Restaurar modo automático conserva la capacidad de reactivar todas las bandas LTE que soporte el módem, incluidas las ocultas por el filtro español.

---

## 0.3.9

### Nuevo
- UI centrada en España y Orange.
- Cabecera visual de BandLock.
- Secciones separadas para estado, perfiles, bandas y acciones.
- Presets Orange España, Cobertura, Capacidad y B3 + B7.
- Acceso a FTMInternal-4.

### Cambiado
- La interfaz dejó de mostrar la mayoría de bandas internacionales/no prioritarias para España.
- Se priorizaron B28/B20/B8/B3/B1/B7.
- El botón de Field Test dejó de intentar abrir com.apple.fieldtest y pasó a lanzar com.apple.FTMInternal.
- El lanzamiento de Field Test intenta primero FrontBoardServices y usa LaunchServices como fallback.

---

## 0.3.8

### Nuevo
- Frecuencia nominal junto al nombre de cada banda LTE.
- Preset inicial Orange España.
- Botones Seleccionar todas y Deseleccionar todas.
- Guardado de la selección LTE anterior.
- Acción Restaurar selección anterior.
- Primer intento de mostrar la banda de la celda servidora mediante CoreTelephony.
- Primer botón para abrir Field Test Mode.

### Cambiado
- La UI empezó a distinguir mejor entre bandas soportadas, bandas permitidas y banda servidora.
- Los logs mantienen los datos de SIM/contexto sensibles fuera del registro.

### Nota
- El primer launcher de Field Test usaba com.apple.fieldtest; se corrigió a com.apple.FTMInternal en 0.3.9.

---

## 0.3.7

### Nuevo
- Primera versión de BandLock capaz de **escribir** el conjunto de bandas LTE permitidas.
- Interruptores generados a partir de las bandas LTE soportadas por el módem.
- Aplicación mediante setActiveBandInfo:bands:error:.
- Verificación posterior mediante una nueva lectura de getBandInfo:error:.
- Acción Restaurar todas las LTE.
- Confirmación antes de aplicar una selección.
- Rechazo de selecciones LTE vacías.

### Cambiado
- Se modifica únicamente kCTRegistrationRadioAccessTechnologyLTE.
- GSM, UTRAN, TDSCDMA y otros RAT se conservan sin cambios.
- Los logs dejaron de guardar la descripción completa del contexto de suscripción.

### Validado
- Se confirmó una escritura real y lectura posterior de configuraciones como B3 + B7.

---

## 0.3.6

### Nuevo
- Sistema de logs en /var/mobile/Library/Logs/BandLock/.
- Archivo BandLock-last.txt para facilitar el diagnóstico por SSH.
- Botón Eliminar todos los registros con confirmación.
- Registro de resultados de las consultas CoreTelephony.

### Cambiado
- Se mantuvo la operación completamente de solo lectura.
- El borrado se limita a la carpeta de logs de BandLock.

### Seguridad
- Esta versión no llama a setters de bandas del módem.

---

## 0.3.5

### Nuevo
- Primer inspector funcional de bandas celulares en modo de solo lectura.
- Consulta manual de CoreTelephony.
- Lectura de bandas soportadas y activas mediante getBandInfo:error:.

### Cambiado
- BandLock pasó de ser una prueba de controlador/UI a consultar información real del módem.
- La consulta solo se ejecuta por acción del usuario.

### Seguridad
- No realiza escrituras de bandas.

---

## 0.3.4

### Nuevo
- Primera versión de BandLock conservada en el repositorio APT.
- PreferenceBundle directo y estable para RootHide.
- Controlador de Preferencias funcional dentro de Ajustes.
- Base de UI utilizada por las versiones posteriores.

### Cambiado
- Se abandonó la arquitectura de carga secundaria/lazy que había dado problemas en prototipos anteriores.

---

## Criterios de diseño mantenidos

- Sin daemon residente.
- Sin inyección en SpringBoard.
- Sin escritura automática de bandas al iniciar.
- Los cambios de radio requieren una acción manual del usuario.
- Las lecturas posteriores del módem se usan para diferenciar una solicitud de un cambio realmente aplicado.
