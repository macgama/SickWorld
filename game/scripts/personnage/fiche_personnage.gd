class_name FichePersonnage
extends RefCounted
## La « fiche » d'un personnage : tout ce que le joueur a choisi à la création.
##
## C'est un simple dictionnaire (facile à sauvegarder en JSON, à envoyer sur le
## réseau et, plus tard, à ranger dans Nakama). Exemple :
##   {
##     "version": 1,
##     "nom": "Aiko",
##     "sexe": "femme",
##     "corps": { "taille_cm": 168, "corpulence": 0.0, "musculature": 0.2 },
##     "visage": { "largeur_visage": -0.3, "menton": 0.5, ... },
##     "peau": "peau_3", "couleur_yeux": "vert",
##     "coiffure": "queue", "couleur_cheveux": "noir", "pilosite": "aucune",
##     "tenue": "terrain",
##     "classe": "lame",
##     "origine": "tokyo"
##   }
##
## Règle d'or : le SERVEUR ne fait jamais confiance à la fiche reçue d'un joueur.
## Il la passe toujours dans valider(), qui remplace tout ce qui est inconnu ou
## hors limites par une valeur permise.
##
## Le « catalogue » est le contenu de data/creation_personnage.json (Donnees.creation).

## Numéro du format. À augmenter si on change la structure, pour pouvoir
## convertir les anciennes fiches sauvegardées.
const VERSION := 1
const FICHIER := "user://personnage.json"
const NOM_LONGUEUR_MIN := 3
const NOM_LONGUEUR_MAX := 20


## Une fiche complète avec les choix par défaut.
static func par_defaut(catalogue: Dictionary, sexe := "") -> Dictionary:
	var sexes: Array = catalogue.get("sexes", [])
	if sexe == "" or _trouver(sexes, sexe).is_empty():
		sexe = _premier_id(sexes, "femme")
	var corps := {}
	for curseur in catalogue.get("corps", []):
		corps[curseur["id"]] = 0.0
	corps["taille_cm"] = float(_trouver(sexes, sexe).get("taille_par_defaut", 175))
	var visage := {}
	for curseur in catalogue.get("visage", []):
		visage[curseur["id"]] = 0.0
	return {
		"version": VERSION,
		"nom": "Agent",
		"sexe": sexe,
		"corps": corps,
		"visage": visage,
		"peau": _premier_id(catalogue.get("peaux", []), ""),
		"couleur_yeux": _premier_id(catalogue.get("couleurs_yeux", []), ""),
		"coiffure": "courte" if not _trouver(catalogue.get("coiffures", []), "courte").is_empty() \
				else _premier_id(catalogue.get("coiffures", []), ""),
		"couleur_cheveux": _premier_id(catalogue.get("couleurs_cheveux", []), ""),
		"pilosite": "aucune" if not _trouver(catalogue.get("pilosites", []), "aucune").is_empty() \
				else _premier_id(catalogue.get("pilosites", []), ""),
		"tenue": _premier_id(catalogue.get("tenues", []), ""),
		"classe": "lame" if not _trouver(catalogue.get("classes", []), "lame").is_empty() \
				else _premier_id(catalogue.get("classes", []), ""),
		"origine": _premier_id(catalogue.get("origines", []), ""),
	}


## Renvoie une copie propre de la fiche : identifiants connus, curseurs dans
## leurs limites, nom valide. Toute valeur douteuse est remplacée.
static func valider(fiche, catalogue: Dictionary) -> Dictionary:
	if not fiche is Dictionary:
		fiche = {}
	var sexe := String(fiche.get("sexe", "")) if fiche.get("sexe") is String else ""
	var propre := par_defaut(catalogue, sexe)
	var nom = fiche.get("nom", "")
	if nom is String and erreur_nom(nom) == "":
		propre["nom"] = nettoyer_nom(nom)

	var corps = fiche.get("corps", {})
	if corps is Dictionary:
		for curseur in catalogue.get("corps", []):
			var id: String = curseur["id"]
			if corps.get(id) is float or corps.get(id) is int:
				propre["corps"][id] = _borner(float(corps[id]), curseur)
	var visage = fiche.get("visage", {})
	if visage is Dictionary:
		for curseur in catalogue.get("visage", []):
			var id: String = curseur["id"]
			if visage.get(id) is float or visage.get(id) is int:
				propre["visage"][id] = _borner(float(visage[id]), curseur)

	for champ in [["peau", "peaux"], ["couleur_yeux", "couleurs_yeux"], ["coiffure", "coiffures"],
			["couleur_cheveux", "couleurs_cheveux"], ["pilosite", "pilosites"], ["tenue", "tenues"],
			["classe", "classes"], ["origine", "origines"]]:
		var valeur = fiche.get(champ[0])
		if valeur is String and not _trouver(catalogue.get(champ[1], []), valeur).is_empty():
			propre[champ[0]] = valeur
	return propre


## Message d'erreur si le nom n'est pas permis, chaîne vide s'il est bon.
static func erreur_nom(nom: String) -> String:
	var n := nettoyer_nom(nom)
	if n.length() < NOM_LONGUEUR_MIN:
		return "Le nom doit faire au moins %d lettres." % NOM_LONGUEUR_MIN
	if n.length() > NOM_LONGUEUR_MAX:
		return "Le nom doit faire au plus %d caractères." % NOM_LONGUEUR_MAX
	var lettres := RegEx.create_from_string("^[\\p{L}][\\p{L} '\\-]*$")
	if lettres.search(n) == null:
		return "Le nom ne peut contenir que des lettres, des espaces, des tirets et des apostrophes."
	return ""


## Enlève les espaces en trop (au début, à la fin, et les doubles espaces).
static func nettoyer_nom(nom: String) -> String:
	var n := nom.strip_edges()
	while n.contains("  "):
		n = n.replace("  ", " ")
	return n


## Traduit la fiche en valeurs directement utilisables par l'apparence 3D
## (couleurs, nombres, arme…).
static func resoudre(fiche: Dictionary, catalogue: Dictionary) -> Dictionary:
	var f := valider(fiche, catalogue)
	var tenue := _trouver(catalogue.get("tenues", []), f["tenue"])
	var classe := _trouver(catalogue.get("classes", []), f["classe"])
	return {
		"sexe": f["sexe"],
		"taille_cm": float(f["corps"].get("taille_cm", 175.0)),
		"corpulence": float(f["corps"].get("corpulence", 0.0)),
		"musculature": float(f["corps"].get("musculature", 0.0)),
		"visage": f["visage"],
		"peau": _couleur(catalogue.get("peaux", []), f["peau"], Color(0.8, 0.62, 0.5)),
		"yeux": _couleur(catalogue.get("couleurs_yeux", []), f["couleur_yeux"], Color(0.3, 0.2, 0.1)),
		"cheveux": _couleur(catalogue.get("couleurs_cheveux", []), f["couleur_cheveux"], Color(0.15, 0.1, 0.08)),
		"coiffure": f["coiffure"],
		"pilosite": f["pilosite"],
		"veste": Color.from_string(String(tenue.get("veste", "#262f42")), Color(0.15, 0.19, 0.26)),
		"pantalon": Color.from_string(String(tenue.get("pantalon", "#1c1c21")), Color(0.11, 0.11, 0.13)),
		"insigne": Color.from_string(String(tenue.get("insigne", "#40d9e6")), Color(0.25, 0.85, 0.9)),
		"manteau": bool(tenue.get("manteau", false)),
		"arme": String(classe.get("arme", "epee")),
	}


## Valeur totale d'un bonus d'origine (par exemple « cout_esquive_pourcent »).
static func bonus(fiche: Dictionary, catalogue: Dictionary, type: String) -> float:
	var origine := _trouver(catalogue.get("origines", []), String(fiche.get("origine", "")))
	var b: Dictionary = origine.get("bonus", {})
	return float(b.get("valeur", 0.0)) if b.get("type", "") == type else 0.0


## Un élément du catalogue par son identifiant (par ex. element(c, "classes", "lame")).
static func element(catalogue: Dictionary, liste: String, id: String) -> Dictionary:
	return _trouver(catalogue.get(liste, []), id)


## Un personnage tiré au hasard (le nom et la classe sont gardés).
static func au_hasard(catalogue: Dictionary, base: Dictionary) -> Dictionary:
	var f := valider(base, catalogue)
	for champ in [["peau", "peaux"], ["couleur_yeux", "couleurs_yeux"], ["coiffure", "coiffures"],
			["couleur_cheveux", "couleurs_cheveux"], ["tenue", "tenues"]]:
		var liste: Array = catalogue.get(champ[1], [])
		if not liste.is_empty():
			f[champ[0]] = liste.pick_random()["id"]
	f["pilosite"] = "aucune"
	if f["sexe"] == "homme" and randf() < 0.5:
		f["pilosite"] = (catalogue.get("pilosites", []) as Array).pick_random()["id"]
	for curseur in catalogue.get("visage", []):
		f["visage"][curseur["id"]] = snappedf(clampf(randfn(0.0, 0.4), -1.0, 1.0), 0.05)
	f["corps"]["corpulence"] = snappedf(clampf(randfn(0.0, 0.35), -1.0, 1.0), 0.05)
	f["corps"]["musculature"] = snappedf(clampf(randfn(0.0, 0.35), -1.0, 1.0), 0.05)
	var sexe := _trouver(catalogue.get("sexes", []), f["sexe"])
	f["corps"]["taille_cm"] = roundf(float(sexe.get("taille_par_defaut", 175)) + randfn(0.0, 6.0))
	return valider(f, catalogue)


# --- Sauvegarde (dans le profil actif : voir Profil et l'autoload Compte) ----

static func existe() -> bool:
	return FileAccess.file_exists(Profil.chemin(FICHIER))


## La fiche sauvegardée sur ce PC, ou un dictionnaire vide s'il n'y en a pas.
static func charger(catalogue: Dictionary) -> Dictionary:
	if not existe():
		return {}
	var donnees = JSON.parse_string(FileAccess.get_file_as_string(Profil.chemin(FICHIER)))
	if not donnees is Dictionary:
		return {}
	return valider(donnees, catalogue)


static func sauvegarder(fiche: Dictionary) -> Error:
	var fichier := FileAccess.open(Profil.chemin(FICHIER), FileAccess.WRITE)
	if fichier == null:
		return FileAccess.get_open_error()
	fichier.store_string(JSON.stringify(fiche, "\t"))
	return OK


static func effacer() -> void:
	if existe():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profil.chemin(FICHIER)))


# --- Outils internes ----------------------------------------------------------

static func _trouver(liste: Array, id: String) -> Dictionary:
	for e in liste:
		if e is Dictionary and e.get("id") == id:
			return e
	return {}


static func _premier_id(liste: Array, defaut: String) -> String:
	if not _trouver(liste, defaut).is_empty():
		return defaut
	return String(liste[0]["id"]) if not liste.is_empty() else defaut


static func _borner(valeur: float, curseur: Dictionary) -> float:
	if is_nan(valeur) or is_inf(valeur):
		return 0.0
	return clampf(valeur, float(curseur.get("min", -1.0)), float(curseur.get("max", 1.0)))


static func _couleur(liste: Array, id: String, defaut: Color) -> Color:
	return Color.from_string(String(_trouver(liste, id).get("couleur", "")), defaut)
