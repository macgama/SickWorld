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


## Une vanne de la citerne (chapitre 8) : une porte de bois épais qui glisse dans deux
## rainures de pierre, et la grande roue de fer qui la lève.
func _construire_vanne() -> void:
	var bois := _mat_uni(Color(0.32, 0.22, 0.13), 0.85)
	var pierre := _mat_uni(Color(0.6, 0.56, 0.46), 0.95)
	var fer := _mat_uni(Color(0.16, 0.13, 0.11), 0.5, 0.6)
	for x: float in [-1.1, 1.1]:
		var montant := BoxMesh.new()
		montant.size = Vector3(0.3, 3.0, 0.4)
		_morceau(montant, pierre, Vector3(x, 1.5, -0.3))
	var porte := BoxMesh.new()
	porte.size = Vector3(1.9, 2.2, 0.16)
	_morceau(porte, bois, Vector3(0, 1.1, -0.3))
	var roue := TorusMesh.new()
	roue.inner_radius = 0.42
	roue.outer_radius = 0.5
	_morceau(roue, fer, Vector3(0, 1.2, 0.15), Vector3(PI * 0.5, 0, 0))
	for k in 4:
		var rayon := BoxMesh.new()
		rayon.size = Vector3(0.9, 0.05, 0.05)
		_morceau(rayon, fer, Vector3(0, 1.2, 0.15), Vector3(0, 0, k * PI * 0.25))
	var axe := CylinderMesh.new()
	axe.top_radius = 0.06
	axe.bottom_radius = 0.06
	axe.height = 0.5
	_morceau(axe, fer, Vector3(0, 1.2, -0.05), Vector3(PI * 0.5, 0, 0))
	# Une fois la vanne fermée, la porte et la roue restent là (sans l'invite ni le halo).
	_debout = Node3D.new()
	_debout.name = "Fermee"
	_debout.visible = false
	add_child(_debout)
	for morceau in _visuel.get_children():
		if morceau is MeshInstance3D:
			_debout.add_child(morceau.duplicate())


# --- Quêtes secondaires et événements de Rome ----------------------------------------------

## Une oie sacrée de Junon échappée de l'enclos : blanche, le cou tendu, qui cacarde.
func _construire_oie() -> void:
	var blanc := _mat_uni(Color(0.95, 0.94, 0.9), 0.8)
	var orange := _mat_uni(Color(0.95, 0.55, 0.15), 0.6)
	var corps := SphereMesh.new()
	corps.radius = 0.24
	corps.height = 0.4
	_morceau(corps, blanc, Vector3(0, 0.34, 0)).scale = Vector3(1.0, 1.0, 1.5)
	var cou := CylinderMesh.new()
	cou.top_radius = 0.045
	cou.bottom_radius = 0.07
	cou.height = 0.42
	_morceau(cou, blanc, Vector3(0, 0.6, -0.26), Vector3(-0.35, 0, 0))
	var tete := SphereMesh.new()
	tete.radius = 0.08
	tete.height = 0.15
	_morceau(tete, blanc, Vector3(0, 0.82, -0.36))
	var bec := CylinderMesh.new()
	bec.top_radius = 0.0
	bec.bottom_radius = 0.035
	bec.height = 0.13
	_morceau(bec, orange, Vector3(0, 0.81, -0.48), Vector3(-PI * 0.5, 0, 0))
	for x: float in [-0.09, 0.09]:
		var patte := CylinderMesh.new()
		patte.top_radius = 0.018
		patte.bottom_radius = 0.018
		patte.height = 0.2
		_morceau(patte, orange, Vector3(x, 0.1, 0.02))


## Un graffiti tracé au charbon et à la pointe sur un pan de mur enduit de la Subure
## (on en a retrouvé des milliers à Pompéi). Une lueur violette : il a été « corrigé ».
func _construire_graffiti() -> void:
	var enduit := _mat_uni(Color(0.82, 0.74, 0.6), 0.95)
	var pan := BoxMesh.new()
	pan.size = Vector3(1.6, 1.3, 0.12)
	_morceau(pan, enduit, Vector3(0, 0.95, 0))
	var rouge := BoxMesh.new()
	rouge.size = Vector3(1.6, 0.3, 0.13)
	_morceau(rouge, _mat_uni(Color(0.55, 0.14, 0.1), 0.9), Vector3(0, 0.15, 0))
	var textes := ["CELADVS\nSVSPIRIVM\nPVELLARVM", "TITVS\nAMOR\nGENERIS\nHVMANI", "VIVAT\nLVDVS\nMAGNVS", "MARTIALIS\nHIC\nFVIT", "AVE\nCAESAR", "PANEM\nET\nCIRCENSES"]
	var texte := Label3D.new()
	texte.text = textes[absi(hash(identifiant)) % textes.size()]
	texte.font_size = 60
	texte.pixel_size = 0.0035
	texte.modulate = Color(0.12, 0.1, 0.09)
	texte.outline_size = 0
	texte.shaded = true
	texte.position = Vector3(0, 1.0, 0.065)
	_visuel.add_child(texte)
	var rature := BoxMesh.new()
	rature.size = Vector3(1.1, 0.06, 0.01)
	_morceau(rature, _emissif(Color(0.62, 0.3, 1.0), 2.5), Vector3(0, 1.0, 0.075), Vector3(0, 0, 0.25)).name = "Rature"


## La chaudière de bronze des thermes, sur son foyer de briques (l'hypocauste). Éteinte et
## froide tant qu'on ne l'a pas rallumée (effet « allumer »).
func _construire_chaudiere() -> void:
	var brique := _mat_uni(Color(0.6, 0.32, 0.2), 0.95)
	var bronze := _mat_uni(Color(0.55, 0.38, 0.2), 0.45, 0.7)
	var foyer := BoxMesh.new()
	foyer.size = Vector3(1.5, 0.8, 1.5)
	_morceau(foyer, brique, Vector3(0, 0.4, 0))
	var bouche := BoxMesh.new()
	bouche.size = Vector3(0.6, 0.45, 0.05)
	_morceau(bouche, _mat_uni(Color(0.05, 0.04, 0.04), 1.0), Vector3(0, 0.3, 0.76))
	var cuve := CylinderMesh.new()
	cuve.top_radius = 0.5
	cuve.bottom_radius = 0.6
	cuve.height = 1.1
	_morceau(cuve, bronze, Vector3(0, 1.35, 0))
	var couvercle := SphereMesh.new()
	couvercle.radius = 0.5
	couvercle.height = 0.5
	_morceau(couvercle, bronze, Vector3(0, 1.9, 0))
	var tuyau := CylinderMesh.new()
	tuyau.top_radius = 0.07
	tuyau.bottom_radius = 0.07
	tuyau.height = 1.4
	_morceau(tuyau, bronze, Vector3(0.75, 1.5, 0), Vector3(0, 0, PI * 0.5))
	_debout = Node3D.new()
	_debout.name = "Allumee"
	_debout.visible = false
	add_child(_debout)
	var braises := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.35, 0.04)
	braises.mesh = b
	braises.material_override = _emissif(Color(1.0, 0.45, 0.12), 5.0)
	braises.position = Vector3(0, 0.3, 0.77)
	_debout.add_child(braises)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.55, 0.25)
	lueur.light_energy = 2.0
	lueur.omni_range = 5.0
	lueur.position = Vector3(0, 0.5, 1.2)
	_debout.add_child(lueur)
	var vapeur := CPUParticles3D.new()
	vapeur.amount = 14
	vapeur.lifetime = 3.0
	vapeur.position = Vector3(0, 2.2, 0)
	vapeur.direction = Vector3.UP
	vapeur.spread = 15.0
	vapeur.gravity = Vector3(0, 0.5, 0)
	vapeur.initial_velocity_min = 0.3
	vapeur.initial_velocity_max = 0.6
	var boule := SphereMesh.new()
	boule.radius = 0.18
	boule.height = 0.3
	var blanc := StandardMaterial3D.new()
	blanc.albedo_color = Color(0.95, 0.95, 0.95, 0.4)
	blanc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blanc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boule.material = blanc
	vapeur.mesh = boule
	_debout.add_child(vapeur)


## Une pile de bûches de chêne, pour le foyer des thermes.
func _construire_bois() -> void:
	var ecorce := _mat_uni(Color(0.3, 0.22, 0.15), 0.95)
	var coeur := _mat_uni(Color(0.7, 0.55, 0.36), 0.9)
	for k in 5:
		var buche := CylinderMesh.new()
		buche.top_radius = 0.09
		buche.bottom_radius = 0.1
		buche.height = 0.9
		var x := -0.2 + (k % 3) * 0.2 + (0.1 if k >= 3 else 0.0)
		var y := 0.1 + (0.18 if k >= 3 else 0.0)
		_morceau(buche, ecorce, Vector3(x, y, 0), Vector3(PI * 0.5, 0, 0))
		var bout := CylinderMesh.new()
		bout.top_radius = 0.085
		bout.bottom_radius = 0.085
		bout.height = 0.01
		_morceau(bout, coeur, Vector3(x, y, 0.455), Vector3(PI * 0.5, 0, 0))


## Le chien de garde de Fausta, un molosse noir et feu, couché, le collier encore au cou.
func _construire_chien() -> void:
	var poil := _mat_uni(Color(0.12, 0.1, 0.08), 0.9)
	var feu := _mat_uni(Color(0.55, 0.32, 0.15), 0.9)
	var corps := CapsuleMesh.new()
	corps.radius = 0.2
	corps.height = 0.85
	_morceau(corps, poil, Vector3(0, 0.22, 0), Vector3(PI * 0.5, 0, 0))
	var tete := SphereMesh.new()
	tete.radius = 0.14
	tete.height = 0.24
	_morceau(tete, poil, Vector3(0, 0.3, -0.5))
	var museau := BoxMesh.new()
	museau.size = Vector3(0.12, 0.1, 0.16)
	_morceau(museau, feu, Vector3(0, 0.26, -0.64))
	for x: float in [-0.08, 0.08]:
		var oreille := BoxMesh.new()
		oreille.size = Vector3(0.05, 0.12, 0.08)
		_morceau(oreille, poil, Vector3(x, 0.4, -0.46), Vector3(0, 0, x * 3.0))
	var collier := TorusMesh.new()
	collier.inner_radius = 0.12
	collier.outer_radius = 0.15
	_morceau(collier, _mat_uni(Color(0.45, 0.3, 0.12), 0.5, 0.5), Vector3(0, 0.28, -0.36), Vector3(PI * 0.4, 0, 0))
	var queue := CylinderMesh.new()
	queue.top_radius = 0.015
	queue.bottom_radius = 0.035
	queue.height = 0.35
	_morceau(queue, poil, Vector3(0, 0.2, 0.55), Vector3(1.2, 0, 0))


## La mosaïque « CAVE CANEM » du seuil de la maison de Fausta, sous une couche de cendre.
func _construire_mosaique() -> void:
	var fond := BoxMesh.new()
	fond.size = Vector3(1.4, 0.04, 1.0)
	_morceau(fond, _mat_uni(Color(0.9, 0.87, 0.8), 0.7), Vector3(0, 0.02, 0))
	var cadre := BoxMesh.new()
	cadre.size = Vector3(1.5, 0.03, 1.1)
	_morceau(cadre, _mat_uni(Color(0.15, 0.13, 0.12), 0.8), Vector3(0, 0.015, 0))
	var chien := Label3D.new()
	chien.text = "CAVE CANEM"
	chien.font_size = 80
	chien.pixel_size = 0.003
	chien.modulate = Color(0.1, 0.09, 0.08)
	chien.outline_size = 0
	chien.shaded = true
	chien.position = Vector3(0, 0.045, 0.32)
	chien.rotation = Vector3(-PI * 0.5, 0, 0)
	_visuel.add_child(chien)
	var cendre := CylinderMesh.new()
	cendre.top_radius = 0.35
	cendre.bottom_radius = 0.5
	cendre.height = 0.08
	_morceau(cendre, _mat_uni(Color(0.45, 0.43, 0.41), 1.0), Vector3(0.3, 0.06, -0.1)).name = "Cendre"


## Un extincteur rouge, moderne, posé contre une colonne : un intrus de plus.
func _construire_extincteur() -> void:
	var rouge := _mat_uni(Color(0.8, 0.08, 0.06), 0.35, 0.3)
	var corps := CylinderMesh.new()
	corps.top_radius = 0.09
	corps.bottom_radius = 0.09
	corps.height = 0.55
	_morceau(corps, rouge, Vector3(0, 0.28, 0))
	var tete := CylinderMesh.new()
	tete.top_radius = 0.03
	tete.bottom_radius = 0.06
	tete.height = 0.1
	_morceau(tete, _mat_uni(Color(0.15, 0.15, 0.15), 0.4, 0.8), Vector3(0, 0.6, 0))
	var tuyau := CylinderMesh.new()
	tuyau.top_radius = 0.012
	tuyau.bottom_radius = 0.012
	tuyau.height = 0.4
	_morceau(tuyau, _mat_uni(Color(0.08, 0.08, 0.08), 0.6), Vector3(0.1, 0.42, 0), Vector3(0, 0, 0.3))
	_trace_violette()


## Un GPS de randonnée oublié, jaune, l'écran qui clignote « Signal perdu ».
func _construire_gps() -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.07, 0.03, 0.14)
	_morceau(b, _mat_uni(Color(0.95, 0.75, 0.1), 0.5), Vector3(0, 0.02, 0), Vector3(0, 0.7, 0))
	var ecran := BoxMesh.new()
	ecran.size = Vector3(0.05, 0.005, 0.06)
	_morceau(ecran, _emissif(Color(0.4, 0.8, 0.5), 2.0), Vector3(0, 0.037, 0), Vector3(0, 0.7, 0))
	_trace_violette()


## Une meule de fromage de brebis (pecorino) dans sa faisselle d'osier.
func _construire_fromage() -> void:
	var osier := _mat_uni(Color(0.6, 0.48, 0.28), 1.0)
	var panier := CylinderMesh.new()
	panier.top_radius = 0.26
	panier.bottom_radius = 0.22
	panier.height = 0.12
	_morceau(panier, osier, Vector3(0, 0.06, 0))
	var meule := CylinderMesh.new()
	meule.top_radius = 0.2
	meule.bottom_radius = 0.21
	meule.height = 0.14
	_morceau(meule, _mat_uni(Color(0.93, 0.88, 0.7), 0.7), Vector3(0, 0.19, 0))


## Un rameau de laurier, l'arbre d'Apollon, encore sur sa branche.
func _construire_laurier() -> void:
	var feuille := _mat_uni(Color(0.2, 0.36, 0.16), 0.7)
	var tige := CylinderMesh.new()
	tige.top_radius = 0.01
	tige.bottom_radius = 0.025
	tige.height = 0.8
	_morceau(tige, _mat_uni(Color(0.35, 0.25, 0.15), 0.9), Vector3(0, 0.4, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 14:
		var f := SphereMesh.new()
		f.radius = 0.06
		f.height = 0.03
		var y := 0.25 + k * 0.04
		_morceau(f, feuille, Vector3(cos(k * 2.3) * 0.1, y, sin(k * 2.3) * 0.1), Vector3(hasard.randf(), k * 2.3, 0.6)).scale = Vector3(1.0, 1.0, 2.0)


## Un panneau routier moderne planté de travers dans la voie romaine (Carrefour fou).
func _construire_panneau() -> void:
	var metal := _mat_uni(Color(0.6, 0.62, 0.62), 0.4, 0.7)
	var penche := Node3D.new()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	penche.rotation = Vector3(hasard.randf_range(-0.35, 0.35), hasard.randf() * TAU, hasard.randf_range(-0.35, 0.35))
	_visuel.add_child(penche)
	var mat := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.035
	c.bottom_radius = 0.035
	c.height = 2.2
	mat.mesh = c
	mat.material_override = metal
	mat.position.y = 1.1
	penche.add_child(mat)
	var couleurs := [Color(0.85, 0.08, 0.08), Color(0.1, 0.3, 0.8), Color(0.95, 0.75, 0.1)]
	var plaque := MeshInstance3D.new()
	var p := CylinderMesh.new()
	p.top_radius = 0.35
	p.bottom_radius = 0.35
	p.height = 0.03
	p.radial_segments = [20, 8, 3][absi(hash(identifiant)) % 3]
	plaque.mesh = p
	plaque.material_override = _mat_uni(couleurs[absi(hash(identifiant)) % 3], 0.5)
	plaque.position = Vector3(0, 2.0, 0.05)
	plaque.rotation.x = PI * 0.5
	penche.add_child(plaque)
	var barre := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.42, 0.09, 0.035)
	barre.mesh = b
	barre.material_override = _mat_uni(Color(0.95, 0.95, 0.95), 0.5)
	barre.position = Vector3(0, 2.0, 0.08)
	penche.add_child(barre)
	_trace_violette()


## Un habitant de Pompéi pris dans les cendres : accroupi, la tête dans son manteau.
func _construire_refugie() -> void:
	var manteau := _mat_uni(Color(0.55, 0.47, 0.38), 1.0)
	var corps := SphereMesh.new()
	corps.radius = 0.38
	corps.height = 0.8
	_morceau(corps, manteau, Vector3(0, 0.38, 0)).scale = Vector3(1.0, 1.0, 0.85)
	var tete := SphereMesh.new()
	tete.radius = 0.15
	tete.height = 0.28
	_morceau(tete, manteau, Vector3(0, 0.78, -0.08))
	var bras := CapsuleMesh.new()
	bras.radius = 0.06
	bras.height = 0.4
	_morceau(bras, _mat_uni(Color(0.75, 0.55, 0.42), 0.8), Vector3(0, 0.6, -0.3), Vector3(0, 0, PI * 0.5))
	var cendre := CylinderMesh.new()
	cendre.top_radius = 0.5
	cendre.bottom_radius = 0.7
	cendre.height = 0.08
	_morceau(cendre, _mat_uni(Color(0.4, 0.39, 0.38), 1.0), Vector3(0, 0.04, 0))


## Rome : la chaudière qu'on rallume ; le reste comme en Grèce.
func appliquer_effet(effet: String) -> void:
	if effet == "allumer" and forme == "chaudiere" and _debout != null:
		_debout.visible = true
		return
	super.appliquer_effet(effet)
