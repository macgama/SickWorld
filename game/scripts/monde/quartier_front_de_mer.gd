extends RefCounted
## Le Front de mer (sud de Hikari Bay), voir docs/HUB.md, section 3.
##
## La promenade le long de la baie, le Terminal des ferries (façade officielle
## de la Vigie : la compagnie « Vigie Lines »), un ferry à quai et la jetée de la
## grande roue. Le terminal se visite.
##
## Plan (le nord est vers -Z, la mer est au sud) :
##   - Promenade : z de 62 à 74, de x = -70 à 70 (garde-corps à z = 74) ;
##   - Jetée du terminal : x de -52 à -18, z de 75 à 108 (ouverture du garde-corps x -42 à -28) ;
##   - Jetée de la grande roue : x de 40 à 70, z de 74 à 124 (ouverture x 50 à 60).
## Le mur du quai, le garde-corps et la grande roue sont construits par HikariBay.

const Marche := preload("res://scripts/monde/quartier_marche.gd")

const TERMINAL := Rect2(-48, 82, 26, 20)
const HAUTEUR_TERMINAL := 8.0
const JETEE_TERMINAL := Rect2(-52, 75, 34, 33)
const JETEE_ROUE := Rect2(40, 74, 30, 50)
## Ouvertures du garde-corps du quai (x début, x fin), lues par HikariBay.
const OUVERTURES_QUAI := [[-42.0, -28.0], [50.0, 60.0]]

const CHAUD := Color(1.0, 0.82, 0.6)
const BLEU := Color(0.3, 0.7, 1.0)
const ROSE := Color(1.0, 0.35, 0.7)
const ROUGE := Color(1.0, 0.3, 0.2)


static func construire(hub: HikariBay) -> void:
	_construire_promenade(hub)
	_construire_jetee_terminal(hub)
	_construire_terminal(hub)
	_construire_ferry(hub)
	_construire_jetee_roue(hub)
	_construire_bateaux(hub)
	_construire_habitants(hub)


## Garde-corps (main courante + poteaux) avec collision, le long d'un segment.
static func _garde_corps(hub: HikariBay, a: Vector2, b: Vector2) -> void:
	var metal := hub._mat("metal")
	var milieu := (a + b) * 0.5
	var longueur := a.distance_to(b)
	var le_long_de_x := absf(b.x - a.x) > absf(b.y - a.y)
	var taille := Vector3(longueur, 0.1, 0.1) if le_long_de_x else Vector3(0.1, 0.1, longueur)
	hub._boite(taille, Vector3(milieu.x, 0.95, milieu.y), metal, false)
	var poteaux := int(longueur / 3.0)
	for i in poteaux + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, poteaux))
		hub._boite(Vector3(0.08, 0.95, 0.08), Vector3(p.x, 0.47, p.y), metal, false)
	var collision := Vector3(longueur, 3.0, 0.3) if le_long_de_x else Vector3(0.3, 3.0, longueur)
	hub._collision_boite(collision, Transform3D(Basis(), Vector3(milieu.x, 1.5, milieu.y)))


# --- Promenade -----------------------------------------------------------------

static func _construire_promenade(hub: HikariBay) -> void:
	# Platelage en bois le long de l'eau.
	var planches := hub._mat_pbr("wood_planks", 3.0, "bois", Color(0.55, 0.45, 0.38))
	hub._bloc(-70, 66, 70, 74, 0.0, 0.03, planches, false)
	# Bancs face à la mer.
	var bois := Marche._bois(hub)
	var metal := hub._mat("metal")
	for x in [-60.0, -10.0, 10.0, 32.0]:
		hub._bloc(x - 1.2, 71.6, x + 1.2, 72.2, 0.4, 0.48, bois)
		hub._bloc(x - 1.2, 71.55, x + 1.2, 71.65, 0.48, 0.95, bois, false)
		for dx in [-1.0, 1.0]:
			hub._bloc(x + dx - 0.05, 71.6, x + dx + 0.05, 72.2, 0.0, 0.4, metal, false)
	# Lampadaires le long du garde-corps, et guirlande d'ampoules entre eux.
	var xs := [-66.0, -52.0, -24.0, -4.0, 18.0, 38.0, 64.0]
	for x: float in xs:
		hub._cylindre(0.07, 0.11, 5.0, Vector3(x, 2.5, 73.3), metal)
		hub._boite(Vector3(0.5, 0.15, 0.5), Vector3(x, 5.05, 73.3), hub._neon(CHAUD, 3.5), false)
		hub._lumiere(Vector3(x, 4.6, 73.3), CHAUD, 2.0, 16.0)
	for i in xs.size() - 1:
		var a: float = xs[i]
		var b: float = xs[i + 1]
		var n := int((b - a) / 1.6)
		for k in n:
			var t := (k + 0.5) / n
			var y := 4.6 - sin(t * PI) * 0.9
			var couleur: Color = [CHAUD, ROSE, BLEU][k % 3]
			hub._boite(Vector3(0.1, 0.1, 0.1), Vector3(lerpf(a, b, t), y, 73.3), hub._neon(couleur, 4.0), false)
	# Stand de takoyaki contre la façade.
	var stand := Rect2(-23, 62, 6, 2)
	hub._bloc(stand.position.x, 63.3, stand.end.x, 63.7, 0, 1.0, bois)
	hub._bloc(stand.position.x - 0.3, 62.0, stand.end.x + 0.3, 64.6, 2.6, 2.75, Marche._papier(hub, Color(0.9, 0.3, 0.15), 0.6), false)
	for x in [stand.position.x, stand.end.x]:
		hub._bloc(x - 0.05, 64.3, x + 0.05, 64.4, 0, 2.6, metal, false)
	hub._texte("たこ焼き TAKOYAKI · 6 pièces 500 ¥", Vector3(-20, 2.95, 64.62), Color(1.0, 0.9, 0.7), 40, 0.0, 2.5)
	for i in 5:
		Marche._lanterne(hub, Vector3(-22.5 + i * 1.25, 2.35, 64.5), Color(1.0, 0.45, 0.2), i == 2, 0.18)
	Marche._vapeur(hub, Vector3(-21.0, 1.1, 63.4))
	# Panneau d'accueil du front de mer.
	hub._texte("海辺 · WATERFRONT · Front de mer", Vector3(0, 3.6, 62.3), BLEU, 60, 0.0, 3.0)


# --- Jetée et Terminal des ferries (on y entre) -----------------------------------------

static func _construire_jetee_terminal(hub: HikariBay) -> void:
	var j := JETEE_TERMINAL
	var planches := hub._mat_pbr("wood_planks", 3.0, "bois", Color(0.45, 0.38, 0.32))
	hub._bloc(j.position.x, j.position.y, j.end.x, j.end.y, -1.2, 0.0, planches)
	# Pilotis.
	var beton := hub._mat("beton")
	for x in [j.position.x + 0.5, j.end.x - 0.5]:
		for i in 5:
			var z := j.position.y + 3.0 + i * 7.0
			hub._cylindre(0.35, 0.35, 3.0, Vector3(x, -2.2, z), beton, false)
	_garde_corps(hub, Vector2(j.position.x, j.position.y), Vector2(j.position.x, j.end.y))
	_garde_corps(hub, Vector2(j.end.x, j.position.y), Vector2(j.end.x, j.end.y))
	_garde_corps(hub, Vector2(j.position.x, j.end.y), Vector2(j.end.x, j.end.y))
	# Bornes d'amarrage.
	for z in [86.0, 100.0]:
		hub._cylindre(0.2, 0.25, 0.6, Vector3(-18.6, 0.3, z), hub._mat("metal"), false)


static func _construire_terminal(hub: HikariBay) -> void:
	var r := TERMINAL
	var mur := hub._mat_pbr("white_rough_plaster", 2.0, "beton", Color(0.82, 0.84, 0.86))
	var sol := hub._mat_pbr("terrazzo_tiles", 2.0, "carrelage", Color(0.7, 0.72, 0.75))
	# Porte au nord (vers la ville), grande baie vitrée au sud (vers la mer).
	Marche._piece(hub, r, mur, sol, [["nord", -37.0, -33.0], ["sud", -44.0, -26.0]], HAUTEUR_TERMINAL, 3.5)
	var verre := StandardMaterial3D.new()
	verre.albedo_color = Color(0.5, 0.7, 0.85, 0.2)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.metallic = 0.6
	verre.roughness = 0.05
	verre.cull_mode = BaseMaterial3D.CULL_DISABLED
	hub._bloc(-44.0, r.end.y, -26.0, r.end.y + 0.1, 0, 3.5, verre)
	for x in [-38.0, -32.0]:
		hub._bloc(x - 0.08, r.end.y, x + 0.08, r.end.y + 0.12, 0, 3.5, hub._mat("metal"), false)
	# Toit en vague (auvent) et enseigne de la compagnie.
	var blanc := hub._mat_pbr("metal_plate", 2.0, "metal", Color(0.85, 0.87, 0.9))
	hub._bloc(r.position.x - 1.5, r.position.y - 3.0, r.end.x + 1.5, r.end.y + 1.5,
			HAUTEUR_TERMINAL + 0.3, HAUTEUR_TERMINAL + 0.7, blanc, false)
	hub._bloc(r.position.x - 1.5, r.position.y - 3.05, r.end.x + 1.5, r.position.y - 2.95,
			HAUTEUR_TERMINAL + 0.35, HAUTEUR_TERMINAL + 0.55, hub._neon(BLEU, 3.0), false)
	hub._texte("VIGIE LINES · フェリーターミナル · Terminal des ferries", Vector3(-35, 6.2, r.position.y - 0.36),
			Color(0.9, 0.95, 1.0), 64, PI, 3.0)
	hub._lumiere(Vector3(-35, 4.0, r.position.y - 2.5), CHAUD, 2.0, 12.0)
	# Guichets (contre le mur ouest).
	var bois := Marche._bois(hub)
	hub._bloc(-46.5, 84.5, -45.8, 90.0, 0, 1.1, bois)
	hub._bloc(-46.6, 84.4, -45.7, 90.1, 1.1, 1.16, blanc, false)
	hub._texte("Billets · Tickets · 乗船券", Vector3(-47.65, 2.6, 87.2), CHAUD, 34, PI / 2, 2.0)
	# Tableau des départs (mur est) : les « destinations » sont les époques.
	var tableau := hub._boite(Vector3(0.1, 2.6, 6.0), Vector3(-22.1, 4.2, 92.0), hub._neon(Color(0.02, 0.03, 0.05), 0.0), false)
	tableau.name = "TableauDesDeparts"
	var lignes := "出発 DÉPARTS · DEPARTURES\n\n" + \
			"23:55   PRÉHISTOIRE  −17 000      ● EMBARQUEMENT\n" + \
			"——:——   ÉGYPTE ANTIQUE            ✕ ANNULÉ\n" + \
			"——:——   GRÈCE ANTIQUE             ✕ ANNULÉ\n" + \
			"——:——   MOYEN ÂGE                 ✕ ANNULÉ\n\n" + \
			"Pour tout renseignement, adressez-vous au guichet."
	var l := hub._texte(lignes, Vector3(-22.16, 4.2, 92.0), Color(1.0, 0.75, 0.25), 26, -PI / 2, 3.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Bancs d'attente face à la baie vitrée.
	for rang in 2:
		var z := 95.0 + rang * 2.5
		for x in [-40.0, -30.0]:
			hub._bloc(x - 3.0, z - 0.3, x + 3.0, z + 0.3, 0.4, 0.48, hub._mat("metal"))
			hub._bloc(x - 3.0, z - 0.35, x + 3.0, z - 0.25, 0.48, 0.95, hub._mat("metal"), false)
	# Plantes et lumières.
	for p in [Vector3(-46.5, 0, 100.5), Vector3(-23.5, 0, 100.5), Vector3(-23.5, 0, 83.5)]:
		var plante := hub._modele("potted_plant_01", p, 0.0, 2.5)
		if plante == null:
			hub._cylindre(0.4, 0.3, 1.4, p + Vector3(0, 0.7, 0), hub._mat("feuillage"), false)
	for x in [-42.0, -28.0]:
		for z in [87.0, 97.0]:
			hub._lumiere(Vector3(x, HAUTEUR_TERMINAL - 1.2, z), CHAUD, 2.6, 14.0)
	# Petit indice : l'emblème de la Vigie, discret, au-dessus des guichets.
	hub._texte("◈", Vector3(-47.65, 4.0, 87.2), Color(0.6, 0.8, 1.0), 80, PI / 2, 1.5)


# --- Le ferry à quai (décor) -------------------------------------------------------

static func _construire_ferry(hub: HikariBay) -> void:
	var coque := hub._mat_pbr("metal_plate", 2.0, "metal", Color(0.9, 0.9, 0.92))
	var bleu := hub._mat_pbr("metal_plate", 2.0, "metal", Color(0.1, 0.18, 0.35))
	hub._bloc(-15.5, 79.0, -5.5, 111.0, -2.0, 0.2, bleu, false)
	hub._bloc(-15.3, 79.5, -5.7, 110.5, 0.2, 1.4, coque, false)
	hub._bloc(-14.5, 85.0, -6.5, 104.0, 1.4, 4.2, coque, false)
	hub._bloc(-13.5, 89.0, -7.5, 100.0, 4.2, 6.6, coque, false)
	# Hublots allumés.
	for i in 9:
		var z := 86.5 + i * 2.0
		hub._boite(Vector3(0.05, 0.5, 0.9), Vector3(-14.53, 2.8, z), hub._neon(CHAUD, 2.5), false)
	for i in 5:
		hub._boite(Vector3(0.05, 0.6, 1.2), Vector3(-13.53, 5.4, 90.5 + i * 2.0), hub._neon(Color(0.7, 0.9, 1.0), 2.0), false)
	hub._cylindre(0.7, 0.8, 3.0, Vector3(-10.5, 8.1, 96.0), bleu, false)
	hub._texte("ひかり丸 · HIKARI MARU", Vector3(-15.56, 0.9, 95.0), Color(0.1, 0.18, 0.35), 70, -PI / 2, 0.0)
	hub._lumiere(Vector3(-10.5, 7.5, 95.0), CHAUD, 2.0, 18.0)
	# Passerelle d'embarquement (fermée).
	hub._bloc(-18.0, 94.0, -15.5, 96.0, 0.6, 0.75, hub._mat("metal"), false)
	hub._texte("Embarquement fermé", Vector3(-18.0, 1.6, 95.0), ROUGE, 28, PI / 2, 2.0)


# --- Jetée de la grande roue -----------------------------------------------------------

static func _construire_jetee_roue(hub: HikariBay) -> void:
	var j := JETEE_ROUE
	_garde_corps(hub, Vector2(j.position.x, 75.0), Vector2(j.position.x, j.end.y))
	_garde_corps(hub, Vector2(j.end.x, 75.0), Vector2(j.end.x, j.end.y))
	_garde_corps(hub, Vector2(j.position.x, j.end.y), Vector2(j.end.x, j.end.y))
	# Guichet de la grande roue.
	var bois := Marche._bois(hub)
	hub._bloc(41.0, 80.0, 43.5, 84.0, 0, 2.6, bois)
	hub._bloc(40.8, 79.8, 43.7, 84.2, 2.6, 2.8, Marche._papier(hub, ROSE, 0.8), false)
	hub._texte("観覧車 · GRANDE ROUE · Ferris wheel", Vector3(43.56, 2.0, 82.0), Color(1.0, 0.85, 0.95), 30, PI / 2, 2.0)
	hub._texte("Fermée pour maintenance", Vector3(43.56, 1.4, 82.0), ROUGE, 24, PI / 2, 2.0)
	# Quai d'embarquement sous la roue.
	hub._bloc(50.0, 112.0, 60.0, 120.0, 0.0, 0.25, hub._mat("beton"))
	for x in [50.5, 59.5]:
		hub._cylindre(0.08, 0.08, 1.0, Vector3(x, 0.75, 112.2), hub._mat("metal"), false)
	hub._lumiere(Vector3(55.0, 3.0, 112.0), ROSE, 2.0, 14.0)


# --- Bateaux de pêche au mouillage -----------------------------------------------------

static func _construire_bateaux(hub: HikariBay) -> void:
	var couleurs := [Color(0.75, 0.2, 0.15), Color(0.15, 0.35, 0.6), Color(0.85, 0.85, 0.8)]
	var places := [Vector3(4.0, 0, 84.0), Vector3(14.0, 0, 90.0), Vector3(26.0, 0, 82.0), Vector3(-62.0, 0, 88.0)]
	for i in places.size():
		var p: Vector3 = places[i]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = couleurs[i % couleurs.size()]
		mat.roughness = 0.6
		hub._boite(Vector3(2.4, 1.0, 7.0), p + Vector3(0, -1.2, 0), mat, false)
		hub._boite(Vector3(1.6, 1.2, 2.0), p + Vector3(0, -0.2, 1.0), hub._mat("blanc"), false)
		hub._cylindre(0.05, 0.05, 4.0, p + Vector3(0, 1.0, -1.5), hub._mat("metal"), false)
		Marche._lanterne(hub, p + Vector3(0, 3.0, -1.5), Color(1.0, 0.6, 0.25), i % 2 == 0, 0.2)


# --- Habitants -------------------------------------------------------------------------

static func _construire_habitants(hub: HikariBay) -> void:
	Marche._pnj(hub, "guichetiere", Vector3(-45.0, 0, 91.5), -PI / 2)
	Marche._pnj(hub, "voyageur_terminal", Vector3(-33.0, 0, 99.5), PI)
	Marche._pnj(hub, "capitaine", Vector3(-19.6, 0, 91.0), 0.0)
	Marche._pnj(hub, "gardien_roue", Vector3(45.0, 0, 82.0), -PI / 2)
	Marche._pnj(hub, "grand_mere_ume", Vector3(20.0, 0, 71.0), PI)
	Marche._pnj(hub, "vendeur_takoyaki", Vector3(-20.0, 0, 62.6), PI)
	Marche._pnj(hub, "promeneuse_quai", Vector3(-58.0, 0, 69.0), PI / 2)
