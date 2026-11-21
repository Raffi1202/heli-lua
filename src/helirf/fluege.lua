-- Heli RF: Seite 2 «Flüge» (Flugliste rechts, Werte des gewählten Flugs links).
-- Wird erst beim Öffnen der Seite geladen und beim Verlassen wieder freigegeben.
-- Ein Flug ist eine Liste: 1 Nr, 2 Dauer s, 3 mAh, 4 max. Drehzahl, 5 max. Strom, 6 max. Reglertemp.,
-- 7 tiefste Zelle, 8 tiefste BEC-Spannung, 9 Akku % am Ende. Fehlende Werte sind nil.
local F = {}
local floor, max, min = math.floor, math.max, math.min

local TEXT = {
  { titel = "FLIGHTS", dieser = "THIS FLIGHT", letzter = "LAST FLIGHT", flug = "FLIGHT", nr = "No", dauer = "Time", mah = "mAh",
    temp = "Max °C", laeuft = "live", pause = "paused", keine = "No flights yet", reset = "CLEAR LIST", zurueck = "BACK", gesamt = "total",
    tipp = "Tap a flight for its values, swipe up/down", loeschen = "DELETE FLIGHT %s",
    w = { "Flight time", "Used capacity", "Max head RPM", "Max current", "Max ESC temp", "Lowest cell", "Lowest BEC", "Battery at end" },
    k = { [3] = "Max RPM", [5] = "Max ESC °C", [8] = "Battery end" } },
  { titel = "FLÜGE", dieser = "DIESER FLUG", letzter = "LETZTER FLUG", flug = "FLUG", nr = "Nr", dauer = "Dauer", mah = "mAh",
    temp = "Max °C", laeuft = "läuft", pause = "Pause", keine = "Noch kein Flug", reset = "LISTE LÖSCHEN", zurueck = "ZURÜCK", gesamt = "gesamt",
    tipp = "Flug antippen = Werte, auf/ab wischen", loeschen = "FLUG %s LÖSCHEN",
    w = { "Flugdauer", "Verbrauch", "Max. Drehzahl", "Max. Strom", "Max. Reglertemp.", "Tiefste Zelle", "Tiefste BEC", "Akku am Ende" },
    k = { [3] = "Max. Drehz.", [5] = "Max. Regler", [8] = "Akku Ende" } },
}

local function dauer(sek)
  if sek == nil then return nil end
  sek = max(0, floor(sek + 0.5))
  return string.format("%d:%02d", floor(sek / 60), sek % 60)
end

-- w: Widget, W/H: Fenster, s: Massstab, h: Hilfen aus kern.lua (C, deutsch, text, kachel, rund, ganz, ziel)
function F.zeichne(w, W, H, s, h)
  local C, text, kachel = h.C, h.text, h.kachel
  local deutsch = h.deutsch == true
  local T = TEXT[deutsch and 2 or 1]
  local function z(x, dez, einheit)
    if x == nil then return nil end
    local t = string.format("%." .. dez .. "f", x)
    if deutsch then t = t:gsub("%.", ",") end
    return t .. (einheit or "")
  end

  local rd, lu = 10 * s, 6 * s
  local top = 63 * s
  local kh = max(40 * s, 32)                            -- Knöpfe unten: zum Antippen nie niedriger als 32 Punkte
  local ph = H - top - kh - lu - 6 * s
  local bL = floor((W - 2 * rd - lu) * 0.52)
  local bR = W - 2 * rd - lu - bL
  local xR = rd + bL + lu

  -- Zeilen der Liste: neuester Flug oben, der laufende zuerst
  local liste, akt = w.liste, w.akt
  local zeilen, n = {}, 0
  if akt and akt.nr then
    n = n + 1
    zeilen[n] = { akt.nr, akt.dauer, akt.mah, akt.rpm, akt.a, akt.t, akt.z, akt.bec, akt.proz, laeuft = true, pause = akt.pause }
  end
  for i = #liste, 1, -1 do
    n = n + 1
    zeilen[n] = liste[i]
  end

  -- gewählter Flug: angetippt (nach Nummer), sonst der oberste
  local wahl = zeilen[1]
  if w.wahl then
    for i = 1, n do
      if zeilen[i][1] == w.wahl then wahl = zeilen[i] end
    end
  end

  -- links: Werte des gewählten Flugs
  kachel(rd, top, bL, ph, s)
  local kopf = T.letzter
  if wahl and wahl.laeuft then
    kopf = T.dieser
  elseif wahl and w.wahl and wahl[1] == w.wahl then
    kopf = T.flug .. " " .. h.ganz(wahl[1])
  end
  text(rd + 16 * s, top + 20 * s, kopf, 3, C.gelb, LEFT, true, bL - 32 * s)
  if wahl == nil then
    text(rd + bL / 2, top + ph / 2, T.keine, 4, C.grau, CENTERED, false, bL - 24 * s)
  else
    local werte = {
      dauer(wahl[2]), z(wahl[3], 0, " mAh"), z(wahl[4], 0, deutsch and " U/min" or " RPM"), z(wahl[5], 0, " A"),
      z(wahl[6], 0, " °C"), z(wahl[7], 2, " V"), z(wahl[8], 1, " V"), z(wahl[9], 0, " %"),
    }
    local zh = (ph - 44 * s) / 4
    local sb = (bL - 32 * s) / 2
    for i = 1, 8 do
      local sp, ze = (i - 1) % 2, floor((i - 1) / 2)
      local x, y = rd + 16 * s + sp * sb, top + 40 * s + zh * ze
      local titel = (W < 560 and T.k[i]) or T.w[i]          -- kleine Displays: kurze Bezeichnung
      text(x, y + zh * 0.24, titel, 2, C.grau, LEFT, false, sb - 10 * s)
      text(x, y + zh * 0.64, werte[i] or "--", 5, C.weiss, LEFT, true, sb - 10 * s)
    end
  end
  h.ziel(rd, top, bL, ph, "abwahl")

  -- rechts: Liste
  kachel(xR, top, bR, ph, s)
  text(xR + 16 * s, top + 20 * s, T.titel, 3, C.gelb, LEFT, true, bR * 0.5)
  text(xR + bR - 14 * s, top + 20 * s, h.ganz(w.fluege) .. " " .. T.gesamt, 2, C.grau, RIGHT, false, bR * 0.4)
  local sx = { xR + 16 * s, xR + bR * 0.46, xR + bR * 0.72, xR + bR - 14 * s }
  local ky = top + 46 * s
  text(sx[1], ky, T.nr, 2, C.grau, LEFT)
  text(sx[2], ky, T.dauer, 2, C.grau, RIGHT)
  text(sx[3], ky, T.mah, 2, C.grau, RIGHT)
  text(sx[4], ky, T.temp, 2, C.grau, RIGHT)
  lcd.color(C.rand)
  lcd.drawFilledRectangle(floor(xR + 12 * s), floor(ky + 12 * s), floor(bR - 24 * s), max(1, floor(s)))
  local zh = max(34 * s, 32)                            -- zum Antippen nie niedriger als 32 Punkte
  local platz = max(1, floor((ph - 62 * s) / zh))
  local ab = floor(max(0, min(tonumber(w.ab) or 0, n - platz)))   -- so viele Zeilen sind nach oben weggerollt
  w.ab, w.zeilenH, w.platz = ab, zh, platz
  local y = ky + 14 * s
  if n == 0 then
    text(xR + bR / 2, top + ph / 2, T.keine, 4, C.grau, CENTERED, false, bR - 24 * s)
  end
  if n > platz then                                     -- Rollbalken: es gibt mehr Flüge, als Platz haben
    local bh = ph - 70 * s
    lcd.color(C.rand)
    lcd.drawFilledRectangle(floor(xR + bR - 6 * s), floor(y), max(2, floor(3 * s)), floor(bh))
    lcd.color(C.hblau)
    lcd.drawFilledRectangle(floor(xR + bR - 6 * s), floor(y + bh * ab / n), max(2, floor(3 * s)), max(4, floor(bh * platz / n)))
  end
  for i = ab + 1, min(n, ab + platz) do
    local r = zeilen[i]
    local gewaehlt = wahl == r
    if gewaehlt then
      h.rund(xR + 6 * s, y + 1, bR - 12 * s, zh - 2, 5 * s, C.rand)
    end
    local f = r.laeuft and C.hblau or C.weiss
    text(sx[1], y + zh / 2, r.laeuft and (h.ganz(r[1]) .. " " .. (r.pause and T.pause or T.laeuft)) or h.ganz(r[1]), 4, r.laeuft and C.hblau or C.titel, LEFT, gewaehlt, bR * 0.24)
    text(sx[2], y + zh / 2, dauer(r[2]) or "--", 4, f, RIGHT, gewaehlt)
    text(sx[3], y + zh / 2, z(r[3], 0) or "--", 4, f, RIGHT, gewaehlt)
    text(sx[4], y + zh / 2, z(r[6], 0) or "--", 4, f, RIGHT, gewaehlt)
    h.ziel(xR, y, bR, zh, "flug", r[1])
    y = y + zh
  end

  -- unten: Knöpfe
  local ky2 = H - 6 * s - kh
  local kb = min(230 * s, (W - 2 * rd - lu) / 2)
  h.rund(rd, ky2, kb, kh, 6 * s, C.rand)
  h.rund(rd + 2, ky2 + 2, kb - 4, kh - 4, 5 * s, C.kachel)
  text(rd + kb / 2, ky2 + kh / 2, "< " .. T.zurueck, 3, C.weiss, CENTERED, true, kb - 16 * s)
  h.ziel(rd, ky2, kb, kh, "seite1")
  if w.wahl and wahl and wahl[1] == w.wahl then
    -- ein Flug ist angetippt: Knopf, um genau diesen zu löschen
    local mb = W - 2 * kb - 2 * rd - 2 * lu
    local mx = rd + kb + lu
    h.rund(mx, ky2, mb, kh, 6 * s, C.orange)
    h.rund(mx + 2, ky2 + 2, mb - 4, kh - 4, 5 * s, C.kachel)
    text(mx + mb / 2, ky2 + kh / 2, string.format(T.loeschen, h.ganz(w.wahl)), 3, C.orange, CENTERED, true, mb - 12 * s)
    h.ziel(mx, ky2, mb, kh, "loeschen")
  elseif n > 0 then
    text(W / 2, ky2 + kh / 2, T.tipp, 2, C.grau, CENTERED, false, W - 2 * kb - 4 * rd)
  end
  h.rund(W - rd - kb, ky2, kb, kh, 6 * s, C.rand)
  h.rund(W - rd - kb + 2, ky2 + 2, kb - 4, kh - 4, 5 * s, C.kachel)
  text(W - rd - kb / 2, ky2 + kh / 2, T.reset, 3, C.weiss, CENTERED, true, kb - 16 * s)
  h.ziel(W - rd - kb, ky2, kb, kh, "liste")
end

return F
