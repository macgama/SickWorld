@tool
extends "res://scripts/monde/rome/ile_rome.gd"
## Île de Rome : l'intérieur de l'amphithéâtre flavien (le Colisée), le jour des jeux
## d'inauguration de Titus (chapitre 7). Plus tard, la fin du donjon (chapitre 8).
##
## Une immense cuvette ovale : au fond, l'arène de sable (80 m sur 48), entourée du
## podium, un mur de 4 m couronné d'une terrasse de marbre où s'assoient les sénateurs.
## Au sud, la loge de l'empereur (le pulvinar), sous un dais pourpre ; en face, la loge
## des Vestales. Puis les gradins montent en trois étages, séparés par des paliers, jusqu'au
## portique du sommet, et au-dessus, le grand voile (le velarium) tendu par les marins de
## la flotte. Des dizaines de milliers de spectateurs.
##
## On entre par un vomitoire, à l'ouest, sur la terrasse du podium. Une rampe de bois,
## posée pour les jeux, descend dans l'arène.
##
## Tout tient dans une seule « hauteur » : le sol du jeu suit l'arène, le podium, les gradins
## (une pente douce de 39°, sur laquelle on marche) et le haut du portique ; les marches,
## la foule et les murs sont posés par-dessus. Repères : le nord est vers -Z.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetRome := preload("res://scripts/monde/rome/objet_rome.gd")

## Les demi-axes de l'arène (le grand axe est est-ouest, le long de X).
const ARENE := Vector2(40, 24)
const PODIUM := 4.0
## La terrasse du podium : de 0 à 6 m au-delà du bord de l'arène.
const TERRASSE := 6.0
const PENTE := 0.8
## Les trois étages de gradins : [début, fin] (en mètres au-delà du bord de l'arène).
const ETAGES := [[6.0, 16.0], [18.0, 30.0], [32.0, 40.0]]
## Le haut des gradins, le portique du sommet et le mur de l'attique.
const SOMMET := 40.0
const ATTIQUE := 44.0
const HAUT_ATTIQUE := 12.0
## On arrive (et on repart) par le vomitoire de l'ouest.
const VOMITOIRE := Vector2(-46.4, 0)
const ENTREE := Vector2(-42.6, 0)
## La rampe de bois qui descend dans l'arène (angle sur l'ellipse).
const ANGLE_RAMPE := PI * 0.82
## La loge de l'empereur (au sud) et celle des Vestales (au nord).
const PULVINAR := Vector2(0, 27)
const LOGE_VESTALES := Vector2(0, -27)
const TITUS := Vector2(-1.6, 27.4)
const DOMITIEN := Vector2(2.2, 27.4)
const MARTIAL := Vector2(-6.5, 27.0)
## Les portes de l'arène : la porte triomphale (ouest) et la porte de la mort (est).
const PORTE_EST := Vector2(40, 0)
## Le chapitre 7 : les comploteurs dans les gradins, les jarres de poix, l'arène.
const COMPLOTEURS := Vector2(6, -46)
const JARRES := [[0.55, 11.0], [-1.65, 24.0], [2.6, 35.0]]
const GLADIATEURS := Vector2(-12, 2)
const TITUS_ARENE := Vector2(-8, 4)

var _attente_sortie := 0.0
var _hasard := RandomNumberGenerator.new()
## Les rangs de gradins : [d, hauteur de la marche] (pour la foule).
var _rangs: Array = []


func _init() -> void:
	identifiant_zone = "colisee"
	taille_terrain = 190
	graine = 80
	point_apparition = ENTREE
	nombre_touffes = 0
	neige_qui_tombe = false
	sols = {
		"galets": ["dry_ground_01", "dense_sand", "sand_01"],
		"neige": ["sand_01", "dense_sand", "dry_ground_01"],
		"sol": ["sand_01", "dense_sand", "dry_ground_01"],
		"roche": ["white_sandstone_blocks_02", "rock_boulder_dry", "cliff_side"],
	}
	reglages_terrain = {"sol_saturation": 0.75, "sol_motif": 3.0, "galets_motif": 3.0, "neige_motif": 4.0,
			"sol_teinte": Color(1.0, 0.92, 0.78), "roche_teinte": Color(0.95, 0.9, 0.8), "roche_saturation": 0.4,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 6.0,
			"neige_teinte": Color(0.95, 0.86, 0.68), "neige_max": Vector3(0.5, 0.45, 0.35), "neige_simple": Color(0.6, 0.52, 0.4),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.3, 0.3, 0.15), "couleur_pointe": Color(0.6, 0.56, 0.3),
			"couleur_givre": Color(0.6, 0.56, 0.3), "force_vent": 0.1}


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_rome", "") != "":
		Reseau.remove_meta("arrivee_rome")
		point_apparition = ENTREE
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return Vector2.INF if zone == "colisee" else VOMITOIRE + Vector2(2.0, 0)


# --- La forme de la cuvette ---------------------------------------------------------------

## De combien de mètres le point (x, z) est au-delà du bord de l'arène, en suivant la
## famille d'ellipses x²/(40+d)² + z²/(24+d)² = 1 (négatif dans l'arène).
func decalage(x: float, z: float) -> float:
	var bas := -ARENE.y + 0.01
	var haut := 260.0
	if _ecart(x, z, bas) <= 0.0:
		return bas
	for i in 26:
		var milieu := (bas + haut) * 0.5
		if _ecart(x, z, milieu) > 0.0:
			bas = milieu
		else:
			haut = milieu
	return (bas + haut) * 0.5


func _ecart(x: float, z: float, d: float) -> float:
	var ax := ARENE.x + d
	var az := ARENE.y + d
	return x * x / (ax * ax) + z * z / (az * az) - 1.0


## Le point de l'ellipse « d » à l'angle « a ».
func point_ellipse(a: float, d: float) -> Vector2:
	return Vector2(cos(a) * (ARENE.x + d), sin(a) * (ARENE.y + d))


## La normale (vers l'extérieur) de l'ellipse « d » à l'angle « a ».
func normale_ellipse(a: float, d: float) -> Vector2:
	var p := point_ellipse(a, d)
	var ax := ARENE.x + d
	var az := ARENE.y + d
	return Vector2(p.x / (ax * ax), p.y / (az * az)).normalized()


## Hauteur du sol à « d » mètres au-delà du bord de l'arène.
func hauteur_d(d: float) -> float:
	if d < 0.0:
		return 0.0
	if d < ETAGES[0][0]:
		return PODIUM
	var h := PODIUM
	for etage in ETAGES:
		var debut: float = etage[0]
		var fin: float = etage[1]
		if d < debut:
			return h
		if d < fin:
			return h + (d - debut) * PENTE
		h += (fin - debut) * PENTE
	return h


func hauteur(x: float, z: float) -> float:
	return hauteur_d(decalage(x, z))


func _parts_sol(_x: float, _z: float, _h: float) -> Color:
	return Color(0.0, 0.0, 1.0, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_hasard.seed = graine
	_commencer()
	_construire_terrain()
	_construire_podium()
	_construire_rampe()
	_construire_gradins()
	_construire_portique()
	_construire_loges()
	_construire_vomitoire()
	_construire_arene()
	_construire_foule()
	_construire_velarium()
	_construire_limites()
	_construire_quete()


## Le mur du podium, plaqué de marbre, ses deux portes, la balustrade de bronze et la
## terrasse de marbre des sénateurs.
func _construire_podium() -> void:
	var podium := Node3D.new()
	podium.name = "Podium"
	_contenu.add_child(podium)
	var marbre := _mat_marbre()
	var n := 96
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := point_ellipse(a0, 0.0)
		var p1 := point_ellipse(a1, 0.0)
		var c := (p0 + p1) * 0.5
		var d := p1 - p0
		var angle := atan2(d.x, d.y)
		var porte := absf(c.y) < 3.0
		var dehors := normale_ellipse((a0 + a1) * 0.5, 0.0)
		if porte:
			# Une des deux grandes portes de l'arène : une baie sombre fermée d'une grille.
			var fond := _boite(Vector3(0.6, PODIUM, d.length() + 0.05), Vector3(c.x + dehors.x * 0.6, PODIUM * 0.5, c.y + dehors.y * 0.6),
					_mat_pbr("", Color(0.06, 0.05, 0.05), 1.0), podium, false)
			fond.rotation.y = angle
			var grille := _boite(Vector3(0.08, PODIUM - 0.3, d.length() + 0.05), Vector3(c.x + dehors.x * 0.2, (PODIUM - 0.3) * 0.5, c.y + dehors.y * 0.2),
					_mat_bronze(), podium, false)
			grille.rotation.y = angle
			var linteau := _boite(Vector3(0.8, 0.5, d.length() + 0.05), Vector3(c.x, PODIUM - 0.25, c.y), _mat_travertin(), podium, false)
			linteau.rotation.y = angle
		else:
			var mur := _boite(Vector3(0.8, PODIUM, d.length() + 0.05), Vector3(c.x + dehors.x * 0.2, PODIUM * 0.5, c.y + dehors.y * 0.2), marbre, podium, false)
			mur.rotation.y = angle
		# La corniche, et la balustrade de bronze au bord de la terrasse.
		var corniche := _boite(Vector3(1.2, 0.3, d.length() + 0.05), Vector3(c.x + dehors.x * 0.3, PODIUM + 0.05, c.y + dehors.y * 0.3), _mat_travertin(), podium, false)
		corniche.rotation.y = angle
		var dans_rampe := absf(angle_difference((a0 + a1) * 0.5, ANGLE_RAMPE)) < 0.05
		if not dans_rampe:
			var rambarde := _boite(Vector3(0.08, 0.08, d.length() + 0.05), Vector3(c.x + dehors.x * 0.35, PODIUM + 1.05, c.y + dehors.y * 0.35), _mat_bronze(), podium, false)
			rambarde.rotation.y = angle
			var poteau := MeshInstance3D.new()
			poteau.mesh = _cylindre(0.04, 0.05, 1.05, 6)
			poteau.material_override = _mat_bronze()
			poteau.position = Vector3(p0.x + dehors.x * 0.35, PODIUM + 0.52, p0.y + dehors.y * 0.35)
			podium.add_child(poteau)
			_mur_invisible(podium, Vector3(0.3, 2.2, d.length() + 0.1), Vector3(c.x + dehors.x * 0.35, PODIUM + 1.1, c.y + dehors.y * 0.35), angle)
		# Le mur du podium arrête aussi les bêtes qui voudraient grimper.
		if not dans_rampe:
			_mur_invisible(podium, Vector3(0.4, PODIUM, d.length() + 0.1), Vector3(c.x - dehors.x * 0.1, PODIUM * 0.5, c.y - dehors.y * 0.1), angle)
	# La terrasse de marbre (les sièges des sénateurs y sont des bancs de pierre).
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	_anneau(outil, 0.2, TERRASSE, PODIUM + 0.02, PODIUM + 0.02, 128)
	outil.generate_normals()
	var terrasse := MeshInstance3D.new()
	terrasse.name = "Terrasse"
	terrasse.mesh = outil.commit()
	terrasse.material_override = _mat_choix(["marble_tiles", "marble_01"], Color(0.92, 0.9, 0.86), 0.5, 2.0)
	podium.add_child(terrasse)
	_fusionner(podium)


## Une bande d'ellipses entre d0 et d1, de la hauteur h0 à h1.
func _anneau(outil: SurfaceTool, d0: float, d1: float, h0: float, h1: float, n: int) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p00 := point_ellipse(a0, d0)
		var p01 := point_ellipse(a1, d0)
		var p10 := point_ellipse(a0, d1)
		var p11 := point_ellipse(a1, d1)
		var q00 := Vector3(p00.x, h0, p00.y)
		var q01 := Vector3(p01.x, h0, p01.y)
		var q10 := Vector3(p10.x, h1, p10.y)
		var q11 := Vector3(p11.x, h1, p11.y)
		for v in [q00, q11, q10, q00, q01, q11]:
			outil.set_uv(Vector2((v as Vector3).x, (v as Vector3).z) * 0.25)
			outil.add_vertex(v)


## La rampe de bois posée pour les jeux, de la terrasse jusqu'au sable.
func _construire_rampe() -> void:
	var haut := point_ellipse(ANGLE_RAMPE, 0.6)
	var n := normale_ellipse(ANGLE_RAMPE, 0.0)
	var longueur_sol := 8.5
	var bas := haut - n * longueur_sol
	var long := Vector3(-n.x * longueur_sol, -PODIUM, -n.y * longueur_sol)
	var axe := long.normalized()
	var cote := Vector3(-n.y, 0, n.x)
	var dessus := cote.cross(axe).normalized()
	if dessus.y < 0.0:
		cote = -cote
		dessus = -dessus
	var rampe := _boite(Vector3(long.length() + 0.4, 0.3, 3.2), Vector3((haut.x + bas.x) * 0.5, PODIUM * 0.5 - 0.15, (haut.y + bas.y) * 0.5),
			_mat_bois(), _contenu)
	rampe.name = "Rampe"
	rampe.basis = Basis(axe, dessus, cote)
	# Les garde-corps de la rampe (et leur collision, inclinée comme elle).
	for s: float in [-1.0, 1.0]:
		var garde := _boite(Vector3(long.length(), 0.1, 0.1), rampe.position + cote * s * 1.55 + dessus * 1.0, _mat_bois(), _contenu, false)
		garde.basis = Basis(axe, dessus, cote)
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = Vector3(long.length(), 2.4, 0.3)
		forme.shape = boite
		corps.add_child(forme)
		corps.transform = Transform3D(Basis(axe, dessus, cote), rampe.position + cote * s * 1.75 + dessus * 1.2)
		_contenu.add_child(corps)


## Les marches des trois étages de gradins, et les paliers entre eux.
func _construire_gradins() -> void:
	var gradins := Node3D.new()
	gradins.name = "Gradins"
	_contenu.add_child(gradins)
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 160
	var marche := 0.75
	_rangs.clear()
	for etage in ETAGES:
		var debut: float = etage[0]
		var fin: float = etage[1]
		var d := debut
		var h_prec := hauteur_d(debut - 0.01)
		while d < fin - 0.01:
			var d1 := minf(d + marche, fin)
			var h := hauteur_d((d + d1) * 0.5)
			# Le devant de la marche (la contremarche), puis le dessus.
			_anneau(outil, d, d, h_prec - 0.05, h, n)
			_anneau(outil, d, d1, h, h, n)
			_rangs.append([d + 0.3, h])
			h_prec = h
			d = d1
		# Le palier en haut de l'étage.
		_anneau(outil, fin, fin, h_prec - 0.05, hauteur_d(fin + 0.5) + 0.02, n)
	outil.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Marches"
	mi.mesh = outil.commit()
	mi.material_override = _mat_deux_faces(_mat_travertin())
	gradins.add_child(mi)
	# Les paliers (praecinctiones) : de larges bandes de marbre.
	var paliers := SurfaceTool.new()
	paliers.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in ETAGES.size():
		var fin: float = ETAGES[k][1]
		var suivant: float = ETAGES[k + 1][0] if k + 1 < ETAGES.size() else ATTIQUE
		var h := hauteur_d(fin + 0.5) + 0.02
		_anneau(paliers, fin, suivant, h, h, n)
	paliers.generate_normals()
	var mp := MeshInstance3D.new()
	mp.name = "Paliers"
	mp.mesh = paliers.commit()
	mp.material_override = _mat_choix(["marble_tiles", "marble_01"], Color(0.9, 0.88, 0.84), 0.6, 2.0)
	gradins.add_child(mp)
	# Les murets entre les étages (on peut les enjamber : ils ne font que 60 cm).
	var murets := SurfaceTool.new()
	murets.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in ETAGES.size() - 1:
		var debut: float = ETAGES[k + 1][0]
		var h := hauteur_d(debut - 0.1)
		_anneau(murets, debut - 0.1, debut - 0.1, h, h + 0.6, n)
	murets.generate_normals()
	var mm := MeshInstance3D.new()
	mm.mesh = murets.commit()
	mm.material_override = _mat_deux_faces(_mat_marbre())
	gradins.add_child(mm)


## Le portique du sommet (les places debout du petit peuple), et le haut mur de l'attique
## avec les mâts du velarium.
func _construire_portique() -> void:
	var portique := Node3D.new()
	portique.name = "Portique"
	_contenu.add_child(portique)
	var h := hauteur_d(SOMMET + 1.0)
	var n := 72
	for i in n:
		var a := TAU * (i + 0.5) / n
		var p := point_ellipse(a, ATTIQUE - 2.6)
		var colonne := MeshInstance3D.new()
		colonne.mesh = _cylindre(0.34, 0.38, 6.0, 10)
		colonne.material_override = _mat_marbre()
		colonne.position = Vector3(p.x, h + 3.0, p.y)
		portique.add_child(colonne)
	var toit := SurfaceTool.new()
	toit.begin(Mesh.PRIMITIVE_TRIANGLES)
	_anneau(toit, ATTIQUE - 3.4, ATTIQUE, h + 6.2, h + 6.6, 128)
	toit.generate_normals()
	var mt := MeshInstance3D.new()
	mt.mesh = toit.commit()
	mt.material_override = _mat_deux_faces(_mat_travertin())
	portique.add_child(mt)
	# Le mur de l'attique : vu de l'intérieur, il ferme le ciel tout autour.
	var mur := SurfaceTool.new()
	mur.begin(Mesh.PRIMITIVE_TRIANGLES)
	_anneau(mur, ATTIQUE, ATTIQUE, h - 0.5, h + HAUT_ATTIQUE, 128)
	_anneau(mur, ATTIQUE, ATTIQUE + 1.0, h + HAUT_ATTIQUE, h + HAUT_ATTIQUE, 128)
	mur.generate_normals()
	var mm := MeshInstance3D.new()
	mm.name = "Attique"
	mm.mesh = mur.commit()
	mm.material_override = _mat_deux_faces(_mat_travertin())
	portique.add_child(mm)
	for i in 80:
		var a := TAU * i / 80
		var p := point_ellipse(a, ATTIQUE + 0.5)
		var mat := MeshInstance3D.new()
		mat.mesh = _cylindre(0.12, 0.16, 9.0, 6)
		mat.material_override = _mat_bois()
		mat.position = Vector3(p.x, h + HAUT_ATTIQUE + 4.0, p.y)
		portique.add_child(mat)
	_fusionner(portique)


## La loge de l'empereur, au sud, sous son dais pourpre ; la loge des Vestales, au nord.
func _construire_loges() -> void:
	var loges := Node3D.new()
	loges.name = "Loges"
	_contenu.add_child(loges)
	var pourpre := _mat_pbr("", Color(0.36, 0.06, 0.2), 0.85)
	var or_mat := _mat_pbr("", Color(0.85, 0.65, 0.25), 0.35)
	or_mat.metallic = 0.9
	for loge: Array in [[PULVINAR, 1.0, pourpre], [LOGE_VESTALES, -1.0, _mat_pbr("", Color(0.92, 0.9, 0.84), 0.9)]]:
		var c: Vector2 = loge[0]
		var s: float = loge[1]
		var dais: StandardMaterial3D = loge[2]
		# Les colonnes de la façade, côté arène.
		for x: float in [-5.0, -2.0, 2.0, 5.0]:
			var col := MeshInstance3D.new()
			col.mesh = _cylindre(0.22, 0.25, 4.4, 10)
			col.material_override = _mat_marbre()
			col.position = Vector3(c.x + x, PODIUM + 2.2, c.y - s * 2.4)
			loges.add_child(col)
		# Le dais, le fronton doré, et les murs de côté.
		_boite(Vector3(11.4, 0.4, 6.0), Vector3(c.x, PODIUM + 4.6, c.y), _mat_travertin(), loges, false)
		_boite(Vector3(11.0, 0.2, 5.6), Vector3(c.x, PODIUM + 4.35, c.y), dais, loges, false)
		_boite(Vector3(11.6, 0.6, 0.3), Vector3(c.x, PODIUM + 5.0, c.y - s * 2.9), or_mat if s > 0 else _mat_marbre(), loges, false)
		for x: float in [-5.6, 5.6]:
			_boite(Vector3(0.3, 4.4, 5.0), Vector3(c.x + x, PODIUM + 2.2, c.y + s * 0.4), _mat_marbre(), loges)
		# Les sièges : le trône d'ivoire et d'or de l'empereur, des bancs pour les Vestales.
		if s > 0:
			_boite(Vector3(1.0, 1.4, 0.9), Vector3(c.x - 1.6, PODIUM + 0.7, c.y + 1.6), or_mat, loges, false)
			_boite(Vector3(1.0, 1.2, 0.9), Vector3(c.x + 2.2, PODIUM + 0.6, c.y + 1.6), _mat_marbre(), loges, false)
			# Les tentures pourpres qui pendent du dais.
			for x: float in [-5.2, 5.2]:
				_boite(Vector3(0.6, 3.0, 0.05), Vector3(c.x + x * 0.95, PODIUM + 2.9, c.y - s * 2.6), pourpre, loges, false)
		else:
			_boite(Vector3(8.0, 0.5, 0.8), Vector3(c.x, PODIUM + 0.25, c.y - 1.2), _mat_marbre(), loges, false)
	_fusionner(loges)


## Le vomitoire de l'ouest : la bouche sombre d'un couloir, sous les gradins.
func _construire_vomitoire() -> void:
	var v := Node3D.new()
	v.name = "Vomitoire"
	_contenu.add_child(v)
	var p := VOMITOIRE
	var noir := _mat_pbr("", Color(0.03, 0.025, 0.02), 1.0)
	_boite(Vector3(2.4, 3.2, 3.4), Vector3(p.x - 1.2, PODIUM + 1.6, p.y), noir, v, false)
	for s: float in [-1.0, 1.0]:
		_boite(Vector3(1.6, 3.6, 0.7), Vector3(p.x - 0.4, PODIUM + 1.8, p.y + s * 2.05), _mat_travertin(), v)
	_boite(Vector3(1.6, 0.9, 4.8), Vector3(p.x - 0.4, PODIUM + 4.05, p.y), _mat_travertin(), v, false)
	# Les gradins juste au-dessus de la bouche : un toit plat pour ne pas voir à travers.
	_boite(Vector3(4.0, 0.3, 5.0), Vector3(p.x - 2.0, PODIUM + 4.6, p.y), _mat_travertin(), v, false)
	_fusionner(v)


## Le sable de l'arène : quelques râteaux, les mâts des bannières, l'autel de Jupiter.
func _construire_arene() -> void:
	var arene := Node3D.new()
	arene.name = "Arene"
	_contenu.add_child(arene)
	# L'autel, au milieu de l'arène (on y sacrifie avant les jeux).
	_boite(Vector3(1.6, 1.1, 1.0), Vector3(0, 0.55, 0), _mat_marbre(), arene)
	_boite(Vector3(1.8, 0.15, 1.2), Vector3(0, 1.15, 0), _mat_marbre(), arene, false)
	# Des pieux de bois et des panneaux contre lesquels on se bat (et se cache).
	for i in 6:
		var a := TAU * i / 6 + 0.3
		var p := Vector2(cos(a) * 22.0, sin(a) * 12.0)
		var panneau := _boite(Vector3(2.4, 1.6, 0.18), Vector3(p.x, 0.8, p.y), _mat_bois(), arene)
		panneau.rotation.y = a
	# Les bannières de la maison flavienne, devant le podium.
	for i in 16:
		var a := TAU * (i + 0.5) / 16
		if absf(angle_difference(a, PI)) < 0.3 or absf(angle_difference(a, ANGLE_RAMPE)) < 0.15:
			continue
		var p := point_ellipse(a, -0.6)
		var mat := MeshInstance3D.new()
		mat.mesh = _cylindre(0.05, 0.06, 7.0, 6)
		mat.material_override = _mat_bois()
		mat.position = Vector3(p.x, 3.5, p.y)
		arene.add_child(mat)
		var tissu := _boite(Vector3(0.04, 2.0, 1.0), Vector3(p.x, 5.6, p.y), _mat_pbr("", Color(0.6, 0.1, 0.12) if i % 2 == 0 else Color(0.85, 0.7, 0.3), 0.9), arene, false)
		tissu.rotation.y = a
	_fusionner(arene)


## La foule : des dizaines de milliers de spectateurs assis, les toges blanches des
## sénateurs en bas, les tuniques de couleur plus haut. Deux MultiMesh (corps et têtes).
func _construire_foule() -> void:
	var corps := _maillage_spectateur(false)
	var tetes := _maillage_spectateur(true)
	var places: Array[Transform3D] = []
	var couleurs: Array[Color] = []
	var peaux: Array[Color] = []
	var tuniques := [Color(0.92, 0.9, 0.84), Color(0.85, 0.8, 0.68), Color(0.62, 0.22, 0.16), Color(0.32, 0.4, 0.55),
			Color(0.55, 0.48, 0.3), Color(0.4, 0.5, 0.35), Color(0.75, 0.55, 0.3), Color(0.45, 0.3, 0.4)]
	var teints := [Color(0.82, 0.62, 0.48), Color(0.72, 0.52, 0.38), Color(0.6, 0.42, 0.3), Color(0.45, 0.3, 0.2)]
	for rang in _rangs:
		var d: float = rang[0]
		var h: float = rang[1]
		var a := 0.0
		while a < TAU:
			var p := point_ellipse(a, d)
			var vitesse := Vector2(-sin(a) * (ARENE.x + d), cos(a) * (ARENE.y + d)).length()
			a += 0.85 / vitesse
			if _place_libre(a, d, vitesse):
				continue
			if _hasard.randf() < 0.12:
				continue
			var n := normale_ellipse(a, d)
			var t := Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)), Vector3(p.x, h, p.y))
			places.append(t)
			var bas := d < 12.0
			couleurs.append(tuniques[0] if bas and _hasard.randf() < 0.8 else tuniques[_hasard.randi() % tuniques.size()])
			peaux.append(teints[_hasard.randi() % teints.size()])
	for k in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tetes if k == 1 else corps
		mm.instance_count = places.size()
		for i in places.size():
			mm.set_instance_transform(i, places[i])
			mm.set_instance_color(i, peaux[i] if k == 1 else couleurs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Foule" if k == 0 else "FouleTetes"
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if k == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_contenu.add_child(mmi)


## Vrai là où personne n'est assis : les escaliers (un tous les 15°), la bouche du
## vomitoire et le haut de la rampe, et autour des jarres de poix.
func _place_libre(a: float, d: float, vitesse: float) -> bool:
	var pas := TAU / 24.0
	var ecart := absf(fposmod(a + pas * 0.5, pas) - pas * 0.5)
	if ecart * vitesse < 0.7:
		return true
	if d < 12.0 and absf(angle_difference(a, PI)) * vitesse < 3.5:
		return true
	return false


## Un spectateur assis, en quelques formes : le corps drapé et les jambes, ou la tête.
func _maillage_spectateur(tete: bool) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	if tete:
		var s := SphereMesh.new()
		s.radius = 0.11
		s.height = 0.25
		s.radial_segments = 8
		s.rings = 4
		outil.append_from(s, 0, Transform3D(Basis(), Vector3(0, 1.02, 0.02)))
	else:
		var buste := CylinderMesh.new()
		buste.top_radius = 0.15
		buste.bottom_radius = 0.22
		buste.height = 0.62
		buste.radial_segments = 8
		buste.rings = 1
		outil.append_from(buste, 0, Transform3D(Basis(), Vector3(0, 0.6, 0.06)))
		var cuisses := BoxMesh.new()
		cuisses.size = Vector3(0.34, 0.16, 0.42)
		outil.append_from(cuisses, 0, Transform3D(Basis(), Vector3(0, 0.36, -0.12)))
		var jambes := BoxMesh.new()
		jambes.size = Vector3(0.3, 0.42, 0.14)
		outil.append_from(jambes, 0, Transform3D(Basis(), Vector3(0, 0.08, -0.3)))
	return outil.commit()


## Le velarium : un grand voile de toile tendu au-dessus des gradins, par bandes, laissant
## le soleil entrer au nord.
func _construire_velarium() -> void:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outil2 := SurfaceTool.new()
	outil2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := hauteur_d(SOMMET + 1.0) + HAUT_ATTIQUE + 7.0
	var n := 48
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var milieu := (a0 + a1) * 0.5
		if sin(milieu) < -0.45:
			continue
		var cible := outil if i % 2 == 0 else outil2
		var pas := 4
		for k in pas:
			var d0 := lerpf(ATTIQUE, 14.0, float(k) / pas)
			var d1 := lerpf(ATTIQUE, 14.0, float(k + 1) / pas)
			var y0 := h - 6.0 * pow(float(k) / pas, 1.4)
			var y1 := h - 6.0 * pow(float(k + 1) / pas, 1.4)
			var p00 := point_ellipse(a0 + 0.01, d0)
			var p01 := point_ellipse(a1 - 0.01, d0)
			var p10 := point_ellipse(a0 + 0.01, d1)
			var p11 := point_ellipse(a1 - 0.01, d1)
			for v in [Vector3(p00.x, y0, p00.y), Vector3(p11.x, y1, p11.y), Vector3(p10.x, y1, p10.y),
					Vector3(p00.x, y0, p00.y), Vector3(p01.x, y0, p01.y), Vector3(p11.x, y1, p11.y)]:
				cible.set_uv(Vector2((v as Vector3).x, (v as Vector3).z) * 0.1)
				cible.add_vertex(v)
	for k in 2:
		var o := outil if k == 0 else outil2
		o.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Velarium%d" % k
		mi.mesh = o.commit()
		var toile := StandardMaterial3D.new()
		toile.albedo_color = Color(0.95, 0.9, 0.78) if k == 0 else Color(0.85, 0.45, 0.25)
		toile.roughness = 0.95
		toile.cull_mode = BaseMaterial3D.CULL_DISABLED
		# La toile laisse passer le soleil : vue d'en bas, elle s'éclaire par transparence.
		toile.backlight_enabled = true
		toile.backlight = Color(0.75, 0.62, 0.45) if k == 0 else Color(0.7, 0.3, 0.12)
		mi.material_override = toile
		_contenu.add_child(mi)


func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var h := hauteur_d(SOMMET + 1.0)
	for i in 64:
		var a0 := TAU * i / 64
		var a1 := TAU * (i + 1) / 64
		var p0 := point_ellipse(a0, ATTIQUE - 0.3)
		var p1 := point_ellipse(a1, ATTIQUE - 0.3)
		var d := p1 - p0
		_mur_invisible(limites, Vector3(0.6, 30.0, d.length() + 0.3), Vector3((p0.x + p1.x) * 0.5, h + 10.0, (p0.y + p1.y) * 0.5), atan2(d.x, d.y))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_pnj(dossier, "titus", TITUS, 0.0)
	var domitien := _pnj(dossier, "domitien", DOMITIEN, -0.3)
	domitien.add_to_group("decor_quete")
	domitien.set_meta("identifiant", "domitien")
	_pnj(dossier, "martial_loge", MARTIAL, 0.4)
	for g: Array in [["priscus", GLADIATEURS + Vector2(-1.2, 0), PI * 0.5], ["verus", GLADIATEURS + Vector2(1.2, 0), -PI * 0.5]]:
		var gladiateur := _pnj(dossier, g[0], g[1], g[2])
		gladiateur.add_to_group("decor_quete")
		gladiateur.set_meta("identifiant", g[0])
		gladiateur.visible = false
	for i in JARRES.size():
		var a: float = JARRES[i][0]
		var d: float = JARRES[i][1]
		var p := point_ellipse(a, d)
		var jarre := ObjetRome.new()
		jarre.name = "JarrePoix%d" % i
		jarre.identifiant = "jarre_poix_%d" % i
		jarre.groupe = "jarre_poix"
		jarre.forme = "jarre_poix"
		jarre.invite = "[F] Étouffer la mèche et emporter la jarre"
		jarre.portee = 2.4
		jarre.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(jarre)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Loge de l'empereur", PULVINAR)
	repere.call(MarqueurCarte.Type.LIEU, "Loge des Vestales", LOGE_VESTALES)
	repere.call(MarqueurCarte.Type.LIEU, "Arène", Vector2.ZERO)
	repere.call(MarqueurCarte.Type.LIEU, "Sortie vers Rome", VOMITOIRE)


# --- La sortie : le vomitoire de l'ouest ----------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if quete == null or joueur == null or not quete.has_method("changer_de_zone"):
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(VOMITOIRE) < 1.6 and joueur.global_position.y < PODIUM + 3.0:
		quete.changer_de_zone("rome")
