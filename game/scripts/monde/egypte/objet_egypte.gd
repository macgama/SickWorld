@tool
extends "res://scripts/monde/prehistoire/objet_quete.gd"
## Objets de quête de l'île d'Égypte (en plus de ceux de la Préhistoire) :
## - « caisse_flottante » : une caisse étanche de la Vigie qui dérive dans les roseaux ;
## - « balise » : l'emplacement où planter la balise de la Vigie (un piquet et un repère au sol).

var _flotte := false


func _construire_caisse_flottante() -> void:
	_flotte = true
	var coque := StandardMaterial3D.new()
	coque.albedo_color = Color(0.17, 0.19, 0.21)
	coque.roughness = 0.45
	var bande := StandardMaterial3D.new()
	bande.albedo_color = Color(0.25, 0.8, 1.0)
	bande.emission_enabled = true
	bande.emission = Color(0.25, 0.8, 1.0)
	bande.emission_energy_multiplier = 1.2
	var boite := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.75, 0.38, 0.5)
	boite.mesh = b
	boite.material_override = coque
	boite.position.y = 0.05
	_visuel.add_child(boite)
	var trace := MeshInstance3D.new()
	var t := BoxMesh.new()
	t.size = Vector3(0.77, 0.04, 0.52)
	trace.mesh = t
	trace.material_override = bande
	trace.position.y = 0.12
	_visuel.add_child(trace)
	# Deux poignées sur le dessus.
	for cote in [-0.22, 0.22]:
		var poignee := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = 0.03
		tore.outer_radius = 0.05
		poignee.mesh = tore
		poignee.material_override = coque
		poignee.position = Vector3(cote, 0.26, 0)
		poignee.rotation.x = PI / 2
		_visuel.add_child(poignee)
	_visuel.rotation = Vector3(0.12, hash(identifiant) % 628 / 100.0, 0.08)


func _construire_balise() -> void:
	# Un piquet de bois planté dans la terre, avec un ruban de la Vigie.
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.45, 0.35, 0.25)
	var piquet := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.03
	c.bottom_radius = 0.04
	c.height = 0.9
	piquet.mesh = c
	piquet.material_override = bois
	piquet.position.y = 0.45
	_visuel.add_child(piquet)
	var ruban := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.08)
	ruban.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.8, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.25, 0.8, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ruban.material_override = m
	ruban.position = Vector3(0.15, 0.82, 0)
	_visuel.add_child(ruban)


func _process(delta: float) -> void:
	super._process(delta)
	if _flotte and _visuel != null and not Engine.is_editor_hint():
		_visuel.position.y = sin(_temps * 1.4 + position.x) * 0.04
