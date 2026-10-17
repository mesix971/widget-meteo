# Widget météo — journal des versions

## 2.31.3 — 2026-10-17
- Stabilité : le widget avait disparu (plantage d'AutoHotkey le 16/10 à 22:47).
  Les rappels Windows (tic de la minute, surveillance des fenêtres) ne
  sont plus en mode « rapide », que la documentation d'AutoHotkey proscrit
  pour un rappel déclenché par un message.
- Nouveau `widget-meteo-veille.ahk`, lancé toutes les 5 minutes par une tâche
  planifiée : relance le widget s'il a disparu, sauf s'il a été quitté
  volontairement (fichier `arret-volontaire.txt`, effacé au démarrage).

## 2.31.2 — 2026-10-07
- Python : l'effet profondeur et les ambiances utilisent Python 3.11
  (`pyw -3.11`) au lieu de 3.10, avec les mêmes versions des modules
  (requirements.txt) ; détourage vérifié identique au pixel près.

## 2.31.1 — 2026-09-28
- Tests : « Mes jours » vérifié sur des dates fictives (2054, même calendrier
  que 2026) ; le test des transports marche aussi sur un dossier de données vierge.
- Code : la ligne de date (PoserDate) rejoint le module du calendrier.

## 2.31.0 — 2026-09-28
- Transports : la gare ou l'arrêt se choisit par son nom, dans toute
  l'Île-de-France (RER, Transilien, métro, tram, bus) : Réglages ▸ Transports ▸
  Gare ou arrêt, puis la ligne dans la liste trouvée (open data d'Île-de-France
  Mobilités, sans clé). Pastille à la couleur officielle de la ligne ; les deux
  sens prennent le nom de leur terminus (métro, tram, bus) ou de leur
  destination principale (trains), et se renomment (« Paris », « Sud ») dans
  Réglages ▸ Transports ▸ Noms des deux sens.
- Correctif : 16 réglages ajoutés en 2.28 et 2.29 (Bitcoin, indice, titres,
  phrases d'anglais, voile, pluie dans l'heure, alertes, choix des marchés, RER)
  n'étaient pas relus au démarrage : ils revenaient à leur valeur par défaut à
  chaque lancement du widget. Un test le vérifie désormais.
- Titre à la une : la description de Réglages ▸ Actus dit ce que fait le clic
  (l'article en grand).
- Publication : licence MIT, README pour les nouveaux utilisateurs.

## 2.30.0 — 2026-09-28
- Fiche d'actualité : un clic sur le titre à la une du widget ouvre cet article
  seul, en grand, au milieu de l'écran (photo, titre, chapeau), au lieu du
  tableau de bord. franceinfo : le texte complet, avec ses intertitres ; Le Monde
  et France 24 protègent leurs pages : le chapeau, puis « Lire la suite » dans le
  navigateur. ◀ ▶ (ou ← →) : les autres titres ; molette, ↑ ↓, espace :
  défiler ; Échap : fermer. Un clic sur un titre du tableau de bord ouvre aussi
  sa fiche, avec « ‹ Actus et marchés » pour y revenir.
- Les titres du widget alternent franceinfo et Le Monde (5 de chaque, un toutes
  les 5 min), avec le nom du journal en étiquette.
- Pluie : quand la pastille « Pluie jusqu'à 11 h 30 » est affichée, le résumé
  décrit la journée (« Averses éparses ce matin ») au lieu de redonner une heure
  de fin calculée heure par heure, qui pouvait la contredire (« Fin de la pluie
  vers 12 h »).
- Phrases Tatoeba : le filtre des grossièretés fonctionne (sa recherche des mots
  entiers était cassée et ne filtrait rien).

## 2.29.1 — 2026-09-28
- RER C : les départs réels s'affichent (la réponse d'Île-de-France Mobilités
  contient des champs vides que le décodage ne supportait pas) ; sens Paris / sud
  vérifié sur de vrais départs (destination, sinon « Aller » /
  « Retour » de la SNCF) ; retard en orange dès qu'il s'affiche « +2 min ».

## 2.29.0 — 2026-09-28
- Pluie dans l'heure : « Pluie dans 20 min, jusqu'à 15 h 30 », « Forte pluie
  jusqu'à… » ; seulement quand une averse arrive dans l'heure (pluie par quart
  d'heure d'Open-Meteo, 3 h à l'avance). Réglages ▸ Météo.
- Alertes marchés (notifications Windows) : le Bitcoin qui bouge de plus de 3,
  5 ou 10 % en 24 h, des seuils de prix à franchir (ex. 70 000 €, 80 000 €), les
  indices et actions suivis qui bougent de plus de 2, 3 ou 5 % pendant la séance ;
  une fois par jour et par sens ; un clic sur la notification ouvre le tableau
  de bord. Réglages ▸ Marchés.
- RER C (jeton gratuit Île-de-France Mobilités, Réglages ▸
  Transports) : les deux prochains départs vers Paris et vers le sud sur le
  widget (orange en retard, rouge supprimé), une pastille quand la ligne est
  perturbée, les 6 prochains départs et l'info trafic en tête du tableau de bord ;
  relevés toutes les 2 min (info trafic toutes les 10), rien de 1 h 30 à 4 h 30,
  pour rester sous le quota de 1 000 requêtes par jour.

## 2.28.1 — 2026-09-28
- Voile sombre léger derrière le Bitcoin, la une et la phrase (lisibles sur un
  fond d'écran chargé) ; désactivable dans Réglages ▸ Apparence.
- La phrase d'anglais en un seul bloc : « FR » et « EN » l'un sous l'autre,
  lignes rapprochées.
- Courbes plus nettes (simplifiées) ; la flèche part du bout de la courbe dans
  le sens de la variation sur 24 h, comme un vrai graphique en hausse ou en baisse.
- Bourse fermée : l'indice est grisé avec le jour de la dernière clôture
  (« −0,04 % · ven. ») ; son nom reste toujours affiché.
- « Maximum 25° (normale 19°) » : plus d'espace avant le degré, comme la grande température.

## 2.28.0 — 2026-09-27
- Marchés sur le widget : le Bitcoin avec une petite courbe des dernières 24 h
  et sa flèche (verte si ça monte, rouge si ça baisse), son prix en euros et sa
  variation, et un indice boursier au choix (CAC 40 par défaut) ; chacun
  s'affiche ou se retire dans Réglages ▸ Marchés.
- Titre à la une sur le widget : les 5 premiers titres du Monde, un nouveau
  toutes les 5 min.
- Nouvelle fenêtre « Actus et marchés » (clic sur le Bitcoin ou le titre, ou
  clic droit) : courbe détaillée (1 j, 7 j, 1 mois, 1 an, valeur sous la souris)
  de n'importe quelle ligne, cryptos, indices, actions et taux d'emprunt d'État
  choisis dans un catalogue (Réglages ▸ Marchés), titres « à la une » (Le Monde),
  « en continu » (franceinfo) et « international » (Le Monde, France 24),
  cliquables. Déplaçable, se rouvre au même endroit.
- Anglais : une phrase en français et sa traduction anglaise sur le widget, une
  nouvelle toutes les 5 min, un clic dessus donne la suivante ; niveaux mélangés,
  470 phrases intégrées et un lot de phrases Tatoeba renouvelé chaque jour
  (grossièretés filtrées), sans répétition avant d'avoir tout vu.
- Collecte à part (widget-meteo-marches.ps1) toutes les 5 min, seulement si ces
  options servent (2 min tableau de bord ouvert, 15 min en mode sobre sur
  batterie) ; sources gratuites et sans clé : CoinGecko, Yahoo Finance, BCE,
  flux RSS du Monde, de franceinfo et de France 24, Tatoeba.

## 2.27.1 — 2026-09-24
- Réglages : la fenêtre se déplace à la souris (on l'attrape par le titre ou
  n'importe quel espace vide) et se rouvre là où on l'a laissée (ramenée dans
  l'écran s'il a changé).

## 2.27.0 — 2026-09-24
- Nouvelle fenêtre « Réglages » : toutes les options rangées en huit catégories
  (Apparence, Heure, Météo, Calendrier, Alertes, Ciel, Écran et batterie,
  Position et taille), avec interrupteurs et pastilles, appliquées aussitôt. Les
  options qui dépendent d'une autre n'apparaissent qu'avec elle (zone des
  vacances, réglages du mode nuit, cases du mode sobre, options des styles…) ;
  les lignes d'état (vigilance, qualité de l'air, mode nuit, effet profondeur)
  s'y affichent et se mettent à jour ; chaque police de l'heure est montrée dans
  sa propre police. Molette pour défiler, ↑/↓ pour changer de catégorie, Échap
  pour fermer ; la dernière catégorie ouverte est retenue.
- Clic droit (widget et zone de notification) : un petit menu — Prévisions
  détaillées, Mes jours, Réglages, Actualiser, Quitter. L'ancien menu complet
  reste accessible par Maj + clic droit sur le widget.
- Mes jours : le pinceau choisi a enfin son fond gris (il restait transparent,
  seul son contour était dessiné).

## 2.26.0 — 2026-09-24
- Mes jours : cycles de travail (roulements). On peint un tour (2-2-3, 4/4, 3x8…),
  clic droit sur son 1er jour ▸ « Répéter en cycle à partir d'ici… » : le motif
  s'écrit en lettres (« TTRRTTT RRTTRRR », prérempli avec ce qui est peint), il
  se répète ensuite sans fin, sur toutes les années (29 février compris). Les
  congés et échanges posés passent devant. Changement de roulement : un nouveau
  cycle à une date (ce qui est déjà prévu après est cité, gardé ou remplacé au
  choix) ; arrêt ; reprise d'un cycle précédent au même rythme, même après un
  autre roulement (été, formation) ; départ plus tôt ; suppression (le 1er tour
  peint reste, au choix) ; « Jour 3 sur 14 du cycle » au clic droit, une
  barrette au 1er jour de chaque tour. Pendant la saisie du motif, on peut aller
  lire son planning dans une autre application sans que la fenêtre se ferme.
- Mes jours : type « non travaillé » (Repos, Congé ; case au clic droit d'un
  type). Un congé posé sur les jours de travail traverse les repos : « Congé,
  reprise ven. 9 oct. » (la date de reprise, y compris un jour de repos au milieu
  du congé), « Congé mercredi » annoncé par-dessus les repos ; glisser un congé
  saute les repos. Recliquer le type d'un jour du cycle ne le vide plus.
- Mes jours : Ctrl+Z (ou « Annuler » au clic droit) défait la dernière
  modification (et la rétablit) ; copie jours-avant-cycle.txt avant le 1er cycle ;
  clic sur le résumé : les totaux de l'année (sur 2 lignes s'il y a beaucoup de
  types) ; Maj+molette ou ↑/↓ : année ; un congé de plusieurs mois garde sa vraie
  fin ; un point de la couleur du cycle sous un jour posé qui le cache ; 12 types
  au plus ; lignes non comprises de jours.txt gardées telles quelles.

## 2.25.0 — 2026-09-24
- Clic gauche : seules l'illustration et la température ouvrent les prévisions
  (plus le lieu, le résumé, la bande, les heures, ni la date ou l'anniversaire) ;
  ailleurs, un clic ne fait rien (la main du curseur n'apparaît que sur elles).
  « Mes jours » et les confettis restent dans le menu du clic droit.
- Mes jours : nouvelle marque « Le jour en couleur » (par défaut) : seul le nom
  du jour (« Jeudi », « jeu. ») prend la couleur de son type, le reste de la date
  ne bouge pas d'un pixel ; même chose pour les 7 jours des prévisions. Type
  Repos (violet) parmi ceux du premier lancement.
- Mes jours : recliquer un congé posé revient à la semaine type (au lieu de
  vider le jour) ; un week-end sans type ne coupe plus une période (« Congé
  jusqu'au ven. 9 oct. » sur deux semaines) ; glisser vite ne saute plus de
  jours ; double-clic et pavé tactile (molette par crans) pris en compte ; boîtes
  de saisie devant la fenêtre ; noms de type en double ou « Effacer » refusés ;
  jours.txt modifié à la main : ids accentués, « #couleur » et noms de type
  acceptés, lignes ignorées notées au journal ; coche du menu Calendrier à jour.
- Corrigé : chaque ouverture des prévisions ou de Mes jours écrivait une erreur
  dans erreurs.log (paramètre « journal » qui masquait la fonction Journal) ;
  /testjours écrasait le vrai jours.txt (il travaille maintenant sur une copie).
- Corrigé : « Laisser passer les clics » : créer une zone faisait passer le
  widget devant tes fenêtres ; un double-clic rouvrait puis refermait ; un clic
  sur l'icône de notification refermait puis rouvrait les prévisions.
- Prévisions : une 3e colonne quand la 2e dépasse la hauteur de l'écran ; nuit
  des étoiles filantes toujours entière (le détail se raccourcit) ; ISS « Ce
  matin » / « Cette nuit » avant midi ; prochain changement d'heure trouvé tout
  l'été (222 jours) ; « Cette nuit, on recule d'1 h » gardé jusqu'à 3 h.
- Normale à côté du maximum : jamais au prix du maximum ; écart et records
  comparés sur les valeurs affichées ; « Sous le record de froid » juste.
- Air : valeurs datées (après minuit, celles de la veille ne passent plus pour
  celles du jour), poussières du jour annoncé, pollens du jour (sinon « hier »,
  « demain »), pas de liste de polluants quand l'air est bon.
- Anniversaires : confettis dès que le widget réapparaît (plus seulement au tic
  de minute), repère du 29/02 le 28/02 pour le tien aussi, « de Yanis » mais
  « d'Yves ».
- Collecte : la météo est écrite avant les options (plus perdue si un service
  traîne) ; hors ligne, min et max du jour recalculés ; normales : un fichier par
  lieu (3 au plus), grosse requête gardée tout de suite, 3 h d'attente après un
  échec de l'archive, clés calculées depuis le cache, datées (clim_jour).

## 2.24.0 — 2026-09-24
- Afficher ▸ Ciel ▸ Planètes visibles ce soir (désactivé par défaut) : section
  « Dans le ciel » des prévisions : « Saturne · ce soir au sud-est · 40° vers
  1 h », « Avant l'aube : Mars et Jupiter à l'est · Saturne au sud ». Calcul sur le
  PC (éléments de Standish, JPL, et précession) : 0,07° près de l'USNO.
- Afficher ▸ Ciel ▸ Étoiles filantes : les deux prochains essaims avec la nuit du
  maximum, le taux horaire, la lune et les nuages prévus ; « Géminides cette nuit »
  dans le calendrier les grandes nuits (50/h et plus, lune sous 50 %, ciel pas
  couvert). Dates calculées chaque année (Draconides 2026 : 9/10 vers 1 h 19 TU).
- Collecte : nuits (nuages moyens de 22 h à 2 h des nuits à venir).

## 2.23.0 — 2026-09-24
- Afficher ▸ Ciel ▸ Passages de la station spatiale (nouveau module
  widget-meteo-ciel.ahk), désactivé par défaut : une pastille « ISS à 21:19 · ONO →
  SSE · 42° » 2 h avant un passage visible, si le ciel n'est pas couvert (nuages
  prévus à l'heure du passage), jusqu'à sa fin (« ISS visible maintenant ») ; les
  3 prochains dans les prévisions. Hauteur minimale au choix (10, 20 ou 40°).
- Calcul sur le PC dans la collecte (-Iss) : éléments d'orbite de CelesTrak (168
  octets, aucune position envoyée, une fois par jour au plus, 6 h d'attente après
  un échec), Kepler + J2 + traînée, bornes à la seconde et maximum affiné. Écart
  constaté avec Heavens-Above : 3 s et 1° ; 2,2 s de calcul pour 4 jours, refait
  au plus toutes les 12 h. Plus rien au-delà de 5 jours sans éléments frais.

## 2.22.0 — 2026-09-24
- Afficher ▸ Normales et records (nouveau module widget-meteo-climat.ahk), trois
  cases décochées par défaut : dans les prévisions, une section « Normale du
  24 sept. : 20° / 11° · aujourd'hui 24° (+4°) », les records du jour depuis 1940
  et « Il y a un an : 12° / 10°, pluie 7 mm » ; dans le widget, « Maximum 27°
  (normale 20°) » quand l'écart atteint 3° ; une pastille « Proche du record de
  chaleur du 24 sept. (28° en 1983) » (ou de froid) quand la prévision s'en approche.
- Source : réanalyse ERA5 du point (archive Open-Meteo, sans clé), une
  reconstitution à ~25 km et non une station. La collecte (-Climat) télécharge
  1940 à l'an dernier une fois par lieu (700 Ko), puis les 400 derniers jours
  chaque semaine ; climat.txt garde normales, records et derniers jours.
- Collecte : max_jour (jour du maximum annoncé : aujourd'hui, ou demain après 17 h).

## 2.21.0 — 2026-09-24
- Vigilance ▸ Qualité de l'air (nouveau module widget-meteo-air.ahk), désactivé par
  défaut : une pastille aux couleurs officielles pendant un épisode de pollution
  déclaré (« Pic de pollution à l'ozone : procédure d'information »), ou, au choix,
  dès que l'indice ATMO de la commune (Airparif, Île-de-France) atteint « Mauvais »
  ou « Dégradé » (aujourd'hui, sinon demain, avec les polluants responsables).
- Options : sable du Sahara (modèle CAMS via Open-Meteo : « Ciel voilé de sable du
  Sahara ») et pollens (indice officiel d'Atmo France, dès « élevé » ou en alerte).
- Prévisions : section « Qualité de l'air » (indice du jour et du lendemain,
  épisodes, poussières, pollens) ; ligne d'état dans le menu.
- Collecte : -Air, -Sable, -Pollens, gardés 55 min (3 h pour les pollens) ; code
  INSEE de la commune gardé dans position.txt avec le département.

## 2.20.0 — 2026-09-24
- Calendrier ▸ Anniversaires (nouveau module widget-meteo-fete.ahk) : prénom et
  date de naissance (JJ/MM/AAAA, ou JJ/MM sans l'âge), plus le tien. La veille
  « Anniversaire de Léa demain (30 ans) », le jour J « Léa a 30 ans aujourd'hui »
  en tête du calendrier (« Joyeux anniversaire ! » pour le tien) ; les 3 prochains
  dans les prévisions ; repère rose dans « Mes jours ». Élision (« d'Anna ») et
  29 février (fêté le 28 hors année bissextile) gérés.
- Confettis le jour J : 3 s de pluie sur le widget au premier affichage visible
  de la journée (quelqu'un devant l'écran, pas la nuit, pas en économie), puis à
  chaque clic sur l'anniversaire (ou Anniversaires ▸ Voir les confettis). Dessinés
  à la volée (2,4 ms par image à 1733×1175 px, une seule image en mémoire) ;
  avec l'effet profondeur, un sur trois passe derrière le sujet du fond d'écran.

## 2.19.0 — 2026-09-24
Lumière du jour (nouveau module widget-meteo-lumiere.ahk), tout décoché par défaut :
- Afficher ▸ Durée du jour et heures d'UV : sur la ligne du soleil « 12 h 05 de
  jour · −3 min 34 » (la forme qui tient, sinon rien) ; dans les prévisions, une
  ligne de plus : lever, coucher, durée du jour, et « Indice UV 4,6 à 14 h · 3 ou
  plus de 13 h à 16 h ». Durée à la seconde (instants du lever et du coucher),
  UV heure par heure dans la même requête : aucune requête en plus.
- Calendrier ▸ Changement d'heure : dès le jeudi « Dimanche : on recule d'1 h
  (3 h → 2 h) », la veille « Cette nuit… », le jour même « Heure d'hiver depuis
  cette nuit » (règles de fuseau de Windows) ; prochain passage dans les prévisions.
- Calendrier ▸ Équinoxes et solstices : « Équinoxe d'automne aujourd'hui à
  02:05 », « Solstice d'hiver lundi à 21:50 » dès J-3 (Meeus chap. 27, calculé
  sur le PC : 1 minute près de l'USNO) ; la prochaine saison dans les prévisions.
- Vigilance ▸ UV fort : une pastille (orange, rouge ou violette selon l'indice)
  les jours où l'UV atteint 6, jusqu'à la fin des heures concernées.
- Collecte : clé lon (calculs du ciel à venir), jour_duree, uv3, uv6.

## 2.18.0 — 2026-09-24
- Clics : un clic sur la température (ou le lieu, le résumé, la bande d'infos)
  ouvre les prévisions détaillées ; un clic sur la date ouvre « Mes jours » ;
  une main apparaît au survol de ce qui se clique. En mode « Laisser passer les
  clics », la température et la date restent cliquables (petites zones
  invisibles posées dessus, clic droit = menu) et tout le reste va au bureau.
  Un simple clic sur l'icône de la zone de notification ouvre les prévisions.
- Fenêtres surgissantes : elles ne se referment plus aussitôt ouvertes depuis la
  zone de notification (fermeture au clic dans un autre programme, Échap, ou
  Alt+Tab, plus sur une simple perte d'activation) ; placées à côté, dessous ou
  dessus du widget, sinon là où elles le recouvrent le moins (elles ne se
  centrent plus sur un grand widget).
- Mes jours (nouveau module widget-meteo-jours.ahk) : types de jour avec leur
  couleur (Travail, Congé, plus ceux qu'on ajoute), semaine type et jours posés
  d'un clic ou d'un glisser dans une fenêtre du mois. La date du jour est
  soulignée (ou surlignée, au choix) à la couleur de son type ; un type annoncé
  (Congé) l'est la veille (« Congé lundi ») et pendant sa période ; les 7 jours
  des prévisions et la section Calendrier suivent. Données dans jours.txt.

## 2.17.2 — 2026-09-24
- Heures justes de part et d'autre d'un changement d'heure : Open-Meteo applique
  un seul décalage à toute sa réponse (lever du 26/10/2025 annoncé à 08:27 au
  lieu de 07:27). La collecte demande désormais des instants Unix et les
  convertit en heure locale du jour concerné (règles de Windows) : lever,
  coucher, lune, créneaux horaires et prévisions sur 7 jours. Un ancien cache
  hors ligne en heures ISO est converti de la même façon.

## 2.17.1 — 2026-09-23
Corrections issues de deux revues adverses du code des versions 2.10 à 2.17 :
- Calendrier : une date impossible dans [comptes] (31/11, 29/02 hors année
  bissextile) est ignorée et notée au journal au lieu d'empêcher le widget de
  s'afficher ; « demain » / « J-5 » ne sont jamais coupés ; menu des comptes à
  jour chaque jour ; suppression sûre même si la liste a changé entre-temps.
- Vigilance : plus de « aucune vigilance » affiché sur des données anciennes
  (flux injoignable) ; dates complètes (« hier à 16 h ») ; J et J+1 regroupés dans
  les prévisions comme dans la pastille, les plus graves d'abord ; Seine : pas de
  clignotement autour du seuil de crue.
- Heures justes de part et d'autre d'un changement d'heure (vigilance, relevés).
- Prévisions : une seule colonne quand il n'y a rien à déplacer (petit écran) ;
  mise en page recalculée quand la fenêtre se met à jour ; plus de double filet.
- Collecte : une seule à la fois (une demande pendant qu'elle tourne est
  relancée à sa fin) ; une collecte bloquée plus de 3 min est arrêtée ; horloge
  du PC reculée prise en compte ; noms et zones protégés en ligne de commande
  (antislash final, tiret initial) ; hors ligne après minuit, soleil, lune et UV
  du bon jour ; calendrier scolaire réessayé tant qu'aucune date n'est connue.
- Anti-marquage OLED : l'orbite ne se fige plus après un glisser ou un
  redimensionnement ; décalage borné à R px contre un bord ; thème calculé sans
  le décalage ; un pas par minute aussi en « aux 5 minutes » ; verre et masque
  en cache près des bords.
- Mode nuit : intensité juste après un redimensionnement ou le mode édition ;
  survol pris en compte au début d'un fondu ; rendu jamais à moitié teinté.
- Mode sobre : ambiance reportée vraiment créée au retour sur secteur (lecture des
  fins de ligne Windows) ; animation arrêtée écran éteint ou session verrouillée.
- Un argument de ligne de commande inconnu (même sans « / ») quitte sans
  démarrer un second widget.

## 2.17.0 — 2026-09-23
- Écran et batterie ▸ Mode sobre (batterie), désactivé par défaut. Écran éteint,
  session verrouillée ou widget entièrement recouvert : plus aucun redessin
  (remis à jour d'un coup à la réapparition) ; écran éteint : ni collecte ni
  changement de fond, rattrapés au rallumage. Sur batterie ou économiseur :
  animations en pause, météo toutes les 30 min (15 pendant une vigilance
  orange ou la Seine haute), et un fond d'ambiance jamais généré n'est
  préparé qu'au retour sur secteur (widget-meteo-fond.py --seulement-existante).
  Chaque point est décochable ; ligne d'état « ↳ batterie · widget caché… ».
- Tout vient des notifications de Windows (alimentation, écran, session) : aucun
  sondage. L'économiseur d'énergie est lu par notification (l'ancien indicateur
  est déprécié sous Windows 11 24H2).

## 2.16.0 — 2026-09-23
- Réveil unique par minute (invisible) : un minuteur Windows calé sur la minute
  remplace le tic d'une seconde, qui réveillait le script toutes les 10 ms
  (≈ 150 réveils par seconde, ~24 s de CPU par heure à vide). Mesuré : tics à
  hh:mm:00,05, 141 ms de CPU en 2 min démarrage compris.
- La collecte est lancée au tic quand elle est due, puis suivie jusqu'à sa fin
  (nouvelles données affichées aussitôt) ; resynchronisation après une mise en
  veille ou un changement d'heure du PC. Une animation cachée guette sa
  réapparition par les événements de fenêtres au lieu de sonder chaque seconde.
- Correction (2.14.0) : à la bascule automatique vers la nuit, le fondu vers
  l'intensité de nuit n'était pas lancé.

## 2.15.0 — 2026-09-23
- Écran et batterie ▸ Anti-marquage OLED (micro-décalage), désactivé par défaut :
  1, 2 ou 3 px. Le widget se décale de 1 px par minute sur un parcours en
  aller-retour autour de sa place (cycle de 16, 48 ou 96 min), invisible à
  l'œil. Ça étale les bords des traits sans empêcher une rémanence : le vrai
  levier contre l'usure reste l'intensité du mode nuit.
- La position mémorisée ne bouge pas : glisser, aimant au centre, centrage,
  redimensionnement et molette travaillent sur la position sans le décalage ;
  l'effet profondeur reste aligné sur le sujet (découpe du masque gardée en cache).
- Un mode de test inconnu (« /… ») quitte avec un message au lieu de démarrer
  un second widget.

## 2.14.0 — 2026-09-23
- Nouveau menu Écran et batterie ▸ Mode nuit (façon StandBy), désactivé par
  défaut : du coucher du soleil (+ 0, 30 min, 1 h ou 2 h) au lever, ou sur une
  plage horaire (22:00-07:00 par défaut), le widget baisse en fondu à 60, 40
  ou 25 % d'intensité, et en option passe en monochrome rouge sombre ou ambre
  (heure, textes, illustration, rangée ; l'effet profondeur continue ; les
  pastilles de vigilance gardent leurs vraies couleurs).
- La nuit, l'animation s'arrête (icône fixe, teintée) ; pleine intensité au
  survol pendant 10 s (désactivable) et pendant un redimensionnement ; la
  fenêtre des prévisions prend la teinte sans être atténuée. « Essayer pendant
  10 secondes » ; ligne d'état « ↳ ce soir de 20:46 à 07:39 ».
- Aucun coût permanent : l'intensité passe par l'alpha global de la fenêtre
  (fondu sans redessin), la teinte par la couleur de remplissage.


## 2.12.0 — 2026-09-23
- Menu Afficher ▸ Vigilance : la vigilance Météo-France du département de la
  position (flux MeteoAlarm, sans clé), dès le jaune ou orange et rouge
  seulement. Rien tant qu'il n'y a rien ; pendant une vigilance, une pastille aux
  couleurs officielles sous le widget (« Vigilance orange orages jusqu'à
  minuit », enchaînement J / J+1 : « jusqu'à demain 6 h »), qui s'efface seule
  à l'heure de fin, même hors ligne. État dans le menu (« ↳ Val-de-Marne :
  aucune vigilance »), liens vers la carte Météo-France et MeteoAlarm.
- Option « Seine haute (Alfortville) » (Hub'Eau) : pastille dès 1,50 m, « Crue de
  la Seine » dès 2,50 m, flèche de tendance sur 6 h.
- Prévisions détaillées : vigilances en cours et à venir (« à partir de demain
  6 h »), avec l'attribution Météo-France / meteoalarm.org ; hauteur de la Seine.
- Collecte : département mis en cache avec la position ; Seine relevée une fois
  par heure tant que l'eau est basse ; en cas d'échec, les dernières données sont
  gardées. Rien n'est demandé quand les options sont décochées.

## 2.11.0 — 2026-09-23
- Menu Afficher ▸ Deuxième ville : on cherche la ville par son nom (géocodage
  Open-Meteo), puis on la choisit dans une liste avec région, pays, heure
  locale et population (jamais de choix automatique : « Saint-Denis » est
  d'abord à La Réunion).
- « Dans le widget » : « Pointe-à-Pitre 04:10 · 30° » avec une mini-illustration,
  sous le lieu en Android et Épuré, sinon dans une bande sous le widget (qui
  grandit d'une ligne). L'heure est toujours juste, même hors ligne (fuseau
  calculé par l'ICU de Windows, heure d'été comprise) ; la température
  disparaît après 6 h sans données.
- « Dans les prévisions détaillées » : une ligne sous l'en-tête (écart horaire,
  temps, min/max, lever et coucher là-bas). Quand la fenêtre ne tient plus
  dans la hauteur de l'écran, les sections en option (2e ville, lune,
  calendrier) passent dans une 2e colonne au lieu d'être coupées.
- Collecte : une requête légère de plus toutes les 15 min, seulement si l'option
  est cochée ; en cas d'échec, les dernières données de la ville sont gardées.

## 2.10.0 — 2026-09-23
- Menu Afficher ▸ Calendrier (tout décoché par défaut) : numéro de semaine,
  jours fériés (calculés sur place, identiques à calendrier.api.gouv.fr), vacances
  scolaires (zone A, B ou C, calendrier officiel data.education.gouv.fr relu une
  fois par semaine), comptes à rebours (date unique ou chaque année, 10 au plus).
- Rien n'apparaît que quand c'est utile : un férié la veille (un lundi dès le
  vendredi), des vacances dans les 7 jours, en cours ou la veille de la rentrée.
  Android : une ligne sous le lieu (sautée si le résumé météo a besoin de la
  place) ; iPhone, En toutes lettres, Analogique : dans la ligne de la date.
- Prévisions détaillées : bloc « Calendrier » (semaine, prochain férié, vacances,
  3 comptes à rebours) ; dans les 7 jours, férié en orange et trait bleu les
  jours de vacances. Option « Aussi dans les prévisions détaillées ».

## 2.9.0 — 2026-09-23
- Nouveau style « En toutes lettres » : « Il est dix heures moins le quart »,
  « midi et demi », « minuit une », en grand, sur 2 ou 3 lignes selon la
  largeur ; à la minute près ou arrondie aux 5 minutes (avec, en option,
  4 points pour les minutes en plus), et « du matin / de l'après-midi / du
  soir » en option. La taille des lettres ne bouge jamais d'une minute à
  l'autre (toutes les phrases de la journée tiennent).
- Nouveau style « Analogique » : cadran épuré à aiguilles (chiffres 12, 3, 6
  et 9 en option), météo à côté du cadran ou dessous.
- Les deux suivent les couleurs, la police et le rendu de l'heure, la taille
  et la largeur libres, et l'effet profondeur.
- En « Arrondie aux 5 minutes », le widget ne se redessine que quand l'image
  change (4 redessins sur 5 évités).

## 2.8.0 — 2026-09-23
- Menu Heure ▸ Rendu : Plein, Contour (chiffres évidés, sans coutures même
  avec Bahnschrift ou Cascadia), Dégradé (de la couleur d'accent vers la
  teinte du fond d'écran), Verre dépoli (le fond d'écran flouté à travers les
  chiffres, avec un liseré clair). L'effet profondeur marche avec les quatre.
- widget-meteo-fond.py --verre : fond flouté en demi-résolution (verre.png),
  produit seulement quand le rendu Verre est choisi.

## 2.7.0 — 2026-09-23
- Menu Heure ▸ Police : la police de l'heure devient indépendante du style
  (Segoe UI Variable fine à grasse, Bahnschrift dont les étroites, Cascadia
  Mono, manuscrites Segoe Print, Ink Free, Segoe Script, et d'autres). Les
  chiffres gardent la même hauteur et des cases fixes ; une police absente du
  PC est grisée. Option « Même police pour la température ».
- Le texte est rempli en « enroulement » : plus de trous dans les polices
  variables (Bahnschrift, Cascadia) ni dans le « ç ».

## 2.6.0 — 2026-09-23
- Option « Phase réelle de la lune » (Afficher ▸ Lune) : la nuit, la lune des
  illustrations prend sa vraie forme du jour (croissant, quartier, gibbeuse,
  pleine), avec une lumière cendrée discrète, partout (widget, prochaines
  heures, prévisions, animation). Calcul local (Meeus), à 2 min près des
  heures officielles de l'IMCCE.
- Option « Lever et coucher de la lune » : dans la rangée des heures, ou sur
  la ligne du soleil. La fenêtre des prévisions gagne un bloc lune (phase,
  prochaine phase principale, éclairement, lever et coucher).
- Collecte : lever et coucher de la lune (Open-Meteo), latitude (hémisphère).
- Modes de test : heure et date imposables (heure=, date=), table d'options
  unique (une option inconnue est signalée), planche /lunes.

## 2.5.0 — 2026-09-23
- Taille libre : tirer un coin du widget change sa taille en continu, de 60 à
  200 % (aimants sur 80, 100, 125, 150 et 200 %, Maj pour les ignorer). Le
  coin opposé reste en place ; un widget centré le reste.
- Largeur libre : tirer le côté gauche ou droit élargit ou rétrécit le widget
  et remet le contenu en page (résumé sur plus ou moins de lignes, de 5 à 10
  créneaux dans « Prochaines heures »). La collecte fournit désormais 12 heures.
- Ctrl+molette (ou pincement du pavé tactile) sur le widget : ±5 % par cran.
- Pendant le geste : aperçu allégé qui suit le curseur, cadre et poignées,
  bulle « 137 % » ; clic droit ou Échap pour annuler.
- Menu Taille : agrandir / réduire, préréglages, largeur d'origine, taille
  actuelle, et « Redimensionner à la souris… » (cadre et poignées visibles),
  indispensable quand le widget est verrouillé ou laisse passer les clics.
- « Verrouiller la position et la taille » bloque aussi le redimensionnement.
- Un réglage invalide dans reglages.ini n'empêche plus le démarrage.
- Avec un arrière-plan, les coins arrondis se saisissent aussi.

## 2.4.0 — 2026-09-23
- Rien d'imposé à l'écran : la rangée « Prochaines heures » et le lever /
  coucher du soleil deviennent des options, désactivées par défaut (menu
  Afficher). Le soleil s'insère dans la rangée, ou a sa propre ligne si la
  rangée est masquée.
- Correctif : des heures en léger retard (collecte de la veille ou de quelques
  minutes) ne sont plus prises pour celles du lendemain dans la rangée.

## 2.3.0 — 2026-09-23
- Rangée « Prochaines heures » sous le résumé : 6 créneaux (heure, ciel,
  température, probabilité de pluie dès 30 %), avec le lever ou le coucher du
  soleil inséré à sa place. Désactivable dans le menu.
- Un clic sur le widget ouvre les prévisions détaillées : conditions actuelles,
  courbe des températures et probabilité de pluie sur 24 h, 7 jours, vent,
  humidité, indice UV, lever et coucher du soleil. Se ferme d'un clic, avec
  Échap ou en cliquant ailleurs. Aussi dans le menu.
- Couleur « Selon le soleil » : texte sombre le jour, blanc la nuit.
- Fond d'écran selon la météo et l'heure (option) : variantes de ta photo
  (crépuscule doré, nuit, pluie, neige, orage, brouillard), le sujet détouré
  restant devant la pluie et la brume. Chaque variante est préparée une fois.
- Animations légères (option, désactivée par défaut) : nuages qui glissent,
  pluie et neige qui tombent, soleil qui rayonne, éclairs. En pause quand
  l'illustration est cachée ou en mode économie de batterie.
- « Verrouiller la position » bloque seulement le déplacement ; « Laisser
  passer les clics » (menu Position) rend le widget inerte, comme avant.
- Collecte : prévisions 7 jours, vent, humidité, UV, lever et coucher du soleil
  (previsions.txt).
- Correctif : faire glisser le widget échouait depuis la 2.2.0 (écran de
  référence de l'aimantation non transmis).

## 2.2.0 — 2026-09-23
- Centrage : menu Position (centrer horizontalement, au milieu de l'écran) et
  aimantation au centre de l'écran pendant qu'on fait glisser le widget.
- Ligne d'état sous « Effet profondeur » : actif, en cours, à placer sur le
  sujet, modèle absent (téléchargeable depuis le menu), détourage à relancer.
- Journal de diagnostic (journal.log) ; l'analyse du fond note chaque passage.
- Correctif : le modèle de détourage avait été installé dans le dossier
  virtualisé de l'application Claude au lieu du vrai %LOCALAPPDATA%.

## 2.1.0 — 2026-09-23
- Thèmes, au clic droit : style Android, iPhone (date en haut, heure géante)
  ou Épuré (heure fine) ; couleur blanche, sombre, automatique selon le fond
  d'écran, ou assortie au fond d'écran (teinte extraite, comme sur iOS).
- Effet profondeur façon iPhone : l'heure passe derrière le sujet du fond
  d'écran. Le sujet est détouré en local par le modèle BiRefNet
  (widget-meteo-fond.py), une fois à chaque changement de fond d'écran.

## 2.0.2 — 2026-09-23
- Hors ligne, le résumé recalculé part de la prévision de l'heure en cours et
  non plus de la météo de la dernière collecte (plus de « Fin de la pluie dans
  l'heure » affiché des heures durant).
- Ombre vraiment floue dans les deux sens (le flou GDI+ n'agissait qu'à
  l'horizontale).
- Nom de ville : nouvel essai de géocodage 15 min après un échec (et non 30).

## 2.0.1 — 2026-09-23
- Une erreur imprévue est notée dans `%LOCALAPPDATA%\WidgetMeteo\erreurs.log`
  au lieu d'ouvrir une boîte de dialogue qui pouvait arrêter le widget.

## 2.0.0 — 2026-09-22
- Nouveau look façon widget météo Android : température et lieu à gauche, résumé
  (« Généralement ensoleillé demain. Maximum 26 ° »), illustration, date et heure
  à droite, texte posé sur le fond d'écran avec une ombre douce.
- 19 illustrations qui suivent la météo du moment, de jour comme de nuit.
- Résumé calculé heure par heure (pluie en cours ou imminente, sinon tendance
  d'aujourd'hui ou de demain), et non plus sur le code météo quotidien.
- Déplacement direct à la souris ; clic droit sur le widget pour le menu
  (taille, fond, verrouillage, retour en haut à droite).

## 1.0.0 — 2026-09-22
- Première version : heure, date et météo sur une carte translucide, position
  détectée par le Wi-Fi, déplacement via le menu de la zone de notification.
