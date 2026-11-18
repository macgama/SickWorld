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
const EcranAffiches := preload("res://scripts/monde/ecran_affiches.gd")
const AfficheActivite := preload("res://scripts/interface/affiche_activite.gd")

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
## Les archives : à l'ouest de la salle des portails (ouvertes au chapitre 5 de la Grèce).
const ARCHIVES := Rect2(-72.0, 112.0, 23.5, 22.0)
## Les époques, dans l'ordre ; les quatre premières (Préhistoire, Égypte, Grèce, Rome) ont un portail actif.
## Nombre de portails allumés (dans l'ordre d'EPOQUES) : Préhistoire, Égypte, Grèce, Rome, Chine, Moyen Âge, Mayence.
const PORTAILS_OUVERTS := 7
const EPOQUES := ["Préhistoire", "Égypte antique", "Grèce antique", "Rome antique", "Chine des Han", "Moyen Âge", "Mayence"]

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
	_construire_salle(hub, PORTAILS, mur, sol, plafond, [["nord", -30.0, -16.0], ["ouest", 120.0, 125.0]])
	_construire_salle(hub, ARCHIVES, mur, sol, plafond, [["est", 120.0, 125.0]])
	_amenager_hall(hub, metal)
	_amenager_coffre(hub, metal)
	_amenager_entrainement(hub, metal)
	_amenager_portails(hub, metal)
	_amenager_archives(hub, metal)


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
	_amenager_missions(hub, metal)


## Bureau des missions, contre le mur nord à droite de l'escalier : Ayaka Mori
## (missions du jour et de la semaine, voir quetes_du_jour.gd) et Sven Halvorsen,
## l'intendant qui échange les insignes de la Vigie (artisan « intendance »).
static func _amenager_missions(hub: HikariBay, metal: Material) -> void:
	var z := HALL.position.y
	# Comptoir devant les deux agents.
	hub._bloc(-11.0, z + 6.6, -0.8, z + 7.4, SOL, SOL + 1.05, metal)
	hub._boite(Vector3(10.2, 0.05, 0.9), Vector3(-5.9, SOL + 1.08, z + 7.0), hub._neon(CYAN, 0.5), false)
	# Enseignes sur la face avant du comptoir (côté joueurs).
	hub._texte("MISSIONS · 任務", Vector3(-8.2, SOL + 0.62, z + 7.43), Color(0.7, 0.92, 1.0), 44, 0.0, 2.0)
	hub._texte("ÉCHANGE · 交換", Vector3(-3.0, SOL + 0.62, z + 7.43), Color(1.0, 0.85, 0.5), 44, 0.0, 2.0)
	# Petits écrans posés sur le comptoir, tournés vers les agents.
	for x in [-9.6, -4.4]:
		var ecran := hub._boite(Vector3(0.9, 0.55, 0.05), Vector3(x, SOL + 1.38, z + 6.85), hub._neon(CYAN.lerp(VIOLET, 0.2), 1.0), false)
		ecran.rotation.x = -0.35
	hub._lumiere(Vector3(-5.9, SOL + 3.2, z + 5.0), Color(0.75, 0.9, 1.0), 2.2, 10.0)
	_pnj(hub, "maitre_missions", Vector3(-8.2, SOL, z + 5.2), PI)
	_pnj(hub, "intendant", Vector3(-3.0, SOL, z + 5.2), PI)


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
		var actif := i < PORTAILS_OUVERTS
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
	# Barrière invisible devant les portails fermés seulement (elle couvrait aussi ceux
	# de l'Égypte et de la Grèce, qu'on ne pouvait donc pas traverser à pied).
	if PORTAILS_OUVERTS < EPOQUES.size():
		var pas := (r.size.x - 10.0) / (EPOQUES.size() - 1)
		var debut := r.position.x + 5.0 + PORTAILS_OUVERTS * pas - pas * 0.5
		var fin := r.end.x - 2.0
		hub._collision_boite(Vector3(fin - debut, 4.0, 0.3), Transform3D(Basis(), Vector3((debut + fin) * 0.5, SOL + 2.0, r.end.y - 6.0)))
	_pnj(hub, "technicienne", Vector3(r.position.x + 5.0 + 4.5, SOL, r.end.y - 9.0), PI * 0.8)
	# Le mur des époques (mur est) : un grand écran qui fait défiler les affiches des îles.
	# [F] devant ouvre l'affiche montrée ; son bouton « Voyager » passe par le portail.
	var ecran := EcranAffiches.new()
	ecran.name = "MurDesEpoques"
	ecran.taille = Vector2(10.6, 6.0)
	ecran.images_par_affiche = 2
	var ids := PackedStringArray()
	for i in PORTAILS_OUVERTS:
		var id := AfficheActivite.id_du_portail(EPOQUES[i])
		if id != "":
			ids.append(id)
			ecran.actions[id] = hub.voyager_vers.bind(EPOQUES[i])
	ecran.affiches = ids
	ecran.position = Vector3(r.end.x - 0.12, SOL + 4.2, r.position.y + 11.0)
	ecran.rotation.y = -PI / 2
	hub._contenu.add_child(ecran)
	hub._texte("Les époques · 時代", Vector3(r.end.x - 0.1, SOL + 7.55, r.position.y + 11.0), CYAN, 40, -PI / 2, 2.0)


# --- Archives ----------------------------------------------------------------

## Des rayonnages de dossiers papier, une table de lecture sous une lampe, et le
## dossier 0417 (Damien Roche) ouvert dessus. L'archiviste Odile Ferrand veille.
static func _amenager_archives(hub: HikariBay, metal: Material) -> void:
	var r := ARCHIVES
	var carton := _mat_uni(Color(0.42, 0.31, 0.19), 0.9)
	var rouge := _mat_uni(Color(0.55, 0.12, 0.1), 0.85)
	# Trois rangées de rayonnages, du nord au sud, côté ouest.
	for i in 3:
		var x := r.position.x + 3.0 + i * 4.2
		# La troisième rangée est plus courte : la troisième cellule (Plomb) est au bout.
		var fin_z := r.end.y - (6.2 if i == 2 else 2.0)
		hub._bloc(x - 0.4, r.position.y + 2.0, x + 0.4, fin_z, SOL, SOL + 3.6, metal, true).visible = false
		for k in 4:
			var y := SOL + 0.4 + k * 0.85
			hub._boite(Vector3(0.8, 0.04, fin_z - r.position.y - 2.0), Vector3(x, y, (r.position.y + 2.0 + fin_z) * 0.5), metal, false)
			var z := r.position.y + 2.4
			while z < fin_z - 0.4:
				var boite := hub._boite(Vector3(0.6, 0.55, 0.9), Vector3(x, y + 0.3, z), rouge if (i * 7 + k * 3 + int(z)) % 11 == 0 else carton, false)
				boite.rotation.y = 0.02 * sin(z * 3.1 + k)
				z += 1.05
	# La table de lecture, la lampe verte de banquier et le dossier ouvert.
	var c := Vector3(r.end.x - 6.0, SOL, r.get_center().y)
	hub._boite(Vector3(2.6, 0.08, 1.4), c + Vector3(0, 0.82, 0), hub._mat("bois"))
	for dx in [-1.15, 1.15]:
		for dz in [-0.55, 0.55]:
			hub._boite(Vector3(0.08, 0.8, 0.08), c + Vector3(dx, 0.4, dz), metal, false)
	hub._bloc(c.x - 1.3, c.z - 0.7, c.x + 1.3, c.z + 0.7, SOL, SOL + 0.86, metal, true).visible = false
	hub._boite(Vector3(0.9, 0.02, 0.6), c + Vector3(-0.2, 0.87, 0), _mat_uni(Color(0.9, 0.87, 0.78), 0.95), false)
	hub._boite(Vector3(0.44, 0.025, 0.6), c + Vector3(-0.42, 0.89, 0), rouge, false)
	hub._cylindre(0.05, 0.12, 0.05, c + Vector3(0.8, 0.88, -0.3), metal, false)
	hub._boite(Vector3(0.5, 0.12, 0.16), c + Vector3(0.8, 1.25, -0.2), hub._neon(Color(0.2, 0.7, 0.35), 1.2), false)
	hub._lumiere(c + Vector3(0.6, 1.6, 0), Color(1.0, 0.85, 0.6), 2.4, 7.0)
	var fiche := hub._texte("DOSSIER 0417\nROCHE, Damien\nStatut : DÉCÉDÉ ?", c + Vector3(0.0, 0.885, 0), Color(0.15, 0.1, 0.08), 32, 0.0, 1.0)
	fiche.pixel_size = 0.004
	fiche.rotation.x = -PI / 2
	_pnj(hub, "archiviste", c + Vector3(-2.2, 0, 0), PI / 2)
	hub._texte("Archives de la Vigie", Vector3(r.end.x - 0.7, SOL + 3.2, r.position.y + 4.0), Color(1.0, 0.85, 0.5), 56, -PI / 2, 2.0)
	_amenager_cellule(hub, metal)


## Les cellules de détention, dans le coin sud-est des archives : des barreaux, un lit de camp,
## une chaise. Vides jusqu'au chapitre 8 de Rome (Janus est enfermée dans la première, voir la
## mission « cellule_janus », qui y fait apparaître Livia Conti) et au chapitre 8 de la Chine
## (Cinabre dans la seconde, juste à l'ouest : mission « cellule_cinabre ») et au chapitre 8 du
## Moyen Âge (Plomb dans la troisième : mission « cellule_plomb »).
static func _amenager_cellule(hub: HikariBay, metal: Material) -> void:
	var r := ARCHIVES
	_cellule(hub, metal, r.end.x - 5.0, r.end.x - 0.3, true)
	_cellule(hub, metal, r.end.x - 10.0, r.end.x - 5.0, false)
	_cellule(hub, metal, r.end.x - 15.0, r.end.x - 10.0, false)


static func _cellule(hub: HikariBay, metal: Material, x0: float, x1: float, mur_est: bool) -> void:
	var r := ARCHIVES
	var z0 := r.end.y - 5.2
	var z1 := r.end.y - 0.3
	# Les barreaux : côté ouest et côté nord (à l'est, le mur de la salle ou la cellule voisine).
	var z := z0
	while z <= z1:
		hub._cylindre(0.03, 0.03, 3.4, Vector3(x0, SOL + 1.7, z), metal, false)
		z += 0.22
	var x := x0
	while x <= x1:
		hub._cylindre(0.03, 0.03, 3.4, Vector3(x, SOL + 1.7, z0), metal, false)
		x += 0.22
	for y: float in [0.1, 1.7, 3.35]:
		hub._boite(Vector3(0.08, 0.08, z1 - z0), Vector3(x0, SOL + y, (z0 + z1) * 0.5), metal, false)
		hub._boite(Vector3(x1 - x0, 0.08, 0.08), Vector3((x0 + x1) * 0.5, SOL + y, z0), metal, false)
	hub._bloc(x0 - 0.06, z0, x0 + 0.06, z1, SOL, SOL + 3.4, metal, true).visible = false
	hub._bloc(x0, z0 - 0.06, x1, z0 + 0.06, SOL, SOL + 3.4, metal, true).visible = false
	# Le lit de camp et la chaise.
	hub._boite(Vector3(0.8, 0.45, 2.0), Vector3(x1 - 0.6, SOL + 0.22, z1 - 1.4), _mat_uni(Color(0.3, 0.32, 0.3), 0.9), false)
	hub._boite(Vector3(0.45, 0.06, 0.45), Vector3(x0 + 1.6, SOL + 0.46, z1 - 1.2), metal, false)
	hub._boite(Vector3(0.45, 0.5, 0.05), Vector3(x0 + 1.6, SOL + 0.72, z1 - 0.98), metal, false)
	hub._lumiere(Vector3((x0 + x1) * 0.5, SOL + 3.2, (z0 + z1) * 0.5), Color(0.8, 0.88, 1.0), 1.2, 5.0)
	if mur_est:
		hub._texte("Détention", Vector3(x0 - 5.1, SOL + 3.0, (z0 + z1) * 0.5), Color(0.75, 0.82, 0.9), 40, -PI / 2, 1.2)


static func _mat_uni(couleur: Color, rugosite: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	return m
