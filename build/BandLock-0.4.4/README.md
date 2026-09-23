# BandLock 0.4.4

Corrige el caso en el que «Aplicar selección LTE» o «Restaurar modo automático» parecían necesitar dos pulsaciones.

Cambios:
- la selección pendiente ya no se sobrescribe con una lectura antigua justo después de escribir;
- BandLock espera 0,8 s antes de verificar para dar tiempo a CommCenter a consolidar el cambio;
- si la primera lectura todavía devuelve la configuración anterior, BandLock repite automáticamente la escritura una sola vez y vuelve a verificar tras 1 s;
- la comparación se hace contra todas las bandas LTE activas del módem, no solo contra las bandas filtradas para España;
- «Restaurar modo automático» puede verificarse correctamente aunque reactive bandas que están ocultas en la UI española;
- si incluso tras el reintento el resultado no coincide, se mantiene la selección pendiente para que el usuario no tenga que volver a marcarla.

No se añaden procesos en segundo plano ni escrituras automáticas al iniciar.
