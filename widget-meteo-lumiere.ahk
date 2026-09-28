; =============================================================================
;  Widget météo — lumière du jour : durée du jour (et ce qu'elle gagne ou
;  perd), changement d'heure annoncé, équinoxes et solstices, heures d'UV fort
;  — inclus par widget-meteo.ahk
;
;  Rien sur le réseau en plus : la durée du jour vient des instants du lever et
;  du coucher (collecte : jour_duree, jour_duree2, à la seconde), les UV de la
;  même requête Open-Meteo (uv3, uv6 : créneaux d'aujourd'hui) ; le changement
;  d'heure suit les règles du fuseau de Windows (si le changement d'heure est
;  un jour aboli, la mise à jour de Windows le fera disparaître d'elle-même) ;
;  les saisons sont calculées ici (Meeus, chap. 27 : à la minute près).
; =============================================================================

; ---------- Durée du jour ----------

; « 12 h 05 » (arrondie à la minute)
DureeTexte(s) {
    m := Round(s / 60)
    return (m // 60) " h " Format("{:02}", Mod(m, 60))
}

; Écart d'un jour à l'autre : « −3 min 34 », « +12 s »
EcartTexte(d) {
    signe := (d < 0) ? Chr(0x2212) : "+", d := Abs(Round(d))
    return signe ((d >= 60) ? (d // 60) " min " Format("{:02}", Mod(d, 60)) : d Chr(0xA0) "s")
}

; Durée du jour d'après la collecte : {jour (s), ecart (s, demain − aujourd'hui, ou "")}, ou ""
DureeJourInfos() {
    j := Donnees.Get("jour_duree", ""), j2 := Donnees.Get("jour_duree2", "")
    if !IsInteger(j)
        return ""
    return {jour: Integer(j), ecart: IsInteger(j2) ? Integer(j2) - Integer(j) : ""}
}

; Formes de plus en plus courtes pour la ligne du soleil du widget
TextesDureeJour() {
    if !IsObject(dj := DureeJourInfos())
        return []
    d := DureeTexte(dj.jour)
    if (dj.ecart = "")
        return [d " de jour", d]
    e := EcartTexte(dj.ecart)
    return [d " de jour  ·  " e, d "  ·  " e, d " de jour", d]
}

; Icône de la durée du jour : l'arc du soleil au-dessus de l'horizon, le soleil au sommet
ArcSoleil(L, X, Y, S) {
    c := {x: X, y: Y, u: S / 100}
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", c.x + 14 * c.u, "Float", c.y + 39 * c.u, "Float", 72 * c.u, "Float", 72 * c.u, "Float", 180, "Float", 180)
    Elargir(p, 5 * c.u)
    L.Push({p: p, f: C_BRUME[1], o: 0x000000, z: false})
    Barre(L, c, 8, 92, 75, C_BRUME[1])
    L[L.Length].o := 0x000000, L[L.Length].z := false
    Disque(L, c, 50, 39, 12, C_SOLEIL)
    L[L.Length].o := 0x000000, L[L.Length].z := false
}

; ---------- UV ----------

; Créneaux d'aujourd'hui où l'UV atteint le seuil (clé uv3 ou uv6) : {debut, fin, max, tmax} ou ""
PlageUV(cle) {
    v := StrSplit(Donnees.Get(cle, ""), "|")
    if (v.Length < 4 || !IsInteger(v[1]) || !IsInteger(v[2]) || !IsNumber(v[3]))
        return ""
    p := {debut: Integer(v[1]), fin: Integer(v[2]), max: Number(v[3]), tmax: IsInteger(v[4]) ? Integer(v[4]) : Integer(v[1])}
    if (SubStr(LocalDeUnix(p.debut), 1, 8) != Aujourdhui())   ; données d'un autre jour
        return ""
    return p
}

; « de 13 h à 16 h (max 4,6 à 14 h) »
TextePlageUV(p) => "de " HeureCourte(p.debut) " à " HeureCourte(p.fin) " (max " StrReplace(Round(p.max, 1), ".", ",") " à " HeureCourte(p.tmax) ")"

; Pastille « UV fort » (option) : jusqu'à la fin du dernier créneau ≥ 6 d'aujourd'hui.
; {niv (1 fort, 2 très fort, 3 extrême), textes, fond, encre} ou ""
UvFort() {
    if (!UvW || !IsObject(p := PlageUV("uv6")))
        return ""
    maint := MomentUnix()
    if (maint >= p.fin + 3600)                    ; la dernière heure forte est passée
        return ""
    niv := (p.max >= 11) ? 3 : (p.max >= 8) ? 2 : 1
    nom := ["UV fort", "UV très fort", "UV extrême"][niv]
    mx := StrReplace(Round(p.max, 1), ".", ",")
    quand := (maint >= p.debut) ? "jusqu'à " HeureCourte(p.fin + 3600) : "de " HeureCourte(p.debut) " à " HeureCourte(p.fin + 3600)
    return {niv: niv, textes: [nom " " quand " (indice " mx ")", nom " " quand, nom " (indice " mx ")", nom],
        fond: [0xFFF7931E, 0xFFE53935, 0xFF8E44AD][niv], encre: (niv = 1) ? 0xFF16191D : 0xFFFFFFFF}
}

; ---------- Changement d'heure ----------

; Décalage de l'heure locale (s) à l'instant Unix t, selon les règles de Windows
DecalageLocal(t) => DateDiff(LocalDeUnix(t), DateAdd("19700101", t, "Seconds"), "Seconds")

; Prochain changement d'heure dans les « jours » jours qui suivent midi du jour
; ymd : {jour (AAAAMMJJ), t (instant), hiver (bool), avant, apres (« 3 h », « 2 h »)}, ou ""
ProchainChangementHeure(ymd, jours) {
    u0 := DateDiff(ymd "120000", "19700101", "Seconds")
    t0 := u0 - DecalageLocal(u0)                  ; midi, heure locale
    o0 := DecalageLocal(t0)
    Loop jours {
        t := t0 + A_Index * 86400
        if (DecalageLocal(t) = o0)
            continue
        tc := t - 86400                           ; l'heure pile où ça change (t0 tombe sur une heure UTC ronde)
        while (DecalageLocal(tc) = o0)
            tc += 3600
        o1 := DecalageLocal(tc)
        return {jour: Integer(SubStr(LocalDeUnix(tc), 1, 8)), t: tc, hiver: o1 < o0,
            avant: Mod(Floor((tc + o0) / 3600), 24) " h", apres: Mod(Floor((tc + o1) / 3600), 24) " h"}
    }
    return ""
}

; ---------- Saisons (Meeus, chap. 27) ----------

; Instant Unix d'une saison de l'année « an » : n = 0 équinoxe de mars, 1 solstice
; de juin, 2 équinoxe de septembre, 3 solstice de décembre. Polynômes 2000-3000
; (table 27.B) et 24 termes périodiques (27.C) ; ΔT pris à 69 s.
InstantSaison(an, n) {
    static TA := [485, 203, 199, 182, 156, 136, 77, 74, 70, 58, 52, 50, 45, 44, 29, 18, 17, 16, 14, 12, 12, 12, 9, 8]
    static TB := [324.96, 337.23, 342.08, 27.85, 73.14, 171.52, 222.54, 296.72, 243.58, 119.81, 297.17, 21.02,
        247.54, 325.15, 60.93, 155.12, 288.79, 198.04, 199.76, 95.39, 287.11, 320.81, 227.73, 15.45]
    static TC := [1934.136, 32964.467, 20.186, 445267.112, 45036.886, 22518.443, 65928.934, 3034.906, 9037.513,
        33718.147, 150.678, 2281.226, 29929.562, 31555.956, 4443.417, 67555.328, 4562.452, 62894.029, 31436.921,
        14577.848, 31931.756, 34777.259, 1222.114, 16859.074]
    static rad := 0.017453292519943295
    yy := (an - 2000) / 1000
    switch n {
        case 0: jde0 := 2451623.80984 + 365242.37404 * yy + 0.05169 * yy ** 2 - 0.00411 * yy ** 3 - 0.00057 * yy ** 4
        case 1: jde0 := 2451716.56767 + 365241.62603 * yy + 0.00325 * yy ** 2 + 0.00888 * yy ** 3 - 0.00030 * yy ** 4
        case 2: jde0 := 2451810.21715 + 365242.01767 * yy - 0.11575 * yy ** 2 + 0.00337 * yy ** 3 + 0.00078 * yy ** 4
        default: jde0 := 2451900.05952 + 365242.74049 * yy - 0.06223 * yy ** 2 - 0.00823 * yy ** 3 + 0.00032 * yy ** 4
    }
    tt := (jde0 - 2451545.0) / 36525
    ww := (35999.373 * tt - 2.47) * rad
    dl := 1 + 0.0334 * Cos(ww) + 0.0007 * Cos(2 * ww)
    somme := 0
    Loop TA.Length
        somme += TA[A_Index] * Cos((TB[A_Index] + TC[A_Index] * tt) * rad)
    jde := jde0 + 0.00001 * somme / dl
    return Round((jde - 2440587.5) * 86400 - 69)  ; temps terrestre → temps universel
}

; Nom d'une saison ; dans l'hémisphère sud, les saisons sont inversées
NomSaison(n) {
    static NORD := ["Équinoxe de printemps", "Solstice d'été", "Équinoxe d'automne", "Solstice d'hiver"]
    static SUD := ["Équinoxe d'automne", "Solstice d'hiver", "Équinoxe de printemps", "Solstice d'été"]
    return (IsNumber(Donnees.Get("lat", "")) && Number(Donnees["lat"]) < 0) ? SUD[n + 1] : NORD[n + 1]
}

; Prochaine saison à partir du jour ymd (compris) : {n, t, jour (AAAAMMJJ local), nom}
ProchaineSaison(ymd) {
    an := Integer(SubStr(ymd, 1, 4))
    Loop 2 {
        a := an + A_Index - 1
        Loop 4 {
            t := InstantSaison(a, A_Index - 1), jour := Integer(SubStr(LocalDeUnix(t), 1, 8))
            if (jour >= ymd)
                return {n: A_Index - 1, t: t, jour: jour, nom: NomSaison(A_Index - 1)}
        }
    }
}

; ---------- Calendrier ----------

; Événements (voir EvenementsCalendrier), dès J-3 : changement d'heure, saison
EvenementsLumiere(auj) {
    ev := []
    if CalHeure && IsObject(c := ProchainChangementHeure(PlusJours(auj, -1), 5)) {
        n := JoursAvant(c.jour), sens := c.hiver ? "on recule d'1 h" : "on avance d'1 h"
        nomH := c.hiver ? "Heure d'hiver" : "Heure d'été"
        if (n = 0 && MomentUnix() >= c.t)
            ev.Push({rang: 3, genre: "heure", long: nomH " depuis cette nuit", court: nomH, date: c.jour})
        else if (n = 1 || n = 0)                  ; (entre minuit et 3 h, le changement n'a pas encore eu lieu)
            ev.Push({rang: 3, genre: "heure", long: "Cette nuit, " sens " (" c.avant " → " c.apres ")", court: "Cette nuit : " (c.hiver ? "−1 h" : "+1 h"), date: c.jour})
        else if (n > 1 && n <= 3)
            ev.Push({rang: 3, genre: "heure", long: Majuscule(FormatTime(String(c.jour), "dddd")) " : " sens " (" c.avant " → " c.apres ")",
                court: Majuscule(FormatTime(String(c.jour), "dddd")) " : " (c.hiver ? "−1 h" : "+1 h"), date: c.jour})
    }
    if CalSaisons && IsObject(s := ProchaineSaison(auj)) {
        n := JoursAvant(s.jour), h := FormatTime(LocalDeUnix(s.t), "HH:mm")
        quand := (n = 0) ? "aujourd'hui" : (n = 1) ? "demain" : FormatTime(String(s.jour), "dddd")
        if (n <= 3)
            ev.Push({rang: 3, genre: "saison", long: s.nom " " quand " à " h, court: s.nom, date: s.jour})
    }
    return ev
}

; Pour le cache du calendrier : le changement d'heure d'aujourd'hui a-t-il eu
; lieu ? (« " » s'il n'y en a pas aujourd'hui)
CleHeureChangee() {
    c := ProchainChangementHeure(PlusJours(Aujourdhui(), -1), 2)
    return (IsObject(c) && JoursAvant(c.jour) = 0) ? (MomentUnix() >= c.t) : ""
}

; Pour la fenêtre des prévisions : [{genre, titre, detail}]
ListeLumiere(auj) {
    liste := [], j := Chr(0xA0) "j"
    Quand(d) => (JoursAvant(d) = 0) ? "aujourd'hui" : (JoursAvant(d) = 1) ? "demain" : "dans " JoursAvant(d) j
    if CalSaisons && IsObject(s := ProchaineSaison(auj))
        liste.Push({genre: "saison", titre: s.nom, detail: DateCourte(s.jour) " à " FormatTime(LocalDeUnix(s.t), "HH:mm") " · " Quand(s.jour)})
    if CalHeure {                                 ; (l'été dure jusqu'à 217 jours : 222 de recherche)
        c := ProchainChangementHeure(PlusJours(auj, -1), 222)   ; la nuit même, avant 3 h : celui de cette nuit
        if (IsObject(c) && c.t <= MomentUnix())
            c := ProchainChangementHeure(auj, 222)
    }
    if (CalHeure && IsObject(c))
        liste.Push({genre: "heure", titre: c.hiver ? "Passage à l'heure d'hiver" : "Passage à l'heure d'été",
            detail: DateCourte(c.jour) " à " c.avant " · " Quand(c.jour)})
    return liste
}

; ---------- Menus ----------

BasculerDureeJour(*) {
    global DureeJour
    DureeJour := !DureeJour
    SauverReglages()
    CocherMenus()
    Redessiner()
}

BasculerUV(*) {
    global UvW
    UvW := !UvW
    SauverReglages()
    CocherMenus()
    Redessiner(true)                              ; la bande peut gagner une ligne
}

; ---------- Tests ----------

; Auto-test : saisons contre l'USNO, changement d'heure, textes
TestLumiere(fichier) {
    global HeureTest, CalHeure, CalSaisons, Donnees
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    Utc(t) => FormatTime(DateAdd("19700101", t, "Seconds"), "yyyy-MM-dd HH:mm")
    ; références USNO (aa.usno.navy.mil/api/seasons, heures UTC) : écart d'au plus 2 min
    for r in [[2026, 0, "20260320144600"], [2026, 1, "20260621082400"], [2026, 2, "20260923000500"], [2026, 3, "20261221205000"], [2027, 0, "20270320202500"]] {
        t := InstantSaison(r[1], r[2]), ref := DateDiff(r[3], "19700101", "Seconds")
        Verifier(Abs(t - ref) <= 120, "saison " r[1] "/" r[2] " : " Utc(t) " UTC (USNO " Utc(ref) ", écart " Round((t - ref) / 60, 1) " min)")
    }
    c := ProchainChangementHeure(20261020, 10)
    Verifier(IsObject(c) && c.jour = 20261025 && c.hiver && c.avant = "3 h" && c.apres = "2 h" && Utc(c.t) = "2026-10-25 01:00",
        "heure d'hiver : dim. 25/10/2026, 3 h → 2 h (" (IsObject(c) ? c.jour " " c.avant " → " c.apres " à " Utc(c.t) " UTC" : "rien") ")")
    c := ProchainChangementHeure(20270301, 40)
    Verifier(IsObject(c) && c.jour = 20270328 && !c.hiver && c.avant = "2 h" && c.apres = "3 h", "heure d'été : dim. 28/03/2027, 2 h → 3 h")
    Verifier(!IsObject(ProchainChangementHeure(20260924, 20)), "rien entre le 24/09 et le 14/10")
    CalHeure := true, CalSaisons := true
    Donnees := Map("lat", "48.76")
    for cas in [["20261022", "Dimanche : on recule d'1 h (3 h → 2 h)"], ["20261024", "Cette nuit, on recule d'1 h (3 h → 2 h)"],
        ["20261025", "Heure d'hiver depuis cette nuit"], ["20261021", ""]] {
        HeureTest := cas[1] "120000"
        ev := EvenementsLumiere(Aujourdhui()), txt := ""
        for e in ev
            if (e.genre = "heure")
                txt := e.long
        Verifier(txt = cas[2], cas[1] " : « " txt " »")
    }
    HeureTest := "20260923120000"
    ev := EvenementsLumiere(Aujourdhui()), txt := ""
    for e in ev
        if (e.genre = "saison")
            txt := e.long
    Verifier(txt = "Équinoxe d'automne aujourd'hui à 02:05", "23/09/2026 : « " txt " »")
    HeureTest := "20261218120000"
    ev := EvenementsLumiere(Aujourdhui()), txt := ""
    for e in ev
        if (e.genre = "saison")
            txt := e.long
    Verifier(txt = "Solstice d'hiver lundi à 21:50", "18/12/2026 : « " txt " »")
    Verifier(DureeTexte(43485) = "12 h 05" && EcartTexte(-214) = Chr(0x2212) "3 min 34" && EcartTexte(12) = "+12" Chr(0xA0) "s", "textes de la durée du jour")
    FileAppend(rapport "`n" echecs " échec(s)`n", fichier, "UTF-8")
}
