extends Node3D
## La bête sur laquelle le joueur est assis (renne, âne…).
##
## Elle utilise un modèle animé d'animal (voir data/montures.json : « modele »),
## recoloré selon « pelage », avec ou sans bois, et des oreilles plus ou moins
## grandes. Le Joueur appelle animer() à chaque image : la bête marche, trotte ou
## galope selon la vitesse, sans que ses pattes glissent sur le sol.

## Réglages de la monture (une entrée de data/montures.json).
var reglages := {}

var _modele: Node3D
var _anim: AnimationPlayer
var _squelette: Skeleton3D
var _courante := ""
var _vitesses_ref := {}
var _os_selle := -1
var _temps_en_l_air := 0.0
static var _textures := {}
var _robes: Array[ShaderMaterial] = []
const SHADER_ROBE := preload("res://shaders/robe_cheval.gdshader")

## Noms par défaut (modèles « élan / ours » de WildMesh 3D). Chaque monture peut
## donner les siens dans data/montures.json : « allures », « repos », « saut »,
## « os_racine », « os_selle », « os_oreilles ».
const ALLURES := ["Walk", "Trot", "Run", "Sprint"]
const REPOS := "Stand_Breathing_01"
const SAUT := "JumpStand"
const OS_RACINE := "RigRoot_01"
## Os où l'on pose la selle (le milieu du dos).
const OS_SELLE := ["RigSpine2_012", "RigSpine2"]
const OS_OREILLES := ["RigLEar1_026", "RigREar1_028"]

var _allures: Array = ALLURES
var _repos := REPOS
var _saut := SAUT
## Teintes du pelage : [luminosité, contraste, saturation] puis couleur multipliée.
const PELAGES := {
	"renne": [1.12, 0.95, 0.38, Color(1, 1, 1)],
	"ane": [1.05, 0.9, 0.12, Color(0.82, 0.8, 0.78)],
}


func _ready() -> void:
	var chemin := String(reglages.get("modele", ""))
	if not ResourceLoader.exists(chemin):
		_construire_silhouette()
		return
	_allures = reglages.get("allures", ALLURES)
	_repos = String(reglages.get("repos", REPOS))
	_saut = String(reglages.get("saut", SAUT))
	_modele = (load(chemin) as PackedScene).instantiate()
	# Les modèles de Sketchfab regardent vers +Z ; dans le jeu, -Z est devant.
	# « tourner » (degrés) corrige un modèle exporté de travers.
	_modele.rotation.y = PI + deg_to_rad(float(reglages.get("tourner", 0.0)))
	_modele.scale = Vector3.ONE * float(reglages.get("echelle", 0.8))
	add_child(_modele)
	var squelettes := _modele.find_children("*", "Skeleton3D", true, false)
	if not squelettes.is_empty():
		_squelette = squelettes[0]
		for nom in ([reglages["os_selle"]] if reglages.has("os_selle") else OS_SELLE):
			_os_selle = _squelette.find_bone(nom)
			if _os_selle >= 0:
				break
	_habiller()
	var lecteurs := _modele.find_children("*", "AnimationPlayer", true, false)
	if lecteurs.is_empty():
		return
	_anim = lecteurs[0]
	for nom in _anim.get_animation_list():
		var a := _anim.get_animation(nom)
		if nom in _allures or nom == _repos:
			a.loop_mode = Animation.LOOP_LINEAR
		_retirer_deplacement(a)
		_vitesses_ref[nom] = float(a.get_meta("vitesse_ref", 0.0)) * float(reglages.get("echelle", 0.8))
	# Animations jouées sur place (sans « root motion ») : vitesses données à la main (m/s).
	var vitesses: Dictionary = reglages.get("vitesses", {})
	for nom in vitesses:
		_vitesses_ref[nom] = float(vitesses[nom])
	_jouer(_repos, 0.0)


## Pelage, bois et oreilles.
func _habiller() -> void:
	var pelage: Array = PELAGES.get(String(reglages.get("pelage", "")), [])
	# « cacher » : matériaux (ou maillages) à ne pas montrer (selle, fers…).
	var cacher: Array = reglages.get("cacher", [])
	var robe = reglages.get("robe", null)
	for mi in _modele.find_children("*", "MeshInstance3D", true, false):
		var maille := mi as MeshInstance3D
		if maille.name in cacher or _materiau(maille) in cacher:
			maille.visible = false
			continue
		if robe is Dictionary:
			_mettre_robe(maille, robe)
			continue
		# Les bois de l'élan sont un maillage à part (« Chifre »).
		if maille.name.begins_with("Chifre") and not bool(reglages.get("bois", true)):
			maille.visible = false
			continue
		if pelage.is_empty() or maille.name.begins_with("Chifre"):
			continue
		for i in maille.mesh.get_surface_count():
			var m := maille.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null or m.albedo_texture == null:
				continue
			var cle := String(reglages.get("pelage")) + m.albedo_texture.resource_path + str(m.albedo_texture.get_rid())
			if not _textures.has(cle):
				var image := m.albedo_texture.get_image()
				if image == null:
					continue
				if image.is_compressed():
					image.decompress()
				image.adjust_bcs(pelage[0], pelage[1], pelage[2])
				image.generate_mipmaps()
				_textures[cle] = ImageTexture.create_from_image(image)
			var copie := m.duplicate() as BaseMaterial3D
			copie.albedo_texture = _textures[cle]
			copie.albedo_color = pelage[3]
			maille.set_surface_override_material(i, copie)
	var oreilles := float(reglages.get("oreilles", 1.0))
	if _squelette != null and absf(oreilles - 1.0) > 0.01:
		var grandes := GrandesOreilles.new()
		grandes.facteur = oreilles
		grandes.os = reglages.get("os_oreilles", OS_OREILLES)
		_squelette.add_child(grandes)


func _materiau(maille: MeshInstance3D) -> String:
	if maille.mesh == null or maille.mesh.get_surface_count() == 0:
		return ""
	var m := maille.mesh.surface_get_material(0)
	return m.resource_name if m != null else ""


## Robe unie (data/montures.json : « robe ») : le corps passe par le shader robe_cheval,
## les crins (crinière, queue) sont teintés.
func _mettre_robe(maille: MeshInstance3D, robe: Dictionary) -> void:
	for i in maille.mesh.get_surface_count():
		var m := maille.mesh.surface_get_material(i) as BaseMaterial3D
		if m == null:
			continue
		if m.resource_name == String(robe.get("materiau_corps", "Horse")) and m.albedo_texture != null:
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_ROBE
			sm.set_shader_parameter("texture_albedo", m.albedo_texture)
			if m.normal_texture != null:
				sm.set_shader_parameter("texture_normal", m.normal_texture)
				sm.set_shader_parameter("force_normale", m.normal_scale)
			sm.set_shader_parameter("robe", Color.html(String(robe.get("couleur", "#b88f57"))))
			sm.set_shader_parameter("pattes", Color.html(String(robe.get("pattes", "#2a1f17"))))
			sm.set_shader_parameter("garrot", float(reglages.get("garrot", 1.35)))
			maille.set_surface_override_material(i, sm)
			_robes.append(sm)
		elif m.resource_name == String(robe.get("materiau_crins", "Hair")):
			var crins := m.duplicate() as BaseMaterial3D
			crins.albedo_color = Color.html(String(robe.get("crins", "#2b2119")))
			maille.set_surface_override_material(i, crins)


func _process(_delta: float) -> void:
	for sm in _robes:
		sm.set_shader_parameter("sol", global_position.y)


## Agrandit les oreilles (l'âne a de grandes oreilles, l'élan non).
class GrandesOreilles extends SkeletonModifier3D:
	var facteur := 1.0
	var os: Array = []

	func _process_modification() -> void:
		var s := get_skeleton()
		for nom in os:
			if s.find_bone(nom) >= 0:
				s.set_bone_pose_scale(s.find_bone(nom), Vector3.ONE * facteur)


## Les animations font avancer l'os racine : c'est le jeu qui déplace la bête,
## donc on retire ce déplacement et on note la vitesse de l'animation.
func _retirer_deplacement(a: Animation) -> void:
	if a.has_meta("vitesse_ref"):
		return
	var vitesse := 0.0
	for t in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(a.track_get_path(t)).ends_with(":" + String(reglages.get("os_racine", OS_RACINE))):
			continue
		var n := a.track_get_key_count(t)
		if n > 1:
			var debut: Vector3 = a.track_get_key_value(t, 0)
			var fin: Vector3 = a.track_get_key_value(t, n - 1)
			vitesse = Vector2(fin.x - debut.x, fin.z - debut.z).length() * 0.01 / maxf(a.length, 0.01)
		if bool(reglages.get("garder_hauteur_racine", false)):
			# La racine porte aussi la hauteur du corps : on ne garde que son mouvement vertical.
			var depart: Vector3 = a.track_get_key_value(t, 0) if n > 0 else Vector3.ZERO
			for k in n:
				var p: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, Vector3(depart.x, p.y, depart.z))
		else:
			a.remove_track(t)
	a.set_meta("vitesse_ref", vitesse)


func _jouer(nom: String, fondu := 0.25, vitesse := 1.0) -> void:
	if _anim == null or not _anim.has_animation(nom):
		return
	_anim.speed_scale = vitesse
	if nom == _courante:
		return
	_courante = nom
	_anim.play(nom, fondu)


## Appelée par le Joueur. vitesse_locale : vitesse dans le repère du joueur (-Z = devant).
func animer(delta: float, vitesse_locale: Vector3, au_sol: bool) -> void:
	if _anim == null:
		return
	if not au_sol:
		_temps_en_l_air += delta
		if _temps_en_l_air > 0.08 and _anim.has_animation(_saut):
			_jouer(_saut, 0.15)
		return
	_temps_en_l_air = 0.0
	var v := Vector2(vitesse_locale.x, vitesse_locale.z).length()
	if v < 0.4:
		_jouer(_repos, 0.3)
		return
	# L'allure dont la vitesse naturelle est la plus proche de la vitesse réelle.
	var choix: String = _allures[0]
	var ecart := INF
	for nom in _allures:
		var ref := float(_vitesses_ref.get(nom, 0.0))
		if ref <= 0.0:
			continue
		var e := absf(log(v / ref))
		if e < ecart:
			ecart = e
			choix = nom
	var ref_choix := float(_vitesses_ref.get(choix, 0.0))
	var lecture := clampf(v / ref_choix, 0.5, 2.0) if ref_choix > 0.0 else 1.0
	# En marche arrière, on joue la marche à l'envers.
	if vitesse_locale.z > 0.3 and absf(vitesse_locale.z) > absf(vitesse_locale.x):
		choix = _allures[0]
		ref_choix = float(_vitesses_ref.get(choix, 1.5))
		lecture = -clampf(v / maxf(ref_choix, 0.1), 0.5, 2.0)
	_jouer(choix, 0.25, lecture)


## Position du dos (dans le repère de la bête), pour que le cavalier suive le pas.
## L'os du dos est au milieu du corps : « selle » (data/montures.json) le remonte jusqu'au pelage.
func point_selle() -> Vector3:
	if _squelette == null or _os_selle < 0:
		return Vector3(0, 1.0, 0)
	var p := _squelette.global_transform * _squelette.get_bone_global_pose(_os_selle).origin
	return global_transform.affine_inverse() * p + Vector3.UP * float(reglages.get("selle", 0.3))


## Sans le modèle 3D : une silhouette en formes simples.
func _construire_silhouette() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.4, 0.35)
	var corps := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	corps.mesh = capsule
	corps.rotation.x = PI / 2
	corps.position.y = 0.9
	corps.material_override = m
	add_child(corps)
	for x in [-0.22, 0.22]:
		for z in [-0.55, 0.55]:
			var patte := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.06
			c.bottom_radius = 0.05
			c.height = 0.8
			patte.mesh = c
			patte.position = Vector3(x, 0.4, z)
			patte.material_override = m
			add_child(patte)
