class_name Loup
extends CharacterBody3D
## Loup : ennemi de l'étape 2 (ou allié invoqué par « Appel de la meute »).
##
## Comportement d'un loup ennemi, comme dans WoW :
## - il erre autour de son camp ;
## - il attaque si un joueur s'approche trop (distance de détection) ;
## - ses voisins du même camp viennent l'aider (entraide) ;
## - s'il est entraîné trop loin de son camp (laisse), il abandonne,
##   rentre en courant et récupère toute sa vie ;
## - mort, il réapparaît après un moment.
##
## Les valeurs (vie, dégâts, vitesse…) sont dans data/ennemis.json.

enum Etat { ERRER, POURSUIVRE, RETOUR, MORT }

## Identifiant dans data/ennemis.json.
@export var type_ennemi := "loup"
## « ennemi » pour les loups sauvages, « joueur » pour les loups invoqués.
@export var faction := "ennemi"

var etat := Etat.ERRER
var camp := Vector3.ZERO
## Pour un loup invoqué : le personnage qu'il accompagne.
var maitre: Node3D = null
var fin_invocation := 0.0

var _donnees: Dictionary
var _cible: Combattant = null
var _prochaine_attaque := 0.0
var _point_errance := Vector3.ZERO
var _prochaine_errance := 0.0
var _moment_mort := 0.0
var _gravite := 16.0

# --- État partagé sur le réseau (le serveur fait réfléchir les loups,
# les joueurs reçoivent seulement leur position et leur état) ---
var position_reseau := Vector3.ZERO
var lacet_reseau := 0.0
var vitesse_reseau := 0.0
var _colore := false

@onready var combat: Combattant = $Combat
@onready var apparence: Node3D = $Apparence


func _enter_tree() -> void:
	add_to_group("loups")


func _ready() -> void:
	combat.hauteur_centre = 0.6
	if not multiplayer.is_server():
		return
	_donnees = Donnees.ennemi(type_ennemi)
	combat.nom_affiche = _donnees.get("nom", "Loup")
	combat.niveau = int(_donnees.get("niveau", 1))
	combat.pv_max = float(_donnees.get("points_de_vie", 100))
	combat.pv = combat.pv_max
	combat.faction = faction
	combat.degats_recus.connect(_sur_degats)
	combat.mort.connect(_sur_mort)
	if camp == Vector3.ZERO:
		camp = global_position
	_point_errance = camp


func _physics_process(delta: float) -> void:
	if not _colore and apparence.has_method("colorer"):
		_colore = true
		apparence.colorer(faction == "joueur")
	if not multiplayer.is_server():
		_suivre_le_reseau(delta)
		return
	if not is_on_floor():
		velocity.y -= _gravite * delta
	else:
		velocity.y = -0.5

	match etat:
		Etat.ERRER:
			_errer()
		Etat.POURSUIVRE:
			_poursuivre()
		Etat.RETOUR:
			_rentrer()
		Etat.MORT:
			velocity.x = 0.0
			velocity.z = 0.0
			var attente := float(_donnees.get("temps_reapparition", 20))
			if maitre == null and attente > 0.0 and Regles.maintenant() - _moment_mort > attente:
				_reapparaitre()

	if maitre != null and Regles.maintenant() > fin_invocation and etat != Etat.MORT:
		_disparaitre()
		return

	move_and_slide()
	if global_position.y < -30.0:
		global_position = camp + Vector3.UP
		reset_physics_interpolation()
	position_reseau = global_position
	lacet_reseau = rotation.y
	vitesse_reseau = Vector2(velocity.x, velocity.z).length()
	if apparence.has_method("animer"):
		apparence.animer(get_physics_process_delta_time(), Vector2(velocity.x, velocity.z).length(),
				etat == Etat.MORT)


func _avancer_vers(point: Vector3, vitesse: float, arret := 0.0) -> float:
	var ecart := point - global_position
	ecart.y = 0.0
	var distance := ecart.length()
	if distance > 0.05:
		_regarder(ecart)
	if distance > arret:
		var v := ecart.normalized() * vitesse * combat.multiplicateur_vitesse()
		velocity.x = v.x
		velocity.z = v.z
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	return distance


func _regarder(direction: Vector3) -> void:
	var voulu := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, voulu, 0.25)


# --- États -----------------------------------------------------------------

func _errer() -> void:
	if maitre != null:
		# Loup invoqué : suit son maître et attaque ses ennemis.
		var cible := _cible_du_maitre()
		if cible != null:
			engager(cible)
			return
		_avancer_vers(maitre.global_position, float(_donnees.get("vitesse_marche", 7)), 3.0)
		return
	if Regles.maintenant() > _prochaine_errance:
		_prochaine_errance = Regles.maintenant() + Regles.aleatoire.randf_range(4.0, 9.0)
		var angle := Regles.aleatoire.randf() * TAU
		_point_errance = camp + Vector3(cos(angle), 0, sin(angle)) * Regles.aleatoire.randf_range(0.0, 7.0)
	_avancer_vers(_point_errance, float(_donnees.get("vitesse_marche", 1.8)), 0.5)
	# Détection : un ennemi trop proche ?
	var detection := float(_donnees.get("distance_detection", 10))
	for c in Regles.hostiles_autour(combat, global_position, detection):
		if Regles.ligne_de_vue(combat, c):
			engager(c)
			return


func _poursuivre() -> void:
	if _cible == null or not is_instance_valid(_cible) or not _cible.est_vivant():
		_cible = combat.plus_menacant()
		if _cible == null and maitre != null:
			_cible = _cible_du_maitre()
		if _cible == null:
			_abandonner()
			return
	if maitre == null and global_position.distance_to(camp) > float(_donnees.get("distance_laisse", 40)):
		_abandonner()
		return
	# Le plus menaçant devient la cible (utile quand plusieurs adversaires frappent).
	var plus_menacant := combat.plus_menacant()
	if plus_menacant != null and plus_menacant != _cible \
			and combat.menace[plus_menacant] > combat.menace.get(_cible, 0.0) * 1.1:
		_cible = plus_menacant
	var portee := float(_donnees.get("portee_attaque", 2.2))
	var distance := _avancer_vers(_cible.acteur().global_position, float(_donnees.get("vitesse_course", 6.5)),
			portee * 0.8)
	if distance <= portee and Regles.maintenant() >= _prochaine_attaque:
		_prochaine_attaque = Regles.maintenant() + float(_donnees.get("intervalle_attaque", 1.8))
		Regles.infliger(combat, _cible, Donnees.entre(_donnees.get("degats", [5, 8])))
		_mordre.rpc()


func _rentrer() -> void:
	var distance := _avancer_vers(camp, float(_donnees.get("vitesse_course", 6.5)) * 1.3, 0.5)
	if distance <= 1.0:
		combat.retirer_effet("evite")
		combat.reanimer(100.0)
		etat = Etat.ERRER


# --- Événements ------------------------------------------------------------

## Commence à combattre « cible » (et prévient les loups voisins du même camp).
func engager(cible: Combattant) -> void:
	if etat == Etat.MORT or etat == Etat.RETOUR or cible == null:
		return
	if not combat.menace.has(cible):
		combat.menace[cible] = 1.0
	if etat == Etat.POURSUIVRE:
		return
	_cible = cible
	etat = Etat.POURSUIVRE
	_prochaine_attaque = Regles.maintenant() + 0.6
	combat.noter_combat()
	var entraide := float(_donnees.get("entraide", 0))
	if entraide > 0.0:
		for autre in get_tree().get_nodes_in_group("loups"):
			if autre != self and autre.faction == faction and autre.camp.distance_to(camp) < entraide:
				autre.engager(cible)


func _sur_degats(_montant: float, source: Combattant) -> void:
	if source != null and is_instance_valid(source) and source.est_vivant():
		engager(source)


func _sur_mort(_tueur: Combattant) -> void:
	etat = Etat.MORT
	_moment_mort = Regles.maintenant()
	_cible = null
	collision_layer = 0
	if maitre != null:
		get_tree().create_timer(3.0).timeout.connect(queue_free)


func _abandonner() -> void:
	_cible = null
	combat.menace.clear()
	if maitre != null:
		etat = Etat.ERRER
		return
	etat = Etat.RETOUR
	combat.ajouter_effet("evite", 60.0)


func _reapparaitre() -> void:
	global_position = camp + Vector3.UP * 0.5
	reset_physics_interpolation()
	collision_layer = Regles.COUCHE_PERSONNAGES
	combat.reanimer(100.0)
	etat = Etat.ERRER


func _disparaitre() -> void:
	combat.pv = 0.0
	queue_free()


func _cible_du_maitre() -> Combattant:
	var combat_maitre: Combattant = maitre.get_node_or_null("Combat")
	if combat_maitre == null:
		return null
	# La cible du joueur, si c'est un ennemi vivant…
	var combat_joueur = maitre.get_node_or_null("CombatJoueur")
	if combat_joueur != null and combat_joueur.cible != null and is_instance_valid(combat_joueur.cible) \
			and combat_joueur.cible.est_vivant() and combat.est_hostile(combat_joueur.cible):
		return combat_joueur.cible
	# … sinon un ennemi proche qui est en train de combattre.
	for c in Regles.hostiles_autour(combat, maitre.global_position, float(_donnees.get("distance_detection", 15))):
		if c.en_combat():
			return c
	return null



@rpc("authority", "call_local", "unreliable")
func _mordre() -> void:
	if apparence.has_method("mordre"):
		apparence.mordre()


## Chez les joueurs : le loup glisse vers la position envoyée par le serveur.
func _suivre_le_reseau(delta: float) -> void:
	if position_reseau == Vector3.ZERO:
		return
	if global_position.distance_to(position_reseau) > 6.0:
		global_position = position_reseau
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(position_reseau, clampf(12.0 * delta, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, lacet_reseau, clampf(12.0 * delta, 0.0, 1.0))
	# Un loup mort ne bloque plus le passage.
	collision_layer = 0 if etat == Etat.MORT else Regles.COUCHE_PERSONNAGES
	if apparence.has_method("animer"):
		apparence.animer(delta, vitesse_reseau, etat == Etat.MORT)
