# BandLock 0.3.8

- Etiqueta cada banda LTE con su frecuencia nominal.
- Añade un preset Orange España que prepara B1/B3/B7/B8/B20/B28 cuando esas bandas están soportadas.
- Añade Seleccionar todas / Deseleccionar todas.
- Guarda la selección LTE anterior antes de aplicar y permite restaurarla.
- Intenta mostrar la banda de la celda servidora real mediante CoreTelephony.
- Añade «Abrir Field Test Mode», que intenta lanzar directamente com.apple.fieldtest mediante LaunchServices.
- Mantiene la verificación posterior con getBandInfo:error:.
- No usa daemon ni inyección en SpringBoard.
- Los logs no guardan el contexto completo de la SIM.
