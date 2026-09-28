; =============================================================================
;  Widget météo — deuxième ville et bande d'infos sous le widget
;  — inclus par widget-meteo.ahk
;
;  Vigilance (menu Afficher ▸ Vigilance) : celle de Météo-France pour le
;  département de la position (flux MeteoAlarm), en pastille aux couleurs
;  officielles dans la bande tant qu'elle dure, et en option la Seine haute
;  (Hub'Eau, station d'Alfortville). Rien tant qu'il n'y a rien à signaler.
;  Deuxième ville (menu Afficher ▸ Deuxième ville) : son heure locale, toujours
;  juste (fuseau calculé par l'ICU de Windows, heure d'été comprise, même hors
;  ligne), sa température et une mini-illustration (requête légère séparée à
;  chaque collecte, clés v2_* de donnees.txt).
;  Dans le widget : sous le lieu en Android et Épuré, sinon (iPhone, En toutes
;  lettres, Analogique, ou quand le calendrier prend la place sous le lieu)
;  dans la bande d'infos, sous tout le reste : le widget grandit alors d'une
;  ligne. Dans les prévisions détaillées : une section sous l'en-tête.
;  (Constantes et état : LIGNE_BANDE, LIB_V2_*, LIB_VIG*, C_VIG, NOMS_NIV,
;  Ville2*, Vigilance*, Seine*, BandeInfos, MenuVille2…, déclarés dans widget-meteo.ahk.)
; =============================================================================

; ---------- Fuseaux : ICU de Windows (icu.dll, Windows 10 1903 et plus) ----------

; Décalage UTC en secondes (heure d'été comprise) du fuseau IANA « iana » à
; l'instant « unix » ; "" si l'ICU manque ou ne connaît pas ce fuseau
DecalageFuseau(iana, unix) {
    static icu := DllCall("LoadLibrary", "Str", "icu.dll", "Ptr")
    if (!icu || iana = "")
        return ""
    err := Buffer(4, 0)
    cal := DllCall("icu\ucal_open", "WStr", iana, "Int", -1, "AStr", "", "Int", 1, "Ptr", err, "CDecl Ptr")   ; UCAL_GREGORIAN
    if (!cal || NumGet(err, "Int") > 0)
        return ""
    id := Buffer(128, 0)
    n := DllCall("icu\ucal_getTimeZoneID", "Ptr", cal, "Ptr", id, "Int", 64, "Ptr", err, "CDecl Int")
    DllCall("icu\ucal_setMillis", "Ptr", cal, "Double", unix * 1000.0, "Ptr", err, "CDecl")
    z := DllCall("icu\ucal_get", "Ptr", cal, "Int", 15, "Ptr", err, "CDecl Int")    ; UCAL_ZONE_OFFSET (ms)
    d := DllCall("icu\ucal_get", "Ptr", cal, "Int", 16, "Ptr", err, "CDecl Int")    ; UCAL_DST_OFFSET (ms)
    e := NumGet(err, "Int")
    DllCall("icu\ucal_close", "Ptr", cal, "CDecl")
    if (e > 0 || StrGet(id, n, "UTF-16") = "Etc/Unknown")    ; fuseau inconnu : l'ICU se rabat sur GMT sans erreur
        return ""
    return (z + d) // 1000
}

; Écart entre l'heure du PC et l'UTC, en secondes (arrondi à la minute)
EcartUTC() => Round(DateDiff(A_Now, A_NowUTC, "Seconds") / 60) * 60

; ---------- Deuxième ville ----------

Ville2Definie() => (Ville2Nom != "" && Ville2Pos != "")

; Données de la collecte pour CETTE ville (elle a pu changer depuis), pas trop vieilles
Ville2Fraiche() {
    if (Donnees.Get("v2_pos", "") != Ville2Pos || !IsNumber(Donnees.Get("v2_temp", "")) || !IsInteger(Donnees.Get("v2_maj", "")))
        return false
    return (MaintenantUnix() - Integer(Donnees["v2_maj"])) / 60 <= RESUME_MAX
}

; Instant local de la ville (AAAAMMJJHHMMSS), "" si inconnu : l'ICU d'abord,
; sinon le décalage de la dernière collecte (faux d'une heure seulement si
; l'heure a changé là-bas depuis). Suit le moment affiché (imposé dans les aperçus).
MomentVille2() {
    utc := DateAdd(MomentAffiche(), -EcartUTC(), "Seconds")
    off := DecalageFuseau(Ville2Fuseau, DateDiff(utc, "19700101", "Seconds"))
    if (off = "" && Donnees.Get("v2_pos", "") = Ville2Pos)
        off := Donnees.Get("v2_decalage", "")
    return IsInteger(off) ? DateAdd(utc, Integer(off), "Seconds") : ""
}

; Jour ou nuit là-bas, d'après son lever et son coucher du jour (à défaut,
; is_day de la collecte, vieux de 15 min au plus)
JourVille2(moment) {
    lev := Minutes(Donnees.Get("v2_lever", "")), cou := Minutes(Donnees.Get("v2_coucher", ""))
    if (moment = "" || lev < 0 || cou < 0)
        return Donnees.Get("v2_jour", "1")
    m := Minutes(FormatTime(moment, "HH:mm"))
    return (m >= lev && m < cou) ? "1" : "0"
}

; « Pointe-à-Pitre 11:21 · 30° » précédé d'une mini-illustration ; seul le nom
; se raccourcit, l'heure et la température restent entières. x = début
; (align 0) ou bord gauche de la zone où centrer (align 1), yb = ligne de
; base, cap = hauteur de capitale. Sans données fraîches : le nom et l'heure.
LigneVille2(L, t, u, x, yb, largeur, align, cap, couleur) {
    if !Ville2Definie()
        return
    moment := MomentVille2(), frais := Ville2Fraiche()
    suffixe := ((moment != "") ? " " FormatTime(moment, "HH:mm") : "")
        . (frais ? " · " Round(Number(Donnees["v2_temp"])) Chr(0xB0) : "")
    em := EmPourCapitale(P_TEXTE, cap)
    s := frais ? 1.35 * cap : 0, ecart := s ? 0.45 * cap : 0
    dispo := largeur - s - ecart - (LargeurTexte("x" suffixe, P_TEXTE, em) - LargeurTexte("x", P_TEXTE, em))
    txt := Tronquer(Ville2Nom, P_TEXTE, em, dispo) suffixe
    x0 := align ? x + (largeur - s - ecart - LargeurTexte(txt, P_TEXTE, em)) / 2 : x
    if s
        IllustrerTheme(L, Illustration(Donnees["v2_code"], JourVille2(moment)), x0, yb - cap / 2 - s / 2, s)
    Poser(L, txt, P_TEXTE, em, x0 + s + ecart, yb, 0, couleur)
}

; Sous le lieu (Android, Épuré), sauf si le calendrier y a sa ligne : la
; ville passe alors dans la bande, pour que la hauteur ne change pas selon les jours
Ville2DansBande() => !(Style = "android" || Style = "epure") || CalendrierActif()

; « 6 h de moins qu'ici », « 3 h 30 de plus qu'ici », « même heure qu'ici »
EcartHoraire(moment) {
    if (moment = "")
        return "heure locale inconnue"
    d := Round(DateDiff(moment, MomentAffiche(), "Seconds") / 60)
    if (Abs(d) < 1)
        return "même heure qu'ici"
    hh := Abs(d) // 60, mm := Mod(Abs(d), 60)
    return hh " h" (mm ? " " Format("{:02}", mm) : "") ((d < 0) ? " de moins" : " de plus") " qu'ici"
}

; « 6 h », « 16 h 28 » : heure locale d'un instant Unix
HeureCourte(unix) {
    t := HeureLocaleUnix(unix)
    return Integer(SubStr(t, 1, 2)) " h" ((SubStr(t, 4, 2) != "00") ? " " SubStr(t, 4, 2) : "")
}

; « à 6 h » le jour même, « hier à 6 h », « le 21/09 à 6 h » sinon
HeureDatee(unix) {
    j := DateDiff(SubStr(A_Now, 1, 8), SubStr(LocalDeUnix(Integer(unix)), 1, 8), "Days")
    return ((j = 0) ? "" : (j = 1) ? "hier " : "le " FormatTime(LocalDeUnix(Integer(unix)), "dd/MM") " ") "à " HeureCourte(unix)
}

; « 154 765 » (espaces fines insécables)
Milliers(n) => RegExReplace(n, "\B(?=(\d{3})+(?!\d))", Chr(0x202F))

; ---------- Bande d'infos sous le widget ----------

; Lignes de la bande, calculées une fois par rendu (la hauteur du widget en dépend)
PreparerBande() {
    global BandeInfos
    b := []
    if (Ville2W && Ville2Definie() && Ville2DansBande())
        b.Push({type: "ville2"})
    if IsObject(v := VigilanceActive())
        b.Push({type: "vigilance", v: v})
    if IsObject(s := SeineHaute())
        b.Push({type: "seine", v: s})
    if IsObject(v := UvFort())
        b.Push({type: "uv", v: v})
    if IsObject(v := PastillePluie())             ; pluie dans l'heure
        b.Push({type: "air", v: v})
    if IsObject(v := PastilleRer())               ; ligne de la gare choisie perturbée (widget-meteo-rer.ahk)
        b.Push({type: "air", v: v})
    for p in PastillesAir()                       ; qualité de l'air, sable, pollens
        b.Push({type: "air", v: p})
    if IsObject(i := PastilleIss())               ; passage visible de la station spatiale
        b.Push({type: "air", v: i})
    if IsObject(r := PastilleRecord())            ; proche d'un record du jour
        b.Push({type: "air", v: {textes: r.textes, fond: r.fond, encre: r.encre, icone: "thermo"}})
    if (RerW && RerFrais())                       ; prochains départs de la gare choisie (widget-meteo-rer.ahk)
        b.Push({type: "rer"})
    if ElementsMarches().Length                   ; Bitcoin et indice (widget-meteo-marches.ahk)
        b.Push({type: "marches"})
    if IsObject(UneCourante())                    ; titre à la une
        b.Push({type: "une"})
    if IsObject(PhraseCourante())                 ; phrase d'anglais : français et anglais en un bloc (widget-meteo-anglais.ahk)
        b.Push({type: "phrase", h: 1.7})
    BandeInfos := b
    if HWIDGET {                                  ; l'état du menu suit l'heure et les données
        MajEtatVigilance()
        MajEtatAir()
    }
}

; La bande commence sous tout le reste : cadran « dessous », rangée des heures
; ou ligne du soleil (en HC, depuis le haut du bloc de contenu)
DebutBande() => 1.023 + ExtraStyle() + LigneBasse()

; Hauteur de la bande en lignes (le bloc de la phrase d'anglais en prend 1,7)
HauteurBande() {
    n := 0
    for ligne in BandeInfos
        n += ligne.HasOwnProp("h") ? ligne.h : 1
    return n
}

DessinerBande(L, t, k) {
    if !BandeInfos.Length
        return
    u := HC * k, x := PAD * k, y0 := PAD * k + 0.012 * u + DebutBande() * u
    largeur := LargeurContenu() * u
    align := (Style = "iphone" || (Style = "analogique" && CadranMeteo = "dessous")) ? 1 : 0
    ; voile derrière les lignes du bas (Bitcoin, une, phrase : toujours en fin de bande), d'un seul tenant
    if VoileBande {
        yy := y0, haut := "", bas := ""
        for ligne in BandeInfos {
            h := (ligne.HasOwnProp("h") ? ligne.h : 1) * LIGNE_BANDE * u
            if (ligne.type = "rer" || ligne.type = "marches" || ligne.type = "une" || ligne.type = "phrase")
                haut := (haut = "") ? yy : haut, bas := yy + h
            yy += h
        }
        if (haut != "") {
            L.Push({p: CheminArrondi(x - 0.035 * u, haut + 0.004 * u, largeur + 0.07 * u, bas - haut - 0.002 * u, 0.04 * u),
                f: t.sombre ? 0x80FFFFFF : 0x6B000000, o: 0, z: false, a: 0})   ; (a : 0 : pas d'ombre sous le voile)
        }
    }
    y := y0
    for ligne in BandeInfos {
        if (A_Index > 1) {
            p := BandeInfos[A_Index - 1]
            y += (p.HasOwnProp("h") ? p.h : 1) * LIGNE_BANDE * u
        }
        switch ligne.type {
            case "ville2": LigneVille2(L, t, u, x, y + 0.095 * u, largeur, align, 0.0635 * u, t.second)
            case "vigilance":
                v := ligne.v
                Pastille(L, u, x, y + 0.03 * u, largeur, align, [v.texte ((v.fin != "") ? " " v.fin : ""), v.texte, "Vigilance " NOMS_NIV[v.niv]],
                    C_VIG[v.niv], (v.niv >= 4) ? 0xFFFFFFFF : 0xFF16191D, "alerte")
            case "seine":
                v := ligne.v
                Pastille(L, u, x, y + 0.03 * u, largeur, align, v.textes, (v.niv = 2) ? 0xFF1F63C6 : 0xFF8CCBFA,
                    (v.niv = 2) ? 0xFFFFFFFF : 0xFF0B2740, "eau")
            case "uv":
                Pastille(L, u, x, y + 0.03 * u, largeur, align, ligne.v.textes, ligne.v.fond, ligne.v.encre, "soleil")
            case "air":
                Pastille(L, u, x, y + 0.03 * u, largeur, align, ligne.v.textes, ligne.v.fond, ligne.v.encre, ligne.v.icone)
            case "rer":     LigneRer(L, t, u, x, y, largeur, align)
            case "marches": LigneMarches(L, t, u, x, y, largeur, align)
            case "une":     LigneUne(L, t, u, x, y, largeur, align)
            case "phrase":  BlocPhrase(L, t, u, x, y, largeur, align)
        }
    }
}

; ---------- Fenêtre des prévisions : section « infos » sous l'en-tête ----------

; Vigilances en cours et à venir (2 lignes au plus), Seine, 2e ville
LignesInfos() {
    l := []
    if VigilanceW {
        vs := [], maint := MomentUnix()
        if (Donnees.Get("vig_etat", "") = "ok")
            for a in FusionnerVigilances(LireVigilances())
                if (a.fin > maint && a.niv >= VigMin)
                    vs.Push(a)
        Loop vs.Length - 1 {                      ; les plus graves d'abord, puis par début
            i := A_Index + 1, e := vs[i], k := i - 1
            while (k >= 1 && (vs[k].niv < e.niv || (vs[k].niv = e.niv && vs[k].debut > e.debut)))
                vs[k + 1] := vs[k], k--
            vs[k + 1] := e
        }
        if !vs.Length
            l.Push({type: "sansvig", h: 46})
        for a in vs {
            if (A_Index = 2 && vs.Length > 2) {
                l.Push({type: "vigplus", n: vs.Length - 1, h: 30})
                break
            }
            l.Push({type: "vig", a: a, h: 46})
        }
    }
    if SeineW
        l.Push({type: "seine", h: 46})
    if (Ville2Prev && Ville2Definie())
        l.Push({type: "ville2", h: 46})
    return l
}

; Un message du même phénomène et du même niveau qui prend le relais (J puis
; J+1) prolonge la vigilance au lieu de faire une 2e ligne (comme la pastille)
FusionnerVigilances(tout) {
    res := []
    for a in tout {
        absorbe := false
        for r in res
            if (r.typ = a.typ && r.niv = a.niv && a.debut >= r.debut && a.debut <= r.fin + 60) {
                r.fin := Max(r.fin, a.fin), absorbe := true
                break
            }
        if !absorbe
            res.Push({niv: a.niv, typ: a.typ, debut: a.debut, fin: a.fin, emis: a.emis, phen: a.phen})
    }
    return res
}

; La vigilance a-t-elle été vérifiée récemment ? (flux injoignable : l'ancienne liste est recopiée)
VigFraiche() => IsInteger(Donnees.Get("vig_maj", "")) && MomentUnix() - Integer(Donnees["vig_maj"]) <= 3 * 60 * PeriodeCollecte() + 600

; Hauteur de la section (px logiques), filet de fin compris ; 0 si vide
HauteurInfos() {
    h := 0
    for ligne in LignesInfos()
        h += ligne.h
    return h ? h + 12 : 0
}

; Dessine la section à partir de y0 (px logiques) ; renvoie sa hauteur
SectionInfos(L, kp, y0, pal) {
    X(v) => v * kp
    em(cap, police := P_TEXTE) => EmPourCapitale(police, cap * kp)
    y := y0 + 6
    for ligne in LignesInfos() {
        switch ligne.type {
            case "vig":
                a := ligne.a, enCours := (a.debut <= MomentUnix())
                L.Push({p: CheminArrondi(X(22), X(y + 9), X(12), X(12), X(3)), f: C_VIG[a.niv], o: 0, z: false, brut: true})
                bd := Poser(L, enCours ? FinVigilance(a.fin) : "à partir de " SubStr(FinVigilance(a.debut), 9), P_TEXTE, em(10), X(418), X(y + 20), 2, pal.second)
                titre := "Vigilance " NOMS_NIV[a.niv] " " a.phen
                Poser(L, Tronquer(titre, P_DATE, em(11, P_DATE), bd.x - X(42) - X(10)), P_DATE, em(11, P_DATE), X(42), X(y + 20), 0, pal.encre)
                ; l'attribution (service national, heure d'émission, lien) reste entière : seule la zone se raccourcit
                fin := (IsInteger(a.emis) ? " · émise à " HeureCourte(a.emis) : "") " · Météo-France via meteoalarm.org"
                bas := Tronquer(Donnees.Get("vig_zone", ""), P_TEXTE, em(9), X(376) - LargeurTexte(fin, P_TEXTE, em(9))) fin
                Poser(L, bas, P_TEXTE, em(9), X(42), X(y + 37), 0, pal.discret)
            case "vigplus":
                Poser(L, "+ " ligne.n ((ligne.n > 1) ? " autres vigilances" : " autre vigilance") " · meteoalarm.org",
                    P_TEXTE, em(10), X(42), X(y + 18), 0, pal.second)
            case "sansvig":
                etat := Donnees.Get("vig_etat", "")
                txt := (etat = "hors_zone") ? "Vigilance : indisponible hors de France métropolitaine"
                    : (etat = "ok" && !VigFraiche()) ? "Vigilance : pas de données récentes (meteoalarm.org injoignable ?)"
                    : (etat = "ok") ? ((VigMin >= 3) ? "Aucune vigilance orange ou rouge · " : "Aucune vigilance en cours · ") Donnees.Get("vig_zone", "")
                    : (etat = "erreur") ? "Vigilance : pas de données (réseau ?)" : "Vigilance : pas encore de données"
                Poser(L, Tronquer(txt, P_TEXTE, em(10), X(376)), P_TEXTE, em(10), X(42), X(y + 20), 0, pal.second)
                if IsInteger(Donnees.Get("vig_maj", ""))
                    Poser(L, "vérifié " HeureDatee(Donnees["vig_maj"]) " · Météo-France via meteoalarm.org",
                        P_TEXTE, em(9), X(42), X(y + 37), 0, pal.discret)
            case "seine":
                h := Donnees.Get("seine_h", ""), tend := Donnees.Get("seine_tendance", "")
                ok := (Donnees.Get("seine_etat", "") = "ok" && IsNumber(h))
                vieille := ok && !(IsInteger(Donnees.Get("seine_date", "")) && (MomentUnix() - Integer(Donnees["seine_date"])) / 3600 <= 3)
                sens := !IsNumber(tend) ? "" : (tend >= 0.05) ? ", en hausse" : (tend <= -0.05) ? ", en baisse" : ", stable"
                Goutte(L, X(24), X(y + 7), X(11))
                bd := {x: X(418)}
                if (ok && IsInteger(Donnees.Get("seine_date", "")))
                    bd := Poser(L, "relevé " HeureDatee(Donnees["seine_date"]), P_TEXTE, em(10), X(418), X(y + 20), 2, vieille ? pal.discret : pal.second)
                txt := "La Seine à " SeineLieu " : " (!ok ? "pas de mesure" : vieille ? "pas de mesure récente"
                    : StrReplace(Format("{:.2f}", h), ".", ",") Chr(0xA0) "m" sens)
                Poser(L, Tronquer(txt, P_DATE, em(11, P_DATE), bd.x - X(42) - X(10)), P_DATE, em(11, P_DATE), X(42), X(y + 20), 0, pal.encre)
                Poser(L, Tronquer("haute dès " StrReplace(Format("{:.2f}", SeineSeuil), ".", ",") " m, crue dès " StrReplace(Format("{:.2f}", SeineCrue), ".", ",")
                    . " m (2016 : 3,65 m) · Hub'Eau", P_TEXTE, em(9), X(376)), P_TEXTE, em(9), X(42), X(y + 37), 0, pal.discret)
            case "ville2":
                moment := MomentVille2(), frais := Ville2Fraiche()
                if frais
                    Illustrer(L, Illustration(Donnees["v2_code"], JourVille2(moment)), X(18), X(y + 6), X(20))
                droite := ""
                if frais
                    droite := Round(Number(Donnees["v2_temp"])) "°" ((IsNumber(Donnees.Get("v2_min", "")) && IsNumber(Donnees.Get("v2_max", "")))
                        ? "  ·  min " Round(Number(Donnees["v2_min"])) "°  max " Round(Number(Donnees["v2_max"])) "°" : "")
                bd := (droite != "") ? Poser(L, droite, P_TEXTE, em(10), X(418), X(y + 20), 2, pal.second) : {x: X(418)}
                heure := (moment != "") ? "  " FormatTime(moment, "HH:mm") : ""
                dispo := bd.x - X(42) - X(10) - LargeurTexte(heure, P_DATE, em(11, P_DATE))
                Poser(L, Tronquer(Ville2Nom, P_DATE, em(11, P_DATE), dispo) heure, P_DATE, em(11, P_DATE), X(42), X(y + 20), 0, pal.encre)
                bas := EcartHoraire(moment)
                if frais
                    bas .= " · " StrLower(InfosMeteo(Donnees["v2_code"]))
                        . ((Donnees.Get("v2_lever", "") != "") ? " · lever " Donnees["v2_lever"] ", coucher " Donnees.Get("v2_coucher", "?") : "")
                Poser(L, Tronquer(bas, P_TEXTE, em(9), X(376)), P_TEXTE, em(9), X(42), X(y + 37), 0, pal.discret)
        }
        y += ligne.h
    }
    Filet(L, X(22), X(y + 6), X(418), pal.grille)
    return y + 12 - y0
}

; ---------- Vigilance (vig_alertes : « niv|type|début|fin|émis|phénomène », séparées par « ; ») ----------

LireVigilances() {
    l := []
    for bloc in StrSplit(Donnees.Get("vig_alertes", ""), ";") {
        v := StrSplit(bloc, "|")
        if (v.Length >= 6 && IsInteger(v[1]) && IsInteger(v[3]) && IsInteger(v[4]))
            l.Push({niv: Integer(v[1]), typ: v[2], debut: Integer(v[3]), fin: Integer(v[4]), emis: v[5], phen: v[6]})
    }
    return l
}

; La vigilance à afficher maintenant : {niv, texte, fin}, ou "" (aucune, option
; coupée, hors de France). Elle s'efface d'elle-même à l'heure de fin, même hors
; ligne. Un message du même phénomène qui prend le relais (J puis J+1) la
; prolonge ; plusieurs phénomènes au niveau le plus haut sont joints, avec
; « jusqu'à … » seulement si leur fin est commune.
VigilanceActive() {
    if (!VigilanceW || Donnees.Get("vig_etat", "") != "ok")
        return ""
    tout := LireVigilances(), maint := MomentUnix(), act := []
    for a in tout
        if (a.debut <= maint && maint < a.fin && a.niv >= VigMin)
            act.Push({niv: a.niv, typ: a.typ, fin: a.fin, phen: a.phen})
    if !act.Length
        return ""
    for a in act
        Loop {
            prolonge := false
            for b in tout
                if (b.typ = a.typ && b.niv >= a.niv && b.debut <= a.fin + 60 && b.fin > a.fin)
                    a.fin := b.fin, prolonge := true
        } until !prolonge
    nmax := 0
    for a in act
        nmax := Max(nmax, a.niv)
    noms := [], fins := Map(), vus := Map()
    for a in act
        if (a.niv = nmax) {
            if !vus.Has(a.phen)
                noms.Push(a.phen), vus[a.phen] := 1
            fins[a.fin] := 1
        }
    fin := ""
    if (fins.Count = 1)
        for f in fins
            fin := FinVigilance(f)
    return {niv: nmax, texte: "Vigilance " NOMS_NIV[nmax] " " JoindreEt(noms), fin: fin}
}

; « orages », « orages et canicule », « vent violent, orages et canicule »
JoindreEt(l) {
    s := ""
    for v in l
        s .= (A_Index = 1) ? v : (A_Index = l.Length) ? " et " v : ", " v
    return s
}

; « jusqu'à 22 h », « jusqu'à 22 h 30 », « jusqu'à minuit », « jusqu'à demain 6 h »,
; « jusqu'à jeudi 16 h » (0 h pile : fin de la journée d'avant)
FinVigilance(unix) {
    loc := LocalDeUnix(unix)                      ; heure d'été ou d'hiver de CE jour-là
    hh := Integer(FormatTime(loc, "H")), mm := FormatTime(loc, "mm")
    j := DateDiff(SubStr(loc, 1, 8), SubStr(MomentAffiche(), 1, 8), "Days"), minuit := (hh = 0 && mm = "00")
    if minuit {
        j -= 1
        heure := (j <= 0) ? "minuit" : "24 h"
    } else
        heure := hh " h" ((mm != "00") ? " " mm : "")
    if (j <= 0)
        return "jusqu'à " heure
    if (j = 1)
        return "jusqu'à demain " heure
    return "jusqu'à " FormatTime(DateAdd(loc, minuit ? -1 : 0, "Days"), "dddd") " " heure
}

; ---------- Seine haute ----------

; {niv (1 haute, 2 crue), textes} ou "" : mesure de moins de 3 h au-dessus du
; seuil. Hystérésis de 5 cm (bruit de ±3 cm) : pas de clignotement autour du seuil.
SeineHaute() {
    global SeineAffichee, SeineCrueAffichee
    ok := SeineW && Donnees.Get("seine_etat", "") = "ok" && IsNumber(Donnees.Get("seine_h", ""))
        && IsInteger(Donnees.Get("seine_date", "")) && (MomentUnix() - Integer(Donnees["seine_date"])) / 3600 <= 3
    h := ok ? Number(Donnees["seine_h"]) : 0
    SeineAffichee := ok && (h >= SeineSeuil || (SeineAffichee && h >= SeineSeuil - 0.05))
    SeineCrueAffichee := SeineAffichee && (h >= SeineCrue || (SeineCrueAffichee && h >= SeineCrue - 0.05))
    if !SeineAffichee
        return ""
    tend := Donnees.Get("seine_tendance", "")
    fleche := !IsNumber(tend) ? "" : (tend >= 0.05) ? " ↗" : (tend <= -0.05) ? " ↘" : ""
    debut := (SeineCrueAffichee ? "Crue de la Seine · " : "Seine haute · ") StrReplace(Format("{:.2f}", h), ".", ",") Chr(0xA0) "m"
    return {niv: SeineCrueAffichee ? 2 : 1, textes: [debut " à " SeineLieu fleche, debut fleche]}
}

; Pluie dans l'heure (Réglages ▸ Météo) : d'après la pluie par quart d'heure de
; la collecte (clé pluie15 : « instant du 1er créneau|mm,… », chaque valeur pour les
; 15 min qui précèdent son instant). Rien s'il ne pleut pas dans l'heure qui vient,
; ou si la prévision date de plus de 45 min. Seuil : 0,1 mm en 15 min.
PastillePluie() {
    if !PluieW
        return ""
    s := Donnees.Get("pluie15", ""), maj := Donnees.Get("maj", "")
    maint := MomentUnix()
    if (s = "" || !IsInteger(maj) || maint - Integer(maj) > 2700)
        return ""
    p := StrSplit(s, "|")
    if (p.Length < 2 || !IsInteger(p[1]))
        return ""
    t0 := Integer(p[1]), debut := "", fin := "", maxi := 0, auBout := false
    v := StrSplit(p[2], ",")
    for k, x in v {
        fk := t0 + (k - 1) * 900                  ; fin du créneau k (il couvre les 15 min d'avant)
        if (fk <= maint)
            continue
        pleut := IsNumber(x) && Number(x) >= 0.1
        if (debut = "") {
            if pleut
                debut := Max(fk - 900, maint), fin := fk, maxi := Number(x)
        } else if pleut
            fin := fk, maxi := Max(maxi, Number(x))
        else
            break
        auBout := (k = v.Length)
    }
    if (debut = "" || debut - maint > 3600)
        return ""
    neige := IsNumber(Donnees.Get("temp", "")) && Number(Donnees["temp"]) <= 1
    nom := neige ? "Neige" : (maxi >= 2.5) ? "Forte pluie" : (maxi >= 0.5) ? "Pluie" : "Pluie faible"
    jusqua := auBout ? "pour un moment" : "jusqu'à " HeureCourte(fin)
    if (debut - maint < 300)                      ; il pleut (ou dans moins de 5 min)
        textes := [nom " " jusqua, nom]
    else {
        n := Max(5, Round((debut - maint) / 300) * 5)
        textes := [nom " dans " n Chr(0xA0) "min, " jusqua, nom " dans " n Chr(0xA0) "min", nom]
    }
    return {textes: textes, fond: (maxi >= 2.5) ? 0xFF1450B8 : 0xFF2F80ED, encre: 0xFFFFFFFF, icone: "pluie"}
}

; Pastille arrondie de la bande : icône et texte (le premier des « textes » qui
; tient, sinon le dernier raccourci), aux couleurs officielles pour la vigilance.
; Pas d'ombre sous ce qui est posé sur la pastille ; « brut » : jamais teintée.
Pastille(L, u, x, yHaut, largeur, align, textes, fond, encre, icone) {
    hp := 0.085 * u, cap := 0.036 * u, em := EmPourCapitale(P_DATE, cap)
    pad := 0.42 * hp, ic := 0.5 * hp, ecart := 0.28 * hp
    dispo := largeur - 2 * pad - ic - ecart, txt := ""
    for essai in textes
        if (LargeurTexte(essai, P_DATE, em) <= dispo) {
            txt := essai
            break
        }
    if (txt = "")
        txt := Tronquer(textes[textes.Length], P_DATE, em, dispo)
    lp := 2 * pad + ic + ecart + LargeurTexte(txt, P_DATE, em)
    x0 := align ? x + (largeur - lp) / 2 : x
    L.Push({p: CheminArrondi(x0, yHaut, lp, hp, hp / 2), f: fond, o: 0x000000, z: false, brut: true})
    n0 := L.Length
    c := {x: x0 + pad, y: yHaut + (hp - ic) / 2, u: ic / 100}
    if (icone = "alerte") {                       ; triangle et point d'exclamation
        Polygone(L, c, [[50, 4], [98, 92], [2, 92]], encre)
        Polygone(L, c, [[44, 32], [56, 32], [54, 64], [46, 64]], fond)
        Disque(L, c, 50, 77, 6.5, fond)
    } else if (icone = "soleil") {              ; un soleil : disque et 8 rayons
        Disque(L, c, 50, 50, 21, encre)
        segs := []
        Loop 8 {
            a := (A_Index - 1) * 0.7853981633974483
            segs.Push([50 + 33 * Cos(a), 50 + 33 * Sin(a), 50 + 46 * Cos(a), 50 + 46 * Sin(a)])
        }
        Traits(L, c, segs, 9, encre)
    } else if (icone = "air") {                 ; l'air : trois traits ondulés de longueurs inégales
        segs := []
        for r in [[20, 6, 70], [50, 14, 94], [80, 6, 60]]
            Loop 3
                segs.Push([r[2] + (A_Index - 1) * (r[3] - r[2]) / 3, r[1] + (Mod(A_Index, 2) ? -4 : 4),
                    r[2] + A_Index * (r[3] - r[2]) / 3, r[1] - (Mod(A_Index, 2) ? -4 : 4)])
        Traits(L, c, segs, 10, encre)
    } else if (icone = "iss") {                 ; la station : un module et deux panneaux solaires
        Traits(L, c, [[6, 50, 94, 50]], 6, encre)
        for xx in [[8, 36], [64, 92]]
            Polygone(L, c, [[xx[1], 30], [xx[2], 30], [xx[2], 70], [xx[1], 70]], encre)
        Disque(L, c, 50, 50, 13, encre)
    } else if (icone = "pluie") {               ; un nuage et trois traits de pluie
        Nuage(L, c, 30, 34, 19, [encre, encre])
        Traits(L, c, [[30, 70, 24, 92], [50, 70, 44, 92], [70, 70, 64, 92]], 9, encre)
    } else if (icone = "thermo") {              ; un thermomètre : la tige et le réservoir
        Traits(L, c, [[50, 16, 50, 62]], 20, encre)
        Disque(L, c, 50, 74, 19, encre)
    } else if (icone = "fleur") {               ; une fleur : cinq pétales autour d'un cœur
        Loop 5 {
            a := -1.5708 + (A_Index - 1) * 1.2566
            Disque(L, c, 50 + 26 * Cos(a), 50 + 26 * Sin(a), 17, encre)
        }
        Disque(L, c, 50, 50, 12, fond)
    } else {                                      ; deux vagues
        segs := []
        for yy in [38, 68]
            Loop 4
                segs.Push([4 + (A_Index - 1) * 23, yy + (Mod(A_Index, 2) ? -7 : 7), 4 + A_Index * 23, yy - (Mod(A_Index, 2) ? -7 : 7)])
        Traits(L, c, segs, 11, encre)
    }
    Poser(L, txt, P_DATE, em, x0 + pad + ic + ecart, yHaut + hp / 2 + cap / 2, 0, encre)
    Loop L.Length - n0
        L[n0 + A_Index].a := 0, L[n0 + A_Index].z := false, L[n0 + A_Index].brut := true
}

; ---------- Menu Afficher ▸ Vigilance ----------

; Ligne d'état grisée : « ↳ Val-de-Marne : aucune vigilance », « ↳ Val-de-Marne : orange orages »…
MajEtatVigilance() {
    global LibEtatVig
    if !IsObject(MenuVigilance)
        return
    etat := Donnees.Get("vig_etat", "")
    if !VigilanceW
        txt := "désactivée"
    else if (etat = "hors_zone")
        txt := "indisponible hors de France métropolitaine"
    else if (etat = "erreur")
        txt := "pas de données (réseau ?)"
    else if (etat != "ok")
        txt := "en attente de la prochaine collecte"
    else {
        v := VigilanceActive()
        txt := Donnees.Get("vig_zone", "") " : " (IsObject(v) ? SubStr(v.texte, 11)
            : !VigFraiche() ? "pas de données récentes"
            : (VigMin >= 3) ? "aucune vigilance orange ou rouge" : "aucune vigilance")
    }
    nouveau := "      ↳ " StrReplace(txt, "&", "&&")
    if (nouveau = LibEtatVig)
        return
    MenuVigilance.Rename(LibEtatVig, nouveau)
    MenuVigilance.Disable(nouveau)
    LibEtatVig := nouveau
    ReglAJour()
}

BasculerVigilance(*) {
    global VigilanceW
    VigilanceW := !VigilanceW
    ApresOptionAlerte(VigilanceW)
}

BasculerSeine(*) {
    global SeineW
    SeineW := !SeineW
    ApresOptionAlerte(SeineW)
}

; Option cochée : la collecte est lancée tout de suite (l'état arrive en quelques secondes)
ApresOptionAlerte(cochee) {
    SauverReglages()
    CocherMenus()
    if cochee {
        LancerCollecte()
        SetTimer(VerifierBientot, -6000)
    }
    Redessiner(true)
}

ChoisirVigMin(n, *) {
    global VigMin
    VigMin := n
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

OuvrirCarteVigilance(*) => Run(URL_VIGILANCE)
OuvrirMeteoAlarm(*) => Run(URL_METEOALARM)

; ---------- Menu Afficher ▸ Deuxième ville ----------

; « Ville : Pointe-à-Pitre (GP) » : le pays (ou son code) entre parenthèses
LibelleVille2() {
    if !Ville2Definie()
        return "Ville : aucune"
    p := InStr(Ville2Detail, ", ", , -1)
    pays := p ? SubStr(Ville2Detail, p + 2) : Ville2Detail
    return StrReplace("Ville : " Ville2Nom ((pays != "") ? " (" pays ")" : ""), "&", "&&")
}

MajLibV2() {
    global LibV2
    nouveau := LibelleVille2()
    if (nouveau = LibV2)
        return
    MenuVille2.Rename(LibV2, nouveau)
    MenuVille2.Disable(nouveau)
    LibV2 := nouveau
}

; Recherche par le nom, puis choix dans une liste (jamais de choix automatique :
; « pointe a pitre » sans accents ne trouve qu'un lieu-dit d'Occitanie).
; « attente » : la case à cocher une fois la ville choisie (widget, prev).
ChoisirVille2(attente := "") {
    r := InputBox("Nom de la ville (par ex. Pointe-à-Pitre, Montréal, Tokyo) :", "Deuxième ville", "w420 h130", Ville2Nom)
    nom := Trim(StrReplace(r.Value, '"'))
    if (r.Result != "OK" || nom = "")
        return
    f := DOSSIER "\recherche-ville.txt"
    try FileDelete(f)
    ToolTip("Recherche de « " nom " »…")
    try RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' SCRIPT_PS '" -ChercherVille:' ArgPS(nom), , "Hide")
    ToolTip()
    liste := ResultatsVille2(f)
    if !IsObject(liste) {
        TrayTip("Recherche impossible (réseau ?).", "Deuxième ville")
        return
    }
    if !liste.Length {
        TrayTip("Aucune ville trouvée pour « " nom " ». Essaie avec les accents, ou en anglais.", "Deuxième ville")
        return
    }
    m := Menu()
    for e in liste
        m.Add(e.lib, AppliquerVille2.Bind(e.res, attente))
    m.Add()
    m.Add("Chercher un autre nom…", EnDialogue.Bind(ChoisirVille2.Bind(attente)))   ; (devant la fenêtre Réglages)
    m.Show()
}

; Résultats de la recherche (recherche-ville.txt) : [{lib, res}], "" si la
; recherche a échoué. Libellé : « nom — détail · heure là-bas · population »,
; « & » doublés, deux libellés identiques numérotés (le menu les confondrait).
ResultatsVille2(f) {
    lignes := []
    try lignes := StrSplit(Trim(FileRead(f, "UTF-8"), "`r`n"), "`n", "`r")
    if (!lignes.Length || lignes[1] = "" || SubStr(lignes[1], 1, 6) = "ERREUR")
        return ""
    liste := [], vus := Map()
    for ligne in lignes {
        v := StrSplit(ligne, "|")
        if (v.Length < 6 || !IsNumber(v[3]) || !IsNumber(v[4]))
            continue
        res := {nom: v[1], detail: v[2], lat: v[3], lon: v[4], fuseau: v[5]}
        off := DecalageFuseau(res.fuseau, MaintenantUnix())
        lib := v[1] ((v[2] != "") ? " — " v[2] : "") ((off != "") ? " · " FormatTime(DateAdd(A_NowUTC, off, "Seconds"), "HH:mm") : "")
            . ((IsInteger(v[6]) && Integer(v[6]) > 0) ? " · " Milliers(v[6]) " hab." : "")
        lib := StrReplace(lib, "&", "&&"), base := lib, n := 1
        while vus.Has(lib) {
            n += 1
            lib := base " (" n ")"
        }
        vus[lib] := 1
        liste.Push({lib: lib, res: res})
    }
    return liste
}

; Mode de test /villes <recherche-ville.txt> <rapport> : les libellés du menu de choix
TestVilles(f, rapport) {
    liste := ResultatsVille2(f), txt := ""
    if !IsObject(liste)
        txt := "recherche en échec`n"
    else if !liste.Length
        txt := "aucune ville`n"
    else
        for e in liste
            txt .= e.lib "  →  " e.res.lat "," e.res.lon " " e.res.fuseau "`n"
    txt .= "Pointe-à-Pitre maintenant : " FormatTime(DateAdd(A_NowUTC, DecalageFuseau("America/Guadeloupe", MaintenantUnix()), "Seconds"), "HH:mm")
        . " (ici " FormatTime(, "HH:mm") "), fuseau inventé : [" DecalageFuseau("Pas/UnFuseau", MaintenantUnix()) "]`n"
    try FileDelete(rapport)
    FileAppend(txt, rapport, "UTF-8")
}

AppliquerVille2(res, attente, *) {
    global Ville2Nom, Ville2Detail, Ville2Pos, Ville2Fuseau, Ville2W, Ville2Prev
    Ville2Nom := res.nom, Ville2Detail := res.detail, Ville2Pos := res.lat "," res.lon, Ville2Fuseau := res.fuseau
    for cle in ["nom", "detail", "lat", "lon", "fuseau"]
        IniWrite(res.%cle%, F_REGLAGES, "ville2", cle)
    if (attente = "prev")                         ; action explicite : la case suit
        Ville2Prev := true
    else if (attente = "widget" || (!Ville2W && !Ville2Prev))
        Ville2W := true
    SauverReglages()
    CocherMenus()
    Journal("deuxième ville : " Ville2Nom " (" Ville2Detail ", " Ville2Pos ", " Ville2Fuseau ")")
    LancerCollecte()
    SetTimer(VerifierBientot, -6000)
    Redessiner(true)
}

BasculerVille2(quoi, *) {
    global Ville2W, Ville2Prev
    if !Ville2Definie() {                         ; pas encore de ville : on la choisit d'abord
        ChoisirVille2(quoi)
        return
    }
    if (quoi = "widget")
        Ville2W := !Ville2W
    else
        Ville2Prev := !Ville2Prev
    SauverReglages()
    CocherMenus()
    if ((Ville2W || Ville2Prev) && Donnees.Get("v2_pos", "") != Ville2Pos) {   ; pas encore de météo pour elle
        LancerCollecte()
        SetTimer(VerifierBientot, -6000)
    }
    Redessiner(true)
}

OublierVille2(*) {
    global Ville2Nom, Ville2Detail, Ville2Pos, Ville2Fuseau, Ville2W, Ville2Prev
    try IniDelete(F_REGLAGES, "ville2")
    Ville2Nom := "", Ville2Detail := "", Ville2Pos := "", Ville2Fuseau := "", Ville2W := false, Ville2Prev := false
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

; Auto-test de la pluie dans l'heure (séries fictives autour de maintenant)
TestPluie(fichier) {
    global Donnees, PluieW
    rapport := "", echecs := 0
    Verifier(ok, msg) {
        rapport .= (ok ? "  ok    " : "  ÉCHEC ") msg "`n"
        echecs += !ok
    }
    PluieW := true
    maint := MomentUnix(), t0 := maint - Mod(maint, 900) + 900   ; fin du quart d'heure en cours
    Serie(vals) {
        Donnees["pluie15"] := t0 "|" vals, Donnees["maj"] := maint, Donnees["temp"] := 12
        return PastillePluie()
    }
    Verifier(!IsObject(Serie("0,0,0,0,0,0,0,0")), "pas de pluie : pas de pastille")
    p := Serie("0,0,0.3,0.4,0,0,0,0")             ; pluie de t0+15 min à t0+45 min
    n := Max(5, Round((t0 + 900 - maint) / 300) * 5)
    Verifier(IsObject(p) && p.textes[2] = "Pluie faible dans " n Chr(0xA0) "min" && InStr(p.textes[1], "jusqu'à " HeureCourte(t0 + 2700)),
        "averse à venir : « " (IsObject(p) ? p.textes[1] : "rien") " »")
    p := Serie("0.6,0.8,0.2,0,0,0,0,0")
    Verifier(IsObject(p) && p.textes[1] = "Pluie jusqu'à " HeureCourte(t0 + 1800), "il pleut : « " (IsObject(p) ? p.textes[1] : "rien") " »")
    p := Serie("0,3,2,0,0,0,0,0")
    Verifier(IsObject(p) && SubStr(p.textes[1], 1, 11) = "Forte pluie", "forte pluie : « " (IsObject(p) ? p.textes[1] : "rien") " »")
    Verifier(!IsObject(Serie("0,0,0,0,0,0.5,0.5,0")), "averse dans plus d'une heure : rien encore")
    p := Serie("0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5")
    Verifier(IsObject(p) && InStr(p.textes[1], "pour un moment"), "pluie jusqu'au bout de la prévision : « " (IsObject(p) ? p.textes[1] : "rien") " »")
    ; le résumé : sa variante « journée » quand la pastille donne déjà l'heure de la pluie (pas deux heures qui se contredisent)
    Donnees["resume"] := "Fin de la pluie vers 12 h.", Donnees["maximum"] := "Maximum 24°"
    Donnees["resume_jour"] := "Averses éparses probables ce matin.", Donnees["maximum_jour"] := "Maximum 24°"
    Serie("0.6,0.8,0.2,0,0,0,0,0"), i := InfosAffichage()
    Verifier(i.texte = Donnees["resume_jour"], "pastille affichée : le résumé de la journée (« " i.texte " »)")
    Serie("0,0,0,0,0,0,0,0"), i := InfosAffichage()
    Verifier(i.texte = Donnees["resume"], "sans pastille : le résumé habituel (« " i.texte " »)")
    Donnees["pluie15"] := t0 "|0,0.5,0.5,0", Donnees["maj"] := maint - 3600
    Verifier(!IsObject(PastillePluie()), "prévision de plus de 45 min : ignorée")
    PluieW := false, Donnees["maj"] := maint
    Verifier(!IsObject(PastillePluie()), "option coupée : rien")
    FileAppend((echecs ? echecs " échec(s)" : "tout est bon") "`n" rapport, fichier, "UTF-8")
}
