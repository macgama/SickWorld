extends RefCounted
## Le QG de la Vigie, sous la station Asahi (voir docs/HUB.md, section 4).
##
## Construit dans la scène du hub, sous terre, juste derrière la porte blindée
## du couloir de la station : un grand escalier descend jusqu'au Hall des
## opérations, qui dessert le Coffre (ouest), la Salle d'entraînement (est)
## et la Salle des portails (sud).
##
## Repères (mètres) : sol du QG à y = -12, plafond à y = -4.

## Chargés directement (et non par nom de classe) : le jeu fonctionne même si
## l'éditeur Godot était ouvert pendant la mise à jour du dossier.
const Pnj := preload("res://scripts/monde/pnj.gd")

const SOL := -12.0
const PLAFOND := -4.0
## Couloir de la station (doit correspondre à HikariBay.ESCALIER) et escalier du QG.
const X1 := -26.0
const X2 := -20.0
const Z_PORTE := 40.0
const Z_ESCALIER := 46.0
const Z_HALL := 70.0
## Hall des opérations.
const HALL := Rect2(-50.0, 70.0, 54.0, 40.0)
## Coffre (ouest), entraînement (est), portails (sud).
const COFFRE := Rect2(-74.0, 76.0, 24.0, 28.0)
const ENTRAINEMENT := Rect2(4.0, 74.0, 28.0, 32.0)
const PORTAILS := Rect2(-48.0, 110.0, 50.0, 26.0)
## Les époques, dans l'ordre ; seule la première a un portail actif.
const EPOQUES := ["Préhistoire", "Égypte antique", "Grèce antique", "Moyen Âge", "Renaissance"]

const VIOLET := Color(0.62, 0.48, 1.0)
const CYAN := Color(0.35, 0.85, 1.0)


static func construire(hub: HikariBay) -> void:
	var mur := hub._mat_pbr("concrete_tile_facade", 3.0, "beton", Color(0.55, 0.57, 0.62))
	var sol := hub._mat_pbr("terrazzo_tiles", 2.5, "carrelage", Color(0.6, 0.6, 0.65))
	var metal := hub._mat_pbr("metal_plate", 1.5, "metal")
	var plafond := hub._mat_pbr("brushed_concrete", 3.0, "beton", Color(0.35, 0.35, 0.4))
	hub.qg = {"portails": [], "pnj": []}
	_construire_escalier(hub, mur, sol, metal)
	_construire_salle(hub, HALL, mur, sol, plafond, [
		["nord", X1, X2], ["ouest", 84.0, 92.0], ["est", 84.0, 92.0], ["sud", -30.0, -16.0]])
	_construire_salle(hub, COFFRE, mur, sol, plafond, [["est", 84.0, 92.0]])
	_construire_salle(hub, ENTRAINEMENT, mur, sol, plafond, [["ouest", 84.0, 92.0]])
	_construire_salle(hub, PORTAILS, mur, sol, plafond, [["nord", -30.0, -16.0]])
	_amenager_hall(hub, metal)
	_amenager_coffre(hub, metal)
	_amenager_entrainement(hub, metal)
	_amenager_portails(hub, metal)


## Petites animations (globe de la table, tourbillon des portails).
static func animer(hub: HikariBay, delta: float) -> void:
	var globe: Node3D = hub.qg.get("globe")
	if globe != null and is_instance_valid(globe):
		globe.rotate_y(delta * 0.25)


# --- Escalier : de la porte blindée (y = -4) jusqu'au hall (y = -12) -------

static func _construire_escalier(hub: HikariBay, mur: Material, sol: Material, metal: Material) -> void:
	var haut := -4.0
	# Palier derrière la porte.
	hub._bloc(X1, Z_PORTE + 0.5, X2, Z_ESCALIER, haut - 0.5, haut, sol)
	# Marches visuelles et pente pour marcher dessus.
	var marches := 40
	var longueur := Z_HALL - Z_ESCALIER
	var hauteur := haut - SOL
	for i in marches:
		var z := Z_ESCALIER + (i + 0.5) * longueur / marches
		var y := haut - (i + 1.0) * hauteur / marches
		hub._bloc(X1, z - longueur / marches * 0.5, X2, z + longueur / marches * 0.5,
				y - 0.3, y + hauteur / marches, sol, false)
	var pente := atan2(hauteur, longueur)
	hub._collision_boite(Vector3(X2 - X1, 0.2, Vector2(longueur, hauteur).length()),
			Transform3D(Basis(Vector3.RIGHT, pente), Vector3((X1 + X2) * 0.5, (haut + SOL) * 0.5 - 0.1, (Z_ESCALIER + Z_HALL) * 0.5)))
	# Murs de la cage d'escalier (jusqu'à la dalle de la ville, à y = -1).
	hub._bloc(X1 - 0.5, Z_PORTE + 0.5, X1, Z_HALL, SOL, -1.0, mur)
	hub._bloc(X2, Z_PORTE + 0.5, X2 + 0.5, Z_HALL, SOL, -1.0, mur)
	# Linteau au-dessus de l'arrivée dans le hall (ferme la cage d'escalier).
	hub._bloc(X1 - 0.5, Z_HALL - 0.5, X2 + 0.5, Z_HALL, PLAFOND, -1.0, mur)
	# Rampes lumineuses le long des murs (guident vers le bas).
	for x in [X1 + 0.1, X2 - 0.1]:
		var bande := hub._boite(Vector3(0.06, 0.06, Vector2(longueur, hauteur).length()),
				Vector3(x, (haut + SOL) * 0.5 + 1.0, (Z_ESCALIER + Z_HALL) * 0.5), hub._neon(VIOLET, 3.0), false)
		bande.rotation.x = pente
	hub._lumiere(Vector3((X1 + X2) * 0.5, haut + 2.0, Z_PORTE + 3.0), VIOLET, 3.0, 12.0)
	hub._lumiere(Vector3((X1 + X2) * 0.5, -6.0, 58.0), Color(0.85, 0.9, 1.0), 3.0, 16.0)
	hub._texte("LA VIGIE", Vector3((X1 + X2) * 0.5, -5.2, Z_HALL - 0.4), VIOLET, 90, PI, 3.0)


# --- Salles ----------------------------------------------------------------

## Construit une salle rectangulaire (sol, plafond, 4 murs) avec des ouvertures.
## Chaque ouverture : [côté, début, fin] (le long de x pour nord/sud, de z pour est/ouest).
static func _construire_salle(hub: HikariBay, r: Rect2, mur: Material, sol: Material, plafond: Material, ouvertures: Array) -> void:
	var x1 := r.position.x
	var x2 := r.end.x
	var z1 := r.position.y
	var z2 := r.end.y
	hub._bloc(x1, z1, x2, z2, SOL - 0.5, SOL, sol)
	hub._bloc(x1 - 0.5, z1 - 0.5, x2 + 0.5, z2 + 0.5, PLAFOND, PLAFOND + 0.5, plafond)
	for cote in ["nord", "sud", "ouest", "est"]:
		var trous := ouvertures.filter(func(o): return o[0] == cote)
		var debut := x1 if cote in ["nord", "sud"] else z1
		var fin := x2 if cote in ["nord", "sud"] else z2
		var morceaux := []
		var curseur := debut
		for o in trous:
			morceaux.append([curseur, o[1]])
			curseur = o[2]
		morceaux.append([curseur, fin])
		for m in morceaux:
			if m[1] - m[0] < 0.01:
				continue
			match cote:
				"nord": hub._bloc(m[0], z1 - 0.5, m[1], z1, SOL, PLAFOND, mur)
				"sud": hub._bloc(m[0], z2, m[1], z2 + 0.5, SOL, PLAFOND, mur)
				"ouest": hub._bloc(x1 - 0.5, m[0], x1, m[1], SOL, PLAFOND, mur)
				"est": hub._bloc(x2, m[0], x2 + 0.5, m[1], SOL, PLAFOND, mur)
	# Bandeaux lumineux au plafond.
	var n := maxi(1, int(r.size.x / 10.0))
	for i in n:
		var x := x1 + (i + 0.5) * r.size.x / n
		hub._boite(Vector3(0.4, 0.06, r.size.y - 4.0), Vector3(x, PLAFOND - 0.05, (z1 + z2) * 0.5),
				hub._neon(Color(0.85, 0.9, 1.0), 1.6), false)
		hub._lumiere(Vector3(x, PLAFOND - 1.2, (z1 + z2) * 0.5), Color(0.8, 0.85, 1.0), 2.6, r.size.y * 0.9)


static func _pnj(hub: HikariBay, id: String, p: Vector3, angle: float) -> Pnj:
	var pnj := Pnj.new()
	pnj.identifiant = id
	pnj.name = "Pnj_" + id
	pnj.position = p
	pnj.rotation.y = angle
	hub._contenu.add_child(pnj)
	hub.qg["pnj"].append(pnj)
	return pnj


# --- Hall des opérations -------------------------------------------------

static func _amenager_hall(hub: HikariBay, metal: Material) -> void:
	var c := Vector3(HALL.get_center().x + 4.0, SOL, HALL.get_center().y)
	# Grande table holographique ronde, avec le globe des époques au-dessus.
	hub._cylindre(4.0, 4.3, 1.0, c + Vector3(0, 0.5, 0), metal)
	var dessus := hub._cylindre(3.8, 3.8, 0.04, c + Vector3(0, 1.02, 0), hub._neon(CYAN, 0.8), false)
	dessus.name = "TableHolographique"
	var globe := Node3D.new()
	globe.name = "GlobeDesEpoques"
	globe.position = c + Vector3(0, 3.2, 0)
	hub._contenu.add_child(globe)
	var sphere := MeshInstance3D.new()
	var maillage := SphereMesh.new()
	maillage.radius = 1.6
	maillage.height = 3.2
	sphere.mesh = maillage
	var verre := StandardMaterial3D.new()
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	verre.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.12)
	verre.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere.material_override = verre
	globe.add_child(sphere)
	# Une lumière par époque autour du globe ; la Préhistoire brille en violet (malade).
	for i in EPOQUES.size():
		var angle := i * TAU / EPOQUES.size()
		var point := MeshInstance3D.new()
		var petite := SphereMesh.new()
		petite.radius = 0.16
		petite.height = 0.32
		point.mesh = petite
		point.material_override = hub._neon(VIOLET if i == 0 else Color(0.6, 0.65, 0.7), 5.0 if i == 0 else 1.0)
		point.position = Vector3(cos(angle) * 1.65, sin(i * 1.3) * 0.6, sin(angle) * 1.65)
		globe.add_child(point)
	hub.qg["globe"] = globe
	hub._lumiere(c + Vector3(0, 2.5, 0), CYAN, 2.5, 14.0)
	# Postes de travail le long des murs est et ouest, avec des écrans.
	for z in [76.0, 82.0, 96.0, 102.0]:
		for x in [HALL.position.x + 1.5, HALL.end.x - 1.5]:
			hub._bloc(x - 0.8, z - 1.6, x + 0.8, z + 1.6, SOL, SOL + 0.8, metal)
			var face := 1.0 if x < c.x else -1.0
			var ecran := hub._boite(Vector3(0.05, 0.9, 2.6), Vector3(x - face * 0.5, SOL + 1.45, z), hub._neon(CYAN.lerp(VIOLET, 0.3), 1.2), false)
			ecran.name = "Ecran"
	# Grand écran mural au nord, de part et d'autre de l'escalier.
	for x in [HALL.position.x + 12.0, HALL.end.x - 12.0]:
		var mur_ecran := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(14, 5)
		mur_ecran.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = HikariBay.SHADER_ECRAN
		mat.set_shader_parameter("couleur_a", VIOLET)
		mat.set_shader_parameter("couleur_b", CYAN)
		mat.set_shader_parameter("luminosite", 0.8)
		mur_ecran.material_override = mat
		mur_ecran.position = Vector3(x, SOL + 4.5, HALL.position.y + 0.05)
		hub._contenu.add_child(mur_ecran)
	hub._texte("Stabilité des époques", Vector3(HALL.position.x + 12.0, SOL + 6.2, HALL.position.y + 0.1), Color(1, 1, 1), 60, 0.0, 1.5)
	hub._texte("Préhistoire : 12 % · instable", Vector3(HALL.position.x + 12.0, SOL + 4.5, HALL.position.y + 0.1), VIOLET, 70, 0.0, 2.0)
	hub._texte("Surveillance · Hikari Bay", Vector3(HALL.end.x - 12.0, SOL + 4.5, HALL.position.y + 0.1), CYAN, 70, 0.0, 2.0)
	# Panneaux d'orientation.
	hub._texte("← Coffre", Vector3(HALL.position.x + 0.6, SOL + 3.2, 88.0), Color(1, 0.9, 0.6), 60, PI / 2, 2.0)
	hub._texte("Entraînement →", Vector3(HALL.end.x - 0.6, SOL + 3.2, 88.0), Color(1, 0.9, 0.6), 60, -PI / 2, 2.0)
	hub._texte("Salle des portails", Vector3(-23.0, SOL + 4.6, HALL.end.y - 0.6), CYAN, 70, PI, 2.5)
	# La commandante, près de la table, face à l'escalier.
	_pnj(hub, "commandante", c + Vector3(-1.5, 0, -5.5), 0.0)


# --- Coffre (banque) -------------------------------------------------------

static func _amenager_coffre(hub: HikariBay, metal: Material) -> void:
	var r := COFFRE
	# Porte de chambre forte ronde au fond (mur ouest).
	var porte := hub._cylindre(3.0, 3.0, 0.6, Vector3(r.position.x + 0.3, SOL + 3.4, r.get_center().y), metal, false)
	porte.rotation.z = PI / 2
	hub._cylindre(0.6, 0.6, 0.8, Vector3(r.position.x + 0.5, SOL + 3.4, r.get_center().y), hub._neon(Color(1.0, 0.8, 0.4), 1.5), false).rotation.z = PI / 2
	# Murs de casiers (nord et sud).
	for z in [r.position.y + 0.4, r.end.y - 0.4]:
		for i in 10:
			for j in 4:
				var x := r.position.x + 3.0 + i * 1.9
				hub._boite(Vector3(1.8, 1.0, 0.5), Vector3(x, SOL + 0.55 + j * 1.05, z), metal, false)
		hub._bloc(r.position.x + 2.0, z - 0.35, r.end.x - 2.0, z + 0.35, SOL, SOL + 4.2, metal, true).visible = false
	# Comptoir et gardien.
	hub._bloc(r.position.x + 9.0, r.get_center().y - 3.0, r.position.x + 10.0, r.get_center().y + 3.0, SOL, SOL + 1.1, metal)
	_pnj(hub, "banquier", Vector3(r.position.x + 8.0, SOL, r.get_center().y), PI / 2)
	hub._lumiere(Vector3(r.position.x + 4.0, SOL + 5.0, r.get_center().y), Color(1.0, 0.85, 0.6), 3.2, 16.0)
	hub._texte("Coffre de la Vigie", Vector3(r.position.x + 0.7, SOL + 7.0, r.get_center().y), Color(1.0, 0.85, 0.5), 70, PI / 2, 2.0)


# --- Salle d'entraînement --------------------------------------------------

static func _amenager_entrainement(hub: HikariBay, metal: Material) -> void:
	var r := ENTRAINEMENT
	# Tapis au sol et mannequins d'entraînement.
	hub._bloc(r.position.x + 4.0, r.position.y + 4.0, r.end.x - 4.0, r.end.y - 4.0, SOL, SOL + 0.05, hub._mat("bois"), false)
	for p in [Vector2(14, 84), Vector2(22, 84), Vector2(14, 96), Vector2(22, 96)]:
		hub._cylindre(0.3, 0.35, 1.8, Vector3(p.x, SOL + 0.9, p.y), hub._mat("bois"))
		hub._cylindre(0.5, 0.5, 0.05, Vector3(p.x, SOL + 1.4, p.y - 0.36), hub._neon(Color(1.0, 0.3, 0.3), 1.5), false).rotation.x = PI / 2
	# Un entraîneur par classe, le long du mur est.
	var classes := ["rempart", "lame", "traqueur", "tisseur"]
	for i in classes.size():
		var z := r.position.y + 6.0 + i * 6.5
		_pnj(hub, classes[i], Vector3(r.end.x - 2.5, SOL, z), PI / 2)
		hub._bloc(r.end.x - 0.6, z - 1.5, r.end.x - 0.1, z + 1.5, SOL + 2.2, SOL + 3.4, hub._neon(VIOLET.lerp(CYAN, i / 3.0), 0.6), false)
	hub._texte("Salle d'entraînement", Vector3(r.end.x - 0.7, SOL + 6.0, r.get_center().y), Color(1, 0.9, 0.6), 70, -PI / 2, 2.0)


# --- Salle des portails ----------------------------------------------------

static func _amenager_portails(hub: HikariBay, metal: Material) -> void:
	var r := PORTAILS
	for i in EPOQUES.size():
		var x := r.position.x + 5.0 + i * (r.size.x - 10.0) / (EPOQUES.size() - 1)
		var z := r.end.y - 4.0
		var actif := i == 0
		var anneau := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = 2.6
		tore.outer_radius = 3.1
		tore.rings = 64
		anneau.mesh = tore
		anneau.material_override = metal
		anneau.rotation.x = PI / 2
		anneau.position = Vector3(x, SOL + 3.2, z)
		hub._contenu.add_child(anneau)
		var halo := MeshInstance3D.new()
		var tore2 := TorusMesh.new()
		tore2.inner_radius = 2.55
		tore2.outer_radius = 2.65
		tore2.rings = 64
		halo.mesh = tore2
		halo.material_override = hub._neon(CYAN if actif else Color(0.25, 0.25, 0.3), 4.0 if actif else 0.6)
		halo.rotation.x = PI / 2
		halo.position = anneau.position
		hub._contenu.add_child(halo)
		hub._bloc(x - 3.4, z - 1.2, x + 3.4, z + 1.2, SOL, SOL + 0.08, metal, false)
		if actif:
			# Voile lumineux du portail actif.
			var voile := MeshInstance3D.new()
			var disque := CylinderMesh.new()
			disque.top_radius = 2.6
			disque.bottom_radius = 2.6
			disque.height = 0.02
			voile.mesh = disque
			var mat := ShaderMaterial.new()
			mat.shader = HikariBay.SHADER_ECRAN
			mat.set_shader_parameter("couleur_a", Color(0.75, 0.9, 1.0))
			mat.set_shader_parameter("couleur_b", CYAN)
			mat.set_shader_parameter("luminosite", 1.3)
			mat.set_shader_parameter("vitesse", 0.4)
			voile.material_override = mat
			voile.rotation.x = PI / 2
			voile.position = anneau.position
			voile.name = "VoilePortail"
			hub._contenu.add_child(voile)
			hub._lumiere(anneau.position + Vector3(0, 0, -2.0), CYAN, 3.0, 12.0)
			# Zone de passage : la traverser déclenche le voyage.
			var zone := Area3D.new()
			zone.name = "Portail_" + EPOQUES[i]
			zone.add_to_group("portail_actif")
			zone.position = anneau.position
			zone.collision_layer = 0
			zone.collision_mask = 2 # couche des joueurs
			var forme := CollisionShape3D.new()
			var boite := BoxShape3D.new()
			boite.size = Vector3(4.0, 5.0, 1.2)
			forme.shape = boite
			zone.add_child(forme)
			zone.set_meta("epoque", EPOQUES[i])
			hub._contenu.add_child(zone)
			hub.qg["portails"].append(zone)
		else:
			# Portails pas encore stables : bâche et ruban.
			hub._boite(Vector3(5.4, 5.4, 0.1), Vector3(x, SOL + 3.2, z - 0.4), hub._mat_pbr("painted_metal_shutter", 2.0, "metal", Color(0.3, 0.32, 0.35)), false)
		hub._texte(EPOQUES[i] + ("" if actif else "\n(instable)"), Vector3(x, SOL + 7.0, z - 0.6), CYAN if actif else Color(0.6, 0.6, 0.65), 56, PI, 2.0 if actif else 1.0)
	# Barrière invisible devant les portails fermés.
	hub._collision_boite(Vector3(r.size.x - 14.0, 4.0, 0.3), Transform3D(Basis(), Vector3(r.get_center().x + 5.0, SOL + 2.0, r.end.y - 6.0)))
	_pnj(hub, "technicienne", Vector3(r.position.x + 5.0 + 4.5, SOL, r.end.y - 9.0), PI * 0.8)
