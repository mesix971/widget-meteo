#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off      ; instance unique gérée par FermerAutresInstances (voir Demarrer)
Persistent

; =============================================================================
;  Widget horloge + météo sur le bureau, façon widget Android
;
;  À gauche la température, le lieu et un résumé (« Généralement ensoleillé
;  demain. Maximum 26 ° ») ; à droite une illustration qui suit la météo du
;  moment, la date et l'heure en grand. Texte posé directement sur le fond
;  d'écran, avec une ombre douce pour rester lisible sur un fond clair.
;
;  Position détectée toute seule (localisation Wi-Fi de Windows), météo
;  Open-Meteo : c'est widget-meteo-donnees.ps1 qui collecte, toutes les 15 min.
;
;  Se déplace en le faisant glisser à la souris ; un clic sur l'illustration ou
;  la température ouvre les prévisions détaillées. Clic droit dessus (ou sur
;  l'icône de la zone de notification) : un petit menu (prévisions, Mes jours,
;  Réglages…) ; la fenêtre Réglages range toutes les options par catégories
;  (widget-meteo-reglages.ahk). Maj + clic droit : l'ancien menu complet.
;
;  Thèmes : trois styles (Android, iPhone, Épuré) et cinq couleurs (blanc,
;  sombre, automatique selon le fond, couleurs du fond d'écran, selon le
;  soleil). L'effet profondeur fait passer l'heure derrière le sujet du fond
;  d'écran, comme sur l'écran verrouillé de l'iPhone : widget-meteo-fond.py
;  détoure le sujet (modèle BiRefNet, en local) à chaque changement de fond.
;
;  En option : une rangée « prochaines heures » (avec lever et coucher du
;  soleil), un fond d'écran qui suit la météo et l'heure (variantes de ta
;  photo : nuit, crépuscule, pluie, neige…) et des animations légères.
;  Modules : widget-meteo-previsions.ahk, widget-meteo-animation.ahk.
; =============================================================================

VERSION := "2.31.2"

; ---------- Mise en page ----------
; Tout est exprimé en fractions de HC, la hauteur du bloc de contenu (du haut
; de l'illustration à la ligne de base de l'heure), mesurée sur le widget
; Android d'origine. HC et PAD sont en pixels à 100 %, multipliés ensuite par
; l'échelle de l'écran et la taille choisie (Taille, de 60 à 200 %).
; La largeur du contenu vaut 2,0 HC à 100 % de largeur (LargeurPct) : voir
; LargeurContenu() ; la mise en page s'y adapte (colonnes, résumé, créneaux).
HC      := 200
PAD     := 14            ; marge autour du contenu (laisse la place à l'ombre)
HAUTEUR := 1.035 * HC + 2 * PAD
LIGNE_HEURES := 0.40     ; hauteur ajoutée par la rangée « prochaines heures » (en HC)
LIGNE_SOLEIL := 0.15     ; hauteur ajoutée par la ligne lever / coucher, quand la rangée est masquée
LIGNE_BANDE  := 0.125    ; hauteur d'une ligne de la bande d'infos sous le widget (2e ville…)

MARGE      := 28         ; distance au bord de l'écran pour la position par défaut
METEO_MIN  := 15         ; rafraîchissement de la météo (minutes)
PERIME_MIN := 60         ; au-delà, la météo est signalée comme ancienne
RESUME_MAX := 360        ; au-delà, on n'affiche plus de résumé (le .ps1 le recalcule
                         ; même hors ligne, mais sur une prévision de plus en plus vieille)
TAILLES    := [80, 100, 125, 150, 200]   ; préréglages du menu, et aimants du redimensionnement
TAILLE_MIN := 60         ; % : en dessous, les plus petits textes deviennent illisibles
TAILLE_MAX := 200        ; % : au-delà, le redessin de chaque minute devient trop lourd
LARG_MIN   := Map("android", 1.65, "epure", 1.65, "iphone", 1.80, "lettres", 1.65, "analogique", 1.65)   ; largeur de contenu mini (en HC) : l'heure doit tenir
LARG_MAX   := 3.5        ; largeur de contenu maxi (en HC), soit 175 %
AIMANT_PCT := 2          ; % : distance à laquelle la taille s'aimante sur un préréglage (Maj : pas d'aimant)
OPACITES   := [0, 20, 35, 50]
STYLES     := [["android", "Android"], ["iphone", "iPhone"], ["epure", "Épuré (heure fine)"],
               ["lettres", "En toutes lettres"], ["analogique", "Analogique"]]
PRECISIONS := [["minute", "À la minute près"], ["cinq", "Arrondie aux 5 minutes"],
               ["points", "Arrondie aux 5 minutes, avec points des minutes"]]
DISPOS_CADRAN := [["cote", "Météo à côté du cadran"], ["dessous", "Météo sous le cadran"]]
LIB_OPT_LETTRES := "Options « En toutes lettres »"
LIB_OPT_CADRAN  := "Options « Analogique »"
LIB_MOMENT      := "Préciser du matin, de l'après-midi, du soir"
LIB_CHIFFRES    := "Chiffres 12, 3, 6 et 9"
LIB_CALENDRIER := "Calendrier", LIB_SEMAINE := "Numéro de semaine", LIB_FERIES := "Jours fériés"
LIB_VACANCES := "Vacances scolaires", LIB_COMPTES := "Comptes à rebours"
LIB_AJOUT := "Ajouter un compte à rebours…", LIB_SUPPR := "Supprimer un compte à rebours"
LIB_ZONE := "Zone des vacances", LIB_CAL_PREV := "Aussi dans les prévisions détaillées"
LIB_JOURS := "Mes jours (travail, congés…)…", LIB_JOURS_MARQUE := "Date du jour à la couleur de son type"
JOURS_MARQUES := [["jour", "Le jour en couleur (« Jeudi »)"], ["souligne", "Soulignée"], ["surligne", "Surlignée (façon feutre)"], ["aucune", "Sans marque"]]
JOURS_PALETTE := [["3987E5", "Bleu"], ["30D158", "Vert"], ["FF9F0A", "Orange"], ["FF453A", "Rouge"], ["BF5AF2", "Violet"],
    ["FF375F", "Rose"], ["FFD60A", "Jaune"], ["40C8E0", "Turquoise"], ["5E5CE6", "Indigo"], ["AC8E68", "Marron"], ["98989D", "Gris"]]
JOURS_TYPES_MAX := 12
LIB_ANNIV := "Anniversaires", LIB_ANNIV_AJOUT := "Ajouter un anniversaire…", LIB_ANNIV_MOI := "Mon anniversaire…"
LIB_ANNIV_SUPPR := "Supprimer", LIB_CONFETTIS := "Confettis le jour J", LIB_CONFETTIS_VOIR := "Voir les confettis"
ANNIV_MAX := 30
C_ANNIV := 0xFFFF6FA8     ; rose des anniversaires (prévisions, Mes jours)
FETE_DUREE := 3000, FETE_PAS := 33, FETE_NB := 110   ; confettis : durée (ms), pas (ms, ~30 i/s), nombre
FETE_COULEURS := [0xFFFF453A, 0xFFFFD60A, 0xFF30D158, 0xFF40C8E0, 0xFFBF5AF2, 0xFFFF9F0A, 0xFFFF6FA8]
; zones des vacances scolaires (académies vérifiées dans le calendrier officiel)
ZONES := [["A", "Zone A (Bordeaux, Lyon, Grenoble…)"], ["B", "Zone B (Lille, Nantes, Strasbourg…)"],
    ["C", "Zone C (Créteil, Paris, Versailles…)"]]
LIB_VILLE2 := "Deuxième ville", LIB_V2_CHOISIR := "Choisir la ville…", LIB_V2_WIDGET := "Dans le widget"
LIB_V2_PREV := "Dans les prévisions détaillées", LIB_V2_OUBLIER := "Oublier cette ville"
LIB_VIGILANCE := "Vigilance", LIB_VIG := "Vigilance météo du département", LIB_VIG_JAUNE := "Dès la vigilance jaune"
LIB_VIG_ORANGE := "Orange et rouge seulement", LIB_CARTE_VIG := "Carte de vigilance Météo-France…"
LIB_METEOALARM := "Source : MeteoAlarm…", ETAT_VIG_VIDE := "      ↳ …"
URL_VIGILANCE := "https://vigilance.meteofrance.fr/fr", URL_METEOALARM := "https://meteoalarm.org/en/live/region/FR"
C_VIG    := Map(2, 0xFFFFDA22, 3, 0xFFFF9300, 4, 0xFFFF0000)   ; couleurs officielles (MeteoAlarm)
NOMS_NIV := Map(2, "jaune", 3, "orange", 4, "rouge")
LIB_ECRAN := "Écran et batterie", LIB_NUIT := "Mode nuit (façon StandBy)"
NUIT_MODES := [["0", "Désactivé"], ["soleil", "Du coucher au lever du soleil"], ["plage", "Sur une plage horaire"]]
LIB_NUIT_DECALAGE := "Commencer après le coucher", LIB_NUIT_PLAGE := "Choisir la plage horaire…"
NUIT_DECALAGES := [[0, "À l'heure du coucher"], [30, "30 min après"], [60, "1 h après"], [120, "2 h après"]]
LIB_NUIT_INTENSITE := "Intensité", NUIT_INTENSITES := [60, 40, 25]
LIB_NUIT_TEINTE := "Teinte", NUIT_TEINTES := [["normale", "Couleurs habituelles"], ["rouge", "Rouge sombre (façon StandBy)"], ["ambre", "Ambre"]]
LIB_NUIT_SURVOL := "Pleine intensité au survol (10 s)", LIB_NUIT_ESSAI := "Essayer pendant 10 secondes"
NUIT_PLAGE_DEFAUT := "22:00-07:00"
LIB_OLED := "Anti-marquage OLED (micro-décalage)"
OLED_MODES := [[0, "Désactivé"], [1, "1 px"], [2, "2 px"], [3, "3 px"]]
ID_TIC_MINUTE := 0x4D6E, ID_TIC_VISIBILITE := 0x5669   ; minuteurs Windows (fenêtre du script)
LIB_SOBRE := "Mode sobre (batterie)", LIB_SOBRE_ON := "Activer le mode sobre"
SOBRE_CASES := [["pause", "Pause quand l'écran est éteint ou le widget caché"], ["anim", "Sur batterie : animations en pause"],
    ["meteo", "Sur batterie : météo toutes les 30 min"], ["ambiance", "Sur batterie : nouveaux fonds d'ambiance au retour du secteur"]]
MARGE_MASQUE := 8        ; px : découpe du masque élargie de 2 × 3 px d'orbite + 2, gardée en cache
; « En toutes lettres » : bande de la phrase (en HC), interligne et moment (en capitales)
LETTRES_T := 0.155, LETTRES_B := 0.72, LETTRES_PAS := 1.48, LETTRES_QUAL := 0.62, LETTRES_QUAL_ECART := 0.25
COUVERTURE_MAX_LIGNE := 0.30   ; « En toutes lettres » : au-delà, une ligne cachée par le sujet devient illisible
; « Analogique » : rayon du cadran, colonne de la météo et écart (en HC), hauteur ajoutée « dessous »
CADRAN_R_MAX := 0.48, CADRAN_R_MIN := 0.40, CADRAN_COL_MIN := 0.85, CADRAN_ECART := 0.08, CADRAN_DESSOUS := 0.37
COULEURS   := [["blanc", "Blanc"], ["sombre", "Sombre"], ["auto", "Automatique (selon le fond d'écran)"],
               ["fond", "Couleurs du fond d'écran"], ["soleil", "Selon le soleil (sombre le jour, blanc la nuit)"]]
LIB_PROFONDEUR := "Effet profondeur (l'heure derrière le sujet)"
COUVERTURE_MAX := 0.45   ; sujet cachant plus que ça de l'heure : pas d'effet (comme sur iPhone)
CLAIR_MIN      := 0.60   ; luminosité moyenne du fond au-delà de laquelle « Automatique » passe au texte sombre
AIMANT         := 24     ; px (à 100 %) : distance à laquelle le widget s'aimante au centre de l'écran
URL_MODELE     := "https://github.com/danielgatis/rembg/releases/download/v0.0.0/BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx"
TAILLE_MODELE  := 224005088
ETAT_VIDE      := "      ↳ …"   ; libellé de départ de la ligne d'état de l'effet profondeur
LIB_AMBIANCE   := "Fond d'écran selon la météo et l'heure"
LIB_HEURES     := "Prochaines heures"
LIB_SOLEIL     := "Lever et coucher du soleil"
LIB_DUREE      := "Durée du jour et heures d'UV"
LIB_CAL_HEURE  := "Changement d'heure", LIB_CAL_SAISONS := "Équinoxes et solstices"
LIB_UV         := "UV fort (pastille les jours d'indice 6 et plus)"
LIB_AIR        := "Qualité de l'air", LIB_AIR_SABLE := "Sable du Sahara (modèle CAMS)"
LIB_AIR_POLLENS := "Pollens (indice officiel Atmo France)", LIB_AIR_CARTE := "Carte d'Airparif…"
URL_AIRPARIF   := "https://www.airparif.fr"
LIB_CLIMAT     := "Normales et records", LIB_CLIMAT_PREV := "Dans les prévisions détaillées"
LIB_CLIMAT_WIDGET := "Normale à côté du maximum (écart de 3° ou plus)", LIB_CLIMAT_RECORD := "Pastille les jours proches d'un record"
LIB_CIEL       := "Ciel", LIB_ISS := "Passages de la station spatiale (ISS)", LIB_ISS_HMIN := "Hauteur minimale des passages"
LIB_PLANETES   := "Planètes visibles ce soir (prévisions)", LIB_ETOILES := "Étoiles filantes (grandes nuits dans le calendrier)"
ISS_HMINS      := [[10, "Tous les passages visibles (10° et plus)"], [20, "20° et plus"], [40, "Beaux passages seulement (40° et plus)"]]
; qualité de l'air : seuils de la pastille (épisodes seulement, dès « Mauvais », dès « Dégradé », désactivée)
AIR_MODES := [["episode", "Épisodes de pollution seulement"], ["4", "Dès l'indice « Mauvais »"],
    ["3", "Dès l'indice « Dégradé »"], ["0", "Désactivée"]]
; sable du Sahara : seuils choisis sur l'épisode du 6-8 avril 2024 en Île-de-France (poussières 12 à
; 16 µg/m³, épaisseur optique 0,62 à 0,94, contre 0,12 à 0,21 d'ordinaire)
SABLE_POUSSIERES := 10, SABLE_AOD := 0.45
POLLENS_NOMS := Map("aul", "aulne", "boul", "bouleau", "oliv", "olivier", "gram", "graminées", "arm", "armoise", "ambr", "ambroisie")
POLLUANTS := Map("o3", "ozone", "pm10", "particules PM10", "pm25", "particules fines", "no2", "dioxyde d'azote", "so2", "dioxyde de soufre")
LIB_LUNE       := "Phase réelle de la lune"
LIB_LUNE_LEVER := "Lever et coucher de la lune"
LIB_POLICE_TEMP := "Même police pour la température"
RENDUS := [["plein", "Plein"], ["contour", "Contour (chiffres évidés)"], ["degrade", "Dégradé"],
    ["verre", "Verre dépoli (fond d'écran flouté)"]]
EPAIS_CONTOUR  := 0.045  ; trait du rendu Contour, en capitale de l'heure
EPAIS_LISERE   := 0.022  ; liseré clair du rendu Verre, en capitale de l'heure
VERRE_ECLAIR   := 0.42   ; le fond flouté est éclairci de 42 % vers la couleur d'accent
VERRE_ECHELLE  := 2      ; fond\verre.png est en demi-résolution
; Polices de l'heure (menu Heure ▸ Police) : [nom de famille GDI+ exact, 31 caractères
; au plus, « |1 » = gras ; libellé] ; [« - »] = séparateur. Toutes vérifiées : chiffres
; alignés (pas elzéviriens), contours remplis en enroulement (voir CheminTexte).
POLICES_HEURE := [["", "Selon le style"], ["-"],
    ["Segoe UI Variable Display Light", "Segoe UI Variable fine"], ["Segoe UI Variable Display", "Segoe UI Variable normale"],
    ["Segoe UI Variable Display Semib", "Segoe UI Variable semi-grasse"], ["Segoe UI Variable Display|1", "Segoe UI Variable grasse"], ["-"],
    ["Bahnschrift Light", "Bahnschrift fine"], ["Bahnschrift", "Bahnschrift"], ["Bahnschrift|1", "Bahnschrift grasse"],
    ["Bahnschrift Condensed", "Bahnschrift étroite"], ["Bahnschrift Condensed|1", "Bahnschrift étroite grasse"], ["-"],
    ["Cascadia Mono Light", "Cascadia Mono fine"], ["Cascadia Mono", "Cascadia Mono"], ["Cascadia Mono SemiBold", "Cascadia Mono semi-grasse"], ["-"],
    ["Segoe Print", "Manuscrite (Segoe Print)"], ["Segoe Print|1", "Manuscrite grasse (Segoe Print)"],
    ["Ink Free", "Feutre (Ink Free)"], ["Segoe Script", "Calligraphiée (Segoe Script)"]]
POLICES_AUTRES := [["Segoe UI Black", "Segoe UI Black"], ["Century Gothic", "Century Gothic"], ["Rockwell", "Rockwell"],
    ["Stencil", "Stencil"], ["Consolas", "Consolas"]]
LUNE_VOILE0    := 0x10   ; opacité de la lumière cendrée (partie sombre de la lune) : 0x10 à pleine lune…
LUNE_VOILE     := 0x1C   ; …plus ceci à la nouvelle lune
LIB_ANIMATIONS := "Animations légères (un peu plus de batterie)"
LIB_TRAVERSANT := "Laisser passer les clics (widget inerte)"
LIB_VERROU     := "Verrouiller la position et la taille"
LIB_EDITION    := "Redimensionner à la souris…"
LIB_LARGEUR0   := "Largeur d'origine"
; Actus et marchés (widget-meteo-marches.ahk) : catalogues [identifiant, nom], tous vérifiés le
; 2026-09-27 (CoinGecko pour les cryptos, Yahoo Finance pour les indices, actions et taux US, BCE
; pour les taux européens : quotidien pour la zone euro, moyenne du mois pour les pays)
MARCHES_CRYPTOS := [["bitcoin", "Bitcoin"], ["ethereum", "Ethereum"], ["solana", "Solana"], ["ripple", "XRP"],
    ["binancecoin", "BNB"], ["cardano", "Cardano"], ["dogecoin", "Dogecoin"], ["litecoin", "Litecoin"]]
MARCHES_INDICES := [["^FCHI", "CAC 40"], ["^GSPC", "S&P 500"], ["^IXIC", "Nasdaq"], ["^DJI", "Dow Jones"],
    ["^GDAXI", "DAX"], ["^STOXX50E", "Euro Stoxx 50"], ["^FTSE", "FTSE 100"], ["^N225", "Nikkei 225"]]
MARCHES_ACTIONS := [["MC.PA", "LVMH"], ["TTE.PA", "TotalEnergies"], ["AIR.PA", "Airbus"], ["RMS.PA", "Hermès"],
    ["OR.PA", "L'Oréal"], ["SAN.PA", "Sanofi"], ["SU.PA", "Schneider Electric"], ["BNP.PA", "BNP Paribas"],
    ["CS.PA", "AXA"], ["AI.PA", "Air Liquide"], ["SAF.PA", "Safran"], ["STLAP.PA", "Stellantis"], ["ORA.PA", "Orange"],
    ["RNO.PA", "Renault"], ["DG.PA", "Vinci"], ["EL.PA", "EssilorLuxottica"], ["KER.PA", "Kering"],
    ["GLE.PA", "Société Générale"], ["ACA.PA", "Crédit Agricole"], ["CAP.PA", "Capgemini"],
    ["CW8.PA", "ETF Amundi MSCI World"], ["AAPL", "Apple"], ["MSFT", "Microsoft"], ["NVDA", "Nvidia"],
    ["AMZN", "Amazon"], ["GOOGL", "Alphabet (Google)"], ["META", "Meta"], ["TSLA", "Tesla"], ["JPM", "JPMorgan"],
    ["V", "Visa"], ["NFLX", "Netflix"], ["AMD", "AMD"], ["BRK-B", "Berkshire Hathaway"]]
MARCHES_TAUX := [["^TNX", "États-Unis 10 ans"], ["^TYX", "États-Unis 30 ans"], ["^FVX", "États-Unis 5 ans"],
    ["zone10", "Zone euro 10 ans"], ["fr10", "France 10 ans (OAT)"], ["de10", "Allemagne 10 ans (Bund)"],
    ["it10", "Italie 10 ans"]]
FICHE_W := 780, FICHE_H := 760      ; fiche d'une actualité (px logiques, widget-meteo-actu.ahk)
MARCHES_W := 900, MARCHES_H := 700   ; fenêtre « Actus et marchés » (px logiques)
MARCHES_S := 300         ; s entre deux collectes des marchés et des actus (120 tableau de bord ouvert, 900 en mode sobre sur batterie)
ACTUS_FLUX := Map("une", "Le Monde", "fil", "franceinfo", "monde", "Le Monde", "f24", "France 24")
PHRASE_S := 300          ; s entre deux phrases d'anglais (et deux titres à la une) sur le widget
; Fenêtre « Réglages » (widget-meteo-reglages.ahk) : largeur, barre latérale, hauteur (px logiques)
REGL_W := 720, REGL_SB := 200, REGL_H := 640, REGL_H_MIN := 440
REGLAGES_CATS := [{id: "apparence", nom: "Apparence", c: 0xFFAF52DE}, {id: "heure", nom: "Heure", c: 0xFF1FA2B6},
    {id: "meteo", nom: "Météo", c: 0xFF3987E5}, {id: "calendrier", nom: "Calendrier", c: 0xFFE5453A},
    {id: "alertes", nom: "Alertes", c: 0xFFE3A008}, {id: "ciel", nom: "Ciel", c: 0xFF5E5CE6},
    {id: "marches", nom: "Marchés", c: 0xFFE0457B}, {id: "actus", nom: "Actus", c: 0xFF8E6E53},
    {id: "transports", nom: "Transports", c: 0xFF4A6FA5},
    {id: "anglais", nom: "Anglais", c: 0xFFF08A00},
    {id: "ecran", nom: "Écran et batterie", c: 0xFF2FA84F}, {id: "position", nom: "Position et taille", c: 0xFF7C7C82}]
ANIM_IMAGES    := 48     ; images par boucle d'animation (24 pour une grande illustration)
ANIM_BOUCLE    := 4000   ; ms : durée d'une boucle d'animation
SEUIL_GLISSER  := 4      ; px (à 100 %) : en deçà, un appui-relâché est un clic, pas un glisser
TOUCHE_ECHAP   := "~Esc" ; annule un geste, termine le mode redimensionnement ; « ~ » : jamais avalée

; Modes de test reconnus, et réglages imposables par nom=valeur : [variable, type]
MODES_TEST := Map("/apercu", 1, "/icones", 1, "/previsions", 1, "/animation", 1, "/testgeste", 1, "/lunes", 1, "/phrases", 1,
    "/testferies", 1, "/villes", 1, "/testnuit", 1, "/testorbite", 1, "/testtic", 1, "/testsobre", 1,
    "/jours", 1, "/testjours", 1, "/testlumiere", 1, "/testanniv", 1, "/fete", 1, "/testciel", 1,
    "/reglages", 1, "/testreglages", 1, "/testfenetre", 1, "/marches", 1, "/testmarches", 1, "/testanglais", 1, "/testtableau", 1, "/testrer", 1, "/testpluie", 1, "/fiche", 1, "/testfiche", 1)
ARGS_TEST  := Map("style", ["Style", "texte"], "couleur", ["Couleur", "texte"], "profondeur", ["Profondeur", "bool"],
    "heures", ["Heures", "bool"], "soleil", ["Soleil", "bool"], "taille", ["Taille", "entier"],
    "lunelever", ["LuneLever", "bool"], "police", ["PoliceHeure", "texte"], "rendu", ["RenduHeure", "texte"],
    "lettres", ["LettresPrecision", "texte"], "moment", ["LettresMoment", "bool"], "cadran", ["CadranMeteo", "texte"],
    "chiffres", ["CadranChiffres", "bool"], "semaine", ["CalSemaine", "bool"], "feries", ["CalFeries", "bool"],
    "vacances", ["CalVacances", "bool"], "comptes", ["CalComptes", "bool"], "policetemp", ["PoliceTemp", "bool"],
    "largeur", ["LargeurPct", "entier"], "opacite", ["Opacite", "entier"], "animations", ["Animations", "bool"],
    "ville2", ["Ville2W", "bool"], "ville2prev", ["Ville2Prev", "bool"], "v2nom", ["Ville2Nom", "texte"],
    "v2fuseau", ["Ville2Fuseau", "texte"], "v2pos", ["Ville2Pos", "texte"], "hprevmax", ["HPrevMax", "entier"],
    "vigilance", ["VigilanceW", "bool"], "vigmin", ["VigMin", "entier"], "seine", ["SeineW", "bool"],
    "nuit", ["NuitEssai", "bool"], "teinte", ["NuitTeinte", "texte"], "intensite", ["NuitIntensite", "entier"],
    "oled", ["Oled", "entier"], "orbite", ["OrbiteTest", "texte"], "marque", ["JoursMarque", "texte"],
    "dureejour", ["DureeJour", "bool"], "calheure", ["CalHeure", "bool"], "calsaisons", ["CalSaisons", "bool"], "uv", ["UvW", "bool"],
    "air", ["AirMode", "texte"], "sable", ["AirSable", "bool"], "pollens", ["AirPollens", "bool"],
    "climatprev", ["ClimatPrev", "bool"], "climatwidget", ["ClimatWidget", "bool"], "climatrecord", ["ClimatRecord", "bool"],
    "iss", ["IssW", "bool"], "isshmin", ["IssHmin", "entier"], "planetes", ["CielPlanetes", "bool"], "etoiles", ["CielEtoiles", "bool"],
    "btc", ["MarchesBtcW", "bool"], "indicew", ["MarchesIndiceW", "bool"], "indice", ["MarchesIndice", "texte"],
    "actus", ["ActusW", "bool"], "anglais", ["AnglaisW", "bool"], "anglaissrc", ["AnglaisSource", "texte"], "voile", ["VoileBande", "bool"], "pluie", ["PluieW", "bool"], "rer", ["RerW", "bool"])

; Polices : Segoe UI Variable (Windows 11), repli sur Segoe UI sinon.
; « Semib » est déjà l'instance semi-grasse : on l'utilise en style normal.
; « Famille|1 » demande le style gras de la famille.
P_DATE  := "Segoe UI Variable Text Semibold"    ; date
P_TEXTE := "Segoe UI Variable Text"             ; lieu et résumé
P_GROS  := Map("android", "Segoe UI Variable Display Semib",   ; heure et température, selon le style
               "iphone",  "Segoe UI Variable Display|1",
               "epure",   "Segoe UI Variable Display Light",
               "lettres", "Segoe UI Variable Display Semib",
               "analogique", "Segoe UI Variable Display Semib")
P_LETTRES_INTRO := "Segoe UI Variable Display Light"   ; « Il est », en fin

; Palette des illustrations (aplats, comme sur Android)
C_SOLEIL  := 0xFFFFC233
C_LUNE    := 0xFFC3D6DD
C_NUAGE   := [0xFFFFFFFF, 0xFFF1F1F1]           ; [avant, arrière]
C_GRIS    := [0xFFC9D1D7, 0xFFBAC3CA]
C_ORAGE   := [0xFF9AA6B0, 0xFF8B97A1]
C_PLUIE   := 0xFF5AB0F7
C_GLACE   := 0xFFBFE6FF
C_NEIGE   := 0xFFFFFFFF
C_BRUME   := [0xFFE3E8EC, 0xFFC3CCD3]

; ---------- Chemins ----------
DOSSIER    := EnvGet("LOCALAPPDATA") "\WidgetMeteo"
F_DONNEES  := DOSSIER "\donnees.txt"
F_REGLAGES := DOSSIER "\reglages.ini"
SCRIPT_PS  := A_ScriptDir "\widget-meteo-donnees.ps1"
SCRIPT_FOND := A_ScriptDir "\widget-meteo-fond.py"
D_FOND     := DOSSIER "\fond"
F_FOND_ECRAN := EnvGet("APPDATA") "\Microsoft\Windows\Themes\TranscodedWallpaper"
F_MODELE   := DOSSIER "\modeles\BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx"
F_JOURNAL  := DOSSIER "\journal.log"
F_VERRE    := D_FOND "\verre.png"
SCRIPT_MARCHES := A_ScriptDir "\widget-meteo-marches.ps1"
F_MARCHES  := DOSSIER "\marches.txt"    ; cours (widget-meteo-marches.ps1 seulement)
F_ACTUS    := DOSSIER "\actus.txt"      ; titres à la une
F_TATOEBA  := DOSSIER "\anglais-tatoeba.txt"   ; lot de phrases du jour
F_HISTO    := DOSSIER "\historique.txt" ; courbe demandée par le tableau de bord
F_RER      := DOSSIER "\rer.txt"        ; transports : prochains départs et info trafic (widget-meteo-marches.ps1 -Rer)
F_CLE_IDFM := DOSSIER "\cle-idfm.txt"   ; jeton de l'utilisateur pour l'API Île-de-France Mobilités (hors du dépôt)
D_ARTICLES := DOSSIER "\articles"     ; fiche d'actualité : textes complets (2 jours)
D_IMAGES   := DOSSIER "\images"       ; … et photos
F_PHRASES  := A_ScriptDir "\widget-meteo-anglais.txt"   ; phrases d'anglais intégrées (niveau|français|anglais)
F_JOURS    := DOSSIER "\jours.txt"   ; Mes jours : types, semaine type, jours posés (widget-meteo-jours.ahk)

; ---------- État ----------
Opacite     := 0        ; % du fond (0 = aucun, comme sur Android)
Taille      := 100      ; % de la taille normale (TAILLE_MIN à TAILLE_MAX)
LargeurPct  := 100      ; % de la largeur normale du contenu (voir LargeurContenu)
Verrou      := false    ; true = ni déplacement ni redimensionnement (un clic ouvre toujours les prévisions)
Traversant  := false    ; true = transparent aux clics (ils vont au bureau dessous)
Heures      := false    ; rangée « prochaines heures » sous le résumé (option, menu Afficher)
Soleil      := false    ; lever et coucher du soleil : dans la rangée, ou sur leur propre ligne (option)
LuneReelle  := false    ; la lune dessinée dans sa phase du jour (option)
LuneLever   := false    ; lever et coucher de la lune, comme ceux du soleil (option)
LunePsi     := 0        ; phase du moment : élongation Lune − Soleil, au degré (voir MajLune)
LuneSud     := false    ; hémisphère sud : la lune croît à gauche
LuneForcee  := ""       ; modes de test : phase imposée (lune=0…359)
PoliceHeure := ""       ; police de l'heure (POLICES_HEURE), "" = celle du style
PoliceTemp  := false    ; la température prend la même police que l'heure
RenduHeure  := "plein"  ; rendu de l'heure : plein, contour, degrade, verre (voir RENDUS)
BlocHeure   := ""       ; rectangle de l'heure (cases fixes), posé par PoserHeure
ZoneRendu   := ""       ; zone des brosses du rendu (le bloc élargi), voir PreparerRendu
ClipContour := 0        ; rendu Contour : intérieur érodé exclu du remplissage (région GDI+)
VerreBmp    := 0        ; rendu Verre : fond flouté sous le widget
VerreCle    := ""
LettresPrecision := "minute"   ; « En toutes lettres » : minute, cinq, points (PRECISIONS)
LettresMoment := false  ; « … du matin, de l'après-midi, du soir »
CadranMeteo := "cote"   ; « Analogique » : météo à côté du cadran ou dessous
CadranChiffres := false ; « Analogique » : chiffres 12, 3, 6, 9 à la place des grandes graduations
DerniereCle := ""       ; ce qui était affiché (voir CleAffichage) : pas de redessin inutile
CalSemaine  := false    ; calendrier (options, menu Afficher ▸ Calendrier)
CalFeries   := false
CalVacances := false
CalComptes  := false
CalZone     := "C"      ; zone des vacances scolaires
CalPrevisions := true   ; aussi dans les prévisions détaillées
CalFeriesAvance := 1    ; jours d'avance (réglables dans reglages.ini seulement)
CalVacancesAvance := 7
CalComptesAvance := 0   ; 0 : toujours affiché
CalPeriodes := []       ; vacances : [{debut, reprise, nom}] (calendrier.txt)
CalDate     := ""
CalZoneLue  := ""       ; zone du fichier (téléchargé pour une autre zone : on le redemande)
ComptesListe := []      ; comptes à rebours [{date, lib, annuel}]
ComptesVersion := 0
JoursTypes  := []       ; Mes jours : types [{id, nom, c (ARGB), annonce, repos (non travaillé)}]
JoursSemaine := Map()   ; semaine type : n° du jour (1 = lundi … 7) → id
JoursCycles := Map()    ; cycles : AAAAMMJJ du début (entier) → [id ou « - », …] (vide : plus de cycle)
JoursRejets := []       ; lignes de jours.txt non comprises, réécrites telles quelles
JoursAnnulable := ""    ; jours.txt d'avant la dernière modification (Ctrl+Z), son libellé, « Annuler » ou « Rétablir »
JoursAnnulLib := "", JoursAnnulSens := "Annuler"
JoursTouches := Map()   ; jours touchés au pinceau depuis l'ouverture de « Mes jours » (même pareils à la base)
SurgieDialogue := 0     ; boîtes de dialogue ouvertes par une fenêtre surgissante (elle ne se ferme pas pendant ce temps)
JoursPoses  := Map()    ; jours posés : AAAAMMJJ (entier) → id, ou « - » (rien, même si la semaine type dit autre chose)
JoursDate   := ""       ; date de jours.txt lu
JoursVersion := 0       ; +1 à chaque changement (cache des événements du calendrier)
JoursMarque := "jour"   ; la date du jour à la couleur de son type : jour (le nom du jour seul), souligne, surligne, aucune
JoursGui    := "", JoursHwnd := 0, JoursGeo := ""   ; fenêtre « Mes jours » {kp, mois, x, y, w, h, mp, annee}
ReglGui     := "", ReglHwnd := 0, ReglGeo := ""   ; fenêtre « Réglages » {kp, cat, defil, survol, suivi, x, y, w, h, mp, hauteur}
ReglCat     := "apparence"   ; sa dernière catégorie (le temps de la session)
ReglCurseurTest := ""  ; /testfenetre : position du curseur simulée [x, y]
MenuClassique := ""    ; l'ancien menu complet (Maj + clic droit), tenu à jour par CocherMenus
MarchesBtcW := true    ; le Bitcoin (mini-graphique) sur le widget
MarchesIndiceW := true ; un indice boursier sur le widget (MarchesIndice)
MarchesIndice := "^FCHI"
MarchesCryptos := "bitcoin,ethereum"          ; tableau de bord (listes « a,b,c » d'identifiants des catalogues)
MarchesIndices := "^FCHI,^GSPC,^IXIC"
MarchesActions := "", MarchesTaux := ""
ActusW      := true    ; le titre à la une sur le widget
AnglaisW    := true    ; la phrase français → anglais sur le widget
AnglaisSource := "mix" ; mix (liste intégrée et Tatoeba), liste, tatoeba
VoileBande  := true    ; un voile sombre derrière le Bitcoin, la une et la phrase (fonds d'écran chargés)
PluieW      := true    ; pastille « Pluie dans 20 min » quand une averse arrive dans l'heure
AlerteBtc   := 5       ; alerte quand le Bitcoin bouge de plus de 5 % en 24 h (0 : non)
AlerteSeuils := ""     ; prix du Bitcoin (€) qui déclenchent une alerte quand il les franchit (« 70000,80000 »)
AlerteActions := 3     ; alerte quand un indice ou une action suivis bouge de plus de 3 % dans la séance (0 : non)
DerniereAlerteT := 0   ; dernière notification d'alerte (A_TickCount) : un clic dessus ouvre le tableau de bord
FicheGui    := "", FicheHwnd := 0, FicheGeo := ""   ; fiche d'une actualité (widget-meteo-actu.ahk)
FicheArt    := Map(), FicheArtPID := 0, FicheImgPID := 0, UneAffichee := ""
RerW        := true    ; prochains départs de la gare choisie sur le widget (widget-meteo-rer.ahk ; il faut le jeton de l'utilisateur)
RerArret    := "", RerLigne := ""   ; zone d'arrêt et ligne d'Île-de-France Mobilités (« 45102 », « C01742 »), choisies par leur nom
RerNom      := "", RerGare := "", RerCouleur := "8e8e93", RerEncre := "ffffff"   ; « RER C », le nom de l'arrêt, couleurs de la ligne
RerSens     := ""      ; noms donnés aux sens, dans l'ordre d'affichage : « Retour=Paris|Aller=Sud » (vide : automatiques)
RerDeparts  := [], RerMessages := [], RerEtatD := "", RerEtatM := "", RerMajD := 0, RerMajM := 0, RerDate := ""
RerPID      := 0, RerT0 := 0, DernierRerD := 0, DernierRerM := 0, RerCleDate := ""
Marches     := Map()   ; marches.txt lu : « C|bitcoin », « S|bitcoin », « Y|^FCHI », « T|fr10 » → objet
MarchesDate := "", MarchesErreurs := "", MarchesMaj := 0
ActusListe  := Map()   ; actus.txt lu : flux → [{t, titre, lien}]
ActusDate   := "", ActusMaj := 0
MarchesPID  := 0, MarchesT0 := 0, DernierMarches := 0, MarchesHisto := "", HistoAttente := ""
HistoCache  := Map()   ; courbes du tableau de bord : clé → {maj, t[], v[]} (ou {erreur})
MarchesGui  := "", MarchesHwnd := 0, MarchesGeo := ""   ; fenêtre « Actus et marchés »
MarchesSel  := "c:bitcoin", MarchesPlage := "1"   ; sa courbe : instrument (c:, y:, t:) et période
UneRang     := 1, UneT0 := 0     ; titre à la une affiché (rang dans le flux « une »), depuis
PhrasesListe := [], PhrasesTat := [], TatDate := ""   ; phrases d'anglais : liste intégrée, lot Tatoeba
PhraseCour  := "", PhraseT0 := 0   ; phrase affichée {fr, en, src}, depuis (MaintenantUnix)
JoursPinceau := ""      ; type posé d'un clic (id), ou « - » (effacer)
JoursTrait  := ""       ; clic ou glisser en cours sur les jours {mode, retrait, vus, lx, ly}
MenuMarque  := ""
DureeJour   := false    ; durée du jour (ligne du soleil) et heures d'UV (prévisions)
CalHeure    := false    ; changement d'heure annoncé (calendrier)
CalSaisons  := false    ; équinoxes et solstices (calendrier)
UvW         := false    ; pastille « UV fort » (bande d'infos)
AnnivListe  := []       ; anniversaires [{date (AAAA-MM-JJ ou MM-JJ), nom}] (section [anniversaires])
AnnivMoi    := ""       ; ta date de naissance
AnnivVersion := 0
AnnivConfettis := true  ; confettis le jour J
AirMode     := "0"      ; qualité de l'air : 0 (désactivée), episode, 4 (dès Mauvais), 3 (dès Dégradé)
AirSable    := false    ; sable du Sahara
AirPollens  := false    ; pollens
MenuAir     := "", LibEtatAir := ""
ClimatPrev  := false    ; normales et records : dans les prévisions
ClimatWidget := false   ; « (normale 20°) » à côté du maximum
ClimatRecord := false   ; pastille proche d'un record
MenuClimat  := ""
IssW        := false    ; passages visibles de l'ISS
IssHmin     := 20       ; hauteur minimale (°) des passages montrés
MenuCiel    := "", MenuIssHmin := ""
CielPlanetes := false   ; planètes visibles ce soir (prévisions)
CielEtoiles := false    ; étoiles filantes (prévisions, grandes nuits dans le calendrier)
MenuAnniv   := "", MenuAnnivSuppr := ""
FeteGui     := "", FeteHwnd := 0, FeteDC := 0, FeteBm := 0, FeteOb := 0   ; pluie de confettis en cours
FeteW := 0, FeteH := 0, FeteT0 := 0, FeteBouts := [], FeteBrosses := [], FeteMasque := 0
Ville2W     := false    ; deuxième ville : dans le widget, dans les prévisions détaillées
Ville2Prev  := false
Ville2Nom   := ""       ; la ville choisie (section [ville2] de reglages.ini)
Ville2Detail := ""
Ville2Pos   := ""       ; « lat,lon », tel que la collecte le renvoie dans v2_pos
Ville2Fuseau := ""      ; fuseau IANA (America/Guadeloupe…)
BandeInfos  := []       ; lignes de la bande sous le widget (PreparerBande, une fois par rendu)
HPrevMax    := ""       ; aperçus : hauteur disponible imposée pour la fenêtre des prévisions
CurH        := 0        ; hauteur du dernier rendu posé
SeineCrueAffichee := false   ; hystérésis du passage « Seine haute » ↔ « crue »
DernierJour := ""       ; changement de jour (menu des comptes à rebours)
CollecteRelance := ""   ; collecte demandée pendant qu'une autre tournait : relancée à sa fin
AmbianceSansCreation := false   ; la dernière ambiance a été demandée sans création (mode sobre, batterie)
ThemeLx := "", ThemeLy := ""    ; position logique (sans l'orbite OLED) pour le thème du rendu en cours
VerreGrand := 0, VerreGrandZone := ""   ; découpe élargie du verre (anti-marquage)
VigilanceW  := false    ; vigilance du département (menu Afficher ▸ Vigilance)
VigMin      := 2        ; 2 : dès le jaune ; 3 : orange et rouge seulement
VigZone     := ""       ; nom de zone MeteoAlarm imposé (secours si l'orthographe diffère)
SeineW      := false    ; Seine haute
SeineStation := "F490000104"   ; Hub'Eau : la Seine à Alfortville (en amont de Paris)
SeineLieu   := "Alfortville"
SeineSeuil  := 1.50     ; m : « Seine haute » (99e centile depuis 2000)
SeineCrue   := 2.50     ; m : « Crue de la Seine » (2001 : 2,67 m ; 2016 : 3,65 m)
SeineAffichee := false  ; hystérésis de la pastille
PopupGeo    := ""       ; fenêtre des prévisions ouverte : {x, y, w, h, kp, p}, pour la repeindre en place
NuitMode    := "0"      ; mode nuit : 0, soleil (du coucher + décalage au lever), plage
NuitDecalage := 60      ; min après le coucher
NuitPlage   := "22:00-07:00"
NuitIntensite := 40     ; % la nuit
NuitTeinte  := "normale"   ; normale, rouge, ambre
NuitSurvol  := true     ; pleine intensité au survol (10 s)
NuitEssai   := false    ; « Essayer pendant 10 secondes » (et aperçus : nuit=1)
NuitEveil   := false    ; survolé la nuit : pleine intensité
NuitEtatPrec := false   ; nuit au dernier tic (bascule, et réveil au survol sans recalcul)
AlphaCourant := 255     ; intensité appliquée à la fenêtre (le fondu la fait varier)
TeinteRendu := ""       ; teinte du rendu en cours (posée par Dessiner et DessinerPrevisions seulement)
NuitFonduDe := 255, NuitFonduVers := 255, NuitFonduPas := 0, NuitFonduN := 0
Oled        := 0        ; anti-marquage : rayon de l'orbite en px (0 : désactivé)
OrbiteDx    := 0        ; décalage appliqué à la fenêtre (position réelle − position logique)
OrbiteDy    := 0
OrbiteTest  := ""       ; aperçus : décalage imposé « dx,dy »
MasqueGrand := 0        ; découpe élargie du masque (anti-marquage : pas de relecture à chaque pas)
MasqueGrandZone := ""
CB_MINUTE   := 0        ; rappel du tic de minute (CallbackCreate, gardé jusqu'à la sortie)
TicCible    := ""       ; fonction lancée à chaque tic (Horloge)
DerniereCollecte := 0   ; unix : dernière collecte complète lancée
CollectePID := 0, CollecteT0 := 0
GuetAnim := false, GuetSobre := false, GuetFete := false, GuetActif := false   ; qui guette la réapparition du widget
HooksFenetres := [], CB_HOOK := 0, CB_VISIB := 0
TestTicFichier := "", TestTicMax := 2, TestTicN := 0
Sobre       := false    ; mode sobre (menu Écran et batterie)
SobrePause := true, SobreAnim := true, SobreMeteo := true, SobreAmbiance := true   ; ses 4 cases
EcranEteint := false, Verrouillee := false, SurBatterie := false, Economie := false   ; notifications de Windows
CacheMemo   := false    ; widget entièrement recouvert (dernier constat)
RedessinEnAttente := false, AttenteRepos := false
NotifsAlim  := [], SessionInscrite := false
AmbianceDifferee := ""  ; ambiance jamais générée, reportée au retour sur secteur (« nom|fond »)
AmbianceActive := false ; fond d'écran selon la météo et l'heure
Animations  := false    ; illustration animée (désactivée par défaut : batterie)
PosX        := ""       ; position mémorisée (vide = coin haut droit)
PosY        := ""
CurW        := 0        ; taille appliquée (0 = pas encore affiché)
Glisse      := false    ; bouton appuyé sur le widget (clic ou glisser en cours)
GlisseActif := false    ; le curseur a bougé : c'est un glisser, pas un clic
GlisseBouge := false    ; a bougé alors que le widget est verrouillé (ni glisser ni clic)
GlisseDouble := false   ; appui venu d'un double-clic (pas de 2e ouverture des prévisions)
GlisseDx    := 0        ; décalage curseur -> coin du widget pendant le glisser
GlisseDy    := 0
GlisseX0    := 0        ; position du curseur à l'appui
GlisseY0    := 0
GlisseEcran := ""       ; écran sous le widget pendant le glisser (pour l'aimantation)
Geste       := ""       ; redimensionnement en cours (coin, côté ou molette), "" sinon ; voir Saisir
RenduGen    := 0        ; numéro du dernier rendu complet lancé (+1 à chaque fin de geste) ; voir Peindre
ModeEdition := ""       ; mode « Redimensionner à la souris… » en cours (objet), "" sinon
MolCumul    := 0        ; crans de molette pas encore appliqués (le pavé tactile envoie des fractions)
LibTaille   := ""       ; libellé « Actuelle : … » du menu Taille
PopupGui    := ""       ; fenêtre des prévisions détaillées
PopupHwnd   := 0
AmbiancePID := 0        ; génération / pose d'une ambiance en cours
AmbianceDemandee := ""
AmbianceCle := ""       ; ambiance + fond d'écran au moment de la demande
AmbianceEchec := ""     ; dernière demande en échec (pas de relance en boucle)
IconeZone   := ""       ; illustration principale du widget {id, x, y, s} (pour l'animation)
AnimGui     := ""       ; fenêtre de l'illustration animée, posée sur le widget
AnimHwnd    := 0
AnimImages  := []       ; images pré-dessinées de la boucle {dc, bm, ob}
AnimCle     := ""
AnimN       := 0        ; image affichée (0 à nombre d'images - 1)
AnimW       := 0
AnimH       := 0
AnimDx      := 0        ; position de la fenêtre d'animation par rapport au widget
AnimDy      := 0
AnimMarche  := false
EtatProf    := ""       ; libellé affiché dans le menu sous « Effet profondeur »
ActionProf  := ""       ; ce que fait un clic sur ce libellé
TelechargePID := 0
Donnees     := Map()
DonneesDate := ""
DerniereMin := ""
Fen         := ""
HWIDGET     := 0
MenuWidget  := ""
MenuTaille  := ""
MenuFond    := ""
MenuStyle   := ""
MenuCouleur := ""
MenuPosition := ""
MenuAfficher := ""
MenuLune    := ""
MenuHeure   := ""
MenuPolice  := ""
MenuPoliceAutres := ""
MenuRendu   := ""
MenuLettres := ""
MenuCadran  := ""
MenuCalendrier := ""
MenuComptesSuppr := ""
MenuZone    := ""
MenuVille2  := ""
LibV2       := ""
MenuVigilance := ""
MenuPi      := ""
MenuEcran   := ""
MenuNuit    := ""
MenuNuitDecalage := ""
MenuNuitIntensite := ""
MenuNuitTeinte := ""
LibEtatNuit := ""
MenuOled    := ""
MenuSobre   := ""
LibEtatSobre := ""
LibEtatVig  := ""
LibSeine    := ""
JetonGdip   := 0
Style       := "android"
Couleur     := "blanc"
Profondeur  := false
InfosFond   := Map()    ; fond.txt : empreinte du fond analysé, teinte, masque dispo…
FondDate    := ""
AnalysePID  := 0
DejaAnalyse := ""       ; empreinte déjà confiée à l'analyse (pas de relance en boucle si elle échoue)
MasqueBmp   := 0        ; sujet du fond d'écran sous le widget (découpé du masque plein écran)
MasqueCle   := ""
LumBmp      := 0        ; petite carte de luminosité de l'écran
ThemeCourant := ""
SansProfondeur := false ; aperçus sur fond uni : pas de sujet derrière
Brosses     := Map()    ; brosses « profondeur », gardées tant que masque, zone et couleurs ne changent pas
BrossesCle  := ""
ZoneHeure   := ""       ; zone de l'heure dans le widget (où s'appliquent les brosses)
ZonesRendu  := []       ; zones cliquables du rendu en cours [{id, x, y, w, h}] (NoterZone)
ZonesClic   := []       ; celles du dernier rendu posé (test de clic)
ZonesFen    := []       ; « Laisser passer les clics » : fenêtres invisibles sur les zones [{g, hwnd, id}]
GlisseZone  := ""       ; zone sous le curseur à l'appui : meteo ou ""
SurgieT0    := 0        ; ouverture de la fenêtre surgissante (prévisions, Mes jours)
SurgiePremier := 0      ; fenêtre au premier plan une fois l'ouverture stabilisée
SurgieClicAilleurs := 0 ; dernier clic hors de nos fenêtres, fenêtre surgissante ouverte (A_TickCount)
ApercuZones := false    ; aperçus : zones cliquables dessinées par-dessus (zones=1)
ApercuBrouillon := false ; aperçus : rendu allégé de pendant un redimensionnement (/apercu … brouillon=1)
HeureTest   := ""       ; modes de test : moment affiché imposé (heure=HH:MM, date=AAAAMMJJ)

InitGdip()
ChargerReglages()

; Modes de test : dessinent dans une image PNG (ou écrivent un rapport) puis quittent.
;   /apercu <png> [code jour "résumé" temp "maximum" âge_min ville] [options…]
;                         le widget sur ton fond d'écran (à sa vraie place), un fond sombre et un fond clair
;   /icones <png>         toutes les illustrations
;   /previsions <png> [previsions.txt]   la fenêtre des prévisions détaillées (données réelles, ou ce fichier)
;   /animation <png> <id> [n]   n images de la boucle d'animation d'une illustration
;   /testgeste <txt>      auto-test des calculs du redimensionnement (invariants)
; Options (tous les modes) : un réglage nom=valeur de ARGS_TEST (style=iphone,
; heures=1, taille=150…), d.clé=valeur (une donnée imposée : d.code=61,
; d.coucher=19:30…), heure=HH:MM et date=AAAAMMJJ (moment affiché), cadre=1
; (poignées du mode redimensionnement), brouillon=1 (rendu allégé du geste).
; un argument qui n'est pas un mode de test connu (faute de frappe, « / » oublié,
; fichier déposé sur le script…) ne doit jamais démarrer un vrai widget, qui
; remplacerait celui en service : le démarrage normal se fait sans argument
if (A_Args.Length && !(A_Args.Length >= 2 && MODES_TEST.Has(A_Args[1]))) {
    try FileAppend("Argument non reconnu (mode de test inconnu ou incomplet) : " A_Args[1] "`n", "*")
    ExitApp(2)
}
if (A_Args.Length >= 2 && MODES_TEST.Has(A_Args[1])) {
    OnError((e, *) => (FileAppend("ERREUR : " e.Message " (" e.What ", ligne " e.Line ")`n" e.Extra "`n", "*"), ExitApp(3)))
    mode := A_Args[1], pos := [], imposees := Map(), testDate := "", testHeure := ""
    for a in A_Args {
        if (A_Index = 1)
            continue
        if !RegExMatch(a, "^([\w.]+)=(.*)$", &o) {    ; sans « = » : argument de position (fichier, données…)
            pos.Push(a)
            continue
        }
        if (SubStr(o[1], 1, 2) = "d.")                ; une donnée imposée (d.heures=…, d.coucher=…)
            imposees[SubStr(o[1], 3)] := o[2]
        else if (o[1] = "heure")
            testHeure := StrReplace(o[2], ":")
        else if (o[1] = "date")
            testDate := o[2]
        else if (o[1] = "cadre")                      ; cadre et poignées du mode « Redimensionner à la souris »
            ModeEdition := (o[2] = "1") ? {t0: 0} : ""
        else if (o[1] = "brouillon")                  ; rendu allégé de pendant un redimensionnement
            ApercuBrouillon := (o[2] = "1")
        else if (o[1] = "zones")                      ; zones cliquables dessinées par-dessus
            ApercuZones := (o[2] = "1")
        else if (o[1] = "lune")                       ; lune=reel (option cochée) ou lune=<degrés> (phase imposée)
            LuneReelle := (o[2] != "0"), LuneForcee := IsInteger(o[2]) ? o[2] : ""
        else if ARGS_TEST.Has(o[1]) {
            def := ARGS_TEST[o[1]], nomVar := def[1]
            %nomVar% := (def[2] = "bool") ? (o[2] = "1") : (def[2] = "entier") ? Integer(o[2]) : o[2]
        } else {
            FileAppend("Option inconnue : " a "`n", "*")
            ExitApp(2)
        }
    }
    if (testDate != "" || testHeure != "")
        HeureTest := ((testDate != "") ? testDate : FormatTime(, "yyyyMMdd")) ((testHeure != "") ? testHeure : FormatTime(, "HHmm")) "00"
    if (mode = "/testgeste")
        TestGeste(pos[1])
    else if (mode = "/testjours")
        TestJours(pos[1])
    else if (mode = "/testlumiere")
        TestLumiere(pos[1])
    else if (mode = "/testanniv")
        TestAnniv(pos[1])
    else if (mode = "/testciel")
        TestCiel(pos[1])
    else if (mode = "/testreglages")
        TestReglages(pos[1])
    else if (mode = "/testfenetre")
        TestFenetreReglages(pos[1])
    else if (mode = "/testmarches")
        TestMarches(pos[1])
    else if (mode = "/testanglais")
        TestAnglais(pos[1])
    else if (mode = "/testtableau")
        TestFenetreMarches(pos[1])
    else if (mode = "/testrer")
        TestRer(pos[1])
    else if (mode = "/testpluie")
        TestPluie(pos[1])
    else if (mode = "/testfiche")
        TestFiche(pos[1])
    else if (mode = "/fete")
        PlancheFete(pos[1], (pos.Length >= 2) ? Integer(pos[2]) : 6)
    else if (mode = "/testtic") {
        TestTic(pos[1], (pos.Length >= 2) ? Integer(pos[2]) : 2)
        Persistent()                              ; attend ses tics (TicTest quitte)
        return
    } else if (mode = "/testsobre")
        TestSobre(pos[1])
    else if (mode = "/testorbite")
        TestOrbite(pos[1])
    else if (mode = "/testnuit")
        TestNuit(pos[1])
    else if (mode = "/villes")
        TestVilles(pos[1], pos[2])
    else if (mode = "/testferies")
        TestFeries(pos[1], pos[2])
    else if (mode = "/phrases")
        TablePhrases(pos[1])
    else if (mode = "/lunes")
        PlancheLunes(pos[1])
    else if (mode = "/icones")
        PlancheIcones(pos[1])
    else if (mode = "/animation")
        PlancheAnimation(pos[1], pos.Length >= 2 ? pos[2] : "pluie", pos.Length >= 3 ? Integer(pos[3]) : 8)
    else {
        LireDonnees()
        LireCalendrier()
        LireJours()
        LireMarches(), LireActus(), LirePhrases(), LireRer()   ; (aperçus : marchés, actus, phrases, RER du dossier de test)
        for a in A_Args                           ; anglais=1 : une phrase affichée (sinon aucune, comme avant 2.28)
            if (a = "anglais=1")
                ChoisirPhrase()
        if (mode = "/apercu")
            ChargerFond()
        for cle, v in imposees
            Donnees[cle] := v
        if (mode = "/previsions")
            ApercuPrevisions(pos[1], pos.Length >= 2 ? pos[2] : "")
        else if (mode = "/jours")
            ApercuJours(pos[1], pos.Length >= 2 ? pos[2] : "", pos.Length >= 3 ? pos[3] : "")
        else if (mode = "/fiche")
            ApercuFiche(pos[1], pos.Length >= 2 ? pos[2] : "fil", pos.Length >= 3 ? Integer(pos[3]) : 1, pos.Length >= 4 ? pos[4] : 0)
        else if (mode = "/marches")
            ApercuMarches(pos[1], pos.Length >= 2 ? pos[2] : "", pos.Length >= 3 ? pos[3] : "", pos.Length >= 4 ? pos[4] : 0)
        else if (mode = "/reglages")
            ApercuReglages(pos[1], pos.Length >= 2 ? pos[2] : "apparence", pos.Length >= 3 ? pos[3] : 0)
        else {
            if (pos.Length > 1) {                     ; données imposées : fraîches, sauf âge indiqué
                Donnees["maj"] := MaintenantUnix()
                Donnees["maximum"] := ""
            }
            for i, cle in ["code", "jour", "resume", "temp", "maximum", "age", "ville"]
                if (pos.Length >= i + 1)
                    Donnees[cle] := pos[i + 1]
            if (Donnees.Get("age", "") != "")
                Donnees["maj"] := MaintenantUnix() - Integer(Donnees["age"]) * 60
            Apercu(pos[1])
        }
    }
    ExitApp
}

Demarrer()
return

; =============================================================================
;  Démarrage
; =============================================================================

InitGdip() {
    global JetonGdip
    DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
    si := Buffer(24, 0)
    NumPut("UInt", 1, si, 0)
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &JetonGdip, "Ptr", si, "Ptr", 0)
}

Demarrer() {
    FermerAutresInstances()
    OnError(NoterErreur)
    DirCreate(DOSSIER)
    vp := ""
    Journal("démarrage v" VERSION " : style " Style ", couleur " Couleur ", profondeur " Profondeur
        . ", taille " Taille ", largeur " LargeurPct ", position " PosX "," PosY ", écran " A_ScreenWidth "x" A_ScreenHeight " à " A_ScreenDPI " dpi"
        . ", heures " Heures ", soleil " Soleil ", lune " LuneReelle ", lune_lever " LuneLever ", police « " PoliceHeure " » (température " PoliceTemp "), rendu " RenduHeure ", lettres " LettresPrecision "/" LettresMoment ", cadran " CadranMeteo "/" CadranChiffres ", calendrier " CalSemaine CalFeries CalVacances CalComptes " zone " CalZone ", ville2 " Ville2W Ville2Prev ", vigilance " VigilanceW "/" VigMin ", seine " SeineW vp ", nuit " NuitMode "/" NuitTeinte "/" NuitIntensite ", oled " Oled ", sobre " Sobre ", jours " JoursMarque ", lumière " DureeJour CalHeure CalSaisons UvW ", air " AirMode "/" AirSable AirPollens ", climat " ClimatPrev ClimatWidget ClimatRecord ", iss " IssW "/" IssHmin ", ciel " CielPlanetes CielEtoiles ", marchés " MarchesBtcW MarchesIndiceW "/" MarchesIndice ", actus " ActusW ", anglais " AnglaisW "/" AnglaisSource ", ambiance " AmbianceActive ", animations " Animations)
    CoordMode("ToolTip", "Screen")                ; bulles de taille près du curseur
    CreerFenetre()
    ConstruireMenus()

    OnMessage(0x201, Saisir)                      ; WM_LBUTTONDOWN : clic ou début du glisser
    OnMessage(0x203, Saisir)                      ; WM_LBUTTONDBLCLK : 2e appui rapide (« taper deux fois et glisser » du pavé tactile)
    OnMessage(0x200, Glisser)                     ; WM_MOUSEMOVE
    OnMessage(0x202, Lacher)                      ; WM_LBUTTONUP
    OnMessage(0x215, Lacher)                      ; WM_CAPTURECHANGED (glisser interrompu)
    OnMessage(0x205, ClicDroit)                   ; WM_RBUTTONUP : menu (ou annulation d'un redimensionnement)
    OnMessage(0x21, PasActiver)                   ; WM_MOUSEACTIVATE
    OnMessage(0x20, CurseurRedim)                 ; WM_SETCURSOR : flèches de redimensionnement sur les bords
    OnMessage(0x20A, Molette)                     ; WM_MOUSEWHEEL : Ctrl+molette = taille
    OnMessage(0x100, PopupMessage)                ; WM_KEYDOWN : Échap
    OnMessage(0x202, PopupMessage)                ; WM_LBUTTONUP dans la fenêtre des prévisions (après Lacher)
    OnMessage(0x201, ZoneFenAppui)                ; zones cliquables du mode « Laisser passer les clics »
    OnMessage(0x203, ZoneFenAppui)                ; (2e appui d'un double-clic : le relâché qui suit ne fait rien)
    OnMessage(0x202, ZoneFenRelache)
    JoursMessages()                               ; fenêtre « Mes jours » (widget-meteo-jours.ahk)
    ReglMessages()                                ; fenêtre « Réglages » (widget-meteo-reglages.ahk)
    MarchesMessages()                             ; fenêtre « Actus et marchés » (widget-meteo-marches.ahk)
    FicheMessages()                               ; fiche d'une actualité (widget-meteo-actu.ahk)
    OnMessage(0x7E, (*) => SetTimer(Repositionner, -1500))   ; WM_DISPLAYCHANGE
    OnMessage(DllCall("RegisterWindowMessage", "Str", "TaskbarCreated", "UInt"), ExplorateurRelance)

    LireDonnees()
    LireCalendrier()
    LireJours()
    LireMarches(), LireActus(), LirePhrases(), LireRer()   ; (les dernières connues, avant la 1re collecte)
    CocherMenus()                                 ; (la coche du calendrier dépend des jours posés)
    ChargerFond()
    A_IconTip := "Widget météo " VERSION
    NuitDemarrer()                                ; mode nuit : l'état du moment, sans fondu
    Redessiner(true)
    VerifierFond()
    OnMessage(0x1E, SurHeureChangee)              ; WM_TIMECHANGE : heure du PC changée
    OnMessage(0x218, SurAlimentation)             ; WM_POWERBROADCAST : sortie de veille (et mode sobre)
    OnMessage(0x2B1, SurSession)                  ; WM_WTSSESSION_CHANGE : verrouillage (mode sobre)
    if Sobre
        InscrireAlimentation()                    ; (après les OnMessage : l'état courant arrive aussitôt)
    ArmerMinute(Horloge)                          ; un seul réveil par minute (voir ArmerMinute)
    SetTimer(Horloge, -1000)                      ; premier passage (ambiance, fond) sans attendre la minute
    SetTimer(FeteAuto, -8000)                     ; anniversaire du jour (une fois le widget posé)
    LancerCollecte()
    if MarchesUtiles()
        LancerMarches()
    OnExit(Quitter)
    AstuceRedimensionnement()
}

; Une seule fois : comment étendre le widget, selon qu'il saisit ou non la souris
AstuceRedimensionnement() {
    if (IniRead(F_REGLAGES, "widget", "astuce_redim", 0) = 1)
        return
    IniWrite(1, F_REGLAGES, "widget", "astuce_redim")
    if (Traversant || Verrou)
        TrayTip("Nouveau : taille et largeur libres. Clic droit sur l'icône du widget ▸ Réglages ▸ Position et taille ▸ « "
            . LIB_EDITION " », puis tire un coin (taille) ou un côté (largeur).", "Widget météo")
    else
        TrayTip("Nouveau : tire un coin du widget pour changer sa taille, un côté pour sa largeur. "
            . "Ctrl+molette marche aussi.", "Widget météo")
}

; Petit journal de diagnostic (démarrage, analyses du fond d'écran, réglages)
Journal(msg) {
    try {
        if (FileExist(F_JOURNAL) && FileGetSize(F_JOURNAL) > 200000)
            FileDelete(F_JOURNAL)
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " msg "`n", F_JOURNAL, "UTF-8")
    }
}

; Une erreur imprévue est notée dans erreurs.log et le widget continue : la
; boîte de dialogue d'AutoHotkey, elle, peut arrêter le script si on la ferme.
NoterErreur(e, mode) {
    try {
        f := DOSSIER "\erreurs.log"
        if (FileExist(f) && FileGetSize(f) > 200000)
            FileDelete(f)
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " v" VERSION " : " e.Message " (" e.What ", ligne " e.Line ")`n"
            . e.Extra "`n" e.Stack "`n", f, "UTF-8")
    }
    return 1                                      ; pas de boîte de dialogue, le widget continue
}

; Une seule instance du widget à la fois. Géré à la main plutôt que par
; #SingleInstance Force, pour que les modes de test (/apercu, /icones) ne
; ferment pas le widget en cours.
FermerAutresInstances() {
    DetectHiddenWindows(true)
    for hw in WinGetList(A_ScriptFullPath " ahk_class AutoHotkey")
        if (hw != A_ScriptHwnd)
            PostMessage(0x111, 65307, 0, , hw)       ; WM_COMMAND « Quitter » de l'autre instance
    DetectHiddenWindows(false)
}

CreerFenetre() {
    global Fen, HWIDGET, CurW
    try Fen.Destroy()
    ; Superposée (0x80000), jamais activée (0x08000000), absente de la barre
    ; des tâches et d'Alt+Tab (ToolWindow). Transparente aux clics (0x20)
    ; seulement si c'est demandé (« Laisser passer les clics »).
    Fen := Gui("-Caption +ToolWindow +E0x80000 +E0x08000000" (Traversant ? " +E0x20" : ""))
    Fen.Show("NA x0 y0 w1 h1")
    HWIDGET := Fen.Hwnd
    CurW := 0
    AncrerAuBureau()
}

; Rattache le widget au bureau. Une fenêtre « possédée » reste toujours
; au-dessus de son propriétaire : posée juste au-dessus du bureau, elle est
; derrière tes fenêtres, et remonte avec le bureau quand on l'affiche (Win+D).
AncrerAuBureau() {
    bureau := DllCall("GetShellWindow", "Ptr")
    if !bureau
        bureau := DllCall("FindWindow", "Str", "Progman", "Ptr", 0, "Ptr")
    if !bureau {
        SetTimer(AncrerAuBureau, -3000)      ; l'explorateur n'est pas encore prêt
        return
    }
    DllCall("SetWindowLongPtr", "Ptr", HWIDGET, "Int", -8, "Ptr", bureau, "Ptr")
    DllCall("SetWindowPos", "Ptr", HWIDGET, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
}

; L'explorateur a redémarré : le bureau a été recréé, et la fenêtre qui lui
; était rattachée a disparu avec l'ancien. On la reconstruit.
ExplorateurRelance(*) {
    SetTimer(Reconstruire, -2000)
}

Reconstruire() {
    if EnGeste()
        FinirGeste()
    QuitterEdition()
    FeteArreter()
    CreerFenetre()
    Redessiner(true)
}

Repositionner() => Redessiner(true)

Quitter(*) {
    DesarmerMinute()
    DesinscrireAlimentation()
    SurveillerVisibilite(false)
    AnimArreter(true)
    FeteArreter()
    FermerSurgies()
    ZonesFenFermer()
    try Fen.Destroy()
    if JetonGdip
        DllCall("gdiplus\GdiplusShutdown", "Ptr", JetonGdip)
}

; =============================================================================
;  Réglages et données
; =============================================================================

ChargerReglages() {
    global Opacite, Taille, LargeurPct, Verrou, PosX, PosY, Style, Couleur, Profondeur, Traversant, Heures, Soleil, AmbianceActive, Animations, LuneReelle, LuneLever, PoliceHeure, PoliceTemp, RenduHeure, LettresPrecision, LettresMoment, CadranMeteo, CadranChiffres,
        CalSemaine, CalFeries, CalVacances, CalComptes, CalZone, CalPrevisions, CalFeriesAvance, CalVacancesAvance, CalComptesAvance,
        Ville2W, Ville2Prev, Ville2Nom, Ville2Detail, Ville2Pos, Ville2Fuseau,
        VigilanceW, VigMin, VigZone, SeineW, SeineStation, SeineLieu, SeineSeuil, SeineCrue,
        NuitMode, NuitDecalage, NuitPlage, NuitIntensite, NuitTeinte, NuitSurvol, Oled,
        Sobre, SobrePause, SobreAnim, SobreMeteo, SobreAmbiance, JoursMarque, DureeJour, CalHeure, CalSaisons, UvW, AnnivConfettis, AirMode, AirSable, AirPollens, ClimatPrev, ClimatWidget, ClimatRecord, IssW, IssHmin, CielPlanetes, CielEtoiles
    global MarchesBtcW, MarchesIndiceW, MarchesIndice, MarchesCryptos, MarchesIndices, MarchesActions, MarchesTaux, ActusW, AnglaisW,
        AnglaisSource, VoileBande, PluieW, AlerteBtc, AlerteSeuils, AlerteActions, RerW, RerArret, RerLigne, RerNom, RerGare, RerCouleur, RerEncre, RerSens
    Style      := IniRead(F_REGLAGES, "widget", "style", "android")
    Couleur    := IniRead(F_REGLAGES, "widget", "couleur", "blanc")
    Profondeur := IniRead(F_REGLAGES, "widget", "profondeur", 0) = 1
    Style := StyleConnu(Style)                    ; forme canonique, style inconnu : Android
    ; lus avant OnError : une valeur invalide ne doit pas empêcher le démarrage
    Opacite    := LireEntier("opacite", 0, 0, 90)
    Taille     := LireEntier("taille", 100, TAILLE_MIN, TAILLE_MAX)
    LargeurPct := LireEntier("largeur", 100, 80, 175)
    Verrou  := IniRead(F_REGLAGES, "widget", "verrou", 0) = 1
    Traversant := IniRead(F_REGLAGES, "widget", "traversant", 0) = 1
    Heures     := IniRead(F_REGLAGES, "widget", "heures", 0) = 1
    Soleil     := IniRead(F_REGLAGES, "widget", "soleil", 0) = 1
    LuneReelle := IniRead(F_REGLAGES, "widget", "lune", 0) = 1
    LuneLever  := IniRead(F_REGLAGES, "widget", "lune_lever", 0) = 1
    PoliceHeure := PoliceValide(IniRead(F_REGLAGES, "widget", "police_heure", ""))   ; absente de ce PC : selon le style
    PoliceTemp := IniRead(F_REGLAGES, "widget", "police_temp", 0) = 1
    RenduHeure := IniRead(F_REGLAGES, "widget", "rendu_heure", "plein")
    if !RegExMatch(RenduHeure, "^(plein|contour|degrade|verre)$")
        RenduHeure := "plein"
    LettresPrecision := LireChoix("lettres_precision", "minute", ["minute", "cinq", "points"])
    LettresMoment := IniRead(F_REGLAGES, "widget", "lettres_moment", 0) = 1
    CadranMeteo := LireChoix("cadran_meteo", "cote", ["cote", "dessous"])
    CadranChiffres := IniRead(F_REGLAGES, "widget", "cadran_chiffres", 0) = 1
    CalSemaine := IniRead(F_REGLAGES, "widget", "semaine", 0) = 1
    CalFeries := IniRead(F_REGLAGES, "widget", "feries", 0) = 1
    CalVacances := IniRead(F_REGLAGES, "widget", "vacances", 0) = 1
    CalComptes := IniRead(F_REGLAGES, "widget", "comptes", 0) = 1
    CalZone := LireChoix("vacances_zone", "C", ["A", "B", "C"])
    CalPrevisions := IniRead(F_REGLAGES, "widget", "cal_previsions", 1) = 1
    CalFeriesAvance := LireEntier("feries_avance", 1, 0, 7)
    CalVacancesAvance := LireEntier("vacances_avance", 7, 0, 30)
    CalComptesAvance := LireEntier("comptes_avance", 0, 0, 365)
    LireComptes()
    Ville2W := IniRead(F_REGLAGES, "widget", "ville2", 0) = 1
    Ville2Prev := IniRead(F_REGLAGES, "widget", "ville2_prev", 0) = 1
    Ville2Nom := Trim(IniRead(F_REGLAGES, "ville2", "nom", ""))
    Ville2Detail := Trim(IniRead(F_REGLAGES, "ville2", "detail", ""))
    Ville2Fuseau := Trim(IniRead(F_REGLAGES, "ville2", "fuseau", ""))
    la := Trim(IniRead(F_REGLAGES, "ville2", "lat", "")), lo := Trim(IniRead(F_REGLAGES, "ville2", "lon", ""))
    Ville2Pos := (IsNumber(la) && IsNumber(lo) && Abs(la) <= 90 && Abs(lo) <= 180) ? la "," lo : ""
    VigilanceW := IniRead(F_REGLAGES, "widget", "vigilance", 0) = 1
    VigMin := LireEntier("vigilance_min", 2, 2, 3)
    VigZone := Trim(StrReplace(IniRead(F_REGLAGES, "widget", "vigilance_zone", ""), '"'))
    SeineW := IniRead(F_REGLAGES, "widget", "seine", 0) = 1
    st := Trim(IniRead(F_REGLAGES, "widget", "seine_station", "F490000104"))
    SeineStation := RegExMatch(st, "^[A-Za-z0-9]+$") ? st : "F490000104"
    SeineLieu := Trim(IniRead(F_REGLAGES, "widget", "seine_lieu", "Alfortville"))
    SeineSeuil := LireEntier("seine_seuil_cm", 150, 50, 900) / 100
    SeineCrue := LireEntier("seine_crue_cm", 250, 100, 900) / 100
    NuitMode := LireChoix("nuit", "0", ["0", "soleil", "plage"])
    NuitDecalage := LireEntier("nuit_decalage", 60, 0, 240)
    NuitPlage := Trim(IniRead(F_REGLAGES, "widget", "nuit_plage", NUIT_PLAGE_DEFAUT))
    if !IsObject(PlageNuit(NuitPlage))
        NuitPlage := NUIT_PLAGE_DEFAUT
    NuitIntensite := LireEntier("nuit_intensite", 40, 10, 100)
    NuitTeinte := LireChoix("nuit_teinte", "normale", ["normale", "rouge", "ambre"])
    NuitSurvol := IniRead(F_REGLAGES, "widget", "nuit_survol", 1) = 1
    Oled := LireEntier("oled", 0, 0, 3)
    Sobre := IniRead(F_REGLAGES, "widget", "sobre", 0) = 1
    SobrePause := IniRead(F_REGLAGES, "widget", "sobre_pause", 1) = 1
    SobreAnim := IniRead(F_REGLAGES, "widget", "sobre_anim", 1) = 1
    SobreMeteo := IniRead(F_REGLAGES, "widget", "sobre_meteo", 1) = 1
    SobreAmbiance := IniRead(F_REGLAGES, "widget", "sobre_ambiance", 1) = 1
    AmbianceActive := IniRead(F_REGLAGES, "widget", "ambiance", 0) = 1
    JoursMarque := LireChoix("jours_marque", "jour", ["jour", "souligne", "surligne", "aucune"])
    DureeJour := IniRead(F_REGLAGES, "widget", "duree_jour", 0) = 1
    CalHeure := IniRead(F_REGLAGES, "widget", "cal_heure", 0) = 1
    CalSaisons := IniRead(F_REGLAGES, "widget", "cal_saisons", 0) = 1
    UvW := IniRead(F_REGLAGES, "widget", "uv_fort", 0) = 1
    AnnivConfettis := IniRead(F_REGLAGES, "widget", "anniv_confettis", 1) = 1
    AirMode := LireChoix("air", "0", ["0", "episode", "4", "3"])
    AirSable := IniRead(F_REGLAGES, "widget", "air_sable", 0) = 1
    AirPollens := IniRead(F_REGLAGES, "widget", "air_pollens", 0) = 1
    ClimatPrev := IniRead(F_REGLAGES, "widget", "climat_prev", 0) = 1
    ClimatWidget := IniRead(F_REGLAGES, "widget", "climat_widget", 0) = 1
    ClimatRecord := IniRead(F_REGLAGES, "widget", "climat_record", 0) = 1
    IssW := IniRead(F_REGLAGES, "widget", "iss", 0) = 1
    IssHmin := LireChoix("iss_hmin", 20, [10, 20, 40])
    CielPlanetes := IniRead(F_REGLAGES, "widget", "ciel_planetes", 0) = 1
    CielEtoiles := IniRead(F_REGLAGES, "widget", "ciel_etoiles", 0) = 1
    MarchesBtcW := IniRead(F_REGLAGES, "widget", "marches_btc", 1) = 1
    MarchesIndiceW := IniRead(F_REGLAGES, "widget", "marches_indice_w", 1) = 1
    MarchesIndice := ListeCatalogue(IniRead(F_REGLAGES, "widget", "marches_indice", "^FCHI"), MARCHES_INDICES)
    if (MarchesIndice = "" || InStr(MarchesIndice, ","))
        MarchesIndice := "^FCHI"
    MarchesCryptos := ListeCatalogue(IniRead(F_REGLAGES, "widget", "marches_cryptos", "bitcoin,ethereum"), MARCHES_CRYPTOS)
    MarchesIndices := ListeCatalogue(IniRead(F_REGLAGES, "widget", "marches_indices", "^FCHI,^GSPC,^IXIC"), MARCHES_INDICES)
    MarchesActions := ListeCatalogue(IniRead(F_REGLAGES, "widget", "marches_actions", ""), MARCHES_ACTIONS)
    MarchesTaux := ListeCatalogue(IniRead(F_REGLAGES, "widget", "marches_taux", ""), MARCHES_TAUX)
    ActusW := IniRead(F_REGLAGES, "widget", "actus_w", 1) = 1
    AnglaisW := IniRead(F_REGLAGES, "widget", "anglais_w", 1) = 1
    AnglaisSource := LireChoix("anglais_source", "mix", ["mix", "liste", "tatoeba"])
    VoileBande := IniRead(F_REGLAGES, "widget", "voile_bande", 1) = 1
    PluieW := IniRead(F_REGLAGES, "widget", "pluie_heure", 1) = 1
    AlerteBtc := LireChoix("alerte_btc", 5, [0, 3, 5, 10])
    AlerteSeuils := RegExReplace(IniRead(F_REGLAGES, "widget", "alerte_seuils", ""), "[^0-9,]")
    AlerteActions := LireChoix("alerte_actions", 3, [0, 2, 3, 5])
    RerW := IniRead(F_REGLAGES, "widget", "rer_w", 1) = 1
    RerArret := LireCle("rer_arret", "^\d+$", ""), RerLigne := LireCle("rer_ligne", "^C\d+$", "")
    RerNom := Trim(StrReplace(IniRead(F_REGLAGES, "widget", "rer_nom", ""), "|")), RerGare := Trim(StrReplace(IniRead(F_REGLAGES, "widget", "rer_gare", ""), "|"))
    RerCouleur := LireCle("rer_couleur", "^[0-9a-fA-F]{6}$", "8e8e93"), RerEncre := LireCle("rer_encre", "^[0-9a-fA-F]{6}$", "ffffff")
    RerSens := Trim(IniRead(F_REGLAGES, "widget", "rer_sens", ""))
    LireAnniversaires()
    Animations := IniRead(F_REGLAGES, "widget", "animations", 0) = 1
    PosX    := IniRead(F_REGLAGES, "widget", "x", "")
    PosY    := IniRead(F_REGLAGES, "widget", "y", "")
    if !(IsInteger(PosX) && IsInteger(PosY))      ; absente, incomplète ou invalide : coin haut droit
        PosX := "", PosY := ""
}

; Texte du fichier de réglages qui doit suivre un motif (il finit en ligne de
; commande) ; « defaut » s'il est absent ou invalide
LireCle(cle, motif, defaut) {
    x := Trim(IniRead(F_REGLAGES, "widget", cle, ""))
    return RegExMatch(x, motif) ? x : defaut
}

; Entier du fichier de réglages, borné ; « defaut » s'il est absent ou invalide
LireEntier(cle, defaut, mini, maxi) {
    v := Trim(IniRead(F_REGLAGES, "widget", cle, defaut))
    return IsInteger(v) ? Max(mini, Min(maxi, Integer(v))) : defaut
}

SauverReglages() {
    DirCreate(DOSSIER)
    IniWrite(Opacite, F_REGLAGES, "widget", "opacite")
    IniWrite(Taille, F_REGLAGES, "widget", "taille")
    IniWrite(LargeurPct, F_REGLAGES, "widget", "largeur")
    IniWrite(Verrou ? 1 : 0, F_REGLAGES, "widget", "verrou")
    IniWrite(Traversant ? 1 : 0, F_REGLAGES, "widget", "traversant")
    IniWrite(Heures ? 1 : 0, F_REGLAGES, "widget", "heures")
    IniWrite(Soleil ? 1 : 0, F_REGLAGES, "widget", "soleil")
    IniWrite(LuneReelle ? 1 : 0, F_REGLAGES, "widget", "lune")
    IniWrite(LuneLever ? 1 : 0, F_REGLAGES, "widget", "lune_lever")
    IniWrite(PoliceHeure, F_REGLAGES, "widget", "police_heure")
    IniWrite(PoliceTemp ? 1 : 0, F_REGLAGES, "widget", "police_temp")
    IniWrite(RenduHeure, F_REGLAGES, "widget", "rendu_heure")
    IniWrite(LettresPrecision, F_REGLAGES, "widget", "lettres_precision")
    IniWrite(LettresMoment ? 1 : 0, F_REGLAGES, "widget", "lettres_moment")
    IniWrite(CadranMeteo, F_REGLAGES, "widget", "cadran_meteo")
    IniWrite(CadranChiffres ? 1 : 0, F_REGLAGES, "widget", "cadran_chiffres")
    IniWrite(CalSemaine ? 1 : 0, F_REGLAGES, "widget", "semaine")
    IniWrite(CalFeries ? 1 : 0, F_REGLAGES, "widget", "feries")
    IniWrite(CalVacances ? 1 : 0, F_REGLAGES, "widget", "vacances")
    IniWrite(CalComptes ? 1 : 0, F_REGLAGES, "widget", "comptes")
    IniWrite(CalZone, F_REGLAGES, "widget", "vacances_zone")
    IniWrite(CalPrevisions ? 1 : 0, F_REGLAGES, "widget", "cal_previsions")
    IniWrite(Ville2W ? 1 : 0, F_REGLAGES, "widget", "ville2")
    IniWrite(Ville2Prev ? 1 : 0, F_REGLAGES, "widget", "ville2_prev")
    IniWrite(VigilanceW ? 1 : 0, F_REGLAGES, "widget", "vigilance")
    IniWrite(VigMin, F_REGLAGES, "widget", "vigilance_min")
    IniWrite(SeineW ? 1 : 0, F_REGLAGES, "widget", "seine")
    IniWrite(NuitMode, F_REGLAGES, "widget", "nuit")
    IniWrite(NuitDecalage, F_REGLAGES, "widget", "nuit_decalage")
    IniWrite(NuitPlage, F_REGLAGES, "widget", "nuit_plage")
    IniWrite(NuitIntensite, F_REGLAGES, "widget", "nuit_intensite")
    IniWrite(NuitTeinte, F_REGLAGES, "widget", "nuit_teinte")
    IniWrite(NuitSurvol ? 1 : 0, F_REGLAGES, "widget", "nuit_survol")
    IniWrite(Oled, F_REGLAGES, "widget", "oled")
    IniWrite(Sobre ? 1 : 0, F_REGLAGES, "widget", "sobre")
    IniWrite(SobrePause ? 1 : 0, F_REGLAGES, "widget", "sobre_pause")
    IniWrite(SobreAnim ? 1 : 0, F_REGLAGES, "widget", "sobre_anim")
    IniWrite(SobreMeteo ? 1 : 0, F_REGLAGES, "widget", "sobre_meteo")
    IniWrite(SobreAmbiance ? 1 : 0, F_REGLAGES, "widget", "sobre_ambiance")
    IniWrite(AmbianceActive ? 1 : 0, F_REGLAGES, "widget", "ambiance")
    IniWrite(JoursMarque, F_REGLAGES, "widget", "jours_marque")
    IniWrite(DureeJour ? 1 : 0, F_REGLAGES, "widget", "duree_jour")
    IniWrite(CalHeure ? 1 : 0, F_REGLAGES, "widget", "cal_heure")
    IniWrite(CalSaisons ? 1 : 0, F_REGLAGES, "widget", "cal_saisons")
    IniWrite(UvW ? 1 : 0, F_REGLAGES, "widget", "uv_fort")
    IniWrite(AnnivConfettis ? 1 : 0, F_REGLAGES, "widget", "anniv_confettis")
    IniWrite(AirMode, F_REGLAGES, "widget", "air")
    IniWrite(AirSable ? 1 : 0, F_REGLAGES, "widget", "air_sable")
    IniWrite(AirPollens ? 1 : 0, F_REGLAGES, "widget", "air_pollens")
    IniWrite(ClimatPrev ? 1 : 0, F_REGLAGES, "widget", "climat_prev")
    IniWrite(ClimatWidget ? 1 : 0, F_REGLAGES, "widget", "climat_widget")
    IniWrite(ClimatRecord ? 1 : 0, F_REGLAGES, "widget", "climat_record")
    IniWrite(IssW ? 1 : 0, F_REGLAGES, "widget", "iss")
    IniWrite(IssHmin, F_REGLAGES, "widget", "iss_hmin")
    IniWrite(CielPlanetes ? 1 : 0, F_REGLAGES, "widget", "ciel_planetes")
    IniWrite(CielEtoiles ? 1 : 0, F_REGLAGES, "widget", "ciel_etoiles")
    IniWrite(Animations ? 1 : 0, F_REGLAGES, "widget", "animations")
    IniWrite(Style, F_REGLAGES, "widget", "style")
    IniWrite(MarchesBtcW ? 1 : 0, F_REGLAGES, "widget", "marches_btc")
    IniWrite(MarchesIndiceW ? 1 : 0, F_REGLAGES, "widget", "marches_indice_w")
    IniWrite(MarchesIndice, F_REGLAGES, "widget", "marches_indice")
    IniWrite(MarchesCryptos, F_REGLAGES, "widget", "marches_cryptos")
    IniWrite(MarchesIndices, F_REGLAGES, "widget", "marches_indices")
    IniWrite(MarchesActions, F_REGLAGES, "widget", "marches_actions")
    IniWrite(MarchesTaux, F_REGLAGES, "widget", "marches_taux")
    IniWrite(ActusW ? 1 : 0, F_REGLAGES, "widget", "actus_w")
    IniWrite(AnglaisW ? 1 : 0, F_REGLAGES, "widget", "anglais_w")
    IniWrite(AnglaisSource, F_REGLAGES, "widget", "anglais_source")
    IniWrite(VoileBande ? 1 : 0, F_REGLAGES, "widget", "voile_bande")
    IniWrite(PluieW ? 1 : 0, F_REGLAGES, "widget", "pluie_heure")
    IniWrite(AlerteBtc, F_REGLAGES, "widget", "alerte_btc")
    IniWrite(AlerteSeuils, F_REGLAGES, "widget", "alerte_seuils")
    IniWrite(AlerteActions, F_REGLAGES, "widget", "alerte_actions")
    IniWrite(RerW ? 1 : 0, F_REGLAGES, "widget", "rer_w")
    IniWrite(RerArret, F_REGLAGES, "widget", "rer_arret")
    IniWrite(RerLigne, F_REGLAGES, "widget", "rer_ligne")
    IniWrite(RerNom, F_REGLAGES, "widget", "rer_nom")
    IniWrite(RerGare, F_REGLAGES, "widget", "rer_gare")
    IniWrite(RerCouleur, F_REGLAGES, "widget", "rer_couleur")
    IniWrite(RerEncre, F_REGLAGES, "widget", "rer_encre")
    IniWrite(RerSens, F_REGLAGES, "widget", "rer_sens")
    IniWrite(Couleur, F_REGLAGES, "widget", "couleur")
    IniWrite(Profondeur ? 1 : 0, F_REGLAGES, "widget", "profondeur")
    if (IniRead(F_REGLAGES, "widget", "style", "") != Style)
        Journal("réglages non enregistrés dans " F_REGLAGES)
    if (PosX != "") {
        IniWrite(PosX, F_REGLAGES, "widget", "x")
        IniWrite(PosY, F_REGLAGES, "widget", "y")
    } else {
        try IniDelete(F_REGLAGES, "widget", "x")
        try IniDelete(F_REGLAGES, "widget", "y")
    }
}

; Relit le fichier de données s'il a changé. Renvoie true si c'est le cas.
LireDonnees() {
    global Donnees, DonneesDate
    if !FileExist(F_DONNEES)
        return false
    m := FileGetTime(F_DONNEES, "M")
    if (m = DonneesDate)
        return false
    d := Map()
    try {
        for ligne in StrSplit(FileRead(F_DONNEES, "UTF-8"), "`n", "`r") {
            if (p := InStr(ligne, "="))
                d[SubStr(ligne, 1, p - 1)] := SubStr(ligne, p + 1)
        }
    } catch
        return false
    Donnees := d
    DonneesDate := m
    return true
}

; forcer : relocalisation ; forcerCal : calendrier redemandé tout de suite ;
; calSeul : seulement le calendrier (changement de zone, option cochée)
LancerCollecte(forcer := false, forcerCal := false, calSeul := false) {
    global DerniereCollecte, CollectePID, CollecteT0, CollecteRelance
    if !FileExist(SCRIPT_PS)
        return
    if (CollectePID && ProcessExist(CollectePID)) {   ; une collecte tourne : relancée à sa fin, avec les options du moment
        r := CollecteRelance
        CollecteRelance := {forcer: forcer || (IsObject(r) && r.forcer), forcerCal: forcerCal || (IsObject(r) && r.forcerCal),
            calSeul: calSeul && (!IsObject(r) || r.calSeul)}
        SetTimer(SuivreCollecte, 1000)
        return
    }
    arg := (forcer ? " -ForcerPosition" : "") (CalVacances ? " -ZoneVacances " CalZone : "")
        . ((CalVacances && forcerCal) ? " -ForcerCalendrier" : "") ((CalVacances && calSeul) ? " -CalendrierSeul" : "")
        . (((Ville2W || Ville2Prev) && Ville2Definie()) ? " -Ville2:" ArgPS(Ville2Pos) : "")
        . (VigilanceW ? " -Vigilance" ((VigZone != "") ? " -VigilanceZone:" ArgPS(VigZone) : "") : "")
        . (SeineW ? " -Seine " SeineStation : "")
        . ((AirMode != "0") ? " -Air" : "") (AirSable ? " -Sable" : "") (AirPollens ? " -Pollens" : "")
        . (ClimatActif() ? " -Climat" : "") (IssW ? " -Iss" : "")
    if !calSeul
        DerniereCollecte := MaintenantUnix()      ; même en échec : pas de relance à chaque minute
    try Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
        . SCRIPT_PS '"' arg, , "Hide", &pid)
    catch
        return
    CollectePID := pid, CollecteT0 := A_TickCount
    SetTimer(SuivreCollecte, 1000)                ; les données sont lues dès la fin (1 à 20 s)
}

; Argument de ligne de commande pour PowerShell (-Param:valeur) : un antislash
; final avalerait le guillemet, un tiret initial ferait lire une option
ArgPS(v) => '"' RegExReplace(StrReplace(v, '"'), "(\\+)$", "$1$1") '"'

ActualiserMaintenant(*) {
    LancerCollecte(true, true)                   ; (suivie jusqu'à sa fin par SuivreCollecte)
}
VerifierBientot() => SurveillerDonnees()
VerifierPlusTard() => SurveillerDonnees()

SurveillerDonnees() {
    a := LireDonnees(), b := ChargerFond(), c := LireCalendrier()
    if (a || b || c)
        Redessiner()
}

; Le tic de minute (voir ArmerMinute) : tout ce qui dépend de l'heure, puis un
; seul redessin si l'affichage change
Horloge() {
    global DerniereMin, DerniereCle, DernierJour
    if !DllCall("IsWindow", "Ptr", HWIDGET) {     ; fenêtre détruite
        Reconstruire()
        return
    }
    ; Explorer relancé : la fenêtre survit mais perd son propriétaire. Le message
    ; TaskbarCreated s'en occupe d'ordinaire ; ceci rattrape le cas où il se perd.
    sh := DllCall("GetShellWindow", "Ptr")
    if (sh && DllCall("GetWindow", "Ptr", HWIDGET, "UInt", 4, "Ptr") != sh)   ; GW_OWNER
        AncrerAuBureau()
    m := FormatTime(, "HHmm")
    if (m = DerniereMin)                          ; tic un peu en avance, ou appel en double
        return
    DerniereMin := m
    if ((j := FormatTime(, "yyyyMMdd")) != DernierJour) {   ; nouveau jour : dates du menu des comptes à rebours
        DernierJour := j
        MajMenuComptes()
        MajMenuAnniv()
    }
    majD := LireDonnees(), majF := ChargerFond(), majC := LireCalendrier()   ; (une collecte a pu finir)
    majM := MajRotation()                         ; phrase d'anglais et titre à la une : les suivants toutes les 5 min
    if LireJours() {                              ; jours.txt modifié à la main
        majC := true
        CocherMenus()
        JoursRelu()                               ; (fenêtre repeinte, annulation oubliée)
    }
    if !(Sobre && (EcranEteint || Verrouillee)) { ; écran éteint (mode sobre) : rattrapé au retour
        VerifierAmbiance()                        ; l'heure ou la météo appellent un autre fond ?
        VerifierFond()                            ; fond d'écran changé ? (vérification légère)
    }
    if Sobre
        VerifierSobre()                           ; recouvert ? le redessin attendra sa réapparition
    if CollecteDue()                              ; météo toutes les 15 min (30 sur batterie en mode sobre)
        LancerCollecte()
    if MarchesDue()                               ; marchés et actus toutes les 5 min, s'ils servent
        LancerMarches()
    if (q := RerDue())                            ; transports : départs toutes les 2 min, info trafic toutes les 10
        LancerRer(q)
    pi := false
    nuit := MajNuit()                             ; bascule jour ↔ nuit ?
    c := CleAffichage(m) (Oled ? "|" MaintenantUnix() // 60 : "")   ; (anti-marquage : un pas de 1 px par minute)
    if (c != DerniereCle || pi || nuit || majD || majF || majC || majM) {   ; « aux 5 minutes » : 1 redessin sur 5
        DerniereCle := c
        Redessiner()
    }
    NuitAjusterAlpha()                            ; mode nuit : fondu vers l'intensité du moment
    FeteAuto()                                    ; anniversaire du jour : confettis une fois, widget visible
    if Animations
        AnimVerifier()                            ; en pause si l'illustration est cachée
}

; =============================================================================
;  Souris : clic pour les prévisions, glisser pour déplacer, clic droit pour le menu
;
;  Le glisser est fait à la main (capture de la souris + SetWindowPos sans
;  toucher à l'ordre Z) plutôt que par la boucle de déplacement de Windows :
;  celle-ci peut activer la fenêtre et la remonter, et avec elle le bureau
;  qui la possède, par-dessus tes fenêtres.
;  Tant que le curseur reste à moins de SEUIL_GLISSER px du point d'appui,
;  c'est un clic : il ouvre (ou referme) les prévisions détaillées.
;  Un appui sur une bande du bord (voir ZoneRedim) redimensionne au lieu de
;  déplacer : coin = taille, côté gauche ou droit = largeur.
; =============================================================================

Saisir(wParam, lParam, msg, hwnd) {
    global Glisse, GlisseActif, GlisseBouge, GlisseDouble, GlisseDx, GlisseDy, GlisseX0, GlisseY0, GlisseEcran, Geste, GlisseZone
    if (hwnd != HWIDGET)
        return
    if EnGeste()                                  ; zoom à la molette pas encore validé : on le valide d'abord
        ValiderGeste()
    Curseur(&cx, &cy)
    WinGetPos(&x, &y, &w, &h, HWIDGET)
    GlisseDx := cx - x, GlisseDy := cy - y, GlisseX0 := cx, GlisseY0 := cy
    GlisseZone := ZoneSous(cx - x, cy - y)        ; à l'appui : un redessin d'ici le relâché ne change rien
    GlisseEcran := EcranProche(x + w // 2, y + h // 2)
    GlisseEcran.w := w, GlisseEcran.h := h
    Glisse := true, GlisseActif := false, GlisseBouge := false, GlisseDouble := (msg = 0x203)
    ; sur un bord : redimensionnement possible (il ne démarre qu'au-delà du seuil)
    Geste := ""
    if (!Verrou || ModeEdition) {
        z := ZoneRedim(cx, cy, x, y, w, h)
        if (z != "")
            Geste := {zone: z, actif: false, x0: x - OrbiteDx, y0: y - OrbiteDy, w0: w, h0: h, e: GlisseEcran}   ; position logique
    }
    DllCall("SetCapture", "Ptr", HWIDGET)
    return 0
}

Glisser(wParam, lParam, msg, hwnd) {
    global GlisseActif, GlisseBouge
    if (!Glisse || hwnd != HWIDGET) {
        if (!Glisse && hwnd = HWIDGET)            ; survol la nuit : pleine intensité 10 s
            NuitReveil()
        return
    }
    if !(wParam & 0x1) {                          ; MK_LBUTTON absent : le relâché s'est perdu pendant un rendu
        Lacher(wParam, lParam, 0x215, hwnd)       ; traité comme une capture perdue : ni clic ni prévisions
        return 0
    }
    Curseur(&cx, &cy)
    if !GlisseActif {
        seuil := SEUIL_GLISSER * A_ScreenDPI / 96
        if (Abs(cx - GlisseX0) < seuil && Abs(cy - GlisseY0) < seuil)
            return 0
        GlisseBouge := true
        if (Verrou && !ModeEdition)               ; verrouillé : ni déplacement, ni clic
            return 0
        GlisseActif := true
        if SurgieOuverte()                        ; « taper deux fois et glisser » : le 1er appui l'avait ouverte
            SetTimer(FermerSurgies, -1)
        FeteArreter()                             ; (le sujet du fond ne bouge pas avec le widget)
        if IsObject(Geste)
            DemarrerGeste()
    }
    if IsObject(Geste) {                          ; redimensionnement
        PoserCurseur(Geste.zone)                  ; sous capture, Windows n'envoie plus WM_SETCURSOR
        if CalculerGeste(cx, cy)
            PlanifierRendu()
        return 0
    }
    nx := cx - GlisseDx, ny := cy - GlisseDy
    ; aimantation : près du centre de l'écran, le widget s'y cale (horizontalement et verticalement)
    e := GlisseEcran, seuil := AIMANT * A_ScreenDPI / 96
    ; (sur la position logique : le micro-décalage anti-marquage est gardé tel quel)
    if (Abs(nx - OrbiteDx + e.w / 2 - (e.ml + e.mr) / 2) <= seuil)
        nx := Round((e.ml + e.mr - e.w) / 2) + OrbiteDx
    if (Abs(ny - OrbiteDy + e.h / 2 - (e.mt + e.mb) / 2) <= seuil)
        ny := Round((e.mt + e.mb - e.h) / 2) + OrbiteDy
    ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER
    DllCall("SetWindowPos", "Ptr", HWIDGET, "Ptr", 0, "Int", nx, "Int", ny,
        "Int", 0, "Int", 0, "UInt", 0x215)
    if AnimHwnd                                   ; l'illustration animée suit le widget
        DllCall("SetWindowPos", "Ptr", AnimHwnd, "Ptr", 0, "Int", nx + AnimDx, "Int", ny + AnimDy,
            "Int", 0, "Int", 0, "UInt", 0x215)
    return 0
}

Lacher(wParam, lParam, msg, hwnd) {
    global Glisse, PosX, PosY, Geste, GlisseActif
    if (!Glisse || hwnd != HWIDGET)
        return
    if EnGeste() {                                ; fin d'un redimensionnement (capture perdue comprise)
        ValiderGeste()
        return 0
    }
    Geste := ""
    Glisse := false                               ; avant ReleaseCapture, qui renvoie WM_CAPTURECHANGED
    DllCall("ReleaseCapture")
    if !GlisseActif {
        ; simple clic (pas le 2e appui d'un double-clic, pas un glisser refusé,
        ; pas en mode redimensionnement) sur l'illustration ou la température :
        ; les prévisions. Ailleurs, rien (le menu reste au clic droit).
        if (msg = 0x202 && GlisseZone != "" && !GlisseDouble && !GlisseBouge && !ModeEdition)
            SetTimer(ActionZone.Bind(GlisseZone), -1)
        return 0
    }
    if ModeEdition
        ModeEdition.t0 := A_TickCount             ; activité : le mode ne s'arrête pas tout seul

    ; lâché à moitié hors de l'écran : on le ramène au bord de l'écran le plus proche
    PositionLogique(&x, &y, &w, &h)             ; sans le micro-décalage anti-marquage
    ZoneTravailProche(x + w // 2, y + h // 2, &l, &t, &r, &b)
    PosX := Max(l, Min(x, r - w)), PosY := Max(t, Min(y, b - h))
    GlisseActif := false
    SauverReglages()
    SetTimer(RenduFinal, -1)                      ; hors du gestionnaire de souris (voir RenduFinal)
    return 0
}

; Rendu complet après un geste de souris, lancé par minuteur : fait dans le
; gestionnaire lui-même (0,2 à 2 s), il bloquerait le relâché suivant, qui
; serait perdu (une seule exécution à la fois par message surveillé).
RenduFinal() => Redessiner(true)

Curseur(&x, &y) {
    pt := Buffer(8)
    DllCall("GetCursorPos", "Ptr", pt)
    x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
}

ClicDroit(wParam, lParam, msg, hwnd) {
    if (hwnd != HWIDGET && !IsObject(ZoneFen(hwnd)))   ; (zones du mode « Laisser passer les clics » comprises)
        return
    if EnGeste() {                                ; clic droit pendant un redimensionnement : annulé
        AnnulerGeste()
        return 0
    }
    QuitterEdition()
    (GetKeyState("Shift") ? MenuClassique : MenuWidget).Show()   ; Maj : l'ancien menu complet
    return 0
}

PasActiver(wParam, lParam, msg, hwnd) {
    if (hwnd = HWIDGET || IsObject(ZoneFen(hwnd)))
        return 3                                  ; MA_NOACTIVATE
}

; =============================================================================
;  Zone cliquable « meteo » : l'illustration et la température (→ prévisions
;  détaillées), rien d'autre (le reste du widget ne fait rien au clic ; le
;  clic droit ouvre le menu partout). Notée à la composition (NoterZone, en px
;  de la fenêtre), elle ne sert qu'une fois le rendu posé (ZonesRendu → copie
;  dans ZonesClic, dans Redessiner) : un rendu jeté en route ne laisse pas de
;  zones fausses.
;  Widget normal : tout le widget se saisit (glisser), seul un clic sur la zone
;  agit. « Laisser passer les clics » : seules les zones réagissent, par de
;  petites fenêtres invisibles (alpha 1/255 : elles saisissent les clics,
;  vérifié) posées dessus ; le reste va au bureau.
; =============================================================================

; Ajoute la zone « id » (bornes b {x, y, w, h}) au rendu en cours ; renvoie b
NoterZone(id, b) {
    if (IsObject(b) && b.w > 0 && b.h > 0)
        ZonesRendu.Push({id: id, x: b.x, y: b.y, w: b.w, h: b.h})
    return b
}

; Zone « meteo » d'une ligne météo (iPhone, En toutes lettres, Analogique) :
; l'illustration (bornes bi, ou "") et la température qui ouvre la ligne posée
; en x0 (bornes b) — pas le lieu qui la suit
NoterZoneTemp(bi, x0, b, temp, em) {
    if (temp != "")
        bi := Union(bi, {x: b.x, y: b.y, w: x0 + LargeurTexte(temp Chr(0xB0), P_TEXTE, em) - b.x, h: b.h})
    NoterZone("meteo", bi)
}

; Zone sous le point (rx, ry) de la fenêtre (marge de 6 px logiques), ou ""
ZoneSous(rx, ry) {
    m := 6 * A_ScreenDPI / 96
    for z in ZonesClic
        if (rx >= z.x - m && rx < z.x + z.w + m && ry >= z.y - m && ry < z.y + z.h + m)
            return z.id
    return ""
}

ActionZone(id, *) {
    switch id {
        case "meteo":   OuvrirPrevisions()
        case "marches": OuvrirMarches()           ; (le Bitcoin, l'indice)
        case "rer":     OuvrirMarches()           ; (les prochains départs)
        case "une":     OuvrirFicheActu(UneAffichee, ListeUneWidget())   ; l'article seul, en grand
        case "phrase":  PhraseSuivante()          ; un clic : la phrase suivante
    }
}

; Le widget (et les fenêtres qu'il possède : zones, animation, confettis) juste
; au-dessus du bureau. À rappeler après avoir montré une fenêtre possédée :
; Windows remonte alors tout le groupe au-dessus des applications (vérifié).
WidgetEnBas() => DllCall("SetWindowPos", "Ptr", HWIDGET, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)

; La fenêtre de zone qui a ce handle, ou ""
ZoneFen(hwnd) {
    for f in ZonesFen
        if (f.hwnd = hwnd)
            return f
    return ""
}

; Pose (ou retire) les fenêtres des zones sur le widget posé en (x, y)
ZonesFenMaj(x := "", y := "") {
    global ZonesFen
    if (!Traversant || ModeEdition || !HWIDGET || x = "") {
        ZonesFenFermer()
        return
    }
    m := Round(6 * A_ScreenDPI / 96), r := []
    for z in ZonesClic
        r.Push({id: z.id, x: x + Round(z.x) - m, y: y + Round(z.y) - m, w: Round(z.w) + 2 * m, h: Round(z.h) + 2 * m})
    while (ZonesFen.Length > r.Length)
        try ZonesFen.Pop().g.Destroy()
    cree := false
    for i, z in r {
        if (i > ZonesFen.Length || !DllCall("IsWindow", "Ptr", ZonesFen[i].hwnd)) {
            ; possédée par le widget : juste au-dessus de lui, derrière les applications
            g := Gui("-Caption +ToolWindow -DPIScale +E0x08000000 +Owner" HWIDGET)
            g.BackColor := "000000"
            WinSetTransparent(1, g.Hwnd)          ; invisible, mais saisit les clics (posé avant l'affichage)
            g.Show("NA x" z.x " y" z.y " w1 h1")
            f := {g: g, hwnd: g.Hwnd, id: z.id}
            (i > ZonesFen.Length) ? ZonesFen.Push(f) : (ZonesFen[i] := f)
            cree := true
        }
        ZonesFen[i].id := z.id
        ; SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_SHOWWINDOW
        DllCall("SetWindowPos", "Ptr", ZonesFen[i].hwnd, "Ptr", 0, "Int", z.x, "Int", z.y, "Int", z.w, "Int", z.h, "UInt", 0x254)
    }
    if cree                                       ; sinon le widget passerait devant tes fenêtres
        WidgetEnBas()
}

ZonesFenFermer() {
    global ZonesFen
    for f in ZonesFen
        try f.g.Destroy()
    ZonesFen := []
}

ZoneFenAppui(wParam, lParam, msg, hwnd) {
    global GlisseZone
    if !IsObject(f := ZoneFen(hwnd))
        return
    GlisseZone := (msg = 0x203) ? "" : f.id       ; 2e appui d'un double-clic : il ne referme pas ce qui vient de s'ouvrir
    return 0
}

ZoneFenRelache(wParam, lParam, msg, hwnd) {
    global GlisseZone
    if !IsObject(f := ZoneFen(hwnd))
        return
    if (GlisseZone = f.id)                        ; appui et relâché dans la même zone
        SetTimer(ActionZone.Bind(f.id), -1)
    GlisseZone := ""
    return 0
}

; =============================================================================
;  Redimensionnement : un coin change la taille (TAILLE_MIN à TAILLE_MAX),
;  le côté gauche ou droit la largeur (le contenu se remet en page), et
;  Ctrl+molette la taille.
;
;  Pendant le geste, un rendu « brouillon » (sans ombre ni effet profondeur,
;  15 à 30 ms) suit le curseur à la vraie taille ; le rendu complet (0,2 à
;  0,7 s) n'est fait qu'au lâcher. Les redessins ordinaires (chaque minute,
;  nouvelles données…) attendent la fin du geste (voir Redessiner).
;  Geste : objet créé à l'appui sur un bord (Saisir) ou au premier cran de
;  molette, « actif » dès que le redimensionnement a vraiment commencé.
; =============================================================================

EnGeste() => IsObject(Geste) && Geste.actif

; Largeur des bandes de redimensionnement : toujours dans la marge PAD, hors du contenu
BandeRedim(k) => Max(Round(6 * A_ScreenDPI / 96), Min(Round(12 * A_ScreenDPI / 96), Round(0.7 * PAD * k)))

; Zone sous le point (cx, cy) du widget (x, y, w, h) : "hg", "hd", "bg", "bd"
; (coins), "g", "d" (côtés), "" (intérieur ; les bords haut et bas en font partie)
ZoneRedim(cx, cy, x, y, w, h) {
    rx := cx - x, ry := cy - y
    if (rx < 0 || ry < 0 || rx >= w || ry >= h)
        return ""
    b := BandeRedim(Echelle())
    if ModeEdition {                              ; poignées plus grandes (utilisables au doigt)
        c := Min(w, h) / 4, bc := 2 * b
        if ((rx < c || rx >= w - c) && (ry < c || ry >= h - c))
            return ((ry < h / 2) ? "h" : "b") ((rx < w / 2) ? "g" : "d")
    } else {
        c := 2.5 * b, bc := b
        ; coin en L : sur une bande, à moins de 2,5 bandes du bord perpendiculaire
        if (((rx < b || rx >= w - b) && (ry < c || ry >= h - c)) || ((ry < b || ry >= h - b) && (rx < c || rx >= w - c)))
            return ((ry < h / 2) ? "h" : "b") ((rx < w / 2) ? "g" : "d")
    }
    return (rx < bc) ? "g" : (rx >= w - bc) ? "d" : ""
}

; Curseurs Windows : diagonales, horizontal, et déplacement (mode redimensionnement)
CurseurZone(z) => (z = "hg" || z = "bd") ? 32642 : (z = "hd" || z = "bg") ? 32643 : (z = "g" || z = "d") ? 32644 : 32646

PoserCurseur(z) => DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", CurseurZone(z), "Ptr"))

; WM_SETCURSOR : flèches de redimensionnement sur les bords, et flèche de
; déplacement partout en mode « Redimensionner à la souris »
CurseurRedim(wParam, lParam, msg, hwnd) {
    if ((lParam & 0xFFFF) != 1 || Glisse)         ; hors de la zone cliente, ou bouton appuyé
        return
    if IsObject(ZoneFen(hwnd)) {                  ; zone du mode « Laisser passer les clics » : une main
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))
        return 1
    }
    if (hwnd != HWIDGET)
        return
    Curseur(&cx, &cy)
    WinGetPos(&x, &y, &w, &h, HWIDGET)
    z := (Verrou && !ModeEdition) ? "" : ZoneRedim(cx, cy, x, y, w, h)
    if (z = "" && !ModeEdition) {
        if (ZoneSous(cx - x, cy - y) != "") {     ; ce qui s'ouvre d'un clic : une main
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))
            return 1
        }
        return
    }
    PoserCurseur(z)
    return 1
}

; Premier mouvement au-delà du seuil sur un bord : tout ce qui sert au calcul
; est figé ici (Geste créé par Saisir : zone, rectangle de départ, écran)
DemarrerGeste() {
    global OrbiteDx, OrbiteDy
    g := Geste, e := g.e
    OrbiteDx := 0, OrbiteDy := 0                  ; le brouillon se peint à la position logique
    ; valeurs de départ lues AVANT de passer « actif » : ensuite, Echelle() et
    ; LargeurContenu() lisent celles du geste (g.t, g.lp)
    g.t0 := TailleVisible(), g.lp0 := LargeurPct
    g.t := g.t0, g.lp := g.lp0, g.x := g.x0, g.y := g.y0, g.aimante := false, g.affiche := "", g.prochain := 0, g.duree := 20
    g.theme := ThemeCourant, g.actif := true
    g.sx := InStr(g.zone, "d") ? 1 : -1           ; bord tiré : droit ou gauche
    g.sy := InStr(g.zone, "b") ? 1 : InStr(g.zone, "h") ? -1 : 0   ; bas, haut, ou aucun (côté)
    ; un axe où le widget est centré sur l'écran le reste ; sinon le bord opposé ne bouge pas
    g.cX := Abs(g.x0 + g.w0 / 2 - (e.ml + e.mr) / 2) <= 1
    g.cY := Abs(g.y0 + g.h0 / 2 - (e.mt + e.mb) / 2) <= 1
    g.ax := g.cX ? g.x0 + g.w0 / 2 : (g.sx > 0 ? g.x0 : g.x0 + g.w0)
    g.ay := g.cY ? g.y0 + g.h0 / 2 : (g.sy > 0 ? g.y0 : g.y0 + g.h0)
    g.mX := g.cX ? 2 : 1, g.mY := g.cY ? 2 : 1
    ; décalage curseur -> bord tiré au moment de l'appui : pas de saut au départ
    g.offX := GlisseX0 - (g.x0 + (g.sx > 0 ? g.w0 : 0))
    g.offY := GlisseY0 - (g.y0 + (g.sy > 0 ? g.h0 : 0))
    ; place disponible dans le sens du geste, dans la zone de travail de l'écran de départ
    wDispo := g.cX ? 2 * Min(g.ax - e.l, e.r - g.ax) : (g.sx > 0 ? e.r - g.ax : g.ax - e.l)
    hDispo := g.cY ? 2 * Min(g.ay - e.t, e.b - g.ay) : (g.sy > 0 ? e.b - g.ay : (g.sy < 0) ? g.ay - e.t : g.h0)
    g.tmin := TAILLE_MIN
    g.tmax := Max(g.t0, Min(TAILLE_MAX, Floor(g.t0 * Min(wDispo / g.w0, hDispo / g.h0))))
    g.lpmin := Ceil(50 * LargeurMin())
    g.lpmax := Max(g.lp0, Min(175, Floor(50 * (wDispo / EchellePour(g.t0) - 2 * PAD) / HC)))
    AnimSuspendre()
    FeteArreter()
    CrochetClics()                                ; Échap annule le geste
    if ModeEdition
        ModeEdition.t0 := A_TickCount
}

; Taille ou largeur visée pour le curseur en (cx, cy), et la position qui va
; avec. Renvoie true si elle a changé (un nouveau rendu est alors utile).
CalculerGeste(cx, cy) {
    g := Geste
    libre := !GetKeyState("Shift", "P")           ; Maj maintenue : pas d'aimant
    aimante := false, t := g.t0, lp := g.lp0
    if (g.sy != 0) {                              ; coin : taille, projetée sur la diagonale du widget
        wx := g.mX * g.sx * ((cx - g.offX) - g.ax)
        hy := g.mY * g.sy * ((cy - g.offY) - g.ay)
        t := g.t0 * (wx * g.w0 + hy * g.h0) / (g.w0 ** 2 + g.h0 ** 2)
        if libre
            for a in TAILLES
                if (Abs(t - a) <= AIMANT_PCT && a <= g.tmax)
                    t := a, aimante := true
        t := Round(Max(g.tmin, Min(g.tmax, t)))
    } else {                                      ; côté : largeur du contenu
        wv := g.mX * g.sx * ((cx - g.offX) - g.ax)
        lp := 50 * (wv / EchellePour(g.t0) - 2 * PAD) / HC
        if (libre && Abs(lp - 100) <= AIMANT_PCT)
            lp := 100, aimante := true
        lp := Round(Max(g.lpmin, Min(g.lpmax, lp)))
    }
    if (t = g.t && lp = g.lp && g.affiche != "")
        return false
    k := EchellePour(t)
    w := Round(LargeurWidget(lp) * k), h := Round(HauteurWidget() * k)
    g.t := t, g.lp := lp, g.aimante := aimante
    ; axe centré : recalculé depuis le centre de l'écran, sans dérive d'arrondi d'un geste à l'autre
    g.x := g.cX ? Round((g.e.ml + g.e.mr - w) / 2) : (g.sx > 0 ? Round(g.ax) : Round(g.ax - w))
    g.y := (g.sy = 0) ? g.y0 : g.cY ? Round((g.e.mt + g.e.mb - h) / 2) : (g.sy > 0 ? Round(g.ay) : Round(g.ay - h))
    if (g.sy != 0)
        txt := t " %" ((t >= g.tmax) ? " · max" : (t <= g.tmin) ? " · min" : "")
    else
        txt := "Largeur " lp " %" ((lp >= g.lpmax) ? " · max" : (lp <= g.lpmin) ? " · min" : "")
    if HWIDGET                                    ; pas de bulle pendant l'auto-test
        ToolTip(txt, cx + 24, cy + 24, 1)
    return true
}

; Prochain rendu brouillon au plus tôt 1,5 fois sa propre durée après le
; précédent (le fil n'est jamais saturé), toujours sur la dernière cible
PlanifierRendu() {
    reste := Geste.prochain - A_TickCount
    if (reste <= 0)
        RenduGeste()
    else
        SetTimer(RenduGeste, -reste)
}

RenduGeste() {
    ; « Critical -1 » : aucun message n'est traité pendant le brouillon (15 à 70 ms).
    ; Un mouvement, un cran de molette ou le lâcher attendent la fin : sinon ils
    ; interrompaient le rendu, et une image dépassée était posée après la bonne.
    Critical -1
    if !EnGeste()
        return
    g := Geste, t0 := A_TickCount
    k := EchellePour(g.t)
    Peindre(g.x, g.y, true, Round(LargeurWidget(g.lp) * k), Round(HauteurWidget() * k), k, true)
    g.affiche := g.t "|" g.lp
    g.duree := A_TickCount - t0
    g.prochain := A_TickCount + Max(16, Round(1.5 * g.duree))
}

; Lâcher (ou 0,4 s après le dernier cran de molette) : la taille est adoptée
ValiderGeste() {
    global Taille, LargeurPct, PosX, PosY
    Critical -1
    if !EnGeste()                                 ; minuteur de la molette arrivé après la fin du geste
        return
    g := Geste
    if (g.affiche != g.t "|" g.lp)                ; la fenêtre doit montrer ce qui est adopté :
        RenduGeste()                              ; un geste suivant part de sa taille réelle
    FinirGeste()
    if (g.t != g.t0)                              ; un geste de largeur garde la taille choisie,
        Taille := g.t                             ; même réduite à l'écran (TailleVisible)
    LargeurPct := g.lp
    if (g.t != g.t0 || g.lp != g.lp0 || g.x != g.x0 || g.y != g.y0)
        PosX := g.x, PosY := g.y
    SauverReglages()
    CocherMenus()
    Journal("redimensionné (" g.zone ") : taille " Taille " %, largeur " LargeurPct " %, position " PosX "," PosY)
    SetTimer(RenduFinal, -1)                      ; rendu complet hors du gestionnaire de souris
}

; Clic droit ou Échap pendant le geste : retour à la taille et à la place d'avant
; (d'abord en brouillon, tout de suite, pour qu'un nouvel appui parte du bon rectangle)
AnnulerGeste(*) {
    Critical -1
    if !EnGeste()
        return
    g := Geste
    g.t := g.t0, g.lp := g.lp0, g.x := g.x0, g.y := g.y0, g.aimante := false
    RenduGeste()
    FinirGeste()
    SetTimer(RenduFinal, -1)
}

FinirGeste() {
    global Glisse, Geste, MolCumul, RenduGen, GlisseActif
    Glisse := false, GlisseActif := false, Geste := "", MolCumul := 0   ; avant ReleaseCapture, qui renvoie WM_CAPTURECHANGED
    RenduGen += 1                                 ; un rendu complet commencé avant le geste est périmé
    DllCall("ReleaseCapture")
    SetTimer(RenduGeste, 0)
    SetTimer(ValiderGeste, 0)
    CrochetClics()
    ToolTip(, , , 1)
}

EchapRedim(*) {
    if EnGeste()
        AnnulerGeste()
    else
        QuitterEdition()
}

; Échap et clics globaux (crochets d'AutoHotkey), posés seulement quand ils
; servent : geste ou mode de redimensionnement, fenêtre surgissante ouverte.
; Une seule fonction par touche : les deux usages se partagent les mêmes crochets.
CrochetClics() {
    souris := ModeEdition || SurgieOuverte()
    try Hotkey("~*LButton", ClicGlobal, souris ? "On" : "Off")
    try Hotkey("~*RButton", ClicGlobal, souris ? "On" : "Off")
    try Hotkey(TOUCHE_ECHAP, EchapGlobal, (souris || EnGeste()) ? "On" : "Off")
}

ClicGlobal(*) {
    if ModeEdition
        ClicPendantEdition()
    if SurgieOuverte()
        ClicPendantSurgie()
}

EchapGlobal(*) {
    if (EnGeste() || ModeEdition)
        EchapRedim()
    else if (SurgieOuverte() && !SurgieDialogue) {   ; (une boîte de dialogue ouverte : Échap tapé ailleurs ne ferme rien)
        ; pas quand Échap vise une de nos boîtes de dialogue (renommer, couleur…)
        fg := DllCall("GetForegroundWindow", "Ptr")
        if (fg = PopupHwnd || fg = JoursHwnd || fg = ReglHwnd || fg = MarchesHwnd || fg = FicheHwnd || PidFenetre(fg) != DllCall("GetCurrentProcessId"))
            SetTimer(FermerSurgies.Bind("Échap"), -1)
    }
}

; Ctrl+molette (ou pincement du pavé tactile) sur le widget : ±5 % par cran, le
; point sous le curseur restant sous le curseur ; molette seule en mode
; redimensionnement. Adopté 0,4 s après le dernier cran.
Molette(wParam, lParam, msg, hwnd) {
    global MolCumul, Geste, OrbiteDx, OrbiteDy
    if (hwnd != HWIDGET || Glisse)
        return
    if !(ModeEdition || ((wParam & 0x8) && !Verrou))   ; MK_CONTROL
        return
    Critical -1                                   ; les crans suivants attendent : aucun n'est perdu
    d := (wParam >> 16) & 0xFFFF
    MolCumul += (d >= 0x8000) ? d - 0x10000 : d
    n := (MolCumul >= 0) ? Floor(MolCumul / 120) : -Floor(-MolCumul / 120)
    if !n
        return 0
    MolCumul -= n * 120
    if !EnGeste() {
        PositionLogique(&x, &y, &w, &h)
        OrbiteDx := 0, OrbiteDy := 0              ; le brouillon se peint à la position logique
        e := EcranProche(x + w // 2, y + h // 2)
        t0 := TailleVisible()
        Geste := {zone: "molette", actif: true, theme: ThemeCourant, t0: t0, lp0: LargeurPct, t: t0, lp: LargeurPct,
            x0: x, y0: y, x: x, y: y, e: e, affiche: "", prochain: 0, duree: 20, aimante: false,
            cX: Abs(x + w / 2 - (e.ml + e.mr) / 2) <= 1, cY: Abs(y + h / 2 - (e.mt + e.mb) / 2) <= 1,
            tmax: Max(t0, Min(TAILLE_MAX, TailleQuiTient()))}
        AnimSuspendre()
        FeteArreter()
        CrochetClics()                            ; Échap annule le geste
    }
    g := Geste
    ; palier de 5 % suivant dans le sens du cran (137 → 140 ou 135)
    t := Max(TAILLE_MIN, Min(g.tmax, ((n > 0) ? Floor(g.t / 5) : Ceil(g.t / 5)) * 5 + 5 * n))
    if (t != g.t) {
        k := EchellePour(g.t), w := Round(LargeurWidget(g.lp) * k), h := Round(HauteurWidget() * k)
        k := EchellePour(t), w2 := Round(LargeurWidget(g.lp) * k), h2 := Round(HauteurWidget() * k)
        Curseur(&cx, &cy)
        nx := g.cX ? Round((g.e.ml + g.e.mr - w2) / 2) : Round(cx - (cx - g.x) * w2 / w)
        ny := g.cY ? Round((g.e.mt + g.e.mb - h2) / 2) : Round(cy - (cy - g.y) * h2 / h)
        g.t := t, g.x := Max(g.e.l, Min(nx, g.e.r - w2)), g.y := Max(g.e.t, Min(ny, g.e.b - h2))
        ToolTip(t " %" ((t >= g.tmax) ? " · max" : (t <= TAILLE_MIN) ? " · min" : ""), cx + 24, cy + 24, 1)
        PlanifierRendu()
    }
    SetTimer(ValiderGeste, -400)
    if ModeEdition
        ModeEdition.t0 := A_TickCount
    return 0
}

; Mode « Redimensionner à la souris… » (menu Taille) : le seul accès au geste
; quand le widget est verrouillé ou laisse passer les clics. Cadre et poignées
; visibles, intérieur = déplacer, molette seule = taille. Échap, un clic
; ailleurs, 30 s sans rien faire ou le même menu en sortent.
EntrerEdition(*) {
    global ModeEdition
    if ModeEdition {
        QuitterEdition()
        return
    }
    FermerSurgies()
    ModeEdition := {t0: A_TickCount}
    if Traversant
        try WinSetExStyle("-0x20", HWIDGET)
    ; Échap, et un clic ailleurs termine le mode : capté au moment de l'appui (un
    ; relevé périodique ratait les clics brefs). « ~ » : le clic arrive quand même.
    CrochetClics()
    SetTimer(SurveillerEdition, 1000)
    CocherMenus()
    Redessiner()
    WinGetPos(&x, &y, &w, &h, HWIDGET)
    d := A_ScreenDPI / 96
    ToolTip("Coin : taille  ·  côté : largeur  ·  molette : taille  ·  intérieur : déplacer`n"
        . "Échap ou un clic ailleurs pour terminer", x, (y > 80 * d) ? y - Round(60 * d) : y + h + Round(8 * d), 2)
}

SurveillerEdition() {
    if !ModeEdition {
        SetTimer(SurveillerEdition, 0)
        return
    }
    if (EnGeste() || Glisse) {
        ModeEdition.t0 := A_TickCount
        return
    }
    if (A_TickCount - ModeEdition.t0 > 30000)
        QuitterEdition()
}

; Appui d'un bouton pendant le mode : hors du widget et hors de nos fenêtres
; (menus, bulles), il termine le mode
ClicPendantEdition(*) {
    if !ModeEdition
        return
    Curseur(&cx, &cy)
    hw := DllCall("WindowFromPoint", "Int64", (cy << 32) | (cx & 0xFFFFFFFF), "Ptr")
    r := hw ? DllCall("GetAncestor", "Ptr", hw, "UInt", 2, "Ptr") : 0
    try pid := WinGetPID("ahk_id " r)
    catch
        pid := 0
    if (r && r != HWIDGET && pid != ProcessExist())
        SetTimer(QuitterEdition, -1)
}

QuitterEdition() {
    global ModeEdition
    if !ModeEdition
        return
    ModeEdition := ""
    SetTimer(SurveillerEdition, 0)
    CrochetClics()                                ; crochets retirés (sauf fenêtre surgissante ouverte)
    ToolTip(, , , 2)
    if Traversant
        try WinSetExStyle("+0x20", HWIDGET)
    CocherMenus()
    if EnGeste()
        ValiderGeste()
    else
        SetTimer(RenduFinal, -1)                  ; sans cadre ; par minuteur : le menu du clic droit n'attend pas
}

; =============================================================================
;  Menus. Clic droit sur le widget et icône de la zone de notification : un
;  petit menu (prévisions, Mes jours, Réglages…). Les sous-menus des options
;  forment l'ancien menu complet (MenuClassique, Maj + clic droit) : toujours
;  construits et cochés, ils portent les lignes d'état que lit la fenêtre Réglages.
; =============================================================================

ConstruireMenus() {
    global MenuWidget, MenuClassique, MenuTaille, MenuFond, MenuStyle, MenuCouleur, MenuPosition, MenuAfficher, MenuLune, MenuLettres, MenuCadran, MenuCalendrier, MenuComptesSuppr, MenuZone, MenuMarque, MenuAnniv, MenuAnnivSuppr, MenuAir, LibEtatAir, MenuClimat, MenuCiel, MenuIssHmin, MenuVille2, LibV2, MenuVigilance, LibEtatVig, LibSeine, MenuPi, EtatProf, LibTaille,
        MenuEcran, MenuNuit, MenuNuitDecalage, MenuNuitIntensite, MenuNuitTeinte, LibEtatNuit, MenuOled, MenuSobre, LibEtatSobre
    A_IconTip := "Widget météo " VERSION
    ; ce qui s'affiche en plus sur le bureau : rien par défaut
    MenuAfficher := Menu()
    MenuAfficher.Add(LIB_HEURES, BasculerHeures)
    MenuAfficher.Add(LIB_SOLEIL, BasculerSoleil)
    MenuAfficher.Add(LIB_DUREE, BasculerDureeJour)
    MenuLune := Menu()
    MenuLune.Add(LIB_LUNE, BasculerLune)
    MenuLune.Add(LIB_LUNE_LEVER, BasculerLuneLever)
    MenuAfficher.Add("Lune", MenuLune)
    MenuClimat := Menu()
    MenuClimat.Add(LIB_CLIMAT_PREV, BasculerClimat.Bind("prev"))
    MenuClimat.Add(LIB_CLIMAT_WIDGET, BasculerClimat.Bind("widget"))
    MenuClimat.Add(LIB_CLIMAT_RECORD, BasculerClimat.Bind("record"))
    MenuAfficher.Add(LIB_CLIMAT, MenuClimat)
    MenuIssHmin := Menu()
    for v in ISS_HMINS
        MenuIssHmin.Add(v[2], ChoisirIssHmin.Bind(v[1]))
    MenuCiel := Menu()
    MenuCiel.Add(LIB_ISS, BasculerIss)
    MenuCiel.Add(LIB_ISS_HMIN, MenuIssHmin)
    MenuCiel.Add()
    MenuCiel.Add(LIB_PLANETES, BasculerCiel.Bind("planetes"))
    MenuCiel.Add(LIB_ETOILES, BasculerCiel.Bind("etoiles"))
    MenuAfficher.Add(LIB_CIEL, MenuCiel)
    MenuComptesSuppr := Menu()
    MenuZone := Menu()
    for v in ZONES
        MenuZone.Add(v[2], ChoisirZone.Bind(v[1]))
    MenuCalendrier := Menu()
    for v in [[LIB_SEMAINE, "semaine"], [LIB_FERIES, "feries"], [LIB_VACANCES, "vacances"], [LIB_COMPTES, "comptes"],
        [LIB_CAL_HEURE, "heure"], [LIB_CAL_SAISONS, "saisons"]]
        MenuCalendrier.Add(v[1], BasculerCal.Bind(v[2]))
    MenuCalendrier.Add()
    MenuCalendrier.Add(LIB_AJOUT, AjouterCompte)
    MenuCalendrier.Add(LIB_SUPPR, MenuComptesSuppr)
    MenuCalendrier.Add()
    MenuCalendrier.Add(LIB_ZONE, MenuZone)
    MenuCalendrier.Add(LIB_CAL_PREV, BasculerCal.Bind("previsions"))
    MenuCalendrier.Add()
    MenuCalendrier.Add(LIB_JOURS, OuvrirJours)
    MenuMarque := Menu()
    for v in JOURS_MARQUES
        MenuMarque.Add(v[2], ChoisirMarque.Bind(v[1]))
    MenuCalendrier.Add(LIB_JOURS_MARQUE, MenuMarque)
    MenuAnnivSuppr := Menu()
    MenuAnniv := Menu()
    MenuAnniv.Add(LIB_ANNIV_AJOUT, AjouterAnniv)
    MenuAnniv.Add(LIB_ANNIV_MOI, MonAnniv)
    MenuAnniv.Add(LIB_ANNIV_SUPPR, MenuAnnivSuppr)
    MenuAnniv.Add()
    MenuAnniv.Add(LIB_CONFETTIS, BasculerConfettis)
    MenuAnniv.Add(LIB_CONFETTIS_VOIR, (*) => FeteLancer(false))
    MenuCalendrier.Add(LIB_ANNIV, MenuAnniv)
    MajMenuAnniv()
    MajMenuComptes()
    MenuAfficher.Add()
    MenuAfficher.Add(LIB_CALENDRIER, MenuCalendrier)
    MenuVille2 := Menu()
    MenuVille2.Add(LIB_V2_CHOISIR, (*) => ChoisirVille2())
    LibV2 := LibelleVille2()                      ; « Ville : … » (grisé, renommé par CocherMenus)
    MenuVille2.Add(LibV2, (*) => 0)
    MenuVille2.Disable(LibV2)
    MenuVille2.Add()
    MenuVille2.Add(LIB_V2_WIDGET, BasculerVille2.Bind("widget"))
    MenuVille2.Add(LIB_V2_PREV, BasculerVille2.Bind("prev"))
    MenuVille2.Add()
    MenuVille2.Add(LIB_V2_OUBLIER, OublierVille2)
    MenuAfficher.Add(LIB_VILLE2, MenuVille2)
    MenuVigilance := Menu()
    MenuVigilance.Add(LIB_VIG, BasculerVigilance)
    MenuVigilance.Add(LIB_VIG_JAUNE, ChoisirVigMin.Bind(2))
    MenuVigilance.Add(LIB_VIG_ORANGE, ChoisirVigMin.Bind(3))
    LibEtatVig := ETAT_VIG_VIDE                   ; « ↳ … » (grisé, renommé par MajEtatVigilance)
    MenuVigilance.Add(LibEtatVig, (*) => 0)
    MenuVigilance.Disable(LibEtatVig)
    MenuVigilance.Add()
    LibSeine := StrReplace("Seine haute (" SeineLieu ")", "&", "&&")
    MenuVigilance.Add(LibSeine, BasculerSeine)
    MenuVigilance.Add(LIB_UV, BasculerUV)
    MenuAir := Menu()
    for v in AIR_MODES
        MenuAir.Add(v[2], ChoisirAirMode.Bind(v[1]))
    MenuAir.Add()
    MenuAir.Add(LIB_AIR_SABLE, BasculerAirOption.Bind("sable"))
    MenuAir.Add(LIB_AIR_POLLENS, BasculerAirOption.Bind("pollens"))
    MenuAir.Add()
    LibEtatAir := ETAT_VIG_VIDE                   ; « ↳ … » (grisé, renommé par MajEtatAir)
    MenuAir.Add(LibEtatAir, (*) => 0)
    MenuAir.Disable(LibEtatAir)
    MenuAir.Add(LIB_AIR_CARTE, OuvrirCarteAirparif)
    MenuVigilance.Add(LIB_AIR, MenuAir)
    MenuVigilance.Add()
    MenuVigilance.Add(LIB_CARTE_VIG, OuvrirCarteVigilance)
    MenuVigilance.Add(LIB_METEOALARM, OuvrirMeteoAlarm)
    MenuAfficher.Add()
    MenuAfficher.Add(LIB_VIGILANCE, MenuVigilance)
    MenuNuit := Menu()
    for v in NUIT_MODES
        MenuNuit.Add(v[2], ChoisirNuit.Bind(v[1]))
    MenuNuit.Add()
    MenuNuitDecalage := Menu()
    for v in NUIT_DECALAGES
        MenuNuitDecalage.Add(v[2], ChoisirNuitDecalage.Bind(v[1]))
    MenuNuit.Add(LIB_NUIT_DECALAGE, MenuNuitDecalage)
    MenuNuit.Add(LIB_NUIT_PLAGE, ChoisirPlageNuit)
    MenuNuitIntensite := Menu()
    for v in NUIT_INTENSITES
        MenuNuitIntensite.Add(v " %", ChoisirNuitIntensite.Bind(v))
    MenuNuit.Add(LIB_NUIT_INTENSITE, MenuNuitIntensite)
    MenuNuitTeinte := Menu()
    for v in NUIT_TEINTES
        MenuNuitTeinte.Add(v[2], ChoisirNuitTeinte.Bind(v[1]))
    MenuNuit.Add(LIB_NUIT_TEINTE, MenuNuitTeinte)
    MenuNuit.Add(LIB_NUIT_SURVOL, BasculerNuitSurvol)
    MenuNuit.Add()
    MenuNuit.Add(LIB_NUIT_ESSAI, EssayerNuit)
    LibEtatNuit := ETAT_VIG_VIDE                  ; « ↳ … » (grisé, renommé par MajEtatNuit)
    MenuNuit.Add(LibEtatNuit, (*) => 0)
    MenuNuit.Disable(LibEtatNuit)
    MenuEcran := Menu()
    MenuEcran.Add(LIB_NUIT, MenuNuit)
    MenuOled := Menu()
    for v in OLED_MODES
        MenuOled.Add(v[2], ChoisirOled.Bind(v[1]))
    MenuEcran.Add(LIB_OLED, MenuOled)
    MenuSobre := Menu()
    MenuSobre.Add(LIB_SOBRE_ON, BasculerSobre.Bind("actif"))
    MenuSobre.Add()
    for v in SOBRE_CASES
        MenuSobre.Add(v[2], BasculerSobre.Bind(v[1]))
    MenuSobre.Add()
    LibEtatSobre := ETAT_VIG_VIDE                 ; « ↳ … » (grisé, renommé par MajEtatSobre)
    MenuSobre.Add(LibEtatSobre, (*) => 0)
    MenuSobre.Disable(LibEtatSobre)
    MenuEcran.Add(LIB_SOBRE, MenuSobre)
    MenuPosition := Menu()
    MenuPosition.Add("Centrer horizontalement", Centrer.Bind(true, false))
    MenuPosition.Add("Centrer au milieu de l'écran", Centrer.Bind(true, true))
    MenuPosition.Add("Remettre en haut à droite", Reinitialiser)
    MenuPosition.Add()
    MenuPosition.Add(LIB_TRAVERSANT, BasculerTraversant)
    ConstruireMenuHeure()
    MenuStyle := Menu()
    for v in STYLES
        MenuStyle.Add(v[2], ChoisirStyle.Bind(v[1]))
    MenuLettres := Menu()
    for v in PRECISIONS
        MenuLettres.Add(v[2], ChoisirPrecision.Bind(v[1]))
    MenuLettres.Add()
    MenuLettres.Add(LIB_MOMENT, BasculerMoment)
    MenuCadran := Menu()
    for v in DISPOS_CADRAN
        MenuCadran.Add(v[2], ChoisirDispoCadran.Bind(v[1]))
    MenuCadran.Add()
    MenuCadran.Add(LIB_CHIFFRES, BasculerChiffres)
    MenuStyle.Add()
    MenuStyle.Add(LIB_OPT_LETTRES, MenuLettres)
    MenuStyle.Add(LIB_OPT_CADRAN, MenuCadran)
    MenuCouleur := Menu()
    for v in COULEURS
        MenuCouleur.Add(v[2], ChoisirCouleur.Bind(v[1]))
    MenuTaille := Menu()
    MenuTaille.Add("Agrandir (+10 %)", ChangerTaille.Bind(10))
    MenuTaille.Add("Réduire (−10 %)", ChangerTaille.Bind(-10))
    MenuTaille.Add()
    for v in TAILLES
        MenuTaille.Add(v " %", ChoisirTaille.Bind(v))
    MenuTaille.Add(LIB_LARGEUR0, LargeurOrigine)
    MenuTaille.Add()
    MenuTaille.Add(LIB_EDITION, EntrerEdition)
    LibTaille := LibelleTaille()                  ; « Actuelle : 137 % » (grisé, renommé par CocherMenus)
    MenuTaille.Add(LibTaille, (*) => 0)
    MenuTaille.Disable(LibTaille)
    MenuFond := Menu()
    for v in OPACITES
        MenuFond.Add(NomFond(v), ChoisirFond.Bind(v))
    m := MenuClassique := Menu()
    m.Add("Widget météo " VERSION " · menu complet", (*) => 0)
    m.Disable("Widget météo " VERSION " · menu complet")
    m.Add()
    m.Add("Prévisions détaillées…", OuvrirPrevisions)
    m.Add("Actus et marchés…", OuvrirMarches)
    m.Add("Réglages…", OuvrirReglages)
    m.Add("Afficher", MenuAfficher)
        m.Add()
    m.Add("Style", MenuStyle)
    m.Add("Couleur", MenuCouleur)
    m.Add("Heure", MenuHeure)
    m.Add(LIB_PROFONDEUR, BasculerProfondeur)
    m.Add(ETAT_VIDE, ClicEtatProfondeur)
    m.Add(LIB_AMBIANCE, BasculerAmbiance)
    m.Add(LIB_ANIMATIONS, BasculerAnimations)
    m.Add(LIB_ECRAN, MenuEcran)
    m.Add()
    m.Add("Taille", MenuTaille)
    m.Add("Arrière-plan", MenuFond)
    m.Add("Position", MenuPosition)
    m.Add(LIB_VERROU, BasculerVerrou)
    m.Add()
    m.Add("Actualiser la météo et la position", ActualiserMaintenant)
    m.Add()
    m.Add("Quitter", (*) => ExitApp())
    ; le petit menu : clic droit sur le widget, et icône de la zone de notification
    MenuWidget := Menu()
    A_TrayMenu.Delete()
    for m in [MenuWidget, A_TrayMenu] {
        m.Add("Widget météo " VERSION, (*) => 0)
        m.Disable("Widget météo " VERSION)
        m.Add()
        m.Add("Prévisions détaillées…", (m = A_TrayMenu) ? PrevisionsIcone : OuvrirPrevisions)
        m.Add("Mes jours…", OuvrirJours)
        m.Add("Actus et marchés…", OuvrirMarches)
        m.Add("Réglages…", OuvrirReglages)
        m.Add()
        m.Add("Actualiser la météo et la position", ActualiserMaintenant)
        m.Add()
        m.Add("Quitter", (*) => ExitApp())
    }
    ; un simple clic sur l'icône de la zone de notification ouvre les prévisions
    A_TrayMenu.Default := "Prévisions détaillées…"
    A_TrayMenu.ClickCount := 1
    EtatProf := ETAT_VIDE
    CocherMenus()
    MajEtatProfondeur()
}

; Ligne d'état sous « Effet profondeur » : dit si l'effet est actif et sinon
; pourquoi, et propose l'action utile (télécharger le modèle, relancer…).
MajEtatProfondeur(couverture := -1, refus := false) {
    global EtatProf, ActionProf
    if !Profondeur
        txt := "désactivé", act := ""
    else if (AnalysePID && ProcessExist(AnalysePID))
        txt := "détourage du fond d'écran en cours…", act := ""
    else if (TelechargePID && ProcessExist(TelechargePID))
        txt := "téléchargement du modèle en cours…", act := ""
    else if !FileExist(F_MODELE)
        txt := "modèle absent : cliquer pour le télécharger (224 Mo)", act := "telecharger"
    else if (InfosFond.Get("masque", "0") != "1")
        txt := "détourage non fait : cliquer pour le lancer", act := "analyser"
    else if (couverture >= 0 && couverture < 0.02)
        txt := "prêt : glisse l'heure sur le sujet du fond d'écran", act := "astuce"
    else if (refus || couverture > COUVERTURE_MAX)
        txt := "en pause : le sujet cacherait trop l'heure", act := "astuce"
    else if (couverture >= 0)
        txt := "actif : l'heure passe derrière le sujet", act := ""
    else
        txt := "prêt", act := ""
    nouveau := "      ↳ " txt
    if (nouveau != EtatProf || act != ActionProf) {
        if IsObject(MenuClassique) {              ; (pas de menus dans les modes de test)
            try MenuClassique.Rename(EtatProf, nouveau)
            (act = "") ? MenuClassique.Disable(nouveau) : MenuClassique.Enable(nouveau)
        }
        EtatProf := nouveau
        ReglAJour()
    }
    ActionProf := act
}

ClicEtatProfondeur(*) {
    switch ActionProf {
        case "telecharger": TelechargerModele()
        case "analyser":    VerifierFond(true, true)
        case "astuce":      TrayTip("Déverrouille le widget si besoin, puis fais-le glisser pour que le sujet (une personne, "
                               . "un objet…) recouvre le bas de l'heure, sans la cacher en entier.", "Effet profondeur")
    }
}

; Le modèle de détourage manque (nouveau PC, dossier effacé…) : on propose de le récupérer
TelechargerModele() {
    global TelechargePID
    if (TelechargePID && ProcessExist(TelechargePID))
        return
    if (MsgBox("Télécharger le modèle de détourage BiRefNet (224 Mo) depuis github.com/danielgatis/rembg ?"
        . "`n`nIl sert à l'effet profondeur, tourne sur ce PC et n'est téléchargé qu'une fois.", "Widget météo", "YesNo Iconi") != "Yes")
        return
    DirCreate(DOSSIER "\modeles")
    try Run('curl.exe -L --fail -s -o "' F_MODELE '.part" "' URL_MODELE '"', , "Hide", &TelechargePID)
    catch {
        TrayTip("Impossible de lancer le téléchargement (curl.exe introuvable).", "Effet profondeur")
        return
    }
    Journal("téléchargement du modèle lancé (pid " TelechargePID ")")
    SetTimer(SuivreTelechargement, 2000)
    MajEtatProfondeur()
}

SuivreTelechargement() {
    if (TelechargePID && ProcessExist(TelechargePID))
        return
    SetTimer(SuivreTelechargement, 0)
    part := F_MODELE ".part"
    if (FileExist(part) && FileGetSize(part) = TAILLE_MODELE) {
        FileMove(part, F_MODELE, 1)
        Journal("modèle téléchargé")
        TrayTip("Modèle téléchargé. Détourage du fond d'écran en cours…", "Effet profondeur")
        VerifierFond(true, true)
    } else {
        try FileDelete(part)
        Journal("échec du téléchargement du modèle")
        TrayTip("Le téléchargement du modèle a échoué (réseau ?). Réessaie depuis Réglages ▸ Apparence.", "Effet profondeur")
    }
    MajEtatProfondeur()
}

; Centre le widget sur l'écran où il se trouve (horizontalement, et verticalement si demandé)
Centrer(horizontal, vertical, *) {
    global PosX, PosY
    PositionLogique(&x, &y, &w, &h)
    e := EcranProche(x + w // 2, y + h // 2)
    if horizontal
        x := Round((e.ml + e.mr - w) / 2)
    if vertical
        y := Round((e.mt + e.mb - h) / 2)
    PosX := x, PosY := y
    SauverReglages()
    Redessiner(true)
}

NomFond(v) => v = 0 ? "Aucun (comme Android)" : "Sombre " v " %"

CocherMenus() {
    for v in TAILLES
        (v = Taille) ? MenuTaille.Check(v " %") : MenuTaille.Uncheck(v " %")
    for v in OPACITES
        (v = Opacite) ? MenuFond.Check(NomFond(v)) : MenuFond.Uncheck(NomFond(v))
    for v in STYLES
        (v[1] = Style) ? MenuStyle.Check(v[2]) : MenuStyle.Uncheck(v[2])
    for v in PRECISIONS
        (v[1] = LettresPrecision) ? MenuLettres.Check(v[2]) : MenuLettres.Uncheck(v[2])
    LettresMoment ? MenuLettres.Check(LIB_MOMENT) : MenuLettres.Uncheck(LIB_MOMENT)
    for v in DISPOS_CADRAN
        (v[1] = CadranMeteo) ? MenuCadran.Check(v[2]) : MenuCadran.Uncheck(v[2])
    CadranChiffres ? MenuCadran.Check(LIB_CHIFFRES) : MenuCadran.Uncheck(LIB_CHIFFRES)
    for v in COULEURS
        (v[1] = Couleur) ? MenuCouleur.Check(v[2]) : MenuCouleur.Uncheck(v[2])
    m := MenuClassique
    Verrou ? m.Check(LIB_VERROU) : m.Uncheck(LIB_VERROU)
    Profondeur ? m.Check(LIB_PROFONDEUR) : m.Uncheck(LIB_PROFONDEUR)
    AmbianceActive ? m.Check(LIB_AMBIANCE) : m.Uncheck(LIB_AMBIANCE)
    Animations ? m.Check(LIB_ANIMATIONS) : m.Uncheck(LIB_ANIMATIONS)
    (NuitMode != "0" || Oled || Sobre) ? m.Check(LIB_ECRAN) : m.Uncheck(LIB_ECRAN)
    Heures ? MenuAfficher.Check(LIB_HEURES) : MenuAfficher.Uncheck(LIB_HEURES)
    Soleil ? MenuAfficher.Check(LIB_SOLEIL) : MenuAfficher.Uncheck(LIB_SOLEIL)
    DureeJour ? MenuAfficher.Check(LIB_DUREE) : MenuAfficher.Uncheck(LIB_DUREE)
    LuneReelle ? MenuLune.Check(LIB_LUNE) : MenuLune.Uncheck(LIB_LUNE)
    LuneLever ? MenuLune.Check(LIB_LUNE_LEVER) : MenuLune.Uncheck(LIB_LUNE_LEVER)
    (LuneReelle || LuneLever) ? MenuAfficher.Check("Lune") : MenuAfficher.Uncheck("Lune")
    for v in [[LIB_CLIMAT_PREV, ClimatPrev], [LIB_CLIMAT_WIDGET, ClimatWidget], [LIB_CLIMAT_RECORD, ClimatRecord]]
        v[2] ? MenuClimat.Check(v[1]) : MenuClimat.Uncheck(v[1])
    ClimatActif() ? MenuAfficher.Check(LIB_CLIMAT) : MenuAfficher.Uncheck(LIB_CLIMAT)
    IssW ? MenuCiel.Check(LIB_ISS) : MenuCiel.Uncheck(LIB_ISS)
    for v in ISS_HMINS
        (v[1] = IssHmin) ? MenuIssHmin.Check(v[2]) : MenuIssHmin.Uncheck(v[2])
    IssW ? MenuCiel.Enable(LIB_ISS_HMIN) : MenuCiel.Disable(LIB_ISS_HMIN)
    CielPlanetes ? MenuCiel.Check(LIB_PLANETES) : MenuCiel.Uncheck(LIB_PLANETES)
    CielEtoiles ? MenuCiel.Check(LIB_ETOILES) : MenuCiel.Uncheck(LIB_ETOILES)
    (IssW || CielPlanetes || CielEtoiles) ? MenuAfficher.Check(LIB_CIEL) : MenuAfficher.Uncheck(LIB_CIEL)
    for v in [[LIB_SEMAINE, CalSemaine], [LIB_FERIES, CalFeries], [LIB_VACANCES, CalVacances], [LIB_COMPTES, CalComptes], [LIB_CAL_PREV, CalPrevisions],
        [LIB_CAL_HEURE, CalHeure], [LIB_CAL_SAISONS, CalSaisons]]
        v[2] ? MenuCalendrier.Check(v[1]) : MenuCalendrier.Uncheck(v[1])
    for v in ZONES
        (v[1] = CalZone) ? MenuZone.Check(v[2]) : MenuZone.Uncheck(v[2])
    for v in JOURS_MARQUES
        (v[1] = JoursMarque) ? MenuMarque.Check(v[2]) : MenuMarque.Uncheck(v[2])
    AnnivConfettis ? MenuAnniv.Check(LIB_CONFETTIS) : MenuAnniv.Uncheck(LIB_CONFETTIS)
    AnnivExistent() ? MenuCalendrier.Check(LIB_ANNIV) : MenuCalendrier.Uncheck(LIB_ANNIV)
    CalVacances ? MenuCalendrier.Enable(LIB_ZONE) : MenuCalendrier.Disable(LIB_ZONE)
    (CalSemaine || CalendrierActif()) ? MenuAfficher.Check(LIB_CALENDRIER) : MenuAfficher.Uncheck(LIB_CALENDRIER)
    Ville2W ? MenuVille2.Check(LIB_V2_WIDGET) : MenuVille2.Uncheck(LIB_V2_WIDGET)
    Ville2Prev ? MenuVille2.Check(LIB_V2_PREV) : MenuVille2.Uncheck(LIB_V2_PREV)
    Ville2Definie() ? MenuVille2.Enable(LIB_V2_OUBLIER) : MenuVille2.Disable(LIB_V2_OUBLIER)
    (Ville2Definie() && (Ville2W || Ville2Prev)) ? MenuAfficher.Check(LIB_VILLE2) : MenuAfficher.Uncheck(LIB_VILLE2)
    MajLibV2()
    VigilanceW ? MenuVigilance.Check(LIB_VIG) : MenuVigilance.Uncheck(LIB_VIG)
    for v in [[LIB_VIG_JAUNE, 2], [LIB_VIG_ORANGE, 3]]
        (VigMin = v[2]) ? MenuVigilance.Check(v[1]) : MenuVigilance.Uncheck(v[1])
    SeineW ? MenuVigilance.Check(LibSeine) : MenuVigilance.Uncheck(LibSeine)
    UvW ? MenuVigilance.Check(LIB_UV) : MenuVigilance.Uncheck(LIB_UV)
    for v in AIR_MODES
        (v[1] = AirMode) ? MenuAir.Check(v[2]) : MenuAir.Uncheck(v[2])
    AirSable ? MenuAir.Check(LIB_AIR_SABLE) : MenuAir.Uncheck(LIB_AIR_SABLE)
    AirPollens ? MenuAir.Check(LIB_AIR_POLLENS) : MenuAir.Uncheck(LIB_AIR_POLLENS)
    AirActif() ? MenuVigilance.Check(LIB_AIR) : MenuVigilance.Uncheck(LIB_AIR)
    MajEtatAir()
    (VigilanceW || SeineW || UvW || AirActif()) ? MenuAfficher.Check(LIB_VIGILANCE) : MenuAfficher.Uncheck(LIB_VIGILANCE)
    MajEtatVigilance()
    for v in NUIT_MODES
        (v[1] = NuitMode) ? MenuNuit.Check(v[2]) : MenuNuit.Uncheck(v[2])
    for v in NUIT_DECALAGES
        (v[1] = NuitDecalage) ? MenuNuitDecalage.Check(v[2]) : MenuNuitDecalage.Uncheck(v[2])
    for v in NUIT_INTENSITES
        (v = NuitIntensite) ? MenuNuitIntensite.Check(v " %") : MenuNuitIntensite.Uncheck(v " %")
    for v in NUIT_TEINTES
        (v[1] = NuitTeinte) ? MenuNuitTeinte.Check(v[2]) : MenuNuitTeinte.Uncheck(v[2])
    NuitSurvol ? MenuNuit.Check(LIB_NUIT_SURVOL) : MenuNuit.Uncheck(LIB_NUIT_SURVOL)
    (NuitMode = "soleil") ? MenuNuit.Enable(LIB_NUIT_DECALAGE) : MenuNuit.Disable(LIB_NUIT_DECALAGE)
    (NuitMode != "0") ? MenuEcran.Check(LIB_NUIT) : MenuEcran.Uncheck(LIB_NUIT)
    for v in OLED_MODES
        (v[1] = Oled) ? MenuOled.Check(v[2]) : MenuOled.Uncheck(v[2])
    Oled ? MenuEcran.Check(LIB_OLED) : MenuEcran.Uncheck(LIB_OLED)
    Sobre ? MenuSobre.Check(LIB_SOBRE_ON) : MenuSobre.Uncheck(LIB_SOBRE_ON)
    cases := Map("pause", SobrePause, "anim", SobreAnim, "meteo", SobreMeteo, "ambiance", SobreAmbiance)
    for v in SOBRE_CASES {
        cases[v[1]] ? MenuSobre.Check(v[2]) : MenuSobre.Uncheck(v[2])
        Sobre ? MenuSobre.Enable(v[2]) : MenuSobre.Disable(v[2])   ; grisées tant que le mode est inactif
    }
    Sobre ? MenuEcran.Check(LIB_SOBRE) : MenuEcran.Uncheck(LIB_SOBRE)
    MajEtatSobre()
    MajEtatNuit()
    CocherMenuHeure()
    Traversant ? MenuPosition.Check(LIB_TRAVERSANT) : MenuPosition.Uncheck(LIB_TRAVERSANT)
    ModeEdition ? MenuTaille.Check(LIB_EDITION) : MenuTaille.Uncheck(LIB_EDITION)
    (LargeurPct != 100) ? MenuTaille.Enable(LIB_LARGEUR0) : MenuTaille.Disable(LIB_LARGEUR0)
    MajLibTaille()
    MajEtatProfondeur()
    ReglAJour()                                   ; (la fenêtre Réglages suit)
}

LibelleTaille() => "Actuelle : " Taille " %" ((LargeurPct != 100) ? " · largeur " LargeurPct " %" : "")

MajLibTaille() {
    global LibTaille
    nouveau := LibelleTaille()
    if (nouveau = LibTaille)
        return
    MenuTaille.Rename(LibTaille, nouveau)
    MenuTaille.Disable(nouveau)
    LibTaille := nouveau
}

ChoisirStyle(v, *) {
    global Style := v
    SauverReglages()
    CocherMenus()
    Redessiner(true)                              ; la largeur minimale dépend du style
}

ChoisirCouleur(v, *) {
    global Couleur := v
    SauverReglages()
    CocherMenus()
    VerifierFond(true)
    Redessiner()
}

BasculerProfondeur(*) {
    global Profondeur
    Profondeur := !Profondeur
    SauverReglages()
    CocherMenus()
    if (Profondeur && !FileExist(F_MODELE))
        TelechargerModele()
    else if (Profondeur && InfosFond.Get("masque", "0") != "1")
        TrayTip("Je détoure le sujet de ton fond d'écran (une quinzaine de secondes). "
            . "Place ensuite le widget pour que le sujet recouvre le bas de l'heure.", "Effet profondeur")
    VerifierFond(true)
    Redessiner()
}

ChoisirTaille(v, *) => AppliquerTaille(v, LargeurPct)
ChangerTaille(delta, *) => AppliquerTaille(TailleVisible() + delta, LargeurPct)
LargeurOrigine(*) => AppliquerTaille(Taille, 100)

; Nouvelle taille et largeur depuis le menu. Un axe où le widget est centré
; le reste ; sinon, le coin du widget le plus proche du coin de l'écran reste
; en place (le widget en haut à droite grandit vers la gauche et vers le bas).
AppliquerTaille(t, lp) {
    global Taille, LargeurPct, PosX, PosY
    t := Max(TAILLE_MIN, Min(TAILLE_MAX, Round(t))), lp := Max(80, Min(175, Round(lp)))
    if (CurW && PosX != "") {
        PositionLogique(&x, &y, &w, &h)
        e := EcranProche(x + w // 2, y + h // 2)
        k := EchellePour(Min(t, TailleQuiTient(lp)))
        w2 := Round(LargeurWidget(lp) * k), h2 := Round(HauteurWidget() * k)
        if (Abs(x + w / 2 - (e.ml + e.mr) / 2) <= 1)
            PosX := Round((e.ml + e.mr - w2) / 2)
        else
            PosX := (x + w / 2 > (e.l + e.r) / 2) ? x + w - w2 : x
        if (Abs(y + h / 2 - (e.mt + e.mb) / 2) <= 1)
            PosY := Round((e.mt + e.mb - h2) / 2)
        else
            PosY := (y + h / 2 > (e.t + e.b) / 2) ? y + h - h2 : y
    }
    Taille := t, LargeurPct := lp
    SauverReglages()
    CocherMenus()
    Journal("taille choisie au menu : " Taille " %, largeur " LargeurPct " %")
    Redessiner(true)
}

ChoisirFond(v, *) {
    global Opacite := v
    SauverReglages()
    CocherMenus()
    Redessiner()
}

BasculerVerrou(*) {
    global Verrou
    Verrou := !Verrou
    SauverReglages()
    CocherMenus()
}

; Transparent aux clics : ils vont au bureau dessous (le widget ne réagit plus
; qu'au menu de l'icône de la zone de notification)
BasculerTraversant(*) {
    global Traversant
    Traversant := !Traversant
    if !ModeEdition                               ; en mode redimensionnement : appliqué à sa sortie
        WinSetExStyle(Traversant ? "+0x20" : "-0x20", HWIDGET)
    SauverReglages()
    CocherMenus()
    Redessiner()
    if Traversant
        TrayTip("Le widget laisse passer les clics. Pour les prévisions et les réglages : clic droit sur l'icône de la zone de notification.", "Widget météo")
}

BasculerHeures(*) {
    global Heures
    Heures := !Heures
    SauverReglages()
    CocherMenus()
    Redessiner(true)                              ; la hauteur change : position revérifiée
}

BasculerLune(*) {
    global LuneReelle
    LuneReelle := !LuneReelle
    SauverReglages()
    CocherMenus()
    Redessiner()
}

BasculerLuneLever(*) {
    global LuneLever
    LuneLever := !LuneLever
    SauverReglages()
    CocherMenus()
    Redessiner(true)                              ; sans la rangée, la ligne du soleil peut apparaître
}

BasculerSoleil(*) {
    global Soleil
    Soleil := !Soleil
    SauverReglages()
    CocherMenus()
    Redessiner(true)
}

BasculerAnimations(*) {
    global Animations
    Animations := !Animations
    SauverReglages()
    CocherMenus()
    Redessiner()
}

BasculerAmbiance(*) {
    global AmbianceActive, AmbianceEchec
    AmbianceActive := !AmbianceActive
    AmbianceEchec := ""
    SauverReglages()
    CocherMenus()
    if AmbianceActive
        TrayTip("Ton fond d'écran suivra l'heure et la météo : crépuscule, nuit, pluie, neige, orage, brouillard. "
            . "Chaque ambiance est préparée une fois (quelques secondes), puis réutilisée.", "Fond d'écran")
    VerifierAmbiance()                            ; option coupée : la photo d'origine revient
}

Reinitialiser(*) {
    global PosX := "", PosY := ""
    SauverReglages()
    Redessiner(true)
}

; =============================================================================
;  Fond d'écran : analyse (teinte, luminosité, sujet détouré)
; =============================================================================

FondNecessaire() => Profondeur || Couleur = "auto" || Couleur = "fond" || RenduHeure = "degrade" || RenduHeure = "verre"

EmpreinteFond() {
    try return FileGetSize(F_FOND_ECRAN) "-" FileGetTime(F_FOND_ECRAN, "M")
    return ""
}

; Relance l'analyse si le fond d'écran a changé depuis la dernière (ou si le
; masque du sujet manque alors que l'effet profondeur est demandé). Une même
; empreinte n'est confiée qu'une fois à l'analyse, sauf demande explicite.
; « refaire » relance l'analyse même si le résultat semble à jour (demande explicite)
VerifierFond(forcer := false, refaire := false) {
    global DejaAnalyse
    if (!FondNecessaire() || (AmbiancePID && ProcessExist(AmbiancePID)))   ; fond en train de changer : on attend
        return
    e := EmpreinteFond()
    if (e = "")
        return
    if (!refaire && InfosFond.Get("empreinte", "") = e && InfosFond.Get("ecran", "") = A_ScreenWidth "x" A_ScreenHeight
        && (!Profondeur || InfosFond.Get("masque", "0") = "1") && (RenduHeure != "verre" || InfosFond.Get("verre", "0") = "1"))
        return
    if (!forcer && e = DejaAnalyse)
        return
    DejaAnalyse := e
    AnalyserFond()
}

AnalyserFond() {
    global AnalysePID
    if ((AnalysePID && ProcessExist(AnalysePID)) || !FileExist(SCRIPT_FOND))
        return
    cmd := 'pyw.exe -3.11 "' SCRIPT_FOND '" ' A_ScreenWidth " " A_ScreenHeight (Profondeur ? "" : " --sans-masque") ((RenduHeure = "verre") ? " --verre" : "")
    try Run(cmd, A_ScriptDir, "Hide", &AnalysePID)
    catch as err {
        Journal("analyse du fond impossible à lancer : " err.Message)
        return
    }
    Journal("analyse du fond lancée (pid " AnalysePID ") : " cmd)
    SetTimer(SuivreAnalyse, 2000)
    MajEtatProfondeur()
}

; Dès que l'analyse se termine, on applique son résultat sans attendre
SuivreAnalyse() {
    if (AnalysePID && ProcessExist(AnalysePID))
        return
    SetTimer(SuivreAnalyse, 0)
    if ChargerFond()
        Journal("analyse terminée : masque " InfosFond.Get("masque", "?") ", erreur « " InfosFond.Get("erreur", "") " », durée " InfosFond.Get("duree", "?") " s")
    else
        Journal("analyse terminée sans résultat (voir fond\fond.log)")
    Redessiner()
}

; =============================================================================
;  Fond d'écran selon la météo et l'heure (« ambiances »)
;
;  widget-meteo-fond.py --ambiance crée une variante de ta photo (nuit,
;  crépuscule, pluie…) et la pose en fond d'écran. L'ambiance affichée se lit
;  dans le registre : nom du fichier posé, s'il est une de nos variantes.
;  Changer de photo dans les Paramètres Windows suffit : les ambiances suivent.
; =============================================================================

; Moment de la journée d'après le lever et le coucher du soleil du jour
PhaseDuJour() {
    m := Minutes(FormatTime(MomentAffiche(), "HH:mm")), lev := Minutes(Donnees.Get("lever", "")), cou := Minutes(Donnees.Get("coucher", ""))
    if (lev < 0 || cou < 0)
        return (Donnees.Get("jour", "1") = "0") ? "nuit" : "jour"
    if (m < lev - 30 || m >= cou + 30)
        return "nuit"
    if (m < lev + 45 || m >= cou - 60)            ; heure dorée : autour du lever et avant le coucher
        return "crepuscule"
    return "jour"
}

EstNuit() {
    m := Minutes(FormatTime(MomentAffiche(), "HH:mm")), lev := Minutes(Donnees.Get("lever", "")), cou := Minutes(Donnees.Get("coucher", ""))
    if (lev < 0 || cou < 0)
        return Donnees.Get("jour", "1") = "0"
    return m < lev || m >= cou
}

; Code WMO -> météo de l'ambiance
MeteoAmbiance(code) {
    if !IsNumber(code)
        return "clair"
    c := Integer(code)
    if (c = 45 || c = 48)
        return "brouillard"
    if (c >= 95)
        return "orage"
    if ((c >= 71 && c <= 77) || c = 85 || c = 86)
        return "neige"
    return (c >= 51) ? "pluie" : "clair"
}

; Ambiance qui correspond au moment et au ciel (« jour-clair » = la photo d'origine)
AmbianceVoulue() {
    if !Donnees.Has("code")
        return ""
    age := (MaintenantUnix() - Integer(Donnees.Get("maj", 0))) / 60
    return PhaseDuJour() "-" ((age > RESUME_MAX) ? "clair" : MeteoAmbiance(Donnees["code"]))
}

FondRegistre() {
    try return RegRead("HKCU\Control Panel\Desktop", "WallPaper")
    return ""
}

; Ambiance affichée : « jour-clair » pour une photo quelconque, "" si inconnue
; (registre illisible, ou variante faite pour une autre définition d'écran)
AmbianceActuelle() {
    chemin := FondRegistre()
    if (chemin = "")
        return ""
    SplitPath(chemin, &nom, &dir)
    if (InStr(dir "\", DOSSIER "\ambiances\") != 1)
        return "jour-clair"
    if (RegExMatch(nom, "i)^([a-z]+-[a-z]+)-(\d+x\d+)\.jpg$", &o) && o[2] = A_ScreenWidth "x" A_ScreenHeight)
        return StrLower(o[1])
    return ""
}

VerifierAmbiance() {
    if ((AmbiancePID && ProcessExist(AmbiancePID)) || (AnalysePID && ProcessExist(AnalysePID)))
        return
    if (Sobre && (EcranEteint || Verrouillee))    ; mode sobre : pas de changement de fond écran éteint
        return
    actuelle := AmbianceActuelle()
    if AmbianceActive
        voulue := AmbianceVoulue()
    else                                          ; option coupée : une variante restée affichée repart
        voulue := (actuelle = "" || actuelle = "jour-clair") ? "" : "jour-clair"
    if (voulue = "" || voulue = actuelle || voulue "|" FondRegistre() = AmbianceEchec)
        return
    if (voulue "|" FondRegistre() = AmbianceDifferee && SobreDiffere())   ; à créer au retour sur secteur
        return
    LancerAmbiance(voulue)
}

LancerAmbiance(nom) {
    global AmbiancePID, AmbianceDemandee, AmbianceCle, AmbianceSansCreation
    if !FileExist(SCRIPT_FOND)
        return
    AmbianceSansCreation := SobreDiffere()        ; sur batterie : pas de nouvelle génération (~40 s de calcul)
    cmd := 'pyw.exe -3.11 "' SCRIPT_FOND '" ' A_ScreenWidth " " A_ScreenHeight " --ambiance " nom
        . (AmbianceSansCreation ? " --seulement-existante" : "")
    try FileDelete(D_FOND "\ambiance.txt")       ; (un « à créer » périmé ne doit pas être relu)
    AmbianceDemandee := nom, AmbianceCle := nom "|" FondRegistre()
    try Run(cmd, A_ScriptDir, "Hide", &AmbiancePID)
    catch as err {
        Journal("ambiance impossible à lancer : " err.Message)
        return
    }
    Journal("ambiance « " nom " » demandée (pid " AmbiancePID ")")
    SetTimer(SuivreAmbiance, 1000)
}

; Ambiance posée : le fond d'écran a changé, on le réanalyse tout de suite
; (le sujet détouré de la photo d'origine est repris, c'est rapide)
SuivreAmbiance() {
    global AmbianceEchec, AmbianceDifferee
    if (AmbiancePID && ProcessExist(AmbiancePID))
        return
    SetTimer(SuivreAmbiance, 0)
    if (AmbianceActuelle() = AmbianceDemandee) {
        Journal("ambiance « " AmbianceDemandee " » posée")
        VerifierFond()
    } else if (AmbianceSansCreation && AmbianceACreer(AmbianceDemandee)) {   ; mode sobre sur batterie : reportée, pas en échec
        AmbianceDifferee := AmbianceCle
        Journal("ambiance « " AmbianceDemandee " » reportée au retour sur secteur")
    } else {
        AmbianceEchec := AmbianceCle
        Journal("ambiance « " AmbianceDemandee " » en échec (voir fond\fond.log)")
    }
}

; Relit fond.txt et la carte de luminosité s'ils ont changé. Renvoie true si c'est le cas.
ChargerFond() {
    global InfosFond, FondDate, LumBmp
    f := D_FOND "\fond.txt"
    if !FileExist(f)
        return false
    m := FileGetTime(f, "M")
    if (m = FondDate)
        return false
    d := Map()
    try {
        for ligne in StrSplit(FileRead(f, "UTF-8"), "`n", "`r")
            if (p := InStr(ligne, "="))
                d[SubStr(ligne, 1, p - 1)] := SubStr(ligne, p + 1)
    } catch
        return false
    InfosFond := d, FondDate := m
    if LumBmp
        DllCall("gdiplus\GdipDisposeImage", "Ptr", LumBmp), LumBmp := 0
    LumBmp := ChargerImage(D_FOND "\luminance.png")
    LibererMasque()
    LibererMasqueGrand()
    LibererVerre()
    return true
}

; Charge (une zone d')une image en la redessinant dans une image neuve : un
; simple clone GDI+ garde le fichier ouvert, et l'analyse suivante ne pourrait
; plus le remplacer (constaté : « Accès refusé »).
ChargerImage(fichier, x := 0, y := 0, w := 0, h := 0) {
    if (!FileExist(fichier) || DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", fichier, "Ptr*", &src := 0))
        return 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", src, "UInt*", &iw := 0)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", src, "UInt*", &ih := 0)
    if !w
        w := iw, h := ih
    copie := 0
    if (x >= 0 && y >= 0 && x + w <= iw && y + h <= ih) {
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &copie)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", copie, "Ptr*", &g := 0)
        DllCall("gdiplus\GdipSetCompositingMode", "Ptr", g, "Int", 1)          ; copie brute, sans mélange
        DllCall("gdiplus\GdipDrawImageRectRectI", "Ptr", g, "Ptr", src, "Int", 0, "Int", 0, "Int", w, "Int", h,
            "Int", x, "Int", y, "Int", w, "Int", h, "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    }
    DllCall("gdiplus\GdipDisposeImage", "Ptr", src)
    return copie
}

LibererMasque() {
    global MasqueBmp, MasqueCle
    ViderBrosses()
    if MasqueBmp
        DllCall("gdiplus\GdipDisposeImage", "Ptr", MasqueBmp)
    MasqueBmp := 0, MasqueCle := ""
}

ViderBrosses() {
    global Brosses, BrossesCle
    for , br in Brosses
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    Brosses := Map(), BrossesCle := ""
}

; Le masque du sujet sous le widget (rouge = sujet, vert = sujet élargi),
; découpé dans le masque plein écran. 0 si l'effet est inactif ou indisponible.
MasqueSous(x, y, w, h) {
    global MasqueBmp, MasqueCle
    if (!Profondeur || SansProfondeur || InfosFond.Get("masque", "0") != "1")
        return 0
    cle := x "," y "," w "," h "," FondDate
    if (cle != MasqueCle) {
        LibererMasque()
        MasqueCle := cle
        MasqueBmp := Oled ? DecoupeMasque(x, y, w, h) : ChargerImage(D_FOND "\masque.png", x, y, w, h)
    }
    return MasqueBmp
}

; Anti-marquage : la découpe est prise dans une découpe élargie gardée en cache
; (masque.png relu une fois par fond et par position, pas à chaque pas d'orbite)
DecoupeMasque(x, y, w, h) {
    global MasqueGrand, MasqueGrandZone
    g := MasqueGrandZone
    if !(MasqueGrand && IsObject(g) && g.date = FondDate && x >= g.x && y >= g.y && x + w <= g.x + g.w && y + h <= g.y + g.h) {
        LibererMasqueGrand()
        m := MARGE_MASQUE                         ; élargie, bornée à l'écran (masque.png est à sa taille)
        gx := Max(0, x - m), gy := Max(0, y - m), gw := Min(A_ScreenWidth, x + w + m) - gx, gh := Min(A_ScreenHeight, y + h + m) - gy
        if (gw >= w && gh >= h && (MasqueGrand := ChargerImage(D_FOND "\masque.png", gx, gy, gw, gh)))
            MasqueGrandZone := {x: gx, y: gy, w: gw, h: gh, date: FondDate}
        else                                      ; hors de l'écran principal : découpe exacte (ou rien)
            return ChargerImage(D_FOND "\masque.png", x, y, w, h)
    }
    g := MasqueGrandZone
    if DllCall("gdiplus\GdipCloneBitmapAreaI", "Int", x - g.x, "Int", y - g.y, "Int", w, "Int", h, "Int", 0x26200A,
        "Ptr", MasqueGrand, "Ptr*", &c := 0)
        return 0
    return c
}

LibererMasqueGrand() {
    global MasqueGrand, MasqueGrandZone
    if MasqueGrand
        DllCall("gdiplus\GdipDisposeImage", "Ptr", MasqueGrand)
    MasqueGrand := 0, MasqueGrandZone := ""
}

; Part de la zone b (bornes de l'heure) que le sujet recouvre, de 0 à 1
Couverture(masque, b) {
    n := 0, somme := 0, pas := Max(4, Round(b.w / 80))
    yy := b.y
    while (yy < b.y + b.h) {
        xx := b.x
        while (xx < b.x + b.w) {
            DllCall("gdiplus\GdipBitmapGetPixel", "Ptr", masque, "Int", Round(xx), "Int", Round(yy), "UInt*", &px := 0)
            somme += (px >> 16) & 0xFF, n++
            xx += pas
        }
        yy += pas
    }
    return n ? somme / (255 * n) : 0
}

; Luminosité moyenne (0 à 1) du fond d'écran sous le widget, -1 si inconnue
LuminanceSous(x, y, w, h) {
    static cle := "", valeur := -1
    if !LumBmp
        return -1
    if (x "," y "," w "," h "," FondDate = cle)
        return valeur
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", LumBmp, "UInt*", &lw := 0)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", LumBmp, "UInt*", &lh := 0)
    ex := lw / A_ScreenWidth, ey := lh / A_ScreenHeight
    x0 := Max(0, Floor(x * ex)), x1 := Min(lw - 1, Floor((x + w) * ex))
    y0 := Max(0, Floor(y * ey)), y1 := Min(lh - 1, Floor((y + h) * ey))
    n := 0, somme := 0
    Loop y1 - y0 + 1 {
        py := y0 + A_Index - 1
        Loop x1 - x0 + 1 {
            DllCall("gdiplus\GdipBitmapGetPixel", "Ptr", LumBmp, "Int", x0 + A_Index - 1, "Int", py, "UInt*", &px := 0)
            somme += (px >> 16) & 0xFF, n++
        }
    }
    cle := x "," y "," w "," h "," FondDate
    valeur := n ? somme / (255 * n) : -1
    return valeur
}

; Polices et couleurs du thème choisi, pour un widget posé en (x, y)
Theme(x, y, w, h) {
    t := {gros: P_GROS[Style]}
    t.heure := (PoliceHeure != "") ? PoliceHeure : t.gros
    t.temp := (PoliceHeure != "" && PoliceTemp) ? PoliceHeure : t.gros
    c := Couleur
    if (NuitTeinteActive() != "")                ; rouge ou ambre : texte clair, ombre noire (sinon rouge-noir sur halo rouge)
        c := "blanc"
    else if (c = "auto")
        c := (LuminanceSous(x, y, w, h) >= CLAIR_MIN) ? "sombre" : "blanc"
    else if (c = "soleil")                          ; bascule au lever et au coucher du soleil
        c := EstNuit() ? "blanc" : "sombre"
    t.sombre := (c = "sombre")
    if (c = "sombre") {
        t.texte := 0xFF16191D, t.second := 0xC016191D, t.accent := 0xFF16191D
        t.ombre := 0xFFFFFF                         ; halo clair autour du texte foncé
    } else {
        t.texte := 0xFFFFFFFF, t.second := 0xB3FFFFFF, t.ombre := 0x000000
        teinte := InfosFond.Get("teinte", "")
        t.accent := (c = "fond" && RegExMatch(teinte, "^[0-9A-Fa-f]{6}$")) ? 0xFF000000 | Integer("0x" teinte) : 0xFFFFFFFF
    }
    return t
}

; Brosse qui peint « argb » partout sauf sur le sujet du fond d'écran : la
; matrice de couleurs transforme le masque (canal 0 : sujet, 1 : sujet élargi)
; en une texture de cette couleur, transparente là où est le sujet. Seule la
; zone de l'heure est convertie (c'est la seule peinte avec ces brosses).
BrossePlaquee(masque, canal, argb) {
    cle := canal "|" argb
    if Brosses.Has(cle)
        return Brosses[cle]
    a := ((argb >> 24) & 0xFF) / 255
    cm := Buffer(100, 0)                          ; ColorMatrix 5 x 5 (sortie = entrée × M)
    NumPut("Float", -a, cm, (canal * 5 + 3) * 4)  ; alpha = a − a × masque
    NumPut("Float", ((argb >> 16) & 0xFF) / 255, "Float", ((argb >> 8) & 0xFF) / 255, "Float", (argb & 0xFF) / 255,
        "Float", a, "Float", 1, cm, 80)           ; translation : couleur fixe
    DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia := 0)
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", ia, "Int", 0, "Int", 1, "Ptr", cm, "Ptr", 0, "Int", 0)
    z := ZoneHeure
    DllCall("gdiplus\GdipCreateTextureIA", "Ptr", masque, "Ptr", ia, "Float", z.x, "Float", z.y, "Float", z.w, "Float", z.h, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipTranslateTextureTransform", "Ptr", br, "Float", z.x, "Float", z.y, "Int", 0)   ; texture recalée sur sa place
    DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia)
    Brosses[cle] := br
    return br
}

; =============================================================================
;  Position et affichage
; =============================================================================

; Moment affiché (heure, date, jour ou nuit) : maintenant, ou celui imposé par un mode de test
MomentAffiche() => (HeureTest != "") ? HeureTest : A_Now

; Échelle des pixels : écran × taille. Pendant un redimensionnement, celle du geste.
EchellePour(t) => A_ScreenDPI / 96 * t / 100
Echelle() => EnGeste() ? EchellePour(Geste.t) : EchellePour(TailleVisible())

; Taille affichée : celle choisie, réduite si le widget ne tient plus dans son
; écran (option cochée à grande taille, écran plus petit…) ; le réglage, lui,
; est gardé pour quand la place revient.
TailleVisible() => Max(TAILLE_MIN, Min(Taille, TailleQuiTient()))

; Plus grande taille (en %) qui tient dans la zone de travail de l'écran du widget
TailleQuiTient(lp := "") {
    if (HWIDGET && CurW) {
        WinGetPos(&x, &y, &w, &h, HWIDGET)
        e := EcranProche(x + w // 2, y + h // 2)
    } else if (PosX != "" && PosY != "")
        e := EcranProche(Integer(PosX) + 1, Integer(PosY) + 1)
    else {
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        e := {l: l, t: t, r: r, b: b}
    }
    d := A_ScreenDPI / 96
    return Floor(100 * Min((e.r - e.l) / (LargeurWidget(lp) * d), (e.b - e.t) / (HauteurWidget() * d)))
}

; Largeur du contenu (en HC) pour une largeur lp (en %, celle du réglage ou du
; geste en cours par défaut) : 2,0 à 100 %, bornée par ce que le style supporte
LargeurContenu(lp := "") {
    if (lp = "")
        lp := EnGeste() ? Geste.lp : LargeurPct
    return Max(LargeurMin(), Min(LARG_MAX, 2.0 * lp / 100))
}

; Dimensions à 100 % (multipliées ensuite par l'échelle)
LargeurWidget(lp := "") => LargeurContenu(lp) * HC + 2 * PAD

; La rangée « prochaines heures », ou à défaut la ligne du lever et du
; coucher du soleil, agrandit le widget vers le bas
HauteurWidget() => HAUTEUR + (ExtraStyle() + LigneBasse() + HauteurBande() * LIGNE_BANDE) * HC

; Hauteur de la rangée des heures, ou à défaut de la ligne du lever et du coucher (en HC)
LigneBasse() => Heures ? LIGNE_HEURES : (Soleil || LuneLever) ? LIGNE_SOLEIL : 0

; Nombre de créneaux de la rangée des heures : une cellule fait au moins
; 0,33 HC (« Coucher » y tient), de 5 à 12 selon la largeur du contenu
NbCreneaux(W) => Max(5, Min(12, Floor(W / 0.33)))

; Position à appliquer : celle mémorisée (ramenée sur l'écran le plus proche si
; son écran a été débranché), sinon le coin haut droit de l'écran principal.
; Toujours dans la zone de travail (hors barre des tâches).
CalculerPosition(w, h, &x, &y) {
    if (PosX != "" && PosY != "") {
        x := Integer(PosX), y := Integer(PosY)
        ZoneTravailProche(x + w // 2, y + h // 2, &l, &t, &r, &b)
    } else {
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        m := Round(MARGE * A_ScreenDPI / 96)
        x := r - w - m, y := t + m
    }
    x := Max(l, Min(x, r - w))
    y := Max(t, Min(y, b - h))
}

; Zone de travail de l'écran le plus proche du point (cx, cy)
ZoneTravailProche(cx, cy, &l, &t, &r, &b) {
    e := EcranProche(cx, cy)
    l := e.l, t := e.t, r := e.r, b := e.b
}

; Écran le plus proche du point (cx, cy) : zone de travail (l, t, r, b, hors
; barre des tâches) et écran entier (ml, mt, mr, mb, pour centrer)
EcranProche(cx, cy) {
    hmon := DllCall("MonitorFromPoint", "Int64", (cy << 32) | (cx & 0xFFFFFFFF), "UInt", 2, "Ptr")   ; MONITOR_DEFAULTTONEAREST
    mi := Buffer(40, 0), NumPut("UInt", 40, mi)
    DllCall("GetMonitorInfo", "Ptr", hmon, "Ptr", mi)
    return {ml: NumGet(mi, 4, "Int"), mt: NumGet(mi, 8, "Int"), mr: NumGet(mi, 12, "Int"), mb: NumGet(mi, 16, "Int"),
            l: NumGet(mi, 20, "Int"), t: NumGet(mi, 24, "Int"), r: NumGet(mi, 28, "Int"), b: NumGet(mi, 32, "Int")}
}

Redessiner(repositionner := false) {
    global CurW, CurH, RenduGen, OrbiteDx, OrbiteDy, RedessinEnAttente, AttenteRepos, ThemeLx, ThemeLy, ZonesClic
    if (!HWIDGET || EnGeste())                    ; pendant un redimensionnement : refait au lâcher
        return
    if (CurW && SobreSuspendu()) {                ; mode sobre : écran éteint ou widget caché, fait à la réapparition
        RedessinEnAttente := true, AttenteRepos := AttenteRepos || repositionner
        return
    }
    gen := ++RenduGen                             ; tout rendu lancé ensuite rend celui-ci périmé
    PreparerBande()                               ; la bande d'infos fixe la hauteur
    k := Echelle()
    w := Round(LargeurWidget() * k), h := Round(HauteurWidget() * k)
    if (h != CurH)                                ; le widget grandit ou rapetisse : recalé dans l'écran
        repositionner := true                     ; (comparé à ce qui a été posé : un rendu interrompu ne perd rien)

    ; Sans nouvelle position, UpdateLayeredWindow laisse la fenêtre où elle
    ; est : un rafraîchissement ne la ramène jamais en arrière pendant un glisser.
    deplacer := (repositionner || !CurW)
    if deplacer
        CalculerPosition(w, h, &lx, &ly)
    else
        PositionLogique(&lx, &ly)
    ; anti-marquage OLED : la fenêtre réelle = position logique + décalage de la
    ; minute, borné à la zone de travail (contre un bord, l'orbite s'aplatit)
    if Glisse                                     ; bouton appuyé (glisser) : décalage figé, fenêtre laissée où elle est
        dx := OrbiteDx, dy := OrbiteDy
    else if ModeEdition                           ; mode édition : poignées à la position logique
        dx := 0, dy := 0
    else {
        o := OrbiteVoulue(), dx := o[1], dy := o[2]
        if (dx || dy) {                           ; on borne le DÉCALAGE (jamais plus de R px) : contre un bord, il s'aplatit
            ZoneTravailProche(lx + w // 2, ly + h // 2, &l, &t, &r, &b)
            dx := (dx > 0) ? Max(0, Min(dx, r - w - lx)) : Min(0, Max(dx, l - lx))
            dy := (dy > 0) ? Max(0, Min(dy, b - h - ly)) : Min(0, Max(dy, t - ly))
        }
    }
    x := lx + dx, y := ly + dy
    ThemeLx := lx, ThemeLy := ly                  ; thème (couleur automatique) sur la position logique
    if (!deplacer && (x != lx + OrbiteDx || y != ly + OrbiteDy))
        deplacer := true
    if !Peindre(x, y, deplacer, w, h, k, false, gen)
        return                                    ; rendu dépassé pendant qu'il se faisait
    OrbiteDx := x - lx, OrbiteDy := y - ly
    CurW := w, CurH := h
    ZonesClic := ZonesRendu.Clone()               ; zones cliquables de ce rendu (posé) ; copie : un rendu
                                                  ; interrompu qui reprend n'y ajoute plus rien
    AnimMaj(x, y)                                 ; illustration animée (ou fenêtre retirée si l'option est coupée)
    ZonesFenMaj(x, y)                             ; « Laisser passer les clics » : les zones restent cliquables
}

; Dessine le widget (w × h, échelle k, posé en x, y) et l'applique à la
; fenêtre, en la déplaçant si « deplacer ». Un rendu complet peut être
; interrompu (message de la souris, minuteur) : il n'est pas posé (renvoie
; false) si un geste est en cours ou si un autre rendu ou un geste l'a
; dépassé entre-temps (gen ≠ RenduGen). Le brouillon, lui, n'est jamais
; interrompu (voir RenduGeste).
Peindre(x, y, deplacer, w, h, k, brouillon := false, gen := 0) {
    hdcE := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdc  := DllCall("CreateCompatibleDC", "Ptr", hdcE, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, "Int", w, "Int", -h, "UShort", 1, "UShort", 32, bi)
    hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits := 0, "Ptr", 0, "UInt", 0, "Ptr")
    obm := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
    try {
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &gr := 0)
        try {
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", gr, "UInt", 0)
            Dessiner(gr, w, h, k, x, y, brouillon)
        } finally {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
        }
        if (!brouillon && (EnGeste() || gen != RenduGen))
            return false
        pt := 0
        if deplacer
            pt := Buffer(8), NumPut("Int", x, "Int", y, pt)
        sz := Buffer(8), NumPut("Int", w, "Int", h, sz)
        src := Buffer(8, 0)
        bf := Buffer(4), NumPut("UChar", 0, "UChar", 0, "UChar", AlphaAffiche(), "UChar", 1, bf)   ; alpha par pixel × intensité (mode nuit)
        DllCall("UpdateLayeredWindow", "Ptr", HWIDGET, "Ptr", hdcE, "Ptr", pt, "Ptr", sz,
            "Ptr", hdc, "Ptr", src, "UInt", 0, "Ptr", bf, "UInt", 2)
        return true
    } finally {
        DllCall("SelectObject", "Ptr", hdc, "Ptr", obm)
        DllCall("DeleteObject", "Ptr", hbm)
        DllCall("DeleteDC", "Ptr", hdc)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcE)
    }
}

; =============================================================================
;  Rendu
; =============================================================================

; (x, y) : position du widget à l'écran (thème automatique, effet profondeur).
; « brouillon » : aperçu pendant un redimensionnement, sans ombre ni effet
; profondeur (15 à 30 ms au lieu de 0,2 à 0,7 s), avec le cadre du geste.
Dessiner(gr, w, h, k, x, y, brouillon := false) {
    global TeinteRendu
    ancienne := TeinteRendu                       ; (un autre rendu a pu être interrompu : on lui rend sa teinte)
    TeinteRendu := NuitTeinteActive()             ; mode nuit rouge ou ambre (jamais hors d'un rendu : l'animation passe aussi par Remplir)
    try DessinerScene(gr, w, h, k, x, y, brouillon)
    finally TeinteRendu := ancienne
}

DessinerScene(gr, w, h, k, x, y, brouillon) {
    global ThemeCourant, ZoneHeure, BrossesCle, IconeZone, BlocHeure, ZonesRendu
    ZonesRendu := []                              ; remplies par la composition (NoterZone)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gr, "Int", 2)
    MajLune()                                     ; phase du moment (après LireDonnees : latitude)

    ; invisible (alpha 1/255), mais toute la surface se saisit, coins arrondis
    ; du fond compris ; en blanc, l'écart reste sous l'arrondi sur un fond clair ou moyen
    if (!Traversant || ModeEdition)
        Aplat(gr, 0, 0, w, h, (AlphaSaisie() << 24) | 0xFFFFFF)
    if (Opacite > 0)
        RectArrondi(gr, 0, 0, w, h, 24 * k, (Round(Opacite * 2.55) << 24) | 0x0E1116)

    ; pendant le geste, le thème du départ (pas de mesure de luminosité à chaque image)
    ThemeCourant := (brouillon && IsObject(Geste) && IsObject(Geste.theme)) ? Geste.theme
        : Theme((ThemeLx != "") ? ThemeLx : x, (ThemeLy != "") ? ThemeLy : y, w, h)   ; (sans l'orbite : pas de bascule d'une minute à l'autre)
    IconeZone := "", BlocHeure := ""
    elems := (Style = "iphone") ? ComposerIphone(w, h, k, ThemeCourant) : (Style = "lettres") ? ComposerLettres(w, h, k, ThemeCourant)
        : (Style = "analogique") ? ComposerAnalogique(w, h, k, ThemeCourant) : ComposerAndroid(w, h, k, ThemeCourant)
    DessinerBande(elems, ThemeCourant, k)         ; 2e ville… sous tout le reste
    PreparerRendu(elems, k, brouillon)            ; contour, dégradé ou verre (rien en « plein »)
    if brouillon {
        ViderBrosses()                            ; la mise en page change à chaque image du geste
        for e in elems
            Remplir(gr, e, 0, true)
        for e in elems
            DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
        ViderBrosses(), LibererClipContour()
        DessinerCadre(gr, w, h, k, IsObject(Geste) && Geste.aimante)
        return
    }

    ; Effet profondeur : l'heure (éléments « z ») s'efface là où est le sujet,
    ; sauf si le sujet en cacherait trop (l'iPhone renonce aussi dans ce cas).
    masque := MasqueSous(x, y, w, h)
    couv := -1, refus := false
    if masque {
        bz := ""
        for e in elems
            if (e.HasOwnProp("z") && e.z)
                bz := Union(bz, Bornes(e.p))
        couv := IsObject(bz) ? Couverture(masque, bz) : 0
        ; en toutes lettres, une seule ligne trop cachée suffit à rendre la phrase illisible
        if (Style = "lettres" && IsObject(bz) && couv <= COUVERTURE_MAX && couv >= 0.02)
            for e in elems
                if (e.HasOwnProp("z") && e.z && Couverture(masque, Bornes(e.p)) > COUVERTURE_MAX_LIGNE)
                    refus := true
        if (!IsObject(bz) || couv > COUVERTURE_MAX || couv < 0.02 || refus)
            masque := 0
        else if (ZoneRendu = "") {
            ; zone de l'heure, élargie pour l'ombre et ramenée dans le widget
            m := 8 * k
            x0 := Max(0, Floor(bz.x - m)), y0 := Max(0, Floor(bz.y - m))
            ZoneHeure := {x: x0, y: y0, w: Min(w, Ceil(bz.x + bz.w + m)) - x0, h: Min(h, Ceil(bz.y + bz.h + m)) - y0}
        }
    }
    if (ZoneRendu != "") {                        ; rendu : zone fixe, les brosses servent d'une minute à l'autre
        z := ZoneRendu, x0 := Max(0, z.x), y0 := Max(0, z.y)
        ZoneHeure := {x: x0, y: y0, w: Min(w, z.x + z.w) - x0, h: Min(h, z.y + z.h) - y0}
    }
    verre := VerreSous(x, y, w, h)
    if (RenduHeure = "verre" && !verre)          ; sans fond flouté : verre simplifié, ombre légère
        for e in elems
            if e.HasOwnProp("verre")
                e.a := 0.15
    if (masque || ZoneRendu != "") {
        cle := MasqueCle "|" (masque ? 1 : 0) "|" VerreCle "|" RenduHeure "|" ZoneHeure.x "," ZoneHeure.y "," ZoneHeure.w "," ZoneHeure.h
        if (cle != BrossesCle)
            ViderBrosses(), BrossesCle := cle
    }
    if (HWIDGET && !SansProfondeur)
        MajEtatProfondeur(couv, refus)
    OmbreDouce(gr, elems, w, h, k, masque)
    for e in elems
        Remplir(gr, e, masque)
    for e in elems
        DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
    LibererClipContour()
    if ModeEdition                                ; « Redimensionner à la souris » : poignées visibles
        DessinerCadre(gr, w, h, k)
}

; Cadre du redimensionnement : contour arrondi, équerres aux quatre coins
; (taille) et poignées au milieu des côtés (largeur). Blanc bordé de sombre,
; lisible sur tous les fonds ; ambre quand la taille s'aimante sur un préréglage.
DessinerCadre(gr, w, h, k, aimante := false) {
    d := A_ScreenDPI / 96, b := BandeRedim(k), m := 1.5 * d
    p := CheminArrondi(m, m, w - 2 * m, h - 2 * m, Min(24 * k, h / 4))
    for trait in [[0x59000000, 3 * d], [aimante ? 0xE6FFC233 : 0x99FFFFFF, 1.2 * d]] {
        DllCall("gdiplus\GdipCreatePen1", "UInt", trait[1], "Float", trait[2], "Int", 0, "Ptr*", &pen := 0)
        DllCall("gdiplus\GdipDrawPath", "Ptr", gr, "Ptr", pen, "Ptr", p)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }
    DllCall("gdiplus\GdipDeletePath", "Ptr", p)
    ep := Max(2 * d, 0.22 * b), lb := 2.5 * b
    rects := []
    for c in [[m, m, 1, 1], [w - m, m, -1, 1], [m, h - m, 1, -1], [w - m, h - m, -1, -1]]
        rects.Push(RectOriente(c[1], c[2], c[3] * lb, c[4] * ep), RectOriente(c[1], c[2], c[3] * ep, c[4] * lb))
    rects.Push([m, h / 2 - b, ep, 2 * b], [w - m - ep, h / 2 - b, ep, 2 * b])
    for r in rects
        Aplat(gr, r[1] - d, r[2] - d, r[3] + 2 * d, r[4] + 2 * d, 0x73000000)
    for r in rects
        Aplat(gr, r[1], r[2], r[3], r[4], aimante ? 0xFFFFC233 : 0xF2FFFFFF)
}

; Rectangle [x, y, w, h] partant de (x, y) vers l'intérieur (dw, dh négatifs : vers la gauche, vers le haut)
RectOriente(x, y, dw, dh) => [Min(x, x + dw), Min(y, y + dh), Abs(dw), Abs(dh)]

Union(a, b) {
    if !IsObject(a)
        return b
    x := Min(a.x, b.x), y := Min(a.y, b.y)
    return {x: x, y: y, w: Max(a.x + a.w, b.x + b.w) - x, h: Max(a.y + a.h, b.y + b.h) - y}
}

; Ce que le widget affiche, préparé une fois pour tous les styles
InfosAffichage() {
    i := {temp: "", lieu: "", suffixe: "", texte: "", maxi: "", normale: ""}
    if Donnees.Has("temp") {
        i.temp := Round(Number(Donnees["temp"]))
        i.lieu := Donnees.Get("ville", "")
        if (i.lieu = "")
            i.lieu := "Lieu inconnu"                   ; géocodage en échec
        if (Donnees.Get("source", "") = "ip")
            i.lieu := "≈ " i.lieu                      ; position approximative (adresse IP)
        age := (MaintenantUnix() - Integer(Donnees.Get("maj", 0))) / 60
        if (age > PERIME_MIN)
            i.suffixe := " · il y a " Max(1, Round(age / 60)) " h"
        ; la pastille « pluie dans l'heure » affichée dit déjà l'heure de la pluie, au quart d'heure :
        ; le résumé parle alors du reste de la journée (sinon deux heures différentes pour la même pluie)
        v := (IsObject(PastillePluie()) && Donnees.Has("resume_jour")) ? "_jour" : ""
        i.texte := Donnees.Get("resume" v, ""), i.maxi := StrReplace(Donnees.Get("maximum" v, ""), Chr(0x202F) "°", "°")
        if (i.maxi != "" && ClimatWidget)          ; « Maximum 27° (normale 20°) » : à part, jamais au prix du maximum
            i.normale := SuffixeNormale()
        if (age > RESUME_MAX)
            i.texte := "Météo non actualisée", i.maxi := "", i.normale := ""
        else if (i.texte = "" && i.maxi = "")          ; résumé indisponible
            i.texte := InfosMeteo(Donnees["code"]) ".", i.maxi := "Maximum" Chr(0xA0) Round(Number(Donnees.Get("max", 0))) "°"
    } else
        i.lieu := "Recherche de ta position…"
    return i
}

; Nom du lieu raccourci pour tenir dans « largeur », l'ancienneté restant entière
LieuAjuste(i, em, largeur) {
    if (i.suffixe != "")
        largeur -= LargeurTexte("x" i.suffixe, P_TEXTE, em) - LargeurTexte("x", P_TEXTE, em)
    return Tronquer(i.lieu, P_TEXTE, em, largeur) i.suffixe
}

; Ajoute une illustration dont les formes gardent une ombre sombre, quel que soit le thème
IllustrerTheme(L, id, X, Y, S) {
    n := L.Length
    Illustrer(L, id, X, Y, S)
    Loop L.Length - n
        L[n + A_Index].o := 0x000000, L[n + A_Index].z := false
}

; L'illustration principale du widget : dessinée avec le reste, ou confiée à
; la fenêtre d'animation posée par-dessus (widget-meteo-animation.ahk)
IconeWidget(L, id, X, Y, S) {
    global IconeZone := {id: id, x: X, y: Y, s: S}
    if (!(AnimPermise() && HWIDGET) || EnGeste())   ; aperçus, redimensionnement, nuit : dessinée dans le widget
        IllustrerTheme(L, id, X, Y, S)
}

; Style Android : température, lieu et résumé à gauche ; illustration, date et
; heure à droite. Construit la liste des formes à peindre.
ComposerAndroid(w, h, k, t) {
    L := []
    u  := HC * k                                   ; une unité = la hauteur du bloc de contenu
    ox := PAD * k, oy := PAD * k + 0.012 * u       ; origine du bloc
    X(v) => ox + v * u
    Y(v) => oy + v * u
    WC  := LargeurContenu()                         ; largeur du contenu (2,0 à 100 %)
    droite := X(WC)

    i := InfosAffichage()

    ; ---- Colonne droite : illustration, date, heure (alignées à droite)
    if Donnees.Has("code") {
        IconeWidget(L, Illustration(Donnees["code"], Donnees.Get("jour", "1")), droite - 0.4235 * u, Y(-0.0118), 0.4235 * u)
        NoterZone("meteo", {x: droite - 0.4235 * u, y: Y(-0.0118), w: 0.4235 * u, h: 0.4235 * u})
    }
    mo := MomentAffiche()                          ; date, avec le numéro de semaine en option (abrégée si étroit)
    dt := FormatTime(mo, (WC < 1.9 && CalSemaine) ? "ddd d MMM" : "ddd d MMMM"), emD := EmPourCapitale(P_DATE, 0.0654 * u), n0 := L.Length
    ligneD := dt (CalSemaine ? " · S" Integer(SubStr(FormatTime(mo, "YWeek"), 5)) : "")
    bd := Poser(L, ligneD, P_DATE, emD, droite, Y(0.684), 2, t.accent)
    MarqueDate(L, n0, bd, ligneD, dt, P_DATE, emD, 0.0654 * u, Y(0.684))   ; Mes jours : la couleur du type du jour
    bh := PoserHeure(L, FormatTime(MomentAffiche(), "HH:mm"), t.heure, 0.221 * u, droite, Y(0.997), "droite", t.accent)

    ; ---- Colonne gauche : température, lieu, résumé
    em := EmPourCapitale(P_TEXTE, 0.0635 * u)
    if (i.temp != "") {
        cap := 0.184 * u
        emT := (t.temp != t.gros) ? EmHeure(t.temp, cap) : EmPourCapitale(t.gros, cap)   ; même hauteur de chiffres
        bt := Poser(L, i.temp, t.temp, emT, X(0), Y(0.265), 0, t.accent)
        ; le « ° » est rapproché des chiffres, comme dans Google Sans
        PoserEncre(L, "°", t.temp, emT, bt.x + bt.w + 0.11 * cap, Y(0.265), t.accent)
        NoterZone("meteo", {x: bt.x, y: bt.y, w: bt.w + 0.6 * cap, h: bt.h})   ; (« ° » compris)
    }

    ; lieu : toute la place jusqu'à l'illustration ; seul le nom se raccourcit,
    ; l'indication d'ancienneté reste toujours entière
    Epingle(L, X(0.0515), Y(0.3936), u, t.second)
    Poser(L, LieuAjuste(i, em, X(WC - 0.55) - X(0.114)), P_TEXTE, em, X(0.114), Y(0.432), 0, t.second)

    ; résumé, calé en bas sur la ligne de base de l'heure : plus large quand le
    ; widget s'élargit (jusqu'à 1,9), sur 4 lignes quand il est étroit
    ; calendrier (option) : sous le lieu ; la météo passe avant : si le widget
    ; est étroit et que le résumé a besoin de ses 4 lignes, pas de ligne calendrier
    largR := Min((WC - 1.05) * u, 1.9 * u, bh.x - X(0) - 0.12 * u), nMax := (WC < 1.9) ? 4 : 3
    cal := CalendrierActif() ? TexteCalendrier(em, X(WC) - X(0.114)) : ""
    if (cal != "" && WC < 1.9) {
        if (Couper(Trim(i.texte " " i.maxi), P_TEXTE, em, largR).Length >= 4)
            cal := ""
        else
            nMax := 3
    }
    if (Ville2W && Ville2Definie() && !Ville2DansBande()) {   ; 2e ville : résumé sur 3 lignes au plus
        nMax := 3
        LigneVille2(L, t, u, X(0), Y(0.537), (WC - 0.55) * u, 0, 0.0635 * u, t.second)
    }
    if (cal != "") {
        IconeCalendrier(L, X(0.0515), Y(0.5185), u, t.second)
        Poser(L, cal, P_TEXTE, em, X(0.114), Y(0.552), 0, t.second)
    }
    if (i.texte != "" || i.maxi != "") {
        lignes := Adapter(i.texte, i.maxi, P_TEXTE, em, largR, nMax, i.normale)
        for ligne in lignes
            Poser(L, ligne, P_TEXTE, em, X(0), Y(0.997 - (lignes.Length - A_Index) * 0.120), 0, t.texte)
    }
    LigneBasseComposer(L, t, u, X(0), WC, Y(1.065), 0)
    return L
}

; Rangée des prochaines heures, ou à défaut la ligne du soleil et de la lune
; (en bas de tous les styles, sauf Analogique qui la place lui-même)
LigneBasseComposer(L, t, u, x0, WC, y, align) {
    if Heures
        RangeeHeures(L, t, u, x0, WC * u, y, NbCreneaux(WC))
    else if (Soleil || LuneLever)
        LigneSoleil(L, t, u, x0, WC * u, y, align)
}

; Style iPhone : la date en haut, l'heure géante au centre, la météo en petit
; en dessous — la mise en page de l'écran verrouillé, faite pour l'effet profondeur.
ComposerIphone(w, h, k, t) {
    L := []
    u  := HC * k
    ox := PAD * k, oy := PAD * k + 0.012 * u
    X(v) => ox + v * u
    Y(v) => oy + v * u
    WC  := LargeurContenu()                         ; l'heure (1,77) impose au moins 1,80
    centre := X(WC / 2)
    i := InfosAffichage()

    emD := EmPourCapitale(P_DATE, 0.075 * u)
    PoserDate(L, emD, 0.075 * u, centre, Y(0.14), 1, (WC - 0.1) * u, t.accent)
    PoserHeure(L, FormatTime(MomentAffiche(), "HH:mm"), t.heure, 0.46 * u, centre, Y(0.70), "centre", t.accent)

    ; ligne météo centrée : illustration, température, lieu
    em := EmPourCapitale(P_TEXTE, 0.07 * u)
    s := Donnees.Has("code") ? 0.15 * u : 0, ecart := s ? 0.03 * u : 0
    debut := (i.temp != "") ? i.temp Chr(0xB0) "  ·  " : ""
    ligne := debut LieuAjuste(i, em, (WC - 0.15) * u - s - ecart - LargeurTexte(debut "x", P_TEXTE, em) + LargeurTexte("x", P_TEXTE, em))
    lt := LargeurTexte(ligne, P_TEXTE, em)
    gauche := centre - (s + ecart + lt) / 2
    if s
        IconeWidget(L, Illustration(Donnees["code"], Donnees.Get("jour", "1")), gauche, Y(0.855) - 0.035 * u - s / 2, s)
    b := Poser(L, ligne, P_TEXTE, em, gauche + s + ecart, Y(0.855), 0, t.texte)
    NoterZoneTemp(s ? {x: gauche, y: Y(0.855) - 0.035 * u - s / 2, w: s, h: s} : "", gauche + s + ecart, b, i.temp, em)

    ; résumé sur une ligne
    if (i.texte != "" || i.maxi != "") {
        em2 := EmPourCapitale(P_TEXTE, 0.0635 * u)
        for ligne in Adapter(i.texte, i.maxi, P_TEXTE, em2, (WC - 0.1) * u, 1, i.normale)
            Poser(L, ligne, P_TEXTE, em2, centre, Y(0.99), 1, t.second)
    }
    LigneBasseComposer(L, t, u, X(0), WC, Y(1.065), 1)
    return L
}

Majuscule(t) => StrUpper(SubStr(t, 1, 1)) SubStr(t, 2)

; Ombre portée douce sous tout ce qui est dessiné (flou gaussien GDI+) : un
; halo large et léger, puis une ombre serrée qui détoure les lettres.
; Le halo, très diffus, est calculé au quart de la résolution puis agrandi :
; beaucoup moins de pixels à flouter, donc un redessin court (le fil du widget
; ne traite aucun message pendant ce temps).
; Chaque forme a sa couleur d'ombre (e.o : noire, ou claire autour d'un texte
; sombre). Avec l'effet profondeur, l'ombre de l'heure disparaît aussi autour
; du sujet (masque élargi), pour ne pas assombrir la personne « devant ».
OmbreDouce(gr, elems, w, h, k, masque := 0) {
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", gr, "Int", 6)          ; bilinéaire haute qualité
    for couche in [[0x70, 5 * k, 1.2 * k, 4], [0x60, 1.3 * k, 0.6 * k, 1]] {
        ; au-delà de 2 Mpx (grand widget sur écran très dense), l'ombre serrée se
        ; calcule à demi-résolution : 2,6 s → ~1 s par redessin, rayon d'au moins 1,9 px
        f := (couche[4] = 1 && w * h > 2000000) ? 2 : couche[4], cw := Ceil(w / f), ch := Ceil(h / f)
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", cw, "Int", ch, "Int", 0, "Int", 0xE200B, "Ptr", 0, "Ptr*", &bmp := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g2 := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4)
        DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", g2, "Float", 1 / f, "Float", 1 / f, "Int", 0)
        for e in elems {
            al := e.HasOwnProp("a") ? Round(couche[1] * e.a) : couche[1]   ; forme en fondu : ombre au prorata
            if (al <= 0)
                continue
            argb := (al << 24) | (e.HasOwnProp("o") ? e.o : 0)
            clip := e.HasOwnProp("contour") && ClipContour
            if clip
                DllCall("gdiplus\GdipSetClipRegion", "Ptr", g2, "Ptr", ClipContour, "Int", 4)
            if (masque && e.HasOwnProp("z") && e.z)
                DllCall("gdiplus\GdipFillPath", "Ptr", g2, "Ptr", BrossePlaquee(masque, 1, argb), "Ptr", e.p)
            else {
                DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br := 0)
                DllCall("gdiplus\GdipFillPath", "Ptr", g2, "Ptr", br, "Ptr", e.p)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
            }
            if clip
                DllCall("gdiplus\GdipResetClip", "Ptr", g2)
        }
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2)
        Flou2D(bmp, couche[2] / f)
        DllCall("gdiplus\GdipDrawImageRectI", "Ptr", gr, "Ptr", bmp, "Int", 0, "Int", Round(couche[3]), "Int", cw * f, "Int", ch * f)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    }
}

; Sous 20 px de rayon, le flou GDI+ n'agit qu'à l'horizontale (mesuré) : on
; floute, on tourne l'image d'un quart de tour, on floute encore, on la remet.
Flou2D(bmp, rayon) {
    Flou(bmp, rayon)
    DllCall("gdiplus\GdipImageRotateFlip", "Ptr", bmp, "Int", 1)      ; 90°
    Flou(bmp, rayon)
    DllCall("gdiplus\GdipImageRotateFlip", "Ptr", bmp, "Int", 3)      ; 270° : retour au sens d'origine
}

; Flou gaussien GDI+ 1.1 (le GUID est passé par adresse : valable en 64 bits)
Flou(bmp, rayon) {
    static guid := 0
    if !guid {
        guid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{633C80A4-1843-482b-9EF2-BE2834C5FDD4}", "Ptr", guid)
    }
    if DllCall("gdiplus\GdipCreateEffect", "Ptr", guid, "Ptr*", &eff := 0)
        return
    p := Buffer(8), NumPut("Float", Min(rayon, 255), "Int", 0, p)
    DllCall("gdiplus\GdipSetEffectParameters", "Ptr", eff, "Ptr", p, "UInt", 8)
    DllCall("gdiplus\GdipBitmapApplyEffect", "Ptr", bmp, "Ptr", eff, "Ptr", 0, "Int", 0, "Ptr", 0, "Ptr", 0)
    DllCall("gdiplus\GdipDeleteEffect", "Ptr", eff)
}

; Remplit une forme : verre, dégradé, heure effacée là où est le sujet (effet
; profondeur), ou aplat. Le contour exclut l'intérieur érodé (voir PreparerRendu).
Remplir(gr, e, masque := 0, brouillon := false) {
    z := masque && e.HasOwnProp("z") && e.z, temp := false, f := CouleurForme(e)   ; teintée la nuit (sauf « brut »)
    if e.HasOwnProp("verre") {
        if (VerreBmp && !brouillon)
            br := BrosseVerre(e.f, masque ? 1 : 0)  ; (la teinte est composée dans sa matrice)
        else if z                                 ; verre simplifié : l'accent à 35 %
            br := BrossePlaquee(masque, 0, 0x59000000 | (f & 0xFFFFFF))
        else
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0x59000000 | (f & 0xFFFFFF), "Ptr*", &br := 0), temp := true
    } else if e.HasOwnProp("dg") {                ; dégradé : les deux extrémités teintées
        dg := (TeinteRendu != "" && !e.HasOwnProp("brut")) ? {c1: TeinteNuit(e.dg.c1), c2: TeinteNuit(e.dg.c2)} : e.dg
        br := z ? BrosseDegradeePlaquee(masque, dg) : BrosseDegrade(dg)
    } else if z                                   ; l'heure, effacée là où est le sujet
        br := BrossePlaquee(masque, 0, f)
    else
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", f, "Ptr*", &br := 0), temp := true
    clip := e.HasOwnProp("contour") && ClipContour
    if clip
        DllCall("gdiplus\GdipSetClipRegion", "Ptr", gr, "Ptr", ClipContour, "Int", 4)   ; exclusion
    DllCall("gdiplus\GdipFillPath", "Ptr", gr, "Ptr", br, "Ptr", e.p)
    if clip
        DllCall("gdiplus\GdipResetClip", "Ptr", gr)
    if temp
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
}

; =============================================================================
;  Texte (converti en formes : placé au pixel près et doté d'une ombre)
; =============================================================================

; Ajoute un texte à la scène. x = bord gauche (align 0), centre (1) ou bord
; droit (2) de la ligne, yb = ligne de base. Renvoie les bornes de l'encre.
Poser(L, txt, police, em, x, yb, align, couleur) {
    p := CheminTexte(txt, police, em, align)
    Deplacer(p, x, yb - LigneDeBase(police, em))
    L.Push({p: p, f: couleur, o: OmbreTheme(), z: false})
    return Bornes(p)
}

OmbreTheme() => IsObject(ThemeCourant) ? ThemeCourant.ombre : 0x000000

; Variante calée sur l'encre : le bord gauche du dessin tombe exactement en x
PoserEncre(L, txt, police, em, x, yb, couleur) {
    p := CheminTexte(txt, police, em, 0)
    b := Bornes(p)
    Deplacer(p, x - b.x, yb - LigneDeBase(police, em))
    L.Push({p: p, f: couleur, o: OmbreTheme(), z: false})
}

; Format typographique (sans les marges que GDI+ ajoute d'ordinaire) : les
; lignes s'alignent sur leur chasse, comme sur Android.
CheminTexte(txt, police, em, align := 0) {
    style := 0
    if (p := InStr(police, "|"))                  ; « Famille|1 » : style gras
        style := Integer(SubStr(police, p + 1)), police := SubStr(police, 1, p - 1)
    fam := Famille(police)
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "Ptr*", &typo := 0)
    DllCall("gdiplus\GdipCloneStringFormat", "Ptr", typo, "Ptr*", &fmt := 0)
    DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", fmt, "Int", 0x7004)     ; typographique + une seule ligne
    DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", align)
    zone := (align = 2) ? Rect(-100000, 0, 100000, 10000) : (align = 1) ? Rect(-50000, 0, 100000, 10000) : Rect(0, 0, 100000, 10000)
    DllCall("gdiplus\GdipAddPathString", "Ptr", p, "WStr", String(txt), "Int", -1, "Ptr", fam, "Int", style,
        "Float", em, "Ptr", zone, "Ptr", fmt)
    ; remplissage en « enroulement » : les polices variables (Bahnschrift,
    ; Cascadia) ont des contours qui se chevauchent, et l'alterné y ferait des trous
    DllCall("gdiplus\GdipSetPathFillMode", "Ptr", p, "Int", 1)
    DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
    DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
    return p
}

; L'heure en cases fixes, alignée à droite sur x (ou centrée sur x). Les chiffres de
; Segoe UI n'ont pas tous la même largeur (le « 1 » est étroit) : posée telle
; quelle, l'heure se décalerait à chaque minute. Chaque chiffre est centré dans
; une case constante (0,84 capitale, l'avance des chiffres du widget Android) ;
; le « : » garde 0,18 capitale d'écart avec le chiffre le plus large, marge de
; la case comprise. Renvoie les bornes du bloc.
; Les formes de l'heure sont marquées « z » : ce sont elles qui passent
; derrière le sujet avec l'effet profondeur.
PoserHeure(L, txt, police, cap, x, yb, align, couleur) {
    em := EmHeure(police, cap)                    ; chiffres à la hauteur de ceux du style
    cs := CasesHeure(police, em, cap)
    formes := [], total := 0
    Loop Parse txt {
        p := CheminTexte(A_LoopField, police, em)
        b := Bornes(p)
        lc := IsDigit(A_LoopField) ? cs.chiffre : b.w + 2 * cs.ecart
        formes.Push({p: p, b: b, lc: lc}), total += lc
    }
    xd := (align = "centre") ? x + total / 2 : x
    xx := xd
    Loop formes.Length {
        fo := formes[formes.Length - A_Index + 1]
        Deplacer(fo.p, xx - fo.lc / 2 - (fo.b.x + fo.b.w / 2), yb - LigneDeBase(police, em))
        L.Push({p: fo.p, f: couleur, o: OmbreTheme(), z: true})
        xx -= fo.lc
    }
    global BlocHeure := {x: xx, y: yb - cap, w: xd - xx, h: cap}   ; pour le rendu (zone, dégradé)
    return {x: xx, y: yb - cap, w: xd - xx, h: cap}
}

; Mesures d'un « H » de 100 px : hauteur de capitale et ligne de base
Mesure(police) {
    static cache := Map()
    if !cache.Has(police) {
        p := CheminTexte("H", police, 100)
        b := Bornes(p)
        DllCall("gdiplus\GdipDeletePath", "Ptr", p)
        cache[police] := {cap: b.h / 100, ligne: (b.y + b.h) / 100}
    }
    return cache[police]
}

EmPourCapitale(police, cap) => cap / Mesure(police).cap
LigneDeBase(police, em) => Mesure(police).ligne * em

LargeurTexte(txt, police, em) {
    p := CheminTexte(txt, police, em)
    b := Bornes(p)
    DllCall("gdiplus\GdipDeletePath", "Ptr", p)
    return b.x + b.w
}

; Choisit la forme la plus complète du résumé qui tient en « nMax » lignes :
; avec le maximum en entier, puis abrégé (« Max. »), suivi de sa normale
; (option) puis sans elle, et enfin sans maximum. En dernier
; recours, la dernière ligne est raccourcie au mot près — jamais au milieu
; d'un nombre (« Maximum 26 ° » est soudé par des espaces insécables).
Adapter(texte, maxi, police, em, largeur, nMax, normale := "") {
    essais := []
    if (maxi != "") {
        court := StrReplace(StrReplace(maxi, "maximum", "max.", true), "Maximum", "Max.", true)
        if (normale != "")
            essais.Push(Trim(texte " " maxi normale), Trim(texte " " court normale))
        essais.Push(Trim(texte " " maxi), Trim(texte " " court))
    }
    if (texte != "")
        essais.Push(texte)
    for e in essais {
        lignes := Couper(e, police, em, largeur)
        if (lignes.Length <= nMax)
            return lignes
    }
    reste := lignes[nMax]
    Loop lignes.Length - nMax
        reste .= " " lignes[nMax + A_Index]
    lignes.Length := nMax
    lignes[nMax] := TronquerMots(reste, police, em, largeur)
    return lignes
}

; Découpe un texte en lignes d'au plus « largeur », aux espaces ordinaires
; seulement (les insécables gardent « 14 h » ou « 26 ° » d'un seul tenant)
Couper(txt, police, em, largeur) {
    lignes := [], cur := ""
    for mot in StrSplit(txt, " ") {
        essai := (cur = "") ? mot : cur " " mot
        if (cur != "" && LargeurTexte(essai, police, em) > largeur) {
            lignes.Push(cur)
            cur := mot
        } else
            cur := essai
    }
    if (cur != "")
        lignes.Push(cur)
    return lignes
}

; Raccourcit un texte au mot près (avec « … ») pour qu'il tienne dans « largeur »
TronquerMots(txt, police, em, largeur) {
    if (LargeurTexte(txt, police, em) <= largeur)
        return txt
    mots := StrSplit(txt, " ")
    while (mots.Length > 1) {
        mots.Pop()
        t := ""
        for mot in mots
            t .= (A_Index > 1 ? " " : "") mot
        t := RTrim(t, " ·,.") "…"
        if (LargeurTexte(t, police, em) <= largeur)
            return t
    }
    return Tronquer(mots[1], police, em, largeur)     ; un seul mot trop long
}

; Raccourcit un texte par la fin, caractère par caractère (avec « … »)
Tronquer(txt, police, em, largeur) {
    if (LargeurTexte(txt, police, em) <= largeur)
        return txt
    while (StrLen(txt) > 1) {
        txt := RTrim(SubStr(txt, 1, -1), " ·,." Chr(0xA0))
        if (LargeurTexte(txt "…", police, em) <= largeur)
            break
    }
    return txt "…"
}

; Épingle de localisation en contour, centrée en (cx, cy) (mesures du widget Android)
Epingle(L, cx, cy, u, couleur) {
    e := 0.0068 * u                                ; épaisseur du trait
    r := 0.0336 * u - e / 2                        ; rayon de la tête (axe du trait)
    d := 0.0500 * u - e / 2                        ; centre -> pointe
    a := ACos(r / d) * 57.29578                    ; demi-angle entre les deux tangentes
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", cx - r, "Float", cy - r, "Float", 2 * r, "Float", 2 * r,
        "Float", 90 + a, "Float", 360 - 2 * a)
    DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", cx + r * Cos((90 - a) / 57.29578), "Float", cy + r * Sin((90 - a) / 57.29578),
        "Float", cx, "Float", cy + d)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    ri := 0.0166 * u - e / 2
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", p, "Float", cx - ri, "Float", cy - ri, "Float", 2 * ri, "Float", 2 * ri)
    Elargir(p, e)
    L.Push({p: p, f: couleur, o: OmbreTheme(), z: false})
}

; =============================================================================
;  Illustrations météo (formes vectorielles en aplats, repère 100 x 100)
; =============================================================================

; Code WMO courant + jour/nuit -> identifiant d'illustration
Illustration(code, jour) {
    if !IsNumber(code)
        return "nuageux"
    c := Integer(code), n := (jour = "0")
    if (c < 0 || c > 99)
        return "nuageux"
    switch {
        case c = 0:                      return n ? "lune" : "soleil"
        case c = 1:                      return n ? "lune_peu" : "soleil_peu"
        case c = 2:                      return n ? "lune_nuage" : "soleil_nuage"
        case c < 45:                     return "nuageux"
        case c < 51:                     return "brouillard"
        case c = 56 || c = 57 || c = 66 || c = 67: return "verglas"
        case c < 60:                     return "bruine"
        case c = 65:                     return "forte_pluie"
        case c < 70:                     return "pluie"
        case c < 80:                     return "neige"
        case c = 82:                     return "forte_pluie"
        case c < 85:                     return n ? "averses_nuit" : "averses_jour"
        case c < 90:                     return n ? "averses_neige_nuit" : "averses_neige_jour"
        case c = 95:                     return "orage"
    }
    return "orage_grele"                           ; 96, 99 (et codes inconnus 90–99)
}

; Libellé court de la condition actuelle (repli quand le résumé manque)
InfosMeteo(code) {
    static t := Map(0, "Ciel dégagé", 1, "Généralement ensoleillé", 2, "Partiellement nuageux", 3, "Nuageux",
        45, "Brouillard", 48, "Brouillard givrant", 51, "Bruine", 53, "Bruine", 55, "Bruine",
        56, "Bruine verglaçante", 57, "Bruine verglaçante", 61, "Pluie faible", 63, "Pluie", 65, "Forte pluie",
        66, "Pluie verglaçante", 67, "Pluie verglaçante", 71, "Neige faible", 73, "Neige", 75, "Forte neige",
        77, "Grésil", 80, "Averses", 81, "Averses", 82, "Fortes averses", 85, "Averses de neige",
        86, "Averses de neige", 95, "Orages", 96, "Orages et grêle", 99, "Orages et grêle")
    return (IsNumber(code) && t.Has(Integer(code))) ? t[Integer(code)] : "Météo"
}

; Dessine l'illustration « id » dans le carré (X, Y, S). Ordre : astre, nuage
; arrière, nuage avant, puis précipitations ou éclair.
; « ph » (de 0 à 1) : moment de la boucle d'animation (widget-meteo-animation.ahk) —
; nuages qui glissent, astre qui rayonne, pluie et neige qui tombent, éclair.
; -1 : illustration fixe (toujours le cas, sauf option « Animations légères »).
Illustrer(L, id, X, Y, S, ph := -1) {
    c := {x: X, y: Y, u: S / 100}
    an := (ph >= 0)
    d1 := an ? 2.5 * Sin(6.2832 * ph) : 0          ; glissement du nuage avant (unités de l'icône)
    d2 := -0.7 * d1                                ; le nuage arrière glisse en sens inverse

    ; la lune : dans sa phase réelle, à la place et à la taille du soleil de
    ; l'illustration de jour (xs, ys, rs) ; sinon le croissant d'origine (xc, yc, rc)
    Astre(xs, ys, rs, xc, yc, rc) => LuneReelle ? PhaseLune(L, c, xs, ys, rs, LunePsi) : Croissant(L, c, xc, yc, rc)
    ; halo qui « respire » autour d'un astre (pas d'ombre sous le halo)
    Halo(cx, cy, r, couleur, force := 1) {
        if !an
            return
        v := 0.5 + 0.5 * Sin(6.2832 * ph)
        Disque(L, c, cx, cy, r + 3 + 4 * v, (Round((0x2A + 0x26 * v) * force) << 24) | (couleur & 0xFFFFFF))
        L[L.Length].a := 0
    }
    ; Chaque goutte ou flocon a sa propre phase (décalée du nombre d'or) : ils
    ; apparaissent sous le nuage, tombent, puis s'effacent, chacun à son tour.
    Moment(i, tours) => Mod(ph * tours + (i - 1) * 0.618, 1)
    Fondu(t) => Max(0, Min(1, t / 0.2, (1 - t) / 0.3))
    ; pluie : chaque goutte glisse le long de son trait (« tours » chutes par boucle)
    Chute(segs, ep, dist, tours) {
        if !an
            return Traits(L, c, segs, ep, C_PLUIE)
        for q in segs {
            t := Moment(A_Index, tours), f := Fondu(t), dd := (t - 0.45) * dist
            lq := Sqrt((q[3] - q[1]) ** 2 + (q[4] - q[2]) ** 2)
            ux := (q[3] - q[1]) / lq, uy := (q[4] - q[2]) / lq
            Traits(L, c, [[q[1] + ux * dd, q[2] + uy * dd, q[3] + ux * dd, q[4] + uy * dd]], ep, (Round(255 * f) << 24) | (C_PLUIE & 0xFFFFFF))
            L[L.Length].a := f
        }
    }
    ; neige : chaque flocon descend en se balançant
    Neige(pos) {
        if !an
            return Flocons(L, c, pos)
        for q in pos {
            t := Moment(A_Index, 2), f := Fondu(t)
            Flocons(L, c, [[q[1] + 2.5 * Sin(6.2832 * (t + A_Index / 3)), q[2] + (t - 0.45) * 16]])
            L[L.Length].f := (Round(255 * f) << 24) | (C_NEIGE & 0xFFFFFF), L[L.Length].a := f
        }
    }

    switch id {
        case "soleil":        Halo(50, 50, 34, C_SOLEIL), Disque(L, c, 50, 50, 34, C_SOLEIL)
        case "lune":
            if LuneReelle                          ; le halo suit la part éclairée
                Halo(50, 50, 34, C_LUNE, FractionLune(LunePsi))
            else
                Halo(50.9, 49.1, 39.7, C_LUNE)
            Astre(50, 50, 34, 50.9, 49.1, 39.7)
        case "soleil_peu":    Halo(58, 42, 36, C_SOLEIL), Disque(L, c, 58, 42, 36, C_SOLEIL), Nuage(L, c, 21.3 + d1, 77.9, 19.9, C_NUAGE)
        case "lune_peu":      Astre(58, 42, 36, 56.3, 44.8, 44.1), Nuage(L, c, 21.3 + d1, 77.9, 19.9, C_NUAGE)
        case "soleil_nuage":  Halo(64, 34, 26, C_SOLEIL), Disque(L, c, 64, 34, 26, C_SOLEIL), Nuage(L, c, 34 + d1, 62, 26, C_NUAGE)
        case "lune_nuage":    Astre(64, 34, 26, 62, 36, 30), Nuage(L, c, 34 + d1, 62, 26, C_NUAGE)
        case "nuageux":       Nuage(L, c, 54 + d2, 36, 20, C_GRIS), Nuage(L, c, 34 + d1, 58, 26, C_NUAGE)
        case "brouillard":
            b := []                                ; chaque banc de brume ondule à son rythme
            Loop 5
                b.Push(an ? 3 * Sin(6.2832 * ph + A_Index * 1.3) : 0)
            Barre(L, c, 14 + b[1], 78 + b[1], 30, C_BRUME[1]), Barre(L, c, 24 + b[2], 88 + b[2], 44, C_BRUME[2])
            Barre(L, c, 10 + b[3], 64 + b[3], 58, C_BRUME[1]), Barre(L, c, 70 + b[4], 90 + b[4], 58, C_BRUME[1])
            Barre(L, c, 20 + b[5], 84 + b[5], 72, C_BRUME[2])
        case "bruine":
            Nuage(L, c, 39, 36, 24, C_NUAGE)
            Chute([[36, 70, 34, 76], [52, 70, 50, 76], [68, 70, 66, 76], [44, 84, 42, 90], [60, 84, 58, 90]], 4.5, 12, 3)
        case "pluie":
            Nuage(L, c, 39, 36, 24, C_NUAGE)
            Chute([[36, 70, 32, 84], [52, 70, 48, 84], [68, 70, 64, 84]], 5.5, 16, 4)
        case "forte_pluie":
            Nuage(L, c, 39, 36, 24, C_GRIS)
            Chute([[30, 68, 24, 90], [44, 68, 38, 90], [58, 68, 52, 90], [72, 68, 66, 90]], 5.5, 14, 5)
        case "averses_jour", "averses_nuit":
            (id = "averses_jour") ? Disque(L, c, 68, 30, 22, C_SOLEIL) : Astre(68, 30, 22, 68, 30, 24)
            Nuage(L, c, 36, 42, 22, C_NUAGE)
            Chute([[34, 72, 30, 86], [50, 72, 46, 86], [66, 72, 62, 86]], 5.5, 14, 4)
        case "neige":
            Nuage(L, c, 39, 36, 24, C_NUAGE)
            Neige([[34, 74], [66, 74], [50, 88]])
        case "averses_neige_jour", "averses_neige_nuit":
            (id = "averses_neige_jour") ? Disque(L, c, 68, 30, 22, C_SOLEIL) : Astre(68, 30, 22, 68, 30, 24)
            Nuage(L, c, 36, 42, 22, C_NUAGE)
            Neige([[34, 78], [66, 78], [50, 90]])
        case "verglas":
            Nuage(L, c, 39, 36, 24, C_NUAGE)
            Chute([[36, 68, 32, 82], [64, 68, 60, 82]], 5.5, 12, 3)
            Losanges(L, c, [[50, 76], [40, 92], [60, 92]], 5)
        case "orage", "orage_grele":
            ; deux éclairs brefs par boucle : une lueur pâle et diffuse derrière le nuage
            if (an && ((ph >= 0.60 && ph < 0.645) || (ph >= 0.70 && ph < 0.73)))
                for r in [46, 38, 30, 22] {
                    Disque(L, c, 45, 42, r, 0x1CFFF6D8)
                    L[L.Length].a := 0
                }
            Nuage(L, c, 39, 34, 24, C_ORAGE)
            Polygone(L, c, [[56, 54], [66, 54], [58, 70], [68, 70], [46, 96], [51, 76], [42, 76]], C_SOLEIL)
            if (id = "orage_grele")
                for q in [[28, 74], [80, 72], [76, 90]]
                    Disque(L, c, q[1], q[2], 4.5, C_GLACE)
    }
}

Disque(L, c, cx, cy, r, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    Cercle(p, c, cx, cy, r)
    L.Push({p: p, f: couleur})
}

; Nuage : une « pilule » (couleur arrière) sur laquelle se pose un grand disque
; (couleur avant) à gauche.
Nuage(L, c, cx, cy, R, couleurs) {
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    Pilule(p, c, cx - 0.58 * R, cy - 0.16 * R, cx + 1.90 * R, cy + R)
    L.Push({p: p, f: couleurs[2]})
    Disque(L, c, cx, cy, R, couleurs[1])
}

; Croissant de lune : le disque (cx, cy, R) privé du disque (cx + 0,636 R,
; cy - 0,636 R, 0,923 R). Construit avec deux arcs pour garder des bords lissés.
Croissant(L, c, cx, cy, R) {
    ax := c.x + cx * c.u, ay := c.y + cy * c.u, R1 := R * c.u
    bx := ax + 0.636 * R1, by := ay - 0.636 * R1, R2 := 0.923 * R1
    d  := Sqrt((bx - ax) ** 2 + (by - ay) ** 2)
    a  := (R1 ** 2 - R2 ** 2 + d ** 2) / (2 * d)
    hh := Sqrt(Max(R1 ** 2 - a ** 2, 0))
    mx := ax + a * (bx - ax) / d, my := ay + a * (by - ay) / d
    p1x := mx + hh * (by - ay) / d, p1y := my - hh * (bx - ax) / d
    p2x := mx - hh * (by - ay) / d, p2y := my + hh * (bx - ax) / d
    t1 := Angle(p1x - ax, p1y - ay), t2 := Angle(p2x - ax, p2y - ay), tB := Angle(bx - ax, by - ay)
    ; arc extérieur : celui qui ne passe pas du côté du disque retiré
    s := Mod(t2 - t1 + 720, 360)
    if (Mod(tB - t1 + 720, 360) < s)
        ts := t2, ss := 360 - s, ex := p1x, ey := p1y, sx := p2x, sy := p2y
    else
        ts := t1, ss := s, ex := p2x, ey := p2y, sx := p1x, sy := p1y
    ; arc intérieur (sur le disque retiré), de la fin de l'arc extérieur vers son début
    ue := Angle(ex - bx, ey - by), us := Angle(sx - bx, sy - by), tA := Angle(ax - bx, ay - by)
    q := Mod(us - ue + 720, 360)
    sb := (Mod(tA - ue + 720, 360) < q) ? q : -(360 - q)
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", ax - R1, "Float", ay - R1, "Float", 2 * R1, "Float", 2 * R1, "Float", ts, "Float", ss)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", bx - R2, "Float", by - R2, "Float", 2 * R2, "Float", 2 * R2, "Float", ue, "Float", sb)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    L.Push({p: p, f: C_LUNE})
}

Angle(dx, dy) => Mod(DllCall("msvcrt\atan2", "Double", dy, "Double", dx, "CDecl Double") * 57.29578 + 360, 360)

; Traits à bouts ronds [[x1, y1, x2, y2], …] (gouttes de pluie)
Traits(L, c, segs, ep, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    for q in segs {
        DllCall("gdiplus\GdipStartPathFigure", "Ptr", p)
        DllCall("gdiplus\GdipAddPathLine", "Ptr", p, "Float", c.x + q[1] * c.u, "Float", c.y + q[2] * c.u,
            "Float", c.x + q[3] * c.u, "Float", c.y + q[4] * c.u)
    }
    Elargir(p, ep * c.u)
    L.Push({p: p, f: couleur})
}

; Flocons : trois segments croisés (90°, 30°, 150°), demi-longueur 6,5
Flocons(L, c, pos) {
    segs := []
    for q in pos
        for a in [90, 30, 150] {
            dx := 6.5 * Cos(a / 57.29578), dy := 6.5 * Sin(a / 57.29578)
            segs.Push([q[1] - dx, q[2] - dy, q[1] + dx, q[2] + dy])
        }
    Traits(L, c, segs, 3.5, C_NEIGE)
}

Losanges(L, c, pos, dd) {
    for q in pos
        Polygone(L, c, [[q[1], q[2] - dd], [q[1] + dd, q[2]], [q[1], q[2] + dd], [q[1] - dd, q[2]]], C_GLACE)
}

; Barre de brouillard : hauteur 8, bouts arrondis, de x1 à x2 autour de y
Barre(L, c, x1, x2, y, couleur) {
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    Pilule(p, c, x1, y - 4, x2, y + 4)
    L.Push({p: p, f: couleur})
}

Polygone(L, c, pts, couleur) {
    buf := Buffer(8 * pts.Length)
    for q in pts
        NumPut("Float", c.x + q[1] * c.u, "Float", c.y + q[2] * c.u, buf, (A_Index - 1) * 8)
    DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &p := 0)
    DllCall("gdiplus\GdipAddPathPolygon", "Ptr", p, "Ptr", buf, "Int", pts.Length)
    L.Push({p: p, f: couleur})
}

; ---------- Primitives de chemins (coordonnées dans le repère de l'icône) ----------

Cercle(p, c, cx, cy, r) {
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", p, "Float", c.x + (cx - r) * c.u, "Float", c.y + (cy - r) * c.u,
        "Float", 2 * r * c.u, "Float", 2 * r * c.u)
}

; Rectangle aux extrémités entièrement arrondies, de (x1, y1) à (x2, y2)
Pilule(p, c, x1, y1, x2, y2) {
    px := c.x + x1 * c.u, py := c.y + y1 * c.u, pw := (x2 - x1) * c.u, ph := (y2 - y1) * c.u
    DllCall("gdiplus\GdipStartPathFigure", "Ptr", p)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", px, "Float", py, "Float", ph, "Float", ph, "Float", 90, "Float", 180)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", px + pw - ph, "Float", py, "Float", ph, "Float", ph, "Float", 270, "Float", 180)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
}

; Transforme un tracé en contour épais à bouts ronds (rempli ensuite)
Elargir(p, ep) {
    DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF000000, "Float", ep, "Int", 0, "Ptr*", &pen := 0)
    DllCall("gdiplus\GdipSetPenLineCap197819", "Ptr", pen, "Int", 2, "Int", 2, "Int", 2)   ; bouts ronds
    DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2)
    DllCall("gdiplus\GdipWidenPath", "Ptr", p, "Ptr", pen, "Ptr", 0, "Float", 0.25)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    DllCall("gdiplus\GdipSetPathFillMode", "Ptr", p, "Int", 1)
}

Bornes(p) {
    r := Buffer(16, 0)
    DllCall("gdiplus\GdipGetPathWorldBounds", "Ptr", p, "Ptr", r, "Ptr", 0, "Ptr", 0)
    return {x: NumGet(r, 0, "Float"), y: NumGet(r, 4, "Float"), w: NumGet(r, 8, "Float"), h: NumGet(r, 12, "Float")}
}

Deplacer(p, dx, dy) {
    DllCall("gdiplus\GdipCreateMatrix2", "Float", 1, "Float", 0, "Float", 0, "Float", 1, "Float", dx, "Float", dy, "Ptr*", &m := 0)
    DllCall("gdiplus\GdipTransformPath", "Ptr", p, "Ptr", m)
    DllCall("gdiplus\GdipDeleteMatrix", "Ptr", m)
}

MaintenantUnix() => DateDiff(A_NowUTC, "19700101", "Seconds")

Famille(nom) {
    if DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", nom, "Ptr", 0, "Ptr*", &fam := 0)
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam := 0)
    return fam
}

Rect(x, y, w, h) {
    r := Buffer(16)
    NumPut("Float", x, "Float", y, "Float", w, "Float", h, r)
    return r
}

RectArrondi(gr, x, y, w, h, r, argb) {
    path := CheminArrondi(x, y, w, h, r)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPath", "Ptr", gr, "Ptr", br, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}

; Tracé d'un rectangle aux coins arrondis (rayon r), à libérer par l'appelant
CheminArrondi(x, y, w, h, r) {
    d := r * 2
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path := 0)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x,         "Float", y,         "Float", d, "Float", d, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y,         "Float", d, "Float", d, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0,   "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x,         "Float", y + h - d, "Float", d, "Float", d, "Float", 90,  "Float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
    return path
}

Aplat(gr, x, y, w, h, argb) {
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br := 0)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", gr, "Ptr", br, "Float", x, "Float", y, "Float", w, "Float", h)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
}

; =============================================================================
;  Aperçus (tests)
; =============================================================================

; Le widget sur le coin haut droit de ton fond d'écran, puis sur fond sombre et fond clair
Apercu(fichier) {
    PreparerBande()
    k := Echelle()
    w := Round(LargeurWidget() * k), h := Round(HauteurWidget() * k), m := Round(20 * k)
    cw := w + 2 * m, tw := 3 * cw, th := h + 2 * m
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", tw, "Int", th, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, cw, th, 0xFF20252B)
    CalculerPosition(w, h, &xw, &yw)
    global ThemeLx := xw, ThemeLy := yw           ; thème sur la position logique
    o := OrbiteVoulue(), xw += o[1], yw += o[2]   ; orbite=dx,dy : alignement du masque décalé
    fond := FondEcran()
    if (fond && !DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", fond, "Ptr*", &img := 0)) {
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", img, "UInt*", &iw := 0)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", img, "UInt*", &ih := 0)
        ; fond en mode « Remplir » : image agrandie jusqu'à couvrir l'écran, centrée,
        ; débords rognés. On découpe la zone qui est vraiment sous le widget.
        e := Max(A_ScreenWidth / iw, A_ScreenHeight / ih)
        ox := (iw * e - A_ScreenWidth) / 2, oy := (ih * e - A_ScreenHeight) / 2
        DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", gr, "Ptr", img, "Float", 0, "Float", 0, "Float", cw, "Float", th,
            "Float", (xw - m + ox) / e, "Float", (yw - m + oy) / e, "Float", cw / e, "Float", th / e, "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", img)
    }
    Aplat(gr, cw, 0, cw, th, 0xFF1F3B5C)
    Aplat(gr, 2 * cw, 0, cw, th, 0xFFD9E3EC)
    global SansProfondeur
    Loop 3 {
        SansProfondeur := (A_Index > 1)           ; sur fond uni, pas de sujet derrière l'heure
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0xE200B, "Ptr", 0, "Ptr*", &cal := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", cal, "Ptr*", &g2 := 0)
        Dessiner(g2, w, h, k, xw, yw, ApercuBrouillon)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2)
        DessinerAttenue(gr, cal, (A_Index - 1) * cw + m, m, w, h, ModeEdition ? 255 : AlphaCible())   ; intensité du mode nuit
        DllCall("gdiplus\GdipDisposeImage", "Ptr", cal)
        px := (A_Index - 1) * cw + m              ; (A_Index : celui de la boucle for, dans la for)
        if ApercuZones                            ; zones cliquables, en cyan
            for z in ZonesRendu {
                DllCall("gdiplus\GdipCreatePen1", "UInt", 0xE633D6FF, "Float", 2, "Int", 0, "Ptr*", &pen := 0)
                DllCall("gdiplus\GdipDrawRectangle", "Ptr", gr, "Ptr", pen, "Float", px + z.x, "Float", m + z.y, "Float", z.w, "Float", z.h)
                DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
            }
    }
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

; Toutes les illustrations, sur fond sombre (haut) et clair (bas)
PlancheIcones(fichier) {
    ids := ["soleil", "lune", "soleil_peu", "lune_peu", "soleil_nuage", "lune_nuage", "nuageux", "brouillard", "bruine", "pluie",
        "forte_pluie", "averses_jour", "averses_nuit", "neige", "averses_neige_jour", "averses_neige_nuit", "verglas", "orage", "orage_grele"]
    t := 220, tw := ids.Length * t, th := 2 * t + 60
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", tw, "Int", th, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gr, "Int", 4)
    Aplat(gr, 0, 0, tw, t + 30, 0xFF1C2733)
    Aplat(gr, 0, t + 30, tw, t + 30, 0xFFE4EAF0)
    for id in ids {
        i := A_Index - 1
        ; chaque case est dessinée sur son propre petit calque (le flou reste rapide)
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", t, "Int", t, "Int", 0, "Int", 0xE200B, "Ptr", 0, "Ptr*", &cal := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", cal, "Ptr*", &g2 := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4)
        L := []
        Illustrer(L, id, 20, 20, t - 40)
        OmbreDouce(g2, L, t, t, 2.5)
        for e in L
            Remplir(g2, e)
        for e in L
            DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2)
        for rang in [0, 1]
            DllCall("gdiplus\GdipDrawImageRectI", "Ptr", gr, "Ptr", cal, "Int", i * t, "Int", rang * (t + 30), "Int", t, "Int", t)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", cal)
        L := []
        Poser(L, id, "Segoe UI", 20, i * t + 10, t + 22, 0, 0xFFB0BCC8)
        Remplir(gr, L[1]), DllCall("gdiplus\GdipDeletePath", "Ptr", L[1].p)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

FondEcran() {
    f := EnvGet("APPDATA") "\Microsoft\Windows\Themes\TranscodedWallpaper"
    if FileExist(f)
        return f
    try return RegRead("HKCU\Control Panel\Desktop", "WallPaper")
    return ""
}

Enregistrer(bmp, fichier) {
    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bmp, "WStr", fichier, "Ptr", clsid, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
}

; La fenêtre des prévisions détaillées, sur un fond de bureau gris
ApercuPrevisions(fichier, source := "") {
    p := LirePrevisions(source)
    if (!p.jours.Length || !p.heures.Length)
        throw Error("previsions.txt absent ou vide")
    p.mp := MisePagePrevisions(p)
    kp := A_ScreenDPI / 96, w := Round(p.mp.w * kp), h := Round(p.mp.h * kp), m := Round(16 * kp)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w + 2 * m, "Int", h + 2 * m, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, w + 2 * m, h + 2 * m, 0xFF5A6570)
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", gr, "Float", m, "Float", m, "Int", 0)
    DessinerPrevisions(gr, w, h, kp, p)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

; Auto-test des calculs du redimensionnement (sans souris ni fenêtre) : un
; écran simulé, un widget centré ou dans un coin, des gestes tirés par les
; coins et les côtés. Écrit un rapport ; « ÉCHEC » signale un invariant faux.
TestGeste(fichier) {
    global Geste, GlisseX0, GlisseY0, Taille, LargeurPct
    rapport := "", echecs := 0
    e := {ml: 0, mt: 0, mr: 3840, mb: 2400, l: 0, t: 0, r: 3840, b: 2280}
    Verifier(ok, quoi) {
        if !ok
            echecs++
        rapport .= (ok ? "ok     " : "ÉCHEC  ") quoi "`n"
    }
    for cas in [["centré", 1251, 101], ["coin bas droit", 2400, 1400], ["coin haut gauche", 40, 40]] {
        Taille := 125, LargeurPct := 100
        k := EchellePour(125), w0 := Round(LargeurWidget() * k), h0 := Round(HauteurWidget() * k)
        x0 := cas[2], y0 := cas[3]
        for z in ["hg", "hd", "bg", "bd", "g", "d"] {
            ; appui au milieu de la bande du bord tiré
            px := x0 + (InStr(z, "d") ? w0 - 5 : 5), py := y0 + (InStr(z, "b") ? h0 - 5 : InStr(z, "h") ? 5 : h0 // 2)
            Geste := {zone: z, actif: false, x0: x0, y0: y0, w0: w0, h0: h0, e: e}
            GlisseX0 := px, GlisseY0 := py
            DemarrerGeste()
            g := Geste
            for dep in [[300, 200], [-400, -250], [5000, 5000], [-5000, -5000], [0, 0]] {
                dx := dep[1] * g.sx, dy := dep[2] * (g.sy ? g.sy : 1)
                CalculerGeste(px + dx, py + dy)
                k := EchellePour(g.t), w := Round(LargeurWidget(g.lp) * k), h := Round(HauteurWidget() * k)
                l := cas[1] " " z " " dep[1] "," dep[2] " -> taille " g.t " largeur " g.lp " : " g.x "," g.y " " w "x" h
                Verifier(g.t >= TAILLE_MIN && g.t <= Max(g.t0, TAILLE_MAX), l " (taille bornée)")
                Verifier(g.x >= e.l - 1 && g.y >= e.t - 1 && g.x + w <= e.r + 1 && g.y + h <= e.b + 1, l " (dans la zone de travail)")
                if g.cX
                    Verifier(Abs(g.x + w / 2 - 1920) <= 1, l " (reste centré)")
                else if (g.sx > 0)
                    Verifier(g.x = x0, l " (bord gauche fixe)")
                else
                    Verifier(g.x + w = x0 + w0 || Abs(g.x + w - (x0 + w0)) <= 1, l " (bord droit fixe)")
                if (g.sy = 0)
                    Verifier(g.y = y0 && h = h0, l " (hauteur et haut inchangés)")
                else if (g.sy > 0 && !g.cY)
                    Verifier(g.y = y0, l " (haut fixe)")
                else if (g.sy < 0 && !g.cY)
                    Verifier(Abs(g.y + h - (y0 + h0)) <= 1, l " (bas fixe)")
                if (dep[1] = 0)
                    Verifier(g.t = g.t0 && g.lp = g.lp0, l " (retour au départ = taille de départ)")
            }
            Geste := ""
        }
    }
    ; gestes enchaînés sur un widget centré (chacun part du résultat du précédent) :
    ; le centrage ne doit pas dériver d'un demi-pixel à chaque fois
    Taille := 125, LargeurPct := 100
    k := EchellePour(125), w0 := Round(LargeurWidget() * k), h0 := Round(HauteurWidget() * k)
    x0 := Round((3840 - w0) / 2), y0 := 101
    for i, dep in [[37, 21], [51, 33], [-29, -17], [63, 40], [-71, -44], [13, 9], [88, 51], [-5, -3], [41, 27], [-97, -60], [7, 5], [120, 70]] {
        z := Mod(i, 3) ? "bd" : "d"
        px := x0 + w0 - 5, py := y0 + ((z = "d") ? h0 // 2 : h0 - 5)
        Geste := {zone: z, actif: false, x0: x0, y0: y0, w0: w0, h0: h0, e: e}
        GlisseX0 := px, GlisseY0 := py
        DemarrerGeste()
        g := Geste
        CalculerGeste(px + dep[1], py + dep[2])
        k := EchellePour(g.t), w := Round(LargeurWidget(g.lp) * k), h := Round(HauteurWidget() * k)
        Verifier(g.cX && Abs(g.x + w / 2 - 1920) <= 0.5, "enchaîné " i " (" z ") : taille " g.t " largeur " g.lp " → " g.x " " w "x" h " (toujours centré)")
        x0 := g.x, y0 := g.y, w0 := w, h0 := h, Taille := g.t, LargeurPct := g.lp
        Geste := ""
    }
    try Hotkey(TOUCHE_ECHAP, "Off")
    FileAppend(rapport "`n" echecs " échec(s)`n", fichier, "UTF-8")
}

; Planche d'une animation : « n » images de la boucle de l'illustration « id »
PlancheAnimation(fichier, id, n := 8) {
    t := 220
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", n * t, "Int", t, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &gr := 0)
    Aplat(gr, 0, 0, n * t, t, 0xFF1C2733)
    Loop n {
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", t, "Int", t, "Int", 0, "Int", 0xE200B, "Ptr", 0, "Ptr*", &cal := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", cal, "Ptr*", &g2 := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4)
        L := []
        Illustrer(L, id, 20, 20, t - 40, (A_Index - 1) / n)
        OmbreDouce(g2, L, t, t, 2.5)
        for e in L
            Remplir(g2, e)
        for e in L
            DllCall("gdiplus\GdipDeletePath", "Ptr", e.p)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2)
        DllCall("gdiplus\GdipDrawImageRectI", "Ptr", gr, "Ptr", cal, "Int", (A_Index - 1) * t, "Int", 0, "Int", t, "Int", t)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", cal)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gr)
    Enregistrer(bmp, fichier)
}

#Include "%A_ScriptDir%\widget-meteo-previsions.ahk"
#Include "%A_ScriptDir%\widget-meteo-animation.ahk"
#Include "%A_ScriptDir%\widget-meteo-lune.ahk"
#Include "%A_ScriptDir%\widget-meteo-heure.ahk"
#Include "%A_ScriptDir%\widget-meteo-styles.ahk"
#Include "%A_ScriptDir%\widget-meteo-calendrier.ahk"
#Include "%A_ScriptDir%\widget-meteo-infos.ahk"
#Include "%A_ScriptDir%\widget-meteo-ecran.ahk"
#Include "%A_ScriptDir%\widget-meteo-jours.ahk"
#Include "%A_ScriptDir%\widget-meteo-lumiere.ahk"
#Include "%A_ScriptDir%\widget-meteo-fete.ahk"
#Include "%A_ScriptDir%\widget-meteo-air.ahk"
#Include "%A_ScriptDir%\widget-meteo-climat.ahk"
#Include "%A_ScriptDir%\widget-meteo-ciel.ahk"
#Include "%A_ScriptDir%\widget-meteo-reglages.ahk"
#Include "%A_ScriptDir%\widget-meteo-marches.ahk"
#Include "%A_ScriptDir%\widget-meteo-anglais.ahk"
#Include "%A_ScriptDir%\widget-meteo-rer.ahk"
#Include "%A_ScriptDir%\widget-meteo-actu.ahk"
