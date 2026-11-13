extends Node3D
## Un endroit du décor qu'on utilise avec F (bouton d'ascenseur, registre...).
## Affiche « [F] texte » quand le joueur est tout près, puis émet « utilise ».
## Les quartiers le créent en code : voir quartier_residences.gd.

signal utilise

## Texte affiché après « [F] ».
@export var texte := "Utiliser"
## Distance (mètres) à laquelle on peut l'utiliser.
@export var portee := 1.8

var _invite: Label3D


func _ready() -> void:
	add_to_group("points_interaction")
	_invite = Label3D.new()
	_invite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_invite.font_size = 36
	_invite.pixel_size = 0.005
	_invite.outline_size = 10
	_invite.no_depth_test = true
	_invite.position = Vector3(0, 1.0, 0)
	_invite.visible = false
	add_child(_invite)


func _proche() -> bool:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return false
	var ecart := joueur.global_position - global_position
	return Vector2(ecart.x, ecart.z).length() < portee and absf(ecart.y) < 2.5


func _dialogue_ouvert() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	return dialogue != null and dialogue.est_ouvert()


func _process(_delta: float) -> void:
	_invite.visible = _proche() and not _dialogue_ouvert()
	_invite.text = "[F] " + texte


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interagir") and _proche() and not _dialogue_ouvert():
		get_viewport().set_input_as_handled()
		utilise.emit()
