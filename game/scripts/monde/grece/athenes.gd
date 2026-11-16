@tool
extends "res://scripts/monde/grece/ile_grece.gd"
## Île de Grèce, zone 3 : Athènes (niveaux 24-28).
##
## La ville de Périclès, l'été -438. On arrive par la porte du sud, au bout des Longs
## Murs. La grande rue monte vers l'Agora, la place du marché et de la vie publique :
## le Portique peint (Stoa Poikilè) au nord, le Portique de Zeus à l'ouest, la Tholos
## ronde où dînent les magistrats, l'autel des Douze Dieux, les étals. À l'ouest, sur sa
## colline, le temple d'Héphaïstos. Au nord-ouest, le Céramique, le quartier des potiers,
## ses fours et ses tombes, jusqu'à la porte du Dipylon. Au sud-ouest, la Pnyx, la
## colline où se réunit l'assemblée. À l'est, le rocher de l'Acropole et le Parthénon
## tout neuf ; sur son flanc sud, le théâtre de Dionysos et ses gradins de bois.
##
## Tout est construit par le code (voir ile_grece.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetGrece := preload("res://scripts/monde/grece/objet_grece.gd")

## La porte du sud (où arrivent les Longs Murs) et l'arrivée juste derrière.
const PORTE_SUD := Vector2(0, 152)
const ENTREE := Vector2(0, 138)
## L'Agora : la grande place, à peu près carrée.
const AGORA := Rect2(-56, -46, 92, 72)
const H_AGORA := 6.0
## Les monuments de l'Agora.
const POIKILE := Vector2(-10, -47)
const STOA_ZEUS := Vector2(-59, -10)
const THOLOS := Vector2(-48, 16)
const BOULEUTERION := Vector2(-74, 12)
const AUTEL_DOUZE := Vector2(8, -24)
const FONTAINE := Vector2(30, 34)
## Les gens de l'Agora.
const KALLIAS := Vector2(14, -10)
const FIGUES := Vector2(22, 6)
const ARCHER := Vector2(-28, 22)
const MARKOS := Vector2(6, 130)
const SOCRATE := Vector2(-4, 134)
## La faille sous le Portique peint, et la table aux masques d'argile.
const FAILLE := Vector2(-18, -48.5)
const MASQUES := Vector2(-26, -49)
## La colline de l'Agora et son temple d'Héphaïstos.
const KOLONOS := Vector2(-98, -30)
## Le Céramique : l'atelier de Lydos, son four, et la porte du Dipylon.
const LYDOS := Vector2(-110, -98)
const ATELIER := Vector2(-119, -104)
const FOUR := Vector2(-113, -109)
const DIPYLON := Vector2(-146, -140)
## La Pnyx : la colline de l'assemblée, et la tribune (le bêma).
const PNYX := Vector2(-92, 92)
const BEMA := Vector2(-92, 82)
## L'Acropole : un rocher ovale, plat sur le dessus, aux flancs presque verticaux.
const ACROPOLE := Vector2(100, -4)
const ACROPOLE_RAYONS := Vector2(46, 26)
const ACROPOLE_HAUT := 36.0
## Le théâtre de Dionysos, au pied du flanc sud : l'orchestre (la piste ronde) et les gradins.
const ORCHESTRE := Vector2(100, 62)
const H_ORCHESTRE := 7.0

## Les trois Pétrifiés de l'Agora, une fois qu'on leur a rendu la voix.
const NOMS_LIBERES := ["petrifie_cherephon", "petrifie_glykera", "petrifie_demochares"]
const LIBERES := [Vector2(-4, -36), Vector2(0, -34), Vector2(4, -36)]

var _attente_sortie := 0.0
var _etat_repris := false


func _init() -> void:
	identifiant_zone = "athenes"
	taille_terrain = 320
	graine = 4382
	point_apparition = ENTREE
	nombre_touffes = 30000
	neige_qui_tombe = false
	prefixe_liberables = "petrifie"
	invite_liberer = "[F] Rendre la voix"
	groupe_liberer = "voix_rendue"
	noms_liberes = NOMS_LIBERES
	places_liberes = LIBERES
	sols = {
		# Rouge : le calcaire nu des collines (Acropole, Pnyx, colline d'Héphaïstos).
		"galets": ["rock_boulder_dry", "dry_ground_rocks", "rocky_terrain_02"],
		# Vert : la terre des jardins et des terrains vagues.
		"neige": ["dry_ground_01", "red_sand", "dry_ground_rocks"],
		# Bleu : la terre battue des rues et de l'Agora.
		"sol": ["mud_cracked_dry_03", "dry_ground_01", "dry_ground_rocks"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.8, "sol_motif": 4.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(1.02, 0.96, 0.88), "roche_teinte": Color(1.02, 0.98, 0.92), "roche_saturation": 0.6,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 10.0,
			"neige_teinte": Color(1.0, 0.86, 0.72), "neige_max": Vector3(0.64, 0.5, 0.38), "neige_simple": Color(0.6, 0.46, 0.34),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.24, 0.24, 0.1), "couleur_pointe": Color(0.66, 0.62, 0.34),
			"couleur_givre": Color(0.66, 0.6, 0.34), "force_vent": 0.2}
	piste = [Vector2(0, 150), Vector2(0, 26)]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_grece", "") != "":
		Reseau.remove_meta("arrivee_grece")
		point_apparition = ENTREE
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "athenes":
		return Vector2.INF
	return PORTE_SUD + Vector2(0, -6)


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.012


## Les rues de terre battue : la grande rue, la voie des Panathénées (du Dipylon à
## l'Acropole, en travers de l'Agora), et les chemins du théâtre et de la Pnyx.
func _distance_rues(p: Vector2) -> float:
	var d := _distance_segment(p, PORTE_SUD, Vector2(0, 26))
	d = minf(d, _distance_segment(p, DIPYLON, Vector2(-60, -50)))
	d = minf(d, _distance_segment(p, Vector2(-60, -50), Vector2(30, 10)))
	d = minf(d, _distance_segment(p, Vector2(30, 10), Vector2(54, -2)))
	d = minf(d, _distance_segment(p, Vector2(36, 26), Vector2(70, 52)))
	d = minf(d, _distance_segment(p, Vector2(70, 52), ORCHESTRE + Vector2(-14, 4)))
	d = minf(d, _distance_segment(p, Vector2(-56, 26), Vector2(-80, 70)))
	d = minf(d, _distance_segment(p, Vector2(0, 90), Vector2(-60, 60)))
	d = minf(d, _distance_segment(p, Vector2(0, 80), Vector2(56, 70)))
	return d


## Une colline ronde au sommet aplati (« plat » : la part du rayon qui reste à plat).
func _colline(x: float, z: float, centre: Vector2, rayon: float, haut: float, plat := 0.35) -> float:
	var d := Vector2(x, z).distance_to(centre)
	return haut * (1.0 - smoothstep(rayon * plat, rayon, d))


## 0 hors du rocher, 1 sur le plateau de l'Acropole (avec des flancs très raides).
func _sur_acropole(x: float, z: float, bruit := 0.0) -> float:
	var e := Vector2((x - ACROPOLE.x) / ACROPOLE_RAYONS.x, (z - ACROPOLE.y) / ACROPOLE_RAYONS.y).length()
	return 1.0 - smoothstep(1.0, 1.3, e + bruit * 0.05)


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var h := H_AGORA + bruit * 1.6 + fin * 0.08
	h += _colline(x, z, KOLONOS, 40.0, 9.0, 0.5)
	h += _colline(x, z, PNYX, 32.0, 10.0)
	# Les rues : on adoucit les bosses.
	var d_rue := _distance_rues(Vector2(x, z))
	h = lerpf(h, H_AGORA + bruit * 0.6 + _colline(x, z, KOLONOS, 40.0, 9.0, 0.5) + _colline(x, z, PNYX, 32.0, 10.0),
			1.0 - smoothstep(2.0, 6.0, d_rue))
	# L'Agora : plate comme une table.
	h = lerpf(h, H_AGORA, _dans_rect(AGORA, x, z, 8.0))
	# Le théâtre : l'orchestre plate, puis les gradins qui montent vers le rocher.
	var vers := Vector2(x, z) - ORCHESTRE
	var d := vers.length()
	var gradins := H_ORCHESTRE + clampf(d - 11.0, 0.0, 24.0) * 0.5
	var cote_nord := smoothstep(4.0, -2.0, vers.y)
	var dans_theatre := (1.0 - smoothstep(31.0, 36.0, d)) * cote_nord
	h = lerpf(h, gradins, dans_theatre)
	h = lerpf(h, H_ORCHESTRE, 1.0 - smoothstep(11.0, 13.0, d))
	# Le rocher de l'Acropole.
	var rocher := _sur_acropole(x, z, bruit)
	h = lerpf(h, H_AGORA + ACROPOLE_HAUT + fin * 0.25 + bruit * 0.6, rocher)
	return h


## Rouge : calcaire des collines ; vert : terre ; bleu : rues, Agora, orchestre.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var colline := maxf(smoothstep(14.0, 4.0, p.distance_to(PNYX) * 0.5), _sur_acropole(x, z) * 0.9)
	colline = maxf(colline, smoothstep(16.0, 6.0, p.distance_to(KOLONOS) * 0.4))
	colline = maxf(colline, smoothstep(H_AGORA + 8.0, H_AGORA + 20.0, h) * (1.0 - smoothstep(36.0, 30.0, p.distance_to(ORCHESTRE))))
	var battu := 1.0 - smoothstep(2.5, 4.5, _distance_rues(p))
	battu = maxf(battu, _dans_rect(AGORA.grow(-2.0), x, z, 3.0))
	battu = maxf(battu, 1.0 - smoothstep(11.0, 12.5, p.distance_to(ORCHESTRE)))
	colline *= 1.0 - battu
	return Color(colline, (1.0 - colline) * (1.0 - battu), battu, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_a_liberer.clear()
	_liberes = 0
	_construire_terrain()
	_construire_remparts()
	_construire_agora()
	_construire_hephaisteion()
	_construire_ceramique()
	_construire_pnyx()
	_construire_acropole()
	_construire_theatre()
	_construire_quartiers()
	_construire_arbres()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


## Regroupe toutes les boîtes d'un dossier en un seul maillage par matériau : des
## centaines de maisons s'affichent alors aussi vite qu'une seule. Les collisions restent.
func _fusionner(dossier: Node3D) -> void:
	var outils := {}
	for n in dossier.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.material_override == null:
			continue
		var t := Transform3D.IDENTITY
		var noeud: Node = mi
		while noeud != null and noeud != dossier:
			if noeud is Node3D:
				t = (noeud as Node3D).transform * t
			noeud = noeud.get_parent()
		var m := mi.material_override
		if not outils.has(m):
			var outil := SurfaceTool.new()
			outil.begin(Mesh.PRIMITIVE_TRIANGLES)
			outils[m] = outil
		(outils[m] as SurfaceTool).append_from(mi.mesh, 0, t)
		mi.mesh = null
	for m in outils:
		var fusion := MeshInstance3D.new()
		fusion.mesh = (outils[m] as SurfaceTool).commit()
		fusion.material_override = m
		dossier.add_child(fusion)


# --- Les remparts et la porte du sud ------------------------------------------------------

func _construire_remparts() -> void:
	var murs := Node3D.new()
	murs.name = "Remparts"
	_contenu.add_child(murs)
	var pierre := _mat_pierre()
	# Le rempart du sud, avec la porte où arrivent les Longs Murs.
	var x := -160.0
	while x < 160.0:
		var x2 := minf(x + 16.0, 160.0)
		var milieu := (x + x2) * 0.5
		if absf(milieu) > 8.0:
			var y := hauteur(milieu, PORTE_SUD.y)
			_boite(Vector3(x2 - x + 0.05, 10.0, 4.0), Vector3(milieu, y + 4.0, PORTE_SUD.y + 2.0), pierre, murs)
		x = x2
	var y0 := hauteur(0.0, PORTE_SUD.y)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(7.0, 14.0, 7.0), Vector3(cote * 8.0, y0 + 6.0, PORTE_SUD.y + 2.0), pierre, murs)
	_boite(Vector3(10.0, 3.0, 4.4), Vector3(0, y0 + 9.5, PORTE_SUD.y + 2.0), pierre, murs, false)
	# Le rempart de l'ouest, et la porte du Dipylon (double porte, fermée) au nord-ouest.
	var z := -160.0
	while z < 150.0:
		var z2 := minf(z + 16.0, 150.0)
		var milieu := (z + z2) * 0.5
		_boite(Vector3(4.0, 9.0, z2 - z + 0.05), Vector3(-158.0, hauteur(-156.0, milieu) + 3.5, milieu), pierre, murs)
		z = z2
	for cote: float in [-1.0, 1.0]:
		var p := DIPYLON + Vector2(-10, cote * 8.0)
		_boite(Vector3(8.0, 14.0, 7.0), Vector3(p.x, hauteur(p.x, p.y) + 6.0, p.y), pierre, murs)
	_boite(Vector3(4.0, 8.0, 9.0), Vector3(DIPYLON.x - 10.0, hauteur(DIPYLON.x, DIPYLON.y) + 3.5, DIPYLON.y), _mat_bois(), murs)


# --- L'Agora ---------------------------------------------------------------------------------

func _construire_agora() -> void:
	var agora := Node3D.new()
	agora.name = "Agora"
	_contenu.add_child(agora)
	var marbre := _mat_marbre()
	# Le Portique peint (Stoa Poikilè) : ses grands panneaux de bois peints racontent
	# la bataille de Marathon. C'est là que les gens se retrouvent pour parler.
	var poikile := _portique(agora, POIKILE, 46.0, 8.0, 0.0, 6.0)
	poikile.name = "PortiquePeint"
	for k in 5:
		var panneau := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(7.0, 2.6)
		panneau.mesh = q
		panneau.material_override = _mat_panneau_peint(k)
		panneau.position = Vector3(-18.0 + k * 9.0, 0.66 + 3.2, -4.0 + 0.66)
		poikile.add_child(panneau)
	# Le Portique de Zeus Libérateur, à l'ouest, et ses deux ailes.
	_portique(agora, STOA_ZEUS, 34.0, 7.0, PI / 2, 5.4)
	# La Tholos : la salle ronde où mangent et dorment les cinquante magistrats de garde.
	var y := H_AGORA
	var tholos := Node3D.new()
	tholos.name = "Tholos"
	tholos.position = Vector3(THOLOS.x, y, THOLOS.y)
	agora.add_child(tholos)
	var mur := MeshInstance3D.new()
	mur.mesh = _cylindre(8.6, 8.8, 5.0, 32)
	mur.material_override = _mat_chaux()
	mur.position.y = 2.5
	tholos.add_child(mur)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 8.8
	cyl.height = 5.0
	forme.shape = cyl
	forme.position.y = 2.5
	corps.add_child(forme)
	tholos.add_child(corps)
	var toit := MeshInstance3D.new()
	toit.mesh = _cylindre(0.6, 9.6, 3.2, 32)
	toit.material_override = _mat_tuiles()
	toit.position.y = 6.6
	tholos.add_child(toit)
	_boite(Vector3(1.6, 2.6, 0.3), Vector3(0, 1.3, 8.75), _mat_bois(), tholos, false)
	# Le Bouleutérion : la salle du Conseil des Cinq-Cents, derrière la Tholos.
	var conseil := _maison_grecque(agora, BOULEUTERION, Vector3(20, 8.0, 18), PI / 2)
	conseil.name = "Bouleuterion"
	# L'autel des Douze Dieux, dans son enclos : c'est le centre d'Athènes, d'où l'on
	# compte les distances.
	_boite(Vector3(2.6, 1.2, 1.8), Vector3(AUTEL_DOUZE.x, y + 0.6, AUTEL_DOUZE.y), marbre, agora)
	_boite(Vector3(2.8, 0.2, 2.0), Vector3(AUTEL_DOUZE.x, y + 1.3, AUTEL_DOUZE.y), _mat_peint(ROUGE_GREC), agora, false)
	for k in 4:
		var horizontal := k < 2
		var c := AUTEL_DOUZE + (Vector2(0, -4.5 if k == 0 else 4.5) if horizontal else Vector2(-4.5 if k == 2 else 4.5, 0))
		var long_muret := 9.0 if horizontal else 9.0
		if k == 1:
			# L'entrée, au sud.
			for bout: float in [-1.0, 1.0]:
				_boite(Vector3(3.0, 0.9, 0.4), Vector3(c.x + bout * 3.0, y + 0.45, c.y), marbre, agora)
			continue
		_boite(Vector3(long_muret, 0.9, 0.4) if horizontal else Vector3(0.4, 0.9, long_muret), Vector3(c.x, y + 0.45, c.y), marbre, agora)
	# Les bornes de l'Agora : « Je suis la borne de l'Agora » (elles ont été retrouvées).
	for p in [Vector2(-52, 28), Vector2(34, 28), Vector2(-4, 28)]:
		var borne := Vector2(p)
		_boite(Vector3(0.5, 1.1, 0.35), Vector3(borne.x, y + 0.55, borne.y), marbre, agora)
		var texte := Label3D.new()
		texte.text = "ΗΟΡΟΣ ΕΙΜΙ\nΤΕΣ ΑΓΟΡΑΣ"
		texte.font_size = 28
		texte.pixel_size = 0.0035
		texte.modulate = Color(0.35, 0.3, 0.26)
		texte.outline_size = 0
		texte.position = Vector3(borne.x, y + 0.8, borne.y + 0.18)
		agora.add_child(texte)
	# Les hermès alignés devant le portique (on les appelle « les Hermès »).
	for k in 8:
		_herme(agora, Vector2(14.0 + k * 2.6, -40.0))
	# Le marché : des étals sous des toiles, des tables, des paniers et des amphores.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	var etals := [KALLIAS + Vector2(0, -3), FIGUES + Vector2(0, -2.6), Vector2(-30, -16), Vector2(-20, -24),
			Vector2(26, -26), Vector2(-36, 0), Vector2(20, 18), Vector2(-14, 18), Vector2(28, -6)]
	var toiles := [Color(0.9, 0.86, 0.76), Color(0.75, 0.42, 0.3), Color(0.86, 0.8, 0.62), Color(0.5, 0.56, 0.62)]
	for k in etals.size():
		var e: Vector2 = etals[k]
		_auvent(agora, e, Vector2(3.6, 2.6), 2.5, toiles[k % toiles.size()])
		_boite(Vector3(2.8, 0.9, 1.0), Vector3(e.x, y + 0.45, e.y - 0.4), _mat_bois(), agora)
		for a in 3:
			_amphore(agora, Vector3(e.x - 1.2 + a * 0.9, y, e.y + 1.4), hasard.randf_range(0.6, 0.9), hasard.randf() * TAU)
	# L'étal de Kallias : des poissons argentés sur la table.
	var argent := StandardMaterial3D.new()
	argent.albedo_color = Color(0.62, 0.66, 0.7)
	argent.metallic = 0.4
	argent.roughness = 0.35
	for k in 7:
		var poisson := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.09
		s.height = 0.18
		poisson.mesh = s
		poisson.scale = Vector3(1.0, 0.5, 3.2)
		poisson.material_override = argent
		poisson.position = Vector3(KALLIAS.x - 1.1 + k * 0.36, y + 0.95, KALLIAS.y - 3.4 + sin(k) * 0.15)
		poisson.rotation.y = 0.3 * sin(k * 2.0)
		agora.add_child(poisson)
	# La fontaine aux neuf bouches, au sud-est de la place.
	_boite(Vector3(10, 4.5, 6), Vector3(FONTAINE.x, y + 2.25, FONTAINE.y - 1.0), _mat_chaux(), agora)
	for k in 3:
		_colonne(agora, Vector3(FONTAINE.x - 3.0 + k * 3.0, y, FONTAINE.y + 2.4), 4.2, 0.3, marbre)
	_boite(Vector3(10.4, 0.5, 2.0), Vector3(FONTAINE.x, y + 4.4, FONTAINE.y + 2.4), marbre, agora, false)
	var eau := MeshInstance3D.new()
	var bassin := BoxMesh.new()
	bassin.size = Vector3(8, 0.1, 1.4)
	eau.mesh = bassin
	var m_eau := StandardMaterial3D.new()
	m_eau.albedo_color = Color(0.2, 0.36, 0.4, 0.8)
	m_eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_eau.roughness = 0.05
	eau.material_override = m_eau
	eau.position = Vector3(FONTAINE.x, y + 0.5, FONTAINE.y + 1.0)
	agora.add_child(eau)
	_boite(Vector3(8.4, 0.5, 0.3), Vector3(FONTAINE.x, y + 0.25, FONTAINE.y + 1.8), _mat_pierre(), agora)


## Une grande peinture sur bois du Portique peint : des bandes de couleur, des
## silhouettes de guerriers (hoplites rouges contre Perses bleus), un ciel ocre.
func _mat_panneau_peint(numero: int) -> StandardMaterial3D:
	var cle := "panneau_%d" % numero
	if _materiaux.has(cle):
		return _materiaux[cle]
	var image := Image.create(140, 52, false, Image.FORMAT_RGB8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 77 + numero
	image.fill(Color(0.78, 0.62, 0.4))
	# Le sol, plus sombre, et une mer bleue derrière (les navires de Marathon).
	image.fill_rect(Rect2i(0, 36, 140, 16), Color(0.48, 0.36, 0.24))
	image.fill_rect(Rect2i(0, 10, 140, 8), Color(0.26, 0.38, 0.5))
	for k in 16:
		var x := hasard.randi_range(4, 132)
		var rouge := k % 2 == 0
		var couleur := Color(0.6, 0.16, 0.1) if rouge else Color(0.18, 0.24, 0.44)
		# Une silhouette : jambes, corps, tête, et un bouclier rond.
		image.fill_rect(Rect2i(x, 30, 2, 8), couleur.darkened(0.2))
		image.fill_rect(Rect2i(x - 1, 20, 4, 10), couleur)
		image.fill_rect(Rect2i(x, 16, 3, 3), Color(0.55, 0.38, 0.26))
		if rouge:
			image.fill_rect(Rect2i(x + 2, 21, 4, 6), Color(0.72, 0.55, 0.2))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.roughness = 0.85
	_materiaux[cle] = m
	return m


## Un hermès : un pilier carré surmonté d'une tête barbue (le dieu des passants).
func _herme(parent: Node3D, p: Vector2) -> void:
	var y := hauteur(p.x, p.y)
	_boite(Vector3(0.42, 1.45, 0.38), Vector3(p.x, y + 0.72, p.y), _mat_marbre(), parent)
	var tete := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.46
	tete.mesh = s
	tete.material_override = _mat_marbre()
	tete.position = Vector3(p.x, y + 1.66, p.y)
	parent.add_child(tete)
	var barbe := MeshInstance3D.new()
	barbe.mesh = _cylindre(0.05, 0.15, 0.28, 8)
	barbe.material_override = _mat_peint(Color(0.3, 0.2, 0.12))
	barbe.position = Vector3(p.x, y + 1.48, p.y + 0.1)
	barbe.rotation.x = PI
	parent.add_child(barbe)


# --- Les temples ------------------------------------------------------------------------------

## Un temple dorique : trois marches, une colonnade tout autour (« n_face » colonnes en
## façade, « n_cote » sur les côtés), la cella (la salle de la statue), l'entablement
## avec sa frise peinte, et le toit à deux pentes avec ses frontons.
## « centre » = milieu du sol du temple ; le temple est allongé selon l'axe X.
func _temple(parent: Node3D, centre: Vector3, largeur: float, longueur: float, n_face: int, n_cote: int,
		haut_colonne: float, rayon: float) -> Node3D:
	var t := Node3D.new()
	t.name = "Temple"
	t.position = centre
	parent.add_child(t)
	var marbre := _mat_marbre()
	for k in 3:
		_boite(Vector3(longueur + 3.0 - k * 1.0, 0.5, largeur + 3.0 - k * 1.0), Vector3(0, 0.25 + k * 0.5, 0), marbre, t, true)
	var sol := 1.5
	var pas_long := (longueur - rayon * 2.4) / (n_cote - 1)
	var pas_large := (largeur - rayon * 2.4) / (n_face - 1)
	for k in n_cote:
		for cote: float in [-1.0, 1.0]:
			_colonne(t, Vector3(-longueur * 0.5 + rayon * 1.2 + k * pas_long, sol, cote * (largeur * 0.5 - rayon * 1.2)), haut_colonne, rayon, marbre)
	for k in range(1, n_face - 1):
		for bout: float in [-1.0, 1.0]:
			_colonne(t, Vector3(bout * (longueur * 0.5 - rayon * 1.2), sol, -largeur * 0.5 + rayon * 1.2 + k * pas_large), haut_colonne, rayon, marbre)
	# La cella.
	_boite(Vector3(longueur * 0.7, haut_colonne, largeur * 0.62), Vector3(0, sol + haut_colonne * 0.5, 0), marbre, t)
	var porte := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(largeur * 0.18, haut_colonne * 0.7)
	porte.mesh = q
	porte.material_override = _mat_bronze()
	porte.rotation.y = PI / 2
	porte.position = Vector3(longueur * 0.35 + 0.02, sol + haut_colonne * 0.35, 0)
	t.add_child(porte)
	# L'entablement : l'architrave, la frise de triglyphes, la corniche.
	var haut := sol + haut_colonne
	_boite(Vector3(longueur, haut_colonne * 0.12, largeur), Vector3(0, haut + haut_colonne * 0.06, 0), marbre, t, false)
	for cote: float in [-1.0, 1.0]:
		_frise(t, Vector3(0, haut + haut_colonne * 0.2, cote * (largeur * 0.5 + 0.02)), longueur, haut_colonne * 0.11, 0.0 if cote > 0.0 else PI)
		_frise(t, Vector3(cote * (longueur * 0.5 + 0.02), haut + haut_colonne * 0.2, 0), largeur, haut_colonne * 0.11, cote * PI / 2)
	_boite(Vector3(longueur + 0.6, haut_colonne * 0.04, largeur + 0.6), Vector3(0, haut + haut_colonne * 0.28, 0), marbre, t, false)
	# Le toit, et les frontons peints en bleu.
	var toit := Node3D.new()
	toit.position = Vector3(0, haut + haut_colonne * 0.3, 0)
	toit.rotation.y = PI / 2
	t.add_child(toit)
	_toit(toit, Vector3.ZERO, largeur, longueur, 0.24)
	for bout: float in [-1.0, 1.0]:
		var fond := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(largeur * 0.92, largeur * 0.5 * tan(0.24) * 0.9, 0.1)
		fond.mesh = prisme
		fond.material_override = _mat_peint(BLEU_GREC)
		fond.position = Vector3(bout * (longueur * 0.5 + 0.05), haut + haut_colonne * 0.3 + prisme.size.y * 0.5, 0)
		fond.rotation.y = PI / 2
		t.add_child(fond)
	return t


## Le temple d'Héphaïstos et d'Athéna Ergané, sur sa colline au-dessus de l'Agora :
## le dieu des forgerons veille sur les artisans du quartier.
func _construire_hephaisteion() -> void:
	var colline := Node3D.new()
	colline.name = "Hephaisteion"
	_contenu.add_child(colline)
	var y := hauteur(KOLONOS.x, KOLONOS.y)
	var temple := _temple(colline, Vector3(KOLONOS.x, y - 0.2, KOLONOS.y), 13.7, 31.8, 6, 13, 5.7, 0.5)
	temple.rotation.y = 0.0
	# Le jardin sacré : des grenadiers et des myrtes en pots autour du temple.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 17
	for k in 14:
		var a := TAU * k / 14.0
		var p := KOLONOS + Vector2(cos(a) * 24.0, sin(a) * 15.0)
		_olivier(colline, p, hasard, 0.7)


# --- Le Céramique ------------------------------------------------------------------------------

func _construire_ceramique() -> void:
	var quartier := Node3D.new()
	quartier.name = "Ceramique"
	_contenu.add_child(quartier)
	# Les ateliers : des maisons ouvertes sur la rue, avec une cour.
	_maison_grecque(quartier, ATELIER, Vector3(10, 4.4, 7), 0.0)
	_maison_grecque(quartier, ATELIER + Vector2(-14, 6), Vector3(9, 4.2, 7), 0.15)
	_maison_grecque(quartier, ATELIER + Vector2(4, 16), Vector3(8, 4.0, 7), -PI / 2)
	_maison_grecque(quartier, ATELIER + Vector2(-20, -12), Vector3(8, 4.0, 6), PI)
	# Le four de Lydos : un dôme d'argile, sa bouche et sa cheminée qui fume encore.
	var y := hauteur(FOUR.x, FOUR.y)
	var argile := _mat_terre_cuite()
	var dome := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.8
	s.height = 2.6
	s.is_hemisphere = true
	dome.mesh = s
	dome.material_override = argile
	dome.position = Vector3(FOUR.x, y, FOUR.y)
	quartier.add_child(dome)
	_boite(Vector3(0.9, 0.9, 0.5), Vector3(FOUR.x, y + 0.45, FOUR.y + 1.65), _mat_peint(NOIR_POIX), quartier, false)
	var cheminee := MeshInstance3D.new()
	cheminee.mesh = _cylindre(0.25, 0.35, 1.4, 10)
	cheminee.material_override = argile
	cheminee.position = Vector3(FOUR.x, y + 1.9, FOUR.y)
	quartier.add_child(cheminee)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	forme.shape = sphere
	corps.add_child(forme)
	corps.position = Vector3(FOUR.x, y, FOUR.y)
	quartier.add_child(corps)
	_fumee(quartier, Vector3(FOUR.x, y + 2.6, FOUR.y))
	# Les vases qui sèchent sur des planches, et des tessons partout.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 23
	for rang in 2:
		var p := LYDOS + Vector2(-5.0, -3.0 + rang * 1.4)
		_boite(Vector3(4.0, 0.08, 0.6), Vector3(p.x, hauteur(p.x, p.y) + 0.8 + rang * 0.1, p.y), _mat_bois(), quartier, false)
		for k in 5:
			var vase := Vector3(p.x - 1.6 + k * 0.8, hauteur(p.x, p.y) + 0.84 + rang * 0.1, p.y)
			_vase(quartier, vase, hasard.randf_range(0.35, 0.5), k % 2 == 0)
	for k in 30:
		var p := LYDOS + Vector2(hasard.randf_range(-16, 10), hasard.randf_range(-14, 10))
		var tesson := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(hasard.randf_range(0.08, 0.2), 0.02, hasard.randf_range(0.06, 0.14))
		tesson.mesh = b
		tesson.material_override = argile if k % 3 else _mat_peint(NOIR_POIX, 0.4)
		tesson.position = Vector3(p.x, hauteur(p.x, p.y) + 0.02, p.y)
		tesson.rotation.y = hasard.randf() * TAU
		quartier.add_child(tesson)
	# Le cimetière, le long de la route du Dipylon : des stèles peintes et des vases-tombes.
	for k in 18:
		var t := float(k) / 17.0
		var route := DIPYLON.lerp(Vector2(-60, -50), t * 0.45)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var p := route + Vector2(-0.7, 0.7).normalized() * cote * 7.0 + Vector2(hasard.randf_range(-1, 1), hasard.randf_range(-1, 1))
		if p.distance_to(LYDOS) < 14.0 or p.distance_to(ATELIER) < 12.0:
			continue
		var py := hauteur(p.x, p.y)
		var stele := _boite(Vector3(0.7, hasard.randf_range(1.2, 1.9), 0.18), Vector3(p.x, py + 0.7, p.y), _mat_marbre(), quartier)
		stele.rotation.y = -PI / 4
		_boite(Vector3(1.0, 0.3, 0.5), Vector3(p.x, py + 0.15, p.y), _mat_pierre(), quartier, false)
		if k % 4 == 1:
			_vase(quartier, Vector3(p.x + 1.4, py, p.y + 1.0), 1.4, true)


## Un vase grec : panse ronde, col, pied ; noir à figures rouges ou rouge à figures noires.
func _vase(parent: Node3D, p: Vector3, taille: float, noir: bool) -> void:
	var cle := "forme_cratere"
	if not _materiaux.has(cle):
		_materiaux[cle] = _tour([[0.0, 0.0], [0.12, 0.0], [0.1, 0.08], [0.2, 0.2], [0.34, 0.45], [0.36, 0.6],
				[0.3, 0.75], [0.22, 0.82], [0.26, 0.95], [0.3, 1.0]], 16)
	var mi := MeshInstance3D.new()
	mi.mesh = _materiaux[cle]
	mi.material_override = _mat_peint(NOIR_POIX, 0.35) if noir else _mat_terre_cuite()
	mi.position = p
	mi.scale = Vector3.ONE * taille
	parent.add_child(mi)
	var bande := MeshInstance3D.new()
	bande.mesh = _cylindre(0.355, 0.355, 0.12, 16)
	bande.material_override = _mat_terre_cuite() if noir else _mat_peint(NOIR_POIX, 0.35)
	bande.position = Vector3(0, 0.52, 0)
	mi.add_child(bande)


## Une fumée grise qui monte doucement (four, autel, forge).
func _fumee(parent: Node3D, p: Vector3) -> void:
	var fumee := GPUParticles3D.new()
	fumee.amount = 24
	fumee.lifetime = 6.0
	fumee.position = p
	var processus := ParticleProcessMaterial.new()
	processus.direction = Vector3(0.2, 1, 0)
	processus.spread = 12.0
	processus.initial_velocity_min = 0.5
	processus.initial_velocity_max = 0.9
	processus.gravity = Vector3(0.15, 0.1, 0)
	processus.scale_min = 0.6
	processus.scale_max = 1.4
	var courbe := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	courbe.curve = c
	processus.scale_curve = courbe
	fumee.process_material = processus
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.53, 0.5, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _texture_flamme()
	quad.material = m
	fumee.draw_pass_1 = quad
	parent.add_child(fumee)


# --- La Pnyx ----------------------------------------------------------------------------------

## La colline de l'assemblée : six mille citoyens assis sur la pente, face à la tribune
## taillée dans le rocher. C'est ici qu'un cordonnier peut contredire Périclès.
func _construire_pnyx() -> void:
	var pnyx := Node3D.new()
	pnyx.name = "Pnyx"
	_contenu.add_child(pnyx)
	var pierre := _mat_pierre()
	var y := hauteur(BEMA.x, BEMA.y)
	# Le bêma : trois marches et un bloc carré, taillés dans le calcaire.
	for k in 3:
		_boite(Vector3(5.0 - k * 1.2, 0.45, 4.0 - k * 1.0), Vector3(BEMA.x, y + 0.22 + k * 0.45, BEMA.y), pierre, pnyx)
	_boite(Vector3(1.4, 1.1, 1.2), Vector3(BEMA.x, y + 1.9, BEMA.y), pierre, pnyx)
	# Les citoyens s'asseyaient à même la pente, face à la tribune : quelques blocs
	# taillés marquent les rangs des magistrats, juste devant.
	for k in 7:
		var p := BEMA + Vector2(-9.0 + k * 3.0, 7.0 + absf(k - 3) * 0.6)
		_boite(Vector3(2.4, 0.45, 0.7), Vector3(p.x, hauteur(p.x, p.y) + 0.15, p.y), pierre, pnyx)
	# L'autel de Zeus Agoraios, à côté de la tribune.
	_boite(Vector3(1.8, 1.0, 1.2), Vector3(BEMA.x + 6.0, hauteur(BEMA.x + 6.0, BEMA.y) + 0.5, BEMA.y), _mat_marbre(), pnyx)


# --- L'Acropole --------------------------------------------------------------------------------

func _construire_acropole() -> void:
	var acropole := Node3D.new()
	acropole.name = "Acropole"
	_contenu.add_child(acropole)
	var haut := H_AGORA + ACROPOLE_HAUT
	# Le Parthénon, tout juste fini : la statue d'Athéna doit être consacrée à la fête.
	var parthenon := _temple(acropole, Vector3(ACROPOLE.x + 6.0, haut - 0.3, ACROPOLE.y + 2.0), 30.9, 69.5, 8, 17, 10.4, 0.95)
	parthenon.name = "Parthenon"
	# Des échafaudages de bois sur le fronton ouest : on y pose encore les dernières statues.
	var bois := _mat_bois()
	var ouest := ACROPOLE.x + 6.0 - 36.0
	for k in 6:
		var z := ACROPOLE.y + 2.0 - 13.0 + k * 5.2
		_boite(Vector3(0.25, 18.0, 0.25), Vector3(ouest - 1.5, haut + 9.0, z), bois, acropole, false)
		_boite(Vector3(0.25, 18.0, 0.25), Vector3(ouest - 3.5, haut + 9.0, z), bois, acropole, false)
	for k in 4:
		_boite(Vector3(2.4, 0.15, 28.0), Vector3(ouest - 2.5, haut + 4.0 + k * 4.0, ACROPOLE.y + 2.0), bois, acropole, false)
	# L'Athéna Promachos : une statue de bronze de neuf mètres, lance levée. Les marins
	# voient la pointe de sa lance briller depuis le cap Sounion.
	var socle := Vector3(ACROPOLE.x - 30.0, haut, ACROPOLE.y - 6.0)
	_boite(Vector3(3.0, 3.0, 3.0), socle + Vector3(0, 1.5, 0), _mat_marbre(), acropole)
	var bronze := _mat_bronze()
	var corps := MeshInstance3D.new()
	corps.mesh = _cylindre(0.7, 1.3, 6.5, 14)
	corps.material_override = bronze
	corps.position = socle + Vector3(0, 6.2, 0)
	acropole.add_child(corps)
	var tete := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.3
	tete.mesh = s
	tete.material_override = bronze
	tete.position = socle + Vector3(0, 10.0, 0)
	acropole.add_child(tete)
	var casque := MeshInstance3D.new()
	casque.mesh = _cylindre(0.05, 0.45, 1.1, 10)
	casque.material_override = bronze
	casque.position = socle + Vector3(0, 10.9, 0)
	acropole.add_child(casque)
	var lance := MeshInstance3D.new()
	lance.mesh = _cylindre(0.06, 0.08, 12.0, 6)
	lance.material_override = bronze
	lance.position = socle + Vector3(1.2, 8.5, 0)
	lance.rotation.z = -0.08
	acropole.add_child(lance)
	var bouclier := MeshInstance3D.new()
	bouclier.mesh = _cylindre(1.4, 1.4, 0.15, 20)
	bouclier.material_override = bronze
	bouclier.rotation.x = PI / 2
	bouclier.position = socle + Vector3(-1.1, 5.5, 0.6)
	acropole.add_child(bouclier)
	# Le chantier des Propylées, à l'ouest : des tambours de colonnes couchés, une grue
	# de bois, des blocs de marbre neuf qui attendent.
	var chantier := Vector2(ACROPOLE.x - 40.0, ACROPOLE.y)
	var marbre := _mat_marbre()
	for k in 8:
		var tambour := MeshInstance3D.new()
		tambour.mesh = _cylindre(0.85, 0.85, 1.2, 20)
		tambour.material_override = marbre
		tambour.rotation.z = PI / 2
		tambour.position = Vector3(chantier.x + 6.0 + (k % 4) * 2.8, haut + 0.85, chantier.y - 8.0 + (k / 4) * 3.0)
		acropole.add_child(tambour)
	for k in 6:
		_boite(Vector3(2.0, 1.0, 1.0), Vector3(chantier.x + 4.0 + k * 2.3, haut + 0.5, chantier.y + 9.0), marbre, acropole)
	for k in 3:
		_colonne(acropole, Vector3(chantier.x + 2.0, haut, chantier.y - 6.0 + k * 6.0), 4.0 + k * 2.0, 0.85, marbre)
	var grue := Node3D.new()
	grue.position = Vector3(chantier.x + 8.0, haut, chantier.y + 2.0)
	acropole.add_child(grue)
	for k in 3:
		var pied := _boite(Vector3(0.3, 12.0, 0.3), Vector3(cos(TAU * k / 3.0) * 1.6, 5.8, sin(TAU * k / 3.0) * 1.6), bois, grue, false)
		pied.rotation = Vector3(sin(TAU * k / 3.0) * 0.14, 0, -cos(TAU * k / 3.0) * 0.14)
	_boite(Vector3(9.0, 0.3, 0.3), Vector3(3.0, 11.6, 0), bois, grue, false)
	# Le vieux mur de Cimon, au bord du plateau, et les ruines du vieux temple brûlé par les Perses.
	var pierre := _mat_pierre()
	for k in 40:
		var a := TAU * k / 40.0
		var p := ACROPOLE + Vector2(cos(a) * (ACROPOLE_RAYONS.x - 1.5), sin(a) * (ACROPOLE_RAYONS.y - 1.5))
		if absf(a - PI) < 0.25:
			continue
		var bloc := _boite(Vector3(7.6, 2.4, 1.2), Vector3(p.x, haut + 0.8, p.y), pierre, acropole)
		bloc.rotation.y = -atan2(sin(a) * ACROPOLE_RAYONS.x, cos(a) * ACROPOLE_RAYONS.y) + PI / 2
	var ruine := Vector2(ACROPOLE.x - 6.0, ACROPOLE.y - 16.0)
	for k in 9:
		_colonne(acropole, Vector3(ruine.x - 10.0 + k * 2.6, haut, ruine.y), [1.2, 3.0, 0.8, 2.2, 0.6, 1.6, 2.8, 0.9, 1.4][k], 0.6, pierre)
	# L'escalier secret (le donjon, plus tard) : une grille de bronze au pied du flanc nord.
	var grille := Vector2(ACROPOLE.x + 10.0, ACROPOLE.y - ACROPOLE_RAYONS.y - 9.0)
	var yg := hauteur(grille.x, grille.y)
	_boite(Vector3(4.0, 4.0, 1.4), Vector3(grille.x, yg + 2.0, grille.y - 0.6), pierre, acropole)
	for k in 6:
		_boite(Vector3(0.08, 2.8, 0.08), Vector3(grille.x - 1.0 + k * 0.4, yg + 1.4, grille.y + 0.2), bronze, acropole, false)


# --- Le théâtre de Dionysos ---------------------------------------------------------------------

func _construire_theatre() -> void:
	var theatre := Node3D.new()
	theatre.name = "Theatre"
	_contenu.add_child(theatre)
	var bois := _mat_bois()
	# Les gradins de bois, posés sur la pente en demi-cercle.
	var r := 13.0
	while r < 30.5:
		var n := int(r * 0.8)
		for k in n:
			var a := lerpf(-PI + 0.15, -0.15, (k + 0.5) / n)
			var p := ORCHESTRE + Vector2(cos(a), sin(a)) * r
			var banc := _boite(Vector3(r * PI / n * 0.92, 0.42, 0.7), Vector3(p.x, hauteur(p.x, p.y) + 0.21, p.y), bois, theatre, false)
			banc.rotation.y = -a - PI / 2
		r += 1.8
	# L'orchestre : la piste ronde du chœur, l'autel de Dionysos au milieu.
	var y := H_ORCHESTRE
	var piste := MeshInstance3D.new()
	piste.mesh = _cylindre(11.0, 11.0, 0.06, 40)
	piste.material_override = _mat_choix(["dry_ground_01"], Color(0.72, 0.6, 0.46), 1.0, 3.0)
	piste.position = Vector3(ORCHESTRE.x, y + 0.03, ORCHESTRE.y)
	theatre.add_child(piste)
	_boite(Vector3(1.2, 0.9, 1.2), Vector3(ORCHESTRE.x, y + 0.45, ORCHESTRE.y), _mat_marbre(), theatre)
	# La skènè : la baraque de bois derrière la piste, où les acteurs changent de masque.
	var scene := Vector2(ORCHESTRE.x, ORCHESTRE.y + 15.0)
	_boite(Vector3(22.0, 6.0, 5.0), Vector3(scene.x, hauteur(scene.x, scene.y) + 3.0, scene.y), bois, theatre)
	_boite(Vector3(22.6, 0.3, 5.6), Vector3(scene.x, hauteur(scene.x, scene.y) + 6.1, scene.y), _mat_peint(ROUGE_GREC.darkened(0.2)), theatre, false)
	for k in 3:
		var porte := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 2.8)
		porte.mesh = q
		porte.material_override = _mat_peint(NOIR_POIX)
		porte.position = Vector3(scene.x - 6.0 + k * 6.0, hauteur(scene.x, scene.y) + 1.4, scene.y - 2.52)
		porte.rotation.y = PI
		theatre.add_child(porte)
	# Le temple de Dionysos, à côté.
	_maison_grecque(theatre, ORCHESTRE + Vector2(-26, 22), Vector3(9, 6.0, 14), 0.0)
	_fusionner(theatre)


# --- Les quartiers d'habitation -------------------------------------------------------------------

func _hors_quartiers(p: Vector2) -> bool:
	if _dans_rect(AGORA.grow(10.0), p.x, p.y, 0.1) > 0.5 or _distance_rues(p) < 5.5:
		return true
	if _sur_acropole(p.x, p.y) > 0.01 or Vector2((p.x - ACROPOLE.x) / (ACROPOLE_RAYONS.x + 14.0), (p.y - ACROPOLE.y) / (ACROPOLE_RAYONS.y + 14.0)).length() < 1.0:
		return true
	if p.distance_to(ORCHESTRE) < 40.0 or p.distance_to(PNYX) < 34.0 or p.distance_to(KOLONOS) < 40.0:
		return true
	if p.distance_to(LYDOS) < 20.0 or p.distance_to(ATELIER) < 26.0 or p.distance_to(DIPYLON) < 22.0:
		return true
	if p.distance_to(BOULEUTERION) < 16.0 or p.distance_to(ENTREE) < 12.0 or p.y > 144.0 or p.x < -150.0:
		return true
	return false


func _construire_quartiers() -> void:
	var ville := Node3D.new()
	ville.name = "Quartiers"
	_contenu.add_child(ville)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var pas := 11.0
	var x := -148.0
	while x < 152.0:
		var z := -152.0
		while z < 146.0:
			var p := Vector2(x + hasard.randf_range(-1.5, 1.5), z + hasard.randf_range(-1.5, 1.5))
			z += pas
			if _hors_quartiers(p) or hasard.randf() < 0.14:
				continue
			# Les maisons suivent la pente : on évite les flancs trop raides.
			if absf(hauteur(p.x + 4.0, p.y) - hauteur(p.x - 4.0, p.y)) > 3.0 or absf(hauteur(p.x, p.y + 4.0) - hauteur(p.x, p.y - 4.0)) > 3.0:
				continue
			var taille := Vector3(hasard.randf_range(6.5, 9.0), hasard.randf_range(3.6, 5.2), hasard.randf_range(6.0, 8.5))
			var angle: float = [0.0, PI / 2, PI, -PI / 2][hasard.randi() % 4] + hasard.randf_range(-0.06, 0.06)
			_maison_grecque(ville, p, taille, angle)
		x += pas
	_fusionner(ville)


func _construire_arbres() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Les platanes de l'Agora, plantés par Cimon pour donner de l'ombre.
	for k in 8:
		_olivier(arbres, Vector2(-48.0 + k * 11.0, 22.0), hasard, 1.9)
	for k in 4:
		_olivier(arbres, Vector2(30.0, -36.0 + k * 12.0), hasard, 1.7)
	# Des cyprès autour du Céramique et sur les pentes de la Pnyx.
	for k in 10:
		_cypres(arbres, LYDOS + Vector2(hasard.randf_range(-30, 18), hasard.randf_range(-36, -18)), hasard)
	for k in 8:
		var a := hasard.randf() * TAU
		_cypres(arbres, PNYX + Vector2(cos(a), sin(a)) * hasard.randf_range(26, 34), hasard)
	# Des oliviers dans les cours et les jardins.
	var poses := 0
	var essais := 0
	while poses < 50 and essais < 600:
		essais += 1
		var p := Vector2(hasard.randf_range(-150, 150), hasard.randf_range(-150, 140))
		if _distance_rues(p) < 4.0 or _dans_rect(AGORA.grow(2.0), p.x, p.y, 0.1) > 0.5 or _sur_acropole(p.x, p.y) > 0.01:
			continue
		if p.distance_to(ORCHESTRE) < 33.0:
			continue
		_olivier(arbres, p, hasard, hasard.randf_range(0.8, 1.2))
		poses += 1


# --- Paysage lointain ---------------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain(Vector3(0, 6.0, -1080), Vector2(4000, 1840), Color(0, 1, 0))
	_plan_lointain(Vector3(0, 6.0, 1080), Vector2(4000, 1840), Color(0, 1, 0))
	_plan_lointain(Vector3(-1080, 6.0, 0), Vector2(1840, 320), Color(0, 1, 0))
	_plan_lointain(Vector3(1080, 6.0, 0), Vector2(1840, 320), Color(0, 1, 0))
	# Le Lycabette (un piton pointu au nord-est), l'Hymette à l'est, le Parnès au nord.
	for m in [[Vector3(380, -10, -360), Vector3(200, 280, 200)], [Vector3(900, -10, 100), Vector3(500, 330, 1400)],
			[Vector3(0, -10, -1800), Vector3(1400, 300, 300)], [Vector3(-1200, -10, -300), Vector3(300, 160, 800)]]:
		bruit.seed = graine + hasard.randi()
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0, 0.6, 0.4))
		montagne.material_override = _mat_lointain()
		montagne.position = m[0]
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	# La ville continue au-delà des limites : des toits.
	var ville := Node3D.new()
	ville.name = "VilleLointaine"
	_contenu.add_child(ville)
	for k in 160:
		var a := hasard.randf() * TAU
		var d := hasard.randf_range(175, 300)
		var p := Vector2(cos(a), sin(a)) * d
		if p.y > 150.0:
			continue
		var maison := Node3D.new()
		maison.position = Vector3(p.x, 5.6, p.y)
		maison.rotation.y = hasard.randf_range(-0.2, 0.2)
		ville.add_child(maison)
		var taille := Vector3(hasard.randf_range(6, 10), hasard.randf_range(4, 6), hasard.randf_range(6, 9))
		_boite(taille, Vector3(0, taille.y * 0.5, 0), _mat_chaux(), maison, false)
		_toit(maison, Vector3(0, taille.y, 0), taille.x, taille.z)
	_fusionner(ville)


# --- Limites de la zone ---------------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 40, PORTE_SUD.y + 2.0))
	# Le rocher de l'Acropole : on n'y monte que par le donjon (plus tard).
	for k in 28:
		var a := TAU * k / 28.0
		var p := ACROPOLE + Vector2(cos(a) * (ACROPOLE_RAYONS.x + 8.0), sin(a) * (ACROPOLE_RAYONS.y + 8.0))
		_mur_invisible(limites, Vector3(14, 80, 2), Vector3(p.x, hauteur(p.x, p.y) + 30.0, p.y),
				-atan2(sin(a) * ACROPOLE_RAYONS.x, cos(a) * ACROPOLE_RAYONS.y) + PI / 2)


# --- Personnages et objets de la quête --------------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_pnj(dossier, "markos", MARKOS, 0.3)
	_pnj(dossier, "socrate", SOCRATE, 0.0)
	_pnj(dossier, "kallias", KALLIAS, -PI / 2)
	_pnj(dossier, "lydos", LYDOS, PI / 2)
	_pnj(dossier, "archer_agora", ARCHER, PI)
	_pnj(dossier, "marchande_figues", FIGUES, -PI / 2)
	# Les réponses des interrogatoires : des tablettes de cire, une par réponse.
	_reponse(dossier, "reponse_kallias_parle", "« Tu ne l'as jamais vu, mais tu sais qu'il parle bien ? »", KALLIAS + Vector2(-4, -3))
	_reponse(dossier, "reponse_kallias_fievre", "« Une fièvre ne change pas les gens en statue ! »", KALLIAS + Vector2(-4, 0))
	_reponse(dossier, "reponse_kallias_ment", "« Tu mens, poissonnier ! »", KALLIAS + Vector2(-4, 3))
	_reponse(dossier, "reponse_lydos_lin", "« Les masques, c'est du lin, pas de l'argile ! »", LYDOS + Vector2(4, -3))
	_reponse(dossier, "reponse_lydos_four", "« Ton four est froid ? Alors pourquoi fume-t-il ? »", LYDOS + Vector2(4, 0))
	_reponse(dossier, "reponse_lydos_vases", "« Montre-moi tes vases. »", LYDOS + Vector2(4, 3))
	# La table aux masques d'argile, sous le Portique peint, et la faille juste à côté.
	var masques := Node3D.new()
	masques.name = "MasquesPoikile"
	masques.set_meta("identifiant", "masques_poikile")
	masques.add_to_group("decor_quete")
	masques.position = Vector3(MASQUES.x, H_AGORA + 0.66, MASQUES.y)
	dossier.add_child(masques)
	_boite(Vector3(3.0, 0.9, 1.0), Vector3(0, 0.45, 0), _mat_bois(), masques)
	var platre := _mat_peint(Color(0.93, 0.9, 0.84), 0.6)
	for k in 6:
		var visage := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.14
		s.height = 0.34
		s.is_hemisphere = true
		visage.mesh = s
		visage.material_override = platre
		visage.scale = Vector3(1.0, 1.0, 0.45)
		visage.rotation = Vector3(-1.35, 0.3 * sin(k), 0)
		visage.position = Vector3(-1.2 + k * 0.48, 0.95, 0)
		masques.add_child(visage)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_poikile"
	faille.position = Vector3(FAILLE.x, H_AGORA + 0.66, FAILLE.y)
	dossier.add_child(faille)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Porte du Pirée", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Agora", Vector2(-10, -10))
	repere.call(MarqueurCarte.Type.LIEU, "Portique peint", POIKILE + Vector2(0, 4))
	repere.call(MarqueurCarte.Type.LIEU, "Temple d'Héphaïstos", KOLONOS)
	repere.call(MarqueurCarte.Type.LIEU, "Céramique", LYDOS)
	repere.call(MarqueurCarte.Type.LIEU, "Porte du Dipylon", DIPYLON + Vector2(6, 0))
	repere.call(MarqueurCarte.Type.LIEU, "Pnyx", BEMA)
	repere.call(MarqueurCarte.Type.LIEU, "Acropole", ACROPOLE + Vector2(0, -40))
	repere.call(MarqueurCarte.Type.LIEU, "Théâtre de Dionysos", ORCHESTRE)
	repere.call(MarqueurCarte.Type.DANGER, "Chiens errants", Vector2(-132, -76))


func _reponse(parent: Node3D, id: String, texte: String, p: Vector2) -> void:
	var o := ObjetGrece.new()
	o.name = id.capitalize().replace(" ", "")
	o.identifiant = id
	o.forme = "tablette"
	o.invite = "[F] Répondre : " + texte
	o.portee = 1.6
	o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	parent.add_child(o)


## Partie reprise après les Pétrifiés : ils sont déjà debout, devant le portique.
func _reprendre_etat() -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	if quete.etape_atteinte("cherephon") and _liberes == 0:
		for k in NOMS_LIBERES.size():
			_pnj(_dossier_quete, NOMS_LIBERES[k], LIBERES[k], PI * 0.1 * k)
		_liberes = NOMS_LIBERES.size()


# --- Sortie : la porte du sud, vers les Oliveraies ---------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	var quete := get_tree().get_first_node_in_group("quete")
	if not _etat_repris and quete != null and quete.get("etapes") != null and not quete.etapes.is_empty():
		_etat_repris = true
		_reprendre_etat.call_deferred()
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if quete == null or joueur == null or not quete.has_method("changer_de_zone"):
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.y > PORTE_SUD.y - 4.0 and absf(p.x) < 5.0:
		quete.changer_de_zone("oliveraies")
