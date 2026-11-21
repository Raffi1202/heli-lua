🇬🇧 [English](../en/Lua-Studio.md) · 🇩🇪 [Deutsch](../de/Lua-Studio.md)

# Lua-Studio

Mit dem PC-Programm Lua-Studio gestaltest du die Anzeige je Modell und setzt Einstellungen und Grenzen. Es schreibt `scripts/studio/<Kennung>.helirf.lua` (Kennung = Modellname, andere Zeichen als A–Z, a–z, 0–9 werden zu `_`). Ohne diese Datei arbeitet Heli RF wie bisher; im Menü steht «Studio-Datei: keine».

- **Ansichten:** je Fenstergrösse eine (z. B. 800 × 480, 784 × 316), höchstens zwei, je bis 16 Kästchen (Zahl, Ring, Balken, Verlauf, Status), mit Titel, Bereich, Farben, MIN/MAX/Ø. Im Vollbild ersetzt die Ansicht Seite 1; die Flugliste bleibt.
- **Format 2 (1.11.0):** Symbole in den Kästchen, fette Einheit, Schmuck (Symbole, Texte, Linien, Rahmen, bis 24 je Ansicht). Symbole sind Graustufen-PNG in `scripts/studio/symbole/`, nur Lua-Studio schreibt sie, höchstens 20 je Datei.
- **Wert-Anpassung:** Faktor, Versatz, Einheit, Stellen, Name je Wert.
- **Grenzen:** gelten je Wert. Fehlt ein Eintrag, gilt die Werkgrenze; nur ein ausdrückliches `aus = true` schaltet einen Alarm ab. Grenzen für weitere Sensoren und Kanäle melden mit Ton und Vibration, höchstens alle 10 s.
- **Auch bei Motor aus (1.12.0):** je Grenze, ab Werk ja, auch für die weiteren Grenzen.
- **Änderungen an der Funke** (Menü) gehen nach `<Kennung>.helirf.funke.lua`; die Studio-Datei bleibt unverändert. Menü › Studio-Datei › Zurücksetzen geht zurück auf den Studio-Stand.
- **Hinweise:** Eine kaputte oder zu neue Datei oder ungültige Einträge zeigen unten 8 s ein dunkles Band, danach ein oranges «!». Heli RF läuft immer weiter. Einzelheiten im Log.
- Je bis 48 Einträge für Wert-Anpassungen, Grenzen und Einstellungen. Heli RF schreibt für Lua-Studio `<Kennung>.helirf.info.json` (Modell, Sender, Sensoren, Fenstergrössen).

---
[← Start](../Home.md) | [Zurück](Alarme.md) | [Weiter →](FAQ.md)
