class_name Recompenses
extends RefCounted
## Ce que rapportent les quêtes, lu dans les données du jeu (jamais dans ce que dit le joueur).
##
## Les quêtes avancent chez chaque joueur ; quand l'une d'elles est faite, le joueur
## DEMANDE sa récompense au serveur (ProgressionJoueur.reclamer). Le serveur retrouve
## ici, dans data/, les objets et l'XP prévus pour cette étape, cet événement ou cette
## mission, et les donne au joueur qui a fait la quête (qu'il soit l'hôte ou non).
##
## Ces fonctions n'ont aucun effet sur la scène (le serveur les appelle, les tests aussi).

## Délai minimal entre deux récompenses du même événement public pour un même joueur
## (secondes) : deux événements d'une zone sont toujours espacés d'au moins 3 min.
const ATTENTE_EVENEMENT := 120.0
## Une mission du jour finie peut être rendue plus tard, mais pas des mois après.
const JOURS_GARDES := 14
const SEMAINES_GARDEES := 3

static var _cache: Dictionary = {}


## Le contenu de res://data/<nom>.json (lu une seule fois ; {} s'il n'existe pas).
static func lire(nom: String) -> Dictionary:
	if not _cache.has(nom):
		var chemin := "res://data/%s.json" % nom
		var lu = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
		_cache[nom] = lu if lu is Dictionary else {}
	return _cache[nom]


static func ile_connue(ile: String) -> bool:
	return ile in Progression.ILES


## Une étape de la quête principale d'une île, avec « chapitre » et « ou » complétés
## comme dans quete.gd ({} si elle n'existe pas).
static func etape_principale(ile: String, id_etape: String) -> Dictionary:
	if not ile_connue(ile) or id_etape == "":
		return {}
	for c in lire(ile + "_quete").get("chapitres", []):
		for e in c.get("etapes", []):
			if String(e.get("id", "")) == id_etape:
				var copie: Dictionary = e.duplicate()
				copie["chapitre"] = c.get("numero", 0)
				if not copie.has("ou"):
					copie["ou"] = c.get("ou", "")
				return copie
	return {}


static func quete_secondaire(ile: String, id_quete: String) -> Dictionary:
	if not ile_connue(ile):
		return {}
	for q in lire(ile + "_secondaires").get("quetes", []):
		if String(q.get("id", "")) == id_quete:
			return q
	return {}


static func evenement(ile: String, id_evenement: String) -> Dictionary:
	if not ile_connue(ile):
		return {}
	for e in lire(ile + "_evenements").get("evenements", []):
		if String(e.get("id", "")) == id_evenement:
			return e
	return {}


## Une mission du jour ou de la semaine (« genre » ajouté : quotidienne / hebdomadaire).
static func mission_du_jour(id_mission: String) -> Dictionary:
	var d := lire("quetes_du_jour")
	for genre in ["quotidienne", "hebdomadaire"]:
		for m in d.get("quotidiennes" if genre == "quotidienne" else "hebdomadaires", []):
			if String(m.get("id", "")) == id_mission:
				var copie: Dictionary = m.duplicate()
				copie["genre"] = genre
				return copie
	return {}


static func mission_hub(id_mission: String) -> Dictionary:
	for q in lire("hub_quetes").get("quetes", []):
		if String(q.get("id", "")) == id_mission:
			return q
	return {}


## Liste d'objets d'une récompense, au format de Inventaire.recevoir ([{id, n}]).
static func objets(liste: Array) -> Array:
	var resultat: Array = []
	for o in liste:
		if o is Dictionary and o.has("id"):
			resultat.append({"id": String(o["id"]), "n": maxi(1, int(o.get("n", 1)))})
	return resultat


## Les objets d'un palier d'événement (or, argent, bronze), en tirant les « chance ».
## En cas d'échec, seule la petite récompense (bronze) est donnée.
static func objets_evenement(e: Dictionary, palier: String, reussi: bool, hasard: RandomNumberGenerator) -> Array:
	var cle := palier if reussi else "bronze"
	var tires: Array = []
	for o in (e.get("recompenses", {}) as Dictionary).get(cle, []):
		if hasard.randf() < float(o.get("chance", 1.0)):
			tires.append(o)
	return objets(tires)


## Noms lisibles d'une liste d'objets (« Éclats de fracture ×4, Sceau de faille »).
static func noms(catalogue: Dictionary, liste: Array) -> String:
	var morceaux: PackedStringArray = []
	for o in liste:
		var nom := String(Objets.objet(catalogue, String(o["id"])).get("nom", o["id"]))
		morceaux.append("%s × %d" % [nom, int(o["n"])] if int(o["n"]) > 1 else nom)
	return ", ".join(morceaux)


## Fait noté pour une mission du jour rendue (une seule récompense par mission et par période).
static func fait_mission_du_jour(genre: String, id_mission: String, periode: int) -> String:
	return "jour:%s:%s@%d" % ["h" if genre == "hebdomadaire" else "q", id_mission, periode]


## Retire des faits les missions du jour trop anciennes (pour que la liste ne grossisse pas).
## « periodes » : {"quotidienne": n° du jour, "hebdomadaire": n° de la semaine}.
static func oublier_vieilles_missions(faits: Array, periodes: Dictionary) -> void:
	for i in range(faits.size() - 1, -1, -1):
		var f := String(faits[i])
		if not f.begins_with("jour:") or not "@" in f:
			continue
		var hebdo := f.begins_with("jour:h:")
		var p := int(f.get_slice("@", 1))
		var actuelle := int(periodes.get("hebdomadaire" if hebdo else "quotidienne", p))
		if p < actuelle - (SEMAINES_GARDEES if hebdo else JOURS_GARDES):
			faits.remove_at(i)


## Une période de mission envoyée par le joueur est-elle plausible ? (Les horloges du
## joueur et du serveur peuvent avoir un jour d'écart : fuseaux horaires.)
static func periode_plausible(genre: String, periode: int, actuelle: int) -> bool:
	var garde := SEMAINES_GARDEES if genre == "hebdomadaire" else JOURS_GARDES
	return periode <= actuelle + 1 and periode >= actuelle - garde


## Numéro du jour (ou de la semaine) selon l'horloge de CETTE machine, calculé comme
## dans quetes_du_jour.gd (renouvellement à l'heure des réglages, semaine du lundi).
static func periode_actuelle(genre: String) -> int:
	var t := int(Time.get_unix_time_from_system())
	t += int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	t -= int(lire("quetes_du_jour").get("reglages", {}).get("heure_renouvellement", 6)) * 3600
	var jour := floori(t / 86400.0)
	return floori((jour + 3) / 7.0) if genre == "hebdomadaire" else jour
