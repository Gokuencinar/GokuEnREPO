# BandLock 0.4.1

Añade control manual de la tecnología de acceso (RAT) además del bloqueo de bandas LTE.

## Modo de red
- Automático: restaura la selección automática de iOS/CommCenter.
- Solo LTE / 4G: solicita kCTRegistrationRATSelectionLTE para impedir fallback a 3G/EDGE mientras esté activo.
- El cambio usa CoreTelephonyClient setRatSelection:selection:preferred:completion:.
- Después de aplicar, BandLock vuelve a leer getRatSelection:completion: y muestra la configuración realmente reportada.
- Si no hay cobertura LTE disponible, el dispositivo puede quedarse temporalmente sin servicio.
- Si VoLTE no está disponible, las llamadas pueden verse afectadas.

Se mantiene el selector de bandas españolas, restauración automática, FTMInternal-4 y los registros SSH.
