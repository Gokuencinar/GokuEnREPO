# BandLock 0.4.0

Rediseño de la interfaz para iPhone XS / iOS 16 / Dopamine RootHide.

## Pantalla principal
- Cabecera visual BandLock / España / Orange.
- Estado de red, RAT, banda conectada, modo LTE y bandas permitidas.
- Nueva entrada «Seleccionar bandas» que abre una pantalla independiente.
- Aplicar selección, restaurar selección anterior y restaurar modo automático.
- Acceso directo a FTMInternal-4.
- Diagnóstico y borrado de registros.

## Selector de bandas
Solo muestra bandas LTE usadas por operadores en España y compatibles con el iPhone:
- B28 · 700 MHz
- B20 · 800 MHz
- B8 · 900 MHz
- B3 · 1800 MHz
- B1 · 2100 MHz
- B7 · 2600 MHz FDD
- B38 · 2600 MHz TDD

Las bandas se agrupan por cobertura, uso general y capacidad.

Perfiles:
- Orange España: B1/B3/B7/B8/B20/B28.
- Todas las de España: añade B38.
- Cobertura: B8/B20/B28.
- B3+B7.

El selector solo prepara la selección. La escritura del módem sigue requiriendo pulsar «Aplicar selección LTE» desde la pantalla principal.
