; =============================================================================
;  Widget météo — la fiche d'une actualité : un clic sur le titre à la une du
;  widget (ou sur un titre du tableau de bord) ouvre cet article seul, en grand,
;  centré sur l'écran : sa photo, son titre, son chapeau et, pour franceinfo, le
;  texte complet (Le Monde et France 24 protègent leurs pages des lectures
;  automatiques : leur chapeau, puis « Lire la suite » dans le navigateur).
;  ◀ ▶ (ou ← →) : les autres titres ; molette, ↑ ↓ : défiler ; Échap : fermer.
;  Les titres qui défilent sur le widget alternent franceinfo et Le Monde.
;
;  Texte et photo : widget-meteo-marches.ps1 -Article / -Image, à l'ouverture,
;  gardés 2 jours dans articles\ et images\. Inclus par widget-meteo.ahk (état :
;  Fiche*, UneAffichee, D_ARTICLES, D_IMAGES là-bas).
; =============================================================================

; Les titres qui défilent sur le widget : un de franceinfo, un du Monde, à tour de rôle (5 de chaque)
ListeUneWidget() {
    l := [], fi := ActusListe.Get("fil", []), lm := ActusListe.Get("une", [])
    Loop 5 {
        if (A_Index <= fi.Length)
            l.Push(fi[A_Index])
        if (A_Index <= lm.Length)
            l.Push(lm[A_Index])
    }
    return l
}

; Empreinte courte d'un texte (noms des fichiers du cache)
Empreinte(t) {
    h := 5381
    Loop Parse t
        h := Mod(h * 33 + Ord(A_LoopField), 4294967296)
    return Format("{:08x}", h) StrLen(t)
}

TexteComplet(a) => InStr(a.lien, "://www.franceinfo.fr/")   ; (les seuls dont la page donne le texte)

; Le texte de l'article : {etat: ok, attente, sans (pas de texte complet), paras[]}
ArticleTexte(a) {
    if !TexteComplet(a)
        return {etat: "sans", paras: []}
    f := D_ARTICLES "\" Empreinte(a.lien) ".txt"
    if FicheArt.Has(f)
        return FicheArt[f]
    if !FileExist(f)
        return {etat: "attente", paras: []}
    paras := [], etat := "sans"
    try
        for i, l in StrSplit(FileRead(f, "UTF-8"), "`n", "`r") {
            if (i = 2 && SubStr(l, 1, 5) = "etat=")
                etat := (SubStr(l, 6) = "ok") ? "ok" : "sans"
            else if (i > 2 && l != "")
                paras.Push(l)
        }
    r := {etat: paras.Length ? etat : "sans", paras: paras}
    FicheArt[f] := r
    return r
}

PhotoFichier(a) => (a.image != "") ? D_IMAGES "\" Empreinte(a.image) ".img" : ""

; Texte complet et photo pas encore là : demandés à la collecte (en arrière-plan)
ChargerArticle(a) {
    global FicheArtPID, FicheImgPID
    static tentes := Map()                        ; (une photo introuvable n'est pas redemandée en boucle)
    DirCreate(D_ARTICLES), DirCreate(D_IMAGES)
    Lancer(arg) {
        try Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' SCRIPT_MARCHES '"' arg, , "Hide", &pid)
        catch
            pid := 0
        return pid
    }
    f := D_ARTICLES "\" Empreinte(a.lien) ".txt"
    if (TexteComplet(a) && !FileExist(f) && !tentes.Has(f) && !(FicheArtPID && ProcessExist(FicheArtPID)))
        FicheArtPID := Lancer(" -Article " ArgPS(a.lien) " -Fichier " ArgPS(f)), tentes[f] := 1
    p := PhotoFichier(a)
    if (p != "" && !FileExist(p) && !tentes.Has(p) && !(FicheImgPID && ProcessExist(FicheImgPID)))
        FicheImgPID := Lancer(" -Image " ArgPS(a.image) " -Fichier " ArgPS(p)), tentes[p] := 1
    SetTimer(SuivreFiche, 400)
}

SuivreFiche() {
    if ((FicheArtPID && ProcessExist(FicheArtPID)) || (FicheImgPID && ProcessExist(FicheImgPID)))
        return
    SetTimer(SuivreFiche, 0)
    if !FicheHwnd
        return
    ChargerArticle(FicheGeo.a)                    ; (un autre article a pu être choisi entre-temps : rien s'il est complet)
    PeindreFicheActu()
}

; ---------- La fenêtre ----------

; a : l'article {flux, t, titre, lien, resume, image} ; liste : ceux de ◀ ▶ ; retour : « marches » (ouverte du tableau de bord)
OuvrirFicheActu(a, liste := "", retour := "", *) {
    global FicheGui, FicheHwnd, FicheGeo
    if !IsObject(a)
        return
    QuitterEdition()
    FermerPrevisions("article demandé"), FermerJours("article demandé"), FermerReglages("article demandé"), FermerMarches("article demandé")
    liste := IsObject(liste) && liste.Length ? liste : [a]
    idx := 1
    for i, x in liste
        if (x.lien == a.lien)
            idx := i
    if (FicheHwnd && IsObject(FicheGeo)) {        ; déjà ouverte : un autre article, même fenêtre
        FicheGeo.liste := liste, FicheGeo.idx := idx, FicheGeo.retour := retour
        FicheChanger(0)
        return
    }
    kp := A_ScreenDPI / 96
    WinGetPos(&wx, &wy, &ww, &wh, HWIDGET)
    e := EcranProche(wx + ww // 2, wy + wh // 2)
    FicheGeo := {kp: kp, a: a, liste: liste, idx: idx, retour: retour, defil: 0, survol: "", suivi: false,
        x: 0, y: 0, w: 0, h: 0, mp: "", ecran: e, img: "", imgChemin: "",
        hauteur: Max(420, Min(FICHE_H, Floor((e.b - e.t) / kp) - 60))}
    FicheGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x80000")
    FicheGui.Show("NA x0 y0 w1 h1")
    FicheHwnd := FicheGui.Hwnd
    ChargerArticle(a)
    PeindreFicheActu(true, true)
    SurgieOuverteLe(FicheHwnd, "article ouvert (" ACTUS_FLUX.Get(a.flux, a.flux) ")")
}

; Article précédent (-1), suivant (1) de la liste, ou le même rechargé (0)
FicheChanger(sens) {
    g := FicheGeo
    if !IsObject(g)
        return
    g.idx := Mod(g.idx - 1 + sens + g.liste.Length, g.liste.Length) + 1
    g.a := g.liste[g.idx], g.defil := 0, g.survol := ""
    LibererPhoto()
    ChargerArticle(g.a)
    PeindreFicheActu()
}

LibererPhoto() {
    if (IsObject(FicheGeo) && FicheGeo.img)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", FicheGeo.img)
    if IsObject(FicheGeo)
        FicheGeo.img := "", FicheGeo.imgChemin := ""
}

FermerFicheActu(raison := "", *) {
    global FicheGui, FicheHwnd, FicheGeo
    if !FicheHwnd
        return
    LibererPhoto()
    FicheHwnd := 0, FicheGeo := ""
    try FicheGui.Destroy()
    FicheGui := ""
    SurgieFermee()
    Journal("article fermé" (IsObject(raison) || raison = "" ? "" : " (" raison ")"))
}

PeindreFicheActu(refaire := true, placer := false) {
    g := FicheGeo
    if (!IsObject(g) || !FicheHwnd)
        return
    if (refaire || !IsObject(g.mp))
        g.mp := MiseEnPageFiche(g.a, g.kp, g.hauteur, g.retour != "", g.liste.Length > 1)
    g.defil := Max(0, Min(g.defil, g.mp.defilMax))
    w := Round(g.mp.w * g.kp), h := Round(g.mp.h * g.kp)
    if (placer || w != g.w || h != g.h) {         ; au milieu de l'écran du widget
        e := g.ecran
        g.x := (e.l + e.r - w) // 2, g.y := (e.t + e.b - h) // 2, g.w := w, g.h := h
    } else {
        rc := Buffer(16, 0)                       ; (elle a pu être déplacée à la souris)
        if DllCall("GetWindowRect", "Ptr", FicheHwnd, "Ptr", rc)
            g.x := NumGet(rc, 0, "Int"), g.y := NumGet(rc, 4, "Int")
    }
    PeindreCalque(FicheHwnd, g.x, g.y, g.w, g.h, (gr) => DessinerFicheActu(gr, g.w, g.h, g.kp, g.mp, g))
}

; Un paragraphe court sans ponctuation finale : un intertitre (en gras)
EstIntertitre(p) => StrLen(p) <= 90 && !RegExMatch(p, "[.!?…:,\]]\s*$") && !RegExMatch(p, "^[\x{22}«\[]")

; {w, h, y0, lignes[], zones[], photo, contenuH, defilMax} en px logiques ; le
; contenu (y relatifs) défile sous l'en-tête (boutons ◀ ▶, retour, fermer)
MiseEnPageFiche(a, kp, hauteur, avecRetour, avecNav) {
    mp := {w: FICHE_W, h: hauteur, y0: 64, lignes: [], zones: [], photo: ""}
    cx := 36, cw := FICHE_W - 72
    mp.zones.Push({x: mp.w - 54, y: 14, w: 36, h: 36, type: "fermer", id: "fermer", fixe: true})
    if avecNav {
        mp.zones.Push({x: mp.w - 54 - 96, y: 14, w: 40, h: 36, type: "prec", id: "prec", fixe: true})
        mp.zones.Push({x: mp.w - 54 - 52, y: 14, w: 40, h: 36, type: "suiv", id: "suiv", fixe: true})
    }
    if avecRetour
        mp.zones.Push({x: 20, y: 14, w: 190, h: 36, type: "retour", id: "retour", fixe: true})
    Ligne(t, police, cap, couleur, h) {
        mp.lignes.Push({t: t, police: police, cap: cap, couleur: couleur, y: y})
        y += h
    }
    y := 4
    if (a.image != "") {
        mp.photo := {x: cx, y: y, w: cw, h: Round(cw * 0.42)}   ; (le titre reste visible sans défiler)
        y += mp.photo.h + 22
    }
    Ligne(ACTUS_FLUX.Get(a.flux, a.flux) ((a.t) ? " · " AgeActu(a.t) : ""), P_TEXTE, 9, "discret", 30)
    for t in ReglCouper(a.titre, P_DATE, 17, kp, cw, 6)
        Ligne(t, P_DATE, 17, "encre", 31)
    y += 10
    art := ArticleTexte(a)
    corps := ""
    for p in art.paras
        corps .= p " "
    if (a.resume != "" && !(art.etat = "ok" && InStr(corps, SubStr(a.resume, 1, 60)))) {   ; (chapeau : sauf s'il est déjà dans le texte)
        for t in ReglCouper(a.resume, P_TEXTE, 11.5, kp, cw, 20)
            Ligne(t, P_TEXTE, 11.5, "second", 23)
        y += 16
    }
    if (art.etat = "ok") {
        for p in art.paras {
            if RegExMatch(p, "^\[(.+)\]$", &m) {      ; (graphique intégré à la page : une mention discrète)
                for t in ReglCouper(m[1], P_TEXTE, 10, kp, cw, 3)
                    Ligne(t, P_TEXTE, 10, "discret", 20)
                y += 12
                continue
            }
            titre := EstIntertitre(p)
            if titre
                y += 6
            for t in ReglCouper(p, titre ? P_DATE : P_TEXTE, titre ? 12 : 11, kp, cw, 200)
                Ligne(t, titre ? P_DATE : P_TEXTE, titre ? 12 : 11, "encre", titre ? 24 : 22)
            y += 12
        }
    } else if (art.etat = "attente")
        Ligne("Chargement de l'article…", P_TEXTE, 10.5, "discret", 30)
    else
        Ligne(TexteComplet(a) ? "Le texte complet n'a pas pu être lu." : "La suite de l'article est sur le site de " ACTUS_FLUX.Get(a.flux, a.flux) ".",
            P_TEXTE, 10.5, "discret", 30)
    y += 10
    site := RegExReplace(a.lien, "^https?://(www\.)?([^/]+).*$", "$2")
    mp.lien := {lib: ((art.etat = "ok") ? "Ouvrir sur " : "Lire la suite sur ") site, x: cx, y: y}
    mp.lien.w := LargeurMemo(mp.lien.lib " ›", P_DATE, EmPourCapitale(P_DATE, 10.5 * kp)) / kp + 40
    mp.zones.Push({x: cx, y: y, w: mp.lien.w, h: 42, type: "lien", id: "lien", fixe: false})
    y += 42 + 24
    mp.contenuH := y
    mp.defilMax := Max(0, mp.contenuH - (hauteur - mp.y0 - 8))
    return mp
}

DessinerFicheActu(gr, w, h, kp, mp, g) {
    global TeinteRendu
    ancienne := TeinteRendu
    TeinteRendu := NuitTeinteActive()
    try DessinerFicheScene(gr, w, h, kp, mp, g)
    finally TeinteRendu := ancienne
}

DessinerFicheScene(gr, w, h, kp, mp, g) {
    static SURFACE := 0xF51A1A19, ENCRE := 0xFFFFFFFF, SECOND := 0xFFC3C2B7, DISCRET := 0xFF898781
    static GRILLE := 0xFF2C2C2A, CHOISI := 0xFF3A3A37, BLEU := 0xFF3987E5, BLEU_SURVOL := 0xFF4C97F0, PUCE := 0xFF34342F
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gr, "Int", 2)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", gr, "Int", 7)   ; (photo : bicubique haute qualité)
    RectArrondi(gr, 0, 0, w, h, 22 * kp, SURFACE)
    F := [], C := []
    teintes := Map("encre", ENCRE, "second", SECOND, "discret", DISCRET)
    oy := mp.y0 - g.defil
    ; ---- photo (dessinée tout de suite, sous le texte, découpée aux coins arrondis)
    DllCall("gdiplus\GdipSetClipRect", "Ptr", gr, "Float", 0, "Float", (mp.y0 - 4) * kp, "Float", w, "Float", h - (mp.y0 + 4) * kp, "Int", 0)
    if IsObject(mp.photo) {
        ph := mp.photo, px := ph.x * kp, py := (oy + ph.y) * kp, pw := ph.w * kp, pht := ph.h * kp
        chemin := PhotoFichier(g.a)
        if (chemin != "" && FileExist(chemin) && g.imgChemin != chemin) {
            LibererPhoto()
            if !DllCall("gdiplus\GdipLoadImageFromFile", "WStr", chemin, "Ptr*", &img := 0) && img
                g.img := img, g.imgChemin := chemin
        }
        cadre := CheminArrondi(px, py, pw, pht, 14 * kp)
        if g.img {
            DllCall("gdiplus\GdipGetImageWidth", "Ptr", g.img, "UInt*", &iw := 0)
            DllCall("gdiplus\GdipGetImageHeight", "Ptr", g.img, "UInt*", &ih := 0)
            if (iw && ih) {                       ; « couvrir » : rognée au rapport du cadre
                r := pw / pht
                sw := (iw / ih > r) ? ih * r : iw, sh := (iw / ih > r) ? ih : iw / r
                DllCall("gdiplus\GdipSetClipPath", "Ptr", gr, "Ptr", cadre, "Int", 1)   ; (intersection)
                DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", gr, "Ptr", g.img, "Float", px, "Float", py, "Float", pw, "Float", pht,
                    "Float", (iw - sw) / 2, "Float", (ih - sh) / 2, "Float", sw, "Float", sh, "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0)
                DllCall("gdiplus\GdipSetClipRect", "Ptr", gr, "Float", 0, "Float", (mp.y0 - 4) * kp, "Float", w, "Float", h - (mp.y0 + 4) * kp, "Int", 0)
            }
        } else {                                  ; (pas encore arrivée : un cadre discret)
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", GRILLE, "Ptr*", &br := 0)
            DllCall("gdiplus\GdipFillPath", "Ptr", gr, "Ptr", br, "Ptr", cadre)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
        }
        DllCall("gdiplus\GdipDeletePath", "Ptr", cadre)
    }
    ; ---- texte
    for l in mp.lignes {
        yb := oy + l.y + l.cap + 6
        if (yb < mp.y0 - 10 || yb - l.cap > mp.h)
            continue
        Poser(C, l.t, l.police, EmPourCapitale(l.police, l.cap * kp), 36 * kp, yb * kp, 0, teintes[l.couleur])
    }
    li := mp.lien, dessus := (g.survol = "lien")
    C.Push({p: CheminArrondi(li.x * kp, (oy + li.y) * kp, li.w * kp, 42 * kp, 21 * kp), f: dessus ? BLEU_SURVOL : BLEU})
    Poser(C, li.lib " ›", P_DATE, EmPourCapitale(P_DATE, 10.5 * kp), (li.x + li.w / 2) * kp, (oy + li.y + 26.25) * kp, 1, ENCRE)
    for e in C
        Remplir(gr, e)
    DllCall("gdiplus\GdipResetClip", "Ptr", gr)
    ; ---- en-tête : retour, ◀ ▶, fermer ; barre de défilement
    for z in mp.zones {
        if !z.fixe
            continue
        cxz := (z.x + z.w / 2) * kp, cyz := (z.y + z.h / 2) * kp, dessus := (g.survol = z.id)
        switch z.type {
            case "fermer":
                ReglRond(F, cxz, cyz, 14 * kp, dessus ? CHOISI : GRILLE)
                ReglTraits(F, [[cxz - 4.5 * kp, cyz - 4.5 * kp, cxz + 4.5 * kp, cyz + 4.5 * kp], [cxz - 4.5 * kp, cyz + 4.5 * kp, cxz + 4.5 * kp, cyz - 4.5 * kp]], 1.8 * kp, SECOND)
            case "prec", "suiv":
                F.Push({p: CheminArrondi(z.x * kp, z.y * kp, z.w * kp, z.h * kp, 18 * kp), f: dessus ? CHOISI : GRILLE})
                s := (z.type = "prec") ? -1 : 1
                ReglTraits(F, [[cxz - s * 2.5 * kp, cyz - 5 * kp, cxz + s * 2.5 * kp, cyz], [cxz + s * 2.5 * kp, cyz, cxz - s * 2.5 * kp, cyz + 5 * kp]], 1.8 * kp, SECOND)
            case "retour":
                F.Push({p: CheminArrondi(z.x * kp, z.y * kp, z.w * kp, z.h * kp, 18 * kp), f: dessus ? CHOISI : GRILLE})
                Poser(F, "‹ Actus et marchés", P_TEXTE, EmPourCapitale(P_TEXTE, 9.5 * kp), cxz, cyz + 4.75 * kp, 1, SECOND)
        }
    }
    if (g.liste.Length > 1)
        Poser(F, g.idx " / " g.liste.Length, P_TEXTE, EmPourCapitale(P_TEXTE, 9 * kp), (mp.w - 54 - 96 - 12) * kp, 37 * kp, 2, DISCRET)
    if (mp.defilMax > 0) {
        vh := mp.h - mp.y0 - 10, th := Max(36, vh * vh / (mp.contenuH + 1))
        ty := mp.y0 + (vh - th) * g.defil / mp.defilMax
        F.Push({p: CheminArrondi((mp.w - 11) * kp, ty * kp, 4 * kp, th * kp, 2 * kp), f: 0x55FFFFFF})
    }
    for e in F
        Remplir(gr, e)
    for e in F
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
    for e in C
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
}

; ---------- Souris et clavier ----------

FicheMessages() {
    OnMessage(0x201, FicheAppui)
    OnMessage(0x203, FicheAppui)
    OnMessage(0x200, FicheDeplace)
    OnMessage(0x2A3, FicheSortie)
    OnMessage(0x20, FicheCurseur)
    OnMessage(0x20A, FicheMolette)
    OnMessage(0x100, FicheTouche)
}

FicheSous() {
    g := FicheGeo
    if !(IsObject(g) && IsObject(g.mp))
        return ""
    rc := Buffer(16, 0)
    if DllCall("GetWindowRect", "Ptr", FicheHwnd, "Ptr", rc)
        g.x := NumGet(rc, 0, "Int"), g.y := NumGet(rc, 4, "Int")
    if IsObject(ReglCurseurTest)
        cx := ReglCurseurTest[1], cy := ReglCurseurTest[2]
    else
        Curseur(&cx, &cy)
    lx := (cx - g.x) / g.kp, ly := (cy - g.y) / g.kp, mp := g.mp
    for z in mp.zones {
        zy := z.y
        if !z.fixe {
            if (ly < mp.y0 - 4 || ly >= mp.h - 8)
                continue
            zy += mp.y0 - g.defil
        }
        if (lx >= z.x && lx < z.x + z.w && ly >= zy && ly < zy + z.h)
            return z
    }
    return ""
}

FicheAppui(wParam, lParam, msg, hwnd) {
    if (!FicheHwnd || hwnd != FicheHwnd)
        return
    z := FicheSous()
    if !IsObject(z) {                             ; ailleurs : la fenêtre suit la souris
        DllCall("PostMessage", "Ptr", FicheHwnd, "UInt", 0xA1, "Ptr", 2, "Ptr", 0)
        return 0
    }
    switch z.type {
        case "fermer": SetTimer(FermerFicheActu.Bind("croix"), -1)
        case "prec":   FicheChanger(-1)
        case "suiv":   FicheChanger(1)
        case "retour": SetTimer(OuvrirMarches, -1)
        case "lien":   lien := FicheGeo.a.lien, SetTimer(() => Run(lien), -1)   ; (le navigateur passe devant : la fiche se ferme)
    }
    return 0
}

FicheDeplace(wParam, lParam, msg, hwnd) {
    if (!FicheHwnd || hwnd != FicheHwnd)
        return
    g := FicheGeo
    if !g.suivi {
        tme := Buffer(24, 0)
        NumPut("UInt", 24, "UInt", 2, tme)
        NumPut("Ptr", FicheHwnd, tme, 8)
        g.suivi := DllCall("TrackMouseEvent", "Ptr", tme)
    }
    z := FicheSous(), id := IsObject(z) ? z.id : ""
    if (id != g.survol) {
        g.survol := id
        PeindreFicheActu(false)
    }
    return 0
}

FicheSortie(wParam, lParam, msg, hwnd) {
    if (!FicheHwnd || hwnd != FicheHwnd)
        return
    FicheGeo.suivi := false
    if (FicheGeo.survol != "") {
        FicheGeo.survol := ""
        PeindreFicheActu(false)
    }
    return 0
}

FicheCurseur(wParam, lParam, msg, hwnd) {
    if (!FicheHwnd || hwnd != FicheHwnd || (lParam & 0xFFFF) != 1 || !IsObject(FicheSous()))
        return
    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))
    return 1
}

FicheMolette(wParam, lParam, msg, hwnd) {
    if (!FicheHwnd || hwnd != FicheHwnd)
        return
    d := (wParam >> 16) & 0xFFFF
    FicheDefiler(-((d >= 0x8000) ? d - 0x10000 : d) / 2)
    return 0
}

FicheDefiler(dy) {
    g := FicheGeo
    if !(IsObject(g) && IsObject(g.mp))
        return
    avant := g.defil
    g.defil := Max(0, Min(g.mp.defilMax, g.defil + dy))
    if (g.defil != avant)
        SetTimer(FicheApresDefil, -10)
}

FicheApresDefil() {
    if !(IsObject(FicheGeo) && FicheHwnd)
        return
    z := FicheSous(), FicheGeo.survol := IsObject(z) ? z.id : ""
    PeindreFicheActu(false)
}

FicheTouche(wParam, lParam, msg, hwnd) {
    if (!FicheHwnd || hwnd != FicheHwnd)
        return
    page := FicheGeo.mp.h - FicheGeo.mp.y0 - 60
    switch wParam {
        case 0x1B: SetTimer(FermerFicheActu.Bind("Échap"), -1)
        case 0x25: FicheChanger(-1)               ; ← : l'article d'avant
        case 0x27: FicheChanger(1)                ; → : le suivant
        case 0x26: FicheDefiler(-60)
        case 0x28: FicheDefiler(60)
        case 0x21: FicheDefiler(-page)
        case 0x22, 0x20: FicheDefiler(page)       ; (page suivante, espace)
        case 0x24: FicheDefiler(-100000)
        case 0x23: FicheDefiler(100000)
        default: return
    }
    return 0
}

; ---------- Tests ----------

; La fiche d'un article (données du dossier de test) : flux « flux », rang « n » ;
; texte et photo récupérés d'abord (en attendant la collecte) ; defil = « plein » : tout
ApercuFiche(fichier, flux := "fil", n := 1, defil := 0) {
    LireActus()
    a := ActusListe.Has(flux) && ActusListe[flux].Length >= n ? ActusListe[flux][n] : ""
    if !IsObject(a)
        throw Error("pas d'article " flux " " n " dans actus.txt")
    DirCreate(D_ARTICLES), DirCreate(D_IMAGES)
    if (TexteComplet(a) && !FileExist(D_ARTICLES "\" Empreinte(a.lien) ".txt"))
        RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' SCRIPT_MARCHES '" -Article ' ArgPS(a.lien) ' -Fichier ' ArgPS(D_ARTICLES "\" Empreinte(a.lien) ".txt"), , "Hide")
    if (PhotoFichier(a) != "" && !FileExist(PhotoFichier(a)))
        RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' SCRIPT_MARCHES '" -Image ' ArgPS(a.image) ' -Fichier ' ArgPS(PhotoFichier(a)), , "Hide")
    kp := A_ScreenDPI / 96
    mp := MiseEnPageFiche(a, kp, FICHE_H, true, true)
    if (defil = "plein")
        mp := MiseEnPageFiche(a, kp, Max(FICHE_H, mp.y0 + 8 + mp.contenuH), true, true), defil := 0
    g := {a: a, liste: [a, a], idx: 1, defil: Max(0, Min(Integer(defil), mp.defilMax)), survol: "", img: "", imgChemin: ""}
    w := Round(mp.w * kp), h := Round(mp.h * kp), m := Round(16 * kp)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w + 2 * m, "Int", h + 2 * m, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, w + 2 * m, h + 2 * m, 0xFF5A6570)
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", gr, "Float", m, "Float", m, "Int", 0)
    DessinerFicheActu(gr, w, h, kp, mp, g)
    if g.img
        DllCall("gdiplus\GdipDisposeImage", "Ptr", g.img)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

; Auto-test : alternance des titres du widget, empreintes, intertitres, mise en page
TestFiche(fichier) {
    global UneRang
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    LireActus()
    l := ListeUneWidget()
    Verifier(l.Length = 10 && l[1].flux = "fil" && l[2].flux = "une" && l[3].flux = "fil", "titres du widget : franceinfo, Le Monde, en alternance (" l.Length ")")
    UneRang := 1, a1 := UneCourante(), UneRang := 11
    Verifier(IsObject(a1) && UneCourante().lien == a1.lien, "rotation sur les 10 titres")
    Verifier(Empreinte("https://a.b/c") = Empreinte("https://a.b/c") && Empreinte("https://a.b/c") != Empreinte("https://a.b/d"), "empreintes stables et distinctes")
    Verifier(EstIntertitre("Des politiques d'aide coûteuses") && !EstIntertitre("En Italie, les taxes sont réduites depuis mars.")
        && !EstIntertitre(Chr(34) "J'ai été violent" Chr(34)) && !EstIntertitre("[Carte interactive à voir sur le site]"), "intertitres repérés")
    Verifier(TexteComplet({lien: "https://www.franceinfo.fr/x.html"}) && !TexteComplet({lien: "https://www.lemonde.fr/x.html"}), "texte complet : franceinfo seulement")
    for kp in [1, 2.5] {
        a := ActusListe["une"][1]
        mp := MiseEnPageFiche(a, kp, FICHE_H, true, true)
        dedans := true
        for z in mp.zones
            dedans := dedans && z.x >= 0 && z.x + z.w <= mp.w
        Verifier(dedans && mp.lignes.Length >= 3 && InStr(mp.lien.lib, "Lire la suite sur lemonde.fr"), "fiche du Monde à " kp " : chapeau et « Lire la suite »")
    }
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}
