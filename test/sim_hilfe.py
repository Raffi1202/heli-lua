"""Heli: gemeinsame Hilfen für die Läufe im fensterlosen Ethos-Simulator (zufallstest.py, bilder.py).

Braucht den Simulator-Treiber sim.cjs im Ordner ETHOS_LUA_WERKZEUGE (Umgebungsvariable).
Das Testmodell liegt bewusst NICHT im Repo (keine Daten von der Funke auf GitHub), sondern in der
Datei aus der Umgebungsvariablen HELI_TESTMODELL (JSON, Eintrag «modell», base64): ein Modell mit
Heli im Vollbild auf Bildschirm 2. In den Bildern zeigt das Widget statt des echten Modellnamens «HELI DEMO».
"""
import base64, binascii, json, os, re, subprocess, sys, tempfile

HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HIER)
SIM = os.path.join(os.path.expanduser(os.environ.get("ETHOS_LUA_WERKZEUGE", "")), "sim.cjs")
SKRIPT = os.path.join(REPO, "src", "heli")
STELLE = "  v.sender = zahl(w.qSender)\n"                 # Zeile in kern.lua (Funktion lesen), an der Testwerte einhaken
TESTMODELL = os.path.expanduser(os.environ.get("HELI_TESTMODELL", ""))   # JSON mit Eintrag «modell» (nicht im Repo)
# Name oben im Widget: in Bildern neutral statt des Modellnamens von der Funke
NAME_ALT = "  local ok, name = pcall(model.name)\n"
NAME_NEU = "  local ok, name = true, \"HELI DEMO\"\n"
FENSTER = "  local W, H = lcd.getWindowSize()\n  local s = min(W / 800, H / 480)"


def lauf(plan):
    """Startet den Simulator mit einer Ablaufliste und gibt sein Protokoll zurück."""
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(plan, f)
    r = subprocess.run(["node", SIM, f.name], capture_output=True, text=True)
    os.unlink(f.name)
    return r.stdout + r.stderr


_modell = None


def modell():
    """Legt das Testmodell dorthin, wo der Simulator sein aktuelles Modell erwartet, und gibt die Datei zurück.

    Welches Modell der Simulator lädt, steht in der radio.bin der FrSky Suite und ändert sich, wenn dort ein anderes
    Modell gewählt wird. Darum kurz starten und den Pfad aus dem Protokoll lesen.
    """
    global _modell
    if _modell:
        return _modell
    probe = lauf({"skripte": [], "abbild": False, "schritte": [{"t": 2500, "ende": True}]})
    treffer = re.search(r"ModelData::read\('USER:/(models/[^']+)'\)", probe)
    if not treffer:
        sys.exit("Modellpfad des Simulators nicht gefunden")
    if not os.path.exists(TESTMODELL):
        sys.exit("Testmodell fehlt: " + TESTMODELL + " (liegt nicht im Repo)")
    daten = json.load(open(TESTMODELL))
    f = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
    # Das Testmodell stammt noch aus der Zeit von «Heli RF»: Widget-Schlüssel «helirf» auf «heli» umstellen (gleiche Länge,
    # mit Nullbytes aufgefüllt; Ethos liest den Schlüssel bis zur ersten Null)
    roh = bytearray(base64.b64decode(daten["modell"]).replace(b"helirf\x00", b"heli\x00\x00\x00"))
    roh[14:16] = binascii.crc_hqx(bytes(roh[16:]), 0).to_bytes(2, "little")   # Prüfsumme der Modelldatei (CRC-16 ab Byte 16)
    roh = bytes(roh)
    json.dump({"/persist/X18RS/" + treffer.group(1): base64.b64encode(roh).decode()}, f)
    f.close()
    _modell = f.name
    return _modell


def fenster(b, h):
    """Textersatz, der eine kleinere Fenstergrösse nachstellt (das Widget zeichnet in die linke obere Ecke)."""
    return ["scripts/heli/kern.lua", FENSTER, "  local W, H = %d, %d\n  local s = min(W / 800, H / 480)" % (b, h)]


def haken(lua):
    """Textersatz, der Lua-Zeilen an der Stelle STELLE einfügt (Testwerte)."""
    return ["scripts/heli/kern.lua", STELLE, STELLE + lua + "\n"]


def plan(ersetze, schritte, abbild=False):
    """Ablauf mit Start (Checkliste bestätigen) und Wechsel auf Bildschirm 2, wo Heli liegt."""
    start = [{"t": 4000, "tipp": [705, 390]}]
    ersetze = [["scripts/heli/kern.lua", NAME_ALT, NAME_NEU]] + list(ersetze)
    return {"skripte": [[SKRIPT, "heli"]], "abbild": abbild, "modell": modell(), "ersetze": ersetze,
            "schritte": start + schritte}
