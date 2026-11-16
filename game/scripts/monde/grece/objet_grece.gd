@tool
extends "res://scripts/monde/egypte/objet_egypte.gd"
## Objets de quête de l'île de Grèce (en plus de ceux de l'Égypte et de la Préhistoire) :
## - « sac_voyage » : le sac à dos de l'agent Markos, coincé entre deux rochers ;
## - « filet » : un filet de pêche emmêlé, avec ses flotteurs de liège ;
## - « amphore » : une amphore de terre cuite, debout ;
## - « masque » : un masque de théâtre blanc, posé dans l'herbe, avec un éclat violet.


func _construire_sac_voyage() -> void:
	var toile := StandardMaterial3D.new()
	toile.albedo_color = Color(0.22, 0.27, 0.22)
	toile.roughness = 0.9
	var sac := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.45, 0.55, 0.28)
	sac.mesh = b
	sac.material_override = toile
	sac.position.y = 0.26
	sac.rotation = Vector3(0.25, 0.4, 0.15)
	_visuel.add_child(sac)
	var poche := MeshInstance3D.new()
	var p := BoxMesh.new()
	p.size = Vector3(0.36, 0.22, 0.08)
	poche.mesh = p
	poche.material_override = toile
	poche.position = Vector3(0, -0.08, 0.17)
	sac.add_child(poche)
	# La bande cyan de la Vigie, et une petite diode qui clignote (la radio).
	var bande := StandardMaterial3D.new()
	bande.albedo_color = Color(0.25, 0.8, 1.0)
	bande.emission_enabled = true
	bande.emission = Color(0.25, 0.8, 1.0)
	bande.emission_energy_multiplier = 1.4
	var trait_cyan := MeshInstance3D.new()
	var t := BoxMesh.new()
	t.size = Vector3(0.46, 0.04, 0.29)
	trait_cyan.mesh = t
	trait_cyan.material_override = bande
	trait_cyan.position.y = 0.12
	sac.add_child(trait_cyan)


func _construire_filet() -> void:
	var corde := StandardMaterial3D.new()
	corde.albedo_color = Color(0.62, 0.56, 0.42)
	corde.roughness = 1.0
	var liege := StandardMaterial3D.new()
	liege.albedo_color = Color(0.55, 0.38, 0.22)
	for k in 7:
		var brin := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.012
		c.bottom_radius = 0.012
		c.height = 1.2
		brin.mesh = c
		brin.material_override = corde
		brin.rotation = Vector3(PI / 2, k * 0.45, 0.2 * sin(k))
		brin.position = Vector3(0, 0.05 + k * 0.01, 0)
		_visuel.add_child(brin)
	for k in 5:
		var flotteur := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.06
		s.height = 0.1
		flotteur.mesh = s
		flotteur.material_override = liege
		var a := TAU * k / 5.0
		flotteur.position = Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45)
		_visuel.add_child(flotteur)


func _construire_amphore() -> void:
	var argile := StandardMaterial3D.new()
	argile.albedo_color = Color(0.82, 0.48, 0.3)
	argile.roughness = 0.85
	var corps := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.62
	corps.mesh = s
	corps.material_override = argile
	corps.position.y = 0.38
	_visuel.add_child(corps)
	var col := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.07
	c.height = 0.22
	col.mesh = c
	col.material_override = argile
	col.position.y = 0.76
	_visuel.add_child(col)


func _construire_masque() -> void:
	# Un masque de tragédie en lin plâtré, blanc, la bouche ouverte, posé de biais.
	var platre := StandardMaterial3D.new()
	platre.albedo_color = Color(0.92, 0.9, 0.84)
	platre.roughness = 0.7
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.04, 0.03, 0.03)
	var visage := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.16
	s.height = 0.4
	s.is_hemisphere = true
	visage.mesh = s
	visage.material_override = platre
	visage.scale = Vector3(1.0, 1.0, 0.45)
	visage.rotation = Vector3(-1.35, 0.5, 0.0)
	visage.position.y = 0.06
	_visuel.add_child(visage)
	for k in 3:
		var trou := MeshInstance3D.new()
		var t := SphereMesh.new()
		t.radius = 0.03 if k < 2 else 0.045
		t.height = t.radius * 1.2
		trou.mesh = t
		trou.material_override = noir
		trou.position = Vector3((-0.055 if k == 0 else 0.055) if k < 2 else 0.0, 0.18, 0.06 if k < 2 else -0.07)
		trou.scale = Vector3(1.0, 0.3, 1.3 if k < 2 else 0.8)
		visage.add_child(trou)
	# L'éclat de faille, violet, planté dans le front.
	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(0.6, 0.3, 1.0)
	cristal.emission_enabled = true
	cristal.emission = Color(0.6, 0.3, 1.0)
	cristal.emission_energy_multiplier = 2.5
	var eclat := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.025
	c.height = 0.12
	c.radial_segments = 5
	eclat.mesh = c
	eclat.material_override = cristal
	eclat.position = Vector3(0.0, 0.14, 0.13)
	visage.add_child(eclat)
