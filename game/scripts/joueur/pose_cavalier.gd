extends SkeletonModifier3D
## Assoit le personnage (squelette Mixamo) sur sa monture : cuisses vers l'avant
## et écartées, genoux pliés, mains en avant comme pour tenir les rênes.
## S'applique par-dessus l'animation de repos (le haut du corps respire encore).

## Angles en degrés (réglables).
var flexion_hanches := 78.0
var ecart_jambes := 24.0
var pli_genoux := 92.0
var bras_en_avant := 38.0
var pli_coudes := 62.0
var ecart_bras := 8.0

var _os := {}
var _cote_gauche := 1.0


func _ready() -> void:
	var s := get_skeleton()
	if s == null:
		return
	for nom in ["LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftArm", "LeftForeArm",
			"RightArm", "RightForeArm", "Hips"]:
		_os[nom] = _trouver(s, nom)
	# Côté gauche du personnage dans le repère du squelette (+X ou -X).
	if _os["LeftUpLeg"] >= 0:
		_cote_gauche = signf(s.get_bone_global_rest(_os["LeftUpLeg"]).origin.x)
		if _cote_gauche == 0.0:
			_cote_gauche = 1.0


static func _trouver(s: Skeleton3D, fin: String) -> int:
	for i in s.get_bone_count():
		var n := s.get_bone_name(i)
		if n == fin or n.ends_with("_" + fin) or n.ends_with(":" + fin):
			return i
	return -1


## Position des hanches (repère du squelette), pour poser le personnage sur la selle.
func hanches() -> Vector3:
	var s := get_skeleton()
	if s == null or int(_os.get("Hips", -1)) < 0:
		return Vector3(0, 0.95, 0)
	return s.get_bone_global_pose(_os["Hips"]).origin


func _process_modification() -> void:
	var s := get_skeleton()
	if s == null or _os.is_empty():
		return
	for cote in ["Left", "Right"]:
		var signe := _cote_gauche if cote == "Left" else -_cote_gauche
		# Jambes : le personnage regarde vers +Z dans son squelette.
		var r_cuisse := Basis(Vector3(0, 0, 1), deg_to_rad(ecart_jambes) * signe) * Basis(Vector3.RIGHT, deg_to_rad(-flexion_hanches))
		var r_tibia := Basis(Vector3(0, 0, 1), deg_to_rad(ecart_jambes * 0.35) * signe) \
				* Basis(Vector3.RIGHT, deg_to_rad(-flexion_hanches + pli_genoux))
		_plier(s, _os[cote + "UpLeg"], _os[cote + "Leg"], r_cuisse, r_tibia)
		# Bras : vers l'avant, coudes pliés.
		var r_bras := Basis(Vector3(0, 0, 1), deg_to_rad(-ecart_bras) * signe) * Basis(Vector3.RIGHT, deg_to_rad(-bras_en_avant))
		var r_avant_bras := Basis(Vector3.RIGHT, deg_to_rad(-bras_en_avant - pli_coudes))
		_plier(s, _os[cote + "Arm"], _os[cote + "ForeArm"], r_bras, r_avant_bras)


## Tourne un membre (os du haut + os du bas) dans le repère du squelette.
## relatif = vrai : la rotation s'ajoute à la pose actuelle au lieu de partir d'un membre vertical.
func _plier(s: Skeleton3D, haut: int, bas: int, r_haut: Basis, r_bas: Basis, relatif := false) -> void:
	if haut < 0 or bas < 0:
		return
	var g_haut := s.get_bone_global_pose(haut)
	var g_bas := s.get_bone_global_pose(bas)
	# On part d'un membre qui pend tout droit, pour obtenir la même pose quelle
	# que soit l'animation de repos.
	var redresse_haut := Basis.IDENTITY if relatif else _vers_le_bas(g_haut, g_bas.origin)
	var nouveau_haut := Transform3D(r_haut * redresse_haut * g_haut.basis, g_haut.origin)
	var genou := g_haut.origin + r_haut * redresse_haut * (g_bas.origin - g_haut.origin)
	var enfant := _premier_enfant(s, bas)
	var bout := s.get_bone_global_pose(enfant).origin if enfant >= 0 else g_bas.origin + (g_bas.origin - g_haut.origin)
	var redresse_bas := Basis.IDENTITY if relatif else _vers_le_bas(g_bas, bout)
	var nouveau_bas := Transform3D(r_bas * redresse_bas * g_bas.basis, genou)
	s.set_bone_global_pose(haut, nouveau_haut)
	s.set_bone_global_pose(bas, nouveau_bas)


## Rotation qui fait pendre l'os (de son origine vers « bout ») tout droit vers le bas.
static func _vers_le_bas(g: Transform3D, bout: Vector3) -> Basis:
	var d := bout - g.origin
	if d.length() < 0.0001:
		return Basis.IDENTITY
	d = d.normalized()
	var axe := d.cross(Vector3.DOWN)
	if axe.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axe.normalized(), d.angle_to(Vector3.DOWN))


static func _premier_enfant(s: Skeleton3D, os: int) -> int:
	var enfants := s.get_bone_children(os)
	return enfants[0] if enfants.size() > 0 else -1
