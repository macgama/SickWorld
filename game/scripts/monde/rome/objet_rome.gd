@tool
extends "res://scripts/monde/grece/objet_grece.gd"
## Objets de quête de l'île de Rome (en plus de ceux de la Grèce, de l'Égypte et de la
## Préhistoire) :
## - « radio_vigie » : la petite radio de la Vigie laissée par l'agent Livia Conti ;
## - « milliaire » : une borne milliaire renversée, fendue d'un éclat violet. Une fois
##   redressée (cacher()), elle reste debout au lieu de disparaître.
## Un Égaré à « renouer » n'a pas de forme : l'objet est invisible, posé sur le personnage.

var _debout: Node3D


## Une radio de terrain : un boîtier gris, son antenne et sa diode cyan.
func _construire_radio_vigie() -> void:
	var gris := _mat_uni(Color(0.2, 0.22, 0.24), 0.6, 0.3)
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.3, 0.1)
	_morceau(b, gris, Vector3(0, 0.15, 0), Vector3(0, 0.5, 0))
	var antenne := CylinderMesh.new()
	antenne.top_radius = 0.006
	antenne.bottom_radius = 0.01
	antenne.height = 0.4
	_morceau(antenne, gris, Vector3(0.06, 0.48, 0.0), Vector3(0, 0, 0.15))
	var diode := SphereMesh.new()
	diode.radius = 0.02
	diode.height = 0.04
	_morceau(diode, _emissif(Color(0.3, 0.9, 1.0), 4.0), Vector3(-0.05, 0.26, 0.05))


## Une borne milliaire romaine couchée dans l'herbe, fendue d'une lueur violette ; et la
## même, debout, cachée jusqu'à ce qu'on la redresse.
func _construire_milliaire() -> void:
	var tuf := _mat_uni(Color(0.6, 0.56, 0.45), 0.95)
	var travertin := _mat_uni(Color(0.84, 0.8, 0.7), 0.85)
	var couchee := Node3D.new()
	couchee.rotation = Vector3(0, 0.6, 1.45)
	couchee.position = Vector3(0, 0.34, 0)
	_visuel.add_child(couchee)
	var fut := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.34
	c.height = 1.9
	fut.mesh = c
	fut.material_override = travertin
	couchee.add_child(fut)
	var fente := MeshInstance3D.new()
	var f := BoxMesh.new()
	f.size = Vector3(0.05, 1.6, 0.66)
	fente.mesh = f
	fente.material_override = _emissif(Color(0.62, 0.3, 1.0), 3.0)
	couchee.add_child(fente)
	var socle := BoxMesh.new()
	socle.size = Vector3(0.8, 0.5, 0.8)
	_morceau(socle, tuf, Vector3(0.9, 0.2, 0.4), Vector3(0, 0.3, 0.1))
	_trace_violette()
	_debout = Node3D.new()
	_debout.name = "Debout"
	_debout.visible = false
	add_child(_debout)
	var s2 := MeshInstance3D.new()
	s2.mesh = socle
	s2.material_override = tuf
	s2.position.y = 0.15
	_debout.add_child(s2)
	var f2 := MeshInstance3D.new()
	f2.mesh = c
	f2.material_override = travertin
	f2.position.y = 1.35
	_debout.add_child(f2)


func cacher() -> void:
	super.cacher()
	if _debout != null:
		_debout.visible = true


## Un gros sac de toile plein de blé, ficelé en haut, avec un peu de grain renversé.
func _construire_sac() -> void:
	var toile := _mat_uni(Color(0.72, 0.62, 0.44), 0.95)
	var corps := SphereMesh.new()
	corps.radius = 0.3
	corps.height = 0.75
	_morceau(corps, toile, Vector3(0, 0.36, 0))
	var col := CylinderMesh.new()
	col.top_radius = 0.1
	col.bottom_radius = 0.07
	col.height = 0.16
	_morceau(col, toile, Vector3(0, 0.76, 0))
	var lien := TorusMesh.new()
	lien.inner_radius = 0.06
	lien.outer_radius = 0.085
	_morceau(lien, _mat_uni(Color(0.4, 0.3, 0.18), 0.9), Vector3(0, 0.7, 0))
	var grain := CylinderMesh.new()
	grain.top_radius = 0.18
	grain.bottom_radius = 0.26
	grain.height = 0.05
	_morceau(grain, _mat_uni(Color(0.86, 0.72, 0.4), 0.9), Vector3(0.32, 0.02, 0.1))


## Les oies sacrées de Junon, dans leur enclos du Capitole : blanches, le cou tendu, le
## bec orange. Quand on ouvre l'enclos (cacher()), elles s'envolent en criant.
func _construire_oies() -> void:
	var blanc := _mat_uni(Color(0.95, 0.94, 0.9), 0.8)
	var orange := _mat_uni(Color(0.95, 0.55, 0.15), 0.6)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 7:
		var oie := Node3D.new()
		oie.position = Vector3(hasard.randf_range(-2.2, 2.2), 0, hasard.randf_range(-2.2, 2.2))
		oie.rotation.y = hasard.randf() * TAU
		_visuel.add_child(oie)
		var corps := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.22
		s.height = 0.36
		corps.mesh = s
		corps.material_override = blanc
		corps.scale = Vector3(1.0, 1.0, 1.5)
		corps.position.y = 0.32
		oie.add_child(corps)
		var cou := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.04
		c.bottom_radius = 0.06
		c.height = 0.36
		cou.mesh = c
		cou.material_override = blanc
		cou.position = Vector3(0, 0.56, 0.24)
		cou.rotation.x = -0.35
		oie.add_child(cou)
		var tete := MeshInstance3D.new()
		var t := SphereMesh.new()
		t.radius = 0.07
		t.height = 0.13
		tete.mesh = t
		tete.material_override = blanc
		tete.position = Vector3(0, 0.75, 0.3)
		oie.add_child(tete)
		var bec := MeshInstance3D.new()
		var b := CylinderMesh.new()
		b.top_radius = 0.0
		b.bottom_radius = 0.035
		b.height = 0.12
		bec.mesh = b
		bec.material_override = orange
		bec.position = Vector3(0, 0.74, 0.41)
		bec.rotation.x = PI / 2
		oie.add_child(bec)
		for cote in [-1.0, 1.0]:
			var patte := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.015
			pm.bottom_radius = 0.015
			pm.height = 0.18
			patte.mesh = pm
			patte.material_override = orange
			patte.position = Vector3(cote * 0.08, 0.09, 0)
			oie.add_child(patte)


## Un foyer de l'incendie du Champ de Mars : des poutres et des débris qui flambent haut,
## et une colonne de fumée noire qu'on voit de loin.
func _construire_brasier() -> void:
	_construire_incendie()
	_visuel.scale = Vector3(2.6, 2.6, 2.6)
	if _lumiere_feu != null:
		_lumiere_feu.omni_range = 6.0
		_lumiere_feu.light_energy = 3.5
	var bois := _mat_uni(Color(0.16, 0.1, 0.07), 0.9)
	for k in 3:
		var poutre := BoxMesh.new()
		poutre.size = Vector3(0.12, 0.12, 1.6)
		_morceau(poutre, bois, Vector3(-0.4 + k * 0.4, 0.25, 0.0), Vector3(0.3, k * 0.9, 0.0))
	# La fumée : des volutes grises qui montent, grossissent et s'effacent, poussées par le vent.
	var fumee := CPUParticles3D.new()
	fumee.amount = 36
	fumee.lifetime = 7.0
	fumee.preprocess = 7.0
	fumee.position = Vector3(0, 1.4, 0)
	fumee.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fumee.emission_sphere_radius = 0.4
	fumee.direction = Vector3(0, 1, 0)
	fumee.spread = 12.0
	fumee.gravity = Vector3(0.25, 0.35, 0.05)
	fumee.initial_velocity_min = 0.5
	fumee.initial_velocity_max = 0.8
	fumee.scale_amount_min = 0.6
	fumee.scale_amount_max = 1.0
	var taille := Curve.new()
	taille.max_value = 4.0
	taille.add_point(Vector2(0, 0.5))
	taille.add_point(Vector2(1, 3.2))
	fumee.scale_amount_curve = taille
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.14, 0.13, 0.12, 0.55))
	teinte.set_color(1, Color(0.45, 0.43, 0.4, 0.0))
	fumee.color_ramp = teinte
	var boule := SphereMesh.new()
	boule.radius = 0.8
	boule.height = 1.3
	boule.radial_segments = 10
	boule.rings = 5
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	boule.material = m
	fumee.mesh = boule
	fumee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuel.add_child(fumee)


## Une jarre de poix cachée sous les gradins du Colisée (chapitre 7) : une grosse jarre
## noire, le col bouché d'étoupe, et une mèche qui fume. L'éclat violet des Effaceurs.
func _construire_jarre_poix() -> void:
	var terre := _mat_uni(Color(0.16, 0.12, 0.1), 0.8)
	var corps := SphereMesh.new()
	corps.radius = 0.3
	corps.height = 0.72
	_morceau(corps, terre, Vector3(0, 0.38, 0))
	var col := CylinderMesh.new()
	col.top_radius = 0.1
	col.bottom_radius = 0.12
	col.height = 0.16
	_morceau(col, terre, Vector3(0, 0.78, 0))
	var etoupe := SphereMesh.new()
	etoupe.radius = 0.1
	etoupe.height = 0.12
	_morceau(etoupe, _mat_uni(Color(0.6, 0.52, 0.38), 1.0), Vector3(0, 0.88, 0))
	var meche := CylinderMesh.new()
	meche.top_radius = 0.008
	meche.bottom_radius = 0.01
	meche.height = 0.2
	_morceau(meche, _mat_uni(Color(0.2, 0.18, 0.15), 1.0), Vector3(0.03, 0.98, 0), Vector3(0, 0, 0.3))
	var braise := SphereMesh.new()
	braise.radius = 0.025
	braise.height = 0.05
	_morceau(braise, _emissif(Color(1.0, 0.5, 0.15), 6.0), Vector3(0.06, 1.08, 0))
	var fumee := CPUParticles3D.new()
	fumee.amount = 10
	fumee.lifetime = 2.5
	fumee.position = Vector3(0.06, 1.1, 0)
	fumee.direction = Vector3.UP
	fumee.spread = 12.0
	fumee.gravity = Vector3(0, 0.4, 0)
	fumee.initial_velocity_min = 0.2
	fumee.initial_velocity_max = 0.4
	var boule := SphereMesh.new()
	boule.radius = 0.06
	boule.height = 0.12
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color(0.3, 0.3, 0.32, 0.5)
	gris.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gris.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boule.material = gris
	fumee.mesh = boule
	_visuel.add_child(fumee)
	_trace_violette()
