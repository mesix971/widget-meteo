; =============================================================================
;  Widget météo — l'heure : police au choix, indépendante du style (menu
;  Heure ▸ Police), et rendu (Heure ▸ Rendu : plein, contour, dégradé,
;  verre dépoli, plus bas) — inclus par widget-meteo.ahk
;
;  Quelle que soit la police, les chiffres gardent la hauteur de ceux du
;  style (EmHeure) et des cases de largeur fixe (l'heure ne saute pas d'une
;  minute à l'autre) ; les polices étroites sont resserrées, les très larges
;  élargissent un peu le widget si besoin (LargeurMin).
;  (Constantes et état : POLICES_HEURE, POLICES_AUTRES, PoliceHeure,
;  PoliceTemp, MenuHeure…, déclarés dans widget-meteo.ahk.)
; =============================================================================

; La police est-elle installée ? (nom de famille GDI+ exact, « |1 » = gras)
PoliceDisponible(nom) {
    if (p := InStr(nom, "|"))
        nom := SubStr(nom, 1, p - 1)
    if DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", nom, "Ptr", 0, "Ptr*", &fam := 0)
        return false
    DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
    return true
}

; Une police des listes du menu, installée : sinon "" (selon le style)
PoliceValide(nom) {
    if (nom = "")
        return ""
    for liste in [POLICES_HEURE, POLICES_AUTRES]
        for v in liste
            if (v.Length = 2 && v[1] = nom)
                return PoliceDisponible(nom) ? nom : ""
    return ""
}

; Hauteur de l'encre des chiffres rapportée à celle du « H » (Ink Free : 0,80,
; Segoe UI Variable : 1,03) ; mesurée une fois par police
RatioChiffres(police) {
    static cache := Map()
    if !cache.Has(police) {
        p := CheminTexte("0123456789", police, 100)
        hc := Bornes(p).h
        DllCall("gdiplus\GdipDeletePath", "Ptr", p)
        cache[police] := hc / (Mesure(police).cap * 100)
    }
    return cache[police]
}

; Taille (em) qui donne aux chiffres de « police » la hauteur qu'ont ceux de la
; police du style pour une capitale « cap » : l'heure garde sa hauteur
EmHeure(police, cap) => EmPourCapitale(police, cap) * RatioChiffres(P_GROS[Style]) / RatioChiffres(police)

; Cases de l'heure pour une police et une taille : chaque chiffre au centre
; d'une case fixe (0,84 capitale pour les polices du style, resserrée pour une
; police étroite, élargie pour une manuscrite), et l'écart autour du « : »
CasesHeure(police, em, cap) {
    static cases := Map()
    cle := police "|" em
    if !cases.Has(cle) {
        m := 0
        Loop 10 {
            p := CheminTexte(A_Index - 1, police, em)
            m := Max(m, Bornes(p).w)
            DllCall("gdiplus\GdipDeletePath", "Ptr", p)
        }
        c := Max(1.08 * m, Min(0.84 * cap, m + 0.18 * cap))
        cases[cle] := {chiffre: c, ecart: Max(0, 0.18 * cap - (c - m) / 2)}
    }
    return cases[cle]
}

; Largeur de « HH:mm » en capitales (constante grâce aux cases fixes)
LargeurHeureCap(police) {
    static cache := Map()
    cle := police "|" Style
    if !cache.Has(cle) {
        em := EmHeure(police, 100), cs := CasesHeure(police, em, 100)
        p := CheminTexte(":", police, em)
        wp := Bornes(p).w
        DllCall("gdiplus\GdipDeletePath", "Ptr", p)
        cache[cle] := (4 * cs.chiffre + wp + 2 * cs.ecart) / 100
    }
    return cache[cle]
}

; Largeur de contenu minimale (en HC) : l'heure doit tenir, et en Android le
; résumé garder au moins 0,60 u à côté d'elle
LargeurMin() {
    if (PoliceHeure = "" || !LARG_MIN.Has(Style) || (Style != "iphone" && Style != "android" && Style != "epure"))
        return LARG_MIN.Get(Style, 1.65)
    w := LargeurHeureCap(PoliceHeure)
    return (Style = "iphone") ? Max(LARG_MIN["iphone"], 0.46 * w + 0.025) : Max(LARG_MIN[Style], 0.221 * w + 0.72)
}

; Menu Heure ▸ Police (les polices absentes de ce PC sont grisées)
ConstruireMenuHeure() {
    global MenuHeure, MenuPolice, MenuPoliceAutres, MenuRendu
    MenuPoliceAutres := Menu()
    for v in POLICES_AUTRES {
        MenuPoliceAutres.Add(v[2], ChoisirPolice.Bind(v[1]))
        if !PoliceDisponible(v[1])
            MenuPoliceAutres.Disable(v[2])
    }
    MenuPolice := Menu()
    for v in POLICES_HEURE {
        if (v.Length = 1) {
            MenuPolice.Add()
            continue
        }
        MenuPolice.Add(v[2], ChoisirPolice.Bind(v[1]))
        if (v[1] != "" && !PoliceDisponible(v[1]))
            MenuPolice.Disable(v[2])
    }
    MenuPolice.Add()
    MenuPolice.Add("Autres", MenuPoliceAutres)
    MenuRendu := Menu()
    for v in RENDUS
        MenuRendu.Add(v[2], ChoisirRendu.Bind(v[1]))
    MenuHeure := Menu()
    MenuHeure.Add("Rendu", MenuRendu)
    MenuHeure.Add("Police", MenuPolice)
    MenuHeure.Add()
    MenuHeure.Add(LIB_POLICE_TEMP, BasculerPoliceTemp)
}

CocherMenuHeure() {
    autre := false
    for v in POLICES_HEURE
        if (v.Length = 2)
            (v[1] = PoliceHeure) ? MenuPolice.Check(v[2]) : MenuPolice.Uncheck(v[2])
    for v in POLICES_AUTRES {
        (v[1] = PoliceHeure) ? MenuPoliceAutres.Check(v[2]) : MenuPoliceAutres.Uncheck(v[2])
        autre := autre || (v[1] = PoliceHeure)
    }
    autre ? MenuPolice.Check("Autres") : MenuPolice.Uncheck("Autres")
    (PoliceHeure != "") ? MenuHeure.Check("Police") : MenuHeure.Uncheck("Police")
    for v in RENDUS
        (v[1] = RenduHeure) ? MenuRendu.Check(v[2]) : MenuRendu.Uncheck(v[2])
    (RenduHeure != "plein") ? MenuHeure.Check("Rendu") : MenuHeure.Uncheck("Rendu")
    PoliceTemp ? MenuHeure.Check(LIB_POLICE_TEMP) : MenuHeure.Uncheck(LIB_POLICE_TEMP)
    ; sans police choisie, la température suit le style : la case n'a pas d'effet
    (PoliceHeure != "") ? MenuHeure.Enable(LIB_POLICE_TEMP) : MenuHeure.Disable(LIB_POLICE_TEMP)
}

ChoisirPolice(v, *) {
    global PoliceHeure := v
    SauverReglages()
    CocherMenus()
    Redessiner(true)                              ; la largeur minimale peut changer
}

BasculerPoliceTemp(*) {
    global PoliceTemp
    PoliceTemp := !PoliceTemp
    SauverReglages()
    CocherMenus()
    Redessiner()
}

; =============================================================================
;  Rendu de l'heure (menu Heure ▸ Rendu) : Plein, Contour (chiffres évidés),
;  Dégradé, Verre dépoli (le fond d'écran flouté à travers les chiffres).
;  Seules les formes « z » (l'heure) changent. L'effet profondeur reste
;  possible dans les quatre rendus : les brosses combinent le masque du sujet.
;  (Constantes et état : RENDUS, EPAIS_*, VERRE_*, RenduHeure, BlocHeure,
;  ZoneRendu, ClipContour, VerreBmp, VerreCle, déclarés dans widget-meteo.ahk.)
; =============================================================================

; Transforme les formes de l'heure selon le rendu, et fixe la zone des brosses
; (le bloc de l'heure, constant grâce aux cases fixes, élargi pour le contour,
; le liseré et l'ombre)
PreparerRendu(elems, k, brouillon) {
    global ClipContour, ZoneRendu
    ClipContour := 0, ZoneRendu := ""
    ; en analogique, les aiguilles sont trop fines pour être évidées : le contour y est rendu plein
    if (RenduHeure = "plein" || !IsObject(BlocHeure) || (RenduHeure = "contour" && Style = "analogique"))
        return
    b := BlocHeure, cap := b.HasOwnProp("cap") ? b.cap : b.h, d := A_ScreenDPI / 96, marge := 0
    if (RenduHeure = "contour") {
        ep := Max(1.5 * d, EPAIS_CONTOUR * cap)
        ; les polices à contours superposés (Bahnschrift, Cascadia) laissent des
        ; coutures à l'intérieur des chiffres : l'intérieur érodé est exclu du
        ; remplissage (son bord tombe dans le vide, jamais sur un bord visible)
        if !brouillon {
            DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &u := 0)
            for e in elems
                if (e.HasOwnProp("z") && e.z)
                    DllCall("gdiplus\GdipAddPathPath", "Ptr", u, "Ptr", e.p, "Int", 0)
            ClipContour := RegionErodee(u, ep / 2 + 1)
            DllCall("gdiplus\GdipDeletePath", "Ptr", u)
        }
        for e in elems
            if (e.HasOwnProp("z") && e.z)
                Elargir(e.p, ep), e.contour := true
        marge := ep
    } else if (RenduHeure = "degrade") {
        for e in elems
            if (e.HasOwnProp("z") && e.z)
                e.dg := {c1: e.f, c2: CouleurDegrade(e.f)}
    } else if (RenduHeure = "verre") {
        ; liseré clair (plus vif en haut) SOUS chaque chiffre, que le verre
        ; recouvre à moitié : un découpage GDI+ ne serait pas lissé
        el := Max(1.2 * d, EPAIS_LISERE * cap), i := 1
        while (i <= elems.Length) {
            e := elems[i]
            if !(e.HasOwnProp("z") && e.z) {
                i++
                continue
            }
            DllCall("gdiplus\GdipClonePath", "Ptr", e.p, "Ptr*", &pl := 0)
            Elargir(pl, 2 * el)
            elems.InsertAt(i, {p: pl, f: 0xB3FFFFFF, o: e.o, z: true, a: 0, dg: {c1: 0xE6FFFFFF, c2: 0x40FFFFFF}})
            e.verre := true, e.a := 0.6
            i += 2
        }
        marge := 2 * el
    }
    m := 0.06 * cap + marge + 8 * k
    ZoneRendu := {x: Floor(b.x - m), y: Floor(b.y - m), w: Ceil(b.w + 2 * m), h: Ceil(b.h + 2 * m)}
}

; Région r px à l'intérieur du tracé p : intersection de 16 copies décalées
RegionErodee(p, r) {
    DllCall("gdiplus\GdipCreateRegionPath", "Ptr", p, "Ptr*", &rg := 0)
    Loop 16 {
        a := (A_Index - 1) * 22.5 * 0.017453292519943295
        DllCall("gdiplus\GdipCreateRegionPath", "Ptr", p, "Ptr*", &rt := 0)
        DllCall("gdiplus\GdipTranslateRegion", "Ptr", rt, "Float", r * Cos(a), "Float", r * Sin(a))
        DllCall("gdiplus\GdipCombineRegionRegion", "Ptr", rg, "Ptr", rt, "Int", 1)   ; intersection
        DllCall("gdiplus\GdipDeleteRegion", "Ptr", rt)
    }
    return rg
}

LibererClipContour() {
    global ClipContour
    if ClipContour
        DllCall("gdiplus\GdipDeleteRegion", "Ptr", ClipContour)
    ClipContour := 0
}

; Bas du dégradé : la teinte du fond d'écran (le blanc si l'accent l'est déjà),
; assombrie avec le thème sombre ; sans analyse du fond, un gris bleuté
CouleurDegrade(c1) {
    teinte := InfosFond.Get("teinte", ""), sombre := ThemeCourant.sombre
    if !RegExMatch(teinte, "^[0-9A-Fa-f]{6}$")
        return (c1 & 0xFF000000) | (sombre ? 0x3A4652 : 0xB9CDE0)
    c := Integer("0x" teinte)
    if ((c1 & 0xFFFFFF) = c)
        c := 0xFFFFFF
    if sombre
        c := (Round(((c >> 16) & 0xFF) * 0.45) << 16) | (Round(((c >> 8) & 0xFF) * 0.45) << 8) | Round((c & 0xFF) * 0.45)
    return (c1 & 0xFF000000) | c
}

; Dégradé vertical sur la hauteur des chiffres (même rectangle pour les 5 caractères)
BrosseDegrade(dg) {
    cle := "dg|" dg.c1 "|" dg.c2
    if Brosses.Has(cle)
        return Brosses[cle]
    b := BlocHeure
    DllCall("gdiplus\GdipCreateLineBrushFromRect", "Ptr", Rect(b.x, b.y - 0.04 * b.h, b.w, 1.08 * b.h),
        "UInt", dg.c1, "UInt", dg.c2, "Int", 1, "Int", 3, "Ptr*", &br := 0)   ; vertical, miroir au-delà
    DllCall("gdiplus\GdipSetLineGammaCorrection", "Ptr", br, "Int", 1)
    Brosses[cle] := br
    return br
}

; Dégradé ET effet profondeur en une seule texture : une image de la zone porte
; la rampe du dégradé dans son canal bleu et le sujet dans son canal rouge (à
; moitié chacun) ; une matrice de couleurs en tire la couleur (c1 → c2 selon le
; bleu) et l'alpha (nul là où est le sujet)
BrosseDegradeePlaquee(masque, dg) {
    cle := "dgp|" dg.c1 "|" dg.c2
    if Brosses.Has(cle)
        return Brosses[cle]
    z := ZoneHeure, b := BlocHeure
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", z.w, "Int", z.h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g := 0)
    DllCall("gdiplus\GdipCreateLineBrushFromRect", "Ptr", Rect(b.x - z.x, b.y - 0.04 * b.h - z.y, b.w, 1.08 * b.h),
        "UInt", 0xFF000000, "UInt", 0xFF0000FF, "Int", 1, "Int", 3, "Ptr*", &lb := 0)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", g, "Ptr", lb, "Float", 0, "Float", 0, "Float", z.w, "Float", z.h)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", lb)
    cm := Buffer(100, 0)                          ; masque : R → R, G → G, B → 0, posé à 50 %
    NumPut("Float", 1, cm, 0), NumPut("Float", 1, cm, 24), NumPut("Float", 0.5, cm, 92), NumPut("Float", 1, cm, 96)
    DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia := 0)
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", ia, "Int", 0, "Int", 1, "Ptr", cm, "Ptr", 0, "Int", 0)
    DllCall("gdiplus\GdipDrawImageRectRectI", "Ptr", g, "Ptr", masque, "Int", 0, "Int", 0, "Int", z.w, "Int", z.h,
        "Int", z.x, "Int", z.y, "Int", z.w, "Int", z.h, "Int", 2, "Ptr", ia, "Ptr", 0, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    ; couleur = c1 + 2·bleu·(c2 − c1) ; alpha = a1 + 2·bleu·(a2 − a1) − 2·rouge·max(a1, a2)
    c1 := Composantes(dg.c1), c2 := Composantes(dg.c2)
    cm := Buffer(100, 0)
    Loop 4
        NumPut("Float", 2 * (c2[A_Index] - c1[A_Index]), cm, (2 * 5 + A_Index - 1) * 4)
    NumPut("Float", -2 * Max(c1[4], c2[4]), cm, (0 * 5 + 3) * 4)
    Loop 4
        NumPut("Float", c1[A_Index], cm, (4 * 5 + A_Index - 1) * 4)
    NumPut("Float", 1, cm, 96)
    DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia := 0)
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", ia, "Int", 0, "Int", 1, "Ptr", cm, "Ptr", 0, "Int", 0)
    DllCall("gdiplus\GdipCreateTextureIA", "Ptr", bmp, "Ptr", ia, "Float", 0, "Float", 0, "Float", z.w, "Float", z.h, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipTranslateTextureTransform", "Ptr", br, "Float", z.x, "Float", z.y, "Int", 0)
    DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)   ; la brosse garde sa copie
    Brosses[cle] := br
    return br
}

; ARGB → [r, g, b, a] entre 0 et 1
Composantes(argb) => [((argb >> 16) & 0xFF) / 255, ((argb >> 8) & 0xFF) / 255, (argb & 0xFF) / 255, ((argb >> 24) & 0xFF) / 255]

; Le fond d'écran flouté sous le widget (fond\verre.png, en demi-résolution,
; alpha = 255 − sujet), découpé et agrandi comme le masque ; 0 s'il manque
VerreSous(x, y, w, h) {
    global VerreBmp, VerreCle
    if (RenduHeure != "verre" || SansProfondeur || InfosFond.Get("verre", "0") != "1") {
        LibererVerre()
        return 0
    }
    cle := x "," y "," w "," h "," FondDate
    if (cle != VerreCle) {
        LibererVerre(false)                       ; (la découpe élargie reste en cache)
        VerreCle := cle
        VerreBmp := Oled ? DecoupeVerre(x, y, w, h) : ChargerImageReduite(F_VERRE, x, y, w, h, VERRE_ECHELLE)
    }
    return VerreBmp
}

; Anti-marquage : la découpe est prise dans une découpe élargie gardée en cache
; (verre.png relu une fois par fond et par position, pas à chaque pas d'orbite)
DecoupeVerre(x, y, w, h) {
    global VerreGrand, VerreGrandZone
    g := VerreGrandZone
    if !(VerreGrand && IsObject(g) && g.date = FondDate && x >= g.x && y >= g.y && x + w <= g.x + g.w && y + h <= g.y + g.h) {
        LibererVerreGrand()
        m := MARGE_MASQUE
        gx := Max(0, x - m), gy := Max(0, y - m), gw := Min(A_ScreenWidth, x + w + m) - gx, gh := Min(A_ScreenHeight, y + h + m) - gy
        if (gw >= w && gh >= h && (VerreGrand := ChargerImageReduite(F_VERRE, gx, gy, gw, gh, VERRE_ECHELLE)))
            VerreGrandZone := {x: gx, y: gy, w: gw, h: gh, date: FondDate}
        else
            return ChargerImageReduite(F_VERRE, x, y, w, h, VERRE_ECHELLE)
    }
    g := VerreGrandZone
    if DllCall("gdiplus\GdipCloneBitmapAreaI", "Int", x - g.x, "Int", y - g.y, "Int", w, "Int", h, "Int", 0x26200A,
        "Ptr", VerreGrand, "Ptr*", &c := 0)
        return 0
    return c
}

LibererVerreGrand() {
    global VerreGrand, VerreGrandZone
    if VerreGrand
        DllCall("gdiplus\GdipDisposeImage", "Ptr", VerreGrand)
    VerreGrand := 0, VerreGrandZone := ""
}

LibererVerre(tout := true) {
    global VerreBmp, VerreCle
    if VerreBmp
        DllCall("gdiplus\GdipDisposeImage", "Ptr", VerreBmp)
    VerreBmp := 0, VerreCle := ""
    if tout
        LibererVerreGrand()
}

; Comme ChargerImage, pour une image r fois plus petite que l'écran : la zone
; (x, y, w, h) de l'écran est agrandie (bilinéaire) dans une image w × h
ChargerImageReduite(fichier, x, y, w, h, r) {
    if (!FileExist(fichier) || DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", fichier, "Ptr*", &src := 0))
        return 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", src, "UInt*", &iw := 0)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", src, "UInt*", &ih := 0)
    copie := 0
    if (x >= 0 && y >= 0 && (x + w) / r <= iw + 0.5 && (y + h) / r <= ih + 0.5) {
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &copie)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", copie, "Ptr*", &g := 0)
        DllCall("gdiplus\GdipSetCompositingMode", "Ptr", g, "Int", 1)
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 6)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2)
        DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", g, "Ptr", src, "Float", 0, "Float", 0, "Float", w, "Float", h,
            "Float", x / r, "Float", y / r, "Float", w / r, "Float", h / r, "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    }
    DllCall("gdiplus\GdipDisposeImage", "Ptr", src)
    return copie
}

; Verre : le fond flouté, éclairci vers la couleur d'accent (et assombri par
; la plaque d'arrière-plan s'il y en a une) ; avec l'effet profondeur, l'alpha
; de verre.png (255 − sujet) fait passer le sujet devant
BrosseVerre(accent, profondeur) {
    cle := "verre|" accent "|" profondeur "|" TeinteRendu
    if Brosses.Has(cle)
        return Brosses[cle]
    z := ZoneHeure, l := VERRE_ECLAIR, o := Opacite / 100
    a := Composantes(accent), pl := Composantes(0xFF0E1116)
    cm := Buffer(100, 0), diag := (1 - o) * (1 - l)
    if (TeinteRendu = "") {
        Loop 3 {
            NumPut("Float", diag, cm, ((A_Index - 1) * 5 + A_Index - 1) * 4)
            NumPut("Float", pl[A_Index] * o * (1 - l) + l * a[A_Index], cm, (4 * 5 + A_Index - 1) * 4)
        }
    } else {                                      ; mode nuit : luminance de la couleur du verre × la teinte
        lum := [0.2126, 0.7152, 0.0722], tv := TeinteVecteur(), trans := 0
        Loop 3
            trans += lum[A_Index] * (pl[A_Index] * o * (1 - l) + l * a[A_Index])
        Loop 3 {
            i := A_Index
            Loop 3
                NumPut("Float", lum[i] * diag * tv[A_Index], cm, ((i - 1) * 5 + A_Index - 1) * 4)
            NumPut("Float", trans * tv[i], cm, (4 * 5 + i - 1) * 4)
        }
    }
    NumPut("Float", 1, cm, profondeur ? (3 * 5 + 3) * 4 : (4 * 5 + 3) * 4)   ; alpha de l'image, ou opaque
    NumPut("Float", 1, cm, 96)
    DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia := 0)
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", ia, "Int", 0, "Int", 1, "Ptr", cm, "Ptr", 0, "Int", 0)
    DllCall("gdiplus\GdipCreateTextureIA", "Ptr", VerreBmp, "Ptr", ia, "Float", z.x, "Float", z.y, "Float", z.w, "Float", z.h, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipTranslateTextureTransform", "Ptr", br, "Float", z.x, "Float", z.y, "Int", 0)
    DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia)
    Brosses[cle] := br
    return br
}

ChoisirRendu(v, *) {
    global RenduHeure := v
    SauverReglages()
    CocherMenus()
    ViderBrosses()
    if (v = "degrade" || v = "verre")
        VerifierFond(true)                        ; teinte du fond, fond flouté
    if (v = "verre" && InfosFond.Get("verre", "0") != "1")
        TrayTip("Je prépare une version floutée de ton fond d'écran (quelques secondes)…", "Rendu de l'heure")
    Redessiner()
}
