#!/usr/bin/env python3
"""Heli RF: Update-Test. Holt kern.lua aus jedem Versions-Tag ab v1.5.0, lässt die alte Version Einstellungen
schreiben und die aktuelle (src/helirf/kern.lua) sie lesen. Nichts darf verloren gehen.

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
with tempfile.TemporaryDirectory() as tmp:
    for t in tags:
        inhalt = subprocess.run(["git", "-C", REPO, "show", t + ":src/helirf/kern.lua"], capture_output=True).stdout
        open(os.path.join(tmp, "kern_" + t + ".lua"), "wb").write(inhalt)
    r = subprocess.run([LUA, os.path.join(HIER, "update_test.lua"), tmp, "kern.lua", " ".join(tags)],
                       cwd=os.path.join(REPO, "src", "helirf"))
sys.exit(r.returncode)
