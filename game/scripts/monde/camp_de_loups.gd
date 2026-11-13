class_name CampDeLoups
extends Marker3D
## Fait apparaître une meute de loups autour de ce point.
## Déplace ce marqueur dans la scène pour changer l'emplacement du camp
## (la hauteur est calculée automatiquement d'après le terrain).

const SCENE_LOUP := preload("res://scenes/ennemis/loup.tscn")

## Nombre de loups dans le camp.
@export_range(1, 10) var nombre := 3
## Rayon du camp (mètres).
@export var rayon := 4.0


func _ready() -> void:
	# Seul le serveur crée les loups ; les joueurs les reçoivent automatiquement.
	if Engine.is_editor_hint() or not multiplayer.is_server():
		return
	# On attend que le terrain soit construit.
	_peupler.call_deferred()


func _peupler() -> void:
	var terrain := _trouver_terrain()
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	if dossier == null:
		dossier = get_parent()
	for i in nombre:
		var angle := TAU * i / nombre + randf() * 0.5
		var p := global_position + Vector3(cos(angle), 0, sin(angle)) * rayon * randf_range(0.4, 1.0)
		if terrain != null:
			p.y = terrain.hauteur(p.x, p.z) + 0.3
		var loup: Loup = SCENE_LOUP.instantiate()
		loup.name = "%s_Loup%d" % [name, i + 1]
		loup.position = p
		loup.camp = p
		loup.position_reseau = p
		loup.rotation.y = randf() * TAU
		dossier.add_child(loup)


func _trouver_terrain() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("hauteur"):
			return n
		n = n.get_parent()
	return null
