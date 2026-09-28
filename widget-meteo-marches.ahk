; =============================================================================
;  Widget météo — actus et marchés : le Bitcoin (mini-courbe et flèche), un
;  indice boursier et le titre à la une sur le widget, et la fenêtre « Actus et
;  marchés » (tableau de bord : courbe détaillée, cryptos, indices, actions,
;  taux, titres du Monde, de franceinfo et de France 24). Inclus par widget-meteo.ahk.
;
;  Données : widget-meteo-marches.ps1, lancé toutes les 5 min quand une de ces
;  options sert (2 min tableau de bord ouvert, 15 min en mode sobre sur
;  batterie) ; courbes longues demandées à la volée par le tableau de bord.
;  (Constantes et état : MARCHES_*, ACTUS_FLUX, Marches*, Actus*, Histo*,
;  UneRang…, déclarés dans widget-meteo.ahk.)
; =============================================================================

; ---------- Catalogues et nombres ----------

; « a,b,c » ramené aux identifiants du catalogue (ordre du catalogue, sans doublon)
ListeCatalogue(csv, catalogue) {
    pris := Map(), res := ""
    for x in StrSplit(csv, ",", " ")
        pris[x] := 1
    for v in catalogue
        if pris.Has(v[1])
            res .= (res = "" ? "" : ",") v[1]
    return res
}

DansListe(csv, id) {
    for x in StrSplit(csv, ",")
        if (x == id)
            return true
    return false
}

; Nom d'un identifiant des catalogues (sinon l'identifiant)
NomMarche(id) {
    for cat in [MARCHES_CRYPTOS, MARCHES_INDICES, MARCHES_ACTIONS, MARCHES_TAUX]
        for v in cat
            if (v[1] == id)
                return v[2]
    return id
}

EstTauxYahoo(sym) => SubStr(sym, 1, 1) = "^" && DansListe("^TNX,^TYX,^FVX", sym)

NombresCsv(s) {
    r := []
    for x in StrSplit(s, ",")
        if IsNumber(x)
            r.Push(Number(x))
    return r
}

; « 74 306 », « 1,34 », « 8 077,80 » : « dec » décimales, milliers séparés d'une espace fine
FormatNombre(v, dec := 0) {
    s := Format("{:." dec "f}", Abs(v))
    p := InStr(s, ".")
    ent := p ? SubStr(s, 1, p - 1) : s
    return ((v < 0 && Round(v, dec) != 0) ? "−" : "") Milliers(ent) (p ? "," SubStr(s, p + 1) : "")
}

; Décimales selon l'ordre de grandeur : 74 306 €, 108,61 €, 1,34 €, 0,2241 €
DecimalesPrix(v) => (Abs(v) >= 1000) ? 0 : (Abs(v) >= 1) ? 2 : 4

; « +0,79 % », « −1,30 % » ; en points pour un taux (« +0,02 pt »)
FormatVar(v, taux := false) {
    if !IsNumber(v)
        return ""
    s := Format("{:.2f}", Abs(v))
    return ((Round(v, 2) > 0) ? "+" : (Round(v, 2) < 0) ? "−" : "") StrReplace(s, ".", ",") (taux ? Chr(0xA0) "pt" : Chr(0xA0) "%")
}

; ---------- Lecture des fichiers de la collecte ----------

LireMarches() {
    global Marches, MarchesDate, MarchesErreurs, MarchesMaj
    try m := FileGetTime(F_MARCHES, "M")
    catch
        return false
    if (m = MarchesDate)
        return false
    try txt := FileRead(F_MARCHES, "UTF-8")
    catch
        return false
    d := Map(), err := "", maj := 0
    for ligne in StrSplit(txt, "`n", "`r") {
        if (SubStr(ligne, 1, 4) = "maj=")
            maj := IsInteger(SubStr(ligne, 5)) ? Integer(SubStr(ligne, 5)) : 0
        else if (SubStr(ligne, 1, 8) = "erreurs=")
            err := SubStr(ligne, 9)
        c := StrSplit(ligne, "|")
        if (c.Length < 3)
            continue
        switch c[1], true {
            case "C":
                if (c.Length >= 9 && IsNumber(c[5]))
                    d["C|" c[2]] := {id: c[2], nom: c[3], sym: c[4], prix: Number(c[5]), v24: IsNumber(c[6]) ? Number(c[6]) : "",
                        v7: IsNumber(c[7]) ? Number(c[7]) : "", recolte: Integer("0" c[8]), courbe: NombresCsv(c[9])}
            case "S":
                if (c.Length >= 6)
                    d["S|" c[2]] := {recolte: Integer("0" c[4]), t: NombresCsv(c[5]), v: NombresCsv(c[6])}
            case "Y":
                if (c.Length >= 8 && IsNumber(c[3]))
                    d["Y|" c[2]] := {sym: c[2], prix: Number(c[3]), prec: IsNumber(c[4]) ? Number(c[4]) : "", tder: Integer("0" c[5]),
                        recolte: Integer("0" c[6]), t: NombresCsv(c[7]), v: NombresCsv(c[8])}
            case "T":
                if (c.Length >= 7 && IsNumber(c[3]))
                    d["T|" c[2]] := {code: c[2], val: Number(c[3]), prec: IsNumber(c[4]) ? Number(c[4]) : "", date: c[5], freq: c[6],
                        recolte: Integer("0" c[7])}
        }
    }
    Marches := d, MarchesDate := m, MarchesErreurs := err, MarchesMaj := maj
    return true
}

LireActus() {
    global ActusListe, ActusDate, ActusMaj
    try m := FileGetTime(F_ACTUS, "M")
    catch
        return false
    if (m = ActusDate)
        return false
    try txt := FileRead(F_ACTUS, "UTF-8")
    catch
        return false
    l := Map(), maj := 0
    for ligne in StrSplit(txt, "`n", "`r") {
        if (SubStr(ligne, 1, 4) = "maj=")
            maj := Integer("0" SubStr(ligne, 5))
        c := StrSplit(ligne, "|", , 7)
        if (c.Length >= 5 && c[1] = "A" && c[4] != "") {
            if !l.Has(c[2])
                l[c[2]] := []
            l[c[2]].Push({flux: c[2], t: Integer("0" c[3]), titre: c[4], lien: c[5],
                resume: (c.Length >= 6) ? c[6] : "", image: (c.Length >= 7) ? c[7] : ""})
        }
    }
    ActusListe := l, ActusDate := m, ActusMaj := maj
    return true
}

; historique.txt : une courbe demandée par le tableau de bord → HistoCache
LireHistorique() {
    static date := ""
    try m := FileGetTime(F_HISTO, "M")
    catch
        return false
    if (m = date)
        return false
    date := m
    d := Map()
    try
        for ligne in StrSplit(FileRead(F_HISTO, "UTF-8"), "`n", "`r")
            if (p := InStr(ligne, "="))
                d[SubStr(ligne, 1, p - 1)] := SubStr(ligne, p + 1)
    catch
        return false
    if !d.Has("cle")
        return false
    HistoCache[d["cle"]] := d.Has("erreur") ? {maj: MaintenantUnix(), erreur: true, t: [], v: []}
        : {maj: MaintenantUnix(), erreur: false, t: NombresCsv(d.Get("t", "")), v: NombresCsv(d.Get("v", ""))}
    return true
}

; ---------- Collecte ----------

; Les options qui ont besoin de la collecte des marchés (ou le tableau de bord ouvert)
MarchesUtiles() => MarchesBtcW || MarchesIndiceW || ActusW || (AnglaisW && AnglaisSource != "liste") || MarchesHwnd

MarchesDue() {
    if (!MarchesUtiles() || (MarchesPID && ProcessExist(MarchesPID)))
        return false
    periode := MarchesHwnd ? 120 : (Sobre && SobreMeteo && SurBatterieEco()) ? 900 : MARCHES_S
    return MaintenantUnix() - DernierMarches >= periode
}

; Le Bitcoin toujours en tête (la courbe 24 h du widget est celle du premier)
CryptosDemandees() {
    res := "bitcoin"
    for x in StrSplit(MarchesCryptos, ",")
        if (x != "" && x != "bitcoin")
            res .= "," x
    return res
}

SymbolesDemandes() {
    s := Map(), res := ""
    for liste in [MarchesIndiceW ? MarchesIndice : "", MarchesIndices, MarchesActions, MarchesTaux]
        for x in StrSplit(liste, ",")
            if (x != "" && !s.Has(x) && (SubStr(x, 1, 1) = "^" || InStr(x, ".") || RegExMatch(x, "^[A-Z-]+$")))
                s[x] := 1, res .= (res = "" ? "" : ",") x
    return res
}

TauxDemandes() {
    res := ""
    for x in StrSplit(MarchesTaux, ",")
        if (x != "" && SubStr(x, 1, 1) != "^")
            res .= (res = "" ? "" : ",") x
    return res
}

; Lance la collecte (ou, « histo » donné, la courbe demandée par le tableau de bord).
; Une seule à la fois : une courbe demandée pendant une collecte attend sa fin.
LancerMarches(histo := "") {
    global MarchesPID, MarchesT0, DernierMarches, MarchesHisto, HistoAttente
    if !FileExist(SCRIPT_MARCHES)
        return
    if (MarchesPID && ProcessExist(MarchesPID)) {
        if (histo != "")
            HistoAttente := histo
        return
    }
    if (histo != "")
        arg := " -Historique " ArgPS(histo)
    else
        arg := " -Cryptos " ArgPS(CryptosDemandees()) " -Symboles " ArgPS(SymbolesDemandes()) " -Taux " ArgPS(TauxDemandes() "")
            . ((ActusW || MarchesHwnd) ? " -Actus" : "") ((AnglaisW && AnglaisSource != "liste") ? " -Tatoeba" : "")
    try Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' SCRIPT_MARCHES '"' arg, , "Hide", &pid)
    catch
        return
    MarchesPID := pid, MarchesT0 := A_TickCount, MarchesHisto := histo
    if (histo = "")
        DernierMarches := MaintenantUnix()        ; (même en échec : pas de relance à chaque minute)
    SetTimer(SuivreMarches, 700)
}

SuivreMarches() {
    global MarchesPID, HistoAttente
    if (MarchesPID && ProcessExist(MarchesPID)) {
        if (A_TickCount - MarchesT0 > 120000) {   ; bloquée (réseau) : abandonnée
            try ProcessClose(MarchesPID)
            Journal("collecte des marchés abandonnée (2 min)")
        } else
            return
    }
    SetTimer(SuivreMarches, 0)
    MarchesPID := 0
    a := LireMarches(), b := LireActus(), c := LireTatoeba(), h := LireHistorique()
    if a
        VerifierAlertes()                         ; (nouveaux cours : alertes éventuelles)
    if (a || b || c) {
        if !IsObject(PhraseCour)
            MajRotation(true)
        Redessiner(true)                          ; (une ligne peut apparaître : la hauteur change)
    }
    if (MarchesHwnd && (a || b || h))
        PeindreMarches()
    if (HistoAttente != "") {
        k := HistoAttente, HistoAttente := ""
        LancerMarches(k)
    }
}

; ---------- Sur le widget ----------

CouleurHausse(t) => t.sombre ? 0xFF16803C : 0xFF34D264
CouleurBaisse(t) => t.sombre ? 0xFFC4271D : 0xFFFF5A4F

; Les éléments de la ligne des marchés : [{nom, prix (texte), var (%), courbe {t, v}}], vide s'il n'y a rien
ElementsMarches() {
    el := []
    if (MarchesBtcW && Marches.Has("C|bitcoin")) {
        c := Marches["C|bitcoin"]
        v := Marches.Has("S|bitcoin") ? Marches["S|bitcoin"].v : c.courbe.Length > 24 ? DernierN(c.courbe, 25) : c.courbe
        el.Push({nom: "Bitcoin", prix: FormatNombre(c.prix, DecimalesPrix(c.prix)) Chr(0xA0) "€", var: c.v24, courbe: v})
    }
    if (MarchesIndiceW && Marches.Has("Y|" MarchesIndice)) {
        y := Marches["Y|" MarchesIndice]
        ferme := MaintenantUnix() - y.tder > 1800     ; (plus de cours depuis 30 min : séance finie)
        el.Push({nom: NomMarche(MarchesIndice), prix: FormatNombre(y.prix, (y.prix >= 1000) ? 0 : 2),
            var: IsNumber(y.prec) && y.prec ? (y.prix - y.prec) / y.prec * 100 : "", courbe: y.v,
            ferme: ferme, jour: ferme ? FormatTime(LocalDeUnix(y.tder), "ddd") : ""})
    }
    return el
}

; La série ramenée à n points (moyenne de chaque tranche ; le premier et le dernier
; restent exacts : la courbe part du bon niveau et finit sur le cours du moment)
Simplifier(v, n) {
    if (v.Length <= n)
        return v
    r := [v[1]]
    Loop n - 2 {
        a := Floor(A_Index * v.Length / (n - 1)) + 1, b := Min(v.Length - 1, Floor((A_Index + 1) * v.Length / (n - 1)))
        s := 0, c := 0
        Loop Max(1, b - a + 1)
            s += v[Min(v.Length, a + A_Index - 1)], c += 1
        r.Push(s / c)
    }
    r.Push(v[v.Length])
    return r
}

DernierN(a, n) {
    r := []
    Loop Min(n, a.Length)
        r.Push(a[a.Length - Min(n, a.Length) + A_Index])
    return r
}

; « +0,79 % », et le jour de la dernière clôture quand la bourse est fermée (« −0,04 % · ven. »)
TexteVar(e) => FormatVar(e.var) ((e.HasOwnProp("ferme") && e.ferme && e.jour != "") ? " · " e.jour : "")

; Le titre à la une affiché (tourne toutes les 5 min parmi les 5 premiers de franceinfo
; et du Monde, en alternance : ListeUneWidget), ou ""
UneCourante() {
    if !ActusW
        return ""
    l := ListeUneWidget()
    return l.Length ? l[Mod(UneRang - 1, l.Length) + 1] : ""
}

; Courbe (px) : valeurs « v » dans le rectangle (x, y, w, h), trait « ep ». « fleche » :
; la courbe laisse le dernier cinquième à un court trait qui part de son bout dans le
; sens de la variation « sens » (1 hausse, -1 baisse, 0 à plat) et porte la pointe
; (collée à la fin de la courbe, la pointe se lisait à l'envers après une petite baisse)
Courbe(L, v, x, y, w, h, couleur, ep, fleche := false, sens := 0, ombre := 0x000000) {
    if (v.Length < 2)
        return
    mn := v[1], mx := v[1]
    for val in v
        mn := Min(mn, val), mx := Max(mx, val)
    e := (mx - mn) ? mx - mn : 1
    fl := fleche ? 0.2 * w : 0, wc := w - fl
    pts := []
    for i, val in v
        pts.Push([x + (i - 1) * wc / (v.Length - 1), y + h - (val - mn) / e * h])
    if fleche {                                   ; le trait de la flèche, à ±35°
        ang := (sens > 0) ? 0.61 : (sens < 0) ? -0.61 : 0
        b := pts[pts.Length], ux := Cos(ang), uy := -Sin(ang), lf := fl * 0.8 / ux
        pts.Push(c := [b[1] + ux * lf, b[2] + uy * lf])
    }
    buf := Buffer(8 * pts.Length)
    for q in pts
        NumPut("Float", q[1], "Float", q[2], buf, (A_Index - 1) * 8)
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &pa := 0)
    DllCall("gdiplus\GdipAddPathLine2", "Ptr", pa, "Ptr", buf, "Int", pts.Length)
    Elargir(pa, ep)
    L.Push({p: pa, f: couleur, o: ombre, z: false})
    if !fleche
        return
    s := 3.2 * ep                                 ; la pointe, au bout du trait
    ReglPolygone(L, [[c[1] + ux * s * 0.6, c[2] + uy * s * 0.6], [c[1] - ux * s + uy * s * 0.75, c[2] - uy * s - ux * s * 0.75],
        [c[1] - ux * s - uy * s * 0.75, c[2] - uy * s + ux * s * 0.75]], couleur)
    L[L.Length].o := ombre, L[L.Length].z := false
}

; Ligne des marchés dans la bande (haut en yHaut) : pour chacun, le nom, la courbe
; avec sa flèche (vert en hausse, rouge en baisse), le prix et la variation
LigneMarches(L, t, u, x, yHaut, largeur, align) {
    el := ElementsMarches()
    if !el.Length
        return
    capP := 0.048 * u, capN := 0.04 * u, emP := EmPourCapitale(P_DATE, capP), emN := EmPourCapitale(P_TEXTE, capN)
    cw := 0.2 * u, ch := 0.05 * u, ec := 0.035 * u, sep := 0.09 * u
    ; largeurs ; si ça ne tient pas : sans la courbe de l'indice, puis sans courbes, et
    ; seulement en dernier sans le nom de l'indice (on doit savoir lequel c'est)
    Mes(avecNom, nbCourbes) {                     ; (noms à part : les variables sont partagées avec la fonction)
        somme := 0
        for j, m in el {
            m.wNom := (avecNom || j = 1) ? LargeurTexte(m.nom, P_TEXTE, emN) + ec : 0
            m.wC := (j <= nbCourbes) ? cw + 1.6 * ec : 0
            m.wP := LargeurTexte(m.prix, P_DATE, emP) + ec
            m.wV := IsNumber(m.var) ? LargeurTexte(TexteVar(m), P_DATE, emN) : 0
            somme += m.wNom + m.wC + m.wP + m.wV + ((j > 1) ? sep : 0)
        }
        return somme
    }
    tot := Mes(true, 2)
    if (tot > largeur)
        tot := Mes(true, 1)
    if (tot > largeur)
        tot := Mes(true, 0)
    if (tot > largeur)
        tot := Mes(false, 0)
    xx := align ? x + Max(0, (largeur - tot) / 2) : x
    yb := yHaut + 0.085 * u, mid := yb - capP / 2
    z := {x: xx, y: yHaut + 0.01 * u, w: Min(tot, largeur), h: 0.1 * u}
    for i, e in el {
        if (i > 1)
            xx += sep
        sens := !IsNumber(e.var) ? 0 : (e.var > 0) ? 1 : (e.var < 0) ? -1 : 0
        coul := (sens = 0 || (e.HasOwnProp("ferme") && e.ferme)) ? t.second : (sens > 0) ? CouleurHausse(t) : CouleurBaisse(t)   ; (fermée : grisée)
        if e.wNom {
            Poser(L, e.nom, P_TEXTE, emN, xx, yb, 0, t.second)
            xx += e.wNom
        }
        if e.wC {
            Courbe(L, Simplifier(e.courbe, 14), xx, mid - ch / 2, cw, ch, coul, 0.009 * u, true, sens, OmbreTheme())
            xx += e.wC
        }
        Poser(L, e.prix, P_DATE, emP, xx, yb, 0, (e.HasOwnProp("ferme") && e.ferme) ? t.second : t.texte)
        xx += e.wP
        if e.wV
            Poser(L, TexteVar(e), P_DATE, emN, xx, yb, 0, coul), xx += e.wV
    }
    NoterZone("marches", z)
}

; Le titre à la une : « À LA UNE » puis le titre (tronqué ; en entier dans le tableau de bord)
LigneUne(L, t, u, x, yHaut, largeur, align) {
    a := UneCourante()
    if !IsObject(a)
        return
    global UneAffichee := a                       ; (un clic dessus ouvre sa fiche)
    capT := 0.029 * u, cap := 0.042 * u, emT := EmPourCapitale(P_DATE, capT), em := EmPourCapitale(P_TEXTE, cap)
    tag := StrUpper(ACTUS_FLUX.Get(a.flux, "À la une")), wt := LargeurTexte(tag, P_DATE, emT) + 0.03 * u
    titre := Tronquer(a.titre, P_TEXTE, em, largeur - wt)
    tot := wt + LargeurTexte(titre, P_TEXTE, em)
    xx := align ? x + Max(0, (largeur - tot) / 2) : x
    yb := yHaut + 0.082 * u
    Poser(L, tag, P_DATE, emT, xx, yb, 0, t.second)
    b := Poser(L, titre, P_TEXTE, em, xx + wt, yb, 0, t.texte)
    NoterZone("une", {x: xx, y: yHaut + 0.01 * u, w: tot, h: 0.1 * u})
}

; ---------- Alertes (notifications Windows) ----------

; Après chaque collecte : le Bitcoin qui bouge de plus d'AlerteBtc % en 24 h, les
; seuils de prix franchis (depuis le cours d'avant, gardé dans reglages.ini même
; widget arrêté), les indices et actions suivis qui bougent de plus
; d'AlerteActions % pendant la séance. Chaque alerte une fois par jour et par sens ;
; un seuil, à chaque franchissement. Renvoie les messages ; « essai » : sans notification.
VerifierAlertes(essai := false) {
    global DerniereAlerteT
    msgs := []
    if !Marches.Has("C|bitcoin")
        return msgs
    c := Marches["C|bitcoin"], j := FormatTime(MomentAffiche(), "yyyyMMdd")
    v := StrSplit(IniRead(F_REGLAGES, "widget", "alertes_vues", ""), "|")
    deja := (v.Length = 2 && v[1] = j) ? v[2] : "", vues := deja
    Vue(cle) => InStr("," vues ",", "," cle ",")
    if (AlerteBtc && IsNumber(c.v24) && Abs(c.v24) >= AlerteBtc && !Vue(cle := "btc" ((c.v24 > 0) ? "+" : "-")))
        msgs.Push("Bitcoin " FormatVar(c.v24) " en 24 h : " FormatNombre(c.prix) Chr(0xA0) "€"), vues .= "," cle
    prec := IniRead(F_REGLAGES, "widget", "alerte_prix", "")
    if IsNumber(prec)
        for s in StrSplit(AlerteSeuils, ",")
            if IsNumber(s) {
                s := Number(s)
                if (prec < s && c.prix >= s)
                    msgs.Push("Le Bitcoin passe au-dessus de " FormatNombre(s) Chr(0xA0) "€ (" FormatNombre(c.prix) Chr(0xA0) "€)")
                else if (prec > s && c.prix <= s)
                    msgs.Push("Le Bitcoin passe sous " FormatNombre(s) Chr(0xA0) "€ (" FormatNombre(c.prix) Chr(0xA0) "€)")
            }
    try IniWrite(c.prix, F_REGLAGES, "widget", "alerte_prix")
    if AlerteActions
        for sym in StrSplit(SymbolesDemandes(), ",") {
            if (sym = "" || EstTauxYahoo(sym) || !Marches.Has("Y|" sym))
                continue
            y := Marches["Y|" sym]
            if (MaintenantUnix() - y.tder > 1800 || !IsNumber(y.prec) || !y.prec)   ; (séance finie : rien de neuf)
                continue
            var := (y.prix - y.prec) / y.prec * 100
            if (Abs(var) >= AlerteActions && !Vue(cle := sym ((var > 0) ? "+" : "-")))
                msgs.Push(NomMarche(sym) " " FormatVar(var) " aujourd'hui : " FormatNombre(y.prix, (y.prix >= 1000) ? 0 : 2)), vues .= "," cle
        }
    if (vues != deja)
        try IniWrite(j "|" LTrim(vues, ","), F_REGLAGES, "widget", "alertes_vues")
    if (msgs.Length && !essai) {
        txt := ""
        for m in msgs
            txt .= (txt = "" ? "" : "`n") m
        TrayTip(SubStr(txt, 1, 250), "Marchés", "Iconi")
        DerniereAlerteT := A_TickCount
        Journal("alerte marchés : " StrReplace(txt, "`n", " / "))
    }
    return msgs
}

; Clic sur la notification d'une alerte (NIN_BALLOONUSERCLICK sur l'icône du widget) : le tableau de bord
SurIconeNotif(wParam, lParam, msg, hwnd) {
    if ((lParam & 0xFFFF) = 0x405 && DerniereAlerteT && A_TickCount - DerniereAlerteT < 600000)
        SetTimer(OuvrirMarches, -1)
}

ChoisirAlerteBtc(v, *) {
    global AlerteBtc := v
    SauverReglages()
    CocherMenus()
}

ChoisirAlerteActions(v, *) {
    global AlerteActions := v
    SauverReglages()
    CocherMenus()
}

; Les seuils de prix du Bitcoin : « 70000, 80000 » (espaces, « € » et « 75 000 » acceptés)
ChoisirSeuilsBtc(*) {
    global AlerteSeuils
    r := InputBox("Prix du Bitcoin, en euros, qui déclenchent une alerte quand il les franchit`n(dans un sens ou dans l'autre). Plusieurs possibles, séparés par des virgules.`nExemple : 70000, 80000. Vide : aucun.", "Alertes Bitcoin", "w480 h190", StrReplace(AlerteSeuils, ",", ", "))
    if (r.Result != "OK")
        return
    l := ""
    for x in StrSplit(r.Value, [",", Chr(59)]) {
        x := RegExReplace(x, "[\s\x{A0}\x{202F}€]")
        if (IsNumber(x) && Number(x) > 0)
            l .= (l = "" ? "" : ",") Round(Number(x))
    }
    AlerteSeuils := l
    SauverReglages()
    CocherMenus()
}

; « 70 000 €, 80 000 € » ou « aucun »
TexteSeuils() {
    t := ""
    for s in StrSplit(AlerteSeuils, ",")
        if IsNumber(s)
            t .= (t = "" ? "" : ", ") FormatNombre(Number(s)) Chr(0xA0) "€"
    return (t = "") ? "aucun" : t
}

; ---------- Réglages (fenêtre Réglages ▸ Marchés, Actus) ----------

ApresReglageMarches(relancer := true) {
    SauverReglages()
    CocherMenus()
    Redessiner(true)                              ; (des lignes apparaissent ou disparaissent : la hauteur change)
    if (relancer && MarchesUtiles())
        LancerMarches()                           ; les nouvelles données tout de suite
    if MarchesHwnd
        PeindreMarches(true)
}

BasculerMarchesBtc(*) {
    global MarchesBtcW := !MarchesBtcW
    ApresReglageMarches()
}

BasculerMarchesIndiceW(*) {
    global MarchesIndiceW := !MarchesIndiceW
    ApresReglageMarches()
}

ChoisirMarchesIndice(v, *) {
    global MarchesIndice := v
    ApresReglageMarches()
}

BasculerPluieW(*) {
    global PluieW := !PluieW
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

BasculerVoileBande(*) {
    global VoileBande := !VoileBande
    SauverReglages()
    CocherMenus()
    Redessiner()
}

BasculerActusW(*) {
    global ActusW := !ActusW
    ApresReglageMarches()
}

; Ajoute ou retire « id » d'une liste du tableau de bord (MarchesCryptos, MarchesIndices…)
BasculerDansListe(nom, catalogue, id, *) {
    global MarchesCryptos, MarchesIndices, MarchesActions, MarchesTaux
    csv := %nom%
    csv := DansListe(csv, id) ? StrReplace("," csv ",", "," id ",", ",") : csv "," id
    %nom% := ListeCatalogue(Trim(csv, ","), catalogue)
    ApresReglageMarches()
}

; ---------- La fenêtre « Actus et marchés » ----------

OuvrirMarches(onglet := "", *) {
    global MarchesGui, MarchesHwnd, MarchesGeo
    QuitterEdition()
    if (MarchesHwnd && DllCall("IsWindow", "Ptr", MarchesHwnd)) {
        FermerMarches("nouvelle demande")
        return
    }
    FermerPrevisions("actus et marchés demandés")  ; une seule fenêtre surgissante à la fois
    FermerJours("actus et marchés demandés")
    FermerReglages("actus et marchés demandés")
    FermerFicheActu("actus et marchés demandés")
    kp := A_ScreenDPI / 96
    WinGetPos(&wx, &wy, &ww, &wh, HWIDGET)
    e := EcranProche(wx + ww // 2, wy + wh // 2)
    MarchesGeo := {kp: kp, defil: 0, survol: "", suivi: false, x: 0, y: 0, w: 0, h: 0, px: 0, py: 0, mp: "", curseur: "",
        hauteur: Max(REGL_H_MIN, Min(MARCHES_H, Floor((e.b - e.t) / kp) - 32))}
    MarchesGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x80000")
    MarchesGui.Show("NA x0 y0 w1 h1")
    MarchesHwnd := MarchesGui.Hwnd
    LireMarches(), LireActus(), LireHistorique()
    PeindreMarches(true, true)
    SurgieOuverteLe(MarchesHwnd, "actus et marchés ouverts")
    if (MaintenantUnix() - DernierMarches > 60)   ; données de plus d'une minute : rafraîchies tout de suite
        LancerMarches()
    CourbeDemandee()
}

FermerMarches(raison := "", *) {
    global MarchesGui, MarchesHwnd, MarchesGeo
    if !MarchesHwnd
        return
    if (IsObject(MarchesGeo) && MarchesGeo.w) {   ; déplacée à la souris : elle se rouvrira là
        MarchesPosReelle()
        if (MarchesGeo.x != MarchesGeo.px || MarchesGeo.y != MarchesGeo.py)
            try IniWrite(MarchesGeo.x "," MarchesGeo.y, F_REGLAGES, "widget", "marches_pos")
    }
    MarchesHwnd := 0, MarchesGeo := ""
    try MarchesGui.Destroy()
    MarchesGui := ""
    SurgieFermee()
    Journal("actus et marchés fermés" (IsObject(raison) || raison = "" ? "" : " (" raison ")"))
}

PeindreMarches(refaire := true, placer := false) {
    g := MarchesGeo
    if (!IsObject(g) || !MarchesHwnd)
        return
    if (refaire || !IsObject(g.mp))
        g.mp := MiseEnPageMarches(g.kp, g.hauteur)
    g.defil := Max(0, Min(g.defil, g.mp.defilMax))
    w := Round(g.mp.w * g.kp), h := Round(g.mp.h * g.kp)
    if (placer || w != g.w || h != g.h) {
        PlacerFenetrePos("marches_pos", w, h, &x, &y)
        g.x := x, g.y := y, g.w := w, g.h := h, g.px := x, g.py := y
    } else
        MarchesPosReelle()
    PeindreCalque(MarchesHwnd, g.x, g.y, g.w, g.h, (gr) => DessinerMarches(gr, g.w, g.h, g.kp, g.mp, g))
}

; Là où on l'a laissée (clé « cle » de reglages.ini), ramenée dans son écran ; sinon à côté du widget
PlacerFenetrePos(cle, w, h, &x, &y) {
    if RegExMatch(IniRead(F_REGLAGES, "widget", cle, ""), "^(-?\d+),(-?\d+)$", &o) {
        e := EcranProche(Integer(o[1]) + w // 2, Integer(o[2]) + h // 2)
        x := Max(e.l, Min(Integer(o[1]), e.r - w)), y := Max(e.t, Min(Integer(o[2]), e.b - h))
        return
    }
    PlacerSurgie(w, h, &x, &y)
}

MarchesPosReelle() {
    rc := Buffer(16, 0)
    if (MarchesHwnd && IsObject(MarchesGeo) && DllCall("GetWindowRect", "Ptr", MarchesHwnd, "Ptr", rc))
        MarchesGeo.x := NumGet(rc, 0, "Int"), MarchesGeo.y := NumGet(rc, 4, "Int")
}

; ---------- Les instruments et leurs courbes ----------

; Un instrument du tableau de bord (« c:bitcoin », « y:^FCHI », « t:fr10 ») :
; {cle, nom, val, unite, var, taux (variation en points), info, courte (courbe de la ligne), plages}
Instrument(cle) {
    typ := SubStr(cle, 1, 1), id := SubStr(cle, 3)
    i := {cle: cle, nom: NomMarche(id), val: "", unite: "", var: "", taux: false, info: "", courte: [], plages: []}
    if (typ = "c") {
        i.plages := [["1", "1 j"], ["7", "7 j"], ["30", "1 mois"], ["365", "1 an"]]
        if Marches.Has("C|" id) {
            c := Marches["C|" id]
            i.nom := c.nom, i.val := c.prix, i.unite := "€", i.var := c.v24
            i.courte := (id = "bitcoin" && Marches.Has("S|bitcoin")) ? Marches["S|bitcoin"].v : DernierN(c.courbe, 25)   ; (24 h, comme la variation)
            i.info := c.sym " · 24 h"
        }
    } else if (typ = "y") {
        i.taux := EstTauxYahoo(id)
        i.plages := [["1d", "1 j"], ["5d", "5 j"], ["1mo", "1 mois"], ["1y", "1 an"]]
        if Marches.Has("Y|" id) {
            y := Marches["Y|" id]
            i.val := y.prix, i.unite := i.taux ? "%" : "", i.courte := y.v
            i.var := !IsNumber(y.prec) ? "" : i.taux ? y.prix - y.prec : y.prec ? (y.prix - y.prec) / y.prec * 100 : ""
            i.info := (MaintenantUnix() - y.tder < 1800) ? "en direct" : "clôture " DateHeureCourte(y.tder)
        }
    } else {
        i.taux := true
        i.plages := (id = "zone10") ? [["0", "1 an"]] : [["0", "5 ans"]]
        if Marches.Has("T|" id) {
            tx := Marches["T|" id]
            i.val := tx.val, i.unite := "%", i.var := IsNumber(tx.prec) ? tx.val - tx.prec : ""
            i.info := (tx.freq = "m") ? "moyenne de " FormatTime(StrReplace(tx.date, "-") "01", "MMMM yyyy") " (BCE)"
                : "au " DateCourte(StrReplace(tx.date, "-")) " (BCE)"
        }
    }
    return i
}

; « ven. 17:35 » (un autre jour), « 17:35 » (aujourd'hui)
DateHeureCourte(unix) {
    l := LocalDeUnix(Integer(unix))
    return (SubStr(l, 1, 8) = FormatTime(, "yyyyMMdd")) ? FormatTime(l, "HH:mm") : FormatTime(l, "ddd HH:mm")
}

; La courbe à tracer : {t[], v[], charge (en attente), erreur} ; celles déjà
; dans marches.txt servent telles quelles (Bitcoin 24 h, 7 j des cryptos, séance)
CourbeInstrument(cle, plage) {
    typ := SubStr(cle, 1, 1), id := SubStr(cle, 3)
    if (typ = "c" && plage = "1" && Marches.Has("S|" id))
        return {t: Marches["S|" id].t, v: Marches["S|" id].v, charge: false, erreur: false}
    if (typ = "c" && plage = "7" && Marches.Has("C|" id) && Marches["C|" id].courbe.Length > 2) {
        c := Marches["C|" id], t := []
        Loop c.courbe.Length                      ; (courbe horaire, la dernière valeur à la récolte)
            t.Push(c.recolte - (c.courbe.Length - A_Index) * 3600)
        return {t: t, v: c.courbe, charge: false, erreur: false}
    }
    if (typ = "y" && plage = "1d" && Marches.Has("Y|" id))
        return {t: Marches["Y|" id].t, v: Marches["Y|" id].v, charge: false, erreur: false}
    k := typ ":" id ":" plage
    if HistoCache.Has(k) {
        h := HistoCache[k]
        return {t: h.t, v: h.v, charge: (MarchesHisto = k && MarchesPID) || HistoAttente = k, erreur: h.erreur}
    }
    return {t: [], v: [], charge: true, erreur: false}
}

; La courbe choisie n'est pas là (ou périmée) : demandée à la collecte
CourbeDemandee() {
    typ := SubStr(MarchesSel, 1, 1), id := SubStr(MarchesSel, 3)
    if ((typ = "c" && MarchesPlage = "1" && Marches.Has("S|" id)) || (typ = "c" && MarchesPlage = "7" && Marches.Has("C|" id))
        || (typ = "y" && MarchesPlage = "1d" && Marches.Has("Y|" id)))
        return
    k := typ ":" id ":" MarchesPlage
    dureeMax := (MarchesPlage = "1" || MarchesPlage = "5d") ? 600 : (MarchesPlage = "30" || MarchesPlage = "1mo") ? 3600 : 6 * 3600
    if (HistoCache.Has(k) && MaintenantUnix() - HistoCache[k].maj < dureeMax)
        return
    LancerMarches(k)
}

ChoisirCourbe(cle, plage := "") {
    global MarchesSel, MarchesPlage
    i := Instrument(cle)
    MarchesSel := cle
    ok := false
    for p in i.plages
        ok := ok || (p[1] = plage)
    eq := (MarchesPlage != "") ? PlageDe(i, MarchesPlage) : ""   ; (la même durée : 1 mois du Bitcoin → 1 mois du CAC 40)
    MarchesPlage := ok ? plage : (eq != "") ? eq : i.plages[1][1]
    CourbeDemandee()
    if MarchesHwnd
        PeindreMarches()
}

; La même durée d'un type à l'autre (7 j ↔ 5 j, 1 mois, 1 an), sinon ""
PlageDe(i, plage) {
    static eq := Map("1", "1d", "1d", "1", "7", "5d", "5d", "7", "30", "1mo", "1mo", "30", "365", "1y", "1y", "365")
    for p in i.plages
        if (p[1] = plage || (eq.Has(plage) && p[1] = eq[plage]))
            return p[1]
    return ""
}

; ---------- Mise en page du tableau de bord (px logiques) ----------

; {w, h, y0, cartes[], lignes[] (contenu qui défile), zones[], contenuH, defilMax}
MiseEnPageMarches(kp, hauteur) {
    global MarchesPlage
    mp := {w: MARCHES_W, h: hauteur, y0: 76, lignes: [], cartes: [], zones: []}
    xg := 20, wg := 500, xd := 540, wd := MARCHES_W - 540 - 26
    mp.zones.Push(mp.zfermer := {x: mp.w - 54, y: 18, w: 36, h: 36, type: "fermer", id: "fermer", fixe: true})
    mp.zones.Push(mp.zactu := {x: mp.w - 54 - 132, y: 21, w: 122, h: 30, type: "actualiser", id: "actualiser", fixe: true})
    Zone(x, y, w, h, type, id, extra := "") {
        z := {x: x, y: y, w: w, h: h, type: type, id: id, fixe: false}
        if IsObject(extra)
            for k, v in extra.OwnProps()
                z.%k% := v
        mp.zones.Push(z)
        return z
    }
    ; ---- colonne de gauche : la courbe choisie, puis les listes
    i := Instrument(MarchesSel)
    if (PlageDe(i, MarchesPlage) = "")
        MarchesPlage := i.plages[1][1]
    y := 0
    mp.graphe := {x: xg, y: y, w: wg, h: 300, i: i}
    mp.cartes.Push({x: xg, y: y, w: wg, h: 300})
    xx := xg + 14
    for p in i.plages {                           ; pastilles des périodes
        lw := LargeurMemo(p[2], P_TEXTE, EmPourCapitale(P_TEXTE, 9 * kp)) / kp + 22
        Zone(xx, y + 72, lw, 26, "plage", "plage:" p[1], {plage: p[1], lib: p[2]})
        xx += lw + 6
    }
    mp.zoneCourbe := {x: xg + 14, y: y + 112, w: wg - 28, h: 170}
    Zone(mp.zoneCourbe.x, mp.zoneCourbe.y, mp.zoneCourbe.w, mp.zoneCourbe.h, "courbe", "courbe")
    y += 300 + 10
    sections := [["Cryptos", "c", StrSplit(CryptosDemandees(), ",")], ["Indices", "y", StrSplit(MarchesIndices, ",")],
        ["Actions", "y", StrSplit(MarchesActions, ",")], ["Taux", "", StrSplit(MarchesTaux, ",")]]
    for sec in sections {
        ids := []
        for id in sec[3]
            if (id != "")
                ids.Push(id)
        if (!ids.Length && sec[1] != "Actions")
            continue
        mp.lignes.Push({t: "section", lib: sec[1], x: xg, y: y + 12, w: wg})
        y += 12 + 26
        carte := {x: xg, y: y, w: wg, h: 0}
        mp.cartes.Push(carte)
        if !ids.Length {                          ; rien de choisi : où le faire
            mp.lignes.Push({t: "vide", lib: "Choisis tes actions dans Réglages ▸ Marchés", x: xg, y: y, w: wg, h: 44, premier: true, id: "reglages"})
            Zone(xg, y, wg, 44, "reglages", "reglages")
            y += 44
        }
        for n, id in ids {
            typ := (sec[2] = "") ? ((SubStr(id, 1, 1) = "^") ? "y" : "t") : sec[2]
            cle := typ ":" id
            mp.lignes.Push({t: "instrument", cle: cle, x: xg, y: y, w: wg, h: 46, premier: n = 1, id: "i:" cle})
            Zone(xg, y, wg, 46, "instrument", "i:" cle, {cle: cle})
            y += 46
        }
        carte.h := y - carte.y
    }
    hg := y
    ; ---- colonne de droite : les prochains départs (s'ils servent), puis les titres
    y := 0
    em := EmPourCapitale(P_TEXTE, 10 * kp)
    if (RerW && RerCle() && RerArret != "") {
        mp.lignes.Push({t: "section", lib: RerNom " · " RerGare, x: xd, y: y, w: wd})
        y += 26
        carte := {x: xd, y: y, w: wd, h: 0}
        mp.cartes.Push(carte)
        deps := RerFrais() ? DepartsRer("", 6) : []
        if !deps.Length {
            mp.lignes.Push({t: "vide", lib: RerFrais() ? "Pas de départ annoncé" : EtatRer(), x: xd, y: y, w: wd, h: 40, premier: true})
            y += 40
        }
        for n, d in deps {
            mp.lignes.Push({t: "rer", d: d, x: xd, y: y, w: wd, h: 40, premier: n = 1})
            y += 40
        }
        maint := MaintenantUnix()
        for msg in RerMessages
            if (RerEtatM = "ok" && (!msg.fin || msg.fin > maint)) {
                lignes := ReglCouper(msg.texte, P_TEXTE, 9, kp, wd - 28, 4)
                h := 12 + 15 * lignes.Length + 10
                mp.lignes.Push({t: "rerinfo", canal: msg.canal, lignesT: lignes, x: xd, y: y, w: wd, h: h, premier: false})
                y += h
            }
        carte.h := y - carte.y
        y += 12
    }
    for sec in [["À la une", ["une"], 7, false], ["En continu", ["fil"], 7, true], ["International", ["monde", "f24"], 8, true]] {
        items := [], vus := Map()
        for f in sec[2]
            if ActusListe.Has(f)
                for a in ActusListe[f]                ; (même titre à une espace insécable près : une seule fois)
                    if !vus.Has(cle := RegExReplace(StrLower(a.titre), "[\s\x{A0}\x{202F}]+", " "))
                        vus[cle] := 1, items.Push(a)
        if sec[4]                                 ; (fil et international : les plus récents d'abord)
            TrierActus(items)
        if (items.Length > sec[3])
            items.Length := sec[3]
        mp.lignes.Push({t: "section", lib: sec[1], x: xd, y: y + ((y > 0) ? 12 : 0), w: wd})
        y += ((y > 0) ? 12 : 0) + 26
        carte := {x: xd, y: y, w: wd, h: 0}
        mp.cartes.Push(carte)
        if !items.Length {
            mp.lignes.Push({t: "vide", lib: ActusDate = "" ? "Chargement des titres…" : "Aucun titre (réseau ?)", x: xd, y: y, w: wd, h: 40, premier: true})
            y += 40
        }
        for n, a in items {
            lignes := ReglCouper(a.titre, P_TEXTE, 10, kp, wd - 28, 3)
            h := 30 + 17 * lignes.Length + 6
            mp.lignes.Push({t: "actu", a: a, lignesT: lignes, x: xd, y: y, w: wd, h: h, premier: n = 1, id: "a:" sec[1] n})
            Zone(xd, y, wd, h, "actu", "a:" sec[1] n, {lien: a.lien, a: a, liste: items})
            y += h
        }
        carte.h := y - carte.y
    }
    mp.lignes.Push({t: "sources", x: xd, y: y + 10, w: wd, h: 40})
    y += 50
    mp.contenuH := Max(hg, y) + 16
    mp.defilMax := Max(0, mp.contenuH - (hauteur - mp.y0 - 10))
    return mp
}

TrierActus(items) {
    Loop items.Length - 1 {                       ; insertion : les plus récents d'abord
        i := A_Index + 1, e := items[i], k := i - 1
        while (k >= 1 && items[k].t < e.t)
            items[k + 1] := items[k], k--
        items[k + 1] := e
    }
}

; « à l'instant », « il y a 12 min », « il y a 3 h », « hier », « le 25/09 »
AgeActu(unix) {
    if !unix
        return ""
    d := MaintenantUnix() - unix
    return (d < 120) ? "à l'instant" : (d < 3600) ? "il y a " d // 60 " min" : (d < 86400) ? "il y a " d // 3600 " h"
        : (d < 172800) ? "hier" : "le " FormatTime(LocalDeUnix(unix), "dd/MM")
}

; ---------- Dessin du tableau de bord ----------

DessinerMarches(gr, w, h, kp, mp, g) {
    global TeinteRendu
    ancienne := TeinteRendu
    TeinteRendu := NuitTeinteActive()
    try DessinerMarchesScene(gr, w, h, kp, mp, g)
    finally TeinteRendu := ancienne
}

DessinerMarchesScene(gr, w, h, kp, mp, g) {
    static SURFACE := 0xF21A1A19, ENCRE := 0xFFFFFFFF, SECOND := 0xFFC3C2B7, DISCRET := 0xFF898781
    static GRILLE := 0xFF2C2C2A, CHOISI := 0xFF3A3A37, BLEU := 0xFF3987E5, CARTE := 0xFF242423
    static TRAIT := 0xFF363633, SURVOL := 0xFF2F2F2C, PUCE := 0xFF34342F, PUCE_SURVOL := 0xFF45453F
    static HAUSSE := 0xFF30D158, BAISSE := 0xFFFF453A
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gr, "Int", 2)
    RectArrondi(gr, 0, 0, w, h, 22 * kp, SURFACE)
    F := [], C := []
    Em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)

    ; ---- en-tête : titre, heure des données, Actualiser, fermer
    Poser(F, "Actus et marchés", P_DATE, Em(15, P_DATE), 22 * kp, 44 * kp, 0, ENCRE)
    sous := (MarchesMaj ? "Cours de " FormatTime(LocalDeUnix(MarchesMaj), "HH:mm") : "Cours en attente")
        . (ActusMaj ? " · titres de " FormatTime(LocalDeUnix(ActusMaj), "HH:mm") : "")
        . ((MarchesErreurs != "") ? " · une source n'a pas répondu" : "")
        . (MarchesPID && MarchesHisto = "" ? " · mise à jour…" : "")
    Poser(F, sous, P_TEXTE, Em(8.5), 22 * kp, 64 * kp, 0, DISCRET)
    za := mp.zactu
    F.Push({p: CheminArrondi(za.x * kp, za.y * kp, za.w * kp, za.h * kp, 15 * kp), f: (g.survol = "actualiser") ? PUCE_SURVOL : PUCE})
    Poser(F, "Actualiser", P_TEXTE, Em(9), (za.x + za.w / 2) * kp, (za.y + 19.5) * kp, 1, (g.survol = "actualiser") ? ENCRE : SECOND)
    zf := mp.zfermer, fx := (zf.x + zf.w / 2) * kp, fy := (zf.y + zf.h / 2) * kp
    ReglRond(F, fx, fy, 14 * kp, (g.survol = "fermer") ? CHOISI : GRILLE)
    ReglTraits(F, [[fx - 4.5 * kp, fy - 4.5 * kp, fx + 4.5 * kp, fy + 4.5 * kp], [fx - 4.5 * kp, fy + 4.5 * kp, fx + 4.5 * kp, fy - 4.5 * kp]], 1.8 * kp, SECOND)

    oy := mp.y0 - g.defil
    for ca in mp.cartes
        C.Push({p: CheminArrondi(ca.x * kp, (oy + ca.y) * kp, ca.w * kp, ca.h * kp, 12 * kp), f: CARTE})

    ; ---- la courbe choisie
    gp := mp.graphe, i := gp.i, x0 := gp.x, yg := oy + gp.y
    coul := CouleurVarTB(i.var)
    Poser(C, i.nom, P_DATE, Em(11, P_DATE), (x0 + 14) * kp, (yg + 28) * kp, 0, ENCRE)
    if (i.info != "")
        Poser(C, i.info, P_TEXTE, Em(8.5), (x0 + gp.w - 14) * kp, (yg + 28) * kp, 2, DISCRET)
    if IsNumber(i.val) {
        dec := i.taux ? 3 : (i.unite = "€") ? DecimalesPrix(i.val) : 2
        b := Poser(C, FormatNombre(i.val, dec) (i.unite != "" ? Chr(0xA0) i.unite : ""), P_DATE, Em(19, P_DATE), (x0 + 14) * kp, (yg + 60) * kp, 0, ENCRE)
        if IsNumber(i.var)
            Poser(C, FormatVar(i.var, i.taux), P_DATE, Em(11, P_DATE), b.x + b.w + 12 * kp, (yg + 60) * kp, 0, coul)
    } else
        Poser(C, "Pas encore de cours", P_TEXTE, Em(11), (x0 + 14) * kp, (yg + 60) * kp, 0, DISCRET)
    for z in mp.zones
        if (z.type = "plage") {
            pris := (z.plage = MarchesPlage)      ; (jamais « choisi » : même variable que CHOISI)
            C.Push({p: CheminArrondi(z.x * kp, (oy + z.y) * kp, z.w * kp, z.h * kp, 13 * kp),
                f: pris ? BLEU : (g.survol = z.id) ? PUCE_SURVOL : PUCE})
            Poser(C, z.lib, P_TEXTE, Em(9), (z.x + z.w / 2) * kp, (oy + z.y + 17.5) * kp, 1, (pris || g.survol = z.id) ? ENCRE : SECOND)
        }
    zc := mp.zoneCourbe, cb := CourbeInstrument(MarchesSel, MarchesPlage)
    if (cb.v.Length >= 2) {
        v1 := cb.v[1], vn := cb.v[cb.v.Length]
        cc := (vn > v1) ? HAUSSE : (vn < v1) ? BAISSE : SECOND
        mn := v1, mx := v1
        for val in cb.v
            mn := Min(mn, val), mx := Max(mx, val)
        cx := zc.x * kp, cyy := (oy + zc.y + 8) * kp, cwd := (zc.w - 70) * kp, chh := (zc.h - 30) * kp
        ; aire sous la courbe, puis la courbe
        e := (mx - mn) ? mx - mn : 1, pts := []
        for k, val in cb.v
            pts.Push([cx + (k - 1) * cwd / (cb.v.Length - 1), cyy + chh - (val - mn) / e * chh])
        aire := [[cx, cyy + chh]]
        for q in pts
            aire.Push(q)
        aire.Push([cx + cwd, cyy + chh])
        ReglPolygone(C, aire, (0x30 << 24) | (cc & 0xFFFFFF))
        Courbe(C, cb.v, cx, cyy, cwd, chh, cc, 2 * kp)
        ; repères : plus haut, plus bas (à droite), début et fin (dessous)
        dec := i.taux ? 2 : (mx >= 1000) ? 0 : 2
        Poser(C, FormatNombre(mx, dec), P_TEXTE, Em(8.5), cx + cwd + 8 * kp, cyy + 4 * kp, 0, DISCRET)
        Poser(C, FormatNombre(mn, dec), P_TEXTE, Em(8.5), cx + cwd + 8 * kp, cyy + chh + 4 * kp, 0, DISCRET)
        ReglRect(C, cx, cyy, cwd, Max(1, 0.6 * kp), TRAIT)
        ReglRect(C, cx, cyy + chh, cwd, Max(1, 0.6 * kp), TRAIT)
        if (cb.t.Length = cb.v.Length) {
            Poser(C, DateCourbe(cb.t[1], MarchesPlage), P_TEXTE, Em(8.5), cx, cyy + chh + 20 * kp, 0, DISCRET)
            Poser(C, DateCourbe(cb.t[cb.t.Length], MarchesPlage), P_TEXTE, Em(8.5), cx + cwd, cyy + chh + 20 * kp, 2, DISCRET)
        }
        ; survol : la valeur sous le curseur
        if (IsObject(g.curseur) && g.curseur.x >= cx && g.curseur.x <= cx + cwd && cb.t.Length = cb.v.Length) {
            k := Round((g.curseur.x - cx) / cwd * (cb.v.Length - 1)) + 1
            px := pts[k][1], py := pts[k][2]
            ReglRect(C, px - 0.5 * kp, cyy, Max(1, kp), chh, 0x66FFFFFF)
            ReglRond(C, px, py, 4 * kp, ENCRE)
            txt := FormatNombre(cb.v[k], i.taux ? 3 : DecimalesPrix(cb.v[k])) (i.unite != "" ? Chr(0xA0) i.unite : "") " · " DateCourbe(cb.t[k], MarchesPlage, true)
            lt := LargeurMemo(txt, P_TEXTE, Em(8.5))
            tx := Max(cx, Min(px - lt / 2, cx + cwd - lt))
            C.Push({p: CheminArrondi(tx - 6 * kp, cyy - 22 * kp, lt + 12 * kp, 20 * kp, 10 * kp), f: CHOISI})
            Poser(C, txt, P_TEXTE, Em(8.5), tx, cyy - 8 * kp, 0, ENCRE)
        }
    } else
        Poser(C, cb.erreur ? "Courbe indisponible (réseau ?)" : "Chargement de la courbe…", P_TEXTE, Em(9.5),
            (zc.x + zc.w / 2) * kp, (oy + zc.y + zc.h / 2) * kp, 1, DISCRET)
    if (cb.charge && cb.v.Length >= 2)
        Poser(C, "mise à jour…", P_TEXTE, Em(8), (zc.x + zc.w) * kp, (oy + zc.y + zc.h + 2) * kp, 2, DISCRET)

    ; ---- les lignes
    for li in mp.lignes {
        yl := oy + li.y
        if (yl + (li.HasOwnProp("h") ? li.h : 30) < mp.y0 - 8 || yl > mp.h)
            continue
        if (li.t = "section") {
            Poser(C, StrUpper(li.lib), P_DATE, Em(7.5, P_DATE), (li.x + 14) * kp, (yl + 20) * kp, 0, DISCRET)
            continue
        }
        if (li.t = "sources") {
            for k, t in ["Sources : CoinGecko, Yahoo Finance, BCE,", "Le Monde, franceinfo, France 24"]
                Poser(C, t, P_TEXTE, Em(8), (li.x + 14) * kp, (yl + 12 + 14 * k) * kp, 0, DISCRET)
            continue
        }
        if (li.HasOwnProp("premier") && !li.premier)
            ReglRect(C, (li.x + 14) * kp, yl * kp, (li.w - 28) * kp, Max(1, 0.6 * kp), TRAIT)
        sel := li.HasOwnProp("cle") && li.cle = MarchesSel
        if (sel || (li.HasOwnProp("id") && g.survol = li.id))
            C.Push({p: CheminArrondi((li.x + 4) * kp, (yl + 3) * kp, (li.w - 8) * kp, (li.h - 6) * kp, 9 * kp), f: sel ? CHOISI : SURVOL})
        switch li.t {
            case "vide":
                Poser(C, li.lib, P_TEXTE, Em(9), (li.x + 14) * kp, (yl + li.h / 2 + 4.5) * kp, 0, DISCRET)
            case "instrument":
                it := Instrument(li.cle), cv := CouleurVarTB(it.var)
                Poser(C, Tronquer(it.nom, P_TEXTE, Em(10.5), 170 * kp), P_TEXTE, Em(10.5), (li.x + 14) * kp, (yl + 22) * kp, 0, ENCRE)
                if (it.info != "")
                    Poser(C, Tronquer(it.info, P_TEXTE, Em(8), 170 * kp), P_TEXTE, Em(8), (li.x + 14) * kp, (yl + 37) * kp, 0, DISCRET)
                if (it.courte.Length >= 2)
                    Courbe(C, Simplifier(it.courte, 30), (li.x + 200) * kp, (yl + 13) * kp, 90 * kp, 20 * kp, cv, 1.6 * kp)
                if IsNumber(it.val) {
                    dec := it.taux ? 3 : (it.unite = "€") ? DecimalesPrix(it.val) : 2
                    Poser(C, FormatNombre(it.val, dec) (it.unite != "" ? Chr(0xA0) it.unite : ""), P_DATE, Em(10, P_DATE),
                        (li.x + 400) * kp, (yl + 22) * kp, 2, ENCRE)
                    if IsNumber(it.var)
                        Poser(C, FormatVar(it.var, it.taux), P_DATE, Em(9, P_DATE), (li.x + li.w - 14) * kp, (yl + 22) * kp, 2, cv)
                } else
                    Poser(C, "en attente", P_TEXTE, Em(9), (li.x + li.w - 14) * kp, (yl + 22) * kp, 2, DISCRET)
            case "rer":
                d := li.d, retard := RetardMin(d)
                Poser(C, FormatTime(LocalDeUnix(d.t), "HH:mm"), P_DATE, Em(11, P_DATE), (li.x + 14) * kp, (yl + 26) * kp, 0,
                    (d.statut = "cancelled") ? 0xFFFF453A : (retard >= 2) ? 0xFFFF9F0A : ENCRE)
                Poser(C, Tronquer(d.dest, P_TEXTE, Em(10), (li.w - 170) * kp), P_TEXTE, Em(10), (li.x + 76) * kp, (yl + 26) * kp, 0, SECOND)
                Poser(C, (d.statut = "cancelled") ? "supprimé" : (retard >= 1) ? "+" retard Chr(0xA0) "min" : "à l'heure",
                    P_TEXTE, Em(8.5), (li.x + li.w - 14) * kp, (yl + 26) * kp, 2,
                    (d.statut = "cancelled") ? 0xFFFF453A : (retard >= 2) ? 0xFFFF9F0A : DISCRET)
            case "rerinfo":
                for k, t in li.lignesT
                    Poser(C, t, P_TEXTE, Em(9), (li.x + 14) * kp, (yl + 12 + 15 * k) * kp, 0, (li.canal = "Perturbation") ? 0xFFFFB340 : SECOND)
            case "actu":
                a := li.a
                Poser(C, ACTUS_FLUX.Get(a.flux, a.flux) ((a.t) ? " · " AgeActu(a.t) : ""), P_TEXTE, Em(8), (li.x + 14) * kp, (yl + 20) * kp, 0, DISCRET)
                for k, t in li.lignesT
                    Poser(C, t, P_TEXTE, Em(10), (li.x + 14) * kp, (yl + 20 + 17 * k) * kp, 0, (g.survol = li.id) ? 0xFF8EC1FF : ENCRE)
        }
    }

    for e in F
        Remplir(gr, e)
    DllCall("gdiplus\GdipSetClipRect", "Ptr", gr, "Float", 0, "Float", (mp.y0 - 6) * kp, "Float", mp.w * kp, "Float", (mp.h - mp.y0 - 4) * kp, "Int", 0)
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

; Vert en hausse, rouge en baisse, gris sinon (tableau de bord, surface sombre)
CouleurVarTB(v) => !IsNumber(v) ? 0xFFC3C2B7 : (Round(v, 2) > 0) ? 0xFF30D158 : (Round(v, 2) < 0) ? 0xFFFF453A : 0xFFC3C2B7

; Repère de temps d'une courbe : « 14:00 » (1 j), « lun. 21 » (7 j), « 21 sept. » (1 mois), « sept. 2025 » (1 an et plus)
DateCourbe(unix, plage, detail := false) {
    l := LocalDeUnix(Integer(unix))
    switch plage {
        case "1", "1d": return FormatTime(l, "HH:mm")
        case "7", "5d": return FormatTime(l, detail ? "ddd d HH:mm" : "ddd d")
        case "30", "1mo": return FormatTime(l, detail ? "d MMM HH:mm" : "d MMM")
        default: return FormatTime(l, detail ? "d MMM yyyy" : "MMM yyyy")
    }
}

; ---------- Souris et clavier ----------

MarchesMessages() {
    OnMessage(0x201, MarchesAppui)
    OnMessage(0x203, MarchesAppui)
    OnMessage(0x200, MarchesDeplace)
    OnMessage(0x2A3, MarchesSortie)
    OnMessage(0x20, MarchesCurseur)
    OnMessage(0x20A, MarchesMolette)
    OnMessage(0x100, MarchesTouche)
    OnMessage(0x404, SurIconeNotif)               ; AHK_NOTIFYICON : clic sur une notification
}

MarchesSous(&lx := 0, &ly := 0) {
    g := MarchesGeo
    if !(IsObject(g) && IsObject(g.mp))
        return ""
    MarchesPosReelle()
    if IsObject(ReglCurseurTest)                  ; (tests)
        cx := ReglCurseurTest[1], cy := ReglCurseurTest[2]
    else
        Curseur(&cx, &cy)
    lx := (cx - g.x) / g.kp, ly := (cy - g.y) / g.kp, mp := g.mp
    for z in mp.zones {
        zy := z.y
        if !z.fixe {
            if (ly < mp.y0 - 6 || ly >= mp.h - 10)
                continue
            zy += mp.y0 - g.defil
        }
        if (lx >= z.x && lx < z.x + z.w && ly >= zy && ly < zy + z.h)
            return z
    }
    return ""
}

MarchesAppui(wParam, lParam, msg, hwnd) {
    global MarchesPlage, ReglCat
    if (!MarchesHwnd || hwnd != MarchesHwnd)
        return
    z := MarchesSous()
    if (!IsObject(z) || z.type = "courbe") {      ; ailleurs que sur un élément : la fenêtre suit la souris
        DllCall("PostMessage", "Ptr", MarchesHwnd, "UInt", 0xA1, "Ptr", 2, "Ptr", 0)
        return 0
    }
    switch z.type {
        case "fermer":     SetTimer(FermerMarches.Bind("croix"), -1)
        case "actualiser": LancerMarches(), PeindreMarches(false)
        case "plage":
            MarchesPlage := z.plage
            CourbeDemandee()
            PeindreMarches()
        case "instrument": ChoisirCourbe(z.cle)
        case "actu":       SetTimer(OuvrirFicheActu.Bind(z.a, z.liste, "marches"), -1)   ; (l'article seul, en grand)
        case "reglages":
            ReglCat := "marches"
            SetTimer(OuvrirReglages, -1)
    }
    return 0
}

MarchesDeplace(wParam, lParam, msg, hwnd) {
    if (!MarchesHwnd || hwnd != MarchesHwnd)
        return
    g := MarchesGeo
    if !g.suivi {
        tme := Buffer(24, 0)
        NumPut("UInt", 24, "UInt", 2, tme)
        NumPut("Ptr", MarchesHwnd, tme, 8)
        g.suivi := DllCall("TrackMouseEvent", "Ptr", tme)
    }
    z := MarchesSous(&lx, &ly)
    id := IsObject(z) ? z.id : ""
    cur := (id = "courbe") ? {x: lx * g.kp, y: ly * g.kp} : ""
    if (id != g.survol || IsObject(cur) || IsObject(g.curseur)) {
        g.survol := id, g.curseur := cur
        PeindreMarches(false)
    }
    return 0
}

MarchesSortie(wParam, lParam, msg, hwnd) {
    if (!MarchesHwnd || hwnd != MarchesHwnd)
        return
    MarchesGeo.suivi := false
    if (MarchesGeo.survol != "" || IsObject(MarchesGeo.curseur)) {
        MarchesGeo.survol := "", MarchesGeo.curseur := ""
        PeindreMarches(false)
    }
    return 0
}

MarchesCurseur(wParam, lParam, msg, hwnd) {
    if (!MarchesHwnd || hwnd != MarchesHwnd || (lParam & 0xFFFF) != 1)
        return
    z := MarchesSous()
    if (!IsObject(z) || z.type = "courbe")
        return
    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))
    return 1
}

MarchesMolette(wParam, lParam, msg, hwnd) {
    if (!MarchesHwnd || hwnd != MarchesHwnd)
        return
    d := (wParam >> 16) & 0xFFFF
    MarchesDefiler(-((d >= 0x8000) ? d - 0x10000 : d) / 2)
    return 0
}

MarchesDefiler(dy) {
    g := MarchesGeo
    if !(IsObject(g) && IsObject(g.mp))
        return
    avant := g.defil
    g.defil := Max(0, Min(g.mp.defilMax, g.defil + dy))
    if (g.defil != avant)
        SetTimer(MarchesApresDefil, -10)
}

MarchesApresDefil() {
    if !(IsObject(MarchesGeo) && MarchesHwnd)
        return
    z := MarchesSous()
    MarchesGeo.survol := IsObject(z) ? z.id : "", MarchesGeo.curseur := ""
    PeindreMarches(false)
}

MarchesTouche(wParam, lParam, msg, hwnd) {
    if (!MarchesHwnd || hwnd != MarchesHwnd)
        return
    page := MarchesGeo.mp.h - MarchesGeo.mp.y0 - 50
    switch wParam {
        case 0x1B: SetTimer(FermerMarches.Bind("Échap"), -1)
        case 0x21: MarchesDefiler(-page)
        case 0x22: MarchesDefiler(page)
        case 0x24: MarchesDefiler(-100000)
        case 0x23: MarchesDefiler(100000)
        case 0x74: LancerMarches(), PeindreMarches(false)   ; F5
        default: return
    }
    return 0
}

; ---------- Tests ----------

; Le tableau de bord sur un fond gris (données du dossier de test) : courbe « sel »
; (« c:bitcoin »…), période « plage » ; defil = « plein » : tout le contenu
ApercuMarches(fichier, sel := "", plage := "", defil := 0) {
    global MarchesSel, MarchesPlage
    if (sel != "")
        MarchesSel := sel
    if (plage != "")
        MarchesPlage := plage
    LireHistorique()
    kp := A_ScreenDPI / 96
    mp := MiseEnPageMarches(kp, MARCHES_H)
    if (defil = "plein")
        mp := MiseEnPageMarches(kp, Max(MARCHES_H, mp.y0 + 10 + mp.contenuH)), defil := 0
    g := {defil: Max(0, Min(Integer(defil), mp.defilMax)), survol: "", curseur: ""}
    w := Round(mp.w * kp), h := Round(mp.h * kp), m := Round(16 * kp)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w + 2 * m, "Int", h + 2 * m, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, w + 2 * m, h + 2 * m, 0xFF5A6570)
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", gr, "Float", m, "Float", m, "Int", 0)
    DessinerMarches(gr, w, h, kp, mp, g)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

; Auto-test : lecture des fichiers, nombres, listes, arguments de la collecte, mise en page
TestMarches(fichier) {
    global MarchesCryptos, MarchesIndices, MarchesActions, MarchesTaux, MarchesIndice, MarchesIndiceW, MarchesSel, MarchesPlage, UneRang
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    ; ---- nombres
    Verifier(FormatNombre(74306.2) = "74" Chr(0x202F) "306" && FormatNombre(1.3412, 2) = "1,34" && FormatNombre(-0.004, 2) = "0,00"
        && FormatNombre(8077.8, 2) = "8" Chr(0x202F) "077,80", "nombres : 74 306, 1,34, 0,00, 8 077,80")
    Verifier(FormatVar(0.787) = "+0,79" Chr(0xA0) "%" && FormatVar(-1.308) = "−1,31" Chr(0xA0) "%" && FormatVar(0.001) = "0,00" Chr(0xA0) "%"
        && FormatVar(0.022, true) = "+0,02" Chr(0xA0) "pt", "variations : +0,79 %, −1,31 %, 0,00 %, +0,02 pt")
    Verifier(DecimalesPrix(74306) = 0 && DecimalesPrix(108.6) = 2 && DecimalesPrix(0.2241) = 4, "décimales selon le prix")
    ; ---- listes
    Verifier(ListeCatalogue("AAPL, MC.PA,XXX,MC.PA", MARCHES_ACTIONS) = "MC.PA,AAPL", "liste : ordre du catalogue, inconnus et doublons retirés")
    MarchesCryptos := "ethereum,bitcoin,solana"
    Verifier(CryptosDemandees() = "bitcoin,ethereum,solana", "cryptos demandées : le Bitcoin en tête, une seule fois (" CryptosDemandees() ")")
    MarchesCryptos := ""
    Verifier(CryptosDemandees() = "bitcoin", "sans crypto choisie : le Bitcoin quand même (widget)")
    MarchesIndiceW := true, MarchesIndice := "^FCHI", MarchesIndices := "^FCHI,^GSPC", MarchesActions := "MC.PA,AAPL", MarchesTaux := "^TNX,fr10,zone10"
    Verifier(SymbolesDemandes() = "^FCHI,^GSPC,MC.PA,AAPL,^TNX", "symboles Yahoo : " SymbolesDemandes())
    Verifier(TauxDemandes() = "fr10,zone10", "taux BCE : " TauxDemandes())
    ; ---- lecture (fichiers du dossier de test)
    LireMarches(), LireActus()
    Verifier(Marches.Has("C|bitcoin") && Marches["C|bitcoin"].prix > 0 && Marches["C|bitcoin"].courbe.Length > 100, "Bitcoin lu : " (Marches.Has("C|bitcoin") ? Marches["C|bitcoin"].prix " €" : "absent"))
    Verifier(Marches.Has("S|bitcoin") && Marches["S|bitcoin"].t.Length = Marches["S|bitcoin"].v.Length && Marches["S|bitcoin"].v.Length > 20, "courbe 24 h du Bitcoin : " (Marches.Has("S|bitcoin") ? Marches["S|bitcoin"].v.Length " points" : "absente"))
    Verifier(Marches.Has("Y|^FCHI") && Marches["Y|^FCHI"].t.Length = Marches["Y|^FCHI"].v.Length, "CAC 40 lu (" (Marches.Has("Y|^FCHI") ? Marches["Y|^FCHI"].prix : "absent") ")")
    Verifier(ActusListe.Has("une") && ActusListe["une"].Length >= 5 && ActusListe["une"][1].lien ~= "^https://", "titres à la une lus (" (ActusListe.Has("une") ? ActusListe["une"].Length : 0) ")")
    ; ---- instruments
    i := Instrument("c:bitcoin")
    Verifier(i.nom = "Bitcoin" && i.unite = "€" && IsNumber(i.var) && i.plages.Length = 4, "instrument Bitcoin : " i.nom ", " i.info)
    i := Instrument("t:fr10")
    Verifier(i.taux && i.plages.Length = 1 && (!Marches.Has("T|fr10") || InStr(i.info, "moyenne de")), "instrument OAT : " i.info)
    i := Instrument("y:^TNX")
    Verifier(i.taux, "le taux US 10 ans varie en points")
    ; ---- courbes locales
    cb := CourbeInstrument("c:bitcoin", "7")
    Verifier(cb.v.Length > 100 && cb.t.Length = cb.v.Length && cb.t[cb.t.Length] - cb.t[1] > 6 * 86400, "Bitcoin 7 j : courbe horaire sur une semaine")
    ; ---- widget : éléments et titre qui tourne
    MarchesIndice := "^FCHI"
    el := ElementsMarches()
    Verifier(el.Length = 2 && el[1].nom = "Bitcoin" && el[2].nom = "CAC 40", "ligne du widget : Bitcoin et CAC 40")
    UneRang := 1
    a1 := UneCourante(), UneRang := 2
    a2 := UneCourante(), UneRang := 11
    Verifier(IsObject(a1) && IsObject(a2) && a1.titre != a2.titre && UneCourante().titre = a1.titre, "titre à la une : tourne sur 10 (franceinfo et Le Monde)")
    ; ---- mise en page du tableau de bord (3 échelles)
    for kp in [1, 1.5, 2.5] {
        MarchesSel := "c:bitcoin", MarchesPlage := "1"
        mp := MiseEnPageMarches(kp, MARCHES_H)
        dedans := true, nbA := 0, nbI := 0
        for z in mp.zones
            if !z.fixe {
                dedans := dedans && z.x >= 0 && z.x + z.w <= mp.w
                nbA += (z.type = "actu"), nbI += (z.type = "instrument")
            }
        Verifier(dedans && nbA >= 10 && nbI >= 6, "tableau de bord à " kp " : " nbI " cours, " nbA " titres, tout dans la fenêtre")
    }
    ChoisirCourbe("t:fr10")
    Verifier(MarchesSel = "t:fr10" && MarchesPlage = "0", "choisir l'OAT : sa seule période")
    ChoisirCourbe("c:bitcoin")
    Verifier(MarchesPlage = "1", "retour au Bitcoin : 1 j")
    MarchesPlage := "30"
    ChoisirCourbe("y:^FCHI")
    Verifier(MarchesPlage = "1mo", "1 mois du Bitcoin → 1 mois du CAC 40")
    ; ---- alertes (une fois par jour et par sens ; seuils franchis dans les deux sens)
    global AlerteBtc, AlerteSeuils, AlerteActions
    AlerteBtc := 5, AlerteSeuils := "75000,70000", AlerteActions := 0
    try IniDelete(F_REGLAGES, "widget", "alertes_vues")
    IniWrite(74000, F_REGLAGES, "widget", "alerte_prix")
    c := Marches["C|bitcoin"], p0 := c.prix, v0 := c.v24
    c.prix := 75500, c.v24 := 6.2
    m1 := VerifierAlertes(true), m2 := VerifierAlertes(true)
    Verifier(m1.Length = 2 && InStr(m1[1], "Bitcoin +6,20") && InStr(m1[2], "au-dessus de 75" Chr(0x202F) "000"), "alertes : +6,2 % en 24 h et seuil de 75 000 € franchi")
    Verifier(!m2.Length, "… pas deux fois (même jour, même sens)")
    c.prix := 69000, c.v24 := -7
    m3 := VerifierAlertes(true)
    Verifier(m3.Length = 3 && InStr(m3[1], "−7,00") && InStr(m3[2], "sous 75") && InStr(m3[3], "sous 70"), "baisse : −7 % et deux seuils franchis vers le bas (" m3.Length ")")
    AlerteBtc := 0, AlerteSeuils := ""
    c.prix := 80000, c.v24 := 9
    Verifier(!VerifierAlertes(true).Length, "alertes coupées : rien")
    c.prix := p0, c.v24 := v0
    try IniDelete(F_REGLAGES, "widget", "alertes_vues")
    try IniDelete(F_REGLAGES, "widget", "alerte_prix")
    ; ---- temps d'un dessin complet (survol de la courbe : un dessin par mouvement)
    kp := A_ScreenDPI / 96, MarchesSel := "c:bitcoin", MarchesPlage := "1"
    mp := MiseEnPageMarches(kp, MARCHES_H), w := Round(mp.w * kp), h := Round(mp.h * kp), t0 := A_TickCount
    Loop 5 {
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
        DessinerMarches(gr, w, h, kp, mp, {defil: 0, survol: "courbe", curseur: {x: 300 * kp, y: 200 * kp}})
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    }
    ms := (A_TickCount - t0) // 5
    Verifier(ms < 250, "dessin du tableau de bord à " kp " : " ms " ms")   ; (160 ms mesurés sous charge : 250 laisse la marge, un vrai ralentissement dépasse)
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}

; La vraie fenêtre, dans ce processus de test (données de test, faux widget
; invisible, aucune collecte lancée) : clics, survol de la courbe, molette,
; Échap, une seule fenêtre à la fois, et les zones du widget (Bitcoin, une, phrase)
TestFenetreMarches(fichier) {
    global HWIDGET, ReglCurseurTest, MarchesSel, MarchesPlage, DernierMarches
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    faux := Gui("-Caption +ToolWindow")
    faux.Show("NA x" (A_ScreenWidth - 420) " y40 w300 h200")
    WinSetTransparent(1, faux)
    HWIDGET := faux.Hwnd
    ConstruireMenus()
    MarchesMessages(), ReglMessages(), FicheMessages()
    LireMarches(), LireActus(), LirePhrases()
    DernierMarches := MaintenantUnix()            ; (données fraîches : pas de collecte à l'ouverture)
    MarchesSel := "c:bitcoin", MarchesPlage := "1"
    Viser(id) {
        global ReglCurseurTest
        for zo in MarchesGeo.mp.zones
            if (zo.id = id) {
                WinGetPos(&fx, &fy, , , "ahk_id " MarchesHwnd)
                zy := zo.fixe ? zo.y : zo.y + MarchesGeo.mp.y0 - MarchesGeo.defil
                ReglCurseurTest := [fx + (zo.x + zo.w / 2) * MarchesGeo.kp, fy + (zy + zo.h / 2) * MarchesGeo.kp]
                return true
            }
        return false
    }
    Envoyer(msg, wp := 0, attente := 150) {
        PostMessage(msg, wp, 0, , "ahk_id " MarchesHwnd)
        Sleep(attente)
    }
    OuvrirMarches(), Sleep(150)
    Verifier(MarchesHwnd && DllCall("IsWindowVisible", "Ptr", MarchesHwnd) && SurgieOuverte() && !MarchesPID,
        "ouverte (" MarchesGeo.w "×" MarchesGeo.h " px), sans collecte (données fraîches)")
    Verifier(Viser("plage:7"), "pastille « 7 j » trouvée")
    Envoyer(0x201)
    Verifier(MarchesPlage = "7" && !MarchesPID, "clic sur « 7 j » : courbe de la semaine (déjà là, rien à télécharger)")
    Viser("i:c:ethereum"), Envoyer(0x201)
    Verifier(MarchesSel = "c:ethereum" && MarchesPlage = "7", "clic sur Ethereum : sa courbe, même période")
    Viser("courbe")
    MarchesGeo.suivi := true                      ; (le vrai curseur est ailleurs : pas de « souris sortie » aussitôt)
    MarchesDeplace(0, 0, 0x200, MarchesHwnd)
    Verifier(MarchesGeo.survol = "courbe" && IsObject(MarchesGeo.curseur), "survol de la courbe : la valeur sous le curseur")
    Sleep(100)
    d0 := MarchesGeo.defil
    Envoyer(0x20A, (-120 & 0xFFFF) << 16)          ; un cran vers soi
    Verifier(MarchesGeo.mp.defilMax > 0 && MarchesGeo.defil = Min(MarchesGeo.mp.defilMax, d0 + 60), "molette : 60 px plus bas")
    Envoyer(0x100, 0x1B, 250)
    Verifier(!MarchesHwnd && !SurgieOuverte(), "Échap : fermée")
    OuvrirMarches(), Sleep(250)                   ; (250 ms : sous charge, 100 ne suffisaient pas toujours)
    OuvrirReglages(), Sleep(250)
    Verifier(!MarchesHwnd && ReglHwnd, "Réglages ouvert : le tableau de bord se ferme (une seule fenêtre)")
    OuvrirMarches(), Sleep(250)
    Verifier(MarchesHwnd && !ReglHwnd, "et l'inverse")
    FermerMarches("test")
    ; les zones du widget
    ActionZone("marches"), Sleep(100)
    Verifier(MarchesHwnd, "clic sur le Bitcoin du widget : le tableau de bord s'ouvre")
    FermerMarches("test")
    global UneAffichee := UneCourante()           ; (le titre que le widget montrerait)
    ActionZone("une"), Sleep(150)
    Verifier(FicheHwnd && !MarchesHwnd && IsObject(FicheGeo) && FicheGeo.a.lien == UneAffichee.lien && FicheGeo.retour = ""
        && FicheGeo.liste.Length = ListeUneWidget().Length, "clic sur le titre à la une : sa fiche seule, pas le tableau de bord")
    i0 := FicheGeo.idx
    PostMessage(0x100, 0x27, 0, , "ahk_id " FicheHwnd), Sleep(150)
    Verifier(FicheHwnd && FicheGeo.idx = Mod(i0, FicheGeo.liste.Length) + 1 && FicheGeo.a.lien == FicheGeo.liste[FicheGeo.idx].lien, "→ : l'article suivant, même fenêtre")
    PostMessage(0x100, 0x1B, 0, , "ahk_id " FicheHwnd), Sleep(250)
    Verifier(!FicheHwnd && !SurgieOuverte(), "Échap : la fiche se ferme")
    OuvrirMarches(), Sleep(150)
    Verifier(Viser("a:À la une1"), "titre du tableau de bord trouvé")
    Envoyer(0x201, 0, 250)
    Verifier(FicheHwnd && !MarchesHwnd && FicheGeo.retour = "marches" && FicheGeo.a.lien == ActusListe["une"][1].lien,
        "clic sur un titre du tableau de bord : sa fiche, à sa place")
    WinGetPos(&fx, &fy, , , "ahk_id " FicheHwnd)
    ReglCurseurTest := [fx + 115 * FicheGeo.kp, fy + 32 * FicheGeo.kp]   ; (le bouton « ‹ Actus et marchés »)
    PostMessage(0x201, 0, 0, , "ahk_id " FicheHwnd), Sleep(250)
    Verifier(MarchesHwnd && !FicheHwnd, "« ‹ Actus et marchés » : retour au tableau de bord")
    FermerMarches("test")
    HWIDGET := 0                                  ; (pas de rendu du widget dans ce test)
    ChoisirPhrase(), avant := PhraseCour.fr
    ActionZone("phrase")
    Verifier(IsObject(PhraseCour) && PhraseCour.fr != avant, "clic sur la phrase : la suivante (« " PhraseCour.fr " »)")
    ReglCurseurTest := ""
    faux.Destroy()
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}
