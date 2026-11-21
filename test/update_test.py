#!/usr/bin/env python3
"""Heli: Update-Test. Holt kern.lua aus jedem Versions-Tag ab v1.5.0, lässt die alte Version Einstellungen
schreiben und die aktuelle (src/heli/kern.lua) sie lesen. Nichts darf verloren gehen.

Aufruf:  python3 test/update_test.py
"""
import re, os, subprocess, sys, tempfile

HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HIER)
LUA = "/opt/homebrew/opt/lua@5.4/bin/lua"

tags = subprocess.run(["git", "-C", REPO, "tag", "--list", "v*"], capture_output=True, text=True).stdout.split()
def nummer(t):                                   # Zahlenvergleich: als Text wäre "v1.10.0" < "v1.5.0"
    return tuple(int(x) for x in t[1:].split(".") if x.isdigit())
tags = sorted((t for t in tags if re.fullmatch(r"v\d+\.\d+\.\d+", t) and nummer(t) >= (1, 5, 0)), key=nummer)
# Bis 1.12.0 lag der Code unter src/helirf («Heli RF»). Beim Umstellen eines Modells (Widget-Schlüssel helirf -> heli)
# bleibt der Widget-Speicher stehen; Heli muss ihn also aus jeder älteren Version lesen können.
with tempfile.TemporaryDirectory() as tmp:
    gut = []
    for t in tags:
        r0 = subprocess.run(["git", "-C", REPO, "show", t + ":src/heli/kern.lua"], capture_output=True)
        if r0.returncode != 0 or not r0.stdout:
            r0 = subprocess.run(["git", "-C", REPO, "show", t + ":src/helirf/kern.lua"], capture_output=True)
        if r0.returncode != 0 or not r0.stdout:
            continue
        open(os.path.join(tmp, "kern_" + t + ".lua"), "wb").write(r0.stdout)
        gut.append(t)
    tags = gut
    r = subprocess.run([LUA, os.path.join(HIER, "update_test.lua"), tmp, "kern.lua", " ".join(tags)],
                       cwd=os.path.join(REPO, "src", "heli"))
sys.exit(r.returncode)
