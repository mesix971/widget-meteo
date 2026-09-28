; =============================================================================
;  Widget météo — animations légères de l'illustration (option « Animations
;  légères », désactivée par défaut) — inclus par widget-meteo.ahk
;
;  L'illustration principale est dessinée une fois pour toutes en ANIM_IMAGES
;  images (une boucle de ANIM_BOUCLE ms ; moitié moins d'images pour une grande
;  illustration, la mémoire restant raisonnable), dans une petite fenêtre
;  superposée posée sur le widget et possédée par lui (elle reste donc juste
;  au-dessus). Ensuite, passer à l'image suivante ne coûte qu'un
;  UpdateLayeredWindow, 6 à 12 fois par seconde. Pendant un redimensionnement,
;  la fenêtre est masquée (le brouillon dessine l'illustration fixe).
;  L'animation se met en pause quand l'illustration est cachée par une fenêtre
;  ou quand l'économiseur de batterie de Windows est actif.
;  (Constantes et état : ANIM_*, Anim*, IconeZone, déclarés dans widget-meteo.ahk.)
; =============================================================================

; Après chaque redessin du widget, posé en (x, y) : prépare, place ou retire l'animation
AnimMaj(x, y) {
    global AnimDx, AnimDy
    if EnGeste()
        return
    if (!Animations || !IsObject(IconeZone)) {
        AnimArreter(true)
        return
    }
    if NuitActive() {                             ; la nuit : icône fixe dans le widget (teintée, atténuée), images gardées
        AnimSuspendre()
        return
    }
    z := IconeZone, k := Echelle()
    m := Ceil(12 * k)                             ; marge : ombre, gouttes et flocons qui débordent un peu
    s := Round(z.s)
    cle := z.id "|" s ((LuneReelle && EstLune(z.id)) ? "|" LunePsi (LuneSud ? "s" : "") : "")   ; une boucle par degré de phase
    if (cle != AnimCle || !AnimImages.Length)
        AnimPreparer(z.id, s, m, k, cle)
    AnimDx := Round(z.x) - m, AnimDy := Round(z.y) - m
    AnimCreerFenetre()
    AnimAfficher(x + AnimDx, y + AnimDy)
    if !DllCall("IsWindowVisible", "Ptr", AnimHwnd)   ; masquée pendant un redimensionnement
        DllCall("ShowWindow", "Ptr", AnimHwnd, "Int", 8)   ; SW_SHOWNA
    AnimVerifier()
}

; Dessine toutes les images de la boucle (quelques dixièmes de seconde, une
; seule fois par illustration et par taille)
AnimPreparer(id, s, m, k, cle) {
    global AnimCle, AnimW, AnimH, AnimN, AnimImages
    AnimLiberer()
    t0 := A_TickCount
    AnimW := s + 2 * m, AnimH := s + 2 * m
    n := (AnimW > 400) ? ANIM_IMAGES // 2 : ANIM_IMAGES   ; au-delà de 400 px, moitié moins d'images (Android à 200 % : ≈ 28 Mo au lieu de 57)
    hdcE := DllCall("GetDC", "Ptr", 0, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, "Int", AnimW, "Int", -AnimH, "UShort", 1, "UShort", 32, bi)
    Loop n {
        dc := DllCall("CreateCompatibleDC", "Ptr", hdcE, "Ptr")
        bm := DllCall("CreateDIBSection", "Ptr", dc, "Ptr", bi, "UInt", 0, "Ptr*", &bits := 0, "Ptr", 0, "UInt", 0, "Ptr")
        ob := DllCall("SelectObject", "Ptr", dc, "Ptr", bm, "Ptr")
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", dc, "Ptr*", &gr := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gr, "Int", 2)
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", gr, "UInt", 0)
        L := []
        Illustrer(L, id, m, m, s, (A_Index - 1) / n)
        for e in L
            e.o := 0x000000                       ; ombre sombre, comme IllustrerTheme
        OmbreDouce(gr, L, AnimW, AnimH, k)
        for e in L
            Remplir(gr, e)
        for e in L
            DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
        AnimImages.Push({dc: dc, bm: bm, ob: ob})
    }
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcE)
    AnimCle := cle, AnimN := 0
    if AnimMarche                                 ; le nombre d'images a pu changer : même durée de boucle
        SetTimer(AnimImageSuivante, Round(ANIM_BOUCLE / n))
    Journal("animation « " id " » préparée : " n " images de " AnimW " px en " (A_TickCount - t0) " ms")
}

AnimCreerFenetre() {
    global AnimGui, AnimHwnd
    if (AnimHwnd && DllCall("IsWindow", "Ptr", AnimHwnd))
        return
    ; superposée, jamais activée, transparente aux clics (ils vont au widget
    ; dessous), possédée par le widget pour rester juste au-dessus de lui
    AnimGui := Gui("-Caption +ToolWindow +E0x80000 +E0x08000000 +E0x20 +Owner" HWIDGET)
    AnimGui.Show("NA x0 y0 w1 h1")
    AnimHwnd := AnimGui.Hwnd
    WidgetEnBas()                                 ; (montrer une fenêtre possédée remonte le widget devant tes fenêtres)
}

; Affiche l'image courante (et déplace la fenêtre si une position est donnée)
AnimAfficher(x := "", y := "") {
    static sz := Buffer(8), src := Buffer(8, 0), bf := Buffer(4), pt := Buffer(8)
    if (!AnimHwnd || !AnimImages.Length)
        return
    NumPut("Int", AnimW, "Int", AnimH, sz)
    NumPut("UChar", 0, "UChar", 0, "UChar", 255, "UChar", 1, bf)   ; alpha par pixel
    if (x != "")
        NumPut("Int", x, "Int", y, pt)
    DllCall("UpdateLayeredWindow", "Ptr", AnimHwnd, "Ptr", 0, "Ptr", (x != "") ? pt : 0, "Ptr", sz,
        "Ptr", AnimImages[AnimN + 1].dc, "Ptr", src, "UInt", 0, "Ptr", bf, "UInt", 2)
}

AnimImageSuivante() {
    global AnimN
    if !AnimImages.Length
        return
    AnimN := Mod(AnimN + 1, AnimImages.Length)
    AnimAfficher()
    if !Mod(AnimN, Max(1, AnimImages.Length // 4))  ; 4 fois par boucle : toujours visible ?
        AnimVerifier()
}

; Marche ou pause (4 fois par boucle pendant l'animation, à chaque tic de
; minute, après chaque redessin) ; cachée par une fenêtre, sa réapparition est
; guettée par les événements de fenêtres (voir SurveillerVisibilite)
AnimVerifier() {
    global AnimMarche
    if EnGeste()
        return
    peut := !!(Animations && AnimHwnd && AnimImages.Length && !NuitActive() && !EconomieEnergie() && !SobreAnimPause())
    voir := peut && AnimVisible()
    if (voir != AnimMarche) {
        AnimMarche := voir
        SetTimer(AnimImageSuivante, voir ? Round(ANIM_BOUCLE / AnimImages.Length) : 0)
    }
    GuetterVisibilite("anim", peut && !voir)
}

; L'illustration est-elle visible ? On regarde ce qu'il y a à l'écran en trois
; points : le widget (ou le bureau, si le widget laisse passer les clics), ou
; une fenêtre posée par-dessus. Session verrouillée : rien de visible.
AnimVisible() {
    try WinGetPos(&x, &y, &w, &h, "ahk_id " AnimHwnd)
    catch
        return false
    for q in [[0.5, 0.5], [0.3, 0.3], [0.7, 0.7]] {
        px := x + Round(w * q[1]), py := y + Round(h * q[2])
        hw := DllCall("WindowFromPoint", "Int64", (py << 32) | (px & 0xFFFFFFFF), "Ptr")
        r := hw ? DllCall("GetAncestor", "Ptr", hw, "UInt", 2, "Ptr") : 0      ; GA_ROOT
        if !r
            continue
        if (r = HWIDGET || r = AnimHwnd)
            return true
        try cls := WinGetClass("ahk_id " r)
        catch
            continue
        if (cls = "Progman" || cls = "WorkerW")
            return true
    }
    return false
}

; Économiseur de batterie de Windows actif (SYSTEM_POWER_STATUS.SystemStatusFlag)
EconomieEnergie() {
    if NotifsAlim.Length                          ; mode sobre : l'état notifié par Windows
        return Economie
    sps := Buffer(12, 0)
    return DllCall("GetSystemPowerStatus", "Ptr", sps) && NumGet(sps, 3, "UChar") = 1
}

; Redimensionnement : fenêtre masquée et animation arrêtée, images gardées
; (AnimMaj la réaffiche après le rendu complet du lâcher)
AnimSuspendre() {
    AnimArreter()
    if AnimHwnd
        DllCall("ShowWindow", "Ptr", AnimHwnd, "Int", 0)   ; SW_HIDE
}

; Arrête l'animation ; « liberer » retire aussi la fenêtre et les images
AnimArreter(liberer := false) {
    global AnimMarche, AnimGui, AnimHwnd
    SetTimer(AnimImageSuivante, 0)
    AnimMarche := false
    if !liberer
        return
    if AnimHwnd
        try AnimGui.Destroy()
    AnimGui := "", AnimHwnd := 0
    AnimLiberer()
}

AnimLiberer() {
    global AnimImages, AnimCle
    for im in AnimImages {
        DllCall("SelectObject", "Ptr", im.dc, "Ptr", im.ob)
        DllCall("DeleteObject", "Ptr", im.bm)
        DllCall("DeleteDC", "Ptr", im.dc)
    }
    AnimImages := [], AnimCle := ""
}
