# BandLock 0.3.7

Versión experimental para iPhone XS / iOS 16 / Dopamine RootHide.

- Lee las bandas con `getBandInfo:error:`.
- Genera la lista de interruptores LTE a partir de las bandas soportadas que devuelve el dispositivo.
- Cambia únicamente `kCTRegistrationRadioAccessTechnologyLTE`.
- Conserva sin modificar las bandas activas de los demás RAT.
- Aplica con `setActiveBandInfo:bands:error:`.
- Después de escribir, vuelve a leer `CTBandInfo` y muestra el resultado real.
- Nunca permite aplicar una lista LTE vacía.
- Incluye «Restaurar todas las LTE» para volver a todas las bandas LTE soportadas.
- No usa daemon, no inyecta SpringBoard y no aplica nada en segundo plano.
- Los logs ya no guardan la descripción del contexto de suscripción para evitar registrar el número de teléfono.
