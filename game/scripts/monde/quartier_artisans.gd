extends RefCounted
## Le Quartier des Artisans (nord-est de Hikari Bay), voir docs/HUB.md, section 3.
##
## D'anciens entrepôts sous le métro aérien, transformés en ateliers. Deux
## ateliers se visitent : la forge Hinode et l'atelier Fil & Fibre (couture et
## impression 3D). Les joueurs y transformeront plus tard les matériaux
## rapportés des époques.
##
## Plan (le nord est vers -Z) :
##   - Rue des Ateliers : x de 16 à 24, de z = -70 à -140 ;
##   - Rue sous le viaduc : z de -87 à -77, de x = 24 à 84 (le métro passe au-dessus, z = -82).
## Les volumes des immeubles sont dans HikariBay.IMMEUBLES.

const Marche := preload("res://scripts/monde/quartier_marche.gd")

const ORANGE := Color(1.0, 0.55, 0.15)
const SODIUM := Color(1.0, 0.72, 0.38)
const CYAN := Color(0.3, 1.0, 0.95)
const BLANC := Color(0.9, 0.95, 1.0)

const FORGE := Rect2(26, -107, 22, 18)
const FABLAB := Rect2(52, -107, 20, 18)
const HAUTEUR_ATELIER := 7.0


static func construire(hub: HikariBay) -> void:
	_construire_entree(hub)
	_construire_forge(hub)
	_construire_fablab(hub)
	_construire_rues(hub)
	_construire_habitants(hub)


# --- Entrée : portique industriel -------------------------------------------

static func _construire_entree(hub: HikariBay) -> void:
	var acier := hub._mat_pbr("metal_plate", 1.5, "metal", Color(0.35, 0.35, 0.38))
	for x in [15.6, 24.4]:
		hub._boite(Vector3(0.5, 6.5, 0.5), Vector3(x, 3.25, -70.5), acier)
	hub._boite(Vector3(9.4, 0.8, 0.5), Vector3(20, 6.6, -70.5), acier, false)
	hub._texte("職人街 · ARTISANS · Quartier des Artisans", Vector3(20, 6.6, -70.2), ORANGE, 40, 0.0, 3.0)
	# Rangée d'ampoules sous le portique.
	for i in 6:
		var x := 16.4 + i * 1.45
		hub._boite(Vector3(0.12, 0.12, 0.12), Vector3(x, 6.05, -70.5), hub._neon(SODIUM, 4.0), false)
	hub._lumiere(Vector3(20, 5.5, -71.5), SODIUM, 2.0, 12.0)


# --- Forge Hinode (on y entre) ---------------------------------------------------

static func _construire_forge(hub: HikariBay) -> void:
	var r := FORGE
	var mur := hub._mat_pbr("corrugated_iron", 2.0, "metal", Color(0.55, 0.5, 0.48))
	var sol := hub._mat_pbr("concrete_pavement", 3.0, "beton", Color(0.5, 0.48, 0.46))
	# Grande porte au sud, sur la rue sous le viaduc (x de 34 à 38).
	Marche._piece(hub, r, mur, sol, [["sud", 34.0, 38.0]], HAUTEUR_ATELIER, 4.0)
	hub._bloc(r.position.x - 0.3, r.position.y - 0.3, r.end.x + 0.3, r.end.y + 0.3,
			HAUTEUR_ATELIER + 0.3, 10.5, hub._facade(51, 0.3))
	hub._texte("日の出 FORGE HINODE", Vector3(36, 5.0, r.end.y + 0.36), ORANGE, 70, 0.0, 4.0)
	hub._lumiere(Vector3(36, 4.2, r.end.y + 2.0), ORANGE, 1.8, 9.0)
	# Le four : un bloc de pierre au fond, avec une gueule rougeoyante.
	var pierre := hub._mat_pbr("granite_tile", 1.0, "pierre", Color(0.35, 0.3, 0.28))
	hub._bloc(30, r.position.y, 37, r.position.y + 3.0, 0, 3.4, pierre)
	hub._bloc(31.5, r.position.y + 1.8, 35.5, r.position.y + 3.05, 0.9, 2.2, hub._neon(Color(1.0, 0.35, 0.05), 4.0), false)
	hub._bloc(32, r.position.y, 35, r.position.y + 2.0, 3.4, HAUTEUR_ATELIER, hub._mat("metal"), false) # hotte
	var feu := hub._lumiere(Vector3(33.5, 1.6, r.position.y + 4.2), Color(1.0, 0.45, 0.12), 4.0, 14.0)
	feu.name = "FeuDeForge"
	_etincelles(hub, Vector3(33.5, 1.6, r.position.y + 3.3))
	# Enclumes, établi, râteliers d'outils.
	var acier := hub._mat("metal")
	for p in [Vector2(33, -100), Vector2(40, -100)]:
		hub._bloc(p.x - 0.3, p.y - 0.25, p.x + 0.3, p.y + 0.25, 0, 0.6, pierre)
		hub._bloc(p.x - 0.55, p.y - 0.2, p.x + 0.55, p.y + 0.2, 0.6, 0.85, acier)
	var bois := Marche._bois(hub)
	hub._bloc(r.end.x - 2.2, r.position.y + 2.0, r.end.x - 0.6, r.end.y - 4.0, 0, 0.95, bois)
	for i in 6:
		var z := r.position.y + 3.0 + i * 1.6
		hub._boite(Vector3(0.05, 0.9, 0.08), Vector3(r.position.x + 0.15, 1.8, z), acier, false)
		hub._boite(Vector3(0.12, 0.15, 0.35), Vector3(r.position.x + 0.2, 1.3, z), acier, false)
	# Barres de métal et caisses.
	for i in 4:
		hub._boite(Vector3(0.1, 0.1, 2.5), Vector3(44.0 + i * 0.25, 0.1 + i * 0.12, -94.0), acier, false)
	hub._modele("plastic_crate_01", Vector3(28.0, 0, -91.0), 0.4, 1.0)
	hub._modele("cardboard_box_01", Vector3(29.0, 0, -91.5), 1.0, 1.0)
	# Lampes industrielles suspendues.
	for x in [30.0, 38.0, 45.0]:
		hub._cylindre(0.45, 0.1, 0.35, Vector3(x, 5.6, -98.0), hub._mat("metal"), false)
		hub._lumiere(Vector3(x, 5.0, -98.0), SODIUM, 2.2, 12.0)
	Marche._pnj(hub, "forgeron", Vector3(34.0, 0, -101.5), PI)
	Marche._pnj(hub, "apprentie_forge", Vector3(40.0, 0, -98.7), 0.0)


static func _etincelles(hub: HikariBay, p: Vector3) -> void:
	var gp := GPUParticles3D.new()
	gp.amount = 24
	gp.lifetime = 1.0
	gp.position = p
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.6, 1)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.0, 0.6, 0.2) * 3.0
	q.material = m
	gp.draw_pass_1 = q
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub._contenu.add_child(gp)


# --- Atelier Fil & Fibre : couture et impression 3D (on y entre) -----------------

static func _construire_fablab(hub: HikariBay) -> void:
	var r := FABLAB
	var mur := hub._mat_pbr("white_rough_plaster", 2.0, "beton", Color(0.8, 0.8, 0.82))
	var sol := hub._mat_pbr("terrazzo_tiles", 2.0, "carrelage", Color(0.75, 0.75, 0.78))
	Marche._piece(hub, r, mur, sol, [["sud", 60.0, 64.0]], HAUTEUR_ATELIER, 3.2)
	hub._bloc(r.position.x - 0.3, r.position.y - 0.3, r.end.x + 0.3, r.end.y + 0.3,
			HAUTEUR_ATELIER + 0.3, 9.5, hub._facade(52, 0.4))
	hub._texte("FIL & FIBRE · FabLab 3D", Vector3(62, 4.4, r.end.y + 0.36), CYAN, 60, 0.0, 4.0)
	var vitre := hub._boite(Vector3(5.0, 2.4, 0.08), Vector3(56.0, 1.6, r.end.y + 0.33), hub._vitrine(BLANC), false)
	vitre.name = "VitreFablab"
	var bois := Marche._bois(hub)
	var acier := hub._mat("metal")
	# Côté couture (ouest) : grandes tables, mannequins, rouleaux de tissu.
	for z in [-100.5, -95.5]:
		hub._bloc(54.0, z - 1.0, 59.0, z + 1.0, 0.85, 0.92, bois, false)
		for x in [54.3, 58.7]:
			for dz in [-0.8, 0.8]:
				hub._bloc(x - 0.05, z + dz - 0.05, x + 0.05, z + dz + 0.05, 0, 0.85, acier)
	var couleurs := [Color(0.7, 0.1, 0.15), Color(0.1, 0.25, 0.6), Color(0.9, 0.8, 0.3), Color(0.15, 0.5, 0.3), Color(0.5, 0.2, 0.55)]
	for i in couleurs.size():
		var tissu := StandardMaterial3D.new()
		tissu.albedo_color = couleurs[i]
		tissu.roughness = 0.95
		var rouleau := hub._cylindre(0.18, 0.18, 1.5, Vector3(r.position.x + 0.4, 0.75 + (i % 2) * 0.4, -104.5 + i * 0.5), tissu, false)
		rouleau.rotation.z = PI / 2
		rouleau.rotation.y = PI / 2
	for i in 3:
		var x := 53.5 + i * 1.5
		hub._cylindre(0.03, 0.2, 1.0, Vector3(x, 0.5, -105.5), acier, false)
		var buste := StandardMaterial3D.new()
		buste.albedo_color = Color(0.85, 0.8, 0.72)
		hub._cylindre(0.2, 0.26, 0.75, Vector3(x, 1.4, -105.5), buste, false)
	# Côté impression 3D (est) : imprimantes qui luisent, établi avec ordinateurs.
	for i in 4:
		var z := -105.0 + i * 2.6
		hub._bloc(r.end.x - 1.4, z - 0.6, r.end.x - 0.3, z + 0.6, 0, 0.8, acier)
		hub._bloc(r.end.x - 1.3, z - 0.5, r.end.x - 0.4, z + 0.5, 0.8, 1.7, hub._vitrine(CYAN), false)
		hub._bloc(r.end.x - 1.4, z - 0.6, r.end.x - 0.3, z + 0.6, 1.7, 1.78, acier, false)
	hub._bloc(63.0, -102.0, 67.0, -100.6, 0.85, 0.92, bois, false)
	hub._bloc(63.1, -101.9, 63.2, -100.7, 0, 0.85, acier)
	hub._bloc(66.8, -101.9, 66.9, -100.7, 0, 0.85, acier)
	for x in [64.0, 66.0]:
		var ecran := hub._boite(Vector3(0.7, 0.45, 0.04), Vector3(x, 1.2, -101.7), hub._neon(Color(0.2, 0.5, 0.9), 1.4), false)
		ecran.rotation.x = -0.2
	# Néons blancs au plafond.
	for x in [56.0, 62.0, 68.0]:
		hub._boite(Vector3(0.3, 0.06, 12.0), Vector3(x, HAUTEUR_ATELIER - 0.08, -98.0), hub._neon(BLANC, 2.0), false)
		hub._lumiere(Vector3(x, HAUTEUR_ATELIER - 1.0, -98.0), BLANC, 2.0, 12.0)
	Marche._pnj(hub, "lea", Vector3(56.5, 0, -98.0), 0.0)
	Marche._pnj(hub, "kofi", Vector3(65.0, 0, -99.6), 0.0)


# --- Rues : façades d'entrepôts, viaduc, objets ------------------------------------

static func _construire_rues(hub: HikariBay) -> void:
	# Les piliers du viaduc bloquent le passage (le viaduc lui-même est construit par le hub).
	for x in [25.0, 50.0, 75.0]:
		hub._collision_boite(Vector3(2, 12, 2), Transform3D(Basis(), Vector3(x, 6, -82)))
	# Rideaux de fer des entrepôts fermés (rangée sud, face au nord ; rue des Ateliers).
	for x in [32.0, 44.0, 56.0, 68.0]:
		var porte := hub._modele("rollershutter_door", Vector3(x, 0, -77.05), PI, 1.2)
		if porte == null:
			hub._bloc(x - 2.0, -77.1, x + 2.0, -77.0, 0, 3.5, hub._mat("metal"), false)
	for z in [-118.0, -130.0]:
		hub._modele("rollershutter_door", Vector3(23.95, 0, z), -PI / 2, 1.2)
		hub._modele("rollershutter_door", Vector3(16.05, 0, z), PI / 2, 1.2)
	# Enseignes d'ateliers fermés (JP / EN / FR).
	var enseignes := [
		["木工 Menuiserie Kiyo", Vector3(23.95, 3.8, -118.0), -PI / 2, SODIUM],
		["革 CUIR & SELLERIE", Vector3(16.05, 3.8, -118.0), PI / 2, ORANGE],
		["陶芸 Céramique", Vector3(23.95, 3.8, -130.0), -PI / 2, CYAN],
		["修理 REPAIR · Réparations", Vector3(16.05, 3.8, -130.0), PI / 2, SODIUM],
		["倉庫 ENTREPÔT 7", Vector3(44.0, 4.6, -77.05), PI, ORANGE],
		["金属 MÉTAUX Ota", Vector3(68.0, 4.6, -77.05), PI, CYAN],
	]
	for e in enseignes:
		hub._texte(e[0], e[1], e[3], 46, e[2], 3.0)
	# Éclairage au sodium sous le viaduc et dans la rue des Ateliers.
	for p in [Vector3(30, 9.5, -80), Vector3(55, 9.5, -84), Vector3(78, 9.5, -80), Vector3(20, 6.0, -100), Vector3(20, 6.0, -125)]:
		hub._lumiere(p, SODIUM, 2.2, 16.0)
		hub._boite(Vector3(0.4, 0.15, 0.4), p + Vector3(0, 0.3, 0), hub._neon(SODIUM, 3.0), false)
	# Palettes, fûts, caisses, chariot élévateur.
	var bois := Marche._bois(hub)
	for p in [Vector3(28, 0, -79), Vector3(28, 0.15, -79), Vector3(46.5, 0, -88.2), Vector3(70, 0, -78.5)]:
		hub._boite(Vector3(1.2, 0.14, 1.0), p + Vector3(0, 0.07, 0), bois, false)
	var fut := StandardMaterial3D.new()
	fut.albedo_color = Color(0.15, 0.3, 0.55)
	fut.metallic = 0.5
	fut.roughness = 0.5
	for p in [Vector3(80.5, 0.45, -85.5), Vector3(81.3, 0.45, -85.0), Vector3(17.0, 0.45, -136.5)]:
		hub._cylindre(0.3, 0.3, 0.9, p, fut)
	var jaune := StandardMaterial3D.new()
	jaune.albedo_color = Color(0.85, 0.65, 0.05)
	jaune.roughness = 0.5
	hub._bloc(76.0, -80.5, 78.2, -79.2, 0.2, 1.4, jaune) # chariot élévateur
	hub._bloc(78.2, -80.4, 78.4, -79.3, 0, 2.6, hub._mat("metal"), false)
	for p in [Vector3(30.0, 0, -88.3), Vector3(70.0, 0, -88.3), Vector3(16.6, 0, -95.0)]:
		hub._modele("metal_trash_can", p, 0.0, 1.0)
	hub._modele("exterior_aircon_unit", Vector3(23.7, 3.0, -100.0), -PI / 2, 1.0)
	hub._modele("utility_box_01", Vector3(16.3, 0, -95.0), PI / 2, 1.0)
	# Vapeur qui s'échappe d'une bouche au sol.
	Marche._vapeur(hub, Vector3(21.5, 0.1, -108.0))
	Marche._vapeur(hub, Vector3(60.0, 0.1, -79.0))


static func _construire_habitants(hub: HikariBay) -> void:
	Marche._pnj(hub, "livreur", Vector3(22.0, 0, -84.0), PI / 2)
	Marche._pnj(hub, "soudeuse", Vector3(70.5, 0, -78.6), PI)
