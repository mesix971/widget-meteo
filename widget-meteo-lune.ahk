; =============================================================================
;  Widget météo — la vraie lune (option « Phase réelle de la lune » et
;  « Lever et coucher de la lune ») — inclus par widget-meteo.ahk
;
;  La phase est calculée sur place (Meeus, « Astronomical Algorithms »,
;  ch. 25 et 47, séries tronquées) : élongation Lune − Soleil à ±0,01°, soit
;  des heures de phase à 2 min près des éphémérides officielles de l'IMCCE.
;  Aucun réseau ; le lever et le coucher de la lune viennent d'Open-Meteo
;  (collecte : lune_lever, lune_coucher…, et champs 14-15 de previsions.txt).
;  (Constantes et état : LUNE_*, LuneReelle, LuneLever, LunePsi, LuneSud,
;  LuneForcee, déclarés dans widget-meteo.ahk.)
; =============================================================================

; Élongation Lune − Soleil (degrés, 0 à 360) à l'instant Unix donné :
; 0 nouvelle lune, 90 premier quartier, 180 pleine lune, 270 dernier quartier
ElongationLune(unix) {
    static rad := 3.141592653589793 / 180
    ; [D, M, M', F, coefficient] (Meeus, tableau 47.A, longitude)
    static termes := [[0, 0, 1, 0, 6288774], [2, 0, -1, 0, 1274027], [2, 0, 0, 0, 658314], [0, 0, 2, 0, 213618],
        [0, 1, 0, 0, -185116], [0, 0, 0, 2, -114332], [2, 0, -2, 0, 58793], [2, -1, -1, 0, 57066],
        [2, 0, 1, 0, 53322], [2, -1, 0, 0, 45758], [0, 1, -1, 0, -40923], [1, 0, 0, 0, -34720],
        [0, 1, 1, 0, -30383], [2, 0, 0, -2, 15327], [0, 0, 1, 2, -12528], [0, 0, 1, -2, 10980],
        [4, 0, -1, 0, 10675], [0, 0, 3, 0, 10034], [4, 0, -2, 0, 8548], [2, 1, -1, 0, -7888],
        [2, 1, 0, 0, -6766], [1, 0, -1, 0, -5163], [1, 1, 0, 0, 4987], [2, -1, 1, 0, 4036]]
    ; siècles juliens depuis J2000 (temps terrestre : ΔT ≈ 69 s)
    tj := ((unix + 69) / 86400 + 2440587.5 - 2451545) / 36525
    ; Soleil : longitude vraie, moins l'aberration
    ms := 357.52911 + 35999.05029 * tj
    ls := 280.46646 + 36000.76983 * tj + (1.914602 - 0.004817 * tj) * Sin(ms * rad)
        + 0.019993 * Sin(2 * ms * rad) + 0.000289 * Sin(3 * ms * rad) - 0.00569
    ; Lune : longitude moyenne, élongation, anomalies, argument de latitude
    lp := 218.3164477 + 481267.88123421 * tj
    d  := 297.8501921 + 445267.1114034 * tj
    m  := 357.5291092 + 35999.0502909 * tj
    mp := 134.9633964 + 477198.8675055 * tj
    f  := 93.2720950 + 483202.0175233 * tj
    s := 3958 * Sin((119.75 + 131.849 * tj) * rad) + 1962 * Sin((lp - f) * rad)
    for tr in termes
        s += tr[5] * Sin((tr[1] * d + tr[2] * m + tr[3] * mp + tr[4] * f) * rad)
    e := Mod(lp + s / 1000000 - ls, 360)
    return (e < 0) ? e + 360 : e
}

; Part éclairée du disque (0 à 1)
FractionLune(psi) => (1 - Cos(psi * 0.017453292519943295)) / 2

; Instant Unix de la phase principale q (0 nouvelle, 1 premier quartier, 2 pleine,
; 3 dernier quartier) qui suit (sens 1) ou précède (sens -1) l'instant donné.
; La Lune gagne en moyenne 12,19° d'élongation par jour ; quelques itérations suffisent.
InstantPhase(unix, q, sens := 1) {
    d := Mod(90 * q - ElongationLune(unix) + 720, 360)
    if (sens < 0)
        d -= 360
    t := unix + d / 12.1907 * 86400
    Loop 5 {
        d := Mod(90 * q - ElongationLune(t) + 540, 360) - 180
        t += d / 12.1907 * 86400
        if (Abs(d) < 0.0001)
            break
    }
    return t
}

; Heure locale (AAAAMMJJHHMISS) d'un instant Unix, avec l'heure d'été de CETTE
; date (et non celle d'aujourd'hui, comme le ferait un simple décalage)
LocalDeUnix(unix) {
    fb := Buffer(8), st := Buffer(16), lt := Buffer(16)
    NumPut("Int64", (Round(unix) + 11644473600) * 10000000, fb)
    DllCall("FileTimeToSystemTime", "Ptr", fb, "Ptr", st)
    DllCall("SystemTimeToTzSpecificLocalTime", "Ptr", 0, "Ptr", st, "Ptr", lt)
    return Format("{:04}{:02}{:02}{:02}{:02}{:02}", NumGet(lt, 0, "UShort"), NumGet(lt, 2, "UShort"),
        NumGet(lt, 6, "UShort"), NumGet(lt, 8, "UShort"), NumGet(lt, 10, "UShort"), NumGet(lt, 12, "UShort"))
}

; Instant Unix du moment affiché (maintenant, ou celui imposé par un mode de test)
MomentUnix() {
    if (HeureTest = "")
        return MaintenantUnix()
    return DateDiff(DateAdd(HeureTest, -DateDiff(A_Now, A_NowUTC, "Seconds"), "Seconds"), "19700101", "Seconds")
}

; Phase du moment (au degré près : le dessin change environ toutes les 2 h) et hémisphère
MajLune() {
    global LunePsi, LuneSud
    LunePsi := (LuneForcee != "") ? Mod(Integer(LuneForcee), 360) : Mod(Round(ElongationLune(MomentUnix())), 360)
    LuneSud := IsNumber(Donnees.Get("lat", "")) && Number(Donnees["lat"]) < 0
}

; Illustration où figure la lune (les 5 de nuit)
EstLune(id) => RegExMatch(id, "^lune|nuit$")

; La lune dans sa phase, disque (cx, cy, R) du repère 100 x 100 de l'icône c.
; Partie éclairée = demi-disque du limbe + demi-ellipse du terminateur (demi-axes
; R et R·|cos ψ|), bombée vers le limbe pour un croissant, vers l'ombre pour une
; gibbeuse. Limbe à droite quand elle croît (hémisphère nord), à gauche sinon.
; Sur la partie sombre, un voile pâle (lumière cendrée) ; près de la nouvelle
; lune, un fin anneau garde l'icône reconnaissable.
PhaseLune(L, c, cx, cy, R, psi) {
    k := FractionLune(psi)
    Disque(L, c, cx, cy, R, ((LUNE_VOILE0 + Round(LUNE_VOILE * (1 - k))) << 24) | (C_LUNE & 0xFFFFFF))
    L[L.Length].a := 0                            ; pas d'ombre sous le voile
    if (k < 0.03) {
        DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
        Cercle(p, c, cx, cy, R - 0.9)
        Elargir(p, 1.8 * c.u)
        L.Push({p: p, f: 0x73000000 | (C_LUNE & 0xFFFFFF), a: 0.5})
    }
    if (k < 0.005)                                ; nouvelle lune : rien d'éclairé
        return
    if (k > 0.995)                                ; pleine lune
        return Disque(L, c, cx, cy, R, C_LUNE)
    ax := c.x + cx * c.u, ay := c.y + cy * c.u, r := R * c.u
    debut := ((psi < 180) != LuneSud) ? 270 : 90  ; limbe à droite : de haut en bas par la droite
    cp := Cos(psi * 0.017453292519943295), b := r * Abs(cp)
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", ax - r, "Float", ay - r, "Float", 2 * r, "Float", 2 * r, "Float", debut, "Float", 180)
    ; terminateur : le sens de balayage ne dépend ni du côté éclairé ni de
    ; l'hémisphère (le parcours s'inverse déjà avec le limbe) ; au quartier, la
    ; fermeture du tracé fait le diamètre
    if (b >= 0.05)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", ax - b, "Float", ay - r, "Float", 2 * b, "Float", 2 * r,
            "Float", debut + 180, "Float", (cp > 0) ? -180 : 180)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    L.Push({p: p, f: C_LUNE})
}

; Icône lever / coucher de la lune : la lune posée sur l'horizon, flèche au-dessus
LuneHorizon(L, sens, X, Y, S) {
    c := {x: X, y: Y, u: S / 100}
    n := L.Length
    if LuneReelle
        PhaseLune(L, c, 50, 56, 20, LunePsi)
    else
        Croissant(L, c, 50, 56, 22)
    Barre(L, c, 8, 92, 75, C_BRUME[1])
    y1 := (sens = "lever") ? 32 : 12, y2 := (sens = "lever") ? 12 : 32, pointe := y2
    Traits(L, c, [[50, y1, 50, y2], [41, pointe + ((sens = "lever") ? 9 : -9), 50, pointe], [59, pointe + ((sens = "lever") ? 9 : -9), 50, pointe]], 5, 0xFFFFFFFF)
    Loop L.Length - n
        L[n + A_Index].o := 0x000000, L[n + A_Index].z := false
}

; Premier lever et premier coucher de la lune après le moment affiché
; (aujourd'hui ou demain, comme le soleil), dans l'ordre chronologique
ProchainsLune() {
    maint := Minutes(FormatTime(MomentAffiche(), "HH:mm")), r := []
    for sens in ["lever", "coucher"]
        for e in [["lune_" sens, 0], ["lune_" sens "2", 1440]] {
            m := Minutes(Donnees.Get(e[1], ""))
            if (m >= 0 && m + e[2] > maint) {
                r.Push({sens: sens, lab: Donnees[e[1]], m: m + e[2]})
                break
            }
        }
    if (r.Length = 2 && r[2].m < r[1].m)
        r := [r[2], r[1]]
    return r
}

; « aujourd'hui à 18:47 », « demain », « le 26 », « le 1er », « le 3 oct. »
QuandLune(t, maint) {
    lt := LocalDeUnix(t), lm := LocalDeUnix(maint)
    if (SubStr(lt, 1, 8) = SubStr(lm, 1, 8))
        return "aujourd'hui à " FormatTime(lt, "HH:mm")
    if (SubStr(lt, 1, 8) = FormatTime(DateAdd(lm, 1, "Days"), "yyyyMMdd"))
        return "demain"
    j := Integer(FormatTime(lt, "d"))
    return "le " ((j = 1) ? "1er" : j) ((SubStr(lt, 5, 2) != SubStr(lm, 5, 2)) ? " " FormatTime(lt, "MMM") : "")
}

; Les deux lignes de la fenêtre des prévisions :
; « Lune gibbeuse croissante  ·  pleine lune le 26 »
; « Éclairée à 90 %  ·  lever 18:33  ·  coucher 04:50 »
TexteLune(jours, maint) {
    static NOMS := ["nouvelle lune", "premier quartier", "pleine lune", "dernier quartier"]
    static ENTRE := ["Premier croissant", "Lune gibbeuse croissante", "Lune gibbeuse décroissante", "Dernier croissant"]
    psi := ElongationLune(maint)
    q := Floor(psi / 90), qs := Mod(q + 1, 4)
    tPrec := InstantPhase(maint, q, -1), tSuiv := InstantPhase(maint, qs, 1)
    auj := SubStr(LocalDeUnix(maint), 1, 8)
    if (SubStr(LocalDeUnix(tPrec), 1, 8) = auj)
        l1 := Majuscule(NOMS[q + 1]) " aujourd'hui à " FormatTime(LocalDeUnix(tPrec), "HH:mm")
    else if (SubStr(LocalDeUnix(tSuiv), 1, 8) = auj)
        l1 := Majuscule(NOMS[qs + 1]) " aujourd'hui à " FormatTime(LocalDeUnix(tSuiv), "HH:mm")
    else
        l1 := ENTRE[q + 1] "  ·  " NOMS[qs + 1] " " QuandLune(tSuiv, maint)
    l2 := "Éclairée à " Round(100 * FractionLune(psi)) " %"
    ; prochain lever et prochain coucher, dans les 30 h (au-delà, prévision trop vieille)
    lm := LocalDeUnix(maint)
    debut := FormatTime(lm, "yyyy-MM-dd'T'HH:mm"), fin := FormatTime(DateAdd(lm, 30, "Hours"), "yyyy-MM-dd'T'HH:mm")
    evts := []
    for e in [["lever", "llev"], ["coucher", "lcou"]]
        for j in jours {
            h := j.HasOwnProp(e[2]) ? j.%e[2]% : ""
            if (h = "")
                continue
            quand := j.date "T" h
            if (StrCompare(quand, debut) > 0 && StrCompare(quand, fin) <= 0) {
                evts.Push([quand, e[1], h])
                break
            }
        }
    if (evts.Length = 2 && StrCompare(evts[2][1], evts[1][1]) < 0)
        evts := [evts[2], evts[1]]
    for e in evts
        l2 .= "  ·  " e[2] " " e[3]
    return [l1, l2]
}

; Mode de test /lunes : 16 phases sur fond sombre puis clair, puis les
; illustrations de nuit avec nuages à 4 phases
PlancheLunes(fichier) {
    global LuneReelle, LuneForcee
    t := 160, colonnes := 16
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", colonnes * t, "Int", 3 * t, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, colonnes * t, t, 0xFF1C2733)
    Aplat(gr, 0, t, colonnes * t, t, 0xFFE4EAF0)
    Aplat(gr, 0, 2 * t, colonnes * t, t, 0xFF2A3440)
    LuneReelle := true
    cases := []
    Loop colonnes
        cases.Push(["lune", (A_Index - 1) * 22.5, A_Index - 1, 0]), cases.Push(["lune", (A_Index - 1) * 22.5, A_Index - 1, 1])
    for i, id in ["lune_peu", "lune_nuage", "averses_nuit", "averses_neige_nuit"]
        for j, psi in [45, 135, 225, 315]
            cases.Push([id, psi, (i - 1) * 4 + j - 1, 2])
    for ca in cases {
        LuneForcee := Round(ca[2])
        MajLune()
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", t, "Int", t, "Int", 0, "Int", 0xE200B, "Ptr", 0, "Ptr*", &cal := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", cal, "Ptr*", &g2 := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4)
        L := []
        Illustrer(L, ca[1], 15, 15, t - 30)
        OmbreDouce(g2, L, t, t, 2)
        for e in L
            Remplir(g2, e)
        for e in L
            DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2)
        DllCall("gdiplus\GdipDrawImageRectI", "Ptr", gr, "Ptr", cal, "Int", ca[3] * t, "Int", ca[4] * t, "Int", t, "Int", t)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", cal)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}
