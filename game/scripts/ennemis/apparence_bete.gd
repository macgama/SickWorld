@tool
extends Node3D
## Apparence des grandes bêtes avec de vrais modèles 3D (CC-BY, voir
## assets/animaux/CREDITS.md) :
## - « leopard » : léopard de Rome, fait d'une panthère noire (kenchoo) dont on
##   peint la robe dorée tachetée. Une seule animation d'attente : sa marche et sa
##   course sont faites ici, en bougeant ses pattes.
## - « hippopotame » (Égypte, planeta-elefante) : attente, marche, course, attaque, mort.
## - « rhinoceros » (Rome, LasquetiSpice) : une seule course en boucle, jouée plus
##   ou moins vite ; à l'arrêt il reste debout.
## - « sanglier » (Grèce, Rome, Chine, Moyen Âge ; Dakta.Grower.Nzl) : 73 animations,
##   mais pas de texture : on lui peint un pelage brun-noir.
##
## Chaque modèle est remis droit à l'ouverture : on lit son squelette (tête, bassin,
## pieds) pour le tourner vers -Z, le poser au sol et le centrer.
## Les bêtes fracturées ont les yeux violets.
##
## Appelé par apparence_loup.gd (même interface : animer, mordre, colorer).
## Si un modèle manque, apparence_loup.gd garde l'ancienne apparence.

const MODELES := {
	"leopard": "res://assets/animaux/panthere/scene.gltf",
	"hippopotame": "res://assets/animaux/hippopotame/scene.gltf",
	"rhinoceros": "res://assets/animaux/rhinoceros/scene.gltf",
	"sanglier": "res://assets/animaux/sanglier/scene.gltf",
}

## Réglages de chaque modèle. « taille » : hauteur du garrot voulue (en mètres) ;
## « garrot » : l'os qui la donne. Les « clips » sont cherchés par morceau de nom.
const FICHES := {
	"leopard": {
		"taille": 0.62, "garrot": "Bip001 Spine3_33",
		"tete": "Bip001 Head_23", "bassin": "Bip001 Pelvis_47",
		"pieds": ["Bip001 L Toe0_37", "Bip001 R Toe0_42", "Bip001 L Finger0_28", "Bip001 R Finger0_7"],
		"machoire": "Bip001 Xtra02_20",
		"gauche": "Bip001 L Thigh_41", "droite": "Bip001 R Thigh_46",
		# Pattes : avant gauche, avant droite, arrière gauche, arrière droite.
		"cuisses": ["Bip001 L UpperArm_31", "Bip001 R UpperArm_10", "Bip001 L Thigh_41", "Bip001 R Thigh_46"],
		"jarrets": ["Bip001 L Forearm_30", "Bip001 R Forearm_9", "Bip001 L Calf_40", "Bip001 R Calf_45"],
		"plis": [0.7, -0.6],
		"foulee": 1.5,
		"queue": "Bone001_5",
		"yeux_os": ["Bip001 Xtra01_17", "Bip001 Xtra01Opp_18"],
		"rayon_oeil": 0.014,
		"procedural": true,
	},
	"hippopotame": {
		"taille": 1.4, "garrot": "Bip01_Spine2_020",
		"tete": "Bip01_Head_022", "bassin": "Bip01_Pelvis_02",
		"pieds": ["Bip01_R_Toe0_010", "Bip01_L_Toe0_016", "Bip01_R_Finger0Nub_034", "Bip01_L_Finger0Nub_040"],
		# Ses os d'yeux sont mal placés : yeux relevés sur la texture (repère du squelette).
		"yeux_repos": [Vector3(131.0, 109.7, 14.3), Vector3(131.0, 109.7, -14.3)],
		"rayon_oeil": 0.03,
		"clips": {"attente": "|Idle|", "marche": "|Walk|", "course": "|Run|", "attaque": "|Attack|", "mort": "|Die|"},
		"vitesse_marche": 1.3, "vitesse_course": 4.5,
	},
	"rhinoceros": {
		"taille": 1.35, "garrot": "Spine3.8_8",
		"tete": "Head.10_10", "bassin": "Root.4_4",
		"pieds": ["L_Ball.66_66", "R_Ball.73_73", "L_Finger2.49_49", "R_Finger2.60_60"],
		"yeux_os": ["L_Eye.35_35", "R_Eye.38_38"],
		"rayon_oeil": 0.035,
		"clips": {"course": "Animation"},
		"vitesse_course": 6.0,
		"metal": false,
	},
	"sanglier": {
		"taille": 0.85, "garrot": "Spine_01_06_12",
		"tete": "head_08_14", "bassin": "Spine_base_02_8",
		"pieds": ["hoof_f.L_022_29", "hoof_f.R_027_34", "hoof_b.L_035_42", "hoof_b.R_039_46"],
		"yeux_os": ["eye.L_016_23", "eye.R_017_24"],
		"rayon_oeil": 0.02,
		"clips": {"attente": "|Idle_1", "marche": "|Walk_F_IP", "course": "|Run_F_IP", "trot": "|Trot_F_IP",
				"attaque": "|Attack_F", "mort": "|Death_L"},
		"vitesse_marche": 1.2, "vitesse_trot": 3.0, "vitesse_course": 6.0,
		# Le modèle n'a pas de texture : pelage brun-noir, plus clair sur le groin.
		"pelage": Color(0.3, 0.25, 0.2),
	},
}

var espece := "sanglier"
## Faux pour une bête saine : pas d'yeux violets.
var fracture := true
var _fiche: Dictionary
var _pivot: Node3D
var _modele: Node3D
var _squelette: Skeleton3D
var _anim: AnimationPlayer
var _clips := {}
var _anim_courante := ""
var _lateral := Vector3.RIGHT
var _phase := 0.0
var _morsure := 0.0
var _attaque := 0.0
var _mort := 0.0
var _os := {}
static var _mat_oeil: StandardMaterial3D
static var _robe_leopard: StandardMaterial3D
static var _pelage_sanglier: StandardMaterial3D


## Vrai si le modèle de cette espèce est présent (sinon on garde l'ancienne apparence).
static func disponible(nom: String) -> bool:
	return MODELES.has(nom) and ResourceLoader.exists(MODELES[nom])


func _ready() -> void:
	_construire()


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	_fiche = FICHES[espece]
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_modele = (load(MODELES[espece]) as PackedScene).instantiate()
	_pivot.add_child(_modele)
	var squelettes := _modele.find_children("*", "Skeleton3D", true, false)
	_squelette = squelettes[0] if not squelettes.is_empty() else null
	var lecteurs := _modele.find_children("*", "AnimationPlayer", true, false)
	_anim = lecteurs[0] if not lecteurs.is_empty() else null
	if _squelette == null:
		return
	for cle in ["tete", "bassin", "machoire", "gauche", "droite", "queue", "garrot"]:
		_os[cle] = _squelette.find_bone(str(_fiche.get(cle, "")))
	for cle in ["cuisses", "jarrets", "pieds", "yeux_os"]:
		var liste: Array[int] = []
		for nom in _fiche.get(cle, []):
			liste.append(_squelette.find_bone(nom))
		_os[cle] = liste
	_redresser()
	_habiller()
	if _os["gauche"] >= 0 and _os["droite"] >= 0:
		_lateral = (_squelette.get_bone_global_rest(_os["gauche"]).origin
				- _squelette.get_bone_global_rest(_os["droite"]).origin).normalized()
	if _anim != null:
		# C'est nous qui faisons avancer l'animation (pour pouvoir corriger la pose ensuite).
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_preparer_clips()
		_jouer(_clips.get("attente", ""))
		if _clips.has("attente"):
			_anim.advance(0.0)
	if fracture:
		_poser_yeux()


## Repère du squelette vu depuis le modèle (en remontant les nœuds un à un, sans
## avoir besoin d'être dans l'arbre de la scène).
func _repere_squelette() -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = _squelette
	while n != null and n != _modele:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _position_os(os: int, repere: Transform3D) -> Vector3:
	return repere * _squelette.get_bone_global_rest(os).origin


## Tourne le modèle vers -Z, le met à la bonne taille, pieds au sol et centré.
func _redresser() -> void:
	var repere := _repere_squelette()
	var tete := _position_os(_os["tete"], repere)
	var bassin := _position_os(_os["bassin"], repere)
	var avant := Vector3(tete.x - bassin.x, 0.0, tete.z - bassin.z).normalized()
	var tourne := Basis.looking_at(avant, Vector3.UP).inverse()
	var centre := Vector3.ZERO
	var sol := INF
	for os: int in _os["pieds"]:
		var p := _position_os(os, repere)
		centre += p
		sol = minf(sol, p.y)
	centre /= maxf(1.0, float(_os["pieds"].size()))
	var garrot := _position_os(_os["garrot"], repere).y if _os["garrot"] >= 0 else tete.y
	var echelle := float(_fiche["taille"]) / maxf(garrot - sol, 0.01)
	var base := tourne.scaled(Vector3.ONE * echelle)
	_modele.transform = Transform3D(base, -(base * Vector3(centre.x, sol, centre.z)))


## Matériaux : sans émission ni métal parasites, robe du léopard, pelage du sanglier.
func _habiller() -> void:
	for mi in _modele.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var copie := mat.duplicate() as BaseMaterial3D
			# La panthère est « éclairée de l'intérieur » : elle paraîtrait plate.
			copie.emission_enabled = false
			if not _fiche.get("metal", true) or espece == "leopard":
				copie.metallic = 0.0
				copie.metallic_texture = null
				copie.roughness = maxf(copie.roughness, 0.75)
			if espece == "leopard" and m.name in ["Object_8", "Object_9", "Object_11"]:
				copie = _robe_tachetee()
			elif espece == "sanglier":
				copie = _pelage()
			m.set_surface_override_material(i, copie)


## Robe dorée du léopard, tachetée de rosettes sombres.
static func _robe_tachetee() -> StandardMaterial3D:
	if _robe_leopard != null:
		return _robe_leopard
	var taches := NoiseTexture2D.new()
	taches.width = 256
	taches.height = 256
	taches.seamless = true
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_CELLULAR
	bruit.frequency = 0.035
	bruit.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	taches.noise = bruit
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.1, 0.07, 0.04))
	degrade.set_color(1, Color(1.0, 0.97, 0.9))
	degrade.add_point(0.2, Color(0.1, 0.07, 0.04))
	degrade.add_point(0.28, Color(1.0, 0.97, 0.9))
	taches.color_ramp = degrade
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.58, 0.42, 0.25)
	robe.albedo_texture = taches
	robe.uv1_scale = Vector3(2.0, 2.0, 1.0)
	robe.roughness = 0.85
	robe.cull_mode = BaseMaterial3D.CULL_DISABLED
	_robe_leopard = robe
	return robe


static func _pelage() -> StandardMaterial3D:
	if _pelage_sanglier != null:
		return _pelage_sanglier
	var poils := NoiseTexture2D.new()
	poils.width = 256
	poils.height = 256
	poils.seamless = true
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.08
	bruit.fractal_octaves = 4
	poils.noise = bruit
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.6, 0.56, 0.52))
	degrade.set_color(1, Color(1.2, 1.12, 1.05))
	poils.color_ramp = degrade
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FICHES["sanglier"]["pelage"]
	mat.albedo_texture = poils
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(6.0, 6.0, 6.0)
	mat.roughness = 0.95
	var relief := NoiseTexture2D.new()
	relief.width = 256
	relief.height = 256
	relief.seamless = true
	relief.as_normal_map = true
	relief.bump_strength = 3.0
	relief.noise = bruit
	mat.normal_enabled = true
	mat.normal_texture = relief
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pelage_sanglier = mat
	return mat


## Retrouve les animations de la fiche par morceau de nom, et fait boucler les allures.
func _preparer_clips() -> void:
	var noms := _anim.get_animation_list()
	if _fiche.get("procedural", false):
		if not noms.is_empty():
			_clips["attente"] = noms[0]
			_anim.get_animation(noms[0]).loop_mode = Animation.LOOP_LINEAR
		return
	var voulus: Dictionary = _fiche.get("clips", {})
	for cle in voulus:
		for nom in noms:
			if str(nom).contains(voulus[cle]):
				_clips[cle] = nom
				break
	for cle in ["attente", "marche", "trot", "course"]:
		if _clips.has(cle):
			_anim.get_animation(_clips[cle]).loop_mode = Animation.LOOP_LINEAR
	for cle in ["attaque", "mort"]:
		if _clips.has(cle):
			_anim.get_animation(_clips[cle]).loop_mode = Animation.LOOP_NONE


func _jouer(nom: String, fondu := 0.25, vitesse := 1.0) -> void:
	if _anim == null or nom == "" or not _anim.has_animation(nom):
		return
	_anim.speed_scale = vitesse
	if nom == _anim_courante:
		return
	_anim_courante = nom
	_anim.play(nom, fondu)


## Les yeux « comme des braises violettes » : deux petites lueurs sur les os des yeux.
func _poser_yeux() -> void:
	if _mat_oeil == null:
		_mat_oeil = StandardMaterial3D.new()
		_mat_oeil.albedo_color = Color(0.12, 0.02, 0.2)
		_mat_oeil.emission_enabled = true
		_mat_oeil.emission = Color(0.55, 0.12, 0.95)
		_mat_oeil.emission_energy_multiplier = 1.8
	# Le rayon est en mètres : on le ramène à l'échelle du squelette.
	var echelle := (_modele.transform * _repere_squelette()).basis.get_scale().x
	var rayon := float(_fiche["rayon_oeil"]) / maxf(echelle, 0.0001)
	var tete: int = _os["tete"]
	if _fiche.has("yeux_repos"):
		var accroche := BoneAttachment3D.new()
		accroche.name = "Yeux"
		accroche.bone_idx = tete
		_squelette.add_child(accroche)
		var repos_tete := _squelette.get_bone_global_rest(tete)
		for p: Vector3 in _fiche["yeux_repos"]:
			var dehors := (p - repos_tete.origin).normalized() * rayon * 0.6
			accroche.add_child(_oeil(rayon, repos_tete.affine_inverse() * (p + dehors)))
		return
	for os: int in _os["yeux_os"]:
		if os < 0:
			continue
		var accroche := BoneAttachment3D.new()
		accroche.name = "Yeux"
		accroche.bone_idx = os
		_squelette.add_child(accroche)
		# L'os de l'œil est au fond de l'orbite : on sort la lueur vers l'extérieur
		# (à l'opposé du centre de la tête), pour qu'elle affleure.
		var repos := _squelette.get_bone_global_rest(os)
		var dehors := repos.origin - _squelette.get_bone_global_rest(tete).origin
		var decale := repos.basis.inverse() * (dehors.normalized() * rayon * float(_fiche.get("sortie_oeil", 1.0)))
		accroche.add_child(_oeil(rayon, decale))


func _oeil(rayon: float, ou: Vector3) -> MeshInstance3D:
	var oeil := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 10
	s.rings = 6
	oeil.mesh = s
	oeil.material_override = _mat_oeil
	oeil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	oeil.position = ou
	return oeil


func colorer(allie: bool) -> void:
	if not allie or _modele == null:
		return
	var lueur := StandardMaterial3D.new()
	lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lueur.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lueur.albedo_color = Color(0.1, 0.35, 0.45)
	for mi in _modele.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = lueur


func mordre() -> void:
	if _clips.has("attaque"):
		_attaque = _anim.get_animation(_clips["attaque"]).length
		_anim_courante = ""
		_jouer(_clips["attaque"], 0.15)
	else:
		_morsure = 0.4


func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _pivot == null:
		return
	if mort:
		_animer_mort(delta)
		return
	if _mort > 0.0:
		_mort = 0.0
		_pivot.rotation.z = 0.0
		_pivot.position.y = 0.0
		_anim_courante = ""
	_morsure = maxf(0.0, _morsure - delta)
	var mord := sin(clampf(_morsure / 0.4, 0.0, 1.0) * PI)
	_pivot.position.z = -mord * 0.3
	if _attaque > 0.0:
		_attaque -= delta
		if _anim != null:
			_anim.advance(delta)
		return
	if _fiche.get("procedural", false):
		_animer_pattes(delta, vitesse)
	else:
		_animer_clips(delta, vitesse)
	_corriger_tete(mord)


func _animer_mort(delta: float) -> void:
	if _clips.has("mort"):
		if _mort == 0.0:
			_anim_courante = ""
			_jouer(_clips["mort"], 0.2)
		_mort += delta
		_anim.advance(delta)
		return
	# Sans animation de mort : il s'effondre sur le flanc, figé.
	_mort = minf(1.0, _mort + delta * 2.5)
	_pivot.rotation.z = lerpf(0.0, PI / 2, _mort)
	_pivot.position.y = lerpf(0.0, float(_fiche["taille"]) * 0.3, _mort)


## Choisit l'allure selon la vitesse et règle la cadence de l'animation.
func _animer_clips(delta: float, vitesse: float) -> void:
	if _anim == null:
		return
	var marche := float(_fiche.get("vitesse_marche", 1.2)) * scale.x
	var trot := float(_fiche.get("vitesse_trot", 0.0)) * scale.x
	var course := float(_fiche.get("vitesse_course", 5.0)) * scale.x
	if vitesse < 0.3:
		if _clips.has("attente"):
			_jouer(_clips["attente"], 0.35)
		else:
			# Pas d'attente (le rhinocéros) : il se fige debout, au repos.
			if _anim_courante != "":
				_anim.stop()
				_anim_courante = ""
				_squelette.reset_bone_poses()
			return
	elif _clips.has("marche") and (vitesse < (trot if trot > 0.0 else course) * 0.6 or not _clips.has("course")):
		_jouer(_clips["marche"], 0.25, clampf(vitesse / maxf(marche, 0.1), 0.6, 2.0))
	elif trot > 0.0 and _clips.has("trot") and vitesse < course * 0.75:
		_jouer(_clips["trot"], 0.25, clampf(vitesse / maxf(trot, 0.1), 0.6, 1.8))
	else:
		_jouer(_clips["course"], 0.25, clampf(vitesse / maxf(course, 0.1), 0.45, 1.8))
	_anim.advance(delta)


## Le léopard n'a qu'une attente : au pas et à la course, on bouge ses pattes nous-mêmes.
func _animer_pattes(delta: float, vitesse: float) -> void:
	if _anim == null or _squelette == null:
		return
	if vitesse < 0.3:
		if _anim_courante == "":
			_squelette.reset_bone_poses()
		_jouer(_clips.get("attente", ""), 0.3)
		_anim.advance(delta)
		return
	_anim_courante = ""
	_anim.stop()
	_squelette.reset_bone_poses()
	var allure := clampf(vitesse / 6.0, 0.0, 1.0)
	_phase = fmod(_phase + delta * vitesse / maxf(float(_fiche["foulee"]) * scale.x, 0.1) * TAU, TAU * 8.0)
	var decalage := lerpf(PI, 0.7, allure)
	var phases := [0.0, PI, decalage, decalage + PI]
	var amplitude := lerpf(0.35, 0.55, allure)
	var plis: Array = _fiche["plis"]
	var cuisses: Array[int] = _os["cuisses"]
	var jarrets: Array[int] = _os["jarrets"]
	for k in 4:
		var p: float = _phase + phases[k]
		_tourner(cuisses[k], -sin(p) * amplitude)
		_tourner(jarrets[k], maxf(0.0, cos(p)) * float(plis[0] if k < 2 else plis[1]) * (0.5 + allure))
	_tourner(_os.get("queue", -1), -0.2 - 0.15 * sin(_phase * 2.0))
	_pivot.position.y = absf(sin(_phase)) * 0.05 * allure


func _corriger_tete(mord: float) -> void:
	if _squelette == null or mord <= 0.0:
		return
	_tourner(_os.get("tete", -1), mord * 0.35)
	_tourner(_os.get("machoire", -1), mord * 0.5)


## Fait pivoter un os autour de l'axe gauche-droite du corps.
## Angle positif : vers le bas (la tête plonge, la gueule s'ouvre, la patte recule).
func _tourner(os: int, angle: float) -> void:
	if os < 0 or absf(angle) < 0.0001:
		return
	var axe := (_squelette.get_bone_global_pose(os).basis.inverse() * _lateral).normalized()
	_squelette.set_bone_pose_rotation(os, _squelette.get_bone_pose_rotation(os) * Quaternion(axe, angle))
