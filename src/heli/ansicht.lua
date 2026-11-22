-- Heli: Plätze einer Ansicht aus der Studio-Datei (Lua-Studio-Format v1, Abschnitte 6.3 und 7; Format 2 ab 1.11.0).
-- Wird nur geladen, wenn zur Fenstergrösse eine Studio-Ansicht passt.
-- Befehlsgrenze: A.vorbereiten (aus wakeup, je Aufruf höchstens einige Plätze) rechnet alles aus: Texte, Schrift,
-- Farben, Lage, Bögen, Balken. A.zeichne (paint) zeichnet nur noch, was je Platz in q.r steht. Kurvenpunkte legt
-- studiolauf.lua schon in Bildschirmkoordinaten ab (q.r.km Punkte, q.r.kx = x je Punkt).
-- Z kommt aus kern.lua: C (Farben), T (Texte), sp (Sprache), SCHRIFT (Schriften mit Höhe), govText.
-- Format 2: Symbole, fette Einheit und Schmuck zeichnet die Referenz studio_symbole.lua (w.sym). Die Einrückung des
-- Titels (Rückgabe von S.platz) merkt sich paint in q.r.ein; vorbereiten legt den Titel danach neu an und misst ihn
-- neu (nicht in paint). Bis dahin lässt paint den Titel weg, damit er nie über dem Symbol liegt.
local A = {}
local floor, max, min = math.floor, math.max, math.min

local function rgb(t, sonst)
  if t then return lcd.RGB(t[1], t[2], t[3]) end
  return sonst
end

-- Dauer in Sekunden: m:ss, ab einer Stunde h:mm:ss (Format 10, «zeit»)
local function zeit(x)
  local s = max(0, floor(x + 0.5))
  if s >= 3600 then return string.format("%d:%02d:%02d", floor(s / 3600), floor(s / 60) % 60, s % 60) end
  return string.format("%d:%02d", floor(s / 60), s % 60)
end

local function zahl(Z, x, dez)
  local t = string.format("%." .. dez .. "f", x)
  if Z.sp == 2 then t = t:gsub("%.", ",") end
  return t
end

-- Abgerundetes Rechteck als 6 Zeichenbefehle mit festen ganzen Zahlen: { x1,y1,b1,h1, x2,y2,b2,h2, r, cx1,cy1,cx2,cy2 }
local function rundGeo(x, y, b, h, r)
  x, y, b, h, r = floor(x), floor(y), floor(b), floor(h), max(1, floor(r))
  return { x + r, y, b - 2 * r, h, x, y + r, b, h - 2 * r, r, x + r, y + r, x + b - r - 1, y + h - r - 1 }
end

-- Text-Eintrag: Lage und gewünschte Schrifthöhe fest, Text, Schrift und Farbe werden in vorbereiten gesetzt
local function eintrag(r, x, ym, px, ausr, breit, fett)
  local e = { x = floor(x), ym = ym, px = px, ausr = ausr, breit = breit and floor(breit) or nil, fett = fett }
  r.t[#r.t + 1] = e
  return e
end

-- Schrift wählen: grösste mit Höhe <= px, dann kleiner, bis der Text in die Breite passt (nur bei neuer Textlänge)
local function setze(Z, e, t, farbe)
  t = tostring(t or "")
  e.farbe = farbe
  if e.text == t and e.f then return end
  if e.f and e.len == #t and not e.kurz then e.text = t return end
  Z.mess = (Z.mess or 0) + 1                            -- Schrift neu wählen kostet: vorbereiten hört danach früher auf
  local S = Z.SCHRIFT
  local gr = 1
  for i = 7, 1, -1 do
    if S[i][2] <= e.px then gr = i break end
  end
  e.kurz = nil
  if e.breit then
    lcd.font(S[gr][1])
    while gr > 1 and lcd.getTextSize(t) > e.breit do
      gr = gr - 1
      lcd.font(S[gr][1])
    end
    local n = 0
    while n < 40 and #t > 1 and lcd.getTextSize(t) > e.breit do       -- auch in der kleinsten Schrift zu breit: kürzen
      n = n + 1
      t = t:sub(1, #t - 1)
      while #t > 1 and t:byte(#t) >= 128 and t:byte(#t) < 192 do t = t:sub(1, #t - 1) end
      if #t > 0 and t:byte(#t) >= 192 then t = t:sub(1, #t - 1) end
      e.kurz = true
    end
  end
  e.text, e.len, e.f = t, #t, S[gr][1]
  e.y = floor(e.ym - S[gr][2] / 2)
end

-- Bogen 225° … 225° + 270·anteil als höchstens 2 Teilstücke (Winkel 0 = oben, im Uhrzeigersinn)
local function bogenTeile(a0, a1, l)
  l[1], l[2], l[3], l[4] = nil, nil, nil, nil
  if a1 <= a0 then return l end
  if a1 > 360 then
    l[1], l[2] = a0, 360
    l[3], l[4] = 0, a1 - 360
  else
    l[1], l[2] = a0, a1
  end
  return l
end

-- Feste Lage eines Platzes (einmal je Platz)
local function geometrie(Z, q, s)
  local r = { t = {}, bogen = {}, wert = {} }
  local x0, y0, b, h = q.x, q.y, q.b, q.h
  local pad = max(4, floor(6 * s))
  local th = min(18, max(10, h * 0.2))
  local zh = q.zusatz ~= "keine" and th or 0
  local rad = floor(6 * s)
  r.aussen = rundGeo(x0, y0, b, h, rad)
  local d = max(1, floor(1.5 * s))
  r.innen = rundGeo(x0 + d, y0 + d, b - 2 * d, h - 2 * d, rad - d)
  local da = max(2, floor(3 * s))
  r.innenA = rundGeo(x0 + da, y0 + da, b - 2 * da, h - 2 * da, rad - da)
  local art = q.darst
  r.pad, r.halb = pad, art == "balken_w" or art == "kurve"   -- für die Einrückung des Titels (Format 2)
  if art == "status" then
    r.titel = eintrag(r, x0 + pad, y0 + pad + th / 2, th, LEFT, b - 2 * pad)
    r.wertT = eintrag(r, x0 + b / 2, y0 + (h + th) / 2 + pad / 2, min(h * 0.45, 40), CENTERED, b - 2 * pad, true)
  elseif art == "ring" then
    r.titel = eintrag(r, x0 + b / 2, y0 + pad + th / 2, th, CENTERED, b - 2 * pad)
    local ra = min(b * 0.42, (h - th - zh - 3 * pad) * 0.5)
    local cx, cy = x0 + b / 2, y0 + pad + th + pad + ra
    local ri = max(2, ra - max(4, ra * 0.22))
    r.ring = { floor(cx), floor(cy), floor(ri), floor(ra) }
    r.wertT = eintrag(r, cx, cy - ra * 0.08, ra * 0.62, CENTERED, 2 * ri - 4, true)
    r.einheit = eintrag(r, cx, cy + ra * 0.42, max(10, ra * 0.22), CENTERED, 2 * ri - 4)
    if zh > 0 then r.zusatz = eintrag(r, cx, y0 + h - pad - th / 2, th, CENTERED, b - 2 * pad, true) end
  elseif art == "balken_w" then
    r.titel = eintrag(r, x0 + pad, y0 + pad + th / 2, th, LEFT, b * 0.5)
    local bh = max(6, floor(h * 0.22))
    local by = y0 + h - pad - bh - zh
    local vh = by - (y0 + pad + th) - pad
    r.wertT = eintrag(r, x0 + b - pad, y0 + pad + th / 2 + max(0, vh - th) / 2, max(th, min(vh + th, 44)), RIGHT, b * 0.55, true)
    r.balken = { floor(x0 + pad), floor(by), floor(b - 2 * pad), bh, true }
    if zh > 0 then r.zusatz = eintrag(r, x0 + b - pad, y0 + h - pad - th / 2, th, RIGHT, b - 2 * pad) end
  elseif art == "balken_s" then
    r.titel = eintrag(r, x0 + b / 2, y0 + pad + th / 2, th, CENTERED, b - 2 * pad)
    local vh = min(30, max(12, h * 0.16))
    local bt = y0 + 2 * pad + th
    local bhoch = y0 + h - pad - vh - zh - pad - bt
    local bb = min(b * 0.4, 40)
    if bhoch > 4 then r.balken = { floor(x0 + (b - bb) / 2), floor(bt), floor(bb), floor(bhoch), false } end
    r.wertT = eintrag(r, x0 + b / 2, y0 + h - pad - zh - vh / 2, vh, CENTERED, b - 2 * pad, true)
    if zh > 0 then r.zusatz = eintrag(r, x0 + b / 2, y0 + h - pad - th / 2, th, CENTERED, b - 2 * pad) end
  elseif art == "kurve" then
    r.titel = eintrag(r, x0 + pad, y0 + pad + th / 2, th, LEFT, b * 0.5)
    r.wertT = eintrag(r, x0 + b - pad, y0 + pad + th / 2, th * 1.3, RIGHT, b * 0.48, true)
    local px, py, pb, ph = x0 + pad, y0 + 2 * pad + th, b - 2 * pad, h - 3 * pad - th - zh
    if ph > 4 then
      r.linie = { floor(px), floor(py + ph), floor(pb), 1 }
      -- Punkte: höchstens 60 und höchstens 1 je 3 Pixel Breite (Befehlsgrenze beim Zeichnen)
      local km = max(2, min(60, floor(pb / 3)))
      r.km, r.kx, r.ky0, r.kh = km, {}, floor(py + ph), ph
      for j = 1, km do r.kx[j] = floor(px + (j - 1) * pb / (km - 1)) end
    end
    if zh > 0 then r.zusatz = eintrag(r, x0 + b - pad, y0 + h - pad - th / 2, th, RIGHT, b - 2 * pad) end
  else                                                   -- "zahl"
    r.titel = eintrag(r, x0 + pad, y0 + pad + th / 2, th, LEFT, b - 2 * pad)
    r.wertT = eintrag(r, x0 + b - pad, y0 + pad + th + (h - 2 * pad - th - zh) / 2, min(h * 0.42, 52), RIGHT, b - 2 * pad, true)
    if zh > 0 then r.zusatz = eintrag(r, x0 + b - pad, y0 + h - pad - th / 2, th, RIGHT, b - 2 * pad) end
  end
  -- Farben einmal je Platz
  r.cF, r.cW, r.cA = rgb(q.farbe, Z.C.hblau), rgb(q.farbeWarn, Z.C.orange), rgb(q.farbeAlarm, Z.C.rot)
  r.cBg = rgb(q.hintergrund, Z.C.kachel)
  if q.stufen then
    r.stufen = {}
    for i, st in ipairs(q.stufen) do r.stufen[i] = { st.ab, rgb(st.farbe) } end
  end
  local d2 = q.art == "lua" and Z.WERTE[q.s] or nil
  r.lo = q.min or (d2 and d2[4]) or 0
  r.hi = q.max or (d2 and d2[5]) or 100
  if r.hi <= r.lo then r.hi = r.lo + 1 end
  return r
end

local function zusatzText(w, q, Z, dez, eh, zt)
  local z = w.studio.zx[q.w]
  if z == nil then return nil end
  local x, vor = z[2], "MAX "
  if q.zusatz == "min" then x, vor = z[1], "MIN " elseif q.zusatz == "mittel" then x, vor = (z[4] > 0 and z[3] / z[4] or nil), "Ø " end
  if x == nil then return nil end
  if zt then return vor .. zeit(x) end
  return vor .. zahl(Z, x, dez) .. ((eh ~= "") and (" " .. eh) or "")
end

-- Format 2: Titel nach der Einrückung ein (Rückgabe 1 von S.platz) neu anlegen, wie Elektro 0.4.0: links ab
-- x + max(pad, ein), mittig in der freien Breite; Breite nie unter 8 px. Der Text wird danach neu gemessen.
local function titelEinruecken(q, r, ein)
  local e, pad, b = r.titel, r.pad, q.b
  local tx = max(pad, ein)
  if e.ausr == LEFT then
    e.x = floor(q.x + tx)
    e.breit = floor(r.halb and max(8, b * 0.5 - (tx - pad)) or max(8, b - tx - pad))
  else
    e.x = floor(q.x + (tx + b - pad) / 2)
    e.breit = floor(max(8, b - tx - pad))
  end
  -- 1.14.2 (wie Electric 0.7.3): Symbol nie grösser als der Titeltext, Titel so hoch wie das Symbol (höchstens 1/3 Platz)
  e.px0 = e.px0 or e.px
  if ein > 8 then e.px = min(ein - 8, max(e.px0, q.h * 0.33)) else e.px = e.px0 end
  e.ym = q.y + r.pad + e.px / 2
  e.text, e.f = nil, nil
  r.einT = ein
end

-- 1.14.3: Steht die Einheit schon im Titel? Nur als eigenes Wort: davor Anfang, Leerzeichen oder Klammer auf, danach Ende,
-- Leerzeichen, Klammer zu oder «%». So zählt «A» in «Akku» nicht, «%» in «Akku %» und «V» in «Akku (V)» schon.
local function einheitImTitel(eh, t)
  if type(eh) ~= "string" or eh == "" or type(t) ~= "string" then return false end
  local i = 1
  while true do
    local a, b = t:find(eh, i, true)
    if not a then return false end
    local v, n = t:sub(a - 1, a - 1), t:sub(b + 1, b + 1)
    if (v == "" or v:find("^[%s%(%[]")) and (n == "" or n:find("^[%s%)%]%%]")) then return true end
    i = a + 1
  end
end

-- Einen Platz vorbereiten (aus wakeup)
local function vorbereitePlatz(w, Z, q, ST, s)
  local r = q.r
  if r == nil then
    r = geometrie(Z, q, s)
    q.r = r
  end
  local C, T = Z.C, Z.T
  if q.art == "leer" then r.leer = true return end
  local roh = q.roh                                     -- nur bei Format 2 gesetzt
  if roh and (r.ein or 0) ~= (r.einT or 0) then titelEinruecken(q, r, r.ein or 0) end
  local x, eh, dez, name = ST.wert(w, q.w, q.art, q.s, Z.sp)
  local d = q.art == "lua" and Z.WERTE[q.s] or nil
  local zt = d and d.zeit
  local st = (d and d.u and w.v.st[d.u]) or w.studio.st[q.w]
  if q.s == "governor" and x == 6 and q.art == "lua" then st = 2 end   -- «Drehzahl verloren» wie im eingebauten Bild rot
  r.alarm = st == 2
  local fg = r.cF
  if st == 2 then fg = r.cA
  elseif st == 1 then fg = r.cW
  elseif r.stufen and x then
    for _, sf in ipairs(r.stufen) do if x >= sf[1] then fg = sf[2] end end
  end
  r.fg = fg
  r.symF = fg                                           -- Format 2: Symbol und fette Einheit in der Farbe des Werts
  -- Format 2: Einheit des Werts für die Referenz (nil bei Flugzeit und Status); neben dem Wert nur bei einheitZeigen = true
  local amWert = true
  if roh then
    -- 1.14.2 (Sendertest 22.11., wie Electric 0.7.3): keine grosse, fette Einheit im Kopf. «fett» gilt wie «Einheit am
    -- Wert» (klein); steht die Einheit schon im Titel (z. B. «Akku %»), entfällt sie ganz.
    local rk = q.rohK
    if rk == nil then
      rk = {}
      for k, v in pairs(roh) do rk[k] = v end
      if rk.einheitZeigen == "fett" then rk.einheitZeigen = true end
      q.rohK = rk
    end
    rk._einheit = nil
    amWert = rk.einheitZeigen ~= false
    local tt = q.titel or name
    if einheitImTitel(eh, tt) then amWert = false end
  end
  local fehlt = (q.art == "sensor" or q.art == "kanal") and w.studio.quellen[q.w] == false
  local wz = fehlt and "---" or (x == nil and "--") or (zt and zeit(x)) or zahl(Z, x, dez)
  setze(Z, r.titel, q.titel or name, (st == 2 and q.darst ~= "balken_w" and q.darst ~= "balken_s" and q.darst ~= "kurve") and fg or C.titel)
  local art = q.darst
  if art == "status" then
    local t, f = "--", C.grau
    if q.s == "governor" then t, f = Z.govText(x and floor(x + 0.5) or nil, T)
    elseif q.s == "scharf" and x ~= nil then t, f = (x == 1) and T.scharf or T.sicher, (x == 1) and C.gruen or C.grau end
    setze(Z, r.wertT, t, f)
    r.symF = f                                          -- Status: Symbol in der Farbe des Zustands
  elseif art == "ring" then
    setze(Z, r.wertT, wz, st and st > 0 and fg or C.weiss)
    setze(Z, r.einheit, (eh ~= "" and not zt and amWert) and eh or "", C.titel)
    local anteil = x and max(0, min(1, (x - r.lo) / (r.hi - r.lo))) or 0
    bogenTeile(225, 225 + anteil * 270, r.wert)
  else
    local t = wz
    if x ~= nil and not fehlt and not zt and eh ~= "" and art ~= "kurve" and amWert then t = t .. " " .. eh end
    setze(Z, r.wertT, t, fg)
    if r.balken then
      local anteil = x and max(0, min(1, (x - r.lo) / (r.hi - r.lo))) or 0
      local B = r.balken
      if B[5] then r.fuell = anteil > 0 and max(2, floor(B[3] * anteil)) or 0
      else r.fuell = anteil > 0 and max(2, floor(B[4] * anteil)) or 0 end
    end
  end
  if r.zusatz then setze(Z, r.zusatz, zusatzText(w, q, Z, dez, amWert and eh or "", zt) or "", C.gelb) end
  r.fertig = true
end

-- Aus wakeup: je Aufruf höchstens n Plätze vorbereiten (reihum); nach 2 neu gewählten Schriften ist Schluss
-- (Befehlsgrenze beim ersten Durchgang und bei neuen Textlängen)
function A.vorbereiten(w, Z, ans, ST, n)
  local s = ans.s
  if s == nil then return end
  local P = ans.plaetze
  if #P == 0 then return end
  Z.mess = 0
  for _ = 1, min(n, #P) do
    if Z.mess >= 2 then break end
    local i = (ans.reihum or 0) % #P + 1
    ans.reihum = i
    local ok, e = pcall(vorbereitePlatz, w, Z, P[i], ST, s)
    if not ok and not w.platzFehler then
      w.platzFehler = true
      print("Heli: Fehler bei " .. tostring(P[i].w) .. ": " .. tostring(e))
    end
  end
end

-- ===== Zeichnen (paint): nur fertige Zahlen und Texte =====
local dfr, dfc
local function rund(g, farbe)
  lcd.color(farbe)
  dfr(g[1], g[2], g[3], g[4])
  dfr(g[5], g[6], g[7], g[8])
  local r = g[9]
  dfc(g[10], g[11], r)
  dfc(g[12], g[11], r)
  dfc(g[10], g[13], r)
  dfc(g[12], g[13], r)
end

local function zeichnePlatz(w, q, C, i)
  local r = q.r
  if r.alarm then
    rund(r.aussen, r.cA)
    rund(r.innenA, r.cBg)
  else
    rund(r.aussen, C.rand)
    rund(r.innen, r.cBg)
  end
  if not (r.leer or r.fertig) then return end
  local SY = w.sym
  if SY and q.roh then                                  -- Format 2: Symbol und fette Einheit, Titel rückt ein
    local ein = SY.platz(q.rohK or q.roh, q.x, q.y, r.symF or r.cF)
    if ein ~= (r.ein or 0) then r.ein = ein end
  end
  if r.leer then return end
  local ohneTitel = (r.ein or 0) ~= (r.einT or 0)       -- Einrückung neu: Titel erst nach dem Neumessen (wakeup)
  local t = r.t
  for k = 1, #t do
    local e = t[k]
    if e.f and e.text ~= "" and not (ohneTitel and e == r.titel) then
      lcd.font(e.f)
      lcd.color(e.farbe)
      lcd.drawText(e.x, e.y, e.text, e.ausr)
      if e.fett then lcd.drawText(e.x + 1, e.y, e.text, e.ausr) end
    end
  end
  local g = r.ring
  if g then
    local das = lcd.drawAnnulusSector
    lcd.color(C.spur)
    das(g[1], g[2], g[3], g[4], 225, 360)
    das(g[1], g[2], g[3], g[4], 0, 135)
    local l = r.wert
    if l[1] then
      lcd.color(r.fg)
      das(g[1], g[2], g[3], g[4], l[1], l[2])
      if l[3] then das(g[1], g[2], g[3], g[4], l[3], l[4]) end
    end
    return
  end
  local B = r.balken
  if B then
    lcd.color(C.spur)
    dfr(B[1], B[2], B[3], B[4])
    local f = r.fuell
    if f > 0 then
      lcd.color(r.fg)
      if B[5] then dfr(B[1], B[2], f, B[4]) else dfr(B[1], B[2] + B[4] - f, B[3], f) end
    end
    return
  end
  local L = r.linie
  if L then
    lcd.color(C.linie)
    dfr(L[1], L[2], L[3], L[4])
    local K = w.studio.kurven[i]
    local Y = K and K.w == q.w and K.y
    if Y then
      local n = #Y
      if n >= 2 then
        local X, dl = r.kx, lcd.drawLine
        local off = r.km - n
        lcd.color(r.fg)
        local y0 = Y[1]
        for j = 2, n do
          local y1 = Y[j]
          if y0 and y1 then dl(X[off + j - 1], y0, X[off + j], y1) end
          y0 = y1
        end
      end
    end
  end
end

function A.zeichne(w, Z, ans, s, ziel)
  ans.s = s
  dfr, dfc = lcd.drawFilledRectangle, lcd.drawFilledCircle
  local C = Z.C
  local SY = w.sym
  if SY then                                            -- Format 2: Schmuck nach dem Hintergrund, vor den Plätzen
    SY.bildAnfang()
    if ans.roh and not ans.deko then SY.deko(ans.roh, 0, 0, C.titel) end   -- umgerechnete Ansicht: ohne Schmuck
  end
  local P = ans.plaetze
  for i = 1, #P do
    local q = P[i]
    if q.r then
      local ok, e = pcall(zeichnePlatz, w, q, C, i)
      if not ok and not w.platzFehler then
        w.platzFehler = true
        print("Heli: Fehler beim Zeichnen von " .. tostring(q.w) .. ": " .. tostring(e))
      end
      -- antippbar wie im eingebauten Bild: Flüge öffnet die Flugliste, Verbraucht fragt «auf 0 setzen?»
      if q.w == "lua:fluege" then ziel(q.x, q.y, q.b, q.h, "seite2")
      elseif q.w == "lua:verbraucht" then ziel(q.x, q.y, q.b, q.h, "mah") end
    end
  end
  if SY and SY.nochZuZeichnen() and lcd.invalidate then lcd.invalidate() end   -- Masken/Texte im nächsten Bild
end

return A
