extends Node3D
## Le passeur du Fleuve Jaune (île de la Chine) : le vieux Bo et sa barque, au bord de
## l'eau. F pour passer sur l'autre rive, dans la même zone (le joueur est posé sur le
## débarcadère d'en face). Le passage n'ouvre qu'une fois la quête arrivée assez loin
## (étape « condition ») : avant, c'est le grand bac du chapitre 3 qui fait la traversée.

const PORTEE := 3.5

## Où l'on arrive, de l'autre côté (x, z), et vers où l'on regarde (angle).
@export var arrivee := Vector2.ZERO
@export var angle_arrivee := 0.0
## Nom affiché de l'autre rive.
@export var nom_rive := ""
## Étape de la quête à partir de laquelle le passeur accepte de traverser.
@export var condition := ""

var _invite: Label3D


func _ready() -> void:
	add_to_group("passeurs")
	_invite = Label3D.new()
	_invite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_invite.font_size = 36
	_invite.pixel_size = 0.005
	_invite.outline_size = 10
	_invite.position = Vector3(0, 2.2, 0)
	_invite.visible = false
	add_child(_invite)


func ouvert() -> bool:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or condition == "":
		return true
	return quete.has_method("etape_atteinte") and quete.etape_atteinte(condition)


func _joueur_proche() -> bool:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	return joueur != null and joueur.global_position.distance_to(global_position) < PORTEE


func _process(_delta: float) -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var occupe: bool = dialogue != null and dialogue.est_ouvert()
	_invite.visible = _joueur_proche() and not occupe
	_invite.text = ("[F] Passer le Fleuve Jaune vers " + nom_rive) if ouvert() \
			else "Le vieux Bo ne passe personne : « Le grand bac partira bientôt. »"


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagir") or not _joueur_proche() or not ouvert():
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null and dialogue.est_ouvert():
		return
	get_viewport().set_input_as_handled()
	traverser()


## Pose le joueur sur l'autre rive.
func traverser() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	var ile := get_tree().get_first_node_in_group("ile")
	if joueur == null:
		return
	var y := global_position.y + 1.0
	if ile != null and ile.has_method("hauteur"):
		y = ile.hauteur(arrivee.x, arrivee.y) + 0.4
	var p := Vector3(arrivee.x, y, arrivee.y)
	if joueur.has_method("teleporter"):
		joueur.teleporter(p, angle_arrivee)
	else:
		joueur.global_position = p
