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
##   marcher.fbx (facultatif) : marche lente, utilisée sous 2 m/s (passants)
##   textures/     textures MakeHuman (réappliquées ici : Mixamo ne les garde pas)

## Animations qui tournent en boucle.
const EN_BOUCLE := ["immobile", "marcher", "courir", "reculer", "pas_gauche", "pas_droite", "chute"]
const ANIMATIONS := ["immobile", "marcher", "courir", "reculer", "pas_gauche", "pas_droite", "saut", "chute",
	"roulade", "attaque", "touche", "mort",
	# Gestes de combat propres aux classes (Mixamo, facultatifs : sinon « attaque »).
	"attaque_lame", "attaque_bouclier", "bouclier_leve", "provocation", "tir_arc", "lancer",
	"incantation", "sort", "esquive_arriere"]
## Vitesse (m/s) des pieds au sol dans chaque animation de déplacement, mesurée sur les
## animations Mixamo (pied d'appui). En jouant l'animation à vitesse × (vitesse réelle /
## vitesse naturelle), les pieds ne glissent pas sur le sol.
const VITESSE_NATURELLE := {
	"homme": {"marcher": 1.4, "courir": 5.96, "reculer": 0.90, "pas_gauche": 4.55, "pas_droite": 4.58},
	"femme": {"marcher": 1.4, "courir": 5.32, "reculer": 0.80, "pas_gauche": 4.08, "pas_droite": 4.11},
}
## Au-delà de cette vitesse en marche arrière, l'animation « reculer » (une marche lente)
## devrait être jouée beaucoup trop vite : on passe alors à la course jouée à l'envers.
const RECUL_MAX_EN_MARCHANT := 1.6
const FONDU := 0.18
## Taille réelle des modèles MakeHuman (cm), pieds au sol, sans les cheveux.
const TAILLE_MODELE := {"homme": 178.0, "femme": 168.0}
## Taille de référence utilisée par l'écran de création pour cadrer la caméra.
const TAILLE_REFERENCE := 180.0
## Couleur de peau qui correspond à la texture MakeHuman (teinte neutre).
const PEAU_DE_REFERENCE := Color(0.80, 0.62, 0.50)
const VisuelEquipement := preload("res://scripts/objets/visuel_equipement.gd")

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

## Dernière apparence reçue (dictionnaire de FichePersonnage.resoudre).
var _apparence := {}
var _materiau_peau: StandardMaterial3D
var _materiau_tenue: ShaderMaterial
var _materiaux_poils: Array[ShaderMaterial] = []   # cheveux et sourcils
var _materiau_yeux: ShaderMaterial
## Maillages de la tête (avec les formes du visage) et maillage de la peau.
var _tete: Array[MeshInstance3D] = []
var _peau: MeshInstance3D
## Cheveux livrés avec le modèle, et coiffure accrochée à la tête (si on en a choisi une autre).
var _cheveux_integres: Array[MeshInstance3D] = []
var _coiffure_accrochee: Node3D
var _coiffure_actuelle := ""
## Teinte de la veste donnée par l'équipement (blanc = aucune).
var _teinte_equipement := Color.WHITE
## Équipement visible (emplacement -> visuel, voir Inventaire et data/objets.json).
var _visuels := {}

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
	_coiffure_accrochee = null
	_coiffure_actuelle = ""
	_appliquer_materiaux()
	_appliquer_teintes()
	_appliquer_equipement()
	_lecteur = _corps.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_lecteur.add_animation_library("agent", _bibliotheque(modele))
	_mort = false
	_jouer("immobile", 0.0)
	# Reconstruit pendant que le joueur est désynchronisé : on garde la translucidité.
	if get_parent() != null and get_parent().get("_translucide") == true:
		for n in _corps.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).transparency = 0.65


# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------
static func _bibliotheque(nom_modele: String) -> AnimationLibrary:
	if _bibliotheques.has(nom_modele):
		return _bibliotheques[nom_modele]
	var bib := AnimationLibrary.new()
	for nom in ANIMATIONS:
		if not ResourceLoader.exists("res://assets/personnages/%s/%s.fbx" % [nom_modele, nom]):
			continue
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
	# « courir_arriere » : la course jouée à l'envers.
	var cle := "agent/" + ("courir" if nom == "courir_arriere" else nom)
	if nom == "courir_arriere":
		vitesse = -absf(vitesse)
	if not _lecteur.has_animation(cle):
		return
	if _actuelle == nom:
		return
	_lecteur.speed_scale = 1.0
	_lecteur.play(cle, fondu, vitesse, vitesse < 0.0)
	if depuis >= 0.0:
		_lecteur.seek(depuis, true)
	_actuelle = nom


func _duree(nom: String) -> float:
	var cle := "agent/" + nom
	return _lecteur.get_animation(cle).length if _lecteur and _lecteur.has_animation(cle) else 0.0


# ---------------------------------------------------------------------------
# Interface utilisée par le Joueur
# ---------------------------------------------------------------------------
## Change l'apparence (dictionnaire produit par FichePersonnage.resoudre).
## Gérés : sexe (modèle homme/femme), taille_cm (échelle), peau, visage (les 17 curseurs,
## voir FormesVisage), yeux, cheveux (couleur), pilosité (barbe peinte sur la peau),
## veste (couleur de la tenue).
## Ignorés pour l'instant : coiffure (une seule coupe par modèle), insigne, manteau, arme.
func appliquer(apparence: Dictionary) -> void:
	_apparence = apparence.duplicate()
	var sexe := String(apparence.get("sexe", modele))
	var nouveau_modele := "femme" if sexe == "femme" else "homme"
	var taille := float(apparence.get("taille_cm", TAILLE_MODELE[nouveau_modele]))
	echelle = clampf(taille / float(TAILLE_MODELE[nouveau_modele]), 0.5, 1.5)
	if nouveau_modele != modele or _corps == null:
		modele = nouveau_modele   # le setter reconstruit le personnage (avec les teintes)
		if not is_inside_tree():
			return
	_appliquer_teintes()


## Accroche l'équipement porté (armes, capuche, cape…) et teinte la veste.
func equiper(visuels: Dictionary) -> void:
	_visuels = visuels.duplicate(true)
	_appliquer_equipement()


func _appliquer_equipement() -> void:
	var squelette := _squelette()
	if squelette == null:
		return
	VisuelEquipement.habiller(squelette, _visuels)
	_teinte_equipement = Color.WHITE
	for e in _visuels:
		if _visuels[e].has("teinte"):
			_teinte_equipement = Color.from_string(String(_visuels[e]["teinte"]), Color.WHITE)
	_appliquer_teintes()


## Position du visage dans le monde (pour que la caméra de l'écran de création le cadre).
func position_visage() -> Vector3:
	var squelette := _squelette()
	if squelette:
		var os := squelette.find_bone("mixamorig_Head")
		if os >= 0:
			var tete := squelette.global_transform * squelette.get_bone_global_pose(os)
			# L'os « Head » est à la base du crâne : le visage est un peu plus haut et devant.
			return tete.origin + Vector3.UP * 0.09 * echelle
	return global_position + Vector3.UP * 1.62 * echelle


func _squelette() -> Skeleton3D:
	if _corps == null:
		return null
	var trouves := _corps.find_children("*", "Skeleton3D", true, false)
	return trouves[0] as Skeleton3D if not trouves.is_empty() else null


func _appliquer_teintes() -> void:
	_appliquer_coiffure()
	# Visage : intensité de chaque forme.
	var visage: Dictionary = _apparence.get("visage", {})
	for mi in _tete:
		if is_instance_valid(mi):
			FormesVisage.regler(mi, visage)
	if _materiau_peau != null and _apparence.has("peau"):
		var peau: Color = _apparence["peau"]
		# La texture de peau correspond à PEAU_DE_REFERENCE : on la module par le rapport.
		_materiau_peau.albedo_color = Color(
				clampf(peau.r / PEAU_DE_REFERENCE.r, 0.15, 1.25),
				clampf(peau.g / PEAU_DE_REFERENCE.g, 0.15, 1.25),
				clampf(peau.b / PEAU_DE_REFERENCE.b, 0.15, 1.25))
	# Barbe : un masque peint par-dessus la peau, de la couleur des cheveux.
	if _materiau_peau != null and _peau != null:
		var masque := FormesVisage.masque_barbe(modele, _peau, String(_apparence.get("pilosite", "aucune")))
		_materiau_peau.detail_enabled = masque != null
		if masque != null:
			_materiau_peau.detail_mask = masque
			_materiau_peau.detail_albedo = _texture_unie(_couleur_poils(0.8))
			_materiau_peau.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	if _apparence.has("cheveux"):
		for m in _materiaux_poils:
			m.set_shader_parameter("couleur", _couleur_poils(1.0))
			m.set_shader_parameter("force", 1.0)
	if _materiau_yeux != null and _apparence.has("yeux"):
		_materiau_yeux.set_shader_parameter("iris", _apparence["yeux"])
		_materiau_yeux.set_shader_parameter("force", 1.0)
	if _materiau_tenue != null:
		var couleur := _teinte_equipement
		if couleur == Color.WHITE and _apparence.has("veste"):
			couleur = _apparence["veste"]
		var teinte := couleur != Color.WHITE
		_materiau_tenue.set_shader_parameter("couleur", couleur.lightened(0.15) if teinte else Color.WHITE)
		_materiau_tenue.set_shader_parameter("force", 0.85 if teinte else 0.0)


func _couleur_poils(intensite: float) -> Color:
	var c: Color = _apparence.get("cheveux", Color(0.2, 0.13, 0.08))
	return c * intensite


static var _textures_unies := {}
static func _texture_unie(couleur: Color) -> Texture2D:
	var cle := couleur.to_html(false)
	if not _textures_unies.has(cle):
		var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
		image.fill(couleur)
		_textures_unies[cle] = ImageTexture.create_from_image(image)
	return _textures_unies[cle]


## Coup (attaque de base ou compétence).
## style : nom d'un geste de combat (« tir_arc », « incantation »…) ; s'il manque, coup de poing.
## duree : si plus grand que 0, le geste est étiré sur cette durée (préparation d'une compétence).
func attaquer(style := "", duree := 0.0) -> void:
	if _mort or _lecteur == null:
		return
	_actuelle = ""
	if style == "" or not _lecteur.has_animation("agent/" + style):
		_jouer("attaque", 0.08, 1.8, 0.15)
		_verrou = maxf(0.55, duree)
		return
	var longueur := maxf(0.1, _duree(style))
	var vitesse := clampf(longueur / duree, 0.5, 3.0) if duree > 0.0 else clampf(longueur / 0.8, 1.0, 2.5)
	_jouer(style, 0.1, vitesse)
	_verrou = duree if duree > 0.0 else longueur / vitesse * 0.9


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
		nom = "reculer" if vitesse <= RECUL_MAX_EN_MARCHANT * echelle else "courir_arriere"
	elif vitesse < 2.0 and _lecteur.has_animation("agent/marcher"):
		nom = "marcher"
	_jouer(nom, FONDU)
	_lecteur.speed_scale = vitesse_animation(nom, vitesse)


## Vitesse de lecture d'une animation de déplacement pour que les pieds ne glissent pas.
func vitesse_animation(nom: String, vitesse: float) -> float:
	var naturelles: Dictionary = VITESSE_NATURELLE.get(modele, VITESSE_NATURELLE["homme"])
	var naturelle := float(naturelles.get("courir" if nom == "courir_arriere" else nom, 5.0)) * echelle
	return clampf(vitesse / naturelle, 0.4, 2.5)


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


## Shader des matières teintables : on garde le relief de la texture mais on remplace
## sa couleur par « couleur » (cheveux, sourcils, tenue). force = 0 : texture d'origine.
const SHADER_TEINTE := """
shader_type spatial;
render_mode %s;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normale : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool avec_normale = false;
uniform vec4 couleur : source_color = vec4(1.0);
uniform float force = 0.0;
uniform float luminance_moyenne = 0.35;
uniform float rugosite = 0.75;
void fragment() {
	vec4 c = texture(texture_albedo, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 teinte = couleur.rgb * clamp(l / luminance_moyenne, 0.0, 2.0);
	ALBEDO = mix(c.rgb, teinte, force);
	ROUGHNESS = rugosite;
	%s
	if (avec_normale) {
		NORMAL_MAP = texture(texture_normale, UV).rgb;
		NORMAL_MAP_DEPTH = 0.6;
	}
}
"""
## Yeux : on recolore seulement l'iris (deux yeux dans la texture MakeHuman).
const SHADER_YEUX := """
shader_type spatial;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform vec4 iris : source_color = vec4(0.3, 0.2, 0.1, 1.0);
uniform float force = 0.0;
void fragment() {
	vec4 c = texture(texture_albedo, UV);
	float d = min(distance(UV, vec2(0.703, 0.293)), distance(UV, vec2(0.293, 0.703)));
	float masque = (1.0 - smoothstep(0.108, 0.13, d)) * force;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(c.rgb, iris.rgb * clamp(0.45 + l * 2.2, 0.0, 1.8), masque);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
"""
static var _shaders := {}


static func _shader(nom: String) -> Shader:
	if not _shaders.has(nom):
		var sh := Shader.new()
		match nom:
			"opaque":
				sh.code = SHADER_TEINTE % ["cull_back", ""]
			"poils":
				sh.code = SHADER_TEINTE % ["cull_disabled",
						"ALPHA = c.a; ALPHA_SCISSOR_THRESHOLD = 0.35; ALPHA_ANTIALIASING_EDGE = 0.3;"]
			"yeux":
				sh.code = SHADER_YEUX
		_shaders[nom] = sh
	return _shaders[nom]


## Luminance moyenne d'une texture (pixels visibles), pour que la teinte garde sa clarté.
static var _luminances := {}
static func _luminance(texture: Texture2D) -> float:
	if texture == null:
		return 0.35
	var cle := texture.resource_path
	if _luminances.has(cle):
		return _luminances[cle]
	var image := texture.get_image()
	if image == null:
		return 0.35
	if image.is_compressed():
		image.decompress()
	image.resize(48, 48, Image.INTERPOLATE_BILINEAR)
	var somme := 0.0
	var n := 0
	for y in 48:
		for x in 48:
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				somme += c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				n += 1
	var l := clampf(somme / maxi(n, 1), 0.05, 1.0)
	_luminances[cle] = l
	return l


func _matiere_teinte(sorte: String, albedo: Texture2D, normale: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(sorte)
	m.set_shader_parameter("texture_albedo", albedo)
	m.set_shader_parameter("luminance_moyenne", _luminance(albedo))
	if normale:
		m.set_shader_parameter("texture_normale", normale)
		m.set_shader_parameter("avec_normale", true)
	m.set_shader_parameter("rugosite", 0.85 if sorte == "poils" else 0.75)
	return m


func _appliquer_materiaux() -> void:
	_materiaux_poils.clear()
	_cheveux_integres.clear()
	_tete.clear()
	_materiau_tenue = null
	_materiau_yeux = null
	_peau = null
	var sortes := {}
	for n in _corps.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var base := String(mi.name).trim_suffix("Mesh")
		var sorte := FormesVisage.Sorte.AUTRE
		if base.contains("1591") or base.contains("1605") or base.contains("proxy") or base.contains("generic"):
			# Peau : moins cireuse, avec un peu de diffusion sous la surface.
			var m := StandardMaterial3D.new()
			m.albedo_texture = _texture("young_", "skinned")
			m.roughness = 0.6
			m.metallic_specular = 0.35
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.25
			m.subsurf_scatter_skin_mode = true
			_materiau_peau = m
			mi.material_override = m
			sorte = FormesVisage.Sorte.PEAU
			_peau = mi
		elif base.contains("poly"):
			_materiau_yeux = ShaderMaterial.new()
			_materiau_yeux.shader = _shader("yeux")
			_materiau_yeux.set_shader_parameter("texture_albedo", _texture("", "_eye"))
			mi.material_override = _materiau_yeux
			sorte = FormesVisage.Sorte.YEUX
		elif base.begins_with("eyelash"):
			var m := StandardMaterial3D.new()
			m.albedo_texture = _texture(base)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.35
			m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = m
			sorte = FormesVisage.Sorte.CILS
		elif base.begins_with("eyebrow") or _est_cheveux(base):
			var albedo := _texture(base + "_diffuse")
			if albedo == null:
				albedo = _texture(base)
			var m := _matiere_teinte("poils", albedo)
			_materiaux_poils.append(m)
			mi.material_override = m
			sorte = FormesVisage.Sorte.SOURCILS if base.begins_with("eyebrow") else FormesVisage.Sorte.CHEVEUX
			if sorte == FormesVisage.Sorte.CHEVEUX:
				_cheveux_integres.append(mi)
		elif base.contains("suit"):
			var albedo := _texture(base + "_diffuse")
			if base.begins_with("female_casualsuit01"):
				albedo = _sans_logo(albedo)
			var m := _matiere_teinte("opaque", albedo, _texture(base + "_normal"))
			_materiau_tenue = m
			mi.material_override = m
		else:
			var m := StandardMaterial3D.new()
			m.roughness = 0.75
			m.albedo_texture = _texture(base + "_diffuse")
			if m.albedo_texture == null:
				m.albedo_texture = _texture(base)
			var normale := _texture(base + "_normal")
			if normale:
				m.normal_enabled = true
				m.normal_texture = normale
				m.normal_scale = 0.6
			mi.material_override = m
		sortes[mi] = sorte
		if sorte != FormesVisage.Sorte.AUTRE:
			_tete.append(mi)
	# Les formes du visage (curseurs de l'écran de création).
	FormesVisage.preparer(modele, sortes)


## Le t-shirt MakeHuman de la femme porte le logo MakeHuman sur la poitrine : on le
## recouvre avec le tissu voisin (copié 170 pixels plus à gauche), bords adoucis.
static var _sans_logo_cache: Texture2D
static func _sans_logo(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if _sans_logo_cache != null:
		return _sans_logo_cache
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	var k := image.get_width() / 1024.0
	var centre := Vector2(810, 237) * k       # logo, dans la texture 1024 × 1024
	var rayons := Vector2(90, 83) * k
	var decalage := int(170 * k)
	var source := image.duplicate() as Image
	var masque := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var boite := Rect2i(Vector2i(centre - rayons) - Vector2i(decalage + 4, 4), Vector2i(rayons * 2.0) + Vector2i(8, 8))
	for y in range(boite.position.y, boite.end.y):
		for x in range(boite.position.x, boite.end.x):
			var d := Vector2((x + decalage - centre.x) / rayons.x, (y - centre.y) / rayons.y).length()
			var alpha := 1.0 - smoothstep(0.88, 1.0, d)
			if alpha > 0.0:
				masque.set_pixel(x, y, Color(1, 1, 1, alpha))
	image.blend_rect_mask(source, masque, boite, boite.position + Vector2i(decalage, 0))
	image.generate_mipmaps()
	_sans_logo_cache = ImageTexture.create_from_image(image)
	return _sans_logo_cache


# ---------------------------------------------------------------------------
# Coiffures (exportées de MakeHuman par tools/personnages/exporter_coiffures.py)
# ---------------------------------------------------------------------------
## Fichier d'une coiffure pour ce modèle, ou "" si elle n'existe pas (encore).
func _fichier_coiffure(id: String) -> String:
	var chemin := "res://assets/personnages/coiffures/%s/%s.glb" % [modele, id]
	return chemin if ResourceLoader.exists(chemin) else ""


func _appliquer_coiffure() -> void:
	var squelette := _squelette()
	if squelette == null or not _apparence.has("coiffure"):
		return
	var id := String(_apparence["coiffure"])
	if id == _coiffure_actuelle:
		return
	_coiffure_actuelle = id
	if _coiffure_accrochee != null:
		for m in _coiffure_accrochee.find_children("*", "MeshInstance3D", true, false):
			_materiaux_poils.erase((m as MeshInstance3D).material_override)
		_coiffure_accrochee.queue_free()
		_coiffure_accrochee = null
	var fichier := _fichier_coiffure(id) if id != "rase" else ""
	# Crâne rasé : pas de cheveux. Coiffure pas encore exportée : on garde celle du modèle.
	var garder_integres := id != "rase" and fichier == ""
	for mi in _cheveux_integres:
		mi.visible = garder_integres
	if fichier == "":
		return
	var scene := load(fichier) as PackedScene
	if scene == null:
		for mi in _cheveux_integres:
			mi.visible = true
		return
	# Les cheveux sont modélisés dans l'espace du personnage au repos (mètres, pieds au sol) :
	# on les accroche à l'os de la tête en compensant la position de repos de cet os.
	var os := squelette.find_bone("mixamorig_Head")
	var accroche := BoneAttachment3D.new()
	accroche.name = "Coiffure"
	accroche.bone_name = "mixamorig_Head"
	squelette.add_child(accroche)
	var cheveux := scene.instantiate() as Node3D
	cheveux.transform = squelette.get_bone_global_rest(os).affine_inverse()
	accroche.add_child(cheveux)
	for n in cheveux.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var origine := mi.mesh.surface_get_material(0) as BaseMaterial3D if mi.mesh else null
		var m := _matiere_teinte("poils", origine.albedo_texture if origine else null)
		if _apparence.has("cheveux"):
			m.set_shader_parameter("couleur", _couleur_poils(1.0))
			m.set_shader_parameter("force", 1.0)
		_materiaux_poils.append(m)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_coiffure_accrochee = accroche


func _est_cheveux(base: String) -> bool:
	for k in ["short", "ponytail", "bob", "long", "braid", "afro", "hair"]:
		if base.begins_with(k):
			return true
	return false
