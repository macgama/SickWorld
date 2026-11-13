@tool
extends Node3D
## Apparence du joueur : agent de la Vigie (personnage MakeHuman animé avec Mixamo).
##
## Même interface que apparence_provisoire.gd : le Joueur appelle animer() à chaque
## image physique et attaquer() quand il frappe. L'agent réagit aussi tout seul aux
## dégâts (touche) et à la mort (mourir) en surveillant le nœud Combat du joueur.
##
## Fichiers : res://assets/personnages/<modele>/
##   immobile.fbx  personnage + squelette + animation de repos
##   courir, reculer, pas_gauche, pas_droite, saut, chute, roulade, attaque,
##   touche, mort (.fbx) : animations seules, même squelette
##   textures/     textures MakeHuman (réappliquées ici : Mixamo ne les garde pas)

## Animations qui tournent en boucle.
const EN_BOUCLE := ["immobile", "courir", "reculer", "pas_gauche", "pas_droite", "chute"]
const ANIMATIONS := ["immobile", "courir", "reculer", "pas_gauche", "pas_droite", "saut", "chute",
	"roulade", "attaque", "touche", "mort"]
## Vitesse (m/s) à laquelle chaque animation de déplacement est jouée à vitesse normale.
const VITESSE_NATURELLE := {"courir": 5.0, "reculer": 2.0, "pas_gauche": 4.5, "pas_droite": 4.5}
const FONDU := 0.18

@export_enum("homme", "femme") var modele := "homme":
	set(valeur):
		modele = valeur
		if is_inside_tree():
			_construire()
@export_range(0.5, 1.5, 0.01) var echelle := 1.0:
	set(valeur):
		echelle = valeur
		if _corps:
			_corps.scale = Vector3.ONE * echelle

## Animations déjà préparées, partagées par tous les personnages du même modèle.
static var _bibliotheques := {}

var _corps: Node3D
var _lecteur: AnimationPlayer
var _actuelle := ""
var _verrou := 0.0          # durée pendant laquelle une action (attaque, touché) garde la main
var _temps_en_l_air := 0.0
var _mort := false
var _pv_precedents := -1.0
var _combat: Node


func _ready() -> void:
	_construire()
	if not Engine.is_editor_hint():
		_combat = get_parent().get_node_or_null("Combat")


func _dossier() -> String:
	return "res://assets/personnages/%s/" % modele


func _construire() -> void:
	if _corps:
		_corps.free()
		_corps = null
	_actuelle = ""
	var scene := load(_dossier() + "immobile.fbx") as PackedScene
	if scene == null:
		push_warning("Personnage introuvable : " + _dossier())
		return
	_corps = scene.instantiate() as Node3D
	_corps.name = "Corps"
	# Les personnages Mixamo regardent vers +Z ; le jeu considère que -Z est devant.
	_corps.rotation.y = PI
	_corps.scale = Vector3.ONE * echelle
	add_child(_corps)
	_appliquer_materiaux()
	_lecteur = _corps.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_lecteur.add_animation_library("agent", _bibliotheque(modele))
	_jouer("immobile", 0.0)


# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------
static func _bibliotheque(nom_modele: String) -> AnimationLibrary:
	if _bibliotheques.has(nom_modele):
		return _bibliotheques[nom_modele]
	var bib := AnimationLibrary.new()
	for nom in ANIMATIONS:
		var scene := load("res://assets/personnages/%s/%s.fbx" % [nom_modele, nom]) as PackedScene
		if scene == null:
			continue
		var racine := scene.instantiate()
		var lecteur := racine.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var anim := (lecteur.get_animation(lecteur.get_animation_list()[0]) as Animation).duplicate(true)
		racine.free()
		anim.loop_mode = Animation.LOOP_LINEAR if nom in EN_BOUCLE else Animation.LOOP_NONE
		if nom != "mort":
			_retirer_deplacement(anim)
		bib.add_animation(nom, anim)
	_bibliotheques[nom_modele] = bib
	return bib


## Le jeu déplace lui-même le personnage : on supprime le déplacement horizontal
## des hanches (root motion) pour que l'animation reste sur place.
static func _retirer_deplacement(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not String(anim.track_get_path(i)).ends_with("Hips"):
			continue
		if anim.track_get_key_count(i) == 0:
			return
		var depart: Vector3 = anim.track_get_key_value(i, 0)
		for k in anim.track_get_key_count(i):
			var p: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(depart.x, p.y, depart.z))
		return


func _jouer(nom: String, fondu := FONDU, vitesse := 1.0, depuis := -1.0) -> void:
	if _lecteur == null:
		return
	var cle := "agent/" + nom
	if not _lecteur.has_animation(cle):
		return
	if _actuelle == nom:
		return
	_lecteur.speed_scale = 1.0
	_lecteur.play(cle, fondu, vitesse)
	if depuis >= 0.0:
		_lecteur.seek(depuis, true)
	_actuelle = nom


func _duree(nom: String) -> float:
	var cle := "agent/" + nom
	return _lecteur.get_animation(cle).length if _lecteur and _lecteur.has_animation(cle) else 0.0


# ---------------------------------------------------------------------------
# Interface utilisée par le Joueur
# ---------------------------------------------------------------------------
## Coup (attaque de base ou compétence).
func attaquer() -> void:
	if _mort or _lecteur == null:
		return
	_actuelle = ""
	_jouer("attaque", 0.08, 1.8, 0.15)
	_verrou = 0.55


## Réaction quand le personnage reçoit des dégâts.
func touche() -> void:
	if _mort or _verrou > 0.0 or _lecteur == null:
		return
	_actuelle = ""
	_jouer("touche", 0.08, 1.4)
	_verrou = 0.35


## Le personnage tombe (désynchronisé).
func mourir() -> void:
	if _mort:
		return
	_mort = true
	_jouer("mort", 0.15)


## Le personnage est réanimé.
func revivre() -> void:
	_mort = false
	_verrou = 0.0
	_jouer("immobile", 0.2)


## Le Joueur n'appelle plus animer() quand il est désynchronisé : on surveille donc
## le Combattant ici, à chaque image.
func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_surveiller_combat()


func _surveiller_combat() -> void:
	if _combat == null or not is_instance_valid(_combat):
		return
	var pv: float = _combat.pv
	var vivant: bool = _combat.est_vivant()
	if not vivant and not _mort:
		mourir()
	elif vivant and _mort:
		revivre()
	elif _pv_precedents >= 0.0 and pv < _pv_precedents - 0.5:
		touche()
	_pv_precedents = pv


## Appelée par le Joueur à chaque image physique.
## vitesse_locale : vitesse dans le repère du personnage (-Z = devant).
## progression_esquive : -1 hors roulade, sinon de 0 à 1.
func animer(delta: float, vitesse_locale: Vector3, au_sol: bool, progression_esquive: float,
		direction_esquive: Vector3) -> void:
	if _lecteur == null or Engine.is_editor_hint():
		return
	if _mort:
		return
	_verrou = maxf(0.0, _verrou - delta)

	# Roulade : jouée au rythme de l'esquive, tournée vers la direction de l'esquive.
	if progression_esquive >= 0.0:
		var d := Vector3(direction_esquive.x, 0.0, direction_esquive.z)
		var lacet := atan2(-d.x, -d.z) if d.length() > 0.01 else 0.0
		_corps.rotation.y = lerp_angle(_corps.rotation.y, PI + lacet, clampf(20.0 * delta, 0.0, 1.0))
		if _actuelle != "roulade":
			_jouer("roulade", 0.08)
			_lecteur.pause()
		# La roulade proprement dite occupe le milieu de l'animation Mixamo.
		var t := lerpf(0.18, 0.8, progression_esquive) * _duree("roulade")
		_lecteur.seek(t, true)
		_verrou = 0.0
		return
	_corps.rotation.y = lerp_angle(_corps.rotation.y, PI, clampf(15.0 * delta, 0.0, 1.0))
	if _actuelle == "roulade":
		_actuelle = ""

	if _verrou > 0.0:
		return

	if not au_sol:
		_temps_en_l_air += delta
		if _temps_en_l_air < 0.45:
			if _actuelle != "saut":
				# On saute directement au moment de l'impulsion.
				_jouer("saut", 0.1, 1.3, 0.3 * _duree("saut"))
		else:
			_jouer("chute", 0.3)
		return
	_temps_en_l_air = 0.0

	var horizontale := Vector2(vitesse_locale.x, vitesse_locale.z)
	var vitesse := horizontale.length()
	if vitesse < 0.4:
		_jouer("immobile", 0.25)
		return
	var nom := "courir"
	if absf(vitesse_locale.x) > absf(vitesse_locale.z) * 1.2:
		nom = "pas_droite" if vitesse_locale.x > 0.0 else "pas_gauche"
	elif vitesse_locale.z > 0.0:
		nom = "reculer"
	var allure := clampf(vitesse / float(VITESSE_NATURELLE[nom]), 0.6, 2.2)
	_jouer(nom, FONDU)
	_lecteur.speed_scale = allure


# ---------------------------------------------------------------------------
# Matériaux (Mixamo ne garde pas les textures : on les réapplique)
# ---------------------------------------------------------------------------
func _texture(debut: String, contient := "") -> Texture2D:
	var dossier := _dossier() + "textures/"
	for nom in ResourceLoader.list_directory(dossier):
		if not (nom.ends_with(".png") or nom.ends_with(".jpg")):
			continue
		if nom.begins_with(debut) and (contient == "" or nom.contains(contient)):
			return load(dossier + nom) as Texture2D
	return null


func _appliquer_materiaux() -> void:
	for n in _corps.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var base := String(mi.name).trim_suffix("Mesh")
		var m := StandardMaterial3D.new()
		m.roughness = 0.75
		if base.contains("1591") or base.contains("1605") or base.contains("proxy") or base.contains("generic"):
			# Peau : moins cireuse, avec un peu de diffusion sous la surface.
			m.albedo_texture = _texture("young_", "skinned")
			m.roughness = 0.6
			m.metallic_specular = 0.35
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.25
			m.subsurf_scatter_skin_mode = true
		elif base.contains("poly"):
			m.albedo_texture = _texture("", "_eye")
			m.roughness = 0.15
		else:
			m.albedo_texture = _texture(base + "_diffuse")
			if m.albedo_texture == null:
				m.albedo_texture = _texture(base)
			var normale := _texture(base + "_normal")
			if normale:
				m.normal_enabled = true
				m.normal_texture = normale
				m.normal_scale = 0.6
			if base.begins_with("eyebrow") or base.begins_with("eyelash") or _est_cheveux(base):
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.35
				m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.roughness = 0.55
		mi.material_override = m


func _est_cheveux(base: String) -> bool:
	for k in ["short", "ponytail", "bob", "long", "braid", "afro", "hair"]:
		if base.begins_with(k):
			return true
	return false
