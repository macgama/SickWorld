class_name Objets
extends RefCounted
## Règles de l'inventaire, de l'équipement et des tenues de mission.
##
## Tout ici travaille sur un simple dictionnaire « état d'inventaire » :
##   {
##     "cases": [ {"id": "croc_loup", "n": 3}, {}, … ],   # une entrée par place de sac ({} = vide)
##     "sacs": ["besace_peau_loup", "", "", ""],           # les sacs portés en plus du sac de départ
##     "equipement": {"tete": "capuche_chasseur", …},     # ce que le personnage porte
##     "barre": ["taille_rapide", …],                      # les 8 compétences de la barre
##     "tenues": [ {"nom": "…", "equipement": {…}, "barre": […]}, {}, … ]
##   }
## Le catalogue (« cat ») est le contenu de data/objets.json (Donnees.objets).
##
## Ce sont des fonctions sans effet de bord sur la scène : le serveur les appelle
## pour décider, le joueur pour afficher, et les tests pour vérifier.

const EMPLACEMENTS := ["tete", "torse", "mains", "jambes", "pieds",
	"arme_principale", "arme_secondaire", "bijou_1", "bijou_2", "relique"]
const NOMS_EMPLACEMENTS := {
	"tete": "Tête", "torse": "Torse", "mains": "Mains", "jambes": "Jambes", "pieds": "Pieds",
	"arme_principale": "Arme principale", "arme_secondaire": "Arme secondaire",
	"bijou_1": "Bijou", "bijou_2": "Bijou", "relique": "Relique d'époque",
}
const STATS := ["pv", "degats_pourcent", "reduction_pourcent", "critique_pourcent"]
const NOMS_STATS := {
	"pv": "Points de vie", "degats_pourcent": "Dégâts", "reduction_pourcent": "Protection",
	"critique_pourcent": "Coups critiques",
}
## Les emplacements de la barre réservés aux compétences d'époque (touches 6 et 7) et à l'ultime (8).
const CASES_EPOQUE := [5, 6]
const CASE_ULTIME := 7


# --- Lecture du catalogue -----------------------------------------------------

static func objet(cat: Dictionary, id: String) -> Dictionary:
	return (cat.get("objets", {}) as Dictionary).get(id, {})


static func existe(cat: Dictionary, id: String) -> bool:
	return id != "" and (cat.get("objets", {}) as Dictionary).has(id)


static func reglage(cat: Dictionary, cle: String, defaut = null):
	return (cat.get("inventaire", {}) as Dictionary).get(cle, defaut)


static func pile_max(cat: Dictionary, id: String) -> int:
	return maxi(1, int(objet(cat, id).get("pile", 1)))


static func couleur_rarete(cat: Dictionary, id: String) -> Color:
	var rarete := String(objet(cat, id).get("rarete", "commun"))
	var r: Dictionary = (cat.get("raretes", {}) as Dictionary).get(rarete, {})
	return Color.from_string(String(r.get("couleur", "#e6e6e6")), Color.WHITE)


## Emplacement où va un objet (bijou_1 ou bijou_2 pour un bijou), "" si on ne peut pas l'équiper.
static func emplacement_pour(cat: Dictionary, etat: Dictionary, id: String) -> String:
	var o := objet(cat, id)
	if String(o.get("type", "")) != "equipement":
		return ""
	var e := String(o.get("emplacement", ""))
	if e == "bijou":
		var porte: Dictionary = etat.get("equipement", {})
		if String(porte.get("bijou_1", "")) == "":
			return "bijou_1"
		if String(porte.get("bijou_2", "")) == "":
			return "bijou_2"
		return "bijou_1"
	return e if e in EMPLACEMENTS else ""


static func peut_aller_dans(cat: Dictionary, id: String, emplacement: String) -> bool:
	var e := String(objet(cat, id).get("emplacement", ""))
	if e == "bijou":
		return emplacement in ["bijou_1", "bijou_2"]
	return e == emplacement and String(objet(cat, id).get("type", "")) == "equipement"


# --- Création et vérification d'un état ---------------------------------------

static func capacite(cat: Dictionary, etat: Dictionary) -> int:
	var total := int(reglage(cat, "places_sac_de_depart", 16))
	for sac in etat.get("sacs", []):
		total += int(objet(cat, String(sac)).get("places", 0))
	return total


## Inventaire d'un nouveau personnage (data/objets.json, partie « depart »).
static func etat_de_depart(cat: Dictionary, barre_par_defaut: Array) -> Dictionary:
	var depart: Dictionary = cat.get("depart", {})
	var etat := {"cases": [], "sacs": [], "equipement": {}, "barre": [], "tenues": []}
	for e in EMPLACEMENTS:
		etat["equipement"][e] = ""
	for e in depart.get("equipement", {}):
		if e in EMPLACEMENTS and existe(cat, String(depart["equipement"][e])):
			etat["equipement"][e] = String(depart["equipement"][e])
	for i in int(reglage(cat, "emplacements_de_sacs", 4)):
		etat["sacs"].append("")
	var n := 0
	for sac in depart.get("sacs", []):
		if n < etat["sacs"].size() and String(objet(cat, String(sac)).get("type", "")) == "sac":
			etat["sacs"][n] = String(sac)
			n += 1
	for i in capacite(cat, etat):
		etat["cases"].append({})
	for b in barre_par_defaut:
		etat["barre"].append(String(b))
	for id in depart.get("objets", []):
		ajouter(cat, etat, String(id), 1)
	for i in int(reglage(cat, "tenues_max", 4)):
		etat["tenues"].append({})
	var i := 0
	for t in depart.get("tenues", []):
		if i >= etat["tenues"].size():
			break
		etat["tenues"][i] = {"nom": String(t.get("nom", "Tenue %d" % (i + 1))),
				"equipement": (etat["equipement"] as Dictionary).duplicate(),
				"barre": (etat["barre"] as Array).duplicate()}
		i += 1
	return etat


## Remet d'aplomb un état lu dans une sauvegarde : objets inconnus retirés,
## tailles corrigées, barre valide. Ne fait jamais confiance au fichier.
static func valider(cat: Dictionary, etat, barre_par_defaut: Array, competences: Dictionary) -> Dictionary:
	if not etat is Dictionary or not (etat as Dictionary).has("cases"):
		return etat_de_depart(cat, barre_par_defaut)
	var propre := {"cases": [], "sacs": [], "equipement": {}, "barre": [], "tenues": []}
	var sacs_lus: Array = etat.get("sacs", []) if etat.get("sacs") is Array else []
	for i in int(reglage(cat, "emplacements_de_sacs", 4)):
		var s := String(sacs_lus[i]) if i < sacs_lus.size() else ""
		propre["sacs"].append(s if String(objet(cat, s).get("type", "")) == "sac" else "")
	var porte: Dictionary = etat.get("equipement", {}) if etat.get("equipement") is Dictionary else {}
	for e in EMPLACEMENTS:
		var id := String(porte.get(e, ""))
		propre["equipement"][e] = id if peut_aller_dans(cat, id, e) else ""
	var cases_lues: Array = etat.get("cases", []) if etat.get("cases") is Array else []
	for i in capacite(cat, propre):
		var c = cases_lues[i] if i < cases_lues.size() else {}
		if c is Dictionary and existe(cat, String(c.get("id", ""))):
			var id := String(c["id"])
			propre["cases"].append({"id": id, "n": clampi(int(c.get("n", 1)), 1, pile_max(cat, id))})
		else:
			propre["cases"].append({})
	propre["barre"] = barre_valide(cat, etat.get("barre", []), barre_par_defaut, competences)
	var tenues_lues: Array = etat.get("tenues", []) if etat.get("tenues") is Array else []
	for i in int(reglage(cat, "tenues_max", 4)):
		var t = tenues_lues[i] if i < tenues_lues.size() else {}
		if t is Dictionary and t.has("equipement"):
			var eq := {}
			for e in EMPLACEMENTS:
				var id := String((t["equipement"] as Dictionary).get(e, "")) if t["equipement"] is Dictionary else ""
				eq[e] = id if peut_aller_dans(cat, id, e) else ""
			propre["tenues"].append({"nom": String(t.get("nom", "Tenue %d" % (i + 1))).left(24),
					"equipement": eq,
					"barre": barre_valide(cat, t.get("barre", []), propre["barre"], competences)})
		else:
			propre["tenues"].append({})
	return propre


## Une barre est valide si les cases 1 à 5 restent celles de la classe, les cases 6-7
## sont des compétences d'époque différentes et la case 8 une ultime.
static func barre_valide(cat: Dictionary, barre, par_defaut: Array, competences: Dictionary) -> Array:
	var resultat: Array = []
	for i in 8:
		var defaut := String(par_defaut[i]) if i < par_defaut.size() else ""
		var id := String(barre[i]) if barre is Array and i < barre.size() else defaut
		if i in CASES_EPOQUE:
			if not id in cat.get("competences_d_epoque", []) or not competences.has(id) or id in resultat:
				id = defaut if not defaut in resultat else ""
		elif i == CASE_ULTIME:
			if not id in cat.get("ultimes", []) or not competences.has(id):
				id = defaut
		else:
			id = defaut
		resultat.append(id)
	return resultat


# --- Sacs ---------------------------------------------------------------------

## Ajoute « n » objets (en complétant les piles existantes). Renvoie combien n'ont pas trouvé de place.
static func ajouter(cat: Dictionary, etat: Dictionary, id: String, n: int) -> int:
	if not existe(cat, id):
		return n
	var cases: Array = etat["cases"]
	var pile := pile_max(cat, id)
	if pile > 1:
		for c in cases:
			if n <= 0:
				break
			if String(c.get("id", "")) == id and int(c["n"]) < pile:
				var ajout := mini(n, pile - int(c["n"]))
				c["n"] = int(c["n"]) + ajout
				n -= ajout
	for i in cases.size():
		if n <= 0:
			break
		if (cases[i] as Dictionary).is_empty():
			var ajout := mini(n, pile)
			cases[i] = {"id": id, "n": ajout}
			n -= ajout
	return n


static func places_libres(etat: Dictionary) -> int:
	var libres := 0
	for c in etat["cases"]:
		if (c as Dictionary).is_empty():
			libres += 1
	return libres


static func premiere_case_libre(etat: Dictionary) -> int:
	var cases: Array = etat["cases"]
	for i in cases.size():
		if (cases[i] as Dictionary).is_empty():
			return i
	return -1


static func trouver(etat: Dictionary, id: String) -> int:
	var cases: Array = etat["cases"]
	for i in cases.size():
		if String((cases[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


static func jeter(etat: Dictionary, index: int) -> String:
	var cases: Array = etat["cases"]
	if index < 0 or index >= cases.size() or (cases[index] as Dictionary).is_empty():
		return "Rien à jeter"
	cases[index] = {}
	return ""


## Range les sacs : les objets sont regroupés au début, dans l'ordre.
static func tasser(etat: Dictionary) -> void:
	var cases: Array = etat["cases"]
	var pleins := cases.filter(func(c): return not (c as Dictionary).is_empty())
	for i in cases.size():
		cases[i] = pleins[i] if i < pleins.size() else {}


static func _redimensionner(cat: Dictionary, etat: Dictionary) -> void:
	var cases: Array = etat["cases"]
	var cible := capacite(cat, etat)
	while cases.size() < cible:
		cases.append({})
	while cases.size() > cible:
		cases.pop_back()


# --- Équipement ---------------------------------------------------------------

## Clic sur un objet des sacs : on l'équipe (ou on l'accroche comme sac).
static func utiliser(cat: Dictionary, etat: Dictionary, index: int) -> String:
	var cases: Array = etat["cases"]
	if index < 0 or index >= cases.size() or (cases[index] as Dictionary).is_empty():
		return "Case vide"
	var id := String(cases[index]["id"])
	match String(objet(cat, id).get("type", "")):
		"equipement":
			return equiper_dans(cat, etat, index, emplacement_pour(cat, etat, id))
		"sac":
			return accrocher_sac(cat, etat, index)
	return "Matériau d'artisanat : apporte-le à la forge Hinode ou à l'atelier Fil & Fibre (Quartier des Artisans)"


## Met l'objet de la case « index » dans l'emplacement donné. L'ancien objet prend sa place dans le sac.
static func equiper_dans(cat: Dictionary, etat: Dictionary, index: int, emplacement: String) -> String:
	var cases: Array = etat["cases"]
	if index < 0 or index >= cases.size() or (cases[index] as Dictionary).is_empty():
		return "Case vide"
	var id := String(cases[index]["id"])
	if not peut_aller_dans(cat, id, emplacement):
		return "Ne va pas à cet emplacement"
	var ancien := String(etat["equipement"].get(emplacement, ""))
	etat["equipement"][emplacement] = id
	cases[index] = {"id": ancien, "n": 1} if ancien != "" else {}
	return ""


## Retire l'objet porté à un emplacement et le range dans les sacs.
static func retirer(cat: Dictionary, etat: Dictionary, emplacement: String) -> String:
	var id := String(etat["equipement"].get(emplacement, ""))
	if id == "":
		return "Rien à retirer"
	var libre := premiere_case_libre(etat)
	if libre < 0:
		return "Tes sacs sont pleins"
	etat["cases"][libre] = {"id": id, "n": 1}
	etat["equipement"][emplacement] = ""
	return ""


static func accrocher_sac(cat: Dictionary, etat: Dictionary, index: int) -> String:
	var id := String(etat["cases"][index]["id"])
	var sacs: Array = etat["sacs"]
	var place := sacs.find("")
	if place < 0:
		# Tous les emplacements sont pris : on remplace le plus petit sac s'il est vide… trop compliqué
		# pour un clic. On demande de retirer un sac d'abord.
		return "Tous les emplacements de sacs sont pris"
	sacs[place] = id
	etat["cases"][index] = {}
	_redimensionner(cat, etat)
	return ""


## Décroche un sac : possible seulement s'il reste assez de place pour tout ranger (sac compris).
static func decrocher_sac(cat: Dictionary, etat: Dictionary, place: int) -> String:
	var sacs: Array = etat["sacs"]
	if place < 0 or place >= sacs.size() or String(sacs[place]) == "":
		return "Pas de sac ici"
	var id := String(sacs[place])
	var objets := (etat["cases"] as Array).filter(func(c): return not (c as Dictionary).is_empty()).size()
	var apres := capacite(cat, etat) - int(objet(cat, id).get("places", 0))
	if objets + 1 > apres:
		return "Vide un peu tes sacs avant de retirer celui-ci"
	tasser(etat)
	sacs[place] = ""
	_redimensionner(cat, etat)
	etat["cases"][premiere_case_libre(etat)] = {"id": id, "n": 1}
	return ""


## Ce qui se voit sur le personnage : emplacement -> visuel (forme, couleur, teinte).
static func visuels(cat: Dictionary, equipement: Dictionary) -> Dictionary:
	var resultat := {}
	for e in equipement:
		var o := objet(cat, String(equipement[e]))
		if o.has("visuel"):
			resultat[e] = o["visuel"]
	return resultat


## Image de l'objet (interface/icones/<id>.png), ou null s'il n'y en a pas encore.
static func icone(id: String) -> Texture2D:
	var chemin := "res://interface/icones/%s.png" % id
	if id == "" or not ResourceLoader.exists(chemin):
		return null
	return load(chemin) as Texture2D


# --- Bonus ---------------------------------------------------------------------

## Additionne tout ce que donne l'équipement porté :
## { "stats": {pv, degats_pourcent…}, "competences": {id: {cle: ajout}},
##   "ensembles": {id: nombre de pièces}, "paliers": [textes des bonus actifs] }
static func bonus(cat: Dictionary, equipement: Dictionary) -> Dictionary:
	var stats := {}
	for s in STATS:
		stats[s] = 0.0
	var competences := {}
	var ensembles := {}
	var paliers: Array = []
	for e in EMPLACEMENTS:
		var o := objet(cat, String(equipement.get(e, "")))
		if o.is_empty():
			continue
		_ajouter_stats(stats, o.get("stats", {}))
		_ajouter_competences(competences, o.get("competences", {}))
		if o.has("ensemble"):
			ensembles[o["ensemble"]] = int(ensembles.get(o["ensemble"], 0)) + 1
	for id in ensembles:
		var ens: Dictionary = (cat.get("ensembles", {}) as Dictionary).get(id, {})
		var p: Dictionary = ens.get("paliers", {})
		for seuil in p:
			if int(ensembles[id]) >= int(seuil):
				_ajouter_stats(stats, p[seuil].get("stats", {}))
				_ajouter_competences(competences, p[seuil].get("competences", {}))
				paliers.append("%s (%s) : %s" % [ens.get("nom", id), seuil, p[seuil].get("texte", "")])
	return {"stats": stats, "competences": competences, "ensembles": ensembles, "paliers": paliers}


static func _ajouter_stats(total: Dictionary, ajout) -> void:
	if ajout is Dictionary:
		for s in ajout:
			if total.has(s):
				total[s] = float(total[s]) + float(ajout[s])


static func _ajouter_competences(total: Dictionary, ajout) -> void:
	if not ajout is Dictionary:
		return
	for id in ajout:
		if not total.has(id):
			total[id] = {}
		for cle in ajout[id]:
			total[id][cle] = float(total[id].get(cle, 0.0)) + float(ajout[id][cle])


## Copie d'une compétence avec les bonus d'équipement ajoutés.
## « ralenti.duree » modifie la clé « duree » du sous-dictionnaire « ralenti ».
static func competence_modifiee(base: Dictionary, modifs) -> Dictionary:
	if not modifs is Dictionary or (modifs as Dictionary).is_empty():
		return base
	var c := base.duplicate(true)
	for cle in modifs:
		var parties := String(cle).split(".")
		var conteneur: Dictionary = c
		for i in parties.size() - 1:
			if not conteneur.get(parties[i]) is Dictionary:
				conteneur = {}
				break
			conteneur = conteneur[parties[i]]
		var nom := parties[parties.size() - 1]
		if conteneur.has(nom):
			conteneur[nom] = maxf(0.0, float(conteneur[nom]) + float(modifs[cle]))
	return c


# --- Tenues de mission -------------------------------------------------------

static func enregistrer_tenue(cat: Dictionary, etat: Dictionary, numero: int, nom: String) -> String:
	var tenues: Array = etat["tenues"]
	if numero < 0 or numero >= tenues.size():
		return "Tenue inconnue"
	nom = nom.strip_edges().left(24)
	if nom == "":
		nom = String((tenues[numero] as Dictionary).get("nom", "Tenue %d" % (numero + 1)))
	tenues[numero] = {"nom": nom, "equipement": (etat["equipement"] as Dictionary).duplicate(),
			"barre": (etat["barre"] as Array).duplicate()}
	return ""


## Ce qu'il faut pour mettre une tenue : "" si possible, sinon la raison.
static func raison_tenue_impossible(cat: Dictionary, etat: Dictionary, numero: int) -> String:
	var tenues: Array = etat["tenues"]
	if numero < 0 or numero >= tenues.size() or (tenues[numero] as Dictionary).is_empty():
		return "Cette tenue n'est pas encore enregistrée"
	return ""


## Met la tenue : chaque emplacement prend l'objet prévu s'il est dans les sacs.
## Renvoie la liste des objets introuvables (pour prévenir le joueur).
static func mettre_tenue(cat: Dictionary, etat: Dictionary, numero: int) -> Array:
	var tenue: Dictionary = etat["tenues"][numero]
	var voulu: Dictionary = tenue["equipement"]
	var manquants: Array = []
	for e in EMPLACEMENTS:
		var id := String(voulu.get(e, ""))
		var actuel := String(etat["equipement"].get(e, ""))
		if id == actuel:
			continue
		if id == "":
			retirer(cat, etat, e)
			continue
		var ailleurs := _emplacement_portant(etat, id, e)
		if ailleurs != "":
			# Déjà porté ailleurs (ex. bijou à gauche au lieu de droite) : on échange.
			etat["equipement"][ailleurs] = actuel
			etat["equipement"][e] = id
			continue
		var index := trouver(etat, id)
		if index < 0:
			manquants.append(String(objet(cat, id).get("nom", id)))
			continue
		equiper_dans(cat, etat, index, e)
	etat["barre"] = (tenue["barre"] as Array).duplicate()
	return manquants


static func _emplacement_portant(etat: Dictionary, id: String, sauf: String) -> String:
	for e in EMPLACEMENTS:
		if e != sauf and String(etat["equipement"].get(e, "")) == id:
			return e
	return ""


## Change une compétence d'époque (cases 6-7) ou l'ultime (case 8).
static func changer_competence(cat: Dictionary, etat: Dictionary, index: int, id: String) -> String:
	var barre: Array = etat["barre"]
	if index in CASES_EPOQUE:
		if not id in cat.get("competences_d_epoque", []):
			return "Ce n'est pas une compétence d'époque"
		var autre := CASES_EPOQUE[1] if index == CASES_EPOQUE[0] else CASES_EPOQUE[0]
		if String(barre[autre]) == id:
			barre[autre] = barre[index]
		barre[index] = id
		return ""
	if index == CASE_ULTIME:
		if not id in cat.get("ultimes", []):
			return "Ce n'est pas une compétence ultime"
		barre[index] = id
		return ""
	return "Les compétences 1 à 5 sont celles de ta classe"


# --- Butin -------------------------------------------------------------------

## Tire le butin d'un ennemi : liste de {"id", "n"}.
static func tirer_butin(cat: Dictionary, type_ennemi: String, hasard: RandomNumberGenerator) -> Array:
	var table: Array = (cat.get("butin", {}) as Dictionary).get(type_ennemi, [])
	var resultat: Array = []
	for ligne in table:
		if hasard.randf() >= float(ligne.get("chance", 0.0)):
			continue
		var id := String(ligne.get("objet", ""))
		if ligne.has("parmi"):
			var choix: Array = ligne["parmi"]
			if choix.is_empty():
				continue
			id = String(choix[hasard.randi_range(0, choix.size() - 1)])
		if not existe(cat, id):
			continue
		var n := 1
		var q = ligne.get("quantite", 1)
		if q is Array and q.size() == 2:
			n = hasard.randi_range(int(q[0]), int(q[1]))
		else:
			n = int(q)
		resultat.append({"id": id, "n": maxi(1, n)})
	return resultat


## Texte d'aide (infobulle) d'un objet.
static func description(cat: Dictionary, id: String) -> String:
	var o := objet(cat, id)
	if o.is_empty():
		return ""
	var r: Dictionary = (cat.get("raretes", {}) as Dictionary).get(String(o.get("rarete", "commun")), {})
	var lignes: Array[String] = [String(o.get("nom", id))]
	var genre := ""
	match String(o.get("type", "")):
		"equipement":
			var e := String(o.get("emplacement", ""))
			genre = "Bijou" if e == "bijou" else String(NOMS_EMPLACEMENTS.get(e, e))
		"sac":
			genre = "Sac (%d places)" % int(o.get("places", 0))
		"materiau":
			genre = "Matériau"
	lignes.append("%s — %s — %s" % [r.get("nom", ""), genre, o.get("epoque", "")])
	var stats: Dictionary = o.get("stats", {})
	for s in STATS:
		if float(stats.get(s, 0)) != 0.0:
			var v := float(stats[s])
			lignes.append(("+%d %s" if s == "pv" else "+%d %% %s") % [v, String(NOMS_STATS[s]).to_lower()])
	if o.has("ensemble"):
		var ens: Dictionary = (cat.get("ensembles", {}) as Dictionary).get(String(o["ensemble"]), {})
		lignes.append("Ensemble : %s" % ens.get("nom", ""))
		var p: Dictionary = ens.get("paliers", {})
		for seuil in p:
			lignes.append("  %s pièces : %s" % [seuil, p[seuil].get("texte", "")])
	lignes.append("")
	lignes.append(String(o.get("description", "")))
	return "\n".join(lignes)
