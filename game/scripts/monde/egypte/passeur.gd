extends Node3D
## Le passeur du Nil (île d'Égypte) : un batelier et sa barque, au bord du fleuve.
## F pour traverser vers l'autre rive (changement de zone). Le passage n'ouvre
## qu'une fois la quête arrivée assez loin (étape « condition »).

const PORTEE := 3.5

## Zone de l'autre rive (ex. « carrieres_toura »).
@export var destination := ""
## Nom affiché de l'autre rive.
@export var nom_destination := ""
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
	_invite.text = ("[F] Traverser le Nil vers " + nom_destination) if ouvert() \
			else "Le passeur ne traverse pas aujourd'hui : le fleuve est trop dangereux."


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagir") or not _joueur_proche() or not ouvert():
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null and dialogue.est_ouvert():
		return
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null:
		return
	get_viewport().set_input_as_handled()
	quete.changer_de_zone(destination)
