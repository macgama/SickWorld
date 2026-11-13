extends Node3D
## Bruits d'un personnage ou d'une bête : pas, saut, réception, roulade, coups
## reçus, cris et mort. Ajouté tout seul par l'autoload Audio à chaque joueur
## et à chaque ennemi (rien à faire dans les scènes).
##
## Tout est déduit de ce qu'on voit (position, points de vie…), donc ça marche
## aussi pour les autres joueurs et les bêtes en multijoueur.
## Les volumes se règlent dans data/audio.json (sections « effets » et « betes »).

## Vitesse (m/s) au-dessus de laquelle on court (sinon on marche).
const SEUIL_COURSE := 5.0

var acteur: Node3D
var combat: Node
## "" pour un agent de la Vigie, sinon l'espèce de la bête (loup, ours, renne).
var espece := ""
var _derniere_position := Vector3.ZERO
var _distance := 0.0
var _au_sol := true
var _temps_en_l_air := 0.0
var _esquive := false
var _pv := -1.0
var _vivant := true
var _etat := -1
var _age := 0.0
var _prochaine_voix := 0.0
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	acteur = get_parent() as Node3D
	combat = acteur.get_node_or_null("Combat")
	_hasard.randomize()
	if not acteur.has_method("est_en_esquive"):
		var apparence = acteur.get("apparence")
		espece = String(apparence.get("espece")) if apparence != null and apparence.get("espece") != null else "loup"
	_derniere_position = acteur.global_position


func _physics_process(delta: float) -> void:
	if not is_instance_valid(acteur) or delta <= 0.0:
		return
	_age += delta
	var p := acteur.global_position
	var deplacement := p - _derniere_position
	_derniere_position = p
	# Téléportation (portail, réapparition) : on ne compte pas ce « pas » géant.
	if deplacement.length() > 6.0:
		return
	var vitesse := Vector2(deplacement.x, deplacement.z).length() / delta
	var vitesse_y := deplacement.y / delta
	if espece == "":
		_bruits_agent(delta, vitesse, vitesse_y)
	_bruits_combat()


func _bruits_agent(delta: float, vitesse: float, vitesse_y: float) -> void:
	var local: bool = acteur.has_method("est_local") and acteur.est_local()
	var au_sol: bool = acteur.is_on_floor() if local and acteur is CharacterBody3D else absf(vitesse_y) < 1.5
	if not au_sol:
		_temps_en_l_air += delta
	if au_sol and not _au_sol:
		if _temps_en_l_air > 0.35:
			_pas("reception", local)
		_distance = 0.0
	elif not au_sol and _au_sol and vitesse_y > 2.0:
		Audio.effet("saut", acteur)
		Audio.effet("voix_effort", acteur, {"sexe": _sexe()})
	if au_sol:
		_temps_en_l_air = 0.0
	_au_sol = au_sol
	# Roulade d'esquive.
	var esquive: bool = acteur.est_en_esquive()
	if esquive and not _esquive:
		Audio.effet("roulade", acteur)
		_distance = 0.0
	_esquive = esquive
	# Pas : un tous les ~2 m en courant, ~1,4 m en marchant.
	if au_sol and not esquive and vitesse > 0.8:
		_distance += vitesse * delta
		var foulee := 2.1 if vitesse > SEUIL_COURSE else 1.4
		if _distance >= foulee:
			_distance -= foulee
			_pas("course" if vitesse > SEUIL_COURSE else "marche", local)


func _pas(allure: String, local: bool) -> void:
	var surface := surface_sous(acteur.global_position)
	var r: Dictionary = Audio.reglage_effet("pas").duplicate()
	r.merge(Audio.reglage_effet("reception" if allure == "reception" else "pas"), true)
	if not local:
		r.merge(Audio.reglage_effet("pas_autres_joueurs"), true)
		if allure == "reception":
			r["volume_db"] = float(r.get("volume_db", -12.0)) + 4.0
	r["son"] = "pas/%s_%s" % [surface, allure]
	Audio.jouer_reglage(r, acteur.global_position)


## Surface sous les pieds : réglée par scène dans data/audio.json, ou lue sur le
## terrain des zones de la Préhistoire (neige, herbe, terre…).
func surface_sous(position_monde: Vector3) -> String:
	var r: Dictionary = Audio.reglages_scene
	if Audio.interieur and r.has("pas_interieur"):
		return String(r["pas_interieur"])
	var surface := String(r.get("pas", "beton"))
	if surface != "auto":
		return surface
	var scene := Audio.get_tree().current_scene
	if scene == null or not scene.has_method("_parts_sol"):
		return "terre"
	var parts: Color = scene._parts_sol(position_monde.x, position_monde.z, position_monde.y)
	var sols = scene.get("sols")
	var cle := "galets"
	if parts.g >= parts.r and parts.g >= parts.b:
		cle = "neige"
	elif parts.b >= parts.r:
		cle = "sol"
	var texture := ""
	if sols is Dictionary and sols.has(cle) and not sols[cle].is_empty():
		texture = String(sols[cle][0])
	if texture.begins_with("snow"):
		return "neige"
	if texture.contains("grass"):
		return "herbe"
	return "terre"


func _bruits_combat() -> void:
	if combat == null or not is_instance_valid(combat):
		return
	var pv := float(combat.get("pv"))
	var vivant := pv > 0.0
	# Au début, les points de vie arrivent du serveur : on ne compte pas ça comme un coup.
	if _age > 1.0 and _pv >= 0.0:
		if vivant and pv < _pv - 0.5:
			_touche()
		elif not vivant and _vivant:
			_touche()
			_cri("mort")
	_pv = pv
	_vivant = vivant
	# Une bête qui vous repère grogne.
	if espece != "":
		var etat = acteur.get("etat")
		if etat is int:
			if etat == _etat_poursuite() and _etat != etat and _age > 1.0:
				_cri("alerte")
			_etat = etat


func _touche() -> void:
	Audio.effet("coup", acteur.global_position + Vector3.UP)
	if espece == "":
		if _age >= _prochaine_voix:
			_prochaine_voix = _age + 1.2
			Audio.effet("voix_douleur", acteur, {"sexe": _sexe()})
	else:
		_cri("douleur")


## Cri d'une bête (alerte, attaque, douleur, mort) ou d'un agent (mort).
func _cri(quoi: String) -> void:
	if espece == "":
		if quoi == "mort":
			Audio.effet("voix_mort", acteur, {"sexe": _sexe()})
		return
	var r: Dictionary = Audio.donnees.get("betes", {}).get(espece, {}).get(quoi, {})
	Audio.jouer_reglage(r, acteur)


## Appelé quand une bête mord (loup.gd) : cri d'attaque.
func attaque() -> void:
	if espece == "":
		Audio.effet("attaque", acteur)
	else:
		_cri("attaque")


func _sexe() -> String:
	var fiche := acteur.get_node_or_null("Fiche")
	if fiche != null and fiche.get("donnees") is Dictionary:
		return String(fiche.donnees.get("sexe", "homme"))
	return "homme"


func _etat_poursuite() -> int:
	var script: Script = acteur.get_script()
	if script != null:
		var etats = script.get_script_constant_map().get("Etat")
		if etats is Dictionary and etats.has("POURSUIVRE"):
			return int(etats["POURSUIVRE"])
	return 1
