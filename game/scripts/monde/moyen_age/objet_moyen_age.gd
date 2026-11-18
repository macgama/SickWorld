@tool
extends "res://scripts/monde/chine/objet_chine.gd"
## Objets de quête de l'île du Moyen Âge (en plus de ceux de la Chine, de Rome, de la
## Grèce, de l'Égypte et de la Préhistoire) :
## - « gerbe » : une gerbe de blé couchée dans le chaume, liée d'un brin de paille, piquée
##   d'éclats violets (la fracture) ; ramassée, elle disparaît.
## - « craie » : un message tracé à la craie sur une pierre (Masque écrit ainsi) ; lu, il
##   reste sur la pierre, à moitié effacé.
## - « sac_farine » : un sac de toile plein de farine, ficelé, posé sur une planche.
## - « lampe_frontale » : une lampe frontale de chantier, élastique rouge et LED qui clignote
##   encore (l'objet moderne du chef des routiers).
## - « verre_bleu » : un éclat de verre bleu de Chartres posé sur un chiffon.
## - « seau » : un seau de bois cerclé de fer.
## - « treuil » : le treuil de bois d'une carrière (deux chevalets, un tambour, une corde),
##   coincé par une pierre et une lueur violette ; débloqué (cacher()), la corde est tendue.
## - « larme_plomb » : des gouttes de plomb fondu figées en larmes grises et brillantes, dans
##   l'herbe (la trace de Plomb) ; ramassées, elles disparaissent.
## - « coffret » : le coffret de bois du verrier (fers à gruger, compas, morceaux de verre),
##   à moitié enfoui sous des poutres noircies ; dégagé, il disparaît.
## - « fumigene » : un fumigène moderne (une boîte de métal gris) qui crache une fumée grise ;
##   étouffé, il disparaît.
## - un Las à qui l'on rend courage n'a pas de forme : l'objet est invisible, posé sur le
##   personnage (meta « pnj_lie ») ; quand il est compté, la fumée grise se dissipe.


## Une gerbe de blé : un faisceau de tiges dorées, épis d'un côté, liées au milieu.
func _construire_gerbe() -> void:
	var paille := _mat_uni(Color(0.86, 0.7, 0.36), 0.9)
	var epi := _mat_uni(Color(0.78, 0.6, 0.28), 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	var angle := hasard.randf() * TAU
	var axe := Vector3(cos(angle), 0, sin(angle))
	var base := Basis.looking_at(axe, Vector3.UP)
	for k in 26:
		var d := Vector3(hasard.randf_range(-0.12, 0.12), hasard.randf_range(0.05, 0.22), hasard.randf_range(-0.04, 0.04))
		var tige := _baton(0.008, 1.1, paille, base * d, Vector3.ZERO)
		tige.basis = base * Basis(Vector3.RIGHT, PI / 2 + hasard.randf_range(-0.08, 0.08))
		var bout := _boule(0.022, 0.12, epi, base * (d + Vector3(0, 0, -0.6)), Vector3(1, 1, 1))
		bout.basis = tige.basis
	# Le lien de paille tordue, au milieu.
	var lien := TorusMesh.new()
	lien.inner_radius = 0.12
	lien.outer_radius = 0.16
	var anneau := _morceau(lien, _mat_uni(Color(0.6, 0.48, 0.26), 1.0), Vector3(0, 0.14, 0))
	anneau.basis = base * Basis(Vector3.RIGHT, PI / 2)
	_trace_violette()


## Un message à la craie sur une pierre plate (Masque n'utilise jamais la radio).
func _construire_craie() -> void:
	var pierre := BoxMesh.new()
	pierre.size = Vector3(1.4, 0.9, 0.35)
	_morceau(pierre, _mat_uni(Color(0.5, 0.48, 0.44), 1.0), Vector3(0, 0.45, 0), Vector3(0.1, 0, 0.02))
	var texte := Label3D.new()
	texte.text = String(get_meta("texte_craie", "Il est passé ici.\n— M."))
	texte.font_size = 42
	texte.pixel_size = 0.004
	texte.modulate = Color(0.95, 0.95, 0.92, 0.9)
	texte.outline_size = 0
	texte.position = Vector3(0, 0.5, 0.19)
	texte.rotation.x = 0.1
	_visuel.add_child(texte)
	_debout = Node3D.new()
	_debout.name = "Lu"
	_debout.visible = false
	add_child(_debout)
	_morceau_dans(_debout, pierre, _mat_uni(Color(0.5, 0.48, 0.44), 1.0), Vector3(0, 0.45, 0), Vector3(0.1, 0, 0.02))
	var efface := texte.duplicate() as Label3D
	efface.modulate.a = 0.35
	_debout.add_child(efface)


## Un sac de farine : un gros coussin de toile écrue, noué en haut, sur une planche.
func _construire_sac_farine() -> void:
	var toile := _mat_uni(Color(0.82, 0.78, 0.68), 1.0)
	_boule(0.34, 0.8, toile, Vector3(0, 0.36, 0), Vector3(1.0, 1.0, 0.8))
	_baton(0.06, 0.16, toile, Vector3(0, 0.78, 0))
	_baton(0.075, 0.03, _mat_uni(Color(0.45, 0.36, 0.22), 1.0), Vector3(0, 0.74, 0))
	var planche := BoxMesh.new()
	planche.size = Vector3(0.9, 0.04, 0.7)
	_morceau(planche, _mat_uni(Color(0.42, 0.3, 0.18), 0.9), Vector3(0, 0.02, 0))
	# Un peu de farine renversée.
	var tas := CylinderMesh.new()
	tas.top_radius = 0.0
	tas.bottom_radius = 0.18
	tas.height = 0.05
	_morceau(tas, _mat_uni(Color(0.95, 0.94, 0.9), 1.0), Vector3(0.38, 0.03, 0.2))


## Une lampe frontale moderne, posée sur une souche : élastique rouge, boîtier noir, LED.
func _construire_lampe_frontale() -> void:
	_baton(0.22, 0.4, _mat_uni(Color(0.36, 0.26, 0.16), 1.0), Vector3(0, 0.2, 0))
	var elastique := TorusMesh.new()
	elastique.inner_radius = 0.08
	elastique.outer_radius = 0.1
	_morceau(elastique, _mat_uni(Color(0.8, 0.12, 0.1), 0.6), Vector3(0, 0.42, 0))
	var boitier := BoxMesh.new()
	boitier.size = Vector3(0.07, 0.045, 0.04)
	_morceau(boitier, _mat_uni(Color(0.06, 0.06, 0.07), 0.4), Vector3(0, 0.44, 0.1))
	var led := _emissif(Color(0.9, 0.95, 1.0), 5.0)
	var verre := CylinderMesh.new()
	verre.top_radius = 0.015
	verre.bottom_radius = 0.015
	verre.height = 0.01
	_morceau(verre, led, Vector3(0, 0.44, 0.125), Vector3(PI / 2, 0, 0))
	_trace_violette()


## Un éclat de verre bleu, sur un chiffon plié.
func _construire_verre_bleu() -> void:
	var chiffon := BoxMesh.new()
	chiffon.size = Vector3(0.3, 0.02, 0.24)
	_morceau(chiffon, _mat_uni(Color(0.6, 0.5, 0.42), 1.0), Vector3(0, 0.01, 0))
	var bleu := _emissif(Color(0.12, 0.28, 0.9), 1.4)
	bleu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bleu.albedo_color = Color(0.1, 0.24, 0.75, 0.85)
	var eclat := PrismMesh.new()
	eclat.size = Vector3(0.16, 0.12, 0.01)
	_morceau(eclat, bleu, Vector3(0, 0.03, 0), Vector3(-PI / 2, 0.3, 0))


## Un seau de bois cerclé de fer.
func _construire_seau() -> void:
	var bois := _mat_uni(Color(0.46, 0.33, 0.2), 0.9)
	var c := CylinderMesh.new()
	c.top_radius = 0.17
	c.bottom_radius = 0.13
	c.height = 0.32
	_morceau(c, bois, Vector3(0, 0.16, 0))
	for y in [0.06, 0.26]:
		var cercle := TorusMesh.new()
		cercle.inner_radius = 0.14 + y * 0.12
		cercle.outer_radius = 0.16 + y * 0.12
		_morceau(cercle, _mat_uni(Color(0.2, 0.2, 0.22), 0.5, 0.8), Vector3(0, y, 0))


## Le treuil d'une carrière : deux chevalets de chêne, un tambour à manivelles, une corde
## qui descend dans le trou. Coincé : une pierre dans les rayons, une lueur violette.
func _treuil_dans(parent: Node3D, debloque: bool) -> void:
	var bois := _mat_uni(Color(0.4, 0.3, 0.2), 0.9)
	for cote: float in [-1.0, 1.0]:
		for sens: float in [-1.0, 1.0]:
			_baton(0.07, 1.9, bois, Vector3(cote * 0.9, 0.85, sens * 0.35), Vector3(sens * 0.35, 0, 0), parent)
	var tambour := CylinderMesh.new()
	tambour.top_radius = 0.22
	tambour.bottom_radius = 0.22
	tambour.height = 1.7
	_morceau_dans(parent, tambour, bois, Vector3(0, 1.6, 0), Vector3(0, 0, PI / 2))
	var corde := _mat_uni(Color(0.7, 0.62, 0.45), 1.0)
	var enroule := CylinderMesh.new()
	enroule.top_radius = 0.26
	enroule.bottom_radius = 0.26
	enroule.height = 0.9
	_morceau_dans(parent, enroule, corde, Vector3(0, 1.6, 0), Vector3(0, 0, PI / 2))
	for cote: float in [-1.0, 1.0]:
		_baton(0.04, 0.7, bois, Vector3(cote * 1.0, 1.6, 0.3), Vector3(PI / 2, 0, 0), parent)
	# La corde qui part vers le bord du trou (+z), tendue si le treuil marche.
	var brin := _baton(0.025, 3.0, corde, Vector3(0, 1.0 if debloque else 0.9, 1.5), Vector3(PI / 2 - (0.6 if debloque else 0.25), 0, 0), parent)
	brin.name = "Corde"
	if not debloque:
		var cale := BoxMesh.new()
		cale.size = Vector3(0.3, 0.25, 0.35)
		_morceau_dans(parent, cale, _mat_uni(Color(0.78, 0.72, 0.6), 1.0), Vector3(0.45, 1.35, 0.2), Vector3(0.3, 0.2, 0))


func _construire_treuil() -> void:
	_treuil_dans(_visuel, false)
	_trace_violette()
	_debout = Node3D.new()
	_debout.name = "Debloque"
	_debout.visible = false
	add_child(_debout)
	_treuil_dans(_debout, true)


## Des larmes de plomb fondu, figées dans l'herbe : grises, lourdes, qui brillent.
func _construire_larme_plomb() -> void:
	var plomb := _mat_uni(Color(0.5, 0.52, 0.56), 0.25, 0.9)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 5:
		var p := Vector3(hasard.randf_range(-0.3, 0.3), 0.04, hasard.randf_range(-0.3, 0.3))
		var goutte := _boule(0.05, 0.14, plomb, p, Vector3(1.0, 0.6, 1.0))
		goutte.rotation = Vector3(PI / 2, hasard.randf() * TAU, 0)
	var flaque := CylinderMesh.new()
	flaque.top_radius = 0.22
	flaque.bottom_radius = 0.24
	flaque.height = 0.02
	_morceau(flaque, plomb, Vector3(0.1, 0.01, -0.05))
	_trace_violette()


## Le coffret du verrier, sous deux poutres noircies.
func _construire_coffret() -> void:
	var bois := _mat_uni(Color(0.4, 0.27, 0.16), 0.9)
	var coffre := BoxMesh.new()
	coffre.size = Vector3(0.6, 0.32, 0.4)
	_morceau(coffre, bois, Vector3(0, 0.16, 0), Vector3(0, 0.2, 0.08))
	var ferrure := BoxMesh.new()
	ferrure.size = Vector3(0.62, 0.04, 0.42)
	_morceau(ferrure, _mat_uni(Color(0.2, 0.2, 0.22), 0.5, 0.8), Vector3(0, 0.26, 0), Vector3(0, 0.2, 0.08))
	var noir := _mat_uni(Color(0.08, 0.07, 0.06), 1.0)
	for k in 2:
		_baton(0.09, 2.2, noir, Vector3(-0.3 + k * 0.6, 0.35, 0), Vector3(PI / 2 - 0.15, 0.6 - k * 1.1, 0))
	var bleu := _emissif(Color(0.12, 0.28, 0.9), 1.2)
	var eclat := PrismMesh.new()
	eclat.size = Vector3(0.12, 0.1, 0.01)
	_morceau(eclat, bleu, Vector3(0.36, 0.03, 0.22), Vector3(-PI / 2, 0.5, 0))
	_trace_violette()


## Un fumigène moderne : une boîte cylindrique grise, une goupille, de la fumée grise.
func _construire_fumigene() -> void:
	var boite := CylinderMesh.new()
	boite.top_radius = 0.05
	boite.bottom_radius = 0.05
	boite.height = 0.22
	_morceau(boite, _mat_uni(Color(0.42, 0.44, 0.46), 0.4, 0.7), Vector3(0, 0.05, 0), Vector3(PI / 2, 0.4, 0))
	var bande := CylinderMesh.new()
	bande.top_radius = 0.052
	bande.bottom_radius = 0.052
	bande.height = 0.04
	_morceau(bande, _mat_uni(Color(0.85, 0.5, 0.1), 0.6), Vector3(0.03, 0.05, 0.06), Vector3(PI / 2, 0.4, 0))
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color(0.55, 0.55, 0.56, 0.35)
	gris.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gris.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 4:
		var nuage := SphereMesh.new()
		nuage.radius = 0.3 + k * 0.2
		nuage.height = nuage.radius * 1.6
		_morceau(nuage, gris, Vector3(0.1 * k, 0.3 + k * 0.45, -0.08 * k))


## Une fissure de la voûte de la crypte, au bas du mur : une rigole de pierre où coule le plomb
## fondu (orange, lumineux). Bouchée (« Eteint ») : un tas de sable gris qui fume encore.
func _construire_gouttiere_plomb() -> void:
	var pierre := _mat_uni(Color(0.42, 0.39, 0.36), 0.95)
	var plomb := _emissif(Color(1.0, 0.42, 0.1), 2.4)
	var rigole := BoxMesh.new()
	rigole.size = Vector3(0.8, 0.3, 1.2)
	var filet := BoxMesh.new()
	filet.size = Vector3(0.12, 2.4, 0.12)
	var flaque := CylinderMesh.new()
	flaque.top_radius = 0.6
	flaque.bottom_radius = 0.7
	flaque.height = 0.05
	for cible in [_visuel, null]:
		var parent: Node3D = cible
		if parent == null:
			_debout = Node3D.new()
			_debout.name = "Eteint"
			_debout.visible = false
			add_child(_debout)
			parent = _debout
		_morceau_dans(parent, rigole, pierre, Vector3(0, 2.6, -0.2))
	_morceau_dans(_visuel, filet, plomb, Vector3(0, 1.3, 0.2))
	_morceau_dans(_visuel, flaque, plomb, Vector3(0, 0.03, 0.4))
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.45, 0.15)
	lueur.light_energy = 1.4
	lueur.omni_range = 5.0
	lueur.position = Vector3(0, 1.0, 0.6)
	_visuel.add_child(lueur)
	var sable := SphereMesh.new()
	sable.radius = 0.7
	sable.height = 0.7
	_morceau_dans(_debout, sable, _mat_uni(Color(0.62, 0.58, 0.5), 1.0), Vector3(0, 0.15, 0.3), Vector3.ZERO)
	_morceau_dans(_debout, rigole, _mat_uni(Color(0.6, 0.56, 0.48), 1.0), Vector3(0, 2.75, -0.2))
	_fumee_dans(_debout, 0.4, false, 0.4)
	_trace_violette()


## Un vitrail de la salle du lac, dans une niche du mur : éteint, un verre sombre et terne ;
## rallumé (« Eteint », ici la lumière), le bleu et le rouge brillent et éclairent la salle.
func _construire_vitrail_crypte() -> void:
	var pierre := _mat_uni(Color(0.4, 0.37, 0.34), 0.95)
	var cadre := BoxMesh.new()
	cadre.size = Vector3(2.2, 3.6, 0.3)
	var verre := BoxMesh.new()
	verre.size = Vector3(1.6, 3.0, 0.05)
	for cible in [_visuel, null]:
		var parent: Node3D = cible
		if parent == null:
			_debout = Node3D.new()
			_debout.name = "Eteint"
			_debout.visible = false
			add_child(_debout)
			parent = _debout
		_morceau_dans(parent, cadre, pierre, Vector3(0, 2.4, -0.25))
	_morceau_dans(_visuel, verre, _mat_uni(Color(0.08, 0.09, 0.12), 0.3), Vector3(0, 2.4, -0.06))
	var morceau := BoxMesh.new()
	morceau.size = Vector3(0.38, 0.48, 0.05)
	var couleurs := [Color(0.14, 0.3, 1.0), Color(0.9, 0.12, 0.1), Color(0.14, 0.3, 1.0), Color(0.95, 0.75, 0.2)]
	for k in 4:
		for l in 6:
			_morceau_dans(_debout, morceau, _emissif(couleurs[(k + l) % 4], 2.2), Vector3(-0.6 + k * 0.4, 1.15 + l * 0.5, -0.06))
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.45, 0.55, 1.0)
	lumiere.light_energy = 3.0
	lumiere.omni_range = 9.0
	lumiere.position = Vector3(0, 2.4, 1.2)
	_debout.add_child(lumiere)


## Moyen Âge : comme en Chine.
func appliquer_effet(effet: String) -> void:
	super.appliquer_effet(effet)


# --- Quêtes secondaires ---------------------------------------------------------------------

## Un jeune faucon pèlerin tombé du nid : gris ardoise, la poitrine claire rayée, la
## « moustache » noire sous l'œil, accroupi dans les feuilles mortes, une aile un peu ouverte.
func _construire_faucon_tombe() -> void:
	var litiere := CylinderMesh.new()
	litiere.top_radius = 0.35
	litiere.bottom_radius = 0.4
	litiere.height = 0.04
	_morceau(litiere, _mat_uni(Color(0.36, 0.26, 0.16), 1.0), Vector3(0, 0.02, 0))
	var ardoise := _mat_uni(Color(0.32, 0.34, 0.38), 0.85)
	var clair := _mat_uni(Color(0.86, 0.82, 0.72), 0.9)
	var noir := _mat_uni(Color(0.05, 0.05, 0.06), 0.4)
	var jaune := _mat_uni(Color(0.95, 0.78, 0.2), 0.5)
	_boule(0.08, 0.2, ardoise, Vector3(0, 0.14, 0), Vector3(1.0, 1.0, 1.3))
	_boule(0.065, 0.15, clair, Vector3(0, 0.13, -0.05))
	for k in 4:
		_baton(0.004, 0.08, ardoise, Vector3(0, 0.08 + k * 0.025, -0.11), Vector3(0, 0, PI / 2))
	_boule(0.055, 0.1, ardoise, Vector3(0, 0.27, -0.05))
	for c: float in [-1.0, 1.0]:
		_boule(0.014, 0.02, jaune, Vector3(c * 0.03, 0.28, -0.09))
		_boule(0.009, 0.014, noir, Vector3(c * 0.032, 0.28, -0.1))
		_baton(0.006, 0.04, noir, Vector3(c * 0.034, 0.25, -0.09))
	var bec := PrismMesh.new()
	bec.size = Vector3(0.022, 0.03, 0.02)
	_morceau(bec, jaune, Vector3(0, 0.26, -0.11), Vector3(PI * 0.6, 0, 0))
	# L'aile gauche entrouverte, l'autre repliée, la queue rayée.
	var aile := BoxMesh.new()
	aile.size = Vector3(0.22, 0.012, 0.12)
	_morceau(aile, ardoise, Vector3(-0.13, 0.1, 0.02), Vector3(0, 0.3, 0.5))
	var aile2 := BoxMesh.new()
	aile2.size = Vector3(0.04, 0.1, 0.16)
	_morceau(aile2, ardoise, Vector3(0.07, 0.14, 0.03))
	var queue := BoxMesh.new()
	queue.size = Vector3(0.06, 0.01, 0.14)
	_morceau(queue, ardoise, Vector3(0, 0.07, 0.14), Vector3(0.3, 0, 0))


## Le piquet de la fauconnière : un poteau de frêne, un perchoir rembourré, et le gant de
## cuir épais posé dessus, avec sa longe.
func _construire_gant_fauconnier() -> void:
	var bois := _mat_uni(Color(0.5, 0.38, 0.24), 0.9)
	var cuir := _mat_uni(Color(0.58, 0.4, 0.24), 0.75)
	_baton(0.04, 1.3, bois, Vector3(0, 0.65, 0))
	_baton(0.05, 0.5, _mat_uni(Color(0.3, 0.42, 0.26), 0.9), Vector3(0, 1.3, 0), Vector3(0, 0, PI / 2))
	var gant := CapsuleMesh.new()
	gant.radius = 0.07
	gant.height = 0.32
	_morceau(gant, cuir, Vector3(0.12, 1.38, 0), Vector3(0, 0, PI / 2 + 0.2))
	var manchette := CylinderMesh.new()
	manchette.top_radius = 0.09
	manchette.bottom_radius = 0.1
	manchette.height = 0.14
	_morceau(manchette, cuir, Vector3(0.28, 1.4, 0), Vector3(0, 0, PI / 2 + 0.2))
	_baton(0.006, 0.6, _mat_uni(Color(0.7, 0.6, 0.45), 1.0), Vector3(0.02, 1.08, 0.02), Vector3(0.1, 0, 0.15))


## Une jument du Perche échappée : le modèle de cheval de la monture, avec un bout de longe
## cassée qui pend.
func _construire_jument() -> void:
	var fiche: Dictionary = {}
	var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/montures.json"))
	if lu is Dictionary:
		fiche = (lu.get("montures", {}) as Dictionary).get("cheval_perche", {})
	if not fiche.is_empty() and ResourceLoader.exists(String(fiche.get("modele", ""))):
		var cheval := ApparenceMonture.new()
		cheval.reglages = fiche
		cheval.rotation.y = 0.8
		_visuel.add_child(cheval)
	else:
		var robe := _mat_uni(Color(0.62, 0.6, 0.56), 0.8)
		var corps := CapsuleMesh.new()
		corps.radius = 0.4
		corps.height = 1.7
		_morceau(corps, robe, Vector3(0, 1.2, 0), Vector3(PI / 2, 0, 0))
	_baton(0.015, 0.9, _mat_uni(Color(0.7, 0.62, 0.45), 1.0), Vector3(0.0, 0.9, -0.9), Vector3(0.2, 0, 0))


## Une pierre taillée, prête à poser, avec la marque de son tailleur gravée sur une face
## (une étoile, une clé, une croix…) et un peu de poussière de calcaire autour.
func _construire_pierre_marquee() -> void:
	var calcaire := _mat_uni(Color(0.84, 0.8, 0.7), 0.95)
	var bloc := BoxMesh.new()
	bloc.size = Vector3(0.7, 0.42, 0.45)
	_morceau(bloc, calcaire, Vector3(0, 0.21, 0), Vector3(0, 0.25, 0))
	var gravure := _mat_uni(Color(0.42, 0.38, 0.32), 1.0)
	var face := _visuel.get_child(_visuel.get_child_count() - 1) as Node3D
	var hasard := hash(identifiant) % 3
	for k in (5 if hasard == 0 else 2):
		var b := BoxMesh.new()
		b.size = Vector3(0.012, 0.2, 0.01)
		var mi := _morceau_dans(face, b, gravure, Vector3(0, 0, -0.229), Vector3(0, 0, k * (TAU / 5.0 if hasard == 0 else PI / 2)))
		mi.position.y = 0.0
	var poussiere := CylinderMesh.new()
	poussiere.top_radius = 0.5
	poussiere.bottom_radius = 0.55
	poussiere.height = 0.015
	_morceau(poussiere, _mat_uni(Color(0.86, 0.84, 0.78), 1.0), Vector3(0, 0.008, 0))


## L'échiquier du chanoine sur un petit banc de pierre : 64 cases d'ivoire et de corne
## brune, quelques pièces debout.
func _construire_echiquier() -> void:
	var pierre := _mat_uni(Color(0.78, 0.74, 0.66), 0.95)
	var banc := BoxMesh.new()
	banc.size = Vector3(0.7, 0.6, 0.7)
	_morceau(banc, pierre, Vector3(0, 0.3, 0))
	var ivoire := _mat_uni(Color(0.92, 0.88, 0.78), 0.4)
	var corne := _mat_uni(Color(0.32, 0.2, 0.12), 0.4)
	var case_ := BoxMesh.new()
	case_.size = Vector3(0.06, 0.012, 0.06)
	for i in 8:
		for j in 8:
			_morceau(case_, ivoire if (i + j) % 2 == 0 else corne, Vector3(-0.21 + i * 0.06, 0.606, -0.21 + j * 0.06))
	for k in 6:
		var piece := CylinderMesh.new()
		piece.top_radius = 0.008
		piece.bottom_radius = 0.018
		piece.height = 0.05 + (k % 3) * 0.015
		_morceau(piece, ivoire if k < 3 else corne, Vector3(-0.18 + k * 0.07, 0.64, -0.15 if k < 3 else 0.15))


## Un chalumeau moderne oublié dans la cour : une bouteille de gaz orange, un tuyau noir, la
## poignée et la buse de cuivre, une trace violette au sol.
func _construire_chalumeau() -> void:
	var bouteille := CylinderMesh.new()
	bouteille.top_radius = 0.1
	bouteille.bottom_radius = 0.1
	bouteille.height = 0.42
	_morceau(bouteille, _mat_uni(Color(0.9, 0.45, 0.1), 0.4, 0.3), Vector3(0, 0.21, 0))
	_boule(0.1, 0.12, _mat_uni(Color(0.9, 0.45, 0.1), 0.4, 0.3), Vector3(0, 0.42, 0))
	_baton(0.02, 0.06, _mat_uni(Color(0.6, 0.6, 0.62), 0.3, 0.9), Vector3(0, 0.5, 0))
	_baton(0.012, 0.6, _mat_uni(Color(0.05, 0.05, 0.05), 0.6), Vector3(0.22, 0.04, 0.1), Vector3(0, 0.4, PI / 2))
	_baton(0.018, 0.18, _mat_uni(Color(0.1, 0.1, 0.1), 0.6), Vector3(0.52, 0.05, 0.22), Vector3(0, 0.4, PI / 2))
	_baton(0.008, 0.12, _mat_uni(Color(0.72, 0.45, 0.25), 0.3, 0.9), Vector3(0.65, 0.05, 0.28), Vector3(0, 0.4, PI / 2))
	var trace := CylinderMesh.new()
	trace.top_radius = 0.45
	trace.bottom_radius = 0.45
	trace.height = 0.01
	_morceau(trace, _emissif(Color(0.55, 0.2, 0.9), 0.6), Vector3(0.2, 0.005, 0.1))
