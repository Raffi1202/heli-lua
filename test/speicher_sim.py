#!/usr/bin/env python3
"""Heli RF: Bleibewert nach dem Modellwechsel im Ethos-Simulator (X18RS-EU, 26.2.0), Auftrag «Speicher freigeben» 21.11.2026.

Aufruf (aus dem Repo-Ordner):
  /opt/homebrew/opt/lua@5.4/bin/lua test/format2_dateien.lua     zuerst: Heli-Fassungen nach test/format2/
  python3 test/speicher_sim.py --port 8801                        alle Fälle
  python3 test/speicher_sim.py --port 8801 p12                    nur diesen Fall
  python3 test/speicher_sim.py --port 8801 --quelle v1.11.0       Vergleich mit einer älteren Fassung (Git-Tag)

Ablauf je Fall: Simulator mit leerem Modell starten, Speicher messen (M0, Heli RF nie gezeigt). Dann Heli RF zeigen,
zurück auf das leere Modell wechseln und messen (M2). Das Ganze zweimal. Gemessen wird nach zweimal
collectgarbage("collect"), wie mit einem Messwerkzeug am Sender.
  ohne  : ohne Studio-Datei
  p12   : Studio-Datei p12_voll (Format 2, 20 Symbole zu 64 px, Schmuck), dazu der Bildspeicher
  zwei  : Heli A (p12) → Heli B (p06) → leer: zwei Heli-Modelle nacheinander, dann ein Modell ohne Heli
Ziel (Auftrag): nach dem Wechsel bleiben höchstens 20 KB je Lua belegt (M2 − M0), kein Bildspeicher.
"""
import os, re, shutil, sys, tempfile, urllib.error

HIER = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HIER)
import studio_sim as ss    # noqa: E402
import format2_sim as f2   # noqa: E402

ZIEL_KB = 20.0
PL, PB = "MOTOR/leer.bin", "MOTOR/heli_zwei.bin"   # Kopien des Modells aus modell-leer.json


def messe(sim):
    m = f2.speicher(sim)            # (collectgarbage("count") in KB, luaRamAvailable KB, luaBitmapsRamAvailable KB)
    if m is None:
        raise RuntimeError("Speicher nicht messbar")
    return m


def lade(sim, pfad):
    r = sim.get("loadModel", path=pfad)
    if not r.get("ok"):
        raise RuntimeError("loadModel %s: %r" % (pfad, r))
    sim.get("wait", ms=7000)


def pfad_finden(sim):
    for vorne in ("models/", "", "/models/"):
        try:
            if sim.get("loadModel", path=vorne + PL).get("ok"):
                return vorne
        except urllib.error.HTTPError:
            pass
    raise RuntimeError("loadModel: kein Pfad angenommen")


def fall(name, port, basis, quelle, koord):
    erg = {"fall": name, "befunde": [], "zeilen": []}
    root = os.path.join(basis, name)
    sim = ss.Sim(port, root, os.path.join(basis, "_shots"))
    try:
        ss.grundstand(root, quelle)
        ss.haken(root, ss.ZELLE_GUT)
        global PA
        PA = ss.grundmodell(root)
        if name != "ohne":
            f2.symbole(root, koord)
            ss.schreibe(ss.studio_pfad(root), f2.datei("p12_voll"))
            ss.schreibe(ss.studio_pfad(root, ss.KENNUNG2), f2.datei("p06_100_symbole"))
        for p in (PL, PB):
            shutil.copyfile(os.path.join(root, "models", PA), os.path.join(root, "models", p))
        sim.start()
        sim.get("wait", ms=3000)
        m0 = messe(sim)
        erg["zeilen"].append(("M0 leeres Modell, Heli RF nie gezeigt", m0))
        sim.modell(ss.MODELL, (800, 480))                 # Heli RF ins aktuelle Modell (PA)
        sim.get("wait", ms=8000)
        erg["zeilen"].append(("Heli RF aktiv", messe(sim)))
        v = pfad_finden(sim)                               # lädt dabei das leere Modell
        n_probe = len(sim.log())
        sim.get("wait", ms=5000)
        if name == "zwei":
            lade(sim, v + PB)
            sim.modell(ss.MODELL2, (800, 480))
            sim.get("wait", ms=8000)
            erg["zeilen"].append(("Heli B aktiv", messe(sim)))
            lade(sim, v + PL)
        m2 = [messe(sim)]
        erg["zeilen"].append(("leer nach Heli RF, Runde 1", m2[-1]))
        for runde in (2,):
            lade(sim, v + PA)
            erg["zeilen"].append(("Heli RF aktiv, Runde %d" % runde, messe(sim)))
            if name == "zwei":
                lade(sim, v + PB)
                erg["zeilen"].append(("Heli B aktiv, Runde %d" % runde, messe(sim)))
            lade(sim, v + PL)
            m2.append(messe(sim))
            erg["zeilen"].append(("leer nach Heli RF, Runde %d" % runde, m2[-1]))
        log = sim.log()[n_probe:]
        fehler = [z for z in log if ss.FEHLER_LOG.search(z)]
        if fehler:
            erg["befunde"].append("Fehler im Log: " + " | ".join(fehler[:4]))
        for i, m in enumerate(m2, 1):
            bleibt, bmp = m[0] - m0[0], m0[2] - m[2]
            erg["zeilen"].append(("bleibt Runde %d: Lua %.1f KB, Bildspeicher %.1f KB" % (i, bleibt, bmp), None))
            if bleibt > ZIEL_KB:
                erg["befunde"].append("Runde %d: %.1f KB bleiben belegt (Ziel ≤ %.0f KB)" % (i, bleibt, ZIEL_KB))
            if bmp > 8:
                erg["befunde"].append("Runde %d: %.1f KB Bildspeicher bleiben belegt" % (i, bmp))
    except Exception as e:
        erg["befunde"].append("Abbruch des Treibers: %r" % (e,))
    finally:
        sim.ende()
    return erg


def main():
    a = sys.argv[1:]

    def opt(n, d=None):
        if n in a:
            i = a.index(n)
            v = a[i + 1]
            del a[i:i + 2]
            return v
        return d
    port = int(opt("--port", "0"))
    if not 8801 <= port <= 8805:
        sys.exit("--port 8801 bis 8805 angeben (8765/8766 sind tabu)")
    quelle = opt("--quelle", "src")
    koord = opt("--koord", f2.KOORD)
    basis = opt("--basis") or tempfile.mkdtemp(prefix="heli-speicher-")
    faelle = a or ["ohne", "p12", "zwei"]
    befunde = 0
    print("Heli RF Speicher nach Modellwechsel, Quelle %s, Arbeitsordner %s" % (quelle, basis))
    for n in faelle:
        e = fall(n, port, basis, quelle, koord)
        print("\n== %s" % n)
        for text, m in e["zeilen"]:
            print("  %-42s" % text + ("  belegt %.1f KB, frei %.0f KB, Bildspeicher frei %.0f KB" % m if m else ""))
        for b in e["befunde"]:
            print("  BEFUND: " + b)
        befunde += len(e["befunde"])
    print("\nERGEBNIS: " + ("kein Fehler" if befunde == 0 else "%d Befunde" % befunde))
    sys.exit(1 if befunde else 0)


if __name__ == "__main__":
    main()
