extends RefCounted
## Les Résidences (ouest de Hikari Bay), voir docs/HUB.md, section 3.
##
## Un quartier d'habitation calme autour d'une petite place plantée : un
## cerisier, des balançoires, des distributeurs automatiques. Trois lieux se
## visitent : le konbini Hoshi (ouvert 24 h/24), le hall de la Résidence Sakura
## (avec l'ascenseur vers l'appartement 1204 du joueur) et la Maison des guildes.
## L'appartement est au 12e étage de la tour Sakura (voir appartement.gd).
##
## Plan (le nord est vers -Z) :
##   - Rue des Résidences : z de -6 à 6, de x = -30 à -70 ;
##   - Place des Résidences : x de -128 à -70, z de -30 à 30.
## Les volumes des immeubles sont dans HikariBay.IMMEUBLES.

const Marche := preload("res://scripts/monde/quartier_marche.gd")
const Musee := preload("res://scripts/monde/quartier_musee.gd")

const KONBINI := Rect2(-100, -29.4, 16, 11.4)
const HALL := Rect2(-98, 17, 18, 12)
const GUILDES := Rect2(-128, -14, 18, 28)
const HAUTEUR_KONBINI := 4.0
const HAUTEUR_HALL := 4.5
const HAUTEUR_GUILDES := 9.0

## Appartement 1204, au 12e étage de la tour Sakura (au-dessus du hall).
const APPART := Rect2(-96, 19, 14, 9)
const SOL_APPART := 40.0
const HAUTEUR_APPART := 3.0
## Ascenseurs : bouton dans le hall et dans l'appartement, et où l'on arrive.
const ASCENSEUR_HALL := Vector3(-92.0, 0.0, 28.4)
const ARRIVEE_HALL := Vector3(-92.0, 0.1, 26.4)
const ASCENSEUR_APPART := Vector3(-87.0, SOL_APPART, 27.6)
const ARRIVEE_APPART := Vector3(-87.0, SOL_APPART + 0.1, 25.6)
## Étagère des souvenirs (mur ouest de l'appartement) : 4 rangées de 4.
const SOUVENIRS_COLONNES := 4
const SOUVENIRS_RANGEES := 4
## Bannière de la guilde du joueur : dans la Maison des guildes et chez lui.
const BANNIERE_MAISON := Vector3(-111.6, 5.5, -13.88)
const BANNIERE_APPART := Vector3(-82.04, SOL_APPART + 1.95, 25.6)

const CHAUD := Color(1.0, 0.82, 0.6)
const ROSE := Color(1.0, 0.6, 0.78)
const VERT := Color(0.3, 0.95, 0.5)
const BLEU := Color(0.35, 0.7, 1.0)
const BLANC := Color(0.92, 0.96, 1.0)


static func construire(hub: HikariBay) -> void:
	_construire_entree(hub)
	_construire_konbini(hub)
	_construire_hall(hub)
	_construire_appartement(hub)
	_construire_guildes(hub)
	_construire_parc(hub)
	_construire_distributeurs(hub)
	_construire_habitants(hub)
	# Ascenseurs, souvenirs et fondation de guilde (seulement en jeu).
	if not Engine.is_editor_hint():
		var appart := Node3D.new()
		appart.name = "Appartement"
		appart.set_script(load("res://scripts/monde/appartement.gd"))
		hub._contenu.add_child(appart)


## Où poser le souvenir numéro i sur l'étagère (rangée du haut d'abord).
static func emplacement_souvenir(i: int) -> Vector3:
	var colonne := i % SOUVENIRS_COLONNES
	var rangee := int(i / SOUVENIRS_COLONNES)
	return Vector3(APPART.position.x + 0.22, SOL_APPART + 2.32 - rangee * 0.6, APPART.position.y + 1.8 + colonne * 1.6)


# --- Entrée du quartier --------------------------------------------------------------

static func _construire_entree(hub: HikariBay) -> void:
	var metal := hub._mat("metal")
	# Arche légère en métal à l'entrée de la place, avec le nom du quartier.
	for z in [-6.4, 6.4]:
		hub._boite(Vector3(0.35, 5.5, 0.35), Vector3(-70.5, 2.75, z), metal)
	hub._boite(Vector3(0.4, 0.6, 13.2), Vector3(-70.5, 5.6, 0), metal, false)
	hub._texte("住宅街 · RÉSIDENCES · Residential", Vector3(-70.25, 5.6, 0), ROSE, 40, PI / 2, 3.0)
	# Pavés de la place, un peu plus clairs que la rue.
	var dalles := hub._mat_pbr("concrete_pavers_02", 2.5, "dalles", Color(0.8, 0.78, 0.76))
	hub._bloc(-128, -30, -70, 30, 0.0, 0.02, dalles, false)
	# Lampadaires de la place.
	for p in [Vector2(-76, -24), Vector2(-76, 24), Vector2(-106, -24), Vector2(-106, 12), Vector2(-90, 0)]:
		var lampe := hub._modele("street_lamp_02", Vector3(p.x, 0, p.y), 0.0, 1.4)
		if lampe == null:
			hub._cylindre(0.07, 0.1, 4.5, Vector3(p.x, 2.25, p.y), metal)
			hub._boite(Vector3(0.5, 0.15, 0.5), Vector3(p.x, 4.55, p.y), hub._neon(CHAUD, 3.5), false)
		else:
			hub._collision_boite(Vector3(0.3, 4.5, 0.3), Transform3D(Basis(), Vector3(p.x, 2.25, p.y)))
		hub._lumiere(Vector3(p.x, 4.3, p.y), CHAUD, 2.2, 16.0)


# --- Konbini Hoshi (on y entre) ------------------------------------------------------------

static func _construire_konbini(hub: HikariBay) -> void:
	var r := KONBINI
	var mur := hub._mat_pbr("white_rough_plaster", 2.0, "beton", Color(0.92, 0.92, 0.92))
	var sol := hub._mat_pbr("square_tiled_wall", 1.0, "carrelage", Color(0.9, 0.9, 0.9))
	# Porte vitrée au sud, sur la place (x de -94 à -90).
	Marche._piece(hub, r, mur, sol, [["sud", -94.0, -90.0]], HAUTEUR_KONBINI, 2.6)
	# Vitrine à gauche de la porte : on voit l'intérieur éclairé.
	var vitre := hub._boite(Vector3(5.0, 2.2, 0.08), Vector3(-97.0, 1.4, r.end.y + 0.34), hub._vitrine(BLANC), false)
	vitre.name = "VitreKonbini"
	# Bandeau aux couleurs de l'enseigne.
	hub._bloc(r.position.x - 0.3, r.end.y + 0.3, r.end.x + 0.3, r.end.y + 0.45, 2.9, 3.2, hub._neon(VERT, 2.5), false)
	hub._bloc(r.position.x - 0.3, r.end.y + 0.3, r.end.x + 0.3, r.end.y + 0.45, 3.2, 3.5, hub._neon(BLEU, 2.5), false)
	hub._texte("ほし HOSHI · 24h · konbini", Vector3(-88.0, 3.85, r.end.y + 0.47), BLANC, 60, 0.0, 3.0)
	# Rayonnages au centre (trois rangées), frigos lumineux au fond, caisse à droite.
	var metal := hub._mat_pbr("metal_plate", 2.0, "metal", Color(0.85, 0.86, 0.88))
	for i in 3:
		var x := -98.0 + i * 3.2
		hub._bloc(x - 0.4, -27.0, x + 0.4, -21.5, 0, 1.6, metal)
		for etage in 3:
			var y := 0.45 + etage * 0.45
			var couleurs := [Color(1.0, 0.4, 0.3), Color(1.0, 0.85, 0.3), Color(0.4, 0.75, 1.0), Color(0.5, 0.9, 0.5)]
			for k in 5:
				var paquet := StandardMaterial3D.new()
				paquet.albedo_color = couleurs[(i + etage + k) % couleurs.size()]
				for cote in [-1.0, 1.0]:
					hub._boite(Vector3(0.12, 0.3, 0.9), Vector3(x + cote * 0.47, y + 0.15, -26.4 + k * 1.1), paquet, false)
	hub._bloc(r.position.x + 0.1, r.position.y, r.end.x - 6.5, r.position.y + 0.8, 0, 2.2, metal)
	hub._bloc(r.position.x + 0.2, r.position.y + 0.79, r.end.x - 6.6, r.position.y + 0.82, 0.2, 2.0, hub._neon(BLANC, 1.2), false)
	hub._texte("Boissons fraîches · 冷たい飲み物", Vector3(-95.0, 2.5, r.position.y + 0.85), BLEU, 28, 0.0, 2.0)
	# Caisse.
	hub._bloc(-87.5, -25.0, -86.7, -20.5, 0, 1.0, metal)
	hub._bloc(-87.6, -25.1, -86.6, -20.4, 1.0, 1.05, hub._mat("blanc"), false)
	hub._boite(Vector3(0.6, 0.3, 0.6), Vector3(-87.1, 1.2, -22.0), hub._mat("metal"), false)
	# Machine à oden et vitrine chauffante sur le comptoir (la vapeur monte).
	hub._boite(Vector3(0.6, 0.35, 0.9), Vector3(-87.1, 1.22, -24.0), hub._neon(Color(1.0, 0.65, 0.3), 1.0), false)
	Marche._vapeur(hub, Vector3(-87.1, 1.4, -24.0))
	# Lumière blanche, franche, comme dans tous les konbinis.
	for x in [-96.0, -89.0]:
		hub._boite(Vector3(0.3, 0.05, 8.0), Vector3(x, HAUTEUR_KONBINI - 0.05, -24.0), hub._neon(BLANC, 3.0), false)
		hub._lumiere(Vector3(x, HAUTEUR_KONBINI - 0.6, -24.0), BLANC, 2.6, 10.0)


# --- Hall de la Résidence Sakura (on y entre) --------------------------------------------------

static func _construire_hall(hub: HikariBay) -> void:
	var r := HALL
	var mur := hub._mat_pbr("granite_tile", 2.0, "pierre", Color(0.55, 0.5, 0.48))
	var sol := hub._mat_pbr("granite_tile", 1.5, "dalles", Color(0.75, 0.72, 0.7))
	# Porte au nord, sur la place (x de -91 à -87).
	Marche._piece(hub, r, mur, sol, [["nord", -91.0, -87.0]], HAUTEUR_HALL, 2.8)
	hub._texte("桜レジデンス · RÉSIDENCE SAKURA", Vector3(-89.0, 3.5, r.position.y - 0.36), ROSE, 48, PI, 2.5)
	hub._lumiere(Vector3(-89.0, 3.0, r.position.y - 1.5), CHAUD, 1.8, 9.0)
	# La tour de la résidence, au-dessus du hall.
	# (sans collision : l'appartement 1204 est à l'intérieur)
	hub._bloc(r.position.x - 0.3, r.position.y - 0.3, r.end.x + 0.3, r.end.y + 0.3,
			HAUTEUR_HALL + 0.3, 46.0, hub._facade(62, 0.45), false)
	# Auvent au-dessus de la porte.
	hub._bloc(-92.5, r.position.y - 2.0, -85.5, r.position.y, 3.0, 3.15, hub._mat("metal"), false)
	# Boîtes aux lettres (mur ouest).
	var laiton := hub._mat_pbr("metal_plate", 1.0, "metal", Color(0.75, 0.6, 0.35))
	for rang in 4:
		for col in 6:
			hub._boite(Vector3(0.12, 0.35, 0.5), Vector3(r.position.x + 0.07, 0.8 + rang * 0.4, 19.0 + col * 0.55), laiton, false)
	hub._texte("郵便受け · Courrier", Vector3(r.position.x + 0.15, 2.6, 20.4), CHAUD, 24, PI / 2, 1.5)
	# Ascenseurs (mur sud) : celui de gauche monte à l'appartement 1204.
	var acier := hub._mat_pbr("metal_plate", 1.0, "metal", Color(0.8, 0.82, 0.85))
	for x in [-92.0, -86.0]:
		hub._bloc(x - 1.0, r.end.y - 0.1, x + 1.0, r.end.y, 0, 2.4, acier, false)
		hub._bloc(x - 0.02, r.end.y - 0.12, x + 0.02, r.end.y - 0.1, 0, 2.4, hub._mat("metal"), false)
		hub._boite(Vector3(0.5, 0.15, 0.05), Vector3(x, 2.65, r.end.y - 0.08), hub._neon(Color(1.0, 0.5, 0.2), 2.0), false)
	hub._texte("Ascenseurs · エレベーター\nAppartements · 12e étage", Vector3(-89.0, 3.3, r.end.y - 0.12), BLANC, 26, PI, 1.5)
	# Comptoir de la concierge (mur est) et banquette.
	var bois := Marche._bois(hub)
	hub._bloc(-82.5, 19.0, -81.8, 24.0, 0, 1.1, bois)
	hub._bloc(-97.6, 26.4, -95.0, 27.2, 0.4, 0.5, bois)
	var plante := hub._modele("potted_plant_01", Vector3(-96.8, 0, 18.2), 0.0, 2.2)
	if plante == null:
		hub._cylindre(0.4, 0.3, 1.3, Vector3(-96.8, 0.65, 18.2), hub._mat("feuillage"), false)
	for x in [-94.0, -85.0]:
		hub._lumiere(Vector3(x, HAUTEUR_HALL - 0.7, 23.0), CHAUD, 1.8, 9.0)


# --- Appartement 1204 (12e étage de la tour Sakura) ------------------------------------------

static func _construire_appartement(hub: HikariBay) -> void:
	var r := APPART
	var s := SOL_APPART
	var h := HAUTEUR_APPART
	var x1 := r.position.x
	var x2 := r.end.x
	var z1 := r.position.y
	var z2 := r.end.y
	var mur := StandardMaterial3D.new()
	mur.albedo_color = Color(0.72, 0.68, 0.62)
	mur.roughness = 0.92
	var parquet := hub._mat_pbr("painted_metal_shutter", 1.0, "bois", Color(0.72, 0.52, 0.34))
	var bois := Marche._bois(hub)
	var blanc := hub._mat("blanc")
	var metal := hub._mat("metal")
	# Sol, plafond et murs (le mur nord est une grande baie vitrée sur la place).
	hub._bloc(x1 - 0.3, z1 - 0.3, x2 + 0.3, z2 + 0.3, s - 0.3, s, parquet)
	hub._bloc(x1 - 0.3, z1 - 0.3, x2 + 0.3, z2 + 0.3, s + h, s + h + 0.2, mur, false)
	hub._bloc(x1 - 0.3, z1 - 0.3, x1, z2 + 0.3, s, s + h, mur)
	hub._bloc(x2, z1 - 0.3, x2 + 0.3, z2 + 0.3, s, s + h, mur)
	hub._bloc(x1, z2, x2, z2 + 0.3, s, s + h, mur)
	hub._bloc(x1, z1 - 0.3, x2, z1, s, s + 0.5, mur)
	hub._bloc(x1, z1 - 0.3, x2, z1, s + 2.7, s + h, mur, false)
	hub._bloc(x1, z1 - 0.15, x2, z1 - 0.12, s + 0.5, s + 2.7, Musee._verre(hub), false)
	hub._collision_boite(Vector3(r.size.x, h, 0.3), Transform3D(Basis(), Vector3(r.get_center().x, s + h * 0.5, z1 - 0.15)))
	for x in [x1 + 0.1, x1 + 3.5, x1 + 7.0, x1 + 10.5, x2 - 0.1]:
		hub._bloc(x - 0.06, z1 - 0.2, x + 0.06, z1 - 0.06, s + 0.5, s + 2.7, metal, false)
	hub._bloc(x1, z1 - 0.2, x2, z1 + 0.15, s + 0.48, s + 0.55, blanc, false)
	# Lumière chaude du plafond et lampadaire près du canapé.
	for x in [x1 + 4.0, x2 - 4.0]:
		hub._cylindre(0.35, 0.35, 0.05, Vector3(x, s + h - 0.03, r.get_center().y), hub._neon(CHAUD, 2.0), false)
		hub._lumiere(Vector3(x, s + h - 0.4, r.get_center().y), CHAUD, 2.4, 11.0)
	hub._lumiere(Vector3(-84.0, s + 2.2, 23.0), CHAUD, 1.4, 7.0)
	hub._cylindre(0.03, 0.03, 1.6, Vector3(-92.8, s + 0.8, 26.4), metal, false)
	hub._cylindre(0.12, 0.22, 0.3, Vector3(-92.8, s + 1.7, 26.4), Marche._papier(hub, CHAUD, 2.5), false)
	hub._lumiere(Vector3(-92.8, s + 1.6, 26.0), CHAUD, 0.7, 4.0)
	# Tapis, canapé tourné vers la baie, table basse.
	var tapis := StandardMaterial3D.new()
	tapis.albedo_color = Color(0.45, 0.2, 0.22)
	tapis.roughness = 1.0
	hub._bloc(-92.5, 21.4, -86.5, 25.0, s, s + 0.015, tapis, false)
	var tissu := StandardMaterial3D.new()
	tissu.albedo_color = Color(0.2, 0.27, 0.36)
	tissu.roughness = 0.95
	hub._bloc(-92.0, 25.0, -88.0, 26.0, s, s + 0.45, tissu)
	hub._bloc(-92.0, 25.7, -88.0, 26.05, s + 0.45, s + 0.95, tissu, false)
	for x in [-92.2, -87.8]:
		hub._bloc(x - 0.2, 25.0, x + 0.2, 26.05, s, s + 0.65, tissu, false)
	for k in 3:
		hub._boite(Vector3(1.15, 0.12, 0.6), Vector3(-90.0 + (k - 1) * 1.25, s + 0.5, 25.35), tissu, false)
	hub._bloc(-91.0, 22.6, -89.0, 23.6, s + 0.36, s + 0.42, bois)
	for x in [-90.85, -89.15]:
		for z in [22.75, 23.45]:
			hub._bloc(x - 0.04, z - 0.04, x + 0.04, z + 0.04, s, s + 0.36, metal, false)
	hub._cylindre(0.1, 0.08, 0.12, Vector3(-90.4, s + 0.48, 23.1), blanc, false)
	# Lit (contre le mur est, près de la baie) et table de nuit.
	hub._bloc(-84.8, 19.4, -82.0, 21.6, s, s + 0.35, bois)
	hub._bloc(-84.7, 19.5, -82.1, 21.5, s + 0.35, s + 0.55, blanc, false)
	var couette := StandardMaterial3D.new()
	couette.albedo_color = Color(0.75, 0.62, 0.45)
	couette.roughness = 1.0
	hub._bloc(-84.75, 19.45, -83.0, 21.55, s + 0.55, s + 0.62, couette, false)
	hub._boite(Vector3(0.45, 0.14, 0.8), Vector3(-82.45, s + 0.62, 20.0), blanc, false)
	hub._boite(Vector3(0.45, 0.14, 0.8), Vector3(-82.45, s + 0.62, 21.0), blanc, false)
	hub._bloc(-82.15, 19.4, -82.0, 21.6, s, s + 1.1, bois, false)
	hub._bloc(-82.6, 21.8, -82.0, 22.4, s, s + 0.5, bois)
	hub._cylindre(0.08, 0.12, 0.25, Vector3(-82.3, s + 0.63, 22.1), Marche._papier(hub, CHAUD, 2.0), false)
	hub._lumiere(Vector3(-82.5, s + 0.9, 22.1), CHAUD, 0.6, 4.0)
	# Bureau (mur est) avec un écran allumé, et sa chaise.
	hub._bloc(-82.9, 24.4, -82.0, 26.8, s + 0.72, s + 0.77, bois)
	for z in [24.5, 26.7]:
		hub._bloc(-82.85, z - 0.05, -82.05, z + 0.05, s, s + 0.72, metal, false)
	hub._collision_boite(Vector3(0.9, 0.77, 2.4), Transform3D(Basis(), Vector3(-82.45, s + 0.385, 25.6)))
	var ecran := hub._boite(Vector3(0.04, 0.42, 0.75), Vector3(-82.25, s + 1.02, 25.6), hub._neon(Color(0.4, 0.75, 1.0), 1.5), false)
	ecran.name = "EcranAppartement"
	hub._boite(Vector3(0.25, 0.02, 0.6), Vector3(-82.6, s + 0.78, 25.6), metal, false)
	hub._boite(Vector3(0.5, 0.06, 0.5), Vector3(-83.4, s + 0.48, 25.6), tissu, false)
	hub._cylindre(0.03, 0.03, 0.45, Vector3(-83.4, s + 0.225, 25.6), metal, false)
	hub._boite(Vector3(0.06, 0.5, 0.5), Vector3(-83.65, s + 0.78, 25.6), tissu, false)
	# Cuisine (mur sud, côté ouest) : plan de travail, évier, placards, frigo.
	hub._bloc(-95.0, 27.35, -91.0, z2, s, s + 0.88, blanc)
	hub._bloc(-95.0, 27.3, -91.0, z2, s + 0.88, s + 0.92, hub._mat_pbr("granite_tile", 1.0, "pierre", Color(0.25, 0.25, 0.27)), false)
	hub._bloc(-93.6, 27.45, -92.6, 27.85, s + 0.86, s + 0.93, metal, false)
	hub._bloc(-95.0, 27.6, -91.0, z2, s + 1.6, s + 2.3, blanc, false)
	hub._bloc(-94.9, 27.55, -91.1, 27.6, s + 1.58, s + 1.6, hub._neon(CHAUD, 2.0), false)
	hub._bloc(-96.0, 27.2, -95.1, z2, s, s + 2.0, metal)
	hub._lumiere(Vector3(-93.0, s + 1.4, 27.4), CHAUD, 0.4, 3.0)
	# Étagère des souvenirs (mur ouest) : appartement.gd y pose un objet par mission accomplie.
	for k in SOUVENIRS_RANGEES:
		var y := SOL_APPART + 2.3 - k * 0.6
		hub._bloc(x1, z1 + 0.9, x1 + 0.42, z1 + 7.5, y - 0.04, y, bois, false)
	for z in [z1 + 0.9, z1 + 7.46]:
		hub._bloc(x1, z - 0.04, x1 + 0.42, z, s, s + 2.4, bois, false)
	hub._collision_boite(Vector3(0.42, 2.4, 6.6), Transform3D(Basis(), Vector3(x1 + 0.21, s + 1.2, z1 + 4.2)))
	hub._texte("Souvenirs de mission · 思い出", Vector3(x1 + 0.05, s + 2.78, z1 + 4.2), CHAUD, 26, PI / 2, 1.2)
	hub._lumiere(Vector3(x1 + 1.2, s + 2.6, z1 + 4.2), Color(1.0, 0.9, 0.75), 1.0, 5.0)
	# Porte de l'ascenseur et numéro de l'appartement.
	var acier := hub._mat_pbr("metal_plate", 1.0, "metal", Color(0.8, 0.82, 0.85))
	hub._bloc(-88.0, z2 - 0.1, -86.0, z2, s, s + 2.4, acier, false)
	hub._bloc(-87.02, z2 - 0.12, -86.98, z2 - 0.1, s, s + 2.4, metal, false)
	hub._boite(Vector3(0.5, 0.15, 0.05), Vector3(-87.0, s + 2.6, z2 - 0.08), hub._neon(Color(1.0, 0.5, 0.2), 2.0), false)
	hub._texte("1204", Vector3(-85.3, s + 1.9, z2 - 0.05), CHAUD, 40, PI, 1.2)
	# Plantes dans les coins.
	for p in [Vector3(x1 + 0.6, s, z1 + 0.45), Vector3(x2 - 0.5, s, z2 - 0.5)]:
		if hub._modele("potted_plant_01", p, 0.0, 2.0) == null:
			hub._cylindre(0.35, 0.25, 1.2, p + Vector3(0, 0.6, 0), hub._mat("feuillage"), false)


# --- Maison des guildes (on y entre) -------------------------------------------------------------

static func _construire_guildes(hub: HikariBay) -> void:
	var r := GUILDES
	var mur := hub._mat_pbr("white_rough_plaster", 2.0, "beton", Color(0.85, 0.75, 0.62))
	var sol := Marche._bois(hub)
	# Grande porte à l'est, face à la place (z de -2 à 2).
	Marche._piece(hub, r, mur, sol, [["est", -2.0, 2.0]], HAUTEUR_GUILDES, 4.0)
	hub._bloc(r.position.x - 0.3, r.position.y - 0.3, r.end.x + 0.3, r.end.y + 0.3,
			HAUTEUR_GUILDES + 0.3, 14.0, hub._facade(61, 0.25))
	hub._texte("ギルド会館 · MAISON DES GUILDES · Guild Hall", Vector3(r.end.x + 0.36, 6.0, 0), CHAUD, 56, PI / 2, 3.0)
	hub._lumiere(Vector3(r.end.x + 2.0, 4.5, 0), CHAUD, 2.0, 12.0)
	# Bannières des guildes (sur les murs nord et sud).
	var guildes := [["Les Veilleurs", Color(0.2, 0.35, 0.75)], ["Ordre du Loup", Color(0.55, 0.12, 0.1)],
			["Les Cartographes", Color(0.2, 0.5, 0.3)], ["Le Brasier", Color(0.8, 0.45, 0.1)]]
	for i in guildes.size():
		var g: Array = guildes[i]
		var tissu := StandardMaterial3D.new()
		tissu.albedo_color = g[1]
		tissu.roughness = 0.9
		var nord := i % 2 == 0
		var x := -124.0 + int(i / 2) * 7.0
		var z := r.position.y + 0.12 if nord else r.end.y - 0.12
		hub._boite(Vector3(2.0, 4.5, 0.05), Vector3(x, 5.5, z), tissu, false)
		hub._texte(g[0], Vector3(x, 5.8, z + (0.05 if nord else -0.05)), Color(1.0, 0.92, 0.75), 30, 0.0 if nord else PI, 1.5)
	# Grande table au centre, tableau d'annonces, bureau des registres au fond.
	var bois := hub._mat_pbr("wood_planks", 2.0, "bois", Color(0.4, 0.28, 0.2))
	hub._bloc(-122.0, -1.2, -113.0, 1.2, 0.75, 0.85, bois)
	for x in [-121.5, -113.5]:
		for z in [-1.0, 1.0]:
			hub._bloc(x - 0.1, z - 0.1, x + 0.1, z + 0.1, 0, 0.75, bois, false)
	for x in [-120.5, -117.5, -114.5]:
		for z in [-2.0, 2.0]:
			hub._bloc(x - 0.3, z - 0.3, x + 0.3, z + 0.3, 0, 0.45, bois, false)
	var liege := StandardMaterial3D.new()
	liege.albedo_color = Color(0.6, 0.45, 0.3)
	hub._boite(Vector3(4.0, 2.0, 0.08), Vector3(-116.0, 2.0, r.position.y + 0.1), liege, false)
	for k in 6:
		hub._boite(Vector3(0.45, 0.6, 0.02), Vector3(-117.5 + k * 0.6, 2.0 + (k % 2) * 0.3, r.position.y + 0.15), hub._mat("blanc"), false)
	hub._texte("Recrutement · 募集中", Vector3(-116.0, 3.25, r.position.y + 0.16), CHAUD, 28, 0.0, 1.5)
	hub._bloc(-127.0, -3.0, -126.0, 3.0, 0, 1.1, bois)
	hub._texte("Registre des guildes\nFondation : parle au registraire", Vector3(-127.65, 3.6, 0.0), CHAUD, 26, PI / 2, 1.5)
	# Lustres.
	for x in [-123.0, -115.0]:
		hub._cylindre(0.8, 0.5, 0.25, Vector3(x, 6.5, 0), hub._mat("metal"), false)
		hub._lumiere(Vector3(x, 6.0, 0), CHAUD, 3.5, 18.0)
	# Appliques murales qui éclairent les bannières.
	for x in [-124.0, -117.0]:
		for z in [r.position.y + 1.0, r.end.y - 1.0]:
			hub._lumiere(Vector3(x, 3.5, z), Color(1.0, 0.75, 0.5), 1.8, 8.0)


# --- Petit parc : cerisier, balançoires, bancs --------------------------------------------------

static func _construire_parc(hub: HikariBay) -> void:
	var terre := StandardMaterial3D.new()
	terre.albedo_color = Color(0.2, 0.25, 0.15)
	terre.roughness = 1.0
	hub._bloc(-104, -10, -82, 10, 0.02, 0.05, terre, false)
	# Bordure.
	var bord := hub._mat_pbr("brushed_concrete", 2.0, "beton", Color(0.75, 0.75, 0.73))
	for z in [-10.0, 10.0]:
		hub._bloc(-104, z - 0.15, -82, z + 0.15, 0, 0.25, bord, false)
	for x in [-104.0, -82.0]:
		hub._bloc(x - 0.15, -10, x + 0.15, 10, 0, 0.25, bord, false)
	# Le cerisier, en fleurs malgré la saison.
	var p := Vector3(-97.0, 0, -3.0)
	hub._cylindre(0.25, 0.4, 3.4, p + Vector3(0, 1.7, 0), hub._mat("tronc"))
	var fleurs := StandardMaterial3D.new()
	fleurs.albedo_color = Color(1.0, 0.72, 0.82)
	fleurs.emission_enabled = true
	fleurs.emission = ROSE
	fleurs.emission_energy_multiplier = 0.25
	fleurs.roughness = 0.9
	for b in [[Vector3(0, 4.2, 0), 2.2], [Vector3(1.5, 3.8, 0.8), 1.6], [Vector3(-1.4, 3.9, -0.6), 1.7],
			[Vector3(0.3, 3.6, -1.6), 1.4], [Vector3(-0.6, 4.8, 1.0), 1.4]]:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = b[1]
		sm.height = b[1] * 1.5
		s.mesh = sm
		s.material_override = fleurs
		s.position = p + b[0]
		hub._contenu.add_child(s)
	hub._lumiere(p + Vector3(0, 1.0, 0), ROSE, 1.5, 9.0)
	_petales(hub, p + Vector3(0, 4.0, 0), fleurs)
	# Balançoires.
	var metal := hub._mat("metal")
	for cote: float in [-1.0, 1.0]:
		var x := -87.0 + cote * 2.0
		hub._boite(Vector3(0.1, 2.6, 0.1), Vector3(x, 1.3, 4.5), metal)
	hub._boite(Vector3(4.2, 0.1, 0.1), Vector3(-87.0, 2.6, 4.5), metal, false)
	for x in [-88.0, -86.0]:
		for dz in [-0.2, 0.2]:
			hub._boite(Vector3(0.02, 2.0, 0.02), Vector3(x, 1.6, 4.5 + dz), metal, false)
		hub._boite(Vector3(0.5, 0.05, 0.5), Vector3(x, 0.6, 4.5), Marche._bois(hub), false)
	# Bancs autour du cerisier.
	var bois := Marche._bois(hub)
	for b in [[-101.0, 4.0], [-93.0, -7.5], [-100.0, -7.5]]:
		hub._bloc(b[0] - 1.1, b[1] - 0.25, b[0] + 1.1, b[1] + 0.25, 0.4, 0.48, bois)
		hub._bloc(b[0] - 1.0, b[1] - 0.2, b[0] + 1.0, b[1] + 0.2, 0.0, 0.4, hub._mat("metal"), false)


static func _petales(hub: HikariBay, p: Vector3, mat: Material) -> void:
	var gp := GPUParticles3D.new()
	gp.amount = 60
	gp.lifetime = 6.0
	gp.position = p
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.2
	pm.direction = Vector3(1, -0.3, 0.2)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.15, -0.35, 0)
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.05)
	var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	gp.draw_pass_1 = q
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub._contenu.add_child(gp)


# --- Distributeurs automatiques (un classique des rues japonaises) ----------------------------------

static func _construire_distributeurs(hub: HikariBay) -> void:
	var couleurs := [Color(0.85, 0.15, 0.15), Color(0.15, 0.35, 0.8), Color(0.95, 0.95, 0.95)]
	for i in 3:
		var x := -80.0 + i * 1.3
		var corps := StandardMaterial3D.new()
		corps.albedo_color = couleurs[i]
		hub._bloc(x - 0.6, -29.9, x + 0.6, -29.1, 0, 1.85, corps)
		# Façade lumineuse avec des rangées de boissons.
		hub._boite(Vector3(1.0, 0.9, 0.03), Vector3(x, 1.3, -29.08), hub._neon(BLANC, 1.8), false)
		for rang in 3:
			for k in 5:
				var c := StandardMaterial3D.new()
				c.albedo_color = Color.from_hsv(fmod(0.1 * k + 0.3 * rang + 0.2 * i, 1.0), 0.7, 0.9)
				hub._boite(Vector3(0.12, 0.2, 0.03), Vector3(x - 0.36 + k * 0.18, 1.05 + rang * 0.27, -29.05), c, false)
		hub._boite(Vector3(0.3, 0.1, 0.03), Vector3(x + 0.25, 0.55, -29.08), hub._neon(Color(0.3, 1.0, 0.4), 2.0), false)
	hub._lumiere(Vector3(-78.7, 1.6, -28.0), BLANC, 1.4, 6.0)


# --- Habitants -------------------------------------------------------------------------------------

static func _construire_habitants(hub: HikariBay) -> void:
	Marche._pnj(hub, "caissier_konbini", Vector3(-86.0, 0, -19.6), PI / 2)
	Marche._pnj(hub, "client_konbini", Vector3(-96.4, 0, -24.0), 0.0)
	Marche._pnj(hub, "concierge", Vector3(-83.6, 0, 26.0), PI / 2)
	Marche._pnj(hub, "registraire", Vector3(-125.2, 0, 0.0), -PI / 2)
	Marche._pnj(hub, "membre_guilde", Vector3(-119.0, 0, 6.0), PI)
	Marche._pnj(hub, "retraite_banc", Vector3(-101.0, 0, 5.0), PI)
	Marche._pnj(hub, "enfant_balancoire", Vector3(-84.0, 0, 6.5), PI / 2)
	Marche._pnj(hub, "joggeuse", Vector3(-76.0, 0, -12.0), PI)
