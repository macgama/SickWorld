@tool
extends Node3D
## Apparence d'un « Oublié » (île d'Égypte) : un ouvrier qui a perdu son nom.
## C'est un vrai personnage (le même corps que les habitants), vêtu de lin, avec
## une petite amulette violette au cou qui grésille. Quand on le met à terre, il
## reste allongé, assommé, jusqu'à ce qu'on lui rende son nom (voir carrieres_toura.gd).
##
## Appelé par apparence_loup.gd (même interface : animer, mordre, colorer).

const SCENE_APPARENCE := "res://scenes/joueur/apparence_agent.tscn"
const PEAUX := ["#9a6a48", "#8f5f3e", "#a07048", "#87583a", "#94643f"]
const HABITS := ["#e2d8c0", "#d8cdb2", "#ddd2b8", "#cfc3a6"]

## Pour varier les visages d'un oublié à l'autre.
@export var graine := 0

var _corps: Node3D
var _amulette: MeshInstance3D
var _mort := false
var _temps := 0.0


func _ready() -> void:
	for enfant in get_children():
		enfant.free()
	if not ResourceLoader.exists(SCENE_APPARENCE):
		return
	_corps = (load(SCENE_APPARENCE) as PackedScene).instantiate()
	_corps.set("modele", "homme")
	add_child(_corps)
	_habiller.call_deferred()
	# L'amulette offerte par la « prêtresse de Memphis » : un scarabée qui luit.
	_amulette = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.035
	s.height = 0.05
	_amulette.mesh = s
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = Color(0.45, 0.25, 0.85)
	lueur.emission_enabled = true
	lueur.emission = Color(0.6, 0.3, 1.0)
	lueur.emission_energy_multiplier = 2.5
	_amulette.material_override = lueur
	_amulette.position = Vector3(0, 1.42, -0.13)
	add_child(_amulette)


func _habiller() -> void:
	if _corps == null or not is_instance_valid(_corps):
		return
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine * 7 + 3
	if _corps.has_method("appliquer"):
		_corps.appliquer({"sexe": "homme", "taille_cm": hasard.randi_range(166, 180),
				"peau": Color.from_string(PEAUX[hasard.randi() % PEAUX.size()], Color.WHITE)})
	var teinte := Color.from_string(HABITS[hasard.randi() % HABITS.size()], Color.WHITE)
	# Comme les habitants (pnj_epoque.gd) : les vêtements modernes deviennent du lin.
	var cible = _corps
	if cible.has_method("teindre_tenue"):
		cible.teindre_tenue(teinte * Color(0.92, 0.9, 0.88))
	for n in cible.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as StandardMaterial3D
		if m == null or m.subsurf_scatter_enabled or m.roughness < 0.2 \
				or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var lin := m.duplicate() as StandardMaterial3D
		lin.albedo_color = teinte * Color(0.92, 0.9, 0.88)
		lin.roughness = 0.9
		(n as MeshInstance3D).material_override = lin
	if _corps.has_method("equiper"):
		_corps.equiper({"tete": {"forme": "bandeau", "couleur": "#d8cdb2"}})


func colorer(_allie: bool) -> void:
	pass


func mordre() -> void:
	if _corps != null and _corps.has_method("attaquer"):
		_corps.attaquer()


## Un oublié assommé se relève-t-il ? Non : il reste à terre (voir carrieres_toura.gd).
func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _corps == null:
		return
	_temps += delta
	if _amulette != null:
		_amulette.visible = not mort or fmod(_temps, 1.4) < 1.0
		_amulette.position.y = 0.25 if mort else 1.42
	if mort and not _mort:
		_mort = true
		_corps.mourir()
	elif not mort and _mort:
		_mort = false
		_corps.revivre()
	if mort:
		return
	_corps.animer(delta, Vector3(0, 0, -vitesse), true, -1.0, Vector3.ZERO)
