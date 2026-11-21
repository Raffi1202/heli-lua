#!/usr/bin/env python3
"""Heli: Studio-Prüfungen nach Lua-Studio-Format v1, Abschnitt 12, im Ethos-Simulator (X18RS-EU, 26.2.0).

Aufruf (aus dem Repo-Ordner):
  python3 test/studio_dateien.py                      zuerst: Testdateien in test/studio erzeugen
  python3 test/studio_sim.py --port 8803              alle Fälle
  python3 test/studio_sim.py --port 8803 gueltig_800 grenzen_aus     nur diese Fälle
  python3 test/studio_sim.py --liste                  Fälle auflisten

Optionen:  --port N (8801–8805; 8765/8766 sind tabu)
           --basis DIR   Arbeitsordner für das Simulator-Dateisystem (Standard: neuer Temp-Ordner; nur eigener Ordner)
           --bilder DIR  Ablage der Bilder (Standard: <basis>/bilder)

Je Fall: eigenes Dateisystem aus modell-leer.json (Hilfswerkzeuge, ETHOS_LUA_WERKZEUGE), Heli aus src/heli (bzw. Tag v1.9.1),
Studio-Datei direkt in den Root-Ordner nach scripts/studio/<Kennung>.heli.lua (nicht über writeFile des Plugins,
das kleine Dateien falsch schreibt), Modell «Heli Studio» (Kennung Heli_Studio) mit Heli als einzigem Widget
(800 × 480 = full_screen_borderless, 784 × 316 = full_screen). Danach: Lua-Log ohne Fehler, Zustand aus
<Kennung>.heli.info.json (Abschnitt 14), Hinweis-Zeilen im Log, Alarm «Zellenspannung» (Ansage im Log), Lua-Speicher
per Makro (collectgarbage nach vollem Aufräumen, luaRamAvailable) und genau ein Bild.

Testwerte kommen über einen Haken nach der Zeile STELLE in kern.lua (wie bilder.py). Fehlt die Stelle, laufen die
Fälle ohne Haken und die Alarm-Prüfungen gelten als «nicht prüfbar».
"""
import urllib.error, base64, hashlib, json, os, re, shutil, signal, subprocess, sys, tempfile, time, urllib.parse, urllib.request, zlib

HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HIER)
SKRIPT = os.path.join(REPO, "src", "heli")
STUDIO = os.path.join(HIER, "studio")
ANGRIFFE = os.path.join(HIER, "studio-messen", "dateien")
def umgebung(name, was):
    """Pfad aus einer Umgebungsvariablen; ohne sie bricht der Test mit einer Meldung ab."""
    p = os.environ.get(name)
    if not p:
        sys.exit("Umgebungsvariable %s fehlt: %s" % (name, was))
    return os.path.expanduser(p)


LEER = os.path.join(umgebung("ETHOS_LUA_WERKZEUGE", "Ordner der Hilfswerkzeuge (modell-leer.json, sim.cjs, paket.py)"), "modell-leer.json")
PLUGIN = umgebung("ETHOS_PLUGIN", "Ordner des ethos-tools-Plugins (darin <Version>/run_wasm.js)")


def grundmodell(root):
    """Pfad (unter models/) des Testmodells aus modell-leer.json; vor dem Anlegen weiterer Modelle aufrufen."""
    for d, _, fs in sorted(os.walk(os.path.join(root, "models"))):
        for f in sorted(fs):
            if f.endswith(".bin"):
                return os.path.relpath(os.path.join(d, f), os.path.join(root, "models"))
    raise RuntimeError("kein Modell in models/")
MODELL, KENNUNG = "Heli Studio", "Heli_Studio"
MODELL2, KENNUNG2 = "Heli Zwei (B)", "Heli_Zwei__B_"
STELLE = "  v.sender = zahl(w.qSender)\n"
LAYOUT = {(800, 480): "full_screen_borderless", (784, 316): "full_screen"}
# Testwerte: alles im grünen Bereich ausser der Zelle (3,20 V, unter jeder Werk- und Studio-Grenze)
WERTE = ("v.tele=true v.volt=47.0 v.rpm=1840 v.strom=64 v.bec=8.1 v.mah=1730 v.rssi=-52 v.zellen=12 v.pid=1 v.rate=1"
         " v.temp=62 v.proz=64")
ZELLE_TIEF = WERTE + " v.zelle=3.20"
ZELLE_GUT = WERTE + " v.zelle=3.92"
CFG_DUMP = ('if not TESTCFG then TESTCFG=true local t={} for k,x in pairs(c) do if type(x)=="number" then '
            't[#t+1]=k.."="..x end end table.sort(t) print("TESTCFG "..table.concat(t," ")) end')
FEHLER_LOG = re.compile(r"Heli: Fehler|error|traceback|attempt to|stack overflow|not enough memory|too much|"
                        r"instruction|CPU limit|killed", re.I)


def esc(s):
    return '"' + "".join("\\%d" % b for b in s.encode()) + '"'


# ---------------------------------------------------------------- Simulator

def run_wasm():
    v = sorted((n for n in os.listdir(PLUGIN) if os.path.exists(os.path.join(PLUGIN, n, "run_wasm.js"))),
               key=lambda n: [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", n)])
    if not v:
        sys.exit("run_wasm.js nicht gefunden (Plugin ethos)")
    return os.path.join(PLUGIN, v[-1], "run_wasm.js")


class Sim:
    def __init__(self, port, root, shots):
        self.port, self.root, self.shots, self.kind = port, root, shots, None

    def get(self, cmd, timeout=60, **q):
        u = "http://127.0.0.1:%d/%s?%s" % (self.port, cmd, urllib.parse.urlencode(q))
        return json.load(urllib.request.urlopen(u, timeout=timeout))

    def post(self, cmd, body):
        r = urllib.request.Request("http://127.0.0.1:%d/%s" % (self.port, cmd), data=json.dumps(body).encode(),
                                   headers={"Content-Type": "application/json"})
        return json.load(urllib.request.urlopen(r, timeout=120))

    def laeuft(self):
        try:
            return self.get("status", timeout=2).get("ok") is True
        except Exception:
            return False

    def start(self):
        if self.laeuft():
            raise RuntimeError("Port %d ist belegt" % self.port)
        os.makedirs(self.shots, exist_ok=True)
        self.kind = subprocess.Popen(["node", run_wasm(), "--radio", "X18RS-EU", "--release", "26.2.0", "--serve",
                                      "--port", str(self.port), "--root-directory", self.root, "--shots-dir", self.shots],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(240):
            if self.laeuft():
                break
            if self.kind.poll() is not None:
                raise RuntimeError("Simulator nicht gestartet")
            time.sleep(0.25)
        else:
            raise RuntimeError("Simulator antwortet nicht")
        self.get("wait", ms=1500)

    def ende(self, hart=False):
        if self.kind is None:
            return
        if hart:                                           # «Strom weg»: Prozess sofort beenden
            self.kind.send_signal(signal.SIGKILL)
        else:
            try:
                self.get("quit", timeout=3)
            except Exception:
                pass
        try:
            self.kind.wait(10)
        except subprocess.TimeoutExpired:
            self.kind.kill()
        self.kind = None

    def log(self):
        zeilen, seit = [], 0
        for _ in range(100):
            r = self.get("getLog", since=seit)
            zeilen += [z if isinstance(z, str) else z.get("text", json.dumps(z)) for z in r.get("lines", [])]
            seit = r.get("next", seit)
            if not r.get("more"):
                break
        return zeilen

    def modell(self, name, groesse):
        m = self.get("getModelJson")["model"]
        m["name"] = name
        m["screens"] = [{"key": LAYOUT[groesse], "widgets": [{"key": "heli", "title": False}]}]
        m["mainScreenIndex"] = 0
        m["preflightChecks"].update(analogsChecks=0, failsafeCheck=0, fsCheck=0, switches=0)
        r = self.post("applyModelJson", {"model": m})
        if not r.get("ok"):
            raise RuntimeError("applyModelJson: %s" % r)

    def speicher(self):
        r = self.post("startMacro", {"code": 'collectgarbage("collect") collectgarbage("collect") '
                                             'print("TESTMEM", collectgarbage("count"), '
                                             'system.getMemoryUsage().luaRamAvailable)'})
        for z in r.get("output", []):
            m = re.search(r"TESTMEM\s+([\d.]+)\s+(\d+)", z)
            if m:
                return float(m.group(1)), int(m.group(2)) / 1024
        return None, None

    def bild(self, pfad):
        self.get("screenshot", out=pfad)


# ---------------------------------------------------------------- Dateisystem

def grundstand(root, quelle):
    shutil.rmtree(root, ignore_errors=True)
    leer = json.load(open(LEER))
    for p, inhalt in leer.items():
        z = os.path.join(root, p.split("/", 3)[3])
        os.makedirs(os.path.dirname(z), exist_ok=True)
        open(z, "wb").write(base64.b64decode(inhalt))
    ziel = os.path.join(root, "scripts", "heli")
    if quelle == "src":
        shutil.copytree(SKRIPT, ziel, ignore=shutil.ignore_patterns(".*", "*.luac"))
    else:                                                  # Git-Tag, z. B. v1.9.1
        os.makedirs(ziel)
        a = subprocess.run(["git", "-C", REPO, "archive", quelle, "src/heli"], capture_output=True, check=True).stdout
        subprocess.run(["tar", "-x", "-C", ziel, "--strip-components", "2"], input=a, check=True)
    os.makedirs(os.path.join(root, "scripts", "studio"), exist_ok=True)


def haken(root, lua):
    p = os.path.join(root, "scripts", "heli", "kern.lua")
    t = open(p, encoding="utf-8").read()
    if STELLE not in t:
        return False
    open(p, "w", encoding="utf-8").write(t.replace(STELLE, STELLE + "  " + lua + "\n", 1))
    return True


def studio_pfad(root, kennung=KENNUNG, endung=".heli.lua"):
    return os.path.join(root, "scripts", "studio", kennung + endung)


def schreibe(pfad, inhalt):
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    with open(pfad, "wb") as f:
        f.write(inhalt if isinstance(inhalt, bytes) else inhalt.encode())
    with open(pfad, "rb") as f:                            # nachlesen
        assert f.read() == (inhalt if isinstance(inhalt, bytes) else inhalt.encode()), "Datei falsch geschrieben: " + pfad


def lies(pfad):
    try:
        return open(pfad, "rb").read()
    except OSError:
        return None


def info(root, kennung=KENNUNG):
    t = lies(studio_pfad(root, kennung, ".heli.info.json"))
    if t is None:
        return None
    try:
        return json.loads(t)
    except ValueError:
        return {"_kaputt": t[:200].decode("utf-8", "replace")}


def png_pixel(pfad):
    d = open(pfad, "rb").read()
    o, idat = 8, []
    while o < len(d):
        n = int.from_bytes(d[o:o + 4], "big")
        k = d[o + 4:o + 8]
        c = d[o + 8:o + 8 + n]
        if k == b"IHDR":
            W, H, bpp = int.from_bytes(c[0:4], "big"), int.from_bytes(c[4:8], "big"), 4 if c[9] == 6 else 3
        if k == b"IDAT":
            idat.append(c)
        o += 12 + n
    roh, z = zlib.decompress(b"".join(idat)), W * bpp
    px, vor = bytearray(), bytearray(z)
    for y in range(H):
        f, q = roh[y * (z + 1)], bytearray(roh[y * (z + 1) + 1:(y + 1) * (z + 1)])
        for x in range(z):
            a = q[x - bpp] if x >= bpp else 0
            b = vor[x]
            c = vor[x - bpp] if x >= bpp else 0
            if f == 1: q[x] = (q[x] + a) & 255
            elif f == 2: q[x] = (q[x] + b) & 255
            elif f == 3: q[x] = (q[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                q[x] = (q[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        px += q
        vor = q
    return W, H, bpp, bytes(px)


def bild_abweichung(a, b):
    W, H, bpp, pa = png_pixel(a)
    W2, H2, _, pb = png_pixel(b)
    if (W, H) != (W2, H2):
        return 1.0
    n = sum(1 for i in range(0, len(pa), bpp) if pa[i:i + 3] != pb[i:i + 3])
    return n / (W * H)


# ---------------------------------------------------------------- Fälle

ANGRIFF_GELADEN = {"g16_lang24", "g12_lang24", "typisch", "g16_513", "g16_liste", "g16_tab", "g16_text"}


def faelle():
    """Name -> Beschreibung des Falls."""
    F = {}

    def fall(name, **k):
        k.setdefault("groesse", (784, 316))
        F[name] = k
    fall("keine_datei", datei=None, zustand="fehlt", alarm=True, hinweis=False)
    for g in ((800, 480), (784, 316)):
        s = "%d" % g[0]
        fall("gueltig_" + s, datei="gueltig.heli.lua", groesse=g, zustand="geladen", fehler=0, werte=ZELLE_GUT)
        fall("voll_" + s, datei="voll.heli.lua", groesse=g, zustand="geladen", fehler=0, werte=ZELLE_GUT, speicher=True)
    fall("format99", datei="format99.heli.lua", zustand="zuNeu", alarm=True)
    fall("abgeschnitten", datei="abgeschnitten.heli.lua", zustand="kaputt", alarm=True)
    fall("falsche_typen", datei="falsche_typen.heli.lua", groesse=(800, 480), zustand="geladen", fehler=">0", alarm=True,
         zeilen=True)
    fall("falsche_typen_oben", datei="falsche_typen_oben.heli.lua", zustand="geladen", fehler=">0", alarm=True, zeilen=True)
    fall("grenzen_fehlt", datei="grenzen_fehlt.heli.lua", zustand="geladen", fehler=0, alarm=True)
    fall("grenzen_aus", datei="grenzen_aus.heli.lua", zustand="geladen", fehler=0, alarm=False)
    fall("grenzen_warnung_false", datei="grenzen_warnung_false.heli.lua", zustand="geladen", fehler=0, alarm=True)
    fall("grenzen_richtung", datei="grenzen_richtung.heli.lua", zustand="geladen", fehler=">0", alarm=True, zeilen=True)
    fall("grenzen_ohne_stufen", datei="grenzen_ohne_stufen.heli.lua", zustand="geladen", fehler=0, alarm=False)
    # 1.10.1, Befehlsgrenze: grosse gültige Dateien (100 Wert-Anpassungen, 160 Sensor-Grenzen); Zelle: Werkgrenze
    fall("gross_werte", datei="gross_werte.heli.lua", zustand="geladen", fehler=0, alarm=True)
    fall("gross_grenzen", datei="gross_grenzen.heli.lua", zustand="geladen", fehler=0, alarm=True)
    for n in sorted(os.listdir(ANGRIFFE)) if os.path.isdir(ANGRIFFE) else []:
        name = n[:-4]
        soll = "geladen" if name in ANGRIFF_GELADEN else ("zuNeu" if name == "format99" else "kaputt")
        fall("angriff_" + name, datei=os.path.join(ANGRIFFE, n), zustand=soll, alarm=True, werte=ZELLE_TIEF)
    fall("funke_gueltig", datei="gueltig.heli.lua", funke="gueltig.heli.funke.lua", zustand="geladen", fehler=0,
         funke_bleibt=True)
    fall("funke_neu_rest", datei="gueltig.heli.lua", neu="gueltig.heli.funke.lua", zustand="geladen", fehler=0,
         nachher_funke=True, nachher_neu=False)
    fall("funke_neu_neben", datei="gueltig.heli.lua", funke="gueltig.heli.funke.lua",
         neu="gueltig.heli.funke.lua", zustand="geladen", fehler=0, nachher_funke=True, nachher_neu=False)
    fall("funke_neu_halb", datei="gueltig.heli.lua", neu="HALB", zustand="geladen", fehler=0, nachher_funke=False,
         nachher_neu=False)
    fall("funke_kaputt", datei="gueltig.heli.lua", funke="KAPUTT", zustand="geladen", alarm=True)
    fall("funke_abbruch", datei="gueltig.heli.lua", funke="gueltig.heli.funke.lua", zustand="geladen", abbruch=True)
    fall("modellwechsel", besonders=True, groesse=(800, 480))
    fall("update_191", besonders=True, groesse=(800, 480))
    return F


def inhalt(name):
    if os.path.isabs(name):
        return open(name, "rb").read()
    return open(os.path.join(STUDIO, name), "rb").read()


def pruefe_log(log, erg, zeilen_erwartet=None):
    """Lua-Fehler suchen (Zeilen der Firmware beginnen mit einer sechsstelligen Zeit)."""
    fehl = [z for z in log if FEHLER_LOG.search(z) and not z.startswith("TEST")]
    if fehl:
        erg["befunde"].append("Lua-Log: " + " | ".join(fehl[:3]))
    return [z for z in log if not re.match(r"^\d{6} ", z) and not z.startswith("TEST")]


def auswerten(fall, root, log, erg, hk):
    eigene = pruefe_log(log, erg)
    studio_zeilen = [z for z in eigene if re.search(r"studio", z, re.I)]
    erg["log_studio"] = studio_zeilen[:12]
    i = info(root)
    erg["info"] = i
    soll = fall.get("zustand")
    if i is None:
        erg["befunde"].append("Info-Datei %s.heli.info.json fehlt (Abschnitt 14)" % KENNUNG)
    elif "_kaputt" in i:
        erg["befunde"].append("Info-Datei ist kein gültiges JSON: " + i["_kaputt"])
    else:
        if soll and i.get("studioDatei") != soll:
            erg["befunde"].append("studioDatei = %r, erwartet %r" % (i.get("studioDatei"), soll))
        for k in ("format", "lua", "luaVersion", "formate", "modell", "kennung", "funke", "ethos", "fenster", "studioDatei", "sensoren"):
            if k not in i:
                erg["befunde"].append("Info-Datei: Feld %s fehlt" % k)
        if i.get("lua") != "heli" or i.get("kennung") != KENNUNG or i.get("modell") != MODELL:
            erg["befunde"].append("Info-Datei: lua/kennung/modell = %r/%r/%r" % (i.get("lua"), i.get("kennung"), i.get("modell")))
        b, h = fall["groesse"]
        if not any(f.get("breite") == b and f.get("hoehe") == h for f in i.get("fenster", []) if isinstance(f, dict)):
            erg["befunde"].append("Info-Datei: Fenster %dx%d fehlt in %r" % (b, h, i.get("fenster")))
        n = i.get("fehler", 0)
        if fall.get("fehler") == 0 and n:
            erg["befunde"].append("%s Fehler gemeldet, erwartet 0" % n)
        if fall.get("fehler") == ">0" and not n:
            erg["befunde"].append("kein Fehler gemeldet, erwartet mindestens einer")
        if fall.get("zeilen") and n and len(studio_zeilen) < n:
            erg["befunde"].append("%d Fehler, aber nur %d Log-Zeilen mit «studio» (je Fehler eine Zeile, Abschnitt 3)"
                                  % (n, len(studio_zeilen)))
    if fall.get("hinweis") is False and studio_zeilen:
        erg["befunde"].append("ohne Studio-Datei kein Hinweis erwartet, Log: " + studio_zeilen[0])
    if "alarm" in fall:
        da = any("alarm_zellenspannung" in z for z in log)
        if not hk:
            erg["notizen"].append("Alarm nicht prüfbar (Haken-Stelle fehlt in kern.lua)")
        elif fall.get("werte", ZELLE_TIEF) != ZELLE_TIEF:
            pass
        elif da != fall["alarm"]:
            erg["befunde"].append("Alarm Zellenspannung %s, erwartet %s" % ("kam" if da else "kam nicht",
                                                                              "Alarm" if fall["alarm"] else "keinen"))
        else:
            erg["notizen"].append("Alarm Zellenspannung " + ("kam" if da else "blieb aus") + " (wie erwartet)")


def lauf(name, fall, port, basis, bilder):
    erg = {"fall": name, "befunde": [], "notizen": []}
    root = os.path.join(basis, name)
    b, h = fall["groesse"]
    bild = os.path.join(bilder, "Heli - Studio %dx%d %s.png" % (b, h, name))
    sim = Sim(port, root, os.path.join(basis, "_shots"))
    try:
        if name == "modellwechsel":
            return modellwechsel(sim, root, erg, bild)
        if name == "update_191":
            return update(sim, root, erg, bild, basis)
        grundstand(root, "src")
        werte = fall.get("werte", ZELLE_TIEF if "alarm" in fall else ZELLE_GUT)
        hk = haken(root, werte)
        if fall.get("datei"):
            schreibe(studio_pfad(root), inhalt(fall["datei"]))
        vorher = lies(studio_pfad(root))
        if fall.get("funke"):
            schreibe(studio_pfad(root, endung=".heli.funke.lua"),
                     b"return { format = 1, a = os }" if fall["funke"] == "KAPUTT" else inhalt(fall["funke"]))
        if fall.get("neu"):
            t = inhalt("gueltig.heli.funke.lua")
            schreibe(studio_pfad(root, endung=".heli.funke.neu"), t[:len(t) // 2] if fall["neu"] == "HALB" else inhalt(fall["neu"]))
        funke_vorher = lies(studio_pfad(root, endung=".heli.funke.lua"))
        sim.start()
        sim.modell(MODELL, fall["groesse"])
        sim.get("wait", ms=6000)
        if fall.get("abbruch"):                            # «Strom weg» mitten im Betrieb, dann neu starten
            sim.ende(hart=True)
            erg["notizen"].append("Simulator hart beendet (SIGKILL), neu gestartet")
            sim.start()
            sim.get("wait", ms=6000)
        if fall.get("speicher"):
            erg["speicher"] = sim.speicher()
        log = sim.log()
        sim.bild(bild)
        erg["bild"] = bild
        auswerten(fall, root, log, erg, hk)
        if lies(studio_pfad(root)) != vorher:
            erg["befunde"].append("Studio-Datei wurde verändert (darf nur das Studio schreiben)")
        if fall.get("funke_bleibt") or fall.get("abbruch"):
            if lies(studio_pfad(root, endung=".heli.funke.lua")) != funke_vorher:
                erg["befunde"].append(".funke.lua wurde ohne Änderung an der Funke verändert")
        if "nachher_funke" in fall:
            da = lies(studio_pfad(root, endung=".heli.funke.lua")) is not None
            if da != fall["nachher_funke"]:
                erg["befunde"].append(".funke.lua %s, erwartet %s" % ("da" if da else "fehlt", "da" if fall["nachher_funke"] else "fehlt"))
            elif fall.get("neu") and fall["neu"] != "HALB" and not fall.get("funke") and lies(studio_pfad(root, endung=".heli.funke.lua")) != inhalt(fall["neu"]):
                erg["befunde"].append(".funke.lua hat nicht den Inhalt der übernommenen .funke.neu")
        if "nachher_neu" in fall and (lies(studio_pfad(root, endung=".heli.funke.neu")) is not None) != fall["nachher_neu"]:
            erg["befunde"].append(".funke.neu ist noch da (muss übernommen oder gelöscht sein, Abschnitt 9)")
    except Exception as e:
        erg["befunde"].append("Abbruch des Treibers: %r" % (e,))
    finally:
        sim.ende()
    return erg


def modellwechsel(sim, root, erg, bild):
    """Zwei Modelle (A: gueltig, B: voll), zehnmal hin und her; der Lua-Speicher darf nicht wachsen (12.3)."""
    grundstand(root, "src")
    haken(root, ZELLE_GUT)
    schreibe(studio_pfad(root), inhalt("gueltig.heli.lua"))
    schreibe(studio_pfad(root, KENNUNG2), inhalt("voll.heli.lua"))
    sim.start()
    sim.modell(MODELL, (800, 480))
    sim.get("wait", ms=3000)
    pa = grundmodell(root)                                  # Modell aus modell-leer.json
    quelle = os.path.join(root, "models", pa)
    pb = "MOTOR/heli_zwei.bin"
    shutil.copyfile(quelle, os.path.join(root, "models", pb))
    pfade = []
    r = None
    for kandidat in ("models/" + pb, pb, "/models/" + pb, "USER:/models/" + pb):
        try:
            r = sim.get("loadModel", path=kandidat)
        except urllib.error.HTTPError as e:                # ungültiger Pfad: 400
            r = {"ok": False, "fehler": "%s %s" % (kandidat, e)}
        if r.get("ok"):
            pfade = [kandidat.replace(pb, pa), kandidat]
            break
    if not pfade:
        erg["befunde"].append("loadModel: kein Pfad angenommen (%r)" % r)
        return erg
    sim.get("wait", ms=2000)
    n_probe = len(sim.log())                               # Lesefehler der verworfenen Pfad-Versuche nicht werten
    erg["notizen"].append("Modellpfad für loadModel: " + pfade[1])
    sim.modell(MODELL2, (800, 480))
    sim.get("wait", ms=4000)
    mem = []
    for i in range(20):
        r = sim.get("loadModel", path=pfade[i % 2])
        if not r.get("ok"):
            erg["befunde"].append("loadModel %s: %r" % (pfade[i % 2], r))
            break
        sim.get("wait", ms=5000)
        mem.append(sim.speicher())
    log = sim.log()[n_probe:]
    sim.bild(bild)
    erg["bild"] = bild
    pruefe_log(log, erg)
    a, b = info(root), info(root, KENNUNG2)
    if not a or a.get("studioDatei") != "geladen":
        erg["befunde"].append("Modell A: studioDatei %r" % (a and a.get("studioDatei")))
    if not b or b.get("studioDatei") != "geladen":
        erg["befunde"].append("Modell B: studioDatei %r" % (b and b.get("studioDatei")))
    werte = [m[0] for m in mem if m[0] is not None]
    erg["speicher_verlauf"] = ["%.1f" % x for x in werte]
    if len(werte) >= 6:
        # nach dem Einschwingen (erste 2 Wechsel) gleiche Modelle vergleichen: A mit A, B mit B
        wachs = max(werte[-2] - werte[2], werte[-1] - werte[3])
        erg["notizen"].append("Speicher nach Wechsel 3/4: %.1f/%.1f KB, nach Wechsel 19/20: %.1f/%.1f KB (Zuwachs %.1f KB)"
                              % (werte[2], werte[3], werte[-2], werte[-1], wachs))
        if wachs > 8:
            erg["befunde"].append("Speicher wächst beim Modellwechsel um %.1f KB" % wachs)
    else:
        erg["befunde"].append("Speicher nicht messbar")
    return erg


def update(sim, root, erg, bild, basis):
    """Update von v1.9.1 ohne Studio-Datei: gleiche Einstellungen, gleiches Bild, keine Fehler, kein Hinweis (12.4)."""
    grundstand(root, "v1.9.1")
    hk = haken(root, ZELLE_GUT + " " + CFG_DUMP)
    sim.start()
    sim.modell(MODELL, (800, 480))
    sim.get("wait", ms=5000)
    alt_log = sim.log()
    alt_bild = os.path.join(basis, "_update_alt.png")
    sim.bild(alt_bild)
    sim.ende()
    # gleicher Speicher, neue Version (Widget-Speicher des Modells bleibt)
    shutil.rmtree(os.path.join(root, "scripts", "heli"))
    shutil.copytree(SKRIPT, os.path.join(root, "scripts", "heli"), ignore=shutil.ignore_patterns(".*", "*.luac"))
    hk2 = haken(root, ZELLE_GUT + " " + CFG_DUMP)
    sim.start()
    sim.get("wait", ms=6000)
    log = sim.log()
    sim.bild(bild)
    erg["bild"] = bild
    pruefe_log(alt_log, erg)
    auswerten({"zustand": "fehlt", "hinweis": False, "groesse": (800, 480)}, root, log, erg, hk2)
    alt = [z for z in alt_log if z.startswith("TESTCFG")]
    neu = [z for z in log if z.startswith("TESTCFG")]
    if hk and hk2 and alt and neu:
        da, dn = dict(x.split("=") for x in alt[0].split()[1:]), dict(x.split("=") for x in neu[0].split()[1:])
        anders = ["%s %s->%s" % (k, da[k], dn.get(k)) for k in da if dn.get(k) != da[k]]
        if anders:
            erg["befunde"].append("Einstellungen nach dem Update anders: " + ", ".join(anders[:8]))
        else:
            erg["notizen"].append("%d Einstellungen gleich wie in 1.9.1" % len(da))
    else:
        erg["notizen"].append("Einstellungen nicht verglichen (Haken fehlt)")
    try:
        a = bild_abweichung(alt_bild, bild)
        erg["notizen"].append("Bild weicht von 1.9.1 um %.2f %% der Pixel ab" % (100 * a))
        if a > 0.01:
            erg["befunde"].append("Bild nach dem Update anders als 1.9.1 (%.2f %% der Pixel), ansehen: %s" % (100 * a, bild))
    except Exception as e:
        erg["notizen"].append("Bildvergleich nicht möglich: %r" % (e,))
    return erg


def main():
    a = sys.argv[1:]
    F = faelle()
    if "--liste" in a:
        for n, f in F.items():
            print("%-26s %s" % (n, f.get("datei") and os.path.basename(f["datei"]) or ""))
        return
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
    basis = os.path.abspath(opt("--basis") or tempfile.mkdtemp(prefix="heli-studio-"))
    bilder = os.path.abspath(opt("--bilder") or os.path.join(basis, "bilder"))
    os.makedirs(bilder, exist_ok=True)
    if subprocess.run(["lsof", "-nP", "-iTCP:%d" % port, "-sTCP:LISTEN"], capture_output=True).stdout:
        sys.exit("Port %d ist belegt" % port)
    if not os.path.exists(os.path.join(STUDIO, "gueltig.heli.lua")):
        sys.exit("test/studio fehlt: zuerst python3 test/studio_dateien.py")
    wahl = a or list(F)
    unbekannt = [n for n in wahl if n not in F]
    if unbekannt:
        sys.exit("unbekannte Fälle: " + ", ".join(unbekannt))
    print("Heli %s, Simulator X18RS-EU 26.2.0, Port %d, Arbeitsordner %s" % (
        re.search(r'VERSION = "([^"]+)"', open(os.path.join(SKRIPT, "main.lua")).read()).group(1), port, basis))
    if not os.path.exists(os.path.join(SKRIPT, "studio.lua")):
        print("HINWEIS: src/heli/studio.lua fehlt noch: Fälle mit Studio-Datei melden Befunde (Info-Datei fehlt usw.)")
    alle = []
    for n in wahl:
        t0 = time.time()
        e = lauf(n, F[n], port, basis, bilder)
        alle.append(e)
        s = e.get("speicher")
        print("%s %-28s %4.0f s%s" % ("ok    " if not e["befunde"] else "FEHLER", n, time.time() - t0,
                                      ("  Lua-Speicher %.1f KB, frei %.0f KB" % s) if s and s[0] else ""))
        for x in e["befunde"]:
            print("         - " + x)
        for x in e["notizen"]:
            print("         · " + x)
        if e.get("log_studio") and (e["befunde"] or "zeilen" in F[n]):
            print("         · Log: " + " | ".join(e["log_studio"][:4]))
        shutil.rmtree(os.path.join(basis, n), ignore_errors=True)
    json.dump(alle, open(os.path.join(basis, "ergebnis.json"), "w"), indent=1, ensure_ascii=False)
    n = sum(1 for e in alle if e["befunde"])
    print("Bilder: %s\nErgebnis: %s" % (bilder, os.path.join(basis, "ergebnis.json")))
    print("ERGEBNIS: kein Fehler" if not n else "ERGEBNIS: %d von %d Fällen mit Befund" % (n, len(alle)))
    sys.exit(1 if n else 0)


if __name__ == "__main__":
    main()
