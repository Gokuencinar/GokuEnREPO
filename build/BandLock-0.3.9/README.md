# BandLock 0.3.9

Versión centrada en España y Orange para iPhone XS / iOS 16 / RootHide.

- UI reorganizada con cabecera visual, estado, perfiles rápidos, bandas agrupadas por cobertura/capacidad y acciones separadas.
- Solo muestra las bandas LTE principales para España: B28 700, B20 800, B8 900, B3 1800, B1 2100 y B7 2600.
- Oculta bandas internacionales/no prioritarias para este uso, como B5 850, B12, B13, B25, B41 o B66.
- Presets: Orange España, Cobertura, Capacidad y B3+B7.
- Mantiene restauración de selección anterior y modo automático completo.
- «Banda conectada» intenta leer la celda servidora mediante CoreTelephony.
- Field Test abre com.apple.FTMInternal (FTMInternal-4), primero mediante FrontBoardServices y como fallback mediante LaunchServices.
- Conserva verificación posterior del módem y logs sin datos del contexto completo de la SIM.
