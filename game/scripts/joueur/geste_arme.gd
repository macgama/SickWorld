extends SkeletonModifier3D
## Geste pour ranger ou sortir son arme : le bras va chercher l'arme dans le dos
## (par-dessus l'épaule) ou à la ceinture, puis revient.
##
## Le geste est calculé (pas d'animation Mixamo) et ne touche que les bras : on peut
## donc ranger son arme en courant. L'ampleur du geste suit « influence » (0 à 1),
## réglée à chaque image par apparence_agent.gd.
##
## Les directions sont données dans le repère du corps : x = vers la droite du
## personnage, y = vers le haut, z = vers l'avant.

## Direction du bras puis de l'avant-bras pour attraper une arme dans le dos (bras droit).
const DOS := [Vector3(0.35, 0.8, 0.3), Vector3(-0.3, 0.45, -0.85)]
## Même chose pour une arme à la ceinture (bras droit).
const HANCHE := [Vector3(0.35, -0.85, -0.25), Vector3(0.05, -0.75, -0.65)]

## Bras qui bougent : « droit » et/ou « gauche » -> « dos » ou « hanche ».
var bras := {}

var _repere := Basis.IDENTITY
var _pret := false


func preparer(squelette: Skeleton3D) -> void:
	_repere = preload("res://scripts/objets/visuel_equipement.gd").repere_corps(squelette)
	_pret = true


func _process_modification() -> void:
	var squelette := get_skeleton()
	if squelette == null or not _pret or bras.is_empty():
		return
	for cote: String in bras:
		var cible: Array = DOS if bras[cote] == "dos" else HANCHE
		var nom := "Right" if cote == "droit" else "Left"
		var miroir := 1.0 if cote == "droit" else -1.0
		var i_bras := squelette.find_bone("mixamorig_%sArm" % nom)
		var i_avant := squelette.find_bone("mixamorig_%sForeArm" % nom)
		var i_main := squelette.find_bone("mixamorig_%sHand" % nom)
		if i_bras < 0 or i_avant < 0 or i_main < 0:
			continue
		_orienter(squelette, i_bras, i_avant, _vers_squelette(cible[0], miroir))
		_orienter(squelette, i_avant, i_main, _vers_squelette(cible[1], miroir))


func _vers_squelette(direction: Vector3, miroir: float) -> Vector3:
	return (_repere * Vector3(direction.x * miroir, direction.y, direction.z)).normalized()


## Tourne l'os « os » pour que l'os « enfant » soit dans la direction voulue.
func _orienter(squelette: Skeleton3D, os: int, enfant: int, voulu: Vector3) -> void:
	var g := squelette.get_bone_global_pose(os)
	var actuel := squelette.get_bone_global_pose(enfant).origin - g.origin
	if actuel.length() < 0.0001:
		return
	var tour := Quaternion(actuel.normalized(), voulu)
	var nouvelle := Basis(tour) * g.basis.orthonormalized()
	var parent := squelette.get_bone_parent(os)
	var repere_parent := squelette.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	squelette.set_bone_pose_rotation(os, (repere_parent.inverse() * nouvelle).get_rotation_quaternion())
