; =============================================================================
;  Widget météo — qualité de l'air (menu Afficher ▸ Vigilance ▸ Qualité de
;  l'air) — inclus par widget-meteo.ahk
;
;  Rien tant que l'air est correct. Une pastille aux couleurs officielles
;  quand l'indice ATMO de la commune (Airparif, Île-de-France) atteint le seuil
;  choisi, ou pendant un épisode de pollution déclaré ; en option, le sable du
;  Sahara (modèle CAMS, via Open-Meteo) et les pollens (indice officiel d'Atmo
;  France). Le détail est dans les prévisions (section « Qualité de l'air »).
;  Collecte : clés air_*, sable_*, pol_* (widget-meteo-donnees.ps1, -Air,
;  -Sable, -Pollens), gardées 55 min (3 h pour les pollens).
; =============================================================================

; (constantes AIR_MODES, SABLE_*, POLLENS_NOMS, POLLUANTS, URL_AIRPARIF : en tête de widget-meteo.ahk)

AirActif() => AirMode != "0" || AirSable || AirPollens

; Décalage des clés J / J+1 de la collecte « prefixe » (air, sable) : 0 si
; elles datent d'aujourd'hui, 1 si d'hier (après minuit, J+1 est aujourd'hui),
; "" si plus vieilles (collecte d'avant 2.25, sans date : 0)
DecalageAir(prefixe) {
    d := Donnees.Get(prefixe "_date", "")
    if !IsTime(d)
        return 0
    n := -JoursAvant(Integer(d))
    return (n = 0 || n = 1) ? n : ""
}

; Indice d'aujourd'hui (jour 0) ou de demain (1) : {code, lib, c (ARGB), polluants (texte)}, ou ""
IndiceAir(jour) {
    dec := DecalageAir("air")
    if (dec = "" || jour + dec > 1)
        return ""
    v := StrSplit(Donnees.Get((jour + dec) ? "air_j1" : "air_j", ""), "|")
    if (v.Length < 4 || !IsInteger(v[1]) || Donnees.Get("air_etat", "") != "ok" || !AirFrais("air_maj"))
        return ""
    pol := []
    if (Integer(v[1]) >= 2)                       ; (« bon » : tous les sous-indices à 1, rien à dire)
        for p in StrSplit(v[4], ",")
            if POLLUANTS.Has(p)
                pol.Push(POLLUANTS[p])
    return {code: Integer(v[1]), lib: v[2], c: RegExMatch(v[3], "^[0-9A-Fa-f]{6}$") ? 0xFF000000 | Integer("0x" v[3]) : 0xFF98989D,
        polluants: JoindreEt(pol)}
}

; Données de moins de 6 h (au-delà, rien plutôt qu'un air d'hier)
AirFrais(cle) => IsInteger(Donnees.Get(cle, "")) && MaintenantUnix() - Integer(Donnees[cle]) < 6 * 3600

; Épisodes de pollution d'aujourd'hui et de demain : [{demain (bool), polluant, alerte (bool)}]
EpisodesAir() {
    ep := []
    if (Donnees.Get("air_etat", "") != "ok" || !AirFrais("air_maj") || (dec := DecalageAir("air")) = "")
        return ep
    for e in StrSplit(Donnees.Get("air_epi", ""), ";") {
        v := StrSplit(e, "|"), j := ((v[1] = "J+1") ? 1 : 0) - dec   ; -1 : celui d'hier
        if (v.Length >= 3 && j >= 0)
            ep.Push({demain: j = 1, polluant: v[2], alerte: InStr(v[3], "ALERTE") > 0})
    }
    return ep
}

; « Pic de pollution à l'ozone », « aux particules », « au dioxyde d'azote »
PicDe(polluant) {
    p := StrLower(polluant)
    return "Pic de pollution " (InStr(p, "ozone") ? "à l'ozone" : InStr(p, "particule") ? "aux particules" : InStr(p, "azote") ? "au dioxyde d'azote" : "(" polluant ")")
}

; Sable du Sahara aujourd'hui ou demain : {demain, poussieres, aod} ou ""
SableAir() {
    if (!AirSable || Donnees.Get("sable_etat", "") != "ok" || !AirFrais("sable_maj") || (dec := DecalageAir("sable")) = "")
        return ""
    for jour in [0, 1] {
        if (jour + dec > 1)
            break
        v := StrSplit(Donnees.Get((jour + dec) ? "sable_j1" : "sable_j", ""), "|")
        if (v.Length >= 2 && IsNumber(v[1]) && IsNumber(v[2]) && Number(v[1]) >= SABLE_POUSSIERES && Number(v[2]) >= SABLE_AOD)
            return {demain: jour = 1, poussieres: Number(v[1]), aod: Number(v[2])}
    }
    return ""
}

; Pollens (indice le plus récent, d'hier au plus) : {code, lib, alerte, date, responsables (texte)} ou ""
PollensAir() {
    if (!AirPollens || Donnees.Get("pol_etat", "") != "ok" || !IsInteger(Donnees.Get("pol_code", "")))
        return ""
    d := StrReplace(Donnees.Get("pol_date", ""), "-")
    if (!IsTime(d) || JoursAvant(Integer(d)) < -1)
        return ""
    niv := 0, resp := []                          ; (jamais « max » : ce serait la fonction Max)
    for t in StrSplit(Donnees.Get("pol_taxons", ""), ",") {
        v := StrSplit(t, ":")
        if (v.Length = 2 && IsInteger(v[2]))
            niv := Max(niv, Integer(v[2]))
    }
    for t in StrSplit(Donnees.Get("pol_taxons", ""), ",") {   ; les taxons au niveau le plus haut
        v := StrSplit(t, ":")
        if (v.Length = 2 && IsInteger(v[2]) && Integer(v[2]) = niv && niv >= 2 && POLLENS_NOMS.Has(v[1]))
            resp.Push(POLLENS_NOMS[v[1]])
    }
    return {code: Integer(Donnees["pol_code"]), lib: Donnees.Get("pol_lib", ""), alerte: Donnees.Get("pol_alerte", "0") = "1",
        date: Integer(d), responsables: JoindreEt(resp)}
}

; Pastilles de la bande (dans l'ordre : épisode, indice, sable, pollens) : [{textes, fond, encre, icone}]
PastillesAir() {
    liste := []
    if (AirMode != "0") {
        ep := EpisodesAir(), e := ""
        for f in ep                               ; un épisode prime sur l'indice : une alerte d'abord
            if (!IsObject(e) || (f.alerte && !e.alerte))
                e := f
        if IsObject(e) {
            quand := e.demain ? " demain" : ""
            proc := e.alerte ? "procédure d'alerte" : "procédure d'information"
            liste.Push({textes: [PicDe(e.polluant) quand " : " proc, PicDe(e.polluant) quand, "Pic de pollution" quand],
                fond: e.alerte ? 0xFFFF5050 : 0xFFF0E641, encre: e.alerte ? 0xFFFFFFFF : 0xFF16191D, icone: "air"})
        }
        if (!liste.Length && AirMode != "episode") {
            seuil := Integer(AirMode)
            for jour in [0, 1]
                if (IsObject(ix := IndiceAir(jour)) && ix.code >= seuil) {
                    quand := jour ? " demain" : ""
                    nom := "Air " StrLower(ix.lib)
                    liste.Push({textes: [nom quand ((ix.polluants != "") ? " · " ix.polluants : ""), nom quand, nom],
                        fond: ix.c, encre: CouleurSur(ix.c), icone: "air"})
                    break
                }
        }
    }
    if IsObject(s := SableAir())
        liste.Push({textes: ["Ciel voilé de sable du Sahara" (s.demain ? " demain" : ""), "Sable du Sahara" (s.demain ? " demain" : "")],
            fond: 0xFFD9A55B, encre: 0xFF16191D, icone: "air"})
    if (IsObject(p := PollensAir()) && (p.code >= 4 || p.alerte)) {
        n := JoursAvant(p.date), quand := (n = 1) ? " demain" : (n = -1) ? " hier" : (n > 1) ? " le " DateCourte(p.date) : ""
        liste.Push({textes: ["Pollens" quand " : " StrLower(p.lib) ((p.responsables != "") ? " (" p.responsables ")" : ""), "Pollens" quand " : " StrLower(p.lib), "Pollens" quand],
            fond: 0xFF8FCB5A, encre: 0xFF16191D, icone: "fleur"})
    }
    return liste
}

; ---------- Fenêtre des prévisions : section « Qualité de l'air » ----------

; Lignes de la section : [{titre, detail, c}] (vide : pas de section)
LignesAir() {
    l := []
    if !AirActif()
        return l
    if (AirMode != "0") {
        etat := Donnees.Get("air_etat", "")
        if (etat = "hors_zone")
            l.Push({titre: "Indice ATMO : Airparif ne couvre que l'Île-de-France", detail: "", c: 0xFF898781})
        else if IsObject(ix := IndiceAir(0)) {
            j1 := IndiceAir(1)
            l.Push({titre: "Aujourd'hui : " StrLower(ix.lib) ((ix.polluants != "") ? " (" ix.polluants ")" : ""),
                detail: IsObject(j1) ? "demain : " StrLower(j1.lib) : "", c: ix.c})
        } else if (etat != "")
            l.Push({titre: "Indice ATMO indisponible pour l'instant", detail: "", c: 0xFF898781})
        for e in EpisodesAir()
            l.Push({titre: PicDe(e.polluant) (e.demain ? " demain" : ""), detail: e.alerte ? "alerte" : "information",
                c: e.alerte ? 0xFFFF5050 : 0xFFF0E641})
    }
    if (AirSable && Donnees.Get("sable_etat", "") = "ok" && AirFrais("sable_maj") && (dec := DecalageAir("sable")) != "") {
        v := StrSplit(Donnees.Get(dec ? "sable_j1" : "sable_j", ""), "|")   ; aujourd'hui
        if (v.Length >= 2 && IsNumber(v[1])) {
            s := SableAir()                       ; (la valeur du jour annoncé : demain, s'il le faut)
            l.Push({titre: IsObject(s) ? "Sable du Sahara" (s.demain ? " demain" : " dans le ciel") : "Pas de sable du Sahara",
                detail: "poussières " StrReplace(Round(IsObject(s) ? s.poussieres : Number(v[1])), ".", ",") " µg/m³", c: IsObject(s) ? 0xFFD9A55B : 0xFF898781})
        }
    }
    if IsObject(p := PollensAir())
        l.Push({titre: "Pollens : " StrLower(p.lib) ((p.responsables != "") ? " (" p.responsables ")" : ""),
            detail: (JoursAvant(p.date) = 0) ? "aujourd'hui" : (JoursAvant(p.date) = 1) ? "demain" : (JoursAvant(p.date) = -1) ? "hier" : DateCourte(p.date), c: 0xFF8FCB5A})
    return l
}

HauteurAir() => (n := LignesAir().Length) ? 42 + 22 * n : 0

SectionAir(L, kp, y0, pal, premier) {
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    if !premier
        Filet(L, X(22), X(y0 + 8), X(418), pal.grille)
    Poser(L, "Qualité de l'air", P_DATE, em(10.5, P_DATE), X(22), X(y0 + 30), 0, pal.second)
    sources := []
    if (AirMode != "0" && Donnees.Get("air_etat", "") = "ok")
        sources.Push("Airparif")
    if AirSable
        sources.Push("CAMS")
    if AirPollens
        sources.Push("Atmo France")
    if sources.Length
        Poser(L, JoindreEt(sources), P_TEXTE, em(9), X(418), X(y0 + 30), 2, pal.discret)
    for i, e in LignesAir() {
        yl := X(y0 + 30 + 22 * i)
        Point(L, X(26), yl - X(4), 3.5 * kp, e.c, 0, pal.surface)
        L[L.Length].brut := true                   ; couleur officielle, jamais teintée
        dt := (e.detail != "") ? Poser(L, e.detail, P_TEXTE, em(10), X(418), yl, 2, pal.second) : {x: X(418)}
        Poser(L, Tronquer(e.titre, P_TEXTE, em(10.5), dt.x - X(36) - X(12)), P_TEXTE, em(10.5), X(36), yl, 0, pal.encre)
    }
}

; ---------- Menu ----------

ChoisirAirMode(v, *) {
    global AirMode := v
    ApresOptionAlerte(AirActif())
}

BasculerAirOption(quoi, *) {
    global AirSable, AirPollens
    if (quoi = "sable")
        AirSable := !AirSable
    else
        AirPollens := !AirPollens
    ApresOptionAlerte(AirActif())
}

; Ligne d'état grisée du sous-menu : « ↳ Créteil : moyen aujourd'hui (ozone) »
MajEtatAir() {
    global LibEtatAir
    if !IsObject(MenuAir)
        return
    etat := Donnees.Get("air_etat", "")
    txt := (AirMode = "0") ? "indice : désactivé"
        : (etat = "hors_zone") ? "hors Île-de-France : pas d'indice Airparif"
        : (etat = "erreur") ? "Airparif injoignable (nouvel essai à la collecte suivante)"
        : IsObject(ix := IndiceAir(0)) ? Donnees.Get("air_zone", "ici") " : " StrLower(ix.lib) " aujourd'hui" ((ix.polluants != "") ? " (" ix.polluants ")" : "")
        : "en attente de la collecte"
    nouveau := "      ↳ " StrReplace(txt, "&", "&&")
    if (nouveau = LibEtatAir)
        return
    try MenuAir.Rename(LibEtatAir, nouveau)
    MenuAir.Disable(nouveau)
    LibEtatAir := nouveau
    ReglAJour()
}

OuvrirCarteAirparif(*) => Run(URL_AIRPARIF)
