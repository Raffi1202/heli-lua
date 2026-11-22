# Testleitfaden Heli 1.14.2

Danke, dass du Heli testest! Arbeite die Testfälle der Reihe nach durch und hake ab, was so klappt wie beschrieben.
Klappt etwas nicht, melde es (ganz unten steht, wie). Ein Testfall dauert meistens ein bis zwei Minuten.

*English testers: the widget, the menu, the voice alerts and the manual are also in English
(`docs/Heli - Manual.pdf`). Set the language in the widget menu (Display and flight count › Sprache / Language)
or leave it «as the radio». The test cases below follow the chapters of the manual. Report problems with the issue
template «Fehler / Bug»; English is fine.*

## Was du brauchst

- FrSky-Sender mit Ethos **26.1 oder neuer** und Farbdisplay. Am echten Sender getestet ist bisher nur die **X18RS**
  mit Ethos 26.2.0. Andere Sender laufen im Simulator; dein Test auf einem anderen Sender hilft besonders.
- Ein Heli mit Telemetrie über einen FrSky-Empfänger: jedes Flybarless-System mit Telemetrie, FrSky-Sensoren
  oder ein Regler mit Telemetrie. Mindestens Akkuspannung und Drehzahl; Strom, Verbrauch, Reglertemperatur,
  BEC-Spannung und Zellensensor sind willkommen, aber freiwillig.
- Am Modell: die Sensoren schon gesucht (Modell › Telemetrie › Sensoren suchen).
- Computer mit der FrSky Suite und das USB-Kabel des Senders.
- Die Datei `Heli-1.14.2-share.zip` aus dem GitHub-Release (Seite «Releases» rechts im Repo). Darin liegen das
  Paket `Heli-1.14.2.zip`, die Anleitung (deutsch und englisch) und eine Datei `LIES MICH.txt`.
- Die Anleitung `Heli - Anleitung.pdf`. Die Testfälle verweisen auf ihre Kapitel.
- Nur für Testfall 16 (Studio-Datei): die Testdateien aus diesem Repo, Ordner `test/studio/` (auf GitHub
  herunterladen), und den Sender als USB-Laufwerk (am Sender beim Anschliessen **USB-Laufwerk** bzw. «SD-Karte»
  wählen). Das PC-Programm Lua-Studio brauchst du dafür nicht. Für Teil h (Format 2) zusätzlich den Ordner
  `test/format2/` und den Ordner `symbole` mit den Test-Symbolen (Graustufen-PNG wie `akku_64.png`). Der Ordner
  `symbole` liegt nicht im Repo; du bekommst ihn vom Entwickler.

**Sicherheit:** Am Tisch immer **ohne Rotorblätter** oder mit abgestecktem Motor testen. Die Testfälle 7 und 8
brauchen einen drehenden Motor: nur ohne Blätter. Der Flugtest (Testfall 14) ist freiwillig und gehört auf den Flugplatz.

**Vorher sichern:** Erstelle in der FrSky Suite eine Sicherung deines Senders. Heli ändert am Modell nur seine
eigenen Widget-Einstellungen und legt sonst nur Dateien im Ordner `scripts/heli` an (Flugliste unter
`scripts/heli/daten/`). Seit 1.10.0 schreibt es dazu im Ordner `scripts/studio` die Info-Datei für Lua-Studio
(`<Kennung>.heli.info.json`) und, nur mit Studio-Datei, deine Menü-Änderungen (`<Kennung>.heli.funke.lua`).

## Testfälle

Notiere dir für die Meldung: Sender, Ethos-Version (System › Info) und welche Sensoren dein Heli hat.

### 1. Installieren (Anleitung Kapitel 2)
- [ ] Sender per USB anschliessen, am Sender **Ethos Suite** wählen. In der FrSky Suite: **Lua-Bibliothek** ›
  **Von lokaler ZIP installieren** › `Heli-1.14.2.zip` (nicht entpacken) › **Skripte installieren**. Sender neu starten.
- **Erwartet:** Die Suite meldet keinen Fehler, «Heli» steht in der Liste der installierten Skripte. Nach dem
  Neustart erscheint keine Fehlermeldung.

### 2. Bildschirm einrichten (Kapitel 3)
- [ ] Bildschirme › **+** › Layout **Vollbild** › ins Feld tippen › Widget **Heli**.
- **Erwartet:** Die Anzeige erscheint sofort: oben Modellname und Uhrzeit, darunter vier Tachos, unten links das Feld
  GOVERNOR mit dem Flugzähler und rechts vier Felder. Unten links steht **kein** roter Text.
- [ ] Einen zweiten Bildschirm mit dem Layout **mit einem Feld und Kopf- und Fussleiste** anlegen und dort Heli wählen.
- **Erwartet:** Kompaktansicht: oben die Ethos-Leiste, darunter eine schmale Leiste (Flugzeit, SCHARF/SICHER,
  Profil/Rate, Empfang), vier Tachos und acht Felder. Nichts abgeschnitten. Antippen von FLÜGE öffnet die Flugliste.
- [ ] Zum Vergleich Heli in eine kleine Zone legen (z. B. Layout 2×2) und wieder entfernen.
- **Erwartet:** In der kleinen Zone steht nur «Feld zu klein», kein abgeschnittenes Bild.

### 3. Ohne Telemetrie
- [ ] Heli aus.
- **Erwartet:** Überall «--», kein roter Text, keine Ansage.

### 4. Sensoren automatisch zuweisen (Kapitel 4)
- [ ] Heli einschalten, etwa 10 Sekunden warten. Widget-Menü öffnen (Bildschirme › Bildschirm wählen › ins Widget
  tippen) und oben in der Zeile «Sensoren automatisch suchen» auf **Suchen** tippen.
- **Erwartet:** Ein Fenster «Suche läuft …» erscheint und schliesst sich am Ende von selbst. Die erkannten Felder in
  der Gruppe **Sensoren** sind gefüllt. Kein roter Text, keine Meldung «Max instructions».
- [ ] Menü schliessen und wieder öffnen.
- **Erwartet:** Neben jedem Feld steht die Kennung in Klammern (z. B. «[0B50/0A]»). Passen mehrere Sensoren, steht
  «n Sensoren passen, gewählt: … – bitte prüfen».
- [ ] Jedes Feld kontrollieren: Steht bei **Akkuspannung** wirklich der Flugakku (nicht die Empfängerspannung)?
  Bei Flybarless-Systemen: nicht die Spannung der Steuerplatine?
- [ ] Ein Feld leeren und nochmals suchen.
- **Erwartet:** Nur das leere Feld wird neu gefüllt, deine anderen Felder bleiben.

### 4b. Nur wenn das Flybarless-System sie sendet: Governor und SCHARF/SICHER (Kapitel 4 und 5)
- [ ] Im Flybarless-System (Telemetrie) die Werte **Governor State** und **Arming Flags** einschalten.
- [ ] Heli scharf schalten (ohne Rotorblätter!), Motor hochlaufen lassen.
- **Erwartet:** Im Feld GOVERNOR erst HOCHLAUF (orange), dann AKTIV (grün); die Pille wechselt von SICHER auf SCHARF.

### 5. Anzeige mit Livewerten (Kapitel 5)
- [ ] Menü schliessen, Werte ansehen.
- **Erwartet:** Drehzahl, Strom, Reglertemperatur, BEC, Verbrauch und Akkuspannung stimmen mit Modell › Telemetrie
  überein. Oben rechts Profil/Rate (nur wenn das Flybarless-System sie sendet), Empfangsbalken (nur mit RSSI-Sensor).

### 6. Akku (Kapitel 4 und 7)
- [ ] Menü › **Akku**: Zellen, Kapazität und Akkutyp deines Akkus einstellen. Vollen Akku anstecken.
- **Erwartet:** Der Akku-Tacho zeigt nach etwa 2 Sekunden einen plausiblen Wert (voll geladen etwa 95–100 %),
  darunter Zellenzahl und Spannung. Das Feld ZELLE zeigt etwa 4,1–4,2 V bei LiPo. Die Zeile «Akku % kommt von» im
  Menü nennt die Quelle.
- [ ] Nur ohne Zellensensor: Zellen auf **0** stellen.
- **Erwartet:** Im Feld ZELLE steht orange «ZELLEN? im Menü». Danach Zellen wieder richtig einstellen.

### 7. Motorschalter und «Autorotation» (Kapitel 6 und 7) – ohne Rotorblätter!
- [ ] Menü › **Flug und Motorschalter**: deinen Motorschalter und seine Stellung «Motor aus» wählen.
- [ ] Motor ein, Rotorkopf drehen lassen, dann mit dem Motorschalter aus.
- **Erwartet:** Ansage «Autorotation», alle 3 Sekunden wiederholt, bis der Kopf steht. Die Drehzahl kommt dazwischen
  nur, wenn ein Gaskanal gewählt ist und das Gas auf −25 % oder tiefer steht (Testfall 8).

### 8. Drehzahlansage (Kapitel 6) – ohne Rotorblätter!
- [ ] Menü › **Drehzahlansage** › Gaskanal wählen. Kopf drehen lassen und Gas auf −25 % oder tiefer stellen.
- **Erwartet:** Jede Sekunde wird die Drehzahl angesagt, links neben dem Flugzähler leuchtet ein hellblauer Punkt.

### 9. Flug am Boden, Rückfrage (Kapitel 7)
- [ ] Motor ein, gut 30 Sekunden laufen lassen, dann Motor aus.
- **Erwartet:** Frage «Flug beendet?».
- [ ] **NEIN, NUR PAUSE**, Motor wieder ein, dann aus und **JA, BEENDET**.
- **Erwartet:** Der Flugzähler unten links steigt um 1. Ein Lauf unter 30 Sekunden zählt nicht.

### 10. Flugliste (Kapitel 7, «Die Flugliste»)
- [ ] Nach links wischen oder auf den Flugzähler tippen (ohne Berührung: Drehrad nach rechts).
- **Erwartet:** Seite «Flüge», der neueste Flug oben. Ein Flug antippen zeigt links seine Werte.
- [ ] Einen Flug löschen: antippen › **FLUG n LÖSCHEN** › bestätigen.
- **Erwartet:** Der Flug ist weg, die späteren Nummern rücken nach, der Flugzähler sinkt um 1. Abbrechen ändert nichts.
- [ ] Nach rechts wischen oder **ZURÜCK**.

### 11. Verbrauch auf 0 (Kapitel 7)
- [ ] Im Feld VERBRAUCHT auf **AUF 0** tippen und bestätigen.
- **Erwartet:** 0 mAh, MAX und TIEF beginnen neu.

### 12. Warnung, Alarm und Ansagen (Kapitel 6)
- [ ] Menü › **Alarm Reglertemperatur**: Orange knapp unter und Rot knapp über der aktuellen Temperatur einstellen
  (oder Alarm Akku % auf 95/90 %). Danach zurück auf die Werkswerte (70/80 °C bzw. 35/25 %).
- **Erwartet:** Über Orange wird der Tacho orange (kein Ton). Über Rot: Tacho und Rahmen rot, Kopfzeile blinkt, Ton,
  Vibration und Ansage «Reglertemperatur …», wiederholt im eingestellten Takt.

### 13. Neustart und Sprache
- [ ] Sender aus- und wieder einschalten.
- **Erwartet:** Einstellungen, Sensoren, Flugzähler und Flugliste sind noch da. Kein roter Text.
- [ ] Menü › **Anzeige und Flugzähler** › Sprache / Language auf **English**, Menü schliessen und wieder öffnen.
- **Erwartet:** Anzeige, Menü und Ansagen sind englisch. Danach wieder zurückstellen, wenn du willst.

### 14. Echter Flug (freiwillig, auf dem Flugplatz)
- [ ] Einen normalen Flug machen, danach landen und Motor aus, **JA, BEENDET**.
- **Erwartet:** Plausible Werte während des Flugs, keine falschen Alarme. Der Flug steht danach in der Liste mit
  Dauer, Verbrauch, Max-Drehzahl, Max-Strom usw.

### 15. Sender ohne Berührung (nur X14, X10, X12)
- [ ] Mit dem Drehrad zur Flugliste und zurück, einen Flug wählen. Im Menü › **Flüge ohne Berührung** einen Flug löschen.
- **Erwartet:** Alles geht ohne Berührung, jede Löschung fragt nach, «ABBRECHEN» ist vorgewählt.

### 16. Studio-Datei aus Lua-Studio (neu in 1.10.0, g neu in 1.10.1, h neu in 1.11.0, Anleitung Kapitel 8 «Studio-Datei aus Lua-Studio»)
Heli liest je Modell die Datei `scripts/studio/<Kennung>.heli.lua`, und zwar dort, wo der Sender die Skripte
lädt (mit SD-Karte meist `SD:/scripts/studio/`). **Kennung** = Modellname, jedes Zeichen ausser A–Z, a–z und 0–9
wird `_`, ein Umlaut ergibt `__` (aus «Logo 700» wird `Logo_700`). Die Datei wird beim **Laden des Modells** gelesen:
Nach jedem Kopieren ein anderes Modell laden und wieder zurück (oder den Sender neu starten). Nimm für diesen
Testfall ein Testmodell oder notiere dir vorher Akku- und Alarm-Einstellungen. Nach dem Test alle Dateien
`<Kennung>.heli.…` im Ordner `scripts/studio` löschen; dann gilt wieder alles wie vorher.

**a) Keine Studio-Datei**
- [ ] Modell ohne Studio-Datei laden, Widget-Menü öffnen.
- **Erwartet:** Unter «Sensoren automatisch suchen» steht die Zeile «Studio-Datei: keine» mit dem Knopf **Zurück**.
  Kein Hinweis unten, kein «!» oben rechts, Anzeige wie in 1.9.1. Im Ordner `scripts/studio` liegt nach dem Laden
  die Datei `<Kennung>.heli.info.json`.
- [ ] **Zurück** antippen.
- **Erwartet:** Frage «Zurück auf Standard?» («Einstellungen und Grenzwerte ab Werk; Sensoren und Flüge bleiben»).
  **ABBRECHEN** ändert nichts. Nur auf einem Testmodell: **JA, ZURÜCK** setzt Akku-, Alarm- und übrige Einstellungen
  auf die Werkswerte (Anleitung Kapitel 8); die Sensoren, der Flugzähler und die Flugliste bleiben.

**b) Gültige Studio-Datei**
- [ ] `test/studio/gueltig.heli.lua` nach `scripts/studio/<Kennung>.heli.lua` kopieren, Modell neu laden.
- **Erwartet:** Im Vollbild zeigt Seite 1 die Kästchen der Datei (Ringe, Zahlen usw.) statt der eingebauten
  Anzeige; die Kopfzeile oben bleibt. Wischen nach links bzw. Drehrad öffnet weiter die Flugliste. Im Layout mit
  Leisten (784 × 316) erscheint die zweite Ansicht der Datei; auf anderen Fenstergrössen die eingebaute Anzeige.
  Kein Hinweis unten. Menü: «Studio-Datei: geladen»; unter **Akku** stehen 12 S und 5000 mAh aus der Datei.

**c) Änderung an der Funke (`.funke.lua`)**
- [ ] Mit der gültigen Datei im Menü › **Akku** die Kapazität ändern (z. B. 4500 mAh), Menü schliessen, ein paar
  Sekunden warten, Modell neu laden.
- **Erwartet:** Die Kapazität bleibt 4500 mAh. In `scripts/studio` liegt neu `<Kennung>.heli.funke.lua`; die
  Studio-Datei `<Kennung>.heli.lua` ist unverändert (gleiche Grösse und gleiches Änderungsdatum wie kopiert).
- [ ] Menü › Zeile «Studio-Datei: geladen» › **Zurück**.
- **Erwartet:** Frage «Zurück auf Studio-Stand?» («Deine Änderungen an der Funke werden gelöscht»). Nach
  **JA, ZURÜCK** gilt wieder der Stand der Studio-Datei (5000 mAh), die Datei `….heli.funke.lua` ist weg.
- [ ] Freiwillig: Die `….heli.funke.lua` mit einem Texteditor öffnen, ein Wort hineinschreiben, speichern, Modell
  neu laden.
- **Erwartet:** Unten der Hinweis «Änderungen an der Funke verworfen», die Studio-Datei gilt weiter.

**d) Kaputte Studio-Datei**
- [ ] `test/studio/abgeschnitten.heli.lua` als `<Kennung>.heli.lua` kopieren (die alte ersetzen), Modell neu laden.
- **Erwartet:** Die eingebaute Anzeige (Standard). Unten steht etwa 8 Sekunden lang ein dunkles Band «Studio-Datei
  kaputt - Standard», danach oben rechts ein oranges «!». Menü: «Studio-Datei: kaputt». Kein roter Text, das Widget
  läuft normal weiter.

**e) Zu neue Studio-Datei**
- [ ] `test/studio/format99.heli.lua` als `<Kennung>.heli.lua` kopieren, Modell neu laden.
- **Erwartet:** Eingebaute Anzeige, Band «Studio-Datei zu neu - Lua aktualisieren», danach «!». Menü: «Studio-Datei:
  zu neu».

**f) Alarme ohne Grenzen-Eintrag und mit Motorschalter aus** – ohne Rotorblätter!
- [ ] `test/studio/grenzen_fehlt.heli.lua` als `<Kennung>.heli.lua` kopieren, Modell neu laden. Die Datei
  enthält nur einen Grenzwert für Akku %, keinen für Zellenspannung und Reglertemperatur.
- **Erwartet:** Menü › **Alarm Zellenspannung** und **Alarm Reglertemperatur** stehen auf «Ein» mit den Werkswerten
  (LiPo 3,60 / 3,50 V bzw. 70 / 80 °C). Ein fehlender Eintrag schaltet keinen Alarm ab.
- [ ] Nur ohne Zellensensor und mit einem Akku bis 8S: Menü › **Akku** › Zellen auf **14** stellen (die gerechnete
  Zellenspannung fällt so unter 3,50 V). Motorschalter in die Stellung **Motor aus** bringen.
- **Erwartet:** Nach etwa einer Sekunde Alarm Zellenspannung: Feld rot, Ton, Vibration und Ansage
  «Zellenspannung …», wiederholt alle 10 s, obwohl der Motorschalter auf «Motor aus» steht. Danach die Zellenzahl
  zurückstellen oder im Menü «Zurück auf Studio-Stand» wählen.
**g) Sensoren der Studio-Datei und Info-Datei (Korrektur in 1.10.1)** – mit Telemetrie (Heli oder Testgerät an)
- [ ] `scripts/studio/<Kennung>.heli.info.json` nach dem Laden des Modells mit einem Texteditor öffnen.
- **Erwartet:** Unter `"sensoren"` stehen die Telemetriesensoren des Modells (je `appId`, `sub`, `phys`, `name`),
  nicht `[]`.
- [ ] `test/studio/voll.heli.lua` als `<Kennung>.heli.lua` kopieren, Modell neu laden, Vollbild ansehen.
- **Erwartet:** Plätze mit Sensoren, die das Modell hat (z. B. RPM 0500, VFAS 0210, Strom 0200, Fuel 0600, RSSI
  F101), zeigen Livewerte, nicht «---». Nur Sensoren, die das Modell nicht hat, zeigen «---»; dazu je eine Zeile
  «… nicht gefunden» im Debug-Log. Der Platz mit Physical ID (`0B50` mit Phys. ID 3) zeigt nur dann einen Wert,
  wenn genau dieser Sensor da ist. Kein «Max instructions».
- [ ] Freiwillig, nur wenn ein Testgerät die Werte liefert: den Sensor Temp1 (0400) über 100 bringen.
- **Erwartet:** Ton und Ansage bzw. Ton für die Sensor-Grenze der Datei (Warnung 90, Alarm 100), auch bei
  Motorschalter «Motor aus».

**h) Lua-Studio-Format 2: Symbole, fette Einheit, Schmuck (neu in 1.11.0)**
- [ ] Den Ordner `symbole` nach `scripts/studio/symbole/` kopieren, in denselben Speicher wie die Studio-Datei (mit
  SD-Karte meist `SD:/scripts/studio/symbole/`). Danach liegen dort Dateien wie `akku_64.png`.
- [ ] `test/format2/p12_voll.heli.lua` als `<Kennung>.heli.lua` kopieren, Modell neu laden, Vollbild ansehen.
- **Erwartet:** 16 Plätze (alle mit Akku %). Jeder Platz hat oben links ein Symbol in der Farbe des Werts, der Titel
  rückt ein, die Einheit steht fett oben links und nicht mehr neben dem Wert. Dazu waagrechte Linien und eine Reihe
  Symbole am unteren Rand. Die Symbole dürfen nach dem Laden ein paar Bilder später erscheinen. Kein Hinweis
  «Studio: n Symbole fehlen», kein roter Text, kein «Max instructions» im Debug-Log. Menü: «Studio-Datei: geladen».
- [ ] **Prüfschritt Befehlsgrenze:** Mit `p12_voll.heli.lua` und allen Symbolen das Vollbild mindestens eine Minute
  laufen lassen, dabei einmal zur Flugliste und zurück wischen. Danach in der Suite das Debug-Log ansehen.
- **Erwartet:** Kein «Max instructions» und kein roter Text. Hintergrund: Das Format setzt seit 21.11.2026 für das Zeichnen
  das Ziel unter 10 000 Befehle je Bild (vorher 5 000); Heli braucht hier am Mac gezählt 6 407 (800 × 480). Belegt ist,
  dass der X18RS das verträgt (Elektro 0.4.0 rund 13 000, Heli ohne Studio-Datei seit 1.9 schon 6 400 bis 7 500). Dieser Schritt
  zeigt, ob das am Sender hält. Tritt «Max instructions» auf, bitte unbedingt melden.
- [ ] Wenn möglich auch im Layout mit Leisten (784 × 316, Kompaktansicht): dieselbe Datei hat dort eine eigene
  Ansicht (am Mac gezählt 5 796 Befehle je Bild). Eine Minute laufen lassen, Debug-Log ansehen.
- **Erwartet:** 16 Plätze mit Symbol und fetter Einheit, Linien und 4 Symbole unten, kein «Max instructions».
- [ ] `test/format2/p00_bild.heli.lua` als `<Kennung>.heli.lua` kopieren, Modell neu laden.
- **Erwartet:** 5 Plätze, davon 4 mit Symbol in verschiedenen Grössen (Akku, Temperatur, Uhr, Höhe) und einer ohne
  Symbol. Die Einheit steht fett oben links, beim Platz «Flugzeit» gar keine Einheit. Dazu ein Rahmen, zwei Linien, zwei
  Texte und unten rechts die Symbole Segler und Thermik. Plätze mit Werten, die das Modell nicht hat, zeigen «---».
- [ ] Modell mehrmals wechseln (mindestens fünfmal zu einem anderen Modell und zurück), jedes Mal das Vollbild ansehen.
- **Erwartet:** Die Symbole erscheinen jedes Mal wieder, kein roter Text, kein «Max instructions», der Sender wird
  nicht träger.
- [ ] Fehlende Symbole: Im Ordner `scripts/studio/symbole/` die Datei `akku_64.png` umbenennen (z. B. in
  `akku_64.png.weg`), Modell neu laden.
- **Erwartet:** Der Platz «Akku» bleibt ohne Symbol, alles andere wie vorher. Unten steht etwa 8 Sekunden lang
  «Studio: 1 Symbole fehlen», danach oben rechts ein oranges «!». Kein roter Text. Danach die Datei zurück umbenennen.
- [ ] Freiwillig: `test/format2/p11_format1_ohne.heli.lua` (Format 1, ohne Symbole) als `<Kennung>.heli.lua`
  kopieren, Modell neu laden.
- **Erwartet:** Dieselben Plätze wie `p11_format1`, ohne Symbole und ohne Schmuck, kein Hinweis.

- [ ] Am Schluss alle Dateien `<Kennung>.heli.…` in `scripts/studio` löschen und das Modell neu laden. Den Ordner
  `scripts/studio/symbole` nur löschen, wenn du Lua-Studio auf diesem Sender sonst nicht nutzt.
- **Erwartet:** «Studio-Datei: keine», Anzeige und Einstellungen wie vor Testfall 16.

### 17. «Auch bei Motor aus» und Speicher (neu in 1.12.0, Kapitel 6) – ohne Rotorblätter!
Voraussetzung: Motorschalter zugewiesen (Testfall 7), Zellenspannung kommt an (oder ein Testgerät liefert sie).
- [ ] Menü › **Alarm Zellenspannung** › «Rot + Ton unter» über die jetzige Zellenspannung stellen (z. B. 4,20 V).
  «Auch bei Motor aus» bleibt ein. Motorschalter auf aus.
- **Erwartet:** Der Alarm kommt (Ton, Vibration, Ansage), die Zelle ist rot.
- [ ] «Auch bei Motor aus» ausschalten, Motorschalter bleibt aus.
- **Erwartet:** Kein Ton, keine Vibration, keine Ansage. Die Zelle bleibt rot.
- [ ] Motorschalter auf ein.
- **Erwartet:** Der Alarm kommt wieder.
- [ ] Sender aus- und einschalten, Menü öffnen.
- **Erwartet:** «Auch bei Motor aus» bei der Zellenspannung ist weiter aus, alle anderen Einstellungen wie vorher, kein
  «Max size reached» im Debug-Log. Danach Haken wieder ein und die Schwelle zurück auf 3,50 V.
- [ ] Freiwillig mit Studio-Datei: In Lua-Studio bei einer Grenze «auch bei Motor aus» abwählen, Datei übertragen.
- **Erwartet:** Im Menü ist der Haken dieser Gruppe aus; schaltest du ihn ein, steht in
  `scripts/studio/<Kennung>.heli.funke.lua` bei dieser Grenze `beiMotorAus = true`.

## Einen Fehler melden

1. Im Repo auf GitHub: **Issues › New issue › «Fehler / Bug»**. Das Formular fragt alles Nötige ab.
2. **Bildschirmfoto:** Ein Handyfoto vom Sender genügt. Wichtig ist roter Text unten links im Widget («Heli: …»).
3. **Log:** Lua-Fehler stehen im Log des Senders. In der FrSky Suite (Sender per USB im Modus «Ethos Suite») unter
   Lua das **Debug-Log** öffnen und die Zeilen mit «Heli» kopieren.
4. Gib die **Nummer des Testfalls** an und was du erwartet hast.

Ideen und Wünsche bitte mit der Vorlage **«Wunsch / Idee»**. Bitte keine Modelldateien anhängen.

## Bekannte Grenzen von 1.14.2

- 1.13.0: umbenannt von «Heli RF» (`helirf`) in «Heli» (`heli`). In vorhandenen Modellen das Widget neu auswählen;
  eine alte Studio-Datei `<Kennung>.helirf.lua` wird noch gelesen (Hinweis im Log).

- Am echten Sender getestet nur auf der **X18RS** (mit 1.8.1, Ethos 26.2.0, 20.11.2026): Installation, Sensorsuche (8 Felder
  zugewiesen) und Anzeige mit Livewerten. Die anderen Sender nur im Simulator.
- Nicht am echten Sender geprüft: jeder Menüpunkt einzeln, die Ansagen, die Flugliste mit echten Flügen, die
  Bedienung mit dem Drehrad. Im Flug ist das Widget noch nicht erprobt.
- Neu in 1.9.1 und nur im Simulator getestet: Kompaktansicht, Feld Governor, SCHARF/SICHER, Ansage
  «Drehzahl verloren». Am Sender geprüft: Kompaktansicht (X18RS); Governor und SCHARF/SICHER noch nicht.
- Neu in 1.10.0: Studio-Datei aus Lua-Studio. Am Sender (X18RS, 20.11.2026) geprüft: ohne Studio-Datei wie bisher,
  volle Studio-Datei im Vollbild ohne Abbruch. Noch offen am Sender: `.funke.lua`, Kompaktansicht mit Studio-Datei,
  Alarm bei Motorschalter aus mit Studio-Datei, Sprache Englisch.
- Neu in 1.10.1 und bisher **nur im Simulator** getestet: Sensoren der Studio-Datei und Info-Datei am Sender
  (Testfall 16 g), grosse Studio-Dateien in Stücken.
- Neu in 1.12.0 und **am Sender noch nicht geprüft:** «Auch bei Motor aus» (Testfall 17) und Speicher freigeben beim
  Modellwechsel (im Simulator bleiben 4–5 KB).
- 1.11.0: Lua-Studio-Format 2 mit Symbolen, fetter Einheit und Schmuck (Testfall 16 h), am Sender mit voller Datei im
  Vollbild ohne Abbruch (21.11.2026). Ohne Studio-Datei und mit
  Format-1-Dateien wie 1.10.1.
- Befehle je Bild: Lua-Studio-Format 2 §9 setzt seit 21.11.2026 für `paint` das Ziel unter 10 000 Befehle (vorher 5 000; `wakeup` weiter unter 5 000). Am Mac gezählt braucht `p12_voll` 6 407 Befehle bei 800 × 480 und 5 796 bei
  784 × 316, die eingebaute Anzeige 6 400 bis 7 500. Begründung: Der X18RS verträgt nachweislich mehr (Elektro 0.4.0
  rund 13 000 je Bild, Heli ohne Studio-Datei seit 1.9 schon 6 400 bis 7 500). Massgebend ist Testfall 16 h:
  `p12_voll` mit Symbolen läuft am Sender im Vollbild und wenn möglich kompakt ohne «Max instructions».
- Layout Vollbild oder ein Feld mit Leisten. In kleineren Zonen steht «Feld zu klein».
- Speicher: rund 90 KB Lua-Speicher (gemessen mit 1.8.1). Auf Sendern mit sehr vielen Lua-Widgets kann
  der Speicher knapp werden.
- Bei der X18RS mit Ethos 26.2.0 lud der Sender Skripte nur von der SD-Karte (`SD:/scripts`), wenn am Sender
  «Speicherort Skripte = SD» eingestellt ist. Die Suite installiert automatisch an den richtigen Ort.
