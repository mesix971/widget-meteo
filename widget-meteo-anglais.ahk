; =============================================================================
;  Widget météo — une phrase en français et sa traduction anglaise sur le
;  widget, pour apprendre l'anglais : une nouvelle toutes les 5 min, et un clic
;  dessus donne la suivante. Niveaux mélangés. Deux sources : la liste intégrée
;  (widget-meteo-anglais.txt, « niveau|français|anglais ») et un lot de phrases
;  de Tatoeba renouvelé chaque jour (anglais-tatoeba.txt, collecte des marchés ;
;  tatoeba.org, licence CC BY 2.0 FR). Chaque liste est parcourue dans un ordre
;  mélangé, sans répétition avant d'avoir tout vu (position gardée dans reglages.ini).
;  Inclus par widget-meteo.ahk (état : Phrases*, PhraseCour, AnglaisW… là-bas).
; =============================================================================

LirePhrases() {
    global PhrasesListe
    static date := ""
    try m := FileGetTime(F_PHRASES, "M")
    catch
        m := ""
    if (m != "" && m != date) {
        l := []
        try
            for ligne in StrSplit(FileRead(F_PHRASES, "UTF-8"), "`n", "`r") {
                c := StrSplit(ligne, "|")
                if (c.Length = 3 && IsInteger(c[1]) && c[2] != "" && c[3] != "" && SubStr(ligne, 1, 1) != "#")
                    l.Push({niv: Integer(c[1]), fr: c[2], en: c[3], src: "liste"})
            }
        PhrasesListe := l, date := m
    }
    LireTatoeba()
}

LireTatoeba() {
    global PhrasesTat, TatDate
    try m := FileGetTime(F_TATOEBA, "M")
    catch
        return false
    if (m = TatDate)
        return false
    l := [], maj := ""
    try
        for ligne in StrSplit(FileRead(F_TATOEBA, "UTF-8"), "`n", "`r") {
            if (SubStr(ligne, 1, 4) = "maj=") {
                maj := SubStr(ligne, 5)
                continue
            }
            c := StrSplit(ligne, "|")
            if (c.Length = 2 && c[1] != "" && c[2] != "")
                l.Push({fr: c[1], en: c[2], src: "tatoeba", lot: maj})
        }
    catch
        return false
    PhrasesTat := l, TatDate := m
    return true
}

PhraseCourante() => (AnglaisW && IsObject(PhraseCour)) ? PhraseCour : ""

; Ordre mélangé des n éléments d'une liste, toujours le même pour une graine
; (Fisher-Yates sur un générateur congruentiel) : la position suffit à reprendre
OrdreMelange(n, graine) {
    o := []
    Loop n
        o.Push(A_Index)
    x := graine & 0x7FFFFFFF
    i := n
    while (i > 1) {
        x := Mod(x * 1103515245 + 12345, 2147483648)
        j := Mod(x // 65536, i) + 1
        tmp := o[i], o[i] := o[j], o[j] := tmp
        i--
    }
    return o
}

; La phrase suivante d'une source (« liste » ou « tatoeba ») : position suivante
; dans l'ordre mélangé ; tout vu : nouvel ordre. "" si la source est vide.
PhraseDe(src) {
    l := (src = "liste") ? PhrasesListe : PhrasesTat
    if !l.Length
        return ""
    cle := "anglais_" src, lot := (src = "tatoeba" && l.Length) ? l[1].lot : ""
    etat := StrSplit(IniRead(F_REGLAGES, "widget", cle, ""), ",")
    graine := (etat.Length >= 2 && IsInteger(etat[1])) ? Integer(etat[1]) : 0
    pos := (etat.Length >= 2 && IsInteger(etat[2])) ? Integer(etat[2]) : 0
    if (src = "tatoeba" && (etat.Length < 3 || etat[3] != lot))   ; nouveau lot du jour : on repart du début
        pos := 0
    if (!graine || pos >= l.Length)
        graine := Mod(A_TickCount * 7919 + A_Sec * 131 + A_MSec, 2147483647) + 1, pos := 0
    ordre := OrdreMelange(l.Length, graine)
    pos += 1
    try IniWrite(graine "," pos (lot != "" ? "," lot : ""), F_REGLAGES, "widget", cle)
    return l[ordre[pos]]
}

; Choisit la phrase suivante selon la source réglée ; « mix » : une sur deux de
; chaque (ou de celle qui reste, si l'autre est vide)
ChoisirPhrase() {
    static tour := 0
    global PhraseCour, PhraseT0
    tour += 1
    ordre := (AnglaisSource = "liste") ? ["liste"] : (AnglaisSource = "tatoeba") ? ["tatoeba", "liste"]
        : Mod(tour, 2) ? ["liste", "tatoeba"] : ["tatoeba", "liste"]
    for src in ordre
        if IsObject(p := PhraseDe(src)) {
            PhraseCour := p, PhraseT0 := MaintenantUnix()
            return true
        }
    return false
}

; Un clic sur la phrase : la suivante tout de suite
PhraseSuivante(*) {
    if (!AnglaisW || !ChoisirPhrase())
        return
    Redessiner()
    ReglAJour()
}

; Tic de minute : une nouvelle phrase et un nouveau titre à la une toutes les
; 5 min (« forcer » : tout de suite) ; renvoie true si l'affichage change
MajRotation(forcer := false) {
    global UneRang, UneT0
    maint := MaintenantUnix(), change := false
    if (AnglaisW && (forcer || !IsObject(PhraseCour) || maint - PhraseT0 >= PHRASE_S))
        change := ChoisirPhrase() || change
    if (ActusW && ListeUneWidget().Length && maint - UneT0 >= PHRASE_S) {
        if UneT0                                  ; (au démarrage : le premier titre d'abord)
            UneRang += 1
        UneT0 := maint, change := true
    }
    return change
}

; La phrase en un bloc dans la bande (haut en yHaut, 1,7 ligne) : le français
; puis l'anglais, rapprochés, « FR » et « EN » l'un sous l'autre (le bloc est
; centré d'un seul tenant en iPhone, pas chaque ligne)
BlocPhrase(L, t, u, x, yHaut, largeur, align) {
    p := PhraseCourante()
    if !IsObject(p)
        return
    emT := EmPourCapitale(P_DATE, 0.027 * u), emF := EmPourCapitale(P_TEXTE, 0.042 * u), emE := EmPourCapitale(P_DATE, 0.046 * u)
    wt := Max(LargeurTexte("FR", P_DATE, emT), LargeurTexte("EN", P_DATE, emT)) + 0.03 * u
    fr := Tronquer(p.fr, P_TEXTE, emF, largeur - wt), en := Tronquer(p.en, P_DATE, emE, largeur - wt)
    tot := wt + Max(LargeurTexte(fr, P_TEXTE, emF), LargeurTexte(en, P_DATE, emE))
    xx := align ? x + Max(0, (largeur - tot) / 2) : x
    y1 := yHaut + 0.079 * u, y2 := y1 + 0.087 * u
    Poser(L, "FR", P_DATE, emT, xx, y1, 0, t.second)
    Poser(L, fr, P_TEXTE, emF, xx + wt, y1, 0, t.second)
    Poser(L, "EN", P_DATE, emT, xx, y2, 0, t.second)
    Poser(L, en, P_DATE, emE, xx + wt, y2, 0, t.texte)
    NoterZone("phrase", {x: xx, y: yHaut + 0.01 * u, w: tot, h: y2 - yHaut + 0.02 * u})
}

; Réglages ▸ Anglais
BasculerAnglaisW(*) {
    global AnglaisW := !AnglaisW
    if (AnglaisW && !IsObject(PhraseCour))
        ChoisirPhrase()
    ApresReglageMarches(AnglaisW && AnglaisSource != "liste")
}

ChoisirAnglaisSource(v, *) {
    global AnglaisSource := v
    ChoisirPhrase()
    ApresReglageMarches(v != "liste")
}

; ---------- Tests ----------

; Auto-test : la liste intégrée (format, longueurs, doublons), l'ordre mélangé,
; la rotation sans répétition et l'alternance des sources
TestAnglais(fichier) {
    global AnglaisW, AnglaisSource, PhraseCour, PhraseT0, PhrasesTat
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    LirePhrases()
    niv := Map(1, 0, 2, 0, 3, 0), vus := Map(), doublons := [], longues := [], total := 0, lignesKo := []
    for ligne in StrSplit(FileRead(F_PHRASES, "UTF-8"), "`n", "`r") {
        if (ligne = "" || SubStr(ligne, 1, 1) = "#")
            continue
        c := StrSplit(ligne, "|")
        if !(c.Length = 3 && IsInteger(c[1]) && niv.Has(Integer(c[1])) && Trim(c[2]) = c[2] && Trim(c[3]) = c[3] && c[2] != "" && c[3] != "") {
            lignesKo.Push(ligne)
            continue
        }
        total += 1, niv[Integer(c[1])] += 1
        if vus.Has(c[2])
            doublons.Push(c[2])
        vus[c[2]] := 1
        if (StrLen(c[2]) > 70 || StrLen(c[3]) > 70)
            longues.Push(c[2])
    }
    Verifier(!lignesKo.Length, "liste : toutes les lignes au format niveau|français|anglais" (lignesKo.Length ? " (ex. « " lignesKo[1] " »)" : ""))
    Verifier(total >= 400 && PhrasesListe.Length = total, "liste : " total " phrases (" niv[1] " débutant, " niv[2] " intermédiaire, " niv[3] " avancé)")
    Verifier(niv[1] >= 100 && niv[2] >= 100 && niv[3] >= 100, "liste : au moins 100 phrases par niveau")
    Verifier(!doublons.Length, "liste : pas de doublon" (doublons.Length ? " (« " doublons[1] " »)" : ""))
    Verifier(!longues.Length, "liste : 70 caractères au plus (tient sur le widget)" (longues.Length ? " (« " longues[1] " »)" : ""))
    ; ordre mélangé : une permutation, reproductible, différente d'une graine à l'autre
    o1 := OrdreMelange(50, 12345), o2 := OrdreMelange(50, 12345), o3 := OrdreMelange(50, 999)
    perm := Map(), pareil := true, diff := false
    for i, v in o1
        perm[v] := 1, pareil := pareil && o2[i] = v, diff := diff || o3[i] != v
    Verifier(perm.Count = 50 && pareil && diff, "ordre mélangé : permutation reproductible")
    ; rotation : toute la liste vue une fois avant la moindre répétition
    AnglaisW := true, AnglaisSource := "liste"
    try IniDelete(F_REGLAGES, "widget", "anglais_liste")
    vus := Map(), repet := false
    Loop PhrasesListe.Length {
        ChoisirPhrase()
        repet := repet || vus.Has(PhraseCour.fr)
        vus[PhraseCour.fr] := 1
    }
    Verifier(!repet && vus.Count = PhrasesListe.Length, "rotation : les " vus.Count " phrases une fois chacune, sans répétition")
    ChoisirPhrase()
    Verifier(IsObject(PhraseCour) && PhraseCour.src = "liste", "tout vu : un nouvel ordre repart")
    ; mélange des sources (lot Tatoeba simulé)
    PhrasesTat := [{fr: "Le chat dort.", en: "The cat is sleeping.", src: "tatoeba", lot: "1"}, {fr: "Il pleut.", en: "It's raining.", src: "tatoeba", lot: "1"}]
    AnglaisSource := "mix", srcs := Map()
    Loop 4
        ChoisirPhrase(), srcs[PhraseCour.src] := srcs.Get(PhraseCour.src, 0) + 1
    Verifier(srcs.Get("liste", 0) = 2 && srcs.Get("tatoeba", 0) = 2, "mélange : une phrase sur deux de chaque source")
    AnglaisSource := "tatoeba"
    ChoisirPhrase()
    Verifier(PhraseCour.src = "tatoeba", "source Tatoeba seule")
    PhrasesTat := []
    ChoisirPhrase()
    Verifier(PhraseCour.src = "liste", "Tatoeba vide (hors ligne) : la liste prend le relais")
    ; rotation au tic : 5 min
    AnglaisSource := "liste", ChoisirPhrase(), avant := PhraseCour.fr, PhraseT0 := MaintenantUnix() - 100
    Verifier(!MajRotation() || PhraseCour.fr = avant, "moins de 5 min : même phrase")
    PhraseT0 := MaintenantUnix() - PHRASE_S
    MajRotation()
    Verifier(PhraseCour.fr != avant, "5 min : phrase suivante")
    try IniDelete(F_REGLAGES, "widget", "anglais_liste")
    try IniDelete(F_REGLAGES, "widget", "anglais_tatoeba")
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}
