@tool
extends Node3D
## Silhouette provisoire du personnage, construite avec des formes simples.
##
## Elle sert en attendant le vrai personnage MakeHuman animé avec Mixamo
## (voir docs/guides/personnage-makehuman-mixamo.md). Elle suit déjà tous les
## choix de l'écran de création : sexe, taille, corpulence, visage (curseurs),
## peau, yeux, coiffure, barbe, tenue et arme de la classe.
## Les membres sont animés par le code : balancement des bras et des jambes,
## saut, roulade.

const HAUTEUR_HANCHES := 0.95
## Taille de référence (cm) : à cette taille, la silhouette n'est pas agrandie.
const TAILLE_REFERENCE := 180.0

## Apparence utilisée tant qu'aucune fiche n'a été appliquée (voir FichePersonnage.resoudre).
const APPARENCE_PAR_DEFAUT := {
	"sexe": "homme", "taille_cm": 180.0, "corpulence": 0.0, "musculature": 0.0, "visage": {},
	"peau": Color(0.80, 0.62, 0.50), "yeux": Color(0.3, 0.2, 0.1), "cheveux": Color(0.18, 0.11, 0.07),
	"coiffure": "courte", "pilosite": "aucune",
	"veste": Color(0.15, 0.19, 0.26), "pantalon": Color(0.11, 0.11, 0.13),
	"insigne": Color(0.25, 0.85, 0.9), "manteau": false, "arme": "epee",
}

var _apparence: Dictionary = APPARENCE_PAR_DEFAUT
var _racine: Node3D
var _centre: Node3D
var _buste: Node3D
var _tete: Node3D
var _hanche_g: Node3D
var _hanche_d: Node3D
var _epaule_g: Node3D
var _epaule_d: Node3D
var _phase := 0.0
var _temps := 0.0
var _attaque := 0.0


func _ready() -> void:
	_reconstruire()


## Change l'apparence (dictionnaire produit par FichePersonnage.resoudre).
func appliquer(apparence: Dictionary) -> void:
	_apparence = APPARENCE_PAR_DEFAUT.duplicate()
	_apparence.merge(apparence, true)
	if is_inside_tree():
		_reconstruire()


## Position du visage dans le monde (pour que la caméra de l'écran de création le cadre).
func position_visage() -> Vector3:
	return _tete.global_position if _tete != null else global_position + Vector3(0, 1.65, 0)


func _reconstruire() -> void:
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_construire()


func _materiau(couleur: Color, rugosite := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	return m


func _forme(parent: Node3D, maillage: Mesh, materiau: Material, position_locale: Vector3,
		echelle := Vector3.ONE, rotation_locale := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = maillage
	instance.material_override = materiau
	instance.position = position_locale
	instance.rotation = rotation_locale
	instance.scale = echelle
	parent.add_child(instance)
	return instance


func _capsule(rayon: float, hauteur: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = rayon
	c.height = maxf(hauteur, rayon * 2.0)
	return c


func _sphere(rayon: float, hauteur := -1.0, demi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0 if hauteur < 0.0 else hauteur
	s.is_hemisphere = demi
	if demi:
		s.height = s.height / 2.0
	return s


func _boite(taille: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = taille
	return b


func _cylindre(rayon: float, hauteur: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = hauteur
	return c


func _articulation(parent: Node3D, position_locale: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = position_locale
	parent.add_child(n)
	return n


## Valeur d'un curseur du visage (de -1 à 1).
func _v(id: String) -> float:
	return float(_apparence.get("visage", {}).get(id, 0.0))


func _construire() -> void:
	var a := _apparence
	var femme: bool = a["sexe"] == "femme"
	var corp := float(a["corpulence"])
	var musc := float(a["musculature"])
	var peau := _materiau(a["peau"], 0.6)
	var veste := _materiau(a["veste"])
	var pantalon := _materiau(a["pantalon"])
	var insigne := _materiau(a["insigne"], 0.3)
	insigne.emission_enabled = true
	insigne.emission = a["insigne"]
	insigne.emission_energy_multiplier = 2.0
	var sombre := _materiau(Color(0.05, 0.05, 0.06), 0.3)

	# Toute la silhouette est agrandie ou réduite selon la taille choisie.
	_racine = _articulation(self, Vector3.ZERO)
	_racine.scale = Vector3.ONE * clampf(float(a["taille_cm"]) / TAILLE_REFERENCE, 0.7, 1.3)

	# Le « centre » est au niveau des hanches : c'est autour de lui qu'on fait la roulade.
	_centre = _articulation(_racine, Vector3(0, HAUTEUR_HANCHES, 0))
	_buste = _articulation(_centre, Vector3.ZERO)

	var largeur_torse := (1.0 if femme else 1.15) * (1.0 + 0.15 * corp + 0.06 * musc)
	var profondeur_torse := 0.75 * (1.0 + 0.2 * corp + 0.05 * musc)
	_forme(_buste, _capsule(0.2, 0.7), veste, Vector3(0, 0.33, 0),
			Vector3(largeur_torse, 1.0, profondeur_torse))
	if a["manteau"]:
		# Pans du manteau de la tenue urbaine.
		_forme(_centre, _capsule(0.2, 0.75), veste, Vector3(0, -0.12, 0.01),
				Vector3(largeur_torse * 1.05, 1.0, profondeur_torse * 1.1))
	_forme(_buste, _capsule(0.047 if femme else 0.055, 0.2), peau, Vector3(0, 0.68, 0))
	var badge := _boite(Vector3(0.07, 0.07, 0.02))
	_forme(_buste, badge, insigne, Vector3(0.09, 0.47, -0.155 * profondeur_torse / 0.75))

	_tete = _articulation(_buste, Vector3(0, 0.82, 0))
	_tete.scale = Vector3.ONE * (0.95 if femme else 1.0)
	_construire_visage(_tete, peau)

	var ecart_epaules := (0.24 if femme else 0.27) * (1.0 + 0.05 * corp + 0.06 * musc)
	var rayon_bras := (0.052 if femme else 0.06) * (1.0 + 0.15 * corp + 0.2 * musc)
	_epaule_g = _articulation(_buste, Vector3(-ecart_epaules, 0.57, 0))
	_epaule_d = _articulation(_buste, Vector3(ecart_epaules, 0.57, 0))
	for epaule in [_epaule_g, _epaule_d]:
		_forme(epaule, _capsule(rayon_bras, 0.62), veste, Vector3(0, -0.29, 0))
		_forme(epaule, _sphere(0.05 if femme else 0.055), peau, Vector3(0, -0.62, 0))
	_construire_arme(String(a["arme"]), sombre, insigne, veste)

	var ecart_hanches := (0.11 if femme else 0.1) * (1.0 + 0.1 * corp)
	var rayon_jambe := (0.09 if femme else 0.085) * (1.0 + 0.2 * corp + 0.1 * musc)
	_hanche_g = _articulation(_centre, Vector3(-ecart_hanches, 0, 0))
	_hanche_d = _articulation(_centre, Vector3(ecart_hanches, 0, 0))
	for hanche in [_hanche_g, _hanche_d]:
		_forme(hanche, _capsule(rayon_jambe, 0.9), pantalon, Vector3(0, -0.45, 0))
		_forme(hanche, _boite(Vector3(0.12, 0.08, 0.26)), sombre, Vector3(0, -0.91, -0.05))


## Le visage : chaque curseur de l'écran de création déplace ou grossit une forme.
## (Avec le vrai modèle MakeHuman, ce seront des « shape keys », voir data/creation_personnage.json.)
func _construire_visage(tete: Node3D, peau: StandardMaterial3D) -> void:
	var a := _apparence
	var couleur_peau: Color = a["peau"]
	var largeur := 1.0 + 0.1 * _v("largeur_visage")
	var longueur := 1.0 + 0.08 * _v("longueur_visage")

	# Crâne (le visage regarde vers -Z).
	_forme(tete, _sphere(0.1, 0.24), peau, Vector3.ZERO, Vector3(0.8 * largeur, longueur, 0.95))
	# Mâchoire et menton.
	var machoire := 1.0 + 0.25 * _v("machoire")
	_forme(tete, _sphere(0.07, 0.1), peau, Vector3(0, -0.06 * longueur, -0.02),
			Vector3(0.95 * machoire * largeur, longueur, 1.0))
	_forme(tete, _sphere(0.022), peau,
			Vector3(0, (-0.095 - 0.008 * _v("longueur_visage")), -0.075 - 0.012 * _v("menton")),
			Vector3(1.0 + 0.3 * _v("machoire"), 0.8, 0.8))
	# Pommettes et oreilles.
	for s in [-1.0, 1.0]:
		var pommette := 1.0 + 0.35 * _v("pommettes")
		_forme(tete, _sphere(0.016), peau, Vector3(s * 0.043 * largeur, -0.014, -0.068 - 0.006 * _v("pommettes")),
				Vector3(1.1, 0.7, 0.8) * pommette)
		var oreille := 1.0 + 0.3 * _v("taille_oreilles")
		_forme(tete, _sphere(0.028), peau, Vector3(s * 0.082 * largeur, 0.0, 0.005),
				Vector3(0.35, 1.0, 0.65) * oreille)

	# Yeux : blanc + iris de la couleur choisie, dans un « œil » qu'on peut incliner.
	var blanc := _materiau(Color(0.93, 0.92, 0.9), 0.3)
	var iris := _materiau(a["yeux"], 0.2)
	var hauteur_yeux := 0.01 + 0.01 * _v("hauteur_yeux")
	var taille_yeux := 1.0 + 0.22 * _v("taille_yeux")
	for s in [-1.0, 1.0]:
		var oeil := _articulation(tete, Vector3(s * 0.032 * (1.0 + 0.15 * _v("ecart_yeux")) * largeur,
				hauteur_yeux, -0.081))
		oeil.rotation.z = s * 0.18 * _v("inclinaison_yeux")
		_forme(oeil, _sphere(0.013), blanc, Vector3.ZERO, Vector3(1.25, 0.8, 0.7) * taille_yeux)
		_forme(oeil, _sphere(0.0072), iris, Vector3(0, 0, -0.0075 * taille_yeux), Vector3(1, 1, 0.6) * taille_yeux)

	# Sourcils (de la couleur des cheveux).
	var poils := _materiau(a["cheveux"], 0.9)
	for s in [-1.0, 1.0]:
		_forme(tete, _boite(Vector3(0.032, 0.005 * (1.0 + 0.8 * _v("epaisseur_sourcils")), 0.01)), poils,
				Vector3(s * 0.034 * (1.0 + 0.1 * _v("ecart_yeux")) * largeur,
						hauteur_yeux + 0.022 + 0.01 * _v("hauteur_sourcils"), -0.086),
				Vector3.ONE, Vector3(0, 0, -s * 0.12))

	# Nez : l'arête puis le bout.
	var long_nez := _v("longueur_nez")
	var larg_nez := _v("largeur_nez")
	var bosse := _v("bosse_nez")
	_forme(tete, _boite(Vector3(0.014 * (1.0 + 0.4 * larg_nez), 0.05 * (1.0 + 0.25 * long_nez), 0.02)), peau,
			Vector3(0, -0.012 - 0.005 * long_nez, -0.096 - 0.004 * bosse), Vector3.ONE,
			Vector3(0.25 + 0.12 * bosse, 0, 0))
	_forme(tete, _sphere(0.012), peau,
			Vector3(0, -0.038 - 0.012 * long_nez + 0.004 * maxf(-bosse, 0.0), -0.104 - 0.006 * long_nez),
			Vector3(1.3 + 0.4 * larg_nez, 1.0, 1.0))

	# Bouche.
	var levres := _materiau(couleur_peau.darkened(0.15).lerp(Color(0.6, 0.25, 0.25), 0.3), 0.5)
	var larg_bouche := 1.0 + 0.3 * _v("largeur_bouche")
	var epaisseur := 1.0 + 0.6 * _v("epaisseur_levres")
	var y_bouche := -0.062 * longueur
	_forme(tete, _boite(Vector3(0.04 * larg_bouche, 0.006 * epaisseur, 0.012)), levres,
			Vector3(0, y_bouche + 0.004, -0.091))
	_forme(tete, _boite(Vector3(0.036 * larg_bouche, 0.007 * epaisseur, 0.012)), levres,
			Vector3(0, y_bouche - 0.0045, -0.09))

	_construire_cheveux(tete, poils, largeur, longueur)
	_construire_barbe(tete, poils, y_bouche)


func _construire_cheveux(tete: Node3D, poils: StandardMaterial3D, largeur: float, longueur: float) -> void:
	var coiffure := String(_apparence["coiffure"])
	var volume: float = {"rase": 1.006, "tres_courte": 1.035, "queue": 1.035, "tresse": 1.035, "courte_2": 1.11, "afro": 1.3}.get(coiffure, 1.08)
	var calotte_mat := poils
	if coiffure == "rase":
		# Crâne rasé : juste une ombre de cheveux sur la peau.
		calotte_mat = _materiau((_apparence["peau"] as Color).lerp(_apparence["cheveux"], 0.3), 0.7)
	# Calotte : une demi-sphère inclinée (plus basse derrière que devant).
	_forme(tete, _sphere(0.1, 0.24, true), calotte_mat, Vector3(0, 0.018, 0.006),
			Vector3(0.8 * largeur, longueur * (1.08 if volume > 1.05 else 1.0), 0.95) * volume,
			Vector3(0.35, 0, 0))
	match coiffure:
		"mi_longue":
			_forme(tete, _capsule(0.07, 0.2), poils, Vector3(0, -0.05, 0.035), Vector3(1.15 * largeur, 1.0, 0.75))
			for s in [-1.0, 1.0]:
				_forme(tete, _capsule(0.026, 0.15), poils, Vector3(s * 0.075 * largeur, -0.035, -0.01))
		"longue":
			_forme(tete, _capsule(0.08, 0.44), poils, Vector3(0, -0.14, 0.05), Vector3(1.05 * largeur, 1.0, 0.55))
			for s in [-1.0, 1.0]:
				_forme(tete, _capsule(0.026, 0.26), poils, Vector3(s * 0.076 * largeur, -0.085, -0.012))
		"queue":
			_forme(tete, _sphere(0.022), poils, Vector3(0, 0.03, 0.098))
			_forme(tete, _capsule(0.026, 0.26), poils, Vector3(0, -0.085, 0.125), Vector3.ONE, Vector3(-0.2, 0, 0))
		"tresse":
			_forme(tete, _capsule(0.022, 0.4), poils, Vector3(0, -0.15, 0.11), Vector3.ONE, Vector3(-0.15, 0, 0))
		"carre":
			_forme(tete, _capsule(0.075, 0.16), poils, Vector3(0, -0.03, 0.02), Vector3(1.25 * largeur, 1.0, 0.95))


func _construire_barbe(tete: Node3D, poils: StandardMaterial3D, y_bouche: float) -> void:
	var pilosite := String(_apparence["pilosite"])
	if pilosite == "aucune":
		return
	var mat := poils
	if pilosite == "trois_jours":
		mat = _materiau((_apparence["peau"] as Color).lerp(_apparence["cheveux"], 0.5), 0.9)
	var barbe := pilosite in ["trois_jours", "barbe_courte", "barbe_longue"]
	var grosse := 1.0 if pilosite == "trois_jours" else 1.15
	if barbe or pilosite == "bouc":
		_forme(tete, _sphere(0.024), mat, Vector3(0, -0.09, -0.066), Vector3(1.3, 0.8, 0.8) * grosse)
	if barbe:
		for s in [-1.0, 1.0]:
			_forme(tete, _capsule(0.014 * grosse, 0.085), mat, Vector3(s * 0.05, -0.06, -0.04),
					Vector3.ONE, Vector3(0.3, 0, s * 0.5))
	if pilosite in ["barbe_courte", "barbe_longue", "moustache", "bouc"]:
		_forme(tete, _boite(Vector3(0.046, 0.009, 0.012)), mat, Vector3(0, y_bouche + 0.013, -0.093))
	if pilosite == "barbe_longue":
		_forme(tete, _capsule(0.035, 0.13), mat, Vector3(0, -0.13, -0.065), Vector3(1.1, 1.0, 0.8), Vector3(0.2, 0, 0))


## L'arme dépend de la classe choisie.
func _construire_arme(arme: String, sombre: Material, insigne: Material, tissu: Material) -> void:
	var metal := _materiau(Color(0.75, 0.78, 0.82), 0.25)
	metal.metallic = 0.9
	var bois := _materiau(Color(0.36, 0.24, 0.14), 0.7)
	match arme:
		"epee_bouclier":
			# Rempart : épée courte à droite, bouclier rond sur le bras gauche.
			_forme(_epaule_d, _boite(Vector3(0.025, 0.06, 0.6)), metal, Vector3(0, -0.64, -0.37))
			_forme(_epaule_d, _boite(Vector3(0.16, 0.03, 0.04)), sombre, Vector3(0, -0.64, -0.07))
			_forme(_epaule_g, _cylindre(0.28, 0.04), metal, Vector3(-0.07, -0.42, -0.05), Vector3.ONE,
					Vector3(0, 0, PI / 2.0))
			_forme(_epaule_g, _cylindre(0.24, 0.045), tissu, Vector3(-0.072, -0.42, -0.05), Vector3.ONE,
					Vector3(0, 0, PI / 2.0))
			_forme(_epaule_g, _cylindre(0.05, 0.05), insigne, Vector3(-0.075, -0.42, -0.05), Vector3.ONE,
					Vector3(0, 0, PI / 2.0))
		"arc":
			# Traqueur : un arc dans la main gauche.
			var arc := _articulation(_epaule_g, Vector3(0, -0.62, -0.04))
			_forme(arc, _boite(Vector3(0.03, 0.16, 0.035)), sombre, Vector3.ZERO)
			for s in [-1.0, 1.0]:
				_forme(arc, _boite(Vector3(0.022, 0.55, 0.025)), bois, Vector3(0, s * 0.33, 0.06),
						Vector3.ONE, Vector3(s * 0.35, 0, 0))
			_forme(arc, _boite(Vector3(0.004, 1.12, 0.004)), _materiau(Color(0.85, 0.85, 0.8)), Vector3(0, 0, 0.17))
		"baton":
			# Tisseur : un bâton surmonté d'un cristal temporel.
			_forme(_epaule_d, _cylindre(0.018, 1.7), bois, Vector3(0, -0.55, -0.08))
			_forme(_epaule_d, _sphere(0.055), insigne, Vector3(0, 0.33, -0.08))
		_:
			# Lame : une épée dans la main droite.
			_forme(_epaule_d, _boite(Vector3(0.025, 0.07, 0.85)), metal, Vector3(0, -0.64, -0.5))
			_forme(_epaule_d, _boite(Vector3(0.18, 0.03, 0.04)), sombre, Vector3(0, -0.64, -0.07))


## Joue un coup d'épée.
func attaquer() -> void:
	_attaque = 0.35


## Appelée par le Joueur à chaque image physique.
## vitesse_locale : vitesse dans le repère du personnage (-Z = devant).
## progression_esquive : -1 hors roulade, sinon de 0 à 1.
func animer(delta: float, vitesse_locale: Vector3, au_sol: bool, progression_esquive: float,
		direction_esquive: Vector3) -> void:
	if _centre == null:
		return
	_temps += delta
	var vitesse := vitesse_locale.length()
	var allure := clampf(vitesse / 7.0, 0.0, 1.0)
	# On avance la « phase » du pas selon la vitesse (en marche arrière, elle recule).
	var sens := -1.0 if vitesse_locale.z > 0.1 else 1.0
	_phase += delta * (2.0 + vitesse * 1.5) * sens

	var balancement := sin(_phase) * 0.75 * allure
	var jambe_g := balancement
	var jambe_d := -balancement
	var bras_g := -balancement * 0.8
	var bras_d := balancement * 0.8
	var respiration := sin(_temps * 2.0) * 0.015 * (1.0 - allure)

	if not au_sol:
		jambe_g = -0.5
		jambe_d = 0.2
		bras_g = -0.6
		bras_d = -0.6

	# Pas de côté : on écarte un peu les jambes au lieu de les balancer d'avant en arrière.
	var cote := clampf(vitesse_locale.x / 7.0, -1.0, 1.0)
	_hanche_g.rotation = Vector3(-jambe_g * (1.0 - absf(cote) * 0.6), 0, sin(_phase) * 0.25 * cote)
	_hanche_d.rotation = Vector3(-jambe_d * (1.0 - absf(cote) * 0.6), 0, -sin(_phase) * 0.25 * cote)
	_epaule_g.rotation = Vector3(-bras_g, 0, -0.08)
	_epaule_d.rotation = Vector3(-bras_d, 0, 0.08)
	if _attaque > 0.0:
		# Coup d'épée : le bras droit se lève puis frappe en diagonale.
		_attaque = maxf(0.0, _attaque - delta)
		var t := 1.0 - _attaque / 0.35
		_epaule_d.rotation = Vector3(lerpf(2.6, 0.6, t), lerpf(-0.3, 0.6, t), 0.3)
	# Penché légèrement vers l'avant quand on court.
	_buste.rotation = Vector3(-0.12 * allure * (1.0 if sens > 0.0 else -0.5), 0, 0)
	_buste.scale = Vector3(1.0, 1.0 + respiration, 1.0)

	if progression_esquive >= 0.0:
		# Roulade : le corps se recroqueville et fait un tour complet dans la direction de l'esquive.
		var d := Vector3(direction_esquive.x, 0.0, direction_esquive.z).normalized()
		if d == Vector3.ZERO:
			d = Vector3.FORWARD
		var axe := Vector3.UP.cross(d).normalized()
		_centre.transform.basis = Basis(axe, TAU * progression_esquive)
		_centre.position = Vector3(0, HAUTEUR_HANCHES - 0.45 * sin(PI * progression_esquive), 0)
		_hanche_g.rotation = Vector3(1.4, 0, 0)
		_hanche_d.rotation = Vector3(1.4, 0, 0)
		_epaule_g.rotation = Vector3(1.2, 0, 0)
		_epaule_d.rotation = Vector3(1.2, 0, 0)
	else:
		_centre.transform.basis = Basis.IDENTITY
		_centre.position = Vector3(0, HAUTEUR_HANCHES + absf(sin(_phase)) * 0.04 * allure, 0)
