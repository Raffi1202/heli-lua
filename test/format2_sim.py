#!/usr/bin/env python3
"""Heli: Pflichttests Lua-Studio-Format 2 (Abschnitt 9) im Ethos-Simulator (X18RS-EU, 26.2.0).

Aufruf (aus dem Repo-Ordner):
  /opt/homebrew/opt/lua@5.4/bin/lua test/format2_dateien.lua     zuerst: Heli-Fassungen nach test/format2/
  python3 test/format2_sim.py --port 8803                         alle Fälle
  python3 test/format2_sim.py --port 8803 t01_05_15 t13            nur diese Fälle
  python3 test/format2_sim.py --liste                              Fälle auflisten

Optionen:  --port N (8803–8805; 8765/8766 sind tabu)   --basis DIR (Arbeitsordner, Standard: neuer Temp-Ordner)
           --bilder DIR (Ablage der Bilder, Standard: <basis>/bilder)   --koord DIR (Ordner «FrSky Koordination»)

Je Fall ein eigenes Dateisystem (wie test/studio_sim.py): Heli aus src/heli, die Symbole aus «Lua-Studio-Format 2 -
Testdateien/symbole» direkt in den Root-Ordner nach scripts/studio/symbole/ (nicht über writeFile des Plugins, das kleine
Dateien falsch schreibt; jede Datei wird nachgelesen), die Studio-Datei nach scripts/studio/Heli_Studio.heli.lua,
Modell «Heli Studio» mit Heli als einzigem Widget. In der KOPIE von studio_symbole.lua (nur im Root-Ordner, nie im
Repo) meldet ein Messzusatz jedes io.open und lcd.loadMask (TESTOPEN/TESTLOAD) und die Zähler nach dem Ende von S.schritt
(TESTSYM geladen fehlend verworfen). Geprüft: Zähler wie im LIESMICH, loadMask/io.open nur für gültige Dateien, Lua-Log
ohne Fehler, Hinweis «Studio: 8 Symbole fehlen» (p01), Lua-Speicher (luaRamAvailable, luaBitmapsRamAvailable), ein Bild
je Fall. t13: zwei Modelle (p12 20 × 64 px, p06 20 × 24 px) zehnmal hin und her, Speicher nach jedem Wechsel.
"""
import json, os, re, shutil, subprocess, sys, tempfile, time, urllib.error

HIER = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HIER)
import studio_sim as ss  # noqa: E402  (Sim, grundstand, schreibe, studio_pfad, FEHLER_LOG, MODELL, KENNUNG …)

F2 = os.path.join(HIER, "format2")
KOORD = os.path.expanduser(os.environ.get("FORMAT2_ORDNER", ""))   # Ordner mit «Lua-Studio-Format 2 - Testdateien»

# Fall: Datei, Fenster, erwartete Zähler (geladen, fehlend, verworfen), Pflichttests
F = {
    "t00_bild":   dict(datei="p00_bild", groesse=(800, 480), zaehler=(6, 0, 0), tests="Bild (Selbsttest)"),
    "t01_05_15":  dict(datei="p01_kaputte_png", groesse=(800, 480), zaehler=(2, 8, 0), tests="1, 2, 3, 4, 5, 15",
                       laden={"akku_48.png", "uhr_48.png"}, hinweis=("8 Symbole fehlen", "8 symbols missing")),
    "t06":        dict(datei="p06_100_symbole", groesse=(800, 480), zaehler=(20, 0, 80), tests="6"),
    "t07":        dict(datei="p07_namen", groesse=(800, 480), zaehler=(1, 1, 9), tests="7",
                       offen={"aaaaaaaaaaaaaaaaaaaaaaaa_48.png", "akku_48.png"}),
    "t08":        dict(datei="p08_px", groesse=(800, 480), zaehler=(1, 0, 7), tests="8"),
    "t09":        dict(datei="p09_deko", groesse=(800, 480), zaehler=(1, 0, 18), tests="9"),
    "t10":        dict(datei="p10_symbol_ohne_eintrag", groesse=(800, 480), zaehler=(1, 0, 3), tests="10"),
    "t11":        dict(datei="p11_format1", groesse=(800, 480), zaehler=None, tests="11", laden=set()),
    "t12_800":    dict(datei="p12_voll", groesse=(800, 480), zaehler=(20, 0, 0), tests="12, 17"),
    "t12_784":    dict(datei="p12_voll", groesse=(784, 316), zaehler=(20, 0, 0), tests="12, 17"),
    "t13":        dict(datei=None, groesse=(800, 480), zaehler=None, tests="13"),
    "t16":        dict(datei="p16_wertanpassungen", groesse=(800, 480), zaehler=(0, 0, 0), tests="16"),
    "t17":        dict(datei="p17_schmaltexte", groesse=(800, 480), zaehler=(0, 0, 0), tests="17"),
}

VORN = ('local io_, lcd_, print_ = io, lcd, print\n'
        'local io = setmetatable({ open = function(p, m) print_("TESTOPEN " .. tostring(p)) return io_.open(p, m) end }, { __index = io_ })\n'
        'local lcd = setmetatable({ loadMask = function(p) print_("TESTLOAD " .. tostring(p)) return lcd_.loadMask(p) end }, { __index = lcd_ })\n')
HINTEN = ('local schritt_, start_, gemeldet = S.schritt, S.start, false\n'
          'S.start = function(d) gemeldet = false return start_(d) end\n'
          'S.schritt = function() local r = schritt_() if r and not gemeldet then gemeldet = true '
          'local g, f, v = S.zaehler() print("TESTSYM " .. g .. " " .. f .. " " .. v) end return r end\n'
          'return S\n')


def messzusatz(root):
    """Messzusatz in die Kopie von studio_symbole.lua (nur im Root-Ordner des Simulators)."""
    p = os.path.join(root, "scripts", "heli", "studio_symbole.lua")
    if not os.path.exists(p):
        return False
    t = open(p, encoding="utf-8").read()
    i = t.rstrip().rfind("return S")
    if i < 0:
        return False
    ss.schreibe(p, VORN + t[:i] + HINTEN)
    return True


def symbole(root, koord):
    """Symbole direkt in den Root-Ordner kopieren und nachlesen."""
    quelle = os.path.join(koord, "Lua-Studio-Format 2 - Testdateien", "symbole")
    ziel = os.path.join(root, "scripts", "studio", "symbole")
    os.makedirs(ziel, exist_ok=True)
    for n in sorted(os.listdir(quelle)):
        if n.endswith(".png"):
            ss.schreibe(os.path.join(ziel, n), open(os.path.join(quelle, n), "rb").read())


def datei(name):
    return open(os.path.join(F2, name + ".heli.lua"), "rb").read()


def speicher(sim):
    r = sim.post("startMacro", {"code": 'collectgarbage("collect") collectgarbage("collect") local m = system.getMemoryUsage() '
                                        'print("TESTMEM", collectgarbage("count"), m.luaRamAvailable, m.luaBitmapsRamAvailable)'})
    for z in r.get("output", []):
        m = re.search(r"TESTMEM\s+([\d.]+)\s+(\d+)\s+(\d+)", z)
        if m:
            return float(m.group(1)), int(m.group(2)) / 1024, int(m.group(3)) / 1024
    return None


def auswerten(fall, log, erg):
    fehler = [z for z in log if ss.FEHLER_LOG.search(z) and not z.startswith(("TESTOPEN", "TESTLOAD", "TESTSYM"))]
    if fehler:
        erg["befunde"].append("Fehler im Log: " + " | ".join(fehler[:4]))
    sym = [z for z in log if z.startswith("TESTSYM")]
    if fall.get("zaehler") is not None:
        if not sym:
            erg["befunde"].append("keine Zeile TESTSYM: S.schritt nicht fertig geworden (oder studio_symbole.lua nicht benutzt)")
        else:
            z = tuple(int(x) for x in sym[-1].split()[1:4])
            erg["notizen"].append("geladen / fehlend / verworfen: %d / %d / %d" % z)
            if z != fall["zaehler"]:
                erg["befunde"].append("Zähler %s, erwartet %s" % (z, fall["zaehler"]))
    geladen = [z.split("/")[-1] for z in log if z.startswith("TESTLOAD")]
    if "laden" in fall and set(geladen) != fall["laden"]:
        erg["befunde"].append("loadMask für %s, erwartet nur %s" % (sorted(set(geladen)), sorted(fall["laden"])))
    offen = [z.split("/")[-1] for z in log if z.startswith("TESTOPEN")]
    if "offen" in fall and not set(offen) <= fall["offen"]:
        erg["befunde"].append("io.open ausserhalb der gültigen Namen: %s" % sorted(set(offen) - fall["offen"]))
    if fall.get("hinweis") and not any(h in z for z in log for h in fall["hinweis"]):
        erg["befunde"].append("Hinweis «%s» fehlt im Log" % fall["hinweis"][0])
    studio = [z for z in log if z.startswith(("Studio-Symbol", "Heli"))]
    if studio:
        erg["notizen"].append("Log: " + " | ".join(studio[:3]) + (" …" if len(studio) > 3 else ""))


def lauf(name, fall, port, basis, bilder, koord):
    erg = {"fall": name, "tests": fall["tests"], "befunde": [], "notizen": []}
    root = os.path.join(basis, name)
    b, h = fall["groesse"]
    bild = os.path.join(bilder, "Heli - Format 2 %s %dx%d.png" % (name, b, h))
    sim = ss.Sim(port, root, os.path.join(basis, "_shots"))
    try:
        ss.grundstand(root, "src")
        if not messzusatz(root):
            erg["befunde"].append("src/heli/studio_symbole.lua fehlt oder ohne «return S»: Messzusatz nicht möglich")
        symbole(root, koord)
        if name == "t13":
            return modellwechsel(sim, root, erg, bild)
        ss.schreibe(ss.studio_pfad(root), datei(fall["datei"]))
        sim.start()
        sim.modell(ss.MODELL, fall["groesse"])
        sim.get("wait", ms=10000)
        erg["speicher"] = speicher(sim)
        log = sim.log()
        sim.bild(bild)
        erg["bild"] = bild
        auswerten(fall, log, erg)
        i = ss.info(root)
        if not i or i.get("studioDatei") != "geladen":
            erg["befunde"].append("Info-Datei: studioDatei %r" % (i and i.get("studioDatei")))
    except Exception as e:
        erg["befunde"].append("Abbruch des Treibers: %r" % (e,))
    finally:
        sim.ende()
    return erg


def modellwechsel(sim, root, erg, bild):
    """Test 13: Modell A (p12, 20 × 64 px) und B (p06, 20 × 24 px) zehnmal hin und her; Speicher nach jedem Wechsel."""
    ss.schreibe(ss.studio_pfad(root), datei("p12_voll"))
    ss.schreibe(ss.studio_pfad(root, ss.KENNUNG2), datei("p06_100_symbole"))
    sim.start()
    sim.modell(ss.MODELL, (800, 480))
    sim.get("wait", ms=3000)
    pa, pb = ss.grundmodell(root), "MOTOR/heli_zwei.bin"               # Modell aus modell-leer.json
    shutil.copyfile(os.path.join(root, "models", pa), os.path.join(root, "models", pb))
    pfade, r = [], None
    for kandidat in ("models/" + pb, pb, "/models/" + pb, "USER:/models/" + pb):
        try:
            r = sim.get("loadModel", path=kandidat)
        except urllib.error.HTTPError as e:
            r = {"ok": False, "fehler": "%s %s" % (kandidat, e)}
        if r.get("ok"):
            pfade = [kandidat.replace(pb, pa), kandidat]
            break
    if not pfade:
        erg["befunde"].append("loadModel: kein Pfad angenommen (%r)" % r)
        return erg
    sim.get("wait", ms=2000)
    n_probe = len(sim.log())
    sim.modell(ss.MODELL2, (800, 480))
    sim.get("wait", ms=6000)
    mem = []
    for i in range(10):
        r = sim.get("loadModel", path=pfade[i % 2])
        if not r.get("ok"):
            erg["befunde"].append("loadModel %s: %r" % (pfade[i % 2], r))
            break
        sim.get("wait", ms=8000)
        mem.append(speicher(sim))
    log = sim.log()[n_probe:]
    sim.bild(bild)
    erg["bild"] = bild
    fehler = [z for z in log if ss.FEHLER_LOG.search(z) and not z.startswith(("TESTOPEN", "TESTLOAD", "TESTSYM"))]
    if fehler:
        erg["befunde"].append("Fehler im Log: " + " | ".join(fehler[:4]))
    sym = [z.split()[1:4] for z in log if z.startswith("TESTSYM")]
    erg["notizen"].append("Zähler je Laden: " + ", ".join("/".join(s) for s in sym))
    # p06 schreibt je Laden 80 Log-Zeilen; der Log-Puffer des Simulators behält nicht alle TESTSYM-Zeilen (gemessen: 7 von 12).
    # Darum: jede gemeldete Zeile gültig, beide Modelle mindestens einmal.
    if any(s not in (["20", "0", "0"], ["20", "0", "80"]) for s in sym) or ["20", "0", "0"] not in sym or ["20", "0", "80"] not in sym:
        erg["befunde"].append("Zähler je Modell nicht 20/0/0 bzw. 20/0/80 (%d Zeilen)" % len(sym))
    gut = [m for m in mem if m]
    erg["speicher_verlauf"] = gut
    if len(gut) >= 6:
        # nach dem Einschwingen gleiche Modelle vergleichen: Wechsel 3/4 gegen 9/10
        ram = min(gut[-2][1] - gut[2][1], gut[-1][1] - gut[3][1])
        bmp = min(gut[-2][2] - gut[2][2], gut[-1][2] - gut[3][2])
        erg["notizen"].append("luaRamAvailable je Wechsel (KB): " + " ".join("%.0f" % m[1] for m in gut))
        erg["notizen"].append("luaBitmapsRamAvailable je Wechsel (KB): " + " ".join("%.0f" % m[2] for m in gut))
        if ram < -8:
            erg["befunde"].append("luaRamAvailable nimmt dauerhaft ab (%.1f KB)" % ram)
        if bmp < -8:
            erg["befunde"].append("luaBitmapsRamAvailable nimmt dauerhaft ab (%.1f KB)" % bmp)
    else:
        erg["befunde"].append("Speicher nicht messbar")
    return erg


def main():
    a = sys.argv[1:]
    if "--liste" in a:
        for n, f in F.items():
            print("%-10s %-26s Test %s" % (n, f.get("datei") or "p12 + p06", f["tests"]))
        return

    def opt(n, d=None):
        if n in a:
            i = a.index(n)
            v = a[i + 1]
            del a[i:i + 2]
            return v
        return d
    port = int(opt("--port", "0"))
    if not 8803 <= port <= 8805:
        sys.exit("--port 8803 bis 8805 angeben (8765/8766 sind tabu)")
    koord = opt("--koord", KOORD)
    basis = os.path.abspath(opt("--basis") or tempfile.mkdtemp(prefix="heli-format2-"))
    bilder = os.path.abspath(opt("--bilder") or os.path.join(basis, "bilder"))
    os.makedirs(bilder, exist_ok=True)
    if subprocess.run(["lsof", "-nP", "-iTCP:%d" % port, "-sTCP:LISTEN"], capture_output=True).stdout:
        sys.exit("Port %d ist belegt" % port)
    if not os.path.exists(os.path.join(F2, "p12_voll.heli.lua")):
        sys.exit("test/format2 fehlt: zuerst lua test/format2_dateien.lua")
    wahl = a or list(F)
    unbekannt = [n for n in wahl if n not in F]
    if unbekannt:
        sys.exit("unbekannte Fälle: " + ", ".join(unbekannt))
    print("Heli %s, Simulator X18RS-EU 26.2.0, Port %d, Arbeitsordner %s" % (
        re.search(r'VERSION = "([^"]+)"', open(os.path.join(ss.SKRIPT, "main.lua")).read()).group(1), port, basis))
    alle = []
    for n in wahl:
        t0 = time.time()
        e = lauf(n, F[n], port, basis, bilder, koord)
        alle.append(e)
        s = e.get("speicher")
        print("%s %-10s Test %-17s %4.0f s%s" % ("ok    " if not e["befunde"] else "FEHLER", n, e["tests"], time.time() - t0,
              ("  Lua %.1f KB, luaRamAvailable %.0f KB, luaBitmapsRamAvailable %.0f KB" % s) if s else ""))
        for x in e["befunde"]:
            print("         - " + x)
        for x in e["notizen"]:
            print("         · " + x)
        shutil.rmtree(os.path.join(basis, n), ignore_errors=True)
    json.dump(alle, open(os.path.join(basis, "ergebnis.json"), "w"), indent=1, ensure_ascii=False)
    n = sum(1 for e in alle if e["befunde"])
    print("Bilder: %s\nErgebnis: %s" % (bilder, os.path.join(basis, "ergebnis.json")))
    print("ERGEBNIS: kein Fehler" if not n else "ERGEBNIS: %d von %d Fällen mit Befund" % (n, len(alle)))
    sys.exit(1 if n else 0)


if __name__ == "__main__":
    main()
