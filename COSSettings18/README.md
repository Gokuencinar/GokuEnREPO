# COS Settings 18 (beta experimental)

Tweak Theos/Logos para organizar las preferencias de jailbreak y personalizar el fondo de Ajustes en iOS 18. El proyecto surge de un estudio funcional de Shuffle 1.6.2, SettingsRevamp 3.0.1 y April 3.1. Todo el codigo es nuevo; no distribuye binarios, iconos ni recursos de esos paquetes.

## Funciones implementadas en 0.1.0

- Localiza las filas de PreferenceLoader por sus metadatos `pl_bundle` (documentados en la implementacion oficial), aunque aparezcan en **General** en lugar de la pantalla inicial. Por precaucion, solo agrupa si encuentra todas las filas reconocidas en un bloque contiguo precedido por su cabecera. Si el formato es diferente, no modifica el listado.
- Mueve sus filas a una subpagina "Mis tweaks". Permite renombrarla, ordenar alfabeticamente y moverla a la primera fila de la lista original.
- Ofrece un segundo interruptor independiente para un fondo degradado con dos colores hexadecimales, imagen seleccionable con el selector de fotos de Apple (PHPicker, API publica sin acceso global a la fototeca), desenfoque opcional y ocultar separadores en la pantalla inicial.
- Conserva el comportamiento original si los controles estan apagados o no encuentra la seccion; el filtro limita la inyeccion a `com.apple.Preferences`.

Las pantallas de ajustes de apps del sistema y de App Store, la transparencia de las celdas, el redisenyo del Apple Account y el resto de personalizaciones de SettingsRevamp/April quedan pendientes de inspeccion del runtime de iOS 18.7.1. No aparecen como controles funcionales en esta version.

## Entorno confirmado

- iPhone 11 Pro `iPhone12,3`; iOS 18.7.1 (22H31)
- Dopamine rootless, ElleKit 1.2, PreferenceLoader 2.2.8
- SSH operativo como usuario `mobile`
- Windows sin distribucion WSL ni Theos/SDK iOS local. **No existe aun un .deb compilado ni se ha hecho prueba de inyeccion.**

## Compilar cuando haya toolchain

En macOS o Linux con Theos, SDK iOS y toolchain compatibles:

```sh
make package FINALPACKAGE=1
```

El proyecto incluye `.github/workflows/build.yml` para compilar automaticamente en un runner macOS al alojarlo en un repositorio GitHub. No se ha ejecutado aun esa compilacion.

Ejecutar la validacion previa independiente del SDK:

```sh
python3 tests/check_project.py
```

No se necesita reiniciar SpringBoard para restaurar estos cambios visuales, aunque puede ser necesario cerrar/reabrir Ajustes para refrescar la pantalla principal. El paquete usa el esquema rootless de Theos. Antes de instalar una beta conviene desactivar temporalmente los otros tweaks que modifiquen Ajustes, para evitar hooks de interfaz enfrentados.

## Validacion pendiente antes de instalar

1. Confirmar en iOS 18.7.1 el selector `specifiers` de `PSUIPrefsListController` o `PrefsListController` (solo se dispone de indicadores estaticos, no de la firma ABI del runtime).
2. Confirmar en el runtime que los specifiers de PreferenceLoader 2.2.8 exponen el metadato `pl_bundle` y que la pagina de agrupacion conserva la navegacion hacia cada tweak.
3. Revisar el `.deb` compilado y probar primero ambos interruptores apagados. Activar una funcion por vez, comprobar la navegacion y revisar Cr4shed.

La version experimental no toca el rootfs, no edita preferencias de otras aplicaciones y no instala servicios persistentes. Para revertir una instalacion, desactivar desde el panel o desinstalar `com.gokuencinar.cossettings18` desde Sileo.
