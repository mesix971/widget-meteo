; =============================================================================
;  Widget météo — styles « En toutes lettres » et « Analogique » (menu Style)
;  — inclus par widget-meteo.ahk
;
;  En toutes lettres : « Il est dix heures moins le quart », en français
;  courant (midi et demi, minuit une, une heure et demie…), à la minute près
;  ou arrondie aux 5 minutes (avec 4 points pour les minutes en plus), et en
;  option « du matin / de l'après-midi / du soir ». La taille des lettres est
;  calculée pour que TOUTES les phrases de la journée tiennent : elle ne bouge
;  jamais d'une minute à l'autre.
;  Analogique : cadran épuré (graduations, ou chiffres 12-3-6-9), aiguilles des
;  heures et des minutes, météo à côté ou sous le cadran.
;  Dans les deux styles, l'heure (formes « z ») passe derrière le sujet du fond
;  d'écran avec l'effet profondeur, et suit la police et le rendu choisis.
;  (Constantes et état : STYLES, PRECISIONS, DISPOS_CADRAN, LETTRES_*, CADRAN_*,
;  LettresPrecision, LettresMoment, CadranMeteo, CadranChiffres…, déclarés dans
;  widget-meteo.ahk.)
; =============================================================================

; Forme canonique d'un style (reglages.ini peut avoir été écrit à la main)
StyleConnu(s) {
    for v in STYLES
        if (v[1] = s)
            return v[1]
    return "android"
}

; Réglage parmi une liste de choix (forme canonique), sinon le défaut
LireChoix(cle, defaut, choix) {
    v := Trim(IniRead(F_REGLAGES, "widget", cle, defaut))
    for c in choix
        if (c = v)
            return c
    return defaut
}

; Hauteur ajoutée par le style : le cadran au-dessus de la météo
ExtraStyle() => (Style = "analogique" && CadranMeteo = "dessous") ? CADRAN_DESSOUS : 0

; Ce qui change à l'écran d'une minute à l'autre : en « Arrondie aux 5
; minutes » sans points, l'image ne change que toutes les 5 minutes (sauf
; si l'heure d'une 2e ville est affichée), ou quand la pastille de l'ISS change
; (« ISS à 21:16 » → « ISS visible maintenant »)
CleAffichage(m) => (Style = "lettres" && LettresPrecision = "cinq" && !(Ville2W && Ville2Definie()))
    ? SubStr(m, 1, 2) "|" (Integer(SubStr(m, 3)) // 5) (IssW && IsObject(q := PastilleIss()) ? "|" q.textes[3] : "") : m

; Nombre au féminin (les minutes) : une, vingt et une, trente-neuf…
NombreFeminin(n) {
    static UNITES := ["une", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix",
        "onze", "douze", "treize", "quatorze", "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf"]
    if (n < 20)
        return UNITES[n]
    dizaine := (n < 30) ? "vingt" : "trente", reste := Mod(n, 10)
    return (reste = 0) ? dizaine : (reste = 1) ? dizaine " et une" : dizaine "-" UNITES[reste]
}

; L'heure h:m en français courant : {intro, heure, minutes, moment}
; « moins » dès :40 (à la minute) ou :35 (aux 5 minutes), avec l'heure suivante ;
; « midi et demi » au masculin (Académie), « une heure et demie » au féminin ;
; le moment suit l'heure NOMMÉE (17:40 : « six heures moins vingt du soir »),
; jamais après midi ni minuit
PhraseHeure(h, m, cinq := false, moment := false) {
    static HEURES := ["une heure", "deux heures", "trois heures", "quatre heures", "cinq heures", "six heures",
        "sept heures", "huit heures", "neuf heures", "dix heures", "onze heures"]
    if cinq
        m -= Mod(m, 5)
    moins := (m >= (cinq ? 35 : 40))
    if moins
        h := Mod(h + 1, 24), m := 60 - m
    nom := (h = 0) ? "minuit" : (h = 12) ? "midi" : HEURES[Mod(h, 12)]
    if moins
        mn := (m = 15) ? "moins le quart" : "moins " NombreFeminin(m)
    else if (m = 0)
        mn := ""
    else if (m = 15)
        mn := "et quart"
    else if (m = 30)
        mn := (h = 0 || h = 12) ? "et demi" : "et demie"
    else
        mn := NombreFeminin(m)
    qual := (!moment || h = 0 || h = 12) ? "" : (h < 12) ? "du matin" : (h < 18) ? "de l'après-midi" : "du soir"
    return {intro: "Il est", heure: nom, minutes: mn, moment: qual}
}

; Gabarit de la phrase pour la largeur WC : 2 ou 3 lignes, et la capitale (en u)
; qui fait tenir toutes les phrases de la journée dans la bande LETTRES_T–B.
; Les largeurs (en capitales) sont mesurées une fois par police et réglage.
GabaritLettres(WC, police) {
    static cache := Map()
    cle := police "|" P_LETTRES_INTRO "|" LettresPrecision "|" LettresMoment
    if !cache.Has(cle) {
        largeurs := Map()
        L1(txt, pol, cap := 1) {                  ; largeur d'un texte, en capitales
            c := pol "|" txt "|" cap
            if !largeurs.Has(c)
                largeurs[c] := LargeurTexte(txt, pol, EmPourCapitale(pol, 100 * cap)) / 100
            return largeurs[c]
        }
        esp := L1("x x", police) - 2 * L1("x", police)
        w3 := 0, w2 := 0, cinq := (LettresPrecision != "minute")
        Loop 24 {
            h := A_Index - 1
            Loop 60 {
                ph := PhraseHeure(h, A_Index - 1, cinq, LettresMoment)
                q := (ph.moment != "") ? LETTRES_QUAL_ECART + L1(ph.moment, police, LETTRES_QUAL) : 0
                li := L1(ph.intro, P_LETTRES_INTRO), lh := L1(ph.heure, police)
                lm := (ph.minutes != "") ? L1(ph.minutes, police) : 0
                fin := (ph.minutes = "") ? lh + q : lh        ; le moment suit la dernière ligne non vide
                w3 := Max(w3, li, fin, (ph.minutes != "") ? lm + q : 0)
                w2 := Max(w2, li + esp + fin, (ph.minutes != "") ? lm + q : 0)
            }
        }
        cache[cle] := {w3: w3, w2: w2, esp: esp}
    }
    g := cache[cle], bande := LETTRES_B - LETTRES_T
    c3 := Min(bande / (1 + 2 * LETTRES_PAS), WC / g.w3)
    c2 := Min(bande / (1 + LETTRES_PAS), WC / g.w2)
    return (c2 > 1.12 * c3) ? {lignes: 2, cap: c2, esp: g.esp} : {lignes: 3, cap: c3, esp: g.esp}
}

; Style « En toutes lettres » : la date en haut à gauche, la phrase en grand,
; la météo en petit dessous
ComposerLettres(w, h, k, t) {
    global BlocHeure
    L := []
    u  := HC * k
    ox := PAD * k, oy := PAD * k + 0.012 * u
    X(v) => ox + v * u
    Y(v) => oy + v * u
    WC := LargeurContenu(), ts := MomentAffiche()
    i := InfosAffichage()
    points := (LettresPrecision = "points")

    ; ---- date, et les 4 points des minutes en plus (mode « points »)
    emD := EmPourCapitale(P_DATE, 0.0654 * u)
    PoserDate(L, emD, 0.0654 * u, X(0), Y(0.075), 0, WC * u - (points ? 4 * 0.052 * u + 0.04 * u : 0), t.second)
    if points {
        allumes := Mod(Integer(FormatTime(ts, "m")), 5), r := 0.018 * u
        Loop 4 {
            cxp := X(WC) - r - (4 - A_Index) * 0.052 * u, cyp := Y(0.075) - 0.0327 * u
            DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
            DllCall("gdiplus\GdipAddPathEllipse", "Ptr", p, "Float", cxp - r, "Float", cyp - r, "Float", 2 * r, "Float", 2 * r)
            allume := (A_Index <= allumes)
            L.Push({p: p, f: allume ? t.accent : 0x40000000 | (t.accent & 0xFFFFFF), o: OmbreTheme(), z: false, a: allume ? 1 : 0.4})
        }
    }

    ; ---- la phrase
    g := GabaritLettres(WC, t.heure)
    ph := PhraseHeure(Integer(FormatTime(ts, "H")), Integer(FormatTime(ts, "m")), LettresPrecision != "minute", LettresMoment)
    cap := g.cap * u, pas := LETTRES_PAS * cap
    emI := EmPourCapitale(P_LETTRES_INTRO, cap), emH := EmPourCapitale(t.heure, cap)
    yb := Y(LETTRES_T) + cap + (Y(LETTRES_B) - Y(LETTRES_T) - (cap + (g.lignes - 1) * pas)) / 2
    n0 := L.Length
    if (g.lignes = 3) {
        Poser(L, ph.intro, P_LETTRES_INTRO, emI, X(0), yb, 0, t.second)
        derniere := Poser(L, ph.heure, t.heure, emH, X(0), yb + pas, 0, t.accent), yder := yb + pas
        if (ph.minutes != "")
            derniere := Poser(L, ph.minutes, t.heure, emH, X(0), yb + 2 * pas, 0, t.accent), yder := yb + 2 * pas
    } else {
        Poser(L, ph.intro, P_LETTRES_INTRO, emI, X(0), yb, 0, t.second)
        xh := X(0) + LargeurTexte(ph.intro, P_LETTRES_INTRO, emI) + g.esp * cap
        derniere := Poser(L, ph.heure, t.heure, emH, xh, yb, 0, t.accent), yder := yb
        if (ph.minutes != "")
            derniere := Poser(L, ph.minutes, t.heure, emH, X(0), yb + pas, 0, t.accent), yder := yb + pas
    }
    if (ph.moment != "")
        Poser(L, ph.moment, t.heure, EmPourCapitale(t.heure, LETTRES_QUAL * cap),
            derniere.x + derniere.w + LETTRES_QUAL_ECART * cap, yder, 0, t.second)
    bz := ""
    Loop L.Length - n0 {                          ; la phrase passe derrière le sujet
        L[n0 + A_Index].z := true
        bz := Union(bz, Bornes(L[n0 + A_Index].p))
    }
    BlocHeure := {x: bz.x, y: bz.y, w: bz.w, h: bz.h, cap: cap}   ; rendu (contour, dégradé, verre)

    ; ---- météo : illustration, température, lieu ; résumé sur une ligne
    em := EmPourCapitale(P_TEXTE, 0.0635 * u)
    s := Donnees.Has("code") ? 0.12 * u : 0, ecart := s ? 0.025 * u : 0
    debut := (i.temp != "") ? i.temp Chr(0xB0) "  ·  " : ""
    ligne := debut LieuAjuste(i, em, WC * u - s - ecart - LargeurTexte(debut "x", P_TEXTE, em) + LargeurTexte("x", P_TEXTE, em))
    if s
        IconeWidget(L, Illustration(Donnees["code"], Donnees.Get("jour", "1")), X(0), Y(0.877) - 0.0318 * u - s / 2, s)
    b := Poser(L, ligne, P_TEXTE, em, X(0) + s + ecart, Y(0.877), 0, t.texte)
    NoterZoneTemp(s ? {x: X(0), y: Y(0.877) - 0.0318 * u - s / 2, w: s, h: s} : "", X(0) + s + ecart, b, i.temp, em)
    if (i.texte != "" || i.maxi != "")
        for ligne in Adapter(i.texte, i.maxi, P_TEXTE, em, WC * u, 1, i.normale)
            Poser(L, ligne, P_TEXTE, em, X(0), Y(0.997), 0, t.second)
    LigneBasseComposer(L, t, u, X(0), WC, Y(1.065), 0)
    return L
}

; Cadran épuré centré en (cx, cy), rayon R (px) : graduations (ou chiffres
; 12-3-6-9), aiguilles à bouts ronds et pastille. Tout est « z » (l'effet
; profondeur fait passer le sujet devant) ; angles depuis midi, sens horaire.
Cadran(L, t, cx, cy, R, ts) {
    static rad := 0.017453292519943295, CHIFFRES := ["12", "3", "6", "9"]
    Px(a, r) => cx + r * Sin(a * rad)
    Py(a, r) => cy - r * Cos(a * rad)
    Trait(a1, r1, a2, r2, ep, couleur) {
        DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
        DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", Px(a1, r1), "Float", Py(a1, r1), "Float", Px(a2, r2), "Float", Py(a2, r2))
        Elargir(p, ep)
        L.Push({p: p, f: couleur, o: OmbreTheme(), z: true})
    }
    Loop 12 {
        a := (A_Index - 1) * 30
        if Mod(A_Index - 1, 3) {
            Trait(a, 0.86 * R, a, 0.95 * R, 0.028 * R, t.second)
            continue
        }
        if CadranChiffres {                        ; 12, 3, 6, 9 à la place des grandes graduations
            capc := 0.13 * R
            Poser(L, CHIFFRES[(A_Index - 1) // 3 + 1], t.heure, EmPourCapitale(t.heure, capc),
                Px(a, 0.84 * R), Py(a, 0.84 * R) + capc / 2, 1, t.texte)
            L[L.Length].z := true
        } else
            Trait(a, 0.78 * R, a, 0.95 * R, 0.045 * R, t.texte)
    }
    hh := Integer(FormatTime(ts, "H")), mm := Integer(FormatTime(ts, "m"))
    ah := Mod(hh, 12) * 30 + mm * 0.5, am := mm * 6
    Trait(ah + 180, 0.10 * R, ah, 0.52 * R, 0.075 * R, t.accent)
    Trait(am + 180, 0.12 * R, am, (CadranChiffres ? 0.68 : 0.82) * R, 0.048 * R, t.accent)   ; plus courte avec les chiffres
    r := 0.07 * R
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", p, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r)
    L.Push({p: p, f: t.accent, o: OmbreTheme(), z: true})
}

; Style « Analogique » : cadran à droite et météo à gauche (« à côté »), ou
; cadran centré en haut et météo dessous (« dessous », widget plus haut)
ComposerAnalogique(w, h, k, t) {
    global BlocHeure
    L := []
    u  := HC * k
    ox := PAD * k, oy := PAD * k + 0.012 * u
    X(v) => ox + v * u
    Y(v) => oy + v * u
    WC := LargeurContenu(), ts := MomentAffiche()
    i := InfosAffichage()
    emD := EmPourCapitale(P_DATE, 0.0654 * u)
    em := EmPourCapitale(P_TEXTE, 0.0635 * u)

    if (CadranMeteo = "dessous") {
        R := CADRAN_R_MAX
        Cadran(L, t, X(WC / 2), Y(0.50), R * u, ts)
        BlocHeure := {x: X(WC / 2 - R), y: Y(0.50 - R), w: 2 * R * u, h: 2 * R * u, cap: 0.5 * R * u}
        PoserDate(L, emD, 0.0654 * u, X(WC / 2), Y(1.105), 1, (WC - 0.1) * u, t.accent)
        ; ligne météo centrée : illustration, température, lieu
        s := Donnees.Has("code") ? 0.12 * u : 0, ecart := s ? 0.025 * u : 0
        debut := (i.temp != "") ? i.temp Chr(0xB0) "  ·  " : ""
        ligne := debut LieuAjuste(i, em, (WC - 0.1) * u - s - ecart - LargeurTexte(debut "x", P_TEXTE, em) + LargeurTexte("x", P_TEXTE, em))
        lt := LargeurTexte(ligne, P_TEXTE, em)
        gauche := X(WC / 2) - (s + ecart + lt) / 2
        if s
            IconeWidget(L, Illustration(Donnees["code"], Donnees.Get("jour", "1")), gauche, Y(1.225) - 0.0318 * u - s / 2, s)
        b := Poser(L, ligne, P_TEXTE, em, gauche + s + ecart, Y(1.225), 0, t.texte)
        NoterZoneTemp(s ? {x: gauche, y: Y(1.225) - 0.0318 * u - s / 2, w: s, h: s} : "", gauche + s + ecart, b, i.temp, em)
        if (i.texte != "" || i.maxi != "")
            for ligne in Adapter(i.texte, i.maxi, P_TEXTE, em, (WC - 0.1) * u, 1, i.normale)
                Poser(L, ligne, P_TEXTE, em, X(WC / 2), Y(1.345), 1, t.second)
        alignSoleil := 1
    } else {
        R := Max(CADRAN_R_MIN, Min(CADRAN_R_MAX, (WC - CADRAN_COL_MIN - CADRAN_ECART) / 2))
        col := WC - 2 * R - CADRAN_ECART
        Cadran(L, t, X(WC - R), Y(0.50), R * u, ts)
        BlocHeure := {x: X(WC - 2 * R), y: Y(0.50 - R), w: 2 * R * u, h: 2 * R * u, cap: 0.5 * R * u}
        PoserDate(L, emD, 0.0654 * u, X(0), Y(0.075), 0, col * u, t.accent)
        ; température en grand et son illustration, si elle tient dans la colonne
        if (i.temp != "") {
            cap := 0.184 * u
            emT := (t.temp != t.gros) ? EmHeure(t.temp, cap) : EmPourCapitale(t.gros, cap)
            bt := Poser(L, i.temp, t.temp, emT, X(0), Y(0.335), 0, t.accent)
            PoserEncre(L, "°", t.temp, emT, bt.x + bt.w + 0.11 * cap, Y(0.335), t.accent)
            NoterZone("meteo", {x: bt.x, y: bt.y, w: bt.w + 0.6 * cap, h: bt.h})   ; (« ° » compris)
            s := 0.22 * u, xi := bt.x + bt.w + 0.53 * cap + 0.05 * u
            if (Donnees.Has("code") && xi + s <= X(col)) {
                IconeWidget(L, Illustration(Donnees["code"], Donnees.Get("jour", "1")), xi, Y(0.335) - cap / 2 - s / 2, s)
                NoterZone("meteo", {x: xi, y: Y(0.335) - cap / 2 - s / 2, w: s, h: s})
            }
        }
        Epingle(L, X(0.0515), Y(0.4336), u, t.second)
        Poser(L, LieuAjuste(i, em, X(col) - X(0.114)), P_TEXTE, em, X(0.114), Y(0.472), 0, t.second)
        if (i.texte != "" || i.maxi != "") {
            lignes := Adapter(i.texte, i.maxi, P_TEXTE, em, Min(col, 1.9) * u, (col < 0.9) ? 4 : 3, i.normale)
            for ligne in lignes
                Poser(L, ligne, P_TEXTE, em, X(0), Y(0.997 - (lignes.Length - A_Index) * 0.120), 0, t.texte)
        }
        alignSoleil := 0
    }
    LigneBasseComposer(L, t, u, X(0), WC, Y(1.065 + ExtraStyle()), alignSoleil)
    return L
}

ChoisirPrecision(v, *) {
    global LettresPrecision := v, Style := "lettres"
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

BasculerMoment(*) {
    global LettresMoment, Style
    LettresMoment := !LettresMoment, Style := "lettres"
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

ChoisirDispoCadran(v, *) {
    global CadranMeteo := v, Style := "analogique"
    SauverReglages()
    CocherMenus()
    Redessiner(true)                              ; la hauteur change
}

BasculerChiffres(*) {
    global CadranChiffres, Style
    CadranChiffres := !CadranChiffres, Style := "analogique"
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

; Mode de test /phrases : les 4 × 1 440 phrases (oracle de non-régression)
TablePhrases(fichier) {
    txt := ""
    for reg in [["à la minute", false, false], ["aux 5 minutes", true, false], ["à la minute + moment", false, true], ["aux 5 minutes + moment", true, true]] {
        txt .= "=== " reg[1] " ===`n"
        Loop 24 {
            h := A_Index - 1
            Loop 60 {
                ph := PhraseHeure(h, A_Index - 1, reg[2], reg[3])
                txt .= Format("{:02}:{:02}", h, A_Index - 1) "`t" ph.intro " " ph.heure
                    . ((ph.minutes != "") ? " " ph.minutes : "") ((ph.moment != "") ? " " ph.moment : "") "`n"
            }
        }
    }
    try FileDelete(fichier)
    FileAppend(txt, fichier, "UTF-8")
}
