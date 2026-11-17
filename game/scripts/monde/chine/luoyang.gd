@tool
extends "res://scripts/monde/chine/ile_chine.gd"
## Île de la Chine, zone 3 : Luoyang, la capitale des Han (niveaux 44-48).
##
## L'hiver de l'an 105, quelques semaines avant le Nouvel An. Une ville immense, enfermée
## dans de hauts murs de terre damée. On entre par la porte de l'ouest, au bout de la route
## du Fleuve Jaune. Une grande avenue file d'ouest en est. Au sud de l'avenue, le Palais du
## Sud (la grande salle des audiences) et, à côté, le pavillon de l'Est : la bibliothèque
## où Ban Zhao termine le Livre des Han. Au nord, le Palais du Nord, relié à celui du Sud
## par une longue galerie couverte, perchée sur des piliers. Au nord-ouest, les ateliers
## impériaux de Cai Lun et le parc impérial ; au sud-ouest, le grand marché ; au nord-est,
## l'Académie impériale ; à l'est, la Plate-forme des esprits (l'observatoire).
##
## Tout est construit par le code (voir ile_chine.gd). Le bouton « Reconstruire » de
## l'Inspecteur refait tout. Repères : le nord est vers -Z.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetChine := preload("res://scripts/monde/chine/objet_chine.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const CharPoste := preload("res://scripts/monde/chine/char_poste.gd")

const SOL := 3.0

## La route qui arrive du Fleuve Jaune, à l'ouest, et l'enceinte de la ville.
const ENTREE := Vector2(-184, 20)
const ENCEINTE := Rect2(-150, -160, 300, 280)
const HAUT_ENCEINTE := 9.0
const PORTE_OUEST := Vector2(-150, 20)
## Les deux grandes avenues.
const AVENUE := 20.0
const AVENUE_NS := -60.0

## Les palais et la galerie couverte qui les relie.
const PALAIS_SUD := Rect2(-30, 44, 100, 70)
const SALLE_SUD := Vector2(20, 94)
const PALAIS_NORD := Rect2(-30, -150, 100, 60)
const SALLE_NORD := Vector2(20, -124)
const GALERIE_X := 20.0
## Le pavillon de l'Est (la bibliothèque), à l'est du Palais du Sud.
const PAVILLON := Rect2(80, 46, 46, 46)
const BIBLIOTHEQUE := Vector2(103, 76)
const HAUT_BIBLIOTHEQUE := 1.6
const BAN_ZHAO := Vector2(103, 54)
const RAYONNAGES := [Vector2(-5.5, -2.5), Vector2(0.0, -2.5), Vector2(5.5, -2.5), Vector2(-3.0, 2.0)]
const LIASSES := [Vector2(94, 62), Vector2(112, 62), Vector2(88, 72), Vector2(118, 74), Vector2(100, 86)]
const MANUSCRIT := Vector2(108, 77)
const ETUDIANTS := [Vector2(96, 56), Vector2(110, 57), Vector2(90, 60)]
const PORTAIL_QG := Vector2(90, 84)
## Les ateliers impériaux de Cai Lun.
const ATELIER := Rect2(-132, -68, 54, 42)
const CAI_LUN := Vector2(-104, -36)
const CUVES := [Vector2(-118, -48), Vector2(-108, -48), Vector2(-98, -48)]
const ECORCES := [Vector2(-124, -60), Vector2(-120, -61), Vector2(-116, -60)]
const PILON := Vector2(-88, -60)
const TAMIS := Vector2(-108, -45.5)
const SECHOIR := Vector2(-86, -40)
const OUVRIERS := [Vector2(-112, -54), Vector2(-94, -54), Vector2(-122, -40)]
## Le grand marché, et le chemin du saboteur.
const MARCHE := Rect2(-132, 40, 62, 62)
const MARCHANDS := [Vector2(-116, 54), Vector2(-96, 58), Vector2(-112, 76), Vector2(-88, 82), Vector2(-122, 92)]
const FIOLE := Vector2(-126, 98)
## Le parc impérial et son tigre.
const PARC := Rect2(-146, -156, 72, 70)
const ETANG := Vector2(-116, -124)
const TIGRE := Vector2(-98, -110)
## L'Académie impériale et l'observatoire.
const ACADEMIE := Rect2(70, -146, 60, 48)
const LINGTAI := Vector2(112, -40)
## Le char de poste vers le mont Li, juste derrière la porte de l'Ouest.
const CHAR_POSTE := Vector2(-134, 11)

var _portail_qg: Node3D
var _incendie: Node3D
var _rayonnages: Array[Node3D] = []


func _init() -> void:
	identifiant_zone = "luoyang"
	taille_terrain = 380
	graine = 1105
	point_apparition = ENTREE + Vector2(10, 0)
	nombre_touffes = 9000
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre battue des rues et des cours.
		"galets": ["mud_cracked_dry_03", "dry_ground_01", "brown_mud_02"],
		# Vert : la neige tassée dans les coins et au pied des murs.
		"neige": ["snow_02", "snow_03", "snow_02"],
		# Bleu : l'herbe sèche des jardins et du parc.
		"sol": ["withered_grass", "dry_ground_01", "dry_ground_rocks"],
		"roche": ["sandstone_cracks", "quarry_wall", "clay_block_wall"],
	}
	reglages_terrain = {"sol_saturation": 0.8, "sol_motif": 5.0, "galets_motif": 4.0, "neige_motif": 6.0,
			"sol_teinte": Color(0.92, 0.86, 0.76), "roche_teinte": Color(1.05, 0.9, 0.66), "roche_saturation": 0.9}
	reglages_herbe = {"couleur_base": Color(0.3, 0.27, 0.15), "couleur_pointe": Color(0.72, 0.64, 0.42),
			"couleur_givre": Color(0.8, 0.78, 0.7), "force_vent": 0.2}
	piste = [ENTREE, PORTE_OUEST, Vector2(140, AVENUE)]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_chine", "") != "":
		var venu := String(Reseau.get_meta("arrivee_chine"))
		Reseau.remove_meta("arrivee_chine")
		# Retour du mont Li : on descend du char de poste, derrière la porte de l'Ouest.
		if venu == "mont_li":
			point_apparition = CHAR_POSTE + Vector2(3, 5)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "fleuve_jaune":
		return ENTREE
	if zone == "mont_li":
		return CHAR_POSTE
	return Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.006


func dans_la_ville(x: float, z: float) -> float:
	return _dans_rect(ENCEINTE, x, z, 4.0)


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# Dehors, la campagne ondule un peu ; dedans, la ville est plate (on l'a nivelée).
	var h := SOL + bruit * 1.2 + fin * 0.06
	h = lerpf(h, SOL + fin * 0.03, dans_la_ville(x, z))
	# L'étang du parc impérial, gelé.
	h = lerpf(h, SOL - 0.6, 1.0 - smoothstep(10.0, 14.0, Vector2(x, z).distance_to(ETANG)))
	return h


## Rouge : terre battue ; vert : neige ; bleu : herbe sèche (parc, jardins, campagne).
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var herbe := 1.0 - dans_la_ville(x, z)
	herbe = maxf(herbe, _dans_rect(PARC.grow(-2.0), x, z, 4.0))
	herbe = maxf(herbe, _dans_rect(ACADEMIE.grow(-6.0), x, z, 3.0) * 0.8)
	var neige := smoothstep(0.35, 0.65, n) * 0.6
	# La neige tassée au pied de l'enceinte.
	var bord := minf(minf(x - ENCEINTE.position.x, ENCEINTE.end.x - x), minf(z - ENCEINTE.position.y, ENCEINTE.end.y - z))
	neige = maxf(neige, (1.0 - smoothstep(4.0, 9.0, absf(bord))) * 0.8)
	var rue := maxf(0.0, 1.0 - herbe - neige)
	return Color(rue + 0.001, neige, herbe * (1.0 - neige), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_enceinte()
	_construire_palais()
	_construire_galerie()
	_construire_pavillon_est()
	_construire_atelier()
	_construire_marche()
	_construire_parc()
	_construire_academie()
	_construire_quartiers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


## Un rectangle « r » contient-il le point, avec une marge ?
func _occupe(p: Vector2, marge := 4.0) -> bool:
	for r: Rect2 in [PALAIS_SUD, PALAIS_NORD, PAVILLON, ATELIER, MARCHE, PARC, ACADEMIE, Rect2(LINGTAI - Vector2(14, 14), Vector2(28, 28))]:
		if r.grow(marge).has_point(p):
			return true
	if absf(p.y - AVENUE) < 9.0 + marge or absf(p.x - AVENUE_NS) < 6.0 + marge:
		return true
	if absf(p.x - GALERIE_X) < 4.0 + marge and p.y > PALAIS_NORD.end.y and p.y < PALAIS_SUD.position.y:
		return true
	return false


# --- L'enceinte et ses portes -------------------------------------------------------------------

func _construire_enceinte() -> void:
	var dossier := Node3D.new()
	dossier.name = "Enceinte"
	_contenu.add_child(dossier)
	var terre := _mat_terre_damee()
	var r := ENCEINTE
	var e := 7.0
	var h := HAUT_ENCEINTE
	var y := SOL
	var largeur_porte := 10.0
	# Nord et sud : d'un seul tenant (la porte sud reste fermée : on ne la voit que de loin).
	for z: float in [r.position.y, r.end.y]:
		_boite(Vector3(r.size.x + e, h, e), Vector3(r.get_center().x, y + h * 0.5 - 0.3, z), terre, dossier)
	# Est : d'un seul tenant. Ouest : coupé par la porte, sur l'avenue.
	_boite(Vector3(e, h, r.size.y), Vector3(r.end.x, y + h * 0.5 - 0.3, r.get_center().y), terre, dossier)
	var nord := (PORTE_OUEST.y - largeur_porte * 0.5) - r.position.y
	var sud := r.end.y - (PORTE_OUEST.y + largeur_porte * 0.5)
	_boite(Vector3(e, h, nord), Vector3(r.position.x, y + h * 0.5 - 0.3, r.position.y + nord * 0.5), terre, dossier)
	_boite(Vector3(e, h, sud), Vector3(r.position.x, y + h * 0.5 - 0.3, r.end.y - sud * 0.5), terre, dossier)
	# Le dessus de la porte ouest : un linteau de terre, et un pavillon de garde à deux étages.
	_boite(Vector3(e, 3.0, largeur_porte), Vector3(r.position.x, y + h - 1.8, PORTE_OUEST.y), terre, dossier)
	var tour := _pavillon_han(dossier, PORTE_OUEST, Vector2(10, 5), PI / 2, 0.0, 2, true, "PorteOuest")
	tour.position.y = y + h - 0.3
	# Des tours de garde aux angles et au milieu des longs murs.
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end,
			Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Vector2(r.end.x, PORTE_OUEST.y)]:
		_boite(Vector3(11, h + 2.0, 11), Vector3(p.x, y + (h + 2.0) * 0.5 - 0.3, p.y), terre, dossier)
		var garde := Node3D.new()
		garde.position = Vector3(p.x, y + h + 1.7, p.y)
		dossier.add_child(garde)
		_toit_croupe(garde, Vector3(0, 2.4, 0), 6.0, 6.0, 1.8)
		for c in 4:
			var q := Vector2(-2.6 if c < 2 else 2.6, -2.6 if c % 2 == 0 else 2.6)
			var pilier := MeshInstance3D.new()
			pilier.mesh = _cylindre(0.2, 0.22, 2.4, 8)
			pilier.material_override = _mat_laque()
			pilier.position = Vector3(q.x, 1.2, q.y)
			garde.add_child(pilier)
	# La porte est (décor) : deux battants rouges cloutés.
	var battants := _boite(Vector3(0.4, 6.0, 9.0), Vector3(r.end.x - e * 0.5 - 0.3, y + 2.7, PORTE_OUEST.y), _mat_laque(), dossier, false)
	battants.name = "PorteEst"
	# La route, dehors, vers le Fleuve Jaune ; des saules nus le long du fossé.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	for k in 6:
		_peuplier_hiver(dossier, Vector2(-158.0 - k * 5.0, PORTE_OUEST.y + (9.0 if k % 2 == 0 else -9.0)), hasard, 0.9)
	_fusionner(dossier)


# --- Les palais ---------------------------------------------------------------------------------

func _construire_palais() -> void:
	var dossier := Node3D.new()
	dossier.name = "Palais"
	_contenu.add_child(dossier)
	for p in [[PALAIS_SUD, SALLE_SUD, "PalaisSud", 0.0], [PALAIS_NORD, SALLE_NORD, "PalaisNord", 1.0]]:
		var r: Rect2 = p[0]
		var salle: Vector2 = p[1]
		var nom: String = p[2]
		var cote_porte: float = p[3]
		var enclos := Node3D.new()
		enclos.name = nom
		dossier.add_child(enclos)
		var a := r.position
		var b := Vector2(r.end.x, r.position.y)
		var c := r.end
		var d := Vector2(r.position.x, r.end.y)
		# La grande porte donne sur l'avenue (au nord pour le Palais du Sud, au sud pour celui du Nord).
		var milieu := (GALERIE_X - r.position.x) / r.size.x
		_mur_palais(enclos, a, b, 5.0, [milieu] if cote_porte == 0.0 else [], 8.0)
		_mur_palais(enclos, d, c, 5.0, [milieu] if cote_porte == 1.0 else [], 8.0)
		_mur_palais(enclos, a, d, 5.0)
		_mur_palais(enclos, b, c, 5.0, [0.5] if nom == "PalaisSud" else [], 5.0)
		var grande := _pavillon_han(enclos, salle, Vector2(30, 13), 0.0 if cote_porte == 0.0 else PI, 2.6, 1, false, "GrandeSalle")
		grande.name = "GrandeSalle"
		# Deux pavillons latéraux et des lanternes dans la cour.
		for cote: float in [-1.0, 1.0]:
			var q := salle + Vector2(cote * 34.0, (-6.0 if cote_porte == 0.0 else 6.0))
			_pavillon_han(enclos, q, Vector2(12, 8), 0.0 if cote_porte == 0.0 else PI, 1.2, 1, false, "PavillonLateral")
		var sens := -1.0 if cote_porte == 0.0 else 1.0
		for k in 4:
			for cote: float in [-1.0, 1.0]:
				var q := Vector2(GALERIE_X + cote * 9.0, salle.y + sens * (16.0 + k * 9.0))
				_lanterne(enclos, Vector3(q.x, hauteur(q.x, q.y), q.y))
		# Des brûle-parfums de bronze devant l'escalier.
		for cote: float in [-1.0, 1.0]:
			var q := salle + Vector2(cote * 5.0, sens * 13.0)
			var bronze := MeshInstance3D.new()
			bronze.mesh = _cylindre(0.55, 0.4, 1.0, 12)
			bronze.material_override = _mat_pbr("", Color(0.28, 0.32, 0.24), 0.4)
			bronze.position = Vector3(q.x, hauteur(q.x, q.y) + 0.7, q.y)
			enclos.add_child(bronze)
	_fusionner(dossier)


## La galerie couverte, perchée sur des piliers, qui relie les deux palais par-dessus l'avenue.
func _construire_galerie() -> void:
	var dossier := Node3D.new()
	dossier.name = "Galerie"
	_contenu.add_child(dossier)
	var z0 := PALAIS_NORD.end.y
	var z1 := PALAIS_SUD.position.y
	var laque := _mat_laque()
	var bois := _mat_bois()
	var haut := 6.5
	var z := z0
	while z <= z1:
		for c: float in [-1.0, 1.0]:
			var pilier := MeshInstance3D.new()
			pilier.mesh = _cylindre(0.28, 0.32, haut + 3.0, 8)
			pilier.material_override = laque
			pilier.position = Vector3(GALERIE_X + c * 2.4, SOL + (haut + 3.0) * 0.5 - 0.2, z)
			dossier.add_child(pilier)
		z += 8.0
	var l := z1 - z0
	_boite(Vector3(5.6, 0.5, l), Vector3(GALERIE_X, SOL + haut, (z0 + z1) * 0.5), bois, dossier, false)
	for c: float in [-1.0, 1.0]:
		_boite(Vector3(0.2, 1.0, l), Vector3(GALERIE_X + c * 2.6, SOL + haut + 0.75, (z0 + z1) * 0.5), laque, dossier, false)
	var toit := Node3D.new()
	toit.position = Vector3(GALERIE_X, SOL + haut + 2.8, (z0 + z1) * 0.5)
	toit.rotation.y = PI / 2
	dossier.add_child(toit)
	_toit_croupe(toit, Vector3.ZERO, l, 4.2, 1.2)
	_fusionner(dossier)


# --- Le pavillon de l'Est (la bibliothèque) --------------------------------------------------------

func _construire_pavillon_est() -> void:
	var dossier := Node3D.new()
	dossier.name = "PavillonEst"
	_contenu.add_child(dossier)
	var r := PAVILLON
	_mur_palais(dossier, r.position, Vector2(r.end.x, r.position.y), 4.0, [0.5], 5.0)
	_mur_palais(dossier, Vector2(r.position.x, r.end.y), r.end, 4.0)
	_mur_palais(dossier, r.position, Vector2(r.position.x, r.end.y), 4.0, [0.5], 4.0)
	_mur_palais(dossier, Vector2(r.end.x, r.position.y), r.end, 4.0)
	# La bibliothèque : un pavillon à deux étages, ouvert sur ses piliers (on y entre de
	# partout), plein d'étagères de livres en lattes de bambou.
	var biblio := _pavillon_han(dossier, BIBLIOTHEQUE, Vector2(20, 12), 0.0, HAUT_BIBLIOTHEQUE, 2, true, "Bibliotheque")
	var bois := _mat_choix(["wooden_rough_planks"], Color(0.4, 0.24, 0.14), 0.8, 1.0)
	var bambou := _mat_pbr("", Color(0.78, 0.68, 0.42), 0.8)
	var lien := _mat_pbr("", Color(0.6, 0.1, 0.08), 0.7)
	var etageres := [Vector2(-8.0, 4.5), Vector2(8.0, 4.5), Vector2(-8.0, -4.5), Vector2(8.0, -4.5)]
	for e: Vector2 in etageres:
		var y := HAUT_BIBLIOTHEQUE
		_boite(Vector3(2.4, 2.2, 0.6), Vector3(e.x, y + 1.1, e.y), bois, biblio)
		for k in 3:
			for i in 7:
				var liasse := MeshInstance3D.new()
				liasse.mesh = _cylindre(0.08, 0.08, 0.3, 8)
				liasse.material_override = bambou if i % 3 != 0 else lien
				liasse.rotation.x = PI / 2
				liasse.position = Vector3(e.x - 1.0 + i * 0.33, y + 0.4 + k * 0.7, e.y + (0.36 if e.y > 0 else -0.36))
				biblio.add_child(liasse)
	# Des tables basses de lecture, avec des pinceaux et des pierres à encre.
	for k in 3:
		_boite(Vector3(1.6, 0.4, 0.8), Vector3(-4.0 + k * 4.0, HAUT_BIBLIOTHEQUE + 0.2, 4.0), bois, biblio, false)
	# Des pruniers en fleurs dans la cour (en plein hiver, les premières fleurs de l'année).
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 31
	for q: Vector2 in [Vector2(86, 52), Vector2(122, 52), Vector2(86, 88), Vector2(122, 88)]:
		var arbre := _murier(dossier, q, hasard, 1.1)
		var fleurs := StandardMaterial3D.new()
		fleurs.albedo_color = Color(0.95, 0.72, 0.78)
		for k in 14:
			var f := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.25
			s.height = 0.4
			s.radial_segments = 6
			s.rings = 3
			f.mesh = s
			f.material_override = fleurs
			var a := hasard.randf() * TAU
			f.position = Vector3(cos(a) * hasard.randf_range(0.3, 1.4), hasard.randf_range(2.2, 3.4), sin(a) * hasard.randf_range(0.3, 1.4))
			arbre.add_child(f)
	# La fumée de l'incendie (chapitre 5), cachée jusque-là.
	var incendie := Node3D.new()
	incendie.name = "IncendieBibliotheque"
	incendie.set_meta("identifiant", "incendie_bibliotheque")
	incendie.add_to_group("decor_quete")
	incendie.visible = false
	_incendie = incendie
	incendie.position = Vector3(BIBLIOTHEQUE.x, hauteur(BIBLIOTHEQUE.x, BIBLIOTHEQUE.y) + 9.0, BIBLIOTHEQUE.y)
	dossier.add_child(incendie)
	_fumee_dans_zone(incendie, 1.8)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.5, 0.2)
	lumiere.light_energy = 3.0
	lumiere.omni_range = 18.0
	lumiere.position.y = -5.0
	incendie.add_child(lumiere)


## Une colonne de fumée noire (un incendie), en particules douces.
func _fumee_dans_zone(parent: Node3D, grosse := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(60 * grosse)
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.5 * grosse
	p.direction = Vector3(0, 1, 0)
	p.spread = 10.0
	p.gravity = Vector3(0.4, 0.5, 0.1)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.8
	var taille := Curve.new()
	taille.max_value = 8.0
	taille.add_point(Vector2(0, 1.0))
	taille.add_point(Vector2(1, 6.0 * grosse))
	p.scale_amount_curve = taille
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.1, 0.09, 0.08, 0.75))
	teinte.set_color(1, Color(0.35, 0.33, 0.3, 0.0))
	p.color_ramp = teinte
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_color(1, Color(1, 1, 1, 0))
	var tache := GradientTexture2D.new()
	tache.gradient = degrade
	tache.fill = GradientTexture2D.FILL_RADIAL
	tache.fill_from = Vector2(0.5, 0.5)
	tache.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tache
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


# --- Les ateliers impériaux de Cai Lun ------------------------------------------------------------

func _construire_atelier() -> void:
	var dossier := Node3D.new()
	dossier.name = "Atelier"
	_contenu.add_child(dossier)
	var r := ATELIER
	_mur_palais(dossier, r.position, Vector2(r.end.x, r.position.y), 3.6)
	_mur_palais(dossier, Vector2(r.position.x, r.end.y), r.end, 3.6, [0.5], 5.0)
	_mur_palais(dossier, r.position, Vector2(r.position.x, r.end.y), 3.6)
	_mur_palais(dossier, Vector2(r.end.x, r.position.y), r.end, 3.6)
	# L'atelier de Cai Lun (au fond), deux remises et la maison des ouvriers.
	_pavillon_han(dossier, Vector2(r.get_center().x, r.position.y + 6.0), Vector2(18, 6), 0.0, 0.8, 1, false, "AtelierCaiLun")
	_maison_han(dossier, Vector2(r.position.x + 6.0, r.get_center().y + 6.0), Vector3(7, 2.6, 4.5), PI / 2, true)
	_maison_han(dossier, Vector2(r.end.x - 5.0, r.get_center().y + 6.0), Vector3(7, 2.6, 4.5), -PI / 2, true)
	# Le séchoir : un long mur enduit, couvert de feuilles qui sèchent.
	var feuille := StandardMaterial3D.new()
	feuille.albedo_color = Color(0.93, 0.9, 0.82)
	var s := SECHOIR + Vector2(0, -1.6)
	var ys := hauteur(s.x, s.y)
	_boite(Vector3(8.0, 2.4, 0.5), Vector3(s.x, ys + 1.2, s.y), _mat_torchis(), dossier)
	_boite(Vector3(8.6, 0.2, 1.1), Vector3(s.x, ys + 2.45, s.y), _mat_tuiles_han(), dossier, false)
	for i in 9:
		for j in 2:
			if i == 4 and j == 0:
				continue
			_boite(Vector3(0.62, 0.72, 0.01), Vector3(s.x - 3.6 + i * 0.9, ys + 0.8 + j * 0.9, s.y + 0.27), feuille, dossier, false)
	# Le pilon à bascule et son mortier.
	var yp := hauteur(PILON.x, PILON.y)
	var bois := _mat_bois()
	_boite(Vector3(4.2, 0.22, 0.22), Vector3(PILON.x, yp + 0.75, PILON.y), bois, dossier, false).rotation.z = 0.12
	_boite(Vector3(0.3, 0.8, 0.3), Vector3(PILON.x + 0.4, yp + 0.4, PILON.y), bois, dossier, false)
	var mortier := MeshInstance3D.new()
	mortier.mesh = _cylindre(0.45, 0.5, 0.5, 10)
	mortier.material_override = _mat_choix(["old_stone_wall"], Color(0.62, 0.6, 0.56), 0.9, 1.0)
	mortier.position = Vector3(PILON.x - 1.9, yp + 0.25, PILON.y)
	dossier.add_child(mortier)
	# Des chiffons, du chanvre et de vieux filets de pêche, prêts à être pilés.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 14
	for k in 14:
		var q := Vector2(-84 + hasard.randf_range(-2, 2), -52 + hasard.randf_range(-2, 2))
		var tissu: Color = SOIES[hasard.randi() % SOIES.size()].darkened(0.35)
		_boite(Vector3(0.6, 0.12, 0.5), Vector3(q.x, hauteur(q.x, q.y) + 0.06 + hasard.randf() * 0.3, q.y), _mat_feutre(tissu), dossier, false).rotation.y = hasard.randf() * TAU
	for k in 2:
		_lanterne(dossier, Vector3(r.get_center().x + (k * 2 - 1) * 6.0, hauteur(r.get_center().x, r.end.y - 3.0), r.end.y - 3.0))
	_fusionner(dossier)


# --- Le grand marché ------------------------------------------------------------------------------

func _construire_marche() -> void:
	var dossier := Node3D.new()
	dossier.name = "Marche"
	_contenu.add_child(dossier)
	var r := MARCHE
	_mur_palais(dossier, r.position, Vector2(r.end.x, r.position.y), 3.0, [0.5], 6.0)
	_mur_palais(dossier, Vector2(r.position.x, r.end.y), r.end, 3.0)
	_mur_palais(dossier, r.position, Vector2(r.position.x, r.end.y), 3.0)
	_mur_palais(dossier, Vector2(r.end.x, r.position.y), r.end, 3.0, [0.5], 6.0)
	# Les rangées d'échoppes : un auvent de toile sur des poteaux, un étal, des marchandises.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var bois := _mat_bois()
	for rang in 4:
		var z := r.position.y + 10.0 + rang * 13.0
		var x := r.position.x + 6.0
		while x < r.end.x - 6.0:
			if absf(x - r.get_center().x) < 4.0:
				x += 7.0
				continue
			var y := hauteur(x, z)
			var toile: Color = SOIES[hasard.randi() % SOIES.size()].lerp(Color(0.8, 0.74, 0.6), 0.4)
			for c in 4:
				var q := Vector2(-2.4 if c < 2 else 2.4, -1.4 if c % 2 == 0 else 1.4)
				var poteau := MeshInstance3D.new()
				poteau.mesh = _cylindre(0.06, 0.07, 2.4, 6)
				poteau.material_override = bois
				poteau.position = Vector3(x + q.x, y + 1.2, z + q.y)
				dossier.add_child(poteau)
			var auvent := _boite(Vector3(5.4, 0.08, 3.4), Vector3(x, y + 2.4, z), _mat_feutre(toile), dossier, false)
			auvent.rotation.x = 0.12
			_boite(Vector3(4.2, 0.9, 1.0), Vector3(x, y + 0.45, z - 0.6), bois, dossier)
			# Sur l'étal : des ballots de soie, des jarres, des paniers…
			match hasard.randi() % 3:
				0:
					_ballots_soie(dossier, Vector2(x, z - 0.6), 0.0, 3).position.y += 0.9
				1:
					for k in 3:
						_jarre(dossier, Vector3(x - 1.2 + k * 1.2, y + 0.9, z - 0.6), 0.6, hasard.randf() * TAU)
				_:
					for k in 4:
						var panier := MeshInstance3D.new()
						panier.mesh = _cylindre(0.3, 0.22, 0.3, 10)
						panier.material_override = _mat_roseaux()
						panier.position = Vector3(x - 1.5 + k, y + 1.05, z - 0.6)
						dossier.add_child(panier)
			x += 7.0
	for k in 6:
		var q := Vector2(r.get_center().x + (k % 2 * 2 - 1) * 2.2, r.position.y + 6.0 + k * 9.0)
		_lanterne(dossier, Vector3(q.x, hauteur(q.x, q.y), q.y))
	_fusionner(dossier)


# --- Le parc impérial ------------------------------------------------------------------------------

func _construire_parc() -> void:
	var dossier := Node3D.new()
	dossier.name = "Parc"
	_contenu.add_child(dossier)
	var r := PARC
	_mur_palais(dossier, Vector2(r.position.x, r.end.y), r.end, 3.0, [0.5], 5.0)
	_mur_palais(dossier, Vector2(r.end.x, r.position.y), r.end, 3.0)
	# L'étang gelé et son petit pavillon.
	var glace := MeshInstance3D.new()
	glace.name = "EtangGele"
	glace.mesh = _cylindre(12.0, 12.0, 0.05, 32)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.78, 0.82)
	m.roughness = 0.1
	glace.material_override = m
	glace.position = Vector3(ETANG.x, SOL - 0.45, ETANG.y)
	dossier.add_child(glace)
	_pavillon_han(dossier, ETANG + Vector2(16, -6), Vector2(5, 5), 0.0, 0.6, 1, true, "KiosqueEtang")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	var plantes := 0
	var essais := 0
	while plantes < 40 and essais < 600:
		essais += 1
		var q := Vector2(hasard.randf_range(r.position.x + 4, r.end.x - 4), hasard.randf_range(r.position.y + 4, r.end.y - 4))
		if q.distance_to(ETANG) < 15.0 or q.distance_to(TIGRE) < 8.0 or q.distance_to(ETANG + Vector2(16, -6)) < 7.0:
			continue
		if hasard.randf() < 0.5:
			_peuplier_hiver(dossier, q, hasard, hasard.randf_range(0.8, 1.1))
		else:
			_murier(dossier, q, hasard, hasard.randf_range(1.0, 1.4))
		plantes += 1
	_preparer_rochers()
	for k in 10:
		var a := hasard.randf() * TAU
		var q := ETANG + Vector2(cos(a), sin(a)) * hasard.randf_range(12.5, 15.0)
		_placer_rocher(dossier, q.x, q.y, hasard.randf_range(0.6, 1.4))


# --- L'Académie impériale et l'observatoire ---------------------------------------------------------

func _construire_academie() -> void:
	var dossier := Node3D.new()
	dossier.name = "Academie"
	_contenu.add_child(dossier)
	var r := ACADEMIE
	_mur_palais(dossier, r.position, Vector2(r.end.x, r.position.y), 3.6)
	_mur_palais(dossier, Vector2(r.position.x, r.end.y), r.end, 3.6, [0.5], 5.0)
	_mur_palais(dossier, r.position, Vector2(r.position.x, r.end.y), 3.6)
	_mur_palais(dossier, Vector2(r.end.x, r.position.y), r.end, 3.6)
	_pavillon_han(dossier, Vector2(r.get_center().x, r.position.y + 12.0), Vector2(24, 10), 0.0, 1.4, 1, false, "SalleAcademie")
	for c: float in [-1.0, 1.0]:
		_maison_han(dossier, Vector2(r.get_center().x + c * 20.0, r.get_center().y + 10.0), Vector3(10, 2.8, 5), 0.0)
	# La Plate-forme des esprits : une terrasse de terre à trois étages, où l'on observait
	# le ciel (un petit pavillon en haut).
	var obs := Node3D.new()
	obs.name = "Lingtai"
	dossier.add_child(obs)
	var y := hauteur(LINGTAI.x, LINGTAI.y)
	var terre := _mat_terre_damee()
	for k in 3:
		var c := 24.0 - k * 7.0
		_boite(Vector3(c, 3.2, c), Vector3(LINGTAI.x, y + 1.5 + k * 3.2, LINGTAI.y), terre, obs)
	var haut := Node3D.new()
	haut.position = Vector3(LINGTAI.x, y + 9.5, LINGTAI.y)
	obs.add_child(haut)
	_toit_croupe(haut, Vector3(0, 3.0, 0), 5.0, 5.0, 1.6)
	for c in 4:
		var q := Vector2(-2.2 if c < 2 else 2.2, -2.2 if c % 2 == 0 else 2.2)
		var pilier := MeshInstance3D.new()
		pilier.mesh = _cylindre(0.2, 0.22, 3.0, 8)
		pilier.material_override = _mat_laque()
		pilier.position = Vector3(q.x, 1.5, q.y)
		haut.add_child(pilier)
	_fusionner(dossier)


# --- Les quartiers d'habitation ------------------------------------------------------------------

func _construire_quartiers() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quartiers"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Des maisons serrées le long de l'avenue (boutiques, auberges), tournées vers elle.
	var x := ENCEINTE.position.x + 12.0
	while x < ENCEINTE.end.x - 10.0:
		for cote: float in [-1.0, 1.0]:
			var q := Vector2(x, AVENUE + cote * 13.5)
			var libre := true
			for r: Rect2 in [PALAIS_SUD, PALAIS_NORD, PAVILLON, ATELIER, MARCHE, PARC, ACADEMIE]:
				if r.grow(3.0).has_point(q):
					libre = false
			if absf(q.x - AVENUE_NS) < 9.0 or absf(q.x - GALERIE_X) < 8.0:
				libre = false
			if libre:
				_maison_han(dossier, q, Vector3(hasard.randf_range(7.0, 9.0), hasard.randf_range(2.6, 3.2), 5.0), 0.0 if cote > 0.0 else PI)
				if hasard.randf() < 0.5:
					_lanterne(dossier, Vector3(q.x + 4.6, SOL, q.y - cote * 3.6))
		x += 11.0
	# Et des cours d'habitation partout où il reste de la place.
	var poses := 0
	var essais := 0
	while poses < 60 and essais < 1500:
		essais += 1
		var q := Vector2(hasard.randf_range(ENCEINTE.position.x + 12.0, ENCEINTE.end.x - 12.0),
				hasard.randf_range(ENCEINTE.position.y + 12.0, ENCEINTE.end.y - 12.0))
		if _occupe(q, 7.0):
			continue
		var deja := false
		for n in dossier.get_children():
			if n is Node3D and Vector2((n as Node3D).position.x, (n as Node3D).position.z).distance_to(q) < 12.0:
				deja = true
				break
		if deja:
			continue
		_maison_han(dossier, q, Vector3(hasard.randf_range(7.0, 10.0), hasard.randf_range(2.6, 3.0), hasard.randf_range(4.5, 5.5)),
				(hasard.randi() % 4) * PI / 2, hasard.randf() < 0.25)
		poses += 1
	_fusionner(dossier)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain(Vector3(0, SOL - 0.6, 0), Vector2(4000, 4000), Color(0, 0.1, 0.9))
	# Les monts Mang au nord, et les montagnes de Song, bleues, au sud.
	for m in [[Vector3(-300, -10, -900), Vector3(1600, 140, 500)], [Vector3(600, -10, -1100), Vector3(1200, 120, 600)],
			[Vector3(0, -10, 1300), Vector3(1800, 260, 600)], [Vector3(-1400, -10, 200), Vector3(600, 120, 1200)]]:
		bruit.seed = graine + hasard.randi()
		var colline := MeshInstance3D.new()
		colline.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0.2, 0.25 if m[1].y > 200 else 0.1, 0.3))
		colline.material_override = _mat_lointain()
		colline.position = m[0]
		colline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colline)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, demi))
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(demi, 40, 0))
	# À l'ouest, on repart vers le Fleuve Jaune par la route.
	_mur_invisible(limites, Vector3(2, 120, demi + ENTREE.y - 6.0), Vector3(-demi - 2.0, 40, (-demi + ENTREE.y - 6.0) * 0.5))
	_mur_invisible(limites, Vector3(2, 120, demi - ENTREE.y - 6.0), Vector3(-demi - 2.0, 40, (demi + ENTREE.y + 6.0) * 0.5))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _objet(dossier: Node3D, nom: String, id: String, p: Vector2, forme := "", invite := "", groupe := "", portee := 2.6, y := INF) -> Node3D:
	var o := ObjetChine.new()
	o.name = nom
	o.identifiant = id
	o.forme = forme
	o.groupe = groupe
	o.invite = invite
	o.portee = portee
	o.position = Vector3(p.x, hauteur(p.x, p.y) if y == INF else y, p.y)
	dossier.add_child(o)
	return o


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	# Le pavillon de l'Est : Ban Zhao, ses étudiants, Ma Rong.
	_pnj(dossier, "ban_zhao", BAN_ZHAO, 0.0)
	_pnj(dossier, "ma_rong", BAN_ZHAO + Vector2(4, 2), -0.4)
	for k in ETUDIANTS.size():
		_pnj(dossier, "etudiant_%d" % (k + 1), ETUDIANTS[k], PI * (0.3 + k * 0.5))
	var y_biblio := hauteur(BIBLIOTHEQUE.x, BIBLIOTHEQUE.y) + HAUT_BIBLIOTHEQUE
	for k in RAYONNAGES.size():
		var q: Vector2 = BIBLIOTHEQUE + RAYONNAGES[k]
		var rayonnage := _objet(dossier, "Rayonnage%d" % k, "rayonnage_%d" % k, q, "feu_rayonnage", "[F] Éteindre le feu (la chaîne de seaux)", "feu_rayonnage", 2.8, y_biblio)
		rayonnage.visible = false
		_rayonnages.append(rayonnage)
	for k in LIASSES.size():
		_objet(dossier, "Liasse%d" % k, "liasse_%d" % k, LIASSES[k], "liasse", "[F] Mettre les livres à l'abri", "liasse", 2.4)
	_objet(dossier, "Manuscrit", "manuscrit_han", MANUSCRIT, "manuscrit", "[F] Lire le manuscrit du Livre des Han", "", 2.6, y_biblio)
	# Le portail de la Vigie qui s'ouvrira dans la cour du pavillon (fin du chapitre 5).
	_construire_portail(dossier, PORTAIL_QG, PI * 0.5)
	_portail_qg = dossier.get_node("Portail") as Node3D
	_portail_qg.name = "PortailVigie"
	_portail_qg.add_to_group("decor_quete")
	_portail_qg.set_meta("identifiant", "portail_qg")
	_portail_qg.visible = false
	_zone_portail.monitoring = false
	# Les ateliers : Cai Lun, ses ouvriers, les cuves empoisonnées et les étapes du papier.
	_pnj(dossier, "cai_lun", CAI_LUN, 0.0)
	for k in OUVRIERS.size():
		_pnj(dossier, "ouvrier_atelier_%d" % (k + 1), OUVRIERS[k], PI * (0.2 + k * 0.6))
	for k in CUVES.size():
		_objet(dossier, "Cuve%d" % k, "cuve_mercure_%d" % k, CUVES[k], "cuve_mercure", "[F] Vider la cuve empoisonnée", "cuve_mercure", 2.6)
	for r in [["AiderCaiLun", "aider_cai_lun", "[F] « Je reste. On refait le papier ensemble. »", Vector2(-2.2, 2.2)],
			["SuivreSaboteur", "suivre_saboteur", "[F] « Je cours après le saboteur ! »", Vector2(2.4, 2.0)]]:
		var q: Vector2 = CAI_LUN + r[3]
		_objet(dossier, r[0], r[1], q, "", r[2], "", 2.0)
	for k in ECORCES.size():
		_objet(dossier, "Ecorce%d" % k, "ecorce_%d" % k, ECORCES[k], "ecorce", "[F] Prendre l'écorce de mûrier qui trempe", "ecorce", 2.4)
	_objet(dossier, "Pilon", "pilon_cai_lun", PILON + Vector2(-1.9, 1.2), "", "[F] Piler les fibres (pied gauche, pied droit…)", "", 2.6)
	_objet(dossier, "Tamis", "tamis_cai_lun", TAMIS, "", "[F] Plonger le tamis dans la cuve", "", 2.4)
	_objet(dossier, "Sechoir", "sechoir_cai_lun", SECHOIR, "", "[F] Coller la feuille sur le mur chaud", "", 2.4)
	# Le grand marché : les marchands, et la fiole que le saboteur a perdue.
	for k in MARCHANDS.size():
		_pnj(dossier, "marchand_luoyang_%d" % (k + 1), MARCHANDS[k], PI * (0.25 + k * 0.4))
	_objet(dossier, "Fiole", "fiole_cinabre", FIOLE, "fiole", "[F] Ramasser ce qui brille dans la ruelle", "", 2.2)
	# Les gardes de la porte ouest, et quelques passants.
	_pnj(dossier, "garde_porte_1", PORTE_OUEST + Vector2(6, -6), PI / 2)
	_pnj(dossier, "garde_porte_2", PORTE_OUEST + Vector2(6, 6), PI / 2)
	# Le char de poste impérial, vers le mont Li (chapitre 6).
	var char_poste := CharPoste.new()
	char_poste.name = "CharPoste"
	char_poste.destination = "mont_li"
	char_poste.nom_destination = "le mont Li"
	char_poste.condition = "vers_mont_li"
	char_poste.position = Vector3(CHAR_POSTE.x, hauteur(CHAR_POSTE.x, CHAR_POSTE.y), CHAR_POSTE.y)
	char_poste.rotation.y = PI / 2
	dossier.add_child(char_poste)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Porte de l'Ouest", PORTE_OUEST)
	repere.call(MarqueurCarte.Type.LIEU, "Palais du Sud", SALLE_SUD)
	repere.call(MarqueurCarte.Type.LIEU, "Palais du Nord", SALLE_NORD)
	repere.call(MarqueurCarte.Type.LIEU, "Pavillon de l'Est (bibliothèque)", BIBLIOTHEQUE)
	repere.call(MarqueurCarte.Type.LIEU, "Ateliers impériaux de Cai Lun", ATELIER.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Grand marché", MARCHE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Parc impérial", ETANG)
	repere.call(MarqueurCarte.Type.LIEU, "Académie impériale", ACADEMIE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Plate-forme des esprits", LINGTAI)
	repere.call(MarqueurCarte.Type.LIEU, "Route du Fleuve Jaune", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Char de poste (mont Li)", CHAR_POSTE)


# --- La route de l'ouest et le portail ---------------------------------------------------------

var _attente_sortie := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	# Le portail de la Vigie ne ramène au QG qu'une fois ouvert.
	if _portail_qg != null and _zone_portail != null and _zone_portail.monitoring != _portail_qg.visible:
		_zone_portail.monitoring = _portail_qg.visible
	# Les rayonnages ne brûlent que pendant l'incendie (et restent noircis une fois éteints).
	if _incendie != null:
		for o in _rayonnages:
			var eteint := o.get_node_or_null("Eteint")
			var voir: bool = _incendie.visible or (eteint != null and eteint.visible)
			if o.visible != voir:
				o.visible = voir
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if quete == null or joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(ENTREE) < 5.0:
		quete.changer_de_zone("fleuve_jaune")
