@tool
extends Node3D
## Apparence des serpents de l'île d'Égypte, sculptée en code :
## - « cobra » : un cobra fracturé des greniers et des tombes, couché en S, le cou
##   dressé et la coiffe ouverte ;
## - « isfet » : Isfet, le Serpent du Désordre (boss du Cœur de la Pyramide). Un
##   serpent géant de sable et de cristal violet qui sort des murs de la chambre du
##   roi : la queue reste dans la pierre, le corps sort à l'horizontale, puis le cou
##   se dresse à cinq mètres du sol.
##
## Le corps est une chaîne d'anneaux (des sphères étirées) posés chaque image le long
## d'une courbe qui ondule. Quand le combattant a l'effet « enfoui » (il passe d'un mur
## à l'autre), le corps rentre dans la pierre.
##
## Appelé par apparence_loup.gd (même interface : animer, mordre, colorer).

@export var espece := "cobra"

const ANNEAUX := 30

var _anneaux: Array[MeshInstance3D] = []
var _rayons: Array[float] = []
var _cristaux: Array[MeshInstance3D] = []
var _tete: Node3D
var _machoire: Node3D
var _coiffe: MeshInstance3D
var _yeux: Array[MeshInstance3D] = []
var _temps := 0.0
var _morsure := 0.0
var _mort := 0.0
## 0 = sorti du mur, 1 = rentré dans la pierre.
var _enfoui := 0.0
var _mat_cristal: StandardMaterial3D
var _dernier_point := Vector3.INF
## Isfet : de combien la tête tourne vers sa proie (le corps, lui, reste face au mur).
var _regard := 0.0


func _ready() -> void:
	for enfant in get_children():
		enfant.free()
	_anneaux.clear()
	_rayons.clear()
	_cristaux.clear()
	_yeux.clear()
	_construire()
	_poser(0.0)


func _geant() -> bool:
	return espece == "isfet"


## La vipère d'Attique et les serpents de la Gorgone ont la même forme (tête triangulaire, sans coiffe).
func _vipere() -> bool:
	return espece == "vipere" or espece == "gorgone"


# --- Construction --------------------------------------------------------------------------

func _construire() -> void:
	var ecailles := StandardMaterial3D.new()
	var dos := StandardMaterial3D.new()
	if _geant():
		# Du sable compact, ocre, veiné de violet : le désordre a pris forme.
		ecailles.albedo_color = Color(0.74, 0.58, 0.38)
		dos.albedo_color = Color(0.55, 0.4, 0.26)
	elif espece == "gorgone":
		# Les serpents de la chevelure de la Gorgone : du bronze vert-de-gris, comme le bouclier d'Athéna.
		ecailles.albedo_color = Color(0.46, 0.37, 0.2)
		dos.albedo_color = Color(0.3, 0.36, 0.26)
		ecailles.metallic = 0.75
		dos.metallic = 0.6
	elif espece == "vipere":
		# La vipère d'Attique : gris-beige, le dos barré d'un zigzag sombre.
		ecailles.albedo_color = Color(0.62, 0.56, 0.46)
		dos.albedo_color = Color(0.2, 0.17, 0.14)
	else:
		# Le cobra d'Égypte : brun-jaune, la gorge plus claire.
		ecailles.albedo_color = Color(0.6, 0.48, 0.3)
		dos.albedo_color = Color(0.36, 0.27, 0.17)
	for m in [ecailles, dos]:
		m.roughness = 0.75
		m.metallic_specular = 0.6
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.09
	bruit.noise_type = FastNoiseLite.TYPE_CELLULAR
	var motif := NoiseTexture2D.new()
	motif.noise = bruit
	motif.seamless = true
	motif.as_normal_map = true
	motif.bump_strength = 6.0
	for m in [ecailles, dos]:
		m.normal_enabled = true
		m.normal_texture = motif
		m.uv1_scale = Vector3(6, 6, 6)
	_mat_cristal = StandardMaterial3D.new()
	_mat_cristal.albedo_color = Color(0.55, 0.3, 0.95, 0.85)
	_mat_cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cristal.emission_enabled = true
	_mat_cristal.emission = Color(0.6, 0.3, 1.0)
	_mat_cristal.emission_energy_multiplier = 2.2 if _geant() else 1.2
	_mat_cristal.roughness = 0.15
	var sphere := SphereMesh.new()
	sphere.radial_segments = 14
	sphere.rings = 8
	for i in ANNEAUX:
		var s := float(i) / float(ANNEAUX - 1)
		var r := _rayon(s)
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = dos if i % (2 if _vipere() else 4) == 1 else ecailles
		add_child(mi)
		_anneaux.append(mi)
		_rayons.append(r)
		# Des éclats de cristal violet le long de l'échine.
		if _geant() and i % 3 == 0 and i > 2 and i < ANNEAUX - 3:
			var c := MeshInstance3D.new()
			var prisme := CylinderMesh.new()
			prisme.top_radius = 0.0
			prisme.bottom_radius = r * 0.35
			prisme.height = r * (1.4 + 0.5 * (i % 2))
			prisme.radial_segments = 5
			c.mesh = prisme
			c.material_override = _mat_cristal
			add_child(c)
			_cristaux.append(c)
	_construire_tete(ecailles, dos)


## Épaisseur du corps le long de la courbe (0 = bout de la queue, 1 = tête).
func _rayon(s: float) -> float:
	var r := lerpf(0.25, 1.0, smoothstep(0.0, 0.45, s)) * lerpf(1.0, 0.62, smoothstep(0.6, 1.0, s))
	return r * (1.05 if _geant() else 0.11)


func _construire_tete(ecailles: Material, dos: Material) -> void:
	var t := 1.45 if _geant() else 0.13
	_tete = Node3D.new()
	_tete.name = "Tete"
	add_child(_tete)
	# Le crâne : large et plat, avec le museau arrondi devant (vers -Z).
	var crane := MeshInstance3D.new()
	var b := SphereMesh.new()
	b.radius = 0.5
	b.height = 1.0
	crane.mesh = b
	crane.material_override = dos
	crane.scale = Vector3(1.0, 0.55, 1.5) * t
	crane.position = Vector3(0, 0.05, -0.35) * t
	_tete.add_child(crane)
	# La mâchoire du bas, qui s'ouvre pour mordre.
	_machoire = Node3D.new()
	_machoire.position = Vector3(0, -0.1, 0.1) * t
	_tete.add_child(_machoire)
	var bas := MeshInstance3D.new()
	bas.mesh = b
	bas.material_override = ecailles
	bas.scale = Vector3(0.85, 0.3, 1.35) * t
	bas.position = Vector3(0, -0.05, -0.45) * t
	_machoire.add_child(bas)
	# Les crochets, longs et blancs.
	var dent := StandardMaterial3D.new()
	dent.albedo_color = Color(0.95, 0.92, 0.84)
	dent.roughness = 0.3
	for cote in [-1.0, 1.0]:
		var crochet := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.04 * t
		cone.bottom_radius = 0.0
		cone.height = 0.32 * t
		crochet.mesh = cone
		crochet.material_override = dent
		crochet.position = Vector3(cote * 0.2, -0.2, -0.95) * t
		_tete.add_child(crochet)
	# Les yeux : violets et lumineux, comme tout ce que la faille touche.
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = Color(0.7, 0.4, 1.0)
	lueur.emission_enabled = true
	lueur.emission = Color(0.75, 0.4, 1.0)
	lueur.emission_energy_multiplier = 4.0
	for cote in [-1.0, 1.0]:
		var oeil := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.08 * t
		s.height = 0.12 * t
		oeil.mesh = s
		oeil.material_override = lueur
		oeil.position = Vector3(cote * 0.38, 0.16, -0.55) * t
		_tete.add_child(oeil)
		_yeux.append(oeil)
	# La coiffe déployée derrière la tête (le cobra, et Isfet qui l'imite).
	# La vipère n'en a pas : sa tête est triangulaire, plus large à l'arrière.
	_coiffe = MeshInstance3D.new()
	if _vipere():
		crane.scale = Vector3(1.35, 0.55, 1.3) * t
	var disque := SphereMesh.new()
	disque.radius = 0.5
	disque.height = 1.0
	_coiffe.mesh = disque
	_coiffe.material_override = dos
	_coiffe.scale = Vector3(2.3, 1.9, 0.22) * t
	_coiffe.position = Vector3(0, -0.55, 0.5) * t
	_coiffe.rotation.x = -0.25
	_tete.add_child(_coiffe)
	_coiffe.visible = not _vipere()
	if _geant():
		# Une couronne d'éclats sur la coiffe.
		for k in 7:
			var c := MeshInstance3D.new()
			var prisme := CylinderMesh.new()
			prisme.top_radius = 0.0
			prisme.bottom_radius = 0.12
			prisme.height = 0.8 + 0.3 * (k % 2)
			prisme.radial_segments = 5
			c.mesh = prisme
			c.material_override = _mat_cristal
			var a := lerpf(-1.2, 1.2, k / 6.0)
			c.position = Vector3(sin(a) * 1.05, -0.5 + cos(a) * 0.85, 0.55) * t
			c.rotation.z = -a
			c.scale = Vector3.ONE * t
			_tete.add_child(c)
		var lumiere := OmniLight3D.new()
		lumiere.light_color = Color(0.65, 0.35, 1.0)
		lumiere.light_energy = 2.5
		lumiere.omni_range = 9.0
		lumiere.position = Vector3(0, 0.3, -0.6)
		_tete.add_child(lumiere)


# --- La courbe du corps ----------------------------------------------------------------------

## Point de la courbe (repère local, la tête regarde vers -Z), de la queue (0) à la tête (1).
func _point(s: float, t: float) -> Vector3:
	var p: Vector3
	if _geant():
		# Queue dans le mur (derrière, +Z), le corps sort à 1,2 m du sol puis le cou se dresse.
		var sortie := _enfoui * 7.0
		var z := lerpf(9.0, -1.0, s) + sortie
		var cou := smoothstep(0.55, 1.0, s)
		var y := lerpf(1.4, 6.0, cou) - _mort * 4.4 * cou
		y -= sin(s * PI) * 0.4 * (1.0 - cou)
		z += cou * cou * 1.4 - _morsure * 2.2 * cou * cou
		var ondule := sin(s * 9.0 - t * 2.2) * 0.55 * smoothstep(0.1, 0.5, s) * (1.0 - cou * 0.6)
		p = Vector3(ondule, y, z)
	else:
		# Couché en S, puis le tiers avant se dresse.
		var cou := smoothstep(0.62, 0.95, s)
		var x := sin(s * 7.5 - t * 1.6) * 0.14 * (1.0 - cou)
		var z := lerpf(0.9, -0.15, s) + cou * 0.15 - _morsure * 0.35 * cou
		# La vipère reste presque à plat, la tête à peine levée.
		var y := 0.06 + cou * (0.18 if _vipere() else 0.55) * (1.0 - _mort)
		p = Vector3(x, y, z)
	return p


func _poser(t: float) -> void:
	var pas := 1.0 / float(ANNEAUX - 1)
	var k := 0
	for i in ANNEAUX:
		var s := float(i) * pas
		var a := _point(s, t)
		var b := _point(minf(s + pas, 1.0), t) if i < ANNEAUX - 1 else a + (a - _point(s - pas, t))
		var dir := b - a
		var longueur := maxf(dir.length(), 0.001)
		dir /= longueur
		var haut := Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK
		var base := Basis.looking_at(dir, haut)
		var r := _rayons[i]
		var anneau := _anneaux[i]
		anneau.transform = Transform3D(base.scaled(Vector3(r, r * 0.9, maxf(longueur * 0.85, r))), a)
		# Les anneaux encore dans le mur ne se voient pas (et ne jettent pas d'ombre dans la salle).
		anneau.visible = not _geant() or a.z < 3.6
		if _geant() and i % 3 == 0 and i > 2 and i < ANNEAUX - 3 and k < _cristaux.size():
			var c := _cristaux[k]
			c.position = a + base.y * r * 0.85
			c.basis = base * Basis(Vector3.RIGHT, -0.5 + 0.2 * sin(i))
			c.visible = anneau.visible
			k += 1
	if _tete != null:
		var bout := _point(1.0, t)
		var avant := _point(1.0 - pas, t)
		var dir := (bout - avant).normalized()
		# La tête regarde devant elle, un peu vers le bas (vers sa proie).
		var vise := Vector3(dir.x * 0.3, -0.25 if not _geant() else -0.35, -1.0).normalized()
		_tete.transform = Transform3D(Basis(Vector3.UP, _regard) * Basis.looking_at(vise, Vector3.UP), bout)
		_tete.visible = not _geant() or bout.z < 3.6


# --- Animation -------------------------------------------------------------------------------

func colorer(allie: bool) -> void:
	if not allie:
		return
	var lueur := StandardMaterial3D.new()
	lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lueur.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lueur.albedo_color = Color(0.1, 0.35, 0.45)
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = lueur


func mordre() -> void:
	_morsure = 0.5


func animer(delta: float, _vitesse: float, mort: bool) -> void:
	_temps += delta
	_morsure = maxf(0.0, _morsure - delta * 1.6)
	_mort = move_toward(_mort, 1.0 if mort else 0.0, delta * 0.8)
	# Passe-muraille : il rentre dans la pierre quand il a l'effet « enfoui ».
	var parent := get_parent().get_parent() if get_parent() != null else null
	var combat = parent.get_node_or_null("Combat") if parent != null else null
	var enfoui: bool = combat != null and combat.has_method("a_effet") and combat.a_effet("enfoui")
	_enfoui = move_toward(_enfoui, 1.0 if enfoui else 0.0, delta * 1.1)
	# Il vient de changer de mur : il ressort de la pierre.
	if parent != null and parent is Node3D:
		var ici := (parent as Node3D).global_position
		if _dernier_point != Vector3.INF and ici.distance_to(_dernier_point) > 4.0:
			_enfoui = 1.0
		_dernier_point = ici
		# Le corps reste perpendiculaire au mur d'où il sort ; seule la tête suit sa proie.
		var ile := get_tree().get_first_node_in_group("ile") if is_inside_tree() else null
		if _geant() and ile != null and ile.has_method("lacet_mur"):
			var mur: float = ile.lacet_mur(ici)
			global_rotation.y = mur
			_regard = clampf(wrapf((parent as Node3D).global_rotation.y - mur, -PI, PI), -1.0, 1.0)
	if _machoire != null:
		_machoire.rotation.x = lerpf(_machoire.rotation.x, 0.55 if _morsure > 0.15 else 0.05, 0.3)
	if _coiffe != null:
		_coiffe.scale.x = (2.3 + 0.08 * sin(_temps * 3.0)) * (1.45 if _geant() else 0.13)
	if _mat_cristal != null:
		_mat_cristal.emission_energy_multiplier = (2.2 if _geant() else 1.2) * (1.0 - _mort * 0.85) \
				* (0.85 + 0.15 * sin(_temps * 7.0))
	_poser(_temps)
