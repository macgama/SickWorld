extends Node3D
## Les points de récolte d'une zone : cueillette, minage et pêche.
##
## Créé par Partie dans chaque zone (même nom partout : « Partie/Recolte »).
## Il pose les points listés pour la zone dans data/recolte.json (« zones »), chez
## tout le monde de la même façon. Récolter se passe ensuite comme une incantation :
##   1. le joueur appuie sur F près d'un point → demande au serveur ;
##   2. le serveur vérifie (niveau du métier, distance, sacs, pas en combat) et lance
##      la barre d'action (2 à 5 s, il ne faut pas bouger) ;
##   3. à la fin, il tire ce que donne la source, le range dans les sacs, ajoute
##      l'expérience du métier et rend la source invisible pour ce joueur
##      jusqu'à ce qu'elle repousse.
## Les sources sont PERSONNELLES : chaque joueur a les siennes, personne ne peut
## « voler » le filon d'un autre.

const Metiers := preload("res://scripts/objets/metiers.gd")
const PointRecolte := preload("res://scripts/monde/point_recolte.gd")

## Identifiant de la zone (celui du terrain), "" s'il n'y a rien à récolter ici.
var zone := ""
## Les points posés, dans l'ordre de data/recolte.json.
var points: Array[Node3D] = []

## Serveur : id du joueur -> { numéro du point -> heure de repousse }.
var _epuises := {}
## Serveur : id du joueur -> { "numero", "fin" } (récolte en cours).
var _en_cours := {}
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("recolte")
	_hasard.randomize()
	# On attend que le terrain soit construit pour connaître la hauteur du sol.
	_poser.call_deferred()


func _rec() -> Dictionary:
	return Donnees.recolte


func _terrain() -> Node:
	return get_parent().get_parent() if get_parent() != null else null


func _poser() -> void:
	var terrain := _terrain()
	if terrain == null or not "identifiant_zone" in terrain:
		return
	zone = String(terrain.get("identifiant_zone"))
	var liste := Metiers.points_de_zone(_rec(), zone)
	for i in liste.size():
		var p: Dictionary = liste[i]
		var point: Node3D = PointRecolte.new()
		point.name = "Point%d" % i
		point.source = p["source"]
		point.numero = i
		point.recolte = self
		var y := 0.0
		if terrain.has_method("hauteur"):
			y = terrain.hauteur(p["x"], p["z"])
		var f := Metiers.source(_rec(), p["source"])
		if String(f.get("metier", "")) == "peche" or bool(f.get("sur_l_eau", false)):
			# Les poissons (et les lotus) sont à la surface de l'eau.
			y = float(Metiers.reglage(_rec(), "niveau_eau", 0.0))
		add_child(point)
		point.global_position = Vector3(p["x"], y, p["z"])
		points.append(point)


## Point le plus proche d'une position (pour les tests et l'aide), -1 si aucun.
func point_proche(position_monde: Vector3, id_source := "") -> int:
	var meilleur := -1
	var distance := INF
	for i in points.size():
		if id_source != "" and points[i].source != id_source:
			continue
		var d := points[i].global_position.distance_to(position_monde)
		if d < distance:
			distance = d
			meilleur = i
	return meilleur


# --- Chez le joueur -------------------------------------------------------------

## Le joueur veut récolter le point « numero ».
func demander(numero: int) -> void:
	Regles.au_serveur(self, "_demander_recolter", [numero])


@rpc("authority", "call_remote", "reliable")
func _commencer(numero: int, duree: float) -> void:
	if numero >= 0 and numero < points.size():
		points[numero].commencer(duree)


@rpc("authority", "call_remote", "reliable")
func _arreter(numero: int) -> void:
	if numero >= 0 and numero < points.size():
		points[numero].arreter()


@rpc("authority", "call_remote", "reliable")
func _epuiser(numero: int, duree: float) -> void:
	if numero >= 0 and numero < points.size():
		points[numero].epuiser(duree)


# --- Serveur --------------------------------------------------------------------

func _joueur(id: int) -> Node:
	var partie := get_parent()
	return partie.get_node_or_null("Joueurs/%d" % id) if partie != null else null


func _dire(joueur: Node, texte: String) -> void:
	Regles.chez(joueur.id_reseau(), joueur.get_node("CombatJoueur"), "_recevoir_message", [texte])


## Heure de repousse du point pour ce joueur (0 si disponible).
func repousse(id_joueur: int, numero: int) -> float:
	var t := float((_epuises.get(id_joueur, {}) as Dictionary).get(numero, 0.0))
	return t if t > Regles.maintenant() else 0.0


func en_cours(id_joueur: int) -> bool:
	return _en_cours.has(id_joueur)


@rpc("any_peer", "call_remote", "reliable")
func _demander_recolter(numero: int) -> void:
	if not multiplayer.is_server() or numero < 0 or numero >= points.size():
		return
	var id := Regles.expediteur()
	var joueur := _joueur(id)
	if joueur == null:
		return
	var combat: Node = joueur.get_node("Combat")
	var point := points[numero]
	var raison := ""
	if not combat.est_vivant():
		raison = "Tu es désynchronisé"
	elif combat.en_combat():
		raison = "Impossible en combat"
	elif _en_cours.has(id):
		raison = "Tu récoltes déjà"
	elif repousse(id, numero) > 0.0:
		raison = "Déjà récolté : ça repousse dans %d s" % ceili(repousse(id, numero) - Regles.maintenant())
		Regles.chez(id, self, "_epuiser", [numero, repousse(id, numero) - Regles.maintenant()])
	else:
		var ecart: Vector3 = joueur.global_position - point.global_position
		if Vector2(ecart.x, ecart.z).length() > Metiers.portee(_rec(), point.source) + 1.5:
			raison = "Trop loin"
		else:
			raison = Metiers.raison_impossible(Donnees.objets, _rec(), joueur.get_node("Inventaire").etat, point.source)
	if raison != "":
		_dire(joueur, raison)
		return
	var monture: Node = joueur.get("monture")
	if monture != null and monture.est_monte():
		monture.descendre("")
	var duree := Metiers.duree(_rec(), point.source)
	_en_cours[id] = {"numero": numero, "fin": Regles.maintenant() + duree}
	var f := Metiers.source(_rec(), point.source)
	var m := Metiers.metier(_rec(), String(f.get("metier", "")))
	Regles.chez(id, joueur.get_node("CombatJoueur"), "_recevoir_incantation",
			["%s : %s" % [m.get("verbe", "Récolter"), f.get("nom", "")], duree])
	Regles.chez(id, self, "_commencer", [numero, duree])


func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server() or _en_cours.is_empty():
		return
	var t := Regles.maintenant()
	for id in _en_cours.keys():
		var r: Dictionary = _en_cours[id]
		var joueur := _joueur(id)
		if joueur == null:
			_en_cours.erase(id)
			continue
		var combat: Node = joueur.get_node("Combat")
		if joueur.bouge() or combat.en_combat() or not combat.est_vivant():
			_en_cours.erase(id)
			Regles.chez(id, joueur.get_node("CombatJoueur"), "_recevoir_incantation", ["", -1.0])
			Regles.chez(id, self, "_arreter", [int(r["numero"])])
			_dire(joueur, "Récolte interrompue")
			continue
		if t >= float(r["fin"]):
			_en_cours.erase(id)
			_terminer(joueur, int(r["numero"]))


## Serveur : la récolte est finie. Ce que donne la source va dans les sacs.
func _terminer(joueur: Node, numero: int) -> void:
	var id: int = joueur.id_reseau()
	var point := points[numero]
	var rec := _rec()
	var f := Metiers.source(rec, point.source)
	var id_metier := String(f.get("metier", ""))
	var m := Metiers.metier(rec, id_metier)
	var inv: Node = joueur.get_node("Inventaire")
	var objets := Metiers.tirer(Donnees.objets, rec, point.source, _hasard)
	var xp := Metiers.gain(rec, inv.etat, point.source)
	var nouveau_niveau: int = inv.gagner_experience(id_metier, xp)
	var restants: Array = inv.recevoir(objets)
	var pris: Array[String] = []
	for o in objets:
		var reste := 0
		for r in restants:
			if r["id"] == o["id"]:
				reste = int(r["n"])
		var n := int(o["n"]) - reste
		if n > 0:
			var nom := String(Objets.objet(Donnees.objets, String(o["id"])).get("nom", o["id"]))
			pris.append(nom + (" × %d" % n if n > 1 else ""))
	var texte := "Récolté : " + (", ".join(pris) if not pris.is_empty() else "rien")
	if xp > 0:
		texte += "   (+%d %s)" % [xp, m.get("nom", "")]
	if not restants.is_empty():
		texte += "\nTes sacs sont pleins"
	if nouveau_niveau > 0:
		texte += "\n%s : niveau %d !" % [m.get("nom", ""), nouveau_niveau]
	_dire(joueur, texte)
	var duree := Metiers.reapparition(rec, point.source)
	if not _epuises.has(id):
		_epuises[id] = {}
	_epuises[id][numero] = Regles.maintenant() + duree
	Regles.chez(id, self, "_epuiser", [numero, duree])
