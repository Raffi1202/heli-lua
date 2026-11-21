# Heli RF – helicopter display for FrSky Ethos

🇩🇪 [Deutsch](README.de.md) · Documentation: [Wiki (English)](wiki/en/Installation.md) · [Wiki (Deutsch)](wiki/de/Installation.md)

> **Configure on your PC with [Lua-Studio](https://github.com/Raffi1202/lua-studio)** – arrange the screen, choose values, alarms and symbols, then transfer to the radio. Download: [latest release](https://github.com/Raffi1202/lua-studio/releases/latest) · [Wiki](https://github.com/Raffi1202/lua-studio/tree/main/wiki)

**Heli RF** is a Lua widget (full screen, or compact with the Ethos header and footer) for FrSky radios with Ethos
(26.1 or newer) and a colour display, for any helicopter with telemetry (Rotorflight, FrSky sensors or an ESC with
telemetry). It shows battery %, head speed, current, ESC temperature, BEC, cell voltage and used capacity, watches five
values with two thresholds each (orange display, red with tone, vibration and voice), announces head speed and
«Autorotation», and keeps a flight list. Display, menu and voice alerts are in English or German.

**Version 1.12.0** · pre-release (public beta) · License GPL-3.0. Tested on a real radio only on the **X18RS**
(Ethos 26.2.0); all other radios only in the Ethos simulator. Not yet flown. The alarms are an aid and do not replace
your own checks.

## Quick start

1. Download `Heli-RF-1.12.0-zum-Teilen.zip` from **Releases** and unzip it (but not the inner `Heli-RF-1.12.0.zip`).
2. Connect the radio via USB (mode «Ethos Suite»), open the FrSky Suite.
3. Suite › **Lua library** › **Install from local ZIP** › `Heli-RF-1.12.0.zip` › **Install scripts**. Restart the radio.
4. Add a screen with layout **Full screen** (or one field with bars for the compact view) and the widget **Heli RF**.
5. In the widget menu tap **Search** («Find sensors automatically»), check the sensors, set cells, capacity and battery type.

Manual: `docs/Heli RF - Manual.pdf` (German: `docs/Heli RF - Anleitung.pdf`). Test guide: `TESTLEITFADEN.md`
(German). Report bugs with the issue template «Fehler / Bug» (English is fine).

## What's new

- **1.12.0:** per alarm the setting «Also with motor off» (on by default, also in Lua-Studio): without the tick the
  alarm stays silent while the motor switch is «off»; the display still turns orange/red. After a model change Heli RF
  frees almost all of its Lua memory (simulator: 4–5 KB stay). A Studio limit without thresholds no longer switches an
  alarm off. Not yet tested on the radio.
- **1.11.0:** Lua-Studio format 2 – symbols in the boxes, bold unit, decoration. Ran on the X18RS with a full file.
- **1.10.0 / 1.10.1:** Studio file from Lua-Studio: own views per model, value adjustment, settings and limits.
- **1.9:** compact view, Rotorflight governor state with ARMED/SAFE, voice alert «headspeed lost».

Details: [CHANGELOG.md](CHANGELOG.md).

## Where is what

| Content | Location |
|---|---|
| Manual (PDF English / German) | `docs/Heli RF - Manual.pdf`, `docs/Heli RF - Anleitung.pdf` |
| Wiki (English / German) | `wiki/` |
| Script, exactly as it goes on the radio | `src/helirf/` |
| Description for Lua-Studio | `studio/beschreibung.json` |
| Simulator screenshots | `docs/bilder-simulator/` |
| Sources of the manuals (HTML) | `docs/anleitung/` |
| Voice alert texts | `docs/Sprachansagen.md` |
| Tests and test files | `test/` |
| Requirements and decisions (German) | `docs/entwicklung/` |

## Development

Lua 5.4 syntax check: `luac -p src/helirf/*.lua`. Mac tests: `lua test/studio_test.lua`, `lua test/format2_test.lua`,
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
| [Telemetry simulator](https://github.com/Raffi1202/telemetrie-simulator) | ESP32-S3 that simulates FrSky telemetry sensors |
| [Ethos model converter](https://github.com/Raffi1202/ethos-modell-konverter) | Move models between Ethos radios |
| [Ethos sensor IDs](https://github.com/Raffi1202/ethos-sensor-ids) | Which sensor Ethos creates for each AppID |
