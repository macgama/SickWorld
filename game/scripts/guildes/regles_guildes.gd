extends RefCounted
## Règles des GUILDES : membres et rangs, banque, niveau, contrats de la semaine.
##
## Comme Objets ou Artisanat, ce sont des fonctions sans effet sur la scène, qui
## travaillent sur une « guilde » (un dictionnaire). Le serveur les appelle pour
## décider (autoload Guildes), et les tests pour vérifier.
##   d : les réglages (data/guildes.json)
##   g : une guilde :
##     {nom, cle (nom en minuscules), couleur (n° dans d.couleurs), fondee (date),
##      membres: {cle_nom: {nom, rang, depuis, vu, total, semaine, retraits: {jour, n}}},
##      xp, banque: [ {} ou {id, n}, … ], journal: [ {t, texte}, … ], message,
##      contrats: {semaine, membres, liste: [ {id, titre, texte, type, nombre, compte, fini} ],
##                 aides: {"0": {cle_nom: n}, …}, semaine_complete},
##      a_donner: {cle_nom: [ {id, n}, … ]}}

const FICHIER := "res://data/guildes.json"


static func donnees() -> Dictionary:
	var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
	if not lu is Dictionary:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % FICHIER)
		return {}
	return lu


static func reglage(d: Dictionary, cle: String, defaut = 0):
	return (d.get("reglages", {}) as Dictionary).get(cle, defaut)


static func cle(nom: String) -> String:
	return nom.strip_edges().to_lower()


# --- Nom et couleur -------------------------------------------------------------------

## "" si le nom convient, sinon la raison. « pris » : les noms des guildes existantes.
static func raison_nom(d: Dictionary, nom: String, pris: Array) -> String:
	nom = nom.strip_edges()
	var mini := int(reglage(d, "nom_min", 3))
	var maxi := int(reglage(d, "nom_max", 24))
	if nom.length() < mini:
		return "Le nom doit faire au moins %d lettres." % mini
	if nom.length() > maxi:
		return "Le nom doit faire %d lettres au plus." % maxi
	for i in nom.length():
		var c := nom.unicode_at(i)
		if c < 32 or c == 127 or nom[i] in ["[", "]", "{", "}", "<", ">", "\\", "/", "|"]:
			return "Le nom contient un caractère interdit (%s)." % nom[i]
	for reserve in d.get("noms_reserves", []):
		if cle(String(reserve)) == cle(nom):
			return "Ce nom est déjà pris par une guilde de la ville."
	for p in pris:
		if cle(String(p)) == cle(nom):
			return "Ce nom est déjà pris par une autre guilde."
	return ""


static func nombre_couleurs(d: Dictionary) -> int:
	return maxi(1, (d.get("couleurs", []) as Array).size())


static func couleur(d: Dictionary, n: int) -> Color:
	var liste: Array = d.get("couleurs", [])
	if liste.is_empty():
		return Color(0.5, 0.12, 0.35)
	return Color.html(String(liste[clampi(n, 0, liste.size() - 1)][1]))


# --- Création et membres ---------------------------------------------------------------

static func nouvelle(d: Dictionary, nom: String, numero_couleur: int, fondateur: String, t: int) -> Dictionary:
	var g := {"nom": nom.strip_edges(), "cle": cle(nom), "couleur": clampi(numero_couleur, 0, nombre_couleurs(d) - 1),
			"fondee": t, "membres": {}, "xp": 0, "banque": [], "journal": [], "message": "",
			"contrats": {}, "a_donner": {}}
	ajuster_banque(d, g)
	ajouter_membre(d, g, fondateur, "maitre", t)
	noter(d, g, "%s fonde la guilde « %s »." % [fondateur, g["nom"]], t)
	return g


static func ajouter_membre(_d: Dictionary, g: Dictionary, nom: String, rang: String, t: int) -> void:
	g["membres"][cle(nom)] = {"nom": nom, "rang": rang, "depuis": t, "vu": t, "total": 0, "semaine": 0,
			"retraits": {"jour": 0, "n": 0}}


static func est_membre(g: Dictionary, nom: String) -> bool:
	return (g.get("membres", {}) as Dictionary).has(cle(nom))


static func membre(g: Dictionary, nom: String) -> Dictionary:
	return (g.get("membres", {}) as Dictionary).get(cle(nom), {})


static func nombre_membres(g: Dictionary) -> int:
	return (g.get("membres", {}) as Dictionary).size()


static func rangs(d: Dictionary) -> Array:
	return d.get("rangs", [])


## Position du rang : 0 = maître (le plus haut). Un rang inconnu compte comme le plus bas.
static func ordre(d: Dictionary, rang: String) -> int:
	var liste := rangs(d)
	for i in liste.size():
		if String(liste[i].get("id", "")) == rang:
			return i
	return maxi(0, liste.size() - 1)


static func infos_rang(d: Dictionary, rang: String) -> Dictionary:
	var liste := rangs(d)
	if liste.is_empty():
		return {}
	return liste[ordre(d, rang)]


static func nom_rang(d: Dictionary, rang: String) -> String:
	return String(infos_rang(d, rang).get("nom", rang))


## Le rang a-t-il ce droit (inviter, exclure, promouvoir, message) ?
static func peut(d: Dictionary, rang: String, droit: String) -> bool:
	return bool(infos_rang(d, rang).get(droit, false))


static func rang_de(g: Dictionary, nom: String) -> String:
	return String(membre(g, nom).get("rang", ""))


static func maitre(g: Dictionary) -> String:
	for c in g.get("membres", {}):
		if String(g["membres"][c].get("rang", "")) == "maitre":
			return String(g["membres"][c]["nom"])
	return ""


## « acteur » peut-il agir sur « cible » (exclure, rétrograder) ? Il faut un rang plus haut.
static func au_dessus(d: Dictionary, g: Dictionary, acteur: String, cible: String) -> bool:
	return est_membre(g, acteur) and est_membre(g, cible) \
			and ordre(d, rang_de(g, acteur)) < ordre(d, rang_de(g, cible))


## Monte (sens = -1) ou descend (sens = +1) un membre d'un rang. "" si c'est fait.
## On ne peut pas nommer maître ainsi (voir nommer_maitre), ni monter quelqu'un à son propre rang
## (sauf le maître, qui nomme des officiers).
static func changer_rang(d: Dictionary, g: Dictionary, acteur: String, cible: String, sens: int, t: int) -> String:
	if not est_membre(g, cible):
		return "%s n'est pas dans la guilde." % cible
	if not peut(d, rang_de(g, acteur), "promouvoir"):
		return "Ton rang ne permet pas de changer les rangs."
	if not au_dessus(d, g, acteur, cible):
		return "Tu ne peux changer que le rang des membres en dessous de toi."
	var liste := rangs(d)
	var actuel := ordre(d, rang_de(g, cible))
	var nouveau := clampi(actuel + sens, 1, liste.size() - 1)
	if nouveau == actuel:
		return "%s est déjà %s." % [membre(g, cible)["nom"], "au rang le plus haut possible" if sens < 0 else "au rang le plus bas"]
	if sens < 0 and nouveau <= ordre(d, rang_de(g, acteur)) and rang_de(g, acteur) != "maitre":
		return "Tu ne peux pas nommer quelqu'un à ton propre rang."
	var m: Dictionary = g["membres"][cle(cible)]
	m["rang"] = String(liste[nouveau]["id"])
	noter(d, g, "%s %s %s : %s." % [acteur, "promeut" if sens < 0 else "rétrograde", m["nom"], nom_rang(d, m["rang"])], t)
	return ""


## Le maître donne sa place : il devient officier.
static func nommer_maitre(d: Dictionary, g: Dictionary, acteur: String, cible: String, t: int) -> String:
	if rang_de(g, acteur) != "maitre":
		return "Seul le maître de guilde peut transmettre sa place."
	if not est_membre(g, cible) or cle(cible) == cle(acteur):
		return "Choisis un autre membre de la guilde."
	g["membres"][cle(acteur)]["rang"] = "officier" if ordre(d, "officier") < rangs(d).size() else "membre"
	g["membres"][cle(cible)]["rang"] = "maitre"
	noter(d, g, "%s transmet la guilde à %s, nouveau maître de guilde." % [acteur, g["membres"][cle(cible)]["nom"]], t)
	return ""


## Retire un membre. Si c'était le maître, le plus haut gradé (le plus ancien à rang égal) le remplace.
## Renvoie le nom du nouveau maître ("" si personne n'a changé).
static func retirer_membre(d: Dictionary, g: Dictionary, nom: String) -> String:
	var etait_maitre := rang_de(g, nom) == "maitre"
	(g["membres"] as Dictionary).erase(cle(nom))
	(g.get("a_donner", {}) as Dictionary).erase(cle(nom))
	if not etait_maitre or nombre_membres(g) == 0:
		return ""
	var meilleur := ""
	for c in g["membres"]:
		var m: Dictionary = g["membres"][c]
		if meilleur == "":
			meilleur = c
			continue
		var b: Dictionary = g["membres"][meilleur]
		var om := ordre(d, String(m["rang"]))
		var ob := ordre(d, String(b["rang"]))
		if om < ob or (om == ob and int(m["depuis"]) < int(b["depuis"])):
			meilleur = c
	g["membres"][meilleur]["rang"] = "maitre"
	return String(g["membres"][meilleur]["nom"])


# --- Niveau -----------------------------------------------------------------------------

static func niveau_max(d: Dictionary) -> int:
	return maxi(1, (d.get("niveaux", [0]) as Array).size())


static func niveau(d: Dictionary, xp: int) -> int:
	var paliers: Array = d.get("niveaux", [0])
	var n := 1
	for i in paliers.size():
		if xp >= int(paliers[i]):
			n = i + 1
	return n


## XP totale pour atteindre ce niveau.
static func xp_pour(d: Dictionary, n: int) -> int:
	var paliers: Array = d.get("niveaux", [0])
	return int(paliers[clampi(n - 1, 0, paliers.size() - 1)]) if not paliers.is_empty() else 0


## {niveau, dans_niveau, pour_niveau (0 = niveau maximum)}
static func avancement(d: Dictionary, xp: int) -> Dictionary:
	var n := niveau(d, xp)
	if n >= niveau_max(d):
		return {"niveau": n, "dans_niveau": 0, "pour_niveau": 0}
	return {"niveau": n, "dans_niveau": xp - xp_pour(d, n), "pour_niveau": xp_pour(d, n + 1) - xp_pour(d, n)}


static func membres_max(d: Dictionary, g: Dictionary) -> int:
	return int(reglage(d, "membres_max_base", 30)) + (niveau(d, int(g.get("xp", 0))) - 1) * int(reglage(d, "membres_max_par_niveau", 10))


static func places_banque(d: Dictionary, g: Dictionary) -> int:
	return int(reglage(d, "banque_places_base", 24)) + (niveau(d, int(g.get("xp", 0))) - 1) * int(reglage(d, "banque_places_par_niveau", 8))


## La banque grandit avec le niveau (jamais l'inverse : rien n'est perdu).
static func ajuster_banque(d: Dictionary, g: Dictionary) -> void:
	var banque: Array = g.get("banque", [])
	while banque.size() < places_banque(d, g):
		banque.append({})
	g["banque"] = banque


# --- Journal ----------------------------------------------------------------------------

static func noter(d: Dictionary, g: Dictionary, texte: String, t: int) -> void:
	var journal: Array = g.get("journal", [])
	journal.append({"t": t, "texte": texte})
	while journal.size() > int(reglage(d, "journal_max", 80)):
		journal.pop_front()
	g["journal"] = journal


# --- Banque -----------------------------------------------------------------------------

## Range des objets dans la banque (les piles se complètent). Renvoie ce qui n'a pas trouvé de place.
static func deposer(cat: Dictionary, d: Dictionary, g: Dictionary, id: String, n: int) -> int:
	ajuster_banque(d, g)
	return Objets.ajouter(cat, {"cases": g["banque"]}, id, n)


## Nombre d'objets que ce membre peut encore sortir aujourd'hui (-1 = sans limite).
static func retraits_restants(d: Dictionary, g: Dictionary, nom: String, jour: int) -> int:
	var m := membre(g, nom)
	if m.is_empty():
		return 0
	var limite := int(infos_rang(d, String(m["rang"])).get("retraits_par_jour", 0))
	if limite < 0:
		return -1
	var r: Dictionary = m.get("retraits", {})
	var deja := int(r.get("n", 0)) if int(r.get("jour", -1)) == jour else 0
	return maxi(0, limite - deja)


static func noter_retrait(g: Dictionary, nom: String, jour: int) -> void:
	var m: Dictionary = g["membres"][cle(nom)]
	var r: Dictionary = m.get("retraits", {})
	if int(r.get("jour", -1)) != jour:
		r = {"jour": jour, "n": 0}
	r["n"] = int(r.get("n", 0)) + 1
	m["retraits"] = r


# --- Contrats de la semaine -------------------------------------------------------------

static func contrat_modele(d: Dictionary, id: String) -> Dictionary:
	for c in d.get("contrats", []):
		if String(c.get("id", "")) == id:
			return c
	return {}


## Tire les contrats de la semaine (le même tirage tant que la semaine et la guilde ne changent pas).
## Le nombre à atteindre dépend du nombre de membres au début de la semaine.
static func tirer_contrats(d: Dictionary, g: Dictionary, semaine: int) -> Dictionary:
	var membres := clampi(nombre_membres(g), 1, int(reglage(d, "membres_comptes_max", 25)))
	var possibles: Array = []
	for c in d.get("contrats", []):
		if membres >= int(c.get("membres_min", 1)):
			possibles.append(c)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash("%s|%d" % [String(g.get("cle", "")), semaine])
	var liste: Array = []
	var nombre := mini(int(reglage(d, "contrats_par_semaine", 3)), possibles.size())
	for i in nombre:
		var c: Dictionary = possibles.pop_at(hasard.randi_range(0, possibles.size() - 1))
		liste.append({"id": c["id"], "titre": c.get("titre", c["id"]), "texte": c.get("texte", ""),
				"type": c.get("type", ""), "nombre": int(c.get("base", 10)) + int(c.get("par_membre", 0)) * (membres - 1),
				"compte": 0, "fini": false})
	return {"semaine": semaine, "membres": membres, "liste": liste, "aides": {}, "semaine_complete": false}


## Nouvelle semaine : nouveaux contrats, compteurs de la semaine remis à zéro. Vrai si ça a changé.
static func verifier_semaine(d: Dictionary, g: Dictionary, semaine: int) -> bool:
	var c: Dictionary = g.get("contrats", {})
	if not c.is_empty() and int(c.get("semaine", -1)) == semaine:
		return false
	g["contrats"] = tirer_contrats(d, g, semaine)
	for m in g.get("membres", {}).values():
		m["semaine"] = 0
	return true


## Sceaux donnés à chaque membre qui a aidé quand un contrat est accompli.
static func sceaux_par_contrat(d: Dictionary, g: Dictionary) -> int:
	return int(reglage(d, "sceaux_par_contrat", 12)) + (niveau(d, int(g.get("xp", 0))) - 1) * int(reglage(d, "sceaux_par_niveau", 1))


## Un membre fait avancer la guilde (n actions du type donné : « fracture », « recolte »…).
## Renvoie ce qui s'est passé : {xp, niveau_avant, niveau, contrats_finis: [titres], semaine_complete,
## recompenses: {cle_nom: sceaux}} (les sceaux sont aussi ajoutés à g.a_donner).
static func contribuer(d: Dictionary, g: Dictionary, nom: String, type: String, n: int, semaine: int) -> Dictionary:
	var resultat := {"xp": 0, "niveau_avant": niveau(d, int(g.get("xp", 0))), "niveau": 0,
			"contrats_finis": [], "semaine_complete": false, "recompenses": {}}
	resultat["niveau"] = resultat["niveau_avant"]
	if not est_membre(g, nom) or n <= 0:
		return resultat
	verifier_semaine(d, g, semaine)
	var m: Dictionary = g["membres"][cle(nom)]
	m["total"] = int(m.get("total", 0)) + n
	m["semaine"] = int(m.get("semaine", 0)) + n
	var xp := int((d.get("xp_par_action", {}) as Dictionary).get(type, 0)) * n
	var contrats: Dictionary = g["contrats"]
	var liste: Array = contrats["liste"]
	for i in liste.size():
		var c: Dictionary = liste[i]
		if c["fini"] or String(c["type"]) != type:
			continue
		var avant := int(c["compte"])
		c["compte"] = mini(avant + n, int(c["nombre"]))
		var aides: Dictionary = contrats["aides"].get(str(i), {})
		aides[cle(nom)] = int(aides.get(cle(nom), 0)) + (int(c["compte"]) - avant)
		contrats["aides"][str(i)] = aides
		if int(c["compte"]) >= int(c["nombre"]):
			c["fini"] = true
			xp += int(reglage(d, "xp_contrat", 400))
			resultat["contrats_finis"].append(c["titre"])
			_recompenser(d, g, aides.keys(), sceaux_par_contrat(d, g), resultat)
	if not contrats["semaine_complete"] and not liste.is_empty() and liste.all(func(c): return bool(c["fini"])):
		contrats["semaine_complete"] = true
		resultat["semaine_complete"] = true
		var tous: Array = []
		for k in contrats["aides"]:
			for qui in contrats["aides"][k]:
				if not qui in tous:
					tous.append(qui)
		_recompenser(d, g, tous, int(reglage(d, "sceaux_semaine_complete", 20)), resultat)
	g["xp"] = int(g.get("xp", 0)) + xp
	resultat["xp"] = xp
	resultat["niveau"] = niveau(d, int(g["xp"]))
	if resultat["niveau"] > resultat["niveau_avant"]:
		ajuster_banque(d, g)
	return resultat


static func _recompenser(_d: Dictionary, g: Dictionary, qui: Array, sceaux: int, resultat: Dictionary) -> void:
	var a_donner: Dictionary = g.get("a_donner", {})
	for c in qui:
		if not (g["membres"] as Dictionary).has(c) or sceaux <= 0:
			continue
		var liste: Array = a_donner.get(c, [])
		liste.append({"id": "sceau_guilde", "n": sceaux})
		a_donner[c] = liste
		resultat["recompenses"][c] = int(resultat["recompenses"].get(c, 0)) + sceaux
	g["a_donner"] = a_donner


## Le type de contribution d'un ennemi vaincu : « chef », « fracture » ou « ennemi ».
static func type_ennemi(d: Dictionary, id_ennemi: String) -> String:
	if id_ennemi in d.get("chefs", []):
		return "chef"
	for morceau in d.get("fractures", []):
		if id_ennemi.contains(String(morceau)):
			return "fracture"
	return "ennemi"
