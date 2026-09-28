# Collecte des marchés, des actus et des phrases d'anglais pour widget-meteo.ahk
# (lancée toutes les 5 min par le widget, seulement si une de ces options sert).
#
# Écrit dans %LOCALAPPDATA%\WidgetMeteo\ (UTF-8, une ligne par élément, champs séparés par « | ») :
#   marches.txt  C|id|nom|symbole|prix €|var. 24 h %|var. 7 j %|récolte|courbe 7 j (€, horaire)
#                S|id|1d|récolte|instants|valeurs      (courbe 24 h en €, cryptos affichées sur le widget)
#                Y|symbole|dernier|clôture précédente|instant du dernier cours|récolte|instants|valeurs (séance)
#                T|code|valeur %|précédente %|date|j ou m|récolte   (taux de la BCE : quotidien ou moyenne du mois)
#   actus.txt    A|flux|instant|titre|lien|résumé|image   (flux : une, fil, monde, f24 ; dans l'ordre des journaux)
#   anglais-tatoeba.txt   maj=… puis français|anglais (un lot de phrases renouvelé chaque jour)
#   historique.txt        cle=… maj=… t=… v=… (une courbe demandée par le tableau de bord)
#   rer.txt               prochains départs et info trafic de la gare choisie (-Rer, -RerInfo)
#
# Sources gratuites et sans clé : CoinGecko (cryptos, en euros), Yahoo Finance
# (bourses et taux US, API non officielle), BCE (taux européens), flux RSS du
# Monde, de franceinfo et de France 24, Tatoeba (phrases, licence CC BY 2.0 FR).
# Une source injoignable garde ses dernières lignes (avec leur heure de récolte) :
# le widget montre la dernière valeur connue et son âge.

param([string]$Cryptos = '', [string]$Symboles = '', [string]$Taux = '', [switch]$Actus, [switch]$Tatoeba,
      [string]$Historique = '', [switch]$Rer, [switch]$RerInfo, [ValidatePattern('^\d*$')][string]$RerArret = '',
      [ValidatePattern('^(C\d+)?$')][string]$RerLigne = '', [string]$EssaiRer = '', [string]$ChercherArret = '',
      [string]$Image = '', [string]$Fichier = '', [string]$Article = '')

$ErrorActionPreference = 'Stop'
$inv = [cultureinfo]::InvariantCulture
$dossier = Join-Path $env:LOCALAPPDATA 'WidgetMeteo'
$fMarches = Join-Path $dossier 'marches.txt'
$fActus = Join-Path $dossier 'actus.txt'
$fTatoeba = Join-Path $dossier 'anglais-tatoeba.txt'
$fHisto = Join-Path $dossier 'historique.txt'
if (-not (Test-Path $dossier)) { New-Item -ItemType Directory -Force $dossier | Out-Null }

function Maintenant() { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

# Texte d'une adresse, décodé en UTF-8 (Invoke-RestMethod de PowerShell 5 se
# trompe d'encodage sur les flux RSS qui ne l'annoncent pas)
function Get-Texte([string]$url, [int]$delai = 15) {
    $req = [Net.HttpWebRequest]::Create($url)
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WidgetMeteo'
    $req.Timeout = $delai * 1000
    $req.ReadWriteTimeout = $delai * 1000
    $req.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
    $rep = $req.GetResponse()
    try {
        $sr = New-Object IO.StreamReader($rep.GetResponseStream(), [Text.Encoding]::UTF8)
        return $sr.ReadToEnd()
    } finally { $rep.Close() }
}

function Nb($v) { ([double]$v).ToString('G7', $inv) }

# Une série réduite à « max » points au plus (le dernier est toujours gardé)
function Reduire($t, $v, [int]$max) {
    $n = $t.Count
    if ($n -le $max) { return @{ t = $t; v = $v } }
    $pas = [Math]::Ceiling($n / $max)
    $rt = New-Object Collections.Generic.List[object]; $rv = New-Object Collections.Generic.List[object]
    for ($i = 0; $i -lt $n; $i += $pas) { $rt.Add($t[$i]); $rv.Add($v[$i]) }
    if ($rt[$rt.Count - 1] -ne $t[$n - 1]) { $rt.Add($t[$n - 1]); $rv.Add($v[$n - 1]) }
    return @{ t = $rt; v = $rv }
}

function Lignes-Existantes([string]$chemin) {
    if (Test-Path $chemin) { return @([IO.File]::ReadAllLines($chemin, [Text.Encoding]::UTF8)) }
    return @()
}

function Ecrire-Lignes([string]$chemin, $lignes) {
    $tmp = "$chemin.tmp"                                  # écriture atomique : jamais lu à moitié écrit
    [IO.File]::WriteAllLines($tmp, [string[]]$lignes, (New-Object Text.UTF8Encoding $false))
    Move-Item $tmp $chemin -Force
}

# Titre propre pour le widget : entités HTML décodées, sans émojis (le dessin
# ne sait pas les afficher), sans « | » ni retours à la ligne
function Titre-Propre([string]$t) {
    $t = [Net.WebUtility]::HtmlDecode($t)
    $t = [regex]::Replace($t, '[\uD800-\uDFFF️‍⭐⭕▶◀✅❌❗]', '')
    $t = ($t -replace '[\r\n\t|]+', ' ' -replace '\s{2,}', ' ').Trim()
    return $t
}

# « Sun, 27 Sep 2026 11:09:51 +0200 » ou « … GMT » : instant Unix (0 si illisible)
function Unix-Rss([string]$s) {
    $m = [regex]::Match($s, '(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ?([+-]\d{4}|GMT|UTC|UT|Z)?')
    if (-not $m.Success) { return 0 }
    $mois = @{Jan=1;Feb=2;Mar=3;Apr=4;May=5;Jun=6;Jul=7;Aug=8;Sep=9;Oct=10;Nov=11;Dec=12}
    if (-not $mois.ContainsKey($m.Groups[2].Value)) { return 0 }
    $off = [TimeSpan]::Zero
    $z = $m.Groups[7].Value
    if ($z -match '^([+-])(\d{2})(\d{2})$') {
        $off = New-Object TimeSpan([int]$Matches[2], [int]$Matches[3], 0)
        if ($Matches[1] -eq '-') { $off = $off.Negate() }
    }
    $d = New-Object DateTimeOffset([int]$m.Groups[3].Value, $mois[$m.Groups[2].Value], [int]$m.Groups[1].Value,
        [int]$m.Groups[4].Value, [int]$m.Groups[5].Value, [int]$m.Groups[6].Value, $off)
    return $d.ToUnixTimeSeconds()
}

$erreurs = @()

# ---------- Prochains départs d'une gare ou d'un arrêt (Île-de-France Mobilités, PRIM) ----------
# Prochains départs de la ligne choisie à la zone d'arrêt choisie (-Rer -RerArret
# 45102 -RerLigne C01742 : tous ses quais, les deux sens) et messages d'info trafic
# de la ligne (-RerInfo), avec le jeton de l'utilisateur (cle-idfm.txt, jamais dans
# le dépôt). Quotas d'un nouveau compte : 1 000 requêtes par jour et par API. rer.txt :
#   cfg=zone d'arrêt|ligne (les départs d'une autre gare ne sont jamais montrés)
#   maj_d / etat_d, puis D|départ prévu|départ théorique|statut|destination|nom du sens|sens (Aller, Retour…)   (instants Unix)
#   maj_m / etat_m, puis M|début|fin|canal|texte court|texte long
# etat : ok, cle (jeton refusé), quota (trop de requêtes), erreur (réseau…), absent (pas de jeton)
if (($Rer -or $RerInfo) -and ($RerArret -eq '' -or $RerLigne -eq '')) { exit 0 }   # (pas de gare choisie)
if ($Rer -or $RerInfo) {
    $fRer = Join-Path $dossier 'rer.txt'
    $fCle = Join-Path $dossier 'cle-idfm.txt'
    $cle = if (Test-Path $fCle) { ([IO.File]::ReadAllText($fCle)).Trim() } else { '' }
    $cfg = "$RerArret|$RerLigne"
    $garde = @{ d = @(); m = @(); maj_d = ''; etat_d = ''; maj_m = ''; etat_m = ''; cfg = '' }
    foreach ($l in (Lignes-Existantes $fRer)) {
        if ($l -match '^(cfg|maj_d|etat_d|maj_m|etat_m)=(.*)$') { $garde[$Matches[1]] = $Matches[2] }
        elseif ($l.StartsWith('D|')) { $garde.d += $l } elseif ($l.StartsWith('M|')) { $garde.m += $l }
    }
    if ($garde.cfg -ne $cfg) { $garde = @{ d = @(); m = @(); maj_d = ''; etat_d = ''; maj_m = ''; etat_m = '' } }   # (autre gare : on repart de zéro)
    function Unix-Iso($v) {
        if (-not $v) { return 0 }
        try { return [DateTimeOffset]::Parse([string]$v, $inv).ToUnixTimeSeconds() } catch { return 0 }
    }
    function Valeur($x) {                                  # SIRI Lite : {value: …} ou [{value: …}] ou texte
        if ($null -eq $x) { return '' }
        $x = @($x)[0]
        if ($null -eq $x) { return '' }                    # (liste vide : « DirectionName: [] »)
        if ($x -is [string]) { return $x }
        if ($x.PSObject.Properties['value']) { return [string]$x.value }
        return [string]$x
    }
    function Get-Idfm([string]$url) {
        if ($EssaiRer -ne '') {                            # tests : réponses enregistrées, sans réseau ni quota
            $f = if ($url -match 'stop-monitoring') { 'passages.json' } else { 'messages.json' }
            return [IO.File]::ReadAllText((Join-Path $EssaiRer $f), [Text.Encoding]::UTF8)
        }
        $req = [Net.HttpWebRequest]::Create($url)
        $req.Headers.Add('apikey', $cle)
        $req.Accept = 'application/json'
        $req.Timeout = 15000; $req.ReadWriteTimeout = 15000
        $req.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
        try { $rep = $req.GetResponse() }
        catch [Net.WebException] {
            $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            throw "http $code"
        }
        try { return (New-Object IO.StreamReader($rep.GetResponseStream(), [Text.Encoding]::UTF8)).ReadToEnd() } finally { $rep.Close() }
    }
    function Etat-Erreur([string]$m) { if ($m -match 'http (401|403)') { 'cle' } elseif ($m -match 'http 429') { 'quota' } else { 'erreur' } }
    if ($Rer) {
        if ($cle -eq '') { $garde.etat_d = 'absent' } else {
            try {
                $txt = Get-Idfm "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopArea:SP:$($RerArret):"
                [IO.File]::WriteAllText((Join-Path $dossier 'rer-passages.json'), $txt, (New-Object Text.UTF8Encoding $false))
                $r = ConvertFrom-Json $txt
                $d = @()
                foreach ($liv in @($r.Siri.ServiceDelivery.StopMonitoringDelivery)) {
                    foreach ($v in @($liv.MonitoredStopVisit)) {
                        $j = $v.MonitoredVehicleJourney
                        if ((Valeur $j.LineRef) -notmatch ":$($RerLigne):") { continue }   # (les autres lignes de l'arrêt)
                        $c = $j.MonitoredCall
                        $prevu = Unix-Iso $c.ExpectedDepartureTime; $theo = Unix-Iso $c.AimedDepartureTime
                        if (-not $prevu) { $prevu = $theo }
                        if (-not $prevu) { continue }
                        $dest = Valeur $j.DestinationName
                        if ($dest -eq '') { $dest = Valeur $c.DestinationDisplay }
                        $d += "D|$prevu|$theo|$(Valeur $c.DepartureStatus)|$(Titre-Propre $dest)|$(Titre-Propre (Valeur $j.DirectionName))|$(Valeur $j.DirectionRef)"
                    }
                }
                $garde.d = $d; $garde.etat_d = 'ok'; $garde.maj_d = [string](Maintenant)
            } catch { $garde.etat_d = Etat-Erreur $_.Exception.Message }
        }
    }
    if ($RerInfo) {
        if ($cle -eq '') { $garde.etat_m = 'absent' } else {
            try {
                $txt = Get-Idfm "https://prim.iledefrance-mobilites.fr/marketplace/general-message?LineRef=STIF:Line::$($RerLigne):"
                [IO.File]::WriteAllText((Join-Path $dossier 'rer-messages.json'), $txt, (New-Object Text.UTF8Encoding $false))
                $r = ConvertFrom-Json $txt
                $m = @()
                foreach ($liv in @($r.Siri.ServiceDelivery.GeneralMessageDelivery)) {
                    foreach ($im in @($liv.InfoMessage)) {
                        $textes = @()
                        foreach ($msg in @($im.Content.Message)) { $t = Titre-Propre (Valeur $msg.MessageText); if ($t -ne '') { $textes += $t } }
                        if (-not $textes.Count) { continue }
                        $texte = ($textes | Sort-Object Length | Select-Object -First 1)   # le plus court (le message « court »)
                        $long = ($textes | Sort-Object Length | Select-Object -Last 1)     # le plus complet (la fiche du RER)
                        $m += "M|$(Unix-Iso $im.RecordedAtTime)|$(Unix-Iso $im.ValidUntilTime)|$(Valeur $im.InfoChannelRef)|$texte|$long"
                    }
                }
                $garde.m = $m; $garde.etat_m = 'ok'; $garde.maj_m = [string](Maintenant)
            } catch { $garde.etat_m = Etat-Erreur $_.Exception.Message }
        }
    }
    $sortie = @("cfg=$cfg", "maj_d=$($garde.maj_d)", "etat_d=$($garde.etat_d)") + $garde.d + @("maj_m=$($garde.maj_m)", "etat_m=$($garde.etat_m)") + $garde.m
    Ecrire-Lignes $fRer $sortie
    exit 0
}

# ---------- Recherche d'une gare ou d'un arrêt par son nom (-ChercherArret texte -Fichier chemin) ----------
# Open data d'Île-de-France Mobilités, sans clé : « arrets-lignes » (les arrêts et
# les lignes qui les desservent), « arrets » (la zone d'arrêt de chaque quai) et
# « referentiel-des-lignes » (nom, réseau, couleurs officielles). Écrit etat=ok,
# vide ou erreur, puis une ligne par arrêt et par ligne, trains d'abord :
#   R|zone d'arrêt|nom de l'arrêt|commune|ligne|nom de la ligne|mode|couleur|couleur du texte
# (la zone d'arrêt donne les prochains passages de tous ses quais, dans les deux sens)
if ($ChercherArret -ne '' -and $Fichier -ne '') {
    $od = 'https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets'
    function Od-Get([string]$jeu, [string]$where) {
        return ConvertFrom-Json (Get-Texte "$od/$jeu/records?where=$([Uri]::EscapeDataString($where))&limit=100" 20)
    }
    function Liste-In($ids) { return '(' + (($ids | ForEach-Object { '"' + $_ + '"' }) -join ',') + ')' }
    $etat = 'erreur'; $res = @()
    try {
        $q = ($ChercherArret -replace '["\\]', ' ').Trim()
        $rangs = @((Od-Get 'arrets-lignes' "search(stop_name, `"$q`")").results)
        $quais = @($rangs | ForEach-Object { if ([string]$_.stop_id -match '^IDFM:(\d+)$') { $Matches[1] } } | Select-Object -Unique)
        $zda = @{}
        if ($quais.Count) { foreach ($a in @((Od-Get 'arrets' "arrid in $(Liste-In $quais)").results)) { $zda[[string]$a.arrid] = [string]$a.zdaid } }
        $ids = @($rangs | ForEach-Object { ([string]$_.id) -replace '^IDFM:', '' } | Where-Object { $_ -match '^C\d+$' } | Select-Object -Unique)
        $ref = @{}
        if ($ids.Count) { foreach ($l in @((Od-Get 'referentiel-des-lignes' "id_line in $(Liste-In $ids)").results)) { $ref[[string]$l.id_line] = $l } }
        $vus = @{}; $liste = @()
        foreach ($r in $rangs) {
            $sid = [string]$r.stop_id; $idl = ([string]$r.id) -replace '^IDFM:', ''
            # zone d'arrêt : directe (« monomodalStopPlace:45102 ») ou par le quai (« IDFM:463030 »)
            $z = if ($sid -match 'monomodalStopPlace:(\d+)$') { $Matches[1] } elseif ($sid -match '^IDFM:(\d+)$' -and $zda.ContainsKey($Matches[1])) { $zda[$Matches[1]] } else { '' }
            if ($z -eq '' -or $idl -notmatch '^C\d+$' -or $vus.ContainsKey("$z|$idl")) { continue }
            $vus["$z|$idl"] = 1
            $l = $ref[$idl]
            $mode = if ($l) { [string]$l.transportmode } else { ([string]$r.mode).ToLower() }
            $court = if ($l -and $l.shortname_line) { [string]$l.shortname_line } else { [string]$r.shortname }
            $reseau = if ($l) { [string]$l.networkname } else { '' }
            $nom = switch -regex ($mode) {
                '^rail'     { if ($reseau -eq 'RER') { "RER $court" } elseif ($reseau -eq 'Transilien') { "Ligne $court" } else { $court } }
                '^metro'    { "Métro $court" }
                '^bus'      { "Bus $court" }
                '^cableway' { "Câble $court" }
                default     { $court }
            }
            $rang = switch -regex ($mode) { '^rail' { if ($reseau -eq 'RER') { 0 } elseif ($reseau -eq 'Transilien') { 1 } else { 2 } } '^metro' { 3 } '^tram' { 4 } '^bus' { 6 } default { 5 } }
            $couleur = if ($l -and [string]$l.colourweb_hexa -match '^[0-9a-fA-F]{6}$') { ([string]$l.colourweb_hexa).ToLower() } else { '8e8e93' }
            $encre = if ($l -and [string]$l.textcolourweb_hexa -match '^[0-9a-fA-F]{6}$') { ([string]$l.textcolourweb_hexa).ToLower() } else { 'ffffff' }
            $num = if ($court -match '\d+') { [int]$Matches[0] } else { 0 }
            $liste += [pscustomobject]@{ rang = $rang; arret = (Titre-Propre ([string]$r.stop_name)); num = $num
                ligne = "R|$z|$(Titre-Propre ([string]$r.stop_name))|$(Titre-Propre ([string]$r.nom_commune))|$idl|$(Titre-Propre $nom)|$mode|$couleur|$encre" }
        }
        $res = @($liste | Sort-Object rang, arret, num | ForEach-Object { $_.ligne })
        $etat = if ($res.Count) { 'ok' } else { 'vide' }
    } catch { $etat = 'erreur' }
    Ecrire-Lignes $Fichier (@("etat=$etat") + $res)
    exit 0
}

# Paragraphes collés d'un articleBody recoupés : « communiqué.La », « l'Essonne."J'ai »
# (guillemet ouvrant), « ma vie"Dans » (guillemet fermant). Les guillemets droits
# s'ouvrent et se ferment à tour de rôle : on suit lequel on rencontre.
function Paragraphes([string]$t) {
    $sb = New-Object Text.StringBuilder
    $ouvert = $false
    $fins = '.!?…'
    for ($i = 0; $i -lt $t.Length; $i++) {
        $c = $t[$i]
        $p = if ($i -gt 0) { $t[$i - 1] } else { ' ' }
        $n = if ($i + 1 -lt $t.Length) { $t[$i + 1] } else { ' ' }
        if ($c -eq '"') {
            if (-not $ouvert -and $fins.Contains($p) -and [char]::IsUpper($n)) { [void]$sb.Append("`n") }
            [void]$sb.Append($c)
            $ouvert = -not $ouvert
            if (-not $ouvert -and [char]::IsUpper($n) -and ([char]::IsLetterOrDigit($p) -or $fins.Contains($p))) { [void]$sb.Append("`n") }
            continue
        }
        if (([char]::IsUpper($c) -or $c -eq '«') -and $fins.Contains($p) -and $i -ge 2 -and ([char]::IsLetterOrDigit($t[$i - 2]) -or $t[$i - 2] -eq ')')) {
            [void]$sb.Append("`n")
        } elseif ([char]::IsUpper($c) -and [char]::IsLower($p)) {
            # intertitre sans ponctuation collé au paragraphe (« depuis fin févrierCes écarts ») :
            # seulement après un bout court et sans ponctuation (pas « YouTube » en pleine phrase)
            $cour = $sb.ToString(); $k = $cour.LastIndexOf("`n"); $bout = $cour.Substring($k + 1)
            if ($bout.Length -le 90 -and $bout -notmatch '[.!?…:;,"«»]') { [void]$sb.Append("`n") }
        }
        [void]$sb.Append($c)
    }
    return $sb.ToString()
}

# ---------- Texte complet d'un article pour sa fiche (-Article url -Fichier chemin) ----------
# Le texte est pris dans les données structurées de la page (JSON-LD « articleBody ») :
# franceinfo les publie ; Le Monde et France 24 protègent leurs pages contre les
# lectures automatiques (page de protection) : « sans_texte », la fiche garde le chapeau du flux.
# Les paragraphes y sont collés (« communiqué.La plaignante ») : recoupés à la majuscule.
if ($Article -ne '') {
    $etat = 'erreur'; $texte = ''
    if ($Article -match '^https://[^\s|"]+$' -and $Fichier -ne '') {
        try {
            $html = Get-Texte $Article 20
            foreach ($m in [regex]::Matches($html, '<script[^>]*application/ld\+json[^>]*>(.*?)</script>', 'Singleline')) {
                try { $j = ConvertFrom-Json $m.Groups[1].Value } catch { continue }
                $objs = @($j)
                foreach ($o in @($j)) { if ($o.PSObject.Properties['@graph']) { $objs += @($o.'@graph') } }
                foreach ($o in $objs) { if ($o -and $o.PSObject.Properties['articleBody'] -and $o.articleBody) { $texte = [string]$o.articleBody; break } }
                if ($texte) { break }
            }
            $etat = if ($texte) { 'ok' } else { 'sans_texte' }
        } catch { $etat = 'erreur' }
        # (entités parfois encodées deux ou trois fois : « &amp;amp;lt;img … » pour les graphiques intégrés)
        for ($k = 0; $k -lt 4 -and $texte -match '&(amp|lt|gt|quot|#\d+|#x[0-9a-f]+);'; $k++) { $texte = [Net.WebUtility]::HtmlDecode($texte) }
        $texte = [regex]::Replace($texte, '<(img|iframe)\b[^>]*>', {
            param($m)
            if ($m.Value -notmatch 'visuali[sz]ation|flourish|datawrapper') { return ' ' }
            if ($m.Value -match 'alt="[^"]*map') { "`n[Carte interactive à voir sur le site]`n" } else { "`n[Graphique interactif à voir sur le site]`n" }
        }, 'IgnoreCase')
        $texte = $texte -replace '<[^>]+>', ' ' -replace '[\r\t|]+', ' '   # (avant les paragraphes : les guillemets des balises fausseraient leur suivi)
        $texte = Paragraphes $texte
        $paras = @($texte -split "`n" | ForEach-Object { ($_ -replace '\s{2,}', ' ').Trim() } | Where-Object { $_ -ne '' })
        Ecrire-Lignes $Fichier (@("url=$Article", "etat=$etat") + $paras)
        # le cache des articles : rien de plus de 2 jours
        Get-ChildItem (Split-Path $Fichier) -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-2) } | Remove-Item -ErrorAction SilentlyContinue
    }
    exit 0
}

# ---------- Photo d'un article pour sa fiche (-Image url -Fichier chemin) ----------
if ($Image -ne '') {
    if ($Image -match '^https://[^\s|"]+$' -and $Fichier -ne '') {
        try {
            $req = [Net.HttpWebRequest]::Create($Image)
            $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WidgetMeteo'
            $req.Timeout = 15000; $req.ReadWriteTimeout = 15000
            $rep = $req.GetResponse()
            try {
                $tmp = "$Fichier.tmp"
                $fs = [IO.File]::Create($tmp)
                try { $rep.GetResponseStream().CopyTo($fs) } finally { $fs.Close() }
                Move-Item $tmp $Fichier -Force
            } finally { $rep.Close() }
        } catch {}
        # le cache des photos : rien de plus de 2 jours
        Get-ChildItem (Split-Path $Fichier) -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-2) } | Remove-Item -ErrorAction SilentlyContinue
    }
    exit 0
}

# ---------- Historique demandé par le tableau de bord (et rien d'autre) ----------
# « c:bitcoin:30 » (crypto, jours), « y:^FCHI:1mo » (Yahoo, période), « t:fr10:0 » (taux BCE)
if ($Historique -ne '') {
    $p = $Historique.Split(':')
    $t = @(); $v = @(); $ok = $true
    try {
        if ($p[0] -eq 'c') {
            $r = ConvertFrom-Json (Get-Texte "https://api.coingecko.com/api/v3/coins/$($p[1])/market_chart?vs_currency=eur&days=$($p[2])" 20)
            foreach ($pt in $r.prices) { $t += [long]([double]$pt[0] / 1000); $v += [double]$pt[1] }
        } elseif ($p[0] -eq 'y') {
            $int = @{ '1d' = '5m'; '5d' = '30m'; '1mo' = '60m'; '1y' = '1d'; '5y' = '1wk' }[$p[2]]
            $r = ConvertFrom-Json (Get-Texte ("https://query1.finance.yahoo.com/v8/finance/chart/" + [uri]::EscapeDataString($p[1]) + "?range=$($p[2])&interval=$int") 20)
            $res = $r.chart.result[0]
            $cl = $res.indicators.quote[0].close
            for ($i = 0; $i -lt $res.timestamp.Count; $i++) {
                if ($null -ne $cl[$i]) { $t += [long]$res.timestamp[$i]; $v += [double]$cl[$i] }
            }
        } elseif ($p[0] -eq 't') {
            $serie = @{ zone10 = 'YC/B.U2.EUR.4F.G_N_A.SV_C_YM.SR_10Y?lastNObservations=260';
                        fr10 = 'IRS/M.FR.L.L40.CI.0000.EUR.N.Z?lastNObservations=60';
                        de10 = 'IRS/M.DE.L.L40.CI.0000.EUR.N.Z?lastNObservations=60';
                        it10 = 'IRS/M.IT.L.L40.CI.0000.EUR.N.Z?lastNObservations=60' }[$p[1]]
            $csv = ConvertFrom-Csv (Get-Texte "https://data-api.ecb.europa.eu/service/data/$serie&format=csvdata" 20)
            foreach ($l in ($csv | Sort-Object TIME_PERIOD)) {
                $d = $l.TIME_PERIOD
                if ($d.Length -eq 7) { $d += '-15' }       # mois : milieu du mois
                $t += [DateTimeOffset]::Parse($d + 'T12:00:00Z', $inv).ToUnixTimeSeconds(); $v += [double]$l.OBS_VALUE
            }
        }
    } catch { $ok = $false }
    if ($ok -and $t.Count -ge 2) {
        $s = Reduire $t $v 400
        Ecrire-Lignes $fHisto @("cle=$Historique", "maj=$(Maintenant)", "t=$(($s.t | ForEach-Object { $_ }) -join ',')",
            "v=$(($s.v | ForEach-Object { Nb $_ }) -join ',')")
    } else {
        Ecrire-Lignes $fHisto @("cle=$Historique", "maj=$(Maintenant)", "erreur=1")
    }
    exit 0
}

# ---------- Marchés ----------
$ancien = Lignes-Existantes $fMarches
$garde = @{}                                               # dernières lignes connues, par « type|id »
foreach ($l in $ancien) {
    $c = $l.Split('|')
    if ($c.Count -ge 3) { $garde["$($c[0])|$($c[1])"] = $l }
}
$sortie = New-Object Collections.Generic.List[string]
$nouv = @{}

$ids = @($Cryptos.Split(',') | Where-Object { $_ -match '^[a-z0-9-]+$' })
if ($ids.Count) {
    try {
        $r = ConvertFrom-Json (Get-Texte ("https://api.coingecko.com/api/v3/coins/markets?vs_currency=eur&ids=" + ($ids -join ',') +
            "&sparkline=true&price_change_percentage=24h,7d"))
        $now = Maintenant
        foreach ($c in $r) {
            # la courbe 7 j de CoinGecko est en dollars : ramenée à l'euro par le rapport des derniers prix
            $sp = @($c.sparkline_in_7d.price | Where-Object { $null -ne $_ })
            $k = if ($sp.Count -and [double]$sp[-1] -gt 0) { [double]$c.current_price / [double]$sp[-1] } else { 1 }
            $courbe = ($sp | ForEach-Object { Nb ([double]$_ * $k) }) -join ','
            $nouv["C|$($c.id)"] = "C|$($c.id)|$(Titre-Propre $c.name)|$(([string]$c.symbol).ToUpper())|$(Nb $c.current_price)|" +
                "$(Nb $c.price_change_percentage_24h_in_currency)|$(Nb $c.price_change_percentage_7d_in_currency)|$now|$courbe"
        }
    } catch { $erreurs += 'cryptos' }
    # la courbe 24 h en euros du premier (le Bitcoin, sur le widget) : points toutes les 15 min
    try {
        $r = ConvertFrom-Json (Get-Texte "https://api.coingecko.com/api/v3/coins/$($ids[0])/market_chart?vs_currency=eur&days=1")
        $t = @(); $v = @()
        foreach ($pt in $r.prices) { $t += [long]([double]$pt[0] / 1000); $v += [double]$pt[1] }
        if ($t.Count -ge 2) {
            $s = Reduire $t $v 100
            $nouv["S|$($ids[0])"] = "S|$($ids[0])|1d|$(Maintenant)|$(($s.t | ForEach-Object { $_ }) -join ',')|$(($s.v | ForEach-Object { Nb $_ }) -join ',')"
        }
    } catch { $erreurs += 'courbe' }
}

$syms = @($Symboles.Split(',') | Where-Object { $_ -match '^[\^A-Za-z0-9.=-]+$' })
for ($i = 0; $i -lt $syms.Count; $i += 20) {             # 20 symboles par requête
    $lot = $syms[$i..([Math]::Min($i + 19, $syms.Count - 1))]
    try {
        $r = ConvertFrom-Json (Get-Texte ("https://query1.finance.yahoo.com/v8/finance/spark?symbols=" +
            (($lot | ForEach-Object { [uri]::EscapeDataString($_) }) -join ',') + "&range=1d&interval=15m"))
        $now = Maintenant
        foreach ($s in $lot) {
            $d = $r.PSObject.Properties[$s]
            if ($null -eq $d) { continue }
            $d = $d.Value
            $t = @(); $v = @()
            for ($j = 0; $j -lt $d.timestamp.Count; $j++) {
                if ($null -ne $d.close[$j]) { $t += [long]$d.timestamp[$j]; $v += [double]$d.close[$j] }
            }
            if (-not $v.Count) { continue }
            $prec = if ($null -ne $d.chartPreviousClose) { $d.chartPreviousClose } else { $d.previousClose }
            $nouv["Y|$s"] = "Y|$s|$(Nb $v[-1])|$(Nb $prec)|$($t[-1])|$now|$($t -join ',')|$(($v | ForEach-Object { Nb $_ }) -join ',')"
        }
    } catch { $erreurs += 'bourse' }
}

# Taux européens de la BCE : quotidien (zone euro) ou moyenne du mois (pays) ; ils
# ne changent qu'une fois par jour ou par mois : redemandés au plus toutes les 6 h
$series = @{ zone10 = @('YC/B.U2.EUR.4F.G_N_A.SV_C_YM.SR_10Y', 'j'); fr10 = @('IRS/M.FR.L.L40.CI.0000.EUR.N.Z', 'm');
             de10 = @('IRS/M.DE.L.L40.CI.0000.EUR.N.Z', 'm'); it10 = @('IRS/M.IT.L.L40.CI.0000.EUR.N.Z', 'm') }
foreach ($code in @($Taux.Split(',') | Where-Object { $series.ContainsKey($_) })) {
    $vieux = $garde["T|$code"]
    if ($vieux) {
        $age = (Maintenant) - [long]($vieux.Split('|')[6])
        if ($age -lt 6 * 3600) { $nouv["T|$code"] = $vieux; continue }
    }
    try {
        $csv = @(ConvertFrom-Csv (Get-Texte "https://data-api.ecb.europa.eu/service/data/$($series[$code][0])?lastNObservations=2&format=csvdata") |
            Sort-Object TIME_PERIOD)
        if ($csv.Count) {
            $der = $csv[-1]
            $prec = if ($csv.Count -ge 2) { $csv[-2].OBS_VALUE } else { $der.OBS_VALUE }
            $nouv["T|$code"] = "T|$code|$(Nb $der.OBS_VALUE)|$(Nb $prec)|$($der.TIME_PERIOD)|$($series[$code][1])|$(Maintenant)"
        }
    } catch { $erreurs += "taux:$code" }
}

# Ce qui est demandé seulement : nouvelle ligne, sinon la dernière connue
$demandes = @()
foreach ($id in $ids) { $demandes += "C|$id" }
if ($ids.Count) { $demandes += "S|$($ids[0])" }
foreach ($s in $syms) { $demandes += "Y|$s" }
foreach ($code in @($Taux.Split(',') | Where-Object { $series.ContainsKey($_) })) { $demandes += "T|$code" }
$sortie.Add("maj=$(Maintenant)")
$sortie.Add("erreurs=$($erreurs -join ',')")
foreach ($k in $demandes) {
    if ($nouv.ContainsKey($k)) { $sortie.Add($nouv[$k]) } elseif ($garde.ContainsKey($k)) { $sortie.Add($garde[$k]) }
}
if ($demandes.Count) { Ecrire-Lignes $fMarches $sortie }

# ---------- Actus ----------
if ($Actus) {
    $flux = [ordered]@{ une = 'https://www.lemonde.fr/rss/une.xml'; fil = 'https://www.franceinfo.fr/titres.rss';
                        monde = 'https://www.lemonde.fr/international/rss_full.xml'; f24 = 'https://www.france24.com/fr/rss' }
    $anciens = @{}
    foreach ($l in (Lignes-Existantes $fActus)) {
        $c = $l.Split('|')
        if ($c.Count -ge 5 -and $c[0] -eq 'A') { if (-not $anciens.ContainsKey($c[1])) { $anciens[$c[1]] = @() }; $anciens[$c[1]] += $l }
    }
    $lignes = New-Object Collections.Generic.List[string]
    $lignes.Add("maj=$(Maintenant)")
    foreach ($nom in $flux.Keys) {
        try {
            $x = [xml](Get-Texte $flux[$nom])
            $n = 0
            foreach ($it in $x.SelectNodes('//item')) {
                $titre = Titre-Propre $it.SelectSingleNode('title').InnerText
                $lien = ([string]$it.SelectSingleNode('link').InnerText).Trim()
                $date = $it.SelectSingleNode('pubDate')
                if ($titre -eq '' -or $lien -notmatch '^https?://') { continue }
                # résumé (sans balises HTML) et photo (enclosure, media:content ou media:thumbnail) pour la fiche de l'article
                $desc = $it.SelectSingleNode('description')
                $resume = if ($desc) { Titre-Propre ([regex]::Replace([Net.WebUtility]::HtmlDecode($desc.InnerText), '<[^>]+>', ' ')) } else { '' }
                if ($resume.Length -gt 600) { $resume = $resume.Substring(0, 600) }
                $image = ''
                foreach ($x in @($it.SelectSingleNode('enclosure'), $it.SelectSingleNode("*[local-name()='content']"), $it.SelectSingleNode("*[local-name()='thumbnail']"))) {
                    if ($x -and $x.GetAttribute('url') -match '^https://[^\s|]+$') { $image = $x.GetAttribute('url'); break }
                }
                $lignes.Add("A|$nom|$(if ($date) { Unix-Rss $date.InnerText } else { 0 })|$titre|$lien|$resume|$image")
                if (++$n -ge 12) { break }
            }
        } catch {
            $erreurs += "actus:$nom"
            if ($anciens.ContainsKey($nom)) { foreach ($l in $anciens[$nom]) { $lignes.Add($l) } }
        }
    }
    Ecrire-Lignes $fActus $lignes
}

# ---------- Phrases Tatoeba (un lot par jour) ----------
if ($Tatoeba) {
    $age = 1e9
    if (Test-Path $fTatoeba) {
        $l1 = [IO.File]::ReadAllLines($fTatoeba, [Text.Encoding]::UTF8)[0]
        if ($l1 -match '^maj=(\d+)$') { $age = (Maintenant) - [long]$Matches[1] }
    }
    if ($age -gt 20 * 3600) {
        # grossièretés et sujets crus : jamais sur le bureau
        $grossier = '(?i)\b(putains?|merdes?|merdique|conn?ards?|conne?s?|connasses?|salopes?|salauds?|bites?|couilles?|encul\w*|' +
            'pd|putes?|niquer?|nique|foutre|chier|chiant\w*|bordel|batard\w*|bâtard\w*|cul|culs|seins?|sexe|sexuel\w*|' +
            'baiser|baise|suicid\w*|viol\w*|drogu\w*|nazi\w*|' +
            'fuck\w*|shit\w*|bitch\w*|bastards?|cunts?|dicks?|pussy|whores?|asshole\w*|damn\w*|crap|sex\w*|rape\w*|nigg\w*|kill\w*|suicide\w*)\b'
        $paires = New-Object Collections.Generic.List[string]
        $vus = @{}
        try {
            for ($page = 0; $page -lt 3 -and $paires.Count -lt 100; $page++) {
                $r = ConvertFrom-Json (Get-Texte "https://api.tatoeba.org/unstable/sentences?lang=fra&trans:lang=eng&sort=random&limit=50" 20)
                foreach ($s in $r.data) {
                    if ($s.is_unapproved) { continue }
                    $en = @($s.translations | Where-Object { $_.lang -eq 'eng' -and -not $_.is_unapproved })
                    $dir = @($en | Where-Object { $_.is_direct })
                    if ($dir.Count) { $en = $dir }
                    if (-not $en.Count) { continue }
                    $fr = Titre-Propre $s.text; $an = Titre-Propre $en[0].text
                    if ($fr.Length -lt 8 -or $fr.Length -gt 70 -or $an.Length -gt 70 -or $vus.ContainsKey($fr)) { continue }
                    if ("$fr $an" -match $grossier) { continue }   # (base collaborative : il y a de tout)
                    $vus[$fr] = 1
                    $paires.Add("$fr|$an")
                }
            }
        } catch { $erreurs += 'tatoeba' }
        if ($paires.Count -ge 10) { Ecrire-Lignes $fTatoeba (@("maj=$(Maintenant)") + $paires) }
    }
}
exit 0
