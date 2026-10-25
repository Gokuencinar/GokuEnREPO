# Better Settings (beta experimental)

**Revision 0.1.1:** El panel 0.1.0 no se cargaba en Ajustes de iOS 18.7.1: dyld identificó `have 'arm64', need 'arm64e'`. Se compilaron ambos Mach-O para `arm64e`, se verificaron las arquitecturas en CI y se instalo 0.1.1 por SSH. El formato Debian rootless sigue siendo `iphoneos-arm64`. La apertura del panel sigue pendiente de comprobacion visual tras cerrar y volver a abrir Ajustes.

**Revision 0.1.2 (diagnostico):** tras confirmar el usuario que el panel se abre y los interruptores de ordenacion se guardan, se agrega el controlador `PSGGeneralController` usado por PreferenceLoader en iOS 18. Se guarda un diagnostico acotado en las claves `diagStage`, `diagClass`, `diagSpecifierCount` y `diagHookCalls` del dominio del tweak para medir el resultado sin recoger nombres de tweaks ni datos del telefono. El estado visual requiere prueba tras instalar y cerrar/abrir Ajustes.

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
- Windows sin distribucion WSL ni Theos/SDK iOS local. El .deb 0.1.0 se compilo en GitHub Actions macOS y se instalo en el iPhone el 21/10/2026. El arranque de Ajustes fue verificado, pero el funcionamiento visual del agrupador y de los fondos aun requiere una prueba en pantalla.

## Compilar cuando haya toolchain

En macOS o Linux con Theos, SDK iOS y toolchain compatibles:

```sh
make package FINALPACKAGE=1
```

La variante integrada en `Gokuencinar/GokuEnREPO`, rama `feature/bettersettings-ios18-ci`, compilo correctamente mediante GitHub Actions run `39507496424` (commit `22dea6c`). Artefacto `BetterSettings-rootless`, SHA-256 del ZIP: `59dfe32b2e8a5ef91dc7e0df9ccf8a75f64a29eeb10a5a1e15aae61ff180be5f`.

Ejecutar la validacion previa independiente del SDK:

```sh
python3 tests/check_project.py
```

No se necesita reiniciar SpringBoard para restaurar estos cambios visuales, aunque puede ser necesario cerrar/reabrir Ajustes para refrescar la pantalla principal. El paquete usa el esquema rootless de Theos. Antes de instalar una beta conviene desactivar temporalmente los otros tweaks que modifiquen Ajustes, para evitar hooks de interfaz enfrentados.

## Pruebas pendientes tras la instalacion experimental

1. Confirmar en iOS 18.7.1 el selector `specifiers` de `PSUIPrefsListController` o `PrefsListController` (solo se dispone de indicadores estaticos, no de la firma ABI del runtime).
2. Confirmar en el runtime que los specifiers de PreferenceLoader 2.2.8 exponen el metadato `pl_bundle` y que la pagina de agrupacion conserva la navegacion hacia cada tweak.
3. Probar visualmente ambos interruptores, una funcion por vez, comprobar la navegacion y revisar Cr4shed. La instalacion y el arranque de Ajustes ya estan verificados; el resultado visual aun no.

La version experimental no toca el rootfs, no edita preferencias de otras aplicaciones y no instala servicios persistentes. Para revertir una instalacion, desactivar desde el panel o desinstalar `com.gokuencinar.bettersettings` desde Sileo.

Ver [registro de instalacion y recuperacion](INSTALLATION-2026-10-21.md).
