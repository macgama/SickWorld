extends RefCounted
## Règles de l'artisanat : fabriquer et améliorer de l'équipement chez les artisans
## du hub (forge Hinode, atelier Fil & Fibre) à partir des matériaux du butin.
##
## Comme Objets, ce sont des fonctions sans effet de bord sur la scène, qui
## travaillent sur l'« état d'inventaire » (voir scripts/objets/objets.gd).
##   cat : le catalogue des objets (data/objets.json, Donnees.objets)
##   art : les recettes (data/artisanat.json, Donnees.artisanat)
## Le serveur les appelle pour décider (Inventaire, action « fabriquer »),
## la fenêtre d'artisanat pour afficher, et les tests pour vérifier.
##
## Une recette :
##   "lance_silex": {"artisan": "forge", "categorie": "armes", "donne": "lance_silex",
##                   "quantite": 1, "ingredients": {"silex": 6, "tendon_seche": 3}}
## Une amélioration est une recette dont un ingrédient est un équipement (l'objet
## à améliorer) : l'objet renforcé le remplace aussi dans les tenues de mission.

static func recette(art: Dictionary, id: String) -> Dictionary:
	return (art.get("recettes", {}) as Dictionary).get(id, {})


static func artisan(art: Dictionary, id: String) -> Dictionary:
	return (art.get("artisans", {}) as Dictionary).get(id, {})


## L'artisan qu'on trouve derrière un personnage du hub ("" si ce n'est pas un artisan).
static func artisan_du_pnj(art: Dictionary, id_pnj: String) -> String:
	var artisans: Dictionary = art.get("artisans", {})
	for a in artisans:
		if id_pnj in (artisans[a] as Dictionary).get("pnj", []):
			return String(a)
	return ""


## Les recettes d'un artisan, dans l'ordre du fichier (et d'une catégorie si on la donne).
static func recettes_de(art: Dictionary, id_artisan: String, categorie := "") -> Array:
	var resultat: Array = []
	var toutes: Dictionary = art.get("recettes", {})
	for id in toutes:
		var r: Dictionary = toutes[id]
		if String(r.get("artisan", "")) == id_artisan and (categorie == "" or String(r.get("categorie", "")) == categorie):
			resultat.append(String(id))
	return resultat


## Nombre d'exemplaires d'un objet dans les sacs (ce qui est porté ne compte pas).
static func compter(etat: Dictionary, id: String) -> int:
	var total := 0
	for c in etat.get("cases", []):
		if String((c as Dictionary).get("id", "")) == id:
			total += int(c.get("n", 1))
	return total


static func porte(etat: Dictionary, id: String) -> bool:
	return id in (etat.get("equipement", {}) as Dictionary).values()


## Ingrédients d'une recette, avec ce que le joueur possède :
## [ {"id", "faut", "a"} ] dans l'ordre du fichier.
static func ingredients(art: Dictionary, etat: Dictionary, id_recette: String) -> Array:
	var resultat: Array = []
	var ing: Dictionary = recette(art, id_recette).get("ingredients", {})
	for id in ing:
		resultat.append({"id": String(id), "faut": maxi(1, int(ing[id])), "a": compter(etat, String(id))})
	return resultat


## L'objet de base qu'améliore cette recette ("" si ce n'est pas une amélioration).
static func objet_ameliore(cat: Dictionary, art: Dictionary, id_recette: String) -> String:
	for id in recette(art, id_recette).get("ingredients", {}):
		if String(Objets.objet(cat, String(id)).get("type", "")) == "equipement":
			return String(id)
	return ""


## "" si la recette peut être fabriquée maintenant, sinon la raison (texte pour le joueur).
static func raison_impossible(cat: Dictionary, art: Dictionary, etat: Dictionary, id_recette: String) -> String:
	var r := recette(art, id_recette)
	if r.is_empty() or not Objets.existe(cat, String(r.get("donne", ""))):
		return "Recette inconnue"
	var manque: Array[String] = []
	for ing in ingredients(art, etat, id_recette):
		if int(ing["a"]) < int(ing["faut"]):
			var nom := String(Objets.objet(cat, ing["id"]).get("nom", ing["id"]))
			if int(ing["a"]) == 0 and porte(etat, ing["id"]):
				return "Tu portes « %s » : enlève cet objet pour le confier à l'artisan" % nom
			manque.append("%d × %s" % [int(ing["faut"]) - int(ing["a"]), nom])
	if not manque.is_empty():
		return "Il te manque : " + ", ".join(manque)
	var essai := etat.duplicate(true)
	_retirer_ingredients(art, essai, id_recette)
	if Objets.ajouter(cat, essai, String(r["donne"]), maxi(1, int(r.get("quantite", 1)))) > 0:
		return "Tes sacs sont pleins"
	return ""


## Fabrique : retire les ingrédients des sacs et y range l'objet fabriqué.
## Renvoie "" si c'est fait, sinon la raison (et l'état n'a pas changé).
static func fabriquer(cat: Dictionary, art: Dictionary, etat: Dictionary, id_recette: String) -> String:
	var raison := raison_impossible(cat, art, etat, id_recette)
	if raison != "":
		return raison
	var r := recette(art, id_recette)
	var donne := String(r["donne"])
	var base := objet_ameliore(cat, art, id_recette)
	_retirer_ingredients(art, etat, id_recette)
	Objets.ajouter(cat, etat, donne, maxi(1, int(r.get("quantite", 1))))
	if base != "":
		# Les tenues de mission qui prévoyaient l'ancien objet prennent le nouveau.
		for t in etat.get("tenues", []):
			var eq = (t as Dictionary).get("equipement")
			if eq is Dictionary:
				for e in eq:
					if String(eq[e]) == base:
						eq[e] = donne
	return ""


## Retire les ingrédients (en vidant d'abord les plus petites piles).
static func _retirer_ingredients(art: Dictionary, etat: Dictionary, id_recette: String) -> void:
	var cases: Array = etat["cases"]
	var ing: Dictionary = recette(art, id_recette).get("ingredients", {})
	for id in ing:
		var reste := maxi(1, int(ing[id]))
		var indices: Array = []
		for i in cases.size():
			if String((cases[i] as Dictionary).get("id", "")) == String(id):
				indices.append(i)
		indices.sort_custom(func(a, b): return int(cases[a]["n"]) < int(cases[b]["n"]))
		for i in indices:
			if reste <= 0:
				break
			var pris := mini(reste, int(cases[i]["n"]))
			cases[i]["n"] = int(cases[i]["n"]) - pris
			reste -= pris
			if int(cases[i]["n"]) <= 0:
				cases[i] = {}


## Vrai si la position est assez près d'un personnage de cet artisan.
static func artisan_proche(arbre: SceneTree, art: Dictionary, id_artisan: String, position: Vector3) -> bool:
	var pnj: Array = artisan(art, id_artisan).get("pnj", [])
	var distance := float(art.get("distance", 4.5))
	for n in arbre.get_nodes_in_group("pnj"):
		if n is Node3D and String(n.get("identifiant")) in pnj \
				and (n as Node3D).global_position.distance_to(position) <= distance:
			return true
	return false


## Matériau : liste des noms d'objets qu'il permet de fabriquer (pour les infobulles).
static func sert_a(cat: Dictionary, art: Dictionary, id_materiau: String) -> Array:
	var resultat: Array = []
	var toutes: Dictionary = art.get("recettes", {})
	for id in toutes:
		if (toutes[id].get("ingredients", {}) as Dictionary).has(id_materiau):
			var nom := String(Objets.objet(cat, String(toutes[id].get("donne", ""))).get("nom", ""))
			if nom != "" and not nom in resultat:
				resultat.append(nom)
	return resultat
