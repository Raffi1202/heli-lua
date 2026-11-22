🇬🇧 [English](../en/Lua-Studio.md) · 🇩🇪 [Deutsch](../de/Lua-Studio.md)

# Lua-Studio

With the PC program Lua-Studio you design the display per model and set settings and limits. It writes `scripts/studio/<ID>.heli.lua` (ID = model name, other characters than A–Z, a–z, 0–9 become `_`). Without this file Heli works as before; the menu shows «Studio file: none».

- **Views:** one per window size (e.g. 800 × 480, 784 × 316), at most two, up to 16 boxes each (number, ring, bar, trend, status), with title, range, colours, MIN/MAX/Ø. In full screen the view replaces page 1; the flight list stays.
- **Format 2 (1.11.0):** symbols in the boxes and bold unit (**removed from 1.15.0**: symbols are ignored, the unit is small at the value), decoration (symbols, texts, lines, frames, up to 24 per view). Symbols are greyscale PNGs in `scripts/studio/symbole/`, written only by Lua-Studio, at most 20 per file.
- **Value adjustment:** factor, offset, unit, decimals, name per value.
- **Limits:** apply per value. A missing entry means the factory limit; only an explicit `aus = true` switches an alarm off. Limits for further sensors and channels alert with tone and vibration, at most every 10 s.
- **Also with motor off (1.12.0):** per limit, yes by default, also for the further limits.
- **Changes on the radio** (menu) go to `<ID>.heli.funke.lua`; the Studio file stays unchanged. Menu › Studio file › Reset goes back to the Studio settings.
- **Notes:** a broken or too new file or invalid entries show a dark bar at the bottom for 8 s, then an orange «!». Heli always keeps running. Details in the log.
- Up to 48 entries each for value adjustments, limits and settings. Heli writes `<ID>.heli.info.json` (model, radio, sensors, window sizes) for Lua-Studio.

---
[← Home](../Home.md) | [Previous](Alarms.md) | [Next →](FAQ.md)


## Finding the layout (1.14.0)

The Studio layout is always found: the widget searches `SCRIPTS:/studio/`, `SD:/scripts/studio/` and `RADIO:/scripts/studio/`; if the file name does not match the model, choose the file in the widget menu under «Studio layout» (the choice wins over the model name). If no view matches the window size exactly, the view with the most similar aspect ratio is scaled to fit (5 s note in the widget's header, «Studio: view 800x480 adapted»); decoration is left out in a scaled view, places that get too small become a number or are left out. A broken file or a missing view shows a note line at the bottom. New info-file fields studioQuelle, studioWahl, ansichtGenutzt, angepasst, hinweis. Storage format 7 (battery type shares a slot), settings from 1.5.0–1.13.1 are kept.
