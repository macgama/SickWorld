@tool
extends Node3D
## Apparence des chiens du Pirée (île de Grèce), avec de vrais modèles 3D (CC-BY,
## voir assets/animaux/CREDITS.md) :
## - « chien » : chien errant roux (« Dog animated », MAXDESIGN-3D). Son unique
##   animation contient une marche et une attente : on les découpe en deux clips.
## - « molosse » : le grand chien de garde, fait à partir d'un labrador
##   (« Labrador Dog », kenchoo) assombri et grandi. Il n'a qu'une animation
##   d'attente : sa marche et sa course sont faites ici, en bougeant ses pattes.
## - « lion » : le lion de l'île de Rome (« Lion », kenchoo, même squelette que
##   le labrador). Une seule animation d'attente lui aussi : il marche et galope en code.
## Les bêtes fracturées ont les yeux violets (« fracture » à faux pour une bête saine).
##
## Appelé par apparence_loup.gd (même interface : animer, mordre, colorer).
## Si un modèle manque, apparence_loup.gd garde l'ancien chien (le loup teinté).

const MODELES := {
	"chien": "res://assets/animaux/chien/scene.gltf",
	"molosse": "res://assets/animaux/molosse/scene.gltf",
	"lion": "res://assets/animaux/lion/scene.gltf",
}

## Réglages de chaque modèle : échelle, os utiles et position des yeux (en mètres,
## par rapport à l'os de la tête, l'animal regardant vers -Z : mesurés sur des captures).
const FICHES := {
	"chien": {
		"echelle": 0.5,
		"tete": "Bip001-Head_05",
		"machoire": "Bip001-D-jaw01-01_07",
		"gauche": "Bip001-L-Thigh_024",
		"droite": "Bip001-R-Thigh_029",
		# Les clips taillés dans « Take 001 » (secondes).
		"marche": [5.6, 6.9667],
		"attente": [1.6, 5.4],
		# Vitesse de la marche du modèle, à cette échelle (m/s).
		"vitesse_marche": 1.15,
		"yeux": [Vector3(0.034, 0.025, -0.108), Vector3(-0.033, 0.025, -0.108)],
		"rayon_oeil": 0.0065,
	},
	"molosse": {
		"echelle": 0.45,
		"tete": "Head_1",
		"machoire": "",
		"gauche": "BackUpperLeg.L_25",
		"droite": "BackUpperLeg.R_29",
		# Pattes : avant gauche, avant droite, arrière gauche, arrière droite.
		"cuisses": ["FrontUpperLeg.L_17", "FrontUpperLeg.R_20", "BackUpperLeg.L_25", "BackUpperLeg.R_29"],
		"jarrets": ["FrontLowerLeg.L_16", "FrontLowerLeg.R_19", "BackLowerLeg.L_24", "BackLowerLeg.R_28"],
		"queue": "Tail1_37",
		"foulee": 1.9,
		"yeux": [Vector3(0.083, -0.027, -0.144), Vector3(-0.084, -0.027, -0.144)],
		"rayon_oeil": 0.0115,
		# Le labrador est jaune : on le rend noir comme la poix.
		"teinte": Color(0.2, 0.18, 0.18),
		"cacher": ["Object_18"],
	},
	"lion": {
		# Le modèle fait 1,86 m au garrot : un vrai lion en fait 1,1 à 1,2.
		"echelle": 0.62,
		"tete": "Head_0",
		"machoire": "",
		"gauche": "BackUpperLeg.L_16",
		"droite": "BackUpperLeg.R_20",
		# Derrière, la cuisse est « BackLeg » et le jarret « BackUpperLeg ».
		"cuisses": ["FrontUpperLeg.L_8", "FrontUpperLeg.R_11", "BackLeg.L_17", "BackLeg.R_21"],
		"jarrets": ["FrontLowerLeg.L_7", "FrontLowerLeg.R_10", "BackUpperLeg.L_16", "BackUpperLeg.R_20"],
		"queue": "Tail1_30",
		"foulee": 2.6,
		# Pli des genoux quand la patte revient en l'air (avant, arrière) : ici le
		# « jarret » arrière est le tibia, qui se replie vers l'arrière.
		"plis": [0.7, -0.2],
		"amplitude": 0.7,
		# Les pieds sont liés aux os d'IK de Blender (IK…, et leurs enfants FF/FFB),
		# qui ne suivent pas les pattes : on les recolle au bas de chaque patte (pied, patte).
		"pieds": [["IKFrontLeg.L_40", "FrontLowerLeg.L_7"], ["IKFrontLeg.R_44", "FrontLowerLeg.R_10"],
				["IKBackLeg.L_38", "BackLowerLeg.L_15"], ["IKBackLeg.R_42", "BackLowerLeg.R_19"]],
		# Ici les yeux sont donnés dans le repère du fichier, au repos (la tête du
		# modèle est tournée de côté au repos) : relevés sur les pupilles de la texture.
		"yeux_repos": [Vector3(-0.565, 2.33, 1.765), Vector3(-0.405, 2.325, 1.985)],
		"rayon_oeil": 0.04,
		# Au repos, le lion a la tête tournée d'environ 50° sur sa droite : on la
		# remet dans l'axe en répartissant la rotation sur le cou et la tête.
		"redresser": ["Neck1_5", "Neck2_4", "Neck3_3", "Head_0"],
		"redresser_angle": 50.0,
	},
}

var espece := "chien"
## Faux pour une bête qui n'est pas altérée par une fracture : pas d'yeux violets.
var fracture := true
var _fiche: Dictionary
var _pivot: Node3D
var _modele: Node3D
var _squelette: Skeleton3D
var _anim: AnimationPlayer
var _anim_courante := ""
var _lateral := Vector3.RIGHT
var _phase := 0.0
var _morsure := 0.0
var _mort := 0.0
var _os := {}


## Vrai si le modèle de cette espèce est présent (sinon on garde l'ancien chien).
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
	# Les deux modèles regardent vers +Z : on les tourne vers -Z (l'avant du jeu).
	_modele.rotation.y = PI
	_modele.scale = Vector3.ONE * float(_fiche["echelle"])
	_pivot.add_child(_modele)
	var squelettes := _modele.find_children("*", "Skeleton3D", true, false)
	_squelette = squelettes[0] if not squelettes.is_empty() else null
	var lecteurs := _modele.find_children("*", "AnimationPlayer", true, false)
	_anim = lecteurs[0] if not lecteurs.is_empty() else null
	for nom in _fiche.get("cacher", []):
		var n := _modele.find_child(nom, true, false) as Node3D
		if n != null:
			n.visible = false
	if _fiche.has("teinte"):
		_teindre(_fiche["teinte"])
	if _squelette != null:
		for cle in ["tete", "machoire", "gauche", "droite", "queue"]:
			_os[cle] = _squelette.find_bone(str(_fiche.get(cle, "")))
		for cle in ["cuisses", "jarrets", "redresser"]:
			var liste: Array[int] = []
			for nom in _fiche.get(cle, []):
				liste.append(_squelette.find_bone(nom))
			_os[cle] = liste
		# L'axe gauche-droite du squelette : on fait pivoter têtes et pattes autour.
		if _os["gauche"] >= 0 and _os["droite"] >= 0:
			_lateral = (_squelette.get_bone_global_rest(_os["gauche"]).origin
					- _squelette.get_bone_global_rest(_os["droite"]).origin).normalized()
		if fracture:
			_poser_yeux()
	if _anim != null:
		# C'est nous qui faisons avancer l'animation, pour pouvoir corriger la pose ensuite.
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if espece == "chien":
			_tailler_clips()
		else:
			var a := _anim.get_animation(_anim.get_animation_list()[0])
			a.loop_mode = Animation.LOOP_LINEAR
		_jouer(_nom_attente())


## Le chien errant n'a qu'une longue animation : on en tire une marche et une attente qui bouclent.
func _tailler_clips() -> void:
	var source_nom: String = _anim.get_animation_list()[0]
	var source := _anim.get_animation(source_nom)
	var bib := AnimationLibrary.new()
	for cle in ["marche", "attente"]:
		var bornes: Array = _fiche[cle]
		bib.add_animation(cle, _extraire(source, float(bornes[0]), float(bornes[1])))
	if _anim.has_animation_library("clips"):
		_anim.remove_animation_library("clips")
	_anim.add_animation_library("clips", bib)


static var _clips_caches := {}


static func _extraire(source: Animation, debut: float, fin: float) -> Animation:
	var cle := "%s_%f_%f" % [source.resource_path, debut, fin]
	if _clips_caches.has(cle):
		return _clips_caches[cle]
	var a := Animation.new()
	a.length = fin - debut
	a.loop_mode = Animation.LOOP_LINEAR
	var pas := 1.0 / 30.0
	for t in source.get_track_count():
		var type := source.track_get_type(t)
		if type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var n := a.add_track(type)
		a.track_set_path(n, source.track_get_path(t))
		var x := 0.0
		while x <= a.length + 0.0001:
			var temps := debut + minf(x, a.length)
			match type:
				Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(n, x, source.rotation_track_interpolate(t, temps))
				Animation.TYPE_POSITION_3D:
					a.position_track_insert_key(n, x, source.position_track_interpolate(t, temps))
				_:
					a.scale_track_insert_key(n, x, source.scale_track_interpolate(t, temps))
			x += pas
	_clips_caches[cle] = a
	return a


func _nom_attente() -> String:
	if espece == "chien":
		return "clips/attente"
	return _anim.get_animation_list()[0] if _anim != null else ""


func _jouer(nom: String, fondu := 0.25, vitesse := 1.0) -> void:
	if _anim == null or not _anim.has_animation(nom):
		return
	_anim.speed_scale = vitesse
	if nom == _anim_courante:
		return
	_anim_courante = nom
	_anim.play(nom, fondu)


## Assombrit le pelage (la texture est multipliée par la teinte).
func _teindre(teinte: Color) -> void:
	for mi in _modele.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var copie := mat.duplicate() as BaseMaterial3D
			copie.albedo_color = mat.albedo_color * teinte
			copie.roughness = maxf(copie.roughness, 0.7)
			m.set_surface_override_material(i, copie)


static var _mat_oeil: StandardMaterial3D


## Les yeux « comme des braises violettes » : deux petites lueurs collées à la tête.
func _poser_yeux() -> void:
	var tete: int = _os.get("tete", -1)
	if tete < 0 or not is_inside_tree():
		return
	if _mat_oeil == null:
		_mat_oeil = StandardMaterial3D.new()
		_mat_oeil.albedo_color = Color(0.12, 0.02, 0.2)
		_mat_oeil.emission_enabled = true
		_mat_oeil.emission = Color(0.55, 0.12, 0.95)
		_mat_oeil.emission_energy_multiplier = 1.8
	# La pose de départ de l'animation, pour mesurer la tête là où elle sera.
	if _anim != null:
		_anim.advance(0.0)
	var accroche := BoneAttachment3D.new()
	accroche.name = "Yeux"
	accroche.bone_idx = tete
	_squelette.add_child(accroche)
	if _fiche.has("yeux_repos"):
		# Positions dans le repère du squelette au repos : on les ramène dans celui de l'os.
		var repos := _squelette.get_bone_global_rest(tete).affine_inverse()
		for p: Vector3 in _fiche["yeux_repos"]:
			accroche.add_child(_oeil(float(_fiche["rayon_oeil"]), Transform3D(Basis(), repos * p)))
		return
	# Repère de la tête vu depuis cette apparence (le squelette est à l'échelle du fichier).
	var tete_ici := global_transform.affine_inverse() * _squelette.global_transform * _squelette.get_bone_global_pose(tete)
	var inverse := tete_ici.basis.inverse()
	var rayon := float(_fiche["rayon_oeil"])
	for p: Vector3 in _fiche["yeux"]:
		accroche.add_child(_oeil(rayon, Transform3D(inverse, inverse * p)))


func _oeil(rayon: float, repere: Transform3D) -> MeshInstance3D:
	var oeil := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 10
	s.rings = 6
	oeil.mesh = s
	oeil.material_override = _mat_oeil
	oeil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	oeil.transform = repere
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
	_morsure = 0.35


func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _pivot == null:
		return
	_morsure = maxf(0.0, _morsure - delta)
	var mord := sin(clampf(_morsure / 0.35, 0.0, 1.0) * PI)
	if mort:
		# Il s'effondre sur le flanc ; l'animation se fige.
		_mort = minf(1.0, _mort + delta * 2.5)
		_pivot.rotation.z = lerpf(0.0, PI / 2, _mort)
		_pivot.position.y = lerpf(0.0, 0.18 * float(_fiche["echelle"]) / 0.5, _mort)
		return
	if _mort > 0.0:
		_mort = 0.0
		_pivot.rotation.z = 0.0
		_pivot.position.y = 0.0
	# La morsure : un bond court vers l'avant.
	_pivot.position.z = -mord * 0.25
	if espece == "chien":
		_animer_chien(delta, vitesse)
	else:
		_animer_molosse(delta, vitesse)
	_redresser_tete()
	_corriger_tete(mord)
	_recoller_pieds()


func _animer_chien(delta: float, vitesse: float) -> void:
	if _anim == null:
		return
	var marche := float(_fiche["vitesse_marche"]) * scale.x
	if vitesse < 0.3:
		_jouer("clips/attente", 0.35)
	else:
		# Au-delà du pas, il trotte : la même foulée, plus vite.
		_jouer("clips/marche", 0.25, clampf(vitesse / maxf(marche, 0.1), 0.7, 2.6))
	_anim.advance(delta)


## Le molosse n'a qu'une attente : au pas et à la course, on bouge ses pattes nous-mêmes.
func _animer_molosse(delta: float, vitesse: float) -> void:
	if _anim == null or _squelette == null:
		return
	if vitesse < 0.3:
		if _anim_courante != _nom_attente():
			_squelette.reset_bone_poses()
		_jouer(_nom_attente(), 0.3)
		_anim.advance(delta)
		return
	_anim_courante = ""
	_anim.stop()
	_squelette.reset_bone_poses()
	var allure := clampf(vitesse / 6.0, 0.0, 1.0)
	var foulee := float(_fiche["foulee"]) * scale.x
	_phase = fmod(_phase + delta * vitesse / maxf(foulee, 0.1) * TAU, TAU * 8.0)
	# Au trot, les pattes vont en diagonale ; au galop, l'avant puis l'arrière.
	var decalage := lerpf(PI, 0.7, allure)
	var phases := [0.0, PI, decalage, decalage + PI]
	var amplitude := lerpf(0.35, 0.6, allure) * float(_fiche.get("amplitude", 1.0))
	var plis: Array = _fiche.get("plis", [0.7, -0.6])
	var cuisses: Array[int] = _os["cuisses"]
	var jarrets: Array[int] = _os["jarrets"]
	for k in 4:
		var p: float = _phase + phases[k]
		# Angle négatif = patte lancée vers l'avant.
		_tourner(cuisses[k], -sin(p) * amplitude)
		# Le genou plie quand la patte revient vers l'avant (en l'air).
		var plie := maxf(0.0, cos(p)) * float(plis[0] if k < 2 else plis[1])
		_tourner(jarrets[k], plie * (0.5 + allure))
	var queue: int = _os.get("queue", -1)
	if queue >= 0:
		_tourner(queue, -0.25 - 0.15 * sin(_phase * 2.0))
	_pivot.position.y = absf(sin(_phase)) * 0.06 * allure


## Les os de pied qui ne suivent pas la patte (voir « pieds ») : on leur applique
## le même déplacement que l'os du bas de la patte, depuis le repos.
func _recoller_pieds() -> void:
	if _squelette == null or not _fiche.has("pieds"):
		return
	for paire: Array in _fiche["pieds"]:
		var pied := _squelette.find_bone(paire[0])
		var patte := _squelette.find_bone(paire[1])
		if pied < 0 or patte < 0:
			continue
		var ecart := _squelette.get_bone_global_pose(patte) * _squelette.get_bone_global_rest(patte).affine_inverse()
		var repos := _squelette.get_bone_global_rest(pied)
		# Le pied suit le bout de la patte mais reste à plat, comme posé.
		_squelette.set_bone_global_pose(pied, Transform3D(repos.basis, ecart * repos.origin))


## Remet dans l'axe du corps une tête tournée de côté dans le modèle (le lion).
func _redresser_tete() -> void:
	var liste: Array = _os.get("redresser", [])
	if _squelette == null or liste.is_empty():
		return
	var angle := deg_to_rad(float(_fiche["redresser_angle"])) / liste.size()
	for os: int in liste:
		if os < 0:
			continue
		var axe := (_squelette.get_bone_global_pose(os).basis.inverse() * Vector3.UP).normalized()
		_squelette.set_bone_pose_rotation(os, _squelette.get_bone_pose_rotation(os) * Quaternion(axe, angle))


## Penche la tête et ouvre la gueule pendant la morsure (par-dessus l'animation).
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
