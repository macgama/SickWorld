class_name CombatJoueur
extends Node
## Le combat du joueur : ciblage (Tab, clic), barre de 8 compétences (touches 1 à 8),
## attaque automatique, temps de recharge, incantations, mort et réapparition.
##
## Les compétences sont décrites dans data/competences.json
## et la barre dans data/joueur.json.

signal cible_changee(cible: Combattant)
signal message(texte: String)
signal incantation_changee(nom: String, progression: float)
signal desynchronise
signal resynchronise

const SCENE_LOUP := preload("res://scenes/ennemis/loup.tscn")
const PORTEE_CIBLAGE := 45.0

var cible: Combattant = null
var barre: Array[String] = []
## id de compétence -> moment où elle sera de nouveau disponible
var recharges := {}
var fin_recharge_globale := 0.0
var elan := 0.0
var elan_max := 100.0
var attaque_auto := false

var _reglages: Dictionary
var _prochaine_attaque_auto := 0.0
var _incantation_id := ""
var _incantation_debut := 0.0
var _incantation_fin := 0.0
var _anneau: MeshInstance3D

@onready var joueur: Joueur = get_parent()
@onready var combat: Combattant = get_parent().get_node("Combat")


func _ready() -> void:
	_reglages = Donnees.joueur
	for id in _reglages.get("barre", []):
		barre.append(String(id))
	elan_max = float(_reglages.get("elan_max", 100))
	combat.nom_affiche = String(_reglages.get("nom", "Agent de la Vigie"))
	combat.niveau = int(_reglages.get("niveau", 1))
	combat.pv_max = float(_reglages.get("points_de_vie", 200))
	combat.pv = combat.pv_max
	combat.faction = "joueur"
	combat.hauteur_centre = 1.1
	combat.mort.connect(_sur_mort)
	(joueur.get_node("CameraRig") as CameraJoueur).clic_simple.connect(_sur_clic)
	_creer_anneau()


# --- Commandes -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cible_suivante"):
		cibler_suivant()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("annuler"):
		if _incantation_id != "":
			_interrompre("Annulé")
		else:
			changer_cible(null)
	else:
		for i in 8:
			if event.is_action_pressed("competence_%d" % (i + 1)):
				utiliser(i)
				get_viewport().set_input_as_handled()
				return


func _sur_clic(bouton: int, position_ecran: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origine := camera.project_ray_origin(position_ecran)
	var fin := origine + camera.project_ray_normal(position_ecran) * 200.0
	var requete := PhysicsRayQueryParameters3D.create(origine, fin,
			Regles.COUCHE_MONDE | Regles.COUCHE_PERSONNAGES, [joueur.get_rid()])
	var touche := joueur.get_world_3d().direct_space_state.intersect_ray(requete)
	if touche.is_empty():
		return
	var c := (touche.collider as Node).get_node_or_null("Combat") as Combattant
	if c != null and c.est_vivant():
		changer_cible(c)
		# Clic droit sur un ennemi : on l'attaque, comme dans WoW.
		if bouton == MOUSE_BUTTON_RIGHT and combat.est_hostile(c):
			attaque_auto = true


func changer_cible(nouvelle: Combattant) -> void:
	if nouvelle == cible:
		return
	cible = nouvelle
	attaque_auto = false
	cible_changee.emit(cible)


## Touche Tab : passe à l'ennemi suivant, en commençant par les plus proches devant la caméra.
func cibler_suivant() -> void:
	var camera := get_viewport().get_camera_3d()
	var candidats: Array = []
	for c in Regles.hostiles_autour(combat, joueur.global_position, PORTEE_CIBLAGE):
		if camera != null and camera.is_position_behind(c.centre()):
			continue
		if not Regles.ligne_de_vue(combat, c):
			continue
		candidats.append(c)
	if candidats.is_empty():
		message.emit("Aucun ennemi en vue")
		return
	candidats.sort_custom(func(a, b): return Regles.distance(combat, a) < Regles.distance(combat, b))
	var index := candidats.find(cible)
	changer_cible(candidats[(index + 1) % candidats.size()])


# --- Compétences -----------------------------------------------------------

func competence(index: int) -> Dictionary:
	if index < 0 or index >= barre.size():
		return {}
	return Donnees.competence(barre[index])


## Temps restant avant de pouvoir réutiliser la compétence (secondes), et durée totale.
func recharge_restante(index: int) -> Vector2:
	if index >= barre.size():
		return Vector2.ZERO
	var t := Regles.maintenant()
	var propre := maxf(0.0, float(recharges.get(barre[index], 0.0)) - t)
	var globale := maxf(0.0, fin_recharge_globale - t)
	var duree := float(competence(index).get("recharge", 0.0))
	if propre >= globale:
		return Vector2(propre, duree)
	return Vector2(globale, float(_reglages.get("temps_de_recharge_global", 1.0)))


## Renvoie "" si la compétence peut être lancée maintenant, sinon la raison.
func raison_impossible(index: int) -> String:
	var c := competence(index)
	if c.is_empty():
		return "Emplacement vide"
	if not combat.est_vivant():
		return "Tu es désynchronisé"
	if _incantation_id != "":
		return "Déjà en train de préparer une compétence"
	if recharge_restante(index).x > 0.0:
		return "Pas encore prêt"
	if elan < float(c.get("cout_elan", 0)):
		return "Pas assez d'Élan"
	var type := String(c.get("type", ""))
	if type in ["melee", "distance", "bond"]:
		if cible == null or not is_instance_valid(cible) or not cible.est_vivant():
			return "Pas de cible"
		if not combat.est_hostile(cible):
			return "Cible invalide"
		var d := Regles.distance(combat, cible)
		if d > float(c.get("portee", 3.5)):
			return "Hors de portée"
		if d < float(c.get("portee_min", 0.0)):
			return "Trop près"
		if not Regles.ligne_de_vue(combat, cible):
			return "Cible non visible"
		if c.has("pv_cible_max_pourcent") and cible.pourcentage_pv() > float(c["pv_cible_max_pourcent"]):
			return "La cible a encore trop de vie"
	return ""


func utiliser(index: int) -> bool:
	var raison := raison_impossible(index)
	if raison != "":
		message.emit(raison)
		return false
	var c := competence(index)
	fin_recharge_globale = Regles.maintenant() + float(_reglages.get("temps_de_recharge_global", 1.0))
	if float(c.get("incantation", 0.0)) > 0.0:
		_incantation_id = barre[index]
		_incantation_debut = Regles.maintenant()
		_incantation_fin = _incantation_debut + float(c["incantation"])
		return true
	_executer(barre[index])
	return true


func _executer(id: String) -> void:
	var c := Donnees.competence(id)
	recharges[id] = Regles.maintenant() + float(c.get("recharge", 0.0))
	elan = clampf(elan - float(c.get("cout_elan", 0)) + float(c.get("gain_elan", 0)), 0.0, elan_max)
	combat.noter_combat()
	if joueur.apparence.has_method("attaquer"):
		joueur.apparence.attaquer()

	match String(c.get("type", "")):
		"melee":
			_toucher(cible, c)
			attaque_auto = true
		"bond":
			var c_cible := cible
			joueur.bondir_vers(cible.acteur(), func(): _toucher(c_cible, c))
			attaque_auto = true
		"distance":
			_lancer_projectile(cible, c)
		"zone_autour":
			for ennemi in Regles.hostiles_autour(combat, joueur.global_position, float(c.get("rayon", 5))):
				_toucher(ennemi, c)
		"zone_au_sol":
			var zone := ZoneDeFeu.new()
			zone.lanceur = combat
			zone.reglages = c
			joueur.get_parent().add_child(zone)
			zone.global_position = joueur.global_position
		"invocation":
			_invoquer(c)


func _toucher(victime: Combattant, c: Dictionary) -> void:
	if victime == null or not is_instance_valid(victime) or not victime.est_vivant():
		return
	Regles.infliger(combat, victime, Donnees.entre(c.get("degats", [0, 0])))
	if c.has("saignement") and victime.est_vivant():
		var s: Dictionary = c["saignement"]
		victime.ajouter_effet("saignement", float(s["duree"]),
				{"degats_par_seconde": float(s["degats_par_seconde"])}, combat)
	if c.has("ralenti") and victime.est_vivant():
		var r: Dictionary = c["ralenti"]
		victime.ajouter_effet("ralenti", float(r["duree"]), {"vitesse": float(r["facteur"])}, combat)


func _lancer_projectile(victime: Combattant, c: Dictionary) -> void:
	var sagaie := MeshInstance3D.new()
	var forme := CylinderMesh.new()
	forme.top_radius = 0.015
	forme.bottom_radius = 0.025
	forme.height = 1.4
	sagaie.mesh = forme
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.32, 0.2)
	sagaie.material_override = mat
	joueur.get_parent().add_child(sagaie)
	var depart := combat.centre() + Vector3.UP * 0.4
	sagaie.global_position = depart
	var arrivee := victime.centre()
	var duree := maxf(0.15, depart.distance_to(arrivee) / 35.0)
	var voler := func(t: float) -> void:
		if not is_instance_valid(victime) or not is_instance_valid(sagaie):
			return
		var p := depart.lerp(victime.centre(), t) + Vector3.UP * sin(t * PI) * 1.5
		var direction := p - sagaie.global_position
		sagaie.global_position = p
		if direction.length() > 0.001:
			sagaie.look_at(p + direction, Vector3.UP)
			sagaie.rotate_object_local(Vector3.RIGHT, PI / 2)
	var arriver := func() -> void:
		_toucher(victime, c)
		sagaie.queue_free()
	var animation := sagaie.create_tween()
	animation.tween_method(voler, 0.0, 1.0, duree)
	animation.tween_callback(arriver)


func _invoquer(c: Dictionary) -> void:
	for i in int(c.get("nombre", 2)):
		var loup: Loup = SCENE_LOUP.instantiate()
		loup.type_ennemi = "loup_allie"
		loup.faction = "joueur"
		loup.maitre = joueur
		loup.fin_invocation = Regles.maintenant() + float(c.get("duree", 20))
		joueur.get_parent().add_child(loup)
		var cote := -1.0 if i == 0 else 1.0
		loup.global_position = joueur.global_position + joueur.global_transform.basis.x * cote * 1.5 + Vector3.UP * 0.5
		loup.camp = loup.global_position


func _interrompre(texte: String) -> void:
	_incantation_id = ""
	fin_recharge_globale = 0.0
	incantation_changee.emit("", -1.0)
	message.emit(texte)


# --- Boucle ----------------------------------------------------------------

func _process(delta: float) -> void:
	var t := Regles.maintenant()

	# Cible morte ou disparue.
	if cible != null and (not is_instance_valid(cible) or not cible.est_vivant()):
		changer_cible(null)

	# Incantation en cours.
	if _incantation_id != "":
		var c := Donnees.competence(_incantation_id)
		if joueur.bouge() or not combat.est_vivant():
			_interrompre("Interrompu")
		elif cible == null:
			_interrompre("Cible perdue")
		elif t >= _incantation_fin:
			var id := _incantation_id
			_incantation_id = ""
			incantation_changee.emit("", -1.0)
			if Regles.distance(combat, cible) <= float(c.get("portee", 30)) + 2.0:
				_executer(id)
			else:
				message.emit("Hors de portée")
		else:
			incantation_changee.emit(String(c.get("nom", "")),
					(t - _incantation_debut) / (_incantation_fin - _incantation_debut))

	# Attaque automatique.
	var auto: Dictionary = _reglages.get("attaque_automatique", {})
	if attaque_auto and cible != null and combat.est_vivant() and t >= _prochaine_attaque_auto \
			and Regles.distance(combat, cible) <= float(auto.get("portee", 3.5)):
		_prochaine_attaque_auto = t + float(auto.get("intervalle", 2.0))
		Regles.infliger(combat, cible, Donnees.entre(auto.get("degats", [5, 8])))
		elan = minf(elan_max, elan + float(auto.get("gain_elan", 8)))
		if joueur.apparence.has_method("attaquer"):
			joueur.apparence.attaquer()

	# Hors combat : la vie remonte, l'Élan redescend.
	if combat.est_vivant() and not combat.en_combat():
		var regen := float(_reglages.get("regeneration_hors_combat_pourcent", 4)) / 100.0
		if combat.pv < combat.pv_max:
			combat.soigner(combat.pv_max * regen * delta)
		elan = maxf(0.0, elan - float(_reglages.get("perte_elan_hors_combat", 5)) * delta)

	_mettre_a_jour_anneau()


# --- Mort et réapparition --------------------------------------------------

func _sur_mort(_tueur: Combattant) -> void:
	_incantation_id = ""
	incantation_changee.emit("", -1.0)
	changer_cible(null)
	elan = 0.0
	desynchronise.emit()


## Bouton « Retourner à la balise » : le joueur réapparaît avec une petite pénalité.
func reapparaitre() -> void:
	var balise := get_tree().get_first_node_in_group("balises") as Node3D
	var p := joueur.global_position
	if balise != null and balise.has_method("point_de_reapparition"):
		p = balise.point_de_reapparition()
	joueur.placer(p, joueur.rotation.y)
	combat.reanimer(100.0)
	var penalite: Dictionary = _reglages.get("penalite_reapparition", {})
	var reduction := float(penalite.get("reduction_degats_pourcent", 10)) / 100.0
	combat.ajouter_effet("desynchronisation", float(penalite.get("duree", 120)),
			{"degats_infliges": 1.0 - reduction})
	resynchronise.emit()


# --- Anneau de sélection sous la cible -------------------------------------

func _creer_anneau() -> void:
	_anneau = MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 0.7
	tore.outer_radius = 0.8
	tore.rings = 32
	_anneau.mesh = tore
	_anneau.scale = Vector3(1, 0.05, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.25, 0.2)
	_anneau.material_override = mat
	_anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anneau.top_level = true
	_anneau.visible = false
	add_child.call_deferred(_anneau)


func _mettre_a_jour_anneau() -> void:
	if _anneau == null or not _anneau.is_inside_tree():
		return
	_anneau.visible = cible != null
	if cible != null:
		var mat := _anneau.material_override as StandardMaterial3D
		mat.albedo_color = Color(1, 0.25, 0.2) if combat.est_hostile(cible) else Color(0.3, 1, 0.4)
		_anneau.global_position = cible.acteur().get_global_transform_interpolated().origin + Vector3.UP * 0.05
