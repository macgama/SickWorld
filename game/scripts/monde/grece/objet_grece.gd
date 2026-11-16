@tool
extends "res://scripts/monde/egypte/objet_egypte.gd"
## Objets de quête de l'île de Grèce (en plus de ceux de l'Égypte et de la Préhistoire) :
## - « sac_voyage » : le sac à dos de l'agent Markos, coincé entre deux rochers ;
## - « filet » : un filet de pêche emmêlé, avec ses flotteurs de liège ;
## - « amphore » : une amphore de terre cuite, debout ;
## - « masque » : un masque de théâtre blanc, posé dans l'herbe, avec un éclat violet.
## - « tablette » : une tablette de cire sur une borne (les réponses d’un interrogatoire).
## - « plaque_or » : des plaques d’or de la statue d’Athéna, sur un tréteau ;
## - « jeton » : un jeton de plomb des mines du Laurion ;
## - « ostraka » : des sacs de tessons gravés (le vote truqué) ;
## - « machine » : une pompe moderne de l’Effaceur, au fond des galeries.
## - « bouclier_poli » : un bouclier de bronze poli comme un miroir, sur son support (Acropole).
## Quêtes secondaires et événements :
## - « chouette » : une petite chevêche blessée dans l'herbe ; « insectes » : des cigales
##   sur une tige de fenouil ; « essaim » : un essaim d'abeilles pendu à une branche ;
## - « thym » : une touffe de thym en fleur ; « empreinte_sanglier » : des traces de sabots
##   et une vigne arrachée ; « olives » : un panier d'olives ; « pressoir » : un pressoir à huile ;
## - « poulain » : un jeune cheval rétif (le vrai modèle de cheval) ;
## - « megaphone », « affiche », « camera » : les objets modernes semés par les Effaceurs ;
## - « banquet » : un lit de banquet, sa petite table et la coupe du kottabos ;
## - « choeur » : la place du chœur sur l'orchestre (un cercle et des masques posés) ;
## - « cible_javelot » : une cible de paille sur un poteau ; « incendie » : un tas
##   d'amphores et de ballots en feu ; « eboulis » : des blocs tombés qui bouchent une galerie.

const ApparenceMonture := preload("res://scripts/joueur/apparence_monture.gd")
var _flammes: Array[MeshInstance3D] = []
var _lumiere_feu: OmniLight3D
var _poulain: Node3D
var _temps_objet := 0.0


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


## Une tablette de cire ouverte (deux planchettes de bois), posée sur une borne de pierre :
## c'est là qu'on choisit sa réponse pendant un interrogatoire à la Socrate.
func _construire_tablette() -> void:
	var pierre := StandardMaterial3D.new()
	pierre.albedo_color = Color(0.72, 0.69, 0.63)
	pierre.roughness = 0.9
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.45, 0.3, 0.18)
	bois.roughness = 0.8
	var cire := StandardMaterial3D.new()
	cire.albedo_color = Color(0.16, 0.12, 0.08)
	cire.roughness = 0.45
	var borne := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.2
	cyl.height = 0.8
	cyl.radial_segments = 10
	borne.mesh = cyl
	borne.material_override = pierre
	borne.position.y = 0.4
	_visuel.add_child(borne)
	for cote: float in [-1.0, 1.0]:
		var planche := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.2, 0.025, 0.28)
		planche.mesh = b
		planche.material_override = bois
		planche.position = Vector3(cote * 0.105, 0.82, 0)
		planche.rotation.z = cote * -0.12
		_visuel.add_child(planche)
		var creux := MeshInstance3D.new()
		var c := BoxMesh.new()
		c.size = Vector3(0.16, 0.01, 0.23)
		creux.mesh = c
		creux.material_override = cire
		creux.position = Vector3(0, 0.014, 0)
		planche.add_child(creux)


## Une plaque d'or de la robe d'Athéna, posée sur un tréteau (on les démonte pour les peser).
func _construire_plaque_or() -> void:
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.45, 0.32, 0.2)
	bois.roughness = 0.85
	var or_m := StandardMaterial3D.new()
	or_m.albedo_color = Color(1.0, 0.78, 0.32)
	or_m.metallic = 1.0
	or_m.roughness = 0.22
	var treteau := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.9, 0.7, 0.6)
	treteau.mesh = b
	treteau.material_override = bois
	treteau.position.y = 0.35
	_visuel.add_child(treteau)
	for k in 3:
		var plaque := MeshInstance3D.new()
		var p := BoxMesh.new()
		p.size = Vector3(0.62, 0.025, 0.4)
		plaque.mesh = p
		plaque.material_override = or_m
		plaque.position = Vector3(0.03 * k, 0.715 + k * 0.026, -0.02 * k)
		plaque.rotation.y = 0.08 * k
		_visuel.add_child(plaque)


## Un petit jeton de plomb gris, tombé au pied d'une stèle.
func _construire_jeton() -> void:
	var plomb := StandardMaterial3D.new()
	plomb.albedo_color = Color(0.42, 0.43, 0.45)
	plomb.metallic = 0.6
	plomb.roughness = 0.5
	var jeton := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.06
	c.height = 0.012
	c.radial_segments = 16
	jeton.mesh = c
	jeton.material_override = plomb
	jeton.position.y = 0.01
	_visuel.add_child(jeton)


func _mat_uni(couleur: Color, rugosite := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	return m


func _morceau(maillage: Mesh, materiau: Material, p: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = p
	mi.rotation = rot
	_visuel.add_child(mi)
	return mi


## Deux sacs de toile ouverts, pleins de tessons de poterie gravés d'un nom.
func _construire_ostraka() -> void:
	var toile := _mat_uni(Color(0.62, 0.55, 0.42), 0.95)
	var terre := _mat_uni(Color(0.72, 0.42, 0.26), 0.85)
	for k in 2:
		var sac := SphereMesh.new()
		sac.radius = 0.32
		sac.height = 0.7
		_morceau(sac, toile, Vector3(-0.3 + k * 0.6, 0.32, 0.05 * k), Vector3(0, k * 0.6, 0.1))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 438
	for k in 14:
		var tesson := BoxMesh.new()
		tesson.size = Vector3(hasard.randf_range(0.08, 0.14), 0.015, hasard.randf_range(0.06, 0.11))
		_morceau(tesson, terre, Vector3(hasard.randf_range(-0.6, 0.6), 0.02 + (0.62 if k < 6 else 0.0), hasard.randf_range(0.25, 0.6) * (1.0 if k >= 6 else 0.0)),
				Vector3(hasard.randf_range(-0.3, 0.3), hasard.randf() * TAU, hasard.randf_range(-0.3, 0.3)))


## Une machine de l'Effaceur : une pompe moderne, carrossée de gris, branchée sur des
## câbles noirs, un voyant rouge qui clignote et un éclat violet de faille dans le moteur.
func _construire_machine() -> void:
	var metal := _mat_uni(Color(0.32, 0.34, 0.36), 0.45, 0.8)
	var noir := _mat_uni(Color(0.04, 0.04, 0.045), 0.6)
	var corps := BoxMesh.new()
	corps.size = Vector3(1.1, 0.8, 0.7)
	_morceau(corps, metal, Vector3(0, 0.45, 0))
	var moteur := CylinderMesh.new()
	moteur.top_radius = 0.26
	moteur.bottom_radius = 0.26
	moteur.height = 0.9
	_morceau(moteur, metal, Vector3(0, 0.55, 0.0), Vector3(0, 0, PI / 2)).position.y = 1.0
	var tuyau := CylinderMesh.new()
	tuyau.top_radius = 0.07
	tuyau.bottom_radius = 0.07
	tuyau.height = 1.8
	_morceau(tuyau, noir, Vector3(-0.9, 0.12, 0.3), Vector3(0, 0.4, PI / 2))
	_morceau(tuyau, noir, Vector3(0.8, 0.12, -0.5), Vector3(0, -0.7, PI / 2))
	var voyant := SphereMesh.new()
	voyant.radius = 0.04
	voyant.height = 0.08
	var rouge := _mat_uni(Color(1.0, 0.1, 0.05))
	rouge.emission_enabled = true
	rouge.emission = Color(1.0, 0.1, 0.05)
	rouge.emission_energy_multiplier = 4.0
	_morceau(voyant, rouge, Vector3(0.35, 0.88, 0.36))
	var eclat := CylinderMesh.new()
	eclat.top_radius = 0.0
	eclat.bottom_radius = 0.08
	eclat.height = 0.42
	eclat.radial_segments = 5
	var violet := _mat_uni(Color(0.6, 0.3, 1.0))
	violet.emission_enabled = true
	violet.emission = Color(0.6, 0.3, 1.0)
	violet.emission_energy_multiplier = 3.0
	_morceau(eclat, violet, Vector3(0, 1.32, 0), Vector3(0.2, 0, 0.15))


func _construire_bouclier_poli() -> void:
	var bois := _mat_uni(Color(0.32, 0.22, 0.14), 0.85)
	var bronze := _mat_uni(Color(0.95, 0.74, 0.46), 0.15, 0.5)
	var pied := BoxMesh.new()
	pied.size = Vector3(0.12, 1.3, 0.12)
	_morceau(pied, bois, Vector3(0, 0.65, -0.12))
	var socle := BoxMesh.new()
	socle.size = Vector3(0.7, 0.08, 0.5)
	_morceau(socle, bois, Vector3(0, 0.04, 0))
	# Le disque de bronze, légèrement incliné, poli comme un miroir.
	var disque := CylinderMesh.new()
	disque.top_radius = 0.48
	disque.bottom_radius = 0.5
	disque.height = 0.06
	disque.radial_segments = 32
	_morceau(disque, bronze, Vector3(0, 1.05, 0), Vector3(PI / 2 - 0.15, 0, 0))
	var bord := TorusMesh.new()
	bord.inner_radius = 0.47
	bord.outer_radius = 0.53
	_morceau(bord, _mat_uni(Color(0.55, 0.36, 0.18), 0.4, 1.0), Vector3(0, 1.05, 0.01), Vector3(PI / 2 - 0.15, 0, 0))


# --- Quêtes secondaires et événements ---------------------------------------------------------

func _emissif(couleur: Color, force := 2.0) -> StandardMaterial3D:
	var m := _mat_uni(couleur, 0.4)
	m.emission_enabled = true
	m.emission = couleur
	m.emission_energy_multiplier = force
	return m


## Une petite chevêche (la chouette d'Athéna), tombée du nid : une boule de plumes brunes
## tachetées de blanc, de grands yeux jaunes, une aile qui pend.
func _construire_chouette() -> void:
	var plume := _mat_uni(Color(0.45, 0.34, 0.24), 1.0)
	var clair := _mat_uni(Color(0.82, 0.76, 0.66), 1.0)
	var jaune := _emissif(Color(1.0, 0.78, 0.2), 0.6)
	var noir := _mat_uni(Color(0.02, 0.02, 0.02), 0.3)
	var nid := TorusMesh.new()
	nid.inner_radius = 0.1
	nid.outer_radius = 0.22
	_morceau(nid, _mat_uni(Color(0.4, 0.33, 0.2), 1.0), Vector3(0, 0.03, 0))
	var corps := SphereMesh.new()
	corps.radius = 0.1
	corps.height = 0.24
	_morceau(corps, plume, Vector3(0, 0.14, 0))
	var ventre := SphereMesh.new()
	ventre.radius = 0.075
	ventre.height = 0.18
	_morceau(ventre, clair, Vector3(0, 0.13, -0.035))
	var tete := SphereMesh.new()
	tete.radius = 0.075
	tete.height = 0.14
	_morceau(tete, plume, Vector3(0, 0.29, 0))
	for c in [-1.0, 1.0]:
		var oeil := SphereMesh.new()
		oeil.radius = 0.022
		oeil.height = 0.04
		_morceau(oeil, jaune, Vector3(c * 0.03, 0.3, -0.063))
		var pupille := SphereMesh.new()
		pupille.radius = 0.01
		pupille.height = 0.02
		_morceau(pupille, noir, Vector3(c * 0.03, 0.3, -0.083))
	var bec := PrismMesh.new()
	bec.size = Vector3(0.02, 0.03, 0.02)
	_morceau(bec, _mat_uni(Color(0.75, 0.7, 0.5)), Vector3(0, 0.27, -0.075), Vector3(PI, 0, 0))
	# L'aile blessée, qui traîne par terre.
	var aile := BoxMesh.new()
	aile.size = Vector3(0.03, 0.08, 0.17)
	_morceau(aile, plume, Vector3(0.11, 0.07, 0.02), Vector3(0.2, 0, 0.9))


## Des cigales et des sauterelles sur une tige de fenouil sauvage.
func _construire_insectes() -> void:
	var tige := _mat_uni(Color(0.45, 0.55, 0.25), 0.9)
	var bete := _mat_uni(Color(0.36, 0.34, 0.2), 0.6)
	var aile := _mat_uni(Color(0.85, 0.9, 0.85, 0.45), 0.2)
	aile.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 3:
		var t := CylinderMesh.new()
		t.top_radius = 0.008
		t.bottom_radius = 0.015
		t.height = 0.9 - k * 0.15
		_morceau(t, tige, Vector3(k * 0.12 - 0.12, t.height * 0.5, k * 0.05), Vector3(0.1 * (k - 1), 0, 0.12 * (1 - k)))
		var fleur := SphereMesh.new()
		fleur.radius = 0.06
		fleur.height = 0.04
		_morceau(fleur, _mat_uni(Color(0.85, 0.75, 0.2)), Vector3(k * 0.12 - 0.12 + 0.12 * (1 - k) * -0.45, t.height, k * 0.05 + 0.04 * (k - 1)))
	for k in 4:
		var c := CapsuleMesh.new()
		c.radius = 0.015
		c.height = 0.06
		var y := 0.3 + k * 0.13
		var mi := _morceau(c, bete, Vector3(-0.1 + (k % 2) * 0.2, y, 0.02), Vector3(PI / 2, 0, 0))
		var a := BoxMesh.new()
		a.size = Vector3(0.05, 0.002, 0.05)
		var ai := MeshInstance3D.new()
		ai.mesh = a
		ai.material_override = aile
		ai.position = Vector3(0, 0, 0.02)
		mi.add_child(ai)


## Un essaim d'abeilles accroché sous une branche d'olivier, et le panier pour le recueillir.
func _construire_essaim() -> void:
	var bois := _mat_uni(Color(0.35, 0.28, 0.2), 0.95)
	var abeilles := _mat_uni(Color(0.42, 0.3, 0.08), 0.7)
	var piquet := CylinderMesh.new()
	piquet.top_radius = 0.04
	piquet.bottom_radius = 0.05
	piquet.height = 1.8
	_morceau(piquet, bois, Vector3(0.35, 0.9, 0))
	var branche := CylinderMesh.new()
	branche.top_radius = 0.025
	branche.bottom_radius = 0.035
	branche.height = 0.9
	_morceau(branche, bois, Vector3(0.0, 1.6, 0), Vector3(0, 0, PI / 2 - 0.15))
	var grappe := SphereMesh.new()
	grappe.radius = 0.17
	grappe.height = 0.46
	_morceau(grappe, abeilles, Vector3(-0.05, 1.35, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 14:
		var b := SphereMesh.new()
		b.radius = 0.012
		b.height = 0.02
		_morceau(b, abeilles, Vector3(hasard.randf_range(-0.5, 0.4), hasard.randf_range(0.9, 1.8), hasard.randf_range(-0.4, 0.4)))
	var panier := CylinderMesh.new()
	panier.top_radius = 0.22
	panier.bottom_radius = 0.16
	panier.height = 0.3
	_morceau(panier, _mat_uni(Color(0.66, 0.55, 0.34), 1.0), Vector3(-0.05, 0.15, 0.1))


## Une touffe de thym en fleur, mauve et gris-vert, sur la pente sèche de l'Hymette.
func _construire_thym() -> void:
	var vert := _mat_uni(Color(0.4, 0.45, 0.32), 1.0)
	var mauve := _mat_uni(Color(0.68, 0.52, 0.75), 0.9)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 7:
		var touffe := SphereMesh.new()
		touffe.radius = hasard.randf_range(0.12, 0.2)
		touffe.height = touffe.radius * 1.3
		var p := Vector3(hasard.randf_range(-0.25, 0.25), touffe.radius * 0.5, hasard.randf_range(-0.25, 0.25))
		_morceau(touffe, vert, p)
		var fleurs := SphereMesh.new()
		fleurs.radius = touffe.radius * 0.6
		fleurs.height = touffe.radius * 0.5
		_morceau(fleurs, mauve, p + Vector3(0, touffe.radius * 0.55, 0))


## Des traces de sabots fourchus dans la terre, des ceps de vigne arrachés.
func _construire_empreinte_sanglier() -> void:
	var terre := _mat_uni(Color(0.3, 0.22, 0.15), 1.0)
	for k in 5:
		for c in [-1.0, 1.0]:
			var sabot := BoxMesh.new()
			sabot.size = Vector3(0.035, 0.012, 0.08)
			_morceau(sabot, terre, Vector3(c * 0.025 + (k % 2) * 0.14 - 0.07, 0.006, -0.6 + k * 0.3), Vector3(0, c * 0.2, 0))
	var cep := _mat_uni(Color(0.32, 0.23, 0.15), 1.0)
	var feuille := _mat_uni(Color(0.35, 0.5, 0.2), 0.9)
	for k in 2:
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.04
		c.height = 0.6
		_morceau(c, cep, Vector3(0.35 - k * 0.7, 0.08, 0.2 * k), Vector3(PI / 2 - 0.15, k * 1.2, 0.2))
		var f := SphereMesh.new()
		f.radius = 0.14
		f.height = 0.1
		_morceau(f, feuille, Vector3(0.55 - k * 1.1, 0.06, 0.25 * k))
	var trou := CylinderMesh.new()
	trou.top_radius = 0.3
	trou.bottom_radius = 0.2
	trou.height = 0.02
	_morceau(trou, _mat_uni(Color(0.22, 0.16, 0.1), 1.0), Vector3(0, 0.005, 0.15))


## Un panier d'olives noires et vertes, sous un rameau.
func _construire_olives() -> void:
	var osier := _mat_uni(Color(0.6, 0.48, 0.28), 1.0)
	var noire := _mat_uni(Color(0.12, 0.1, 0.12), 0.35)
	var verte := _mat_uni(Color(0.42, 0.48, 0.18), 0.4)
	var panier := CylinderMesh.new()
	panier.top_radius = 0.26
	panier.bottom_radius = 0.2
	panier.height = 0.3
	_morceau(panier, osier, Vector3(0, 0.15, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 26:
		var o := SphereMesh.new()
		o.radius = 0.028
		o.height = 0.07
		var a := hasard.randf() * TAU
		var r := hasard.randf() * 0.2
		_morceau(o, noire if k % 3 else verte, Vector3(cos(a) * r, 0.3 + hasard.randf() * 0.04, sin(a) * r), Vector3(hasard.randf(), 0, hasard.randf()))
	var rameau := BoxMesh.new()
	rameau.size = Vector3(0.5, 0.01, 0.06)
	_morceau(rameau, _mat_uni(Color(0.45, 0.5, 0.38), 0.9), Vector3(0.1, 0.34, 0.05), Vector3(0, 0.5, 0.1))


## Un pressoir à huile : une grosse meule de pierre sur une cuve, et le levier de bois.
func _construire_pressoir() -> void:
	var pierre := _mat_uni(Color(0.66, 0.62, 0.55), 0.95)
	var bois := _mat_uni(Color(0.36, 0.26, 0.17), 0.9)
	var cuve := CylinderMesh.new()
	cuve.top_radius = 0.75
	cuve.bottom_radius = 0.8
	cuve.height = 0.55
	_morceau(cuve, pierre, Vector3(0, 0.27, 0))
	var meule := CylinderMesh.new()
	meule.top_radius = 0.42
	meule.bottom_radius = 0.42
	meule.height = 0.26
	_morceau(meule, pierre, Vector3(0, 0.85, 0), Vector3(0, 0, PI / 2))
	var axe := CylinderMesh.new()
	axe.top_radius = 0.05
	axe.bottom_radius = 0.05
	axe.height = 2.2
	_morceau(axe, bois, Vector3(0.4, 0.85, 0), Vector3(0, 0, PI / 2))
	var bec := BoxMesh.new()
	bec.size = Vector3(0.12, 0.08, 0.3)
	_morceau(bec, pierre, Vector3(0, 0.36, -0.85))
	var amphore := CylinderMesh.new()
	amphore.top_radius = 0.1
	amphore.bottom_radius = 0.16
	amphore.height = 0.5
	var mi := _morceau(amphore, _mat_uni(Color(0.7, 0.42, 0.25), 0.85), Vector3(0, 0.25, -1.15))
	mi.name = "Amphore"
	mi.visible = false


## Le poulain rétif de Lysimaque : le vrai cheval, en plus petit et à la robe baie.
func _construire_poulain() -> void:
	var fiche: Dictionary = {}
	var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/montures.json"))
	if lu is Dictionary:
		fiche = (lu.get("montures", {}) as Dictionary).get("cheval_attique", (lu.get("montures", {}) as Dictionary).get("cheval", {}))
	if fiche.is_empty() or not ResourceLoader.exists(String(fiche.get("modele", ""))):
		# Sans le modèle : une silhouette simple.
		var robe := _mat_uni(Color(0.45, 0.28, 0.16), 0.8)
		var corps := CapsuleMesh.new()
		corps.radius = 0.32
		corps.height = 1.4
		_morceau(corps, robe, Vector3(0, 1.0, 0), Vector3(PI / 2, 0, 0))
		return
	_poulain = ApparenceMonture.new()
	_poulain.reglages = fiche
	_poulain.scale = Vector3.ONE * 0.85
	_visuel.add_child(_poulain)


func _construire_megaphone() -> void:
	var blanc := _mat_uni(Color(0.92, 0.92, 0.9), 0.4)
	var rouge := _mat_uni(Color(0.85, 0.12, 0.1), 0.4)
	var pavillon := CylinderMesh.new()
	pavillon.top_radius = 0.05
	pavillon.bottom_radius = 0.16
	pavillon.height = 0.34
	_morceau(pavillon, blanc, Vector3(0, 0.17, 0), Vector3(PI / 2 - 0.2, 0, 0))
	var poignee := BoxMesh.new()
	poignee.size = Vector3(0.04, 0.12, 0.05)
	_morceau(poignee, _mat_uni(Color(0.1, 0.1, 0.1)), Vector3(0, 0.06, 0.12))
	var bande := TorusMesh.new()
	bande.inner_radius = 0.15
	bande.outer_radius = 0.17
	_morceau(bande, rouge, Vector3(0, 0.2, -0.16), Vector3(PI / 2 - 0.2, 0, 0))
	_morceau(_petite_diode(), _emissif(Color(0.2, 1.0, 0.3), 3.0), Vector3(0.03, 0.12, 0.13))


## Une affiche électorale moderne, collée de travers sur une colonne (une photo, un slogan).
func _construire_affiche() -> void:
	var colonne := CylinderMesh.new()
	colonne.top_radius = 0.24
	colonne.bottom_radius = 0.26
	colonne.height = 2.4
	_morceau(colonne, _mat_uni(Color(0.88, 0.85, 0.78), 0.8), Vector3(0, 1.2, 0.3))
	var papier := BoxMesh.new()
	papier.size = Vector3(0.45, 0.62, 0.01)
	_morceau(papier, _mat_uni(Color(0.95, 0.95, 0.97), 0.6), Vector3(0, 1.35, 0.04), Vector3(0, 0, 0.06))
	var bandeau := BoxMesh.new()
	bandeau.size = Vector3(0.45, 0.14, 0.012)
	_morceau(bandeau, _mat_uni(Color(0.1, 0.25, 0.7), 0.5), Vector3(0, 1.12, 0.035), Vector3(0, 0, 0.06))
	var visage := BoxMesh.new()
	visage.size = Vector3(0.22, 0.26, 0.012)
	_morceau(visage, _mat_uni(Color(0.75, 0.6, 0.5), 0.5), Vector3(0.02, 1.43, 0.034), Vector3(0, 0, 0.06))
	var texte := Label3D.new()
	texte.text = "VOTEZ\nPOUR MOI"
	texte.font_size = 40
	texte.pixel_size = 0.0022
	texte.modulate = Color.WHITE
	texte.outline_size = 0
	texte.position = Vector3(0.0, 1.12, 0.045)
	texte.rotation.z = 0.06
	_visuel.add_child(texte)


## Une petite caméra de surveillance, sur une patte de fixation, avec sa diode rouge.
func _construire_camera() -> void:
	var gris := _mat_uni(Color(0.85, 0.86, 0.88), 0.35, 0.3)
	var poteau := CylinderMesh.new()
	poteau.top_radius = 0.03
	poteau.bottom_radius = 0.04
	poteau.height = 1.5
	_morceau(poteau, _mat_uni(Color(0.4, 0.32, 0.22), 0.9), Vector3(0, 0.75, 0))
	var boitier := BoxMesh.new()
	boitier.size = Vector3(0.12, 0.11, 0.3)
	_morceau(boitier, gris, Vector3(0, 1.55, -0.1), Vector3(-0.3, 0, 0))
	var objectif := CylinderMesh.new()
	objectif.top_radius = 0.035
	objectif.bottom_radius = 0.035
	objectif.height = 0.03
	_morceau(objectif, _mat_uni(Color(0.05, 0.05, 0.08), 0.1), Vector3(0, 1.5, -0.26), Vector3(PI / 2 - 0.3, 0, 0))
	_morceau(_petite_diode(), _emissif(Color(1.0, 0.1, 0.05), 4.0), Vector3(0.04, 1.6, -0.24))


func _petite_diode() -> SphereMesh:
	var d := SphereMesh.new()
	d.radius = 0.012
	d.height = 0.024
	return d


## Le banquet chez Aspasie : un lit de banquet (klinê), sa petite table, un cratère de vin
## et la coupe plate (le kylix) pour le kottabos ; le support de bronze et son disque.
func _construire_banquet() -> void:
	var bois := _mat_uni(Color(0.4, 0.26, 0.16), 0.7)
	var tissu := _mat_uni(Color(0.55, 0.14, 0.12), 0.95)
	var terre := _mat_uni(Color(0.75, 0.42, 0.22), 0.6)
	var noir := _mat_uni(Color(0.08, 0.06, 0.05), 0.5)
	var bronze := _mat_uni(Color(0.75, 0.55, 0.3), 0.35, 0.5)
	var lit := BoxMesh.new()
	lit.size = Vector3(2.0, 0.14, 0.85)
	_morceau(lit, bois, Vector3(0, 0.55, 0.9))
	var matelas := BoxMesh.new()
	matelas.size = Vector3(1.95, 0.12, 0.8)
	_morceau(matelas, tissu, Vector3(0, 0.68, 0.9))
	for c in [Vector2(-0.9, 0.55), Vector2(0.9, 0.55), Vector2(-0.9, 1.25), Vector2(0.9, 1.25)]:
		var pied := BoxMesh.new()
		pied.size = Vector3(0.08, 0.5, 0.08)
		_morceau(pied, bois, Vector3(c.x, 0.25, c.y))
	var table := BoxMesh.new()
	table.size = Vector3(0.9, 0.05, 0.5)
	_morceau(table, bois, Vector3(0, 0.45, 0.1))
	var crat := CylinderMesh.new()
	crat.top_radius = 0.22
	crat.bottom_radius = 0.12
	crat.height = 0.42
	_morceau(crat, terre, Vector3(-0.9, 0.21, -0.3))
	var coupe := CylinderMesh.new()
	coupe.top_radius = 0.13
	coupe.bottom_radius = 0.04
	coupe.height = 0.05
	_morceau(coupe, noir, Vector3(0.2, 0.5, 0.1))
	# Le kottabos : une tige de bronze, un petit plateau à mi-hauteur, un disque au sommet.
	var tige := CylinderMesh.new()
	tige.top_radius = 0.015
	tige.bottom_radius = 0.03
	tige.height = 1.6
	_morceau(tige, bronze, Vector3(0, 0.8, -1.4))
	var plateau := CylinderMesh.new()
	plateau.top_radius = 0.22
	plateau.bottom_radius = 0.22
	plateau.height = 0.02
	_morceau(plateau, bronze, Vector3(0, 0.9, -1.4))
	var disque := CylinderMesh.new()
	disque.top_radius = 0.07
	disque.bottom_radius = 0.07
	disque.height = 0.015
	_morceau(disque, bronze, Vector3(0, 1.61, -1.4))
	var socle := CylinderMesh.new()
	socle.top_radius = 0.12
	socle.bottom_radius = 0.18
	socle.height = 0.06
	_morceau(socle, bronze, Vector3(0, 0.03, -1.4))


## La place du chœur, au milieu de l'orchestre : un cercle tracé, l'autel de Dionysos
## (la thymélè) et des masques de choreutes posés au sol.
func _construire_choeur() -> void:
	var cercle := TorusMesh.new()
	cercle.inner_radius = 1.9
	cercle.outer_radius = 2.0
	var trace := _mat_uni(Color(0.85, 0.8, 0.68), 1.0)
	_morceau(cercle, trace, Vector3(0, 0.01, 0)).scale = Vector3(1, 0.05, 1)
	var autel := CylinderMesh.new()
	autel.top_radius = 0.3
	autel.bottom_radius = 0.34
	autel.height = 0.7
	_morceau(autel, _mat_uni(Color(0.86, 0.83, 0.76), 0.8), Vector3(0, 0.35, 0))
	var blanc := _mat_uni(Color(0.95, 0.93, 0.88), 0.6)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var masque := SphereMesh.new()
		masque.radius = 0.12
		masque.height = 0.16
		_morceau(masque, blanc, Vector3(cos(a) * 1.4, 0.05, sin(a) * 1.4), Vector3(-PI / 2 + 0.2, a, 0)).scale = Vector3(1, 1, 0.35)


## Une cible de paille tressée, sur un poteau, au bout du terrain de lancer.
func _construire_cible_javelot() -> void:
	var bois := _mat_uni(Color(0.4, 0.3, 0.2), 0.9)
	var paille := _mat_uni(Color(0.82, 0.7, 0.38), 1.0)
	var rouge := _mat_uni(Color(0.65, 0.15, 0.1), 0.9)
	for c in [-0.5, 0.5]:
		var pied := CylinderMesh.new()
		pied.top_radius = 0.05
		pied.bottom_radius = 0.06
		pied.height = 1.8
		_morceau(pied, bois, Vector3(c, 0.9, 0.08))
	var cible := CylinderMesh.new()
	cible.top_radius = 0.6
	cible.bottom_radius = 0.6
	cible.height = 0.2
	_morceau(cible, paille, Vector3(0, 1.3, 0), Vector3(PI / 2, 0, 0))
	for k in 2:
		var anneau := TorusMesh.new()
		anneau.inner_radius = 0.36 - k * 0.22
		anneau.outer_radius = 0.42 - k * 0.22
		_morceau(anneau, rouge, Vector3(0, 1.3, -0.1), Vector3(PI / 2, 0, 0)).scale = Vector3(1, 0.2, 1)
	# Quelques javelots de bois plantés à côté.
	for k in 3:
		var j := CylinderMesh.new()
		j.top_radius = 0.012
		j.bottom_radius = 0.015
		j.height = 2.2
		_morceau(j, bois, Vector3(1.1 + k * 0.15, 1.0, 0.3 - k * 0.2), Vector3(0.15, 0, 0.2 - k * 0.1))


## Un tas d'amphores et de ballots qui brûle sur le quai (allumé par les pirates).
func _construire_incendie() -> void:
	var terre := _mat_uni(Color(0.68, 0.4, 0.24), 0.85)
	var toile := _mat_uni(Color(0.52, 0.45, 0.34), 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 6:
		var a := CylinderMesh.new()
		a.top_radius = 0.08
		a.bottom_radius = 0.17
		a.height = 0.7
		_morceau(a, terre, Vector3(hasard.randf_range(-0.6, 0.6), 0.35, hasard.randf_range(-0.5, 0.5)), Vector3(0, 0, hasard.randf_range(-0.3, 0.3)))
	for k in 3:
		var b := BoxMesh.new()
		b.size = Vector3(0.6, 0.4, 0.45)
		_morceau(b, toile, Vector3(hasard.randf_range(-0.7, 0.7), 0.2, hasard.randf_range(-0.6, 0.6)), Vector3(0, hasard.randf() * TAU, 0))
	var feu := _emissif(Color(1.0, 0.5, 0.12), 4.0)
	feu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	feu.albedo_color.a = 0.8
	feu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flammes.clear()
	for k in 5:
		var f := CylinderMesh.new()
		f.top_radius = 0.0
		f.bottom_radius = 0.22
		f.height = 1.1
		f.radial_segments = 6
		_flammes.append(_morceau(f, feu, Vector3(hasard.randf_range(-0.5, 0.5), 0.9, hasard.randf_range(-0.4, 0.4))))
	_lumiere_feu = OmniLight3D.new()
	_lumiere_feu.light_color = Color(1.0, 0.55, 0.2)
	_lumiere_feu.light_energy = 2.5
	_lumiere_feu.omni_range = 7.0
	_lumiere_feu.position.y = 1.2
	_visuel.add_child(_lumiere_feu)


## Des blocs de roche tombés du plafond, qui bouchent l'entrée d'une galerie.
func _construire_eboulis() -> void:
	var roche := _mat_uni(Color(0.42, 0.4, 0.38), 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 7:
		var b := BoxMesh.new()
		b.size = Vector3(hasard.randf_range(0.4, 0.9), hasard.randf_range(0.3, 0.6), hasard.randf_range(0.4, 0.8))
		_morceau(b, roche, Vector3(hasard.randf_range(-0.6, 0.6), b.size.y * 0.5 + (0.35 if k > 4 else 0.0), hasard.randf_range(-0.4, 0.4)),
				Vector3(hasard.randf_range(-0.3, 0.3), hasard.randf() * TAU, hasard.randf_range(-0.3, 0.3)))
	var poutre := BoxMesh.new()
	poutre.size = Vector3(1.8, 0.14, 0.14)
	_morceau(poutre, _mat_uni(Color(0.3, 0.22, 0.14), 0.9), Vector3(0, 0.55, 0.1), Vector3(0, 0.4, 0.35))


## Ce que change une étape faite (voir quetes_secondaires.gd et evenements_publics.gd).
func appliquer_effet(effet: String) -> void:
	match effet:
		"eteindre":
			for f in _flammes:
				f.visible = false
			if _lumiere_feu != null:
				_lumiere_feu.visible = false
		"huile":
			var amphore := _visuel.get_node_or_null("Amphore") if _visuel != null else null
			if amphore != null:
				amphore.visible = true
		"dresse":
			# Le poulain s'est calmé : il ne recule plus, et sa tête se baisse.
			if _poulain != null:
				_poulain.rotation.y = PI * 0.15
		_:
			super.appliquer_effet(effet)


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	_temps_objet += delta
	if not _flammes.is_empty() and is_instance_valid(_flammes[0]) and _flammes[0].visible:
		for k in _flammes.size():
			var f := _flammes[k]
			var s := 0.8 + 0.3 * sin(_temps_objet * (7.0 + k) + k * 1.7)
			f.scale = Vector3(1.0, s, 1.0)
		if _lumiere_feu != null and is_instance_valid(_lumiere_feu):
			_lumiere_feu.light_energy = 2.2 + 0.6 * sin(_temps_objet * 11.0)
	if _poulain != null and is_instance_valid(_poulain) and _poulain.has_method("animer"):
		_poulain.animer(delta, Vector3.ZERO, true)
