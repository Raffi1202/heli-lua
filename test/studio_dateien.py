#!/usr/bin/env python3
"""Heli: erzeugt die Studio-Testdateien (Lua-Studio-Format v1, Abschnitte 4 bis 6 und 12) in test/studio/.

Aufruf:  python3 test/studio_dateien.py

Alle Texte und Text-Schlüssel stehen vollständig als Dezimal-Escapes, ganze Zahlen ohne Punkt, andere mit «%.4f».
Danach prüft das Skript jede Datei mit der Referenz-Ladefunktion (Lua 5.4) und vergleicht das Ergebnis mit der
Erwartung (geladen / kaputt / zuNeu). Gültige Dateien halten die Grenzen des Studios ein (15 KB, 1100 Elemente,
220 Tabellen). Liegt studio/beschreibung.json schon vor, nimmt der Generator Einstellungen und Werkgrenzen von dort.

Dateien:
  gueltig.heli.lua            2 Ansichten (800 × 480 und 784 × 316), Einstellungen, Werte, Grenzen; 0 Fehler
  gueltig.heli.funke.lua      Änderungen an der Funke (Kapazität, Warnung Zelle)
  voll.heli.lua               Abschnitt 12.2: bis an die Studio-Grenzen gefüllt, 2 × 16 Plätze, 2 Kurven je Ansicht,
                                alle 6 Darstellungsarten, 8 Sensoren (einer mit Physical ID); 0 Fehler
  falsche_typen.heli.lua      jedes Feld in Einstellungen, Werten, Grenzen, Ansicht und Platz mit falschem Typ
  falsche_typen_oben.heli.lua jedes Feld der obersten Ebene mit falschem Typ
  grenzen_fehlt.heli.lua      kein Eintrag für lua:zelle: Werkgrenze gilt (Alarm bei 3,2 V)
  grenzen_aus.heli.lua        lua:zelle mit aus = true: kein Alarm
  grenzen_warnung_false.heli.lua  lua:zelle warnung = false, alarm = 3,5: Alarm kommt
  grenzen_richtung.heli.lua   lua:zelle mit richtung «ueber»: Werkgrenze plus Hinweis, Alarm kommt
  grenzen_ohne_stufen.heli.lua    lua:zelle = { ansage = false }: beide Stufen aus, kein Alarm
  format99.heli.lua           gültig, aber format = 99: «zu neu»
  abgeschnitten.heli.lua      gueltig.heli.lua nach der Hälfte abgeschnitten: «kaputt»
  gross_werte.heli.lua        Befehlsgrenze: 48 Wert-Anpassungen für Sensoren (gültig, 0 Fehler). Bis 1.10.1 waren
                                es 100; ab 1.11.0 (Format 2, Regel 7.2) gelten höchstens 48 Einträge je Liste.
  gross_grenzen.heli.lua      Befehlsgrenze: 48 Grenzen für Sensoren (gültig, 0 Fehler, Alarm ab 100; bis 1.10.1: 160)
  ueber48.heli.lua            1.11.0, Format 2 Regel 7.2: je 60 Einträge in werte, grenzen und einstellungen;
                                geladen, je Liste 12 verworfen und 1 Hinweis (3 Fehler)
                                In diesen Dateien stehen Texte kurz (nur «:» als Escape \058), damit sie unter 15 KB
                                und 1100 Elementen bleiben.
"""
import json, os, re, subprocess, sys

HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HIER)
ZIEL = os.path.join(HIER, "studio")
LUA = "/opt/homebrew/opt/lua@5.4/bin/lua"
REFERENZ = os.environ.get("STUDIO_REF") or os.path.join(os.path.expanduser(os.environ.get("FORMAT2_ORDNER", "")),
    "Lua-Studio-Format v1 - Referenz studio_laden.lua")
BESCHREIBUNG = os.path.join(REPO, "studio", "beschreibung.json")

GRENZE_BYTE, GRENZE_ELEMENTE, GRENZE_TABELLEN = 15 * 1024, 1100, 220   # Grenzen des Studios (Abschnitt 4)
SCHLUESSELWOERTER = set("and break do else elseif end for function goto if in local nil not or repeat then until "
                        "while return true false".split())


class Roh:
    """Unveränderter Lua-Text (nur für absichtlich falsche Dateien)."""
    def __init__(self, t):
        self.t = t


def text(s):
    return '"' + "".join("\\%d" % b for b in s.encode("utf-8")) + '"'


def schluessel(k):
    if re.fullmatch(r"[a-z][A-Za-z0-9_]{0,23}", k) and k not in SCHLUESSELWOERTER:
        return k
    return "[" + text(k) + "]"


def lua(v):
    """Python-Wert als Lua-Tabellen-Literal nach Abschnitt 4."""
    if isinstance(v, Roh):
        return v.t
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return "%d" % v
    if isinstance(v, float):
        return "%.4f" % v
    if isinstance(v, str):
        return text(v)
    if isinstance(v, dict):
        return "{ " + ", ".join(schluessel(k) + " = " + lua(x) for k, x in v.items()) + " }" if v else "{}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x) for x in v) + " }" if v else "{}"
    raise TypeError(type(v))


def datei(d):
    return "return " + lua(d) + "\n"


def zaehle(t):
    """Elemente und Tabellen wie in studioLaden: Kommas + «=» + «{» ausserhalb von Texten."""
    o = re.sub(r'"[^"]*"', '""', t)
    return o.count(",") + o.count("=") + o.count("{"), o.count("{")


# ---------------------------------------------------------------- Inhalte

KOPF = {"format": 1, "studio": "0.2.0", "funke": "X18RS", "modell": "Heli Studio", "luaVersion": "1.10.0"}

# Einstellungen ab Werk (snake_case der Widget-Namen); aus beschreibung.json, wenn vorhanden
EINST_ERSATZ = {"zellen": 12, "kapaz": 5000, "rpm_max": 2600, "akkutyp": 1}
GRENZEN_ERSATZ = {
    "lua:akku_proz": {"richtung": "unter", "warnung": 35, "alarm": 25, "ansage": True, "vibration": True},
    "lua:zelle": {"richtung": "unter", "warnung": 3.6, "alarm": 3.5, "ansage": True, "vibration": True},
    "lua:reglertemp": {"richtung": "ueber", "warnung": 70, "alarm": 80, "ansage": True, "vibration": True},
    "lua:bec": {"richtung": "unter", "warnung": 7.2, "alarm": 7.0, "ansage": True, "vibration": True},
    "lua:verbraucht": {"richtung": "ueber", "warnung": 3500, "alarm": 4000, "ansage": True, "vibration": True},
}
WERTE = ["akku_proz", "zelle", "bec", "reglertemp", "verbraucht", "drehzahl", "strom", "spannung", "leistung", "rssi",
         "gas_proz", "pid_profil", "rate_profil", "flugzeit", "fluege", "governor", "scharf"]


def beschreibung():
    """Einstellungen (Werkwerte) und Werkgrenzen aus studio/beschreibung.json, sonst die Ersatzwerte oben."""
    if not os.path.exists(BESCHREIBUNG):
        return dict(EINST_ERSATZ), dict(GRENZEN_ERSATZ), None
    b = json.load(open(BESCHREIBUNG, encoding="utf-8"))
    einst = {}
    for e in b.get("einstellungen", []):
        if e.get("art") in ("z", "w") and isinstance(e.get("werk"), (int, float)) and not isinstance(e.get("werk"), bool):
            einst[e["s"]] = e["werk"]
        elif e.get("art") == "b" and isinstance(e.get("werk"), bool):
            einst[e["s"]] = e["werk"]
    for k, v in EINST_ERSATZ.items():          # Testwerte (gleich wie im Simulator-Test erwartet), wenn es sie gibt
        if k in einst:
            einst[k] = v
    grenzen = (b.get("standard") or {}).get("grenzen") or dict(GRENZEN_ERSATZ)
    s = {w.get("s") for w in b.get("werte", [])}
    fehlend = [w for w in WERTE if w not in s]
    return einst, grenzen, fehlend


def platz(x, y, b, h, w, darst, titel):
    return {"x": x, "y": y, "b": b, "h": h, "w": w, "darstellung": darst, "titel": titel}


def gueltig(einst, grenzen):
    d = dict(KOPF)
    d["einstellungen"] = dict(einst)
    d["werte"] = {"lua:drehzahl": {"faktor": 1.0, "stellen": 0}, "lua:spannung": {"stellen": 1, "name": "Akku V"}}
    d["grenzen"] = {k: grenzen[k] for k in ("lua:akku_proz", "lua:zelle", "lua:reglertemp") if k in grenzen}
    voll = [
        platz(0, 0, 200, 200, "lua:akku_proz", "ring", "Akku"),
        platz(200, 0, 200, 200, "lua:drehzahl", "ring", "Drehzahl"),
        dict(platz(400, 0, 400, 200, "lua:strom", "kurve", "Strom"), kurveS=120),
        platz(0, 200, 200, 100, "lua:zelle", "zahl", "Zelle"),
        platz(200, 200, 200, 100, "lua:bec", "zahl", "BEC"),
        dict(platz(400, 200, 400, 100, "lua:verbraucht", "balken_w", "Verbraucht"), min=0, max=5000),
        platz(0, 300, 400, 90, "lua:governor", "status", "Governor"),
        platz(400, 300, 400, 90, "lua:scharf", "status", "Motor"),
        dict(platz(0, 390, 266, 90, "lua:flugzeit", "zahl", "Flugzeit"), zusatz="keine"),
        dict(platz(266, 390, 267, 90, "lua:reglertemp", "zahl", "Regler"), zusatz="max"),
        platz(533, 390, 267, 90, "lua:fluege", "zahl", "Flüge"),
    ]
    kompakt = [
        platz(0, 0, 196, 158, "lua:akku_proz", "ring", "Akku"),
        platz(196, 0, 196, 158, "lua:drehzahl", "ring", "Drehzahl"),
        dict(platz(392, 0, 392, 158, "lua:strom", "kurve", "Strom"), kurveS=60),
        platz(0, 158, 196, 79, "lua:zelle", "zahl", "Zelle"),
        dict(platz(196, 158, 196, 79, "lua:reglertemp", "zahl", "Regler"), zusatz="max"),
        platz(392, 158, 196, 79, "lua:governor", "status", "Governor"),
        platz(588, 158, 196, 79, "lua:scharf", "status", "Motor"),
        platz(0, 237, 196, 79, "lua:verbraucht", "zahl", "Verbraucht"),
        platz(196, 237, 196, 79, "lua:bec", "zahl", "BEC"),
        dict(platz(392, 237, 392, 79, "lua:gas_proz", "balken_w", "Gas"), min=0, max=100),
    ]
    d["ansichten"] = [{"breite": 800, "hoehe": 480, "plaetze": voll}, {"breite": 784, "hoehe": 316, "plaetze": kompakt}]
    return d


SENSOREN = [   # 8 eigene Sensoren (AppID hexadezimal, Grossbuchstaben), einer mit Physical ID
    ("sensor:0500:0", "RPM", "U/min", 0), ("sensor:0210:0", "VFAS", "V", 1), ("sensor:0200:0", "Strom", "A", 1),
    ("sensor:0400:0", "Temp1", "°C", 0), ("sensor:0600:0", "Fuel", "%", 0), ("sensor:0300:0", "Zellen", "V", 2),
    ("sensor:F101:0", "RSSI", "dB", 0), ("sensor:0B50:0:3", "BEC 2", "V", 1),
]
FARBEN = [(40, 200, 120), (60, 140, 255), (255, 200, 0), (200, 80, 255)]


def voll(einst, grenzen):
    """Abschnitt 12.2: so viele Angaben, wie die Studio-Grenzen erlauben."""
    d = dict(KOPF)
    d["einstellungen"] = dict(einst)
    d["werte"] = {k: {"faktor": 1.0, "versatz": 0.0, "einheit": e, "stellen": st, "name": n} for k, n, e, st in SENSOREN}
    d["werte"]["lua:drehzahl"] = {"faktor": 0.5, "stellen": 0}
    d["grenzen"] = dict(grenzen)
    d["grenzen"]["sensor:0400:0"] = {"richtung": "ueber", "warnung": 90, "alarm": 100, "ansage": True, "vibration": True}
    d["grenzen"]["sensor:0B50:0:3"] = {"richtung": "unter", "warnung": 7.2, "alarm": 6.8, "ansage": False, "vibration": True}
    s = [k for k, *_ in SENSOREN]
    # 800 × 480: 4 × 4 Felder zu 200 breit unter der reservierten Kopfzeile (y 0–57, beschreibung.json «reserviert»),
    # Reihenhöhen 110/110/110/92 (Mindestgrössen Abschnitt 7: Ring 110, Kurve 180 × 90, Balken senkrecht 50 × 110)
    art_v = ["kurve", "kurve", "ring", "ring", "balken_s", "balken_w", "status", "status",
             "ring", "balken_w", "balken_s", "zahl", "zahl", "zahl", "zahl", "zahl"]
    wert_v = ["lua:strom", "lua:drehzahl", "lua:akku_proz", s[0], "lua:gas_proz", s[1], "lua:governor", "lua:scharf",
              s[3], s[4], s[5], s[7], "lua:zelle", "lua:bec", "lua:flugzeit", s[2]]
    reihe_y, reihe_h = [58, 168, 278, 388], [110, 110, 110, 92]
    pv = [platz(200 * (i % 4), reihe_y[i // 4], 200, reihe_h[i // 4], wert_v[i], art_v[i], "Platz %d" % (i + 1))
          for i in range(16)]
    # 784 × 316 (Mindestgrössen × 784/800: Ring 108, Kurve 176 × 88, Balken senkrecht 49 × 108, Zahl 88 × 49)
    lage_k = [(0, 0, 180, 110, "kurve"), (180, 0, 180, 110, "kurve"), (360, 0, 110, 110, "ring"),
              (470, 0, 56, 110, "balken_s"), (526, 0, 56, 110, "balken_s"), (582, 0, 98, 55, "zahl"),
              (582, 55, 98, 55, "zahl"), (680, 0, 104, 55, "zahl"), (680, 55, 104, 55, "zahl"),
              (0, 110, 196, 50, "balken_w"), (196, 110, 196, 50, "balken_w"), (392, 110, 196, 50, "balken_w"),
              (588, 110, 196, 50, "balken_w"), (0, 160, 196, 50, "status"), (196, 160, 196, 50, "status"),
              (392, 160, 196, 50, "zahl")]
    wert_k = ["lua:leistung", s[6], "lua:akku_proz", "lua:gas_proz", s[4], "lua:zelle", "lua:bec", "lua:pid_profil",
              "lua:rate_profil", "lua:verbraucht", "lua:spannung", s[1], "lua:rssi", "lua:governor", "lua:scharf", s[7]]
    # 784 × 316: alles um die reservierte Leiste (y 0–33) nach unten
    pk = [platz(x, y + 34, b, h, wert_k[i], a, "Kompakt %d" % (i + 1)) for i, (x, y, b, h, a) in enumerate(lage_k)]
    d["ansichten"] = [{"breite": 800, "hoehe": 480, "plaetze": pv}, {"breite": 784, "hoehe": 316, "plaetze": pk}]

    # freiwillige Felder reihum ergänzen, solange die Grenzen des Studios halten
    def passt():
        t = datei(d)
        e, tb = zaehle(t)
        return len(t.encode()) <= GRENZE_BYTE and e <= GRENZE_ELEMENTE and tb <= GRENZE_TABELLEN
    zusatz = [
        ("min", lambda p, i: 0), ("max", lambda p, i: 100 + i), ("farbe", lambda p, i: list(FARBEN[i % 4])),
        ("stufen", lambda p, i: [{"ab": 20, "farbe": [255, 200, 0]}, {"ab": 50.5, "farbe": [120, 220, 80]},
                                 {"ab": 80, "farbe": [40, 200, 120]}]),
        ("zusatz", lambda p, i: ["min", "max", "mittel", "keine"][i % 4]),
        ("kurveS", lambda p, i: 600 if p["darstellung"] == "kurve" else None),
        ("hintergrund", lambda p, i: [10, 20, 40]),
        ("farbeWarn", lambda p, i: [255, 160, 0]), ("farbeAlarm", lambda p, i: [230, 40, 40]),
    ]
    for feld, wert in zusatz:
        for i, p in enumerate(pv + pk):
            v = wert(p, i)
            if v is None:
                continue
            p[feld] = v
            if not passt():
                del p[feld]
    return d


def falsche_typen():
    """Jedes Feld unterhalb der obersten Ebene mit falschem Typ (Abschnitt 6, Spalte «Fehler»)."""
    d = dict(KOPF)
    d["einstellungen"] = {"kapaz": "5000", "zellen": True, "rpm_max": {}, "akkutyp": 1.5}
    d["werte"] = {"lua:drehzahl": {"faktor": "x", "versatz": True, "einheit": 5, "stellen": 1.5, "name": {}},
                  "lua:strom": "x"}
    d["grenzen"] = {"lua:zelle": {"richtung": 1, "warnung": "x", "alarm": {}, "ansage": 1, "vibration": "x", "aus": 1},
                    "lua:reglertemp": 5}
    d["ansichten"] = [
        {"breite": "800", "hoehe": 480, "plaetze": []},                       # Ansicht verworfen
        {"breite": 800, "hoehe": 480, "plaetze": [
            {"x": "0", "y": 0, "b": 200, "h": 120, "w": "lua:zelle"},           # Platz verworfen
            {"x": 0, "y": 0, "b": 200, "h": 120, "w": 5},                        # Platz verworfen
            {"x": 0.5, "y": 0, "b": 200, "h": 120, "w": "lua:zelle"},            # Platz verworfen (keine ganze Zahl)
            {"x": 0, "y": 0, "b": 400, "h": 200, "w": "lua:akku_proz", "darstellung": 5, "titel": 5, "min": "x",
             "max": True, "farbe": "x", "farbeWarn": [1, 2], "farbeAlarm": [256, 0, 0], "hintergrund": [1.5, 0, 0],
             "zusatz": 5, "kurveS": "x", "stufen": "x"},
            {"x": 400, "y": 0, "b": 400, "h": 200, "w": "lua:strom", "darstellung": "kurve", "kurveS": 1.5,
             "stufen": [{"ab": "x", "farbe": [1, 2, 3]}]},
            "x",                                                                 # Platz ist keine Tabelle
        ]},
        {"breite": 784, "hoehe": 316, "plaetze": "x"},
    ]
    return d


def falsche_typen_oben():
    return {"format": 1, "studio": 1, "funke": True, "modell": {}, "luaVersion": 2, "einstellungen": "x",
            "werte": 5, "grenzen": True, "ansichten": "x"}


def mit_grenzen(einst, g):
    d = dict(KOPF)
    d["einstellungen"] = dict(einst)
    d["grenzen"] = g
    return d


def kurz(t):
    """Text mit möglichst wenig Escapes: Buchstaben und Ziffern bleiben, alles andere als \ddd (immer 3 Ziffern)."""
    return '"' + "".join(c if c.isascii() and c.isalnum() else "\\%03d" % ord(c) for c in t) + '"'


def gross(einst, art, n=48):
    """Grosse gültige Datei (Befehlsgrenze): n Wert-Anpassungen bzw. n Grenzen für Sensoren (höchstens 48 gültig)."""
    d = dict(KOPF)
    d["einstellungen"] = {k: v for k, v in einst.items() if k in ("zellen", "kapaz")}
    t = datei(d).rstrip()[:-1].rstrip()                   # ohne die schliessende Klammer
    teile = []
    if art == "werte":
        for i in range(n):
            k = "sensor:%04X:%d" % (0x0A00 + i // 4, i % 4)
            teile.append("[%s] = { faktor = %d, einheit = %s, stellen = %d, name = %s }"
                         % (kurz(k), 2 + i % 3, kurz("V"), i % 4, kurz("Sensor%d" % i)))
        return t + ", werte = { " + ", ".join(teile) + " } }\n"
    for i in range(n):
        k = "sensor:%04X:%d" % (0x0A00 + i // 4, i % 4)
        teile.append("[%s] = { richtung = %s, alarm = 100 }" % (kurz(k), kurz("ueber")))
    return t + ", grenzen = { " + ", ".join(teile) + " } }\n"


def ueber48():
    """Format 2, Regel 7.2: je 60 Einträge in werte, grenzen und einstellungen (12 je Liste zu viel)."""
    t = datei(dict(KOPF)).rstrip()[:-1].rstrip()
    w = ", ".join("[%s] = { faktor = 2 }" % kurz("sensor:%04X:%d" % (0x0B00 + i // 4, i % 4)) for i in range(60))
    g = ", ".join("[%s] = { richtung = %s, alarm = 100 }" % (kurz("sensor:%04X:%d" % (0x0C00 + i // 4, i % 4)), kurz("ueber"))
                  for i in range(60))
    e = ", ".join("x%d = 1" % i for i in range(60))      # unbekannte Einstellungen zählen mit (ohne Hinweis überlesen)
    return t + ", einstellungen = { " + e + " }, werte = { " + w + " }, grenzen = { " + g + " } }\n"


# ---------------------------------------------------------------- Prüfung mit der Referenzfunktion

PRUEF_LUA = r'''
local laden = dofile(arg[1])
for i = 2, #arg do
  local d, g = laden(arg[i], 1)
  print(arg[i]:match("[^/]+$") .. "\t" .. (d and "geladen" or g))
end
'''


def main():
    if not os.path.exists(REFERENZ):
        sys.exit("Referenz fehlt: " + REFERENZ)
    einst, grenzen, fehlend = beschreibung()
    if fehlend is None:
        print("Hinweis: studio/beschreibung.json fehlt noch, Einstellungen und Werkgrenzen aus dem Ersatz im Skript")
    elif fehlend:
        print("Hinweis: diese Wert-Schlüssel fehlen in beschreibung.json:", ", ".join(fehlend))
    os.makedirs(ZIEL, exist_ok=True)
    g_gueltig = gueltig(einst, grenzen)
    dateien = {   # Name: (Inhalt, Erwartung, Studio-Grenzen einhalten)
        "gueltig.heli.lua": (datei(g_gueltig), "geladen", True),
        "gueltig.heli.funke.lua": (datei({"format": 1, "einstellungen": {"kapaz": 4500},
                                            "grenzen": {"lua:zelle": {"warnung": 3.7}}}), "geladen", True),
        "voll.heli.lua": (datei(voll(einst, grenzen)), "geladen", True),
        "falsche_typen.heli.lua": (datei(falsche_typen()), "geladen", True),
        "falsche_typen_oben.heli.lua": (datei(falsche_typen_oben()), "geladen", True),
        "grenzen_fehlt.heli.lua": (datei(mit_grenzen(einst, {"lua:akku_proz": grenzen.get("lua:akku_proz", GRENZEN_ERSATZ["lua:akku_proz"])})), "geladen", True),
        "grenzen_aus.heli.lua": (datei(mit_grenzen(einst, {"lua:zelle": dict(GRENZEN_ERSATZ["lua:zelle"], aus=True)})), "geladen", True),
        "grenzen_warnung_false.heli.lua": (datei(mit_grenzen(einst, {"lua:zelle": {"richtung": "unter", "warnung": False, "alarm": 3.5,
                                                                                      "ansage": True, "vibration": True}})), "geladen", True),
        "grenzen_richtung.heli.lua": (datei(mit_grenzen(einst, {"lua:zelle": {"richtung": "ueber", "warnung": 3.6, "alarm": 3.5,
                                                                                 "ansage": True, "vibration": True}})), "geladen", True),
        "grenzen_ohne_stufen.heli.lua": (datei(mit_grenzen(einst, {"lua:zelle": {"ansage": False}})), "geladen", True),
        "format99.heli.lua": (datei(dict(g_gueltig, format=99)), "zuNeu", True),
    }
    dateien["gross_werte.heli.lua"] = (gross(einst, "werte"), "geladen", True)
    dateien["gross_grenzen.heli.lua"] = (gross(einst, "grenzen"), "geladen", True)
    dateien["ueber48.heli.lua"] = (ueber48(), "geladen", True)
    t = dateien["gueltig.heli.lua"][0]
    dateien["abgeschnitten.heli.lua"] = (t[:len(t) // 2], "kaputt", False)
    fehler = 0
    for n, (inhalt, _, grenze) in dateien.items():
        with open(os.path.join(ZIEL, n), "w", encoding="ascii") as f:   # nur ASCII: alle Texte sind Escapes
            f.write(inhalt)
        e, tb = zaehle(inhalt)
        b = len(inhalt.encode())
        zu_gross = grenze and (b > GRENZE_BYTE or e > GRENZE_ELEMENTE or tb > GRENZE_TABELLEN)
        if zu_gross:
            fehler += 1
        print("%-34s %6d B %5d Elemente %4d Tabellen%s" % (n, b, e, tb, "  ÜBER DER STUDIO-GRENZE" if zu_gross else ""))
    pfade = [os.path.join(ZIEL, n) for n in dateien]
    r = subprocess.run([LUA, "-", REFERENZ] + pfade, input=PRUEF_LUA, capture_output=True, text=True)
    if r.returncode:
        sys.exit("Lua-Prüfung lief nicht: " + r.stderr)
    for zeile in r.stdout.splitlines():
        n, ist = zeile.split("\t")
        soll = dateien[n][1]
        ok = ist == soll
        fehler += 0 if ok else 1
        print(("ok     " if ok else "FEHLER ") + "%s: %s (erwartet %s)" % (n, ist, soll))
    # voll: Abschnitt 12.2 nachzählen
    v = voll(einst, grenzen)
    arten = {p["darstellung"] for a in v["ansichten"] for p in a["plaetze"]}
    kurven = [sum(p["darstellung"] == "kurve" for p in a["plaetze"]) for a in v["ansichten"]]
    sens = {p["w"] for a in v["ansichten"] for p in a["plaetze"] if p["w"].startswith("sensor:")}
    ok = (len(arten) == 6 and kurven == [2, 2] and [len(a["plaetze"]) for a in v["ansichten"]] == [16, 16]
          and len(sens) == 8 and any(k.count(":") == 3 for k in sens))
    fehler += 0 if ok else 1
    print(("ok     " if ok else "FEHLER ") + "voll: 2 × 16 Plätze, Kurven je Ansicht %s, %d Darstellungsarten, %d Sensoren"
          % (kurven, len(arten), len(sens)))
    print("ERGEBNIS: kein Fehler" if not fehler else "ERGEBNIS: %d Fehler" % fehler)
    sys.exit(1 if fehler else 0)


if __name__ == "__main__":
    main()
