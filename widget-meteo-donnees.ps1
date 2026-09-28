# Collecte la position et la météo pour widget-meteo.ahk.
# Écrit un fichier « clé=valeur » (UTF-8) dans %LOCALAPPDATA%\WidgetMeteo\donnees.txt.
#
# Position : localisation Windows (Wi-Fi, précise et insensible au VPN) en
# priorité. L'adresse IP ne sert qu'en dernier recours : derrière NordVPN
# elle donnerait la ville du serveur, pas la tienne. Une position Wi-Fi de
# moins de 24 h est donc préférée à une position IP fraîche.
#
# En cas d'échec réseau, le fichier précédent est conservé tel quel : le
# widget affiche la dernière météo connue plutôt qu'un écran vide.

param([switch]$ForcerPosition, [ValidatePattern('^[ABC]?$')][string]$ZoneVacances = '', [switch]$ForcerCalendrier,
      [switch]$CalendrierSeul, [string]$Ville2 = '', [string]$ChercherVille = '', [switch]$Vigilance,
      [string]$VigilanceZone = '', [ValidatePattern('^[A-Za-z0-9]*$')][string]$Seine = '', [switch]$Air, [switch]$Sable,
      [switch]$Pollens, [switch]$Climat, [switch]$Iss)

$ErrorActionPreference = 'Stop'
$inv = [cultureinfo]::InvariantCulture

$dossier   = Join-Path $env:LOCALAPPDATA 'WidgetMeteo'
$fPosition = Join-Path $dossier 'position.txt'
$fDonnees  = Join-Path $dossier 'donnees.txt'

$RAFRAICHIR_POSITION_H = 3    # on redemande la position au-delà (portable qui bouge)
$GARDER_POSITION_WIFI_H = 24  # une position Wi-Fi reste préférable à l'IP jusque-là

function Lire-Cles([string]$chemin) {
    $h = @{}
    if (Test-Path $chemin) {
        foreach ($l in [IO.File]::ReadAllLines($chemin, [Text.Encoding]::UTF8)) {
            $i = $l.IndexOf('=')
            if ($i -gt 0) { $h[$l.Substring(0, $i)] = $l.Substring($i + 1) }
        }
    }
    return $h
}

function Ecrire-Cles([string]$chemin, $h) {
    $lignes = foreach ($k in $h.Keys) { "$k=$($h[$k])" }
    # Écriture atomique : le widget ne lit jamais un fichier à moitié écrit
    $tmp = "$chemin.tmp"
    [IO.File]::WriteAllLines($tmp, [string[]]$lignes, (New-Object Text.UTF8Encoding $false))
    Move-Item $tmp $chemin -Force
}

function Maintenant() { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

function Position-Windows {
    try {
        Add-Type -AssemblyName System.Device
        $w = New-Object System.Device.Location.GeoCoordinateWatcher([System.Device.Location.GeoPositionAccuracy]::High)
        [void]$w.TryStart($false, [TimeSpan]::FromSeconds(20))
        $t0 = Get-Date
        while ($w.Status -ne 'Ready' -and ((Get-Date) - $t0).TotalSeconds -lt 20) { Start-Sleep -Milliseconds 300 }
        $c = $w.Position.Location
        $w.Stop(); $w.Dispose()
        if ($c.IsUnknown) { return $null }
        return @{ lat = $c.Latitude; lon = $c.Longitude; source = 'wifi' }
    } catch { return $null }
}

function Position-IP {
    try {
        $r = Invoke-RestMethod 'https://ipwho.is/?fields=success,city,latitude,longitude' -TimeoutSec 15
        if (-not $r.success) { return $null }
        return @{ lat = [double]$r.latitude; lon = [double]$r.longitude; ville = $r.city; source = 'ip' }
    } catch { return $null }
}

function Nom-Ville([double]$lat, [double]$lon) {
    $la = $lat.ToString($inv); $lo = $lon.ToString($inv)
    try {
        $r = Invoke-RestMethod "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$la&longitude=$lo&localityLanguage=fr" -TimeoutSec 15
        if ($r.city) { return $r.city }
        if ($r.locality) { return $r.locality }
    } catch {}
    try {
        $r = Invoke-RestMethod "https://nominatim.openstreetmap.org/reverse?lat=$la&lon=$lo&format=json&accept-language=fr&zoom=10" `
            -Headers @{ 'User-Agent' = 'widget-meteo-perso/1.0' } -TimeoutSec 15
        foreach ($k in 'city', 'town', 'village', 'municipality') { if ($r.address.$k) { return $r.address.$k } }
    } catch {}
    return ''
}

# ---------------------------------------------------------------- résumé
# Le texte façon Google : « Généralement ensoleillé demain. Maximum 26 ° ».
#  1. Pluie (neige, orage…) en cours ou imminente : « Fin de la pluie vers 15 h »,
#     « Averses probables vers 14 h ».
#  2. Sinon la tendance de la journée : aujourd'hui jusqu'à 17 h, demain ensuite.
#  3. Puis le maximum du jour concerné.
#
# Sémantique Open-Meteo à connaître (doc + code source vérifiés) :
#  - un créneau horaire « 15:00 » décrit l'heure PRÉCÉDENTE pour la pluie
#    (precipitation, precipitation_probability) : la pluie de ce créneau
#    commence donc vers 14 h ;
#  - le weather_code QUOTIDIEN est la condition la plus sévère de la journée
#    (une heure couverte suffit) : la tendance se calcule sur les heures ;
#  - la probabilité vient d'un ensemble de modèles, le code d'un modèle
#    unique : ils peuvent diverger, on combine les deux (P-Eff).

$NBSP  = [char]0x00A0             # espaces insécables : « 26 » et « ° » ne se séparent jamais
$NNBSP = [char]0x202F
$SEUIL_HUMIDE    = 40             # % effectif : l'heure compte comme pluvieuse
$SEUIL_FORT      = 70             # % effectif : « prévue » au lieu de « probable »
$P_SANS_ENSEMBLE = 55             # % retenu quand la probabilité manque mais que le modèle mouille
$DET_MM          = 0.2            # mm/h : le modèle unique « mouille »
$FEN_ARRIVEE     = 4              # créneaux scrutés pour « Pluie prévue vers… »
$FEN_FIN         = 6              # créneaux scrutés pour « Fin de la pluie vers… »
$J_DEB = 8; $J_FIN = 21           # créneaux de la journée
$H_BASCULE       = 17             # à partir de 17 h, le résumé parle de demain

# type -> libellé immédiat, accord, libellé de tendance, accord, « Fin de… »
$TYPES = @{
    PLUIE_FAIBLE  = @('Pluie faible',      'fs', 'Pluie faible',      'fs', 'Fin de la pluie')
    AVERSES       = @('Averses',           'fp', 'Averses',           'fp', 'Fin des averses')
    PLUIE         = @('Pluie',             'fs', 'Pluie',             'fs', 'Fin de la pluie')
    AVERSES_NEIGE = @('Averses de neige',  'fp', 'Averses de neige',  'fp', 'Fin des averses de neige')
    NEIGE         = @('Neige',             'fs', 'Neige',             'fs', 'Fin de la neige')
    VERGLAS       = @('Pluie verglaçante', 'fs', 'Pluie verglaçante', 'fs', 'Fin de la pluie verglaçante')
    ORAGE         = @('Orage',             'ms', 'Orages',            'mp', "Fin de l'orage")
}
$GRAVITE  = @('PLUIE_FAIBLE', 'AVERSES', 'PLUIE', 'AVERSES_NEIGE', 'NEIGE', 'VERGLAS', 'ORAGE')
$PREVU    = @{ ms = 'prévu'; fs = 'prévue'; mp = 'prévus'; fp = 'prévues' }
$PROBABLE = @{ ms = 'probable'; fs = 'probable'; mp = 'probables'; fp = 'probables' }
$QUAND    = @{ 'auj|' = "aujourd'hui"; 'auj|matin' = 'ce matin'; 'auj|apres_midi' = 'cet après-midi'; 'auj|soir' = 'ce soir'
               'dem|' = 'demain'; 'dem|matin' = 'demain matin'; 'dem|apres_midi' = 'demain après-midi'; 'dem|soir' = 'demain soir' }

# Type de précipitation d'après le code WMO (plages pour les codes inconnus)
function Type-Code($code, $temp) {
    if ($null -eq $code -or $code -lt 50 -or $code -gt 99) {
        if ($null -ne $temp -and $temp -le 1) { return 'NEIGE' } else { return 'AVERSES' }
    }
    $c = [int]$code
    if ($c -in 56, 57, 66, 67) { return 'VERGLAS' }
    if ($c -le 59) { return 'PLUIE_FAIBLE' }
    if ($c -le 69) { return 'PLUIE' }
    if ($c -le 79) { return 'NEIGE' }
    if ($c -le 84) { return 'AVERSES' }
    if ($c -le 89) { return 'AVERSES_NEIGE' }
    return 'ORAGE'
}

function Plus-Grave($liste) {
    $pire = $liste[0]
    foreach ($t in $liste) { if ([array]::IndexOf($GRAVITE, $t) -gt [array]::IndexOf($GRAVITE, $pire)) { $pire = $t } }
    return $pire
}

# Probabilité « effective » : celle de l'ensemble, relevée si le modèle unique mouille
function P-Eff($p, $mm) {
    $det = $null -ne $mm -and $mm -ge $DET_MM
    if ($null -eq $p) { if ($det) { return $P_SANS_ENSEMBLE } else { return 0 } }
    if ($det) { return [Math]::Max([double]$p, 50) } else { return [double]$p }
}

# ---------------------------------------------------------------- heures locales
# Open-Meteo applique UN SEUL décalage horaire à toute sa réponse (celui du
# moment de la requête) : après un changement d'heure dans la période, ses
# heures locales sont fausses d'1 h (constaté : lever du 26/10/2025 donné à
# 08:27 au lieu de 07:27). On demande donc des instants Unix
# (timeformat=unixtime) et on les convertit ici en heure locale du jour
# concerné, avec les règles de Windows quand elles donnent le même décalage que
# la ville au moment de la requête (le cas normal : le PC est à l'heure du
# lieu) ; sinon au décalage fixe d'Open-Meteo, comme avant. Les dates des jours
# (daily.time) restent au décalage fixe : ce sont des étiquettes, pas des instants.

# Instant Unix d'une heure Open-Meteo : nombre (unixtime) ou « yyyy-MM-ddTHH:mm »
# au décalage fixe $off (ancien cache meteo.json) ; $null si vide
function Unix-De($v, [double]$off) {
    if ($null -eq $v) { return $null }
    $s = [string]$v
    if ($s -match '^\d+$') { $t = [long]$s; if ($t -gt 0) { return $t } else { return $null } }
    if ($s.Length -ge 16) {
        $d = [DateTime]::MinValue
        if (-not [DateTime]::TryParseExact($s.Substring(0, 16), "yyyy-MM-dd'T'HH:mm", $inv,
            [Globalization.DateTimeStyles]'AssumeUniversal, AdjustToUniversal', [ref]$d)) { return $null }
        return ([DateTimeOffset]$d).ToUnixTimeSeconds() - [long]$off
    }
    return $null
}

# Fuseau de conversion : @{ tz = règles de Windows, ou $null ; off = décalage fixe d'Open-Meteo }
function Fuseau-Meteo($o) {
    $off = [double]$o.utc_offset_seconds
    $tz = $null
    try {
        $ref = if ($o.current) { Unix-De $o.current.time $off } else { $null }
        if ($null -eq $ref) { $ref = Maintenant }
        $tz = [TimeZoneInfo]::Local
        if ($tz.GetUtcOffset([DateTimeOffset]::FromUnixTimeSeconds($ref)).TotalSeconds -ne $off) { $tz = $null }
    } catch { $tz = $null }
    return @{ tz = $tz; off = $off }
}

# « yyyy-MM-ddTHH:mm » local d'un instant Unix ($null reste $null)
function Local-De($t, $z) {
    if ($null -eq $t -or [long]$t -le 0) { return $null }
    $u = [DateTimeOffset]::FromUnixTimeSeconds([long]$t)
    $l = if ($z.tz) { [TimeZoneInfo]::ConvertTime($u, $z.tz) } else { $u.ToOffset([TimeSpan]::FromSeconds($z.off)) }
    return $l.ToString("yyyy-MM-dd'T'HH:mm", $inv)
}

# La pluie par quart d'heure des 3 prochaines heures (Open-Meteo, modèles à maille
# fine) : « instant du 1er créneau|mm par créneau,… » ; chaque valeur est la pluie
# des 15 min qui PRÉCÈDENT son instant ; "" si la réponse n'en a pas
function Pluie-15($o) {
    if (-not $o.minutely_15) { return '' }
    $t = @($o.minutely_15.time); $p = @($o.minutely_15.precipitation)
    if (-not $t.Count) { return '' }
    $v = for ($i = 0; $i -lt $t.Count; $i++) { if ($null -eq $p[$i]) { '' } else { ([double]$p[$i]).ToString($inv) } }
    return "$($t[0])|$($v -join ',')"
}

# Réécrit en place les heures de la réponse en heure locale juste ; garde les
# instants dans hourly.unix et current.unix, et le fuseau dans $o.zone
function Normaliser-Heures($o) {
    if ($o.PSObject.Properties['zone']) { return }
    $z = Fuseau-Meteo $o
    if ($o.current -and $o.current.PSObject.Properties['time']) {
        $u = Unix-De $o.current.time $z.off
        $o.current | Add-Member -NotePropertyName unix -NotePropertyValue $u -Force
        $o.current.time = Local-De $u $z
    }
    if ($o.hourly -and $o.hourly.PSObject.Properties['time']) {
        $a = @($o.hourly.time); $u = New-Object object[] $a.Count; $l = New-Object object[] $a.Count
        for ($i = 0; $i -lt $a.Count; $i++) { $u[$i] = Unix-De $a[$i] $z.off; $l[$i] = Local-De $u[$i] $z }
        $o.hourly | Add-Member -NotePropertyName unix -NotePropertyValue $u -Force
        $o.hourly.time = $l
    }
    $dj = $o.daily
    if ($dj) {
        foreach ($k in 'sunrise', 'sunset', 'moonrise', 'moonset') {
            if (-not $dj.PSObject.Properties[$k]) { continue }
            $a = @($dj.$k); $r = New-Object object[] $a.Count; $u = New-Object object[] $a.Count
            for ($i = 0; $i -lt $a.Count; $i++) { $u[$i] = Unix-De $a[$i] $z.off; $r[$i] = Local-De $u[$i] $z }
            $dj.$k = $r
            $dj | Add-Member -NotePropertyName "$($k)_unix" -NotePropertyValue $u -Force   # (durée du jour à la seconde)
        }
        if ($dj.PSObject.Properties['time']) {
            $a = @($dj.time); $r = New-Object object[] $a.Count
            for ($i = 0; $i -lt $a.Count; $i++) {
                $s = [string]$a[$i]
                $r[$i] = if ($s -match '^\d+$') { [DateTimeOffset]::FromUnixTimeSeconds([long]$s + [long]$z.off).UtcDateTime.ToString('yyyy-MM-dd', $inv) } else { $s }
            }
            $dj.time = $r
        }
    }
    $o | Add-Member -NotePropertyName zone -NotePropertyValue $z -Force
}

# « yyyy-MM-ddTHH:mm » de maintenant, à l'heure du lieu
function Maintenant-Local($o) {
    if ($o.PSObject.Properties['zone']) { return Local-De (Maintenant) $o.zone }
    return [DateTime]::UtcNow.AddSeconds([double]$o.utc_offset_seconds).ToString("yyyy-MM-dd'T'HH:mm", $inv)
}

# Index du dernier créneau horaire commencé (heure ≤ maintenant), -1 si aucun :
# par les instants Unix quand on les a (la nuit du passage à l'heure d'hiver,
# « 02:00 » revient deux fois), sinon en comparant les heures locales
function Dernier-Creneau($o, [string]$maintenant = '') {
    $T = @($o.hourly.time); $U = @($o.hourly.unix); $idx = -1
    if (-not $maintenant -and $U.Count -eq $T.Count -and $T.Count) {
        $n = Maintenant
        for ($i = 0; $i -lt $U.Count; $i++) { if ($null -ne $U[$i] -and $U[$i] -le $n) { $idx = $i } }
    } else {
        $now = if ($maintenant) { $maintenant } else { Maintenant-Local $o }
        for ($i = 0; $i -lt $T.Count; $i++) { if ([string]::CompareOrdinal($T[$i], $now) -le 0) { $idx = $i } }
    }
    return $idx
}

# L'événement (lever ou coucher de lune, heure locale complète) qui tombe le
# jour $date : les journées d'Open-Meteo suivent le décalage fixe, pas les vraies
# journées locales ; après un changement d'heure, un lever vers minuit peut être
# rangé la veille ou le lendemain. Choisi par sa date, il ne se trompe jamais de 24 h.
function Evenement-Du-Jour($liste, [string]$date) {
    foreach ($v in @($liste)) { if ($v -and ([string]$v).StartsWith($date)) { return $v } }
    return $null
}

function Heure([string]$t) { [int]$t.Substring(11, 2) }
function Debut([string]$t) { '{0}{1}h' -f (((Heure $t) + 23) % 24), $NBSP }  # le créneau couvre l'heure précédente

function Moment($heures) {
    $parts = @($heures | ForEach-Object { if ($_ -le 12) { 'matin' } elseif ($_ -le 18) { 'apres_midi' } else { 'soir' } } | Select-Object -Unique)
    if ($parts.Count -eq 1) { return $parts[0] } else { return $null }
}

function Ciel($nuages) {
    if (-not $nuages.Count) { return $null }
    $frac = @($nuages | Where-Object { $_ -lt 50 }).Count / $nuages.Count
    $moy  = ($nuages | Measure-Object -Average).Average
    if ($frac -ge 0.9 -and $moy -lt 20) { return 'Ensoleillé' }
    if ($frac -ge 0.65) { return 'Généralement ensoleillé' }
    if ($frac -ge 0.35) { return 'Partiellement nuageux' }
    if ($frac -ge 0.10) { return 'Généralement nuageux' }
    return 'Nuageux'
}

function Suite-Brouillard($nuages) {
    if (-not $nuages.Count) { return 'ciel couvert' }
    $frac = @($nuages | Where-Object { $_ -lt 50 }).Count / $nuages.Count
    if ($frac -ge 0.65) { return 'soleil' } elseif ($frac -ge 0.35) { return 'éclaircies' } else { return 'ciel couvert' }
}

# Renvoie @{ texte = « Généralement ensoleillé demain. » ; maximum = « Maximum 26 ° » }.
# Les deux sont séparés : c'est le widget, qui connaît la place disponible, qui
# décide s'il affiche le maximum en entier, en abrégé (« Max. ») ou pas du tout.
# $maintenant : heure locale « yyyy-MM-ddTHH:mm » imposée (tests) ; sinon l'heure actuelle du lieu
function Resume($o, [string]$maintenant = '') {
    $horaire = $o.hourly            # (PowerShell ignore la casse : surtout pas $H, $h sert plus bas)
    $T = @($horaire.time)
    $n = $T.Count
    function Val($k, $i) { $a = $horaire.$k; if ($null -ne $a -and $i -lt @($a).Count) { return $a[$i] } else { return $null } }
    function PEff($i) { P-Eff (Val 'precipitation_probability' $i) (Val 'precipitation' $i) }
    function Humide($i) {
        $c = Val 'weather_code' $i
        ((PEff $i) -ge $SEUIL_HUMIDE) -or ($null -ne $c -and $c -ge 95 -and $c -le 99)
    }
    function Typ($i) { Type-Code (Val 'weather_code' $i) (Val 'temperature_2m' $i) }

    # heure locale du lieu (pas celle du PC), au format des créneaux
    $now = if ($maintenant) { $maintenant } else { Maintenant-Local $o }
    $idx = Dernier-Creneau $o $maintenant
    if ($idx -lt 0 -or $idx + $FEN_FIN -ge $n) { return @{ texte = ''; maximum = '' } }   # données absentes ou trop anciennes
    $auj  = $now.Substring(0, 10)
    $hNow = [int]$now.Substring(11, 2)

    # ---- jour concerné : demain après 17 h, ou quand il ne reste presque plus de jour
    $restants = @(for ($i = $idx + 1; $i -lt $n; $i++) {
        $h = Heure $T[$i]
        if ($T[$i].Substring(0, 10) -eq $auj -and $h -ge $J_DEB -and $h -le $J_FIN -and (Val 'is_day' $i) -eq 1) { $i }
    })
    $cible = if ($hNow -ge $H_BASCULE -or $restants.Count -lt 2) { 'dem' } else { 'auj' }
    $jourCible = if ($cible -eq 'auj') { $auj } else { $T | ForEach-Object { $_.Substring(0, 10) } | Where-Object { $_ -gt $auj } | Select-Object -First 1 }

    $tmax = $null
    $dt = @($o.daily.time); $dmax = @($o.daily.temperature_2m_max)
    $j = [array]::IndexOf([string[]]$dt, [string]$jourCible)
    if ($jourCible -and $j -ge 0 -and $j -lt $dmax.Count) { $tmax = $dmax[$j] }
    if ($null -eq $tmax) {
        $tl = @(for ($i = 0; $i -lt $n; $i++) { if ($T[$i].Substring(0, 10) -eq $jourCible) { $v = Val 'temperature_2m' $i; if ($null -ne $v) { $v } } })
        if ($tl.Count) { $tmax = ($tl | Measure-Object -Maximum).Maximum }
    }

    # ---- 1. précipitations en cours ou imminentes
    $cur = $o.current
    $cCode = $cur.weather_code; $cMm = $cur.precipitation
    $pleut = ($null -ne $cCode -and (($cCode -ge 51 -and $cCode -le 86) -or ($cCode -ge 95 -and $cCode -le 99))) -or
             ($null -ne $cMm -and $cMm -ge 0.1)
    $s1 = $null; $immediat = $false
    if ($pleut) {
        $tp = if ($null -ne $cCode -and $cCode -ge 50) { Type-Code $cCode $cur.temperature_2m } else { Typ ($idx + 1) }
        $ty = $TYPES[$tp]
        $k = $null
        for ($i = $idx + 1; $i -le $idx + $FEN_FIN; $i++) { if (-not (Humide $i)) { $k = $i; break } }
        $s1 = if ($null -eq $k) { "$($ty[0]) en cours." }
              elseif ($k -eq $idx + 1) { "$($ty[4]) dans l'heure." }
              else { "$($ty[4]) vers $(Debut $T[$k])." }
        $immediat = $true
    } else {
        $k = $null
        for ($i = $idx + 1; $i -le $idx + $FEN_ARRIVEE; $i++) { if (Humide $i) { $k = $i; break } }
        if ($null -ne $k) {
            $serie = @($k)
            while ($serie[-1] + 1 -le $idx + $FEN_FIN -and (Humide ($serie[-1] + 1))) { $serie += $serie[-1] + 1 }
            $ty = $TYPES[(Plus-Grave @($serie | ForEach-Object { Typ $_ }))]
            $pmax = ($serie | ForEach-Object { PEff $_ } | Measure-Object -Maximum).Maximum
            $mot = if ($pmax -ge $SEUIL_FORT) { $PREVU[$ty[1]] } else { $PROBABLE[$ty[1]] }
            $quandTxt = if ($k -eq $idx + 1) { "dans l'heure" } else { "vers $(Debut $T[$k])" }
            $s1 = "$($ty[0]) $mot $quandTxt."
            $immediat = $true
        }
    }

    # ---- 2. tendance du jour concerné (toujours calculée : c'est la variante « journée »
    # du résumé, que le widget montre quand la pastille « pluie dans l'heure » dit déjà
    # l'heure précise de la pluie : une seule source pour elle, pas deux qui se contredisent)
    $sImm = $s1; $s1 = $null
    if ($true) {
        $W = @(for ($i = 0; $i -lt $n; $i++) {
            $h = Heure $T[$i]
            if ($T[$i].Substring(0, 10) -eq $jourCible -and $h -ge $J_DEB -and $h -le $J_FIN -and ($cible -eq 'dem' -or $i -gt $idx)) { $i }
        })
        if ($W.Count -ge 3) {
            $hum   = @($W | Where-Object { Humide $_ })
            $orage = @($hum | Where-Object { $c = Val 'weather_code' $_; $c -ge 95 -and $c -le 99 })
            $pHum  = if ($hum.Count) { ($hum | ForEach-Object { PEff $_ } | Measure-Object -Maximum).Maximum } else { 0 }
            if ($hum.Count -and ($hum.Count -ge 2 -or $pHum -ge 60 -or $orage.Count)) {
                $genres = @($hum | ForEach-Object { Typ $_ })
                $nb = { param($x) @($genres | Where-Object { $_ -eq $x }).Count }
                if ($genres -contains 'VERGLAS') { $tp = 'VERGLAS' }
                elseif ($orage.Count) { $tp = 'ORAGE' }
                elseif (((& $nb 'NEIGE') + (& $nb 'AVERSES_NEIGE')) * 2 -ge $genres.Count) {
                    $tp = if ((& $nb 'AVERSES_NEIGE') * 2 -gt $genres.Count) { 'AVERSES_NEIGE' } else { 'NEIGE' }
                }
                elseif ((& $nb 'AVERSES') * 2 -ge $genres.Count) { $tp = 'AVERSES' }
                elseif ($hum.Count * 2 -ge $W.Count) { $tp = if ((& $nb 'PLUIE_FAIBLE') -eq $genres.Count) { 'PLUIE_FAIBLE' } else { 'PLUIE' } }
                else { $tp = 'AVERSES' }
                $sel = if ($tp -eq 'ORAGE') { $orage } else { $hum }
                $ty = $TYPES[$tp]
                $lab = if ($tp -eq 'AVERSES' -and $hum.Count * 3 -lt $W.Count) { 'Averses éparses' } else { $ty[2] }
                $pmax = ($sel | ForEach-Object { PEff $_ } | Measure-Object -Maximum).Maximum
                $mot = if ($pmax -ge $SEUIL_FORT) { $PREVU[$ty[3]] } else { $PROBABLE[$ty[3]] }
                $moment = Moment @($sel | ForEach-Object { Heure $T[$_] })
                $s1 = "$lab $mot $($QUAND["$cible|$moment"])."
            } else {
                $jour = @($W | Where-Object { (Val 'is_day' $_) -eq 1 })
                if (-not $jour.Count) { $jour = $W }
                $brume = @($W | Where-Object { (Val 'weather_code' $_) -in 45, 48 })
                if ($brume.Count -ge 2 -and -not ($brume | Where-Object { (Heure $T[$_]) -gt 12 }) -and $brume.Count * 2 -lt $W.Count) {
                    $reste = @($jour | Where-Object { $brume -notcontains $_ } | ForEach-Object { Val 'cloud_cover' $_ } | Where-Object { $null -ne $_ })
                    $s1 = "Brouillard $($QUAND["$cible|matin"]), puis $(Suite-Brouillard $reste)."
                } elseif ($brume.Count * 2 -ge $W.Count) {
                    $s1 = "Brouillard $($QUAND["$cible|"])."
                } else {
                    $c = Ciel @($jour | ForEach-Object { Val 'cloud_cover' $_ } | Where-Object { $null -ne $_ })
                    if ($c) { $s1 = "$c $($QUAND["$cible|"])." }
                }
            }
        }
    }

    # ---- 3. maximum du jour concerné
    $s2 = ''; $s2j = ''
    if ($null -ne $tmax) {
        $pref = if ($immediat -and $cible -eq 'dem') { 'Demain, maximum' } else { 'Maximum' }
        $arrondi = [int][Math]::Round([double]$tmax, [MidpointRounding]::AwayFromZero)
        $s2 = "$pref$NBSP$arrondi°"
        $s2j = "Maximum$NBSP$arrondi°"
    }
    $sJour = $s1
    $texte = if ($null -ne $sImm) { $sImm } else { $s1 }
    return @{ texte = [string]$texte; maximum = $s2; jour = $(if ($null -ne $tmax) { $jourCible } else { '' });
              texte_jour = [string]$sJour; maximum_jour = $s2j }
}

# ---------------------------------------------------------------- prévisions détaillées
# Pour la rangée « heure par heure » du widget, sa fenêtre de prévisions et le
# fond d'écran qui suit le soleil : lever/coucher, heures à venir, 7 jours.
$fPrevisions = Join-Path $dossier 'previsions.txt'

function Nombre($v, [int]$dec = 1) { if ($null -eq $v) { '' } else { ([Math]::Round([double]$v, $dec)).ToString($inv) } }
function HeureDe($t) { if ([string]$t -and ([string]$t).Length -ge 16) { ([string]$t).Substring(11, 5) } else { '' } }

# Index du premier créneau horaire postérieur à « maintenant » (heure locale du lieu)
function Prochain-Creneau($o) {
    $k = (Dernier-Creneau $o) + 1
    if ($k -ge @($o.hourly.time).Count) { return -1 }
    return $k
}

# Clés ajoutées à donnees.txt : soleil, 12 prochaines heures (le widget en montre 5 à 12 selon sa largeur), vent, humidité, UV
# Indice du jour courant (heure de la ville) dans « daily » : 0 d'ordinaire, 1 si
# le cache hors ligne date d'hier ; 0 si introuvable (cache très ancien)
function Index-Jour($o) {
    $auj = (Maintenant-Local $o).Substring(0, 10)
    $j = [array]::IndexOf([string[]]@($o.daily.time), $auj)
    if ($j -lt 0) { $j = 0 }
    return $j
}

function Extraits($o) {
    $x = [ordered]@{}
    $j = Index-Jour $o
    $lv = @($o.daily.sunrise); $cc = @($o.daily.sunset)
    $x.lever = HeureDe $lv[$j]; $x.coucher = HeureDe $cc[$j]
    $x.lever2 = if ($lv.Count -gt $j + 1) { HeureDe $lv[$j + 1] } else { '' }
    $x.coucher2 = if ($cc.Count -gt $j + 1) { HeureDe $cc[$j + 1] } else { '' }
    # lune (null les jours sans lever ou sans coucher) ; @() : un ancien meteo.json n'a pas la clé
    $ml = @($o.daily.moonrise); $mc = @($o.daily.moonset); $dt = @($o.daily.time)
    $d1 = [string]$dt[$j]; $d2 = if ($dt.Count -gt $j + 1) { [string]$dt[$j + 1] } else { '-' }
    $x.lune_lever = HeureDe (Evenement-Du-Jour $ml $d1); $x.lune_coucher = HeureDe (Evenement-Du-Jour $mc $d1)
    $x.lune_lever2 = HeureDe (Evenement-Du-Jour $ml $d2); $x.lune_coucher2 = HeureDe (Evenement-Du-Jour $mc $d2)
    $hh = $o.hourly; $k = Prochain-Creneau $o
    $liste = @()
    if ($k -ge 0) {
        for ($i = $k; $i -lt [Math]::Min($k + 12, @($hh.time).Count); $i++) {
            $liste += '{0},{1},{2},{3},{4}' -f (HeureDe $hh.time[$i]), $hh.weather_code[$i], $hh.is_day[$i], (Nombre $hh.temperature_2m[$i]), $hh.precipitation_probability[$i]
        }
    }
    $x.heures = $liste -join ';'
    $x.vent = Nombre $o.current.wind_speed_10m 0
    $x.vent_dir = Nombre $o.current.wind_direction_10m 0
    $x.humidite = Nombre $o.current.relative_humidity_2m 0
    $x.uv = Nombre (@($o.daily.uv_index_max)[$j]) 1
    # durée du jour (s) aujourd'hui et demain, à la seconde (instants Unix du lever et du coucher)
    $lu = @($o.daily.sunrise_unix); $cu = @($o.daily.sunset_unix)
    $x.jour_duree = if ($null -ne $lu[$j] -and $null -ne $cu[$j]) { [string]($cu[$j] - $lu[$j]) } else { '' }
    $x.jour_duree2 = if ($lu.Count -gt $j + 1 -and $null -ne $lu[$j + 1] -and $null -ne $cu[$j + 1]) { [string]($cu[$j + 1] - $lu[$j + 1]) } else { '' }
    # UV du jour, heure par heure : « début|fin|max|heure du max » (instants Unix des créneaux) au-dessus de 3 et de 6
    $x.uv3 = Plage-UV $o 3
    $x.uv6 = Plage-UV $o 6
    $x.nuits = Nuages-Nuits $o
    return $x
}

# Nuages des nuits à venir (étoiles filantes, planètes) : moyenne de 22 h à 2 h,
# « AAAAMMJJ:pourcentage;… » (la nuit porte la date du soir)
function Nuages-Nuits($o) {
    $heures = @($o.hourly.time); $couv = @($o.hourly.cloud_cover); $soirs = [ordered]@{}
    for ($i = 0; $i -lt $heures.Count; $i++) {
        $h = [string]$heures[$i]
        if ($h.Length -lt 16 -or $null -eq $couv[$i]) { continue }
        $hh = [int]$h.Substring(11, 2)
        if ($hh -ge 22) { $soir = $h.Substring(0, 10) }
        elseif ($hh -le 2) { $soir = [DateTime]::ParseExact($h.Substring(0, 10), 'yyyy-MM-dd', $inv).AddDays(-1).ToString('yyyy-MM-dd', $inv) }
        else { continue }
        if (-not $soirs.Contains($soir)) { $soirs[$soir] = @() }
        $soirs[$soir] += [double]$couv[$i]
    }
    return (@(foreach ($s in $soirs.Keys) { if ($soirs[$s].Count -ge 4) {
        '{0}:{1}' -f $s.Replace('-', ''), [Math]::Round(($soirs[$s] | Measure-Object -Average).Average) } }) -join ';')
}

# Créneaux d'aujourd'hui (heure du lieu) où l'indice UV atteint « seuil » :
# « premier|dernier|max|créneau du max » en instants Unix, '' s'il n'y en a pas
function Plage-UV($o, [double]$seuil) {
    # (PowerShell ignore la casse : jamais $v à côté de $V)
    $hh = $o.hourly; $heures = @($hh.time); $instants = @($hh.unix); $indices = @($hh.uv_index)
    if (-not $indices.Count -or $instants.Count -ne $heures.Count) { return '' }
    $auj = (Maintenant-Local $o).Substring(0, 10)
    $prem = $null; $der = $null; $max = -1; $tmax = $null
    for ($i = 0; $i -lt $heures.Count; $i++) {
        if (-not ([string]$heures[$i]).StartsWith($auj) -or $null -eq $indices[$i]) { continue }
        $uv = [double]$indices[$i]
        if ($uv -ge $seuil) { if ($null -eq $prem) { $prem = $instants[$i] }; $der = $instants[$i] }
        if ($uv -gt $max) { $max = $uv; $tmax = $instants[$i] }
    }
    if ($null -eq $prem) { return '' }
    return '{0}|{1}|{2}|{3}' -f $prem, $der, (Nombre $max 1), $tmax
}

# previsions.txt : une ligne « J|… » par jour (7), une ligne « H|… » par heure (48)
function Ecrire-Previsions($o) {
    $lignes = @()
    $dj = $o.daily
    $ml = @($dj.moonrise); $mc = @($dj.moonset)   # champs 14 et 15 : lever et coucher de la lune
    for ($i = (Index-Jour $o); $i -lt @($dj.time).Count; $i++) {   # (hors ligne après minuit : à partir d'aujourd'hui)
        $lignes += 'J|' + (@($dj.time[$i], $dj.weather_code[$i], (Nombre $dj.temperature_2m_min[$i]), (Nombre $dj.temperature_2m_max[$i]),
            $dj.precipitation_probability_max[$i], (Nombre $dj.precipitation_sum[$i]), (Nombre $dj.wind_speed_10m_max[$i] 0),
            (Nombre $dj.wind_gusts_10m_max[$i] 0), $dj.wind_direction_10m_dominant[$i], (Nombre $dj.uv_index_max[$i]),
            (HeureDe $dj.sunrise[$i]), (HeureDe $dj.sunset[$i]), (HeureDe (Evenement-Du-Jour $ml $dj.time[$i])),
            (HeureDe (Evenement-Du-Jour $mc $dj.time[$i]))) -join '|')
    }
    $hh = $o.hourly; $k = Prochain-Creneau $o
    if ($k -ge 1) { $k-- }       # on commence par l'heure en cours
    if ($k -ge 0) {
        for ($i = $k; $i -lt [Math]::Min($k + 48, @($hh.time).Count); $i++) {
            $lignes += 'H|' + (@($hh.time[$i], $hh.weather_code[$i], $hh.is_day[$i], (Nombre $hh.temperature_2m[$i]),
                $hh.precipitation_probability[$i], (Nombre $hh.precipitation[$i]), (Nombre $hh.wind_speed_10m[$i] 0),
                $hh.wind_direction_10m[$i]) -join '|')
        }
    }
    $tmp = "$fPrevisions.tmp"
    [IO.File]::WriteAllLines($tmp, [string[]]$lignes, (New-Object Text.UTF8Encoding $false))
    Move-Item $tmp $fPrevisions -Force
}

# Le reste ne s'exécute pas quand le script est seulement chargé pour les tests
# ---------------------------------------------------------------- calendrier
# Vacances scolaires (option « Vacances scolaires » du widget) : calendrier
# officiel du ministère (data.education.gouv.fr, jeu « fr-en-calendrier-scolaire »,
# Licence Ouverte), une requête d'environ 2 Ko par semaine. calendrier.txt :
#   maj=<unix>  zone=C  source=…  lignes V|premier jour|jour de reprise|nom
# (reprise = jour de la rentrée, exclu ; vide si la fin n'est pas encore publiée)
# En cas d'échec, les lignes V déjà connues sont TOUJOURS gardées (echec=<unix>).
$fCalendrier = Join-Path $dossier 'calendrier.txt'
$CAL_RAFRAICHIR_J = 7         # nouvelle requête au-delà
$CAL_REESSAI_H = 6            # après un échec, pas de nouvel essai avant

function Maj-Calendrier([string]$zone, [bool]$forcer) {
    $cles = Lire-Cles $fCalendrier
    $ancien = @()
    if (Test-Path $fCalendrier) {
        $ancien = @([IO.File]::ReadAllLines($fCalendrier, [Text.Encoding]::UTF8) | Where-Object { $_ -like 'V|*' })
    }
    $maint = Maintenant
    if (-not $forcer -and $cles['zone'] -eq $zone -and $cles['maj'] -and
        ($maint - [long]$cles['maj']) -lt $CAL_RAFRAICHIR_J * 86400) { return 'à jour' }
    if (-not $forcer -and $cles['zone'] -eq $zone -and $ancien.Count -and $cles['echec'] -and
        ($maint - [long]$cles['echec']) -lt $CAL_REESSAI_H * 3600) { return 'échec récent, attente' }   # (sans dates pour la zone : on réessaie)
    $depuis = (Get-Date).AddDays(-100).ToString('yyyy-MM-dd')
    $u = 'https://data.education.gouv.fr/api/explore/v2.1/catalog/datasets/fr-en-calendrier-scolaire/records' +
         '?select=description%2Cpopulation%2Cstart_date%2Cend_date' +
         "&where=zones%3D%22Zone%20$zone%22%20and%20end_date%3E%3Ddate'$depuis'" +
         '&group_by=description%2Cpopulation%2Cstart_date%2Cend_date&order_by=start_date&limit=100'
    $paris = [TimeZoneInfo]::FindSystemTimeZoneById('Romance Standard Time')
    $lignes = @()
    try {
        $r = Invoke-RestMethod -Uri $u -TimeoutSec 15
        foreach ($p in @($r.results)) {
            if ([string]$p.population -like 'Enseignant*') { continue }   # on garde « - » et « Élèves »
            $nom = [string]$p.description
            $jour = {
                param($v)
                $dt = if ($v -is [datetime]) { $v.ToUniversalTime() } else { [DateTimeOffset]::Parse([string]$v, $inv).UtcDateTime }
                [TimeZoneInfo]::ConvertTimeFromUtc($dt, $paris).Date
            }
            $debut = & $jour $p.start_date
            $fin = & $jour $p.end_date
            if ($nom -like 'Début des *') {
                $nom = ($nom -replace '^Début des\s+', ''); $fin = $null   # fin pas encore publiée
            } elseif ($fin -le $debut) {
                $fin = $debut.AddDays(1)                          # pont d'un seul jour
            }
            if ($fin) {                                           # rentrée un samedi ou un dimanche : le lundi
                while ($fin.DayOfWeek -eq 'Saturday' -or $fin.DayOfWeek -eq 'Sunday') { $fin = $fin.AddDays(1) }
            }
            $nom = $nom.Replace("d'Hiver", "d'hiver").Replace("d'Été", "d'été").Replace('de Printemps', 'de printemps')
            $lignes += 'V|' + $debut.ToString('yyyy-MM-dd') + '|' + $(if ($fin) { $fin.ToString('yyyy-MM-dd') } else { '' }) + '|' + $nom
        }
        if (-not $lignes.Count) { throw 'réponse vide' }
        $sortie = @("maj=$maint", "zone=$zone", 'source=data.education.gouv.fr fr-en-calendrier-scolaire') + @($lignes | Select-Object -Unique)
        $etat = "téléchargé : $($lignes.Count) périodes"
    } catch {
        # jamais écraser ce qu'on sait : on garde les lignes V et on note l'échec
        $sortie = @()
        foreach ($k in 'maj', 'zone', 'source') { if ($cles[$k]) { $sortie += "$k=$($cles[$k])" } }
        $sortie += "echec=$maint"
        $sortie += $ancien
        $etat = 'échec : ' + $_.Exception.Message
    }
    $tmp = "$fCalendrier.tmp"
    [IO.File]::WriteAllLines($tmp, [string[]]$sortie, (New-Object Text.UTF8Encoding $false))
    Move-Item $tmp $fCalendrier -Force
    return $etat
}

# ---------------------------------------------------------------- deuxième ville
# Un texte venu du réseau ne doit jamais casser le format « clé=valeur » ni les « | »
function Propre([string]$t) { ($t -replace '[|;=\r\n]', ' ').Trim() }

# Recherche d'une ville par son nom (géocodage Open-Meteo, sans clé) : une ligne
# par résultat « nom|détail|lat|lon|fuseau|population » (10 au plus), sinon
# « AUCUN » ou « ERREUR|message ». Le détail : région (à défaut département ou
# arrondissement), puis pays (à défaut son code : la Guadeloupe n'a ni l'un ni l'autre).
function Chercher-Ville([string]$nom, [string]$fichier) {
    $lignes = @()
    try {
        $u = 'https://geocoding-api.open-meteo.com/v1/search?name=' + [uri]::EscapeDataString($nom.Trim()) +
             '&count=10&language=fr&format=json'
        $r = Invoke-RestMethod $u -TimeoutSec 15
        foreach ($v in @($r.results)) {
            if (-not $v) { continue }
            $region = @($v.admin1, $v.admin2, $v.admin3) | Where-Object { $_ } | Select-Object -First 1
            $pays = if ($v.country) { $v.country } else { $v.country_code }
            $detail = (@($region, $pays) | Where-Object { $_ }) -join ', '
            $lignes += '{0}|{1}|{2}|{3}|{4}|{5}' -f (Propre $v.name), (Propre $detail), ([double]$v.latitude).ToString($inv),
                ([double]$v.longitude).ToString($inv), (Propre $v.timezone), [long]$v.population
        }
        if (-not $lignes.Count) { $lignes = @('AUCUN') }
    } catch { $lignes = @('ERREUR|' + (Propre $_.Exception.Message)) }
    [IO.File]::WriteAllLines($fichier, [string[]]$lignes, (New-Object Text.UTF8Encoding $false))
}

# Météo de la 2e ville. $ll = « lat,lon » tel que passé par le widget, renvoyé
# dans v2_pos : le widget ignore les données d'une ville qu'il n'affiche plus.
# Requête séparée et légère : une 2e ville en erreur ne prive jamais de la météo d'ici.
function Meteo-Ville2([string]$ll) {
    $p = $ll.Split(',')
    $la = [double]::Parse($p[0], $inv).ToString($inv); $lo = [double]::Parse($p[1], $inv).ToString($inv)
    $u = "https://api.open-meteo.com/v1/forecast?latitude=$la&longitude=$lo" +
         '&current=temperature_2m,weather_code,is_day&daily=temperature_2m_min,temperature_2m_max,sunrise,sunset' +
         '&timezone=auto&forecast_days=1'
    $m = Invoke-RestMethod $u -TimeoutSec 15
    $x = [ordered]@{}
    $x.v2_pos      = $ll
    $x.v2_temp     = ([double]$m.current.temperature_2m).ToString($inv)
    $x.v2_code     = [string]$m.current.weather_code
    $x.v2_jour     = [string]$m.current.is_day
    $x.v2_min      = ([double]@($m.daily.temperature_2m_min)[0]).ToString($inv)
    $x.v2_max      = ([double]@($m.daily.temperature_2m_max)[0]).ToString($inv)
    $x.v2_lever    = ([string]@($m.daily.sunrise)[0]).Substring(11, 5)       # heures locales de la ville
    $x.v2_coucher  = ([string]@($m.daily.sunset)[0]).Substring(11, 5)
    $x.v2_decalage = [string][int]$m.utc_offset_seconds                      # repli si l'ICU manque
    $x.v2_fuseau   = Propre $m.timezone
    $x.v2_maj      = [string](Maintenant)
    return $x
}


# ---------------------------------------------------------------- vigilance et Seine
# Instant Unix d'une date ISO (chaîne, ou DateTime si le JSON a été converti)
function Unix($v) {
    if ($v -is [datetime]) { return ([DateTimeOffset]$v.ToUniversalTime()).ToUnixTimeSeconds() }
    return [DateTimeOffset]::Parse([string]$v, $inv).ToUnixTimeSeconds()
}

# Département et commune d'une position (geo.api.gouv.fr, sans clé) :
# @{code; nom; commune (code INSEE); commune_nom}, vides hors de France
function Departement([double]$lat, [double]$lon) {
    $r = @(Invoke-RestMethod ('https://geo.api.gouv.fr/communes?lat={0}&lon={1}&fields=nom,code,departement&format=json' -f
        $lat.ToString($inv), $lon.ToString($inv)) -TimeoutSec 15)
    if (-not $r.Count -or -not $r[0].departement) { return @{ code = ''; nom = ''; commune = ''; commune_nom = '' } }
    return @{ code = [string]$r[0].departement.code; nom = [string]$r[0].departement.nom
              commune = [string]$r[0].code; commune_nom = [string]$r[0].nom }
}

# Département et commune de la position, gardés dans position.txt jusqu'au
# prochain déplacement (une requête seulement quand on a bougé)
function Lieu-Admin($pos) {
    $ll = "$($pos['lat']),$($pos['lon'])"
    if ($pos['dep_pour'] -eq $ll -and $null -ne $pos['commune']) { return }
    $dp = Departement ([double]::Parse($pos['lat'], $inv)) ([double]::Parse($pos['lon'], $inv))
    $pos['dep'] = $dp.code; $pos['dep_nom'] = $dp.nom; $pos['commune'] = $dp.commune; $pos['commune_nom'] = Propre $dp.commune_nom
    $pos['dep_pour'] = $ll
    Ecrire-Cles $fPosition $pos
}

# Nom comparable : sans accents, en minuscules, sans tirets, espaces ni apostrophes
function Cle-Nom([string]$t) {
    $d = $t.Normalize([Text.NormalizationForm]::FormD)
    (-join ($d.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })).ToLowerInvariant() -replace '[^a-z0-9]', ''
}

# Phénomène par type MeteoAlarm, quand l'intitulé « Vigilance <couleur> <phénomène> » manque
$PHENOMENES = @{ 1 = 'vent violent'; 2 = 'neige-verglas'; 3 = 'orages'; 4 = 'brouillard'; 5 = 'canicule'; 6 = 'grand froid'
                 7 = 'vagues-submersion'; 8 = 'feux de forêt'; 9 = 'avalanches'; 10 = 'pluie'; 12 = 'crues'; 13 = 'pluie-inondation' }

# Premier nombre d'un paramètre CAP (« 2; yellow; Moderate » → 2), 0 s'il manque
function Parametre($info, [string]$nom) {
    $v = @(@($info.parameter) | Where-Object { $_.valueName -eq $nom })[0]
    if (-not $v) { return 0 }
    return [int](([string]$v.value).Split(';')[0].Trim())
}

# Vigilances jaunes à rouges de la zone « $nomZone », pas finies à l'instant $t.
# Le flux garde l'historique (alertes périmées, « Update » verts qui portent
# encore l'intitulé « Vigilance jaune … ») : on se fie au niveau et aux
# heures, jamais au texte. Par type : l'état en cours est le dernier message
# émis parmi ceux déjà commencés (un vert plus récent annule une jaune) ; une
# vigilance à venir compte si aucun message plus récent ne la remplace.
function Vigilances($flux, [string]$nomZone, [long]$t) {
    $cle = Cle-Nom $nomZone
    $msgs = @()
    foreach ($w in @($flux.warnings)) {
        try {
            $a = $w.alert
            if (-not $a -or $a.status -ne 'Actual') { continue }
            $emis = Unix $a.sent
            if ($emis -gt $t + 900) { continue }             # émis « après » t : horloge en retard
            $infos = @($a.info)
            $i = @($infos | Where-Object { $_.language -eq 'fr-FR' })[0]
            if (-not $i) { $i = $infos[0] }
            if (-not $i) { continue }
            if (-not @(@($i.area) | Where-Object { (Cle-Nom $_.areaDesc) -eq $cle }).Count) { continue }
            $niv = Parametre $i 'awareness_level'
            $typ = Parametre $i 'awareness_type'
            if ($a.msgType -eq 'Cancel') { $niv = 1 }
            $phen = if ([string]$i.event -match '^Vigilance\s+(?:verte|jaune|orange|rouge)\s+(.+)$') { $Matches[1] } else { $PHENOMENES[$typ] }
            $msgs += [pscustomobject]@{ niv = $niv; typ = $typ; debut = (Unix $i.onset); fin = (Unix $i.expires); emis = $emis; phen = (Propre $phen) }
        } catch { continue }                                  # un message mal formé n'empêche pas les autres
    }
    $res = @()
    foreach ($g in @($msgs | Group-Object typ)) {
        $l = @($g.Group | Sort-Object emis, @{ Expression = { $_.fin -gt $_.debut } }, debut)   # (Sort-Object n'est pas stable)
        $cours = @($l | Where-Object { $_.debut -le $t })
        if ($cours.Count) { $c = $cours[-1]; if ($c.niv -ge 2 -and $c.fin -gt $t) { $res += $c } }
        foreach ($f in @($l | Where-Object { $_.debut -gt $t -and $_.niv -ge 2 -and $_.fin -gt $t })) {
            if (-not @($l | Where-Object { $_.emis -gt $f.emis -and $_.debut -le $f.debut }).Count) { $res += $f }
        }
    }
    return @($res | Sort-Object debut, @{ Expression = 'niv'; Descending = $true })
}

# Clés vig_* ; vig_alertes = « niv|type|début|fin|émis|phénomène », séparées par « ; »
function Cles-Vigilance($liste, [string]$dep, [string]$zone, [string]$etat) {
    $x = [ordered]@{}
    $x.vig_dep = $dep; $x.vig_zone = Propre $zone; $x.vig_etat = $etat
    $x.vig_alertes = (@($liste | Where-Object { $_ } | ForEach-Object {
        '{0}|{1}|{2}|{3}|{4}|{5}' -f $_.niv, $_.typ, $_.debut, $_.fin, $_.emis, $_.phen }) -join ';')
    $x.vig_maj = [string](Maintenant)
    return $x
}

# Diagnostic : les noms de zones du flux (« areaDesc|NUTS3 »), pour constater
# l'orthographe réelle d'un département à sa première alerte
function Noter-Zones($flux) {
    $f = Join-Path $dossier 'zones-meteoalarm.txt'
    $vus = @{}
    if (Test-Path $f) { foreach ($l in [IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8)) { $vus[$l] = 1 } }
    $nouv = @()
    foreach ($w in @($flux.warnings)) { foreach ($i in @($w.alert.info)) { foreach ($ar in @($i.area)) {
        if (-not $ar) { continue }
        $nuts = @(@($ar.geocode) | Where-Object { $_.valueName -eq 'NUTS3' })[0]
        $l = (Propre $ar.areaDesc) + '|' + $(if ($nuts) { [string]$nuts.value } else { '' })
        if (-not $vus.ContainsKey($l)) { $vus[$l] = 1; $nouv += $l }
    } } }
    if ($nouv.Count) { [IO.File]::AppendAllLines($f, [string[]]$nouv, (New-Object Text.UTF8Encoding $false)) }
}

# Hauteur de la Seine (Hub'Eau temps réel, en mm → m) : dernière mesure et
# tendance sur 6 h (moyennes des 3 mesures de chaque bout : bruit de ±3 cm)
function Mesure-Seine([string]$station) {
    $debut = [DateTime]::UtcNow.AddHours(-6).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", $inv)
    $u = "https://hubeau.eaufrance.fr/api/v2/hydrometrie/observations_tr?code_entite=$station&grandeur_hydro=H" +
         "&date_debut_obs=$debut&size=60&sort=desc&fields=date_obs,resultat_obs&format=json"
    $r = Invoke-RestMethod $u -TimeoutSec 15
    $o = @(@($r.data) | Where-Object { $_ -and $null -ne $_.resultat_obs })
    $x = [ordered]@{ seine_station = $station }
    if (-not $o.Count) { $x.seine_etat = 'sans_mesure' }
    else {
        $x.seine_h = ([Math]::Round([double]$o[0].resultat_obs / 1000.0, 2)).ToString($inv)
        $x.seine_date = [string](Unix $o[0].date_obs)
        $x.seine_tendance = ''
        if ($o.Count -ge 12) {
            $recent = ($o[0..2] | Measure-Object resultat_obs -Average).Average
            $vieux = ($o[-3..-1] | Measure-Object resultat_obs -Average).Average
            $x.seine_tendance = ([Math]::Round(($recent - $vieux) / 1000.0, 2)).ToString($inv)
        }
        $x.seine_etat = 'ok'
    }
    $x.seine_maj = [string](Maintenant)
    return $x
}

# Recopie les clés « préfixe* » de $ancien (échec réseau) ; sinon état « erreur »
function Reprendre($d, $ancien, [string]$prefixe) {
    if ($ancien[$prefixe + 'etat']) {
        foreach ($k in @($ancien.Keys)) { if ($k -like "$prefixe*") { $d[$k] = $ancien[$k] } }
    } else { $d[$prefixe + 'etat'] = 'erreur' }
}

# Clés des options ajoutées à $d (2e ville, vigilance, Seine), chacune dans son
# try : en cas d'échec, celles de $ancien sont reprises (pour la 2e ville,
# seulement si c'est la même ; le widget masque ce qui est trop vieux).
function Ajouter-Extras($d, $ancien, $pos) {
    if ($Ville2) {
        try {
            $x = Meteo-Ville2 $Ville2
            foreach ($k in $x.Keys) { $d[$k] = $x[$k] }
        } catch {
            if ($ancien['v2_pos'] -eq $Ville2) {
                foreach ($k in @($ancien.Keys)) { if ($k -like 'v2_*') { $d[$k] = $ancien[$k] } }
            }
        }
    }
    if ($Vigilance) {
        try {
            Lieu-Admin $pos                            # département de la position
            $dep = [string]$pos['dep']
            if (-not $dep -or $dep -like '97*' -or $dep -like '98*') {
                $x = Cles-Vigilance @() $dep $pos['dep_nom'] 'hors_zone'   # MeteoAlarm France = métropole
            } else {
                $flux = Invoke-RestMethod 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-france' -TimeoutSec 20
                try { Noter-Zones $flux } catch {}
                $zone = if ($VigilanceZone) { $VigilanceZone } else { [string]$pos['dep_nom'] }
                $x = Cles-Vigilance @(Vigilances $flux $zone (Maintenant)) $dep $pos['dep_nom'] 'ok'
            }
            foreach ($k in $x.Keys) { $d[$k] = $x[$k] }
        } catch { Reprendre $d $ancien 'vig_' }
    }
    if ($Seine) {
        try {
            # une fois par heure tant que l'eau est basse (99 % du temps), à chaque collecte sinon
            if ($ancien['seine_station'] -eq $Seine -and $ancien['seine_etat'] -eq 'ok' -and $ancien['seine_maj'] -and
                ((Maintenant) - [long]$ancien['seine_maj']) -lt 55 * 60 -and [double]::Parse($ancien['seine_h'], $inv) -lt 1.0) {
                foreach ($k in @($ancien.Keys)) { if ($k -like 'seine_*') { $d[$k] = $ancien[$k] } }
            } else {
                $x = Mesure-Seine $Seine
                foreach ($k in $x.Keys) { $d[$k] = $x[$k] }
            }
        } catch { Reprendre $d $ancien 'seine_' }
    }
    # qualité de l'air (Île-de-France), sable (CAMS), pollens (Atmo France) : chacun
    # gardé de la collecte précédente tant qu'il est récent (55 min, 3 h pour les pollens)
    foreach ($o in @(@{ actif = $Air; prefixe = 'air_'; duree = 55; mesure = { Mesure-Air $pos } },
                     @{ actif = $Sable; prefixe = 'sable_'; duree = 55; mesure = { Mesure-Sable $pos } },
                     @{ actif = $Pollens; prefixe = 'pol_'; duree = 180; mesure = { Mesure-Pollens $pos } })) {
        if (-not $o.actif) { continue }
        $pf = $o.prefixe
        try {
            if ($o.prefixe -ne 'sable_') { Lieu-Admin $pos }
            # (et du même jour : après minuit, « aujourd'hui » et « demain » ont changé)
            $recent = $ancien[$pf + 'maj'] -and ((Maintenant) - [long]$ancien[$pf + 'maj']) -lt $o.duree * 60 -and
                $ancien[$pf + 'etat'] -in 'ok', 'hors_zone', 'sans_donnee' -and $ancien[$pf + 'pour'] -eq "$($pos['lat']),$($pos['lon'])" -and
                [DateTimeOffset]::FromUnixTimeSeconds([long]$ancien[$pf + 'maj']).ToLocalTime().ToString('yyyyMMdd') -eq (Get-Date).ToString('yyyyMMdd')
            if ($recent) { foreach ($k in @($ancien.Keys)) { if ($k -like "$pf*") { $d[$k] = $ancien[$k] } } }
            else { $x = & $o.mesure; foreach ($k in $x.Keys) { $d[$k] = $x[$k] } }
        } catch { Reprendre $d $ancien $pf }
    }
    if ($Climat) {
        try { $x = Cles-Climat $pos; foreach ($k in $x.Keys) { $d[$k] = $x[$k] } } catch { Reprendre $d $ancien 'clim_' }
    }
    if ($Iss) {
        try { $x = Cles-Iss $pos $ancien; foreach ($k in $x.Keys) { $d[$k] = $x[$k] } } catch { Reprendre $d $ancien 'iss_' }
    }
}

# ---------------------------------------------------------------- station spatiale
# Passages VISIBLES de l'ISS (hauteur ≥ 10°, soleil sous −6°, station éclairée),
# calculés ici : Kepler + effets séculaires de J2 + traînée du TLE (pas SGP4 :
# validé à ~10 s et ~1° près contre Heavens-Above sur 7 jours avec un TLE frais).
# Le TLE (168 octets, aucune position envoyée) vient de CelesTrak une fois par
# jour au plus : un 2e téléchargement avant leur mise à jour (2 h) est refusé
# (403), et trop de refus bloquent l'adresse. Après un échec, 6 h d'attente.
# iss_passages = « début|fin|max|hauteur max|azimut début|azimut max|azimut fin|nuages % ;… »
$fTle = Join-Path $dossier 'iss-tle.txt'

# Somme de contrôle d'une ligne de TLE (chiffres + 1 par « - », modulo 10)
function Tle-Valide([string]$l, [string]$num) {
    if ($l.Length -lt 69 -or $l.Substring(2, 5) -ne $num) { return $false }
    $s = 0; foreach ($c in $l.Substring(0, 68).ToCharArray()) { if ($c -match '\d') { $s += [int][string]$c } elseif ($c -eq '-') { $s += 1 } }
    return ($s % 10) -eq [int][string]$l[68]
}

# Le TLE : @{ l1; l2; recu } (cache iss-tle.txt), renouvelé au-delà de 20 h
function Tle-Iss {
    $c = Lire-Cles $fTle
    $l = @(); if (Test-Path $fTle) { $l = @([IO.File]::ReadAllLines($fTle, [Text.Encoding]::UTF8) | Where-Object { $_ -match '^[12] ' }) }
    $maint = Maintenant
    $vieux = -not $c['recu'] -or $maint - [long]$c['recu'] -gt 20 * 3600
    $attente = $c['echec'] -and $maint - [long]$c['echec'] -lt 6 * 3600
    if ($vieux -and -not $attente) {
        try {
            $r = (Invoke-WebRequest 'https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=TLE' -UseBasicParsing -TimeoutSec 20).Content
            $n = @($r -split "`r?`n" | Where-Object { $_ -match '^[12] ' })
            if ($n.Count -ne 2 -or -not (Tle-Valide $n[0] '25544') -or -not (Tle-Valide $n[1] '25544')) { throw 'TLE invalide' }
            $l = $n; $c = @{ recu = [string]$maint }
        } catch { $c['echec'] = [string]$maint }
        $sortie = @(foreach ($k in 'recu', 'echec') { if ($c[$k]) { "$k=$($c[$k])" } }) + $l
        [IO.File]::WriteAllLines("$fTle.tmp", [string[]]$sortie, (New-Object Text.UTF8Encoding $false))
        Move-Item "$fTle.tmp" $fTle -Force
    }
    if ($l.Count -ne 2) { throw 'pas de TLE' }
    return @{ l1 = $l[0]; l2 = $l[1] }
}

# Passages visibles sur « jours » jours à partir de t0 (instants Unix)
function Passages-Iss($tle, [double]$latDeg, [double]$lonDeg, [long]$t0, [double]$jours) {
    $rad = [Math]::PI / 180; $RE = 6378.137; $MU = 398600.4418; $J2 = 1.08262668e-3
    $l1 = $tle.l1; $l2 = $tle.l2
    $an = [int]$l1.Substring(18, 2); $an += $(if ($an -lt 57) { 2000 } else { 1900 })
    $epoque = [DateTimeOffset]::new($an, 1, 1, 0, 0, 0, [TimeSpan]::Zero).AddDays([double]::Parse($l1.Substring(20, 12), $inv) - 1).ToUnixTimeMilliseconds() / 1000.0
    $ndot2 = [double]::Parse($l1.Substring(33, 10).Trim(), $inv)
    $inc = [double]::Parse($l2.Substring(8, 8), $inv) * $rad; $raan0 = [double]::Parse($l2.Substring(17, 8), $inv) * $rad
    $ecc = [double]::Parse('0.' + $l2.Substring(26, 7), $inv); $argp0 = [double]::Parse($l2.Substring(34, 8), $inv) * $rad
    $m0 = [double]::Parse($l2.Substring(43, 8), $inv) * $rad; $nrev = [double]::Parse($l2.Substring(52, 11), $inv)
    $n0 = $nrev * 2 * [Math]::PI / 86400; $ga = [Math]::Pow($MU / ($n0 * $n0), 1 / 3); $gp = $ga * (1 - $ecc * $ecc)
    $gk = 1.5 * $J2 * [Math]::Pow($RE / $gp, 2) * $n0
    $draan = -$gk * [Math]::Cos($inc); $dargp = 0.5 * $gk * (5 * [Math]::Pow([Math]::Cos($inc), 2) - 1)
    $lat0 = $latDeg * $rad; $lon0 = $lonDeg * $rad
    $fl = 1 / 298.257223563; $e2 = $fl * (2 - $fl); $Nr = $RE / [Math]::Sqrt(1 - $e2 * [Math]::Pow([Math]::Sin($lat0), 2))
    $rc = ($Nr + 0.05) * [Math]::Cos($lat0); $zo = ($Nr * (1 - $e2) + 0.05) * [Math]::Sin($lat0)
    $sl = [Math]::Sin($lat0); $cl = [Math]::Cos($lat0)
    # hauteur du soleil (°) à l'instant t
    function SolEl([double]$t) {
        $dd = $t / 86400 + 2440587.5 - 2451545.0
        $th = ((280.46061837 + 360.98564736629 * $dd) % 360) * $rad + $lon0
        $g = ((357.529 + 0.98560028 * $dd) % 360) * $rad; $q = (280.459 + 0.98564736 * $dd) % 360
        $lam = ($q + 1.915 * [Math]::Sin($g) + 0.020 * [Math]::Sin(2 * $g)) * $rad; $ob = (23.439 - 0.00000036 * $dd) * $rad
        $ox = $rc * [Math]::Cos($th); $oy = $rc * [Math]::Sin($th)
        return [Math]::Asin(([Math]::Cos($lam) * $ox + [Math]::Cos($ob) * [Math]::Sin($lam) * $oy + [Math]::Sin($ob) * [Math]::Sin($lam) * $zo) /
            [Math]::Sqrt($ox * $ox + $oy * $oy + $zo * $zo)) / $rad
    }
    # hauteur, azimut de l'ISS et station éclairée : @(el, az, eclairee)
    function IssEtat([double]$t) {
        $dd = $t / 86400 + 2440587.5 - 2451545.0
        $th = ((280.46061837 + 360.98564736629 * $dd) % 360) * $rad + $lon0
        $g = ((357.529 + 0.98560028 * $dd) % 360) * $rad; $q = (280.459 + 0.98564736 * $dd) % 360
        $lam = ($q + 1.915 * [Math]::Sin($g) + 0.020 * [Math]::Sin(2 * $g)) * $rad; $ob = (23.439 - 0.00000036 * $dd) * $rad
        $sx = [Math]::Cos($lam); $sy = [Math]::Cos($ob) * [Math]::Sin($lam); $sz = [Math]::Sin($ob) * [Math]::Sin($lam)
        $dts = $t - $epoque; $dj = $dts / 86400
        $M = $m0 + $n0 * $dts + 2 * [Math]::PI * $ndot2 * $dj * $dj; $E = $M
        for ($i = 0; $i -lt 6; $i++) { $E = $E - ($E - $ecc * [Math]::Sin($E) - $M) / (1 - $ecc * [Math]::Cos($E)) }
        $nu = 2 * [Math]::Atan2([Math]::Sqrt(1 + $ecc) * [Math]::Sin($E / 2), [Math]::Sqrt(1 - $ecc) * [Math]::Cos($E / 2))
        $r = $ga * (1 - $ecc * [Math]::Cos($E)); $W = $raan0 + $draan * $dts; $u = $argp0 + $dargp * $dts + $nu
        $x = $r * ([Math]::Cos($W) * [Math]::Cos($u) - [Math]::Sin($W) * [Math]::Sin($u) * [Math]::Cos($inc))
        $y = $r * ([Math]::Sin($W) * [Math]::Cos($u) + [Math]::Cos($W) * [Math]::Sin($u) * [Math]::Cos($inc))
        $z = $r * [Math]::Sin($u) * [Math]::Sin($inc)
        $ox = $rc * [Math]::Cos($th); $oy = $rc * [Math]::Sin($th)
        $rx = $x - $ox; $ry = $y - $oy; $rz = $z - $zo; $st = [Math]::Sin($th); $ct = [Math]::Cos($th)
        $vs = $sl * $ct * $rx + $sl * $st * $ry - $cl * $rz; $ve = -$st * $rx + $ct * $ry; $vz = $cl * $ct * $rx + $cl * $st * $ry + $sl * $rz
        $el = [Math]::Asin($vz / [Math]::Sqrt($rx * $rx + $ry * $ry + $rz * $rz)) / $rad
        $az = ([Math]::Atan2($ve, -$vs) / $rad + 360) % 360
        $pd = $x * $sx + $y * $sy + $z * $sz
        $ecl = ($pd -gt 0) -or ([Math]::Sqrt([Math]::Pow($x - $pd * $sx, 2) + [Math]::Pow($y - $pd * $sy, 2) + [Math]::Pow($z - $pd * $sz, 2)) -gt $RE)
        return @($el, $az, $ecl)
    }
    function Visible([double]$t) { if ((SolEl $t) -ge -6) { return $false }; $e = IssEtat $t; return ($e[0] -ge 10 -and $e[2]) }
    # bord entre un instant non visible (a) et un visible (b), ou l'inverse, à 1 s près
    function Bord([double]$a, [double]$b) {
        $va = Visible $a
        while ([Math]::Abs($b - $a) -gt 1) { $m = ($a + $b) / 2; if ((Visible $m) -eq $va) { $a = $m } else { $b = $m } }
        return [long][Math]::Round($b)
    }
    $pas = 30; $fin = $t0 + $jours * 86400; $res = @(); $cour = $null; $prec = $false
    for ($t = [double]$t0; $t -lt $fin; $t += $pas) {
        $vis = Visible $t
        if ($vis -and -not $prec) { $deb = if ($t -gt $t0) { Bord ($t - $pas) $t } else { [long]$t }; $cour = @{ d = $deb; tm = $t; em = -1 } }
        if ($vis) { $e = IssEtat $t; if ($e[0] -gt $cour.em) { $cour.em = $e[0]; $cour.tm = $t } }
        if (-not $vis -and $prec -and $cour) {
            $cour.f = Bord ($t - $pas) $t
            # hauteur maximale affinée (section dorée sur ±30 s, dans le passage)
            $a = [Math]::Max($cour.d, $cour.tm - $pas); $b = [Math]::Min($cour.f, $cour.tm + $pas)
            for ($i = 0; $i -lt 12; $i++) {
                $c1 = $b - 0.618 * ($b - $a); $c2 = $a + 0.618 * ($b - $a)
                if ((IssEtat $c1)[0] -lt (IssEtat $c2)[0]) { $a = $c1 } else { $b = $c2 }
            }
            $tm = ($a + $b) / 2; $em = IssEtat $tm
            $res += , @($cour.d, $cour.f, [long][Math]::Round($tm), $em[0], (IssEtat $cour.d)[1], $em[1], (IssEtat $cour.f)[1])
            $cour = $null
        }
        $prec = $vis
    }
    return @{ passages = $res; epoque = [long]$epoque }
}

# Clés iss_* : les passages des 4 prochains jours, recalculés quand le TLE ou le
# lieu change, et toutes les 12 h (le reste du temps, ceux de la collecte d'avant)
function Cles-Iss($pos, $ancien) {
    $tle = Tle-Iss
    $ll = "$($pos['lat']),$($pos['lon'])"; $maint = Maintenant
    $x = [ordered]@{}
    $ep = [long](Passages-Iss $tle 0 0 0 0).epoque
    if ($ancien['iss_etat'] -eq 'ok' -and $ancien['iss_pour'] -eq $ll -and $ancien['iss_ep'] -eq [string]$ep -and
        $ancien['iss_calc'] -and $maint - [long]$ancien['iss_calc'] -lt 12 * 3600) {
        foreach ($k in @($ancien.Keys)) { if ($k -like 'iss_*') { $x[$k] = $ancien[$k] } }
        return $x
    }
    if ($maint - $ep -gt 5 * 86400) {               # TLE de plus de 5 jours (CelesTrak injoignable) : plus rien
        $x.iss_etat = 'perime'; $x.iss_ep = [string]$ep; $x.iss_maj = [string]$maint; return $x
    }
    $p = Passages-Iss $tle ([double]::Parse($pos['lat'], $inv)) ([double]::Parse($pos['lon'], $inv)) ($maint - 900) 4
    $x.iss_passages = (@(foreach ($q in $p.passages) {
        '{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $q[0], $q[1], $q[2], [Math]::Round($q[3]), [Math]::Round($q[4]), [Math]::Round($q[5]), [Math]::Round($q[6])
    }) -join ';')
    $x.iss_ep = [string]$ep; $x.iss_pour = $ll; $x.iss_calc = [string]$maint; $x.iss_etat = 'ok'; $x.iss_maj = [string]$maint
    return $x
}

# Nuages (%) du créneau horaire de chaque passage (8e champ), d'après la prévision
function Nuages-Passages($d, $o) {
    if (-not $d['iss_passages']) { return }
    $U = @($o.hourly.unix); $nu = @($o.hourly.cloud_cover)
    $d['iss_passages'] = (@(foreach ($p in $d['iss_passages'].Split(';')) {
        $v = @($p.Split('|') | Select-Object -First 7); $tm = [long]$v[2]; $n = ''
        for ($i = 0; $i -lt $U.Count; $i++) { if ($null -ne $U[$i] -and $U[$i] -le $tm -and $tm -lt $U[$i] + 3600 -and $null -ne $nu[$i]) { $n = [string][int]$nu[$i] } }
        ($v + $n) -join '|'
    }) -join ';')
}

# ---------------------------------------------------------------- normales et records
# climat.txt : réanalyse ERA5 du point (Open-Meteo, archive, sans clé), maille
# d'environ 25 km : ce n'est pas un thermomètre (records lissés : 28,0° le
# 23/09/1961 pour ERA5, 27,0° mesurés à Orly en 1949). Une grosse requête
# (1940 à l'an dernier, 700 Ko, ~2 200 « appels » du quota gratuit de 10 000 par
# jour) une fois par lieu, puis les 400 derniers jours chaque semaine. Un
# fichier par lieu (climat.txt, puis climat-<lat>_<lon>.txt), 3 lieux au plus :
# un aller-retour ne retélécharge rien. Après un échec de l'archive, 3 h sans
# la redemander (climat-echec.txt) : le cache sert en attendant.
#   pour=lat,lon  fin=année  maj=unix  an_maj=unix
#   N|MMJJ|normale max|normale min|record max|année|record min|année   (normales 1991-2020, ±7 jours)
#   A|AAAA-MM-JJ|max|min|pluie|code                                   (les 400 derniers jours)
$fClimat = Join-Path $dossier 'climat.txt'
$fClimatEchec = Join-Path $dossier 'climat-echec.txt'
$ARCHIVE = 'https://archive-api.open-meteo.com/v1/archive'

# Le fichier du lieu (à 0,2° près) parmi ceux déjà là, sinon celui d'un
# nouveau lieu (les plus anciens au-delà de 3 sont effacés)
function Fichier-Climat([double]$la, [double]$lo) {
    $fs = @(Get-ChildItem -Path $dossier -Filter 'climat*.txt' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'climat-echec.txt' } | Sort-Object LastWriteTime -Descending)
    foreach ($fc in $fs) {
        $p = [string](Lire-Cles $fc.FullName)['pour']
        if (-not $p) { continue }
        $q = $p.Split(',')
        if ([Math]::Abs([double]::Parse($q[0], $inv) - $la) -le 0.2 -and [Math]::Abs([double]::Parse($q[1], $inv) - $lo) -le 0.2) {
            try { $fc.LastWriteTime = Get-Date } catch {}   # (le dernier servi : gardé)
            return $fc.FullName
        }
    }
    foreach ($fc in @($fs | Select-Object -Skip 2)) { Remove-Item $fc.FullName -Force -ErrorAction SilentlyContinue }
    if (-not (Test-Path $fClimat)) { return $fClimat }
    return Join-Path $dossier ('climat-{0}_{1}.txt' -f $la.ToString('0.00', $inv), $lo.ToString('0.00', $inv))
}

function Ecrire-Climat([string]$chemin, $cles, $n, $a) {
    $sortie = @(foreach ($k in 'pour', 'fin', 'maj', 'an_maj') { "$k=$($cles[$k])" }) + $n + $a
    $tmp = "$chemin.tmp"
    [IO.File]::WriteAllLines($tmp, [string[]]$sortie, (New-Object Text.UTF8Encoding $false))
    Move-Item $tmp $chemin -Force
}

# Met à jour le fichier du lieu si besoin (sans jamais lever : en cas d'échec,
# le cache) et renvoie ses lignes @{ n = lignes N ; a = lignes A }
function Maj-Climat($pos) {
    $la = [double]::Parse($pos['lat'], $inv); $lo = [double]::Parse($pos['lon'], $inv)
    $fc = Fichier-Climat $la $lo
    $cles = Lire-Cles $fc
    $lignes = @(); if (Test-Path $fc) { $lignes = @([IO.File]::ReadAllLines($fc, [Text.Encoding]::UTF8)) }
    $n = @($lignes | Where-Object { $_ -like 'N|*' }); $a = @($lignes | Where-Object { $_ -like 'A|*' })
    $finVoulue = (Get-Date).Year - 1
    $maint = Maintenant
    $echec = 0; try { if (Test-Path $fClimatEchec) { $echec = [long](([IO.File]::ReadAllText($fClimatEchec)).Trim()) } } catch {}
    if ($maint - $echec -lt 3 * 3600) { return @{ n = $n; a = $a } }   # archive en échec il y a peu : le cache
    try {
        if (-not $cles['pour'] -or $n.Count -lt 366 -or [int]$cles['fin'] -lt $finVoulue) {
            $u = "$ARCHIVE`?latitude=$($la.ToString($inv))&longitude=$($lo.ToString($inv))&start_date=1940-01-01&end_date=$finVoulue-12-31" +
                 '&daily=temperature_2m_max,temperature_2m_min&timezone=auto'
            $r = Invoke-RestMethod $u -TimeoutSec 90
            $n = @(Normales-Records $r)
            $cles['pour'] = '{0},{1}' -f $la.ToString($inv), $lo.ToString($inv); $cles['fin'] = [string]$finVoulue; $cles['maj'] = [string]$maint
            $a = @(); $cles['an_maj'] = ''
            Ecrire-Climat $fc $cles $n $a            # tout de suite : un échec de la suite ne la perd pas
        }
        if (-not $cles['an_maj'] -or $maint - [long]$cles['an_maj'] -gt 7 * 86400) {
            $debut = (Get-Date).AddDays(-400).ToString('yyyy-MM-dd'); $fin = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
            $u = "$ARCHIVE`?latitude=$($la.ToString($inv))&longitude=$($lo.ToString($inv))&start_date=$debut&end_date=$fin" +
                 '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code&timezone=auto'
            $r = Invoke-RestMethod $u -TimeoutSec 30
            $t = @($r.daily.time); $mx = @($r.daily.temperature_2m_max); $mn = @($r.daily.temperature_2m_min)
            $pl = @($r.daily.precipitation_sum); $co = @($r.daily.weather_code)
            $a = @(for ($i = 0; $i -lt $t.Count; $i++) {
                if ($null -eq $mx[$i] -or $null -eq $mn[$i]) { continue }
                'A|{0}|{1}|{2}|{3}|{4}' -f $t[$i], (Nombre $mx[$i]), (Nombre $mn[$i]), (Nombre $pl[$i]), $co[$i]
            })
            $cles['an_maj'] = [string]$maint
            Ecrire-Climat $fc $cles $n $a
        }
    } catch {
        [IO.File]::WriteAllText($fClimatEchec, [string]$maint)
    }
    return @{ n = $n; a = $a }
}

# Lignes N (366 jours, 29 février compris) d'une réponse de l'archive quotidienne
function Normales-Records($r) {
    $t = @($r.daily.time); $mx = @($r.daily.temperature_2m_max); $mn = @($r.daily.temperature_2m_min)
    $rmax = @{}; $rmin = @{}; $smax = @{}; $smin = @{}; $nb = @{}
    for ($i = 0; $i -lt $t.Count; $i++) {
        $jour = [string]$t[$i]; $k = $jour.Substring(5, 2) + $jour.Substring(8, 2); $an = [int]$jour.Substring(0, 4)
        $vmax = $mx[$i]; $vmin = $mn[$i]
        if ($null -ne $vmax -and (-not $rmax.ContainsKey($k) -or [double]$vmax -gt $rmax[$k][0])) { $rmax[$k] = @([double]$vmax, $an) }
        if ($null -ne $vmin -and (-not $rmin.ContainsKey($k) -or [double]$vmin -lt $rmin[$k][0])) { $rmin[$k] = @([double]$vmin, $an) }
        if ($an -ge 1991 -and $an -le 2020 -and $null -ne $vmax -and $null -ne $vmin) {
            $smax[$k] = [double]$smax[$k] + [double]$vmax; $smin[$k] = [double]$smin[$k] + [double]$vmin; $nb[$k] = [int]$nb[$k] + 1
        }
    }
    # jours de l'année dans l'ordre (2000 est bissextile), normale lissée sur ±7 jours
    $ordre = @(for ($d = [DateTime]::new(2000, 1, 1); $d.Year -eq 2000; $d = $d.AddDays(1)) { $d.ToString('MMdd') })
    $N = $ordre.Count
    @(for ($i = 0; $i -lt $N; $i++) {
        $k = $ordre[$i]; $sx = 0.0; $sn = 0.0; $c = 0
        for ($o = -7; $o -le 7; $o++) { $kk = $ordre[($i + $o + $N) % $N]; if ($nb.ContainsKey($kk)) { $sx += $smax[$kk]; $sn += $smin[$kk]; $c += $nb[$kk] } }
        if (-not $c -or -not $rmax.ContainsKey($k)) { continue }
        'N|{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $k, (Nombre ($sx / $c)), (Nombre ($sn / $c)), (Nombre $rmax[$k][0]), $rmax[$k][1], (Nombre $rmin[$k][0]), $rmin[$k][1]
    })
}

# Clés clim_* du jour et du lendemain : clim_n = « normale max|normale min »,
# clim_r = « record max|année|record min|année », clim_an = « max|min|pluie|code »
# il y a un an (le 28/02 pour un 29/02)
function Cles-Climat($pos) {
    $c = Maj-Climat $pos
    # pas de normales pour ce lieu (nouveau lieu, archive en échec) : rien, plutôt que celles d'ailleurs
    if (-not @($c.n).Count) { return [ordered]@{ clim_etat = 'erreur'; clim_maj = [string](Maintenant) } }
    $x = [ordered]@{ clim_jour = (Get-Date).ToString('yyyyMMdd') }   # (après minuit, le widget prend « demain »)
    $parJour = @{}; foreach ($l in $c.n) { $v = $l.Split('|'); $parJour[$v[1]] = $v }
    foreach ($j in @(@(0, ''), @(1, '2'))) {
        $d = (Get-Date).AddDays($j[0]); $k = $d.ToString('MMdd')
        if ($parJour.ContainsKey($k)) {
            $v = $parJour[$k]
            $x["clim_n$($j[1])"] = '{0}|{1}' -f $v[2], $v[3]
            $x["clim_r$($j[1])"] = '{0}|{1}|{2}|{3}' -f $v[4], $v[5], $v[6], $v[7]
        }
    }
    $d = (Get-Date).AddYears(-1).ToString('yyyy-MM-dd')     # (AddYears ramène le 29/02 au 28/02)
    foreach ($l in $c.a) { if ($l.StartsWith("A|$d|")) { $x.clim_an = $l.Substring(13) } }
    $x.clim_etat = 'ok'; $x.clim_maj = [string](Maintenant)
    return $x
}

# ---------------------------------------------------------------- qualité de l'air
# Indice ATMO officiel de la commune et épisodes de pollution (Airparif, données
# ouvertes ODbL, en Île-de-France seulement) : air_j / air_j1 = « code|libellé|
# couleur|polluants responsables », air_epi = « J ou J+1|polluant|état;… » (hors
# « pas de dépassement »). propertyName est indispensable : sans lui, 1,2 Mo de géométrie.
$IDF = '75', '77', '78', '91', '92', '93', '94', '95'
$AIRPARIF = 'https://magellan.airparif.asso.fr/geoserver/DIDON/wfs?service=WFS&version=2.0.0&request=GetFeature&outputFormat=application/json'
function Mesure-Air($pos) {
    $x = [ordered]@{ air_pour = "$($pos['lat']),$($pos['lon'])" }
    if ([string]$pos['dep'] -notin $IDF -or -not $pos['commune']) {
        $x.air_etat = 'hors_zone'; $x.air_maj = [string](Maintenant); return $x
    }
    $auj = (Get-Date).ToString('yyyy-MM-dd'); $dem = (Get-Date).AddDays(1).ToString('yyyy-MM-dd')
    $x.air_date = $auj.Replace('-', '')            # le jour J (le widget recale J / J+1 après minuit)
    $r = Invoke-RestMethod ($AIRPARIF + '&typeNames=DIDON:indice_atmo_2020' +
        '&propertyName=date_ech,code_qual,lib_qual,coul_qual,lib_zone,code_no2,code_o3,code_pm10,code_pm25,code_so2' +
        "&CQL_FILTER=code_zone%3D%27$($pos['commune'])%27") -TimeoutSec 20
    foreach ($f in @($r.features)) {
        $p = $f.properties; $j = ([string]$p.date_ech).Substring(0, 10)
        if ($j -ne $auj -and $j -ne $dem) { continue }
        # polluants responsables : ceux dont le sous-indice atteint l'indice
        $resp = @(foreach ($pol in 'o3', 'pm10', 'pm25', 'no2', 'so2') { if ([int]$p."code_$pol" -eq [int]$p.code_qual) { $pol } }) -join ','
        $v = '{0}|{1}|{2}|{3}' -f [int]$p.code_qual, (Propre $p.lib_qual), ([string]$p.coul_qual).TrimStart('#'), $resp
        if ($j -eq $auj) { $x.air_j = $v } else { $x.air_j1 = $v }
        $x.air_zone = Propre $p.lib_zone
    }
    $e = Invoke-RestMethod ($AIRPARIF + '&typeNames=DIDON:alrt3j_idf&propertyName=date_ech,etat,echeance,lib_pol') -TimeoutSec 20
    $x.air_epi = (@(foreach ($f in @($e.features)) {
        $p = $f.properties; $j = ([string]$p.date_ech).Substring(0, 10)
        if (($j -eq $auj -or $j -eq $dem) -and [string]$p.etat -and [string]$p.etat -notmatch '^PAS DE D') {
            '{0}|{1}|{2}' -f $(if ($j -eq $auj) { 'J' } else { 'J+1' }), (Propre $p.lib_pol), (Propre $p.etat)
        } }) -join ';')
    $x.air_etat = 'ok'; $x.air_maj = [string](Maintenant)
    return $x
}

# Sable du Sahara (modèle CAMS, via Open-Meteo, sans clé) : poussières (µg/m³) et
# épaisseur optique des aérosols, maximum d'aujourd'hui et de demain :
# sable_j / sable_j1 = « poussières|épaisseur optique »
function Mesure-Sable($pos) {
    $u = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$($pos['lat'])&longitude=$($pos['lon'])" +
         '&hourly=dust,aerosol_optical_depth&timezone=auto&forecast_days=2&timeformat=unixtime'
    $r = Invoke-RestMethod $u -TimeoutSec 20
    Normaliser-Heures $r
    $x = [ordered]@{ sable_pour = "$($pos['lat']),$($pos['lon'])" }
    $heures = @($r.hourly.time); $poussieres = @($r.hourly.dust); $aod = @($r.hourly.aerosol_optical_depth)
    $auj = (Maintenant-Local $r).Substring(0, 10)
    $dem = [DateTime]::ParseExact($auj, 'yyyy-MM-dd', $inv).AddDays(1).ToString('yyyy-MM-dd', $inv)
    $x.sable_date = $auj.Replace('-', '')
    foreach ($jour in @(@($auj, 'sable_j'), @($dem, 'sable_j1'))) {
        $pm = 0.0; $am = 0.0
        for ($i = 0; $i -lt $heures.Count; $i++) {
            if (-not ([string]$heures[$i]).StartsWith($jour[0])) { continue }
            if ($null -ne $poussieres[$i]) { $pm = [Math]::Max($pm, [double]$poussieres[$i]) }
            if ($null -ne $aod[$i]) { $am = [Math]::Max($am, [double]$aod[$i]) }
        }
        $x[$jour[1]] = '{0}|{1}' -f (Nombre $pm 1), (Nombre $am 2)
    }
    $x.sable_etat = 'ok'; $x.sable_maj = [string](Maintenant)
    return $x
}

# Indice pollen officiel de la commune (Atmo France, sans clé ; publié en fin de
# journée pour le lendemain, parfois plusieurs jours d'un coup) : celui du jour,
# sinon le plus récent d'avant, sinon le plus proche à venir. pol_taxons =
# « gram:2,arm:2,… » (1 à 6)
function Mesure-Pollens($pos) {
    $x = [ordered]@{ pol_pour = "$($pos['lat']),$($pos['lon'])" }
    if (-not $pos['commune'] -or [string]$pos['dep'] -like '97*') {
        $x.pol_etat = 'hors_zone'; $x.pol_maj = [string](Maintenant); return $x
    }
    $u = 'https://data.atmo-france.org/geoserver/ind_pol/ows?service=WFS&version=2.0.0&request=GetFeature' +
         '&typeNames=ind_pol:ind_national_pol&outputFormat=application/json' +
         '&propertyName=date_ech,code_qual,lib_qual,pollen_resp,alerte,code_aul,code_boul,code_oliv,code_gram,code_arm,code_ambr,source' +
         "&CQL_FILTER=code_zone%3D%27$($pos['commune'])%27&sortBy=date_ech+D&count=5"
    $r = Invoke-RestMethod $u -TimeoutSec 30
    $auj = (Get-Date).ToString('yyyy-MM-dd')
    $fs = @($r.features | Where-Object { $_ })                    # (du plus récent au plus ancien)
    $f = @($fs | Where-Object { ([string]$_.properties.date_ech).Substring(0, 10) -le $auj })[0]
    if (-not $f -and $fs.Count) { $f = $fs[-1] }
    if (-not $f) { $x.pol_etat = 'sans_donnee' }
    else {
        $p = $f.properties
        $x.pol_date = ([string]$p.date_ech).Substring(0, 10)
        $x.pol_code = [string][int]$p.code_qual
        $x.pol_lib = Propre $p.lib_qual
        $x.pol_alerte = $(if ($p.alerte) { '1' } else { '0' })
        $x.pol_taxons = (@(foreach ($t in 'aul', 'boul', 'oliv', 'gram', 'arm', 'ambr') { "{0}:{1}" -f $t, [int]$p."code_$t" }) -join ',')
        $x.pol_source = Propre $p.source
        $x.pol_etat = 'ok'
    }
    $x.pol_maj = [string](Maintenant)
    return $x
}

if ($MyInvocation.InvocationName -eq '.') { return }

New-Item -ItemType Directory -Force $dossier | Out-Null
# recherche d'une 2e ville (menu du widget) : rien d'autre
if ($ChercherVille) { Chercher-Ville $ChercherVille (Join-Path $dossier 'recherche-ville.txt'); exit 0 }
# calendrier d'abord (rapide quand il est à jour), sans jamais bloquer la météo
if ($ZoneVacances) { try { Maj-Calendrier $ZoneVacances $ForcerCalendrier.IsPresent | Out-Null } catch {} }
if ($CalendrierSeul) { exit 0 }

# ---------------------------------------------------------------- position
$pos = Lire-Cles $fPosition
$age = if ($pos['date']) { ((Maintenant) - [long]$pos['date']) / 3600.0 } else { [double]::MaxValue }

if ($ForcerPosition -or $age -ge $RAFRAICHIR_POSITION_H) {
    $p = Position-Windows
    if (-not $p) {
        # Pas de Wi-Fi exploitable : on garde l'ancienne position Wi-Fi si
        # elle est encore raisonnable, plutôt qu'une position IP (VPN).
        if ($pos['source'] -eq 'wifi' -and $age -lt $GARDER_POSITION_WIFI_H) { $p = $null }
        else { $p = Position-IP }
    }
    if ($p) {
        $ville = Nom-Ville $p.lat $p.lon
        if (-not $ville -and $p.ville) { $ville = $p.ville }
        $date = Maintenant
        if (-not $ville) {
            # Géocodage en échec (service ou réseau) : si on n'a pas bougé
            # (~5 km), on garde l'ancien nom ; sinon on réessaie à la collecte
            # suivante (15 min) au lieu d'afficher un lieu vide pendant 3 h.
            # Marge de 10 min et non 15 : localisation et géocodeurs ont déjà
            # pris plusieurs secondes avant que $date soit lue.
            if ($pos['ville'] -and $pos['lat'] -and
                [Math]::Abs([double]$p.lat - [double]::Parse($pos['lat'], $inv)) -lt 0.05 -and
                [Math]::Abs([double]$p.lon - [double]::Parse($pos['lon'], $inv)) -lt 0.07) { $ville = $pos['ville'] }
            else { $date = $date - [long]($RAFRAICHIR_POSITION_H * 3600) + 600 }
        }
        $pos = [ordered]@{
            lat    = ([double]$p.lat).ToString($inv)
            lon    = ([double]$p.lon).ToString($inv)
            ville  = $ville
            source = $p.source
            date   = $date
        }
        Ecrire-Cles $fPosition $pos
    }
}

if (-not $pos['lat']) { exit 1 }   # aucune position connue : rien à afficher

# ---------------------------------------------------------------- météo
# La réponse brute est gardée dans meteo.json : si le réseau tombe, le résumé
# est recalculé à l'heure actuelle à partir de cette dernière prévision, pour
# ne pas laisser affiché un « Pluie probable dans l'heure » devenu faux.
$fCache = Join-Path $dossier 'meteo.json'
$utf8 = New-Object Text.UTF8Encoding $false
$ancien = Lire-Cles $fDonnees             # repli des options en cas d'échec
try {
    $u = "https://api.open-meteo.com/v1/forecast?latitude=$($pos['lat'])&longitude=$($pos['lon'])" +
         "&current=temperature_2m,apparent_temperature,weather_code,is_day,precipitation,wind_speed_10m,wind_direction_10m,relative_humidity_2m" +
         "&hourly=weather_code,precipitation_probability,precipitation,cloud_cover,is_day,temperature_2m,wind_speed_10m,wind_direction_10m,uv_index" +
         "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum," +
         "wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,uv_index_max,sunrise,sunset,moonrise,moonset&timezone=auto&forecast_days=7" +
         "&minutely_15=precipitation&forecast_minutely_15=12&timeformat=unixtime"
    $brut = (Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 20).Content
    $m = $brut | ConvertFrom-Json
    Normaliser-Heures $m                  # heures locales justes (voir Normaliser-Heures)

    # un résumé raté ne doit pas priver de la météo
    $resume = try { Resume $m } catch { @{ texte = ''; maximum = ''; texte_jour = ''; maximum_jour = '' } }
    $ext = try { Extraits $m } catch { [ordered]@{} }
    try { Ecrire-Previsions $m } catch {}

    $d = [ordered]@{
        ville    = $pos['ville']
        source   = $pos['source']
        temp     = ([double]$m.current.temperature_2m).ToString($inv)
        ressenti = ([double]$m.current.apparent_temperature).ToString($inv)
        code     = [string]$m.current.weather_code
        jour     = [string]$m.current.is_day
        min      = ([double]$m.daily.temperature_2m_min[0]).ToString($inv)
        max      = ([double]$m.daily.temperature_2m_max[0]).ToString($inv)
        fuseau   = [string]$m.timezone
        lat      = $pos['lat']                 # hémisphère (sens de la lune)
        lon      = $pos['lon']                 # calculs du ciel faits sur le PC (planètes)
        resume   = $resume.texte
        maximum  = $resume.maximum
        max_jour = [string]$resume.jour     # jour du maximum annoncé (demain après 17 h)
        resume_jour  = $resume.texte_jour   # le résumé sans la pluie imminente (quand la pastille la donne)
        maximum_jour = $resume.maximum_jour
        pluie15  = Pluie-15 $m              # pluie par quart d'heure des 3 prochaines heures (« pluie dans l'heure »)
        maj      = Maintenant
    }
    foreach ($cle in $ext.Keys) { $d[$cle] = $ext[$cle] }
    # la météo fraîche d'abord, avec les options de la collecte d'avant : si les
    # services des options traînent (le widget coupe la collecte au bout de
    # 180 s), elle n'est pas perdue
    $tot = [ordered]@{}; foreach ($k in $d.Keys) { $tot[$k] = $d[$k] }
    foreach ($o in @(@($Ville2, 'v2_'), @($Vigilance, 'vig_'), @($Seine, 'seine_'), @($Air, 'air_'), @($Sable, 'sable_'),
                     @($Pollens, 'pol_'), @($Climat, 'clim_'), @($Iss, 'iss_'))) {
        if ($o[0]) { foreach ($k in @($ancien.Keys)) { if ($k -like "$($o[1])*") { $tot[$k] = $ancien[$k] } } }
    }
    Ecrire-Cles $fDonnees $tot
    Ajouter-Extras $d $ancien $pos
    try { Nuages-Passages $d $m } catch {}
    Ecrire-Cles $fDonnees $d
    [IO.File]::WriteAllText("$fCache.tmp", $brut, $utf8)
    Move-Item "$fCache.tmp" $fCache -Force
} catch {
    # Réseau en panne : la météo affichée reste la dernière connue (« maj » ne
    # change pas, le widget indique son âge), seul le résumé est recalculé.
    try {
        $d = Lire-Cles $fDonnees
        if ((Test-Path $fCache) -and $d['maj']) {
            $c = [IO.File]::ReadAllText($fCache, $utf8) | ConvertFrom-Json
            Normaliser-Heures $c              # (un cache d'avant 2.17.2 est en heures ISO : converti aussi)
            # « current » décrit le ciel de la dernière collecte réussie, pas
            # celui de maintenant : on le remplace par le créneau horaire qui
            # couvre l'heure en cours (celui de 15:00 décrit 14 h-15 h), ou on
            # le retire si la prévision ne va pas jusque-là.
            $k = (Dernier-Creneau $c) + 1; $tc = @($c.hourly.time)
            $c.PSObject.Properties.Remove('current')
            if ($k -gt 0 -and $k -lt $tc.Count) {
                $c | Add-Member current ([pscustomobject]@{
                    weather_code   = @($c.hourly.weather_code)[$k]
                    precipitation  = @($c.hourly.precipitation)[$k]
                    temperature_2m = @($c.hourly.temperature_2m)[$k] })
            }
            $r = Resume $c
            $d['resume'] = $r.texte
            $d['maximum'] = $r.maximum
            $d['max_jour'] = [string]$r.jour
            $d['resume_jour'] = $r.texte_jour
            $d['maximum_jour'] = $r.maximum_jour
            # heures à venir et soleil recalculés aussi (le vent « actuel » reste celui de la dernière collecte)
            $ext = try { Extraits $c } catch { [ordered]@{} }
            foreach ($cle in 'lever', 'coucher', 'lever2', 'coucher2', 'lune_lever', 'lune_coucher', 'lune_lever2', 'lune_coucher2', 'heures', 'uv',
                'jour_duree', 'jour_duree2', 'uv3', 'uv6', 'nuits') { if ($ext.Contains($cle)) { $d[$cle] = $ext[$cle] } }
            # min et max du jour (après minuit, ceux d'hier fausseraient normales et records)
            $j = Index-Jour $c; $tn = @($c.daily.temperature_2m_min); $tx = @($c.daily.temperature_2m_max)
            if ($null -ne $tn[$j] -and $null -ne $tx[$j]) { $d['min'] = ([double]$tn[$j]).ToString($inv); $d['max'] = ([double]$tx[$j]).ToString($inv) }
            try { Ecrire-Previsions $c } catch {}
            Ecrire-Cles $fDonnees $d                  # le résumé recalculé d'abord (voir plus haut)
            Ajouter-Extras $d $d $pos
            try { Nuages-Passages $d $c } catch {}
            Ecrire-Cles $fDonnees $d
        }
    } catch {}
    exit 2
}
