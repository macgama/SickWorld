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


func _construire_encre() -> void:
	# De la poussière d'encre noire et luisante, avec des reflets violets (l'effacement).
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.03, 0.025, 0.04)
	noir.roughness = 0.08
	noir.metallic_specular = 0.9
	var reflet := StandardMaterial3D.new()
	reflet.albedo_color = Color(0.35, 0.15, 0.6)
	reflet.emission_enabled = true
	reflet.emission = Color(0.55, 0.25, 1.0)
	reflet.emission_energy_multiplier = 1.6
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	var flaque := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.45
	c.bottom_radius = 0.5
	c.height = 0.02
	flaque.mesh = c
	flaque.material_override = noir
	flaque.position.y = 0.01
	_visuel.add_child(flaque)
	for k in 7:
		var eclat := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.06, hasard.randf_range(0.08, 0.2), 0.05)
		eclat.mesh = p
		eclat.material_override = reflet if k % 3 == 0 else noir
		eclat.position = Vector3(hasard.randf_range(-0.3, 0.3), 0.05, hasard.randf_range(-0.3, 0.3))
		eclat.rotation = Vector3(hasard.randf_range(-0.5, 0.5), hasard.randf() * TAU, hasard.randf_range(-0.5, 0.5))
		_visuel.add_child(eclat)


## Un scarabée de faïence bleue posé sur un cordon, qui grésille d'une lueur violette
## (les amulettes de la « prêtresse »).
func _construire_amulette() -> void:
	var faience := StandardMaterial3D.new()
	faience.albedo_color = Color(0.18, 0.5, 0.72)
	faience.roughness = 0.2
	faience.emission_enabled = true
	faience.emission = Color(0.55, 0.3, 1.0)
	faience.emission_energy_multiplier = 0.9
	var scarabee := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.08
	scarabee.mesh = s
	scarabee.scale = Vector3(1.0, 0.7, 1.4)
	scarabee.material_override = faience
	scarabee.position.y = 0.05
	_visuel.add_child(scarabee)
	var cordon := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.17
	t.outer_radius = 0.185
	cordon.mesh = t
	var lin := StandardMaterial3D.new()
	lin.albedo_color = Color(0.75, 0.68, 0.52)
	cordon.material_override = lin
	cordon.position.y = 0.012
	_visuel.add_child(cordon)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.6, 0.4, 1.0)
	lumiere.light_energy = 0.6
	lumiere.omni_range = 2.0
	lumiere.position.y = 0.3
	_visuel.add_child(lumiere)


## Un panier de roseau rempli de petits scarabées de stéatite (les vraies amulettes d'Ouni).
func _construire_panier() -> void:
	var roseau := StandardMaterial3D.new()
	roseau.albedo_color = Color(0.62, 0.5, 0.3)
	roseau.roughness = 1.0
	var panier := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.17
	c.height = 0.18
	panier.mesh = c
	panier.material_override = roseau
	panier.position.y = 0.09
	_visuel.add_child(panier)
	var bleu := StandardMaterial3D.new()
	bleu.albedo_color = Color(0.2, 0.45, 0.62)
	bleu.roughness = 0.35
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 9:
		var s := MeshInstance3D.new()
		var b := SphereMesh.new()
		b.radius = 0.035
		b.height = 0.04
		s.mesh = b
		s.scale = Vector3(1.0, 0.7, 1.4)
		s.material_override = bleu
		s.position = Vector3(hasard.randf_range(-0.12, 0.12), 0.19, hasard.randf_range(-0.12, 0.12))
		s.rotation.y = hasard.randf() * TAU
		_visuel.add_child(s)
