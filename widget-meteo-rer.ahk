; =============================================================================
;  Widget météo — les prochains départs d'une gare ou d'un arrêt d'Île-de-France
;  (RER, Transilien, métro, tram, bus), choisi par son nom : les deux prochains
;  dans chaque sens sur le widget (orange en retard, rouge supprimé), une pastille
;  quand la ligne est perturbée, le détail dans le tableau de bord.
;
;  Données : Île-de-France Mobilités — la recherche d'arrêt dans son open data
;  (sans clé), les prochains passages et l'info trafic par PRIM avec le jeton
;  gratuit de l'utilisateur (cle-idfm.txt, saisi dans Réglages ▸ Transports, jamais
;  dans le dépôt). Collecte par widget-meteo-marches.ps1 -Rer / -RerInfo : départs
;  toutes les 2 min, messages toutes les 10 min, rien de 1 h 30 à 4 h 30 (quotas
;  d'un nouveau compte : 1 000 requêtes par jour et par API).
;
;  Les sens : ceux d'Île-de-France Mobilités (« Aller », « Retour »), nommés d'après
;  le terminus annoncé (métro, tram, bus) ou la destination la plus fréquente
;  (trains, qui n'en annoncent pas) ; l'utilisateur peut les renommer (« Paris »).
;  Inclus par widget-meteo.ahk (état : Rer*, F_RER, F_CLE_IDFM là-bas).
; =============================================================================

LireRer() {
    global RerDeparts, RerMessages, RerEtatD, RerEtatM, RerMajD, RerMajM, RerDate
    try m := FileGetTime(F_RER, "M")
    catch
        return false
    if (m = RerDate)
        return false
    try txt := FileRead(F_RER, "UTF-8")
    catch
        return false
    d := [], ms := [], cfg := "", etatD := "", etatM := "", majD := 0, majM := 0
    for ligne in StrSplit(txt, "`n", "`r") {
        if RegExMatch(ligne, "^(cfg|maj_d|etat_d|maj_m|etat_m)=(.*)$", &o) {
            switch o[1] {
                case "cfg":    cfg := o[2]
                case "maj_d":  majD := Integer("0" o[2])
                case "etat_d": etatD := o[2]
                case "maj_m":  majM := Integer("0" o[2])
                case "etat_m": etatM := o[2]
            }
            continue
        }
        c := StrSplit(ligne, "|", , 7)
        if (c.Length >= 6 && c[1] = "D" && IsInteger(c[2])) {
            ref := (c.Length >= 7) ? c[7] : ""
            d.Push({t: Integer(c[2]), theo: Integer("0" c[3]), statut: c[4], dest: c[5], dir: c[6], ref: ref, cle: CleSens(c[5], c[6], ref)})
        } else if (c.Length >= 5 && c[1] = "M")
            ms.Push({debut: Integer("0" c[2]), fin: Integer("0" c[3]), canal: c[4], texte: c[5]})
    }
    RerDate := m
    if (RerArret = "" || cfg != RerArret "|" RerLigne)   ; (relevé d'une autre gare, ou d'avant le choix)
        d := [], ms := [], etatD := "", etatM := "", majD := 0, majM := 0
    TrierDeparts(d)
    RerDeparts := d, RerMessages := ms, RerEtatD := etatD, RerEtatM := etatM, RerMajD := majD, RerMajM := majM
    return true
}

TrierDeparts(d) {
    Loop d.Length - 1 {
        i := A_Index + 1, e := d[i], k := i - 1
        while (k >= 1 && d[k].t > e.t)
            d[k + 1] := d[k], k--
        d[k + 1] := e
    }
}

; La clé d'un sens : celui d'Île-de-France Mobilités (« Aller », « Retour ») ; une
; ligne le range dans le nom du sens (constaté sur le T9), d'autres n'en donnent
; aucun : le nom du sens, sinon la destination
CleSens(dest, dir, ref) {
    if (ref != "")
        return ref
    if (dir = "Aller" || dir = "Retour")
        return dir
    return (dir != "") ? dir : dest
}

; Les noms donnés aux sens (Réglages ▸ Transports), dans l'ordre d'affichage : [[clé, nom], …] (nom vide : automatique)
NomsSens() {
    r := []
    for p in StrSplit(RerSens, "|")
        if RegExMatch(p, "^([^=]+)=(.*)$", &o)
            r.Push([o[1], o[2]])
    return r
}

NomDonne(cle) {
    for e in NomsSens()
        if (e[1] == cle)
            return e[2]
    return ""
}

; Le nom automatique d'un sens : le terminus annoncé (métro, tram, bus : « Mairie
; d'Ivry • Villejuif - Louis Aragon » → « Mairie d'Ivry »), sinon la destination la
; plus fréquente (trains : « Versailles Château Rive Gauche » → « Versailles Château »)
LibelleAuto(cle) {
    nd := Map(), nt := Map()
    for d in RerDeparts
        if (d.cle == cle) {
            if (d.dir != "" && d.dir != "Aller" && d.dir != "Retour")
                nd[d.dir] := nd.Get(d.dir, 0) + 1
            nt[d.dest] := nt.Get(d.dest, 0) + 1
        }
    return CourtSens(PlusFrequent(nd.Count ? nd : nt, cle))
}

LibelleSens(cle) => ((n := NomDonne(cle)) != "") ? n : LibelleAuto(cle)

PlusFrequent(m, defaut) {
    meilleur := defaut, n := 0
    for k, v in m
        if (v > n && k != "")
            meilleur := k, n := v
    return meilleur
}

; Un nom de sens court : avant « • », « - », « < » ou « ( », sans « Gare de », puis
; 18 caractères au plus en mots entiers (sans finir sur « de », « la »…)
CourtSens(t) {
    t := Trim(RegExReplace(t, "\s*(•|\s-\s|<|\().*$"))
    t := RegExReplace(t, "i)^Gare (de |d'|du |des )")
    if (StrLen(t) <= 18)
        return t
    r := ""
    for w in StrSplit(t, " ") {
        if (StrLen(r (r = "" ? "" : " ") w) > 18)
            break
        r .= (r = "" ? "" : " ") w
    }
    r := RegExReplace(r, "i)\s+(de|du|des|d'|la|le|les|l'|à|au|aux|sur|et)$")
    if (r = "") {                                 ; (un premier mot trop long : « Saint-Germain-en-Laye » → « Saint-Germain »)
        for p in StrSplit(StrSplit(t, " ")[1], "-") {
            if (StrLen(r (r = "" ? "" : "-") p) > 18)
                break
            r .= (r = "" ? "" : "-") p
        }
        r := RegExReplace(r, "i)-(en|la|le|les|sur|sous|lès|lez|de|du|des|d)$")
    }
    return (StrLen(r) >= 6) ? r : SubStr(t, 1, 17) "…"
}

; Les destinations d'un sens, les plus fréquentes d'abord : « Versailles Château, Pontoise, Montigny »
DestinationsSens(cle, n := 3) {
    nt := Map()
    for d in RerDeparts
        if (d.cle == cle && d.dest != "")
            nt[CourtSens(d.dest)] := nt.Get(CourtSens(d.dest), 0) + 1
    r := ""
    Loop n {
        k := PlusFrequent(nt, "")
        if (k = "")
            break
        r .= (r = "" ? "" : ", ") k, nt.Delete(k)
    }
    return r
}

; Les deux sens montrés : [{cle, lib}] — les deux qui ont le plus de départs, dans
; l'ordre des noms donnés, sinon alphabétique (« Aller » avant « Retour »)
GroupesRer() {
    n := Map()
    for d in RerDeparts
        n[d.cle] := n.Get(d.cle, 0) + 1
    cles := []
    for c, k in n {
        i := cles.Length + 1
        while (i > 1 && n[cles[i - 1]] < k)
            i--
        cles.InsertAt(i, c)
    }
    if (cles.Length > 2)
        cles.Length := 2
    rang := Map()
    for i, e in NomsSens()
        rang[e[1]] := i
    if (cles.Length = 2) {
        ra := rang.Get(cles[1], 99), rb := rang.Get(cles[2], 99)
        if (ra > rb || (ra = rb && StrCompare(cles[1], cles[2]) > 0))
            cles := [cles[2], cles[1]]
    }
    g := []
    for c in cles
        g.Push({cle: c, lib: LibelleSens(c)})
    return g
}

; Retard en minutes, arrondi comme il s'affiche (« +2 min » : orange dès 2)
RetardMin(d) => Max(0, Round((d.t - d.theo) / 60))

RerCle() => FileExist(F_CLE_IDFM) && Trim(FileRead(F_CLE_IDFM)) != ""

; Les n prochains départs du sens « cle » (tous si vide ; déjà partis il y a moins de 30 s compris)
DepartsRer(cle := "", n := 3) {
    r := [], maint := MaintenantUnix()
    for d in RerDeparts
        if ((cle = "" || d.cle == cle) && d.t >= maint - 30) {
            r.Push(d)
            if (r.Length >= n)
                break
        }
    return r
}

; Départs à jour (relevés il y a moins de 10 min) ?
RerFrais() => RerEtatD = "ok" && MaintenantUnix() - RerMajD < 600

RerDue() {
    if (!RerW || RerArret = "" || RerLigne = "" || (RerPID && ProcessExist(RerPID)) || !FileExist(F_CLE_IDFM))
        return ""
    if (RerEtatD = "cle") {                       ; jeton refusé : on attend qu'il change
        try m := FileGetTime(F_CLE_IDFM, "M")
        catch
            return ""
        if (m = RerCleDate)
            return ""
    }
    mn := A_Hour * 60 + A_Min
    if (mn >= 90 && mn < 270)                     ; 1 h 30 – 4 h 30 : presque rien ne roule (quota)
        return ""
    maint := MaintenantUnix(), q := ""
    pas := (RerEtatD = "quota") ? 1800 : (Sobre && SobreMeteo && SurBatterieEco()) ? 300 : 120
    if (maint - DernierRerD >= pas - 5)
        q .= "d"
    if (maint - DernierRerM >= ((RerEtatM = "quota") ? 3600 : 600) - 5)
        q .= "m"
    return q
}

LancerRer(q := "dm") {
    global RerPID, RerT0, DernierRerD, DernierRerM, RerCleDate
    if (!FileExist(SCRIPT_MARCHES) || (RerPID && ProcessExist(RerPID)) || RerArret = "" || RerLigne = "")
        return
    arg := (InStr(q, "d") ? " -Rer" : "") (InStr(q, "m") ? " -RerInfo" : "")
    if (arg = "")
        return
    try Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' SCRIPT_MARCHES '"' arg
        . " -RerArret " RerArret " -RerLigne " RerLigne, , "Hide", &pid)
    catch
        return
    RerPID := pid, RerT0 := A_TickCount
    if InStr(q, "d")
        DernierRerD := MaintenantUnix()
    if InStr(q, "m")
        DernierRerM := MaintenantUnix()
    try RerCleDate := FileGetTime(F_CLE_IDFM, "M")
    SetTimer(SuivreRer, 500)
}

SuivreRer() {
    global RerPID
    if (RerPID && ProcessExist(RerPID)) {
        if (A_TickCount - RerT0 < 60000)
            return
        try ProcessClose(RerPID)
    }
    SetTimer(SuivreRer, 0)
    RerPID := 0
    if LireRer() {
        Redessiner(true)                          ; (la ligne ou la pastille peut apparaître)
        if MarchesHwnd
            PeindreMarches()
        ReglAJour()
    }
}

; ---------- Sur le widget ----------

; « RER C » dans une pastille à la couleur de la ligne, puis « Paris 07:12 · 07:27
; Sud 07:18 · 07:33 » (orange : en retard de 2 min ou plus ; rouge : supprimé) ;
; un seul départ par sens si les deux ne tiennent pas dans la largeur
LigneRer(L, t, u, x, yHaut, largeur, align) {
    if !RerFrais()
        return
    capT := 0.03 * u, cap := 0.044 * u, capS := 0.036 * u
    emT := EmPourCapitale(P_DATE, capT), em := EmPourCapitale(P_DATE, cap), emS := EmPourCapitale(P_TEXTE, capS)
    orange := t.sombre ? 0xFFB85C00 : 0xFFFFA940, rouge := t.sombre ? 0xFFC4271D : 0xFFFF5A4F
    nom := (RerNom != "") ? RerNom : "Départs"
    wp := LargeurTexte(nom, P_DATE, emT) + 0.036 * u, hp := 0.06 * u
    groupes := GroupesRer()
    for nb in [2, 1] {
        ; morceaux : [texte, police, em, couleur, écart après]
        m := [], sep := 0.022 * u
        for g in groupes {
            dep := DepartsRer(g.cle, nb)
            if !dep.Length
                continue
            if m.Length
                m[m.Length][5] := 0.07 * u
            m.Push([g.lib, P_TEXTE, emS, t.second, sep])
            for i, d in dep
                m.Push([FormatTime(LocalDeUnix(d.t), "HH:mm"), P_DATE, em,
                    (d.statut = "cancelled") ? rouge : (RetardMin(d) >= 2) ? orange : t.texte, (i < dep.Length) ? 0.03 * u : 0])
        }
        if !m.Length
            m.Push(["pas de départ annoncé", P_TEXTE, emS, t.second, 0])
        tot := wp + 0.03 * u
        for q in m
            q.Push(LargeurTexte(q[1], q[2], q[3])), tot += q[6] + q[5]
        if (tot <= largeur)
            break
    }
    xx := align ? x + Max(0, (largeur - tot) / 2) : x
    yb := yHaut + 0.082 * u
    L.Push({p: CheminArrondi(xx, yb - capT / 2 - hp / 2, wp, hp, hp / 2), f: 0xFF000000 | Integer("0x" RerCouleur), o: 0, z: false, brut: true, a: 0})
    Poser(L, nom, P_DATE, emT, xx + wp / 2, yb, 1, 0xFF000000 | Integer("0x" RerEncre))   ; (centré dans la pastille, sans ombre)
    L[L.Length].o := 0x000000, L[L.Length].a := 0, L[L.Length].brut := true
    xc := xx + wp + 0.03 * u
    for q in m {
        Poser(L, q[1], q[2], q[3], xc, yb, 0, q[4])
        xc += q[6] + q[5]
    }
    NoterZone("rer", {x: xx, y: yHaut + 0.01 * u, w: tot, h: 0.1 * u})
}

; Pastille quand la ligne est perturbée (message « Perturbation » en cours)
PastilleRer() {
    if (!RerW || RerArret = "" || RerEtatM != "ok" || MaintenantUnix() - RerMajM > 1800)
        return ""
    maint := MaintenantUnix()
    for msg in RerMessages
        if (msg.canal = "Perturbation" && (!msg.fin || msg.fin > maint))
            return {textes: [RerNom " : " msg.texte, RerNom " : trafic perturbé"], fond: 0xFFF7931E, encre: 0xFF16191D, icone: "alerte"}
    return ""
}

; ---------- Réglages ▸ Transports ----------

BasculerRerW(*) {
    global RerW := !RerW
    SauverReglages()
    CocherMenus()
    if (RerW && RerCle())
        LancerRer("dm")
    Redessiner(true)
}

; Gare ou arrêt : un nom, la recherche dans l'open data d'Île-de-France Mobilités
; (quelques secondes), puis le menu des arrêts trouvés avec leurs lignes (trains d'abord)
ChoisirArret(*) {
    r := InputBox("Nom de la gare, de la station ou de l'arrêt (Île-de-France) :`nex. Châtelet, Gare de Lyon, La Défense, Porte d'Orléans…",
        "Prochains départs", "w460 h150", RerGare)
    q := Trim(r.Value)
    if (r.Result != "OK" || q = "")
        return
    f := DOSSIER "\arrets-trouves.txt"
    try FileDelete(f)
    ToolTip("Recherche de « " q " »…")
    try RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' SCRIPT_MARCHES '" -ChercherArret ' ArgPS(q) ' -Fichier ' ArgPS(f), , "Hide")
    ToolTip()
    res := LireArretsTrouves(f)
    if !res.liste.Length {
        MsgBox((res.etat = "vide") ? "Aucun arrêt trouvé pour « " q " »." : "Recherche impossible pour l'instant (réseau ?).", "Prochains départs", "Iconi")
        return
    }
    m := Menu(), vus := Map()
    for i, a in res.liste {
        if (i > 40) {
            m.Add("… (précise le nom pour voir les autres)", (*) => 0), m.Disable("… (précise le nom pour voir les autres)")
            break
        }
        lib := StrReplace(a.ligne " · " a.nom ((a.commune != "" && !InStr(a.nom, a.commune)) ? " (" a.commune ")" : ""), "&", "&&")
        while vus.Has(lib)
            lib .= " "
        vus[lib] := 1
        m.Add(lib, AppliquerArret.Bind(a))
        if (a.zda = RerArret && a.idl = RerLigne)
            m.Check(lib)
    }
    m.Show()
}

; etat (ok, vide, erreur) et liste [{zda, nom, commune, idl, ligne, mode, couleur, encre}] d'une recherche
LireArretsTrouves(f) {
    r := {etat: "erreur", liste: []}
    try txt := FileRead(f, "UTF-8")
    catch
        return r
    for l in StrSplit(txt, "`n", "`r") {
        if (SubStr(l, 1, 5) = "etat=")
            r.etat := SubStr(l, 6)
        c := StrSplit(l, "|")
        if (c.Length >= 9 && c[1] = "R" && RegExMatch(c[2], "^\d+$") && RegExMatch(c[5], "^C\d+$"))
            r.liste.Push({zda: c[2], nom: c[3], commune: c[4], idl: c[5], ligne: c[6], mode: c[7],
                couleur: RegExMatch(c[8], "^[0-9a-fA-F]{6}$") ? c[8] : "8e8e93", encre: RegExMatch(c[9], "^[0-9a-fA-F]{6}$") ? c[9] : "ffffff"})
    }
    return r
}

AppliquerArret(a, *) {
    global RerArret, RerLigne, RerNom, RerGare, RerCouleur, RerEncre, RerSens, RerDate, RerDeparts, RerMessages,
        RerEtatD, RerEtatM, DernierRerD, DernierRerM
    if !(a.zda = RerArret && a.idl = RerLigne)    ; (autre gare ou autre ligne : d'autres sens)
        RerSens := "", RerDeparts := [], RerMessages := [], RerEtatD := "", RerEtatM := "", DernierRerD := 0, DernierRerM := 0
    RerArret := a.zda, RerLigne := a.idl, RerNom := a.ligne, RerGare := a.nom, RerCouleur := a.couleur, RerEncre := a.encre, RerDate := ""
    SauverReglages()
    Journal("transports : " a.ligne " à " a.nom)
    if (RerW && RerCle())
        LancerRer("dm")
    Redessiner(true)
    ReglAJour()
}

; Noms des deux sens : « Paris », « Sud »… (vide : le nom automatique)
NommerSens(*) {
    global RerSens
    g := GroupesRer()
    if !g.Length {
        MsgBox("Les sens apparaîtront avec les premiers départs relevés (il faut une gare et le jeton).", "Prochains départs", "Iconi")
        return
    }
    noms := ""
    for e in g {
        r := InputBox("Nom du sens vers " DestinationsSens(e.cle) " :`n(vide : « " LibelleAuto(e.cle) " », le nom automatique)",
            "Prochains départs", "w480 h150", NomDonne(e.cle))
        if (r.Result != "OK")
            return
        noms .= (noms = "" ? "" : "|") e.cle "=" Trim(RegExReplace(r.Value, "[|=]"))
    }
    RerSens := noms
    SauverReglages()
    Redessiner(true)
    if MarchesHwnd
        PeindreMarches()
    ReglAJour()
}

; « Paris, Sud » ou « automatiques »
TexteSens() {
    t := ""
    for e in NomsSens()
        if (e[2] != "")
            t .= (t = "" ? "" : ", ") e[2]
    return (t = "") ? "automatiques" : t
}

; Le jeton d'Île-de-France Mobilités : collé par l'utilisateur, écrit dans
; cle-idfm.txt (données du widget, hors du dépôt), jamais affiché
SaisirCleIdfm(*) {
    global RerEtatD, RerEtatM
    r := InputBox("Colle ici ton jeton d'API Île-de-France Mobilités`n(prim.iledefrance-mobilites.fr ▸ Mes jetons d'authentification ▸ API).`nVide : retirer le jeton.",
        "Prochains départs", "Password w500 h170")
    if (r.Result != "OK")
        return
    v := RegExReplace(r.Value, "\s")
    try FileDelete(F_CLE_IDFM)
    if (v != "")
        FileAppend(v, F_CLE_IDFM, "UTF-8-RAW")
    RerEtatD := "", RerEtatM := ""
    Journal("jeton Île-de-France Mobilités " ((v != "") ? "enregistré" : "retiré"))
    if (v != "" && RerW)
        LancerRer("dm")
    Redessiner(true)
}

; État lisible pour Réglages : « départs relevés à 07:10 », « jeton refusé »…
EtatRer() {
    if (RerArret = "")
        return "Choisis d'abord une gare ou un arrêt"
    if !RerCle()
        return "Pas encore de jeton"
    switch RerEtatD {
        case "ok":     return "Départs relevés à " FormatTime(LocalDeUnix(RerMajD), "HH:mm")
            . ((RerEtatM = "ok") ? ", info trafic à " FormatTime(LocalDeUnix(RerMajM), "HH:mm") : "")
        case "cle":    return "Jeton refusé par Île-de-France Mobilités (à vérifier ou regénérer)"
        case "quota":  return "Quota du jour atteint (1 000 requêtes) : nouvel essai dans 30 min"
        case "erreur": return "Île-de-France Mobilités injoignable (réseau ?) : nouvel essai dans 2 min"
        default:       return "Premier relevé en cours…"
    }
}

; ---------- Tests ----------

; Auto-test : lecture de rer.txt (écrit ici, départs placés autour de maintenant ;
; le décodage des vraies réponses se teste avec la collecte en mode -EssaiRer), sens
; et leurs noms, retards, suppressions, pastille de perturbation, gare changée,
; lecture d'une recherche d'arrêts
TestRer(fichier) {
    global RerDate, RerArret, RerLigne, RerNom, RerSens
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    DirCreate(DOSSIER)                            ; (dossier de données vierge : premier lancement)
    RerArret := "12345", RerLigne := "C01727", RerNom := "RER C", RerSens := ""   ; (zone d'arrêt fictive)
    n := MaintenantUnix()
    Ecrire(cfg, lignes) {
        try FileDelete(F_RER)
        FileAppend("cfg=" cfg "`nmaj_d=" n "`netat_d=ok`n" lignes, F_RER, "UTF-8")
        RerDate := ""
        return LireRer()
    }
    Ecrire("12345|C01727",
        "D|" n - 600 "|" n - 600 "|cancelled|Avenue Henri Martin||Aller`n"      ; (déjà parti : ignoré)
        . "D|" n + 240 "|" n + 240 "|onTime|Pontoise||Retour`n"
        . "D|" n + 660 "|" n + 420 "|onTime|Brétigny||Aller`n"
        . "D|" n + 1140 "|" n + 1140 "|onTime|Versailles Château Rive Gauche||Retour`n"
        . "D|" n + 1320 "|" n + 1320 "|cancelled|Massy-Palaiseau||Aller`n"
        . "D|" n + 1500 "|" n + 1500 "|onTime|Versailles Château Rive Gauche||Retour`n"
        . "D|" n + 2220 "|" n + 2220 "|onTime|Brétigny||Aller`n"
        . "maj_m=" n "`netat_m=ok`n"
        . "M|" n - 1800 "|" n + 7200 "|Perturbation|Trafic perturbé entre Juvisy et Paris Austerlitz`n"
        . "M|" n - 36000 "|" n + 180000 "|Information|Travaux le week-end prochain`n")
    Verifier(RerEtatD = "ok" && RerEtatM = "ok", "rer.txt lu (départs " RerEtatD ", info trafic " RerEtatM ")")
    Verifier(RerDeparts.Length = 7 && DepartsRer("", 9).Length = 6, "7 départs lus, 6 à venir (celui déjà parti écarté)")
    ok := true
    Loop RerDeparts.Length - 1
        ok := ok && RerDeparts[A_Index].t <= RerDeparts[A_Index + 1].t
    Verifier(ok, "départs dans l'ordre")
    g := GroupesRer()
    Verifier(g.Length = 2 && g[1].cle = "Aller" && g[2].cle = "Retour" && g[1].lib = "Brétigny" && g[2].lib = "Versailles Château",
        "sens automatiques : Aller « " (g.Length ? g[1].lib : "") " », Retour « " (g.Length > 1 ? g[2].lib : "") " » (destination la plus fréquente)")
    RerSens := "Retour=Paris|Aller=Sud", g := GroupesRer()
    Verifier(g.Length = 2 && g[1].lib = "Paris" && g[2].lib = "Sud" && TexteSens() = "Paris, Sud", "sens renommés, dans l'ordre des noms : Paris puis Sud")
    RerSens := "Aller=|Retour=Paris", g := GroupesRer()
    Verifier(g[1].lib = "Brétigny" && g[2].lib = "Paris" && TexteSens() = "Paris", "un seul sens renommé : l'autre garde son nom automatique et sa place")
    p := DepartsRer("Retour", 2), s := DepartsRer("Aller", 2)
    Verifier(p.Length = 2 && s.Length = 2 && p[1].dest = "Pontoise" && s[1].dest = "Brétigny", "2 prochains de chaque côté")
    Verifier(s[1].t - s[1].theo = 240 && s[2].statut = "cancelled", "retard (+4 min) et suppression repérés")
    Verifier(InStr(DestinationsSens("Retour"), "Versailles Château") = 1 && InStr(DestinationsSens("Retour"), "Pontoise"), "destinations d'un sens : " DestinationsSens("Retour"))
    ps := PastilleRer()
    Verifier(IsObject(ps) && ps.textes[1] = "RER C : Trafic perturbé entre Juvisy et Paris Austerlitz", "pastille : la perturbation, pas l'information travaux")
    Verifier(InStr(EtatRer(), "Départs relevés à") || InStr(EtatRer(), "jeton"), "état pour Réglages : " EtatRer())
    ; métro : le terminus annoncé nomme le sens ; T9 : le sens rangé dans son nom
    RerSens := ""
    Ecrire("12345|C01727",
        "D|" n + 100 "|" n + 100 "|onTime|Mairie d'Ivry|Mairie d'Ivry • Villejuif - Louis Aragon|Aller`n"
        . "D|" n + 200 "|" n + 200 "|onTime|La Courneuve-8-Mai-1945|La Courneuve - 8 Mai 1945|Retour`n"
        . "D|" n + 300 "|" n + 300 "|onTime|Orly - Gaston Viens|Aller|`n")
    g := GroupesRer()
    Verifier(g.Length = 2 && g[1].lib = "Mairie d'Ivry" && g[2].lib = "La Courneuve" && RerDeparts[3].cle = "Aller",
        "métro : « " (g.Length ? g[1].lib : "") " » / « " (g.Length > 1 ? g[2].lib : "") " », sens du T9 lu dans son nom")
    Verifier(CourtSens("Pont de Rungis Aéroport d'Orly") = "Pont de Rungis" && CourtSens("Gare de Saint-Maur - Créteil") = "Saint-Maur"
        && CourtSens("École Vétérinaire de Maisons-Alfort") = "École Vétérinaire" && CourtSens("Porte de Vincennes") = "Porte de Vincennes"
        && CourtSens("Villeneuve - Triage <RER>") = "Villeneuve" && CourtSens("Saint-Germain-en-Laye") = "Saint-Germain"
        && CourtSens("Marne-la-Vallée Chessy") = "Marne-la-Vallée", "noms courts des sens")
    ; relevé d'une autre gare (choix changé entre-temps) : rien de montré
    Ecrire("42587|C01377", "D|" n + 100 "|" n + 100 "|onTime|Mairie d'Ivry||Aller`n")
    Verifier(!RerDeparts.Length && RerEtatD = "" && !RerFrais(), "relevé d'une autre gare : ignoré")
    ; résultat d'une recherche d'arrêts
    f := DOSSIER "\arrets-test.txt"
    try FileDelete(f)
    FileAppend("etat=ok`nR|45102|Châtelet - Les Halles|Paris|C01742|RER A|rail|eb2132|ffffff`n"
        . "R|42587|Châtelet|Paris|C01377|Métro 7|metro|ff82b4|000000`nR|x|mauvais|||||`n", f, "UTF-8")
    res := LireArretsTrouves(f)
    Verifier(res.etat = "ok" && res.liste.Length = 2 && res.liste[1].ligne = "RER A" && res.liste[2].couleur = "ff82b4", "recherche d'arrêts lue (2 valides sur 3)")
    try FileDelete(f)
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}
