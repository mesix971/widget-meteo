; =============================================================================
;  Widget météo — calendrier (menu Afficher ▸ Calendrier : numéro de semaine,
;  jours fériés, vacances scolaires, comptes à rebours) — inclus par
;  widget-meteo.ahk
;
;  Rien n'apparaît que quand c'est utile : un férié la veille et le jour même
;  (un lundi férié dès le vendredi), des vacances dans les 7 jours ou en
;  cours, un compte à rebours. Fériés et semaine sont calculés sur place ; les
;  vacances viennent du calendrier officiel (calendrier.txt, écrit par
;  widget-meteo-donnees.ps1 une fois par semaine) ; les comptes à rebours sont
;  dans reglages.ini, section [comptes].
;  (Constantes et état : LIB_CAL*, ZONES, Cal*, ComptesListe, MenuCalendrier…,
;  déclarés dans widget-meteo.ahk.)
; =============================================================================

; Dimanche de Pâques (algorithme de Meeus, Jones et Butcher), « AAAAMMJJ »
Paques(an) {
    a := Mod(an, 19), b := an // 100, c := Mod(an, 100), d := b // 4, e := Mod(b, 4)
    f := (b + 8) // 25, g := (b - f + 1) // 3, h := Mod(19 * a + b - d - g + 15, 30)
    i := c // 4, k := Mod(c, 4), l := Mod(32 + 2 * e + 2 * i - h - k, 7)
    m := (a + 11 * h + 22 * l) // 451
    return Format("{:04}{:02}{:02}", an, (h + l - 7 * m + 114) // 31, Mod(h + l - 7 * m + 114, 31) + 1)
}

; Jours fériés de métropole d'une année : Map(AAAAMMJJ → nom), comme l'API
; calendrier.api.gouv.fr (vérifié identique de 2006 à 2031) ; un férié mobile
; qui tombe sur un fixe le remplace (2008 : Ascension le 1er mai)
JoursFeries(an) {
    static cache := Map()
    if cache.Has(an)
        return cache[an]
    f := Map()
    for v in [["0101", "1er janvier"], ["0501", "1er mai"], ["0508", "8 mai"], ["0714", "14 juillet"],
            ["0815", "Assomption"], ["1101", "Toussaint"], ["1111", "11 novembre"], ["1225", "Jour de Noël"]]
        f[Integer(an v[1])] := v[2]
    p := Paques(an)
    for v in [[1, "Lundi de Pâques"], [39, "Ascension"], [50, "Lundi de Pentecôte"]]
        f[Integer(FormatTime(DateAdd(p, v[1], "Days"), "yyyyMMdd"))] := v[2]
    cache[an] := f
    return f
}

NomFerie(ymd) => JoursFeries(ymd // 10000).Get(ymd, "")

; Le jour affiché (AAAAMMJJ, entier) et l'écart en jours avec une date
Aujourdhui() => Integer(SubStr(MomentAffiche(), 1, 8))
JoursAvant(ymd) => DateDiff(String(ymd), String(Aujourdhui()), "Days")
PlusJours(ymd, n) => Integer(FormatTime(DateAdd(String(ymd), n, "Days"), "yyyyMMdd"))

; « dim. 1er nov. », « lun. 2 nov. » (« … 2026 » si demandé)
DateCourte(ymd, avecAnnee := false) {
    t := String(ymd), j := Integer(SubStr(t, 7, 2))
    return FormatTime(t, "ddd ") ((j = 1) ? "1er" : j) FormatTime(t, " MMM") (avecAnnee ? FormatTime(t, " yyyy") : "")
}

; Relit calendrier.txt s'il a changé : les périodes de vacances (entiers
; AAAAMMJJ ; reprise = jour de la rentrée, 0 si inconnue). Renvoie true si ça a changé.
LireCalendrier() {
    global CalPeriodes, CalDate, CalZoneLue
    f := DOSSIER "\calendrier.txt"
    if !FileExist(f) {
        if (CalDate = "")
            return false
        CalPeriodes := [], CalDate := "", CalZoneLue := ""
        return true
    }
    m := FileGetTime(f, "M")
    if (m = CalDate)
        return false
    per := [], zone := ""
    try {
        for ligne in StrSplit(FileRead(f, "UTF-8"), "`n", "`r") {
            if (SubStr(ligne, 1, 5) = "zone=")
                zone := SubStr(ligne, 6)
            if (SubStr(ligne, 1, 2) != "V|")
                continue
            v := StrSplit(ligne, "|", , 4)
            if (v.Length < 4 || !RegExMatch(v[2], "^\d{4}-\d{2}-\d{2}$"))
                continue
            per.Push({debut: Integer(StrReplace(v[2], "-")), reprise: (v[3] != "") ? Integer(StrReplace(v[3], "-")) : 0, nom: v[4]})
        }
    } catch
        return false
    CalPeriodes := per, CalDate := m, CalZoneLue := zone
    return true
}

; Les dates de vacances sont-elles là, pour la bonne zone ?
CalendrierValide() => CalPeriodes.Length && CalZoneLue = CalZone

; Période de vacances en cours un jour donné (une fin inconnue vaut 70 jours), sinon ""
EnVacances(ymd) {
    for p in CalPeriodes {
        fin := p.reprise ? p.reprise : PlusJours(p.debut, 70)
        if (p.debut <= ymd && ymd < fin)
            return p
    }
    return ""
}

; Comptes à rebours : section [comptes] de reglages.ini, « n=AAAA-MM-JJ|libellé »
; (date unique) ou « n=MM-JJ|libellé » (chaque année)
LireComptes() {
    global ComptesListe, ComptesVersion
    ComptesListe := []
    try sec := IniRead(F_REGLAGES, "comptes")
    catch
        sec := ""
    for ligne in StrSplit(sec, "`n", "`r") {
        if !(p := InStr(ligne, "="))
            continue
        val := SubStr(ligne, p + 1)
        if !(q := InStr(val, "|"))
            continue
        d := SubStr(val, 1, q - 1), lib := SubStr(val, q + 1)
        ; la date doit exister (31/11, 30/02… feraient échouer chaque rendu) ; 2000 est bissextile : le 29/02 passe
        if (RegExMatch(d, "^\d{4}-\d{2}-\d{2}$") && IsTime(StrReplace(d, "-")))
            ComptesListe.Push({date: d, lib: lib, annuel: false})
        else if (RegExMatch(d, "^\d{2}-\d{2}$") && IsTime("2000" StrReplace(d, "-")))
            ComptesListe.Push({date: d, lib: lib, annuel: true})
        else
            Journal("compte à rebours ignoré (date impossible) : " ligne)
    }
    ComptesVersion += 1
}

SauverComptes() {
    global ComptesVersion
    try IniDelete(F_REGLAGES, "comptes")
    for i, c in ComptesListe
        IniWrite(c.date "|" c.lib, F_REGLAGES, "comptes", i)
    ComptesVersion += 1
}

; Prochaine date d'un compte (AAAAMMJJ) : un annuel repart l'année suivante
; une fois passé ; un 29/02 devient le 28/02 les années non bissextiles
ProchaineDate(c) {
    if !c.annuel
        return Integer(StrReplace(c.date, "-"))
    auj := Aujourdhui(), an := auj // 10000, md := StrReplace(c.date, "-")
    Loop 2 {
        d := an md
        if (!IsTime(d) && md = "0229")
            d := an "0228"
        if (Integer(d) >= auj)
            return Integer(d)
        an += 1
    }
    return Integer(d)
}

; Date saisie : JJ/MM/AAAA, JJ/MM/AA, JJ.MM.AAAA, JJ-MM-AAAA, AAAA-MM-JJ, ou
; JJ/MM (chaque année) → « AAAA-MM-JJ » ou « MM-JJ »
LireDateSaisie(txt, &ymd, &annuel) {
    txt := Trim(txt)
    if RegExMatch(txt, "^(\d{4})-(\d{1,2})-(\d{1,2})$", &o)
        an := o[1], mo := o[2], j := o[3], annuel := false
    else if RegExMatch(txt, "^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})$", &o)
        j := o[1], mo := o[2], an := (StrLen(o[3]) = 2) ? "20" o[3] : o[3], annuel := false
    else if RegExMatch(txt, "^(\d{1,2})[/.\-](\d{1,2})$", &o)
        j := o[1], mo := o[2], an := "2000", annuel := true
    else
        return false
    if !IsTime(Format("{:04}{:02}{:02}", Integer(an), Integer(mo), Integer(j)))
        return false
    ymd := annuel ? Format("{:02}-{:02}", Integer(mo), Integer(j)) : Format("{:04}-{:02}-{:02}", Integer(an), Integer(mo), Integer(j))
    return true
}

AjouterCompte(*) {
    global CalComptes
    if (ComptesListe.Length >= 10) {
        MsgBox("10 comptes à rebours au plus : supprime-en un d'abord.", "Compte à rebours", "Iconi")
        return
    }
    r := InputBox("Nom de l'événement (40 caractères au plus)", "Compte à rebours")
    if (r.Result != "OK" || Trim(r.Value) = "")
        return
    lib := SubStr(Trim(r.Value), 1, 40)
    invite := "Date de « " lib " » :`nJJ/MM/AAAA, ou JJ/MM pour chaque année (anniversaire)"
    Loop {
        r := InputBox(invite, "Compte à rebours")
        if (r.Result != "OK")
            return
        if !LireDateSaisie(r.Value, &ymd, &annuel) {
            invite := "Date non reconnue : « " r.Value " ».`nJJ/MM/AAAA, ou JJ/MM pour chaque année (anniversaire)"
            continue
        }
        if (!annuel && Integer(StrReplace(ymd, "-")) < Aujourdhui()) {
            invite := "Cette date est déjà passée.`nJJ/MM/AAAA, ou JJ/MM pour chaque année (anniversaire)"
            continue
        }
        break
    }
    ComptesListe.Push({date: ymd, lib: lib, annuel: annuel})
    SauverComptes()
    if !CalComptes {                              ; action explicite : l'option suit
        CalComptes := true
        SauverReglages()
        TrayTip("« Comptes à rebours » est maintenant activé.", "Calendrier")
    }
    MajMenuComptes()
    CocherMenus()
    Redessiner()
}

SupprimerCompte(i, *) {
    if (i > ComptesListe.Length)
        return
    c := ComptesListe[i]
    if (MsgBox("Supprimer le compte à rebours « " c.lib " » ?", "Compte à rebours", "YesNo Icon?") != "Yes")
        return
    ; la liste a pu changer pendant la question (autre suppression) : on retire CET objet
    trouve := 0
    for k, x in ComptesListe
        if (x = c) {
            trouve := k
            break
        }
    if !trouve
        return
    ComptesListe.RemoveAt(trouve)
    SauverComptes()
    MajMenuComptes()
    Redessiner()
}

; Les comptes à rebours à supprimer : [[libellé de menu, commande], …]
; (numérotés : deux comptes identiques ne doivent pas se confondre ; « & » doublé)
ComptesSuppr() {
    liste := []
    for i, c in ComptesListe {
        d := ProchaineDate(c)
        liste.Push([i ". " StrReplace(c.lib, "&", "&&") " — " DateCourte(d, !c.annuel)
            . (c.annuel ? " (chaque année)" : "") ((!c.annuel && d < Aujourdhui()) ? " (passé)" : ""), SupprimerCompte.Bind(i)])
    }
    return liste
}

; Sous-menu de suppression, reconstruit à chaque changement (la fenêtre Réglages
; construit le sien avec ComptesSuppr)
MajMenuComptes() {
    MenuComptesSuppr.Delete()
    if !ComptesListe.Length {
        MenuComptesSuppr.Add("(aucun)", (*) => 0)
        MenuComptesSuppr.Disable("(aucun)")
        return
    }
    for e in ComptesSuppr()
        MenuComptesSuppr.Add(e[1], e[2])
}

; Événements du jour, du plus important au moins important :
; [{rang, genre (ferie, vacances, compte), long, court, date}]
; compte du jour > férié du jour > férié à venir > veille de vacances ou de
; rentrée > compte du lendemain > vacances en cours > vacances à venir > compte
EvenementsCalendrier() {
    static cle := "", ev := []
    auj := Aujourdhui()
    c := auj "|" CalDate "|" CalZone "|" ComptesVersion "|" CalFeries CalVacances CalComptes "|" CalFeriesAvance "|" CalVacancesAvance "|" CalComptesAvance "|" JoursVersion "|" CalHeure CalSaisons "|" AnnivVersion "|" CielEtoiles
        . "|" (CielEtoiles ? Donnees.Get("nuits", "") : "") "|" (CalHeure ? CleHeureChangee() : "")   ; (nuages prévus ; changement d'heure de la nuit fait ou non)
    if (c = cle)
        return ev
    ev := [], j := Chr(0xA0) "j"                  ; « dans 7 j », espace insécable
    if CalFeries
        Loop 8 {                                  ; le prochain férié annoncé (un lundi : dès le vendredi)
            n := A_Index - 1, d := PlusJours(auj, n), nom := NomFerie(d)
            if (nom = "" || (n > CalFeriesAvance && !(FormatTime(String(d), "WDay") = 2 && n <= 3)))
                continue
            if (n = 0)
                ev.Push({rang: 2, genre: "ferie", long: "Férié : " nom, court: "Férié", date: d})
            else if (n = 1)
                ev.Push({rang: 3, genre: "ferie", long: "Férié demain : " nom, court: "Férié demain", date: d})
            else {
                jour := FormatTime(String(d), "dddd")
                ev.Push({rang: 3, genre: "ferie", long: "Férié " jour " : " nom, court: "Férié " jour, date: d})
            }
            break
        }
    if (CalVacances && CalendrierValide()) {    ; dates d'une autre zone (changée hors ligne) : rien plutôt que faux
        per := EnVacances(auj)
        if IsObject(per) {
            if !per.reprise
                ev.Push({rang: 6, genre: "vacances", long: per.nom, court: "Vacances", date: auj})
            else if (JoursAvant(per.reprise) <= 1)
                ev.Push({rang: 4, genre: "vacances", long: "Rentrée demain", court: "Rentrée demain", date: per.reprise})
            else
                ev.Push({rang: 6, genre: "vacances", long: per.nom ", rentrée " DateCourte(per.reprise), court: "Rentrée " DateCourte(per.reprise), date: per.reprise})
        } else
            for p in CalPeriodes
                if (p.debut > auj) {
                    n := JoursAvant(p.debut), mot := (SubStr(p.nom, 1, 4) = "Pont") ? "Pont" : "Vacances"
                    if (n = 1)
                        ev.Push({rang: 4, genre: "vacances", long: p.nom " demain", court: mot " demain", date: p.debut})
                    else if (n <= CalVacancesAvance)
                        ev.Push({rang: 7, genre: "vacances", long: p.nom " dans " n j, court: mot " dans " n j, date: p.debut})
                    break
                }
    }
    if CalComptes
        for co in ComptesListe {
            d := ProchaineDate(co), n := JoursAvant(d)
            if (n < 0 || (CalComptesAvance && n > CalComptesAvance))
                continue
            if (n = 0)
                ev.Push({rang: 1, genre: "compte", long: "Aujourd'hui : " co.lib, court: co.lib, date: d, lib: co.lib, suf: ""})
            else if (n = 1)
                ev.Push({rang: 5, genre: "compte", long: co.lib " demain", court: co.lib " J-1", date: d, lib: co.lib, suf: " J-1"})
            else
                ev.Push({rang: 8, genre: "compte", long: co.lib " dans " n j, court: co.lib " J-" n, date: d, lib: co.lib, suf: " J-" n})
        }
    for e in EvenementsJours(auj)                ; Mes jours : un type annoncé qui arrive, ou en cours
        ev.Push(e)
    for e in EvenementsLumiere(auj)              ; changement d'heure, équinoxe ou solstice (dès J-3)
        ev.Push(e)
    for e in EvenementsAnniv(auj)                ; anniversaires : le jour J (en tête) et la veille
        ev.Push(e)
    for e in EvenementsCiel(auj)                 ; une grande nuit d'étoiles filantes
        ev.Push(e)
    ; tri par rang puis par date (insertion : quelques éléments)
    Loop ev.Length - 1 {
        i := A_Index + 1, e := ev[i], k := i - 1
        while (k >= 1 && (ev[k].rang > e.rang || (ev[k].rang = e.rang && ev[k].date > e.date)))
            ev[k + 1] := ev[k], k--
        ev[k + 1] := e
    }
    cle := c
    return ev
}

CalendrierActif() => CalFeries || CalVacances || CalComptes || CalHeure || CalSaisons || JoursAnnonce() || AnnivExistent() || CielEtoiles

; Ligne calendrier (Android, Épuré) : les événements qui tiennent dans
; « largeur », du plus important au moins important
TexteCalendrier(em, largeur) {
    ev := EvenementsCalendrier()
    if !ev.Length
        return ""
    Tient(s) => LargeurTexte(s, P_TEXTE, em) <= largeur
    e1 := ev[1]
    if Tient(e1.long)
        txt := e1.long
    else if Tient(e1.court)
        txt := e1.court
    else if e1.HasOwnProp("suf")                  ; seul le libellé se raccourcit : « … J-5 » reste entier
        txt := Tronquer(e1.lib, P_TEXTE, em, largeur - (LargeurTexte("x" e1.suf, P_TEXTE, em) - LargeurTexte("x", P_TEXTE, em))) e1.suf
    else
        txt := Tronquer(e1.court, P_TEXTE, em, largeur)
    Loop ev.Length - 1 {
        e := ev[A_Index + 1]
        if Tient(txt "  ·  " e.long)
            txt .= "  ·  " e.long
        else if Tient(txt "  ·  " e.court)
            txt .= "  ·  " e.court
        else
            break
    }
    return txt
}

; La ligne de date (iPhone, En toutes lettres, Analogique) : à partir de x
; (align 0) ou centrée sur x (align 1), dans la largeur « dispo »
PoserDate(L, em, cap, x, yb, align, dispo, couleur) {
    txt := LigneDate(em, dispo), n0 := L.Length
    bd := Poser(L, txt, P_DATE, em, x, yb, align, couleur)
    MarqueDate(L, n0, bd, txt, PartieDate(txt), P_DATE, em, cap, yb)   ; Mes jours : la couleur du type du jour
    return bd
}

; Ligne de date (iPhone, lettres, analogique) : la date, puis en option la
; semaine et l'événement le plus important, la forme la plus complète qui tient
LigneDate(em, dispo, police := "") {
    police := (police = "") ? P_DATE : police
    mo := MomentAffiche()
    dL := Majuscule(FormatTime(mo, "dddd d MMMM")), dM := Majuscule(FormatTime(mo, "ddd d MMMM"))
    dC := Majuscule(FormatTime(mo, "ddd d MMM"))
    s := CalSemaine ? "S" Integer(SubStr(FormatTime(mo, "YWeek"), 5)) : ""
    ev := CalendrierActif() ? EvenementsCalendrier() : []
    Joindre(morceaux*) {
        r := ""
        for m in morceaux
            if (m != "")
                r .= ((r = "") ? "" : "  ·  ") m
        return r
    }
    if ev.Length
        candidats := [Joindre(dL, s, ev[1].long), Joindre(dM, s, ev[1].long), Joindre(dC, s, ev[1].long),
            Joindre(dC, s, ev[1].court), Joindre(dC, ev[1].court)]
    else
        candidats := []
    for c in [Joindre(dL, s), Joindre(dM, s), Joindre(dC, s), dC]  ; sinon sans l'événement (tronqué, il ne dirait rien)
        candidats.Push(c)
    for c in candidats
        if (LargeurTexte(c, police, em) <= dispo)
            return c
    return Tronquer(candidats[candidats.Length], police, em, dispo)
}

; Pour la fenêtre des prévisions : [{genre, titre, detail}] (6 au plus) : Mes jours,
; prochain férié, vacances en cours ou prochaines, 3 comptes les plus proches
ListeCalendrier() {
    liste := [], auj := Aujourdhui(), j := Chr(0xA0) "j"
    Quand(d) {
        n := JoursAvant(d)
        return (n = 0) ? "aujourd'hui" : (n = 1) ? "demain" : "dans " n j
    }
    if CalFeries
        Loop 366 {
            d := PlusJours(auj, A_Index - 1), nom := NomFerie(d)
            if (nom != "") {
                liste.Push({genre: "ferie", titre: nom " (férié)", detail: DateCourte(d) " · " Quand(d)})
                break
            }
        }
    if (CalVacances && !CalendrierValide())
        liste.Push({genre: "vacances", titre: "Vacances scolaires (zone " CalZone ")", detail: "dates pas encore reçues"})
    else if CalVacances {
        per := EnVacances(auj)
        if IsObject(per)
            liste.Push({genre: "vacances", titre: per.nom, detail: per.reprise ? "rentrée " DateCourte(per.reprise) : "en cours"})
        else
            for p in CalPeriodes
                if (p.debut > auj) {
                    fin := p.reprise ? " → " DateCourte(PlusJours(p.reprise, -1)) : ""
                    liste.Push({genre: "vacances", titre: p.nom, detail: DateCourte(p.debut) fin " · " Quand(p.debut)})
                    break
                }
    }
    if CalComptes {
        prochains := []
        for co in ComptesListe {
            d := ProchaineDate(co)
            if (JoursAvant(d) >= 0)
                prochains.Push({d: d, lib: co.lib})
        }
        Loop prochains.Length - 1 {               ; les plus proches d'abord
            i := A_Index + 1, e := prochains[i], k := i - 1
            while (k >= 1 && prochains[k].d > e.d)
                prochains[k + 1] := prochains[k], k--
            prochains[k + 1] := e
        }
        for e in prochains {
            if (A_Index > 3)
                break
            liste.Push({genre: "compte", titre: e.lib, detail: DateCourte(e.d) " · " Quand(e.d)})
        }
    }
    for e in ListeJours(auj)                    ; Mes jours : la période en cours ou la prochaine, en tête
        liste.InsertAt(A_Index, e)
    for e in ListeAnniv(auj)                    ; les 3 prochains anniversaires (60 jours)
        liste.Push(e)
    for e in ListeLumiere(auj)                  ; prochaine saison, prochain changement d'heure
        liste.Push(e)
    return liste
}

; Petite icône calendrier dessinée au trait, comme l'épingle du lieu
IconeCalendrier(L, cx, cy, u, couleur) {
    ep := 0.0068 * u
    gx := cx - 0.030 * u, gy := cy - 0.028 * u + 0.004 * u, lg := 0.060 * u, ht := 0.056 * u
    p := CheminArrondi(gx, gy, lg, ht, 0.010 * u)
    Elargir(p, ep)
    L.Push({p: p, f: couleur, o: OmbreTheme(), z: false})
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &b := 0)
    DllCall("gdiplus\GdipAddPathRectangle", "Ptr", b, "Float", gx, "Float", gy, "Float", lg, "Float", 0.016 * u)
    L.Push({p: b, f: couleur, o: OmbreTheme(), z: false})
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &a := 0)
    for fr in [0.3, 0.7] {
        DllCall("gdiplus\GdipStartPathFigure", "Ptr", a)
        DllCall("gdiplus\GdipAddPathLine", "Ptr", a, "Float", gx + fr * lg, "Float", gy - 0.010 * u, "Float", gx + fr * lg, "Float", gy + 0.006 * u)
    }
    Elargir(a, ep)
    L.Push({p: a, f: couleur, o: OmbreTheme(), z: false})
}

BasculerCal(quoi, *) {
    global CalSemaine, CalFeries, CalVacances, CalComptes, CalPrevisions, CalHeure, CalSaisons
    switch quoi {
        case "semaine":    CalSemaine := !CalSemaine
        case "feries":     CalFeries := !CalFeries
        case "vacances":   CalVacances := !CalVacances
        case "comptes":    CalComptes := !CalComptes
        case "previsions": CalPrevisions := !CalPrevisions
        case "heure":      CalHeure := !CalHeure
        case "saisons":    CalSaisons := !CalSaisons
    }
    SauverReglages()
    CocherMenus()
    if (quoi = "vacances" && CalVacances && !CalendrierValide())
        LancerCollecte(false, true, true)          ; dates pas encore là : on les demande tout de suite
    Redessiner()
}

ChoisirZone(z, *) {
    global CalZone := z
    SauverReglages()
    CocherMenus()
    if CalVacances
        LancerCollecte(false, true, true)
    Redessiner()
}

; Mode de test /testferies <metropole.json> <rapport> : JoursFeries contre l'API
TestFeries(json, rapport) {
    txt := FileRead(json, "UTF-8"), api := Map(), pos := 1, ecarts := 0, sortie := ""
    while (pos := RegExMatch(txt, '"(\d{4})-(\d{2})-(\d{2})"\s*:\s*"([^"]*)"', &o, pos)) {
        nom := o[4]
        while RegExMatch(nom, "\\u([0-9a-fA-F]{4})", &e)
            nom := StrReplace(nom, e[0], Chr(Integer("0x" e[1])))
        api[Integer(o[1] o[2] o[3])] := nom
        pos += o.Len[0]
    }
    ans := Map()
    for d in api
        ans[d // 10000] := 1
    calcul := 0
    for an in ans {
        for d, nom in JoursFeries(an) {
            calcul++
            if (api.Get(d, "") != nom)
                ecarts++, sortie .= "écart " d " : calcul « " nom " », API « " api.Get(d, "(absent)") " »`n"
        }
    }
    for d, nom in api
        if (JoursFeries(d // 10000).Get(d, "") = "")
            ecarts++, sortie .= "manque " d " « " nom " »`n"
    try FileDelete(rapport)
    FileAppend("API " api.Count " dates, calcul " calcul " dates, écarts " ecarts "`n" sortie, rapport, "UTF-8")
}
