class_name Progression
extends RefCounted
## Règles de la progression du personnage : niveaux, expérience (XP), talents et titres.
##
## Comme Objets, tout travaille sur un simple dictionnaire « état de progression » :
##   {
##     "xp": 1234,                              # expérience totale gagnée depuis le niveau 1
##     "talents": {"lame_affutee": 3, …},      # rang de chaque talent pris
##     "titres": ["recrue", …],                 # titres obtenus
##     "titre": "recrue",                       # titre porté ("" = aucun)
##     "tues": {"loup_fracture": 12, …},        # ennemis vaincus par type
##     "decouvertes": ["steppe", …],            # zones déjà découvertes
##     "faits": ["etape:prehistoire:vers_le_camp", "secondaire:miou", "evenement:prehistoire", …],
##     "arene": {"victoires": 12, "meilleure_cote": 1642, "meilleur_rang": 3}  # Arène JcJ (rang 0 = jamais classé)
##   }
## Les réglages (« d ») sont le contenu de data/progression.json (ProgressionJoueur les lit).
##
## Ces fonctions n'ont aucun effet sur la scène : le serveur les appelle pour décider,
## le joueur pour afficher, et les tests pour vérifier.

const STATS := ["pv", "degats_pourcent", "reduction_pourcent", "critique_pourcent"]
const FICHIER_DONNEES := "res://data/progression.json"
## Les îles dont on lit les quêtes (rattrapage, titre « toutes les secondaires »).
const ILES := ["prehistoire", "egypte"]

static var _donnees: Dictionary = {}


## Le contenu de data/progression.json (lu une seule fois).
static func donnees() -> Dictionary:
	if _donnees.is_empty():
		var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_DONNEES))
		if lu is Dictionary:
			_donnees = lu
		else:
			push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % FICHIER_DONNEES)
	return _donnees


# --- Niveaux -----------------------------------------------------------------

static func niveau_max(d: Dictionary) -> int:
	return int((d.get("niveaux", {}) as Dictionary).get("niveau_max", 20))


## XP pour passer du niveau n au niveau n + 1.
static func xp_pour_niveau(d: Dictionary, n: int) -> int:
	var r: Dictionary = d.get("niveaux", {})
	return int(round(float(r.get("base", 0)) + float(r.get("par_niveau", 100)) * n + float(r.get("carre", 8)) * n * n))


## XP totale qu'il faut avoir gagnée pour ÊTRE au niveau n.
static func xp_total_pour(d: Dictionary, n: int) -> int:
	var total := 0
	for i in range(1, n):
		total += xp_pour_niveau(d, i)
	return total


static func niveau_pour_xp(d: Dictionary, xp: int) -> int:
	var n := 1
	var reste := xp
	while n < niveau_max(d) and reste >= xp_pour_niveau(d, n):
		reste -= xp_pour_niveau(d, n)
		n += 1
	return n


## Avancement dans le niveau en cours : Vector2i(xp gagnée dans ce niveau, xp nécessaire).
## Au niveau maximum : (0, 0).
static func avancement(d: Dictionary, xp: int) -> Vector2i:
	var n := niveau_pour_xp(d, xp)
	if n >= niveau_max(d):
		return Vector2i.ZERO
	return Vector2i(xp - xp_total_pour(d, n), xp_pour_niveau(d, n))


## Points de talent gagnés à un niveau (un par niveau à partir du niveau 2).
static func points_gagnes(d: Dictionary, niveau: int) -> int:
	var premier := int((d.get("niveaux", {}) as Dictionary).get("premier_niveau_talents", 2))
	return maxi(0, niveau - premier + 1)


# --- Expérience --------------------------------------------------------------

## Niveau de référence d'une zone (data/progression.json, partie « zones »).
static func niveau_zone(d: Dictionary, zone: String) -> int:
	return maxi(1, int((d.get("zones", {}) as Dictionary).get(zone, 1)))


## XP d'une source (« etape_quete », « ennemi »…) pour un niveau donné.
static func xp_de(d: Dictionary, source: String, niveau: int) -> int:
	var r: Dictionary = (d.get("xp", {}) as Dictionary).get(source, {})
	return int(round(float(r.get("base", 0)) + float(r.get("par_niveau", 0)) * maxi(1, niveau)))


## XP d'un ennemi vaincu, selon l'écart entre son niveau et celui du joueur.
static func xp_ennemi(d: Dictionary, niveau_ennemi: int, niveau_joueur: int) -> int:
	var e: Dictionary = (d.get("xp", {}) as Dictionary).get("ecart_ennemi", {})
	var ecart := niveau_ennemi - niveau_joueur
	var facteur := 1.0
	if ecart < 0:
		facteur = maxf(float(e.get("minimum", 0.1)), 1.0 + ecart * float(e.get("moins_par_niveau", 0.15)))
	elif ecart > 0:
		facteur = minf(float(e.get("maximum", 1.5)), 1.0 + ecart * float(e.get("plus_par_niveau", 0.1)))
	return maxi(1, int(round(xp_de(d, "ennemi", niveau_ennemi) * facteur)))


## XP d'un événement public selon le palier obtenu (or, argent, bronze).
static func xp_evenement(d: Dictionary, niveau: int, palier: String) -> int:
	var r: Dictionary = (d.get("xp", {}) as Dictionary).get("evenement", {})
	return int(round(xp_de(d, "evenement", niveau) * float(r.get(palier, 0.5))))


# --- État --------------------------------------------------------------------

static func etat_de_depart() -> Dictionary:
	return {"xp": 0, "talents": {}, "titres": [], "titre": "", "tues": {}, "decouvertes": [], "faits": [],
			"arene": {"victoires": 0, "meilleure_cote": 0, "meilleur_rang": 0}}


## Remet d'aplomb un état lu dans une sauvegarde (talents inconnus ou trop chers retirés…).
static func valider(d: Dictionary, classe: String, lu) -> Dictionary:
	var e := etat_de_depart()
	if not lu is Dictionary:
		return e
	e["xp"] = clampi(int(lu.get("xp", 0)), 0, xp_total_pour(d, niveau_max(d)) * 4)
	for cle in ["tues"]:
		if lu.get(cle) is Dictionary:
			for k in lu[cle]:
				e[cle][String(k)] = maxi(0, int(lu[cle][k]))
	for cle in ["decouvertes", "faits"]:
		if lu.get(cle) is Array:
			for v in lu[cle]:
				if not String(v) in e[cle]:
					e[cle].append(String(v))
	if lu.get("arene") is Dictionary:
		for cle in e["arene"]:
			e["arene"][cle] = maxi(0, int(lu["arene"].get(cle, 0)))
	if lu.get("titres") is Array:
		for t in lu["titres"]:
			if not titre(d, String(t)).is_empty() and not String(t) in e["titres"]:
				e["titres"].append(String(t))
	var porte := String(lu.get("titre", ""))
	e["titre"] = porte if porte in e["titres"] else ""
	# Les talents sont repris un par un, dans l'ordre des paliers, tant qu'ils restent permis.
	var voulus: Dictionary = lu.get("talents", {}) if lu.get("talents") is Dictionary else {}
	for palier in range(1, 5):
		for v in voies(d, classe):
			for t in v.get("talents", []):
				if int(t.get("palier", 1)) != palier or not voulus.has(t["id"]):
					continue
				for i in clampi(int(voulus[t["id"]]), 0, int(t.get("rangs", 1))):
					if raison_talent_impossible(d, classe, e, String(t["id"])) == "":
						e["talents"][t["id"]] = int(e["talents"].get(t["id"], 0)) + 1
	return e


static func niveau(d: Dictionary, e: Dictionary) -> int:
	return niveau_pour_xp(d, int(e.get("xp", 0)))


# --- Talents -----------------------------------------------------------------

## Les 3 voies de talents d'une classe.
static func voies(d: Dictionary, classe: String) -> Array:
	var t = (d.get("talents", {}) as Dictionary).get(classe, [])
	return t if t is Array else []


## Un talent de la classe et sa voie : {"talent": {…}, "voie": {…}} (vide si inconnu).
static func trouver_talent(d: Dictionary, classe: String, id: String) -> Dictionary:
	for v in voies(d, classe):
		for t in v.get("talents", []):
			if String(t.get("id", "")) == id:
				return {"talent": t, "voie": v}
	return {}


static func points_depenses(e: Dictionary) -> int:
	var total := 0
	for id in e.get("talents", {}):
		total += int(e["talents"][id])
	return total


static func points_dans_voie(e: Dictionary, voie: Dictionary) -> int:
	var total := 0
	for t in voie.get("talents", []):
		total += int(e.get("talents", {}).get(t["id"], 0))
	return total


static func points_libres(d: Dictionary, e: Dictionary) -> int:
	return points_gagnes(d, niveau(d, e)) - points_depenses(e)


## Points à avoir dans la voie pour ouvrir un palier (1 à 4).
static func points_requis(d: Dictionary, palier: int) -> int:
	var liste: Array = (d.get("talents", {}) as Dictionary).get("points_par_palier", [0, 3, 6, 8])
	return int(liste[clampi(palier - 1, 0, liste.size() - 1)])


## "" si on peut prendre un rang de plus dans ce talent, sinon la raison.
static func raison_talent_impossible(d: Dictionary, classe: String, e: Dictionary, id: String) -> String:
	var trouve := trouver_talent(d, classe, id)
	if trouve.is_empty():
		return "Ce talent n'est pas de ta classe"
	var t: Dictionary = trouve["talent"]
	if int(e.get("talents", {}).get(id, 0)) >= int(t.get("rangs", 1)):
		return "Ce talent est déjà au maximum"
	if points_libres(d, e) <= 0:
		return "Plus de point de talent (un par niveau)"
	var requis := points_requis(d, int(t.get("palier", 1)))
	if points_dans_voie(e, trouve["voie"]) < requis:
		return "Il faut %d points dans la voie %s" % [requis, trouve["voie"].get("nom", "")]
	return ""


static func prendre_talent(d: Dictionary, classe: String, e: Dictionary, id: String) -> String:
	var raison := raison_talent_impossible(d, classe, e, id)
	if raison == "":
		e["talents"][id] = int(e["talents"].get(id, 0)) + 1
	return raison


static func oublier_talents(e: Dictionary) -> void:
	e["talents"] = {}


## Bonus des talents et du niveau, au même format que Objets.bonus :
## {"stats": {pv, degats_pourcent…}, "competences": {id: {clé: valeur}}}.
## pv_de_base : la vie de base de la classe (le niveau en ajoute un pourcentage).
static func bonus(d: Dictionary, classe: String, e: Dictionary, pv_de_base: float) -> Dictionary:
	var stats := {}
	for s in STATS:
		stats[s] = 0.0
	var competences := {}
	var n := niveau(d, e)
	var par_niveau: Dictionary = (d.get("niveaux", {}) as Dictionary).get("par_niveau_gagne", {})
	stats["pv"] = round(pv_de_base * float(par_niveau.get("pv_pourcent", 0)) / 100.0 * (n - 1))
	stats["degats_pourcent"] = float(par_niveau.get("degats_pourcent", 0)) * (n - 1)
	for v in voies(d, classe):
		for t in v.get("talents", []):
			var rang := int(e.get("talents", {}).get(t["id"], 0))
			if rang <= 0:
				continue
			var s = t.get("stats", {})
			if s is Dictionary:
				for cle in s:
					if stats.has(cle):
						stats[cle] = float(stats[cle]) + float(s[cle]) * rang
			var c = t.get("competences", {})
			if c is Dictionary:
				for id in c:
					if not competences.has(id):
						competences[id] = {}
					for cle in c[id]:
						competences[id][cle] = float(competences[id].get(cle, 0.0)) + float(c[id][cle]) * rang
	return {"stats": stats, "competences": competences}


## Bonus d'un combat ÉQUILIBRÉ (Arène JcJ) : tout le monde se bat comme s'il était au
## niveau de référence, avec le même « équipement standard ». L'équipement, les talents
## et le repas sont ignorés : seuls comptent la classe et le savoir-faire du joueur.
## eq : la partie « equilibrage » de data/arene.json.
static func bonus_equilibre(d: Dictionary, eq: Dictionary, pv_de_base: float) -> Dictionary:
	var stats := {}
	for s in STATS:
		stats[s] = 0.0
	var n := clampi(int(eq.get("niveau_reference", niveau_max(d))), 1, niveau_max(d))
	var par_niveau: Dictionary = (d.get("niveaux", {}) as Dictionary).get("par_niveau_gagne", {})
	stats["pv"] = round(pv_de_base * float(par_niveau.get("pv_pourcent", 0)) / 100.0 * (n - 1))
	stats["degats_pourcent"] = float(par_niveau.get("degats_pourcent", 0)) * (n - 1)
	var standard: Dictionary = eq.get("equipement_standard", {})
	for s in standard:
		if stats.has(s):
			stats[s] = float(stats[s]) + float(standard[s])
	return {"stats": stats, "competences": {}, "ensembles": {}, "paliers": []}


## Ajoute les bonus « ajout » (même format) dans « total » (le bonus de l'équipement).
static func fusionner(total: Dictionary, ajout: Dictionary) -> void:
	var stats: Dictionary = total.get("stats", {})
	for s in ajout.get("stats", {}):
		stats[s] = float(stats.get(s, 0.0)) + float(ajout["stats"][s])
	var comp: Dictionary = total.get("competences", {})
	for id in ajout.get("competences", {}):
		if not comp.has(id):
			comp[id] = {}
		for cle in ajout["competences"][id]:
			comp[id][cle] = float(comp[id].get(cle, 0.0)) + float(ajout["competences"][id][cle])


# --- Titres ------------------------------------------------------------------

static func liste_titres(d: Dictionary) -> Array:
	return (d.get("titres", {}) as Dictionary).get("liste", [])


static func titre(d: Dictionary, id: String) -> Dictionary:
	for t in liste_titres(d):
		if String(t.get("id", "")) == id:
			return t
	return {}


## Nom affiché du titre porté ("" si aucun).
static func nom_titre(d: Dictionary, id: String) -> String:
	return String(titre(d, id).get("nom", ""))


## Nombre d'ennemis vaincus dont le type commence par « debut » (ex. "loup").
static func vaincus(e: Dictionary, debut: String) -> int:
	var total := 0
	for type in e.get("tues", {}):
		if String(type).begins_with(debut):
			total += int(e["tues"][type])
	return total


static func compte_faits(e: Dictionary, prefixe: String) -> int:
	var n := 0
	for f in e.get("faits", []):
		if String(f).begins_with(prefixe):
			n += 1
	return n


## Vrai si la condition du titre est remplie.
## total_secondaires : île -> nombre de quêtes secondaires qu'elle propose.
static func condition_remplie(d: Dictionary, e: Dictionary, t: Dictionary, total_secondaires := {}) -> bool:
	var c: Dictionary = t.get("condition", {})
	if c.has("niveau"):
		return niveau(d, e) >= int(c["niveau"])
	if c.has("etape"):
		return ("etape:" + String(c["etape"])) in e.get("faits", [])
	if c.has("secondaire"):
		return ("secondaire:%s" % c["secondaire"]) in e.get("faits", [])
	if c.has("secondaires"):
		var ile := String(c["secondaires"])
		var total := int(total_secondaires.get(ile, 0))
		return total > 0 and compte_faits(e, "secondaire_ile:%s:" % ile) >= total
	if c.has("evenements"):
		return compte_faits(e, "evenement:%s:" % c["evenements"]) >= int(c.get("nombre", 1))
	if c.has("tuer"):
		return vaincus(e, String(c["tuer"])) >= int(c.get("nombre", 1))
	var arene: Dictionary = e.get("arene", {})
	if c.has("arene_victoires"):
		return int(arene.get("victoires", 0)) >= int(c["arene_victoires"])
	if c.has("arene_cote"):
		return int(arene.get("meilleure_cote", 0)) >= int(c["arene_cote"])
	if c.has("arene_rang"):
		var rang := int(arene.get("meilleur_rang", 0))
		return rang > 0 and rang <= int(c["arene_rang"])
	return false


## Donne tous les titres dont la condition vient d'être remplie. Renvoie leurs ids.
static func nouveaux_titres(d: Dictionary, e: Dictionary, total_secondaires := {}) -> Array:
	var gagnes: Array = []
	for t in liste_titres(d):
		var id := String(t.get("id", ""))
		if id == "" or id in e["titres"]:
			continue
		if condition_remplie(d, e, t, total_secondaires):
			e["titres"].append(id)
			gagnes.append(id)
	if String(e.get("titre", "")) == "" and not e["titres"].is_empty():
		e["titre"] = String(e["titres"][e["titres"].size() - 1])
	return gagnes


static func choisir_titre(d: Dictionary, e: Dictionary, id: String) -> String:
	if id == "":
		e["titre"] = ""
		return ""
	if not id in e.get("titres", []):
		return "Tu n'as pas encore ce titre"
	e["titre"] = id
	return ""


# --- Rattrapage -----------------------------------------------------------------

## Premier chargement : rend l'XP des quêtes déjà faites avant l'arrivée des niveaux
## (étapes de quête principale, quêtes secondaires finies, événements réussis).
static func rattrapage(e: Dictionary, fichier_cfg: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(fichier_cfg) != OK:
		return
	var d := donnees()
	var xp := 0
	for ile in ILES:
		var q = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_quete.json" % ile))
		if not q is Dictionary or not cfg.has_section(ile):
			continue
		var actuelle := String(cfg.get_value(ile, "etape", ""))
		var fini := false
		for c in q.get("chapitres", []):
			for et in c.get("etapes", []):
				if actuelle != "fin" and String(et.get("id", "")) == actuelle:
					fini = true
					break
				var n := niveau_zone(d, String(et.get("ou", c.get("ou", ""))))
				xp += xp_de(d, "etape_quete", n)
				if et.get("fin_chapitre", false):
					xp += xp_de(d, "fin_chapitre", n)
				e["faits"].append("etape:%s:%s" % [ile, et.get("id", "")])
			if fini:
				break
		var s = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_secondaires.json" % ile)) \
				if FileAccess.file_exists("res://data/%s_secondaires.json" % ile) else null
		if s is Dictionary:
			for sq in s.get("quetes", []):
				if int(cfg.get_value(ile + "_secondaires", "etat_" + String(sq["id"]), -1)) >= 999:
					e["faits"].append("secondaire:" + String(sq["id"]))
					e["faits"].append("secondaire_ile:%s:%s" % [ile, sq["id"]])
					var zone := String((sq.get("etapes", [{}]) as Array)[0].get("ou", "")) if not (sq.get("etapes", []) as Array).is_empty() else ""
					xp += xp_de(d, "quete_secondaire", niveau_zone(d, zone))
		var ev = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_evenements.json" % ile)) \
				if FileAccess.file_exists("res://data/%s_evenements.json" % ile) else null
		if ev is Dictionary:
			for evt in ev.get("evenements", []):
				var reussis := int(cfg.get_value(ile + "_evenements", "reussis_" + String(evt["id"]), 0))
				for i in mini(reussis, 3):
					e["faits"].append("evenement:%s:%s" % [ile, evt["id"]])
					xp += xp_evenement(d, niveau_zone(d, String(evt.get("zone", ""))), "argent")
	e["xp"] = mini(xp, xp_total_pour(d, niveau_max(d)))
