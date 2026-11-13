@tool
class_name BaliseVigie
extends Node3D
## Balise de la Vigie : point de réapparition du joueur quand il est désynchronisé.
## Elle se pose toute seule sur le terrain.


func _ready() -> void:
	add_to_group("balises")
	for enfant in get_children():
		enfant.queue_free()
	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = Color(0.1, 0.12, 0.15)
	materiau.metallic = 0.8
	materiau.roughness = 0.3
	var lumineux := StandardMaterial3D.new()
	lumineux.albedo_color = Color(0.25, 0.85, 0.9)
	lumineux.emission_enabled = true
	lumineux.emission = Color(0.25, 0.85, 0.9)
	lumineux.emission_energy_multiplier = 3.0

	var socle := CylinderMesh.new()
	socle.top_radius = 0.6
	socle.bottom_radius = 0.8
	socle.height = 0.4
	_ajouter(socle, materiau, Vector3(0, 0.2, 0))
	var colonne := CylinderMesh.new()
	colonne.top_radius = 0.12
	colonne.bottom_radius = 0.2
	colonne.height = 2.4
	_ajouter(colonne, materiau, Vector3(0, 1.6, 0))
	var anneau := TorusMesh.new()
	anneau.inner_radius = 0.3
	anneau.outer_radius = 0.38
	_ajouter(anneau, lumineux, Vector3(0, 2.2, 0)).rotation.x = PI / 2
	var coeur := SphereMesh.new()
	coeur.radius = 0.16
	coeur.height = 0.32
	_ajouter(coeur, lumineux, Vector3(0, 2.95, 0))
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.3, 0.85, 0.95)
	lumiere.light_energy = 1.5
	lumiere.omni_range = 6.0
	lumiere.position = Vector3(0, 2.6, 0)
	add_child(lumiere)
	if not Engine.is_editor_hint():
		_poser_au_sol.call_deferred()


func _ajouter(maillage: Mesh, materiau: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = pos
	add_child(mi)
	return mi


func _poser_au_sol() -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("hauteur"):
		global_position.y = parent.hauteur(global_position.x, global_position.z) - 0.1


## Endroit où le joueur réapparaît (devant la balise).
func point_de_reapparition() -> Vector3:
	return global_position + global_transform.basis.z * 2.5 + Vector3.UP * 0.3
