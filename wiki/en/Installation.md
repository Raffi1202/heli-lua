🇬🇧 [English](../en/Installation.md) · 🇩🇪 [Deutsch](../de/Installation.md)

# Installation

**You need:** a FrSky radio with Ethos (26.1 or later) and a colour screen, a computer with the FrSky Suite and the USB cable, and a heli with telemetry via the FrSky receiver (Rotorflight, FrSky sensors via FBUS/S.Port or a telemetry ESC). Discover the sensors in the model first (Model › Telemetry › Discover new sensors).

## With the FrSky Suite
1. Unpack `Heli-RF-1.12.0-zum-Teilen.zip`. It contains the manuals, `LIES MICH.txt` and the package `Heli-RF-1.12.0.zip`. **Do not unpack the package.**
2. Switch on the radio, connect it via USB and choose **Ethos Suite** on the radio.
3. In the Suite: **Lua library › Install from local ZIP**, select `Heli-RF-1.12.0.zip`, click **Install scripts**.
4. Disconnect the radio and restart it.

The radio must be connected before you click «Install scripts». Do not delete an old `helirf` folder first: it holds the flight list.

## By hand
Unpack `Heli-RF-1.12.0.zip`, connect the radio as a USB drive and copy the folder `helirf` (with its subfolder `audio`) into the radio's `scripts` folder. Overwrite an existing folder, do not delete it. On radios with an SD card, copy to where the other Lua scripts are; if in doubt `SD:/scripts/helirf`. On the X18RS with Ethos 26.2.0 only the SD card loaded.

## Putting it on a screen
Screens › **+** › layout **Full screen** (or one field with bars for the compact view) › tap the field › Widget › **Heli RF**.

---
[← Home](../Home.md) | Previous | [Next →](Setup.md)
