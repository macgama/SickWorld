@tool
extends Node3D
## Personnage non joueur du hub : un agent de la Vigie qui parle quand on
## s'approche et qu'on appuie sur F.
## Son nom et ses répliques viennent de data/hub_pnj.json (clé « identifiant »).

const DONNEES := "res://data/hub_pnj.json"
const SCENE_APPARENCE := "res://scenes/joueur/apparence_agent.tscn"
## Distance (mètres) à laquelle on peut lui parler.
const PORTEE := 3.2

signal parle(id: String)

## Clé du personnage dans data/hub_pnj.json.
@export var identifiant := "commandante":
	set(valeur):
		identifiant = valeur
		if is_inside_tree():
			_construire()

var nom := ""
var role := ""
var repliques: PackedStringArray = []
## Répliques imposées par une quête ou l'intro (prioritaires si non vides).
var repliques_speciales: PackedStringArray = []
var _invite: Label3D
var _apparence: Node3D

static var _donnees := {}


func _ready() -> void:
	add_to_group("pnj")
	_construire()


static func donnees() -> Dictionary:
	if _donnees.is_empty():
		var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
		if lu is Dictionary:
			_donnees = lu
		else:
			push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	return _donnees


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	var fiche: Dictionary = donnees().get(identifiant, {})
	nom = fiche.get("nom", identifiant)
	role = fiche.get("role", "")
	repliques = PackedStringArray(fiche.get("repliques", []))
	if ResourceLoader.exists(SCENE_APPARENCE):
		_apparence = (load(SCENE_APPARENCE) as PackedScene).instantiate()
		_apparence.set("modele", fiche.get("modele", "homme"))
		add_child(_apparence)
	var etiquette := Label3D.new()
	etiquette.text = nom + ("\n" + role if role != "" else "")
	etiquette.position = Vector3(0, 2.15, 0)
	etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiquette.font_size = 40
	etiquette.pixel_size = 0.005
	etiquette.outline_size = 10
	etiquette.modulate = Color(1.0, 0.92, 0.55)
	etiquette.no_depth_test = false
	add_child(etiquette)
	_invite = Label3D.new()
	_invite.text = "[F] Parler"
	_invite.position = Vector3(0, 1.0, 0)
	_invite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_invite.font_size = 36
	_invite.pixel_size = 0.005
	_invite.outline_size = 10
	_invite.visible = false
	add_child(_invite)


func _joueur_proche() -> bool:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	return joueur != null and joueur.global_position.distance_to(global_position) < PORTEE


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _invite == null:
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var occupe: bool = dialogue != null and dialogue.est_ouvert()
	_invite.visible = _joueur_proche() and not occupe


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed("interagir"):
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue == null or dialogue.est_ouvert() or not _joueur_proche():
		return
	get_viewport().set_input_as_handled()
	parler()


## Ouvre le dialogue de ce personnage.
func parler() -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue == null:
		return
	dialogue.ouvrir(identifiant, nom, repliques_speciales if not repliques_speciales.is_empty() else repliques)
	parle.emit(identifiant)
