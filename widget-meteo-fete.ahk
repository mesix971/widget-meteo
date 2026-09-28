; =============================================================================
;  Widget météo — anniversaires (avec l'âge) et pluie de confettis le jour J
;  (menu Afficher ▸ Calendrier ▸ Anniversaires) — inclus par widget-meteo.ahk
;
;  reglages.ini, section [anniversaires] : n=AAAA-MM-JJ|prénom (ou MM-JJ si
;  l'année est inconnue : pas d'âge), et moi=AAAA-MM-JJ pour le tien. Données
;  personnelles : elles restent dans %LOCALAPPDATA%, jamais dans le dépôt.
;  La veille : « Anniversaire de Léa demain (30 ans) » ; le jour J : « Léa a 30
;  ans aujourd'hui » en tête du calendrier, et 3 s de confettis au premier
;  affichage visible de la journée (Anniversaires ▸ Voir les confettis pour
;  les revoir).
;  Les confettis sont dessinés à la volée dans une fenêtre posée sur le widget
;  (une seule image en mémoire, 30 images par seconde pendant 3 s) ; avec l'effet
;  profondeur, un sur trois passe derrière le sujet du fond d'écran, comme l'heure.
; =============================================================================

; ---------- Données ----------

LireAnniversaires() {
    global AnnivListe, AnnivMoi, AnnivVersion
    liste := [], moi := ""
    try sec := IniRead(F_REGLAGES, "anniversaires")
    catch
        sec := ""
    for ligne in StrSplit(sec, "`n", "`r") {
        if !(p := InStr(ligne, "="))
            continue
        cle := Trim(SubStr(ligne, 1, p - 1)), v := Trim(SubStr(ligne, p + 1))
        if (cle = "moi") {
            if DateAnnivValide(v)
                moi := v
            continue
        }
        q := InStr(v, "|"), d := q ? SubStr(v, 1, q - 1) : "", nom := q ? Trim(SubStr(v, q + 1)) : ""
        if (DateAnnivValide(d) && nom != "" && liste.Length < ANNIV_MAX)
            liste.Push({date: d, nom: nom})
        else
            Journal("anniversaire ignoré (date ou nom invalide) : « " ligne " »")
    }
    AnnivListe := liste, AnnivMoi := moi
    AnnivVersion += 1
}

; « AAAA-MM-JJ » (pas dans le futur) ou « MM-JJ » (29/02 compris)
DateAnnivValide(d) {
    if RegExMatch(d, "^\d{4}-\d{2}-\d{2}$")
        return IsTime(StrReplace(d, "-")) && Integer(StrReplace(d, "-")) <= Integer(FormatTime(, "yyyyMMdd"))
    return RegExMatch(d, "^\d{2}-\d{2}$") && IsTime("2000" StrReplace(d, "-"))
}

SauverAnniversaires() {
    global AnnivVersion
    try IniDelete(F_REGLAGES, "anniversaires")
    if (AnnivMoi != "")
        IniWrite(AnnivMoi, F_REGLAGES, "anniversaires", "moi")
    for i, a in AnnivListe
        IniWrite(a.date "|" a.nom, F_REGLAGES, "anniversaires", i)
    AnnivVersion += 1
}

; Prochaine date (AAAAMMJJ, aujourd'hui compris) d'un anniversaire ; le 29/02 tombe le 28 hors bissextile
ProchainAnniv(d) {
    auj := Aujourdhui(), an := auj // 10000, md := StrReplace(SubStr(d, -5), "-")
    Loop 2 {
        x := an md
        if (!IsTime(x) && md = "0229")
            x := an "0228"
        if (Integer(x) >= auj)
            return Integer(x)
        an += 1
    }
    return Integer(x)
}

; Âge atteint à la date « quand » (AAAAMMJJ), "" si l'année de naissance est inconnue
AgeAnniv(d, quand) => (StrLen(d) = 10) ? quand // 10000 - Integer(SubStr(d, 1, 4)) : ""

AnsTexte(age) => age " an" ((age > 1) ? "s" : "")

; « de Léa », « d'Anna », « d'Yves » (élision devant une voyelle ou un h ;
; pas devant un y qui sonne comme une consonne : « de Yanis »)
DePrenom(nom) => (RegExMatch(nom, "i)^(?:[aeiouhàâéèêëîïôöûü]|y(?![aeiouàâéèêëîïôöûü]))") ? "d'" : "de ") nom

AnnivExistent() => AnnivListe.Length || AnnivMoi != ""

; Événements du calendrier : le jour J (rang 1, en tête) et la veille (rang 5)
EvenementsAnniv(auj) {
    ev := []
    for a in AnnivListe {
        d := ProchainAnniv(a.date), n := JoursAvant(d), age := AgeAnniv(a.date, d)
        if (n = 0)
            ev.Push({rang: 1, genre: "anniv", long: (age != "") ? a.nom " a " AnsTexte(age) " aujourd'hui" : "Anniversaire " DePrenom(a.nom) " aujourd'hui",
                court: (age != "") ? a.nom " a " AnsTexte(age) : "Anniv. " DePrenom(a.nom), date: d})
        else if (n = 1)
            ev.Push({rang: 5, genre: "anniv", long: "Anniversaire " DePrenom(a.nom) " demain" ((age != "") ? " (" AnsTexte(age) ")" : ""),
                court: a.nom " demain", date: d})
    }
    if (AnnivMoi != "") {
        d := ProchainAnniv(AnnivMoi), n := JoursAvant(d), age := AgeAnniv(AnnivMoi, d)
        if (n = 0)
            ev.InsertAt(1, {rang: 1, genre: "anniv", long: "Joyeux anniversaire !" ((age != "") ? " " AnsTexte(age) " aujourd'hui" : ""),
                court: "Joyeux anniversaire !", date: d})
        else if (n = 1)
            ev.Push({rang: 5, genre: "anniv", long: "Ton anniversaire demain", court: "Ton anniv. demain", date: d})
    }
    return ev
}

; Un anniversaire aujourd'hui ?
AnnivAujourdhui() {
    for a in AnnivListe
        if (ProchainAnniv(a.date) = Aujourdhui())
            return true
    return AnnivMoi != "" && ProchainAnniv(AnnivMoi) = Aujourdhui()
}

; Le jour ymd est-il celui de l'anniversaire « d » (AAAA-MM-JJ ou MM-JJ) ? Un
; 29/02 se fête le 28/02 les années non bissextiles (comme ProchainAnniv)
MemeJourAnniv(d, ymd) {
    md := SubStr(ymd, 5, 4), a := SubStr(d, -5)
    return StrReplace(a, "-") = md || (md = "0228" && a = "02-29" && !IsTime(SubStr(ymd, 1, 4) "0229"))
}

; Un jour d'anniversaire (fenêtre « Mes jours »)
EstAnniv(ymd) {
    for a in AnnivListe
        if MemeJourAnniv(a.date, ymd)
            return true
    return AnnivMoi != "" && MemeJourAnniv(AnnivMoi, ymd)
}

; Pour la fenêtre des prévisions : les 3 prochains dans les 60 jours
ListeAnniv(auj) {
    proch := []
    for a in AnnivListe {
        d := ProchainAnniv(a.date)
        if (JoursAvant(d) <= 60)
            proch.Push({d: d, a: a})
    }
    Loop proch.Length - 1 {                       ; les plus proches d'abord (insertion)
        i := A_Index + 1, e := proch[i], k := i - 1
        while (k >= 1 && proch[k].d > e.d)
            proch[k + 1] := proch[k], k--
        proch[k + 1] := e
    }
    liste := [], j := Chr(0xA0) "j"
    for e in proch {
        if (A_Index > 3)
            break
        n := JoursAvant(e.d), age := AgeAnniv(e.a.date, e.d)
        liste.Push({genre: "anniv", titre: e.a.nom ((age != "") ? " · " AnsTexte(age) : ""), c: C_ANNIV,
            detail: DateCourte(e.d) " · " ((n = 0) ? "aujourd'hui" : (n = 1) ? "demain" : "dans " n j)})
    }
    return liste
}

; ---------- Menus ----------

AjouterAnniv(*) {
    if (AnnivListe.Length >= ANNIV_MAX) {
        MsgBox(ANNIV_MAX " anniversaires au plus : supprimes-en un d'abord.", "Anniversaires", "Iconi")
        return
    }
    r := InputBox("Prénom (30 caractères au plus) :", "Anniversaires", "w360 h130")
    nom := SubStr(Trim(RegExReplace(r.Value, "[|\r\n=]", " ")), 1, 30)
    if (r.Result != "OK" || nom = "")
        return
    if !IsObject(d := DemanderDateNaissance("Date de naissance de " nom " :"))
        return
    AnnivListe.Push({date: d.date, nom: nom})
    AnnivModifies()
}

MonAnniv(*) {
    global AnnivMoi
    if !IsObject(d := DemanderDateNaissance("Ta date de naissance :", AnnivMoi))
        return
    AnnivMoi := d.date
    AnnivModifies()
}

; JJ/MM/AAAA, ou JJ/MM si l'année est inconnue : {date: « AAAA-MM-JJ » ou « MM-JJ »}, ou "" (annulé)
DemanderDateNaissance(invite, defaut := "") {
    aide := "`nJJ/MM/AAAA (JJ/MM si tu ne connais pas l'année)"
    txt := invite aide, val := ""
    if (defaut != "")
        val := (StrLen(defaut) = 10) ? SubStr(defaut, 9, 2) "/" SubStr(defaut, 6, 2) "/" SubStr(defaut, 1, 4) : SubStr(defaut, 4, 2) "/" SubStr(defaut, 1, 2)
    Loop {
        r := InputBox(txt, "Anniversaires", "w380 h150", val)
        if (r.Result != "OK")
            return ""
        if (!LireDateSaisie(r.Value, &ymd, &annuel) || !DateAnnivValide(ymd)) {
            txt := "Date non reconnue (ou dans le futur) : « " r.Value " »." aide, val := r.Value
            continue
        }
        return {date: ymd}
    }
}

SupprimerAnniv(i, *) {
    global AnnivMoi
    if (i = "moi") {
        if (MsgBox("Oublier ta date d'anniversaire ?", "Anniversaires", "YesNo Icon?") = "Yes")
            AnnivMoi := "", AnnivModifies()
        return
    }
    if (i > AnnivListe.Length)
        return
    a := AnnivListe[i]
    if (MsgBox("Supprimer l'anniversaire " DePrenom(a.nom) " ?", "Anniversaires", "YesNo Icon?") != "Yes")
        return
    for k, x in AnnivListe                        ; la liste a pu changer pendant la question : on retire CET objet
        if (x = a) {
            AnnivListe.RemoveAt(k)
            AnnivModifies()
            return
        }
}

AnnivModifies() {
    SauverAnniversaires()
    MajMenuAnniv()
    CocherMenus()
    Redessiner(true)                              ; (le calendrier peut apparaître : Android change de hauteur)
    if IsObject(JoursGeo)
        PeindreJours()
}

; Les anniversaires à supprimer : [[libellé de menu, commande], …] (numérotés, « & » doublé)
AnnivSuppr() {
    liste := []
    if (AnnivMoi != "")
        liste.Push(["Le tien — " DateCourte(ProchainAnniv(AnnivMoi)), SupprimerAnniv.Bind("moi")])
    for i, a in AnnivListe
        liste.Push([i ". " StrReplace(a.nom, "&", "&&") " — " DateCourte(ProchainAnniv(a.date))
            . ((StrLen(a.date) = 10) ? " (" AnsTexte(AgeAnniv(a.date, ProchainAnniv(a.date))) ")" : ""), SupprimerAnniv.Bind(i)])
    return liste
}

; Sous-menu de suppression, reconstruit à chaque changement (la fenêtre Réglages
; construit le sien avec AnnivSuppr)
MajMenuAnniv() {
    MenuAnnivSuppr.Delete()
    if !AnnivExistent() {
        MenuAnnivSuppr.Add("(aucun)", (*) => 0)
        MenuAnnivSuppr.Disable("(aucun)")
        return
    }
    for e in AnnivSuppr()
        MenuAnnivSuppr.Add(e[1], e[2])
}

BasculerConfettis(*) {
    global AnnivConfettis
    AnnivConfettis := !AnnivConfettis
    SauverReglages()
    CocherMenus()
}

; ---------- Confettis ----------

; Le widget est-il visible (bureau dégagé) ? Trois points de son rectangle
WidgetVisible() {
    try WinGetPos(&x, &y, &w, &h, "ahk_id " HWIDGET)
    catch
        return false
    for q in [[0.5, 0.5], [0.3, 0.3], [0.7, 0.7]] {
        px := x + Round(w * q[1]), py := y + Round(h * q[2])
        hw := DllCall("WindowFromPoint", "Int64", (py << 32) | (px & 0xFFFFFFFF), "Ptr")
        r := hw ? DllCall("GetAncestor", "Ptr", hw, "UInt", 2, "Ptr") : 0
        if !r
            continue
        if (r = HWIDGET || r = AnimHwnd || IsObject(ZoneFen(r)))
            return true
        try cls := WinGetClass("ahk_id " r)
        catch
            continue
        if (cls = "Progman" || cls = "WorkerW")   ; (« Laisser passer les clics » : on voit le bureau)
            return true
    }
    return false
}

; Au tic de minute, et à chaque réapparition du widget (guetteur de
; visibilité, tant que la pluie n'a pas eu lieu) : la pluie du jour J, une
; fois, dès que le widget est visible et que quelqu'un est devant l'écran
; (souris ou clavier dans les 2 dernières minutes)
FeteAuto() {
    j := FormatTime(, "yyyyMMdd")
    if (!AnnivConfettis || !HWIDGET || !AnnivExistent() || !AnnivAujourdhui() || IniRead(F_REGLAGES, "widget", "fete_jour", "") = j) {
        GuetterVisibilite("fete", false)
        return
    }
    if (A_TimeIdle <= 120000 && FeteLancer(true)) {
        IniWrite(j, F_REGLAGES, "widget", "fete_jour")
        GuetterVisibilite("fete", false)
    } else
        GuetterVisibilite("fete", true)           ; caché (ou personne) : à sa réapparition
}

; Lance la pluie ; « auto » : pas la nuit, ni sur batterie en mode sobre, ni widget caché
FeteLancer(auto := false, *) {
    global FeteGui, FeteHwnd, FeteDC, FeteBm, FeteOb, FeteW, FeteH, FeteT0, FeteBouts, FeteBrosses, FeteMasque, TeinteRendu
    Critical -1                                   ; un glisser (FeteArreter) ne l'interrompt pas en route
    if (!HWIDGET || !CurW || EnGeste() || Glisse || ModeEdition)
        return false
    if (auto && (NuitActive() || SobreAnimPause() || EconomieEnergie() || SobreSuspendu() || !WidgetVisible()))
        return false
    FeteArreter()                                 ; un nouveau clic repart de zéro
    WinGetPos(&x, &y, &w, &h, HWIDGET)
    FeteW := w, FeteH := h
    ; comme la fenêtre d'animation : superposée, jamais activée, transparente aux clics, possédée par le widget
    FeteGui := Gui("-Caption +ToolWindow +E0x80000 +E0x08000000 +E0x20 +Owner" HWIDGET)
    FeteGui.Show("NA x" x " y" y " w1 h1")
    FeteHwnd := FeteGui.Hwnd
    WidgetEnBas()                                 ; (montrer une fenêtre possédée remonte le widget devant tes fenêtres)
    hdcE := DllCall("GetDC", "Ptr", 0, "Ptr")
    FeteDC := DllCall("CreateCompatibleDC", "Ptr", hdcE, "Ptr")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcE)
    bi := Buffer(40, 0)
    NumPut("UInt", 40, "Int", w, "Int", -h, "UShort", 1, "UShort", 32, bi)
    FeteBm := DllCall("CreateDIBSection", "Ptr", FeteDC, "Ptr", bi, "UInt", 0, "Ptr*", &bits := 0, "Ptr", 0, "UInt", 0, "Ptr")
    FeteOb := DllCall("SelectObject", "Ptr", FeteDC, "Ptr", FeteBm, "Ptr")
    ; couleurs (teintées la nuit, comme le reste), une brosse devant et une derrière le sujet
    ancienne := TeinteRendu, TeinteRendu := NuitTeinteActive()
    couleurs := []
    try {
        for c in FETE_COULEURS
            couleurs.Push((TeinteRendu != "") ? TeinteNuit(c) : c)
    } finally TeinteRendu := ancienne
    ; masque du sujet sous le widget : une copie à part (celle du widget reste à lui)
    FeteMasque := 0
    if (Profondeur && !SansProfondeur && InfosFond.Get("masque", "0") = "1")
        FeteMasque := (MasqueBmp && MasqueCle = x "," y "," w "," h "," FondDate)
            ? (DllCall("gdiplus\GdipCloneImage", "Ptr", MasqueBmp, "Ptr*", &cl := 0) ? 0 : cl)
            : ChargerImage(D_FOND "\masque.png", x, y, w, h)
    FeteBrosses := []
    for c in couleurs {
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", c, "Ptr*", &br := 0)
        FeteBrosses.Push({devant: br, derriere: FeteMasque ? BrosseSousSujet(FeteMasque, c, w, h) : 0})
    }
    ; les confettis : taille à l'échelle du widget, départ au-dessus, chute en 1 à 2 s par hauteur
    FeteBouts := NouveauxConfettis(w, h, HC * Echelle(), FeteMasque != 0)
    FeteT0 := A_TickCount
    SetTimer(FetePas, FETE_PAS)
    FetePas()
    Journal("confettis" (auto ? " (anniversaire du jour)" : "") " : " w "x" h (FeteMasque ? ", derrière le sujet" : ""))
    return true
}

; Les confettis d'une pluie sur w × h px (u : unité du widget) : départ
; au-dessus, chute de 0,5 à 0,9 hauteur par seconde, balancement, rotation et
; retournement ; « derriere » : un sur trois passe derrière le sujet
NouveauxConfettis(w, h, u, derriere) {
    bouts := []
    Loop FETE_NB
        bouts.Push({x0: Random(0.0, w), y0: -Random(0.02, 0.7) * h, vy: Random(0.5, 0.9) * h,
            amp: Random(0.006, 0.03) * w, f: Random(0.5, 1.4), ph: Random(0.0, 6.2832),
            lw: Random(0.028, 0.05) * u, lh: Random(0.013, 0.022) * u, rot: Random(0.0, 6.2832), vr: Random(-9.0, 9.0),
            flip: Random(3.0, 9.0), c: Random(1, FETE_COULEURS.Length), derriere: derriere && Mod(A_Index, 3) = 0})
    return bouts
}

; Brosse de couleur « argb » effacée là où est le sujet (canal R du masque),
; sur tout le rectangle de la fenêtre : la technique de BrossePlaquee, sans son
; cache (un redessin du widget pendant la pluie viderait les brosses partagées)
BrosseSousSujet(masque, argb, w, h) {
    a := ((argb >> 24) & 0xFF) / 255, cm := Buffer(100, 0)
    NumPut("Float", -a, cm, 12)                   ; alpha = a − a × sujet
    NumPut("Float", ((argb >> 16) & 0xFF) / 255, "Float", ((argb >> 8) & 0xFF) / 255, "Float", (argb & 0xFF) / 255,
        "Float", a, "Float", 1, cm, 80)
    DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia := 0)
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", ia, "Int", 0, "Int", 1, "Ptr", cm, "Ptr", 0, "Int", 0)
    DllCall("gdiplus\GdipCreateTextureIA", "Ptr", masque, "Ptr", ia, "Float", 0, "Float", 0, "Float", w, "Float", h, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia)
    return br
}

; Une image : chaque confetti tombe, se balance, tourne et se retourne (sa
; largeur suit un cosinus) ; la dernière demi-seconde, tout s'efface en fondu
FetePas() {
    Critical -1
    if !FeteHwnd {
        SetTimer(FetePas, 0)
        return
    }
    t := (A_TickCount - FeteT0) / 1000
    try WinGetPos(&x, &y, &w, &h, HWIDGET)
    catch
        w := 0
    if (t >= FETE_DUREE / 1000 || !DllCall("IsWindow", "Ptr", FeteHwnd) || w != FeteW || h != FeteH) {
        FeteArreter()                             ; fini, ou widget recréé ou redimensionné
        return
    }
    DllCall("gdiplus\GdipCreateFromHDC", "Ptr", FeteDC, "Ptr*", &gr := 0)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", gr, "UInt", 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    pts := Buffer(32)
    for b in FeteBouts {
        cy := b.y0 + b.vy * t
        if (cy < -b.lw || cy > h + b.lw)
            continue
        cx := b.x0 + b.amp * Sin(6.2832 * b.f * t + b.ph)
        a := b.rot + b.vr * t, dx := b.lw / 2 * Abs(Cos(b.flip * t + b.ph)), dy := b.lh / 2
        ca := Cos(a), sa := Sin(a)
        for i, s in [[-1, -1], [1, -1], [1, 1], [-1, 1]]
            NumPut("Float", cx + s[1] * dx * ca - s[2] * dy * sa, "Float", cy + s[1] * dx * sa + s[2] * dy * ca, pts, (i - 1) * 8)
        br := FeteBrosses[b.c]
        DllCall("gdiplus\GdipFillPolygon", "Ptr", gr, "Ptr", (b.derriere && br.derriere) ? br.derriere : br.devant, "Ptr", pts, "Int", 4, "Int", 1)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    fondu := Max(0, Min(1, (FETE_DUREE / 1000 - t) / 0.5))
    pt := Buffer(8), NumPut("Int", x, "Int", y, pt)
    sz := Buffer(8), NumPut("Int", w, "Int", h, sz)
    src := Buffer(8, 0)
    bf := Buffer(4), NumPut("UChar", 0, "UChar", 0, "UChar", Round(AlphaAffiche() * fondu), "UChar", 1, bf)   ; (intensité du mode nuit)
    hdcE := DllCall("GetDC", "Ptr", 0, "Ptr")
    DllCall("UpdateLayeredWindow", "Ptr", FeteHwnd, "Ptr", hdcE, "Ptr", pt, "Ptr", sz, "Ptr", FeteDC, "Ptr", src, "UInt", 0, "Ptr", bf, "UInt", 2)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcE)
}

FeteArreter() {
    global FeteGui, FeteHwnd, FeteDC, FeteBm, FeteOb, FeteBrosses, FeteMasque, FeteBouts
    SetTimer(FetePas, 0)
    if FeteGui
        try FeteGui.Destroy()
    FeteGui := "", FeteHwnd := 0
    if FeteDC {
        DllCall("SelectObject", "Ptr", FeteDC, "Ptr", FeteOb)
        DllCall("DeleteObject", "Ptr", FeteBm)
        DllCall("DeleteDC", "Ptr", FeteDC)
    }
    FeteDC := 0, FeteBm := 0, FeteOb := 0
    for br in FeteBrosses {
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", br.devant)
        if br.derriere
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", br.derriere)
    }
    FeteBrosses := [], FeteBouts := []
    if FeteMasque
        DllCall("gdiplus\GdipDisposeImage", "Ptr", FeteMasque)
    FeteMasque := 0
}

; ---------- Tests ----------

; Auto-test des textes et des dates (anniversaires de test, jamais les tiens)
TestAnniv(fichier) {
    global AnnivListe, AnnivMoi, HeureTest
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    AnnivListe := [{date: "1996-09-26", nom: "Léa"}, {date: "10-01", nom: "Anna"}, {date: "2000-02-29", nom: "Hugo"}], AnnivMoi := "1990-09-30"
    HeureTest := "20260925120000"
    ev := EvenementsAnniv(Aujourdhui())
    Verifier(ev.Length = 1 && ev[1].long = "Anniversaire de Léa demain (30 ans)", "la veille : « " (ev.Length ? ev[1].long : "") " »")
    HeureTest := "20260926120000"
    ev := EvenementsAnniv(Aujourdhui())
    Verifier(ev.Length = 1 && ev[1].long = "Léa a 30 ans aujourd'hui" && ev[1].rang = 1 && AnnivAujourdhui(), "le jour J : « " (ev.Length ? ev[1].long : "") " »")
    HeureTest := "20261001120000"
    ev := EvenementsAnniv(Aujourdhui())
    Verifier(ev.Length = 1 && ev[1].long = "Anniversaire d'Anna aujourd'hui", "sans année, élision : « " (ev.Length ? ev[1].long : "") " »")
    HeureTest := "20260930120000"
    ev := EvenementsAnniv(Aujourdhui())
    Verifier(ev.Length >= 1 && ev[1].long = "Joyeux anniversaire ! 36 ans aujourd'hui", "le tien : « " (ev.Length ? ev[1].long : "") " »")
    HeureTest := "20270227120000"
    Verifier(ProchainAnniv("2000-02-29") = 20270228 && AgeAnniv("2000-02-29", 20270228) = 27, "29/02 fêté le 28/02/2027 (27 ans)")
    ev := EvenementsAnniv(Aujourdhui())
    Verifier(ev.Length = 1 && ev[1].long = "Anniversaire d'Hugo demain (27 ans)", "élision devant h : « " (ev.Length ? ev[1].long : "") " »")
    Verifier(EstAnniv(20270228) && !EstAnniv(20280228) && EstAnniv(20280229), "repères de « Mes jours » (29/02)")
    HeureTest := "20260920120000"
    li := ListeAnniv(Aujourdhui())
    Verifier(li.Length = 2 && li[1].titre = "Léa · 30 ans" && InStr(li[1].detail, "dans 6") && li[2].titre = "Anna", "prévisions : « " (li.Length ? li[1].titre " " li[1].detail : "") " »")
    Verifier(AnsTexte(1) = "1 an" && AnsTexte(2) = "2 ans", "1 an, 2 ans")
    Verifier(DateAnnivValide("02-29") && !DateAnnivValide("2099-01-01") && !DateAnnivValide("13-01"), "dates de naissance valides")
    FileAppend(rapport "`n" echecs " échec(s)`n", fichier, "UTF-8")
}

; Planche : n images de la pluie sur le widget (fond sombre), sans fenêtre
PlancheFete(fichier, n := 6) {
    PreparerBande()
    k := Echelle(), w := Round(LargeurWidget() * k), h := Round(HauteurWidget() * k)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w * n, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, w * n, h, 0xFF20252B)
    bouts := NouveauxConfettis(w, h, HC * k, false)
    brosses := []
    for c in FETE_COULEURS {
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", c, "Ptr*", &br := 0)
        brosses.Push(br)
    }
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    pts := Buffer(32)
    Loop n {
        t := (A_Index - 1) * FETE_DUREE / 1000 / n, ox := (A_Index - 1) * w
        for b in bouts {
            cy := b.y0 + b.vy * t
            if (cy < -b.lw || cy > h + b.lw)
                continue
            cx := ox + b.x0 + b.amp * Sin(6.2832 * b.f * t + b.ph)
            a := b.rot + b.vr * t, dx := b.lw / 2 * Abs(Cos(b.flip * t + b.ph)), dy := b.lh / 2
            ca := Cos(a), sa := Sin(a)
            for i, s in [[-1, -1], [1, -1], [1, 1], [-1, 1]]
                NumPut("Float", cx + s[1] * dx * ca - s[2] * dy * sa, "Float", cy + s[1] * dx * sa + s[2] * dy * ca, pts, (i - 1) * 8)
            DllCall("gdiplus\GdipFillPolygon", "Ptr", gr, "Ptr", brosses[b.c], "Ptr", pts, "Int", 4, "Int", 1)
        }
    }
    ; coût d'une image à cette taille (effacer + remplir, comme FetePas, sans la pose à l'écran)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &img := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", img, "Ptr*", &g2 := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4)
    DllCall("QueryPerformanceFrequency", "Int64*", &fq := 0), DllCall("QueryPerformanceCounter", "Int64*", &c0 := 0)
    Loop 30 {
        t := A_Index / 10
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", g2, "UInt", 0)
        for b in bouts {
            cy := b.y0 + b.vy * t, cx := b.x0, a := b.rot + b.vr * t, dx := b.lw / 2, dy := b.lh / 2, ca := Cos(a), sa := Sin(a)
            for i, s in [[-1, -1], [1, -1], [1, 1], [-1, 1]]
                NumPut("Float", cx + s[1] * dx * ca - s[2] * dy * sa, "Float", cy + s[1] * dx * sa + s[2] * dy * ca, pts, (i - 1) * 8)
            DllCall("gdiplus\GdipFillPolygon", "Ptr", g2, "Ptr", brosses[b.c], "Ptr", pts, "Int", 4, "Int", 1)
        }
    }
    DllCall("QueryPerformanceCounter", "Int64*", &c1 := 0)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2), DllCall("gdiplus\GdipDisposeImage", "Ptr", img)
    FileAppend(w "x" h " px, " FETE_NB " confettis : " Round((c1 - c0) / fq * 1000 / 30, 1) " ms par image`n", fichier ".txt", "UTF-8")
    for br in brosses
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}
