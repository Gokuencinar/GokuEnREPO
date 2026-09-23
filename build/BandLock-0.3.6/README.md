# BandLock 0.3.6

Versión de diagnóstico solo lectura para Dopamine RootHide / iOS 16.

- Mantiene el PreferenceBundle estable.
- CoreTelephony solo se consulta manualmente al pulsar «Leer bandas».
- Guarda cada lectura en /var/mobile/Library/Logs/BandLock/.
- Mantiene /var/mobile/Library/Logs/BandLock/BandLock-last.txt para copiarlo por SSH.
- Incluye botón «Eliminar todos los registros» con confirmación.
- El borrado está limitado a la carpeta de registros de BandLock.
- No llama a setBandInfo:, setActiveBandInfo: ni otros setters del módem.
