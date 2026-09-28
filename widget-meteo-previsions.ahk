; =============================================================================
;  Widget météo — prévisions : rangée des prochaines heures et fenêtre détaillée
;  (inclus par widget-meteo.ahk)
; =============================================================================

; ---------- Rangée « heure par heure » ----------

; Minutes depuis minuit d'un « HH:MM »
Minutes(hhmm) => (StrLen(hhmm) >= 5) ? Integer(SubStr(hhmm, 1, 2)) * 60 + Integer(SubStr(hhmm, 4, 2)) : -1

; Les n prochains créneaux affichés (5 à 12 selon la largeur du widget) :
; heures pleines tirées de donnees.txt (12 au plus), avec
; le lever ou le coucher du soleil inséré à sa place (comme le widget Google)
; si l'option « Lever et coucher du soleil » est cochée.
CreneauxAVenir(n := 6) {
    slots := [], prec := -1, jourPlus := 0
    for bloc in StrSplit(Donnees.Get("heures", ""), ";") {
        v := StrSplit(bloc, ",")
        if (v.Length < 5)
            continue
        m := Minutes(v[1])
        if (prec >= 0 && m < prec)
            jourPlus += 1440                       ; passage de minuit
        prec := m
        slots.Push({m: m + jourPlus, lab: Integer(SubStr(v[1], 1, 2)) " h", id: Illustration(v[2], v[3]),
            temp: IsNumber(v[4]) ? Round(Number(v[4])) : "", proba: IsNumber(v[5]) ? Integer(v[5]) : 0, soleil: ""})
    }
    if !slots.Length
        return slots
    maintenant := Minutes(FormatTime(MomentAffiche(), "HH:mm"))
    ; créneaux après minuit alors qu'il est 23 h : le premier est « bien avant »
    ; maintenant (plus de 12 h) ; quelques minutes de retard ne changent pas de jour
    if (slots[1].m < maintenant - 720)
        for s in slots
            s.m += 1440
    evts := []
    for e in (Soleil ? [["lever", "lever", 0], ["coucher", "coucher", 0], ["lever2", "lever", 1440], ["coucher2", "coucher", 1440]] : []) {
        m := Minutes(Donnees.Get(e[1], ""))
        if (m >= 0)
            evts.Push({m: m + e[3], lab: Donnees[e[1]], soleil: e[2]})
    }
    if LuneLever                                   ; lever et coucher de la lune, insérés de même
        for e in [["lune_lever", "lever", 0], ["lune_coucher", "coucher", 0], ["lune_lever2", "lever", 1440], ["lune_coucher2", "coucher", 1440]] {
            m := Minutes(Donnees.Get(e[1], ""))
            if (m >= 0)
                evts.Push({m: m + e[3], lab: Donnees[e[1]], soleil: e[2], lune: true})
        }
    for ev in evts {
        if (ev.m <= maintenant || ev.m >= slots[slots.Length].m)
            continue
        pos := 1
        while (pos <= slots.Length && slots[pos].m < ev.m)
            pos++
        slots.InsertAt(pos, ev)
    }
    while (slots.Length > n)
        slots.Pop()
    return slots
}

; Dessine la rangée dans le rectangle (x0, yHaut, largeur), unité u. Par
; créneau, de haut en bas : l'heure, l'illustration, la probabilité de pluie
; (goutte + « 40 % », seulement à partir de 30 %), la température. Pour le
; lever ou le coucher du soleil : l'heure exacte, le soleil sur l'horizon, « Coucher ».
RangeeHeures(L, t, u, x0, largeur, yHaut, n := 6) {
    slots := CreneauxAVenir(n)
    if !slots.Length
        return
    lc := largeur / slots.Length
    emH := EmPourCapitale(P_TEXTE, 0.050 * u), emT := EmPourCapitale(P_TEXTE, 0.060 * u)
    emP := EmPourCapitale(P_TEXTE, 0.040 * u)
    ti := 0.13 * u, yi := yHaut + 0.075 * u, bas := yHaut + 0.335 * u
    for s in slots {
        cx := x0 + (A_Index - 0.5) * lc
        Poser(L, s.lab, P_TEXTE, emH, cx, yHaut + 0.05 * u, 1, t.second)
        if (s.soleil != "") {
            if s.HasOwnProp("lune")
                LuneHorizon(L, s.soleil, cx - ti / 2, yi, ti)
            else
                SoleilHorizon(L, s.soleil, cx - ti / 2, yi, ti)
            Poser(L, (s.soleil = "lever") ? "Lever" : "Coucher", P_TEXTE, emH, cx, bas, 1, t.second)
            continue
        }
        IllustrerTheme(L, s.id, cx - ti / 2, yi, ti)
        if (s.proba >= 30) {
            gp := s.proba " %", lg := 0.024 * u, ecart := 0.01 * u
            lp := LargeurTexte(gp, P_TEXTE, emP)
            x := cx - (lg + ecart + lp) / 2, yp := yHaut + 0.258 * u
            Goutte(L, x, yp - 0.043 * u, lg)
            Poser(L, gp, P_TEXTE, emP, x + lg + ecart, yp, 0, t.second)
        }
        Poser(L, s.temp "°", P_TEXTE, emT, cx, bas, 1, t.texte)
    }
}

; Lever et coucher du soleil et / ou de la lune sur une ligne (options sans la
; rangée des heures) : alignée à gauche (align 0) ou centrée (1)
LigneSoleil(L, t, u, x0, largeur, yHaut, align) {
    em := EmPourCapitale(P_TEXTE, 0.055 * u), ti := 0.085 * u, ecart := 0.02 * u, entre := 0.09 * u
    yb := yHaut + 0.085 * u                        ; ligne de base du texte
    blocs := []
    if Soleil
        for e in [["lever", Donnees.Get("lever", "")], ["coucher", Donnees.Get("coucher", "")]]
            if (e[2] != "")
                blocs.Push({sens: e[1], txt: e[2], lune: false})
    if LuneLever                                   ; prochains lever et coucher de la lune
        for ev in ProchainsLune()
            blocs.Push({sens: ev.sens, txt: ev.lab, lune: true})
    if !blocs.Length
        return
    for b in blocs
        b.l := ti + ecart + LargeurTexte(b.txt, P_TEXTE, em)
    total := -entre
    for b in blocs
        total += b.l + entre
    ; durée du jour (option) : la forme la plus complète qui tient, sinon rien
    if (Soleil && DureeJour)
        for txt in TextesDureeJour() {
            lg := ti + ecart + LargeurTexte(txt, P_TEXTE, em)   ; (surtout pas « l » : c'est L, la liste)
            if (total + entre + lg <= largeur) {
                blocs.InsertAt(2 + (blocs.Length >= 2 && !blocs[2].lune), {sens: "duree", txt: txt, lune: false, l: lg})   ; après le coucher
                total += entre + lg
                break
            }
        }
    x := align ? x0 + (largeur - total) / 2 : x0
    for b in blocs {
        if b.lune
            LuneHorizon(L, b.sens, x, yb - 0.078 * u, ti)
        else if (b.sens = "duree")
            ArcSoleil(L, x, yb - 0.078 * u, ti)
        else
            SoleilHorizon(L, b.sens, x, yb - 0.078 * u, ti)
        Poser(L, b.txt, P_TEXTE, em, x + ti + ecart, yb, 0, t.texte)
        x += b.l + entre
    }
}

; Petite goutte bleue (probabilité de pluie), largeur lg, pointe en (x + lg/2, y).
; Fond rond : arc de 240° par le bas (de -30° à 210°, angles GDI+ comptés vers
; le bas) ; les deux côtés sont tangents au cercle, la pointe à 2 rayons du centre.
Goutte(L, x, y, lg) {
    r := lg / 2, cx := x + r, cy := y + 2 * r
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r, "Float", -30, "Float", 240)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", cx - r * 0.866, "Float", cy - r * 0.5, "Float", cx, "Float", y)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    L.Push({p: p, f: C_PLUIE, o: 0x000000, z: false})
}

; Icône lever / coucher : demi-soleil posé sur l'horizon, flèche au-dessus
SoleilHorizon(L, sens, X, Y, S) {
    c := {x: X, y: Y, u: S / 100}
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", c.x + 22 * c.u, "Float", c.y + 44 * c.u, "Float", 56 * c.u, "Float", 56 * c.u, "Float", 180, "Float", 180)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    L.Push({p: p, f: C_SOLEIL, o: 0x000000, z: false})
    Barre(L, c, 8, 92, 75, C_BRUME[1])
    L[L.Length].o := 0x000000, L[L.Length].z := false
    y1 := (sens = "lever") ? 32 : 12, y2 := (sens = "lever") ? 12 : 32, pointe := y2
    Traits(L, c, [[50, y1, 50, y2], [41, pointe + ((sens = "lever") ? 9 : -9), 50, pointe], [59, pointe + ((sens = "lever") ? 9 : -9), 50, pointe]], 5, 0xFFFFFFFF)
    L[L.Length].o := 0x000000, L[L.Length].z := false
}

; ---------- Fenêtre de prévisions détaillées ----------
; Ouverte par un clic sur l'illustration ou la température du widget, sur
; l'icône de notification, ou par le menu. Elle se ferme d'un clic,
; avec Échap, ou dès qu'on clique ailleurs.
; (état : PopupGui et PopupHwnd, déclarés dans widget-meteo.ahk)

; Heure locale « HH:mm » d'un horodatage Unix (UTC)
HeureLocaleUnix(sec) => FormatTime(LocalDeUnix(Integer(sec)), "HH:mm")   ; (heure d'été ou d'hiver de ce jour-là)

LirePrevisions(f := "") {
    p := {jours: [], heures: [], cal: ""}
    ; calendrier (options) : la liste, ou "" s'il n'y a rien à montrer
    if (CalPrevisions && (CalSemaine || CalendrierActif())) {
        liste := ListeCalendrier()
        if (liste.Length || CalSemaine)
            p.cal := liste
    }
    if (f = "")
        f := DOSSIER "\previsions.txt"
    if !FileExist(f)
        return p
    for ligne in StrSplit(FileRead(f, "UTF-8"), "`n", "`r") {
        v := StrSplit(ligne, "|")
        if (v.Length >= 13 && v[1] = "J")
            p.jours.Push({date: v[2], code: v[3], min: v[4], max: v[5], proba: v[6], pluie: v[7], vent: v[8],
                rafales: v[9], dir: v[10], uv: v[11], lever: v[12], coucher: v[13],
                llev: (v.Length >= 14) ? v[14] : "", lcou: (v.Length >= 15) ? v[15] : ""})   ; lune (2.6.0)
        else if (v.Length >= 9 && v[1] = "H")
            p.heures.Push({t: v[2], code: v[3], jour: v[4], temp: v[5], proba: v[6], pluie: v[7], vent: v[8], dir: v[9]})
    }
    return p
}

; Clic sur l'icône de la zone de notification : bascule. Si la fenêtre était
; ouverte, le crochet des clics vient de la fermer pour ce même clic (« clic
; ailleurs » : la barre des tâches) ; la rouvrir la ferait clignoter.
PrevisionsIcone(*) {
    if (A_TickCount - SurgieClicAilleurs < 500)
        return
    OuvrirPrevisions()
}

OuvrirPrevisions(*) {
    global PopupGui, PopupHwnd, PopupGeo
    QuitterEdition()                               ; le mode « Redimensionner à la souris » s'arrête
    if (PopupHwnd && DllCall("IsWindow", "Ptr", PopupHwnd)) {
        FermerPrevisions("nouveau clic sur le widget")
        return
    }
    FermerJours("prévisions demandées")            ; une seule fenêtre surgissante à la fois
    FermerReglages("prévisions demandées")
    FermerMarches("prévisions demandées")
    FermerFicheActu("prévisions demandées")
    p := LirePrevisions()
    if (!p.jours.Length || !p.heures.Length) {
        TrayTip("Les prévisions détaillées arrivent à la prochaine mise à jour de la météo.", "Widget météo")
        return
    }
    kp := A_ScreenDPI / 96
    p.mp := MisePagePrevisions(p)                  ; une ou deux colonnes, selon la place à l'écran
    w := Round(p.mp.w * kp), h := Round(p.mp.h * kp)
    PopupGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x80000")
    PopupGui.Show("NA x0 y0 w1 h1")
    PopupHwnd := PopupGui.Hwnd

    PlacerSurgie(w, h, &x, &y)
    PopupGeo := {x: x, y: y, w: w, h: h, kp: kp, p: p}
    PeindrePrevisions()
    if !PopupHwnd                                  ; refermée entre-temps
        return
    SurgieOuverteLe(PopupHwnd, "prévisions ouvertes")
}

; ---------- Fenêtres surgissantes (prévisions, Mes jours, Réglages, Actus et marchés) ----------
; Une seule à la fois. Elle se ferme sur : un clic dans une fenêtre d'un autre
; programme (bureau, application, barre des tâches ; crochet ~*LButton posé le
; temps de l'ouverture, voir CrochetClics), Échap, ou une autre application
; passée au premier plan (Alt+Tab). Plus jamais sur une simple perte
; d'activation : ouverte depuis la zone de notification, Windows rend aussitôt
; le premier plan à la barre des tâches, et la fenêtre se refermait avant
; d'être vue (journal du 24/09 : onze ouvertures refermées en moins d'une seconde).

SurgieOuverte() => (PopupHwnd && DllCall("IsWindow", "Ptr", PopupHwnd)) || (JoursHwnd && DllCall("IsWindow", "Ptr", JoursHwnd))
    || (ReglHwnd && DllCall("IsWindow", "Ptr", ReglHwnd)) || (MarchesHwnd && DllCall("IsWindow", "Ptr", MarchesHwnd))
    || (FicheHwnd && DllCall("IsWindow", "Ptr", FicheHwnd))

; À appeler une fois la fenêtre « hwnd » affichée
SurgieOuverteLe(hwnd, libelle) {
    global SurgieT0, SurgiePremier
    ; au premier plan si Windows l'accorde (Échap au clavier) ; sinon, le
    ; crochet d'Échap et des clics fait le travail
    try WinActivate("ahk_id " hwnd)
    SurgieT0 := A_TickCount, SurgiePremier := DllCall("GetForegroundWindow", "Ptr")
    SetTimer(SurveillerSurgie, 300)
    CrochetClics()
    Journal(libelle ((SurgiePremier = hwnd) ? "" : " (sans le focus)"))   ; (jamais « journal » : ce serait la fonction Journal)
}

FermerSurgies(raison := "", *) {
    FermerPrevisions(raison)
    FermerJours(raison)
    FermerReglages(raison)
    FermerMarches(raison)
    FermerFicheActu(raison)
}

; Après la fermeture d'une fenêtre surgissante : crochets et surveillance retirés s'il n'en reste pas
SurgieFermee() {
    if SurgieOuverte()
        return
    SetTimer(SurveillerSurgie, 0)
    CrochetClics()
}

; Processus d'une fenêtre (0 si aucune) ; sans WinGetPID, qui ignore les fenêtres cachées
PidFenetre(hw) {
    pid := 0
    if hw
        DllCall("GetWindowThreadProcessId", "Ptr", hw, "UInt*", &pid)
    return pid
}

; Appui d'un bouton pendant qu'une fenêtre surgissante est ouverte : dans une
; fenêtre d'un autre programme, elle se ferme. Nos fenêtres (widget, zones,
; menus, la fenêtre elle-même) gèrent leurs clics elles-mêmes.
ClicPendantSurgie() {
    if SurgieDialogue                              ; une boîte de dialogue ouverte : on peut aller lire ailleurs
        return
    Curseur(&cx, &cy)
    hw := DllCall("WindowFromPoint", "Int64", (cy << 32) | (cx & 0xFFFFFFFF), "Ptr")
    r := hw ? DllCall("GetAncestor", "Ptr", hw, "UInt", 2, "Ptr") : 0
    if (r && PidFenetre(r) != DllCall("GetCurrentProcessId")) {
        global SurgieClicAilleurs := A_TickCount   ; (voir PrevisionsIcone)
        SetTimer(FermerSurgies.Bind("clic ailleurs"), -1)
    }
}

; Une autre application passe au premier plan (Alt+Tab, Win…) : fermeture.
; Les 800 premières ms, le premier plan se stabilise (zone de notification :
; Windows le rend à la barre des tâches) ; on garde alors celui qu'il devient.
SurveillerSurgie() {
    global SurgiePremier
    if !SurgieOuverte() {
        SetTimer(SurveillerSurgie, 0)
        return
    }
    fg := DllCall("GetForegroundWindow", "Ptr")
    if (A_TickCount - SurgieT0 < 800 || fg = SurgiePremier || SurgieDialogue)   ; (boîte de dialogue ouverte : pas de fermeture)
        SurgiePremier := fg
    else if (fg && PidFenetre(fg) != DllCall("GetCurrentProcessId"))
        FermerSurgies("autre fenêtre au premier plan")
    else
        SurgiePremier := fg                        ; une des nôtres (menu, widget) : rien à fermer
}

; À côté du widget (droite, gauche), sinon dessous ou dessus. Si rien ne tient
; (grand widget sur un écran très dense), la place de l'écran qui recouvre le
; moins le widget : avant, la fenêtre se centrait dessus et cachait la température.
PlacerSurgie(w, h, &x, &y) {
    WinGetPos(&wx, &wy, &ww, &wh, HWIDGET)
    e := EcranProche(wx + ww // 2, wy + wh // 2), g := Round(16 * A_ScreenDPI / 96)
    rec := -1
    for c in [[wx + ww + g, wy], [wx - w - g, wy], [wx + (ww - w) // 2, wy + wh + g], [wx + (ww - w) // 2, wy - h - g]] {
        cx := Max(e.l, Min(c[1], e.r - w)), cy := Max(e.t, Min(c[2], e.b - h))
        r := Max(0, Min(cx + w, wx + ww) - Max(cx, wx)) * Max(0, Min(cy + h, wy + wh) - Max(cy, wy))
        if (rec < 0 || r < rec)
            rec := r, x := cx, y := cy
        if !r                                      ; la première qui ne recouvre rien, dans l'ordre
            break
    }
}

; Dessine la fenêtre des prévisions (PopupGeo) ; « recalculer » : repeinte en
; place avec des données qui ont pu changer (un relevé terminé) : la
; mise en page et la taille sont refaites, pour que rien ne se chevauche
PeindrePrevisions(recalculer := false) {
    g := PopupGeo
    if (!IsObject(g) || !PopupHwnd)
        return
    if recalculer {
        g.p.mp := MisePagePrevisions(g.p)
        w := Round(g.p.mp.w * g.kp), h := Round(g.p.mp.h * g.kp)
        if (w != g.w || h != g.h) {
            PlacerSurgie(w, h, &x, &y)
            g.x := x, g.y := y, g.w := w, g.h := h
        }
    }
    PeindreCalque(PopupHwnd, g.x, g.y, g.w, g.h, (gr) => DessinerPrevisions(gr, g.w, g.h, g.kp, g.p))
}

; Peint une fenêtre superposée (x, y, w, h) : « dessin(gr) » sur une DIB 32 bits
; transparente, posée par UpdateLayeredWindow (alpha par pixel)
PeindreCalque(hwnd, x, y, w, h, dessin) {
    hdcE := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdc  := DllCall("CreateCompatibleDC", "Ptr", hdcE, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, "Int", w, "Int", -h, "UShort", 1, "UShort", 32, bi)
    hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits := 0, "Ptr", 0, "UInt", 0, "Ptr")
    obm := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
    try {
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &gr := 0)
        try {
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", gr, "UInt", 0)
            dessin(gr)
        } finally
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
        pt := Buffer(8), NumPut("Int", x, "Int", y, pt)
        sz := Buffer(8), NumPut("Int", w, "Int", h, sz)
        src := Buffer(8, 0)
        bf := Buffer(4), NumPut("UChar", 0, "UChar", 0, "UChar", 255, "UChar", 1, bf)
        DllCall("UpdateLayeredWindow", "Ptr", hwnd, "Ptr", hdcE, "Ptr", pt, "Ptr", sz, "Ptr", hdc, "Ptr", src, "UInt", 0, "Ptr", bf, "UInt", 2)
    } finally {
        DllCall("SelectObject", "Ptr", hdc, "Ptr", obm)
        DllCall("DeleteObject", "Ptr", hbm)
        DllCall("DeleteDC", "Ptr", hdc)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcE)
    }
}

FermerPrevisions(raison := "", *) {
    global PopupGui, PopupHwnd, PopupGeo
    if !PopupHwnd
        return
    PopupHwnd := 0, PopupGeo := ""
    try PopupGui.Destroy()
    PopupGui := ""
    SurgieFermee()
    Journal("prévisions fermées" (IsObject(raison) || raison = "" ? "" : " (" raison ")"))
}

; Messages de la fenêtre : un clic dedans ou Échap (quand elle a le focus) la ferment
PopupMessage(wParam, lParam, msg, hwnd) {
    if (!PopupHwnd || hwnd != PopupHwnd)
        return
    if (msg = 0x100 && wParam != 0x1B)            ; WM_KEYDOWN autre qu'Échap
        return
    SetTimer(FermerPrevisions.Bind((msg = 0x100) ? "Échap" : "clic"), -1)
    return 0
}

; Contenu de la fenêtre (couleurs de la surface sombre de référence dataviz)
; La fenêtre des prévisions prend la teinte du mode nuit, jamais son
; atténuation (on l'ouvre exprès)
DessinerPrevisions(gr, w, h, kp, p) {
    global TeinteRendu
    ancienne := TeinteRendu
    TeinteRendu := NuitTeinteActive()
    try DessinerPrevisionsScene(gr, w, h, kp, p)
    finally TeinteRendu := ancienne
}

DessinerPrevisionsScene(gr, w, h, kp, p) {
    static SURFACE := 0xF21A1A19, ENCRE := 0xFFFFFFFF, SECOND := 0xFFC3C2B7, DISCRET := 0xFF898781
    static GRILLE := 0xFF2C2C2A, AXE := 0xFF383835, ORANGE := 0xFFD95926, BLEU := 0xFF3987E5
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gr, "Int", 2)
    RectArrondi(gr, 0, 0, w, h, 22 * kp, SURFACE)
    MajLune()
    L := []
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    marge := 22, droite := 440 - 22
    PremierQuiTient(formes) {                    ; la forme la plus complète qui tient sur une ligne
        for f in formes
            if (LargeurTexte(f, P_TEXTE, em(10)) <= X(droite - marge))
                return f
        return Tronquer(formes[formes.Length], P_TEXTE, em(10), X(droite - marge))
    }

    ; ---- en-tête : conditions actuelles
    if Donnees.Has("code")
        Illustrer(L, Illustration(Donnees["code"], Donnees.Get("jour", "1")), X(18), X(12), X(88))
    if Donnees.Has("temp") {
        bt := Poser(L, Round(Number(Donnees["temp"])), P_GROS["android"], em(40, P_GROS["android"]), X(118), X(64), 0, ENCRE)
        PoserEncre(L, "°", P_GROS["android"], em(40, P_GROS["android"]), bt.x + bt.w + 4 * kp, X(64), ENCRE)
        Poser(L, InfosMeteo(Donnees["code"]), P_DATE, em(12.5, P_DATE), X(118), X(90), 0, ENCRE)
        ligne := "Ressenti " Round(Number(Donnees.Get("ressenti", Donnees["temp"]))) "°  ·  min " Round(Number(Donnees.Get("min", 0)))
            . "°  ·  max " Round(Number(Donnees.Get("max", 0))) "°"
        Poser(L, ligne, P_TEXTE, em(10.5), X(118), X(110), 0, SECOND)
    }
    Poser(L, Tronquer(Donnees.Get("ville", ""), P_TEXTE, em(11), X(150)), P_TEXTE, em(11), X(droite), X(34), 2, SECOND)
    if Donnees.Has("maj")
        Poser(L, "mis à jour à " HeureLocaleUnix(Donnees["maj"]), P_TEXTE, em(9.5), X(droite), X(52), 2, DISCRET)
    Filet(L, X(marge), X(128), X(droite), GRILLE)
    nHaut := L.Length                             ; la suite descend sous les infos (une colonne)

    ; ---- prochaines 24 heures : températures (courbe) puis pluie (barres), deux petits graphiques
    Poser(L, "Prochaines 24 heures", P_DATE, em(10.5, P_DATE), X(marge), X(152), 0, SECOND)
    hs := [], n := Min(25, p.heures.Length)
    Loop n
        hs.Push(p.heures[A_Index])
    xa := X(marge + 12), xb := X(droite - 12), pas := (xb - xa) / Max(1, n - 1)
    tmin := 1000, tmax := -1000
    for hr in hs
        if IsNumber(hr.temp)
            tmin := Min(tmin, Number(hr.temp)), tmax := Max(tmax, Number(hr.temp))
    ecartT := Max(tmax - tmin, 4)
    yBas := X(268), yHautC := X(214)
    YT(v) => yBas - (Number(v) - tmin) / ecartT * (yBas - yHautC)
    ; aire (voile à ~10 %) et courbe (2 px)
    pts := []
    for hr in hs
        if IsNumber(hr.temp)
            pts.Push([xa + (A_Index - 1) * pas, YT(hr.temp)])
    if (pts.Length >= 2) {
        L.Push({p: CheminAire(pts, yBas), f: 0x1AD95926, o: 0, z: false})
        L.Push({p: CheminCourbe(pts, 2 * kp), f: ORANGE, o: 0, z: false})
    }
    ; toutes les 3 h : icône, marqueur + valeur, heure (étiquettes sélectives)
    for hr in hs {
        i := A_Index - 1
        if (Mod(i, 3) != 0 || !IsNumber(hr.temp))
            continue
        cx := xa + i * pas, cy := YT(hr.temp)
        Illustrer(L, Illustration(hr.code, hr.jour), cx - X(12), X(164), X(24))
        Point(L, cx, cy, 4 * kp, ORANGE, 2 * kp, SURFACE)
        Poser(L, Round(Number(hr.temp)) "°", P_TEXTE, em(9.5), cx, cy - 9 * kp, 1, ENCRE)
        Poser(L, (i = 0) ? "Maint." : Integer(SubStr(hr.t, 12, 2)) " h", P_TEXTE, em(9), cx, X(288), 1, DISCRET)
    }
    ; pluie : barres (≤ 24 px, bout arrondi, 2 px d'écart), une étiquette sur la plus haute
    Poser(L, "Probabilité de pluie", P_TEXTE, em(9.5), X(marge), X(312), 0, SECOND)
    yB := X(368), hMax := X(30), lb := Min(X(24), pas - 2 * kp)
    Filet(L, xa - lb / 2, yB, xb + lb / 2, AXE)
    iMax := 0, pMax := 0
    for hr in hs {
        pr := IsNumber(hr.proba) ? Integer(hr.proba) : 0
        if (pr > pMax)
            pMax := pr, iMax := A_Index
        if (pr > 0)
            L.Push({p: CheminBarre(xa + (A_Index - 1) * pas - lb / 2, yB - Max(pr / 100 * hMax, 2 * kp), lb, Max(pr / 100 * hMax, 2 * kp), 4 * kp), f: BLEU, o: 0, z: false})
    }
    if (pMax >= 20)
        Poser(L, pMax " %", P_TEXTE, em(9), xa + (iMax - 1) * pas, yB - pMax / 100 * hMax - 6 * kp, 1, ENCRE)
    else
        Poser(L, "Pas de pluie prévue", P_TEXTE, em(9.5), (xa + xb) / 2, yB - 12 * kp, 1, DISCRET)
    Filet(L, X(marge), X(382), X(droite), GRILLE)

    ; ---- 7 jours : nom, icône, pluie, min, plage de températures, max
    Poser(L, "7 jours", P_DATE, em(10.5, P_DATE), X(marge), X(400), 0, SECOND)
    smin := 1000, smax := -1000
    for j in p.jours
        if (IsNumber(j.min) && IsNumber(j.max))
            smin := Min(smin, Number(j.min)), smax := Max(smax, Number(j.max))
    etendue := Max(smax - smin, 1)
    for j in p.jours {
        y := X(412 + (A_Index - 1) * 32)
        nom := (A_Index = 1) ? "Aujourd'hui" : (A_Index = 2) ? "Demain" : NomJour(j.date)
        ymd := IsTime(StrReplace(j.date, "-")) ? Integer(StrReplace(j.date, "-")) : 0
        ferie := ymd && IsObject(p.cal) && CalFeries && NomFerie(ymd) != ""
        ty := ymd ? TypeDuJour(ymd) : "", enCouleur := IsObject(ty) && JoursMarque = "jour"
        bn := Poser(L, nom, P_TEXTE, em(11), X(marge), y + X(21), 0, enCouleur ? ty.c : ferie ? ORANGE : ENCRE)
        if enCouleur                              ; Mes jours : le nom du jour à la couleur de son type…
            L[L.Length].brut := true
        else if IsObject(ty)                      ; … ou souligné de cette couleur
            L.Push({p: CheminArrondi(bn.x, y + X(25), bn.w, X(2.4), X(1.2)), f: ty.c, o: 0, z: false, brut: true})
        if (ymd && IsObject(p.cal) && CalVacances && CalendrierValide() && IsObject(EnVacances(ymd)))
            L.Push({p: CheminArrondi(X(10), y + X(7), X(3), X(18), X(1.5)), f: BLEU, o: 0, z: false})
        Illustrer(L, Illustration(j.code, "1"), X(128), y + X(4), X(24))
        if (IsNumber(j.proba) && Integer(j.proba) >= 20) {
            Goutte(L, X(162), y + X(8), X(8))
            Poser(L, j.proba " %", P_TEXTE, em(9), X(174), y + X(20), 0, SECOND)
        }
        if (IsNumber(j.min) && IsNumber(j.max)) {
            Poser(L, Round(Number(j.min)) "°", P_TEXTE, em(11), X(252), y + X(21), 2, SECOND)
            x1 := X(262), x2 := X(362), yPlage := y + X(13)
            L.Push({p: CheminBarre(x1, yPlage, x2 - x1, X(6), X(3)), f: AXE, o: 0, z: false})
            a := x1 + (Number(j.min) - smin) / etendue * (x2 - x1), b := x1 + (Number(j.max) - smin) / etendue * (x2 - x1)
            L.Push({p: CheminBarre(a, yPlage, Max(b - a, X(6)), X(6), X(3)), f: ORANGE, o: 0, z: false})
            Poser(L, Round(Number(j.max)) "°", P_TEXTE, em(11), X(372), y + X(21), 0, ENCRE)
        }
    }
    Filet(L, X(marge), X(644), X(droite), GRILLE)

    ; ---- vent, humidité, UV, soleil
    j := p.jours[1]
    l1 := "Vent " Donnees.Get("vent", "?") " km/h" ((Donnees.Get("vent_dir", "") != "") ? " " DirectionVent(Donnees["vent_dir"]) : "")
        . ", rafales " j.rafales " km/h  ·  Humidité " Donnees.Get("humidite", "?") " %"
    Poser(L, l1, P_TEXTE, em(10), X(marge), X(668), 0, SECOND)
    if DureeJour {                                ; soleil et durée du jour, puis UV heure par heure (une ligne de plus)
        base := "Lever " j.lever "  ·  Coucher " j.coucher, f2 := [base]
        if IsObject(dj := DureeJourInfos()) {
            d := DureeTexte(dj.jour) " de jour"
            f2 := (dj.ecart = "") ? [base "  ·  " d] : [base "  ·  " d ", " EcartTexte(dj.ecart) " demain", base "  ·  " d " (" EcartTexte(dj.ecart) ")", base "  ·  " d]
        }
        uv := "Indice UV " StrReplace(j.uv, ".", ","), f3 := [uv]
        if IsObject(p3 := PlageUV("uv3"))
            f3 := [uv " à " HeureCourte(p3.tmax) "  ·  3 ou plus de " HeureCourte(p3.debut) " à " HeureCourte(p3.fin),
                uv "  ·  3 ou plus de " HeureCourte(p3.debut) " à " HeureCourte(p3.fin), uv]
        Poser(L, PremierQuiTient(f2), P_TEXTE, em(10), X(marge), X(688), 0, SECOND)
        Poser(L, PremierQuiTient(f3), P_TEXTE, em(10), X(marge), X(708), 0, SECOND)
    } else {
        l2 := "Indice UV " StrReplace(j.uv, ".", ",") "  ·  Lever " j.lever "  ·  Coucher " j.coucher
        Poser(L, l2, P_TEXTE, em(10), X(marge), X(688), 0, SECOND)
    }
    nBase := L.Length

    ; ---- sections en option (voir MisePagePrevisions) : infos sous l'en-tête,
    ; lune et calendrier en bas, ou toutes dans une 2e colonne à droite
    mp := p.mp
    pal := {encre: ENCRE, second: SECOND, discret: DISCRET, grille: GRILLE, orange: ORANGE, bleu: BLEU, surface: SURFACE}
    if (!mp.deux && mp.infos)                     ; une colonne : le corps descend sous les infos
        Loop nBase - nHaut
            Deplacer(L[nHaut + A_Index].p, 0, X(mp.infos))
    for s in mp.secs {
        n0 := L.Length
        switch s.id {
            case "infos": SectionInfos(L, kp, s.y0, pal)
            case "lune":  SectionLune(L, kp, s.y0, pal, p)
            case "cal":   SectionCalendrier(L, kp, s.y0, pal, p, s.premier)
            case "air":   SectionAir(L, kp, s.y0, pal, s.premier)
            case "climat": SectionClimat(L, kp, s.y0, pal, s.premier)
            case "iss":   SectionIss(L, kp, s.y0, pal, s.premier)
            case "ciel":  SectionCiel(L, kp, s.y0, pal, s.premier)
        }
        if s.x0                                   ; 2e colonne : dessinée comme la 1re, puis décalée
            Loop L.Length - n0
                Deplacer(L[n0 + A_Index].p, X(s.x0), 0)
    }
    if mp.deux                                    ; trait entre les colonnes
        Loop mp.w // 440 - 1 {
            DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &sep := 0)
            DllCall("gdiplus\GdipAddPathRectangle", "Ptr", sep, "Float", X(440 * A_Index), "Float", X(22), "Float", Max(1, kp), "Float", X(mp.h - 44))
            L.Push({p: sep, f: GRILLE, o: 0, z: false})
        }

    for e in L
        Remplir(gr, e)
    for e in L
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
}

; Mise en page de la fenêtre des prévisions (px logiques) : {w, h, deux, infos, secs}.
; Sections en option : infos (2e ville…) sous l'en-tête, lune et calendrier en
; bas. Si la fenêtre dépasse la hauteur de l'écran, elles passent toutes dans
; une 2e colonne à droite (880 px de large) : rien n'est retiré.
MisePagePrevisions(p) {
    hi := HauteurInfos(), bas := [], total := 0
    if (LuneReelle || LuneLever)
        bas.Push({id: "lune", h: 44})
    if IsObject(p.cal)
        bas.Push({id: "cal", h: 42 + 22 * p.cal.Length})
    if (hk := HauteurCiel())                    ; planètes, étoiles filantes (options)
        bas.Push({id: "ciel", h: hk})
    if (hs := HauteurIss())                     ; station spatiale (option)
        bas.Push({id: "iss", h: hs})
    if (hc := HauteurClimat())                  ; normales et records (option)
        bas.Push({id: "climat", h: hc})
    if (ha := HauteurAir())                     ; qualité de l'air (options)
        bas.Push({id: "air", h: ha})
    for s in bas
        total += s.h
    secs := []
    corps := CorpsPrevisions()
    if (hi + total = 0 || corps + hi + total <= HauteurMaxPrevisions()) {   ; (rien d'optionnel : une colonne, même sur un petit écran)
        if hi
            secs.Push({id: "infos", x0: 0, y0: 128, premier: false})
        y := corps + hi
        for s in bas
            secs.Push({id: s.id, x0: 0, y0: y, premier: false}), y += s.h
        return {w: 440, h: y, deux: false, infos: hi, secs: secs}
    }
    ; 2e colonne ; si elle dépasse la hauteur de l'écran, une 3e (rien n'est retiré)
    y := 16, x0 := 440, hmax := HauteurMaxPrevisions(), h := corps
    if hi
        secs.Push({id: "infos", x0: 440, y0: y, premier: true}), y += hi
    for s in bas {
        if (x0 = 440 && y > 16 && y + s.h + 6 > hmax)
            h := Max(h, y + 6), x0 := 880, y := 16
        secs.Push({id: s.id, x0: x0, y0: y, premier: y = 16 || secs[secs.Length].id = "infos"}), y += s.h   ; (infos finit déjà par un filet)
    }
    return {w: x0 + 440, h: Max(h, y + 6), deux: true, infos: hi, secs: secs}
}

; Hauteur du corps de la fenêtre (px logiques) : une ligne de plus avec la durée du jour et les UV
CorpsPrevisions() => DureeJour ? 720 : 700

; Hauteur disponible (px logiques) sur l'écran du widget, marge comprise
HauteurMaxPrevisions() {
    if IsInteger(HPrevMax)                        ; aperçus : imposée
        return HPrevMax
    if (HWIDGET && DllCall("IsWindow", "Ptr", HWIDGET)) {
        WinGetPos(&wx, &wy, &ww, &wh, HWIDGET)
        e := EcranProche(wx + ww // 2, wy + wh // 2)
        t := e.t, b := e.b
    } else
        MonitorGetWorkArea(MonitorGetPrimary(), , &t, , &b)
    return (b - t) / (A_ScreenDPI / 96) - 16
}

; Lune (options lune) : sa phase, la prochaine phase principale, lever et coucher
SectionLune(L, kp, y0, pal, p) {
    X(v) => v * kp
    em := EmPourCapitale(P_TEXTE, 10 * kp)
    Illustrer(L, "lune", X(22 - 5.76), X(y0 - 1), X(36))
    for i, ligne in TexteLune(p.jours, MomentUnix())
        Poser(L, Tronquer(ligne, P_TEXTE, em, X(418 - 54)), P_TEXTE, em, X(54), X(y0 + 12 + 20 * (i - 1)), 0, pal.second)
}

; Calendrier (options) : semaine, prochain férié, vacances, comptes à rebours
SectionCalendrier(L, kp, y0, pal, p, premier) {
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    if !premier
        Filet(L, X(22), X(y0 + 8), X(418), pal.grille)
    Poser(L, "Calendrier", P_DATE, em(10.5, P_DATE), X(22), X(y0 + 30), 0, pal.second)
    if CalSemaine
        Poser(L, "Semaine " Integer(SubStr(FormatTime(MomentAffiche(), "YWeek"), 5)), P_TEXTE, em(10), X(418), X(y0 + 30), 2, pal.second)
    for i, e in p.cal {
        yl := X(y0 + 30 + 22 * i)
        couleur := e.HasOwnProp("c") ? e.c : (e.genre = "ferie") ? pal.orange : (e.genre = "vacances") ? pal.bleu
            : (e.genre = "saison") ? C_SOLEIL : (e.genre = "heure") ? pal.second : pal.encre
        Point(L, X(26), yl - X(4), 3.5 * kp, couleur, 0, pal.surface)
        dt := Poser(L, e.detail, P_TEXTE, em(10), X(418), yl, 2, pal.second)
        Poser(L, Tronquer(e.titre, P_TEXTE, em(10.5), dt.x - X(36) - X(12)), P_TEXTE, em(10.5), X(36), yl, 0, pal.encre)
    }
}

NomJour(date) => FormatTime(StrReplace(date, "-") "000000", "ddd d")

; Direction d'où vient le vent, en toutes lettres
DirectionVent(deg) {
    static noms := ["du nord", "du nord-est", "de l'est", "du sud-est", "du sud", "du sud-ouest", "de l'ouest", "du nord-ouest"]
    return IsNumber(deg) ? noms[Mod(Round(Number(deg) / 45), 8) + 1] : ""
}

Filet(L, x1, y, x2, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathRectangle", "Ptr", p, "Float", x1, "Float", y, "Float", x2 - x1, "Float", Max(1, A_ScreenDPI / 96))
    L.Push({p: p, f: couleur, o: 0, z: false})
}

Point(L, cx, cy, r, couleur, anneau, surface) {
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", p, "Float", cx - r - anneau, "Float", cy - r - anneau, "Float", 2 * (r + anneau), "Float", 2 * (r + anneau))
    L.Push({p: p, f: surface, o: 0, z: false})
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &q := 0)
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", q, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r)
    L.Push({p: q, f: couleur, o: 0, z: false})
}

; Barre au bout arrondi en haut (rayon r), carrée à la base
CheminBarre(x, y, w, h, r) {
    r := Min(r, w / 2, h)
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x, "Float", y, "Float", 2 * r, "Float", 2 * r, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x + w - 2 * r, "Float", y, "Float", 2 * r, "Float", 2 * r, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", x + w, "Float", y + h, "Float", x, "Float", y + h)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    return p
}

; Courbe lissée passant par les points (cardinal spline), épaissie en trait de « ep »
CheminCourbe(pts, ep) {
    buf := Buffer(8 * pts.Length)
    for q in pts
        NumPut("Float", q[1], "Float", q[2], buf, (A_Index - 1) * 8)
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathCurve2", "Ptr", p, "Ptr", buf, "Int", pts.Length, "Float", 0.4)
    Elargir(p, ep)
    return p
}

CheminAire(pts, yBas) {
    buf := Buffer(8 * pts.Length)
    for q in pts
        NumPut("Float", q[1], "Float", q[2], buf, (A_Index - 1) * 8)
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathCurve2", "Ptr", p, "Ptr", buf, "Int", pts.Length, "Float", 0.4)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", pts[pts.Length][1], "Float", yBas, "Float", pts[1][1], "Float", yBas)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    return p
}
