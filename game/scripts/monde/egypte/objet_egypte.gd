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


## Une empreinte de chaussure moderne dans le sable : semelle crantée, talon marqué.
func _construire_empreinte_semelle() -> void:
	var creux := StandardMaterial3D.new()
	creux.albedo_color = Color(0.42, 0.25, 0.16)
	creux.roughness = 1.0
	for pas in 3:
		var pied := Node3D.new()
		pied.position = Vector3((pas % 2) * 0.22 - 0.11, 0.005, -pas * 0.75)
		_visuel.add_child(pied)
		var semelle := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.11, 0.012, 0.2)
		semelle.mesh = b
		semelle.material_override = creux
		semelle.position.z = -0.04
		pied.add_child(semelle)
		var talon := MeshInstance3D.new()
		var bt := BoxMesh.new()
		bt.size = Vector3(0.09, 0.012, 0.08)
		talon.mesh = bt
		talon.material_override = creux
		talon.position.z = 0.12
		pied.add_child(talon)
		# Les crans de la semelle : de petites barres en relief, impossibles en -2560.
		for k in 5:
			var cran := MeshInstance3D.new()
			var bc := BoxMesh.new()
			bc.size = Vector3(0.1, 0.02, 0.012)
			cran.mesh = bc
			cran.material_override = creux
			cran.position = Vector3(0, 0.004, -0.12 + k * 0.035)
			pied.add_child(cran)


# --- Objets des quêtes secondaires de l'Égypte ------------------------------------------------

## Une gerbe d'orge mûre, liée d'un brin de lin, encore debout dans le champ.
func _construire_gerbe() -> void:
	var paille := _mat(Color(0.78, 0.64, 0.33), 0.9)
	var epi := _mat(Color(0.86, 0.72, 0.38), 0.85)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 16:
		var a := hasard.randf() * TAU
		var r := hasard.randf_range(0.0, 0.09)
		var penche := Vector3(hasard.randf_range(-0.18, 0.18), 0, hasard.randf_range(-0.18, 0.18))
		var tige := CylinderMesh.new()
		tige.top_radius = 0.004
		tige.bottom_radius = 0.006
		tige.height = 0.85
		var t := _piece(tige, paille, Vector3(cos(a) * r, 0.42, sin(a) * r), penche)
		var e := CapsuleMesh.new()
		e.radius = 0.014
		e.height = 0.11
		var tete := MeshInstance3D.new()
		tete.mesh = e
		tete.material_override = epi
		tete.position.y = 0.46
		t.add_child(tete)
	var lien := TorusMesh.new()
	lien.inner_radius = 0.07
	lien.outer_radius = 0.085
	_piece(lien, _mat(Color(0.88, 0.84, 0.72)), Vector3(0, 0.32, 0))


## Miou, une chatte tigrée assise entre les jarres, les yeux qui brillent.
func _construire_chat() -> void:
	var pelage := _mat(Color(0.52, 0.42, 0.3), 1.0)
	var rayure := _mat(Color(0.25, 0.19, 0.13), 1.0)
	var corps := SphereMesh.new()
	corps.radius = 0.12
	corps.height = 0.24
	_piece(corps, pelage, Vector3(0, 0.14, 0.04), Vector3(-0.35, 0, 0), Vector3(0.85, 1.25, 1.0))
	var tete := SphereMesh.new()
	tete.radius = 0.075
	tete.height = 0.14
	var t := _piece(tete, pelage, Vector3(0, 0.34, -0.04), Vector3.ZERO, Vector3(1.05, 0.9, 0.95))
	for cote in [-1.0, 1.0]:
		var oreille := PrismMesh.new()
		oreille.size = Vector3(0.05, 0.06, 0.02)
		var o := MeshInstance3D.new()
		o.mesh = oreille
		o.material_override = pelage
		o.position = Vector3(cote * 0.04, 0.07, 0)
		o.rotation.z = -cote * 0.25
		t.add_child(o)
		var oeil := SphereMesh.new()
		oeil.radius = 0.012
		oeil.height = 0.024
		var yeux := _mat(Color(0.55, 0.75, 0.25), 0.1)
		yeux.emission_enabled = true
		yeux.emission = Color(0.6, 0.85, 0.3)
		yeux.emission_energy_multiplier = 0.8
		var y := MeshInstance3D.new()
		y.mesh = oeil
		y.material_override = yeux
		y.position = Vector3(cote * 0.03, 0.012, -0.065)
		t.add_child(y)
		var patte := CapsuleMesh.new()
		patte.radius = 0.022
		patte.height = 0.16
		_piece(patte, pelage, Vector3(cote * 0.045, 0.08, -0.06))
	for k in 4:
		var bande := TorusMesh.new()
		bande.inner_radius = 0.1
		bande.outer_radius = 0.112
		_piece(bande, rayure, Vector3(0, 0.08 + k * 0.05, 0.05), Vector3(-0.35, 0, 0), Vector3(0.85, 1.0, 1.0))
	var queue := CapsuleMesh.new()
	queue.radius = 0.016
	queue.height = 0.32
	_piece(queue, rayure, Vector3(0.1, 0.03, 0.06), Vector3(PI / 2, 0, 0.9))
	_visuel.rotation.y = 0.5


## Une croûte de natron : le sel blanc qui sèche au bord des oueds.
func _construire_natron() -> void:
	var sel := _mat(Color(0.93, 0.92, 0.86), 0.7)
	var gris := _mat(Color(0.78, 0.76, 0.7), 0.9)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 9:
		var s := SphereMesh.new()
		s.radius = hasard.randf_range(0.08, 0.2)
		s.height = s.radius * 2.0
		_piece(s, sel if k % 3 else gris, Vector3(hasard.randf_range(-0.35, 0.35), 0.0, hasard.randf_range(-0.35, 0.35)),
				Vector3(0, hasard.randf() * TAU, 0), Vector3(1.0, hasard.randf_range(0.2, 0.4), 1.0))


## Des ruches égyptiennes : des tubes de terre crue couchés et empilés, l'entrée vers l'avant.
func _construire_ruche() -> void:
	var terre := _mat(Color(0.5, 0.38, 0.27), 1.0)
	var sombre := _mat(Color(0.12, 0.09, 0.06), 1.0)
	for place: Vector2 in [Vector2(-0.19, 0.17), Vector2(0.19, 0.17), Vector2(0.0, 0.48)]:
		var tube := CylinderMesh.new()
		tube.top_radius = 0.17
		tube.bottom_radius = 0.18
		tube.height = 1.0
		_piece(tube, terre, Vector3(place.x, place.y, 0), Vector3(PI / 2, 0, 0))
		var trou := CylinderMesh.new()
		trou.top_radius = 0.035
		trou.bottom_radius = 0.035
		trou.height = 0.01
		_piece(trou, sombre, Vector3(place.x, place.y, -0.505), Vector3(PI / 2, 0, 0))
	var abeille := _mat(Color(0.2, 0.15, 0.05), 0.6)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 8:
		var b := SphereMesh.new()
		b.radius = 0.012
		b.height = 0.02
		_piece(b, abeille, Vector3(hasard.randf_range(-0.4, 0.4), hasard.randf_range(0.2, 0.8), hasard.randf_range(-0.8, -0.55)))


## Un haleur blessé allongé sur une natte de roseau, les mains brûlées par les cordes.
func _construire_natte() -> void:
	var roseau := _mat(Color(0.7, 0.6, 0.38), 1.0)
	var peau := _mat(Color(0.55, 0.36, 0.23), 0.7)
	var lin := _mat(Color(0.9, 0.87, 0.78), 0.9)
	var plaie := _mat(Color(0.62, 0.18, 0.12), 0.6)
	var natte := BoxMesh.new()
	natte.size = Vector3(0.8, 0.03, 1.9)
	_piece(natte, roseau, Vector3(0, 0.015, 0))
	var torse := CapsuleMesh.new()
	torse.radius = 0.17
	torse.height = 0.75
	_piece(torse, peau, Vector3(0, 0.15, -0.25), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.75))
	var pagne := CapsuleMesh.new()
	pagne.radius = 0.16
	pagne.height = 0.4
	_piece(pagne, lin, Vector3(0, 0.14, 0.2), Vector3(PI / 2, 0, 0), Vector3(1.05, 1.0, 0.75))
	for cote in [-1.0, 1.0]:
		var jambe := CapsuleMesh.new()
		jambe.radius = 0.06
		jambe.height = 0.75
		_piece(jambe, peau, Vector3(cote * 0.08, 0.08, 0.58), Vector3(PI / 2, 0, 0))
		var bras := CapsuleMesh.new()
		bras.radius = 0.045
		bras.height = 0.6
		_piece(bras, peau, Vector3(cote * 0.24, 0.08, -0.2), Vector3(PI / 2, 0, 0))
		var main := SphereMesh.new()
		main.radius = 0.05
		main.height = 0.08
		_piece(main, plaie, Vector3(cote * 0.25, 0.08, 0.1))
	var tete := SphereMesh.new()
	tete.radius = 0.1
	tete.height = 0.2
	_piece(tete, peau, Vector3(0, 0.12, -0.75))
	var cheveux := SphereMesh.new()
	cheveux.radius = 0.102
	cheveux.height = 0.12
	_piece(cheveux, _mat(Color(0.05, 0.04, 0.04), 0.9), Vector3(0, 0.13, -0.79))
	_visuel.rotation.y = hash(identifiant) % 314 / 100.0


## Un bloc de calcaire du chantier, prêt à être tiré. Les équipes y peignent leur nom.
func _construire_bloc() -> void:
	var calcaire := _mat(Color(0.83, 0.77, 0.64), 0.95)
	var b := BoxMesh.new()
	b.size = Vector3(1.5, 1.0, 1.0)
	_piece(b, calcaire, Vector3(0, 0.5, 0))
	# La vieille marque, effacée : quelques traînées violettes.
	var efface := _mat(Color(0.35, 0.18, 0.55), 0.6)
	efface.emission_enabled = true
	efface.emission = Color(0.5, 0.25, 0.9)
	efface.emission_energy_multiplier = 0.5
	for k in 3:
		var ligne := BoxMesh.new()
		ligne.size = Vector3(0.9 - k * 0.2, 0.04, 0.01)
		_piece(ligne, efface, Vector3(-0.1 + k * 0.08, 0.35 + k * 0.18, -0.505), Vector3(0, 0, 0.08 * (k - 1)))


## Ce que change une étape faite (quêtes secondaires) : ici, la marque peinte sur le bloc.
func appliquer_effet(effet: String) -> void:
	if effet != "marque" or _visuel == null or _visuel.get_node_or_null("Marque") != null:
		return
	for enfant in _visuel.get_children():
		var mi := enfant as MeshInstance3D
		if mi != null and mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.y < 0.05:
			mi.visible = false
	var marque := Label3D.new()
	marque.name = "Marque"
	marque.text = "COMPAGNONS\nDE KHÉOPS"
	marque.font_size = 64
	marque.pixel_size = 0.0026
	marque.modulate = Color(0.68, 0.17, 0.08)
	marque.outline_size = 0
	marque.shaded = true
	marque.position = Vector3(0.12, 0.55, -0.506)
	marque.rotation.y = PI
	_visuel.add_child(marque)
	# Le cartouche du roi, à côté : un ovale rouge.
	var cartouche := TorusMesh.new()
	cartouche.inner_radius = 0.07
	cartouche.outer_radius = 0.085
	_piece(cartouche, _mat(Color(0.68, 0.17, 0.08)), Vector3(-0.56, 0.55, -0.505), Vector3(PI / 2, 0, 0), Vector3(0.6, 1.0, 1.5))


## Un gobelet en carton (avec son couvercle en plastique) : rien à faire en -2560.
func _construire_gobelet() -> void:
	var g := CylinderMesh.new()
	g.top_radius = 0.045
	g.bottom_radius = 0.032
	g.height = 0.12
	_piece(g, _mat(Color(0.95, 0.94, 0.9), 0.7), Vector3(0, 0.04, 0), Vector3(PI / 2, 0.5, 0))
	var manchon := CylinderMesh.new()
	manchon.top_radius = 0.047
	manchon.bottom_radius = 0.04
	manchon.height = 0.05
	_piece(manchon, _mat(Color(0.5, 0.33, 0.2), 0.9), Vector3(0, 0.04, 0), Vector3(PI / 2, 0.5, 0))
	var couvercle := CylinderMesh.new()
	couvercle.top_radius = 0.042
	couvercle.bottom_radius = 0.047
	couvercle.height = 0.012
	_piece(couvercle, _mat(Color(0.1, 0.1, 0.1), 0.3), Vector3(0.18, 0.01, 0.1), Vector3(0, 0, 0.1))
	_trace_violette()


## Un petit drone de loisir écrasé dans le sable, une hélice cassée.
func _construire_drone() -> void:
	var plastique := _mat(Color(0.22, 0.23, 0.25), 0.4)
	var corps := BoxMesh.new()
	corps.size = Vector3(0.12, 0.05, 0.18)
	_piece(corps, plastique, Vector3(0, 0.05, 0))
	var camera := SphereMesh.new()
	camera.radius = 0.025
	camera.height = 0.05
	_piece(camera, _mat(Color(0.05, 0.05, 0.06), 0.1, 0.5), Vector3(0, 0.03, -0.09))
	for k in 4:
		var a := PI / 4 + k * PI / 2
		var bras := BoxMesh.new()
		bras.size = Vector3(0.02, 0.015, 0.17)
		var dir := Vector3(sin(a), 0, cos(a))
		_piece(bras, plastique, Vector3(0, 0.055, 0) + dir * 0.09, Vector3(0, a, 0))
		var helice := CylinderMesh.new()
		helice.top_radius = 0.07 if k != 2 else 0.035
		helice.bottom_radius = helice.top_radius
		helice.height = 0.004
		var m := _mat(Color(0.75, 0.76, 0.78, 0.6), 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_piece(helice, m, Vector3(0, 0.075, 0) + dir * 0.17)
		var led := SphereMesh.new()
		led.radius = 0.008
		led.height = 0.016
		var lm := _mat(Color(1, 0.1, 0.1) if k < 2 else Color(0.1, 1, 0.2))
		lm.emission_enabled = true
		lm.emission = lm.albedo_color
		lm.emission_energy_multiplier = 2.0
		_piece(led, lm, Vector3(0, 0.045, 0) + dir * 0.17)
	_visuel.rotation = Vector3(0.25, 0.7, -0.18)
	_trace_violette()


## Une borne de crue : un pilier de pierre gravé de traits, un par coudée d'eau.
func _construire_borne() -> void:
	var pierre := _mat(Color(0.7, 0.64, 0.52), 0.95)
	var grave := _mat(Color(0.3, 0.26, 0.2), 1.0)
	var p := BoxMesh.new()
	p.size = Vector3(0.32, 1.4, 0.32)
	_piece(p, pierre, Vector3(0, 0.7, 0))
	var tete := PrismMesh.new()
	tete.size = Vector3(0.34, 0.14, 0.34)
	_piece(tete, pierre, Vector3(0, 1.47, 0))
	for k in 6:
		var ligne := BoxMesh.new()
		ligne.size = Vector3(0.2 if k % 2 else 0.12, 0.015, 0.01)
		_piece(ligne, grave, Vector3(0, 0.25 + k * 0.2, -0.162))


## Un pion de senet en faïence bleue, un petit cône.
func _construire_pion() -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.008
	c.bottom_radius = 0.028
	c.height = 0.06
	var faience := _mat(Color(0.15, 0.45, 0.65), 0.25)
	faience.emission_enabled = true
	faience.emission = Color(0.1, 0.3, 0.45)
	faience.emission_energy_multiplier = 0.3
	_piece(c, faience, Vector3(0, 0.03, 0))
	var bout := SphereMesh.new()
	bout.radius = 0.012
	bout.height = 0.024
	_piece(bout, faience, Vector3(0, 0.065, 0))


## Le plateau de senet d'Ouni : trois rangées de dix cases, les pions et les bâtonnets.
func _construire_senet() -> void:
	var bois := _mat(Color(0.42, 0.28, 0.16), 0.7)
	var clair := _mat(Color(0.82, 0.72, 0.52), 0.8)
	var natte := BoxMesh.new()
	natte.size = Vector3(1.2, 0.02, 0.9)
	_piece(natte, _mat(Color(0.7, 0.6, 0.38), 1.0), Vector3(0, 0.01, 0))
	var boite := BoxMesh.new()
	boite.size = Vector3(0.66, 0.08, 0.24)
	_piece(boite, bois, Vector3(0, 0.06, 0))
	for rang in 3:
		for k in 10:
			var case_ := BoxMesh.new()
			case_.size = Vector3(0.056, 0.004, 0.064)
			_piece(case_, clair if (rang + k) % 2 == 0 else bois, Vector3(-0.29 + k * 0.064, 0.102, -0.072 + rang * 0.072))
	var bleu := _mat(Color(0.15, 0.45, 0.65), 0.25)
	var rouge := _mat(Color(0.6, 0.2, 0.12), 0.4)
	for k in 5:
		for camp in 2:
			var pion := CylinderMesh.new()
			pion.top_radius = 0.006 if camp == 0 else 0.016
			pion.bottom_radius = 0.016
			pion.height = 0.035
			_piece(pion, bleu if camp == 0 else rouge, Vector3(-0.29 + (k * 2 + camp) * 0.064, 0.122, -0.072 + (k % 3) * 0.072))
	for k in 4:
		var baton := BoxMesh.new()
		baton.size = Vector3(0.012, 0.006, 0.14)
		_piece(baton, clair, Vector3(0.42 + k * 0.03, 0.025, 0.12), Vector3(0, 0.3 * k - 0.4, 0))


# --- Objets des événements publics de l'Égypte ------------------------------------------------

## Une corde de papyrus enroulée au pied d'un bloc, prête à l'arrimer sur le traîneau.
func _construire_corde() -> void:
	var papyrus := _mat(Color(0.66, 0.55, 0.34), 1.0)
	var calcaire := _mat(Color(0.86, 0.82, 0.72), 0.95)
	var bloc := BoxMesh.new()
	bloc.size = Vector3(1.1, 0.7, 0.8)
	_piece(bloc, calcaire, Vector3(0, 0.35, 0))
	for k in 4:
		var spire := TorusMesh.new()
		spire.inner_radius = 0.16 - k * 0.02
		spire.outer_radius = 0.2 - k * 0.02
		_piece(spire, papyrus, Vector3(0.75, 0.03 + k * 0.035, 0.1))
	for x in [-0.3, 0.3]:
		var tour := BoxMesh.new()
		tour.size = Vector3(0.05, 0.72, 0.82)
		_piece(tour, papyrus, Vector3(x, 0.36, 0))


## Une outre de peau de chèvre, à moitié enfouie dans le sable.
func _construire_outre() -> void:
	var cuir := _mat(Color(0.42, 0.28, 0.17), 0.75)
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.4
	_piece(s, cuir, Vector3(0, 0.1, 0), Vector3(0, 0.4, 0.3), Vector3(1.3, 0.7, 0.9))
	var col := CylinderMesh.new()
	col.top_radius = 0.03
	col.bottom_radius = 0.05
	col.height = 0.14
	_piece(col, cuir, Vector3(0.27, 0.15, -0.1), Vector3(0, 0.4, -1.1))
	var lien := TorusMesh.new()
	lien.inner_radius = 0.03
	lien.outer_radius = 0.04
	_piece(lien, _mat(Color(0.85, 0.8, 0.68)), Vector3(0.31, 0.17, -0.12), Vector3(0, 0.4, -1.1 + PI / 2))
