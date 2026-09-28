; =============================================================================
;  Widget météo — normales et records (menu Afficher ▸ Normales et records)
;  — inclus par widget-meteo.ahk
;
;  « Maximum 27° (normale 20°) » quand l'écart est net ; une pastille les jours
;  où la prévision frôle le record du jour ; dans les prévisions, la normale
;  1991-2020, les records et « il y a un an ». Source : réanalyse ERA5 du point
;  (Open-Meteo, archive), maille d'environ 25 km : une reconstitution, pas le
;  thermomètre d'Orly (collecte -Climat : climat.txt, clés clim_*).
; =============================================================================

ClimatActif() => ClimatPrev || ClimatWidget || ClimatRecord

; Normale et records d'aujourd'hui (suffixe "") ou de demain ("2") :
; {nmax, nmin, rmax, anmax, rmin, anmin} ou "". Les clés sont celles du jour
; de la collecte (clim_jour) : après minuit, celles de « demain » sont les
; bonnes ; plus vieilles : rien.
ClimatJour(suffixe := "") {
    if (Donnees.Get("clim_etat", "") != "ok")
        return ""
    if IsTime(j := Donnees.Get("clim_jour", "")) {
        dec := -JoursAvant(Integer(j)), k := (suffixe = "2") + dec
        if (dec < 0 || k > 1)
            return ""
        suffixe := k ? "2" : ""
    } else if (!IsInteger(Donnees.Get("clim_maj", "")) || MaintenantUnix() - Integer(Donnees["clim_maj"]) > 86400)
        return ""                                 ; (collecte d'avant 2.25, sans clim_jour)
    n := StrSplit(Donnees.Get("clim_n" suffixe, ""), "|"), r := StrSplit(Donnees.Get("clim_r" suffixe, ""), "|")
    if (n.Length < 2 || r.Length < 4 || !IsNumber(n[1]) || !IsNumber(r[1]) || !IsNumber(r[3]))
        return ""
    return {nmax: Number(n[1]), nmin: Number(n[2]), rmax: Number(r[1]), anmax: r[2], rmin: Number(r[3]), anmin: r[4]}
}

; Le maximum annoncé est-il celui de demain ? (après 17 h, le résumé parle de demain)
MaxDeDemain() => (d := StrReplace(Donnees.Get("max_jour", ""), "-")) != "" && IsTime(d) && Integer(d) > Aujourdhui()

; Suffixe du maximum dans le widget (option) : « (normale 20°) » quand l'écart atteint 3°
SuffixeNormale() {
    if (!ClimatWidget || !IsObject(c := ClimatJour(MaxDeDemain() ? "2" : "")))
        return ""
    if !RegExMatch(Donnees.Get("maximum", ""), "(-?\d+)\D*$", &o)
        return ""
    return (Abs(Integer(o[1]) - c.nmax) >= 3) ? Chr(0xA0) "(normale " Round(c.nmax) "°)" : ""
}

; Pastille (option) : la prévision du jour à 1° du record, ou au-delà
; {textes, fond, encre} ou ""
PastilleRecord() {
    if (!ClimatRecord || !IsObject(c := ClimatJour()) || !IsNumber(Donnees.Get("max", "")) || !IsNumber(Donnees.Get("min", "")))
        return ""
    ; (comparés arrondis, comme ils s'affichent : « Maximum 28° » ne bat pas un record de 28°)
    mx := Round(Number(Donnees["max"])), mn := Round(Number(Donnees["min"])), jour := FormatTime(MomentAffiche(), "d MMM")
    rmax := Round(c.rmax), rmin := Round(c.rmin)
    if (mx >= rmax - 1) {
        r := rmax "° en " c.anmax
        debut := (mx > rmax) ? "Au-dessus du record du " jour : "Proche du record de chaleur du " jour
        return {textes: [debut " (" r ")", (mx > rmax) ? "Au-dessus du record du jour" : "Proche du record du jour", "Record ?"],
            fond: 0xFFFF7043, encre: 0xFF16191D}
    }
    if (mn <= rmin + 1) {
        r := rmin "° en " c.anmin
        return {textes: [((mn < rmin) ? "Sous le record de froid du " : "Proche du record de froid du ") jour " (" r ")",
            (mn < rmin) ? "Sous le record de froid" : "Proche du record de froid", "Record ?"],
            fond: 0xFF4FC3F7, encre: 0xFF16191D}
    }
    return ""
}

; ---------- Fenêtre des prévisions : section « Normales et records » ----------

LignesClimat() {
    l := []
    if (!ClimatPrev || !IsObject(c := ClimatJour()))
        return l
    jour := FormatTime(MomentAffiche(), "d MMM")
    ecart := ""
    if IsNumber(Donnees.Get("max", ""))
        e := Round(Number(Donnees["max"])) - Round(c.nmax), ecart := "aujourd'hui " Round(Number(Donnees["max"])) "° (" ((e > 0) ? "+" : (e < 0) ? Chr(0x2212) : "") Abs(e) "°)"   ; (l'écart des valeurs affichées)
    l.Push({titre: "Normale du " jour " : " Round(c.nmax) "° / " Round(c.nmin) "°", detail: ecart, c: 0xFFC3C2B7})
    l.Push({titre: "Records : " Round(c.rmax) "° en " c.anmax "  ·  " Round(c.rmin) "° en " c.anmin, detail: "depuis 1940", c: 0xFFFF7043})
    a := StrSplit(Donnees.Get("clim_an", ""), "|")
    if (a.Length >= 4 && IsNumber(a[1]) && IsNumber(a[2]))
        l.Push({titre: "Il y a un an : " Round(Number(a[1])) "° / " Round(Number(a[2])) "°" ((IsNumber(a[3]) && Number(a[3]) >= 0.5) ? ", pluie " Round(Number(a[3])) " mm" : ""),
            detail: IsInteger(a[4]) ? StrLower(InfosMeteo(a[4])) : "", c: 0xFF3987E5})
    return l
}

HauteurClimat() => (n := LignesClimat().Length) ? 42 + 22 * n : 0

SectionClimat(L, kp, y0, pal, premier) {
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    if !premier
        Filet(L, X(22), X(y0 + 8), X(418), pal.grille)
    Poser(L, "Normales et records", P_DATE, em(10.5, P_DATE), X(22), X(y0 + 30), 0, pal.second)
    Poser(L, "ERA5 (reconstitution) · Open-Meteo", P_TEXTE, em(9), X(418), X(y0 + 30), 2, pal.discret)
    for i, e in LignesClimat() {
        yl := X(y0 + 30 + 22 * i)
        Point(L, X(26), yl - X(4), 3.5 * kp, e.c, 0, pal.surface)
        dt := (e.detail != "") ? Poser(L, e.detail, P_TEXTE, em(10), X(418), yl, 2, pal.second) : {x: X(418)}
        Poser(L, Tronquer(e.titre, P_TEXTE, em(10.5), dt.x - X(36) - X(12)), P_TEXTE, em(10.5), X(36), yl, 0, pal.encre)
    }
}

; ---------- Menu ----------

BasculerClimat(quoi, *) {
    global ClimatPrev, ClimatWidget, ClimatRecord
    switch quoi {
        case "prev":   ClimatPrev := !ClimatPrev
        case "widget": ClimatWidget := !ClimatWidget
        case "record": ClimatRecord := !ClimatRecord
    }
    ApresOptionAlerte(ClimatActif())              ; la collecte demande l'archive (une fois par lieu)
}
