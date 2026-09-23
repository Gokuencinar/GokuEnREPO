# BandLock 0.4.3

Corrige el crash al tocar «Tecnología preferida» de 0.4.2.

La causa estaba en el selector genérico de Preferences usado para abrir la lista RAT. En esta versión se elimina por completo esa ruta.

## Modo de red
La pantalla principal muestra dos botones nativos y seguros:
- Automático
- Solo LTE / 4G

El modo activo se marca con ✓.

Los botones llaman directamente al código RAT ya implementado:
- getRatSelection:completion:
- setRatSelection:selection:preferred:completion:

Solo LTE / 4G sigue mostrando confirmación antes de cambiar el módem.

Se mantiene el selector separado de bandas LTE de España, FTMInternal-4, verificación posterior y logs.
