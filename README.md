# Heli – helicopter display for FrSky Ethos

🇩🇪 [Deutsch](README.de.md) · Documentation: [Wiki (English)](wiki/en/Installation.md) · [Wiki (Deutsch)](wiki/de/Installation.md)

> **Configure on your PC with [Lua-Studio](https://github.com/Raffi1202/lua-studio)** – arrange the screen, choose values and alarms, then transfer to the radio. Download: [latest release](https://github.com/Raffi1202/lua-studio/releases/latest) · [Wiki](https://github.com/Raffi1202/lua-studio/tree/main/wiki)

**Heli** is a Lua widget (full screen, or compact with the Ethos header and footer) for FrSky radios with Ethos
(26.1 or newer) and a colour display, for **any helicopter with telemetry** (any flybarless system or ESC that sends
telemetry, or FrSky sensors). It shows battery %, head speed, current, ESC temperature, BEC, cell voltage and used capacity, watches five
values with two thresholds each (orange display, red with tone, vibration and voice), announces head speed and
«Autorotation», and keeps a flight list. Display, menu and voice alerts are in English or German.

**Version 1.16.0** · pre-release (public beta) · License GPL-3.0. Tested on a real radio only on the **X18RS**
(Ethos 26.2.0); all other radios only in the Ethos simulator. Not yet flown. The alarms are an aid and do not replace
your own checks.

## Quick start

1. Download `Heli-1.16.0-share.zip` from **Releases** and unzip it (but not the inner `Heli-1.16.0.zip`).
2. Connect the radio via USB (mode «Ethos Suite»), open the FrSky Suite.
3. Suite › **Lua library** › **Install from local ZIP** › `Heli-1.16.0.zip` › **Install scripts**. Restart the radio.
4. Add a screen with layout **Full screen** (or one field with bars for the compact view) and the widget **Heli**.
5. In the widget menu tap **Search** («Find sensors automatically»), check the sensors, set cells, capacity and battery type.

Manual: `docs/Heli - Manual.pdf` (German: `docs/Heli - Anleitung.pdf`). Test guide: `TESTLEITFADEN.md`
(German). Report bugs with the issue template «Fehler / Bug» (English is fine).

## What's new

- **1.16.0:** One layout for all models: `Standard.heli.lua` (same locations as before) applies to every model without its own file. Order: choice in the widget menu, then `<ID>.heli.lua` of the model, then `Standard.heli.lua`, then the built-in display. Menu entry «Default (all models)»; «automatic» shows in brackets what applies. Changes on the radio stay per model (`<ID>.heli.funke.lua`). Info file: studioWahl "standard". A model named «Standard» uses the file as its own model file.
- **1.15.1:** Clean-up after the final review: unused «symbols missing» note removed, shared reference studio_symbole.lua as in Electric 0.8.1 (83f4c74), docs: template «With symbols» only until 1.14.4. No functional change.
- **1.15.0:** Symbols removed completely (decision after the radio test): no symbol masks are loaded or drawn, the menu line «Show symbols» is gone; symbols in older Studio files and «symbole=» in data files are silently ignored. Decoration lines/frames/texts stay. Mac: p12_voll paint 5 994 → 4 463 commands, Lua memory with the file 657 → 617 KB.
- **1.14.4:** Symbols as large as the text: titles keep the normal size; the symbol in the box header uses the largest mask (12/16/24 px from Lua-Studio 0.10.6) not higher than the title, centred on the title line (shared reference studio_symbole.lua, as Electric 0.7.5). New menu line «Show symbols» (default on), stored in the model's data file.
- **1.14.3:** «Unit already in the title» now only counts the unit as a word of its own (before it: start, space or opening bracket; after it: end, space, closing bracket or %), so «A» in «Akku» no longer hides the unit.
- **1.14.2:** Box header (from radio test): no large bold unit any more – «bold» is shown like «unit at value» (small); if the title already contains the unit (e.g. «Battery %»), the unit is left out; next to a symbol the title is as high as the symbol (at most a third of the box). Same rule as Electric 0.7.3.
- **1.14.1:** Studio notes («view adapted», «file faulty», «no matching view») now appear in the widget's own header (instead of the model name, compact: instead of profile/rate) and no longer cover the bottom row of values. Fix: after returning to a window size with an exact view, «adapted» is reset. Info file: `hinweis` now also carries the «view adapted» text. Remaining system names removed from code comments and test names (`test/governor_makro.lua`). New Mac test: commands for scaled views (640x360, 480x320, 630x258, 472x210).
- **1.14.0:** The Studio layout is always found: the widget searches `SCRIPTS:/studio/`, `SD:/scripts/studio/` and `RADIO:/scripts/studio/`; if the file name does not match the model, choose the file in the widget menu under «Studio layout» (the choice wins over the model name). If no view matches the window size exactly, the view with the most similar aspect ratio is scaled to fit (5 s note «Studio: view 800x480 adapted»); decoration is left out in a scaled view, places that get too small become a number or are left out. A broken file or a missing view shows a note line at the bottom. New info-file fields studioQuelle, studioWahl, ansichtGenutzt, angepasst, hinweis. Storage format 7 (battery type shares a slot), settings from 1.5.0–1.13.1 are kept.
- **1.13.1:** Governor field without governor telemetry shows «no governor»; docs neutral for any heli with telemetry.
- **1.13.0:** **Renamed from «Heli RF» (`helirf`) – breaking:** old models must re-add the widget (its settings start from the factory values); Studio files must be renamed to `<ID>.heli.lua` or re-transferred with Lua-Studio. An old `<ID>.helirf.lua` is still read once, with the log note «old studio file found, please re-transfer». Flight count and flight list are taken over automatically from `scripts/helirf/daten/` (read only, never deleted), so keep the old folder until each model has been used once. If the widget key in the model file is switched from `helirf` to `heli` instead of re-adding the widget, all settings are kept as well.
- **1.12.0:** per alarm the setting «Also with motor off» (on by default, also in Lua-Studio): without the tick the
  alarm stays silent while the motor switch is «off»; the display still turns orange/red. After a model change Heli
  frees almost all of its Lua memory (simulator: 4–5 KB stay). A Studio limit without thresholds no longer switches an
  alarm off. Not yet tested on the radio.
- **1.11.0:** Lua-Studio format 2 – symbols in the boxes, bold unit, decoration. Ran on the X18RS with a full file.
- **1.10.0 / 1.10.1:** Studio file from Lua-Studio: own views per model, value adjustment, settings and limits.
- **1.9:** compact view, Governor state of the flybarless system with ARMED/SAFE, voice alert «headspeed lost».

Details: [CHANGELOG.md](CHANGELOG.md).

## Where is what

| Content | Location |
|---|---|
| Manual (PDF English / German) | `docs/Heli - Manual.pdf`, `docs/Heli - Anleitung.pdf` |
| Wiki (English / German) | `wiki/` |
| Script, exactly as it goes on the radio | `src/heli/` |
| Description for Lua-Studio | `studio/beschreibung.json` |
| Simulator screenshots | `docs/bilder-simulator/` |
| Sources of the manuals (HTML) | `docs/anleitung/` |
| Voice alert texts | `docs/Sprachansagen.md` |
| Tests and test files | `test/` |
| Requirements and decisions (German) | `docs/entwicklung/` |

## Development

Lua 5.4 syntax check: `luac -p src/heli/*.lua`. Mac tests: `lua test/studio_test.lua`, `lua test/format2_test.lua`,
`lua test/suche_test.lua`, `python3 test/update_test.py`. The simulator tests (`test/*_sim.py`, `test/zufallstest.py`,
`test/bilder.py`) need the ethos-tools plugin (`ETHOS_PLUGIN`) and the helper tools folder (`ETHOS_LUA_WERKZEUGE`);
the format test files come from the Lua-Studio format documentation (`FORMAT2_ORDNER`). Details (German) in
[README.de.md](README.de.md).

## License

GPL-3.0, see [LICENSE](LICENSE).

## Related projects

| Project | What it does |
|---|---|
| [Elektro](https://github.com/Raffi1202/elektro-lua) | Ethos widget for electric models |
| [Jet](https://github.com/Raffi1202/jet-lua) | Ethos widget for turbines (several ECU brands) |
| [Segler](https://github.com/Raffi1202/segler-lua) | Ethos widget for gliders (vario, thermals) |
| [Motoren ECU / Vergaser](https://github.com/Raffi1202/motoren-lua) | Ethos widgets for gas engines |
| [Lua-Studio](https://github.com/Raffi1202/lua-studio) | PC app to set up the widgets (Mac/Windows) |
