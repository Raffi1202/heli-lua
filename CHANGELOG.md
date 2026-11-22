# Versionen von Heli RF

Die Versionsnummer steht in `src/helirf/main.lua` (`local VERSION`). Sie ist dieselbe in der Anleitung, im Paket für
die Suite und hier. Der oberste Abschnitt erscheint in der FrSky Suite als Versionshinweis. Die Stände vor 1.5.0
sind nicht einzeln im Repo, nur hier beschrieben. Alle Versionen bis 1.6.0 stammen vom 17.11.2026.

*Older entries (1.12.0 and before) in German.*

## 1.14.4 (22.11.2026)

- Symbols as large as the text: titles keep the normal size; the symbol in the box header uses the largest mask (12/16/24 px from Lua-Studio 0.10.6) not higher than the title, centred on the title line (shared reference studio_symbole.lua, as Electric 0.7.5). New menu line «Show symbols» (default on), stored in the model's data file.

## 1.14.3 (22.11.2026)

- «Unit already in the title» now only counts the unit as a word of its own (before it: start, space or opening bracket; after it: end, space, closing bracket or %), so «A» in «Akku» no longer hides the unit.

## 1.14.2 (22.11.2026)

- Box header (from radio test): no large bold unit any more – «bold» is shown like «unit at value» (small); if the title already contains the unit (e.g. «Battery %»), the unit is left out; next to a symbol the title is as high as the symbol (at most a third of the box). Same rule as Electric 0.7.3.

## 1.14.1 (22.11.2026)

- Studio notes («view adapted», «file faulty», «no matching view») now appear in the widget's own header (instead of the model name, compact: instead of profile/rate) and no longer cover the bottom row of values. Fix: after returning to a window size with an exact view, «adapted» is reset. Info file: `hinweis` now also carries the «view adapted» text. Remaining system names removed from code comments and test names (`test/governor_makro.lua`). New Mac test: commands for scaled views (640x360, 480x320, 630x258, 472x210).

## 1.14.0 (22.11.2026)

- The Studio layout is always found: the widget searches `SCRIPTS:/studio/`, `SD:/scripts/studio/` and `RADIO:/scripts/studio/`; if the file name does not match the model, choose the file in the widget menu under «Studio layout» (the choice wins over the model name). If no view matches the window size exactly, the view with the most similar aspect ratio is scaled to fit (5 s note «Studio: view 800x480 adapted»); decoration is left out in a scaled view, places that get too small become a number or are left out. A broken file or a missing view shows a note line at the bottom. New info-file fields studioQuelle, studioWahl, ansichtGenutzt, angepasst, hinweis. Storage format 7 (battery type shares a slot), settings from 1.5.0–1.13.1 are kept.

## 1.13.1 (21.11.2026)

- Governor field without governor telemetry now shows «no governor» / «kein Governor» (was a system name).
- Docs: Heli is described as a widget for any heli with telemetry (any flybarless system, ESC with telemetry or FrSky
  sensors); no system names any more. Manuals (PDF) and packages `Heli-1.13.1.zip` / `Heli-1.13.1-share.zip` rebuilt.
  No other functional change.

## 1.13.0 (21.11.2026)

- **Renamed from «Heli RF» (`helirf`) to «Heli» (`heli`) – breaking: old models must re-add the widget; Studio files must be renamed or re-transferred.** Widget key and folder on the radio `heli`, Studio files `<ID>.heli.lua`, `.heli.funke.lua`, `.heli.info.json`, `"lua": "heli"` in `beschreibung.json` and the info file.
- Transition: if `<ID>.heli.lua` is missing but an old `<ID>.helirf.lua` exists, Heli reads it and logs «old studio file found, please re-transfer». Flight data (`daten/<model>.txt`) are read from `scripts/helirf/daten/` if `scripts/heli/daten/` has none (read only); the next save writes them to the new folder. Settings stored in the widget are kept when only the widget key in the model is switched from `helirf` to `heli`; `test/update_test.py` checks reading the settings of every version from 1.5.0 to 1.12.0.
- Packages `Heli-1.13.0.zip` and `Heli-1.13.0-share.zip`. Docs, wiki and simulator pictures renamed. No other functional change from 1.12.0.

## 1.12.0 (21.11.2026)

Im Mac-Prüfstand und im Simulator (X18RS, Ethos 26.2.0) geprüft, **am Sender noch nicht geprüft**.
- **«Auch bei Motor aus» je Alarm** (Wunsch des Users, Lua-Studio-Format 2 §3.5): Im Menü hat jede Alarmgruppe den
  Haken «Auch bei Motor aus», ab Werk ein. Ohne Haken schweigt der Alarm (Ton, Vibration, Ansage), solange der
  Motorschalter auf «Stellung Motor aus» steht; die Anzeige wird trotzdem orange bzw. rot. Ohne Motorschalter gilt der
  Haken nicht. «Drehzahl verloren» kommt immer.
- **Studio-Datei:** Je Grenze `beiMotorAus = true/false` (fehlt oder ungültig: `true`, ungültig mit Hinweis). Gilt auch
  für die weiteren Grenzen (Sensoren, Kanäle). Eine Änderung im Menü schreibt `beiMotorAus` in `.funke.lua`, `true` hebt
  ein `false` der Studio-Datei auf. `beschreibung.json` und Info-Datei melden `"beiMotorAus": true`.
- **Speicherformat 6:** Die Einstellung braucht keinen eigenen Platz im Widget-Speicher (dort passen nur rund 51 Werte),
  sie steckt im Platz von «Stellung Motor aus». Weiter 50 Werte. Alle Einstellungen ab 1.5.0 werden übernommen, der
  Haken steht danach überall auf ein. Eine ältere Version liest Format 6 nicht und nimmt Werkswerte.
- **Speicher freigeben beim Modellwechsel:** Der Kern hielt das zuletzt gezeichnete Widget fest, darum blieb nach einem
  Wechsel auf ein Modell ohne Heli RF fast der ganze Speicher belegt. Jetzt lässt der Kern das Widget nach jedem Bild los,
  und ist kein Heli-RF-Widget mehr da, gibt `main.lua` den Kern frei (Finalizer der Widget-Tabelle, Ethos 26.2 kennt kein
  `close`). Im Simulator bleiben danach 4 KB ohne Studio-Datei (vorher 158 KB) und 5 KB mit voller Format-2-Datei und
  20 Symbolen (vorher 317 KB Lua-Speicher und 72 KB Bildspeicher). Test `test/speicher_sim.py`.
- **Korrektur (schon vor 1.12.0):** Ein Grenz-Eintrag der Studio-Datei ohne Stufen (ohne `warnung`, `alarm`, `aus`,
  z. B. nur `ansage = false` oder nur `beiMotorAus = false`) schaltete den überwachten Alarm ganz aus. Jetzt gilt dafür
  die Werkgrenze, nur `ansage`, `vibration` und `beiMotorAus` wirken. Dasselbe gilt für `warnung = false` zusammen mit
  `alarm = false` ohne `aus`: Ganz still wird ein Alarm nur mit `aus = true` (Entscheid des Users 20.11.2026).
- Tests: `test/update_test.py` verglich die Versionen als Text und liess v1.10.x und v1.11.0 aus; jetzt alle ab v1.5.0,
  mit Speicher-Grenze 51 wie Ethos.

## 1.11.0 (21.11.2026)

Lua-Studio-Format 2. Im Mac-Prüfstand und im Simulator (X18RS, Ethos 26.2.0) geprüft, **am Sender noch nicht geprüft**.
Ohne Studio-Datei und mit Format-1-Dateien zeichnet und rechnet Heli RF wie 1.10.1.
- **Format 2:** Heli RF liest Studio-Dateien mit `format = 1` oder `2`. Neu bei Format 2: Symbole im Platz (`symbol`,
  `symbolPx`), fette Einheit oben links (`einheitZeigen = "fett"`, `false` = keine Einheit) und Schmuck je Ansicht
  (`deko`: Symbol, Text, Linie, Rahmen). Prüfen, Laden und Zeichnen übernimmt die Referenz `studio_symbole.lua`
  wörtlich. Sie wird nur bei einer Format-2-Datei geladen. Die Symbole sind Graustufen-Masken aus
  `SCRIPTS:/studio/symbole/<name>_<px>.png`, die nur das Studio schreibt. Fehlt eine Datei oder ist sie kaputt, gibt es
  kein Symbol und unten den Hinweis «Studio: n Symbole fehlen». Symbole und Schmuck ändern keine Grenze, keine Ansage
  und keinen Alarm.
- **Feldprüfung in Stücken zu höchstens 8 Einträgen** (vorher 15), jetzt auch für Einstellungen und das Zusammenführen
  der Einstellungen. `werte`, `grenzen` und `einstellungen` gelten bis 48 Einträge, ab dem 49. verworfen mit Hinweis.
  **Abweichung von §7.1:** Das Anwenden bleibt ein Aufruf. Es läuft über die festen internen Listen des Luas (nicht
  über die Einträge der Datei), seine Grösse hängt also nicht von der Datei ab; gemessen höchstens 2 504 Befehle im
  ganzen `wakeup`.
- **Kanäle der Studio-Datei:** ausser der Kategorie «keine» wird jetzt auch geprüft, ob der Wert vorhanden ist.
- Ansagen und Alarme: Ein Alarm spielt weiterhin immer den Ton, auch bei `ansage = false`, `vibration = false`
  und bei Motorschalter «aus». Ganz still bleibt ein Wert nur mit `aus = true`. Eine fehlende WAV blockiert nichts.
  Gegenüber 1.10.1 unverändert.
- `studio/beschreibung.json`: `formate: [1, 2]`, Vorlagen «Heutiges Aussehen» und «Mit Symbolen» für 800 × 480 und
  784 × 316 (Vorschlag von Lua-Studio).
- **Befehle (Mac-Zählung):** Eine Format-2-Datei mit voller Belegung (16 Plätze mit 64-px-Symbol und fetter
  Einheit, 24 Schmuck-Elemente) braucht rund 6 400 Befehle je `paint`. Davon entfallen rund 2 400 auf die Referenz
  und rund 3 700 auf die Plätze wie bei 1.10.1. Das eingebaute Bild braucht 6 400 bis 7 500 Befehle. Am X18RS lief Elektro mit rund 13 000 Befehlen je `paint` ohne Abbruch.
  Format 2 §9 verlangte zuerst unter 5 000 auch je `paint`; entschieden 21.11.2026: so belassen. Seit
  21.11.2026 setzt §9 für `paint` das Ziel unter 10 000 (Heli liegt darin), `wakeup` weiter unter 5 000.
  Pflichttest 12 mit `test/format2/p12_voll.helirf.lua` (Heli-Fassung unter der Kopfzeile): 6 407 Befehle bei
  800 × 480, 5 796 bei 784 × 316 (Mac-Zählung). Begründung: Am X18RS laufen nachweislich mehr Befehle je `paint` ohne
  Abbruch (Elektro 0.4.0 rund 13 000, Heli ohne Studio-Datei seit 1.9 6 400–7 500). Bestanden gilt der Test, wenn
  `p12_voll` mit Symbolen am Sender im Vollbild (wenn möglich auch kompakt) ohne «Max instructions» läuft.
- **Sensorsuche:** Der Start der automatischen Suche läuft jetzt über zwei Aufrufe (erst die Kennungstabelle, dann
  der Index). Vorher kamen in einem Aufruf bis rund 4 800 Befehle zusammen, jetzt höchstens rund 3 800.
- Tests: Testdateien `gross_werte` und `gross_grenzen` auf 48 Einträge (Listengrenze), neue Datei `ueber48`.

## 1.10.1 (20.11.2026)

Korrekturen am Studio-Teil nach dem Sendertest von Elektro 0.3.2 (dieselben Schwächen). Am Sender noch nicht geprüft.
- **Sensoren der Studio-Datei und Info-Datei:** Am Sender (X18RS, Ethos 26.2.0) liefert `system.getSources` mit
  einer Tabelle als Filter eine leere Liste, und `system.getSource` über die AppID ein Objekt ohne Wert. Heli RF holt
  die Sensorliste jetzt mit der Kategorie als Zahl (wie die Sensorsuche) und sucht Studio-Sensoren darin über AppID,
  Teilwert und Physical ID, in Stücken über mehrere Aufrufe. Vorher hätten Studio-Plätze mit Sensoren am Sender «---»
  gezeigt, Sensor-Grenzen nie ausgelöst und die Info-Datei keine Sensoren enthalten. Kanäle wie bisher.
- **Governor-Rückfall:** Eigene Sensoren mit den AppIDs 0x5125/0x5122 sucht Heli RF ebenfalls in der Sensorliste
  (alle 30 s, solange nicht beide gefunden sind; vorher alle 5 s). Der Hauptweg über die S.Port-Rahmen bleibt unverändert.
- **Befehlsgrenze:** Grosse gültige Studio-Dateien brauchten bis 24 726 Befehle in einem Aufruf (160 Sensor-Grenzen;
  100 Wert-Anpassungen 14 452), im Betrieb 16 795 je Aufruf. Werte, Grenzen und Zusammenführen laufen jetzt in Stücken
  (höchstens rund 2 600 Befehle je Aufruf). Im Betrieb prüft Heli RF die Grenzen für Sensoren und Kanäle im Ring, je
  Aufruf 10; Grenzen, die gerade warnen, alarmieren oder entprellen, zusätzlich in jedem Aufruf (höchstens 6), mit
  derselben Entprellung (1 s) wie bisher (höchstens rund 2 800 Befehle). Bis 10 Grenzen ändert sich nichts; bei 160
  Grenzen kommt ein neuer Alarm nach rund 2 s (gemessen; mit 20 gleichzeitig aktiven Grenzen 2,2 s), statt nach 1 s.
- **Alarm nie ganz stumm (Entscheid des Users):** geprüft, war schon so: Bei `ansage = false` und/oder
  `vibration = false` kommt beim Alarm immer der Ton, auch bei Motorschalter «aus»; ganz still nur mit `aus = true`.
  Stille Einträge gibt es darum nicht, sie können keine Ansagen blockieren. Ohne Studio-Datei wie 1.10.0.
- Tests: `test/studio_test.lua` Teil 6 (Sender-Eigenheiten nachgestellt, Befehle im Betrieb, Alarm-Ton),
  neue Testdateien `gross_werte` und `gross_grenzen` (Generator und Simulator-Test).

## 1.10.0 (20.11.2026)

- Neu: Lua-Studio-Format v1. Liegt auf der Funke `SCRIPTS:/studio/<Kennung>.helirf.lua`, liest Heli RF sie beim
  Modellwechsel in Schritten (Referenz-Ladefunktion, Erlaubtliste, Feldprüfung) und übernimmt Einstellungen,
  Grenzen, Wert-Anpassungen und eigene Ansichten (Vollbild 800 × 480 bzw. Kompaktansicht, je 16 Plätze in sechs
  Darstellungsarten, höchstens 2 Kurven). Fehlt in den Grenzen ein Eintrag, gilt die Werkgrenze (Zelle nach Akkutyp);
  nur `aus = true` schaltet einen Alarm ab. Sensoren und Kanäle der Studio-Datei können eigene Grenzen haben (Ton
  und Vibration).
- Neu: Änderungen im Widget-Menü gehen mit Studio-Datei nach `.funke.lua` (die Studio-Datei bleibt unverändert,
  der Widget-Speicher auch). Menüzeile «Studio-Datei» mit Zustand und «Zurück auf Studio-Stand» bzw. ohne Datei
  «Zurück auf Standard». Kaputte oder zu neue Datei: Standard und Hinweis unten (8 s), danach «!» oben rechts.
- Neu: Info-Datei `<Kennung>.helirf.info.json` (Sensorliste, Fenstergrössen, Modellpfad) für Lua-Studio.
- `studio/beschreibung.json` beschreibt Werte, Einstellungen, Standard-Ansichten und Werkgrenzen für das Studio.
- Ohne Studio-Datei arbeitet Heli RF wie 1.9.1. Speicherformat unverändert (5).

## 1.9.1 (20.11.2026)

- Behoben: Governor und SCHARF/SICHER blieben am Sender leer (X18RS: per Lua angelegte DIY-Sensoren bekamen keine
  Werte, im Simulator schon). Heli RF liest die Governor-Rahmen 0x5125 und 0x5122 jetzt direkt aus der Telemetrie
  (`sport.getSensor` mit `popFrame`), unabhängig von der Physical ID. Es muss kein Sensor
  mehr angelegt werden; der Menüknopf «Governor + Scharf › Anlegen» fällt weg. Von Hand angelegte
  Sensoren mit diesen AppIDs gelten weiter, wenn keine Rahmen kommen. Simulator 26.2: `test/governor_makro.lua`.
- Am Sender (X18RS, 1.9.0) geprüft: Kompaktansicht mit Livewerten, keine «Max instructions».

## 1.9.0 (20.11.2026)

- Neu: Kompaktansicht für das Ethos-Layout mit Kopf- und Fussleiste (784 × 316, 630 × 258, 472 × 210). Das Widget
  erkennt sie am Seitenverhältnis (Höhe unter halber Breite). Oben eine schmale Leiste mit Flugzeit, SCHARF/SICHER,
  Profil/Rate und Empfang, darunter vier Tachos und acht Felder (Governor, Zelle, Verbraucht, BEC, Flugmodus,
  Empfang, Leistung, Flüge). Statt «nur im Vollbild» steht nur noch in sehr kleinen Feldern «Feld zu klein».
- Neu: Feld **Governor** an der Stelle des Heli-Bilds: Zustand des Governors im Flybarless-System (AppID 0x5125, Zustände 0–9
  nach Firmware des Flybarless-Systems) mit Pille SCHARF/SICHER (Arming-Flags 0x5122, Bit 0; ohne diese Werte folgt die Pille
  dem Motorschalter). Bei «Drehzahl verloren» (Fallback) roter Rahmen, Ton, Vibration und die neue Ansage
  `drehzahl_verloren` (höchstens alle 10 s; ein kurzer Telemetrie-Ausfall löst sie nicht erneut aus).
- Neu im Menü (Sensoren): Knopf «Governor + Scharf › Anlegen» legt die beiden Sensoren an, die Ethos
  nicht selbst anlegt (nur auf Knopfdruck, keine doppelten). Im Simulator 26.2 geprüft: eingespeiste Werte kommen an,
  unabhängig von der Physical ID (`test/governor_makro.lua`).
- Heli-Bild (heli.png, heli_m.png, heli_k.png) entfernt: kein Bildspeicher mehr nötig.
- Speicherformat unverändert (5): alle Einstellungen bleiben (Update-Test ab 1.5.0 bestanden).

## 1.8.1 (20.11.2026)

- Behoben: Die Sensorsuche brach am Sender (X18RS, Ethos 26.2) mit «Max instructions count reached» ab und ordnete
  nichts zu (jeder Sensor wurde mit allen 141 Einträgen der Kennung verglichen). Jetzt wird `kennung.lua` einmal nach
  Bereich (16 AppIDs) in einen Index umgebaut, und die Suche läuft verteilt über mehrere Aufrufe: höchstens 10
  Sensoren je Weckruf, auch der Namens-Rückfall. Gemessen auf dem Mac (100 Sensoren): höchstens rund 3 500
  Lua-Befehle je Aufruf. Nach «Suchen» im Menü erscheint das Fenster «Suche läuft …», bis die Suche fertig ist.
- In einem zu kleinen Feld (unter 400 × 250, z. B. Zone im Layout 2×2) zeigt das Widget nur «nur im Vollbild» /
  «full screen only» statt eines abgeschnittenen Bildes.
- Für Tester freigegeben (20.11.2026): am echten Sender getestet (X18RS, Ethos 26.2.0, 48 Sensoren), die Sensorsuche
  ordnet 8 Felder zu, Livewerte stimmen, keine «Max instructions». Dazu im Repo: `TESTLEITFADEN.md`, englische
  Anleitung `docs/Heli RF - Manual.pdf`, README deutsch und englisch, Vorlagen für Fehlermeldungen und Wünsche,
  GitHub-Release mit ZIP.

## 1.8.0 (20.11.2026)

- Automatische Sensorsuche nach den gemeinsamen «Vorgaben Sensorzuordnung»: FrSky-Sensoren werden an AppID und
  Teilwert erkannt (gemeinsame Tabelle `kennung.lua`), nicht mehr am Namen. Je Feld gilt eine feste Rangfolge, z. B.
  Akkuspannung ESC → Spannung (0x0210) → RB-35 Bat1 → Bat1 → RB → RB-25 → D-Hub; BEC: BEC-Spannung → Empf.-Batt. →
  RB-Ausgang; Reglertemperatur: ESC Temp. vor Temp. 1; Drehzahl: «Headspeed» → Drehzahl (0x0500) → ESC U/min.
- Abweichende Belegung bei Flybarless-Systemen beachtet: 0x0900 (Spannung der Steuerplatine) nie als Akku, 0x0910 (Ø-Zelle) als Zellenspannung,
  0x0222/0x0229 (BEC-Strom) nie als Akkustrom, 0x0600 als Akku-%. Ein 0x0600-Wert über 100 (Betaflight/INAV: mAh)
  gilt nicht als Akku-%.
- Mehrere passende Sensoren (Instanzen oder gleiche AppID auf mehreren Physical IDs): Wahl nach gültigem Wert, dann
  tiefster Instanz, dann Standard-Physical-ID; im Menü steht «n Sensoren passen, gewählt: … – bitte prüfen».
- Im Menü steht neben jedem Sensorfeld AppID und Physical ID (z. B. «[0B50/0A]»).
- Sensoren ohne Kennung (eigene Sensoren 0x5xxx, berechnete Sensoren, ELRS/CRSF): wie bisher über Name und Einheit.
  Per Lua angelegte Sensoren ohne Teilwert werden bei gepackten AppIDs über die Einheit zugeordnet.
- Speicher: Die Suche (`suche.lua`, `kennung.lua`) wird nur während der Suche geladen und danach freigegeben.
  Speicherformat unverändert (5): gespeicherte Zuordnungen und Einstellungen bleiben.
- Neuer Test `test/suche_test.lua` (feste Fälle), Simulator-Makro `test/suche_makro.lua`.

## 1.7.3 (19.11.2026)

- Nur Gesamtspannung, kein Zellensensor und Zellenzahl auf «automatisch» (0): Die Kachel «Zelle» zeigt jetzt gut
  sichtbar in Orange «ZELLEN? im Menü» (englisch «SET CELLS in menu»). Bisher stand dort nur «--», und der
  Zellenalarm blieb still. Geschätzt wird die Zellenzahl bewusst nicht; mit eingestellter Zellenzahl gilt wie
  bisher Gesamtspannung ÷ Zellenzahl, samt Alarm.

## 1.7.2 (19.11.2026)

- Nach einem Neuladen der Skripte ruft Ethos die Widgets teils ohne Widget-Objekt auf. Heli RF meldete dann laufend
  «attempt to index a nil value (local 'w')», bis der Lua-Speicher voll war (gemessen an einer X18RS). Jetzt prüfen
  alle Aufrufe (wakeup, paint, event, Menü, Lesen, Schreiben) zuerst, ob das Widget-Objekt da ist, und tun sonst nichts.

## 1.7.1 (19.11.2026)

- Zellen-Alarm folgt dem Akkutyp: Beim Wechsel des Akkutyps gelten die Werkswerte des neuen Typs (LiPo und LiHV
  3,60 / 3,50 V, Li-Ion 3,10 / 3,00 V), solange die Schwellen noch auf dem Werkswert stehen. Selbst eingestellte
  Schwellen bleiben. Ein Modell, das mit 1.7.0 schon auf Li-Ion stand und noch die LiPo-Werkswerte hat, bekommt beim
  Laden die Li-Ion-Werte. Der Werkswert im Zahlenfeld (Zurücksetzen) folgt ebenfalls dem Akkutyp.
- Neuer Update-Test (`python3 test/update_test.py`): Jede getaggte Version ab 1.5.0 schreibt Einstellungen, die
  aktuelle liest sie; alles wird übernommen.
- Abnahmetest-Befund «leere Vollbildseite nach PAGE und Zurückwischen» geklärt: kein Fehler im Widget. Im Testmodell
  lag vor der Heli-RF-Seite ein leerer Bildschirm (3×3 ohne Widgets); dorthin führte das Zurückwischen.

## 1.7.0 (19.11.2026)

- Neue Einstellung **Akkutyp** (LiPo, LiHV, Li-Ion) unter Akku: Die %-Schätzung aus der Ruhespannung nimmt die passende
  Kennlinie (LiHV voll bei 4,35 V, Li-Ion flacher bis 3,0 V). Ab Werk LiPo wie bisher.
- Menüzeile «Akku % kommt von»: zeigt laufend, ob ein Akku-%-Sensor (z. B. vom Flybarless oder Regler) gilt, ob er
  zugewiesen ist, aber keinen Wert liefert, oder ob die eigene Schätzung gilt. Ein %-Sensor geht immer vor; geschätzt wird nur ohne ihn.
- Speicherformat 5: Das seit 1.4.1 unbenutzte Feld «Akku-Profil» belegt keinen Platz mehr, dafür der Akkutyp (weiter 50
  Werte). Einstellungen aus allen früheren Formaten werden übernommen.

## 1.6.2 (19.11.2026)

- Zellenspannung: Ist ein Zellensensor (FLVSS, in Ethos «LiPo») zugewiesen, gilt die tiefste Zelle. Vorher kam die
  Summe seiner Zellen (z. B. 15,94 V statt 3,98 V), und Zellenanzeige und Zellenalarm stimmten nicht. Ein anderer
  Sensor über 5 V gilt als Gesamtspannung und wird durch die eingestellte Zellenzahl geteilt.
- Automatische Sensorsuche: «LiPo» (FLVSS) wird als Zellenspannung erkannt (nicht mehr als Akkuspannung),
  «Kraftstoff» (deutscher Ethos-Name des Fuel-Sensors, bei Flybarless-Systemen oft die Restladung) als Akku %.
  Befund aus dem Telemetrie-Simulator (Ethos 26.2.0).
- Anleitung: Hinweis zur Reglertemperatur, die Ethos bei 100 °C begrenzt.

## 1.6.1 (18.11.2026)

- Drehrad: Rechtsdrehen auf der Anzeige öffnet die Flugliste, dort wählt Drehen den Flug (rechts = nach unten, links = nach
  oben, die Liste rollt mit); links über den obersten Flug hinaus geht es zurück zur Anzeige. Vorher blieb das Bild
  beim Drehen scheinbar stehen.
- Wischen zwischen Anzeige und Flugliste: Die Seite wechselt schon während des Wischens; ein Loslassen ohne
  Fingerposition bleibt nicht mehr hängen.
- Suite-Paket: Dateiliste mit Ordner (`helirf/*`, `helirf/audio/**`). Mit 1.6.0 meldete die Suite «Ein
  Wildcard-Selektor in "files" hat keine Datei gefunden».
- Anleitung: Drehrad, Hinweise zur Installation (Sender verbunden, alten Ordner nicht löschen).

## 1.6.0 (17.11.2026)

- Paket für die FrSky Suite: Installation über «Lua-Bibliothek › Von lokaler ZIP installieren».
- Sender ohne Berührung (X14, X10, X12): Menügruppe «Flüge ohne Berührung» (Seite umschalten, Flug wählen, Flug
  löschen, laufenden Flug beenden, Rückfrage «Flug beendet?» als Pause schliessen, Liste löschen), alle Knöpfe mit
  Rückfrage; auch «Verbrauch zurücksetzen» fragt nach. «Flug wählen» 0 = oberste Zeile; eine Nummer, die es nicht
  gibt, löscht nichts.
- Zu langer Text wird mit Punkt gekürzt (z. B. Flugmodus auf kleinen Displays).
- Anleitung nach den festen Kapiteln (1 Was du brauchst … 11 Welche Sender); Bildersatz vollständig.
- Aufteilung für 640 × 360 und 480 × 272 geprüft, eigenes Heli-Bild für 640 × 360, Felder zum Antippen mindestens
  32 Punkte hoch, Rückfrage auf kleinen Displays breiter.
- Anleitung: Installieren über die Suite, Bedienung ohne Berührung, Abschnitt «Welche Sender».
- Projekt an den festen Aufbau angeglichen (Ordner wie das Repo `heli-lua`, `docs/bilder-simulator`,
  `docs/anleitung`, `docs/konzept`, `dist/`).

## 1.5.2
- Wird der laufende Flug ohne Motorschalter gelöscht, beginnt erst nach dem Stillstand des Rotors ein neuer.
- Anleitung: Hinweise zum Löschen des pausierten und des laufenden Flugs, zur Sprache nach dem Aktualisieren und
  zu den Bildschirmgrössen (X18RS-Simulator 800 × 480; 480 × 320 nachgestellt), sauberere Seitenumbrüche.

## 1.5.1
- Beim Übernehmen älterer Einstellungen gilt als Sprache «wie der Sender» (früher war Englisch der Werkswert, das Menü
  blieb darum nach dem Aktualisieren englisch).
- Anleitung: Bild der Gruppe «Flug und Motorschalter» mit den Werten ab Werk, im Abschnitt 8.

## 1.5.0
- Einzelne Flüge löschen: Flug antippen, «FLUG n LÖSCHEN», Rückfrage. Der Flugzähler geht um eins zurück, spätere
  Nummern rücken nach. Auch der laufende oder pausierte Flug ist löschbar.

## 1.4.1
- Anzeige des Akku-Profils («P3») entfernt; der Platz im Speicher bleibt reserviert.

## 1.4.0
- Zwei Schwellen je Überwachung: grün, orange (nur Anzeige), rot (Umrandung, Ton, Vibration, Ansage).
- Tachos mit 270° statt Vollkreisen; darunter MAX = höchster gemessener Wert mit diesem Akku.
- Sichtbarer Knopf zum Zurücksetzen des Verbrauchs.
- Ansage «Autorotation» nach Motor aus per Schalter, wiederholt, bis der Rotor steht.
- Alles deutsch und englisch (Anzeige, Rückfragen, Menü), Einstellung «wie der Sender».
- Sprachdateien deutsch und englisch für die fünf Alarme und «Autorotation»; der Alarm nennt zuerst das Wort, dann den Wert.
- Offener (pausierter) Flug übersteht das Ausschalten des Senders; Flugliste lässt sich rollen; Zeile «Pause»
  antippen fragt nochmals.
- Speicherformat 4 (50 Werte); ältere Formate werden übernommen, Orange wird aus der roten Schwelle abgeleitet.

## 1.3.0
- Seite 2 «Flüge»: Liste der letzten 20 Flüge, Werte des angetippten Flugs, Liste löschen.
- Flug-Erkennung per Motorschalter mit Rückfrage «Flug beendet?» und Pause; Stellung «Motor aus» einstellbar.
- Rückfragen zeichnet das Widget selbst.
- Alarme: der am längsten nicht gemeldete kommt zuerst; die Drehzahlansage hat Vorrang.

## 1.2.0
- Vier weitere Alarme mit einstellbarer Schwelle: Akku %, Zellenspannung, BEC-Spannung, Verbrauch.
- Schneller Akkuwechsel wird erkannt (Sensor zählt wieder ab 0).

## 1.1.0
- Verbrauch zurücksetzen (Antippen mit Rückfrage, Knopf im Menü, «Flug zurücksetzen» von Ethos).
- Akku % mit Startwert aus der Ruhespannung statt immer 100 %.

## 1.0.0
- Erste Fassung: Vollbild-Anzeige, Warnung Reglertemperatur ab 80 °C, Drehzahlansage bei Gas −25 %,
  Flugzähler, automatische Sensorsuche (Flybarless-Sensoren und übliche FrSky-Namen), Anpassung an 480 × 320.
