# Nuke Wireless — Wi-Fi Tools for iOS 16

**Nuke Wireless** es una app para **Dopamine RootHide** que muestra los dispositivos de la red Wi-Fi y permite bloquearlos o desbloquearlos mediante ARP.

## Español

### Funciones

- Lista de dispositivos conectados con dirección IP, MAC y nombre disponible.
- Asignación de alias locales por dirección MAC.
- Actualización de la lista mediante gesto de deslizar.
- Bloqueo y desbloqueo individual.
- Acción para bloquear varios equipos, con confirmación.
- Selector de idioma: Español, English, Français, Deutsch, 简体中文, 繁體中文 y 日本語.
- Interfaz visible con la marca **Nuke Wireless**, incluido el encabezado Wi-Fi rediseñado.
- Tarjeta Wi-Fi con el texto **Nuke Wireless /NETWORK KILLER** y sin el rótulo heredado superpuesto.
- Aviso cuando la interfaz Wi-Fi tiene IPv6; el bloqueo ARP solo cubre IPv4.
- Pestaña Info propia, sin el fondo heredado de Harpy RH, con SSID, BSSID, IPv4, máscara, router, MAC, IPv6 y DNS de la conexión actual.
- La pestaña Info explica de forma clara cómo funciona el bloqueo mediante ARP spoofing, cómo se restaura la asociación al desbloquear y por qué el mecanismo afecta principalmente a IPv4.
- Créditos **Gokuencinar · GokuEn** y avatar en la pestaña Info.

El bloqueo ARP no es desautenticación Wi-Fi. Úsalo únicamente en redes y con dispositivos que administras.

### Compatibilidad

- iOS 16.x
- Dopamine 2 RootHide
- iPhone arm64e
- Sileo
- Paquete: `com.gokuencinar.nukewireless`

## English

**Nuke Wireless** is a **Dopamine RootHide** app that lists devices on the connected Wi-Fi network and lets you block or unblock them with ARP.

### Features

- Connected-device list with IP address, MAC address and available device name.
- Local aliases saved by MAC address.
- Pull to refresh the device list.
- Individual block and unblock controls.
- Bulk blocking with a confirmation step.
- Language selector: Español, English, Français, Deutsch, 简体中文, 繁體中文 and 日本語.
- Visible UI branded as **Nuke Wireless**, including the redesigned Wi-Fi header.
- Wi-Fi card labeled **Nuke Wireless /NETWORK KILLER**, with the legacy title hidden to avoid overlap.
- IPv6 warning; ARP blocking covers IPv4 only.
- Custom Info tab without the legacy Harpy RH background, showing SSID, BSSID, IPv4, subnet mask, router, MAC, IPv6 and DNS for the current connection.
- The Info tab clearly explains how ARP spoofing blocking works, how normal ARP information is restored when unblocking, and why this mechanism primarily affects IPv4.
- Info tab credits **Gokuencinar · GokuEn** with the author’s avatar.

ARP blocking is not Wi-Fi deauthentication. Use it only on networks and devices you administer.

### Compatibility

- iOS 16.x
- Dopamine 2 RootHide
- arm64e iPhone
- Sileo
- Package: `com.gokuencinar.nukewireless`

## Install / Instalación

Add this Sileo source / Añade esta fuente a Sileo:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Install **Nuke Wireless** from the package list after the repository update is published.
