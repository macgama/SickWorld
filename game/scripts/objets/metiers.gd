extends RefCounted
## Règles des métiers de récolte : Cueillette, Minage et Pêche.
##
## Comme Objets et l'artisanat, ce sont des fonctions sans effet de bord sur la scène.
## Elles travaillent sur :
##   rec : le contenu de data/recolte.json (Donnees.recolte) — métiers, paliers, sources, zones
##   etat : l'« état d'inventaire » (voir objets.gd), qui garde aussi l'expérience
##          de chaque métier : etat["metiers"] = {"cueillette": 125, "minage": 40, "peche": 0}
##
## Une « source » est un type de point de récolte (un banc de saumons, un affleurement
## de silex…) : son métier, le niveau qu'il faut, ce qu'elle donne.
## Les points eux-mêmes (où se trouvent les sources) sont listés par zone dans
## data/recolte.json (« zones »), et posés par scripts/monde/recolte.gd.

const METIERS := ["cueillette", "minage", "peche"]


static func metier(rec: Dictionary, id: String) -> Dictionary:
	return (rec.get("metiers", {}) as Dictionary).get(id, {})


static func source(rec: Dictionary, id: String) -> Dictionary:
	return (rec.get("sources", {}) as Dictionary).get(id, {})


static func reglage(rec: Dictionary, cle: String, defaut = null):
	return (rec.get("reglages", {}) as Dictionary).get(cle, defaut)


## Les points de récolte d'une zone : [ {"source", "x", "z"} ] dans l'ordre du fichier.
## Le numéro d'un point (son index dans cette liste) sert aux échanges réseau.
static func points_de_zone(rec: Dictionary, zone: String) -> Array:
	var resultat: Array = []
	for p in (rec.get("zones", {}) as Dictionary).get(zone, []):
		if p is Array and p.size() >= 3 and not source(rec, String(p[0])).is_empty():
			resultat.append({"source": String(p[0]), "x": float(p[1]), "z": float(p[2])})
	return resultat


# --- Niveaux et expérience -----------------------------------------------------

static func experience(etat: Dictionary, id_metier: String) -> int:
	var m = etat.get("metiers", {})
	return int((m as Dictionary).get(id_metier, 0)) if m is Dictionary else 0


## Niveau atteint avec cette expérience (1 au départ).
static func niveau_pour(rec: Dictionary, xp: int) -> int:
	var paliers: Array = rec.get("paliers", [0])
	var niveau := 1
	for i in paliers.size():
		if xp >= int(paliers[i]):
			niveau = i + 1
	return niveau


static func niveau(rec: Dictionary, etat: Dictionary, id_metier: String) -> int:
	return niveau_pour(rec, experience(etat, id_metier))


static func niveau_max(rec: Dictionary) -> int:
	return maxi(1, (rec.get("paliers", [0]) as Array).size())


## Progression dans le niveau actuel : [xp gagnée dans ce niveau, xp à gagner pour le suivant]
## ([0, 0] au niveau maximum).
static func progression(rec: Dictionary, etat: Dictionary, id_metier: String) -> Array:
	var xp := experience(etat, id_metier)
	var n := niveau_pour(rec, xp)
	var paliers: Array = rec.get("paliers", [0])
	if n >= paliers.size():
		return [0, 0]
	return [xp - int(paliers[n - 1]), int(paliers[n]) - int(paliers[n - 1])]


## Expérience gagnée en récoltant une source : beaucoup si elle est à notre niveau,
## moitié moins quand on la dépasse de 3 niveaux, plus rien au-delà de 4 (« source grise »).
static func gain(rec: Dictionary, etat: Dictionary, id_source: String) -> int:
	var s := source(rec, id_source)
	var niveau_source := int(s.get("niveau", 1))
	var ecart := niveau(rec, etat, String(s.get("metier", ""))) - niveau_source
	var base := int(reglage(rec, "xp_base", 10)) + int(reglage(rec, "xp_par_niveau", 5)) * niveau_source
	if ecart >= 5:
		return 0
	if ecart >= 3:
		return base / 2
	return base


## Couleur de difficulté d'une source pour ce joueur (comme les noms des ennemis) :
## rouge = niveau trop bas, jaune/vert = bonne expérience, gris = plus rien à apprendre.
static func couleur(rec: Dictionary, etat: Dictionary, id_source: String) -> Color:
	var s := source(rec, id_source)
	var ecart := niveau(rec, etat, String(s.get("metier", ""))) - int(s.get("niveau", 1))
	if ecart < 0:
		return Color(1.0, 0.35, 0.3)
	if ecart >= 5:
		return Color(0.62, 0.62, 0.62)
	if ecart >= 3:
		return Color(0.45, 0.85, 0.4)
	return Color(1.0, 0.85, 0.35)


## Ajoute de l'expérience. Renvoie le nouveau niveau s'il a augmenté (0 sinon).
static func gagner(rec: Dictionary, etat: Dictionary, id_metier: String, xp: int) -> int:
	if not id_metier in METIERS or xp <= 0:
		return 0
	if not etat.get("metiers") is Dictionary:
		etat["metiers"] = {}
	var avant := niveau(rec, etat, id_metier)
	var maximum := int((rec.get("paliers", [0]) as Array).back())
	etat["metiers"][id_metier] = mini(experience(etat, id_metier) + xp, maxi(maximum, 0))
	var apres := niveau(rec, etat, id_metier)
	return apres if apres > avant else 0


# --- Récolter ------------------------------------------------------------------

## "" si on peut récolter cette source, sinon la raison (texte pour le joueur).
static func raison_impossible(cat: Dictionary, rec: Dictionary, etat: Dictionary, id_source: String) -> String:
	var s := source(rec, id_source)
	if s.is_empty():
		return "Source inconnue"
	var id_metier := String(s.get("metier", ""))
	var faut := int(s.get("niveau", 1))
	if niveau(rec, etat, id_metier) < faut:
		return "Il faut %s niveau %d" % [metier(rec, id_metier).get("nom", id_metier), faut]
	if Objets.places_libres(etat) <= 0:
		# On accepte quand même si chaque objet possible trouve une pile entamée.
		for ligne in s.get("donne", []):
			var id := String(ligne.get("objet", ""))
			var essai := etat.duplicate(true)
			if Objets.ajouter(cat, essai, id, 1) > 0:
				return "Tes sacs sont pleins"
	return ""


## Tire ce que donne une source : liste de {"id", "n"} (même format que le butin).
static func tirer(cat: Dictionary, rec: Dictionary, id_source: String, hasard: RandomNumberGenerator) -> Array:
	var resultat: Array = []
	for ligne in source(rec, id_source).get("donne", []):
		if hasard.randf() >= float(ligne.get("chance", 1.0)):
			continue
		var id := String(ligne.get("objet", ""))
		if not Objets.existe(cat, id):
			continue
		var n := 1
		var q = ligne.get("quantite", 1)
		if q is Array and q.size() == 2:
			n = hasard.randi_range(int(q[0]), int(q[1]))
		else:
			n = int(q)
		resultat.append({"id": id, "n": maxi(1, n)})
	return resultat


## Durée de l'action (secondes) : celle du métier, ou celle de la source si elle en a une.
static func duree(rec: Dictionary, id_source: String) -> float:
	var s := source(rec, id_source)
	return float(s.get("duree", metier(rec, String(s.get("metier", ""))).get("duree", 2.0)))


## Temps (secondes) avant que la source repousse pour ce joueur.
static func reapparition(rec: Dictionary, id_source: String) -> float:
	var s := source(rec, id_source)
	return float(s.get("reapparition", metier(rec, String(s.get("metier", ""))).get("reapparition", 120.0)))


## Distance (mètres) à laquelle on peut récolter (la pêche se fait depuis la rive).
static func portee(rec: Dictionary, id_source: String) -> float:
	var s := source(rec, id_source)
	return float(s.get("portee", metier(rec, String(s.get("metier", ""))).get("portee", 3.0)))


## Matériau : le métier qui le récolte et les sources qui le donnent (pour les infobulles).
static func provenance(rec: Dictionary, id_objet: String) -> Array:
	var resultat: Array = []
	var sources: Dictionary = rec.get("sources", {})
	for id in sources:
		for ligne in sources[id].get("donne", []):
			if String(ligne.get("objet", "")) == id_objet:
				var m := metier(rec, String(sources[id].get("metier", "")))
				var texte := "%s (%s niv. %d)" % [sources[id].get("nom", id), m.get("nom", ""), int(sources[id].get("niveau", 1))]
				if not texte in resultat:
					resultat.append(texte)
	return resultat


# --- Repas (plats du Chef Goro) --------------------------------------------------

## Mange le plat de la case « index » : un seul repas à la fois (le nouveau remplace l'ancien).
## « maintenant » : heure réelle en secondes (Time.get_unix_time_from_system()).
static func manger(cat: Dictionary, etat: Dictionary, index: int, maintenant: float) -> String:
	var cases: Array = etat["cases"]
	if index < 0 or index >= cases.size() or (cases[index] as Dictionary).is_empty():
		return "Case vide"
	var id := String(cases[index]["id"])
	var o := Objets.objet(cat, id)
	if String(o.get("type", "")) != "consommable":
		return "Ça ne se mange pas"
	cases[index]["n"] = int(cases[index]["n"]) - 1
	if int(cases[index]["n"]) <= 0:
		cases[index] = {}
	etat["repas"] = {"id": id, "fin": maintenant + float((o.get("repas", {}) as Dictionary).get("duree", 1800))}
	return ""


## Le repas en cours ("" si aucun, ou s'il est fini).
static func repas_actif(cat: Dictionary, etat: Dictionary, maintenant: float) -> String:
	var r = etat.get("repas")
	if not r is Dictionary or maintenant >= float(r.get("fin", 0.0)):
		return ""
	var id := String(r.get("id", ""))
	return id if String(Objets.objet(cat, id).get("type", "")) == "consommable" else ""


## Les bonus du repas en cours (mêmes clés que les stats d'équipement).
static func stats_repas(cat: Dictionary, etat: Dictionary, maintenant: float) -> Dictionary:
	var id := repas_actif(cat, etat, maintenant)
	if id == "":
		return {}
	return (Objets.objet(cat, id).get("repas", {}) as Dictionary).get("stats", {})

