# Génère game/data/arsenal.json : « l'Arsenal des époques », l'équipement de palier de chaque île
# (3 panoplies par île : Assaut, Garde, Harmonie ; 7 pièces chacune ; version normale + renforcée),
# les bonus d'ensemble et les recettes de l'atelier d'Inès (quartier des Artisans du hub).
# Usage : python3 tools/progression/generer_arsenal.py   (puis relancer les tests)
# Pour une nouvelle île : ajouter une entrée à ILES (palier suivant) et relancer.
import json, os

SORTIE = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "arsenal.json")

EMPLACEMENTS = ["arme_principale", "torse", "jambes", "tete", "mains", "pieds", "bijou"]
# Part de chaque pièce dans le total de la panoplie.
POIDS_ATTAQUE = {"arme_principale": .30, "torse": .17, "jambes": .14, "tete": .12, "mains": .10, "pieds": .09, "bijou": .08}
POIDS_VIE = {"arme_principale": .10, "torse": .22, "jambes": .17, "tete": .14, "mains": .12, "pieds": .12, "bijou": .13}
POIDS_PROTECTION = {"arme_principale": .08, "torse": .25, "jambes": .20, "tete": .15, "mains": .13, "pieds": .12, "bijou": .07}
RENFORCE = 1.35   # la version renforcée est 35 % plus forte
NORMAL = 1 / RENFORCE

# Totaux d'une panoplie RENFORCÉE complète (7 pièces) au palier p (1 = Préhistoire, 5 = Chine…).
def totaux(role, p):
    attaque = 20 + 25 * p            # % de dégâts : 45, 70, 95, 120, 145, 170
    vie = {1: 220, 2: 420, 3: 720, 4: 1000, 5: 1350, 6: 1700}.get(p, 1350 + 350 * (p - 5))
    if role == "assaut":
        return {"degats_pourcent": attaque, "critique_pourcent": 3 + 2 * p, "pv": vie, "reduction_pourcent": p}
    if role == "garde":
        return {"degats_pourcent": round(attaque * 0.4), "reduction_pourcent": 2 + 4 * p, "pv": round(vie * 1.8)}
    return {"soins_pourcent": 4 + 8 * p, "degats_pourcent": round(attaque * 0.7), "critique_pourcent": p + 1, "pv": round(vie * 1.2)}

def poids(stat):
    if stat == "pv": return POIDS_VIE
    if stat == "reduction_pourcent": return POIDS_PROTECTION
    return POIDS_ATTAQUE

def stats_piece(role, p, emplacement, facteur):
    r = {}
    for stat, total in totaux(role, p).items():
        v = total * facteur * poids(stat)[emplacement]
        v = int(round(v / 5.0) * 5) if stat == "pv" else int(round(v))
        if v <= 0 and stat in ("degats_pourcent", "soins_pourcent", "pv") and total > 0:
            v = 1
        if v > 0:
            r[stat] = v
    return r

def bonus_ensemble(role, p):
    if role == "assaut":
        return {
            "3": {"texte": "+%d %% de dégâts" % (2 * p + 2), "stats": {"degats_pourcent": 2 * p + 2}},
            "5": {"texte": "+%d %% de coups critiques" % (p + 1), "stats": {"critique_pourcent": p + 1}},
            "7": {"texte": "+%d %% de dégâts et %d %% de vol de vie" % (3 * p, 2 + p // 2),
                  "stats": {"degats_pourcent": 3 * p, "vol_de_vie_pourcent": 2 + p // 2}},
        }
    if role == "garde":
        return {
            "3": {"texte": "+%d points de vie" % (40 * p), "stats": {"pv": 40 * p}},
            "5": {"texte": "+%d %% de protection" % (p + 1), "stats": {"reduction_pourcent": p + 1}},
            "7": {"texte": "+%d points de vie et les contrôles durent %d %% de moins sur toi" % (60 * p, 15 + 3 * p),
                  "stats": {"pv": 60 * p, "resistance_controles_pourcent": 15 + 3 * p}},
        }
    return {
        "3": {"texte": "+%d %% de soins donnés" % (2 * p + 2), "stats": {"soins_pourcent": 2 * p + 2}},
        "5": {"texte": "+%d %% de coups critiques" % (p + 1), "stats": {"critique_pourcent": p + 1}},
        "7": {"texte": "+%d %% de soins donnés et +%d points de vie" % (3 * p, 40 * p),
              "stats": {"soins_pourcent": 3 * p, "pv": 40 * p}},
    }

ROLES = {
    "assaut": "pour la Lame et le Traqueur : dégâts et coups critiques",
    "garde": "pour le Rempart : vie et protection",
    "harmonie": "pour le Tisseur : soins, vie et un peu de dégâts",
}

# Chaque île : palier, époque, matériaux (armure, arme), trophée du donjon (pour la version renforcée),
# et pour chaque panoplie : nom, couleur, formes visibles et noms des 7 pièces (même ordre que EMPLACEMENTS).
ILES = [
    {"id": "prehistoire", "palier": 1, "epoque": "Préhistoire", "categorie": "Préhistoire",
     "armure": {"peau_loup": 3, "tendon_seche": 2}, "arme": {"silex": 3, "bois_de_renne": 1},
     "trophee": "fourrure_ours",
     "panoplies": {
        "assaut": {"nom": "Croc de la steppe", "couleur": "#8a7356",
            "formes": ["lance", "cape_fourrure", "jambieres", "capuche_loup", "brassards", "bottes_fourrure", "collier"],
            "pieces": ["Lance du croc", "Cape du croc", "Jambières du croc", "Capuche du croc", "Brassards du croc", "Bottes du croc", "Collier de crocs"]},
        "garde": {"nom": "Peau d'aurochs", "couleur": "#5b4330",
            "formes": ["massue", "cape_fourrure", "jambieres", "bandeau", "brassards", "bottes_fourrure", "collier"],
            "pieces": ["Massue d'aurochs", "Manteau d'aurochs", "Jambières d'aurochs", "Bandeau d'aurochs", "Brassards d'aurochs", "Bottes d'aurochs", "Collier de cornes"]},
        "harmonie": {"nom": "Esprit du clan", "couleur": "#a0583a",
            "formes": ["lance", "cape_fourrure", "jambieres", "bandeau", "brassards", "bottes_fourrure", "collier"],
            "pieces": ["Bâton des esprits", "Cape des esprits", "Jambières des esprits", "Bandeau d'ocre", "Brassards des esprits", "Bottes des esprits", "Collier d'ambre"]},
     }},
    {"id": "egypte", "palier": 2, "epoque": "Égypte antique", "categorie": "Égypte",
     "armure": {"lin": 4, "ecaille_crocodile": 2}, "arme": {"calcaire_fin": 2, "malachite": 2},
     "trophee": "ecaille_isfet",
     "panoplies": {
        "assaut": {"nom": "Lame du Nil", "couleur": "#c9a55a",
            "formes": ["lame", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Khopesh du Nil", "Tunique du Nil", "Pagne du Nil", "Coiffe du Nil", "Brassards du Nil", "Sandales du Nil", "Scarabée du Nil"]},
        "garde": {"nom": "Garde du pharaon", "couleur": "#3e6f8f",
            "formes": ["massue", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Masse du pharaon", "Corselet du pharaon", "Pagne de la garde", "Némès de la garde", "Brassards de la garde", "Sandales de la garde", "Ousekh de la garde"]},
        "harmonie": {"nom": "Souffle de Maât", "couleur": "#e8dcb0",
            "formes": ["lance", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Sceptre de Maât", "Robe de Maât", "Pagne de lin de Maât", "Bandeau à la plume", "Bracelets de Maât", "Sandales de Maât", "Amulette d'Ânkh"]},
     }},
    {"id": "grece", "palier": 3, "epoque": "Grèce antique", "categorie": "Grèce",
     "armure": {"soie_de_sanglier": 3, "peau_de_vipere": 2}, "arme": {"croc_de_chien": 3, "defense_sanglier": 1},
     "trophee": "oeil_de_gorgone",
     "panoplies": {
        "assaut": {"nom": "Peltaste d'Athènes", "couleur": "#a8402e",
            "formes": ["lance", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Javeline de peltaste", "Exomis de peltaste", "Cnémides de peltaste", "Pétase de peltaste", "Brassards de peltaste", "Sandales de peltaste", "Fibule de peltaste"]},
        "garde": {"nom": "Phalange d'Athéna", "couleur": "#b08a3e",
            "formes": ["lame", "veste", "pantalon", "casque_hoplite", "brassards", "rangers", "collier"],
            "pieces": ["Kopis de la phalange", "Linothorax de la phalange", "Cnémides de bronze", "Casque corinthien", "Brassards de la phalange", "Sandales de la phalange", "Chouette de la phalange"]},
        "harmonie": {"nom": "Disciple d'Asclépios", "couleur": "#e9e4d4",
            "formes": ["lance", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Bâton d'Asclépios", "Himation du disciple", "Chiton du disciple", "Couronne de laurier", "Bracelets du disciple", "Sandales du disciple", "Serpent d'argent"]},
     }},
    {"id": "rome", "palier": 4, "epoque": "Rome antique", "categorie": "Rome",
     "armure": {"criniere_de_lion": 2, "fourrure_ours_vivarium": 1, "gilet_pretorien": 1}, "arme": {"pioche_pilleur": 3, "griffe_leopard": 1},
     "trophee": "bronze_colosse",
     "panoplies": {
        "assaut": {"nom": "Glaive de Mars", "couleur": "#9e2b25",
            "formes": ["lame", "veste", "pantalon", "casque_thrace", "brassards", "rangers", "collier"],
            "pieces": ["Glaive de Mars", "Lorica de Mars", "Braies de Mars", "Casque de Mars", "Manicae de Mars", "Caligae de Mars", "Phalère de Mars"]},
        "garde": {"nom": "Tortue prétorienne", "couleur": "#6b5a8a",
            "formes": ["lame", "veste", "pantalon", "casque_gladiateur", "brassards", "rangers", "collier"],
            "pieces": ["Spatha prétorienne", "Lorica segmentata", "Braies prétoriennes", "Galea prétorien", "Manicae prétoriennes", "Caligae prétoriennes", "Torque prétorien"]},
        "harmonie": {"nom": "Flamme de Vesta", "couleur": "#f0e8d8",
            "formes": ["lance", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Bâton de Vesta", "Stola de Vesta", "Tunique de Vesta", "Voile de Vesta", "Bracelets de Vesta", "Sandales de Vesta", "Bulla de Vesta"]},
     }},
    {"id": "chine", "palier": 5, "epoque": "Chine des Han", "categorie": "Chine",
     "armure": {"soie_grege": 3, "pelage_loup_desert": 2}, "arme": {"plaquette_laque": 2, "ecorce_murier": 2},
     "trophee": "perle_coiffe_imperiale",
     "panoplies": {
        "assaut": {"nom": "Arbalétrier des Han", "couleur": "#7a2a2a",
            "formes": ["lame", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Jian de l'arbalétrier", "Cuirasse laquée", "Pantalon de l'arbalétrier", "Bonnet de l'arbalétrier", "Brassards laqués", "Bottes de l'arbalétrier", "Jade de l'arbalétrier"]},
        "garde": {"nom": "Garde de la Muraille", "couleur": "#4a4a3a",
            "formes": ["lame", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Dao de la Muraille", "Armure d'écailles de la Muraille", "Jambières de la Muraille", "Casque de la Muraille", "Gantelets de la Muraille", "Bottes de la Muraille", "Sceau de la Muraille"]},
        "harmonie": {"nom": "Lettré de Luoyang", "couleur": "#2f5a6a",
            "formes": ["lance", "veste", "pantalon", "bandeau", "brassards", "rangers", "collier"],
            "pieces": ["Pinceau-bâton du lettré", "Robe de soie du lettré", "Pantalon de soie", "Bonnet du lettré", "Manchettes du lettré", "Chaussons du lettré", "Bi de jade du lettré"]},
     }},
]

ICONES = {"arme_principale": None, "torse": "veste", "jambes": "pantalon", "tete": "bandeau", "mains": "brassards", "pieds": "rangers", "bijou": "eclat"}

def generer():
    objets, ensembles, recettes = {}, {}, {}
    categories = {}
    for ile in ILES:
        p = ile["palier"]
        cat = "arsenal_" + ile["id"]
        categories[cat] = ile["categorie"]
        niveau_normal, niveau_renforce = 10 * p - 4, 10 * p
        for role, pan in ile["panoplies"].items():
            ens = "arsenal_%s_%s" % (ile["id"], role)
            ensembles[ens] = {"nom": pan["nom"], "epoque": ile["epoque"], "paliers": bonus_ensemble(role, p)}
            for i, emp in enumerate(EMPLACEMENTS):
                forme = pan["formes"][i]
                base_id = "%s_%s" % (ens, emp.replace("arme_principale", "arme"))
                for renforce in (False, True):
                    oid = base_id + ("_renforce" if renforce else "")
                    nom = pan["pieces"][i] + (" (renforcé)" if renforce else "")
                    o = {
                        "nom": nom, "type": "equipement",
                        "rarete": "epique" if renforce else "rare",
                        "description": "Arsenal des époques, panoplie « %s » (%s). %s" % (pan["nom"], ROLES[role],
                            "Renforcée avec un trophée du donjon de l'île." if renforce else "Fabriquée par Inès avec les matériaux de l'île."),
                        "emplacement": emp, "epoque": ile["epoque"],
                        "niveau": niveau_renforce if renforce else niveau_normal,
                        "stats": stats_piece(role, p, emp, 1.0 if renforce else NORMAL),
                        "ensemble": ens,
                    }
                    couleur = pan["couleur"]
                    if emp == "bijou":
                        o["icone"] = {"forme": "collier", "couleur": couleur}
                    elif emp in ("torse", "jambes", "pieds") and forme in ("veste", "pantalon", "rangers"):
                        o["visuel"] = {"forme": forme, "couleur": couleur}
                        if emp == "torse":
                            o["visuel"]["teinte"] = couleur
                    else:
                        o["visuel"] = {"forme": forme, "couleur": couleur}
                        if forme == "cape_fourrure":
                            o["visuel"]["teinte"] = couleur
                    if renforce:
                        o["ameliore_de"] = base_id
                    objets[oid] = o
                    # Recette
                    if not renforce:
                        ing = {"eclat_de_fracture": 2 + p}
                        ing.update(ile["arme"] if emp in ("arme_principale", "bijou") else ile["armure"])
                    else:
                        ing = {base_id: 1, "eclat_de_fracture": 4 + p}
                        if ile.get("trophee"):
                            ing[ile["trophee"]] = 1
                        else:
                            ing.update(ile["trophee_provisoire"])
                    recettes[oid] = {"artisan": "arsenal", "categorie": cat, "donne": oid, "quantite": 1, "ingredients": ing}
    return {
        "_aide": "Arsenal des époques (généré par tools/progression/generer_arsenal.py : modifie le script puis relance-le plutôt que ce fichier). Pour chaque île, 3 panoplies de 7 pièces : Assaut (Lame, Traqueur), Garde (Rempart), Harmonie (Tisseur). La pièce normale (rare) se fabrique chez Inès la soudeuse (quartier des Artisans) avec des éclats de fracture et des matériaux de l'île ; la version renforcée (épique, 35 % plus forte) demande en plus le trophée du boss du donjon de l'île. « niveau » : niveau du personnage requis pour porter la pièce. Ces objets, ensembles et recettes s'ajoutent au démarrage à ceux de objets.json et artisanat.json.",
        "artisan": {
            "id": "arsenal", "nom": "Arsenal des époques",
            "titre": "Atelier d'Inès · Arsenal des époques", "pnj": ["soudeuse"], "couleur": "#b46cff",
            "accueil": "Ta ferraille violette, je sais la travailler. Apporte-moi des éclats de fracture et des matériaux de l'île : je te fais une panoplie digne de l'époque. Un trophée de donjon, et je la renforce.",
            "categories": list(categories.keys()),
        },
        "categories": categories,
        "objets": objets, "ensembles": ensembles, "recettes": recettes,
    }

if __name__ == "__main__":
    d = generer()
    with open(SORTIE, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    print("%d objets, %d ensembles, %d recettes -> %s" % (len(d["objets"]), len(d["ensembles"]), len(d["recettes"]), os.path.normpath(SORTIE)))
