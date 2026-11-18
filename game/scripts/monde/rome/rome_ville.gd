@tool
extends "res://scripts/monde/rome/ile_rome.gd"
## Île de Rome, zone 3 : Rome (niveaux 34-38).
##
## La ville, un million d'habitants, l'été de l'an 80. On entre au sud-est, par la route
## de la Porta Maggiore, sur la colline de l'Esquilin, à côté du vivarium où l'on garde
## les bêtes des jeux. Au centre, l'amphithéâtre flavien (le Colisée) tout neuf, et à
## côté le Colosse de Néron, une statue de bronze de trente mètres. À l'ouest, le Forum,
## ses temples et ses basiliques, et le Capitole sur sa colline. Au nord, la Subure, le
## quartier populaire et ses immeubles de briques ; au nord-ouest, le Champ de Mars et le
## Panthéon d'Agrippa.
##
## Les grands monuments sont à une échelle un peu réduite (le Colisée aux deux tiers),
## pour tenir dans la zone. Tout est construit par le code. Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetRome := preload("res://scripts/monde/rome/objet_rome.gd")

const SOCLE := 8.0
## L'arrivée, au sud-est (la route de la Porta Maggiore).
const ENTREE := Vector2(126, 146)
## Les rues principales : de l'entrée au Colisée, la Voie Sacrée vers le Forum, l'Argilète
## vers la Subure.
const RUE_ESQUILIN := [Vector2(128, 162), Vector2(124, 120), Vector2(112, 60), Vector2(70, 46), Vector2(20, 36)]
const VOIE_SACREE := [Vector2(20, 36), Vector2(4, 0), Vector2(-6, -30), Vector2(-28, -38), Vector2(-100, -39)]
const ARGILETE := [Vector2(-40, -52), Vector2(-24, -72), Vector2(-4, -90), Vector2(14, -110)]
const RUE_COLOSSE := [Vector2(-6, -30), Vector2(6, -60), Vector2(14, -100)]
## L'amphithéâtre flavien : centre et demi-axes (aux deux tiers de la vraie taille).
const COLISEE := Vector2(72, -16)
const COLISEE_AXES := Vector2(62, 51)
const COLISEE_HAUT := 32.0
## Le Colosse de Néron, devenu le dieu Soleil.
const COLOSSE := Vector2(14, -60)
## Le Forum : la grande place pavée, entre deux basiliques.
const FORUM := Rect2(-100, -50, 74, 22)
## Le Capitole, sur sa colline, et la montée (le « clivus ») depuis le Forum.
const CAPITOLE := Vector2(-132, -40)
const CLIVUS := [Vector2(-98, -30), Vector2(-108, -16), Vector2(-126, -14), Vector2(-138, -26)]
const HAUT_CAPITOLE := 20.0
## Le Palatin, au sud du Forum : les palais, sur leurs grands murs de soutènement.
const PALATIN := Rect2(-84, 6, 64, 40)
## La Subure : les immeubles, et la place où l'on distribue le blé.
const SUBURE := Rect2(-34, -154, 96, 72)
const PLACE_BLE := Vector2(16, -118)
## Le Champ de Mars et le Panthéon d'Agrippa, au nord-ouest.
const CHAMP_DE_MARS := Rect2(-156, -156, 90, 56)
const PANTHEON := Vector2(-112, -128)
## Le vivarium, à côté de l'entrée : les cages des bêtes des jeux.
const VIVARIUM := Rect2(132, 92, 22, 28)
const ARENE_RHINO := Vector2(110, 84)
## Les personnages du chapitre 4.
const LIVIA := Vector2(120, 136)
const MARTIAL := PLACE_BLE + Vector2(-3, 2)
const EGARES := [PLACE_BLE + Vector2(-8, -6), PLACE_BLE + Vector2(8, -7), PLACE_BLE + Vector2(6, 7)]
const TABLE_BLE := PLACE_BLE + Vector2(-6, 7)
const FRUMENTARIUS := PLACE_BLE + Vector2(-6, 9.5)
const AGITATEUR := PLACE_BLE + Vector2(11, 0)
const SACS_BLE := [PLACE_BLE + Vector2(-9, 9), PLACE_BLE + Vector2(-3, 10), PLACE_BLE + Vector2(-10, 4), PLACE_BLE + Vector2(-2, 5)]
const FILATURE := [Vector2(44, -142), Vector2(56, -96)]
const OREILLETTE := Vector2(58, -92)
const CARPOPHORE := Vector2(126, 98)
const CAGE_RHINO := Vector2(146, 104)
const SORTIE_SUD := Vector2(128, 156)
# Chapitre 5 : l'incendie du Champ de Mars, les oies du Capitole et Janus.
const LUCRETIUS := Vector2(-62, -92)
const VIGILES := [Vector2(-66, -88), Vector2(-58, -97)]
const FEUX := [Vector2(-132, -108), Vector2(-90, -118), Vector2(-142, -142), Vector2(-82, -136)]
const OIES := CAPITOLE + Vector2(-10, 12)
const JANUS := Vector2(-100, -150)
const PORTAIL_QG := Vector2(-74, -146)
# Chapitre 7 : les jeux d'inauguration. On entre dans l'amphithéâtre par la grande arche de
# l'ouest (la porte du côté du Colosse) ; la bouche de la Cloaca Maxima, au bord du Forum.
const PORTE_COLISEE := Vector2(9, -16)
const MARTIAL_JEUX := Vector2(3, -11)
const MARTIAL_COLOSSE := Vector2(24, -48)
const EGOUT := Vector2(-96, -26)
const EGOUTIER := EGOUT + Vector2(3, 1.5)

var _portail_qg: Node3D

var _hasard := RandomNumberGenerator.new()


func _init() -> void:
	identifiant_zone = "rome"
	taille_terrain = 320
	graine = 82
	point_apparition = ENTREE + Vector2(0, -4)
	nombre_touffes = 30000
	fertilite_sols = Vector3(0.0, 1.0, 0.08)
	reglages_couvre_sol = {"cailloux": 6.0, "fleurs": [Color(0.82, 0.1, 0.06), Color(0.95, 0.78, 0.12), Color(0.58, 0.38, 0.75)], "densite_fleurs": 0.6}
	neige_qui_tombe = false
	sols = {
		"galets": ["dry_ground_01", "mud_cracked_dry_03", "dry_ground_rocks"],
		"neige": ["brown_mud_02", "dry_ground_rocks", "dry_ground_01"],
		"sol": ["cobblestone_floor_04", "dry_ground_01", "brown_mud_02"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.8, "sol_motif": 4.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.98, 0.93, 0.84), "roche_teinte": Color(0.98, 0.92, 0.8), "roche_saturation": 0.7,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.95, 0.88, 0.7), "neige_max": Vector3(0.5, 0.44, 0.3), "neige_simple": Color(0.5, 0.45, 0.3),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.24, 0.26, 0.1), "couleur_pointe": Color(0.66, 0.62, 0.34),
			"couleur_givre": Color(0.62, 0.58, 0.34), "force_vent": 0.25}
	piste = CLIVUS.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_rome", "") != "":
		# En sortant de l'amphithéâtre, on se retrouve devant sa grande arche.
		var depuis := String(Reseau.get_meta("arrivee_rome", ""))
		Reseau.remove_meta("arrivee_rome")
		if depuis == "colisee":
			point_apparition = PORTE_COLISEE + Vector2(-5, -2)
		elif depuis == "cloaca":
			point_apparition = EGOUT + Vector2(0, 5)
		else:
			point_apparition = ENTREE + Vector2(0, -4)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "colisee":
		return PORTE_COLISEE + Vector2(-2, 0)
	if zone == "cloaca":
		return EGOUT + Vector2(0, 2)
	return Vector2.INF if zone == "rome" else SORTIE_SUD + Vector2(0, -6)


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.006


func _distance_ligne(p: Vector2, points: Array) -> float:
	var meilleure := INF
	for i in points.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, points[i], points[i + 1]))
	return meilleure


func distance_rues(p: Vector2) -> float:
	return minf(minf(_distance_ligne(p, RUE_ESQUILIN), _distance_ligne(p, VOIE_SACREE)),
			minf(_distance_ligne(p, ARGILETE), _distance_ligne(p, RUE_COLOSSE)))


## Vrai à l'intérieur de l'ellipse du Colisée, agrandie de « marge » mètres.
func dans_colisee(p: Vector2, marge := 0.0) -> bool:
	var d := p - COLISEE
	var ax := COLISEE_AXES.x + marge
	var az := COLISEE_AXES.y + marge
	return (d.x * d.x) / (ax * ax) + (d.y * d.y) / (az * az) <= 1.0


## La montée du Capitole : de 0 (au Forum) à 1 (en haut).
func _avancee_clivus(p: Vector2) -> Vector2:
	var total := 0.0
	var longueurs: Array[float] = []
	for i in CLIVUS.size() - 1:
		longueurs.append((CLIVUS[i] as Vector2).distance_to(CLIVUS[i + 1]))
		total += longueurs[i]
	var meilleure := INF
	var avancee := 0.0
	var parcouru := 0.0
	for i in CLIVUS.size() - 1:
		var a: Vector2 = CLIVUS[i]
		var b: Vector2 = CLIVUS[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var d := p.distance_to(a.lerp(b, t))
		if d < meilleure:
			meilleure = d
			avancee = (parcouru + t * longueurs[i]) / total
		parcouru += longueurs[i]
	return Vector2(meilleure, avancee)


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var p := Vector2(x, z)
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var h := 0.6 + bruit * 1.2 + fin * 0.05
	# L'Esquilin, au sud-est, monte doucement vers l'entrée.
	h += smoothstep(60.0, 150.0, x) * smoothstep(20.0, 150.0, z) * 5.0
	# Le Capitole : une colline à pic, au sommet plat.
	var d_cap := p.distance_to(CAPITOLE)
	var h_cap := HAUT_CAPITOLE * (1.0 - smoothstep(20.0, 30.0, d_cap))
	h = maxf(h, h_cap + bruit * 0.3)
	# Le Palatin : un plateau sur de grands murs.
	h = maxf(h, 12.0 * _dans_rect(PALATIN, x, z, 4.0))
	# La montée du Capitole, taillée dans la colline.
	var c := _avancee_clivus(p)
	var largeur := 1.0 - smoothstep(3.0, 5.5, c.x)
	if largeur > 0.0:
		var h_rampe := lerpf(0.6, HAUT_CAPITOLE, smoothstep(0.0, 1.0, c.y))
		h = lerpf(h, h_rampe, largeur)
	# Les rues et les places, à plat.
	h = lerpf(h, 0.6 + bruit * 0.2, _dans_rect(FORUM.grow(4.0), x, z, 6.0))
	h = lerpf(h, minf(h, 1.5 + smoothstep(60.0, 150.0, x) * smoothstep(20.0, 150.0, z) * 5.0), (1.0 - smoothstep(4.0, 9.0, distance_rues(p))) * (1.0 - _dans_rect(PALATIN, x, z, 2.0)))
	if dans_colisee(p, 18.0):
		h = lerpf(h, 1.2, 1.0)
	return h + SOCLE


func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var rue := 1.0 - smoothstep(3.0, 6.0, distance_rues(p))
	var place := maxf(_dans_rect(FORUM, x, z, 2.0), 1.0 - smoothstep(4.0, 8.0, p.distance_to(PLACE_BLE)))
	place = maxf(place, 1.0 if dans_colisee(p, 16.0) else 0.0)
	var ville := maxf(_dans_rect(SUBURE, x, z, 4.0), _dans_rect(CHAMP_DE_MARS, x, z, 4.0))
	var tasse := maxf(maxf(place, ville), rue)
	var pres := (1.0 - tasse)
	return Color(rue * (1.0 - place), pres, maxf(place, ville * (1.0 - rue)), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_hasard.seed = graine
	_commencer()
	_construire_terrain()
	_construire_rues()
	_construire_colisee()
	_construire_colosse()
	_construire_forum()
	_construire_capitole()
	_construire_palatin()
	_construire_subure()
	_construire_champ_de_mars()
	_construire_vivarium()
	_construire_quartiers()
	_construire_vegetation()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _construire_rues() -> void:
	var rues := Node3D.new()
	rues.name = "Rues"
	_contenu.add_child(rues)
	_voie(rues, RUE_ESQUILIN, 6.0)
	_voie(rues, VOIE_SACREE, 6.0)
	_voie(rues, ARGILETE, 4.6)
	_voie(rues, RUE_COLOSSE, 4.6)
	# Le dallage de travertin autour du Colisée et sur le Forum.
	var dalles := Node3D.new()
	dalles.name = "Dallages"
	rues.add_child(dalles)
	var travertin := _mat_travertin()
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var pts: Array[Vector3] = []
		for a: float in [a0, a1]:
			for marge: float in [0.0, 16.0]:
				var q := COLISEE + Vector2(cos(a) * (COLISEE_AXES.x + marge), sin(a) * (COLISEE_AXES.y + marge))
				pts.append(Vector3(q.x, hauteur(q.x, q.y) + 0.05, q.y))
		outil.set_normal(Vector3.UP)
		outil.add_vertex(pts[0])
		outil.add_vertex(pts[1])
		outil.add_vertex(pts[3])
		outil.add_vertex(pts[0])
		outil.add_vertex(pts[3])
		outil.add_vertex(pts[2])
	outil.generate_normals()
	var piazza := MeshInstance3D.new()
	piazza.name = "PlaceDuColisee"
	piazza.mesh = outil.commit()
	piazza.material_override = _mat_paves()
	dalles.add_child(piazza)
	var forum := _boite(Vector3(FORUM.size.x, 0.2, FORUM.size.y), Vector3(FORUM.get_center().x, hauteur(FORUM.get_center().x, FORUM.get_center().y) + 0.0, FORUM.get_center().y), travertin, dalles, false)
	forum.name = "DallageForum"


# --- Le Colisée ---------------------------------------------------------------------------

## L'amphithéâtre flavien : trois étages d'arcades (doriques, ioniques, corinthiennes) et
## l'attique, tout en travertin. On ne peut pas y entrer d'ici (on y descendra par les
## égouts, au chapitre 8) : les arches du bas sont fermées par des grilles.
func _construire_colisee() -> void:
	var colisee := Node3D.new()
	colisee.name = "Colisee"
	_contenu.add_child(colisee)
	var travertin := _mat_travertin()
	var cintre := _mat_deux_faces(travertin)
	var sol := hauteur(COLISEE.x, COLISEE.y)
	var travees := 64
	var etage := (COLISEE_HAUT - 8.0) / 3.0
	var profondeur := 4.0
	var grille := StandardMaterial3D.new()
	grille.albedo_color = Color(0.12, 0.1, 0.09)
	grille.metallic = 0.6
	grille.roughness = 0.5
	var ombre := _mat_pbr("", Color(0.08, 0.07, 0.06), 1.0)
	for i in travees:
		var a := TAU * (i + 0.5) / travees
		var a0 := TAU * i / travees
		var a1 := TAU * (i + 1) / travees
		var p0 := COLISEE + Vector2(cos(a0) * COLISEE_AXES.x, sin(a0) * COLISEE_AXES.y)
		var p1 := COLISEE + Vector2(cos(a1) * COLISEE_AXES.x, sin(a1) * COLISEE_AXES.y)
		var c := (p0 + p1) * 0.5
		var d := p1 - p0
		var largeur := d.length()
		var angle := atan2(d.x, d.y)
		var pilier := 1.6
		var portee := largeur - pilier
		for niveau in 3:
			var bas := sol + niveau * etage
			var naissance := bas + etage * 0.62
			# Le pilier (à gauche de la travée) et sa demi-colonne engagée.
			var pp := p0 + d.normalized() * pilier * 0.5
			var bloc := _boite(Vector3(profondeur, naissance - bas, pilier), Vector3(pp.x, (bas + naissance) * 0.5, pp.y), travertin, colisee, niveau == 0)
			bloc.rotation.y = angle
			var dehors := (c - COLISEE).normalized()
			var colonne := MeshInstance3D.new()
			colonne.mesh = _cylindre(0.42, 0.45, etage * 0.86, 10)
			colonne.material_override = travertin
			colonne.position = Vector3(pp.x + dehors.x * (profondeur * 0.5), bas + etage * 0.43, pp.y + dehors.y * (profondeur * 0.5))
			colisee.add_child(colonne)
			# Le cintre de l'arche et le plein au-dessus du pilier.
			var arche := MeshInstance3D.new()
			arche.mesh = _maillage_arche(portee, profondeur, etage * 0.38)
			arche.material_override = cintre
			var ca := c + d.normalized() * pilier * 0.5
			arche.position = Vector3(ca.x, naissance, ca.y)
			arche.rotation.y = angle - PI / 2
			colisee.add_child(arche)
			var plein := _boite(Vector3(profondeur, etage * 0.38, pilier), Vector3(pp.x, naissance + etage * 0.19, pp.y), travertin, colisee, false)
			plein.rotation.y = angle
			# L'entablement qui court tout autour, à chaque étage.
			var corniche := _boite(Vector3(profondeur + 0.6, 0.5, largeur + 0.05), Vector3(c.x, bas + etage - 0.25, c.y), travertin, colisee, false)
			corniche.rotation.y = angle
			if niveau == 0:
				# Les arches du bas : une grille de fer (fermées tant que les jeux n'ont pas commencé).
				var g := _boite(Vector3(0.1, naissance - bas + portee * 0.4, portee), Vector3(ca.x, (bas + naissance + portee * 0.4) * 0.5, ca.y), grille, colisee)
				g.rotation.y = angle
				# Le numéro de l'entrée gravé au-dessus (les spectateurs avaient un jeton numéroté).
			elif niveau > 0:
				# Aux étages, une statue dans chaque arche.
				if i % 2 == 0:
					var statue := MeshInstance3D.new()
					statue.mesh = _cylindre(0.3, 0.38, 2.4, 8)
					statue.material_override = _mat_marbre()
					statue.position = Vector3(ca.x + dehors.x * 1.2, bas + 1.5, ca.y + dehors.y * 1.2)
					colisee.add_child(statue)
		# L'attique : un mur plein avec des petites fenêtres carrées une travée sur deux, et
		# les consoles qui tenaient les mâts du velarium.
		var bas_attique := sol + etage * 3.0
		var mur := _boite(Vector3(profondeur - 0.4, 8.0, largeur + 0.05), Vector3(c.x, bas_attique + 4.0, c.y), travertin, colisee, false)
		mur.rotation.y = angle
		var dehors2 := (c - COLISEE).normalized()
		if i % 2 == 0:
			var fenetre := _boite(Vector3(0.1, 1.3, 1.4), Vector3(c.x + dehors2.x * (profondeur * 0.5 - 0.15), bas_attique + 4.0, c.y + dehors2.y * (profondeur * 0.5 - 0.15)), ombre, colisee, false)
			fenetre.rotation.y = angle
		var mat := MeshInstance3D.new()
		mat.mesh = _cylindre(0.12, 0.14, 4.0, 6)
		mat.material_override = _mat_bois()
		mat.position = Vector3(c.x + dehors2.x * (profondeur * 0.5 + 0.2), bas_attique + 9.5, c.y + dehors2.y * (profondeur * 0.5 + 0.2))
		colisee.add_child(mat)
	# Les gradins, vus d'en haut : une cuvette qui descend vers l'arène.
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 64
	var anneaux := [[1.0, COLISEE_HAUT - 0.5], [0.86, COLISEE_HAUT - 6.0], [0.62, 10.0], [0.42, 4.0]]
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		for k in anneaux.size() - 1:
			var r0: float = anneaux[k][0]
			var r1: float = anneaux[k + 1][0]
			var y0: float = sol + float(anneaux[k][1])
			var y1: float = sol + float(anneaux[k + 1][1])
			var q00 := Vector3(COLISEE.x + cos(a0) * COLISEE_AXES.x * r0, y0, COLISEE.y + sin(a0) * COLISEE_AXES.y * r0)
			var q01 := Vector3(COLISEE.x + cos(a1) * COLISEE_AXES.x * r0, y0, COLISEE.y + sin(a1) * COLISEE_AXES.y * r0)
			var q10 := Vector3(COLISEE.x + cos(a0) * COLISEE_AXES.x * r1, y1, COLISEE.y + sin(a0) * COLISEE_AXES.y * r1)
			var q11 := Vector3(COLISEE.x + cos(a1) * COLISEE_AXES.x * r1, y1, COLISEE.y + sin(a1) * COLISEE_AXES.y * r1)
			for v in [q00, q10, q11, q00, q11, q01]:
				outil.set_uv(Vector2((v as Vector3).x, (v as Vector3).z) * 0.25)
				outil.add_vertex(v)
	outil.generate_normals()
	var gradins := MeshInstance3D.new()
	gradins.name = "Gradins"
	gradins.mesh = outil.commit()
	gradins.material_override = _mat_deux_faces(travertin)
	colisee.add_child(gradins)
	var arene := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 1.0
	disque.bottom_radius = 1.0
	disque.height = 0.2
	disque.radial_segments = 48
	arene.mesh = disque
	arene.scale = Vector3(COLISEE_AXES.x * 0.42, 1.0, COLISEE_AXES.y * 0.42)
	arene.position = Vector3(COLISEE.x, sol + 4.0, COLISEE.y)
	arene.material_override = _mat_choix(["dry_ground_01", "brown_mud_02"], Color(0.82, 0.7, 0.5), 1.0, 2.0)
	colisee.add_child(arene)
	# Un mur intérieur (invisible) : on ne passe pas à travers la façade.
	for i in 32:
		var a0 := TAU * i / 32
		var a1 := TAU * (i + 1) / 32
		var p0 := COLISEE + Vector2(cos(a0), sin(a0)) * COLISEE_AXES * 0.93
		var p1 := COLISEE + Vector2(cos(a1), sin(a1)) * COLISEE_AXES * 0.93
		var dd := p1 - p0
		_mur_invisible(colisee, Vector3(1.0, 40.0, dd.length() + 0.5), Vector3((p0.x + p1.x) * 0.5, sol + 20.0, (p0.y + p1.y) * 0.5), atan2(dd.x, dd.y))
	_fusionner(colisee)


# --- Le Colosse -----------------------------------------------------------------------------

## Le Colosse de Néron : trente mètres de bronze doré. Vespasien lui a donné une couronne de
## rayons et en a fait le dieu Soleil. Debout, la main droite sur un gouvernail.
func _construire_colosse() -> void:
	var colosse := Node3D.new()
	colosse.name = "Colosse"
	var sol := hauteur(COLOSSE.x, COLOSSE.y)
	colosse.position = Vector3(COLOSSE.x, sol, COLOSSE.y)
	colosse.rotation.y = PI * 0.15
	_contenu.add_child(colosse)
	var bronze := _mat_bronze()
	# Le socle de brique revêtu de marbre.
	_boite(Vector3(11, 7.0, 11), Vector3(0, 3.5, 0), _mat_marbre(), colosse)
	_boite(Vector3(12, 0.8, 12), Vector3(0, 7.2, 0), _mat_marbre(), colosse, false)
	# Le corps de bronze (voir ile_rome.gd), posé sur le socle : trente mètres en tout.
	var corps := Node3D.new()
	corps.position.y = 7.6
	colosse.add_child(corps)
	_corps_colosse(corps, 1.08, bronze)
	_fusionner(colosse)


# --- Le Forum -------------------------------------------------------------------------------

## Un temple romain : un haut podium, un grand escalier devant, des colonnes sur la
## façade (corinthiennes), la cella derrière, un fronton. La façade regarde vers +Z local.
func _temple_romain(parent: Node3D, centre: Vector2, largeur: float, longueur: float, haut_col: float, angle := 0.0, podium := 3.5, materiau: Material = null) -> Node3D:
	var t := Node3D.new()
	t.name = "Temple"
	t.position = Vector3(centre.x, hauteur(centre.x, centre.y), centre.y)
	t.rotation.y = angle
	parent.add_child(t)
	var marbre := materiau if materiau != null else _mat_marbre()
	_boite(Vector3(largeur, podium, longueur), Vector3(0, podium * 0.5, 0), _mat_tuf(), t)
	_boite(Vector3(largeur + 0.3, 0.3, longueur + 0.3), Vector3(0, podium - 0.1, 0), marbre, t, false)
	# L'escalier : des marches jusqu'au podium, sur toute la façade.
	var marches := int(podium / 0.3)
	for k in marches:
		_boite(Vector3(largeur * 0.8, 0.3, 0.45), Vector3(0, 0.15 + k * 0.3, longueur * 0.5 + (marches - k) * 0.45 - 0.2), marbre, t)
	# La cella (le mur plein), derrière le porche.
	var porche := minf(longueur * 0.35, 3.0 * haut_col / 4.0)
	_boite(Vector3(largeur - 1.2, haut_col, longueur - porche - 0.6), Vector3(0, podium + haut_col * 0.5, -porche * 0.5), marbre, t)
	# Les colonnes de la façade et du porche.
	var n := maxi(4, int(largeur / 2.6) + 1)
	for rang in 2:
		for k in n:
			var x := lerpf(-largeur * 0.5 + 0.7, largeur * 0.5 - 0.7, float(k) / (n - 1))
			_colonne(t, Vector3(x, podium, longueur * 0.5 - 0.7 - rang * porche * 0.6), haut_col, haut_col / 18.0, marbre)
	# L'entablement et le fronton.
	_boite(Vector3(largeur + 0.2, 1.2, longueur + 0.2), Vector3(0, podium + haut_col + 0.6, 0), marbre, t, false)
	var fronton := MeshInstance3D.new()
	var prisme := PrismMesh.new()
	prisme.size = Vector3(largeur + 0.4, largeur * 0.22, 0.6)
	fronton.mesh = prisme
	fronton.material_override = marbre
	fronton.position = Vector3(0, podium + haut_col + 1.2 + largeur * 0.11, longueur * 0.5)
	t.add_child(fronton)
	var toit := Node3D.new()
	toit.position = Vector3(0, podium + haut_col + 1.2, 0)
	t.add_child(toit)
	_toit(toit, Vector3.ZERO, largeur + 0.2, longueur, atan(0.44))
	return t


## Une basilique : une grande salle couverte, avec une façade de deux étages d'arcades
## (pour les tribunaux, les affaires, la foule qui se met à l'ombre). Façade vers +Z local.
func _basilique(parent: Node3D, centre: Vector2, longueur: float, profondeur: float, angle := 0.0) -> Node3D:
	var b := Node3D.new()
	b.name = "Basilique"
	b.position = Vector3(centre.x, hauteur(centre.x, centre.y), centre.y)
	b.rotation.y = angle
	parent.add_child(b)
	var marbre := _mat_marbre()
	var cintre := _mat_deux_faces(marbre)
	var etage := 6.5
	_boite(Vector3(longueur, 0.6, profondeur), Vector3(0, 0.3, 0), marbre, b)
	_boite(Vector3(longueur, etage * 2.4, profondeur - 4.0), Vector3(0, 0.6 + etage * 1.2, -2.0), _mat_brique(), b)
	var n := int(longueur / 4.2)
	var travee := longueur / n
	for niveau in 2:
		var bas := 0.6 + niveau * etage
		for k in n + 1:
			var x := -longueur * 0.5 + k * travee
			_boite(Vector3(1.2, etage * 0.6, 1.2), Vector3(x, bas + etage * 0.3, profondeur * 0.5 - 0.6), marbre, b, niveau == 0)
			if k < n:
				var arche := MeshInstance3D.new()
				arche.mesh = _maillage_arche(travee - 1.2, 1.2, etage * 0.4)
				arche.material_override = cintre
				arche.position = Vector3(x + travee * 0.5, bas + etage * 0.6, profondeur * 0.5 - 0.6)
				b.add_child(arche)
		_boite(Vector3(longueur + 0.2, 0.4, 1.6), Vector3(0, bas + etage - 0.2, profondeur * 0.5 - 0.6), marbre, b, false)
	var toit := Node3D.new()
	toit.position = Vector3(0, 0.6 + etage * 2.4, 0)
	toit.rotation.y = PI / 2
	b.add_child(toit)
	_toit(toit, Vector3.ZERO, profondeur, longueur, 0.28)
	return b


func _construire_forum() -> void:
	var forum := Node3D.new()
	forum.name = "Forum"
	_contenu.add_child(forum)
	var f := FORUM
	# Au nord, la basilique Émilienne ; au sud, la basilique Julienne.
	_basilique(forum, Vector2(f.get_center().x, f.position.y - 9.0), 60.0, 16.0, 0.0)
	_basilique(forum, Vector2(f.get_center().x, f.end.y + 9.0), 60.0, 16.0, PI)
	# À l'ouest, au pied du Capitole : le temple de Saturne (le trésor de Rome) et les Rostres.
	_temple_romain(forum, Vector2(f.position.x - 6.0, f.end.y - 2.0), 12.0, 20.0, 11.0, PI / 2, 5.0)
	var rostres := _boite(Vector3(4.0, 3.0, 18.0), Vector3(f.position.x + 3.0, hauteur(f.position.x + 3.0, f.get_center().y) + 1.5, f.get_center().y), _mat_tuf(), forum)
	rostres.name = "Rostres"
	for k in 5:
		var proue := _boite(Vector3(0.8, 0.8, 1.6), Vector3(f.position.x + 5.2, rostres.position.y + 0.2, f.get_center().y - 7.0 + k * 3.5), _mat_bronze(), forum, false)
		proue.rotation.y = PI / 2
	# À l'est : le temple de César divinisé, le temple rond de Vesta, celui de Castor et Pollux.
	_temple_romain(forum, Vector2(f.end.x + 6.0, f.get_center().y), 14.0, 18.0, 9.0, -PI / 2, 3.5)
	_temple_romain(forum, Vector2(f.end.x - 18.0, f.end.y + 24.0), 14.0, 24.0, 12.5, 0.0, 6.0)
	var vesta := Node3D.new()
	vesta.name = "TempleDeVesta"
	var pv := Vector2(f.end.x + 2.0, f.end.y + 10.0)
	vesta.position = Vector3(pv.x, hauteur(pv.x, pv.y), pv.y)
	forum.add_child(vesta)
	var socle := MeshInstance3D.new()
	socle.mesh = _cylindre(7.0, 7.2, 2.0, 32)
	socle.material_override = _mat_marbre()
	socle.position.y = 1.0
	vesta.add_child(socle)
	var cella := MeshInstance3D.new()
	cella.mesh = _cylindre(5.0, 5.0, 7.0, 32)
	cella.material_override = _mat_marbre()
	cella.position.y = 5.5
	vesta.add_child(cella)
	for k in 20:
		var a := TAU * k / 20.0
		_colonne(vesta, Vector3(cos(a) * 6.3, 2.0, sin(a) * 6.3), 7.5, 0.35)
	var dome := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 7.4
	cone.height = 2.6
	cone.radial_segments = 32
	dome.mesh = cone
	dome.material_override = _mat_bronze()
	dome.position.y = 10.8
	vesta.add_child(dome)
	# La Curie (le sénat), au nord-ouest de la place.
	var curie := _batiment_romain(forum, Vector2(f.position.x + 6.0, f.position.y - 22.0), Vector3(18, 16, 26), 0.0, Color(0.9, 0.86, 0.78))
	curie.name = "Curie"
	# Des statues sur des colonnes honorifiques et des piédestaux.
	for k in 6:
		var p := Vector2(f.position.x + 12.0 + k * 10.0, f.get_center().y + (3.0 if k % 2 == 0 else -3.0))
		var y := hauteur(p.x, p.y)
		_boite(Vector3(1.4, 2.4, 1.4), Vector3(p.x, y + 1.2, p.y), _mat_marbre(), forum)
		var s := MeshInstance3D.new()
		s.mesh = _cylindre(0.3, 0.4, 2.2, 8)
		s.material_override = _mat_bronze()
		s.position = Vector3(p.x, y + 3.5, p.y)
		forum.add_child(s)
	_fusionner(forum)


# --- Le Capitole ------------------------------------------------------------------------------

func _construire_capitole() -> void:
	var capitole := Node3D.new()
	capitole.name = "Capitole"
	_contenu.add_child(capitole)
	# Le temple de Jupiter Très Bon Très Grand : le plus grand de Rome.
	var temple := _temple_romain(capitole, CAPITOLE + Vector2(2, -6), 30.0, 36.0, 15.0, PI * 0.5, 4.0)
	temple.name = "TempleDeJupiter"
	# Les murs de soutènement en tuf, au bord de la colline.
	var tuf := _mat_tuf()
	for k in 24:
		var a := TAU * k / 24.0
		var p := CAPITOLE + Vector2(cos(a), sin(a)) * 21.0
		var c := _avancee_clivus(p)
		if c.x < 6.0:
			continue
		var mur := _boite(Vector3(1.6, HAUT_CAPITOLE - 1.0, 6.0), Vector3(p.x, SOCLE + HAUT_CAPITOLE * 0.5, p.y), tuf, capitole)
		mur.rotation.y = -a
	# L'enclos des oies sacrées de Junon, à côté du temple.
	var y := hauteur(CAPITOLE.x - 10.0, CAPITOLE.y + 12.0)
	for k in 8:
		var a := TAU * k / 8.0
		_boite(Vector3(0.12, 0.5, 3.0), Vector3(CAPITOLE.x - 10.0 + cos(a) * 3.5, y + 0.25, CAPITOLE.y + 12.0 + sin(a) * 3.5), _mat_bois(), capitole, false).rotation.y = -a
	_fusionner(capitole)


# --- Le Palatin -------------------------------------------------------------------------------

func _construire_palatin() -> void:
	var palatin := Node3D.new()
	palatin.name = "Palatin"
	_contenu.add_child(palatin)
	var r := PALATIN
	var brique := _mat_brique()
	var cintre := _mat_deux_faces(brique)
	# Les grands murs de soutènement, percés d'arches aveugles.
	for cote in 4:
		var long := r.size.x if cote < 2 else r.size.y
		var n := int(long / 6.0)
		for k in n:
			var t := (k + 0.5) / n
			var p: Vector2
			var angle := 0.0
			match cote:
				0: p = Vector2(r.position.x + t * r.size.x, r.position.y); angle = PI / 2
				1: p = Vector2(r.position.x + t * r.size.x, r.end.y); angle = PI / 2
				2: p = Vector2(r.position.x, r.position.y + t * r.size.y); angle = 0.0
				_: p = Vector2(r.end.x, r.position.y + t * r.size.y); angle = 0.0
			var bas := SOCLE + 0.6
			var pilier := _boite(Vector3(2.2, 12.5, 1.6), Vector3(p.x, bas + 6.0, p.y) + (Vector3(-long / n * 0.5, 0, 0) if angle != 0.0 else Vector3(0, 0, -long / n * 0.5)), brique, palatin)
			pilier.rotation.y = angle
			var arche := MeshInstance3D.new()
			arche.mesh = _maillage_arche(long / n - 1.6, 2.2, 4.0)
			arche.material_override = cintre
			arche.position = Vector3(p.x, bas + 8.0, p.y)
			arche.rotation.y = angle - PI / 2 if angle != 0.0 else PI / 2
			palatin.add_child(arche)
			var fond := _boite(Vector3(1.0, 12.5, long / n), Vector3(p.x, bas + 6.0, p.y), _mat_pbr("", Color(0.18, 0.12, 0.1), 1.0), palatin)
			fond.rotation.y = angle
	# Les palais, en haut : de grandes salles de brique et des portiques.
	var y := SOCLE + 12.0
	for b in [[Vector2(-60, 20), Vector3(26, 12, 18)], [Vector2(-34, 28), Vector3(18, 9, 22)], [Vector2(-70, 38), Vector3(16, 8, 12)]]:
		var bat := _batiment_romain(palatin, b[0], b[1], 0.0, Color(0.88, 0.8, 0.68))
		bat.position.y = y - 0.3
	_portique(palatin, Vector2(-50, r.position.y + 3.0), 30.0, 5.0, PI, 5.0)
	for p in palatin.get_children():
		if p.name.begins_with("Portique"):
			(p as Node3D).position.y = y
	for k in 6:
		var pin := Vector2(r.position.x + 6.0 + k * 10.0, r.end.y - 4.0)
		_pin_parasol(palatin, pin, _hasard, 0.9)
	_fusionner(palatin)


# --- La Subure --------------------------------------------------------------------------------

## Un immeuble (une « insula ») : boutiques au rez-de-chaussée, ouvertes sur la rue, et
## trois ou quatre étages d'appartements en brique, avec des balcons de bois.
func _insula(parent: Node3D, centre: Vector2, taille: Vector2, etages: int, angle := 0.0) -> Node3D:
	var b := Node3D.new()
	b.name = "Insula"
	b.position = Vector3(centre.x, hauteur(centre.x, centre.y), centre.y)
	b.rotation.y = angle
	parent.add_child(b)
	var haut_etage := 3.2
	var haut := 3.8 + etages * haut_etage
	var enduit := _mat_enduit_peint([Color(0.86, 0.58, 0.36), Color(0.9, 0.74, 0.48), Color(0.74, 0.34, 0.22), Color(0.9, 0.8, 0.6)][_hasard.randi() % 4])
	var brique := _mat_brique()
	var ombre := _mat_pbr("", Color(0.06, 0.05, 0.045), 1.0)
	_boite(Vector3(taille.x, 3.8, taille.y), Vector3(0, 1.6, 0), enduit, b)
	_boite(Vector3(taille.x - 0.05, haut - 3.8, taille.y - 0.05), Vector3(0, 3.5 + (haut - 3.8) * 0.5, 0), brique, b)
	# Les boutiques sur les quatre côtés : de grandes ouvertures sombres, un comptoir.
	for face in 4:
		var long := taille.x if face < 2 else taille.y
		var n := maxi(1, int(long / 4.5))
		for k in n:
			var t := lerpf(-long * 0.5 + long / n * 0.5, long * 0.5 - long / n * 0.5, float(k) / maxf(1.0, n - 1)) if n > 1 else 0.0
			var pos: Vector3
			var rot := 0.0
			match face:
				0: pos = Vector3(t, 1.4, taille.y * 0.5 + 0.03)
				1: pos = Vector3(t, 1.4, -taille.y * 0.5 - 0.03); rot = PI
				2: pos = Vector3(taille.x * 0.5 + 0.03, 1.4, t); rot = PI / 2
				_: pos = Vector3(-taille.x * 0.5 - 0.03, 1.4, t); rot = -PI / 2
			var ouverture := _boite(Vector3(2.6, 2.6, 0.05), pos, ombre, b, false)
			ouverture.rotation.y = rot
			_devanture(b, pos, rot, enduit, hash(Vector2i(roundi(centre.x * 10.0), roundi(centre.y * 10.0))) + face * 131 + k * 17)
			# Les fenêtres des étages, au-dessus de chaque boutique, avec leur appui.
			var dehors := Basis(Vector3.UP, rot) * Vector3.BACK
			for e in etages:
				var fenetre := _boite(Vector3(0.9, 1.1, 0.05), pos + Vector3(0, 3.8 + e * haut_etage, 0), ombre, b, false)
				fenetre.rotation.y = rot
				var appui := _boite(Vector3(1.15, 0.09, 0.22), pos + Vector3(0, 3.8 + e * haut_etage - 0.6, 0) + dehors * 0.08, brique, b, false)
				appui.rotation.y = rot
	# Un balcon de bois au premier étage, sur la façade.
	_boite(Vector3(taille.x * 0.8, 0.15, 1.1), Vector3(0, 4.4, taille.y * 0.5 + 0.55), _mat_bois(), b, false)
	for k in 5:
		_boite(Vector3(0.1, 1.0, 0.1), Vector3(lerpf(-taille.x * 0.4, taille.x * 0.4, k / 4.0), 4.9, taille.y * 0.5 + 1.05), _mat_bois(), b, false)
	# Le toit de tuiles, presque plat.
	var toit := Node3D.new()
	toit.position = Vector3(0, haut - 0.3, 0)
	b.add_child(toit)
	_toit(toit, Vector3.ZERO, taille.x, taille.y, 0.22)
	return b


## La devanture d'une boutique (taberna) : linteau de bois, et selon la boutique un comptoir
## maçonné, des amphores, une toile tendue. Hasard propre à la boutique (ne décale pas _hasard).
func _devanture(b: Node3D, pos: Vector3, rot: float, enduit: Material, graine_d: int) -> void:
	var h := RandomNumberGenerator.new()
	h.seed = graine_d
	var base := Basis(Vector3.UP, rot)
	var dehors := base * Vector3.BACK
	var lateral := base * Vector3.RIGHT
	var sol := Vector3(pos.x, 0.0, pos.z)
	var linteau := _boite(Vector3(3.0, 0.22, 0.22), pos + Vector3(0, 1.42, 0) + dehors * 0.08, _mat_bois(), b, false)
	linteau.rotation.y = rot
	var genre := h.randi() % 4
	if genre <= 1:
		# Comptoir maçonné en L, comme à Pompéi et Herculanum.
		var comptoir := _boite(Vector3(1.5, 0.95, 0.55), sol + Vector3(0, 0.47, 0) + dehors * 0.32 - lateral * 0.45, enduit, b, false)
		comptoir.rotation.y = rot
		var dessus := _boite(Vector3(1.6, 0.06, 0.62), sol + Vector3(0, 0.97, 0) + dehors * 0.32 - lateral * 0.45, _mat_travertin(), b, false)
		dessus.rotation.y = rot
		for j in h.randi_range(1, 3):
			_amphore(b, sol + Vector3(0, 1.0, 0) + dehors * 0.3 - lateral * (0.9 - j * 0.35), 0.38, h.randf() * TAU)
	if genre >= 1:
		# Des amphores posées contre le mur, à côté de l'entrée.
		var cote := -1.0 if h.randf() < 0.5 else 1.0
		for j in h.randi_range(1, 3):
			_amphore(b, sol + dehors * (0.35 + h.randf() * 0.1) + lateral * cote * (1.55 + j * 0.42), h.randf_range(0.75, 0.9), h.randf() * TAU)
	if genre == 3 or h.randf() < 0.25:
		# Une toile tendue au-dessus de l'entrée (l'ombre de l'après-midi).
		var couleurs := [Color(0.78, 0.7, 0.52), Color(0.62, 0.3, 0.2), Color(0.72, 0.62, 0.42), Color(0.5, 0.46, 0.38)]
		var toile := _boite(Vector3(3.0, 0.03, 1.3), pos + Vector3(0, 1.62, 0) + dehors * 0.68, _mat_pbr("", couleurs[h.randi() % couleurs.size()], 0.95), b, false)
		toile.rotation = Vector3(0.0, rot, 0.0)
		toile.rotate_object_local(Vector3.RIGHT, 0.22)


func _construire_subure() -> void:
	var subure := Node3D.new()
	subure.name = "Subure"
	_contenu.add_child(subure)
	var r := SUBURE
	# Un quadrillage serré : îlots de 16 × 14 m, ruelles de 4 m.
	var ilot := Vector2(16, 14)
	var ruelle := 4.5
	var x := r.position.x + ilot.x * 0.5
	while x < r.end.x:
		var z := r.position.y + ilot.y * 0.5
		while z < r.end.y:
			var p := Vector2(x, z)
			if p.distance_to(PLACE_BLE) > 17.0 and _distance_ligne(p, ARGILETE) > 9.0 and _distance_ligne(p, RUE_COLOSSE) > 9.0 \
					and absf(p.x) < 152.0 and p.y > -150.0:
				_insula(subure, p, ilot - Vector2(_hasard.randf_range(0.0, 2.0), _hasard.randf_range(0.0, 2.0)), _hasard.randi_range(3, 4))
			z += ilot.y + ruelle
		x += ilot.x + ruelle
	# La fontaine de la place (à sec), et des étals.
	var y := hauteur(PLACE_BLE.x, PLACE_BLE.y)
	var bassin := MeshInstance3D.new()
	bassin.mesh = _cylindre(1.6, 1.7, 0.8, 20)
	bassin.material_override = _mat_travertin()
	bassin.position = Vector3(PLACE_BLE.x + 4.0, y + 0.4, PLACE_BLE.y - 2.0)
	subure.add_child(bassin)
	_auvent(subure, PLACE_BLE + Vector2(12, 8), Vector2(4.0, 3.0), 2.6, Color(0.7, 0.3, 0.2))
	_auvent(subure, PLACE_BLE + Vector2(-12, -8), Vector2(4.0, 3.0), 2.6, Color(0.5, 0.4, 0.25))
	_fusionner(subure)


# --- Les autres quartiers ---------------------------------------------------------------------

## Les points où l'on ne bâtit pas : les lieux de la quête, les camps, les monuments.
var _batiments: Array[Rect2] = []


func _terrain_libre(p: Vector2, marge: float) -> bool:
	if absf(p.x) > 146.0 - marge or absf(p.y) > 146.0 - marge:
		return false
	if distance_rues(p) < 6.5 + marge or dans_colisee(p, 24.0) or p.distance_to(COLOSSE) < 12.0 + marge:
		return false
	for r: Rect2 in [FORUM.grow(26.0), SUBURE.grow(2.0), CHAMP_DE_MARS.grow(4.0), PALATIN.grow(5.0), VIVARIUM.grow(8.0)]:
		if r.grow(marge).has_point(p):
			return false
	if p.distance_to(CAPITOLE) < 32.0 + marge or _avancee_clivus(p).x < 8.0 + marge:
		return false
	for q: Vector2 in [ENTREE, LIVIA, CARPOPHORE, CAGE_RHINO, SORTIE_SUD, LUCRETIUS, JANUS, PORTAIL_QG] + VIGILES + FEUX:
		if p.distance_to(q) < 10.0 + marge:
			return false
	if p.distance_to(ARENE_RHINO) < 22.0 + marge:
		return false
	for camp in [Vector2(30, -150), Vector2(-60, -150), Vector2(-140, -110), Vector2(140, 40), Vector2(100, -90)]:
		if p.distance_to(camp) < 8.0 + marge:
			return false
	return true


## Le reste de la ville : des maisons basses (domus) et des immeubles le long des rues,
## avec des jardins entre eux, pour que Rome soit pleine jusqu'aux limites de la zone.
func _construire_quartiers() -> void:
	var quartiers := Node3D.new()
	quartiers.name = "Quartiers"
	_batiments.clear()
	_contenu.add_child(quartiers)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var pas := 19.0
	var x := -146.0
	while x < 146.0:
		var z := -146.0
		while z < 146.0:
			var p := Vector2(x, z) + Vector2(hasard.randf_range(-2.5, 2.5), hasard.randf_range(-2.5, 2.5))
			var taille := Vector2(hasard.randf_range(10.0, 15.0), hasard.randf_range(9.0, 14.0))
			z += pas
			if hasard.randf() < 0.18 or not _terrain_libre(p, taille.length() * 0.5):
				continue
			# Une pente trop forte (le bord d'une colline) : pas de maison.
			var h := [hauteur(p.x - taille.x * 0.5, p.y - taille.y * 0.5), hauteur(p.x + taille.x * 0.5, p.y + taille.y * 0.5),
					hauteur(p.x + taille.x * 0.5, p.y - taille.y * 0.5), hauteur(p.x - taille.x * 0.5, p.y + taille.y * 0.5)]
			if h.max() - h.min() > 2.5:
				continue
			# Le long d'une rue, la façade regarde la rue.
			var angle := hasard.randf_range(-0.08, 0.08)
			if hasard.randf() < 0.45:
				_insula(quartiers, p, taille, hasard.randi_range(2, 4), angle)
			else:
				var teinte: Color = [Color(0.86, 0.72, 0.52), Color(0.9, 0.82, 0.66), Color(0.78, 0.5, 0.36), Color(0.88, 0.76, 0.6)][hasard.randi() % 4]
				_batiment_romain(quartiers, p, Vector3(taille.x, hasard.randf_range(5.0, 8.0), taille.y), angle, teinte)
			_batiments.append(Rect2(p - taille * 0.5, taille))
		x += pas
	_fusionner(quartiers)


# --- Le Champ de Mars ------------------------------------------------------------------------

func _construire_champ_de_mars() -> void:
	var champ := Node3D.new()
	champ.name = "ChampDeMars"
	_contenu.add_child(champ)
	# Le Panthéon d'Agrippa : un temple rectangulaire au grand porche (celui d'aujourd'hui,
	# avec sa coupole, sera rebâti par Hadrien, quarante ans plus tard).
	var pantheon := _temple_romain(champ, PANTHEON, 22.0, 30.0, 12.0, PI, 2.0)
	pantheon.name = "Pantheon"
	# Des portiques et des jardins, des maisons basses.
	_portique(champ, Vector2(-90, -108), 40.0, 6.0, PI, 5.0)
	for k in 6:
		var p := Vector2(_hasard.randf_range(CHAMP_DE_MARS.position.x + 8.0, CHAMP_DE_MARS.end.x - 8.0), _hasard.randf_range(CHAMP_DE_MARS.position.y + 6.0, CHAMP_DE_MARS.end.y - 6.0))
		if p.distance_to(PANTHEON) < 24.0 or p.distance_to(JANUS) < 14.0 or p.distance_to(PORTAIL_QG) < 14.0 \
				or FEUX.any(func(f: Vector2) -> bool: return p.distance_to(f) < 12.0):
			continue
		_insula(champ, p, Vector2(14, 12), 2)
	_fusionner(champ)


# --- Le vivarium ------------------------------------------------------------------------------

## Le vivarium : un enclos de murs où l'on garde les bêtes des jeux dans des cages. Les
## portes des cages sont ouvertes (quelqu'un les a ouvertes).
func _construire_vivarium() -> void:
	var vivarium := Node3D.new()
	vivarium.name = "Vivarium"
	_contenu.add_child(vivarium)
	var r := VIVARIUM
	var y := hauteur(r.get_center().x, r.get_center().y)
	var mur := _mat_tuf()
	_boite(Vector3(0.8, 3.5, r.size.y), Vector3(r.end.x, y + 1.75, r.get_center().y), mur, vivarium)
	_boite(Vector3(r.size.x, 3.5, 0.8), Vector3(r.get_center().x, y + 1.75, r.position.y), mur, vivarium)
	_boite(Vector3(r.size.x, 3.5, 0.8), Vector3(r.get_center().x, y + 1.75, r.end.y), mur, vivarium)
	# Le mur ouest a une grande porte.
	_boite(Vector3(0.8, 3.5, r.size.y * 0.35), Vector3(r.position.x, y + 1.75, r.position.y + r.size.y * 0.175), mur, vivarium)
	_boite(Vector3(0.8, 3.5, r.size.y * 0.35), Vector3(r.position.x, y + 1.75, r.end.y - r.size.y * 0.175), mur, vivarium)
	var fer := StandardMaterial3D.new()
	fer.albedo_color = Color(0.16, 0.14, 0.13)
	fer.metallic = 0.7
	fer.roughness = 0.45
	# Les cages contre le mur est : des barreaux de fer, et la porte grande ouverte.
	for k in 4:
		var cz := r.position.y + 4.0 + k * 6.6
		var cx := r.end.x - 3.0
		_boite(Vector3(4.6, 0.2, 5.6), Vector3(cx, y + 3.0, cz), _mat_bois(), vivarium, false)
		for b in 9:
			var bz := cz - 2.6 + b * 0.65
			if b >= 3 and b <= 5:
				continue
			_boite(Vector3(0.07, 3.0, 0.07), Vector3(cx - 2.3, y + 1.5, bz), fer, vivarium, false)
		var porte := _boite(Vector3(0.07, 3.0, 1.95), Vector3(cx - 3.2, y + 1.5, cz + 1.4), fer, vivarium, false)
		porte.rotation.y = 1.2
		# De la paille sur le sol de la cage.
		_boite(Vector3(4.0, 0.06, 5.0), Vector3(cx, y + 0.03, cz), _mat_choix(["dry_ground_01"], Color(0.8, 0.68, 0.36), 1.0, 1.0), vivarium, false)
	_fusionner(vivarium)


# --- Arbres -----------------------------------------------------------------------------------

func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Des pins et des cyprès sur les collines (Esquilin, Capitole), quelques platanes
	# (des oliviers ici) dans les jardins.
	var plantes := 0
	var essais := 0
	while plantes < 50 and essais < 1200:
		essais += 1
		var p := Vector2(hasard.randf_range(-150.0, 150.0), hasard.randf_range(-150.0, 150.0))
		if distance_rues(p) < 9.0 or dans_colisee(p, 22.0) or _dans_rect(FORUM.grow(30.0), p.x, p.y, 0.1) > 0.5 \
				or _dans_rect(SUBURE.grow(4.0), p.x, p.y, 0.1) > 0.5 or _dans_rect(VIVARIUM.grow(6.0), p.x, p.y, 0.1) > 0.5 \
				or p.distance_to(COLOSSE) < 14.0 or p.distance_to(CAPITOLE) < 24.0 or _dans_rect(PALATIN.grow(4.0), p.x, p.y, 0.1) > 0.5 \
				or _dans_rect(CHAMP_DE_MARS.grow(4.0), p.x, p.y, 0.1) > 0.5 or p.distance_to(ARENE_RHINO) < 18.0 or _avancee_clivus(p).x < 7.0 \
				or _batiments.any(func(r: Rect2) -> bool: return r.grow(3.0).has_point(p)):
			continue
		if hasard.randf() < 0.5:
			_pin_parasol(arbres, p, hasard, hasard.randf_range(0.85, 1.15))
		elif hasard.randf() < 0.5:
			_cypres(arbres, p, hasard)
		else:
			_olivier(arbres, p, hasard, hasard.randf_range(0.8, 1.1))
		plantes += 1


# --- Paysage lointain -----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	for bande: Array in [[Vector3(0, 2.8 + SOCLE, -1075), Vector2(4000, 1850)], [Vector3(0, 2.8 + SOCLE, 1075), Vector2(4000, 1850)],
			[Vector3(-1075, 2.8 + SOCLE, 0), Vector2(1850, 300)], [Vector3(1075, 2.8 + SOCLE, 0), Vector2(1850, 300)]]:
		_plan_lointain(bande[0], bande[1], Color(0, 1, 0))
	var lointain := Node3D.new()
	lointain.name = "VilleLointaine"
	_contenu.add_child(lointain)
	# La ville continue de tous côtés : des toits de tuiles, des immeubles, quelques temples.
	var enduit := _mat_enduit_peint(Color(0.84, 0.66, 0.46))
	var tuiles := _mat_tuiles()
	for k in 360:
		var a := hasard.randf() * TAU
		var r := hasard.randf_range(200.0, 900.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if x < -300.0 and absf(z) < 400.0:
			continue
		var t := Vector3(hasard.randf_range(10.0, 26.0), hasard.randf_range(6.0, 18.0), hasard.randf_range(10.0, 22.0))
		var bloc := _boite(t, Vector3(x, SOCLE + 2.8 + t.y * 0.5, z), enduit, lointain, false)
		bloc.rotation.y = hasard.randf() * PI
		var toit := _boite(Vector3(t.x + 1.0, 0.8, t.z + 1.0), Vector3(x, SOCLE + 2.8 + t.y + 0.4, z), tuiles, lointain, false)
		toit.rotation.y = bloc.rotation.y
	# Le Tibre, à l'ouest, et le Janicule au-delà.
	var tibre := _boite(Vector3(120, 0.2, 1600), Vector3(-380, SOCLE + 2.6, 0), _mat_pbr("", Color(0.26, 0.32, 0.26), 0.2), lointain, false)
	tibre.rotation.y = 0.15
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	bruit.seed = graine
	var janicule := MeshInstance3D.new()
	janicule.mesh = _maillage_bosse(bruit, Vector3(300, 80, 900), 1.4, 0.3, 28, Color(0, 0.6, 0.4))
	janicule.material_override = _mat_lointain()
	janicule.position = Vector3(-700, SOCLE - 5.0, 0)
	_contenu.add_child(janicule)
	for mi in lointain.get_children():
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fusionner(lointain)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 40, demi))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_pnj(dossier, "livia", LIVIA, -PI * 0.8)
	_pnj(dossier, "martial", MARTIAL, PI)
	_pnj(dossier, "frumentarius", FRUMENTARIUS, PI)
	var agitateur := _pnj(dossier, "agitateur", AGITATEUR, -PI / 2)
	agitateur.add_to_group("decor_quete")
	agitateur.set_meta("identifiant", "agitateur")
	_pnj(dossier, "carpophore", CARPOPHORE, PI * 0.3)
	# Les Égarés de la foule : on les renoue (puzzle de mots).
	for k in EGARES.size():
		var p: Vector2 = EGARES[k]
		_pnj(dossier, "egare_subure_%d" % (k + 1), p, TAU * k / EGARES.size())
		var renouer := ObjetRome.new()
		renouer.name = "RenouerSubure%d" % k
		renouer.identifiant = "renouer_subure_%d" % k
		renouer.groupe = "egare_subure"
		renouer.invite = "[F] Renouer (remettre ses mots dans l'ordre)"
		renouer.portee = 2.2
		renouer.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(renouer)
	# Le choix : la table des distributions (les jetons de blé), ou l'agitateur qui file.
	var table := ObjetRome.new()
	table.name = "TableBle"
	table.identifiant = "table_ble"
	table.invite = "[F] Organiser la distribution du blé"
	table.portee = 2.6
	table.position = Vector3(TABLE_BLE.x, hauteur(TABLE_BLE.x, TABLE_BLE.y), TABLE_BLE.y)
	dossier.add_child(table)
	_boite(Vector3(2.4, 0.9, 1.0), table.position + Vector3(0, 0.45, 0), _mat_bois(), dossier)
	var suivre := ObjetRome.new()
	suivre.name = "SuivreAgitateur"
	suivre.identifiant = "suivre_agitateur"
	suivre.invite = "[F] Suivre l'agitateur"
	suivre.portee = 3.0
	suivre.position = Vector3(AGITATEUR.x, hauteur(AGITATEUR.x, AGITATEUR.y), AGITATEUR.y)
	dossier.add_child(suivre)
	for k in SACS_BLE.size():
		var p: Vector2 = SACS_BLE[k]
		var sac := ObjetRome.new()
		sac.name = "SacBle%d" % k
		sac.identifiant = "sac_ble_%d" % k
		sac.groupe = "sac_ble"
		sac.forme = "sac"
		sac.invite = "[F] Donner un sac de blé"
		sac.portee = 2.2
		sac.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(sac)
	var oreillette := ObjetRome.new()
	oreillette.name = "OreilletteVigie"
	oreillette.identifiant = "oreillette_vigie"
	oreillette.forme = "radio_vigie"
	oreillette.invite = "[F] Ramasser l'objet tombé"
	oreillette.position = Vector3(OREILLETTE.x, hauteur(OREILLETTE.x, OREILLETTE.y), OREILLETTE.y)
	dossier.add_child(oreillette)
	var cage := ObjetRome.new()
	cage.name = "CageRhino"
	cage.identifiant = "cage_rhino"
	cage.invite = "[F] Examiner la cage ouverte"
	cage.portee = 3.0
	cage.position = Vector3(CAGE_RHINO.x, hauteur(CAGE_RHINO.x, CAGE_RHINO.y), CAGE_RHINO.y)
	dossier.add_child(cage)
	_construire_quete_incendie(dossier)
	_construire_quete_jeux(dossier)
	_construire_secondaires(dossier)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Amphithéâtre flavien (Colisée)", COLISEE)
	repere.call(MarqueurCarte.Type.LIEU, "Colosse", COLOSSE)
	repere.call(MarqueurCarte.Type.LIEU, "Forum", FORUM.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Capitole", CAPITOLE)
	repere.call(MarqueurCarte.Type.LIEU, "Palatin", PALATIN.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Subure", PLACE_BLE)
	repere.call(MarqueurCarte.Type.LIEU, "Champ de Mars", PANTHEON)
	repere.call(MarqueurCarte.Type.LIEU, "Vivarium", VIVARIUM.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Vers la Porta Maggiore", SORTIE_SUD)
	repere.call(MarqueurCarte.Type.LIEU, "Caserne des vigiles", LUCRETIUS)
	repere.call(MarqueurCarte.Type.LIEU, "Cloaca Maxima", EGOUT)


## Chapitre 7 : Martial devant l'amphithéâtre, les yeux du Colosse qui s'allument, et la
## bouche du grand égout (la Cloaca Maxima) avec son égoutier.
func _construire_quete_jeux(dossier: Node3D) -> void:
	var martial := _pnj(dossier, "martial_jeux", MARTIAL_JEUX, PI * 0.6)
	martial.add_to_group("decor_quete")
	martial.set_meta("identifiant", "martial_jeux")
	martial.visible = false
	_pnj(dossier, "egoutier", EGOUTIER, PI * 0.5)
	# La bouche de l'égout : un grand arc de pierre à demi enterré, fermé d'une grille.
	var egout := Node3D.new()
	egout.name = "CloacaMaxima"
	var sol := hauteur(EGOUT.x, EGOUT.y)
	egout.position = Vector3(EGOUT.x, sol, EGOUT.y)
	dossier.add_child(egout)
	var arche := MeshInstance3D.new()
	arche.mesh = _maillage_arche(3.4, 1.2, 1.8)
	arche.material_override = _mat_deux_faces(_mat_tuf())
	arche.position = Vector3(0, 0.4, 0)
	egout.add_child(arche)
	for x: float in [-2.2, 2.2]:
		_boite(Vector3(1.0, 1.2, 1.2), Vector3(x, 0.4, 0), _mat_tuf(), egout)
	_boite(Vector3(3.4, 2.2, 0.4), Vector3(0, 0.6, -0.5), _mat_pbr("", Color(0.04, 0.035, 0.03), 1.0), egout, false)
	var grille := StandardMaterial3D.new()
	grille.albedo_color = Color(0.14, 0.11, 0.09)
	grille.metallic = 0.6
	grille.roughness = 0.6
	for i in 7:
		_boite(Vector3(0.06, 2.0, 0.06), Vector3(-1.5 + i * 0.5, 0.8, 0.0), grille, egout, false)
	# Les yeux du Colosse : deux lueurs violettes, cachées jusqu'au chapitre 7.
	var yeux := Node3D.new()
	yeux.name = "YeuxColosse"
	yeux.add_to_group("decor_quete")
	yeux.set_meta("identifiant", "yeux_colosse")
	yeux.visible = false
	var sol_c := hauteur(COLOSSE.x, COLOSSE.y)
	yeux.position = Vector3(COLOSSE.x, sol_c, COLOSSE.y)
	yeux.rotation.y = PI * 0.15
	dossier.add_child(yeux)
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = Color(0.6, 0.3, 1.0)
	lueur.emission_enabled = true
	lueur.emission = Color(0.65, 0.3, 1.0)
	lueur.emission_energy_multiplier = 8.0
	for x: float in [-0.6, 0.6]:
		var oeil := MeshInstance3D.new()
		var boule := SphereMesh.new()
		boule.radius = 0.28
		boule.height = 0.4
		oeil.mesh = boule
		oeil.material_override = lueur
		oeil.position = Vector3(x * 0.9, 7.6 + 20.4 * 1.08 + 0.17, -1.55)
		yeux.add_child(oeil)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.65, 0.3, 1.0)
	lumiere.light_energy = 6.0
	lumiere.omni_range = 14.0
	lumiere.position = Vector3(0, 7.6 + 20.4 * 1.08, -3.0)
	yeux.add_child(lumiere)


## Chapitre 5 : le centurion des vigiles et ses hommes, les foyers de l'incendie, l'enclos
## des oies du Capitole, les deux réponses à Janus et le portail de campagne de Lenoir.
func _construire_quete_incendie(dossier: Node3D) -> void:
	_pnj(dossier, "lucretius", LUCRETIUS, PI * 0.75)
	for k in VIGILES.size():
		_pnj(dossier, "vigile_%d" % (k + 1), VIGILES[k], PI * (0.6 + k * 0.3))
	for k in FEUX.size():
		var p: Vector2 = FEUX[k]
		var feu := ObjetRome.new()
		feu.name = "FoyerChamp%d" % k
		feu.identifiant = "foyer_champ_%d" % k
		feu.groupe = "foyer_champ"
		feu.forme = "brasier"
		feu.invite = "[F] Faire la chaîne des seaux"
		feu.portee = 3.0
		feu.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(feu)
	var oies := ObjetRome.new()
	oies.name = "EnclosOies"
	oies.identifiant = "enclos_oies"
	oies.forme = "oies"
	oies.invite = "[F] Ouvrir l'enclos des oies"
	oies.portee = 3.6
	oies.position = Vector3(OIES.x, hauteur(OIES.x, OIES.y), OIES.y)
	dossier.add_child(oies)
	for r in [["arreter_janus", "[F] « Livia Conti, je t'arrête au nom de la Vigie »", Vector2(-2.5, 2.5)],
			["ecouter_janus", "[F] « Explique-toi. Pourquoi ? »", Vector2(2.5, 2.5)]]:
		var reponse := ObjetRome.new()
		reponse.name = String(r[0]).to_pascal_case()
		reponse.identifiant = r[0]
		reponse.invite = r[1]
		reponse.portee = 2.0
		var q: Vector2 = JANUS + r[2]
		reponse.position = Vector3(q.x, hauteur(q.x, q.y), q.y)
		dossier.add_child(reponse)
	# Le portail de campagne : Lenoir l'ouvre quand Janus s'est enfuie.
	_construire_portail(dossier, PORTAIL_QG, PI * 0.25)
	_portail_qg = dossier.get_node("Portail") as Node3D
	_portail_qg.name = "PortailCampagne"
	_portail_qg.add_to_group("decor_quete")
	_portail_qg.set_meta("identifiant", "portail_qg")
	_portail_qg.visible = false
	_zone_portail.monitoring = false


# --- La sortie : la route de la Porta Maggiore ---------------------------------------------------

var _attente_sortie := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	# Le portail de campagne ne ramène au QG qu'une fois ouvert.
	if _portail_qg != null and _zone_portail != null and _zone_portail.monitoring != _portail_qg.visible:
		_zone_portail.monitoring = _portail_qg.visible
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if quete == null or joueur == null or not quete.has_method("changer_de_zone"):
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.y > 152.0 and absf(p.x - SORTIE_SUD.x) < 12.0:
		quete.changer_de_zone("campagne")
	# La grande arche de l'ouest de l'amphithéâtre s'ouvre le jour des jeux.
	elif p.distance_to(PORTE_COLISEE) < 4.5 and quete.etape_atteinte("entrer_colisee"):
		quete.changer_de_zone("colisee")
	# La bouche de la Cloaca Maxima, ouverte par l'égoutier (chapitre 8, donjon).
	elif p.distance_to(EGOUT) < 3.2 and quete.etape_atteinte("entrer_cloaca"):
		quete.changer_de_zone("cloaca")


## Quêtes secondaires : le gardien des oies du Capitole, le gérant des thermes de Titus,
## le lanista du Ludus Magnus et la boulangère de la Subure.
func _construire_secondaires(dossier: Node3D) -> void:
	_pnj(dossier, "gardien_junon", Vector2(-136, -24), PI * 0.5)
	_pnj(dossier, "gerant_thermes", Vector2(100, -80), PI * 0.8)
	_pnj(dossier, "lanista", Vector2(140, -50), -PI * 0.6)
	_pnj(dossier, "boulangere", Vector2(3, -130), PI * 0.2)
