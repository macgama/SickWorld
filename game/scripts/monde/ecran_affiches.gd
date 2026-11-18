@tool
extends Node3D
## Un grand ÉCRAN du hub qui fait défiler les images d'une ou plusieurs affiches
## (data/affiches.json), en fondu, avec un lent travelling et la légende en dessous.
## [F] devant l'écran ouvre l'affiche de l'image montrée (fiche + bande-annonce).
##
## Les quartiers le créent en code :
##   var e := EcranAffiches.new()
##   e.affiches = ["ile_prehistoire", "ile_egypte"]
##   e.taille = Vector2(10.6, 6.0)
##   e.actions = {"ile_egypte": func(): ...}   # bouton de la fiche (facultatif)

const AfficheActivite := preload("res://scripts/interface/affiche_activite.gd")
const PointInteraction := preload("res://scripts/monde/point_interaction.gd")
const SHADER := preload("res://shaders/ecran_affiche.gdshader")
const DUREE := 7.0
const FONDU := 1.2

## Les affiches montrées, dans l'ordre.
@export var affiches: PackedStringArray = []
## Largeur et hauteur de l'écran (mètres).
@export var taille := Vector2(8.0, 4.5)
## Combien d'images de chaque affiche (1 = seulement la première).
@export var images_par_affiche := 2
## Distance du [F] devant l'écran (0 : pas d'interaction).
@export var portee_interaction := 4.0
## Callable par id d'affiche : ce que fait le gros bouton de la fiche.
var actions := {}

var _materiau: ShaderMaterial
var _legende: Label3D
var _sous_legende: Label3D
var _liste: Array = [] # [id, texture]
var _n := 0
var _temps := 0.0
var _point: Node3D


func _ready() -> void:
	for id in affiches:
		var fiche: Dictionary = AfficheActivite.donnees().get(id, {})
		var images: Array = fiche.get("images", [])
		for k in mini(images_par_affiche, images.size()):
			var chemin := String(images[k].get("fichier", ""))
			if ResourceLoader.exists(chemin):
				_liste.append([id, load(chemin)])
	var ecran := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = taille
	ecran.mesh = quad
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER
	ecran.material_override = _materiau
	ecran.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ecran)
	# Cadre sombre derrière l'écran.
	var cadre := MeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = Vector3(taille.x + 0.3, taille.y + 0.3, 0.12)
	cadre.mesh = boite
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.03, 0.035, 0.045)
	noir.metallic = 0.6
	noir.roughness = 0.35
	cadre.material_override = noir
	cadre.position = Vector3(0, 0, -0.08)
	add_child(cadre)
	_legende = _label(Vector3(-taille.x * 0.5 + 0.35, -taille.y * 0.5 + 0.75, 0.02), 64)
	_sous_legende = _label(Vector3(-taille.x * 0.5 + 0.35, -taille.y * 0.5 + 0.38, 0.02), 34)
	_sous_legende.modulate = Color(1.0, 0.82, 0.42)
	if _liste.is_empty():
		_materiau.set_shader_parameter("luminosite", 0.15)
		return
	_montrer(0, true)
	if not Engine.is_editor_hint() and portee_interaction > 0.0:
		_point = Node3D.new()
		_point.set_script(PointInteraction)
		_point.texte = "Regarder l'affiche"
		_point.portee = portee_interaction
		_point.position = Vector3(0, -taille.y * 0.5, portee_interaction * 0.6)
		add_child(_point)
		_point.utilise.connect(_ouvrir_affiche)


func _label(p: Vector3, police: int) -> Label3D:
	var l := Label3D.new()
	l.position = p
	l.font_size = police
	l.pixel_size = 0.006 * taille.y / 4.5
	l.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.double_sided = false
	l.shaded = false
	l.font = load("res://assets/polices/NotoSansJP-Bold-hub.ttf") if ResourceLoader.exists("res://assets/polices/NotoSansJP-Bold-hub.ttf") else null
	add_child(l)
	return l


func _cadre(n: int, t: float) -> Vector3:
	var sens := 1.0 if n % 2 == 0 else -1.0
	var k := clampf(t, 0.0, 1.0)
	return Vector3(0.5 + sens * lerpf(-0.12, 0.12, k), 0.5, lerpf(1.06, 1.18, k))


func _montrer(n: int, immediat := false) -> void:
	_n = n
	var id := String(_liste[n][0])
	var fiche: Dictionary = AfficheActivite.donnees().get(id, {})
	_legende.text = String(fiche.get("titre", ""))
	_sous_legende.text = String(fiche.get("epoque", ""))
	if immediat:
		_materiau.set_shader_parameter("image_a", _liste[n][1])
		_materiau.set_shader_parameter("melange", 0.0)
		_temps = 0.0
		return
	# Fondu : la nouvelle image arrive dans B, puis on la recopie dans A.
	_materiau.set_shader_parameter("image_b", _liste[n][1])
	var anim := create_tween()
	anim.tween_method(func(m: float): _materiau.set_shader_parameter("melange", m), 0.0, 1.0, FONDU)
	anim.tween_callback(func():
		_materiau.set_shader_parameter("image_a", _liste[n][1])
		_materiau.set_shader_parameter("melange", 0.0))


func _process(delta: float) -> void:
	if _liste.is_empty():
		return
	_temps += delta
	var precedent := (_n - 1 + _liste.size()) % _liste.size()
	_materiau.set_shader_parameter("cadre_b", _cadre(_n, _temps / (DUREE + FONDU)))
	if float(_materiau.get_shader_parameter("melange")) > 0.0:
		_materiau.set_shader_parameter("cadre_a", _cadre(precedent, (_temps + DUREE) / (DUREE + FONDU)))
	else:
		_materiau.set_shader_parameter("cadre_a", _cadre(_n, _temps / (DUREE + FONDU)))
	if _temps >= DUREE and _liste.size() > 1:
		_temps = 0.0
		_montrer((_n + 1) % _liste.size())


## Id de l'affiche montrée en ce moment.
func affiche_montree() -> String:
	return String(_liste[_n][0]) if not _liste.is_empty() else ""


func _ouvrir_affiche() -> void:
	var id := affiche_montree()
	if id == "":
		return
	AfficheActivite.ouvrir(get_tree(), id, actions.get(id, Callable()))
