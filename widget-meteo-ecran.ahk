; =============================================================================
;  Widget météo — écran et batterie : mode nuit façon StandBy (menu Écran et
;  batterie ▸ Mode nuit) — inclus par widget-meteo.ahk
;
;  Du coucher du soleil (+ un décalage) au lever, ou sur une plage horaire, le
;  widget baisse en fondu à 60, 40 ou 25 % d'intensité (alpha global de la
;  fenêtre : aucun redessin pour le fondu) et peut passer en monochrome rouge
;  sombre ou ambre (teinte appliquée au remplissage de chaque forme, pas de
;  post-traitement). La mise en page ne change pas ; l'effet profondeur
;  continue ; l'animation s'arrête et l'icône est dessinée fixe dans le widget
;  (donc teintée et atténuée). Au survol : pleine intensité 10 s. Les pastilles
;  et les repères colorés (« brut ») gardent leurs couleurs : elles ont un sens.
;  (Constantes et état : LIB_NUIT*, NUIT_*, Nuit*, AlphaCourant, TeinteRendu,
;  MenuEcran, MenuNuit…, déclarés dans widget-meteo.ahk.)
; =============================================================================

; Plage « 22:00-07:00 » (ou « 22h00 – 7h00 ») → {debut, fin} en minutes, "" si invalide ou vide
PlageNuit(txt) {
    if !RegExMatch(Trim(txt), "^([01]?\d|2[0-3])[:h]([0-5]\d)\s*[-–]\s*([01]?\d|2[0-3])[:h]([0-5]\d)$", &m)
        return ""
    d := m[1] * 60 + m[2], f := m[3] * 60 + m[4]
    return (d = f) ? "" : {debut: d, fin: f}
}

HeureMin(m) => Format("{:02}:{:02}", m // 60, Mod(m, 60))

; Fenêtre de nuit du jour, en minutes : {debut, fin, repli}. Mode « soleil » :
; du coucher + décalage au lever ; sans lever ni coucher (1er démarrage,
; régions polaires), repli sur la plage horaire (repli = true)
NuitFenetre() {
    if (NuitMode = "soleil") {
        lev := Minutes(Donnees.Get("lever", "")), cou := Minutes(Donnees.Get("coucher", ""))
        if (lev >= 0 && cou >= 0)
            return {debut: Mod(cou + NuitDecalage, 1440), fin: lev, repli: false}
    }
    p := PlageNuit(NuitPlage)
    if !IsObject(p)
        p := PlageNuit(NUIT_PLAGE_DEFAUT)
    return {debut: p.debut, fin: p.fin, repli: (NuitMode = "soleil")}
}

; La minute m (0 à 1439) est-elle dans la fenêtre ? Elle peut enjamber minuit ;
; début = fin : jamais
DansFenetre(m, f) => (f.debut = f.fin) ? false : (f.debut < f.fin) ? (m >= f.debut && m < f.fin) : (m >= f.debut || m < f.fin)

NuitActive() {
    if NuitEssai                                  ; « Essayer pendant 10 secondes »
        return true
    if (NuitMode = "0")
        return false
    mo := MomentAffiche()
    return DansFenetre(Integer(FormatTime(mo, "H")) * 60 + Integer(FormatTime(mo, "m")), NuitFenetre())
}

NuitTeinteActive() => (NuitActive() && (NuitTeinte = "rouge" || NuitTeinte = "ambre")) ? NuitTeinte : ""
AnimPermise() => Animations && !NuitActive()
AlphaNuit() => Round(255 * NuitIntensite / 100)
; Intensité voulue (le survol la remet à 100 %) ; pendant un geste ou le mode
; édition, AlphaAffiche force 100 % à l'écran sans toucher à cette cible
AlphaCible() => (NuitEveil || !NuitActive()) ? 255 : AlphaNuit()
; Intensité appliquée à un rendu (celle du fondu en cours, s'il y en a un)
AlphaAffiche() => (EnGeste() || ModeEdition) ? 255 : AlphaCourant
; Un pixel reste cliquable si alpha × intensité ≥ 128 : l'aplat invisible qui
; rend toute la surface saisissable doit monter un peu la nuit (2 au lieu de 1)
AlphaSaisie() => NuitActive() ? Max(1, Ceil(128 / AlphaNuit())) : 1

; Monochrome : luminance de la couleur × la teinte, alpha gardé
TeinteNuit(argb) {
    tv := TeinteVecteur()                         ; (pas « t » : même variable que « T », la casse est ignorée)
    l := 0.2126 * ((argb >> 16) & 0xFF) + 0.7152 * ((argb >> 8) & 0xFF) + 0.0722 * (argb & 0xFF)
    return (argb & 0xFF000000) | (Round(l * tv[1]) << 16) | (Round(l * tv[2]) << 8) | Round(l * tv[3])
}

; Couleur de remplissage d'une forme pendant le rendu (teintée la nuit, sauf « brut »)
CouleurForme(e) => (TeinteRendu != "" && !e.HasOwnProp("brut")) ? TeinteNuit(e.f) : e.f

; Composante j (1 à 3) de la teinte du rendu en cours, pour les matrices de couleurs
TeinteVecteur() {
    static TEINTES := Map("rouge", [1.00, 0.16, 0.10], "ambre", [1.00, 0.62, 0.18])
    return TEINTES[TeinteRendu]
}

; ---------- Intensité (alpha global de la fenêtre, sans redessin) ----------

; UpdateLayeredWindow en alpha seul : le contenu est gardé. ULW_ALPHA est
; indispensable (avec 0, comme le suggère la documentation, l'alpha est ignoré)
AppliquerAlpha(sca) {
    if !HWIDGET
        return
    bf := Buffer(4), NumPut("UChar", 0, "UChar", 0, "UChar", sca, "UChar", 1, bf)
    DllCall("UpdateLayeredWindow", "Ptr", HWIDGET, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr", bf, "UInt", 2)
}

; Fondu vers « vers » en n paliers de ms millisecondes (8 × 250 ms : 2 s)
NuitFondu(vers, n := 8, ms := 250) {
    global NuitFonduDe, NuitFonduVers, NuitFonduPas, NuitFonduN
    NuitFonduDe := AlphaCourant, NuitFonduVers := vers, NuitFonduPas := 0, NuitFonduN := n
    SetTimer(PasFondu, ms)
}

PasFondu() {
    global AlphaCourant, NuitFonduPas
    NuitFonduPas += 1
    AlphaCourant := Round(NuitFonduDe + (NuitFonduVers - NuitFonduDe) * NuitFonduPas / NuitFonduN)
    if (NuitFonduPas >= NuitFonduN) {
        SetTimer(PasFondu, 0)
        AlphaCourant := NuitFonduVers
    }
    if !(EnGeste() || ModeEdition)                ; pendant un geste : pleine intensité
        AppliquerAlpha(AlphaCourant)
}

; Amène l'intensité à la cible, en fondu (sans relancer un fondu déjà en route vers elle)
NuitAjusterAlpha(n := 8, ms := 250) {
    c := AlphaCible()
    if ((NuitFonduPas < NuitFonduN) ? (NuitFonduVers = c) : (c = AlphaCourant))   ; (fondu en route : comparé à SA cible)
        return
    NuitFondu(c, n, ms)
}

; Aperçus : pose un calque avec l'intensité du mode nuit (comme l'alpha global de la fenêtre)
DessinerAttenue(gr, img, x, y, w, h, sca) {
    if (sca >= 255)
        return DllCall("gdiplus\GdipDrawImageRectI", "Ptr", gr, "Ptr", img, "Int", x, "Int", y, "Int", w, "Int", h)
    cm := Buffer(100, 0)
    NumPut("Float", 1, cm, 0), NumPut("Float", 1, cm, 24), NumPut("Float", 1, cm, 48), NumPut("Float", sca / 255, cm, 72), NumPut("Float", 1, cm, 96)
    DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia := 0)
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", ia, "Int", 0, "Int", 1, "Ptr", cm, "Ptr", 0, "Int", 0)
    DllCall("gdiplus\GdipDrawImageRectRectI", "Ptr", gr, "Ptr", img, "Int", x, "Int", y, "Int", w, "Int", h,
        "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", 2, "Ptr", ia, "Ptr", 0, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia)
}

; ---------- Bascule (chaque minute, et après un réglage) ----------

; Renvoie true à la bascule jour ↔ nuit (le redessin est à la charge de l'appelant)
MajNuit() {
    global NuitEtatPrec
    act := NuitActive()
    if (act != NuitEtatPrec) {
        NuitEtatPrec := act
        if !NuitEssai
            Journal(act ? "mode nuit : début (" NuitTeinte ", " NuitIntensite " %)" : "mode nuit : fin")
        MajEtatNuit()
        ReglAJour()
        return true
    }
    MajEtatNuit()
    return false
}

; Au démarrage : l'état du moment, appliqué directement (sans fondu)
NuitDemarrer() {
    global AlphaCourant
    MajNuit()
    AlphaCourant := AlphaCible()
}

; Survol du widget la nuit : pleine intensité, jusqu'à 10 s après le dernier mouvement
NuitReveil() {
    global NuitEveil
    if (!NuitEtatPrec || !NuitSurvol || Traversant)
        return
    SetTimer(NuitRendormir, -10000)
    if !NuitEveil {
        NuitEveil := true
        NuitAjusterAlpha(4, 60)
    }
}

NuitRendormir() {
    global NuitEveil
    NuitEveil := false
    NuitAjusterAlpha()
}

EssayerNuit(*) {
    global NuitEssai
    if EnGeste()
        return
    NuitEssai := true
    SetTimer(FinEssaiNuit, -10000)
    if MajNuit()
        Redessiner()
    NuitAjusterAlpha(4, 100)
}

FinEssaiNuit() {
    global NuitEssai
    NuitEssai := false
    if MajNuit()
        Redessiner()
    NuitAjusterAlpha(4, 100)
}

; ---------- Mode nuit : réglages (Réglages ▸ Écran et batterie, menu Écran et batterie ▸ Mode nuit) ----------

; Ligne d'état : « ↳ ce soir de 20:46 à 07:39 », « ↳ en cours jusqu'à 07:39 »…
MajEtatNuit() {
    global LibEtatNuit
    if !IsObject(MenuNuit)
        return
    f := NuitFenetre()
    if (NuitMode = "0")
        txt := "désactivé"
    else if (f.debut = f.fin)
        txt := "jamais (début = fin)"
    else if (NuitEtatPrec && !NuitEssai)
        txt := "en cours jusqu'à " HeureMin(f.fin)
    else
        txt := (f.repli ? "heures du soleil inconnues : " : (f.debut >= 720) ? "ce soir " : "cette nuit ")
            . "de " HeureMin(f.debut) " à " HeureMin(f.fin)
    nouveau := "      ↳ " txt
    if (nouveau = LibEtatNuit)
        return
    MenuNuit.Rename(LibEtatNuit, nouveau)
    MenuNuit.Disable(nouveau)
    LibEtatNuit := nouveau
    ReglAJour()
}

; Après un changement de réglage : état, rendu (teinte), intensité
ApresReglageNuit() {
    SauverReglages()
    CocherMenus()
    MajNuit()
    Redessiner()
    NuitAjusterAlpha(4, 100)
}

ChoisirNuit(v, *) {
    global NuitMode
    NuitMode := v
    ApresReglageNuit()
}

ChoisirNuitDecalage(v, *) {
    global NuitDecalage
    NuitDecalage := v
    ApresReglageNuit()
}

ChoisirNuitIntensite(v, *) {
    global NuitIntensite
    NuitIntensite := v
    ApresReglageNuit()
}

ChoisirNuitTeinte(v, *) {
    global NuitTeinte
    NuitTeinte := v
    ApresReglageNuit()
}

BasculerNuitSurvol(*) {
    global NuitSurvol
    NuitSurvol := !NuitSurvol
    ApresReglageNuit()
}

ChoisirPlageNuit(*) {
    global NuitPlage
    r := InputBox("Plage horaire du mode nuit (par ex. 22:00-07:00) :", "Mode nuit", "w360 h130", NuitPlage)
    if (r.Result != "OK")
        return
    p := PlageNuit(r.Value)
    if !IsObject(p) {
        TrayTip("Plage non reconnue : « " r.Value " ». Exemple : 22:00-07:00 (début et fin différents).", "Mode nuit")
        return
    }
    NuitPlage := HeureMin(p.debut) "-" HeureMin(p.fin)
    ApresReglageNuit()
}

; Mode de test /testnuit <rapport> : les bascules sur les 1 440 minutes d'une journée
TestNuit(rapport) {
    global NuitMode, NuitDecalage, NuitPlage, Donnees
    garde := Donnees, txt := ""
    for c in [["soleil", 0, "07:38", "19:46"], ["soleil", 60, "07:38", "19:46"], ["soleil", 120, "07:38", "19:46"],
            ["soleil", 240, "04:50", "22:10"], ["soleil", 60, "", ""], ["plage", 0, "", "", "22:00-07:00"],
            ["plage", 0, "", "", "08:00-18:00"], ["plage", 0, "", "", "23h30 – 0h15"]] {
        NuitMode := c[1], NuitDecalage := c[2], NuitPlage := (c.Length >= 5) ? c[5] : "22:00-07:00"
        Donnees := Map("lever", c[3], "coucher", c[4])
        f := NuitFenetre(), bascules := "", avant := DansFenetre(1439, f), n := 0
        Loop 1440 {
            m := A_Index - 1, dedans := DansFenetre(m, f)
            if (dedans != avant)
                bascules .= (dedans ? " nuit dès " : " jour dès ") HeureMin(m)
            avant := dedans, n += dedans
        }
        txt .= c[1] " décalage " c[2] " lever « " c[3] " » coucher « " c[4] " » plage " NuitPlage (f.repli ? " (repli)" : "")
            . " →" bascules " (" n " min de nuit)`n"
    }
    for p in ["22:00-07:00", "7:00-7:00", "25:00-07:00", "22h00–07h00", ""]
        txt .= "plage « " p " » : " (IsObject(q := PlageNuit(p)) ? HeureMin(q.debut) " → " HeureMin(q.fin) : "refusée") "`n"
    Donnees := garde
    try FileDelete(rapport)
    FileAppend(txt, rapport, "UTF-8")
}

; =============================================================================
;  Anti-marquage OLED (menu Écran et batterie ▸ Anti-marquage OLED) : le
;  widget se décale de 1 px par minute sur un parcours en aller-retour dans un
;  carré de ±R px autour de sa place (R = 1, 2 ou 3). Les bords des traits
;  s'étalent sur 2R+1 px au lieu de rester sur la même rangée de pixels : ça
;  adoucit une rémanence sans l'empêcher (le vrai levier est l'intensité du
;  mode nuit). La position mémorisée (PosX, PosY) reste la position
;  « logique », sans le décalage ; toute lecture de la position de la fenêtre
;  passe par PositionLogique (glisser, aimant, redimensionnement, centrage).
;  (État : Oled, OrbiteDx, OrbiteDy, OrbiteTest, MenuOled, déclarés dans widget-meteo.ahk.)
; =============================================================================

; Parcours : aller en boustrophédon sur [−R, R]², retour par le même chemin ;
; chaque pas vaut exactement 1 px (R = 1 : 16 min, R = 2 : 48 min, R = 3 : 96 min)
OrbiteTable(R) {
    static cache := Map()
    if cache.Has(R)
        return cache[R]
    aller := []
    Loop 2 * R + 1 {
        yy := A_Index - 1 - R, rang := A_Index
        Loop 2 * R + 1
            aller.Push([Mod(rang, 2) ? A_Index - 1 - R : R - (A_Index - 1), yy])
    }
    tab := aller.Clone()
    Loop aller.Length - 2                         ; retour, sans répéter les deux extrémités
        tab.Push(aller[aller.Length - A_Index])
    cache[R] := tab
    return tab
}

; Décalage de la minute [dx, dy] (déduit de l'horloge : après un redémarrage,
; le parcours reprend au même point) ; aperçus : orbite=dx,dy
OrbiteVoulue() {
    if RegExMatch(OrbiteTest, "^(-?\d+),(-?\d+)$", &m)
        return [Integer(m[1]), Integer(m[2])]
    if !Oled
        return [0, 0]
    tab := OrbiteTable(Oled)
    return tab[Mod(MaintenantUnix() // 60, tab.Length) + 1]
}

; Position de la fenêtre sans le micro-décalage (celle qu'on mémorise)
PositionLogique(&x, &y, &w := 0, &h := 0) {
    WinGetPos(&x, &y, &w, &h, HWIDGET)
    x -= OrbiteDx, y -= OrbiteDy
}

ChoisirOled(v, *) {
    global Oled
    Oled := v
    SauverReglages()
    CocherMenus()
    Redessiner()
}

; Mode de test /testorbite <rapport> : pas de 1 px, bornes, passages par position
TestOrbite(rapport) {
    txt := "", echecs := 0
    for R in [1, 2, 3] {
        tab := OrbiteTable(R), n := tab.Length, vus := Map(), pasFaux := 0, horsBornes := 0
        for i, p in tab {
            q := tab[Mod(i, n) + 1]                ; pas suivant (le cycle se referme)
            if (Abs(q[1] - p[1]) + Abs(q[2] - p[2]) != 1)
                pasFaux++
            if (Abs(p[1]) > R || Abs(p[2]) > R)
                horsBornes++
            vus[p[1] "," p[2]] := vus.Get(p[1] "," p[2], 0) + 1
        }
        uns := 0, deux := 0
        for , c in vus
            (c = 1) ? uns++ : (c = 2) ? deux++ : 0
        ok := (n = 2 * (2 * R + 1) ** 2 - 2 && pasFaux = 0 && horsBornes = 0 && vus.Count = (2 * R + 1) ** 2 && uns = 2 && deux = vus.Count - 2)
        echecs += !ok
        txt .= "R = " R " : " n " pas (" n " min), " vus.Count " positions (" uns " visitée(s) 1 fois, " deux " 2 fois), pas ≠ 1 px : "
            . pasFaux ", hors bornes : " horsBornes (ok ? "" : "  ← ÉCHEC") "`n"
    }
    txt .= echecs " échec(s)`n"
    try FileDelete(rapport)
    FileAppend(txt, rapport, "UTF-8")
}

; =============================================================================
;  Réveil unique par minute (socle, invisible). Tant qu'un minuteur SetTimer
;  d'AutoHotkey est actif, le script se réveille toutes les 10 ms (constaté :
;  609 ms de CPU en 2 min pour un simple tic d'une seconde). Ici, un minuteur
;  Windows calé sur la minute (+30 ms) réarme la suivante, puis confie le
;  travail à Horloge, fil AutoHotkey normal (qui respecte Critical) : 1 réveil
;  par minute. La collecte est lancée au tic quand elle est due, puis suivie
;  jusqu'à sa fin ; une animation cachée guette sa réapparition par les
;  événements de fenêtres au lieu de sonder chaque seconde.
;  (État : CB_MINUTE, TicCible, ID_TIC_*, DerniereCollecte, CollectePID,
;  GuetAnim, GuetSobre, GuetActif, HooksFenetres, déclarés dans widget-meteo.ahk.)
; =============================================================================

ProchaineMinute() => 60000 - (A_Sec * 1000 + A_MSec) + 30

; Arme (ou réarme) le tic de la minute ; « cible » : la fonction à lancer à chaque tic
ArmerMinute(cible := "") {
    global CB_MINUTE, TicCible
    if IsObject(cible)
        TicCible := cible
    if !CB_MINUTE
        ; Sans l'option « F » (rapide) : ce rappel arrive par un message Windows,
        ; donc au milieu de n'importe quel fil du script ; la doc d'AutoHotkey
        ; proscrit alors le mode rapide (plantage du widget le 16/10/2026).
        CB_MINUTE := CallbackCreate(TicMinute, "", 4)    ; gardé en global jusqu'à la sortie (sinon plantage)
    DllCall("SetTimer", "Ptr", A_ScriptHwnd, "UPtr", ID_TIC_MINUTE, "UInt", ProchaineMinute(), "Ptr", CB_MINUTE, "UPtr")
}

; Rappel du minuteur Windows : réarmer D'ABORD (sinon l'heure se figerait), puis travailler
TicMinute(hwnd, msg, id, t) {
    DllCall("SetTimer", "Ptr", A_ScriptHwnd, "UPtr", ID_TIC_MINUTE, "UInt", ProchaineMinute(), "Ptr", CB_MINUTE, "UPtr")
    SetTimer(TicCible, -1)
    return 0
}

DesarmerMinute() {
    global CB_MINUTE
    DllCall("KillTimer", "Ptr", A_ScriptHwnd, "UPtr", ID_TIC_MINUTE)
    if CB_MINUTE
        CallbackFree(CB_MINUTE)
    CB_MINUTE := 0
}

; Heure du PC changée (WM_TIMECHANGE) : on se recale tout de suite
SurHeureChangee(*) {
    global DerniereCollecte
    if (DerniereCollecte > MaintenantUnix())      ; horloge reculée : la collecte ne doit pas attendre des heures
        DerniereCollecte := 0
    ArmerMinute()
    SetTimer(TicCible, -1)
}

; WM_POWERBROADCAST : sortie de veille (le minuteur a pu dormir avec le PC)
; ; le mode sobre y ajoute les notifications d'alimentation et d'écran
SurAlimentation(wParam, lParam, msg, hwnd) {
    if (wParam = 0x12) {                          ; PBT_APMRESUMEAUTOMATIC
        ArmerMinute()
        SetTimer(TicCible, -1)
    } else if (wParam = 0x8013)                   ; PBT_POWERSETTINGCHANGE (mode sobre)
        return SurReglageAlimentation(lParam)
}

; Collecte due : la période est écoulée depuis la dernière, et aucune ne tourne
; (mode sobre, écran éteint ou session verrouillée : rattrapée au retour ;
; horloge du PC reculée : écart négatif, collecte tout de suite)
CollecteDue() {
    d := MaintenantUnix() - DerniereCollecte
    return (d < 0 || d >= 60 * PeriodeCollecte()) && !(CollectePID && ProcessExist(CollectePID)) && !(Sobre && (EcranEteint || Verrouillee))
}

; Collecte en cours : dès qu'elle se termine, les nouvelles données sont lues
SuivreCollecte() {
    global CollecteRelance, CollectePID
    if (CollectePID && ProcessExist(CollectePID)) {
        if (A_TickCount - CollecteT0 < 180000)
            return
        ; bloquée depuis 3 min : arrêtée (elle écrirait par-dessus la suivante) ; le nom
        ; est vérifié, au cas où Windows aurait donné ce numéro à un autre processus
        try if (ProcessGetName(CollectePID) = "powershell.exe")
            ProcessClose(CollectePID)
    }
    CollectePID := 0
    SetTimer(SuivreCollecte, 0)
    SurveillerDonnees()
    if IsObject(r := CollecteRelance) {           ; demandée pendant qu'elle tournait
        CollecteRelance := ""
        LancerCollecte(r.forcer, r.forcerCal, r.calSeul)
    }
}

; ---------- Visibilité : guetter la réapparition sans sonder ----------

; « qui » (anim, sobre, fete) a besoin, ou plus besoin, de savoir quand le widget réapparaît
GuetterVisibilite(qui, actif) {
    global GuetAnim, GuetSobre, GuetFete
    if (qui = "anim")
        GuetAnim := !!actif
    else if (qui = "fete")
        GuetFete := !!actif
    else
        GuetSobre := !!actif
    SurveillerVisibilite(GuetAnim || GuetSobre || GuetFete)
}

; Événements de fenêtres (premier plan, fin de déplacement, réduction,
; bureau virtuel), plus un minuteur Windows de 5 s en filet de sécurité
; (Win+flèches, fenêtre fermée sans changement de premier plan)
SurveillerVisibilite(actif) {
    global GuetActif, HooksFenetres, CB_HOOK, CB_VISIB
    if (!!actif = GuetActif)
        return
    GuetActif := !!actif
    if actif {
        if !CB_HOOK
            ; sans l'option « F » (rapide) : rappels déclenchés par des messages
            ; Windows (voir ArmerMinute)
            CB_HOOK := CallbackCreate(HookFenetres, "", 7), CB_VISIB := CallbackCreate(TicVisibilite, "", 4)
        for plage in [[0x0003, 0x0003], [0x000B, 0x000B], [0x0016, 0x0017], [0x8017, 0x8018]]
            if (h := DllCall("SetWinEventHook", "UInt", plage[1], "UInt", plage[2], "Ptr", 0, "Ptr", CB_HOOK,
                "UInt", 0, "UInt", 0, "UInt", 2, "Ptr"))   ; hors contexte, sans nos propres fenêtres
                HooksFenetres.Push(h)
        DllCall("SetTimer", "Ptr", A_ScriptHwnd, "UPtr", ID_TIC_VISIBILITE, "UInt", 5000, "Ptr", CB_VISIB, "UPtr")
    } else {
        for h in HooksFenetres
            DllCall("UnhookWinEvent", "Ptr", h)
        HooksFenetres := []
        DllCall("KillTimer", "Ptr", A_ScriptHwnd, "UPtr", ID_TIC_VISIBILITE)
    }
}

; Une rafale d'événements ne donne qu'une vérification (80 ms après le dernier)
HookFenetres(h, evt, hwnd, obj, enfant, fil, t) {
    SetTimer(VerifierVisibilite, -80)
    return 0
}

TicVisibilite(hwnd, msg, id, t) {
    SetTimer(VerifierVisibilite, -1)
    return 0
}

VerifierVisibilite() {
    AnimVerifier()                                ; l'animation reprend si elle est de nouveau visible
    VerifierSobre()                               ; mode sobre : redessin en attente
    if GuetFete                                   ; les confettis du jour J pas encore vus
        FeteAuto()
}

; Mode de test /testtic <rapport> [minutes] : les tics du minuteur, et le CPU consommé
TestTic(rapport, minutes := 2) {
    global TestTicFichier, TestTicMax
    TestTicFichier := rapport, TestTicMax := minutes
    try FileDelete(rapport)
    FileAppend("départ " FormatTime(, "HH:mm:ss") "." A_MSec "`n", rapport, "UTF-8")
    ArmerMinute(TicTest)
}

TicTest() {
    global TestTicN
    TestTicN += 1
    FileAppend(FormatTime(, "HH:mm:ss") "." A_MSec " tic`n", TestTicFichier, "UTF-8")
    if (TestTicN < TestTicMax)
        return
    DllCall("GetProcessTimes", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "Int64*", &c := 0, "Int64*", &e := 0, "Int64*", &k := 0, "Int64*", &u := 0)
    FileAppend(TestTicN " tics, CPU " Round((k + u) / 10000) " ms (démarrage compris)`n", TestTicFichier, "UTF-8")
    DesarmerMinute()
    ExitApp
}

; =============================================================================
;  Mode sobre (menu Écran et batterie ▸ Mode sobre), désactivé par défaut.
;  Écran éteint, session verrouillée ou widget entièrement recouvert : plus
;  aucun redessin (remis à jour d'un coup à la réapparition) ; écran éteint :
;  ni collecte ni changement de fond (rattrapés au rallumage). Sur batterie ou
;  économiseur : animations en pause, météo toutes les 30 min (15 pendant une
;  vigilance orange ou la Seine haute), et un fond d'ambiance jamais généré
;  n'est préparé qu'au retour sur secteur. Tout vient de notifications de
;  Windows (alimentation, écran, session) : aucun sondage.
;  (État : Sobre*, EcranEteint, Verrouillee, SurBatterie, Economie, CacheMemo,
;  RedessinEnAttente, AttenteRepos, NotifsAlim, AmbianceDifferee, MenuSobre…,
;  déclarés dans widget-meteo.ahk.)
; =============================================================================

SurBatterieEco() => SurBatterie || Economie
SobreSuspendu() => Sobre && SobrePause && (EcranEteint || Verrouillee || CacheMemo)
; animation en pause : sur batterie (option), ou écran éteint / session verrouillée (pause)
SobreAnimPause() => Sobre && ((SobreAnim && SurBatterieEco()) || (SobrePause && (EcranEteint || Verrouillee)))
SobreDiffere() => Sobre && SobreAmbiance && SurBatterieEco()

; Vigilance orange ou plus, ou Seine haute : la météo reste à 15 min, même sur batterie
AlerteMeteoEnCours() {
    v := VigilanceActive()
    return (IsObject(v) && v.niv >= 3) || SeineAffichee
}

PeriodeCollecte() => (Sobre && SobreMeteo && SurBatterieEco() && !AlerteMeteoEnCours()) ? 30 : METEO_MIN

; GUID des notifications d'alimentation (Power Setting GUIDs, learn.microsoft.com)
GuidAlim(nom) {
    static g := Map()
    if !g.Count
        for n, s in Map("ecran", "{2B84C20E-AD23-4DDF-93DB-05FFBD7EFCA5}",   ; GUID_SESSION_DISPLAY_STATUS
                "secteur", "{5D3E9A59-E9D5-4B00-A6BD-FF34FF516548}",         ; GUID_ACDC_POWER_SOURCE
                "eco", "{550E8400-E29B-41D4-A716-446655440000}") {           ; GUID_ENERGY_SAVER_STATUS
            b := Buffer(16)
            DllCall("ole32\CLSIDFromString", "WStr", s, "Ptr", b)
            g[n] := b
        }
    return g[nom]
}

; Inscription aux notifications (les gestionnaires OnMessage 0x218 et 0x2B1
; sont posés avant, dans Demarrer : Windows envoie tout de suite l'état courant)
InscrireAlimentation() {
    global NotifsAlim, SessionInscrite, SurBatterie, Economie
    if NotifsAlim.Length
        return
    sps := Buffer(12, 0)                          ; état de départ, confirmé par la notification immédiate
    if DllCall("GetSystemPowerStatus", "Ptr", sps)
        SurBatterie := (NumGet(sps, 0, "UChar") = 0), Economie := (NumGet(sps, 3, "UChar") = 1)
    for n in ["ecran", "secteur", "eco"]
        if (h := DllCall("RegisterPowerSettingNotification", "Ptr", A_ScriptHwnd, "Ptr", GuidAlim(n), "UInt", 0, "Ptr"))
            NotifsAlim.Push(h)
    SessionInscrite := !!DllCall("wtsapi32\WTSRegisterSessionNotification", "Ptr", A_ScriptHwnd, "UInt", 0)
}

DesinscrireAlimentation() {
    global NotifsAlim, SessionInscrite, EcranEteint, Verrouillee
    for h in NotifsAlim
        DllCall("UnregisterPowerSettingNotification", "Ptr", h)
    NotifsAlim := []
    if SessionInscrite
        DllCall("wtsapi32\WTSUnRegisterSessionNotification", "Ptr", A_ScriptHwnd)
    SessionInscrite := false, EcranEteint := false, Verrouillee := false
}

; PBT_POWERSETTINGCHANGE : lParam → POWERBROADCAST_SETTING (GUID, DataLength à +16, Data à +20)
SurReglageAlimentation(lParam) {
    global EcranEteint, SurBatterie, Economie, AmbianceDifferee
    g1 := NumGet(lParam, 0, "Int64"), g2 := NumGet(lParam, 8, "Int64"), data := NumGet(lParam, 20, "UInt")
    Est(nom) => g1 = NumGet(GuidAlim(nom), 0, "Int64") && g2 = NumGet(GuidAlim(nom), 8, "Int64")
    if Est("ecran") {
        eteint := (data = 0)                      ; 2 (atténué) compte comme allumé
        if (eteint != EcranEteint) {
            EcranEteint := eteint
            Journal("mode sobre : écran " (eteint ? "éteint" : "rallumé"))
            if !eteint
                SetTimer(RattraperSobre, -1)
            else
                SetTimer(AnimVerifier, -1)          ; animation arrêtée écran éteint
        }
    } else if Est("secteur") {
        bat := (data != 0)                        ; 1 batterie, 2 onduleur : sur batterie
        if (bat != SurBatterie) {
            SurBatterie := bat
            Journal("mode sobre : " (bat ? "sur batterie" : "sur secteur"))
            if !bat {                             ; retour sur secteur : ambiance différée, collecte en retard
                AmbianceDifferee := ""
                SetTimer(RattraperSobre, -1)
            }
            SetTimer(AnimVerifier, -1)
        }
    } else if Est("eco") {
        eco := (data >= 1)                        ; « prerelease » chez Microsoft : toute valeur ≥ 1 = économie
        if (eco != Economie) {
            Economie := eco
            SetTimer(AnimVerifier, -1)
        }
    }
    SetTimer(MajEtatSobre, -1)
    return 1
}

; WM_WTSSESSION_CHANGE : 7 session verrouillée, 8 déverrouillée
SurSession(wParam, lParam, msg, hwnd) {
    global Verrouillee
    if (wParam = 7 || wParam = 8) {
        Verrouillee := (wParam = 7)
        Journal("mode sobre : session " (Verrouillee ? "verrouillée" : "déverrouillée"))
        if !Verrouillee
            SetTimer(RattraperSobre, -1)
        else
            SetTimer(AnimVerifier, -1)
        SetTimer(MajEtatSobre, -1)
    }
}

; Écran rallumé, session déverrouillée, retour sur secteur : on rattrape
RattraperSobre() {
    VerifierSobre()
    if CollecteDue()
        LancerCollecte()
    VerifierAmbiance()
    AnimVerifier()
}

; Le widget est-il entièrement recouvert ? On retire du rectangle du widget le
; cadre visible de chaque fenêtre au-dessus de lui (ordre Z) : visible, pas
; réduite, pas masquée (autre bureau virtuel), ni superposée ni transparente
; (celles-là peuvent laisser voir dessous). Caché si rien ne reste.
EntierementCache(hwnd) {
    if (!hwnd || !DllCall("IsWindowVisible", "Ptr", hwnd))
        return false
    r := Buffer(16)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", r)
    rg := DllCall("CreateRectRgn", "Int", NumGet(r, 0, "Int"), "Int", NumGet(r, 4, "Int"), "Int", NumGet(r, 8, "Int"), "Int", NumGet(r, 12, "Int"), "Ptr")
    w := hwnd, cache := false, n := 0, fr := Buffer(16)
    while (w := DllCall("GetWindow", "Ptr", w, "UInt", 3, "Ptr")) {   ; GW_HWNDPREV : vers le haut
        if (++n > 3000)
            break
        if (!DllCall("IsWindowVisible", "Ptr", w) || DllCall("IsIconic", "Ptr", w))
            continue
        if (DllCall("GetWindowLongPtr", "Ptr", w, "Int", -20, "Ptr") & 0x80020)   ; WS_EX_LAYERED | WS_EX_TRANSPARENT
            continue
        cloak := 0
        DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", w, "UInt", 14, "UInt*", &cloak, "UInt", 4)   ; DWMWA_CLOAKED
        if cloak
            continue
        if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", w, "UInt", 9, "Ptr", fr, "UInt", 16)   ; cadre visible (sans les 16 px invisibles)
            DllCall("GetWindowRect", "Ptr", w, "Ptr", fr)
        rw := DllCall("CreateRectRgn", "Int", NumGet(fr, 0, "Int"), "Int", NumGet(fr, 4, "Int"), "Int", NumGet(fr, 8, "Int"), "Int", NumGet(fr, 12, "Int"), "Ptr")
        res := DllCall("CombineRgn", "Ptr", rg, "Ptr", rg, "Ptr", rw, "Int", 4)   ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", rw)
        if (res = 1) {                            ; NULLREGION : plus rien de visible
            cache := true
            break
        }
    }
    DllCall("DeleteObject", "Ptr", rg)
    return cache
}

; Visibilité du widget (tic de minute, événements de fenêtres) : redessin en attente lancé à la réapparition
VerifierSobre() {
    global CacheMemo, RedessinEnAttente, AttenteRepos
    avant := CacheMemo
    CacheMemo := (Sobre && SobrePause && HWIDGET) ? EntierementCache(HWIDGET) : false
    if (CacheMemo != avant)
        Journal("mode sobre : widget " (CacheMemo ? "caché" : "visible"))
    GuetterVisibilite("sobre", CacheMemo)         ; caché : on guette sa réapparition
    if (RedessinEnAttente && !SobreSuspendu()) {
        RedessinEnAttente := false, r := AttenteRepos, AttenteRepos := false
        Redessiner(r)
    }
    MajEtatSobre()
}

; Ligne d'état : « ↳ secteur · widget visible », « ↳ écran éteint : tout est en pause »…
MajEtatSobre() {
    global LibEtatSobre
    if !IsObject(MenuSobre)
        return
    if !Sobre
        txt := "inactif"
    else if EcranEteint
        txt := "écran éteint : tout est en pause"
    else if Verrouillee
        txt := "session verrouillée : tout est en pause"
    else
        txt := (SurBatterieEco() ? "batterie" : "secteur") " · widget " (CacheMemo ? "caché" (RedessinEnAttente ? ", redessin en attente" : "") : "visible")
    nouveau := "      ↳ " txt
    if (nouveau = LibEtatSobre)
        return
    MenuSobre.Rename(LibEtatSobre, nouveau)
    MenuSobre.Disable(nouveau)
    LibEtatSobre := nouveau
    ReglAJour()
}

BasculerSobre(cle, *) {
    global Sobre, SobrePause, SobreAnim, SobreMeteo, SobreAmbiance, AmbianceDifferee
    switch cle {
        case "actif":
            Sobre := !Sobre
            if Sobre
                InscrireAlimentation()
            else {
                DesinscrireAlimentation()
                AmbianceDifferee := ""
            }
        case "pause":    SobrePause := !SobrePause
        case "anim":     SobreAnim := !SobreAnim
        case "meteo":    SobreMeteo := !SobreMeteo
        case "ambiance":
            SobreAmbiance := !SobreAmbiance
            if !SobreAmbiance
                AmbianceDifferee := ""
    }
    SauverReglages()
    CocherMenus()
    VerifierSobre()                               ; (lance un redessin en attente s'il n'y a plus de raison d'attendre)
    AnimVerifier()
    VerifierAmbiance()
}

; Mode de test /testsobre <rapport> : état de l'alimentation et du recouvrement, sans rien changer
TestSobre(rapport) {
    global Sobre
    vus := []
    Noter(w, l, *) {                              ; enregistre seulement (ne déclenche ni collecte ni fond)
        if (w != 0x8013)
            return
        nom := "GUID inconnu"
        for n in ["ecran", "secteur", "eco"]
            if (NumGet(l, 0, "Int64") = NumGet(GuidAlim(n), 0, "Int64") && NumGet(l, 8, "Int64") = NumGet(GuidAlim(n), 8, "Int64"))
                nom := n
        vus.Push(nom "=" NumGet(l, 20, "UInt"))
        return 1
    }
    OnMessage(0x218, Noter)
    t0 := A_TickCount
    InscrireAlimentation()
    txt := "inscriptions : " NotifsAlim.Length " sur 3, session " (SessionInscrite ? "oui" : "non") " (" (A_TickCount - t0) " ms)`n"
    txt .= "départ (GetSystemPowerStatus) : " (SurBatterie ? "batterie" : "secteur") ", économiseur " (Economie ? "oui" : "non") "`n"
    Sleep(500)                                    ; les notifications immédiates arrivent pendant l'attente
    OnMessage(0x218, Noter, 0)
    s := ""
    for v in vus
        s .= (A_Index > 1 ? ", " : "") v
    txt .= "notifications reçues : " (s = "" ? "aucune" : s) "  (ecran : 0 éteint, 1 allumé · secteur : 0 secteur, 1 batterie · eco : 0 non)`n"
    Sobre := true
    txt .= "période de collecte : " PeriodeCollecte() " min`n"
    DesinscrireAlimentation()
    ; recouvrement : chaque fenêtre visible de premier niveau testée comme si c'était le widget
    for hw in WinGetList() {
        try t := WinGetTitle(hw), c := WinGetClass(hw)
        catch
            continue
        if (t = "" || !DllCall("IsWindowVisible", "Ptr", hw))
            continue
        t1 := A_TickCount, ca := EntierementCache(hw)
        txt .= (ca ? "CACHÉE  " : "visible ") Format("{:4}", A_TickCount - t1) " ms  " c "  « " SubStr(t, 1, 50) " »`n"
    }
    try FileDelete(rapport)
    FileAppend(txt, rapport, "UTF-8")
}

; widget-meteo-fond.py --seulement-existante a noté l'ambiance « à créer » (fond\ambiance.txt)
AmbianceACreer(nom) {
    try txt := "`n" StrReplace(FileRead(D_FOND "\ambiance.txt", "UTF-8"), "`r")   ; (Python écrit des CRLF)
    catch
        return false
    return InStr(txt, "`nnom=" nom "`n") && InStr(txt, "`netat=a_creer`n")
}
