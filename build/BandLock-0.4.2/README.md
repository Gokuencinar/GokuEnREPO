# BandLock 0.4.2

Corrección del selector «Tecnología preferida».

En 0.4.1 se utilizó PSListItemCell, que mostraba el valor pero no abría una pantalla de selección al tocarlo.

0.4.2 usa PSLinkListCell + PSListItemsController:
- Automático
- Solo LTE / 4G

La lectura RAT que mostraba «Automático» ya funcionaba; esta versión corrige la interacción para poder cambiar el modo desde Preferencias.

Se mantiene:
- bloqueo de bandas LTE,
- selector de bandas usadas en España,
- restauración de modo automático,
- FTMInternal-4,
- verificación posterior y logs SSH.
