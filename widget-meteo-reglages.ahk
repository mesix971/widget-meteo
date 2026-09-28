; =============================================================================
;  Widget météo — la fenêtre « Réglages » (clic droit ▸ Réglages…) : toutes
;  les options, rangées par catégories à gauche, avec interrupteurs et choix
;  à droite, appliqués aussitôt. Même famille que « Mes jours » : fenêtre
;  surgissante superposée, dessinée en GDI+ (PeindreCalque), fermée par Échap,
;  un clic ailleurs ou une autre application passée au premier plan.
;
;  La fenêtre ne connaît pas les réglages : elle appelle les fonctions des
;  anciens menus (Basculer…, Choisir…). Ces menus sont toujours construits et
;  tenus à jour par CocherMenus (Maj + clic droit sur le widget : le menu
;  complet) ; CocherMenus et les lignes d'état (MajEtat…) font repeindre la
;  fenêtre (ReglAJour). Inclus par widget-meteo.ahk (constantes REGL_…,
;  REGLAGES_CATS et état Regl… déclarés là-bas).
; =============================================================================

; ---------- Ouverture, fermeture ----------

OuvrirReglages(*) {
    global ReglGui, ReglHwnd, ReglGeo
    QuitterEdition()                              ; le mode « Redimensionner à la souris » s'arrête
    if (ReglHwnd && DllCall("IsWindow", "Ptr", ReglHwnd)) {
        FermerReglages("nouvelle demande")
        return
    }
    FermerPrevisions("réglages demandés")         ; une seule fenêtre surgissante à la fois
    FermerJours("réglages demandés")
    FermerMarches("réglages demandés")
    FermerFicheActu("réglages demandés")
    kp := A_ScreenDPI / 96
    WinGetPos(&wx, &wy, &ww, &wh, HWIDGET)
    e := EcranProche(wx + ww // 2, wy + wh // 2)
    ReglGeo := {kp: kp, cat: ReglCat, defil: 0, survol: "", suivi: false, x: 0, y: 0, w: 0, h: 0, px: 0, py: 0, mp: "",
        hauteur: Max(REGL_H_MIN, Min(REGL_H, Floor((e.b - e.t) / kp) - 32))}
    ReglGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x80000")
    ReglGui.Show("NA x0 y0 w1 h1")
    ReglHwnd := ReglGui.Hwnd
    PeindreReglages(true, true)
    SurgieOuverteLe(ReglHwnd, "réglages ouverts")
}

FermerReglages(raison := "", *) {
    global ReglGui, ReglHwnd, ReglGeo
    if !ReglHwnd
        return
    if (IsObject(ReglGeo) && ReglGeo.w) {         ; déplacée à la souris : elle se rouvrira là
        ReglPosReelle()
        if (ReglGeo.x != ReglGeo.px || ReglGeo.y != ReglGeo.py)
            try IniWrite(ReglGeo.x "," ReglGeo.y, F_REGLAGES, "widget", "reglages_pos")
    }
    ReglHwnd := 0, ReglGeo := ""
    try ReglGui.Destroy()
    ReglGui := ""
    SurgieFermee()
    Journal("réglages fermés" (IsObject(raison) || raison = "" ? "" : " (" raison ")"))
}

; Repeint la fenêtre ; « refaire » : lignes et mise en page recalculées (un
; réglage a changé) ; sinon seulement le survol ou le défilement
PeindreReglages(refaire := true, placer := false) {
    g := ReglGeo
    if (!IsObject(g) || !ReglHwnd)
        return
    if (refaire || !IsObject(g.mp))
        g.mp := MiseEnPageReglages(g.cat, g.kp, g.hauteur)
    g.defil := Max(0, Min(g.defil, g.mp.defilMax))
    w := Round(g.mp.w * g.kp), h := Round(g.mp.h * g.kp)
    if (placer || w != g.w || h != g.h) {
        ReglPlacer(w, h, &x, &y)
        g.x := x, g.y := y, g.w := w, g.h := h, g.px := x, g.py := y
    } else
        ReglPosReelle()                           ; (elle a pu être déplacée à la souris)
    PeindreCalque(ReglHwnd, g.x, g.y, g.w, g.h, (gr) => DessinerReglages(gr, g.w, g.h, g.kp, g.mp, g))
}

; Là où on l'a laissée la dernière fois (déplacée à la souris : reglages_pos de
; reglages.ini), ramenée dans son écran s'il a changé ; sinon à côté du widget
ReglPlacer(w, h, &x, &y) {
    if RegExMatch(IniRead(F_REGLAGES, "widget", "reglages_pos", ""), "^(-?\d+),(-?\d+)$", &o) {
        e := EcranProche(Integer(o[1]) + w // 2, Integer(o[2]) + h // 2)
        x := Max(e.l, Min(Integer(o[1]), e.r - w)), y := Max(e.t, Min(Integer(o[2]), e.b - h))
        return
    }
    PlacerSurgie(w, h, &x, &y)
}

; Position réelle de la fenêtre (Windows la déplace quand on la fait glisser) :
; le dessin et les clics la suivent
ReglPosReelle() {
    rc := Buffer(16, 0)
    if (ReglHwnd && IsObject(ReglGeo) && DllCall("GetWindowRect", "Ptr", ReglHwnd, "Ptr", rc))
        ReglGeo.x := NumGet(rc, 0, "Int"), ReglGeo.y := NumGet(rc, 4, "Int")
}

; Un réglage ou une ligne d'état a changé : la fenêtre, si elle est ouverte,
; est repeinte (par minuteur : plusieurs changements d'affilée, un seul dessin)
ReglAJour() {
    if ReglHwnd
        SetTimer(PeindreReglages, -30)
}

; Une commande lancée depuis la fenêtre (ou un de ses menus) : hors du
; gestionnaire de clic, boîtes de dialogue devant la fenêtre et modales, et
; pas de fermeture pendant qu'elles sont ouvertes (on peut aller lire
; ailleurs) ; puis la fenêtre repeinte : état, lignes qui en dépendent
EnDialogue(fn, *) {
    global SurgieDialogue
    if IsObject(ReglGui)                          ; (+OwnDialogs ne vaut que pour ce fil)
        ReglGui.Opt("+OwnDialogs")
    else if IsObject(JoursGui)
        JoursGui.Opt("+OwnDialogs")
    SurgieDialogue += 1
    try fn()
    finally SurgieDialogue -= 1
    if ReglHwnd {
        SetTimer(PeindreReglages, 0)              ; (celui demandé par CocherMenus : fait tout de suite)
        PeindreReglages()
    }
}

; Un petit menu de la fenêtre (supprimer un compte à rebours, un anniversaire) :
; « source » donne [[libellé, fonction], …] ; chaque choix passe par EnDialogue
ReglMenu(source, *) {
    m := Menu()
    for e in source()
        m.Add(e[1], EnDialogue.Bind(e[2]))
    m.Show()
}

; ---------- Les lignes de chaque catégorie ----------

RSection(lib) => {t: "section", lib: lib}
RBascule(lib, val, fn, desc := "") => {t: "bascule", lib: lib, val: !!val, fn: fn, desc: desc}
RChoix(lib, opts, desc := "") => {t: "choix", lib: lib, opts: opts, desc: desc, fn: ""}
RAction(lib, fn, val := "") => {t: "action", lib: lib, fn: fn, val: val, desc: ""}
REtat(lib, fn := "") => {t: "etat", lib: lib, fn: fn}

; Les choix d'une liste [[valeur, libellé], …] ; « courts » : libellés des pastilles
ReglOpts(liste, cour, fn, courts := "") {
    opts := []
    for i, v in liste
        opts.Push({lib: IsObject(courts) ? courts[i] : v[2], sel: v[1] = cour, fn: fn.Bind(v[1])})
    opts.unique := true                           ; (auto-test : une et une seule pastille choisie)
    return opts
}

; Pastilles à choix multiples d'une liste du tableau de bord (« nom » : sa variable) ;
; « sauf » : un identifiant jamais proposé ; « place » : paris ou us (les actions)
ReglMulti(catalogue, nom, sauf := "", place := "") {
    global MarchesCryptos, MarchesIndices, MarchesActions, MarchesTaux
    opts := [], csv := %nom%
    for v in catalogue {
        paris := SubStr(v[1], -3) = ".PA"
        if (v[1] == sauf || (place = "paris" && !paris) || (place = "us" && paris))
            continue
        opts.Push({lib: v[2], sel: DansListe(csv, v[1]), fn: BasculerDansListe.Bind(nom, catalogue, v[1])})
    }
    opts.multi := true
    return opts
}

; Texte d'une ligne d'état des menus (« ↳ … », « & » doublés) ; "" s'il n'y a rien à dire
EtatTexte(lib) {
    t := StrReplace(RegExReplace(lib, "^\s*↳\s*"), "&&", "&")
    return (t = "…") ? "" : t
}

AjouterEtat(r, lib, fn := "") {
    if ((t := EtatTexte(lib)) != "")
        r.Push(REtat(t, fn))
}

; « 12 mars 1990 », ou « 12 mars » sans l'année (AAAA-MM-JJ ou MM-JJ)
DateNaissanceTexte(d) {
    t := FormatTime("2000" StrReplace(SubStr(d, -5), "-"), "d MMMM")
    return (StrLen(d) = 10) ? t " " SubStr(d, 1, 4) : t
}

CategorieReglages(id) {
    for c in REGLAGES_CATS
        if (c.id = id)
            return c
    return REGLAGES_CATS[1]
}

; Les polices de l'heure par famille, d'après POLICES_HEURE (un groupe entre
; deux séparateurs) puis POLICES_AUTRES : [{nom, polices: [{v, lib}]}]. Le nom
; est le début commun des libellés (« Bahnschrift »), les pastilles gardent la
; fin (« Étroite grasse ») ; seules les polices installées sont proposées.
GroupesPolices() {
    groupes := [], gp := ""
    for v in POLICES_HEURE {
        if (v.Length = 1) {                       ; séparateur : famille suivante
            gp := ""
            continue
        }
        if !IsObject(gp)
            groupes.Push(gp := {nom: "", polices: []})
        if (v[1] = "" || PoliceDisponible(v[1]))
            gp.polices.Push({v: v[1], lib: v[2]})
    }
    groupes.Push(gp := {nom: "Autres", polices: []})
    for v in POLICES_AUTRES
        if PoliceDisponible(v[1])
            gp.polices.Push({v: v[1], lib: v[2]})
    res := []
    for gp in groupes {
        if !gp.polices.Length
            continue
        if (gp.nom = "" && gp.polices.Length > 1) {
            pre := PrefixeMots(gp.polices)
            if (pre = "")
                gp.nom := "Manuscrites"
            else {
                gp.nom := pre
                for po in gp.polices
                    po.lib := (StrLen(po.lib) > StrLen(pre)) ? Majuscule(Trim(SubStr(po.lib, StrLen(pre) + 1))) : "Normale"
            }
        }
        res.Push(gp)
    }
    return res
}

; Les premiers mots communs à tous les libellés (mots entiers)
PrefixeMots(polices) {
    pre := ""
    for mot in StrSplit(polices[1].lib, " ") {
        essai := (pre = "") ? mot : pre " " mot
        for po in polices
            if !(po.lib == essai || SubStr(po.lib, 1, StrLen(essai) + 1) == essai " ")
                return pre
        pre := essai
    }
    return pre
}

; Les lignes de la catégorie « cat », selon l'état du moment (les options qui
; n'ont de sens qu'avec une autre n'apparaissent qu'avec elle)
ReglagesLignes(cat) {
    r := []
    switch cat {
        case "apparence":
            r.Push(RSection("Style"),
                RChoix("", ReglOpts(STYLES, Style, ChoisirStyle, ["Android", "iPhone", "Épuré", "En toutes lettres", "Analogique"])))
            if (Style = "lettres")
                r.Push(RChoix("Précision de l'heure", ReglOpts(PRECISIONS, LettresPrecision, ChoisirPrecision, ["À la minute", "Aux 5 minutes", "Aux 5 minutes, avec points"])),
                    RBascule("Préciser le moment", LettresMoment, BasculerMoment, "« du matin », « de l'après-midi », « du soir »"))
            else if (Style = "analogique")
                r.Push(RChoix("La météo", ReglOpts(DISPOS_CADRAN, CadranMeteo, ChoisirDispoCadran, ["À côté du cadran", "Sous le cadran"])),
                    RBascule(LIB_CHIFFRES, CadranChiffres, BasculerChiffres))
            fonds := []
            for v in OPACITES
                fonds.Push({lib: v ? v " %" : "Aucun", sel: v = Opacite, fn: ChoisirFond.Bind(v)})
            fonds.unique := true
            r.Push(RSection("Couleurs"),
                RChoix("Texte", ReglOpts(COULEURS, Couleur, ChoisirCouleur, ["Blanc", "Sombre", "Automatique", "Couleurs du fond", "Selon le soleil"]),
                    Map("auto", "Blanc ou sombre selon la clarté du fond d'écran", "fond", "Les couleurs de ton fond d'écran",
                        "soleil", "Sombre le jour, blanc la nuit").Get(Couleur, "")),
                RChoix("Arrière-plan", fonds, "Un fond sombre derrière le widget, pour les fonds d'écran chargés"))
            r.Push(RSection("Effets"),
                RBascule("Effet profondeur", Profondeur, BasculerProfondeur, "L'heure passe derrière le sujet de ton fond d'écran"))
            if Profondeur
                AjouterEtat(r, EtatProf, (ActionProf != "") ? ClicEtatProfondeur : "")
            r.Push(RBascule("Voile sous les infos du bas", VoileBande, BasculerVoileBande, "Un fond sombre léger derrière le Bitcoin, la une et la phrase, pour les fonds d'écran chargés"),
                RBascule("Fond d'écran selon la météo et l'heure", AmbianceActive, BasculerAmbiance, "Des variantes de ta photo : nuit, crépuscule, pluie, neige…"),
                RBascule("Animations légères", Animations, BasculerAnimations, "L'illustration bouge, un peu plus de batterie"))

        case "heure":
            r.Push(RSection("Rendu"),
                RChoix("", ReglOpts(RENDUS, RenduHeure, ChoisirRendu, ["Plein", "Contour", "Dégradé", "Verre dépoli"]),
                    Map("contour", "Chiffres évidés", "verre", "Le fond d'écran flouté dans les chiffres").Get(RenduHeure, "")))
            r.Push(RSection("Police"))
            for gp in GroupesPolices() {
                opts := []
                for po in gp.polices
                    opts.Push({lib: po.lib, sel: po.v = PoliceHeure, fn: ChoisirPolice.Bind(po.v), police: (po.v = "") ? P_GROS[Style] : po.v})
                r.Push(RChoix(gp.nom, opts))
            }
            if (PoliceHeure != "")
                r.Push(RBascule(LIB_POLICE_TEMP, PoliceTemp, BasculerPoliceTemp))

        case "meteo":
            r.Push(RSection("Sous le résumé"),
                RBascule(LIB_HEURES, Heures, BasculerHeures, "Une rangée sous le résumé"),
                RBascule(LIB_SOLEIL, Soleil, BasculerSoleil),
                RBascule(LIB_DUREE, DureeJour, BasculerDureeJour),
                RBascule("Pluie dans l'heure", PluieW, BasculerPluieW, "« Pluie dans 20 min », seulement quand une averse arrive"))
            r.Push(RSection(LIB_CLIMAT),
                RBascule("Dans les prévisions détaillées", ClimatPrev, BasculerClimat.Bind("prev")),
                RBascule("Normale à côté du maximum", ClimatWidget, BasculerClimat.Bind("widget"), "Quand l'écart est de 3° ou plus"),
                RBascule(LIB_CLIMAT_RECORD, ClimatRecord, BasculerClimat.Bind("record")))
            v2 := Ville2Definie()
            r.Push(RSection(LIB_VILLE2),
                RAction(v2 ? "Changer de ville…" : LIB_V2_CHOISIR, ChoisirVille2, v2 ? StrReplace(SubStr(LibelleVille2(), 9), "&&", "&") : "aucune"),
                RBascule(LIB_V2_WIDGET, v2 && Ville2W, BasculerVille2.Bind("widget")),
                RBascule(LIB_V2_PREV, v2 && Ville2Prev, BasculerVille2.Bind("prev")))
            if v2
                r.Push(RAction(LIB_V2_OUBLIER, OublierVille2))

        case "calendrier":
            r.Push(RSection("Événements affichés"),
                RBascule(LIB_SEMAINE, CalSemaine, BasculerCal.Bind("semaine")),
                RBascule(LIB_FERIES, CalFeries, BasculerCal.Bind("feries")),
                RBascule(LIB_VACANCES, CalVacances, BasculerCal.Bind("vacances")))
            if CalVacances {                      ; (en description : les académies de la zone choisie)
                acad := ""
                for v in ZONES
                    if (v[1] = CalZone && RegExMatch(v[2], "\((.*)\)", &o))
                        acad := o[1]
                r.Push(RChoix("Zone", ReglOpts(ZONES, CalZone, ChoisirZone, ["Zone A", "Zone B", "Zone C"]), acad))
            }
            r.Push(RBascule(LIB_CAL_HEURE, CalHeure, BasculerCal.Bind("heure")),
                RBascule(LIB_CAL_SAISONS, CalSaisons, BasculerCal.Bind("saisons")),
                RBascule(LIB_CAL_PREV, CalPrevisions, BasculerCal.Bind("previsions")))
            r.Push(RSection(LIB_COMPTES),
                RBascule("Afficher les comptes à rebours", CalComptes, BasculerCal.Bind("comptes")),
                RAction(LIB_AJOUT, AjouterCompte))
            if (n := ComptesListe.Length)
                r.Push(RAction("Supprimer un compte à rebours…", ReglMenu.Bind(ComptesSuppr), n " en cours"))
            r.Push(RSection("Mes jours"),
                RAction("Ouvrir Mes jours…", OuvrirJours, "travail, congés, cycles"),
                RChoix(LIB_JOURS_MARQUE, ReglOpts(JOURS_MARQUES, JoursMarque, ChoisirMarque, ["Le jour en couleur", "Soulignée", "Surlignée", "Sans marque"])))
            r.Push(RSection(LIB_ANNIV),
                RAction(LIB_ANNIV_AJOUT, AjouterAnniv),
                RAction(LIB_ANNIV_MOI, MonAnniv, (AnnivMoi != "") ? DateNaissanceTexte(AnnivMoi) : ""))
            if AnnivExistent()
                r.Push(RAction("Supprimer un anniversaire…", ReglMenu.Bind(AnnivSuppr)))
            r.Push(RBascule(LIB_CONFETTIS, AnnivConfettis, BasculerConfettis),
                RAction(LIB_CONFETTIS_VOIR, FeteLancer.Bind(false)))

        case "alertes":
            r.Push(RSection("Vigilance Météo-France"), RBascule(LIB_VIG, VigilanceW, BasculerVigilance))
            if VigilanceW {
                r.Push(RChoix("Afficher", [{lib: "Dès le jaune", sel: VigMin = 2, fn: ChoisirVigMin.Bind(2)},
                    {lib: "Orange et rouge seulement", sel: VigMin = 3, fn: ChoisirVigMin.Bind(3)}]))
                AjouterEtat(r, LibEtatVig)
            }
            r.Push(RAction("Carte de vigilance Météo-France", OuvrirCarteVigilance),
                RAction("Source des alertes", OuvrirMeteoAlarm, "MeteoAlarm"))
            r.Push(RSection("Seine et UV"),
                RBascule("Seine haute (" SeineLieu ")", SeineW, BasculerSeine),
                RBascule("UV fort", UvW, BasculerUV, "Une pastille les jours d'indice 6 et plus"))
            r.Push(RSection(LIB_AIR),
                RChoix("Pastille", ReglOpts(AIR_MODES, AirMode, ChoisirAirMode, ["Épisodes seulement", "Dès « Mauvais »", "Dès « Dégradé »", "Désactivée"])),
                RBascule("Sable du Sahara", AirSable, BasculerAirOption.Bind("sable"), "Modèle CAMS"),
                RBascule("Pollens", AirPollens, BasculerAirOption.Bind("pollens"), "Indice officiel Atmo France"))
            if AirActif()
                AjouterEtat(r, LibEtatAir)
            r.Push(RAction("Carte d'Airparif", OuvrirCarteAirparif))

        case "ciel":
            r.Push(RSection("Lune"),
                RBascule(LIB_LUNE, LuneReelle, BasculerLune),
                RBascule(LIB_LUNE_LEVER, LuneLever, BasculerLuneLever))
            r.Push(RSection("Station spatiale"), RBascule(LIB_ISS, IssW, BasculerIss))
            if IssW
                r.Push(RChoix("Hauteur minimale", ReglOpts(ISS_HMINS, IssHmin, ChoisirIssHmin, ["Tous (10° et plus)", "20° et plus", "Les beaux (40° et plus)"])))
            r.Push(RSection("Ce soir"),
                RBascule("Planètes visibles", CielPlanetes, BasculerCiel.Bind("planetes"), "Dans les prévisions détaillées"),
                RBascule("Étoiles filantes", CielEtoiles, BasculerCiel.Bind("etoiles"), "Les grandes nuits, dans le calendrier"))

        case "ecran":
            r.Push(RSection(LIB_NUIT),
                RChoix("", ReglOpts(NUIT_MODES, NuitMode, ChoisirNuit, ["Désactivé", "Du coucher au lever du soleil", "Plage horaire"])))
            if (NuitMode = "soleil")
                r.Push(RChoix("Commencer", ReglOpts(NUIT_DECALAGES, NuitDecalage, ChoisirNuitDecalage, ["Au coucher", "30 min après", "1 h après", "2 h après"])))
            else if (NuitMode = "plage")
                r.Push(RAction("Plage horaire…", ChoisirPlageNuit, NuitPlage))
            if (NuitMode != "0") {
                it := []
                for v in NUIT_INTENSITES
                    it.Push({lib: v " %", sel: v = NuitIntensite, fn: ChoisirNuitIntensite.Bind(v)})
                it.unique := true
                r.Push(RChoix(LIB_NUIT_INTENSITE, it),
                    RChoix(LIB_NUIT_TEINTE, ReglOpts(NUIT_TEINTES, NuitTeinte, ChoisirNuitTeinte, ["Habituelle", "Rouge sombre", "Ambre"])),
                    RBascule("Pleine intensité au survol", NuitSurvol, BasculerNuitSurvol, "Pendant 10 secondes"))
                AjouterEtat(r, LibEtatNuit)
            }
            r.Push(RAction(LIB_NUIT_ESSAI, EssayerNuit))
            r.Push(RSection("Anti-marquage OLED"), RChoix("Micro-décalage", ReglOpts(OLED_MODES, Oled, ChoisirOled)))
            r.Push(RSection(LIB_SOBRE), RBascule(LIB_SOBRE_ON, Sobre, BasculerSobre.Bind("actif"), "Moins de redessins, pour la batterie"))
            if Sobre {
                cases := Map("pause", SobrePause, "anim", SobreAnim, "meteo", SobreMeteo, "ambiance", SobreAmbiance)
                for v in SOBRE_CASES
                    r.Push(RBascule(v[2], cases[v[1]], BasculerSobre.Bind(v[1])))
                AjouterEtat(r, LibEtatSobre)
            }

        case "marches":
            r.Push(RSection("Sur le widget"),
                RBascule("Bitcoin", MarchesBtcW, BasculerMarchesBtc, "Courbe des dernières 24 h, prix et variation : vert si ça monte, rouge si ça baisse"),
                RBascule("Un indice boursier", MarchesIndiceW, BasculerMarchesIndiceW))
            if MarchesIndiceW
                r.Push(RChoix("Indice", ReglOpts(MARCHES_INDICES, MarchesIndice, ChoisirMarchesIndice)))
            r.Push(RSection("Tableau de bord"), RAction("Ouvrir Actus et marchés…", OuvrirMarches, "ou un clic sur le Bitcoin"))
            r.Push(RSection("Alertes (notifications Windows)"),
                RChoix("Bitcoin : variation sur 24 h", ReglOpts([[0, "Désactivée"], [3, "3 %"], [5, "5 %"], [10, "10 %"]], AlerteBtc, ChoisirAlerteBtc)),
                RAction("Seuils de prix du Bitcoin…", ChoisirSeuilsBtc, TexteSeuils()),
                RChoix("Indices et actions suivis : variation du jour", ReglOpts([[0, "Désactivée"], [2, "2 %"], [3, "3 %"], [5, "5 %"]], AlerteActions, ChoisirAlerteActions),
                    "Une fois par jour et par sens, un clic sur la notification ouvre le tableau de bord"))
            r.Push(RSection("Cryptos"), RChoix("", ReglMulti(MARCHES_CRYPTOS, "MarchesCryptos", "bitcoin"), "Le Bitcoin est toujours suivi"))
            r.Push(RSection("Indices"), RChoix("", ReglMulti(MARCHES_INDICES, "MarchesIndices")))
            r.Push(RSection("Actions"), RChoix("Paris", ReglMulti(MARCHES_ACTIONS, "MarchesActions", "", "paris")),
                RChoix("New York", ReglMulti(MARCHES_ACTIONS, "MarchesActions", "", "us")))
            r.Push(RSection("Taux des emprunts d'État"), RChoix("", ReglMulti(MARCHES_TAUX, "MarchesTaux"),
                "États-Unis : en direct. Zone euro : chaque jour. France, Allemagne, Italie : moyenne du mois (BCE)"))

        case "actus":
            r.Push(RSection("Sur le widget"), RBascule("Titre à la une", ActusW, BasculerActusW,
                "franceinfo et Le Monde en alternance, un nouveau toutes les 5 min, un clic : l'article en grand"))
            if IsObject(a := UneCourante())
                r.Push(REtat(a.titre))
            r.Push(RSection("Tableau de bord"), RAction("Ouvrir Actus et marchés…", OuvrirMarches, "à la une, en continu, international"))
            r.Push(REtat("Sources : Le Monde (à la une et international), franceinfo, France 24, mises à jour toutes les 5 min"))

        case "transports":
            r.Push(RSection("Prochains départs (Île-de-France)"), RBascule("Sur le widget", RerW, BasculerRerW,
                "Les deux prochains dans chaque sens (orange en retard, rouge supprimé), une pastille si la ligne est perturbée"),
                RAction("Gare ou arrêt…", ChoisirArret, (RerArret != "") ? RerNom " · " RerGare : "à choisir"),
                RAction("Noms des deux sens…", NommerSens, TexteSens()),
                RAction("Jeton Île-de-France Mobilités…", SaisirCleIdfm, RerCle() ? "enregistré" : "à saisir"), REtat(EtatRer()))
            r.Push(RSection("Le jeton"), RAction("Créer un compte ou un jeton…", (*) => Run("https://prim.iledefrance-mobilites.fr"), "prim.iledefrance-mobilites.fr"),
                REtat("Gratuit : un compte, puis Mes jetons d'authentification ▸ API ▸ Générer mon jeton. Quota : 1 000 requêtes par jour, le widget en utilise environ 600"))

        case "anglais":
            r.Push(RSection("Sur le widget"), RBascule("Phrase français → anglais", AnglaisW, BasculerAnglaisW,
                "Une nouvelle toutes les 5 min, un clic dessus : la suivante"))
            if IsObject(p := PhraseCourante())
                r.Push(REtat(p.fr " → " p.en), RAction("Phrase suivante", PhraseSuivante))
            r.Push(RSection("Source des phrases"), RChoix("", ReglOpts([["mix", "Mélange"], ["liste", "Liste intégrée"], ["tatoeba", "Tatoeba"]],
                AnglaisSource, ChoisirAnglaisSource), Map("mix", "Une phrase sur deux de chaque", "liste", PhrasesListe.Length " phrases de tous niveaux, sans Internet",
                "tatoeba", "Un nouveau lot de phrases réelles chaque jour").Get(AnglaisSource, "")))
            r.Push(REtat("Phrases Tatoeba : tatoeba.org, licence CC BY 2.0 FR"))

        case "position":
            ta := []
            for v in TAILLES
                ta.Push({lib: v " %", sel: v = Taille, fn: ChoisirTaille.Bind(v)})
            aj := [{lib: "Réduire de 10 %", sel: false, fn: ChangerTaille.Bind(-10)}, {lib: "Agrandir de 10 %", sel: false, fn: ChangerTaille.Bind(10)}]
            if (LargeurPct != 100)
                aj.Push({lib: LIB_LARGEUR0, sel: false, fn: LargeurOrigine})
            r.Push(RSection("Taille"),
                RChoix("Taille", ta, LibelleTaille()),
                RChoix("", aj),
                RAction(LIB_EDITION, EntrerEdition, "coins et côtés"))
            r.Push(RSection("Position"),
                RAction("Centrer horizontalement", Centrer.Bind(true, false)),
                RAction("Centrer au milieu de l'écran", Centrer.Bind(true, true)),
                RAction("Remettre en haut à droite", Reinitialiser),
                RBascule(LIB_VERROU, Verrou, BasculerVerrou, "Un clic ouvre toujours les prévisions"),
                RBascule("Laisser passer les clics", Traversant, BasculerTraversant, "Le widget devient inerte, sauf l'illustration et la température"))
    }
    return r
}

; ---------- Mise en page (px logiques) ----------

; Largeur de « txt » en px de l'écran (mémorisée : la mise en page est refaite à chaque réglage)
LargeurMemo(txt, police, em) {
    static cache := Map()
    cle := police "|" Round(em, 3) "|" txt
    if !cache.Has(cle) {
        if (cache.Count > 4000)
            cache.Clear()
        cache[cle] := LargeurTexte(txt, police, em)
    }
    return cache[cle]
}

; « txt » en lignes de « largeur » px logiques au plus (capitale « cap ») ; au-delà
; de « maxl » lignes, la dernière est tronquée
ReglCouper(txt, police, cap, kp, largeur, maxl := 2) {
    em := EmPourCapitale(police, cap * kp), lim := largeur * kp
    if (LargeurMemo(txt, police, em) <= lim)
        return [txt]
    lignes := [], cour := ""
    for mot in StrSplit(txt, " ") {
        essai := (cour = "") ? mot : cour " " mot
        if (cour = "" || LargeurMemo(essai, police, em) <= lim)
            cour := essai
        else
            lignes.Push(cour), cour := mot
    }
    lignes.Push(cour)
    if (lignes.Length > maxl) {
        reste := lignes[maxl]
        Loop lignes.Length - maxl
            reste .= " " lignes[maxl + A_Index]
        lignes.Length := maxl
        lignes[maxl] := reste
    }
    for i, t in lignes
        if (LargeurMemo(t, police, em) > lim)
            lignes[i] := Tronquer(t, police, em, lim)
    return lignes
}

; {w, h, sb, cx, cw, y0, cats[], lignes[], cartes[], zones[], contenuH, defilMax}.
; Les lignes et les zones du contenu ont leur « y » dans la partie qui défile
; (0 = son haut, à y0 dans la fenêtre) ; les zones « fixe » sont en place.
MiseEnPageReglages(cat, kp, hauteur) {
    mp := {w: REGL_W, h: hauteur, sb: REGL_SB, cx: REGL_SB + 20, y0: 70, cats: [], lignes: [], cartes: [], zones: []}
    mp.cw := mp.w - mp.cx - 26
    y := 88, pas := Max(30, Min(38, Floor((hauteur - 88 - 40) / REGLAGES_CATS.Length)))
    for c in REGLAGES_CATS {
        z := {x: 10, y: y, w: mp.sb - 20, h: pas - 2, type: "cat", id: "cat:" c.id, cat: c.id, fixe: true}
        mp.cats.Push({c: c, z: z}), mp.zones.Push(z)
        y += pas
    }
    mp.zfermer := {x: mp.w - 54, y: 18, w: 36, h: 36, type: "fermer", id: "fermer", fixe: true}
    mp.zones.Push(mp.zfermer)
    cw := mp.cw, y := 0, carte := ""
    for i, li in ReglagesLignes(cat) {
        li.id := "l" i
        mp.lignes.Push(li)
        if (li.t = "section") {
            carte := ""
            li.y := y + ((i > 1) ? 14 : 0), li.h := 28
            y := li.y + li.h
            continue
        }
        li.y := y, li.premier := !IsObject(carte)
        if !IsObject(carte)
            mp.cartes.Push(carte := {y: y, h: 0})
        ; libellé (et description) : lignes de base depuis le haut de la ligne
        largeur := cw - 28 - ((li.t = "bascule") ? 52 : 0)
        if (li.t = "action") {
            li.valT := "", lv := 0
            if (li.val != "") {
                em := EmPourCapitale(P_TEXTE, 9.5 * kp)
                li.valT := Tronquer(li.val, P_TEXTE, em, 190 * kp)
                lv := LargeurMemo(li.valT, P_TEXTE, em) / kp + 10
            }
            largeur -= 18 + lv
        }
        if (li.t = "etat") {
            li.labT := ReglCouper(li.lib, P_TEXTE, 9, kp, largeur - (IsObject(li.fn) ? 18 : 0), 3)
            li.ybLab := [], li.descT := [], li.ybDesc := []
            Loop li.labT.Length
                li.ybLab.Push(22 + 15 * (A_Index - 1))
            li.h := li.ybLab[li.ybLab.Length] + 12
            if IsObject(li.fn)
                mp.zones.Push({x: mp.cx, y: y, w: cw, h: li.h, type: "fn", fn: li.fn, id: li.id, fixe: false})
        } else {
            li.labT := (li.lib != "") ? ReglCouper(li.lib, P_TEXTE, 10.5, kp, largeur, (li.t = "choix") ? 1 : 2) : []
            li.descT := (li.desc != "") ? ReglCouper(li.desc, P_TEXTE, 8.5, kp, largeur) : []
            li.ybLab := [], li.ybDesc := [], bas := 0
            Loop li.labT.Length
                li.ybLab.Push(bas := 26 + 18 * (A_Index - 1))
            Loop li.descT.Length
                li.ybDesc.Push(bas := bas ? bas + 16 : 22)
            if (li.t = "choix") {                 ; pastilles, à la ligne quand elles ne tiennent plus
                xx := 14, yy := bas ? bas + 12 : 12
                for j, o in li.opts {
                    pol := o.HasOwnProp("police") ? o.police : P_TEXTE
                    em := EmPourCapitale(pol, 9.5 * kp)
                    o.libT := Tronquer(o.lib, pol, em, (cw - 28 - 26) * kp)
                    o.w := LargeurMemo(o.libT, pol, em) / kp + 26
                    if (xx + o.w > cw - 14 && xx > 14)
                        xx := 14, yy += 36
                    o.x := xx, o.y := yy, o.id := li.id "." j
                    if (!o.sel || li.opts.HasOwnProp("multi"))   ; (déjà choisie : rien à faire, sauf choix multiple)
                        mp.zones.Push({x: mp.cx + xx, y: y + yy, w: o.w, h: 28, type: "fn", fn: o.fn, id: o.id, fixe: false})
                    xx += o.w + 8
                }
                li.h := yy + 28 + 12
            } else {
                li.h := bas + 16
                mp.zones.Push({x: mp.cx, y: y, w: cw, h: li.h, type: "fn", fn: li.fn, id: li.id, fixe: false})
            }
        }
        y += li.h
        carte.h := y - carte.y
    }
    mp.contenuH := y + 16
    mp.defilMax := Max(0, mp.contenuH - (hauteur - mp.y0 - 10))
    return mp
}

; ---------- Dessin ----------

DessinerReglages(gr, w, h, kp, mp, g) {
    global TeinteRendu
    ancienne := TeinteRendu
    TeinteRendu := NuitTeinteActive()             ; comme les prévisions : la teinte de nuit, pas l'atténuation
    try DessinerReglagesScene(gr, w, h, kp, mp, g)
    finally TeinteRendu := ancienne
}

DessinerReglagesScene(gr, w, h, kp, mp, g) {
    static SURFACE := 0xF21A1A19, ENCRE := 0xFFFFFFFF, SECOND := 0xFFC3C2B7, DISCRET := 0xFF898781
    static GRILLE := 0xFF2C2C2A, CHOISI := 0xFF3A3A37, BLEU := 0xFF3987E5, LIEN := 0xFF78AEF2, BARRE := 0x30000000
    static CARTE := 0xFF242423, TRAIT := 0xFF363633, SURVOL := 0xFF2F2F2C, PISTE := 0xFF4A4A46, BOUTON := 0xFFE9E9E6
    static PUCE := 0xFF34342F, PUCE_SURVOL := 0xFF45453F
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gr, "Int", 2)
    RectArrondi(gr, 0, 0, w, h, 22 * kp, SURFACE)
    F := [], C := []                              ; formes fixes ; formes du contenu (qui défile, découpé)

    ; ---- barre latérale : titre, version, catégories
    F.Push({p: CheminGauche(0, 0, mp.sb * kp, h, 22 * kp), f: BARRE})
    Poser(F, "Réglages", P_DATE, EmPourCapitale(P_DATE, 15 * kp), 22 * kp, 46 * kp, 0, ENCRE)
    Poser(F, "Widget météo " VERSION, P_TEXTE, EmPourCapitale(P_TEXTE, 8.5 * kp), 22 * kp, 64 * kp, 0, DISCRET)
    for it in mp.cats {
        z := it.z, estCat := (it.c.id = g.cat)   ; (jamais « choisi » : même variable que CHOISI, la casse est ignorée)
        if (estCat || g.survol = z.id)
            F.Push({p: CheminArrondi(z.x * kp, z.y * kp, z.w * kp, z.h * kp, 10 * kp), f: estCat ? CHOISI : GRILLE})
        ic := Min(26, z.h - 8) * kp, ix := (z.x + 8) * kp, iy := (z.y + z.h / 2) * kp - ic / 2
        F.Push({p: CheminArrondi(ix, iy, ic, ic, 7 * kp), f: it.c.c})
        GlypheCategorie(F, it.c.id, ix + ic / 2, iy + ic / 2, ic, it.c.c)
        Poser(F, it.c.nom, P_TEXTE, EmPourCapitale(P_TEXTE, 10 * kp), (z.x + 44) * kp, (z.y + z.h / 2 + 5) * kp, 0, estCat ? ENCRE : SECOND)
    }
    Poser(F, "Maj + clic droit : menu complet", P_TEXTE, EmPourCapitale(P_TEXTE, 8 * kp), 22 * kp, h - 20 * kp, 0, DISCRET)

    ; ---- titre de la catégorie, fermer
    Poser(F, CategorieReglages(g.cat).nom, P_DATE, EmPourCapitale(P_DATE, 15 * kp), (mp.cx + 2) * kp, 46 * kp, 0, ENCRE)
    zf := mp.zfermer, fx := (zf.x + zf.w / 2) * kp, fy := (zf.y + zf.h / 2) * kp
    ReglRond(F, fx, fy, 14 * kp, (g.survol = "fermer") ? CHOISI : GRILLE)
    ReglTraits(F, [[fx - 4.5 * kp, fy - 4.5 * kp, fx + 4.5 * kp, fy + 4.5 * kp], [fx - 4.5 * kp, fy + 4.5 * kp, fx + 4.5 * kp, fy - 4.5 * kp]], 1.8 * kp, SECOND)

    ; ---- contenu : cartes, puis chaque ligne
    oy := mp.y0 - g.defil, x0 := mp.cx, x1 := mp.cx + mp.cw
    for ca in mp.cartes
        C.Push({p: CheminArrondi(x0 * kp, (oy + ca.y) * kp, mp.cw * kp, ca.h * kp, 12 * kp), f: CARTE})
    for li in mp.lignes {
        yl := oy + li.y
        if (yl + li.h < mp.y0 - 8 || yl > mp.h)   ; hors de vue
            continue
        if (li.t = "section") {
            Poser(C, StrUpper(li.lib), P_DATE, EmPourCapitale(P_DATE, 7.5 * kp), (x0 + 14) * kp, (yl + 20) * kp, 0, DISCRET)
            continue
        }
        if !li.premier                            ; filet entre deux lignes d'une carte
            ReglRect(C, (x0 + 14) * kp, yl * kp, (mp.cw - 28) * kp, Max(1, 0.6 * kp), TRAIT)
        if (li.t != "choix" && IsObject(li.fn) && g.survol = li.id)
            C.Push({p: CheminArrondi((x0 + 4) * kp, (yl + 3) * kp, (mp.cw - 8) * kp, (li.h - 6) * kp, 9 * kp), f: SURVOL})
        if (li.t = "etat") {
            for k, t in li.labT
                Poser(C, t, P_TEXTE, EmPourCapitale(P_TEXTE, 9 * kp), (x0 + 14) * kp, (yl + li.ybLab[k]) * kp, 0, IsObject(li.fn) ? LIEN : DISCRET)
            if IsObject(li.fn)
                ReglChevron(C, (x1 - 20) * kp, (yl + li.h / 2) * kp, 5 * kp, 1.8 * kp, DISCRET)
            continue
        }
        for k, t in li.labT
            Poser(C, t, P_TEXTE, EmPourCapitale(P_TEXTE, 10.5 * kp), (x0 + 14) * kp, (yl + li.ybLab[k]) * kp, 0, ENCRE)
        for k, t in li.descT
            Poser(C, t, P_TEXTE, EmPourCapitale(P_TEXTE, 8.5 * kp), (x0 + 14) * kp, (yl + li.ybDesc[k]) * kp, 0, DISCRET)
        switch li.t {
            case "bascule":                       ; interrupteur
                sx := x1 - 14 - 40, sy := yl + (li.h - 24) / 2
                C.Push({p: CheminArrondi(sx * kp, sy * kp, 40 * kp, 24 * kp, 12 * kp), f: li.val ? BLEU : PISTE})
                ReglRond(C, (li.val ? sx + 28 : sx + 12) * kp, (sy + 12) * kp, 10 * kp, li.val ? ENCRE : BOUTON)
            case "action":
                if (li.valT != "")
                    Poser(C, li.valT, P_TEXTE, EmPourCapitale(P_TEXTE, 9.5 * kp), (x1 - 30) * kp, (yl + li.h / 2 + 4.75) * kp, 2, SECOND)
                ReglChevron(C, (x1 - 20) * kp, (yl + li.h / 2) * kp, 5 * kp, 1.8 * kp, DISCRET)
            case "choix":                         ; pastilles (la choisie en bleu ; police : chacune dans la sienne)
                for o in li.opts {
                    dessous := (g.survol = o.id)   ; (jamais « survol » : même variable que SURVOL)
                    ox := x0 + o.x, oo := yl + o.y
                    C.Push({p: CheminArrondi(ox * kp, oo * kp, o.w * kp, 28 * kp, 14 * kp), f: o.sel ? BLEU : dessous ? PUCE_SURVOL : PUCE})
                    pol := o.HasOwnProp("police") ? o.police : P_TEXTE
                    Poser(C, o.libT, pol, EmPourCapitale(pol, 9.5 * kp), (ox + o.w / 2) * kp, (oo + 18.75) * kp, 1, (o.sel || dessous) ? ENCRE : SECOND)
                }
        }
    }

    for e in F
        Remplir(gr, e)
    DllCall("gdiplus\GdipSetClipRect", "Ptr", gr, "Float", mp.sb * kp, "Float", (mp.y0 - 6) * kp,
        "Float", (mp.w - mp.sb) * kp, "Float", (mp.h - mp.y0 - 4) * kp, "Int", 0)
    for e in C
        Remplir(gr, e)
    DllCall("gdiplus\GdipResetClip", "Ptr", gr)
    if (mp.defilMax > 0) {                        ; barre de défilement
        vh := mp.h - mp.y0 - 10, th := Max(36, vh * vh / mp.contenuH)
        ty := mp.y0 + (vh - th) * g.defil / mp.defilMax
        F.Push(e := {p: CheminArrondi((mp.w - 11) * kp, ty * kp, 4 * kp, th * kp, 2 * kp), f: 0x55FFFFFF})
        Remplir(gr, e)
    }
    for e in F
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
    for e in C
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
}

; Rectangle aux coins arrondis à gauche seulement (la barre latérale)
CheminGauche(x, y, w, h, r) {
    d := 2 * r
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pa := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", pa, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", pa, "Float", x + r, "Float", y, "Float", x + w, "Float", y)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", pa, "Float", x + w, "Float", y, "Float", x + w, "Float", y + h)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", pa, "Float", x + w, "Float", y + h, "Float", x + r, "Float", y + h)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", pa, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", pa)
    return pa
}

ReglRond(L, cx, cy, r, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pa := 0)
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", pa, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r)
    L.Push({p: pa, f: couleur})
}

ReglAnneau(L, cx, cy, r, ep, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pa := 0)
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", pa, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r)
    Elargir(pa, ep)
    L.Push({p: pa, f: couleur})
}

ReglRect(L, x, y, w, h, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pa := 0)
    DllCall("gdiplus\GdipAddPathRectangle", "Ptr", pa, "Float", x, "Float", y, "Float", w, "Float", h)
    L.Push({p: pa, f: couleur})
}

; Segments [[x1, y1, x2, y2], …] (px) en traits d'épaisseur « ep » à bouts ronds
ReglTraits(L, segs, ep, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &pa := 0)
    for q in segs {
        DllCall("gdiplus\GdipStartPathFigure", "Ptr", pa)
        DllCall("gdiplus\GdipAddPathLine", "Ptr", pa, "Float", q[1], "Float", q[2], "Float", q[3], "Float", q[4])
    }
    Elargir(pa, ep)
    L.Push({p: pa, f: couleur})
}

; « › » centré en (cx, cy), demi-hauteur s
ReglChevron(L, cx, cy, s, ep, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &pa := 0)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", pa, "Float", cx - s / 2, "Float", cy - s, "Float", cx + s / 2, "Float", cy)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", pa, "Float", cx + s / 2, "Float", cy, "Float", cx - s / 2, "Float", cy + s)
    Elargir(pa, ep)
    L.Push({p: pa, f: couleur})
}

ReglPolygone(L, pts, couleur) {
    buf := Buffer(8 * pts.Length)
    for q in pts
        NumPut("Float", q[1], "Float", q[2], buf, (A_Index - 1) * 8)
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &pa := 0)
    DllCall("gdiplus\GdipAddPathPolygon", "Ptr", pa, "Ptr", buf, "Int", pts.Length)
    L.Push({p: pa, f: couleur})
}

; Le pictogramme blanc d'une catégorie, dans son carré de couleur « fond » (côté u, centre cx, cy)
GlypheCategorie(L, id, cx, cy, u, fond) {
    static BLANC := 0xFFFFFFFF
    ep := 0.075 * u
    switch id {
        case "apparence":                         ; disque à moitié plein (thème)
            r := 0.29 * u
            ReglAnneau(L, cx, cy, r, ep, BLANC)
            DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pa := 0)
            DllCall("gdiplus\GdipAddPathPie", "Ptr", pa, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r, "Float", -90, "Float", 180)
            L.Push({p: pa, f: BLANC})
        case "heure":                             ; horloge
            ReglAnneau(L, cx, cy, 0.29 * u, ep, BLANC)
            ReglTraits(L, [[cx, cy, cx, cy - 0.17 * u], [cx, cy, cx + 0.12 * u, cy + 0.05 * u]], ep, BLANC)
        case "meteo":                             ; nuage
            ReglRond(L, cx - 0.12 * u, cy + 0.03 * u, 0.13 * u, BLANC)
            ReglRond(L, cx + 0.05 * u, cy - 0.04 * u, 0.18 * u, BLANC)
            L.Push({p: CheminArrondi(cx - 0.28 * u, cy + 0.01 * u, 0.57 * u, 0.16 * u, 0.08 * u), f: BLANC})
        case "calendrier":
            IconeCalendrier(L, cx, cy, 0.58 * u / 0.060, BLANC)
        case "alertes":                           ; triangle et « ! »
            pts := [[cx, cy - 0.27 * u], [cx + 0.29 * u, cy + 0.23 * u], [cx - 0.29 * u, cy + 0.23 * u]]
            ReglPolygone(L, pts, BLANC)
            DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pa := 0)   ; coins arrondis : le même contour élargi
            buf := Buffer(24)
            for q in pts
                NumPut("Float", q[1], "Float", q[2], buf, (A_Index - 1) * 8)
            DllCall("gdiplus\GdipAddPathPolygon", "Ptr", pa, "Ptr", buf, "Int", 3)
            Elargir(pa, 0.09 * u)
            L.Push({p: pa, f: BLANC})
            ReglTraits(L, [[cx, cy - 0.08 * u, cx, cy + 0.06 * u]], 0.075 * u, fond)
            ReglRond(L, cx, cy + 0.155 * u, 0.042 * u, fond)
        case "ciel":                              ; étoile à cinq branches
            pts := []
            Loop 10 {
                a := (-90 + (A_Index - 1) * 36) / 57.29578, r := (A_Index & 1) ? 0.33 * u : 0.14 * u
                pts.Push([cx + r * Cos(a), cy + 0.02 * u + r * Sin(a)])
            }
            ReglPolygone(L, pts, BLANC)
        case "ecran":                             ; batterie
            pa := CheminArrondi(cx - 0.31 * u, cy - 0.16 * u, 0.55 * u, 0.32 * u, 0.08 * u)
            Elargir(pa, 0.065 * u)
            L.Push({p: pa, f: BLANC})
            L.Push({p: CheminArrondi(cx + 0.275 * u, cy - 0.07 * u, 0.06 * u, 0.14 * u, 0.03 * u), f: BLANC})
            L.Push({p: CheminArrondi(cx - 0.235 * u, cy - 0.085 * u, 0.29 * u, 0.17 * u, 0.035 * u), f: BLANC})
        case "marches":                           ; une courbe qui monte, avec sa flèche
            pts := [[-0.27, 0.22], [-0.11, 0.0], [0.0, 0.09], [0.2, -0.16]]
            segs := []
            Loop pts.Length - 1
                segs.Push([cx + pts[A_Index][1] * u, cy + pts[A_Index][2] * u, cx + pts[A_Index + 1][1] * u, cy + pts[A_Index + 1][2] * u])
            ReglTraits(L, segs, 0.07 * u, BLANC)
            ReglPolygone(L, [[cx + 0.29 * u, cy - 0.27 * u], [cx + 0.24 * u, cy - 0.06 * u], [cx + 0.08 * u, cy - 0.22 * u]], BLANC)
        case "actus":                             ; un journal : cadre, titre et lignes
            pa := CheminArrondi(cx - 0.26 * u, cy - 0.24 * u, 0.52 * u, 0.48 * u, 0.06 * u)
            Elargir(pa, 0.06 * u)
            L.Push({p: pa, f: BLANC})
            L.Push({p: CheminArrondi(cx - 0.16 * u, cy - 0.14 * u, 0.14 * u, 0.12 * u, 0.02 * u), f: BLANC})
            ReglTraits(L, [[cx + 0.04 * u, cy - 0.11 * u, cx + 0.15 * u, cy - 0.11 * u], [cx + 0.04 * u, cy - 0.04 * u, cx + 0.15 * u, cy - 0.04 * u],
                [cx - 0.15 * u, cy + 0.05 * u, cx + 0.15 * u, cy + 0.05 * u], [cx - 0.15 * u, cy + 0.13 * u, cx + 0.15 * u, cy + 0.13 * u]], 0.045 * u, BLANC)
        case "transports":                        ; l'avant d'un train sur ses rails
            L.Push({p: CheminArrondi(cx - 0.2 * u, cy - 0.29 * u, 0.4 * u, 0.44 * u, 0.1 * u), f: BLANC})
            L.Push({p: CheminArrondi(cx - 0.13 * u, cy - 0.21 * u, 0.26 * u, 0.14 * u, 0.03 * u), f: fond})
            ReglRond(L, cx - 0.1 * u, cy + 0.06 * u, 0.035 * u, fond)
            ReglRond(L, cx + 0.1 * u, cy + 0.06 * u, 0.035 * u, fond)
            ReglTraits(L, [[cx - 0.12 * u, cy + 0.2 * u, cx - 0.2 * u, cy + 0.31 * u], [cx + 0.12 * u, cy + 0.2 * u, cx + 0.2 * u, cy + 0.31 * u]], 0.055 * u, BLANC)
        case "anglais":                           ; une bulle « EN »
            L.Push({p: CheminArrondi(cx - 0.3 * u, cy - 0.24 * u, 0.6 * u, 0.4 * u, 0.1 * u), f: BLANC})
            ReglPolygone(L, [[cx - 0.14 * u, cy + 0.14 * u], [cx - 0.18 * u, cy + 0.3 * u], [cx - 0.0 * u, cy + 0.14 * u]], BLANC)
            Poser(L, "EN", P_DATE, EmPourCapitale(P_DATE, 0.2 * u), cx, cy + 0.06 * u, 1, fond)
        case "position":                          ; flèches dans les quatre sens
            d := 0.22 * u, t := 0.33 * u, b := 0.10 * u
            ReglTraits(L, [[cx - d, cy, cx + d, cy], [cx, cy - d, cx, cy + d]], 0.065 * u, BLANC)
            ReglPolygone(L, [[cx, cy - t], [cx + b, cy - t + 1.2 * b], [cx - b, cy - t + 1.2 * b]], BLANC)
            ReglPolygone(L, [[cx, cy + t], [cx + b, cy + t - 1.2 * b], [cx - b, cy + t - 1.2 * b]], BLANC)
            ReglPolygone(L, [[cx - t, cy], [cx - t + 1.2 * b, cy - b], [cx - t + 1.2 * b, cy + b]], BLANC)
            ReglPolygone(L, [[cx + t, cy], [cx + t - 1.2 * b, cy - b], [cx + t - 1.2 * b, cy + b]], BLANC)
    }
}

; ---------- Souris et clavier ----------

ReglMessages() {
    OnMessage(0x201, ReglAppui)                   ; WM_LBUTTONDOWN
    OnMessage(0x203, ReglAppui)                   ; WM_LBUTTONDBLCLK : 2e clic rapide, traité comme un clic
    OnMessage(0x200, ReglDeplace)                 ; WM_MOUSEMOVE : survol
    OnMessage(0x2A3, ReglSortie)                  ; WM_MOUSELEAVE
    OnMessage(0x20, ReglCurseur)                  ; WM_SETCURSOR : une main sur ce qui se clique
    OnMessage(0x20A, ReglMolette)                 ; WM_MOUSEWHEEL : défilement
    OnMessage(0x100, ReglTouche)                  ; WM_KEYDOWN
}

; La zone sous le curseur (voir MiseEnPageReglages), ou ""
ReglSous() {
    g := ReglGeo
    if !(IsObject(g) && IsObject(g.mp))
        return ""
    ReglPosReelle()
    if IsObject(ReglCurseurTest)                  ; (/testfenetre)
        cx := ReglCurseurTest[1], cy := ReglCurseurTest[2]
    else
        Curseur(&cx, &cy)
    lx := (cx - g.x) / g.kp, ly := (cy - g.y) / g.kp, mp := g.mp
    for z in mp.zones {
        zy := z.y
        if !z.fixe {                              ; contenu : décalé du défilement, et seulement dans sa partie visible
            if (ly < mp.y0 - 6 || ly >= mp.h - 10)
                continue
            zy += mp.y0 - g.defil
        }
        if (lx >= z.x && lx < z.x + z.w && ly >= zy && ly < zy + z.h)
            return z
    }
    return ""
}

ReglAppui(wParam, lParam, msg, hwnd) {
    global ReglCat
    if (!ReglHwnd || hwnd != ReglHwnd)
        return
    z := ReglSous()
    if !IsObject(z) {                             ; ailleurs que sur un réglage (titres, vides) : la
        DllCall("PostMessage", "Ptr", ReglHwnd, "UInt", 0xA1, "Ptr", 2, "Ptr", 0)   ; fenêtre suit la souris
        return 0                                  ; (WM_NCLBUTTONDOWN sur HTCAPTION : Windows la déplace)
    }
    switch z.type {
        case "cat":
            if (z.cat != ReglGeo.cat) {
                ReglGeo.cat := ReglCat := z.cat, ReglGeo.defil := 0
                PeindreReglages()
            }
        case "fermer": SetTimer(FermerReglages.Bind("croix"), -1)
        case "fn":     SetTimer(EnDialogue.Bind(z.fn), -1)   ; (hors du gestionnaire : elle peut ouvrir une boîte de dialogue)
    }
    return 0
}

ReglDeplace(wParam, lParam, msg, hwnd) {
    if (!ReglHwnd || hwnd != ReglHwnd)
        return
    g := ReglGeo
    if !g.suivi {                                 ; WM_MOUSELEAVE demandé à chaque entrée
        tme := Buffer(24, 0)
        NumPut("UInt", 24, "UInt", 2, tme)        ; cbSize, TME_LEAVE
        NumPut("Ptr", ReglHwnd, tme, 8)
        g.suivi := DllCall("TrackMouseEvent", "Ptr", tme)
    }
    ReglSurvol()
    return 0
}

ReglSortie(wParam, lParam, msg, hwnd) {
    if (!ReglHwnd || hwnd != ReglHwnd)
        return
    ReglGeo.suivi := false
    if (ReglGeo.survol != "") {
        ReglGeo.survol := ""
        PeindreReglages(false)
    }
    return 0
}

; Le survol suit le curseur (repeint seulement quand il change d'élément)
ReglSurvol() {
    z := ReglSous()
    id := IsObject(z) ? z.id : ""
    if (id != ReglGeo.survol) {
        ReglGeo.survol := id
        PeindreReglages(false)
    }
}

ReglCurseur(wParam, lParam, msg, hwnd) {
    if (!ReglHwnd || hwnd != ReglHwnd || (lParam & 0xFFFF) != 1)   ; (zone cliente seulement)
        return
    if !IsObject(ReglSous())
        return
    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))   ; IDC_HAND
    return 1
}

ReglMolette(wParam, lParam, msg, hwnd) {
    if (!ReglHwnd || hwnd != ReglHwnd)
        return
    d := (wParam >> 16) & 0xFFFF
    ReglDefiler(-((d >= 0x8000) ? d - 0x10000 : d) / 2)   ; 60 px par cran (le pavé tactile : au prorata)
    return 0
}

ReglDefiler(dy) {
    g := ReglGeo
    if !(IsObject(g) && IsObject(g.mp))
        return
    avant := g.defil
    g.defil := Max(0, Min(g.mp.defilMax, g.defil + dy))
    if (g.defil != avant)                         ; dessin par minuteur : les crans d'un geste du pavé
        SetTimer(ReglApresDefil, -10)             ; tactile arrivés pendant un dessin n'en font qu'un
}

ReglApresDefil() {
    if !(IsObject(ReglGeo) && ReglHwnd)
        return
    z := ReglSous()                               ; (ce qui est sous le curseur a changé)
    ReglGeo.survol := IsObject(z) ? z.id : ""
    PeindreReglages(false)
}

ReglCategorie(sens) {
    global ReglCat
    g := ReglGeo
    for i, c in REGLAGES_CATS
        if (c.id = g.cat) {
            n := Mod(i - 1 + sens + REGLAGES_CATS.Length, REGLAGES_CATS.Length) + 1
            g.cat := ReglCat := REGLAGES_CATS[n].id, g.defil := 0
            PeindreReglages()
            return
        }
}

ReglTouche(wParam, lParam, msg, hwnd) {
    if (!ReglHwnd || hwnd != ReglHwnd)
        return
    page := ReglGeo.mp.h - ReglGeo.mp.y0 - 50
    switch wParam {
        case 0x1B: SetTimer(FermerReglages.Bind("Échap"), -1)
        case 0x26: ReglCategorie(-1)              ; haut : catégorie précédente
        case 0x28: ReglCategorie(1)               ; bas : suivante
        case 0x21: ReglDefiler(-page)             ; page précédente
        case 0x22: ReglDefiler(page)              ; page suivante
        case 0x24: ReglDefiler(-100000)           ; début
        case 0x23: ReglDefiler(100000)            ; fin
        default: return
    }
    return 0
}

; ---------- Tests ----------

; La fenêtre sur un fond gris : catégorie « cat », défilée de « defil » px logiques ;
; defil = « plein » : toute la catégorie, fenêtre allongée pour tout montrer
ApercuReglages(fichier, cat := "apparence", defil := 0) {
    ConstruireMenus()                             ; (les lignes d'état viennent des menus)
    kp := A_ScreenDPI / 96
    mp := MiseEnPageReglages(cat, kp, REGL_H)
    if (defil = "plein")
        mp := MiseEnPageReglages(cat, kp, Max(REGL_H, mp.y0 + 10 + mp.contenuH)), defil := 0
    g := {cat: cat, defil: Max(0, Min(Integer(defil), mp.defilMax)), survol: ""}
    w := Round(mp.w * kp), h := Round(mp.h * kp), m := Round(16 * kp)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w + 2 * m, "Int", h + 2 * m, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, w + 2 * m, h + 2 * m, 0xFF5A6570)
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", gr, "Float", m, "Float", m, "Int", 0)
    DessinerReglages(gr, w, h, kp, mp, g)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

; Auto-test : mise en page de chaque catégorie (à trois échelles), pastilles,
; commandes branchées, lignes qui apparaissent avec leur option, polices
TestReglages(fichier) {
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    ConstruireMenus()                             ; (les commandes tiennent les menus à jour)
    ; ---- mise en page
    for kp in [1, 1.5, 2.5] {
        for c in REGLAGES_CATS {
            mp := MiseEnPageReglages(c.id, kp, REGL_H)
            dedans := true, chevauche := false, branche := true, unique := true, largeurs := true, nb := 0
            for z in mp.zones {
                if z.fixe
                    continue
                nb += 1
                dedans := dedans && z.x >= mp.cx && z.x + z.w <= mp.cx + mp.cw + 0.01
                branche := branche && IsObject(z.fn) && HasMethod(z.fn)
                for z2 in mp.zones
                    if (!z2.fixe && z2 != z && z.x < z2.x + z2.w && z2.x < z.x + z.w && z.y < z2.y + z2.h && z2.y < z.y + z.h)
                        chevauche := true
            }
            for li in mp.lignes {
                if (li.t = "choix") {
                    n := 0
                    for o in li.opts
                        n += o.sel
                    unique := unique && (li.opts.HasOwnProp("multi") || (li.opts.HasOwnProp("unique") ? n = 1 : n <= 1))
                }
                if (li.t != "section")
                    for t in li.labT
                        largeurs := largeurs && LargeurTexte(t, P_TEXTE, EmPourCapitale(P_TEXTE, ((li.t = "etat") ? 9 : 10.5) * kp)) <= (mp.cw - 28) * kp + 0.5
            }
            Verifier(nb > 0 && dedans && !chevauche, c.nom " à " kp " : " nb " zones, dans la carte, sans chevauchement")
            Verifier(branche, c.nom " à " kp " : chaque zone a sa commande")
            Verifier(unique, c.nom " à " kp " : une seule pastille choisie par choix")
            Verifier(largeurs, c.nom " à " kp " : libellés dans leur ligne")
        }
    }
    ; ---- polices : chaque police installée proposée une fois, familles nommées
    vues := Map(), attendues := 0, noms := ""
    for gp in GroupesPolices() {
        noms .= gp.nom "|"
        for po in gp.polices
            vues[po.v] := vues.Get(po.v, 0) + 1
    }
    for liste in [POLICES_HEURE, POLICES_AUTRES]
        for v in liste
            if (v.Length = 2 && (v[1] = "" || PoliceDisponible(v[1])))
                attendues += 1, Verifier(vues.Get(v[1], 0) = 1, "police « " v[2] " » proposée une fois")
    Verifier(vues.Count = attendues, "pas d'autre police (" vues.Count "/" attendues ")")
    Verifier(InStr(noms, "Segoe UI Variable|") && InStr(noms, "Bahnschrift|") && InStr(noms, "|Autres|"), "familles : " noms)
    ; ---- découpe des libellés
    l := ReglCouper("Sur batterie : nouveaux fonds d'ambiance au retour du secteur, et même un peu plus loin encore", P_TEXTE, 10.5, 2.5, 200)
    Verifier(l.Length = 2 && SubStr(l[2], -1) = "…", "texte long : 2 lignes, la dernière tronquée")
    ; ---- commandes : un clic change le réglage, la ligne suit, les lignes dépendantes apparaissent
    Ligne(cat, lib) {
        for lg in MiseEnPageReglages(cat, 2.5, REGL_H).lignes
            if (lg.lib == lib)
                return lg
        return ""
    }
    Pastille(cat, lib) {
        for lg in MiseEnPageReglages(cat, 2.5, REGL_H).lignes
            if (lg.t = "choix")
                for op in lg.opts
                    if (op.lib == lib)
                        return op
        return ""
    }
    avant := Heures
    EnDialogue(Ligne("meteo", LIB_HEURES).fn)
    Verifier(Heures = !avant && Ligne("meteo", LIB_HEURES).val = !avant, "« Prochaines heures » : le clic bascule le réglage et l'interrupteur")
    EnDialogue(Ligne("meteo", LIB_HEURES).fn)
    Verifier(Heures = avant, "… et un 2e clic le remet")
    styleAvant := Style
    EnDialogue(Pastille("apparence", "En toutes lettres").fn)
    Verifier(Style = "lettres" && IsObject(Ligne("apparence", "Précision de l'heure")) && Pastille("apparence", "En toutes lettres").sel,
        "style « En toutes lettres » : choisi, et ses options apparaissent")
    EnDialogue(Pastille("apparence", "Analogique").fn)
    Verifier(Style = "analogique" && !IsObject(Ligne("apparence", "Précision de l'heure")) && IsObject(Ligne("apparence", LIB_CHIFFRES)),
        "style « Analogique » : les options des lettres disparaissent, celles du cadran apparaissent")
    for v in STYLES
        if (v[1] = styleAvant)
            ChoisirStyle(v[1])
    Verifier(Style = styleAvant, "style remis (" Style ")")
    fondAvant := Opacite
    EnDialogue(Pastille("apparence", "35 %").fn)
    Verifier(Opacite = 35 && Pastille("apparence", "35 %").sel, "arrière-plan 35 % : choisi")
    ChoisirFond(fondAvant)
    Verifier(IsObject(Ligne("calendrier", "Ouvrir Mes jours…")) && IsObject(Ligne("position", LIB_EDITION)), "Mes jours et le redimensionnement à la souris sont là")
    ; ---- temps d'un dessin complet (catégorie la plus chargée, à l'échelle de ce PC)
    kp := A_ScreenDPI / 96, t0 := A_TickCount
    Loop 5 {
        mp := MiseEnPageReglages("heure", kp, REGL_H), w := Round(mp.w * kp), h := Round(mp.h * kp)
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
        DessinerReglages(gr, w, h, kp, mp, {cat: "heure", defil: 0, survol: ""})
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    }
    ms := (A_TickCount - t0) // 5
    Verifier(ms < 250, "mise en page et dessin de « Heure » à " kp " : " ms " ms")
    ; ---- relus au démarrage (de 2.28 à 2.30, 16 réglages ne l'étaient pas : sans « global », des locales)
    try avant := FileRead(F_REGLAGES, "RAW")
    catch
        avant := ""
    for cle, v in Map("actus_w", 0, "marches_btc", 0, "marches_indice_w", 0, "anglais_w", 0, "voile_bande", 0, "pluie_heure", 0,
            "rer_w", 0, "alerte_btc", 10, "alerte_actions", 5, "alerte_seuils", "70000", "anglais_source", "liste", "marches_indice", "^GSPC",
            "marches_cryptos", "bitcoin", "marches_indices", "^DJI", "marches_actions", "MC.PA", "marches_taux", "",
            "rer_arret", "42587", "rer_ligne", "C01377", "rer_nom", "Métro 7", "rer_gare", "Châtelet", "rer_couleur", "ff82b4",
            "rer_encre", "000000", "rer_sens", "Aller=Sud")
        IniWrite(v, F_REGLAGES, "widget", cle)
    ChargerReglages()
    Verifier(!ActusW && !MarchesBtcW && !MarchesIndiceW && !AnglaisW && !VoileBande && !PluieW && !RerW && AlerteBtc = 10 && AlerteActions = 5
        && AlerteSeuils = "70000" && AnglaisSource = "liste" && MarchesIndice = "^GSPC" && MarchesCryptos = "bitcoin" && MarchesIndices = "^DJI"
        && MarchesActions = "MC.PA" && RerArret = "42587" && RerLigne = "C01377" && RerNom = "Métro 7" && RerGare = "Châtelet"
        && RerCouleur = "ff82b4" && RerEncre = "000000" && RerSens = "Aller=Sud", "réglages des marchés, actus, anglais, pluie, alertes et transports relus au démarrage")
    if IsObject(avant) {                          ; (le dossier de test retrouve ses réglages, octet pour octet)
        f := FileOpen(F_REGLAGES, "w"), f.RawWrite(avant), f.Close()
        ChargerReglages()
    }
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}

; La vraie fenêtre, dans ce processus de test (données de test, faux widget
; invisible) : messages de la souris et du clavier simulés, curseur simulé
; (ReglCurseurTest) ; 2 à 3 s à l'écran
TestFenetreReglages(fichier) {
    global HWIDGET, ReglCurseurTest, ReglCat
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    faux := Gui("-Caption +ToolWindow")           ; (le widget : la fenêtre se place à côté)
    faux.Show("NA x" (A_ScreenWidth - 420) " y40 w300 h200")
    WinSetTransparent(1, faux)
    HWIDGET := faux.Hwnd
    ConstruireMenus()
    ReglMessages()
    ReglCat := "apparence"
    Viser(z) {                                    ; le curseur au milieu d'une zone (fenêtre là où elle est vraiment)
        global ReglCurseurTest
        g := ReglGeo
        WinGetPos(&fx, &fy, , , "ahk_id " ReglHwnd)
        zy := z.fixe ? z.y : z.y + g.mp.y0 - g.defil
        ReglCurseurTest := [fx + (z.x + z.w / 2) * g.kp, fy + (zy + z.h / 2) * g.kp]
    }
    Zone(id) {
        for zo in ReglGeo.mp.zones
            if (zo.id = id)
                return zo
        return ""
    }
    ZoneLigne(lib) {
        for lg in ReglGeo.mp.lignes
            if (lg.lib == lib)
                return Zone(lg.id)
        return ""
    }
    Envoyer(msg, wp := 0, attente := 150) {
        PostMessage(msg, wp, 0, , "ahk_id " ReglHwnd)
        Sleep(attente)                            ; (les messages et les minuteurs passent)
    }
    OuvrirReglages()
    Sleep(150)
    Verifier(ReglHwnd && DllCall("IsWindowVisible", "Ptr", ReglHwnd) && ReglGeo.w > 0 && SurgieOuverte(), "ouverte, visible (" ReglGeo.w "×" ReglGeo.h " px)")
    Viser(Zone("cat:calendrier")), Envoyer(0x201)
    Verifier(ReglGeo.cat = "calendrier" && ReglCat = "calendrier", "clic sur « Calendrier » : la catégorie change")
    ReglSurvol()                                  ; (appelé par WM_MOUSEMOVE ; le vrai curseur est ailleurs)
    Verifier(ReglGeo.survol = "cat:calendrier", "survol noté")
    Verifier(ReglGeo.mp.defilMax > 0, "catégorie plus haute que la fenêtre : " ReglGeo.mp.defilMax " px à défiler")
    ReglCurseurTest := [ReglGeo.x + 400 * ReglGeo.kp, ReglGeo.y + 300 * ReglGeo.kp]
    Envoyer(0x100, 0x23)                          ; Fin
    Verifier(ReglGeo.defil = ReglGeo.mp.defilMax, "touche Fin : tout en bas (" ReglGeo.defil " px)")
    avant := AnnivConfettis
    Viser(ZoneLigne(LIB_CONFETTIS)), Envoyer(0x201, 1, 300)
    Verifier(AnnivConfettis = !avant, "clic sur l'interrupteur « Confettis le jour J » : réglage basculé")
    lc := ""
    for l2 in ReglGeo.mp.lignes
        if (l2.lib == LIB_CONFETTIS)
            lc := l2
    Verifier(IsObject(lc) && lc.val = !avant, "… et l'interrupteur redessiné")
    Viser(ZoneLigne(LIB_CONFETTIS)), Envoyer(0x201, 1, 300)
    Verifier(AnnivConfettis = avant, "2e clic : remis")
    d0 := ReglGeo.defil
    Envoyer(0x20A, 120 << 16)                     ; un cran de molette vers le haut
    Verifier(ReglGeo.defil = Max(0, d0 - 60), "molette : 60 px plus haut (" d0 " → " ReglGeo.defil ")")
    Envoyer(0x100, 0x28)                          ; ↓ : catégorie suivante
    Verifier(ReglGeo.cat = "alertes" && ReglGeo.defil = 0, "↓ : catégorie suivante, en haut")
    Envoyer(0x100, 0x1B, 250)                     ; Échap
    Verifier(!ReglHwnd && !SurgieOuverte(), "Échap : fermée")
    OuvrirReglages(), Sleep(100)
    Verifier(ReglGeo.cat = "alertes", "rouverte sur la dernière catégorie")
    OuvrirReglages(), Sleep(100)
    Verifier(!ReglHwnd, "« Réglages… » une 2e fois : fermée")
    OuvrirReglages(), Sleep(100)
    OuvrirJours(), Sleep(100)
    Verifier(!ReglHwnd && JoursHwnd, "Mes jours ouvert : Réglages fermé (une seule fenêtre à la fois)")
    OuvrirReglages(), Sleep(100)
    Verifier(ReglHwnd && !JoursHwnd, "et l'inverse")
    Viser(Zone("fermer")), Envoyer(0x201, 1, 250)
    Verifier(!ReglHwnd, "croix : fermée")
    ; déplacée (comme Windows le fait quand on la fait glisser) : les clics suivent, et elle se rouvre là
    try IniDelete(F_REGLAGES, "widget", "reglages_pos")
    OuvrirReglages(), Sleep(100)
    nx := ReglGeo.x - 150, ny := ReglGeo.y + 40
    WinMove(nx, ny, , , "ahk_id " ReglHwnd), Sleep(50)
    Viser(Zone("cat:ciel")), Envoyer(0x201)
    Verifier(ReglGeo.cat = "ciel" && ReglGeo.x = nx && ReglGeo.y = ny, "déplacée de 150 px : un clic sur « Ciel » tombe juste")
    Envoyer(0x200)                                ; survol puis dessin : la fenêtre reste où on l'a mise
    WinGetPos(&fx, &fy, , , "ahk_id " ReglHwnd)
    Verifier(fx = nx && fy = ny, "repeinte, elle ne revient pas à sa place d'avant")
    FermerReglages("test")
    Verifier(IniRead(F_REGLAGES, "widget", "reglages_pos", "") = nx "," ny, "position gardée : " IniRead(F_REGLAGES, "widget", "reglages_pos", ""))
    OuvrirReglages(), Sleep(100)
    WinGetPos(&fx, &fy, , , "ahk_id " ReglHwnd)
    Verifier(fx = nx && fy = ny, "rouverte là où on l'a laissée")
    FermerReglages("test")
    IniWrite("99999,99999", F_REGLAGES, "widget", "reglages_pos")
    OuvrirReglages(), Sleep(100)
    WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " ReglHwnd)
    e := EcranProche(fx + fw // 2, fy + fh // 2)
    Verifier(fx >= e.l && fy >= e.t && fx + fw <= e.r && fy + fh <= e.b, "position hors écran (autre écran débranché) : ramenée dans l'écran")
    FermerReglages("test")
    try IniDelete(F_REGLAGES, "widget", "reglages_pos")
    ReglCurseurTest := ""
    faux.Destroy()
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}
