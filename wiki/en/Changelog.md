🇬🇧 [English](../en/Changelog.md) · 🇩🇪 [Deutsch](../de/Versionen.md)

# Changelog

Full details: [CHANGELOG.md](../../CHANGELOG.md) (German).

| Version | Main changes |
|---|---|
| 1.14.2 | Box header (from radio test): no large bold unit any more – «bold» is shown like «unit at value» (small); if the title already contains the unit (e.g. «Battery %»), the unit is left out; next to a symbol the title is as high as the symbol (at most a third of the box). Same rule as Electric 0.7.3. |
| 1.14.1 | Studio notes («view adapted», «file faulty», «no matching view») now appear in the widget's own header (instead of the model name, compact: instead of profile/rate) and no longer cover the bottom row of values. Fix: after returning to a window size with an exact view, «adapted» is reset. Info file: `hinweis` now also carries the «view adapted» text. Remaining system names removed from code comments and test names (`test/governor_makro.lua`). New Mac test: commands for scaled views (640x360, 480x320, 630x258, 472x210). |
| 1.14.0 | The Studio layout is always found: the widget searches `SCRIPTS:/studio/`, `SD:/scripts/studio/` and `RADIO:/scripts/studio/`; if the file name does not match the model, choose the file in the widget menu under «Studio layout» (the choice wins over the model name). If no view matches the window size exactly, the view with the most similar aspect ratio is scaled to fit (5 s note «Studio: view 800x480 adapted»); decoration is left out in a scaled view, places that get too small become a number or are left out. A broken file or a missing view shows a note line at the bottom. New info-file fields studioQuelle, studioWahl, ansichtGenutzt, angepasst, hinweis. Storage format 7 (battery type shares a slot), settings from 1.5.0–1.13.1 are kept. |
| 1.13.1 | Governor field shows «no governor» without governor telemetry; docs for any heli with telemetry. |
| 1.13.0 | Renamed from «Heli RF» to «Heli» (key and folder `heli`, Studio file `<ID>.heli.lua`) – breaking, see [Upgrading](Installation.md#upgrading-from-heli-rf). |
| 1.12.0 | «Also with motor off» per alarm (menu and Lua-Studio), memory freed after a model change, a Studio entry without thresholds no longer switches an alarm off. Pre-release. |
| 1.11.0 | Lua-Studio format 2: symbols, bold unit, decoration. |
| 1.10.1 | Studio file sensors on the radio, large Studio files in parts. |
| 1.10.0 | Studio file from Lua-Studio. |
| 1.9.1 | Governor and arming flags read directly. |
| 1.9.0 | Compact view, Governor field with ARMED/SAFE. |

---
[← Home](../Home.md) | [Previous](Troubleshooting.md) | Next →
