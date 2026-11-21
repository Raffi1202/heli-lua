# Heli – Anzeige für Helis (FrSky Ethos)

🇬🇧 [English](README.md) · Dokumentation: [Wiki (Deutsch)](wiki/de/Installation.md) · [Wiki (English)](wiki/en/Installation.md)

> **Am PC einrichten mit [Lua-Studio](https://github.com/Raffi1202/lua-studio)**: Bildschirm einteilen, Werte, Alarme und Symbole wählen, auf die Funke übertragen.

Lua-Widget für FrSky-Sender mit Ethos (ab 26.1) und Farbdisplay, für alle Helis mit Telemetrie (z. B. Rotorflight,
FrSky-Sensoren oder ein Regler mit Telemetrie). Es zeigt die Telemetrie im Vollbild oder kompakt mit den Ethos-Leisten, den Rotorflight-Governor mit SCHARF/SICHER, überwacht fünf Werte in zwei
Stufen, sagt Drehzahl und «Autorotation» an und führt eine Flugliste. Anzeige, Menü und Ansagen deutsch und englisch.

**Neu in 1.13.0:** **Umbenannt von «Heli RF» (`helirf`), nicht rückwärtskompatibel:** In vorhandenen Modellen das Widget neu auswählen (die Einstellungen beginnen mit den Werkswerten); Studio-Dateien in `<Kennung>.heli.lua` umbenennen oder mit Lua-Studio neu übertragen. Eine alte `<Kennung>.helirf.lua` wird noch gelesen, mit dem Hinweis «old studio file found, please re-transfer» im Log. Flugzähler und Flugliste übernimmt Heli automatisch aus `scripts/helirf/daten/` (nur lesen, nie löschen); den alten Ordner darum stehen lassen, bis jedes Modell einmal benutzt wurde. Wird im Modell nur der Widget-Schlüssel von `helirf` auf `heli` umgestellt statt das Widget neu zu wählen, bleiben auch alle Einstellungen.

**Neu in 1.12.0:** Je Alarm die Einstellung **«Auch bei Motor aus»** (ab Werk ein, auch in Lua-Studio wählbar): Ohne
Haken schweigt der Alarm, solange der Motorschalter auf «aus» steht; die Anzeige bleibt orange/rot. Nach einem
Modellwechsel gibt Heli seinen Lua-Speicher fast ganz frei (im Simulator bleiben 4–5 KB statt bis 317 KB).
Am Sender noch nicht geprüft.

**Neu in 1.11.0:** Lua-Studio-Format 2. Studio-Dateien können jetzt Symbole in den Kästchen, eine fette Einheit und
Schmuck (Symbole, Texte, Linien, Rahmen) bringen; Lua-Studio bietet dazu die Vorlagen «Heutiges Aussehen» und «Mit
Symbolen». Format-1-Dateien gelten weiter. **Ohne Studio-Datei läuft alles wie in 1.10.1.** Am Sender noch nicht
geprüft (nur Mac-Prüfstand und Simulator).

**Neu in 1.10.0:** Lua-Studio-Format v1. Mit dem PC-Programm Lua-Studio gestaltest du die Anzeige je Modell frei
(bis 16 Kästchen je Ansicht mit Zahl, Ring, Balken, Verlauf oder Status), passt Werte an und setzt Einstellungen und
Grenzwerte. Dafür liegt je Modell eine Studio-Datei auf dem Sender. **Ohne diese Datei läuft alles wie in 1.9.1.**

**Version 1.13.0** · Vorabversion (public beta) · Lizenz GPL-3.0

![Heli auf 800 × 480](docs/bilder-simulator/Heli%20-%20Sim%20800x480%2004%20Normal.png)

## Schnellstart in 5 Schritten

1. Unter **Releases** (rechts auf der Repo-Seite) die Datei `Heli-1.13.0-share.zip` herunterladen und
   entpacken. Das Paket `Heli-1.13.0.zip` darin **nicht** entpacken.
2. Sender einschalten, per USB anschliessen, am Sender **Ethos Suite** wählen, die FrSky Suite öffnen.
3. Suite › **Lua-Bibliothek** › **Von lokaler ZIP installieren** › `Heli-1.13.0.zip` › **Skripte installieren**.
   Danach Sender trennen und neu starten.
4. Am Sender: Bildschirme › **+** › Layout **Vollbild** › ins Feld tippen › Widget **Heli**.
5. Heli einschalten, im Widget-Menü in der Zeile «Sensoren automatisch suchen» auf **Suchen** tippen, die Zuordnung kontrollieren und unter
   **Akku** Zellen, Kapazität und Akkutyp einstellen.

Alles Weitere: **Anleitung** [`docs/Heli - Anleitung.pdf`](docs/Heli%20-%20Anleitung.pdf) (englisch:
[`docs/Heli - Manual.pdf`](docs/Heli%20-%20Manual.pdf)). Zum Testen: **[TESTLEITFADEN.md](TESTLEITFADEN.md)**.
Fehler und Wünsche: **Issues › New issue** (Vorlagen «Fehler / Bug» und «Wunsch / Idee»).

## Sender und Stand der Erprobung

| Display | Sender | Stand |
|---|---|---|
| 800 × 480, Berührung | X20, X20S, X20HD, X20 Pro, X20R, X20RS, X18R, X18RS | **X18RS am Sender getestet** (Ethos 26.2.0), übrige im Simulator |
| 640 × 360, ohne Berührung | Twin X14, X14S | im Simulator nachgestellt |
| 480 × 320, Berührung | X18, X18S, X18SE, Twin X Lite, Twin X Lite S | im Simulator nachgestellt |
| 480 × 272, ohne Berührung | X10, X10S, X10 Express, X12S (mit Ethos) | im Simulator nachgestellt |

Ein Paket für alle Sender: Das Widget misst die Fenstergrösse selbst. Ohne Berührung geht alles mit dem Drehrad und
über das Menü des Widgets (Gruppe «Flüge ohne Berührung»).

## Bekannte Grenzen (ehrlich)

- Am echten Sender getestet (mit 1.8.1, 20.11.2026, X18RS, Ethos 26.2.0, Archer Plus SR10+, Telemetrie aus einem Testgerät mit
  48 Sensoren): Installation, automatische Sensorsuche (8 Felder zugewiesen), Anzeige mit Livewerten, keine
  Lua-Fehler. Die Installation über die FrSky Suite hat auch am 18.11.2026 an einem echten Sender geklappt.
- **Nicht** am echten Sender geprüft: jeder Menüpunkt einzeln, die Ansagen, die Flugliste mit echten Flügen, die
  Bedienung mit dem Drehrad, alle anderen Sender. **Im Flug noch nicht erprobt.** Zuerst am Boden ausprobieren.
- Neu in 1.9.0 und nur im Simulator getestet: Kompaktansicht (Layout mit Leisten), Feld Governor mit SCHARF/SICHER,
  Ansage «Drehzahl verloren». Am Sender geprüft: Kompaktansicht (X18RS); Governor und SCHARF/SICHER noch nicht.
- **Neu in 1.10.0 und nur im Simulator getestet (Ethos 26.2):** die Studio-Datei aus Lua-Studio samt `.funke.lua`
  und Info-Datei. Der Sendertest folgt. Ohne Studio-Datei arbeitet Heli wie 1.9.1 (Speicherformat 5,
  Einstellungen bleiben); neu sind dann nur die Menüzeile «Studio-Datei: keine» und die Info-Datei im Ordner
  `scripts/studio`.
- **Neu in 1.12.0 und am Sender noch nicht geprüft:** «Auch bei Motor aus» und Speicher freigeben beim Modellwechsel.
- **1.11.0:** Lua-Studio-Format 2 (Symbole, fette Einheit, Schmuck). Am Sender (X18RS, 21.11.2026) mit voller Datei im
  Vollbild ohne Abbruch; Kompaktansicht, `.funke.lua` und Englisch dort noch offen. Ohne Studio-Datei und mit Format-1-Dateien
  zeichnet und rechnet Heli wie 1.10.1.
- Befehle je Aufruf: Lua-Studio-Format 2 §9 setzt seit 21.11.2026 für `paint` das Ziel unter 10 000 Befehle (vorher 5 000; `wakeup` weiter unter 5 000). Am Mac gezählt braucht eine volle Format-2-Datei (16 Plätze mit
  64-px-Symbol und fetter Einheit, 24 Schmuck-Elemente) rund 6 400 Befehle je Bild, die eingebaute Anzeige 6 400 bis
  7 500, also innerhalb des Ziels. Zum Vergleich: Am X18RS lief Elektro mit rund 13 000 Befehlen je Bild ohne
  Abbruch.
- Layout **Vollbild** oder ein Feld mit Kopf- und Fussleiste; in kleineren Zonen steht «Feld zu klein».
- Speicher: rund 90 KB Lua-Speicher (gemessen mit 1.8.1). Mit sehr vielen anderen Lua-Widgets kann der
  Lua-Speicher knapp werden.
- Mit SD-Karte lädt Ethos die Skripte von dort, wo es am Sender eingestellt ist (X18RS mit 26.2.0: nur `SD:/scripts`).
  Die Suite installiert an den richtigen Ort; von Hand im Zweifel nach `SD:/scripts/heli` kopieren.
- Die Alarme sind eine Hilfe und ersetzen nicht die eigene Kontrolle von Akku und Temperatur.

## Was es kann

- **Anzeige (Seite 1):** vier Tachos (Akku %, Drehzahl, Strom, Reglertemperatur; Bogen 270°, unten offen), darunter
  MAX = höchster gemessener Wert mit diesem Akku. Feld Governor (Rotorflight) mit SCHARF/SICHER und Flugzähler. Kompaktansicht im Layout mit Leisten. Flugmodus (aus Ethos), BEC-Spannung,
  Zellenspannung (je mit TIEF = tiefster Wert), verbrauchte mAh mit Knopf zum Zurücksetzen.
- **Überwachung in zwei Stufen** für Reglertemperatur, Akku %, Zellenspannung, BEC-Spannung, Verbrauch:
  gut = grün, erste Schwelle = orange (nur Anzeige), zweite Schwelle = rot mit Umrandung, Warnton, Vibration und
  Ansage («Reglertemperatur, 85 Grad Celsius»). Je Überwachung Ein/Aus, zwei Schwellen, Wiederholzeit.
- **Drehzahlansage** bei Gas auf −25 % oder tiefer, **Ansage «Autorotation»** nach Motor aus per Schalter, bis der
  Rotor steht.
- **Akku in %:** eigener Sensor, sonst Startwert aus der Ruhespannung (Kennlinie für LiPo, LiHV oder Li-Ion) und Herunterzählen mit den mAh.
- **Flüge (Seite 2):** Liste der letzten 20 Flüge, Werte des gewählten Flugs, einzelne Flüge oder die ganze Liste
  löschen. Flug-Erkennung per Motorschalter (mit Rückfrage «Flug beendet?» und Pause) oder nach Drehzahl.
- **Sprache:** Deutsch oder Englisch, ab Werk wie der Sender.
- **Lua-Studio (neu in 1.10.0):** Liegt auf dem Sender die Datei `scripts/studio/<Kennung>.heli.lua` (Kennung =
  Modellname, nur A–Z, a–z und 0–9, alles andere wird `_`), liest Heli sie beim Laden des Modells. Sie bringt eigene
  Ansichten (Vollbild bzw. Kompaktansicht, je Ansicht genau eine Fenstergrösse, bis 16 Plätze, höchstens 2 Kurven),
  Wert-Anpassungen (Faktor, Versatz, Einheit, Stellen, Name), Einstellungen und Grenzwerte, auch für weitere Sensoren
  und Kanäle (Ton und Vibration, ohne Ansage). Fehlt ein Grenzwert in der Datei, gilt die Werkgrenze. Änderungen im
  Widget-Menü schreibt Heli dann in `….heli.funke.lua`; die Studio-Datei bleibt unverändert. Menüzeile
  «Studio-Datei» mit Zustand und **Zurück** («Zurück auf Studio-Stand», ohne Datei «Zurück auf Standard»). Eine kaputte
  oder zu neue Datei ergibt die eingebaute Anzeige und einen Hinweis. Für Lua-Studio schreibt Heli zusätzlich
  `….heli.info.json` (Sensorliste, Fenstergrössen).
- **Lua-Studio-Format 2 (neu in 1.11.0):** Plätze mit Symbol (`symbol`, `symbolPx`) und fetter Einheit oben links,
  dazu je Ansicht bis 24 Schmuck-Elemente (Symbol, Text, Linie, Rahmen). Die Symbole sind Graustufen-Masken
  `scripts/studio/symbole/<name>_<px>.png`, die nur Lua-Studio schreibt; höchstens 20 Symbole je Datei. Fehlt eine
  Symboldatei oder ist sie kaputt, bleibt der Platz ohne Symbol und unten steht «Studio: n Symbole fehlen». `werte`,
  `grenzen` und `einstellungen` gelten bis je 48 Einträge, weitere werden mit Hinweis verworfen. Symbole und Schmuck
  ändern keine Grenze, keine Ansage und keinen Alarm. Format-1-Dateien gelten weiter.

## Wo liegt was

| Inhalt | Ort |
|---|---|
| Anleitung (PDF deutsch / englisch) | `docs/Heli - Anleitung.pdf`, `docs/Heli - Manual.pdf` |
| Testfälle für Tester | `TESTLEITFADEN.md` |
| Skript, 1:1 so wie es auf den Sender kommt | `src/heli/` |
| Versionen | `CHANGELOG.md` |
| Vorlagen für Fehlermeldungen und Wünsche | `.github/ISSUE_TEMPLATE/` |
| Bilder aus dem Ethos-Simulator | `docs/bilder-simulator/` |
| Quellen der Anleitungen (HTML) | `docs/anleitung/` |
| Texte aller Sprachansagen | `docs/Sprachansagen.md` |
| Beschreibung für Lua-Studio (Werte, Einstellungen, Standard-Ansichten, Werkgrenzen) | `studio/beschreibung.json` |
| Studio-Testdateien (gültig, kaputt, zu neu, Grenzen-Fälle) | `test/studio/` |
| Testdateien Lua-Studio-Format 2 (Symbole, Schmuck, volle Datei) | `test/format2/` |
| Zeichnung des Heli-Bilds (Entwurf) | `docs/konzept/` |
| Anforderungen und Entscheide | `docs/entwicklung/` |
| Tests (das Testmodell liegt ausserhalb des Repos) | `test/` |
| Demo-Makro für den Simulator der FrSky Suite | `tools/suite-demo/` |
| Pakete (entstehen mit `paket.py`, nicht im Repo, sondern im Release) | `dist/` |

## Entwickeln (für Mitarbeit am Code)

Die Hilfswerkzeuge `dokument.py` (Anleitung als PDF), `paket.py` (Pakete) und der Simulator-Treiber gehören nicht zum Repo;
ihr Ordner wird mit der Umgebungsvariablen `ETHOS_LUA_WERKZEUGE` angegeben. Die Simulator-Tests brauchen das
ethos-tools-Plugin (`run_wasm.js`, Umgebungsvariable `ETHOS_PLUGIN`). Kurz:

- **Dateien des Skripts:** `main.lua` (Anmeldung, Fehlerfang, `NAME`, `VERSION`, `INFO`), `kern.lua` (Werte, Alarme,
  Ansagen, Flug-Erfassung, Seite 1, Rückfragen, Menü), `fluege.lua` (Seite 2, nur geladen, solange sie offen ist),
  `suche.lua` und `kennung.lua` (Sensorsuche, nur während der Suche geladen; `kennung.lua` ist bei allen Luas gleich),
  `studio.lua` (Studio-Datei laden und prüfen, `.funke.lua` und Info-Datei schreiben; nur dafür geladen),
  `studiolauf.lua` (Betrieb mit Studio-Datei, nur geladen, solange eine gilt), `ansicht.lua` (zeichnet die Plätze einer
  Studio-Ansicht), `studio_symbole.lua` (Referenz Lua-Studio-Format 2, Symbole und Schmuck, nur bei einer
  Format-2-Datei geladen), `audio/de`, `audio/en`.
- **Syntax:** `luac -p src/heli/*.lua` (Lua 5.4).
- **Studio-Testdateien:** `python3 test/studio_dateien.py` erzeugt `test/studio/` neu und prüft jede Datei mit der
  Referenz-Ladefunktion (Lua-Studio-Format v1).
- **Sensorsuche:** `lua test/suche_test.lua` (Lua 5.4, feste Fälle (a)–(g) der Vorgaben Sensorzuordnung, Rotorflight); im
  Simulator 26.2 das Makro `test/suche_makro.lua` (Schritt `makro` in `simulator.cjs`), Ausgabe «TEST …» im Log.
- **Zufallstest:** `python3 test/zufallstest.py` (800 × 480) und `python3 test/zufallstest.py klein` (640 × 360,
  480 × 320, 480 × 272 und Mini-Feld), mit `abbild` zusammen mit allen Skripten des Senders. Muss «BESTANDEN» melden.
- **Simulatorbilder:** `python3 test/bilder.py [Nummer …]` erzeugt den Satz in `docs/bilder-simulator/`.
- **Anleitung:** `python3 "$ETHOS_LUA_WERKZEUGE/dokument.py" anleitung .` und jede Seite ansehen.
- **ZIP:** `python3 "$ETHOS_LUA_WERKZEUGE/paket.py" .` baut `dist/` (Suite-Paket und ZIP zum Teilen),
  `--pruefen` sagt, ob `dist/` aktuell ist. Nach jeder Änderung an Skript, Ansagen oder Anleitung neu bauen.
- **Version:** `local VERSION` in `src/heli/main.lua`; Anleitung und CHANGELOG tragen dieselbe Nummer, je Version
  ein Git-Tag `vX.Y.Z`.
- **Sprachdateien:** Texte in `docs/Sprachansagen.md`.

Abweichungen vom Bauplan: keine `felder.lua`/`texte.lua`/`menue.lua` (alles in `kern.lua`), kein Konzeptblatt,
eigener Zufallstest im Simulator statt `zufallstest.lua`, Simulatorbilder über `test/bilder.py` statt Abläufen als
JSON. Die Einstellungen liegen im Widget-Speicher von Ethos, der nach Reihenfolge arbeitet: Format 6 = Kennung,
13 Quellen, 35 Zahlen, Endkennung = **50 Werte bei einer Grenze von rund 51** («Auch bei Motor aus» steckt im Platz
von «Stellung Motor aus»). Neues nur ans Ende; für weitere
Einstellungen müssen die Zahlen in die Datei unter `daten/` wandern. Die Formate 1 bis 5 werden weiter gelesen
(`test/update_test.py` prüft das Update von jeder Version ab 1.5.0).
Speicher (Simulator, mit 44 weiteren Skripten): rund 90 KB Lua-Speicher (1.8.1), seit 1.9.0 kein Bild mehr.

## Lizenz

GPL-3.0, siehe [LICENSE](LICENSE).

## Weitere Projekte

| Projekt | Wozu |
|---|---|
| [Elektro](https://github.com/Raffi1202/elektro-lua) | Ethos-Widget für Elektromodelle |
| [Jet](https://github.com/Raffi1202/jet-lua) | Ethos-Widget für Turbinen (mehrere ECU-Hersteller) |
| [Segler](https://github.com/Raffi1202/segler-lua) | Ethos-Widget für Segler (Vario, Thermik) |
| [Motoren ECU / Vergaser](https://github.com/Raffi1202/motoren-lua) | Ethos-Widgets für Verbrennungsmotoren |
| [Lua-Studio](https://github.com/Raffi1202/lua-studio) | PC-Programm zum Einrichten der Widgets (Mac/Windows) |
