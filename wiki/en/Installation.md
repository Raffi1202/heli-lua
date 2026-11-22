🇬🇧 [English](../en/Installation.md) · 🇩🇪 [Deutsch](../de/Installation.md)

# Installation

**You need:** a FrSky radio with Ethos (26.1 or later) and a colour screen, a computer with the FrSky Suite and the USB cable, and a heli with telemetry via the FrSky receiver (any flybarless system or ESC with telemetry, or FrSky sensors via S.Port/FBUS). Discover the sensors in the model first (Model › Telemetry › Discover new sensors).

## With the FrSky Suite
1. Unpack `Heli-1.16.0-share.zip`. It contains the manuals, `LIES MICH.txt` and the package `Heli-1.16.0.zip`. **Do not unpack the package.**
2. Switch on the radio, connect it via USB and choose **Ethos Suite** on the radio.
3. In the Suite: **Lua library › Install from local ZIP**, select `Heli-1.16.0.zip`, click **Install scripts**.
4. Disconnect the radio and restart it.

The radio must be connected before you click «Install scripts». Do not delete an old `heli` folder first: it holds the flight list.

## By hand
Unpack `Heli-1.16.0.zip`, connect the radio as a USB drive and copy the folder `heli` (with its subfolder `audio`) into the radio's `scripts` folder. Overwrite an existing folder, do not delete it. On radios with an SD card, copy to where the other Lua scripts are; if in doubt `SD:/scripts/heli`. On the X18RS with Ethos 26.2.0 only the SD card loaded.

## Putting it on a screen
Screens › **+** › layout **Full screen** (or one field with bars for the compact view) › tap the field › Widget › **Heli**.


## Upgrading from Heli RF

**Renamed from «Heli RF» (`helirf`) – breaking:** old models must re-add the widget (its settings start from the factory values); Studio files must be renamed to `<ID>.heli.lua` or re-transferred with Lua-Studio. An old `<ID>.helirf.lua` is still read once, with the log note «old studio file found, please re-transfer». Flight count and flight list are taken over automatically from `scripts/helirf/daten/` (read only, never deleted), so keep the old folder until each model has been used once. If the widget key in the model file is switched from `helirf` to `heli` instead of re-adding the widget, all settings are kept as well.

1. Install Heli 1.16.0 (folder `scripts/heli`).
2. In every model: replace the widget «Heli RF» with **Heli** on the screen, then set up the sensors and settings again ([Setup](Setup.md)).
3. Studio file: re-transfer it with Lua-Studio (or rename `<ID>.helirf.lua` to `<ID>.heli.lua`).
4. When every model has been used once with Heli, the old folder `scripts/helirf` can be deleted.

---
[← Home](../Home.md) | Previous | [Next →](Setup.md)
