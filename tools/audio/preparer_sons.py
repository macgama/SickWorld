#!/usr/bin/env python3
"""Prépare les sons du jeu (game/audio/) à partir des banques libres.

Usage :
    python3 tools/audio/preparer_sons.py <dossier_sources> [game/audio] [filtre, ex. betes/loup]

<dossier_sources> contient les banques téléchargées (voir docs/CREDITS.md) :
    oculus/       Oculus Audio Pack 01 (CC BY 4.0), dépôt facebookincubator/Meta-open-sound,
                  dossier corpora/oculus-audio-pack/ogg
    mangarr/      packs CC0 de github.com/Asion001/mangarr-sounds (releases) :
                  mangarr/city, mangarr/combat, mangarr/nature, mangarr/objects, mangarr/weather
    holizna/      musiques HoliznaCC0 (CC0) prises dans github.com/seyedpouramir/alvana-audio (music/)
    alvana/       quelques bruitages CC0 du même dépôt (sfx/)
    kenney_ui/    Kenney UI Audio (CC0), dépôt Calinou/kenney-ui-audio
    loups/        vrais loups et gros chiens en CC0 de Freesound (aperçus HQ, liste dans docs/CREDITS.md)

Ce que fait le script (avec ffmpeg et numpy) :
- tout est converti en Ogg Vorbis 44,1 kHz ;
- les bruitages ponctuels sont en mono (sons placés en 3D) et normalisés à -1 dB crête ;
- les boucles d'ambiance gardent leur stéréo, sont normalisées en volume moyen et
  rendues « sans couture » (la fin est fondue dans le début) ;
- les musiques sont seulement converties ;
- les gouttes de la grotte sont fabriquées ici
  (synthèse), faute d'enregistrement libre accessible.
"""
import math
import os
import subprocess
import sys

import numpy as np

TAUX = 44100

# ---------------------------------------------------------------------------
# Liste des sons : destination -> (sources, réglages)
#   sources : chemin(s) relatif(s) au dossier des sources
#   type : "ponctuel" (mono, crête -1 dB), "boucle" (stéréo, fondu de bouclage),
#          "musique" (conversion seule)
#   hauteur : facteur de vitesse/hauteur (0.8 = plus grave)
#   debut / duree : extrait (secondes)
# ---------------------------------------------------------------------------
OC = "oculus/"


def serie(prefixe, n, debut=1):
    return [f"{OC}{prefixe}_{i:02d}.ogg" for i in range(debut, debut + n)]


SONS = {}


def ajouter(dossier, nom, sources, **reglages):
    if isinstance(sources, str):
        sources = [sources]
    if len(sources) == 1:
        SONS[f"{dossier}/{nom}.ogg"] = (sources[0], reglages)
    else:
        for i, s in enumerate(sources, 1):
            SONS[f"{dossier}/{nom}_{i}.ogg"] = (s, reglages)


# Pas (une variante par fichier)
for surface, oculus in [("beton", "Concrete"), ("terre", "Dirt"), ("herbe", "Grass"),
                        ("neige", "Snow"), ("bois", "Wood"), ("metal", "Metal")]:
    ajouter("pas", f"{surface}_course", serie(f"FEETHmn_Shoe{oculus}Run_OS", 5), type="ponctuel")
    ajouter("pas", f"{surface}_marche", serie(f"FEETHmn_Shoe{oculus}Walk_OS", 5), type="ponctuel")
    ajouter("pas", f"{surface}_reception", serie(f"FEETHmn_Shoe{oculus}Land_OS", 2), type="ponctuel")

# Mouvements du personnage
ajouter("personnage", "tissu", serie("CLOTHMvmt_ClothingMovement_OS", 4), type="ponctuel")
ajouter("personnage", "equipement", serie("CLOTHMvmt_MovementWithGear_OS", 4), type="ponctuel")
ajouter("personnage", "roulade", serie("WHSH_WhooshMedium_OS", 3), type="ponctuel")

# Combat
ajouter("combat", "elan", serie("SWSH_Swoosh_OS", 6), type="ponctuel")
ajouter("combat", "coup", serie("FGHTImpt_PunchRegular_OS", 6), type="ponctuel")
ajouter("combat", "coup_fort", serie("FGHTImpt_PunchHarder_OS", 4), type="ponctuel")
ajouter("combat", "lame", ["mangarr/combat/slash-kenney.ogg", "mangarr/combat/chop-kenney.ogg",
                            f"{OC}WEAPSwrd_Sword_OS_01.ogg", f"{OC}WEAPSwrd_Sword_OS_02.ogg"], type="ponctuel")
ajouter("combat", "lancer", serie("WHSH_WhooshSmall_OS", 3), type="ponctuel")
ajouter("combat", "impact_sagaie", "mangarr/combat/arrow-impact-205938.ogg", type="ponctuel")
ajouter("combat", "feu", "mangarr/nature/1103campfire1-62487.ogg", type="boucle", debut=5, duree=20)
ajouter("combat", "embrasement", f"{OC}MAGSpel_MagicSpell_OS_02.ogg", type="ponctuel", hauteur=0.8)

# Voix des agents
for sexe, oculus in [("homme", "VOXMale_Male01"), ("femme", "VOXFem_Female01")]:
    ajouter("voix", f"{sexe}_douleur", serie(f"{oculus}Hurt_OS", 3), type="ponctuel")
    ajouter("voix", f"{sexe}_mort", serie(f"{oculus}Death_OS", 3), type="ponctuel")
ajouter("voix", "homme_effort", f"{OC}VOXEfrt_Male01Effort_OS_01.ogg", type="ponctuel")
ajouter("voix", "femme_effort", f"{OC}VOXEfrt_Female01Effort_OS_01.ogg", type="ponctuel")

# Bêtes
# Loups : vrais enregistrements Freesound en CC0 (dossier loups/, voir docs/CREDITS.md).
# Aucun aboiement ni cri de douleur de loup n'existe en CC0 : on prend de gros chiens, un peu ralentis.
LOUPS = {
    "loup_hurlement": [("hurlement_500646", 1.8, 9.2), ("hurlement_500646", 11.4, 8.3), ("hurlement_500646", 29.2, 8.8),
                       ("hurlement_500646", 40.5, 8.1), ("hurlement_158780", 1.5, 4.8), ("hurlement_158780", 10.4, 6.4),
                       ("hurlement_143568", 0.0, 10.9), ("hurlement_651193", 43.2, 15.0)],
    "loup_grondement": [("grondement_472401", 0.0, 4.9), ("grondement_404920", 5.0, 3.3), ("grondement_404920", 10.0, 2.3),
                        ("grondement_404920", 19.8, 3.0), ("grondement_461519", 7.8, 2.0), ("grondement_401820", 8.7, 1.9)],
    "loup_morsure": [("aboiement_625501", 0.55, 0.65), ("aboiement_619045", 3.55, 0.85), ("aboiement_619045", 5.0, 0.55),
                     ("aboiement_619045", 10.78, 0.3), ("aboiement_619045", 13.78, 0.3), ("aboiement_383483", 1.88, 0.32),
                     ("aboiement_383483", 2.82, 0.3)],
    "loup_douleur": [("douleur_635114", 0.0, 1.15), ("douleur_635114", 2.68, 0.8), ("douleur_635114", 4.42, 0.8),
                     ("douleur_160478", 2.38, 1.3), ("douleur_160478", 3.7, 0.7)],
    "loup_mort": [("douleur_160478", 6.64, 2.5), ("douleur_635114", 0.0, 1.15)],
}
HAUTEUR_LOUPS = {"loup_hurlement": 1.0, "loup_grondement": 0.95, "loup_morsure": 0.88, "loup_douleur": 0.92, "loup_mort": 0.85}
for nom, extraits in LOUPS.items():
    for i, (src, debut, duree) in enumerate(extraits, 1):
        SONS[f"betes/{nom}_{i}.ogg"] = (f"loups/{src}.mp3", {"type": "ponctuel", "debut": debut, "duree": duree,
                                                           "hauteur": HAUTEUR_LOUPS[nom], "garder_silences": True})
ajouter("betes", "ours_rugissement", "alvana/creature_roar-02.wav", type="ponctuel", hauteur=0.7)
ajouter("betes", "ours_grognement", ["alvana/creature_grunt-01.wav", "alvana/creature_grunt-03.wav"], type="ponctuel", hauteur=0.7)
ajouter("betes", "renne_grognement", "alvana/creature_grunt-03.wav", type="ponctuel", hauteur=1.3)

# Ambiances (boucles)
ajouter("ambiances", "pluie_ville", f"{OC}RAIN_CityRain_LOOP_01.ogg", type="boucle")
ajouter("ambiances", "ville_nuit", "mangarr/city/city-streets-by-night-ambient-atmosphere-270881.ogg", type="boucle")
ajouter("ambiances", "foule", "mangarr/city/people-talking-at-cafe-ambience-482990.ogg", type="boucle")
ajouter("ambiances", "vagues", "mangarr/nature/ocean-waves-531015.ogg", type="boucle")
ajouter("ambiances", "salle_machines", f"{OC}AMBInd_RoomToneMachineRoom_LOOP_01.ogg", type="boucle")
ajouter("ambiances", "vent_arctique", "mangarr/weather/wind-artic-cold-117136.ogg", type="boucle")
ajouter("ambiances", "vent_hiver", "mangarr/weather/winter-wind-01c-117513.ogg", type="boucle")
ajouter("ambiances", "vent_plaine", f"{OC}WINDVege_LightWindTreesBirds_LOOP_01.ogg", type="boucle")
ajouter("ambiances", "foret", f"{OC}AMBForst_Forest_LOOP_01.ogg", type="boucle")
ajouter("ambiances", "riviere", "mangarr/nature/stream-river-water-up-close-433589.ogg", type="boucle")
ajouter("ambiances", "feu_de_camp", "mangarr/nature/1103campfire1-62487.ogg", type="boucle")
ajouter("ambiances", "grotte_vent", "mangarr/weather/winter-wind-whistling-through-window-69512.ogg", type="boucle", hauteur=0.6)

# Sons ponctuels d'ambiance (joués au hasard autour du joueur)
ajouter("ambiances", "klaxon", ["mangarr/city/05-horn-461679.ogg", "mangarr/city/car-horn-182474.ogg"], type="ponctuel")
ajouter("ambiances", "tonnerre", ["mangarr/weather/thunder-193170.ogg", "mangarr/weather/thunder-244053.ogg"], type="ponctuel")
ajouter("ambiances", "train", f"{OC}TRNElec_TrainPassby_OS_01.ogg", type="ponctuel")
ajouter("ambiances", "oiseau", ["mangarr/nature/bird-chirp-182507.ogg", "mangarr/nature/birds-chirping-02-182502.ogg"], type="ponctuel")
ajouter("ambiances", "chouette", "mangarr/nature/owl-hoot-465697.ogg", type="ponctuel")
ajouter("ambiances", "corbeau", serie("AMBForst_ForestBirds_OS", 3), type="ponctuel")

# Interface
ajouter("interface", "clic", ["kenney_ui/click1.wav", "kenney_ui/click2.wav", "kenney_ui/click3.wav"], type="ponctuel")
ajouter("interface", "survol", ["kenney_ui/rollover2.wav", "kenney_ui/rollover3.wav"], type="ponctuel")
ajouter("interface", "valider", f"{OC}UIClick_ScifiHightechConfirm_OS_01.ogg", type="ponctuel")
ajouter("interface", "ouvrir", f"{OC}UIClick_ScifiHightechOpen_OS_01.ogg", type="ponctuel")
ajouter("interface", "fermer", f"{OC}UIClick_ScifiHightechClose_OS_01.ogg", type="ponctuel")
ajouter("interface", "erreur", f"{OC}UIAlert_ScifiHightechError_OS_01.ogg", type="ponctuel")
ajouter("interface", "notification", f"{OC}UIAlert_Notification_OS_02.ogg", type="ponctuel")
ajouter("interface", "quete_acceptee", f"{OC}UIMisc_BelltreeUp_OS_01.ogg", type="ponctuel")
ajouter("interface", "quete_etape", f"{OC}UIAlert_MusicTone_OS_03.ogg", type="ponctuel")
ajouter("interface", "quete_terminee", f"{OC}MUSCStngr_VictoryOrchestral_OS_01.ogg", type="ponctuel", stereo=True)
ajouter("interface", "niveau", f"{OC}MUSCStngr_LevelUpOrchestral_OS_01.ogg", type="ponctuel", stereo=True)
ajouter("interface", "butin", f"{OC}OBJCoin_CoinDrop_OS_01.ogg", type="ponctuel")
ajouter("interface", "sac", f"{OC}OBJBag_KnapsackNylonOpen_OS_01.ogg", type="ponctuel")
ajouter("interface", "portail", f"{OC}MAGSpel_MagicSpell_OS_01.ogg", type="ponctuel", stereo=True)

# Musiques (HoliznaCC0)
for dest, src in [
    ("menu_1", "intro_beginning-6"), ("menu_2", "intro_beginning-4"),
    ("hub_1", "lofi_city-in-the-rearview"), ("hub_2", "calm_night-driving"),
    ("hub_3", "lofi_foggy-headed"), ("hub_4", "lofi_ramen"), ("hub_5", "lofi_pretty-little-lies"),
    ("prehistoire_1", "ambient_quiet-village-1"), ("prehistoire_2", "ambient_quiet-village-2"),
    ("prehistoire_3", "ambient_quiet-village-3"), ("prehistoire_4", "ambient_quiet-village-4"),
    ("grotte_1", "ambient_cave-1"), ("grotte_2", "ambient_cave-4"), ("grotte_3", "ambient_cave-5"),
]:
    SONS[f"musique/{dest}.ogg"] = (f"holizna/{src}.mp3", {"type": "musique"})


# ---------------------------------------------------------------------------

def lire(chemin, canaux, hauteur=1.0, debut=0.0, duree=0.0):
    filtres = []
    if hauteur != 1.0:
        filtres.append(f"asetrate={int(TAUX * hauteur)},aresample={TAUX}")
    cmd = ["ffmpeg", "-v", "error"]
    if debut:
        cmd += ["-ss", str(debut)]
    if duree:
        cmd += ["-t", str(duree / hauteur)]
    cmd += ["-i", chemin, "-ar", str(TAUX), "-ac", str(canaux)]
    if filtres:
        cmd += ["-af", ",".join(filtres)]
    cmd += ["-f", "f32le", "-"]
    brut = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(brut, dtype=np.float32).reshape(-1, canaux).copy()


def ecrire(chemin, donnees, qualite=4):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    canaux = donnees.shape[1]
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(TAUX), "-ac", str(canaux), "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(qualite), chemin]
    subprocess.run(cmd, input=np.clip(donnees, -1, 1).astype(np.float32).tobytes(), check=True)


def couper_silences(x, seuil_db=-50.0):
    niveau = np.abs(x).max(axis=1)
    seuil = 10 ** (seuil_db / 20)
    ou = np.nonzero(niveau > seuil)[0]
    if len(ou) == 0:
        return x
    debut = max(0, ou[0] - int(0.005 * TAUX))
    fin = min(len(x), ou[-1] + int(0.05 * TAUX))
    return x[debut:fin]


def fondus(x, entree=0.01, sortie=0.12):
    a, b = min(int(entree * TAUX), len(x) // 4), min(int(sortie * TAUX), len(x) // 3)
    x = x.copy()
    if a:
        x[:a] *= np.linspace(0, 1, a, dtype=np.float32)[:, None]
    if b:
        x[-b:] *= np.linspace(1, 0, b, dtype=np.float32)[:, None]
    return x


def boucler(x, fondu_s=2.5):
    f = min(int(fondu_s * TAUX), len(x) // 4)
    t = np.linspace(0, 1, f, dtype=np.float32)[:, None]
    corps = x[: len(x) - f].copy()
    queue = x[len(x) - f:]
    # Fondu à puissance constante : la fin se mélange au début.
    corps[:f] = corps[:f] * np.sin(t * math.pi / 2) + queue * np.cos(t * math.pi / 2)
    return corps


def normaliser_crete(x, db=-1.0):
    m = np.abs(x).max()
    return x if m == 0 else x * (10 ** (db / 20) / m)


def normaliser_moyenne(x, db=-20.0):
    rms = math.sqrt(float(np.mean(x ** 2)))
    if rms == 0:
        return x
    y = x * (10 ** (db / 20) / rms)
    m = np.abs(y).max()
    return y * (0.95 / m) if m > 0.95 else y


# --- Synthèses --------------------------------------------------------------

def reverberation(x, duree=2.5, melange=0.45, graine=0):
    rng = np.random.default_rng(graine)
    n = int(duree * TAUX)
    rep = rng.standard_normal(n).astype(np.float32) * np.exp(-np.linspace(0, 7, n)).astype(np.float32)
    rep[0] = 0
    sortie = np.zeros((len(x) + n - 1, x.shape[1]), dtype=np.float32)
    for c in range(x.shape[1]):
        r = rep if c == 0 else np.roll(rep, 37)
        humide = np.fft.irfft(np.fft.rfft(x[:, c], len(sortie)) * np.fft.rfft(r, len(sortie)), len(sortie))
        humide /= max(1e-9, np.abs(humide).max())
        sortie[:, c] = humide * melange
        sortie[: len(x), c] += x[:, c] * (1 - melange)
    return sortie


def passe_bas(x, coupure):
    spectre = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1 / TAUX)
    spectre *= (1 / np.sqrt(1 + (f / coupure) ** 4))[:, None]
    return np.fft.irfft(spectre, len(x), axis=0).astype(np.float32)


def goutte(graine):
    """Goutte d'eau qui tombe dans une flaque de grotte."""
    rng = np.random.default_rng(graine)
    d = 0.12
    t = np.linspace(0, d, int(d * TAUX), endpoint=False)
    f0 = rng.uniform(900, 1500)
    f = f0 * (1 + 1.8 * (t / d))
    phase = 2 * math.pi * np.cumsum(f) / TAUX
    x = (np.sin(phase) * np.exp(-t * 45)).astype(np.float32)[:, None]
    x = np.repeat(x, 2, axis=1)
    return normaliser_crete(reverberation(x, 2.2, 0.55, graine), -3)


def principal():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    sources = sys.argv[1]
    sortie = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "../../game/audio")
    manquants = []
    filtre = sys.argv[3] if len(sys.argv) > 3 else ""  # ex. « betes/loup » : ne refait que ces sons
    for dest, (src, r) in sorted(SONS.items()):
        if filtre and not dest.startswith(filtre):
            continue
        chemin = os.path.join(sources, src)
        if not os.path.exists(chemin):
            manquants.append(src)
            continue
        type_son = r.get("type", "ponctuel")
        cible = os.path.join(sortie, dest)
        if type_son == "musique":
            os.makedirs(os.path.dirname(cible), exist_ok=True)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", chemin, "-ar", str(TAUX), "-c:a", "libvorbis",
                            "-q:a", "4", cible], check=True)
        elif type_son == "boucle":
            x = lire(chemin, 2, r.get("hauteur", 1.0), r.get("debut", 0.0), r.get("duree", 0.0))
            ecrire(cible, normaliser_moyenne(boucler(x)), 3)
        else:
            x = lire(chemin, 2 if r.get("stereo") else 1, r.get("hauteur", 1.0), r.get("debut", 0.0), r.get("duree", 0.0))
            if not r.get("garder_silences"):
                x = couper_silences(x)
            ecrire(cible, normaliser_crete(fondus(x)), 4)
        print("ok", dest)
    for i in range(1, 5 if not filtre else 1):
        ecrire(os.path.join(sortie, f"ambiances/goutte_{i}.ogg"), goutte(200 + i), 4)
        print("ok", f"ambiances/goutte_{i}.ogg (synthèse)")
    if manquants:
        print("\nSources introuvables :", *manquants, sep="\n  ")
        sys.exit(2)


if __name__ == "__main__":
    principal()
