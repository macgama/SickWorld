@tool
extends Node3D
## Grise, la louve de Kéo. Touchée par la faille : des veines violettes courent
## sous son pelage et elle reste couchée, haletante.
## Selon le choix du joueur (chapitre 4), on la soigne (elle se relève, guérie)
## ou on la laisse partir (elle s'enfuit dans la forêt).

const APPARENCE := preload("res://scripts/ennemis/apparence_loup.gd")
const SHADER_FRACTURE := preload("res://shaders/prehistoire_fracture.gdshader")

## Contaminée par la faille (veines violettes, couchée).
@export var contaminee := true

var _apparence: Node3D
var _lueur: OmniLight3D
var _fuite := false
var _temps := 0.0
var _depart := Vector3.ZERO
var _direction := Vector3.ZERO
var _couchee := true


func _ready() -> void:
	for enfant in get_children():
		enfant.free()
	_apparence = APPARENCE.new()
	add_child(_apparence)
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(0.6, 0.25, 1.0)
	_lueur.light_energy = 0.9
	_lueur.omni_range = 3.5
	_lueur.position = Vector3(0, 0.6, 0)
	add_child(_lueur)
	_couchee = contaminee
	_appliquer.call_deferred()


func _appliquer() -> void:
	if _apparence == null:
		return
	# Un peu plus clair qu'un loup sauvage : c'est une louve grise.
	for mi in _apparence.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m != null and m.albedo_color.r > 0.3 and m.albedo_color.r < 0.5:
			m.albedo_color = Color(0.56, 0.55, 0.53)
	var overlay: Material = null
	if contaminee:
		var shader := ShaderMaterial.new()
		shader.shader = SHADER_FRACTURE
		var bruit := NoiseTexture2D.new()
		bruit.seamless = true
		bruit.noise = FastNoiseLite.new()
		shader.set_shader_parameter("bruit", bruit)
		overlay = shader
	for mi in _apparence.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = overlay
	_lueur.visible = contaminee


## Kéo et le joueur l'ont soignée : la faille la quitte, elle se relève.
func soigner(_anime := true) -> void:
	contaminee = false
	_couchee = false
	_appliquer()


## On la laisse partir : elle s'enfuit entre les bouleaux.
func fuir(anime := true) -> void:
	if not anime or Engine.is_editor_hint():
		visible = false
		return
	_couchee = false
	_fuite = true
	_temps = 0.0
	_depart = global_position
	_direction = Vector3(1, 0, -0.6).normalized()
	rotation.y = atan2(-_direction.x, -_direction.z)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _apparence == null or not _apparence.has_method("animer"):
		return
	if _fuite:
		_temps += delta
		var ile := get_tree().get_first_node_in_group("ile")
		var p := _depart + _direction * minf(_temps, 2.0) * 3.0 + _direction * maxf(_temps - 2.0, 0.0) * 8.0
		if ile != null:
			p.y = ile.hauteur(p.x, p.z)
		global_position = p
		_apparence.animer(delta, 3.0 if _temps < 2.0 else 8.0, false)
		if _temps > 7.0:
			_fuite = false
			visible = false
		return
	_apparence.animer(delta, 0.0, _couchee)
	if _lueur.visible:
		_lueur.light_energy = 0.8 + sin(Time.get_ticks_msec() * 0.006) * 0.3
