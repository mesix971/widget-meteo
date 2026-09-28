; =============================================================================
;  Widget météo — le ciel : passages visibles de la station spatiale (menu
;  Afficher ▸ Ciel) — inclus par widget-meteo.ahk
;
;  ISS : les passages sont calculés par la collecte (-Iss : TLE de CelesTrak une
;  fois par jour, propagation sur ce PC, aucune position envoyée ; ~3 s et 1°
;  d'écart avec Heavens-Above), avec les nuages prévus à l'heure du passage.
;  Une pastille 2 h avant un passage assez haut, si le ciel n'est pas couvert,
;  jusqu'à sa fin ; les 3 prochains dans les prévisions.
; =============================================================================

; ---------- Station spatiale ----------

; Direction sur la rose des vents (16 secteurs, en français)
RoseVents(az) {
    static ROSE := ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
    return ROSE[Mod(Floor((Mod(az, 360) + 11.25) / 22.5), 16) + 1]
}

; Passages à venir (fin après maintenant), assez hauts (IssHmin) :
; [{debut, fin, tmax, hmax, azd, azm, azf, nuages ("" si inconnu)}]
PassagesIss() {
    liste := []
    if (!IssW || Donnees.Get("iss_etat", "") != "ok")
        return liste
    maint := MomentUnix()
    for p in StrSplit(Donnees.Get("iss_passages", ""), ";") {
        v := StrSplit(p, "|")
        if (v.Length < 7 || !IsInteger(v[1]) || !IsInteger(v[2]) || !IsNumber(v[4]))
            continue
        if (Integer(v[2]) <= maint || Number(v[4]) < IssHmin)
            continue
        liste.Push({debut: Integer(v[1]), fin: Integer(v[2]), tmax: Integer(v[3]), hmax: Round(Number(v[4])),
            azd: Number(v[5]), azm: Number(v[6]), azf: Number(v[7]), nuages: (v.Length >= 8 && IsInteger(v[8])) ? Integer(v[8]) : ""})
    }
    return liste
}

; Pastille : 2 h avant le prochain passage (ciel pas couvert) et pendant : {textes, fond, encre, icone} ou ""
PastilleIss() {
    maint := MomentUnix()
    for p in PassagesIss() {
        if (p.debut - 7200 > maint)
            break
        if (p.nuages != "" && p.nuages >= 50)
            continue
        trajet := RoseVents(p.azd) " → " RoseVents(p.azf)
        if (maint >= p.debut)
            return {textes: ["ISS visible maintenant · " trajet " · " p.hmax "°", "ISS visible maintenant", "ISS visible"],
                fond: 0xFF1E2A55, encre: 0xFFFFFFFF, icone: "iss"}
        h := HeureLocaleUnix(p.debut)
        return {textes: ["ISS à " h " · " trajet " · " p.hmax "°", "ISS à " h " · " p.hmax "° " RoseVents(p.azm), "ISS à " h],
            fond: 0xFF1E2A55, encre: 0xFFFFFFFF, icone: "iss"}
    }
    return ""
}

; Section des prévisions : les 3 prochains passages [{titre, detail, c}], ou un message
LignesIss() {
    l := []
    if !IssW
        return l
    etat := Donnees.Get("iss_etat", "")
    if (etat != "ok") {
        l.Push({titre: (etat = "perime") ? "Éléments d'orbite trop anciens (CelesTrak injoignable)"
            : (etat = "erreur") ? "Orbite pas encore reçue (CelesTrak injoignable, nouvel essai dans quelques heures)"
            : "Passages calculés à la prochaine collecte",
            detail: "", c: 0xFF898781})
        return l
    }
    for p in PassagesIss() {
        if (A_Index > 3)
            break
        couvert := (p.nuages != "" && p.nuages >= 50)
        loc := LocalDeUnix(p.debut), hl := Integer(SubStr(loc, 9, 2))   ; (un passage d'avant l'aube n'est pas « ce soir »)
        jour := (JoursAvant(Integer(SubStr(loc, 1, 8))) = 0) ? ((hl < 6) ? "Cette nuit" : (hl < 12) ? "Ce matin" : "Ce soir")
            : Majuscule(FormatTime(loc, "ddd d"))
        l.Push({titre: jour " " HeureLocaleUnix(p.debut) "–" HeureLocaleUnix(p.fin) " · " RoseVents(p.azd) " → " RoseVents(p.azf),
            detail: p.hmax "°" (couvert ? " · nuages " p.nuages " %" : ""), c: couvert ? 0xFF898781 : 0xFFFFFFFF})
    }
    if !l.Length
        l.Push({titre: "Aucun passage visible d'ici 4 jours" ((IssHmin > 10) ? " (au-dessus de " IssHmin "°)" : ""), detail: "", c: 0xFF898781})
    return l
}

HauteurIss() => IssW ? 42 + 22 * LignesIss().Length : 0

SectionIss(L, kp, y0, pal, premier) {
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    if !premier
        Filet(L, X(22), X(y0 + 8), X(418), pal.grille)
    Poser(L, "Station spatiale (ISS)", P_DATE, em(10.5, P_DATE), X(22), X(y0 + 30), 0, pal.second)
    Poser(L, "calculée ici · orbite CelesTrak", P_TEXTE, em(9), X(418), X(y0 + 30), 2, pal.discret)
    for i, e in LignesIss() {
        yl := X(y0 + 30 + 22 * i)
        Point(L, X(26), yl - X(4), 3.5 * kp, e.c, 0, pal.surface)
        dt := (e.detail != "") ? Poser(L, e.detail, P_TEXTE, em(10), X(418), yl, 2, pal.second) : {x: X(418)}
        Poser(L, Tronquer(e.titre, P_TEXTE, em(10.5), dt.x - X(36) - X(12)), P_TEXTE, em(10.5), X(36), yl, 0, pal.encre)
    }
}

BasculerIss(*) {
    global IssW
    IssW := !IssW
    ApresOptionAlerte(IssW)
}

; ---------- Planètes (sur ce PC, sans réseau) ----------
; Éléments képlériens approchés de Standish (JPL, table 1, valables 1800-2050)
; et précession de J2000 à la date : 0,07° près des positions de l'USNO
; (vérifié le 23-24/09/2026), largement assez pour l'œil nu. Pas de magnitude :
; Vénus, Mars, Jupiter et Saturne dès 10° de hauteur, Mercure aussi (elle ne
; se voit qu'au crépuscule, et rarement).

Atan2(y, x) => DllCall("msvcrt\atan2", "Double", y, "Double", x, "CDecl Double")

; Position héliocentrique écliptique J2000 (UA) d'un jeu d'éléments au siècle julien tj
HelioPlanete(el, tj) {
    static R := 0.017453292519943295
    v := []
    Loop 6
        v.Push(el[1][A_Index] + el[2][A_Index] * tj)
    ga := v[1], ex := v[2], incl := v[3] * R, lm := v[4], wb := v[5], nd := v[6]
    ma := (Mod(Mod(lm - wb + 180, 360) + 360, 360) - 180) * R
    ea := ma
    Loop 12
        ea -= (ea - ex * Sin(ea) - ma) / (1 - ex * Cos(ea))
    xp := ga * (Cos(ea) - ex), yp := ga * Sqrt(1 - ex * ex) * Sin(ea)
    om := (wb - nd) * R, nd := nd * R
    return [(Cos(om) * Cos(nd) - Sin(om) * Sin(nd) * Cos(incl)) * xp + (-Sin(om) * Cos(nd) - Cos(om) * Sin(nd) * Cos(incl)) * yp,
        (Cos(om) * Sin(nd) + Sin(om) * Cos(nd) * Cos(incl)) * xp + (-Sin(om) * Sin(nd) + Cos(om) * Cos(nd) * Cos(incl)) * yp,
        (Sin(om) * Sin(incl)) * xp + (Cos(om) * Sin(incl)) * yp]
}

; Hauteur et azimut (degrés, azimut depuis le nord vers l'est) d'une planète
; (ou du Soleil : nom « Soleil ») à l'instant Unix, vus de (lat, lon)
PositionPlanete(nom, unix, lat, lon) {
    static R := 0.017453292519943295
    static EL := Map(
        "Mercure", [[0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
                    [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]],
        "Vénus",   [[0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
                    [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]],
        "Terre",   [[1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
                    [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]],
        "Mars",    [[1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
                    [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]],
        "Jupiter", [[5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
                    [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]],
        "Saturne", [[9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
                    [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]])
    jd := unix / 86400 + 2440587.5, tj := (jd - 2451545.0) / 36525
    te := HelioPlanete(EL["Terre"], tj)
    if (nom = "Soleil")
        gx := -te[1], gy := -te[2], gz := -te[3]
    else {
        hp := HelioPlanete(EL[nom], tj)
        gx := hp[1] - te[1], gy := hp[2] - te[2], gz := hp[3] - te[3]
    }
    pr := (1.396971 * tj + 0.0003086 * tj * tj) * R   ; précession : rotation autour du pôle de l'écliptique
    qx := gx * Cos(pr) - gy * Sin(pr), qy := gx * Sin(pr) + gy * Cos(pr)
    eps := (23.43928 - 0.0130042 * tj) * R
    xe := qx, ye := qy * Cos(eps) - gz * Sin(eps), ze := qy * Sin(eps) + gz * Cos(eps)
    ra := Atan2(ye, xe), dec := Atan2(ze, Sqrt(xe * xe + ye * ye))
    gmst := Mod(280.46061837 + 360.98564736629 * (jd - 2451545.0), 360)
    ha := (gmst + lon - ra / R) * R, la := lat * R
    alt := ASin(Sin(la) * Sin(dec) + Cos(la) * Cos(dec) * Cos(ha))
    az := Atan2(-Cos(dec) * Sin(ha), Sin(dec) * Cos(la) - Cos(dec) * Sin(la) * Cos(ha))
    return {alt: alt / R, az: Mod(az / R + 360, 360)}
}

; « au sud-est », « à l'est »… (8 directions)
DirectionHuit(az) {
    static D := ["au nord", "au nord-est", "à l'est", "au sud-est", "au sud", "au sud-ouest", "à l'ouest", "au nord-ouest"]
    return D[Mod(Floor((Mod(az, 360) + 22.5) / 45), 8) + 1]
}

; Planètes visibles entre t1 et t2 (instants Unix), soleil sous −8° : par pas de
; 20 min, la plus grande hauteur (10° au moins) : [{nom, alt, az, t}], la plus haute d'abord
PlanetesVisibles(t1, t2, lat, lon) {
    res := []
    for nom in ["Vénus", "Jupiter", "Mars", "Saturne", "Mercure"] {
        best := ""
        t := t1
        while (t <= t2) {
            if (PositionPlanete("Soleil", t, lat, lon).alt < -8) {
                pp := PositionPlanete(nom, t, lat, lon)
                if (pp.alt >= 10 && (!IsObject(best) || pp.alt > best.alt))
                    best := {nom: nom, alt: pp.alt, az: pp.az, t: t}
            }
            t += 1200
        }
        if IsObject(best)
            res.Push(best)
    }
    Loop res.Length - 1 {                         ; la plus haute d'abord (insertion)
        i := A_Index + 1, e := res[i], k := i - 1
        while (k >= 1 && res[k].alt < e.alt)
            res[k + 1] := res[k], k--
        res[k + 1] := e
    }
    return res
}

; Ce soir (de 17 h à 1 h) et avant l'aube suivante (de 3 h à 8 h), à l'heure du
; PC : {soir, aube}, calculé une fois par jour et par lieu
PlanetesDuJour() {
    static cle := "", res := ""
    lat := Donnees.Get("lat", ""), lon := Donnees.Get("lon", "")
    if (!IsNumber(lat) || !IsNumber(lon))
        return ""
    auj := Aujourdhui(), c := auj "|" lat "|" lon
    if (c = cle)
        return res
    UnixLocal(stamp) => DateDiff(stamp, "19700101", "Seconds") - DecalageLocal(DateDiff(stamp, "19700101", "Seconds"))
    soir := UnixLocal(auj "170000"), demain := PlusJours(auj, 1)
    res := {soir: PlanetesVisibles(soir, UnixLocal(demain "010000"), Number(lat), Number(lon)),
        aube: PlanetesVisibles(UnixLocal(demain "030000"), UnixLocal(demain "080000"), Number(lat), Number(lon))}
    cle := c
    return res
}

; ---------- Étoiles filantes ----------
; Longitude solaire du maximum (valeurs de l'IMO, équinoxe J2000) et taux
; horaire zénithal ; la date se calcule chaque année (Meeus, chap. 25).
; Vérifié : Draconides 2026 le 9/10 vers 01 h 19 TU (annoncées « vers 1 h TU »).

; Longitude du Soleil (degrés, équinoxe J2000) à l'instant Unix
LongitudeSoleilJ2000(unix) {
    static R := 0.017453292519943295
    tj := (unix / 86400 + 2440587.5 - 2451545.0) / 36525
    l0 := 280.46646 + 36000.76983 * tj + 0.0003032 * tj * tj
    ma := (357.52911 + 35999.05029 * tj - 0.0001537 * tj * tj) * R
    ce := (1.914602 - 0.004817 * tj) * Sin(ma) + (0.019993 - 0.000101 * tj) * Sin(2 * ma) + 0.000289 * Sin(3 * ma)
    om := (125.04 - 1934.136 * tj) * R
    return Mod(Mod(l0 + ce - 0.00569 - 0.00478 * Sin(om) - 1.39697 * tj, 360) + 360, 360)
}

; Instant (Unix) où le Soleil atteint la longitude lam, après « apres »
InstantEssaim(lam, apres) {
    t := apres
    Loop 60 {
        d := Mod(Mod(lam - LongitudeSoleilJ2000(t) + 540, 360) + 360, 360) - 180
        if (Abs(d) < 0.00001)
            break
        t += d / 0.9856 * 86400
    }
    return (t < apres) ? InstantEssaim(lam, t + 363 * 86400) : t
}

; Prochains essaims (maximum dans les « jours » jours, ou fini depuis moins de 12 h) :
; [{nom, zhr, t, nuit (AAAAMMJJ du soir), lune (% éclairée), nuages ("" ou %)}]
EssaimsAVenir(jours := 45) {
    static ESSAIMS := [["Quadrantides", 283.15, 80], ["Lyrides", 32.32, 18], ["Êta Aquarides", 45.5, 50],
        ["Perséides", 140.0, 100], ["Draconides", 195.4, 5], ["Orionides", 208.0, 20],
        ["Léonides", 235.27, 15], ["Géminides", 262.2, 150], ["Ursides", 270.7, 10]]
    maint := MomentUnix(), liste := []
    nuages := Map()
    for n in StrSplit(Donnees.Get("nuits", ""), ";") {
        v := StrSplit(n, ":")
        if (v.Length = 2 && IsInteger(v[1]) && IsInteger(v[2]))
            nuages[Integer(v[1])] := Integer(v[2])
    }
    for e in ESSAIMS {
        t := InstantEssaim(e[2], maint - 12 * 3600)
        if (t - maint > jours * 86400)
            continue
        ; la nuit dont le milieu (2 h) est le plus proche du maximum
        loc := LocalDeUnix(Round(t)), h := Integer(SubStr(loc, 9, 2)), j := Integer(SubStr(loc, 1, 8))
        soir := (h < 14) ? PlusJours(j, -1) : j
        milieu := DateDiff(PlusJours(soir, 1) "020000", "19700101", "Seconds") - DecalageLocal(Round(t))
        liste.Push({nom: e[1], zhr: e[3], t: t, nuit: soir, lune: Round(100 * FractionLune(ElongationLune(milieu))),
            nuages: nuages.Get(soir, "")})
    }
    Loop liste.Length - 1 {                       ; dans l'ordre des dates
        i := A_Index + 1, x := liste[i], k := i - 1
        while (k >= 1 && liste[k].t > x.t)
            liste[k + 1] := liste[k], k--
        liste[k + 1] := x
    }
    return liste
}

; « nuit du 8 au 9 oct. »
NuitTexte(soir) {
    lendemain := PlusJours(soir, 1)
    return "nuit du " FormatTime(String(soir), "d") ((SubStr(soir, 5, 2) != SubStr(lendemain, 5, 2)) ? " " FormatTime(String(soir), "MMM") : "")
        . " au " FormatTime(String(lendemain), "d MMM")
}

; Événement du calendrier : une grande nuit d'étoiles filantes ce soir (au moins
; 50 par heure, lune éclairée à moins de 50 %, ciel pas couvert si on le sait)
EvenementsCiel(auj) {
    ev := []
    if !CielEtoiles
        return ev
    for e in EssaimsAVenir(2)
        if (e.nuit = auj && e.zhr >= 50 && e.lune < 50 && (e.nuages = "" || e.nuages < 50))
            ev.Push({rang: 3, genre: "ciel", long: e.nom " cette nuit (~" e.zhr "/h)", court: e.nom " cette nuit", date: auj})
    return ev
}

; ---------- Fenêtre des prévisions : section « Ce soir dans le ciel » ----------

LignesCiel() {
    l := []
    if CielPlanetes && IsObject(pj := PlanetesDuJour()) {
        for p in pj.soir {
            if (A_Index > 3)
                break
            l.Push({titre: p.nom " · ce soir " DirectionHuit(p.az), detail: Round(p.alt) "° vers " HeureCourte(Round(p.t)), c: 0xFFFFD27A})
        }
        ; avant l'aube : les planètes regroupées par direction (« Mars et Jupiter à l'est · Saturne à l'ouest »)
        dirs := [], parDir := Map()
        for p in pj.aube {
            dr := DirectionHuit(p.az)
            if !parDir.Has(dr)
                parDir[dr] := [], dirs.Push(dr)
            parDir[dr].Push(p.nom)
        }
        morceaux := []
        for dr in dirs
            morceaux.Push(JoindreEt(parDir[dr]) " " dr)
        if morceaux.Length {
            txt := "Avant l'aube : "
            for m in morceaux
                txt .= ((A_Index > 1) ? " · " : "") m
            l.Push({titre: txt, detail: "", c: 0xFFC3C2B7})
        }
        if (!pj.soir.Length && !pj.aube.Length)
            l.Push({titre: "Aucune planète brillante bien placée cette nuit", detail: "", c: 0xFF898781})
    }
    if CielEtoiles {
        for e in EssaimsAVenir() {
            if (A_Index > 2)
                break
            ; la nuit à observer, toujours entière : le détail se raccourcit s'il le faut
            titre := e.nom ", " NuitTexte(e.nuit), taux := "~" e.zhr "/h", lune := " · lune " e.lune " %"
            nuages := (e.nuages != "") ? " · nuages " e.nuages " %" : ""
            det := DetailQuiTient(titre, ["filantes " taux lune nuages, taux lune nuages, taux ((nuages != "") ? nuages : lune), taux])
            l.Push({titre: titre, detail: det,
                c: (e.zhr >= 50 && e.lune < 50) ? 0xFFFFFFFF : 0xFF898781})
        }
    }
    return l
}

HauteurCiel() => (n := LignesCiel().Length) ? 42 + 22 * n : 0

; Le détail le plus complet qui laisse le titre entier sur une ligne de section
; (titre de X(36) au détail, 12 px d'écart, détail calé à droite sur X(418) ;
; en px logiques : les largeurs suivent l'échelle)
DetailQuiTient(titre, variantes) {
    lt := LargeurTexte(titre, P_TEXTE, EmPourCapitale(P_TEXTE, 10.5))
    for v in variantes
        if (36 + lt + 12 + LargeurTexte(v, P_TEXTE, EmPourCapitale(P_TEXTE, 10)) <= 418)
            return v
    return variantes[variantes.Length]
}

SectionCiel(L, kp, y0, pal, premier) {
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    if !premier
        Filet(L, X(22), X(y0 + 8), X(418), pal.grille)
    Poser(L, "Dans le ciel", P_DATE, em(10.5, P_DATE), X(22), X(y0 + 30), 0, pal.second)
    Poser(L, "calculé ici", P_TEXTE, em(9), X(418), X(y0 + 30), 2, pal.discret)
    for i, e in LignesCiel() {
        yl := X(y0 + 30 + 22 * i)
        Point(L, X(26), yl - X(4), 3.5 * kp, e.c, 0, pal.surface)
        dt := (e.detail != "") ? Poser(L, e.detail, P_TEXTE, em(10), X(418), yl, 2, pal.second) : {x: X(418)}
        Poser(L, Tronquer(e.titre, P_TEXTE, em(10.5), dt.x - X(36) - X(12)), P_TEXTE, em(10.5), X(36), yl, 0, pal.encre)
    }
}

BasculerCiel(quoi, *) {
    global CielPlanetes, CielEtoiles
    if (quoi = "planetes")
        CielPlanetes := !CielPlanetes
    else
        CielEtoiles := !CielEtoiles
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

; ---------- Test ----------

; Auto-test : planètes contre l'USNO (hauteur géocentrique, sans réfraction), essaims
TestCiel(fichier) {
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    ; références : aa.usno.navy.mil/api/celnav (48,76 N, 2,41 E), relevées le 24/09/2026
    for r in [["Saturne", "20260923190000", 6.893, 94.383], ["Mars", "20260924043000", 43.944, 109.084],
        ["Jupiter", "20260924043000", 26.301, 95.780], ["Saturne", "20260924043000", 20.606, 248.652]] {
        p := PositionPlanete(r[1], DateDiff(r[2], "19700101", "Seconds"), 48.76, 2.41)
        Verifier(Abs(p.alt - r[3]) < 0.15 && Abs(p.az - r[4]) < 0.15, r[1] " " r[2] " UTC : " Round(p.alt, 2) "° / " Round(p.az, 2)
            . "° (USNO " r[3] " / " r[4] ")")
    }
    t := InstantEssaim(195.4, DateDiff("20260923000000", "19700101", "Seconds"))
    Verifier(Abs(t - DateDiff("20261009010000", "19700101", "Seconds")) < 3600, "Draconides 2026 : "
        . FormatTime(DateAdd("19700101", Round(t), "Seconds"), "dd/MM HH:mm") " TU (annoncées vers le 9/10 à 1 h TU)")
    t := InstantEssaim(262.2, DateDiff("20251101000000", "19700101", "Seconds"))
    Verifier(Abs(t - DateDiff("20251214070000", "19700101", "Seconds")) < 5400, "Géminides 2025 : "
        . FormatTime(DateAdd("19700101", Round(t), "Seconds"), "dd/MM HH:mm") " TU (IMO : vers le 14/12 à 7 h TU)")
    Verifier(NuitTexte(20261008) = "nuit du 8 au 9 oct." && NuitTexte(20261031) = "nuit du 31 oct. au 1 nov.", "« " NuitTexte(20261008) " », « " NuitTexte(20261031) " »")
    FileAppend(rapport "`n" echecs " échec(s)`n", fichier, "UTF-8")
}

ChoisirIssHmin(h, *) {
    global IssHmin := h
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}
