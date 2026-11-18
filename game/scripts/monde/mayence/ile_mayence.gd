@tool
extends "res://scripts/monde/moyen_age/ile_moyen_age.gd"
## Base commune des zones de l'île de Mayence (1450-1454, l'atelier de Gutenberg) : les vignes
## du Rheingau, le Rhin et le moulin à papier, Mayence, la foire de Francfort, la fonderie…
##
## On garde tout ce que sait faire le Moyen Âge (pans de bois, torchis, églises, haies,
## arbres réalistes) et on y ajoute la Rhénanie du XVe siècle : les maisons à colombages sur
## un rez-de-chaussée de pierre et leur étage en encorbellement, les toits d'ardoise très
## pentus, le grès rouge des églises du Rhin, le schiste des murets de vigne, les rangs de
## vigne sur leurs échalas, le pressoir à vis des vignerons (celui dont Gutenberg a tiré
## sa presse), le Rhin et ses bateaux.

## Le grès rouge du Main et du Rhin (la cathédrale de Mayence, les églises).
const GRES_ROUGE := Color(0.72, 0.42, 0.34)
## Le schiste gris-brun du Rheingau (murets des terrasses, soubassements).
const SCHISTE := Color(0.5, 0.47, 0.43)
## L'ardoise bleu-gris des toits.
const ARDOISE := Color(0.3, 0.32, 0.37)
## Le feuillage des vignes en octobre : vert, jaune, et quelques rouges.
const RAISIN_NOIR := Color(0.2, 0.08, 0.22)
const RAISIN_BLANC := Color(0.66, 0.7, 0.32)

# --- Matériaux ---------------------------------------------------------------------------------

## Le grès rouge, taillé en blocs réguliers.
func _mat_gres_rouge() -> StandardMaterial3D:
	var cle := "gres_rouge"
	if not _materiaux.has(cle):
		var m := _mat_choix(["large_sandstone_blocks", "sandstone_blocks_08", "old_stone_wall"], GRES_ROUGE, 0.9, 2.4).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Le schiste des murets : des plaquettes empilées à sec.
func _mat_schiste() -> StandardMaterial3D:
	var cle := "schiste"
	if not _materiaux.has(cle):
		var m := _mat_choix(["stacked_stone_wall", "old_stone_wall", "rock_wall_10"], SCHISTE, 0.92, 1.6).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## L'ardoise des toits (des écailles de pierre bleu-gris, un peu brillantes).
func _mat_ardoise() -> StandardMaterial3D:
	var cle := "ardoise"
	if not _materiaux.has(cle):
		var m := _mat_choix(["clay_roof_tiles_02", "stacked_stone_wall"], ARDOISE, 0.55, 0.9).duplicate()
		m.albedo_color = ARDOISE * Color(1.1, 1.1, 1.15)
		_materiaux[cle] = m
	return _materiaux[cle]


## Le crépi ocre ou rose de certaines maisons (pas tout blanc : les couleurs vives du Rhin).
func _mat_crepi(couleur: Color) -> StandardMaterial3D:
	var cle := "crepi_%s" % couleur.to_html()
	if not _materiaux.has(cle):
		var m := _mat_choix(["white_plaster_rough_01", "white_rough_plaster", "clay_plaster"], couleur, 0.95, 2.0).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Le chêne clair et neuf (le bois des pressoirs et des cuves).
func _mat_chene_clair() -> StandardMaterial3D:
	var cle := "chene_clair"
	if not _materiaux.has(cle):
		var m := _mat_choix(["weathered_planks", "wooden_rough_planks", "rough_wood"], Color(0.62, 0.48, 0.34), 0.85, 1.0).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


# --- Maisons rhénanes -------------------------------------------------------------------------

## Une maison à colombages du Rhin : un rez-de-chaussée de pierre (schiste, chaînages de grès
## rouge aux angles), un étage en encorbellement (il déborde un peu sur la rue) en pans de
## bois et torchis coloré, et un haut toit d'ardoise. La façade (porte) regarde +z.
## taille.x = largeur, taille.z = profondeur, taille.y = hauteur jusqu'au toit.
func _maison_rhenane(parent: Node3D, centre: Vector2, taille: Vector3, angle := 0.0, couleur := Color(0.92, 0.88, 0.78)) -> Node3D:
	var m := Node3D.new()
	m.name = "MaisonRhenane%d" % parent.get_child_count()
	m.position = Vector3(centre.x, hauteur(centre.x, centre.y) - 0.3, centre.y)
	m.rotation.y = angle
	parent.add_child(m)
	var rez := 2.8
	var pierre := _mat_schiste()
	var gres := _mat_gres_rouge()
	# Le rez-de-chaussée de pierre, enterré un peu (la pente).
	_boite(Vector3(taille.x, rez + 0.6, taille.z), Vector3(0, (rez + 0.6) * 0.5 - 0.6, 0), pierre, m)
	# Les chaînages d'angle en grès rouge, et un cordon de grès sous l'étage.
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			for k in 5:
				var long := 0.5 if k % 2 == 0 else 0.32
				_boite(Vector3(long, 0.5, 0.82 - long), Vector3(cx * (taille.x * 0.5 - long * 0.5 + 0.05), 0.3 + k * 0.52,
						cz * (taille.z * 0.5 - (0.82 - long) * 0.5 + 0.05)), gres, m, false)
	_boite(Vector3(taille.x + 0.2, 0.2, taille.z + 0.2), Vector3(0, rez - 0.1, 0), gres, m, false)
	# La porte en plein cintre (encadrement de grès) et une fenêtre à meneau.
	var bois := _mat_colombage()
	var sombre := _mat_uni_ma(Color(0.05, 0.045, 0.04), 1.0)
	_boite(Vector3(1.2, 2.1, 0.06), Vector3(-taille.x * 0.2, 1.05, taille.z * 0.5 + 0.03), bois, m, false)
	_boite(Vector3(1.6, 0.28, 0.16), Vector3(-taille.x * 0.2, 2.2, taille.z * 0.5 + 0.06), gres, m, false)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.22, 2.2, 0.16), Vector3(-taille.x * 0.2 + cote * 0.7, 1.1, taille.z * 0.5 + 0.06), gres, m, false)
	_boite(Vector3(1.1, 0.8, 0.05), Vector3(taille.x * 0.22, 1.5, taille.z * 0.5 + 0.03), sombre, m, false)
	_boite(Vector3(0.1, 0.8, 0.1), Vector3(taille.x * 0.22, 1.5, taille.z * 0.5 + 0.06), gres, m, false)
	_boite(Vector3(1.3, 0.12, 0.2), Vector3(taille.x * 0.22, 1.05, taille.z * 0.5 + 0.08), gres, m, false)
	# L'étage, qui déborde de 0,4 m sur la façade et les côtés, sur des corbeaux de bois.
	var deb := 0.4
	var h := taille.y - rez
	var etage := Vector3(taille.x + deb * 2.0, h, taille.z + deb)
	var y0 := rez
	_boite(etage, Vector3(0, y0 + h * 0.5, deb * 0.5), _mat_crepi(couleur), m, true)
	for k in int(taille.x / 1.2) + 1:
		_boite(Vector3(0.18, 0.22, deb + 0.3), Vector3(-taille.x * 0.5 + k * taille.x / int(taille.x / 1.2), y0 - 0.1, taille.z * 0.5 + deb * 0.5), bois, m, false)
	# Les pans de bois de l'étage : sablières, poteaux, et les « hommes » (une croix en
	# losange sous chaque fenêtre, des écharpes aux angles), en chêne sombre.
	var e := 0.15
	for face in 3:
		var long_face := etage.x if face == 0 else etage.z
		var normale := Vector3(0, 0, 1) if face == 0 else (Vector3(1, 0, 0) if face == 1 else Vector3(-1, 0, 0))
		var dist := (etage.z * 0.5 + 0.04) if face == 0 else (etage.x * 0.5 + 0.04)
		var le_long := Vector3(1, 0, 0) if face == 0 else Vector3(0, 0, 1)
		var base := normale * dist + Vector3(0, 0, deb * 0.5)
		for y in [y0 + 0.08, y0 + h * 0.45, y0 + h - 0.08]:
			_boite(Vector3(long_face, 0.15, e) if face == 0 else Vector3(e, 0.15, long_face), base + Vector3(0, y, 0), bois, m, false)
		var nb := maxi(3, int(long_face / 1.1))
		for k in nb + 1:
			var t := -long_face * 0.5 + k * long_face / nb
			_boite(Vector3(e, h, e), base + le_long * t + Vector3(0, y0 + h * 0.5, 0), bois, m, false)
		# Les écharpes des angles (l'homme de Mayence : un poteau et deux bras obliques).
		for bout: float in [-1.0, 1.0]:
			var pas := long_face / nb
			var milieu := base + le_long * (bout * (long_face * 0.5 - pas * 0.5))
			var diag := sqrt(pas * pas + (h * 0.45) * (h * 0.45))
			var inclinaison := atan2(h * 0.45, pas)
			var br := _boite(Vector3(e * 0.9, diag, e * 0.9), milieu + Vector3(0, y0 + h * 0.225, 0), bois, m, false)
			if face == 0:
				br.rotation.z = bout * (PI / 2 - inclinaison)
			else:
				br.rotation.x = -bout * (PI / 2 - inclinaison)
		# Des fenêtres à petits carreaux sur la façade.
		if face == 0:
			for k in maxi(1, nb / 2):
				var x := -long_face * 0.5 + (k * 2 + 1) * long_face / nb
				if absf(x) > long_face * 0.5 - 0.6:
					continue
				_boite(Vector3(0.7, 0.8, 0.05), base + Vector3(x, y0 + h * 0.66, 0.03), _mat_uni_ma(Color(0.25, 0.3, 0.32), 0.2), m, false)
				_boite(Vector3(0.06, 0.8, 0.07), base + Vector3(x, y0 + h * 0.66, 0.05), bois, m, false)
	# Le haut toit d'ardoise, le faîtage dans la profondeur (pignon sur rue, comme au Rhin).
	var toit := Node3D.new()
	toit.position = Vector3(0, taille.y, deb * 0.5)
	toit.rotation.y = PI / 2
	m.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, etage.z, etage.x, _mat_ardoise(), _mat_crepi(couleur), 1.0, 0.16)
	return m


# --- Le pressoir à vis ------------------------------------------------------------------------

## Le grand pressoir à vis des vignerons (un « pressoir à arbre » du Rhin) : deux jumelles de
## chêne plantées dans une maie (le plateau où l'on met le raisin), une poutre (le mouton) qui
## descend quand on tourne la grosse vis de bois avec la barre. Sous le bec, une cuve reçoit le
## moût. Le nœud « Vis » tourne quand on presse. C'est cette presse que Gutenberg a copiée.
func _pressoir_a_vis(parent: Node3D, p: Vector2, angle := 0.0, taille := 1.0) -> Node3D:
	var m := Node3D.new()
	m.name = "Pressoir"
	m.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	m.rotation.y = angle
	m.scale = Vector3.ONE * taille
	parent.add_child(m)
	var chene := _mat_colombage()
	var clair := _mat_chene_clair()
	# La maie : un grand plateau de pierre, avec son rebord et son bec.
	_boite(Vector3(3.0, 0.7, 3.0), Vector3(0, 0.35, 0), _mat_gres_rouge(), m)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(3.0, 0.16, 0.16), Vector3(0, 0.78, cote * 1.42), _mat_gres_rouge(), m, false)
		_boite(Vector3(0.16, 0.16, 3.0), Vector3(cote * 1.42, 0.78, 0), _mat_gres_rouge(), m, false)
	_boite(Vector3(0.3, 0.12, 0.7), Vector3(0, 0.6, 1.8), _mat_gres_rouge(), m, false)
	# Le marc de raisin sous le plateau de pression (une masse violette).
	_boite(Vector3(2.2, 0.5, 2.2), Vector3(0, 0.95, 0), _mat_uni_ma(Color(0.26, 0.1, 0.2), 0.7), m, false)
	_boite(Vector3(2.4, 0.18, 2.4), Vector3(0, 1.3, 0), clair, m, false)
	# Les deux jumelles et le chapeau.
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.42, 4.2, 0.42), Vector3(cote * 1.7, 2.1, 0), chene, m)
	_boite(Vector3(4.2, 0.5, 0.6), Vector3(0, 4.1, 0), chene, m, false)
	# Le mouton (la grosse poutre qui presse), au-dessus du plateau.
	_boite(Vector3(3.6, 0.45, 0.55), Vector3(0, 1.65, 0), chene, m, false)
	# La vis, avec ses filets, et la barre pour la tourner.
	var vis := Node3D.new()
	vis.name = "Vis"
	vis.position = Vector3(0, 1.9, 0)
	m.add_child(vis)
	var tige := MeshInstance3D.new()
	tige.mesh = _cylindre(0.2, 0.2, 2.2, 12)
	tige.material_override = clair
	tige.position.y = 1.1
	vis.add_child(tige)
	for k in 9:
		var filet := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = 0.18
		tore.outer_radius = 0.28
		tore.rings = 12
		tore.ring_segments = 6
		filet.mesh = tore
		filet.material_override = clair
		filet.position.y = 0.3 + k * 0.22
		filet.rotation.x = 0.12
		filet.rotation.y = k * 0.7
		vis.add_child(filet)
	var barre := _boite(Vector3(3.4, 0.12, 0.12), Vector3(0, 0.25, 0), chene, vis, false)
	barre.name = "Barre"
	# La cuve qui reçoit le moût, et le seau.
	var cuve := MeshInstance3D.new()
	cuve.mesh = _cylindre(0.55, 0.48, 0.7, 14)
	cuve.material_override = clair
	cuve.position = Vector3(0, 0.35, 2.4)
	m.add_child(cuve)
	var mout := MeshInstance3D.new()
	mout.mesh = _cylindre(0.5, 0.5, 0.02, 14)
	mout.material_override = _mat_uni_ma(Color(0.3, 0.08, 0.16), 0.1)
	mout.position = Vector3(0, 0.62, 2.4)
	m.add_child(mout)
	return m


## La halle du pressoir : un grand toit d'ardoise sur des poteaux, ouverte sur les côtés.
func _halle_pressoir(parent: Node3D, p: Vector2, taille: Vector2, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.name = "HallePressoir"
	m.position = Vector3(p.x, hauteur(p.x, p.y) - 0.1, p.y)
	m.rotation.y = angle
	parent.add_child(m)
	var chene := _mat_colombage()
	# Le sol de dalles.
	_boite(Vector3(taille.x + 1.0, 0.4, taille.y + 1.0), Vector3(0, -0.1, 0), _mat_schiste(), m)
	for kx in 4:
		for kz: float in [-1.0, 1.0]:
			var x := -taille.x * 0.5 + kx * taille.x / 3.0
			_boite(Vector3(0.32, 4.6, 0.32), Vector3(x, 2.3, kz * taille.y * 0.5), chene, m)
			# Les aisseliers (les bras obliques sous la sablière).
			if kx < 3:
				var a := _boite(Vector3(0.14, 1.3, 0.14), Vector3(x + 0.45, 4.05, kz * taille.y * 0.5), chene, m, false)
				a.rotation.z = -0.7
	for kz: float in [-1.0, 1.0]:
		_boite(Vector3(taille.x + 0.4, 0.3, 0.3), Vector3(0, 4.7, kz * taille.y * 0.5), chene, m, false)
	# Le mur du fond (nord) en schiste, contre la pente.
	_boite(Vector3(taille.x, 4.6, 0.6), Vector3(0, 2.3, -taille.y * 0.5 - 0.3), _mat_schiste(), m)
	var toit := Node3D.new()
	toit.position = Vector3(0, 4.85, 0)
	toit.rotation.y = PI / 2
	m.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, taille.y + 0.6, taille.x + 0.6, _mat_ardoise(), _mat_colombage(), 0.75, 0.16)
	return m


# --- Vignes -----------------------------------------------------------------------------------

var _maillage_echalas: Mesh
var _maillage_grappe: Mesh


## Plante des rangs de vigne (chaque cep sur son échalas, comme au Rhin) dans un rectangle.
## Les rangs suivent l'axe x ; « garder » (Callable(Vector2) -> bool) dit si l'on peut planter là.
## Tout est en MultiMesh, par bloc de 40 m, pour des milliers de ceps.
func _vignoble(parent: Node3D, r: Rect2, garder: Callable, hasard: RandomNumberGenerator, ecart_rangs := 2.4, ecart_ceps := 1.4) -> int:
	if _maillage_echalas == null:
		var b := BoxMesh.new()
		b.size = Vector3(0.05, 1.7, 0.05)
		_maillage_echalas = b
		var s := SphereMesh.new()
		s.radius = 0.09
		s.height = 0.22
		s.radial_segments = 6
		s.rings = 3
		_maillage_grappe = s
	var ceps := {}
	var echalas := {}
	var grappes := {}
	var poses := 0
	var z := r.position.y
	var rang := 0
	while z <= r.end.y:
		var x := r.position.x + (rang % 2) * ecart_ceps * 0.5
		while x <= r.end.x:
			var p := Vector2(x + hasard.randf_range(-0.12, 0.12), z + hasard.randf_range(-0.08, 0.08))
			x += ecart_ceps
			if not garder.call(p):
				continue
			var y := hauteur(p.x, p.y)
			var bloc := Vector2i(floori(p.x / 40.0), floori(p.y / 40.0))
			var v := hasard.randi() % Arbres.NB_VARIANTES
			var cle := Vector3i(v, bloc.x, bloc.y)
			var t := Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(Vector3.ONE * hasard.randf_range(0.85, 1.15)), Vector3(p.x, y - 0.05, p.y))
			if not ceps.has(cle):
				ceps[cle] = []
			(ceps[cle] as Array).append(t)
			var cb := Vector3i(0, bloc.x, bloc.y)
			if not echalas.has(cb):
				echalas[cb] = []
				grappes[cb] = []
			(echalas[cb] as Array).append(Transform3D(Basis(Vector3(1, 0, 0), hasard.randf_range(-0.05, 0.05)), Vector3(p.x + 0.12, y + 0.75, p.y)))
			# Une à trois grappes sous les feuilles (pas toutes cueillies : c'est la vendange).
			for g in hasard.randi_range(0, 3):
				var a := hasard.randf() * TAU
				(grappes[cb] as Array).append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.4, 1.0) * hasard.randf_range(0.8, 1.3)),
						Vector3(p.x + cos(a) * 0.3, y + hasard.randf_range(0.45, 0.75), p.y + sin(a) * 0.3)))
			poses += 1
		z += ecart_rangs
		rang += 1
	var noir := _mat_uni_ma(RAISIN_NOIR, 0.35)
	var bois := _mat_colombage()
	for cle: Vector3i in ceps:
		_multi(parent, Arbres.maillage("vigne", cle.x, bois), ceps[cle], null, 140.0, true, "Vigne_%d_%d_%d" % [cle.x, cle.y, cle.z])
	for cle: Vector3i in echalas:
		_multi(parent, _maillage_echalas, echalas[cle], bois, 90.0, false, "Echalas_%d_%d" % [cle.y, cle.z])
		_multi(parent, _maillage_grappe, grappes[cle], noir, 60.0, false, "Grappes_%d_%d" % [cle.y, cle.z])
	return poses


func _multi(parent: Node3D, maillage: Mesh, transfos: Array, materiau: Material, distance: float, ombre: bool, nom: String) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = maillage
	multi.instance_count = transfos.size()
	for i in transfos.size():
		multi.set_instance_transform(i, transfos[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.multimesh = multi
	if materiau != null:
		mmi.material_override = materiau
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = distance
	mmi.visibility_range_end_margin = 10.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)
	return mmi


## Un muret de pierre sèche (schiste) le long d'un segment, posé sur le terrain : il retient
## la terre d'une terrasse de vigne. Des pierres plates sur le dessus.
func _muret_sec(parent: Node3D, a: Vector2, b: Vector2, haut := 0.9, collision := true) -> void:
	var longueur := a.distance_to(b)
	var nb := maxi(1, int(longueur / 3.0))
	var dir := (b - a) / longueur
	var angle := -atan2(dir.y, dir.x)
	for k in nb:
		var c := a + dir * (k + 0.5) * longueur / nb
		var y := hauteur(c.x, c.y)
		var bloc := _boite(Vector3(longueur / nb + 0.05, haut + 0.6, 0.6), Vector3(c.x, y + haut * 0.5 - 0.3, c.y), _mat_schiste(), parent, collision)
		bloc.rotation.y = angle
		var dessus := _boite(Vector3(longueur / nb + 0.1, 0.1, 0.72), Vector3(c.x, y + haut + 0.02, c.y), _mat_schiste(), parent, false)
		dessus.rotation.y = angle


# --- Le Rhin ----------------------------------------------------------------------------------

## Une barque de pêcheur ou de passeur (coque de bois, deux bancs).
func _barque_rhin(parent: Node3D, p: Vector3, angle: float, longueur := 5.0) -> Node3D:
	var m := Node3D.new()
	m.name = "Barque%d" % parent.get_child_count()
	m.position = p
	m.rotation.y = angle
	parent.add_child(m)
	var bois := _mat_colombage()
	_boite(Vector3(1.4, 0.3, longueur), Vector3(0, 0.0, 0), bois, m, false)
	for cote: float in [-1.0, 1.0]:
		var bord := _boite(Vector3(0.1, 0.5, longueur * 0.95), Vector3(cote * 0.7, 0.3, 0), bois, m, false)
		bord.rotation.z = cote * 0.25
	for k: float in [-0.25, 0.2]:
		_boite(Vector3(1.4, 0.06, 0.25), Vector3(0, 0.35, k * longueur), bois, m, false)
	var proue := MeshInstance3D.new()
	var prisme := PrismMesh.new()
	prisme.size = Vector3(1.4, 0.8, 0.5)
	proue.mesh = prisme
	proue.material_override = bois
	proue.rotation.x = PI / 2
	proue.position = Vector3(0, 0.2, longueur * 0.5 + 0.25)
	m.add_child(proue)
	return m


## Une nef du Rhin : un grand bateau de charge à fond plat, un mât et une voile carrée.
func _nef_du_rhin(parent: Node3D, p: Vector3, angle: float, voile := Color(0.88, 0.82, 0.7)) -> Node3D:
	var m := _barque_rhin(parent, p, angle, 14.0)
	m.name = "NefDuRhin%d" % parent.get_child_count()
	m.scale = Vector3(2.2, 1.6, 1.0)
	var mat := MeshInstance3D.new()
	mat.mesh = _cylindre(0.06, 0.09, 9.0, 8)
	mat.material_override = _mat_colombage()
	mat.position = Vector3(0, 4.8, 1.0)
	m.add_child(mat)
	var vergue := _boite(Vector3(2.6, 0.08, 0.08), Vector3(0, 8.4, 1.0), _mat_colombage(), m, false)
	vergue.name = "Vergue"
	var toile := StandardMaterial3D.new()
	toile.albedo_color = voile
	toile.roughness = 0.95
	toile.cull_mode = BaseMaterial3D.CULL_DISABLED
	var v := _boite(Vector3(2.4, 4.6, 0.03), Vector3(0, 6.0, 1.1), toile, m, false)
	v.name = "Voile"
	# Des tonneaux de vin sur le pont.
	for k in 4:
		var t := MeshInstance3D.new()
		t.mesh = _cylindre(0.32, 0.32, 0.8, 10)
		t.material_override = _mat_chene_clair()
		t.rotation.z = PI / 2
		t.position = Vector3(-0.3 + (k % 2) * 0.6, 0.55, -3.0 - (k / 2) * 0.9)
		m.add_child(t)
	return m


## Le Rhin : une eau simple (pas d'effet d'écran), vert-gris et large, avec des rides.
func _eau_du_rhin(centre: Vector3, taille: Vector2) -> MeshInstance3D:
	var plan := PlaneMesh.new()
	plan.size = taille
	plan.subdivide_width = 40
	plan.subdivide_depth = 20
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.26, 0.26, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.25
	m.metallic_specular = 0.85
	m.normal_enabled = true
	m.normal_texture = _texture_vagues(graine + 31, 0.035)
	m.normal_scale = 0.5
	m.uv1_scale = Vector3(taille.x / 12.0, taille.y / 12.0, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var eau := MeshInstance3D.new()
	eau.name = "Rhin"
	eau.mesh = plan
	eau.material_override = m
	eau.position = centre
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(eau)
	return eau


# --- Végétation, couvre-sol -------------------------------------------------------------------

func _essence_buisson() -> String:
	return "buisson"


func _teinte_litiere() -> Color:
	# Les feuilles mortes d'octobre : brun-roux.
	return Color(0.62, 0.42, 0.24)
