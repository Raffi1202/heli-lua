#!/usr/bin/env python3
"""Heli: erzeugt den festen Satz Simulatorbilder in docs/bilder-simulator/.

Aufruf:  python3 test/bilder.py [Nummer ...]     ohne Nummer alle Bilder, sonst nur die genannten (z. B. 06 20)

Namen: «Heli - Sim <BxH> <Nr> <Zustand>.png». Die Werte sind glaubhafte Testwerte, die Einstellungen stehen ab Werk.
Jedes Bild danach ansehen. Ein Lauf dauert rund 40 s.
"""
import os, sys
from sim_hilfe import REPO, fenster, haken, lauf, plan

ZIEL = os.path.join(REPO, "docs", "bilder-simulator")
GROESSEN = [(800, 480), (640, 360), (480, 320), (480, 272), (784, 316), (630, 258), (472, 210)]   # ab 4: Layout mit Leisten
WISCH = {"t": 5800, "wisch": [700, 250, 100, 250]}       # auf Bildschirm 2 (Heli)
MENUE = [{"t": 5800, "tipp": [370, 450]}, {"t": 7600, "tipp": [270, 88]}, {"t": 9400, "tipp": [400, 290]}]   # Bildschirme > Bildsch. 2 > Widget
HOCH = {"wisch": [400, 420, 400, 120]}

WERTE = ("  v.tele=true v.volt=47.0 v.rpm=1840 v.strom=64 v.bec=8.1 v.mah=1730 v.rssi=-52 v.zellen=12 v.pid=1 v.rate=1"
         " v.becTief=7.6 v.zelleTief=3.57 v.rpmHoch=2310 v.stromHoch=212 v.tempHoch=78 v.gov=4 v.scharf=true ")
GUT = WERTE + "v.temp=62 v.proz=64 v.zelle=3.92"
ORANGE = WERTE + "v.temp=74 v.proz=31 v.zelle=3.58 v.tempHoch=74"
ROT = WERTE + "v.temp=86 v.proz=18 v.zelle=3.44 v.tempHoch=86 v.zelleTief=3.44"
FRAGE = (WERTE + "v.temp=71 v.proz=58 v.zelle=3.82 v.rpm=1650 v.strom=4\n"
         "  if not TESTSTUB then TESTSTUB=true w.fluege=14 w.akt={ dauer=281, nr=14, mah=3120, rpm=2310, a=212, t=78, z=3.57, bec=7.6, proz=58, pause=true } w.dialog='flug' end")
LISTE = (GUT + "\n  if not TESTSTUB then TESTSTUB=true w.seite=2 w.fluege=14 w.wahl=11\n"
         "    w.liste={ {9,312,3980,2310,205,88,3.52,7.6,18}, {10,275,3420,2280,190,81,3.61,7.7,29}, {11,341,4105,2320,212,91,3.49,7.6,15},"
         " {12,198,2260,2250,180,74,3.72,7.8,52}, {13,301,3760,2300,201,85,3.55,7.7,22} }\n"
         "    w.akt={ dauer=154, nr=14, mah=1730, rpm=2260, a=176, t=72, z=3.74, bec=7.7, proz=61 } end")
DE, EN = "  c.sprache=2\n", "  c.sprache=1\n"
PAUSE = (GUT + "\n  if not TESTSTUB then TESTSTUB=true w.fluege=14 w.akt={ dauer=281, nr=14, mah=3120, rpm=2310, a=212, t=78, z=3.57, bec=7.6, proz=58, pause=true } end")
NACHJA = (GUT + "\n  if not TESTSTUB then TESTSTUB=true w.fluege=14 w.akt=nil w.liste={ {14,281,3120,2310,212,78,3.57,7.6,58} } end")
NEUSTART = (GUT + "\n  if not TESTSTUB then TESTSTUB=true w.seite=2 w.fluege=14 w.liste={ {12,198,2260,2250,180,74,3.72,7.8,52}, {13,301,3760,2300,201,85,3.55,7.7,22} }"
            " w.akt={ dauer=281, nr=14, mah=3120, rpm=2310, a=212, t=78, z=3.57, bec=7.6, proz=58, pause=true } end")
TEIL = "  v.tele=true v.volt=47.0 v.rpm=1840 v.zellen=12 v.temp=62 v.zelle=3.92 v.rpmHoch=2280 v.tempHoch=71 v.proz=nil"
OHNEZAHL = ("  v.tele=true v.volt=22.8 v.rpm=1840 v.strom=64 v.bec=8.1 v.mah=1486 v.rssi=-52 v.zellen=nil v.pid=1 v.rate=1"
            " v.temp=62 v.proz=nil v.zelle=nil v.zelleTief=nil v.zellenFehlt=true")
MLISTE = "  if not TESTSTUB then TESTSTUB=true w.fluege=3 w.liste={ {1,312,3980,2310,205,88,3.52,7.6,18}, {2,275,3420,2280,190,81,3.61,7.7,29}, {3,341,4105,2320,212,91,3.49,7.6,15} } end"

# Nummer, Zustand, Lua-Haken, Grössen, Schritte vor dem Bild (ohne Zeit), Wartezeit bis zum Bild in ms
BILDER = [
    ("01", "Widget-Liste", DE, [0], "menue", [{"tipp": [610, 97]}, {"wisch": [400, 360, 400, 150]}, {"wisch": [400, 360, 400, 150]},
                                             {"wisch": [400, 360, 400, 150]}, {"wisch": [400, 360, 400, 150]}]),
    ("02", "Menue", DE, [0], "menue", []),
    ("03", "ohne Telemetrie", DE, [0], "seite", []),
    ("04", "Normal", DE + GUT, [0], "seite", []),
    ("05", "Warnung", DE + ORANGE, [0], "seite", []),
    ("06", "Alarm", DE + ROT, [0, 1, 2, 3], "seite", []),
    ("07", "Rueckfrage Flug beendet", DE + FRAGE, [0, 1, 2, 3], "seite", []),
    ("08", "nach Nur Pause", DE + PAUSE, [0, 1, 2, 3], "seite", []),
    ("09", "nach Ja beendet", DE + NACHJA, [0], "seite", []),
    ("10", "nach Neustart pausierter Flug", DE + NEUSTART, [0], "seite", []),
    ("11", "nur ein Teil der Sensoren", DE + TEIL, [0], "seite", []),
    ("14", "Zellenzahl fehlt", DE + OHNEZAHL, [0, 1, 2, 3], "seite", []),
    ("15", "Zellenzahl fehlt Englisch", EN + OHNEZAHL, [0], "seite", []),
    ("12", "Englisch", EN + GUT, [0], "seite", []),
    ("13", "Englische Rueckfrage", EN + FRAGE, [0], "seite", []),
    ("30", "Kompakt", DE + GUT + "\n  if not TESTSTUB then TESTSTUB=true w.fluege=14 w.akt={ dauer=154, nr=15 } end", [4, 5, 6], "seite", []),
    ("31", "Kompakt Drehzahl verloren", DE + ROT + " v.gov=6 v.scharf=true", [4], "seite", []),
    ("32", "Kompakt Englisch ohne Rotorflight", EN + GUT + " v.gov=nil v.scharf=false", [4], "seite", []),
    ("34", "Kompakt Englisch", EN + GUT + "\n  if not TESTSTUB then TESTSTUB=true w.fluege=14 w.akt={ dauer=154, nr=15 } end", [4], "seite", []),
    ("35", "Kompakt Rueckfrage", DE + FRAGE, [4], "seite", []),
    ("33", "Kompakt Flugliste", DE + LISTE, [4], "seite", []),
    ("20", "Flugliste", DE + LISTE, [0, 1, 2, 3], "seite", []),
    ("22", "Menue Alarm", DE, [0], "menue", [{"tipp": [300, 415]}, {"wisch": [400, 420, 400, 160]}]),
    ("23", "Menue Flug und Motorschalter", DE, [0], "menue", [HOCH, HOCH, HOCH, {"tipp": [300, 311]}, {"wisch": [400, 420, 400, 160]}]),
    ("24", "Menue Fluege ohne Beruehrung", DE, [0], "menue", [HOCH, HOCH, HOCH, {"tipp": [300, 375]}, {"wisch": [400, 420, 400, 120]}]),
    ("25", "Menue Rueckfrage Flug loeschen", DE + MLISTE, [0], "menue", [HOCH, HOCH, HOCH, {"tipp": [300, 375]}, {"wisch": [400, 420, 400, 120]}, {"tipp": [585, 242]}]),
]

wahl = sys.argv[1:]
os.makedirs(ZIEL, exist_ok=True)
for nr, zustand, lua, groessen, art, extra in BILDER:
    if wahl and nr not in wahl:
        continue
    for g in groessen:
        b, h = GROESSEN[g]
        datei = os.path.join(ZIEL, "Heli - Sim %dx%d %s %s.png" % (b, h, nr, zustand))
        ersetze = [haken(lua.rstrip("\n"))]
        if g:
            ersetze.insert(0, fenster(b, h))
        schritte = [WISCH] if art == "seite" else list(MENUE)
        t = schritte[-1]["t"]
        for s in extra:
            t += 1500
            schritte.append(dict(s, t=t))
        t += 4300 if nr == "06" else 2700
        bild = {"t": t, "bild": datei}
        if g:
            bild["schnitt"] = [b, h]
        aus = lauf(plan(ersetze, schritte + [bild, {"t": t + 800, "ende": True}]))
        fehler = [z for z in aus.splitlines() if "Heli: Fehler" in z or "FEHLER" in z or "ERSETZE" in z]
        print(("FEHLER " if fehler or not os.path.exists(datei) else "ok     ") + os.path.basename(datei), *fehler[:2], sep="\n  " if fehler else "")
