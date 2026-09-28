; =============================================================================
;  Widget météo — « Mes jours » : jours de travail, de repos, congés… une
;  couleur par type (menu Afficher ▸ Calendrier ▸ Mes jours)
;  — inclus par widget-meteo.ahk
;
;  Des types de jour (nom et couleur au choix : Travail, Repos, Congé…), une
;  base qui se répète — un cycle (roulement de N jours, « 2-2-3 » sur 14 jours,
;  valable des années) ou à défaut une semaine type (« chaque lundi : Travail »)
;  — et des jours posés un par un, qui passent devant (« - » : rien ce jour-là).
;  Sur le widget, la date du jour prend la couleur de son type (le nom du jour
;  seul, « Jeudi », ou la date soulignée ou surlignée, au choix) ; un type
;  « annoncé » (Congé) l'est la veille dans la ligne du calendrier (« Congé
;  lundi »), puis pendant sa période (« Congé, reprise mer. 30 sept. »), avec
;  sa prochaine période dans les prévisions détaillées. Un type « non
;  travaillé » (Repos, Congé) ne coupe pas une période de congé.
;
;  Fichier DOSSIER\jours.txt (UTF-8, jamais dans le dépôt : c'est ton planning) :
;    T|id|nom|RRGGBB|annoncé|non travaillé (0 ou 1)   un type
;    S|n° du jour (1 = lundi … 7)|id                   la semaine type
;    C|AAAA-MM-JJ|id,id,…,id                           un cycle de N jours qui part de
;                                                      cette date (« - » : rien ce jour
;                                                      du cycle ; liste vide : plus de
;                                                      cycle) ; il vaut jusqu'au suivant
;    J|AAAA-MM-JJ|id ou -                              un jour posé
;  Une ligne non comprise (modifiée à la main) est gardée telle quelle en fin de
;  fichier, et notée au journal.
; =============================================================================

; ---------- Données ----------

; Types du premier lancement : Travail en bleu, Repos en violet, Congé en vert (annoncé)
JoursDefaut() => [{id: "travail", nom: "Travail", c: 0xFF3987E5, annonce: false, repos: false},
    {id: "repos", nom: "Repos", c: 0xFFBF5AF2, annonce: false, repos: true},
    {id: "conge", nom: "Congé", c: 0xFF30D158, annonce: true, repos: true}]

TypeParId(types, id) {
    for ty in types
        if (ty.id = id)
            return ty
    return ""
}

; Relit jours.txt s'il a changé (ou les types par défaut s'il n'existe pas) ;
; renvoie true si c'est le cas
LireJours() {
    global JoursTypes, JoursSemaine, JoursPoses, JoursCycles, JoursRejets, JoursDate, JoursVersion, JoursPinceau
    Resoudre(id) {                                ; l'id d'un type, ou le nom d'un type (fichier modifié à la main), ou ""
        id := Trim(id)
        if (id = "-")
            return id
        if IsObject(ty := TypeParId(types, id))
            return ty.id
        for ty in types
            if !StrCompare(ty.nom, id, "Locale")
                return ty.id
        return ""
    }
    m := FileExist(F_JOURS) ? FileGetTime(F_JOURS, "M") : "absent"
    if (m = JoursDate)
        return false
    types := [], sem := Map(), poses := Map(), cycles := Map(), rejets := [], bruts := []
    if (m != "absent")
        try {
            for ligne in StrSplit(FileRead(F_JOURS, "UTF-8"), "`n", "`r") {
                if (Trim(ligne) = "" || SubStr(ligne, 1, 1) = "#")
                    continue
                v := StrSplit(ligne, "|"), genre := StrUpper(Trim(v[1])), coul := (v.Length >= 4) ? LTrim(Trim(v[4]), "#") : ""
                if (v.Length >= 4 && genre = "T" && RegExMatch(v[2], "(*UCP)^\w+$") && RegExMatch(coul, "^[0-9A-Fa-f]{6}$")
                    && !IsObject(TypeParId(types, v[2])) && types.Length < JOURS_TYPES_MAX)
                    types.Push({id: v[2], nom: NomTypePropre(v[3]), c: 0xFF000000 | Integer("0x" coul), annonce: v.Length >= 5 && v[5] = "1",
                        repos: (v.Length >= 6) ? v[6] = "1" : (v[2] = "repos" || v[2] = "conge")})   ; (avant 2.26 : Repos et Congé)
                else if (v.Length >= 3 && ((genre = "S" && RegExMatch(v[2], "^[1-7]$"))
                    || ((genre = "J" || genre = "C") && RegExMatch(v[2], "^\d{4}-\d{2}-\d{2}$") && IsTime(StrReplace(v[2], "-")))))
                    bruts.Push({genre: genre, cle: Integer(StrReplace(v[2], "-")), val: v[3], ligne: ligne})
                else
                    rejets.Push(ligne)
            }
        } catch as e {
            Journal("Mes jours : lecture impossible (" e.Message ")")
            return false
        }
    if !types.Length
        types := JoursDefaut()
    for b in bruts {                              ; (une fois les types connus)
        switch b.genre {
            case "S", "J":                        ; un type disparu : la ligne est gardée à part
                if ((r := Resoudre(b.val)) = "")
                    rejets.Push(b.ligne)
                else if (b.genre = "S")
                    sem[b.cle] := r
                else
                    poses[b.cle] := r
            case "C":                             ; un id inconnu reste tel quel (rien ce jour-là) : le rythme ne bouge pas
                if cycles.Has(b.cle)
                    Journal("Mes jours : deux cycles le " DateTiret(b.cle) ", le dernier est gardé")
                motif := []
                if (Trim(b.val) != "")
                    for el in StrSplit(b.val, ",") {
                        el := Trim(el)
                        motif.Push((el = "" || el = "-") ? "-" : ((r := Resoudre(el)) != "") ? r : el)
                    }
                cycles[b.cle] := motif
        }
    }
    if rejets.Length                              ; (gardées telles quelles en fin de fichier)
        Journal("Mes jours : " rejets.Length " ligne(s) de jours.txt non comprise(s), dont « " rejets[1] " »")
    JoursTypes := types, JoursSemaine := sem, JoursPoses := poses, JoursCycles := cycles, JoursRejets := rejets
    JoursDate := m
    JoursVersion += 1
    if (JoursPinceau != "-" && !IsObject(TypeParId(types, JoursPinceau)))   ; (un type disparu : pas de pinceau fantôme)
        JoursPinceau := types[1].id
    return true
}

; jours.txt changé hors de la fenêtre (à la main) et relu : l'annulation
; réécrirait un état d'avant ce changement, elle est oubliée
JoursRelu() {
    global JoursAnnulable := ""
    PeindreJours()
}

; Un nom de type : sans « | », « , » ni retour à la ligne, 24 caractères au plus
NomTypePropre(t) => SubStr(Trim(RegExReplace(t, "[|,\r\n]", " ")), 1, 24)

DateTiret(d) => SubStr(d, 1, 4) "-" SubStr(d, 5, 2) "-" SubStr(d, 7, 2)

; Enregistre jours.txt ; « lib » : ce qui a changé (pour « Annuler : … »)
SauverJours(lib := "modification") {
    global JoursVersion, JoursAnnulable, JoursAnnulLib, JoursAnnulSens
    txt := "# Mes jours (widget météo) — T|id|nom|couleur|annoncé|non travaillé  S|jour (1 = lundi)|id  "
        . "C|début|id,id,… (cycle, vide : arrêt)  J|date|id (- : rien)`n"
    for ty in JoursTypes
        txt .= "T|" ty.id "|" ty.nom "|" Format("{:06X}", ty.c & 0xFFFFFF) "|" (ty.annonce ? 1 : 0) "|" (ty.repos ? 1 : 0) "`n"
    for n, id in JoursSemaine
        txt .= "S|" n "|" id "`n"
    for d, motif in JoursCycles {                 ; (une Map se parcourt dans l'ordre des clés : les dates dans l'ordre)
        liste := ""
        for id in motif
            liste .= ((A_Index > 1) ? "," : "") id
        txt .= "C|" DateTiret(d) "|" liste "`n"
    }
    for d, id in JoursPoses
        txt .= "J|" DateTiret(d) "|" id "`n"
    if JoursRejets.Length {
        txt .= "# Lignes non comprises, gardées telles quelles :`n"
        for l in JoursRejets
            txt .= l "`n"
    }
    JoursCopieExterne()
    ancien := ""
    try ancien := FileExist(F_JOURS) ? FileRead(F_JOURS, "UTF-8") : ""
    if (EcrireJoursTexte(txt) && ancien != "" && ancien !== txt)   ; (!== : « Travail » → « TRAVAIL » compte)
        JoursAnnulable := ancien, JoursAnnulLib := SubStr(lib, 1, 80), JoursAnnulSens := "Annuler"   ; un seul niveau
    JoursVersion += 1
}

; jours.txt changé à la main depuis sa lecture (pendant une boîte de dialogue,
; la fenêtre reste ouverte) : copie gardée avant de l'écraser, et notée au journal
JoursCopieExterne() {
    try {
        if (FileExist(F_JOURS) && FileGetTime(F_JOURS, "M") != JoursDate) {
            copie := RegExReplace(F_JOURS, "i)\.txt$", "") "-modifie-a-la-main-" FormatTime(, "yyyyMMdd-HHmmss") ".txt"
            FileCopy(F_JOURS, copie, 1)
            Journal("Mes jours : jours.txt changé hors de la fenêtre, gardé dans " copie " avant d'être remplacé")
            TrayTip("jours.txt avait été modifié à la main pendant que Mes jours était ouvert. Cette version est gardée dans "
                . copie ".", "Widget météo : Mes jours")
        }
    }
}

; Écriture atomique de jours.txt (le widget ne relit jamais un fichier à moitié écrit)
EcrireJoursTexte(txt) {
    global JoursDate
    try {
        DirCreate(DOSSIER)
        tmp := F_JOURS ".tmp"
        try FileDelete(tmp)
        FileAppend(txt, tmp, "UTF-8-RAW")
        FileMove(tmp, F_JOURS, 1)
        JoursDate := FileGetTime(F_JOURS, "M")
        return true
    } catch as e {
        Journal("Mes jours : enregistrement impossible (" e.Message ")")
        return false
    }
}

; Copie de secours avant la 1re opération qui touche beaucoup de jours (cycle,
; type supprimé) : gardée ensuite (lisible par une version sans cycles) ; pour
; le reste, Ctrl+Z
JoursCopieAvant() {
    base := RegExReplace(F_JOURS, "i)\.txt$", "")
    if !FileExist(base "-avant-cycle.txt")        ; celle d'avant le 1er cycle : gardée (lisible par une version sans cycles)
        try FileCopy(F_JOURS, base "-avant-cycle.txt")
    try FileCopy(F_JOURS, base "-avant-derniere-operation.txt", 1)   ; et celle d'avant la dernière opération lourde
}

; Numéro du jour de la semaine : 1 = lundi … 7 = dimanche
JourISO(ymd) => Mod(Integer(FormatTime(String(ymd), "WDay")) + 5, 7) + 1

; Le cycle en vigueur au jour ymd : {debut, motif}, ou "" (aucun, ou arrêté)
CycleDe(ymd) {
    c := ""
    for d, motif in JoursCycles {
        if (d > ymd)
            break
        c := motif.Length ? {debut: d, motif: motif} : ""
    }
    return c
}

; Rang (1 à N) du jour ymd dans le cycle cy ; jamais négatif, même avant son début
RangCycle(cy, ymd) => Mod(Mod(DateDiff(String(ymd), String(cy.debut), "Days"), cy.motif.Length) + cy.motif.Length, cy.motif.Length) + 1

; Le type de base d'un jour (sans les jours posés) : celui du cycle en vigueur,
; sinon de la semaine type (ignorée en entier sous un cycle) ; un id, ou ""
BaseDuJour(ymd) {
    if IsObject(cy := CycleDe(ymd))
        return ((id := cy.motif[RangCycle(cy, ymd)]) = "-") ? "" : id
    return JoursSemaine.Get(JourISO(ymd), "")
}

; Type d'un jour (le jour posé, sinon la base) : l'objet, ou ""
TypeDuJour(ymd) {
    id := JoursPoses.Get(ymd, "")
    if (id = "")
        id := BaseDuJour(ymd)
    return (id = "" || id = "-") ? "" : TypeParId(JoursTypes, id)
}

IdDuJour(ymd) => IsObject(ty := TypeDuJour(ymd)) ? ty.id : ""

JoursUtilises() => JoursPoses.Count || JoursSemaine.Count || JoursCycles.Count

; Un type annoncé est-il en usage ? (le calendrier a alors quelque chose à dire)
JoursAnnonce() {
    if !JoursUtilises()
        return false
    for ty in JoursTypes
        if ty.annonce
            return true
    return false
}

; Un jour « - » d'un cycle (rien de posé) : un jour de repos laissé sans type
VideDuCycle(ymd) => !JoursPoses.Has(ymd) && IsObject(CycleDe(ymd))

; Dernier jour de la période du type « id » qui commence à ymd (400 jours au
; plus : un congé parental passe). 3 jours sans type de suite (un week-end)
; ne la coupent pas ; pour un type non travaillé (Congé), les jours non
; travaillés (Repos, « - » d'un cycle) non plus, sur 7 jours d'écart au plus.
; Tout autre type la coupe (et un « - » de cycle, un type travaillé : Nuit).
FinPeriode(ymd, id, &auBout := false) {
    ty0 := TypeParId(JoursTypes, id), off := IsObject(ty0) && ty0.repos
    d := ymd, s := ymd, vides := 0, ecart := 0, coupe := false
    Loop 400 {
        s := PlusJours(s, 1), ty := TypeDuJour(s)
        if (IsObject(ty) && ty.id = id)
            d := s, vides := 0, ecart := 0
        else if (!IsObject(ty) && VideDuCycle(s))
            coupe := !off || ++ecart > 7, vides := 0
        else if !IsObject(ty)
            coupe := ++vides > 3 || ++ecart > 7
        else if (off && ty.repos)
            coupe := ++ecart > 7, vides := 0
        else
            coupe := true
        if coupe
            break
    }
    auBout := !coupe                              ; (plus de 400 jours : la vraie fin n'est pas encore connue)
    return d
}

; Jour de reprise après une période qui finit à « fin » : le premier jour d'un
; type travaillé (les jours sans type, 3 de suite au plus, et non travaillés
; sont sautés) ; "" si on ne le sait pas
RepriseApres(fin) {
    s := fin, vides := 0
    Loop 14 {
        s := PlusJours(s, 1), ty := TypeDuJour(s)
        if (!IsObject(ty) && VideDuCycle(s))
            vides := 0                            ; (un repos du cycle laissé sans type)
        else if !IsObject(ty) {
            if (++vides > 3)
                return ""
        } else if !ty.repos
            return s
        else
            vides := 0
    }
    return ""
}

; La période d'un type annoncé en cours aujourd'hui : {ty, fin}, ou "". Un jour
; de repos au milieu d'un congé en fait partie (le congé reprend après).
PeriodeEnCours(auj) {
    t0 := TypeDuJour(auj)
    if (IsObject(t0) && t0.annonce)
        return {ty: t0, fin: FinPeriode(auj, t0.id, &ab), auBout: ab}
    if IsObject(t0) && !t0.repos                  ; un jour travaillé : pas de congé en cours
        return ""
    d := auj
    Loop 7 {                                      ; aujourd'hui sans type ou non travaillé : dans un congé ?
        d := PlusJours(d, -1), ty := TypeDuJour(d)
        if (IsObject(ty) && ty.annonce && ty.repos)
            return ((fin := FinPeriode(d, ty.id, &ab)) > auj) ? {ty: ty, fin: fin, auBout: ab} : ""
        if (IsObject(ty) && !ty.repos)
            return ""
    }
    return ""
}

; Une date courte, avec l'année quand ce n'est pas celle du jour « auj »
DateAn(d, auj) => DateCourte(d, SubStr(d, 1, 4) != SubStr(auj, 1, 4))

; Texte d'une période en cours : « Congé, reprise mer. 30 sept. » quand on
; reprend plus d'un jour après la fin (repos ou week-end entre les deux),
; sinon « Congé jusqu'au ven. 2 oct. » ; {long, court, date} ou "" (fini ce soir)
TextePeriode(p, auj) {
    if p.auBout                                   ; plus de 400 jours (congé parental…) : sans date de fin
        return {long: p.ty.nom " (plus d'un an)", court: p.ty.nom, date: p.fin, detail: "au-delà du " DateCourte(p.fin, true)}
    rep := p.ty.repos ? RepriseApres(p.fin) : ""
    if (rep != "" && rep > PlusJours(p.fin, 1))
        return {long: p.ty.nom ", reprise " DateAn(rep, auj), court: "Reprise " FormatTime(String(rep), "ddd d"), date: rep,
            detail: ((p.fin > auj) ? "jusqu'au " DateAn(p.fin, auj) : "dernier jour") " · reprise " DateAn(rep, auj)}
    if (p.fin > auj)
        return {long: p.ty.nom " jusqu'au " DateAn(p.fin, auj), court: p.ty.nom, date: p.fin, detail: "jusqu'au " DateAn(p.fin, auj)}
    return ""
}

; Événements du calendrier (voir EvenementsCalendrier) : un type annoncé qui
; arrive (« Congé demain », « Congé lundi » : les jours sans type ou non
; travaillés d'ici là sont sautés, 6 jours au plus), et la période en cours
EvenementsJours(auj) {
    ev := []
    if !JoursUtilises()
        return ev
    p := PeriodeEnCours(auj)
    Loop 6 {                                      ; (au-delà, « lundi » serait ambigu)
        n := A_Index, d := PlusJours(auj, n), ty := TypeDuJour(d)
        if (IsObject(ty) && ty.annonce) {
            if !(IsObject(p) && p.ty.id = ty.id) {   ; pas la suite de la période en cours
                quand := (n = 1) ? "demain" : FormatTime(String(d), "dddd")
                ev.Push({rang: 4, genre: "jour", long: ty.nom " " quand, court: ty.nom " " quand, date: d, c: ty.c})
            }
            break
        }
        if (IsObject(ty) && !ty.repos)            ; un jour travaillé avant : rien à annoncer
            break
    }
    if (IsObject(p) && IsObject(t := TextePeriode(p, auj)))
        ev.Push({rang: 6, genre: "jour", long: t.long, court: t.court, date: t.date, c: p.ty.c})
    return ev
}

; Pour la fenêtre des prévisions : la période en cours ou la prochaine d'un
; type annoncé (sur 120 jours) : [{genre, titre, detail, c}]
ListeJours(auj) {
    if !JoursAnnonce()
        return []
    if IsObject(p := PeriodeEnCours(auj))
        return [{genre: "jour", titre: p.ty.nom, detail: IsObject(t := TextePeriode(p, auj)) ? t.detail : "aujourd'hui", c: p.ty.c}]
    Loop 120 {
        n := A_Index, d := PlusJours(auj, n), ty := TypeDuJour(d)
        if !(IsObject(ty) && ty.annonce)
            continue
        fin := FinPeriode(d, ty.id, &ab)
        detail := ((fin > d) ? DateAn(d, auj) " → " (ab ? "plus d'un an" : DateAn(fin, auj)) : DateAn(d, auj)) " · " ((n = 1) ? "demain" : "dans " n Chr(0xA0) "j")
        return [{genre: "jour", titre: ty.nom, detail: detail, c: ty.c}]
    }
    return []
}

; Nombre de jours de chaque type sur l'année « an » (du 1er janvier au 31
; décembre, bissextile comprise) : Map id → n, gardée tant que rien ne change
TotauxAnnee(an) {
    static cle := "", res := ""
    if (cle = an "|" JoursVersion)
        return res
    res := Map(), d := Integer(an "0101")
    while (SubStr(d, 1, 4) = an) {
        if IsObject(ty := TypeDuJour(d))
            res[ty.id] := res.Get(ty.id, 0) + 1
        d := PlusJours(d, 1)
    }
    cle := an "|" JoursVersion
    return res
}

; ---------- Cycles ----------

; Le cycle cy lu à partir du jour ymd (même rythme) : son motif décalé
MotifTourne(cy, ymd) {
    nb := cy.motif.Length, k := RangCycle(cy, ymd) - 1, motif := []
    Loop nb
        motif.Push(cy.motif[Mod(k + A_Index - 1, nb) + 1])
    return motif
}

; Le dernier cycle (non vide) qui commence avant ymd, en vigueur ou arrêté : {debut, motif}, ou ""
CycleAvant(ymd) {
    c := ""
    for d, motif in JoursCycles {
        if (d >= ymd)
            break
        if motif.Length
            c := {debut: d, motif: motif}
    }
    return c
}

; Le premier cycle (non vide) qui commence après ymd : {debut, motif}, ou ""
CycleApres(ymd) {
    for d, motif in JoursCycles
        if (d > ymd && motif.Length)
            return {debut: d, motif: motif}
    return ""
}

; Les débuts de cycle (ou arrêts) après ymd, dans l'ordre
ClesCyclesApres(ymd) {
    l := []
    for d in JoursCycles
        if (d > ymd)
            l.Push(d)
    return l
}

; Le motif lu sur les jours affichés à partir de ymd, jusqu'au jour « fin »
; (sinon jusqu'à 7 jours sans type de suite, 400 jours au plus) ; voir PeriodeMotif
MotifPeint(ymd, fin := 0) {
    seq := [], d := ymd
    if fin {                                      ; une fenêtre donnée (sous un cycle) : ses jours tels quels
        while (d <= fin)
            seq.Push(((id := IdDuJour(d)) = "") ? "-" : id), d := PlusJours(d, 1)
        return seq
    }
    ; jusqu'à 7 jours sans type de suite ; avec une base (semaine type, cycle plus
    ; loin), jusqu'au dernier jour peint (posé, ou touché au pinceau : un jour
    ; pareil à la base n'est pas noté) suivi de 7 jours de base seule : le tour
    ; peint, sans la base qui le suit
    vides := 0, dernier := 0, base := false
    Loop 400 {
        i := A_Index, id := IdDuJour(d)
        if (id = "") {
            if (++vides >= 7)
                break
        } else
            vides := 0
        seq.Push((id = "") ? "-" : id)
        if (JoursPoses.Has(d) || JoursTouches.Has(d))
            dernier := i
        else if (id != "")
            base := true
        d := PlusJours(d, 1)
        if (base && dernier && i - dernier >= 7)
            break
    }
    if (base && dernier)
        seq.Length := Min(dernier, seq.Length)
    coupes := 0
    while (seq.Length && seq[seq.Length] = "-")
        seq.Pop(), coupes += 1
    return PeriodeMotif(seq, coupes)
}

; La période d'une série de jours : la plus petite multiple de 7 qui la
; reproduit (16 jours de 2-2-3 → 14), sinon la plus petite qui se vérifie sur
; 7 jours au moins ; sinon toute la série, complétée par ses jours sans type
; de fin jusqu'au multiple de 7 (TT--TTT--TT → 14 jours) ; 14 jours au plus
; si elle est longue sans période
PeriodeMotif(seq, coupes := 0) {
    nb := seq.Length
    Reproduit(p) {
        Loop nb - p
            if (seq[p + A_Index] != seq[A_Index])
                return false
        return true
    }
    Loop (nb - 1) // 7 {                          ; 7, 14, 21… : vérifiée sur 7 jours, ou un tour de 2 à
        p := 7 * A_Index                          ; 4 semaines peint un peu au-delà (16 jours de 2-2-3 → 14)
        if (p > 366)
            break
        if ((nb - p >= 7 || (p >= 14 && p <= 28)) && Reproduit(p)) {
            seq.Length := p
            return seq
        }
    }
    Loop Min(Max(0, nb - 8), 365) {               ; 2 … nb-7 : au moins 7 jours pour vérifier
        if Reproduit(p := A_Index + 1) {
            seq.Length := p
            return seq
        }
    }
    if (nb > 60) {
        seq.Length := 14
        return seq
    }
    ; un jour non travaillé peint : la série est rendue entière (quelques jours peints
    ; en trop ne se distinguent pas d'un tour exact commencé au milieu d'un bloc :
    ; l'invite montre la plage lue, on retire les lettres en trop)
    for id in seq
        if (IsObject(ty := TypeParId(JoursTypes, id)) && ty.repos)
            return seq
    ; repos laissés sans type (aucun jour non travaillé peint, fin sur un jour
    ; travaillé) : la fin du tour, pas peinte, complétée jusqu'au multiple de 7
    if (coupes && nb && IsObject(TypeParId(JoursTypes, seq[nb])))
        Loop Min(coupes, Mod(7 - Mod(nb, 7), 7))
            seq.Push("-")
    return seq
}

; Une lettre par type pour écrire un motif : {lettre: Map lettre → id, id: Map id → lettre}
; (la 1re lettre du nom sans accent, sinon une autre de ses lettres, sinon un chiffre)
LettresTypes() {
    parLettre := Map(), parId := Map()
    for ty in JoursTypes {
        choix := ""
        Loop Parse SansAccents(StrUpper(ty.nom))
            if (RegExMatch(A_LoopField, "^[A-Z]$") && !parLettre.Has(A_LoopField)) {
                choix := A_LoopField
                break
            }
        if (choix = "")
            Loop 9
                if !parLettre.Has(String(A_Index)) {
                    choix := String(A_Index)
                    break
                }
        parLettre[choix] := ty.id, parId[ty.id] := choix
    }
    return {lettre: parLettre, id: parId}
}

SansAccents(t) {
    static DE := "ÀÂÄÁÃÉÈÊËÎÏÍÌÔÖÓÒÕÙÛÜÚÇŸ", VERS := "AAAAAEEEEIIIIOOOOOUUUUCY"
    Loop Parse DE
        t := StrReplace(t, A_LoopField, SubStr(VERS, A_Index, 1), true)
    return t
}

; Motif → lettres, une espace tous les 7 jours (« TTRRTTT RRTTRRR »)
MotifTexte(motif, lettres) {
    t := ""
    for i, id in motif
        t .= ((i > 1 && Mod(i - 1, 7) = 0) ? " " : "") ((id = "-") ? "-" : lettres.id.Get(id, "?"))
    return t
}

; Lettres → motif (tableau d'ids, « - » : rien), ou le message d'erreur (chaîne)
LireMotif(txt, lettres) {
    motif := []
    Loop Parse StrUpper(txt) {
        ch := A_LoopField
        if (ch = " " || ch = "`t" || ch = Chr(0xB7) || ch = Chr(0xA0))
            continue
        if (ch = "-" || ch = ".")
            motif.Push("-")
        else if lettres.lettre.Has(ch)
            motif.Push(lettres.lettre[ch])
        else
            return "« " ch " » n'est la lettre d'aucun type."
    }
    if (motif.Length < 2 || motif.Length > 366)
        return "Un cycle fait de 2 à 366 jours (" motif.Length " ici)."
    return motif
}

NomOuRien(id) => IsObject(ty := TypeParId(JoursTypes, id)) ? ty.nom : "sans type"

; « 2 Travail · 2 Repos · 3 Travail · 2 Repos · 2 Travail · 3 Repos »
ResumeMotif(motif) {
    t := "", n := 0, prec := ""
    for id in motif {
        if (n && id != prec)
            t .= ((t = "") ? "" : " · ") n " " NomOuRien(prec), n := 0
        prec := id, n += 1
    }
    return t ((t = "") ? "" : " · ") n " " NomOuRien(prec)
}

; Deux cycles qui se suivent sans rien changer (même longueur, même rythme) : true
MemeCycle(prec, d, motif) {
    if (motif.Length != prec.motif.Length)
        return false
    k := RangCycle(prec, d) - 1
    for i, id in motif
        if (id != prec.motif[Mod(k + i - 1, motif.Length) + 1])
            return false
    return true
}

; Lignes C en ordre : un arrêt sans cycle avant (ou après un autre arrêt) et un
; cycle qui ne fait que continuer le précédent au même rythme sont retirés
JoursNormaliserCycles() {
    cles := []
    for d in JoursCycles
        cles.Push(d)
    prec := ""
    for d in cles {
        motif := JoursCycles[d]
        if !motif.Length {
            if !IsObject(prec)
                JoursCycles.Delete(d)
            prec := ""
        } else if (IsObject(prec) && MemeCycle(prec, d, motif))
            JoursCycles.Delete(d)
        else
            prec := {debut: d, motif: motif}
    }
}

; Après un nouveau cycle en ymd (N jours) : les jours posés de son 1er tour
; pareils à lui (c'est le tour qui a servi de modèle) ne sont plus notés. Les
; autres restent (congés, échanges), comme tous ceux d'après.
JoursNettoyerPoses(ymd, nb) {
    borne := PlusJours(ymd, nb - 1)
    for d in ClesCyclesApres(ymd) {
        borne := Min(borne, PlusJours(d, -1))
        break
    }
    for d, id in JoursPoses.Clone()
        if (d >= ymd && d <= borne && ((id = "-") ? BaseDuJour(d) = "" : BaseDuJour(d) = id))
            JoursPoses.Delete(d)
}

; Pose le cycle « motif » à partir de ymd (sans rien demander). « remplacer » :
; les débuts de cycle et arrêts suivants sont supprimés ; « lu » (motif lu tel
; quel sur les jours peints) : seulement ceux de son 1er tour, qui y ont été lus
; (un mauvais départ corrigé). Puis ordre et jours posés remis au propre.
JoursAppliquerCycle(ymd, motif, remplacer := false) {
    if remplacer
        for d in ClesCyclesApres(ymd)
            JoursCycles.Delete(d)
    JoursCycles[ymd] := motif
    JoursNormaliserCycles()
    JoursNettoyerPoses(ymd, motif.Length)
    JoursTouches.Clear()                          ; (le tour peint est devenu le cycle)
}

; Retire le cycle qui commence en ymd ; « repeindre » (sans cycle avant lui) :
; son 1er tour reste peint en jours posés, jusqu'au cycle suivant au plus
JoursRetirerCycle(ymd, repeindre := true) {
    if !JoursCycles.Has(ymd)
        return
    motif := JoursCycles[ymd]
    JoursCycles.Delete(ymd)
    ap := ClesCyclesApres(ymd), lim := ap.Length ? ap[1] : 99991231
    if (repeindre && !IsObject(CycleDe(ymd)))
        for i, id in motif {
            if ((d := PlusJours(ymd, i - 1)) >= lim)
                break
            if !JoursPoses.Has(d)
                JoursPoserJour(d, id)
        }
    JoursNormaliserCycles()
    JoursTouches.Clear()
}

; Plus de cycle à partir de ymd ; « suivants » : les roulements prévus après aussi
; (un cycle qui commençait ce jour-là, sans cycle la veille : simplement retiré)
JoursStopperCycle(ymd, suivants := false) {
    if suivants
        for d in ClesCyclesApres(ymd)
            JoursCycles.Delete(d)
    if (JoursCycles.Has(ymd) && !IsObject(CycleDe(PlusJours(ymd, -1))))
        JoursCycles.Delete(ymd)
    else
        JoursCycles[ymd] := []
    JoursNormaliserCycles()
}

; « l'arrêt du jeu. 1er juil. 2027, le cycle de 14 j du mer. 1er sept. 2027 et … »
DecrireCles(cles) {
    l := []
    for d in cles
        l.Push(JoursCycles[d].Length ? "le cycle de " JoursCycles[d].Length Chr(0xA0) "j du " DateCourte(d, true) : "l'arrêt du " DateCourte(d, true))
    return JoindreEt(l)
}

; Les cycles distincts (non vides) qui commencent avant ymd, sans celui en vigueur
; ni deux fois le même au même rythme : [{debut, motif}]
CyclesPrecedents(ymd) {
    l := [], actif := CycleDe(ymd)
    for d, motif in JoursCycles {
        if (d >= ymd)
            break
        if !motif.Length
            continue
        c := {debut: d, motif: motif}, deja := IsObject(actif) && MemeCycle(actif, d, motif)
        for autre in l
            deja := deja || MemeCycle(autre, d, motif)
        if !deja
            l.Push(c)
    }
    return l
}

; Un type supprimé : « - » à sa place dans les motifs (le rythme ne bouge pas) ; renvoie le nombre de jours touchés
RetirerTypeDesMotifs(id) {
    n := 0
    for d, motif in JoursCycles
        for i, el in motif
            if (el = id)
                motif[i] := "-", n += 1
    return n
}

; ---------- La marque sur la date du widget ----------

; La date seule, au début d'une ligne de date (sans semaine ni événement)
PartieDate(txt) => (p := InStr(txt, "  ·  ")) ? SubStr(txt, 1, p - 1) : txt

; Marque du type du jour, à sa couleur : le nom du jour seul (« jour » :
; « Jeudi » en couleur, le reste inchangé), un trait sous la date
; (« souligne ») ou un fond façon feutre derrière elle (« surligne »).
; bd : bornes de la ligne posée, forme L[n0 + 1] (le surlignage passe
; dessous) ; ligne : son texte ; date : son début qui est la date. La couleur
; garde son sens la nuit (brut : jamais teintée), comme les pastilles.
MarqueDate(L, n0, bd, ligne, date, police, em, cap, yb) {
    if (JoursMarque = "aucune" || !IsObject(bd) || !JoursUtilises())
        return
    ty := TypeDuJour(Aujourdhui())
    if !IsObject(ty)
        return
    if (JoursMarque = "jour") {
        ; le nom du jour et le reste en deux formes, calées sur l'encre de la
        ; ligne (premier et dernier glyphe) : chaque lettre reste à sa place
        if !(sp := InStr(ligne, " "))
            return
        e := L[n0 + 1], yh := yb - LigneDeBase(police, em)
        pj := CheminTexte(SubStr(ligne, 1, sp - 1), police, em), bj := Bornes(pj)
        Deplacer(pj, bd.x - bj.x, yh)
        pr := CheminTexte(SubStr(ligne, sp), police, em), br := Bornes(pr)
        Deplacer(pr, bd.x + bd.w - (br.x + br.w), yh)
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
        e.p := pr
        L.InsertAt(n0 + 2, {p: pj, f: ty.c, o: e.o, z: e.z, brut: true})
        return
    }
    p := CheminTexte(date, police, em), b := Bornes(p)
    DllCall("gdiplus\GdipDeletePath", "Ptr", p)
    x1 := bd.x, lg := b.w                         ; la date commence la ligne : même premier glyphe
    if (JoursMarque = "surligne") {
        m := 0.14 * cap                           ; un trait de feutre sur le bas des lettres
        L.InsertAt(n0 + 1, {p: CheminArrondi(x1 - m, yb - 0.34 * cap, lg + 2 * m, 0.46 * cap, 0.12 * cap),
            f: 0x99000000 | (ty.c & 0xFFFFFF), o: 0, a: 0, z: false, brut: true})
    } else {
        ep := Max(2 * A_ScreenDPI / 96, 0.12 * cap)
        L.Push({p: CheminArrondi(x1, yb + 0.30 * cap, lg, ep, ep / 2), f: ty.c, o: OmbreTheme(), a: 0.7, z: false, brut: true})
    }
}

; Couleur de texte lisible sur un fond « c » (ARGB) : sombre sur une couleur claire
CouleurSur(c) {
    r := (c >> 16) & 0xFF, v := (c >> 8) & 0xFF, b := c & 0xFF
    return (0.2126 * r + 0.7152 * v + 0.0722 * b > 165) ? 0xFF16191D : 0xFFFFFFFF
}

; ---------- La fenêtre « Mes jours » ----------

OuvrirJours(*) {
    global JoursGui, JoursHwnd, JoursGeo, JoursPinceau, JoursAnnulable
    QuitterEdition()                              ; le mode « Redimensionner à la souris » s'arrête
    if (JoursHwnd && DllCall("IsWindow", "Ptr", JoursHwnd)) {
        FermerJours("nouvelle demande")
        return
    }
    FermerPrevisions("Mes jours demandés")        ; une seule fenêtre surgissante à la fois
    FermerReglages("Mes jours demandés")
    FermerMarches("Mes jours demandés")
    FermerFicheActu("Mes jours demandés")
    global JoursTouches := Map()                  ; (les jours touchés au pinceau depuis l'ouverture)
    if LireJours()                                ; (changé à la main depuis : l'annulation ne vaut plus)
        JoursAnnulable := ""
    if (JoursPinceau != "-" && !IsObject(TypeParId(JoursTypes, JoursPinceau)))
        JoursPinceau := JoursTypes[1].id
    JoursGeo := {kp: A_ScreenDPI / 96, mois: SubStr(Aujourdhui(), 1, 6), x: 0, y: 0, w: 0, h: 0, mp: "", annee: false, aReplacer: false}
    JoursGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x80000")
    JoursGui.Show("NA x0 y0 w1 h1")
    JoursHwnd := JoursGui.Hwnd
    PeindreJours(true)
    SurgieOuverteLe(JoursHwnd, "Mes jours ouverts")
}

FermerJours(raison := "", *) {
    global JoursGui, JoursHwnd, JoursGeo, JoursTrait
    if !JoursHwnd
        return
    if IsObject(JoursTrait)                       ; glisser en cours : ce qui est peint est gardé
        JoursFinTrait()
    JoursHwnd := 0, JoursGeo := ""
    try JoursGui.Destroy()
    JoursGui := ""
    SurgieFermee()
    Journal("Mes jours fermés" (IsObject(raison) || raison = "" ? "" : " (" raison ")"))
}

; Repeint la fenêtre ; « placer » : la (re)positionner près du widget
PeindreJours(placer := false) {
    g := JoursGeo
    if (!IsObject(g) || !JoursHwnd)
        return
    mp := MiseEnPageJours(g.mois, g.kp, g.annee)
    w := Round(mp.w * g.kp), h := Round(mp.h * g.kp)
    if (placer || w != g.w || h != g.h || g.aReplacer) {
        if (IsObject(JoursTrait) && !placer)      ; pendant un clic ou un glisser, la fenêtre ne bouge pas sous le
            g.aReplacer := true                   ; curseur (le pied peut prendre une ligne) : replacée au relâché
        else {
            PlacerSurgie(w, h, &x, &y)
            g.x := x, g.y := y, g.aReplacer := false
        }
        g.w := w, g.h := h
    }
    g.mp := mp
    PeindreCalque(JoursHwnd, g.x, g.y, g.w, g.h, (gr) => DessinerJours(gr, g.w, g.h, g.kp, mp))
}

; Mise en page (px logiques) : {w, h, mois, annee, titre, prec, suiv, sem[], cases[], pinceaux[], resume, cycle, yPied}
MiseEnPageJours(mois, kp, annee := false) {
    static LETTRES := ["L", "M", "M", "J", "V", "S", "D"]
    mp := {w: 440, mois: mois, annee: annee, sem: [], cases: [], pinceaux: []}
    mp.prec := {type: "prec", x: 22, y: 16, w: 44, h: 40}
    mp.suiv := {type: "suiv", x: 374, y: 16, w: 44, h: 40}
    mp.titre := {type: "titre", x: 90, y: 16, w: 260, h: 40}
    cw := (418 - 22) / 7
    Loop 7
        mp.sem.Push({n: A_Index, lettre: LETTRES[A_Index], x: 22 + (A_Index - 1) * cw, y: 62, w: cw, h: 34})
    d1 := Integer(mois "01"), debut := PlusJours(d1, 1 - JourISO(d1))
    Loop 42 {
        i := A_Index - 1, d := PlusJours(debut, i)
        mp.cases.Push({ymd: d, dehors: SubStr(d, 1, 6) != mois, x: 22 + Mod(i, 7) * cw, y: 100 + (i // 7) * 44, w: cw, h: 44})
    }
    ; pinceaux : un par type, « Effacer », « + Type » ; à la ligne quand ils ne tiennent plus
    emP := EmPourCapitale(P_TEXTE, 10 * kp)
    items := []
    for ty in JoursTypes
        items.Push({id: ty.id, nom: ty.nom, c: ty.c})
    items.Push({id: "-", nom: "Effacer", c: 0})
    if (JoursTypes.Length < JOURS_TYPES_MAX)
        items.Push({id: "+", nom: "Type", c: 0})
    xp := 22, yp := 376
    for it in items {
        lg := 12 + 10 + 7 + LargeurTexte(it.nom, P_TEXTE, emP) / kp + 12   ; marge, pastille, écart, nom, marge
        if (xp + lg > 418 && xp > 22)
            xp := 22, yp += 36
        mp.pinceaux.Push({type: "pinceau", id: it.id, nom: it.nom, c: it.c, x: xp, y: yp, w: lg, h: 28})
        xp += lg + 8
    }
    mp.yPied := yp + 28
    ; pied : résumé (clic : le mois ou l'année ; 2 lignes s'il le faut), ligne du cycle (clic : son début), aide
    mp.lignesResume := LignesResume(mois, annee, kp)
    mp.ex := 22 * (LignesPied() - 1)              ; hauteur en plus (fixe pour un nombre de types donné)
    mp.resume := {type: "resume", x: 22, y: mp.yPied + 8, w: 396, h: 22 + mp.ex}
    mp.cycle := {type: "cycle", x: 22, y: mp.yPied + 30 + mp.ex, w: 396, h: 22}
    mp.h := mp.yPied + 98 + mp.ex
    return mp
}

; Le résumé du mois AAAAMM (ou de son année) : 1 à 3 lignes qui tiennent dans le pied
LignesResume(mois, annee, kp) {
    an := SubStr(mois, 1, 4), comptes := Map()
    if annee
        comptes := TotauxAnnee(an)
    else {
        d := Integer(mois "01")
        while (SubStr(d, 1, 6) = mois) {
            if IsObject(ty := TypeDuJour(d))
                comptes[ty.id] := comptes.Get(ty.id, 0) + 1
            d := PlusJours(d, 1)
        }
    }
    morceaux := []
    for ty in JoursTypes
        if comptes.Has(ty.id)
            morceaux.Push(comptes[ty.id] Chr(0xA0) "j " ty.nom)
    if !morceaux.Length
        return [annee ? "Aucun jour posé en " an : "Aucun jour posé ce mois-ci"]
    return DecouperResume((annee ? an : Majuscule(FormatTime(mois "01", "MMMM"))) " : ", morceaux, LignesPied(), kp)
}

; « Quand : » puis les morceaux séparés par « · », sur « lmax » lignes au plus de
; 396 px logiques (la dernière, trop longue, est tronquée au dessin)
DecouperResume(debut, morceaux, lmax, kp := 1) {
    em := EmPourCapitale(P_TEXTE, 10 * kp), largeur := 396 * kp
    lignes := [debut], n := 0                     ; n : morceaux déjà sur la ligne en cours
    for m in morceaux {
        essai := lignes[lignes.Length] (n ? "  ·  " : "") m
        if (!n || lignes.Length = lmax || LargeurTexte(essai, P_TEXTE, em) <= largeur)
            lignes[lignes.Length] := essai, n += 1
        else
            lignes.Push(m), n := 1
    }
    return lignes
}

; Lignes réservées au résumé dans le pied : ce qu'il faut au pire mois (« Septembre :
; 30 j … » pour chaque type) et à la pire année (« 366 j … »), 3 au plus. Ça ne
; dépend que des types : la fenêtre ne change pas de hauteur d'un mois ou d'un clic à l'autre.
LignesPied() {
    static cle := "", n := 1
    noms := ""
    for ty in JoursTypes
        noms .= ty.nom "|"
    if (noms == cle)
        return n
    mois := [], ans := []
    for ty in JoursTypes
        mois.Push("30" Chr(0xA0) "j " ty.nom), ans.Push("366" Chr(0xA0) "j " ty.nom)
    n := Min(3, Max(DecouperResume("Septembre : ", mois, 3).Length, DecouperResume("2026 : ", ans, 3).Length))
    cle := noms
    return n
}


; Le cycle dont parle le pied de la fenêtre pour le mois AAAAMM : celui en
; vigueur à la fin du mois, sinon au début ; {debut, motif} ou ""
CycleDuMois(mois) {
    fin := PlusJours(PlusJours(Integer(mois "01"), 32) // 100 * 100 + 1, -1)   ; dernier jour du mois
    if IsObject(cy := CycleDe(fin)) || IsObject(cy := CycleDe(Integer(mois "01")))
        return cy
    for d, motif in JoursCycles                   ; un cycle qui commence et s'arrête dans le mois
        if (SubStr(d, 1, 6) = mois && motif.Length)
            cy := {debut: d, motif: motif}
    return cy
}

DessinerJours(gr, w, h, kp, mp) {
    global TeinteRendu
    ancienne := TeinteRendu
    TeinteRendu := NuitTeinteActive()             ; comme les prévisions : la teinte de nuit, pas l'atténuation
    try DessinerJoursScene(gr, w, h, kp, mp)
    finally TeinteRendu := ancienne
}

DessinerJoursScene(gr, w, h, kp, mp) {
    static SURFACE := 0xF21A1A19, ENCRE := 0xFFFFFFFF, SECOND := 0xFFC3C2B7, DISCRET := 0xFF898781
    static GRILLE := 0xFF2C2C2A, CHOISI := 0xFF3A3A37, ORANGE := 0xFFD95926, BLEU := 0xFF3987E5
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gr, "Int", 2)
    RectArrondi(gr, 0, 0, w, h, 22 * kp, SURFACE)
    L := []
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    Rond(cx, cy, r, couleur, brut := false) {
        DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
        DllCall("gdiplus\GdipAddPathEllipse", "Ptr", p, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r)
        e := {p: p, f: couleur, o: 0, z: false}
        if brut
            e.brut := true
        L.Push(e)
    }
    Anneau(xa, ya, lw, lh, r, ep, couleur) {
        p := CheminArrondi(xa, ya, lw, lh, r)
        Elargir(p, ep)
        L.Push({p: p, f: couleur, o: 0, z: false})
    }
    Barrette(xb, yb, lb, hb, couleur) => L.Push({p: CheminArrondi(xb, yb, lb, hb, Min(lb, hb) / 2), f: couleur, o: 0, z: false})
    Chevron(cx, cy, s, sens, couleur) {           ; « ‹ » (sens -1) ou « › » (1)
        DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
        DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", cx - sens * s / 2, "Float", cy - s, "Float", cx + sens * s / 2, "Float", cy)
        DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", cx + sens * s / 2, "Float", cy, "Float", cx - sens * s / 2, "Float", cy + s)
        Elargir(p, 2.2 * kp)
        L.Push({p: p, f: couleur, o: 0, z: false})
    }
    auj := Aujourdhui()

    ; ---- mois et flèches
    Poser(L, Majuscule(FormatTime(mp.mois "01", "MMMM yyyy")), P_DATE, em(13, P_DATE), X(220), X(42), 1, ENCRE)
    Chevron(X(mp.prec.x + 18), X(36), X(6), -1, SECOND)
    Chevron(X(mp.suiv.x + mp.suiv.w - 18), X(36), X(6), 1, SECOND)
    if (mp.mois != SubStr(auj, 1, 6))             ; un autre mois : retour à aujourd'hui d'un clic sur le titre
        Poser(L, "revenir à aujourd'hui", P_TEXTE, em(8.5), X(220), X(56), 1, DISCRET)

    ; ---- lettres des jours ; la semaine type en pastille dessous (atténuée sous un cycle : elle ne compte pas)
    sousCycle := IsObject(CycleDe(Integer(mp.mois "01"))) && IsObject(CycleDe(mp.cases[42].ymd))
    for s in mp.sem {
        cx := X(s.x + s.w / 2)
        Poser(L, s.lettre, P_TEXTE, em(10), cx, X(80), 1, (s.n >= 6) ? DISCRET : SECOND)
        if IsObject(ty := TypeParId(JoursTypes, JoursSemaine.Get(s.n, "")))
            Rond(cx, X(89), X(3), sousCycle ? (0x55000000 | (ty.c & 0xFFFFFF)) : ty.c, true)
    }

    ; ---- les jours
    vac := CalVacances && CalendrierValide()
    for c in mp.cases {
        ty := TypeDuJour(c.ymd), pose := JoursPoses.Has(c.ymd) && JoursPoses[c.ymd] != "-"
        xc := X(c.x + 3), yc := X(c.y + 3), lw := X(c.w - 6), lh := X(c.h - 6)
        if IsObject(ty) {
            al := pose ? 0xF2 : 0x6B              ; posé : plein ; cycle ou semaine type : plus léger
            if c.dehors
                al := al // 2
            L.Push({p: CheminArrondi(xc, yc, lw, lh, X(11)), f: (al << 24) | (ty.c & 0xFFFFFF), o: 0, z: false, brut: true})
        }
        ; un jour posé qui cache sa base (congé sur un jour de travail) : un point de la couleur de la base
        if (JoursPoses.Has(c.ymd) && (base := BaseDuJour(c.ymd)) != JoursPoses[c.ymd] && IsObject(tb := TypeParId(JoursTypes, base)))
            Rond(xc + lw - X(7), yc + X(7), X(3), c.dehors ? (0x80000000 | (tb.c & 0xFFFFFF)) : tb.c, true)
        ; 1er jour de chaque tour de cycle : une barrette au bord gauche
        if (IsObject(cy := CycleDe(c.ymd)) && RangCycle(cy, c.ymd) = 1)
            Barrette(xc + X(2.5), yc + X(11), X(2.5), lh - X(22), c.dehors ? DISCRET : ENCRE)
        if (c.ymd = auj)
            Anneau(xc - X(1.5), yc - X(1.5), lw + X(3), lh + X(3), X(12.5), 2 * kp, ENCRE)
        couleur := (IsObject(ty) && pose && !c.dehors) ? CouleurSur(ty.c) : c.dehors ? DISCRET : ENCRE
        cx := X(c.x + c.w / 2)
        Poser(L, Integer(SubStr(c.ymd, 7, 2)), (c.ymd = auj) ? P_DATE : P_TEXTE, em(11, (c.ymd = auj) ? P_DATE : P_TEXTE), cx, X(c.y + 27), 1, couleur)
        ; repères sous le numéro : férié (orange), vacances scolaires (bleu)
        rep := []
        if (NomFerie(c.ymd) != "")
            rep.Push(ORANGE)
        if (vac && IsObject(EnVacances(c.ymd)))
            rep.Push(BLEU)
        if EstAnniv(c.ymd)                        ; anniversaire (rose)
            rep.Push(C_ANNIV)
        for i, rc in rep
            Rond(cx + X(7) * (i - (rep.Length + 1) / 2), X(c.y + 36), X(2.3), rc)
    }

    ; ---- pinceaux
    for pz in mp.pinceaux {
        xc := X(pz.x), yc := X(pz.y), lw := X(pz.w), lh := X(pz.h)
        pris := (pz.id = JoursPinceau)             ; (jamais « choisi » : même variable que CHOISI, la casse est ignorée)
        L.Push({p: CheminArrondi(xc, yc, lw, lh, lh / 2), f: pris ? CHOISI : GRILLE, o: 0, z: false})
        if pris
            Anneau(xc, yc, lw, lh, lh / 2, 1.5 * kp, ENCRE)
        cy := yc + lh / 2
        if (pz.id = "-")
            Anneau(xc + X(12), cy - X(5), X(10), X(10), X(5), 1.3 * kp, SECOND)
        else if (pz.id = "+") {                   ; un « + » en deux traits
            Barrette(xc + X(12), cy - X(0.8), X(10), X(1.6), SECOND)
            Barrette(xc + X(16.2), cy - X(5), X(1.6), X(10), SECOND)
        } else
            Rond(xc + X(17), cy, X(5), pz.c, true)
        Poser(L, pz.nom, P_TEXTE, em(10), xc + X(29), cy + X(5), 0, pris ? ENCRE : SECOND)
    }

    ; ---- résumé du mois (ou de l'année), cycle, mode d'emploi
    yP := mp.yPied, largeur := X(396)
    for i, ligne in mp.lignesResume
        Poser(L, Tronquer(ligne, P_TEXTE, em(10), largeur), P_TEXTE, em(10), X(22), X(yP + 24 + 22 * (i - 1)), 0, SECOND)
    yP += mp.ex
    if IsObject(cy := CycleDuMois(mp.mois)) {
        suite := ClesCyclesApres(cy.debut)
        txt := "Cycle de " cy.motif.Length Chr(0xA0) "j depuis le " DateCourte(cy.debut, true)
            . (suite.Length ? " · jusqu'au " DateCourte(PlusJours(suite[1], -1)) : "")
        Poser(L, Tronquer(txt, P_TEXTE, em(10), largeur), P_TEXTE, em(10), X(22), X(yP + 46), 0, SECOND)
    } else
        Poser(L, JoursCycles.Count ? "Pas de cycle ce mois-ci" : "Un roulement ? Peins un tour, clic droit sur son 1er jour ▸ Répéter en cycle",
            P_TEXTE, em(JoursCycles.Count ? 10 : 8.5), X(22), X(yP + 46), 0, DISCRET)
    Poser(L, JoursCycles.Count ? "Clic : poser  ·  glisser : plusieurs jours  ·  clic droit sur un jour : type, cycle"
        : "Clic : poser le type choisi  ·  glisser : plusieurs jours  ·  lettre : la semaine",
        P_TEXTE, em(8.5), X(22), X(yP + 68), 0, DISCRET)
    Poser(L, "Clic droit sur un type : ses options  ·  molette : mois, Maj : année  ·  Ctrl+Z",
        P_TEXTE, em(8.5), X(22), X(yP + 84), 0, DISCRET)

    for e in L
        Remplir(gr, e)
    for e in L
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
}

; ---------- Souris et clavier dans la fenêtre ----------

JoursMessages() {
    OnMessage(0x201, JoursAppui)                  ; WM_LBUTTONDOWN
    OnMessage(0x203, JoursAppui)                  ; WM_LBUTTONDBLCLK : 2e clic rapide, traité comme un clic
    OnMessage(0x200, JoursDeplace)                ; WM_MOUSEMOVE (glisser sur les jours)
    OnMessage(0x202, JoursRelache)                ; WM_LBUTTONUP
    OnMessage(0x215, JoursRelache)                ; WM_CAPTURECHANGED
    OnMessage(0x205, JoursClicDroit)              ; WM_RBUTTONUP
    OnMessage(0x20A, JoursMolette)                ; WM_MOUSEWHEEL
    OnMessage(0x100, JoursTouche)                 ; WM_KEYDOWN
}

; Ce qui est sous le curseur (px logiques de la fenêtre) : {type, ymd | n | id}, ou ""
JoursSous() {
    g := JoursGeo
    if !(IsObject(g) && IsObject(g.mp))
        return ""
    Curseur(&cx, &cy)
    lx := (cx - g.x) / g.kp, ly := (cy - g.y) / g.kp
    Dans(r) => lx >= r.x && lx < r.x + r.w && ly >= r.y && ly < r.y + r.h
    for c in g.mp.cases
        if Dans(c)
            return {type: "jour", ymd: c.ymd}
    for r in [g.mp.prec, g.mp.suiv, g.mp.titre, g.mp.resume, g.mp.cycle]
        if Dans(r)
            return {type: r.type}
    for s in g.mp.sem
        if Dans(s)
            return {type: "sem", n: s.n}
    for pz in g.mp.pinceaux
        if Dans(pz)
            return {type: "pinceau", id: pz.id}
    return ""
}

JoursAppui(wParam, lParam, msg, hwnd) {
    global JoursTrait
    if (!JoursHwnd || hwnd != JoursHwnd)
        return
    s := JoursSous()
    if !IsObject(s)
        return 0
    switch s.type {
        case "jour":
            ; le type choisi déjà là : posé à part, on l'enlève (retour à la base) ;
            ; venu de la semaine type : rien ce jour-là ; venu d'un cycle : rien ne
            ; change (« Effacer » pour vider). Sinon on le pose. Tout le glisser fait
            ; pareil, sur les seuls jours de ce type quand on enlève.
            retrait := false
            if (JoursPinceau = "-" || IdDuJour(s.ymd) != JoursPinceau)
                mode := JoursPinceau
            else if (JoursPoses.Get(s.ymd, "") = JoursPinceau)
                mode := "=", retrait := true
            else if IsObject(CycleDe(s.ymd))
                mode := JoursPinceau
            else
                mode := "-", retrait := true
            Curseur(&cx, &cy)
            JoursTrait := {mode: mode, retrait: retrait, origine: JoursPoses.Get(s.ymd, ""), vus: Map(), lx: (cx - JoursGeo.x) / JoursGeo.kp, ly: (cy - JoursGeo.y) / JoursGeo.kp}
            JoursPoserJour(s.ymd, mode)
            JoursTrait.vus[s.ymd] := 1
            DllCall("SetCapture", "Ptr", JoursHwnd)
            PeindreJours()
        case "prec": JoursMois(-1)
        case "suiv": JoursMois(1)
        case "titre": JoursMois(0)
        case "resume":                            ; le mois ↔ l'année
            JoursGeo.annee := !JoursGeo.annee
            PeindreJours()
        case "cycle":                             ; au début du cycle affiché
            if IsObject(cy := CycleDuMois(JoursGeo.mois))
                JoursAllerA(cy.debut)
        case "sem": JoursSemaineType(s.n)
        case "pinceau":
            if (s.id = "+")
                SetTimer(JoursNouveauType, -1)
            else
                JoursChoisirPinceau(s.id)
    }
    return 0
}

JoursDeplace(wParam, lParam, msg, hwnd) {
    if (!JoursHwnd || hwnd != JoursHwnd || !IsObject(JoursTrait))
        return
    if !(wParam & 1) {                            ; relâché perdu
        JoursFinTrait()
        return 0
    }
    if JoursTraitJusquIci()                       ; repeint hors du gestionnaire : les mouvements
        SetTimer(PeindreJours, -1)                ; qui arrivent pendant ce temps ne sont pas perdus
    return 0
}

; Un jour que le glisser laisse tel quel : en retrait, ceux d'un autre type ;
; avec un pinceau non travaillé (Congé), les jours déjà non travaillés (Repos) :
; on pose ses congés sur les jours de travail d'un seul geste
TraitSaute(trait, ymd) {
    ty := TypeDuJour(ymd)
    if trait.retrait
        return !(IsObject(ty) && ty.id = JoursPinceau)
    ; pinceau non travaillé (Congé) : les jours déjà non travaillés restent (Repos du
    ; cycle, repos échangé) ; seuls les jours POSÉS du type posé au jour de départ sont
    ; remplacés (Maladie glissée depuis un congé posé remplace les congés posés)
    tp := TypeParId(JoursTypes, trait.mode)
    return IsObject(tp) && tp.repos && IsObject(ty) && ty.repos && ty.id != tp.id
        && !(trait.origine != "" && ty.id = trait.origine && JoursPoses.Get(ymd, "") = ty.id)
}

; Pose le type du trait sur toutes les cases entre le dernier point vu et le
; curseur (un glisser rapide saute des cases) ; true si un jour a changé
JoursTraitJusquIci() {
    g := JoursGeo
    if !(IsObject(JoursTrait) && IsObject(g) && IsObject(g.mp))
        return false
    Curseur(&cx, &cy)
    lx := (cx - g.x) / g.kp, ly := (cy - g.y) / g.kp, change := false
    n := Max(1, Ceil(Max(Abs(lx - JoursTrait.lx), Abs(ly - JoursTrait.ly)) / 20))   ; par pas de 20 px (une case : 57 × 44)
    Loop n {
        px := JoursTrait.lx + (lx - JoursTrait.lx) * A_Index / n, py := JoursTrait.ly + (ly - JoursTrait.ly) * A_Index / n
        for c in g.mp.cases
            if (px >= c.x && px < c.x + c.w && py >= c.y && py < c.y + c.h) {
                if !JoursTrait.vus.Has(c.ymd) {
                    JoursTrait.vus[c.ymd] := 1
                    if !TraitSaute(JoursTrait, c.ymd) {
                        JoursPoserJour(c.ymd, JoursTrait.mode)
                        change := true
                    }
                }
                break
            }
    }
    JoursTrait.lx := lx, JoursTrait.ly := ly
    return change
}

JoursRelache(wParam, lParam, msg, hwnd) {
    if (!JoursHwnd || hwnd != JoursHwnd)
        return
    if IsObject(JoursTrait) {
        if (msg = 0x202)                          ; la dernière case, si son mouvement s'est perdu
            JoursTraitJusquIci()
        JoursFinTrait()
    }
    return 0
}

; Fin d'un clic ou d'un glisser sur les jours : enregistré, widget mis à jour
JoursFinTrait() {
    global JoursTrait
    JoursTrait := ""
    DllCall("ReleaseCapture")
    JoursChanges("jours posés")                   ; (la date du widget change peut-être de couleur)
}

; Pose le type « mode » sur un jour (« - » : rien ce jour-là ; « = » : retour
; à la base). Un jour pareil à sa base (cycle ou semaine type) n'est pas noté ;
; un jour vidé alors que sa base a un type est noté « - ».
JoursPoserJour(ymd, mode) {
    if (mode != "-" && mode != "=" && !IsObject(TypeParId(JoursTypes, mode)))
        return                                    ; (un type disparu)
    if (mode = "=")                               ; (touché au pinceau : voir MotifPeint ; revenu à la base : plus peint)
        JoursTouches.Has(ymd) && JoursTouches.Delete(ymd)
    else
        JoursTouches[ymd] := 1
    base := BaseDuJour(ymd)
    if (mode = "=")
        JoursPoses.Has(ymd) && JoursPoses.Delete(ymd)
    else if (mode = "-")
        (base != "") ? (JoursPoses[ymd] := "-") : (JoursPoses.Has(ymd) && JoursPoses.Delete(ymd))
    else
        (base = mode) ? (JoursPoses.Has(ymd) && JoursPoses.Delete(ymd)) : (JoursPoses[ymd] := mode)
}

; Clic sur une lettre : chaque semaine ce jour-là prend le pinceau (ou le perd)
JoursSemaineType(n) {
    if (JoursPinceau = "-" || JoursSemaine.Get(n, "") = JoursPinceau)
        (JoursSemaine.Has(n) && JoursSemaine.Delete(n))
    else
        JoursSemaine[n] := JoursPinceau
    JoursChanges("semaine type")
}

JoursChoisirPinceau(id) {
    global JoursPinceau := id
    PeindreJours()
}

; Mois affiché : -1, +1 (±12 : une année), ou 0 (celui d'aujourd'hui)
JoursMois(n) {
    g := JoursGeo
    if !IsObject(g)
        return
    if !n
        g.mois := SubStr(Aujourdhui(), 1, 6)
    else {
        a := Integer(SubStr(g.mois, 1, 4)), m := Integer(SubStr(g.mois, 5, 2)) + n
        a += Floor((m - 1) / 12), m := Mod(Mod(m - 1, 12) + 12, 12) + 1
        g.mois := a Format("{:02}", m)
    }
    PeindreJours()
}

; Le mois d'un jour donné
JoursAllerA(ymd, *) {
    if IsObject(JoursGeo) {
        JoursGeo.mois := SubStr(ymd, 1, 6)
        PeindreJours()
    }
}

JoursMolette(wParam, lParam, msg, hwnd) {
    static cumul := 0, dernier := 0
    if (!JoursHwnd || hwnd != JoursHwnd)
        return
    d := (wParam >> 16) & 0xFFFF
    d := (d >= 0x8000) ? d - 0x10000 : d
    if (A_TickCount - dernier > 1000 || (cumul > 0) != (d > 0))   ; nouveau geste, ou changement de sens
        cumul := 0
    dernier := A_TickCount, cumul += d
    n := (cumul > 0) ? Floor(cumul / 120) : -Floor(-cumul / 120)   ; par crans de 120 (le pavé tactile envoie des fractions)
    if n {
        cumul -= n * 120
        JoursMois(-n * ((wParam & 0x4) ? 12 : 1))   ; molette vers soi : mois suivant ; Maj (MK_SHIFT) : année
    }
    return 0
}

JoursTouche(wParam, lParam, msg, hwnd) {
    if (!JoursHwnd || hwnd != JoursHwnd)
        return
    if (wParam = 0x5A && GetKeyState("Ctrl")) {   ; Ctrl+Z (une fois : pas la répétition de la touche maintenue)
        if !(lParam & 0x40000000)
            SetTimer(JoursAnnuler, -1)
        return 0
    }
    switch wParam {
        case 0x1B: SetTimer(FermerJours.Bind("Échap"), -1)
        case 0x25, 0x21: JoursMois(-1)            ; gauche, page précédente
        case 0x27, 0x22: JoursMois(1)             ; droite, page suivante
        case 0x26: JoursMois(-12)                 ; haut : année précédente
        case 0x28: JoursMois(12)                  ; bas : année suivante
        case 0x24: JoursMois(0)                   ; début
        default: return
    }
    return 0
}

; Clic droit : sur un type, ses options ; sur un jour, le type à poser et le
; cycle ; sur la ligne du cycle, le cycle
JoursClicDroit(wParam, lParam, msg, hwnd) {
    if (!JoursHwnd || hwnd != JoursHwnd)
        return
    s := JoursSous()
    if !IsObject(s)
        return 0
    if (s.type = "pinceau" && IsObject(ty := TypeParId(JoursTypes, s.id))) {
        m := Menu(), mc := Menu()
        m.Add("Renommer…", (*) => JoursRenommer(ty.id))
        for v in JOURS_PALETTE
            mc.Add(v[2], JoursCouleur.Bind(ty.id, 0xFF000000 | Integer("0x" v[1])))
        mc.Add()
        mc.Add("Autre couleur…", (*) => JoursCouleurLibre(ty.id))
        m.Add("Couleur", mc)
        m.Add("Annoncer la veille dans le calendrier", (*) => JoursAnnoncer(ty.id))
        if ty.annonce
            m.Check("Annoncer la veille dans le calendrier")
        m.Add("Jour non travaillé (repos, congé, RTT…)", (*) => JoursNonTravaille(ty.id))
        if ty.repos
            m.Check("Jour non travaillé (repos, congé, RTT…)")
        m.Add()
        m.Add("Supprimer ce type…", (*) => JoursSupprimerType(ty.id))
        m.Show()
    } else if (s.type = "jour") {
        m := Menu(), ymd := s.ymd, cy := CycleDe(ymd)
        if IsObject(cy) {                         ; où on en est du cycle
            info := "Jour " RangCycle(cy, ymd) " sur " cy.motif.Length " du cycle"
            m.Add(info, (*) => 0), m.Disable(info), m.Add()
        }
        for ty in JoursTypes
            m.Add(StrReplace(ty.nom, "&", "&&"), JoursMenuPoser.Bind(ymd, ty.id))
        if IsObject(cour := TypeDuJour(ymd))
            try m.Check(StrReplace(cour.nom, "&", "&&"))
        if JoursPoses.Has(ymd)                    ; un jour posé : revenir à la base
            m.Add((IsObject(cy) ? "Comme le cycle (" : "Comme la semaine type (") StrReplace(NomOuRien(BaseDuJour(ymd)), "&", "&&") ")", JoursMenuPoser.Bind(ymd, "="))
        m.Add("Effacer", JoursMenuPoser.Bind(ymd, "-"))
        m.Add()
        if (JoursCycles.Has(ymd) && JoursCycles[ymd].Length)
            m.Add("Modifier le cycle qui commence ici…", JoursRepeterCycle.Bind(ymd))
        else
            m.Add(IsObject(cy) ? "Nouveau cycle à partir d'ici…" : "Répéter en cycle à partir d'ici…", JoursRepeterCycle.Bind(ymd))
        if IsObject(cy)
            m.Add("Arrêter le cycle à partir d'ici…", JoursArreterCycle.Bind(ymd))
        prec := CyclesPrecedents(ymd)             ; revenir à un roulement d'avant, au même rythme
        if (prec.Length = 1)
            m.Add("Reprendre ici le cycle du " DateCourte(prec[1].debut, true) " (même rythme)…", JoursReprendreCycle.Bind(ymd, prec[1], false))
        else if prec.Length {
            mr := Menu()
            for c in prec
                mr.Add("Le cycle de " c.motif.Length Chr(0xA0) "j du " DateCourte(c.debut, true) "…", JoursReprendreCycle.Bind(ymd, c, false))
            m.Add("Reprendre ici un cycle précédent (même rythme)", mr)
        }
        if (!IsObject(cy) && IsObject(ap := CycleApres(ymd)))
            m.Add("Faire partir d'ici le cycle du " DateCourte(ap.debut, true) " (même rythme)…", JoursReprendreCycle.Bind(ymd, ap, true))
        JoursMenuAnnuler(m)
        m.Show()
    } else if (s.type = "cycle" || s.type = "resume") {
        m := Menu()
        if IsObject(cy := CycleDuMois(JoursGeo.mois)) {
            m.Add("Aller au début (" DateCourte(cy.debut, true) ")", JoursAllerA.Bind(cy.debut))
            m.Add("Modifier le motif…", JoursRepeterCycle.Bind(cy.debut))
            if (IsObject(ca := CycleDe(Aujourdhui())) && ca.debut = cy.debut)   ; (seulement le cycle affiché, s'il vaut aujourd'hui)
                m.Add("Arrêter ce cycle à partir d'aujourd'hui…", JoursArreterCycle.Bind(Aujourdhui()))
            m.Add("Supprimer ce cycle…", JoursSupprimerCycle.Bind(cy.debut))
        }
        JoursMenuAnnuler(m)
        try m.Show()                              ; (vide : rien à montrer)
    }
    return 0
}

; « Annuler : … » en bas d'un menu, s'il y a quelque chose à annuler
JoursMenuAnnuler(m) {
    if (JoursAnnulable = "")
        return
    try m.Add()                                   ; (séparateur ; rien avant : sans effet)
    m.Add(JoursAnnulSens " : " StrReplace(JoursAnnulLib, "&", "&&") "  (Ctrl+Z)", JoursAnnuler)
}

JoursMenuPoser(ymd, id, *) {
    JoursPoserJour(ymd, id)
    JoursChanges("jour posé")
}

; Après une modification : enregistré, fenêtre, widget et menu à jour
; (la ligne du calendrier dépend des jours posés)
JoursChanges(lib := "modification") {
    SauverJours(lib)
    PeindreJours()
    SetTimer(RenduFinal, -1)
    if IsObject(MenuWidget)                       ; (pas de menus dans les modes de test)
        CocherMenus()
}

; Annule la dernière modification (un seul niveau ; annuler l'annulation la refait)
JoursAnnuler(*) {
    global JoursAnnulable, JoursAnnulSens, JoursDate
    if (JoursAnnulable = "")
        return
    JoursCopieExterne()
    txt := JoursAnnulable, lib := JoursAnnulLib, actuel := ""
    try actuel := FileRead(F_JOURS, "UTF-8")
    if !EcrireJoursTexte(txt)
        return
    Journal("Mes jours : " StrLower(JoursAnnulSens) " « " lib " »")
    JoursTouches.Clear()                          ; (la peinture annulée ne compte plus)
    JoursAnnulable := actuel, JoursAnnulSens := (JoursAnnulSens = "Annuler") ? "Rétablir" : "Annuler"
    JoursDate := ""
    LireJours()
    PeindreJours()
    SetTimer(RenduFinal, -1)
    if IsObject(MenuWidget)
        CocherMenus()
}

; Boîtes de dialogue devant la fenêtre et modales (+OwnDialogs ne vaut que
; pour le fil où il est posé : à refaire dans chaque fonction qui en ouvre)
JoursDialogues() {
    if IsObject(JoursGui)
        JoursGui.Opt("+OwnDialogs")
}

; InputBox et MsgBox de « Mes jours » : pendant la boîte, un clic dans une
; autre application ne ferme pas la fenêtre (elle emporterait la boîte et ce
; qui y est tapé : on va souvent lire son roulement dans un PDF)
JoursSaisie(invite, titre, opts, defaut := "") {
    global SurgieDialogue
    JoursDialogues()
    SurgieDialogue += 1
    try return InputBox(invite, titre, opts, defaut)
    finally SurgieDialogue -= 1
}

JoursBoite(texte, titre, opts) {
    global SurgieDialogue
    JoursDialogues()
    SurgieDialogue += 1
    try return MsgBox(texte, titre, opts)
    finally SurgieDialogue -= 1
}

; ---------- Cycles : les commandes ----------

; « Répéter en cycle à partir d'ici » (ou modifier le cycle qui part de ymd) :
; le motif en lettres, prérempli avec ce qui est peint (ou le cycle en place),
; puis une confirmation qui le résume
JoursRepeterCycle(ymd, *) {
    static T := "Mes jours : cycle"
    lettres := LettresTypes(), cy := CycleDe(ymd)
    if (JoursCycles.Has(ymd) && JoursCycles[ymd].Length)
        motif := JoursCycles[ymd], origine := ""  ; modifier le cycle en place
    else if IsObject(cy)                          ; sous un cycle : les jours affichés sur un tour (un nouveau tour peint par-dessus)
        motif := MotifPeint(ymd, PlusJours(ymd, cy.motif.Length - 1)), origine := " (prérempli avec les " cy.motif.Length
            . " jours affichés : raccourcis ou allonge si ton nouveau tour n'a pas cette longueur)"
    else
        motif := MotifPeint(ymd), origine := motif.Length ? " (prérempli avec ce qui est peint du " DateCourte(ymd) " au "
            . DateCourte(PlusJours(ymd, motif.Length - 1)) ")" : ""
    legende := ""
    for ty in JoursTypes
        legende .= ((legende = "") ? "" : " · ") lettres.id[ty.id] " = " ty.nom
    txt := MotifTexte(motif, lettres)
    Loop {
        r := JoursSaisie("Motif du cycle à partir du " DateCourte(ymd, true) origine " : une lettre par jour, dans l'ordre (les espaces "
            . "ne comptent pas). Il se répète ensuite sans fin, sur toutes les années.`n`n" legende " · - = sans type", T, "w640 h190", txt)
        if (r.Result != "OK")
            return
        txt := r.Value, lu := LireMotif(txt, lettres)
        if IsObject(lu)
            break
        JoursBoite(lu, T, "Iconx")
    }
    nb := lu.Length
    msg := "Cycle de " nb " jours à partir du " DateCourte(ymd, true) " :`n" ResumeMotif(lu) "`n"
    dedans := [], poses := []
    for i, id in lu {
        d := PlusJours(ymd, i - 1), ty := TypeParId(JoursTypes, id)
        if (IsObject(ty) && ty.annonce)           ; un type annoncé (Congé) dans le motif : il reviendrait à chaque tour
            dedans.Push(DateCourte(d) " (" ty.nom ")")
        else if (IsObject(ty) && IsObject(cy) && JoursPoses.Get(d, "") = id)   ; un jour posé à part (échange) qui deviendrait la règle
            poses.Push(ty.nom " le " DateCourte(d))
    }
    if dedans.Length
        msg .= "`nAttention : " JoindreEt(dedans) " reviendra tous les " nb " jours. S'il s'agit d'un congé, annule, "
            . "peins ce jour de son type habituel, répète, puis repose le congé.`n"
    if (poses.Length && poses.Length <= 3)
        msg .= "`nDes jours posés à part entrent dans le cycle (ils reviendront à chaque tour) : " JoindreEt(poses) ".`n"
    else if poses.Length
        msg .= "`nLes " poses.Length " jours peints par-dessus l'ancien cycle en font partie.`n"
    suite := ClesCyclesApres(ymd)                 ; tout ce qui est déjà prévu après, même dans ce 1er tour
    if suite.Length {
        rep := JoursBoite(msg "`nDéjà prévu après : " DecrireCles(suite) ".`n"
            . "Oui : tout remplacer (ce cycle vaut sans fin).`nNon : le garder (ce cycle vaut jusqu'au " DateCourte(PlusJours(suite[1], -1), true) ").",
            T, "YesNoCancel Icon?")
        if (rep = "Cancel")
            return
    } else {
        if (JoursBoite(msg "`nRépété sans fin, sur toutes les années. Les congés et autres jours posés à part restent. "
            . "Ctrl+Z annule.", T, "OKCancel Iconi") != "OK")
            return
        rep := "No"
    }
    JoursCopieAvant()
    JoursAppliquerCycle(ymd, lu, rep = "Yes")
    Journal("Mes jours : cycle de " nb " jours à partir du " DateTiret(ymd) " (" ResumeMotif(lu) ")")
    JoursChanges("cycle du " DateCourte(ymd))
}

; « Reprendre le cycle du … ici » : le même cycle, au même rythme, à partir de
; ymd (après un arrêt, un roulement d'été…), ou le faire partir plus tôt
JoursReprendreCycle(ymd, src, plusTot := false, *) {
    motif := MotifTourne(src, ymd), prec := {debut: ymd, motif: motif}, suite := []
    for d in ClesCyclesApres(ymd) {               ; ce qui restera après, comme le laissera la remise en ordre
        m := JoursCycles[d]
        if !m.Length
            suite.Push(d), prec := ""
        else if !(IsObject(prec) && MemeCycle(prec, d, m))   ; (au même rythme juste après : il fusionne)
            suite.Push(d), prec := {debut: d, motif: m}
    }
    txt := plusTot ? "Le cycle du " DateCourte(src.debut, true) " (" motif.Length " jours) part plus tôt, dès le " DateCourte(ymd, true) ", au même rythme :`n"
        : "Le cycle du " DateCourte(src.debut, true) " (" motif.Length " jours) vaut à partir du " DateCourte(ymd, true) ", au même rythme que s'il ne s'était jamais arrêté :`n"
    txt .= ResumeMotif(motif) " (à partir de ce jour)."
    if (JoursCycles.Has(ymd) && JoursCycles[ymd].Length && !MemeCycle({debut: ymd, motif: motif}, ymd, JoursCycles[ymd]))
        txt .= "`n`nIl remplace le cycle de " JoursCycles[ymd].Length Chr(0xA0) "j qui commence ce jour-là."
    if suite.Length
        txt .= "`n`nCe qui est prévu après reste : " DecrireCles(suite) " (celui-ci vaut donc jusqu'au " DateCourte(PlusJours(suite[1], -1), true) ")."
    if (JoursBoite(txt, "Mes jours : cycle", "OKCancel Iconi") != "OK")
        return
    JoursCopieAvant()
    JoursAppliquerCycle(ymd, motif)
    JoursChanges((plusTot ? "cycle avancé au " : "cycle repris le ") DateCourte(ymd))
}

; « Arrêter le cycle à partir d'ici » : la base redevient la semaine type
JoursArreterCycle(ymd, *) {
    static T := "Mes jours : cycle"
    if (JoursCycles.Has(ymd) && !IsObject(CycleAvant(ymd))) {
        JoursSupprimerCycle(ymd)                  ; (le 1er cycle, arrêté le jour où il commence : c'est le supprimer)
        return
    }
    msg := "Plus de cycle à partir du " DateCourte(ymd, true) " : la semaine type reprend" (JoursSemaine.Count ? "." : " (elle est vide).")
    suite := [], rep := "No"                      ; les roulements prévus après (un arrêt seul n'a pas à être cité)
    for d in ClesCyclesApres(ymd)
        if JoursCycles[d].Length
            suite := ClesCyclesApres(ymd)
    if suite.Length {
        rep := JoursBoite(msg "`n`nDéjà prévu après : " DecrireCles(suite) ". Le supprimer aussi ?", T, "YesNoCancel Icon?")
        if (rep = "Cancel")
            return
    } else if (JoursBoite(msg, T, "OKCancel Icon?") != "OK")
        return
    JoursCopieAvant()
    JoursStopperCycle(ymd, rep = "Yes")
    JoursChanges("arrêt du cycle le " DateCourte(ymd))
}

; « Supprimer ce cycle » (ligne du cycle) : le précédent reprend s'il y en a un ;
; sinon son 1er tour reste peint
JoursSupprimerCycle(debut, *) {
    global JoursCycles
    static T := "Mes jours : cycle"
    av := CycleDe(PlusJours(debut, -1)), nb := JoursCycles[debut].Length
    ap := ClesCyclesApres(debut), lim := ap.Length ? ap[1] : 0
    repeints := lim ? Min(nb, DateDiff(String(lim), String(debut), "Days")) : nb   ; (le repeint s'arrête à la ligne suivante)
    ; ce qui suivra, une fois la ligne retirée et la liste remise en ordre (essai sur une copie)
    vraie := JoursCycles, JoursCycles := vraie.Clone()
    try {
        JoursCycles.Delete(debut), JoursNormaliserCycles()
        suite := ClesCyclesApres(debut)
        fin := suite.Length ? " jusqu'au " DateCourte(PlusJours(suite[1], -1), true) " (puis " DecrireCles([suite[1]]) ")" : ""
    } finally JoursCycles := vraie
    base := JoursSemaine.Count ? "la semaine type reprend" : "plus rien"
    repeindre := false
    if IsObject(av) {
        if (JoursBoite("Supprimer le cycle du " DateCourte(debut, true) " ? Le cycle du " DateCourte(av.debut, true)
            . " reprend à sa place" fin ". Ctrl+Z annule.", T, "OKCancel Icon?") != "OK")
            return
    } else if IsObject(CycleAvant(debut)) {       ; une reprise après un arrêt : rien à repeindre
        if (JoursBoite("Supprimer le cycle du " DateCourte(debut, true) " ? À partir de ce jour, " base fin ". Ctrl+Z annule.",
            T, "OKCancel Icon?") != "OK")
            return
    } else {
        ensuite := (lim && suite.Length && suite[1] = lim && PlusJours(debut, repeints) = lim) ? DecrireCles([lim]) : base fin   ; (repeint jusqu'à la ligne suivante)
        rep := JoursBoite("Supprimer le cycle du " DateCourte(debut, true) " ?`n`nOui : ses " repeints " premiers jours (jusqu'au "
            . DateCourte(PlusJours(debut, repeints - 1)) ") restent peints, en jours posés (utile s'ils t'ont servi de modèle), puis "
            . ensuite ".`nNon : " base " à partir de ce jour" fin ".`n`nCtrl+Z annule.", T, "YesNoCancel Icon?")
        if (rep = "Cancel")
            return
        repeindre := rep = "Yes"
    }
    JoursCopieAvant()
    JoursRetirerCycle(debut, repeindre)
    JoursChanges("suppression du cycle du " DateCourte(debut))
}

; ---------- Types ----------

; Nom refusé : déjà pris par un autre type, ou « Effacer » (les menus ne
; distinguent pas deux éléments de même nom, casse comprise)
NomTypePris(nom, sauf := "") {
    if !StrCompare(nom, "Effacer", "Locale")
        return true
    for ty in JoursTypes
        if (ty.id != sauf && !StrCompare(ty.nom, nom, "Locale"))
            return true
    return false
}

JoursNouveauType(*) {
    global JoursPinceau
    static enCours := false                       ; (un double-clic sur « + Type » : une seule saisie)
    if (enCours || JoursTypes.Length >= JOURS_TYPES_MAX)
        return
    enCours := true
    try r := JoursSaisie("Nom du nouveau type de jour (Télétravail, RTT, Nuit, Formation…) :", "Mes jours", "w380 h130")
    finally enCours := false
    nom := NomTypePropre(r.Value)
    if (r.Result != "OK" || nom = "")
        return
    if NomTypePris(nom) {
        JoursBoite("Le nom « " nom " » est déjà pris.", "Mes jours", "Iconi")
        return
    }
    ; identifiant : le nom sans accents ni espaces, rendu unique
    base := RegExReplace(StrLower(SansAccents(StrUpper(nom))), "[^a-z0-9]", ""), base := (base = "") ? "type" : SubStr(base, 1, 16), id := base, n := 1
    while IsObject(TypeParId(JoursTypes, id))
        id := base (++n)
    couleur := 0xFF98989D
    for v in JOURS_PALETTE {                      ; la première couleur libre de la palette
        c := 0xFF000000 | Integer("0x" v[1]), libre := true
        for ty in JoursTypes
            libre := libre && (ty.c != c)
        if libre {
            couleur := c
            break
        }
    }
    JoursTypes.Push({id: id, nom: nom, c: couleur, annonce: false, repos: false})
    JoursPinceau := id
    JoursChanges("nouveau type " nom)
}

JoursRenommer(id) {
    if !IsObject(ty := TypeParId(JoursTypes, id))
        return
    r := JoursSaisie("Nouveau nom du type « " ty.nom " » :", "Mes jours", "w380 h130", ty.nom)
    nom := NomTypePropre(r.Value)
    if (r.Result != "OK" || nom = "")
        return
    if NomTypePris(nom, ty.id) {
        JoursBoite("Le nom « " nom " » est déjà pris.", "Mes jours", "Iconi")
        return
    }
    ty.nom := nom
    JoursChanges("nom du type")
}

JoursCouleur(id, c, *) {
    if !IsObject(ty := TypeParId(JoursTypes, id))
        return
    ty.c := c
    JoursChanges("couleur du type")
}

; Sélecteur de couleur de Windows (ChooseColorW) : ARGB choisi, ou ""
JoursCouleurLibre(id) {
    if !IsObject(ty := TypeParId(JoursTypes, id))
        return
    static perso := Buffer(64, 0xFF)              ; 16 couleurs personnalisées, gardées d'une fois à l'autre
    cc := Buffer(72, 0)                           ; CHOOSECOLORW (64 bits)
    NumPut("UInt", 72, cc, 0)
    NumPut("Ptr", JoursHwnd, cc, 8)
    NumPut("UInt", ((ty.c & 0xFF) << 16) | (ty.c & 0xFF00) | ((ty.c >> 16) & 0xFF), cc, 24)   ; ARGB → 0x00BBGGRR
    NumPut("Ptr", perso.Ptr, cc, 32)
    NumPut("UInt", 0x3, cc, 40)                   ; CC_RGBINIT | CC_FULLOPEN
    global SurgieDialogue
    SurgieDialogue += 1
    try ok := DllCall("comdlg32\ChooseColorW", "Ptr", cc)
    finally SurgieDialogue -= 1
    if !ok
        return
    r := NumGet(cc, 24, "UInt")
    ty.c := 0xFF000000 | ((r & 0xFF) << 16) | (r & 0xFF00) | ((r >> 16) & 0xFF)
    JoursChanges("couleur du type")
}

JoursAnnoncer(id) {
    if !IsObject(ty := TypeParId(JoursTypes, id))
        return
    ty.annonce := !ty.annonce
    JoursChanges("annonce du type")
}

; « Jour non travaillé » : il ne coupe pas une période de congé, et ne compte
; pas comme une reprise
JoursNonTravaille(id) {
    if !IsObject(ty := TypeParId(JoursTypes, id))
        return
    ty.repos := !ty.repos
    JoursChanges("jour non travaillé")
}

JoursSupprimerType(id) {
    global JoursTypes, JoursPinceau
    if !IsObject(ty := TypeParId(JoursTypes, id))
        return
    if (JoursTypes.Length <= 1) {
        JoursBoite("Il faut garder au moins un type de jour.", "Mes jours", "Iconi")
        return
    }
    n := 0, nc := 0
    for d, v in JoursPoses
        n += (v = id)
    for j, v in JoursSemaine
        n += (v = id)
    for d, motif in JoursCycles
        for el in motif
            nc += (el = id)
    if ((n || nc) && JoursBoite("Supprimer le type « " ty.nom " » ? "
        . (n ? "Les " n " jours (posés ou de la semaine type) de ce type seront effacés. " : "")
        . (nc ? "Dans les cycles, ses " nc " jours deviendront « sans type » (le rythme ne change pas). " : "")
        . "Ctrl+Z annule.", "Mes jours", "YesNo Icon?") != "Yes")
        return
    if (n || nc)
        JoursCopieAvant()
    for d, v in JoursPoses.Clone()
        if (v = id)
            JoursPoses.Delete(d)
    for j, v in JoursSemaine.Clone()
        if (v = id)
            JoursSemaine.Delete(j)
    RetirerTypeDesMotifs(id)
    reste := []
    for t2 in JoursTypes
        if (t2.id != id)
            reste.Push(t2)
    JoursTypes := reste
    if (JoursPinceau = id)
        JoursPinceau := JoursTypes[1].id
    JoursChanges("suppression du type " ty.nom)
}

ChoisirMarque(v, *) {
    global JoursMarque := v
    SauverReglages()
    CocherMenus()
    Redessiner()
}

; ---------- Tests ----------

; La fenêtre « Mes jours » (mois AAAAMM, celui d'aujourd'hui par défaut) sur un fond gris ; « annee » : les totaux de l'année
ApercuJours(fichier, mois := "", annee := false) {
    global JoursPinceau
    LireJours()
    if (JoursPinceau != "-" && !IsObject(TypeParId(JoursTypes, JoursPinceau)))
        JoursPinceau := JoursTypes[1].id
    kp := A_ScreenDPI / 96
    mp := MiseEnPageJours((mois != "") ? mois : SubStr(Aujourdhui(), 1, 6), kp, annee = "annee" || annee = 1)
    w := Round(mp.w * kp), h := Round(mp.h * kp), m := Round(16 * kp)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w + 2 * m, "Int", h + 2 * m, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, w + 2 * m, h + 2 * m, 0xFF5A6570)
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", gr, "Float", m, "Float", m, "Int", 0)
    DessinerJours(gr, w, h, kp, mp)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

; Auto-test des règles (semaine type, cycles, jours posés, périodes, annonces, fichier).
; Les valeurs attendues du 2-2-3 sont calculées à part (pas avec la formule testée).
TestJours(fichier) {
    global JoursTypes, JoursSemaine, JoursPoses, JoursCycles, JoursRejets, JoursDate, HeureTest, JoursAnnulable, JoursAnnulSens, JoursAnnulLib, JoursTouches
    global F_JOURS := A_Temp "\widget-meteo-testjours-" A_TickCount ".txt"   ; jamais ton vrai jours.txt
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    Ev(ymd) {                                     ; les textes du calendrier ce jour-là (noms à part : une
        global HeureTest := ymd "120000"          ; fonction imbriquée partage les variables de TestJours)
        evt := ""
        for evj in EvenementsJours(Aujourdhui())
            evt .= ((evt = "") ? "" : " | ") evj.long
        return evt
    }
    Verifier(JourISO(20540928) = 1 && JourISO(20541004) = 7 && JourISO(20540926) = 6, "JourISO : lundi 28/09 = 1, dimanche 4/10 = 7, samedi 26/09 = 6")

    ; ---- semaine type (lundi-vendredi Travail) et congés posés
    JoursTypes := JoursDefaut(), JoursSemaine := Map(), JoursPoses := Map(), JoursCycles := Map(), JoursRejets := []
    Loop 5
        JoursSemaine[A_Index] := "travail"
    Verifier(IdDuJour(20540930) = "travail" && IdDuJour(20541003) = "", "semaine type : mercredi travail, samedi rien")
    Loop 5
        JoursPoserJour(PlusJours(20541019, A_Index - 1), "conge")   ; une semaine de congé
    Verifier(IdDuJour(20541021) = "conge" && JoursPoses.Count = 5, "congé posé sur 5 jours de la semaine type")
    JoursPoserJour(20541021, "-")
    Verifier(JoursPoses[20541021] = "-" && IdDuJour(20541021) = "", "jour vidé sur la semaine type : noté « - »")
    JoursPoserJour(20541021, "travail")
    Verifier(!JoursPoses.Has(20541021) && IdDuJour(20541021) = "travail", "remis comme la semaine type : plus noté")
    JoursPoserJour(20541021, "conge")
    Verifier(FinPeriode(20541019, "conge") = 20541023, "période de congé du 19 au 23/10")
    JoursPoserJour(20541021, "=")
    Verifier(!JoursPoses.Has(20541021) && IdDuJour(20541021) = "travail", "congé retiré (« = ») : retour à la semaine type")
    JoursPoserJour(20541021, "conge")
    Loop 5
        JoursPoserJour(PlusJours(20541026, A_Index - 1), "conge")   ; 2e semaine, après un week-end sans type
    Verifier(FinPeriode(20541019, "conge") = 20541030 && FinPeriode(20541023, "conge") = 20541030, "congé du 19 au 30/10 : le week-end sans type ne coupe pas")
    Loop 5
        JoursPoserJour(PlusJours(20541026, A_Index - 1), "=")
    Verifier(FinPeriode(20541019, "conge") = 20541023 && JoursPoses.Count = 5, "2e semaine retirée : fin le 23/10")
    JoursPoserJour(20541024, "repos"), JoursPoserJour(20541026, "conge")
    Verifier(FinPeriode(20541019, "conge") = 20541026, "un samedi Repos (non travaillé) ne coupe pas le congé : fin lun. 26/10")
    JoursPoserJour(20541024, "travail")
    Verifier(FinPeriode(20541019, "conge") = 20541023, "un samedi Travail le coupe")
    JoursPoses.Delete(20541024), JoursPoses.Delete(20541026)
    Verifier(Ev(20541016) = "Congé lundi", "vendredi 16/10 : « " Ev(20541016) " »")
    Verifier(Ev(20541018) = "Congé demain", "dimanche 18/10 : « " Ev(20541018) " »")
    Verifier(Ev(20541020) = "Congé, reprise lun. 26 oct.", "mardi 20/10 : « " Ev(20541020) " »")
    li := ListeJours(20541016)
    Verifier(li.Length = 1 && li[1].detail = "lun. 19 oct. → ven. 23 oct. · dans 3" Chr(0xA0) "j", "prévisions le 16/10 : « " (li.Length ? li[1].detail : "") " »")
    Verifier(Ev(20541014) = "", "mercredi 14/10 : rien à annoncer")

    ; ---- le 2-2-3 de 14 jours du lundi 21/09/2054, peint puis répété
    JoursSemaine := Map(), JoursPoses := Map(), JoursCycles := Map()
    tour := ["travail", "travail", "repos", "repos", "travail", "travail", "travail", "repos", "repos", "travail", "travail", "repos", "repos", "repos"]
    for i, id in tour
        JoursPoserJour(PlusJours(20540921, i - 1), id)
    mp := MotifPeint(20540921), t := ""
    for id in mp
        t .= SubStr(id, 1, 1)
    Verifier(t = "ttrrtttrrttrrr", "motif lu sur le tour peint : « " t " »")
    lettres := LettresTypes()
    Verifier(MotifTexte(tour, lettres) = "TTRRTTT RRTTRRR" && lettres.id["conge"] = "C", "lettres : « " MotifTexte(tour, lettres) " »")
    lu := LireMotif("ttrr ttt rrtt rrr", lettres)
    Verifier(IsObject(lu) && lu.Length = 14 && lu[5] = "travail" && lu[14] = "repos", "motif écrit en lettres relu")
    Verifier(!IsObject(LireMotif("TTX", lettres)) && !IsObject(LireMotif("T", lettres)), "lettre inconnue, cycle d'un jour : refusés")
    Verifier(ResumeMotif(tour) = "2 Travail · 2 Repos · 3 Travail · 2 Repos · 2 Travail · 3 Repos", "résumé : « " ResumeMotif(tour) " »")
    JoursAppliquerCycle(20540921, lu)
    Verifier(JoursPoses.Count = 0 && JoursCycles.Count = 1 && JoursUtilises(), "cycle posé : le tour peint n'est plus noté, le planning reste actif")
    Verifier(IdDuJour(20540920) = "" && IdDuJour(20540921) = "travail" && IdDuJour(20541005) = "travail", "20/09 rien, 21/09 et 05/10 Travail")
    Verifier(IdDuJour(20560229) = "repos" && IdDuJour(20560301) = "travail" && IdDuJour(20581231) = "repos", "29/02/2056 Repos, 01/03/2056 Travail, 31/12/2058 Repos")
    t26 := TotauxAnnee("2054"), t27 := TotauxAnnee("2055"), t28 := TotauxAnnee("2056")
    Verifier(t26["travail"] = 51 && t26["repos"] = 51 && t27["travail"] = 183 && t27["repos"] = 182 && t28["travail"] = 184 && t28["repos"] = 182,
        "totaux : 2054 51/51, 2055 183/182, 2056 184/182 (bissextile)")
    Verifier(IsObject(MotifPeint(20541005)) && MotifTourne(CycleDe(20541007), 20541007)[1] = "repos", "motif lu au 7/10 : commence par Repos")

    ; ---- congés sur les jours travaillés, repos au milieu
    for d in [20540930, 20541001, 20541005, 20541006]
        JoursPoserJour(d, "conge")
    Verifier(FinPeriode(20540930, "conge") = 20541006 && RepriseApres(20541006) = 20541009, "congé 30/09 → 06/10 à travers les repos, reprise ven. 09/10")
    Verifier(Ev(20540929) = "Congé demain", "mar. 29/09 (Repos) : « " Ev(20540929) " »")
    Verifier(Ev(20540927) = "Congé mercredi", "dim. 27/09 (Travail, puis 2 repos) : « " Ev(20540927) " »")
    Verifier(Ev(20540925) = "", "ven. 25/09 (Travail, puis Travail) : rien")
    Verifier(Ev(20540930) = "Congé, reprise ven. 9 oct.", "mer. 30/09 : « " Ev(20540930) " »")
    Verifier(Ev(20541003) = "Congé, reprise ven. 9 oct.", "sam. 03/10 (Repos au milieu du congé) : « " Ev(20541003) " »")
    li := ListeJours(20541003)
    Verifier(li.Length = 1 && li[1].detail = "jusqu'au mar. 6 oct. · reprise ven. 9 oct.", "prévisions le 03/10 : « " (li.Length ? li[1].detail : "") " »")
    Verifier(Ev(20541007) = "", "mer. 07/10 (Repos après le congé) : rien")
    JoursPoserJour(20541001, "=")
    Verifier(!JoursPoses.Has(20541001) && IdDuJour(20541001) = "travail", "congé retiré : retour au cycle (Travail)")
    JoursPoserJour(20541002, "-")
    Verifier(JoursPoses[20541002] = "-" && IdDuJour(20541002) = "", "Effacer sur un jour du cycle : rien ce jour-là")
    JoursPoserJour(20541002, "repos")
    Verifier(!JoursPoses.Has(20541002), "remis comme le cycle : plus noté")
    for d in [20540930, 20541005, 20541006]
        JoursPoses.Delete(d)
    ty := TypeParId(JoursTypes, "repos"), ty.annonce := true
    Verifier(Ev(20540922) = "Repos demain", "Repos annoncé, mar. 22/09 : « " Ev(20540922) " »")
    ty.annonce := false

    ; ---- glisser : congé sur des jours de repos sautés, retrait limité au type
    global JoursPinceau := "conge"
    Verifier(TraitSaute({mode: "conge", retrait: false, origine: "travail"}, 20540923) && !TraitSaute({mode: "conge", retrait: false, origine: "travail"}, 20540925),
        "glisser un congé : saute les repos, pose sur le travail")
    JoursPoserJour(20540925, "repos")             ; un repos échangé : gardé ; mais une Maladie partie d'un congé remplace les congés
    JoursPoserJour(20540926, "conge")
    Verifier(TraitSaute({mode: "conge", retrait: false, origine: "travail"}, 20540925) && !TraitSaute({mode: "repos", retrait: false, origine: "conge"}, 20540926),
        "glisser : un repos échangé reste, un jour du type de départ est remplacé")
    JoursPoses.Delete(20540925), JoursPoses.Delete(20540926)
    Verifier(TraitSaute({mode: "conge", retrait: false, origine: ""}, 20540929), "glisser un congé parti d'un Repos du cycle : les autres repos sont sautés")
    JoursPinceau := "travail"
    Verifier(TraitSaute({mode: "=", retrait: true, origine: "travail"}, 20540923) && !TraitSaute({mode: "=", retrait: true, origine: "travail"}, 20540925), "retrait : seulement les jours du même type")

    ; ---- arrêt, reprise au même rythme, départ plus tôt, arrêts inutiles
    JoursStopperCycle(20550101)
    Verifier(IdDuJour(20550105) = "" && IdDuJour(20541231) != "", "arrêt au 01/01/2055 : plus rien après, rien ne change avant")
    JoursAppliquerCycle(20550301, MotifTourne(CycleAvant(20550301), 20550301))
    Verifier(IdDuJour(20550301) = "repos" && IdDuJour(20550302) = "repos" && IdDuJour(20550303) = "travail", "repris le 01/03/2055 au même rythme (R R T)")
    JoursAppliquerCycle(20540101, MotifTourne(CycleApres(20540101), 20540101))
    Verifier(!JoursCycles.Has(20540921) && JoursCycles.Count = 3 && IdDuJour(20540921) = "travail", "parti du 01/01/2054 : la ligne du 21/09 fusionne")
    JoursCycles[20530101] := [], JoursNormaliserCycles()
    Verifier(!JoursCycles.Has(20530101), "arrêt sans cycle avant : retiré")
    JoursAppliquerCycle(20540922, ["travail", "repos"])
    JoursAppliquerCycle(20540921, lu, true)       ; mauvais départ corrigé (« Oui : tout remplacer ») : la ligne du 22/09 disparaît
    Verifier(!JoursCycles.Has(20540922) && IdDuJour(20541005) = "travail", "mauvais départ (22/09) puis Répéter le 21/09 : corrigé")
    JoursCycles := Map(), JoursAppliquerCycle(20540921, lu)
    JoursRetirerCycle(20540921)
    Verifier(!JoursCycles.Count && JoursPoses.Count = 14 && IdDuJour(20540927) = "travail", "cycle supprimé : son 1er tour reste peint")
    JoursAppliquerCycle(20540921, lu)

    ; ---- revue : roulements déjà prévus gardés, reprise, arrêt au début, motif lu, longues périodes
    JoursCycles[20541001] := ["travail", "travail", "travail", "travail", "repos", "repos", "repos", "repos"]
    JoursAppliquerCycle(20540921, lu)             ; motif tapé (pas lu sur la peinture)
    Verifier(JoursCycles.Has(20541001), "motif tapé : le roulement prévu dans son 1er tour (01/10) reste")
    JoursRetirerCycle(20540921)
    Verifier(!JoursPoses.Has(20541002) && JoursPoses.Get(20540930, "") = "travail" && IdDuJour(20541002) = "travail",
        "supprimé : le 1er tour repeint s'arrête au roulement suivant (01/10)")
    JoursPoses := Map(), JoursCycles := Map(), JoursAppliquerCycle(20540921, lu)
    JoursStopperCycle(20540921)
    Verifier(!JoursCycles.Count && !JoursPoses.Count, "arrêter le 1er cycle le jour où il commence : retiré, rien de repeint")
    JoursAppliquerCycle(20540921, lu)
    JoursCycles[20550701] := [], JoursCycles[20550906] := ["travail", "repos"]
    JoursAppliquerCycle(20550830, MotifTourne(CycleDe(20550630), 20550830))
    Verifier(JoursCycles.Has(20550906) && IdDuJour(20550830) = "repos" && IdDuJour(20550906) = "travail", "reprise le 30/08/2055 : le roulement du 06/09 reste")
    pr := CyclesPrecedents(20550910)
    Verifier(pr.Length = 1 && pr[1].debut = 20540921, "sous un autre roulement : le 2-2-3 proposé une fois (reprise au même rythme comprise)")
    Verifier(DecrireCles([20550701, 20550906]) = "l'arrêt du jeu. 1er juil. 2055 et le cycle de 2" Chr(0xA0) "j du lun. 6 sept. 2055", "« " DecrireCles([20550701, 20550906]) " »")
    JoursCycles := Map(), JoursAppliquerCycle(20540921, lu)
    JoursCycles := Map()
    for i, id in tour
        JoursPoserJour(PlusJours(20540921, i - 1), id)
    JoursPoserJour(20541005, "travail"), JoursPoserJour(20541006, "travail")
    Verifier(MotifPeint(20540921).Length = 14, "16 jours peints : cycle de 14 proposé")
    Loop 5
        JoursPoserJour(PlusJours(20541007, A_Index - 1), tour[A_Index + 2])
    Verifier(MotifPeint(20540921).Length = 14, "21 jours peints : cycle de 14 proposé")
    t := MotifTexte(PeriodeMotif(["travail", "travail", "-", "-", "travail", "travail", "travail", "-", "-", "travail", "travail"], 3), lettres)
    Verifier(t = "TT--TTT --TT---", "repos non peints : « " t " » (14 jours)")
    Verifier(PeriodeMotif(["travail", "travail", "travail", "travail", "repos", "repos", "repos", "repos"], 6).Length = 8
        && PeriodeMotif(["travail", "travail", "repos", "repos"], 6).Length = 4, "4-4 et 2-2 peints une fois : 8 et 4 jours (pas complétés)")
    JoursPoses := Map(), JoursTouches := Map()
    Loop 5
        JoursSemaine[A_Index] := "travail"        ; une ancienne semaine type, puis le 2-2-3 peint par-dessus
    for i, id in tour
        JoursPoserJour(PlusJours(20540921, i - 1), id)
    Verifier(MotifPeint(20540921).Length = 14, "semaine type + 2-2-3 peint : cycle de 14 proposé (pas 399)")
    JoursPoses := Map(), JoursTouches := Map()
    for i, id in ["travail", "travail", "travail", "travail", "repos", "repos", "repos", "repos"]
        JoursPoserJour(PlusJours(20540921, i - 1), id)
    Verifier(MotifPeint(20540921).Length = 8, "semaine type + 4-4 peint : cycle de 8 proposé")
    Verifier(PeriodeMotif(["travail", "repos", "repos", "travail", "travail", "travail", "repos", "repos", "travail", "travail", "repos", "repos", "repos", "travail"], 6).Length = 14
        && PeriodeMotif(["travail", "travail", "travail", "repos", "repos", "repos", "repos", "travail"], 6).Length = 8
        && PeriodeMotif(["travail", "travail", "travail", "travail", "travail", "repos", "repos", "repos", "repos"], 6).Length = 9,
        "tours exacts commencés au milieu d'un bloc (2-2-3, 4-4) et 5-4 : rendus entiers")
    JoursPoserJour(20540930, "repos"), JoursPoserJour(20540930, "=")
    Verifier(!JoursTouches.Has(20540930), "un jour remis à la base n'est plus compté comme peint")
    JoursPoses := Map(), JoursTouches := Map()
    for i, id in ["repos", "repos", "travail", "travail", "travail", "repos", "repos", "travail", "travail", "repos", "repos", "repos", "travail", "travail"]
        JoursPoserJour(PlusJours(20540923, i - 1), id)   ; 2-2-3 peint dès un mercredi : les 2 derniers jours pareils à la semaine type
    Verifier(MotifPeint(20540923).Length = 14, "semaine type + 2-2-3 peint dès un mercredi : 14 (jours touchés au pinceau)")
    JoursPoses := Map(), JoursTouches := Map()
    Loop 5
        JoursPoserJour(PlusJours(20540928, A_Index - 1), "-")   ; une semaine vidée au pinceau Effacer
    Verifier(IsObject(MotifPeint(20540921)), "semaine vidée au pinceau Effacer : pas d'erreur")
    JoursSemaine := Map(), JoursTouches := Map()
    JoursPoses := Map(), JoursCycles := Map(), JoursAppliquerCycle(20540921, ["travail", "travail", "travail", "travail", "repos", "repos", "repos", "repos"])
    Verifier(MotifPeint(20540922, 20540929).Length = 8, "sous un 4-4, au rang 2 : les 8 jours affichés")
    JoursCycles := Map()
    JoursPoses := Map(), JoursAppliquerCycle(20540921, lu)
    d := 20541005                                 ; congé de 7 mois sur les jours travaillés
    while (d <= 20550430) {
        if (IdDuJour(d) = "travail")
            JoursPoserJour(d, "conge")
        d := PlusJours(d, 1)
    }
    Verifier(FinPeriode(20541005, "conge") = 20550429 && RepriseApres(20550429) = 20550503, "congé de 7 mois : fin jeu. 29/04/2055, reprise lun. 03/05")
    t := TextePeriode(PeriodeEnCours(20541220), 20541220)
    Verifier(IsObject(t) && InStr(t.long, "2055"), "l'année quand la fin n'est pas cette année : « " (IsObject(t) ? t.long : "") " »")
    d := 20550501
    while (d <= 20561231) {
        if (IdDuJour(d) = "travail")
            JoursPoserJour(d, "conge")
        d := PlusJours(d, 1)
    }
    p := PeriodeEnCours(20541005), t := TextePeriode(p, 20541005)
    Verifier(p.auBout && t.long = "Congé (plus d'un an)", "congé de plus de 400 jours : « " t.long " »")
    JoursPoses := Map()
    JoursTypes.Push({id: "nuit", nom: "Nuit", c: 0xFF5E5CE6, annonce: true, repos: false})
    JoursCycles := Map(), JoursAppliquerCycle(20540921, ["nuit", "nuit", "-", "-", "nuit", "nuit", "nuit", "-", "-", "nuit", "nuit", "-", "-", "-"])
    Verifier(FinPeriode(20540921, "nuit") = 20540922, "Nuit annoncée, repos laissés « - » : « jusqu'au mar. 22 sept. »")
    JoursTypes.Pop(), JoursCycles := Map(), JoursAppliquerCycle(20540921, lu)
    JoursPoserJour(20541013, "inconnu")
    Verifier(!JoursPoses.Has(20541013), "un type inconnu n'est jamais posé")
    for nom in ["Matin", "Après-midi", "Nuit", "Formation"]
        JoursTypes.Push({id: "x" A_Index, nom: nom, c: 0xFF888888, annonce: false, repos: false})
    Loop 4
        JoursPoserJour(PlusJours(20541012, A_Index - 1), "x" A_Index)
    lr := LignesResume("205410", false, 1)
    Verifier(lr.Length = 2 && InStr(lr[2], "Formation"), "résumé long sur deux lignes : « " lr[1] " » / « " (lr.Length > 1 ? lr[2] : "") " »")
    JoursTypes.Length := 3, JoursPoses := Map()

    ; ---- type supprimé dans un motif ; fichier : enregistrement, relecture, lignes gardées
    JoursTypes.Push({id: "nuit", nom: "Nuit", c: 0xFF5E5CE6, annonce: false, repos: false})
    JoursAppliquerCycle(20541201, ["nuit", "nuit", "repos", "repos"])
    Verifier(RetirerTypeDesMotifs("nuit") = 2 && JoursCycles[20541201][1] = "-" && JoursCycles[20541201].Length = 4, "type supprimé : « - » dans le motif, rythme gardé")
    JoursTypes.Pop(), JoursCycles.Delete(20541201)
    JoursPoserJour(20541021, "conge")
    SauverJours()
    avant := JoursPoses.Count "|" JoursCycles.Count "|" JoursTypes.Length
    FileAppend("X|ligne inconnue`nC|2055-02-30|travail`n", F_JOURS, "UTF-8-RAW")
    JoursDate := ""
    Verifier(LireJours() && JoursPoses.Count "|" JoursCycles.Count "|" JoursTypes.Length = avant && JoursRejets.Length = 2
        && IdDuJour(20560229) = "repos" && TypeParId(JoursTypes, "conge").repos && !TypeParId(JoursTypes, "travail").repos,
        "relecture : cycle, drapeaux, 2 lignes non comprises (" avant ")")
    SauverJours()
    Verifier(InStr(FileRead(F_JOURS, "UTF-8"), "`nX|ligne inconnue`n"), "lignes non comprises gardées telles quelles")
    ; ancienne version (2.25) : pas de 6e champ ; un type à la main, un nom au lieu de l'id
    FileAppend("T|télétravail|Télétravail|#40C8E0|0`nJ|2054-11-02|Congé`nJ|2054-11-3|conge`n", F_JOURS, "UTF-8-RAW")
    JoursDate := ""
    Verifier(LireJours() && IsObject(TypeParId(JoursTypes, "télétravail")) && IdDuJour(20541102) = "conge" && !TypeParId(JoursTypes, "télétravail").repos,
        "ajouts à la main : type accentué, congé posé par son nom")
    Verifier(!NomTypePris("Télétravail2") && NomTypePris("congé") && NomTypePris("EFFACER") && !NomTypePris("Congé", "conge"),
        "noms refusés : déjà pris (casse ignorée), « Effacer »")
    JoursPinceau := "fantome", JoursDate := "", LireJours()
    Verifier(JoursPinceau = JoursTypes[1].id, "après relecture, le pinceau d'un type disparu revient à « " JoursTypes[1].nom " »")
    ; annuler : la dernière modification, puis l'annulation elle-même
    JoursPoserJour(20541111, "conge"), SauverJours("test")
    JoursAnnuler()
    Verifier(!JoursPoses.Has(20541111), "Ctrl+Z : le congé du 11/11 disparaît")
    JoursAnnuler()
    Verifier(JoursPoses.Get(20541111, "") = "conge" && JoursAnnulSens = "Annuler", "Ctrl+Z encore : il revient (Rétablir, puis Annuler)")
    TypeParId(JoursTypes, "travail").nom := "TRAVAIL", SauverJours("renommer")
    Verifier(JoursAnnulLib = "renommer", "un renommage en majuscules compte comme une modification")
    try FileDelete(F_JOURS)
    FileAppend(rapport "`n" echecs " échec(s)`n", fichier, "UTF-8")
}
