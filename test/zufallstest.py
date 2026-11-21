#!/usr/bin/env python3
"""Heli RF: Zufallstest im fensterlosen Ethos-Simulator.

Aufruf:  python3 test/zufallstest.py [klein] [abbild]
  klein   wechselt bei jedem Zeichnen zwischen 640 x 360, 480 x 320, 480 x 272, einem Mini-Feld und den Kompaktgrössen
          784 x 316, 630 x 258, 472 x 210 (Layout mit Leisten), sonst 800 x 480
  abbild  lädt alle Skripte der Funke dazu (Speicher wie am Sender, dauert rund 2 min)

Der Haken (zufallstest-haken.lua) gibt allen Werten Zufalls- und Extremwerte und tippt und wischt zufällig.
Bestanden: kein Fehler, kein Ereignis-Fehler.
"""
import sys
from sim_hilfe import HIER, STELLE, FENSTER, lauf, plan
import os

text = open(os.path.join(HIER, "zufallstest-haken.lua"), encoding="utf-8").read()
text = text[text.index(STELLE):]                          # Kopfkommentar weglassen
ersetze = [["scripts/helirf/kern.lua", STELLE, text]]
if "klein" in sys.argv:
    ersetze.insert(0, ["scripts/helirf/kern.lua", FENSTER,
                       "  local W, H = 480, 320\n"
                       "  if FZ then local g = { { 640, 360 }, { 480, 320 }, { 480, 272 }, { 120, 40 }, { 784, 316 }, { 630, 258 }, { 472, 210 } } W, H = g[FZ % 7 + 1][1], g[FZ % 7 + 1][2] end\n"
                       "  local s = min(W / 800, H / 480)"])
aus = lauf(plan(ersetze, [{"t": 5800, "wisch": [700, 250, 100, 250]}, {"t": 40000, "ende": True}], "abbild" in sys.argv))
zeilen = [z for z in aus.splitlines() if "Heli RF" in z or "FEHLER" in z or "ERSETZE" in z]
print("\n".join(z[:200] for z in zeilen[-6:]))
gut = any("FUZZ" in z for z in zeilen) and not any(("Fehler in" in z) or ("FEHLER" in z) or ("ERSETZE" in z) for z in zeilen) \
    and all("Fehler nil" in z for z in zeilen if "Durchlauf" in z) and all("Ereignis-Fehler 0" in z for z in zeilen if "Ereignis-Fehler" in z)
print("BESTANDEN" if gut else "NICHT BESTANDEN")
sys.exit(0 if gut else 1)
