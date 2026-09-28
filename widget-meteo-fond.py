# -*- coding: utf-8 -*-
"""Analyse le fond d'écran pour widget-meteo.ahk.

Produit dans %LOCALAPPDATA%\\WidgetMeteo\\fond\\ :
  - masque.png    : le sujet du fond d'écran (personne, objet…), détouré par
                    le modèle BiRefNet et aligné pixel pour pixel sur l'écran.
                    Rouge = sujet ; vert = sujet élargi (sert à retirer
                    l'ombre de l'heure autour du sujet). C'est ce qui permet
                    l'effet « profondeur » de l'iPhone : l'heure passe derrière.
  - luminance.png : l'écran en petit et en niveaux de gris, pour choisir
                    automatiquement un texte clair ou foncé.
  - fond.txt      : empreinte du fond analysé et teinte assortie pour le
                    thème « Couleurs du fond d'écran ».
  - verre.png     : (--verre) le fond flouté en demi-résolution, alpha = 255 −
                    sujet, pour le rendu « Verre dépoli » de l'heure.

Usage : pyw -3.10 widget-meteo-fond.py <largeur_ecran> <hauteur_ecran> [--sans-masque] [--verre]
        pyw -3.10 widget-meteo-fond.py <largeur_ecran> <hauteur_ecran> --ambiance <phase-météo> [--seulement-existante]
Le détourage (une dizaine de secondes) n'est refait que si le fond change.
Le mode --ambiance pose une variante de la photo (nuit-pluie, crepuscule-clair…,
ou jour-clair pour la photo d'origine) : voir ambiance() plus bas. Avec
--seulement-existante (mode sobre du widget, sur batterie), une variante jamais
générée n'est pas créée : fond\\ambiance.txt le note (etat=a_creer) et le script
sort avec le code 3 ; elle sera créée au retour sur secteur.
"""
import colorsys, os, sys, time, traceback, winreg

DOSSIER = os.path.join(os.environ["LOCALAPPDATA"], "WidgetMeteo")
SORTIE = os.path.join(DOSSIER, "fond")
MODELE = os.path.join(DOSSIER, "modeles", "BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx")
TRANSCODE = os.path.join(os.environ["APPDATA"], "Microsoft", "Windows", "Themes", "TranscodedWallpaper")
ELARGISSEMENT = 20        # px : marge autour du sujet où l'ombre de l'heure est retirée
REDUCTION_LUM = 16        # la carte de luminosité est 16 fois plus petite que l'écran
VERRE_REDUCTION = 2       # verre.png : demi-résolution (le widget l'agrandit)
VERRE_FLOU = 0.0125       # flou du verre : σ = 1,25 % de la hauteur d'écran


def journal(msg):
    os.makedirs(SORTIE, exist_ok=True)
    with open(os.path.join(SORTIE, "fond.log"), "a", encoding="utf-8") as f:
        f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")


def ecrire_atomique(chemin, ecrire):
    tmp = chemin + ".tmp"
    ecrire(tmp)
    os.replace(tmp, chemin)


def reglages_fond():
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\Desktop") as k:
        def lire(nom, defaut):
            try:
                return winreg.QueryValueEx(k, nom)[0]
            except OSError:
                return defaut
        return int(lire("WallpaperStyle", "10") or 10), int(lire("TileWallpaper", "0") or 0)


def empreinte(chemin):
    """Taille + date de modification locale : le même format que calcule le widget
    (FileGetSize "-" FileGetTime), pour savoir si le fond a changé depuis l'analyse."""
    st = os.stat(chemin)
    return f"{st.st_size}-{time.strftime('%Y%m%d%H%M%S', time.localtime(st.st_mtime))}"


def vers_ecran(img, largeur, hauteur, style, mosaique, fond_rgb=(0, 0, 0), reechantillonnage=None):
    """Place une image comme Windows place le fond d'écran (même cadrage)."""
    from PIL import Image
    r = reechantillonnage or Image.Resampling.LANCZOS
    iw, ih = img.size
    mode = img.mode
    vide = 0 if mode == "L" else fond_rgb
    if style == 2:                                   # Étirer
        return img.resize((largeur, hauteur), r)
    if style == 6:                                   # Ajuster : image entière, bandes autour
        e = min(largeur / iw, hauteur / ih)
        im = img.resize((max(1, round(iw * e)), max(1, round(ih * e))), r)
        out = Image.new(mode, (largeur, hauteur), vide)
        out.paste(im, ((largeur - im.width) // 2, (hauteur - im.height) // 2))
        return out
    if style == 0 and not mosaique:                  # Centrer, sans mise à l'échelle
        out = Image.new(mode, (largeur, hauteur), vide)
        out.paste(img, ((largeur - iw) // 2, (hauteur - ih) // 2))
        return out
    # Remplir (10), Étendre (22), Mosaïque : image agrandie jusqu'à couvrir l'écran, centrée
    e = max(largeur / iw, hauteur / ih)
    sw, sh = max(largeur, round(iw * e)), max(hauteur, round(ih * e))
    im = img.resize((sw, sh), r)
    x, y = (sw - largeur) // 2, (sh - hauteur) // 2
    return im.crop((x, y, x + largeur, y + hauteur))


def detourer(img):
    """Masque du sujet (0-255), à la taille de l'image, via BiRefNet (onnxruntime, processeur)."""
    import numpy as np
    import onnxruntime as ort
    from PIL import Image
    s = ort.InferenceSession(MODELE, providers=["CPUExecutionProvider"])
    x = np.asarray(img.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS), dtype=np.float32)
    x = x / max(float(x.max()), 1e-6)
    x = (x - np.array([0.485, 0.456, 0.406], np.float32)) / np.array([0.229, 0.224, 0.225], np.float32)
    sortie = s.run(None, {s.get_inputs()[0].name: x.transpose(2, 0, 1)[None].astype(np.float32)})[0][0, 0]
    p = 1 / (1 + np.exp(-sortie))
    p = (p - p.min()) / max(float(p.max() - p.min()), 1e-6)
    p[p < 0.04] = 0                                   # pas de voile parasite sur le décor
    return Image.fromarray((p * 255).astype(np.uint8), "L").resize(img.size, Image.Resampling.LANCZOS)


def ecrire_verre(ecran, sujet_l):
    """Fond flouté pour le rendu « Verre dépoli » : flou calculé au quart
    (même rendu, bien plus rapide), image en demi-résolution, alpha = 255 −
    sujet (le sujet reste devant l'heure en verre, comme l'effet profondeur)."""
    import cv2
    import numpy as np
    from PIL import Image
    w, h = ecran.size
    a = np.asarray(ecran.convert("RGB"))
    petit = cv2.resize(a, (max(1, w // 4), max(1, h // 4)), interpolation=cv2.INTER_AREA)
    petit = cv2.GaussianBlur(petit, (0, 0), VERRE_FLOU * h / 4)
    dw, dh = max(1, w // VERRE_REDUCTION), max(1, h // VERRE_REDUCTION)
    demi = cv2.resize(petit, (dw, dh), interpolation=cv2.INTER_LINEAR)
    if sujet_l is not None:
        alpha = 255 - cv2.resize(np.asarray(sujet_l.convert("L")), (dw, dh), interpolation=cv2.INTER_AREA)
    else:
        alpha = np.full((dh, dw), 255, np.uint8)
    img = Image.fromarray(np.dstack([demi, alpha]).astype(np.uint8), "RGBA")
    ecrire_atomique(os.path.join(SORTIE, "verre.png"), lambda chemin: img.save(chemin, "PNG", compress_level=6))


def teinte(img_ecran):
    """Couleur marquante du fond, éclaircie pour rester lisible en texte (façon iOS)."""
    import numpy as np
    import cv2
    petit = np.asarray(img_ecran.convert("RGB").resize((200, 125)), dtype=np.float32).reshape(-1, 3)
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 1.0)
    cv2.setRNGSeed(7)
    _, etiq, centres = cv2.kmeans(petit, 6, None, crit, 4, cv2.KMEANS_PP_CENTERS)
    parts = np.bincount(etiq.ravel(), minlength=6) / len(etiq)
    meilleur, score_max = None, -1
    for c, part in zip(centres, parts):
        h, l, s = colorsys.rgb_to_hls(*(c / 255))
        v = max(c) / 255
        if v < 0.18 or l > 0.92:                     # ni le noir du décor, ni un blanc brûlé
            continue
        score = s * (part ** 0.5)
        if score > score_max:
            meilleur, score_max = (h, s), score
    h, s = meilleur if meilleur else (0.55, 0.3)
    r, g, b = colorsys.hls_to_rgb(h, 0.80, min(max(s, 0.35), 0.65))
    return "%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


# ---------------------------------------------------------------- ambiances
# « Fond d'écran selon la météo et l'heure » : des variantes de la photo de
# l'utilisateur (crépuscule doré, nuit, pluie, neige, orage, brouillard),
# générées une fois et gardées dans AMBIANCES\<photo>\. Le sujet détouré sert
# à placer pluie, neige et brume DERRIÈRE lui, comme l'heure du widget.
AMBIANCES = os.path.join(DOSSIER, "ambiances")


def lire_cles(chemin):
    d = {}
    if os.path.exists(chemin):
        with open(chemin, encoding="utf-8") as f:
            for ligne in f:
                if "=" in ligne:
                    k, v = ligne.rstrip("\n").split("=", 1)
                    d[k] = v
    return d


def fond_registre():
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\Desktop") as k:
        try:
            return winreg.QueryValueEx(k, "WallPaper")[0]
        except OSError:
            return ""


def base_courante():
    """La photo d'origine du fond d'écran actuel, et son dossier d'ambiances.
    Si le fond affiché est déjà une de nos variantes, on remonte à sa photo."""
    import hashlib
    chemin = fond_registre()
    racine = os.path.normcase(os.path.abspath(AMBIANCES)) + os.sep
    if chemin and os.path.normcase(os.path.abspath(chemin)).startswith(racine):
        dossier = os.path.dirname(os.path.abspath(chemin))
        b = lire_cles(os.path.join(dossier, "base.txt"))
        return {"chemin": b.get("chemin", ""), "dossier": dossier, "variante": True,
                "style": int(b.get("style", "10")), "mosaique": int(b.get("mosaique", "0"))}
    if not chemin or not os.path.exists(chemin):
        return None                                  # diaporama, Windows à la une, couleur unie…
    st = os.stat(chemin)
    ident = hashlib.sha1(f"{os.path.normcase(chemin)}|{st.st_size}|{int(st.st_mtime)}".encode("utf-8")).hexdigest()[:12]
    dossier = os.path.join(AMBIANCES, ident)
    os.makedirs(dossier, exist_ok=True)
    style, mosaique = reglages_fond()
    f = os.path.join(dossier, "base.txt")
    if not os.path.exists(f):
        with open(f, "w", encoding="utf-8") as fh:
            fh.write(f"chemin={chemin}\nstyle={style}\nmosaique={mosaique}\n")
    return {"chemin": chemin, "dossier": dossier, "variante": False, "style": style, "mosaique": mosaique}


def masque_rgb(masque_l):
    """Masque du sujet (L) -> image R = sujet, G = sujet élargi (format du widget)."""
    import cv2
    import numpy as np
    from PIL import Image
    a = np.asarray(masque_l)
    noyau = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * ELARGISSEMENT + 1, 2 * ELARGISSEMENT + 1))
    return Image.fromarray(np.dstack([a, cv2.dilate(a, noyau), np.zeros_like(a)]), "RGB")


def creer_variante(ecran, sujet, phase, meteo, graine):
    """Une ambiance à partir de la photo à la taille de l'écran (PIL RGB) et du
    sujet détouré (PIL L, 255 = sujet). phase : jour / crepuscule / nuit ;
    meteo : clair / pluie / neige / orage / brouillard."""
    import cv2
    import numpy as np
    from PIL import Image
    rng = np.random.default_rng(graine)
    a = np.asarray(ecran, dtype=np.float32) / 255.0
    h, w = a.shape[:2]
    s = (np.asarray(sujet, dtype=np.float32) / 255.0)[..., None] if sujet is not None else np.zeros((h, w, 1), np.float32)
    b = 1.0 - s                                            # le décor, derrière le sujet
    lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)

    def desaturer(x, k):
        g = (x @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
        return x * (1 - k) + g * k

    def lueur(couleur, force, rayon):
        """Halo radial centré sur la zone la plus lumineuse du décor (source de lumière)."""
        petit = cv2.GaussianBlur(cv2.resize(lum * b[..., 0], (w // 16, h // 16)), (0, 0), 6)
        cy, cx = np.unravel_index(np.argmax(petit), petit.shape)
        cy, cx = cy * 16 + 8, cx * 16 + 8
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (rayon * max(w, h))
        return np.exp(-d * d)[..., None] * np.array(couleur, np.float32) * force

    # ---- moment de la journée
    if phase == "crepuscule":
        # lumière dorée rasante : tons chauds, ombres légèrement pourpres, halo orangé
        a = desaturer(a, 0.10) * np.array([1.12, 0.93, 0.74], np.float32)
        a = a + (1 - a) * lueur((1.0, 0.42, 0.14), 0.55, 0.45) * (b + 0.30 * s)   # « écran » : pas de blanc brûlé
        ombres = np.clip(1 - lum * 2.5, 0, 1)[..., None]
        a = a + ombres * np.array([0.05, 0.0, 0.04], np.float32)
        a = (a - 0.5) * 1.06 + 0.5
    elif phase == "nuit":
        a = desaturer(a, 0.30) * np.array([0.72, 0.84, 1.02], np.float32)
        a = a * (0.46 * b + 0.62 * s)                        # le sujet reste un peu éclairé
        a = a + lueur((0.55, 0.68, 0.95), 0.10, 0.35) * b    # clair de lune
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        r2 = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2
        a = a * (1 - 0.30 * np.clip(r2, 0, 1.5))[..., None]  # vignette

    # ---- météo
    def couche_traits(n, lmin, lmax, angle, ep, alpha):
        c = np.zeros((h, w), np.float32)
        xs, ys = rng.uniform(-0.1 * w, 1.1 * w, n), rng.uniform(-0.1 * h, 1.0 * h, n)
        ls, al = rng.uniform(lmin, lmax, n), rng.uniform(alpha * 0.5, alpha, n)
        dx, dy = np.sin(np.radians(angle)), np.cos(np.radians(angle))
        for x, y, l, v in zip(xs, ys, ls, al):
            cv2.line(c, (int(x), int(y)), (int(x + dx * l), int(y + dy * l)), float(v), ep, cv2.LINE_AA)
        return cv2.GaussianBlur(c, (0, 0), 1.2)[..., None]

    def pluie(densite, clarte):
        k = max(w, h) / 3840
        t = couche_traits(int(w * h / densite), 40 * k, 120 * k, 12, max(1, int(2 * k)), 0.55)
        return t * b, np.array([0.82, 0.88, 0.95], np.float32) * clarte

    if meteo == "pluie":
        a = desaturer(a, 0.30) * np.array([0.92, 0.97, 1.04], np.float32) * 0.86
        t, coul = pluie(2600, 0.95 if phase != "nuit" else 0.55)
        a = a * (1 - t) + coul * t
    elif meteo == "orage":
        a = desaturer(a, 0.25) * np.array([0.86, 0.86, 1.06], np.float32) * 0.72
        a = (a - 0.5) * 1.12 + 0.5
        # éclair lointain : un tracé en zigzag dans le ciel, avec son halo
        k = max(w, h) / 3840
        cx = w * (0.82 if rng.random() < 0.5 else 0.12)
        pts, x, y = [], cx, 0.0
        while y < h * 0.42:
            pts.append((int(x), int(y)))
            x += rng.normal(0, 45 * k)
            y += rng.uniform(40, 90) * k
        eclair = np.zeros((h, w), np.float32)
        cv2.polylines(eclair, [np.array(pts, np.int32)], False, 1.0, max(2, int(4 * k)), cv2.LINE_AA)
        halo = cv2.GaussianBlur(eclair, (0, 0), 40 * k) * 6 + cv2.GaussianBlur(eclair, (0, 0), 4 * k)
        a = a + (np.clip(halo, 0, 1)[..., None] * np.array([0.75, 0.80, 1.0], np.float32)) * b
        t, coul = pluie(1800, 0.7)
        a = a * (1 - t) + coul * t
    elif meteo == "neige":
        a = desaturer(a, 0.20) * np.array([0.97, 1.0, 1.06], np.float32) * 0.95 + 0.04
        k = max(w, h) / 3840
        # trois plans de flocons : fins et nets au loin, moyens et doux, gros et flous devant
        c = np.zeros((h, w), np.float32)
        for n, rmin, rmax, flou, amin in ((int(w * h / 3000), 1.5, 3.5, 0.8, 0.55),
                                           (int(w * h / 12000), 4.0, 8.0, 2.5, 0.60),
                                           (int(w * h / 90000), 10.0, 18.0, 6.0, 0.45)):
            plan = np.zeros((h, w), np.float32)
            for x, y, r, v in zip(rng.uniform(0, w, n), rng.uniform(0, h, n), rng.uniform(rmin, rmax, n) * k, rng.uniform(amin, 1.0, n)):
                cv2.circle(plan, (int(x), int(y)), max(1, int(r)), float(v), -1, cv2.LINE_AA)
            c = np.maximum(c, cv2.GaussianBlur(plan, (0, 0), flou * k))
        c = c[..., None] * (b + 0.25 * s)                  # surtout derrière le sujet
        a = a * (1 - c) + np.float32(0.97) * c
    elif meteo == "brouillard":
        k = max(w, h) / 3840
        # voile doux : bancs de brume très étalés, plus denses vers le bas
        # (flou calculé à 1/8 de la taille puis agrandi : même rendu, 50 fois plus rapide)
        bruit = cv2.resize(rng.random((h // 320 + 3, w // 320 + 3)).astype(np.float32), (w // 8, h // 8), interpolation=cv2.INTER_CUBIC)
        bruit = cv2.resize(cv2.GaussianBlur(bruit, (0, 0), 15 * k), (w, h), interpolation=cv2.INTER_CUBIC)
        bruit = (bruit - bruit.min()) / max(float(bruit.max() - bruit.min()), 1e-6)
        yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
        f = np.clip(0.22 + 0.30 * yy + 0.14 * (bruit - 0.5), 0, 0.75)[..., None]
        f = f * (b + 0.45 * s)
        brume = np.array([0.74, 0.78, 0.80], np.float32) * (0.45 if phase == "nuit" else 1.0)
        a = a * (1 - f) + brume * f

    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def appliquer_fond(chemin, style, mosaique):
    """Pose le fond d'écran (même effet que Paramètres > Personnalisation)."""
    import ctypes
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\Desktop", 0, winreg.KEY_SET_VALUE) as k:
        winreg.SetValueEx(k, "WallpaperStyle", 0, winreg.REG_SZ, str(style))
        winreg.SetValueEx(k, "TileWallpaper", 0, winreg.REG_SZ, str(mosaique))
    if not ctypes.windll.user32.SystemParametersInfoW(20, 0, chemin, 3):   # SPI_SETDESKWALLPAPER, mise à jour + diffusion
        raise OSError("SystemParametersInfo a refusé le fond " + chemin)


def masque_de_base(b, img_base, largeur, hauteur):
    """Sujet détouré de la photo d'origine, à la taille de l'écran (calculé une fois)."""
    from PIL import Image
    f = os.path.join(b["dossier"], f"masque-{largeur}x{hauteur}.png")
    if os.path.exists(f):
        with Image.open(f) as im:
            return im.convert("RGB").getchannel("R")
    if not os.path.exists(MODELE):
        return None
    m = vers_ecran(detourer(img_base), largeur, hauteur, b["style"], b["mosaique"])
    ecrire_atomique(f, lambda p: masque_rgb(m).save(p, "PNG"))
    return m


def noter_ambiance(nom, etat):
    """fond\\ambiance.txt : dernière ambiance demandée et ce qu'elle est devenue (posee, a_creer)."""
    texte = f"nom={nom}\netat={etat}\ndate={int(time.time())}\n"
    def ecrire(p):
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(texte)
    os.makedirs(SORTIE, exist_ok=True)
    ecrire_atomique(os.path.join(SORTIE, "ambiance.txt"), ecrire)


def ambiance(nom, largeur, hauteur, seulement_existante=False):
    """Pose l'ambiance « phase-météo » (ex. nuit-pluie), en la générant si besoin
    (sauf « seulement_existante » : génération différée, code de sortie 3)."""
    import zlib
    from PIL import Image, ImageOps
    b = base_courante()
    if b is None or not b["chemin"] or not os.path.exists(b["chemin"]):
        raise RuntimeError("fond d'écran d'origine introuvable (diaporama ou image déplacée ?)")
    if nom in ("origine", "jour-clair"):
        appliquer_fond(b["chemin"], b["style"], b["mosaique"])
        journal(f"ambiance {nom} : photo d'origine remise")
        noter_ambiance(nom, "posee")
        return
    phase, _, meteo = nom.partition("-")
    if phase not in ("jour", "crepuscule", "nuit") or meteo not in ("clair", "pluie", "orage", "neige", "brouillard"):
        raise ValueError("ambiance inconnue : " + nom)
    cible = os.path.join(b["dossier"], f"{nom}-{largeur}x{hauteur}.jpg")
    if not os.path.exists(cible) and seulement_existante:
        noter_ambiance(nom, "a_creer")
        journal(f"ambiance {nom} : pas encore créée, reportée (mode sobre, sur batterie)")
        sys.exit(3)                              # SystemExit traverse le « except Exception » de __main__
    if not os.path.exists(cible):
        t0 = time.time()
        base = ImageOps.exif_transpose(Image.open(b["chemin"])).convert("RGB")
        ecran = vers_ecran(base, largeur, hauteur, b["style"], b["mosaique"])
        sujet = masque_de_base(b, base, largeur, hauteur)
        img = creer_variante(ecran, sujet, phase, meteo, zlib.crc32(nom.encode()))
        ecrire_atomique(cible, lambda p: img.save(p, "JPEG", quality=92))
        journal(f"ambiance {nom} créée en {time.time() - t0:.1f} s")
    appliquer_fond(cible, 10, 0)
    journal(f"ambiance {nom} posée")
    noter_ambiance(nom, "posee")


def main():
    from PIL import Image, ImageOps
    largeur, hauteur = int(sys.argv[1]), int(sys.argv[2])
    if "--ambiance" in sys.argv:
        ambiance(sys.argv[sys.argv.index("--ambiance") + 1], largeur, hauteur, "--seulement-existante" in sys.argv)
        return
    avec_masque = "--sans-masque" not in sys.argv
    style, mosaique = reglages_fond()
    os.makedirs(SORTIE, exist_ok=True)
    t0 = time.time()
    journal(f"analyse lancée : écran {largeur}x{hauteur}, détourage {'oui' if avec_masque else 'non'}")

    img = ImageOps.exif_transpose(Image.open(TRANSCODE)).convert("RGB")
    ecran = vers_ecran(img, largeur, hauteur, style, mosaique)

    # luminosité : petite carte en niveaux de gris
    lum = ecran.convert("L").resize((max(1, largeur // REDUCTION_LUM), max(1, hauteur // REDUCTION_LUM)), Image.Resampling.BOX)
    ecrire_atomique(os.path.join(SORTIE, "luminance.png"), lambda p: lum.save(p, "PNG"))

    # Une ambiance, ou une photo déjà détourée : on reprend le sujet de la photo
    # d'origine (même cadrage) au lieu de relancer le modèle.
    try:
        b = base_courante()
    except Exception:
        b = None
    connu = os.path.join(b["dossier"], f"masque-{largeur}x{hauteur}.png") if b else ""
    masque_ok, erreur, sujet = 0, "", None
    if avec_masque and connu and os.path.exists(connu):
        import shutil
        shutil.copyfile(connu, os.path.join(SORTIE, "masque.png.tmp"))
        os.replace(os.path.join(SORTIE, "masque.png.tmp"), os.path.join(SORTIE, "masque.png"))
        masque_ok = 1
        if "--verre" in sys.argv:
            with Image.open(connu) as im:
                sujet = im.convert("RGB").getchannel("R")
        journal("sujet repris de la photo d'origine")
    elif avec_masque and os.path.exists(MODELE):
        m = vers_ecran(detourer(img), largeur, hauteur, style, mosaique)
        rgb = masque_rgb(m)
        ecrire_atomique(os.path.join(SORTIE, "masque.png"), lambda p: rgb.save(p, "PNG"))
        if b and not b["variante"]:
            ecrire_atomique(connu, lambda p: rgb.save(p, "PNG"))      # pour les ambiances
        masque_ok = 1
        sujet = m
    elif avec_masque:
        erreur = "modèle absent"
        journal("modèle introuvable : " + MODELE)

    verre_ok = 0
    if "--verre" in sys.argv:
        ecrire_verre(ecran, sujet)
        verre_ok = 1

    infos = {
        "empreinte": empreinte(TRANSCODE),
        "style": style,
        "ecran": f"{largeur}x{hauteur}",
        "teinte": teinte(ecran),
        "masque": masque_ok,
        "verre": verre_ok,
        "erreur": erreur,
        "duree": f"{time.time() - t0:.1f}",
        "date": int(time.time()),
    }
    texte = "".join(f"{k}={v}\n" for k, v in infos.items())

    def ecrire_texte(p):
        with open(p, "w", encoding="utf-8") as f:
            f.write(texte)
    ecrire_atomique(os.path.join(SORTIE, "fond.txt"), ecrire_texte)
    journal(f"analyse terminée en {time.time() - t0:.1f} s (masque {masque_ok})")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        if "--ambiance" in sys.argv:
            # ambiance ratée : on le note, mais l'analyse du fond (fond.txt) reste valable
            journal("ambiance en échec : " + traceback.format_exc())
            try:                                     # un « à créer » d'avant ne doit pas faire croire à un report
                noter_ambiance(sys.argv[sys.argv.index("--ambiance") + 1], "echec")
            except Exception:
                pass
            sys.exit(2)
        journal(traceback.format_exc())
        # le widget doit savoir que ça a échoué (et pourquoi) : fond.txt sans masque
        try:
            lignes = [f"empreinte={empreinte(TRANSCODE)}", "masque=0",
                      f"erreur={type(e).__name__} : {str(e)[:120]}", f"date={int(time.time())}"]
            with open(os.path.join(SORTIE, "fond.txt"), "w", encoding="utf-8") as f:
                f.write("\n".join(lignes) + "\n")
        except Exception:
            pass
        sys.exit(1)
