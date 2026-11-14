@tool
extends Node3D
## Un bloc de calcaire posé sur un traîneau de bois (deux patins recourbés et des
## traverses), tiré par des cordes. On le halait sur un chemin de limon mouillé :
## un homme versait de l'eau devant les patins pour qu'ils glissent (comme sur la
## peinture du tombeau de Djéhoutihotep).
##
## La quête le fait avancer (étape « escorte » avec « charge ») et appelle tirer()
## avec la position des haleurs : les cordes vont du traîneau à chacun d'eux.

var materiau_bloc: Material
var materiau_bois: Material
var _cordes: MeshInstance3D
var _maillage_cordes: ImmediateMesh
var _materiau_corde: StandardMaterial3D
var _eau: GPUParticles3D


func _ready() -> void:
	_construire()


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	var bois := materiau_bois
	if bois == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.4, 0.3)
		bois = m
	var bloc := materiau_bloc
	if bloc == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.93, 0.9, 0.82)
		bloc = m
	# Les deux patins, recourbés à l'avant (vers -Z).
	for cote in [-0.55, 0.55]:
		var patin := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.18, 0.2, 2.6)
		patin.mesh = b
		patin.material_override = bois
		patin.position = Vector3(cote, 0.1, 0.1)
		add_child(patin)
		var pointe := MeshInstance3D.new()
		var bp := BoxMesh.new()
		bp.size = Vector3(0.18, 0.18, 0.6)
		pointe.mesh = bp
		pointe.material_override = bois
		pointe.position = Vector3(cote, 0.25, -1.35)
		pointe.rotation.x = 0.6
		add_child(pointe)
	for k in 4:
		var traverse := MeshInstance3D.new()
		var bt := BoxMesh.new()
		bt.size = Vector3(1.4, 0.1, 0.16)
		traverse.mesh = bt
		traverse.material_override = bois
		traverse.position = Vector3(0, 0.25, -0.9 + k * 0.6)
		add_child(traverse)
	var pierre := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.1, 1.0, 1.7)
	pierre.mesh = bb
	pierre.material_override = bloc
	pierre.position = Vector3(0, 0.8, 0.1)
	add_child(pierre)
	# Une marque d'équipe peinte à l'ocre rouge sur le flanc du bloc (un signe simple).
	var ocre := StandardMaterial3D.new()
	ocre.albedo_color = Color(0.6, 0.17, 0.07)
	ocre.roughness = 1.0
	for t in [[Vector3(0.012, 0.5, 0.06), Vector3(0.556, 0.85, -0.1)], [Vector3(0.012, 0.06, 0.4), Vector3(0.556, 0.95, -0.1)],
			[Vector3(0.012, 0.3, 0.05), Vector3(0.556, 0.85, 0.35)], [Vector3(0.012, 0.05, 0.25), Vector3(0.556, 0.72, 0.35)]]:
		var trace := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = t[0]
		trace.mesh = bm
		trace.material_override = ocre
		trace.position = t[1]
		add_child(trace)
	# Collision : on ne traverse pas le bloc.
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(1.4, 1.4, 2.6)
	forme.shape = boite
	forme.position.y = 0.7
	corps.add_child(forme)
	add_child(corps)
	_maillage_cordes = ImmediateMesh.new()
	_cordes = MeshInstance3D.new()
	_cordes.mesh = _maillage_cordes
	_materiau_corde = StandardMaterial3D.new()
	_materiau_corde.albedo_color = Color(0.55, 0.45, 0.3)
	_materiau_corde.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cordes.material_override = _materiau_corde
	_cordes.top_level = true
	add_child(_cordes)
	# L'eau qu'on verse devant les patins pendant qu'on tire.
	if DisplayServer.get_name() == "headless" or Engine.is_editor_hint():
		return
	_eau = GPUParticles3D.new()
	_eau.amount = 40
	_eau.lifetime = 0.6
	_eau.emitting = false
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3(0, -1, -0.3)
	p.spread = 15.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -9.8, 0)
	_eau.process_material = p
	var goutte := SphereMesh.new()
	goutte.radius = 0.025
	goutte.height = 0.05
	var mg := StandardMaterial3D.new()
	mg.albedo_color = Color(0.55, 0.6, 0.55, 0.6)
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	goutte.material = mg
	_eau.draw_pass_1 = goutte
	_eau.position = Vector3(0, 0.6, -1.7)
	add_child(_eau)


## Tend les cordes vers les haleurs (positions dans le monde).
func tirer(haleurs: Array[Vector3], en_mouvement: bool) -> void:
	if _maillage_cordes == null:
		return
	_maillage_cordes.clear_surfaces()
	if not haleurs.is_empty():
		_maillage_cordes.surface_begin(Mesh.PRIMITIVE_LINES)
		var avant_g := to_global(Vector3(-0.5, 0.45, -1.5))
		var avant_d := to_global(Vector3(0.5, 0.45, -1.5))
		for k in haleurs.size():
			var depart := avant_g if k % 2 == 0 else avant_d
			# Une corde un peu détendue : trois segments qui pendent légèrement.
			var milieu := depart.lerp(haleurs[k], 0.5) + Vector3(0, -0.12 if not en_mouvement else -0.03, 0)
			_maillage_cordes.surface_add_vertex(depart)
			_maillage_cordes.surface_add_vertex(milieu)
			_maillage_cordes.surface_add_vertex(milieu)
			_maillage_cordes.surface_add_vertex(haleurs[k])
		_maillage_cordes.surface_end()
	if _eau != null:
		_eau.emitting = en_mouvement
