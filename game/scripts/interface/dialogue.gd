class_name Dialogue
extends CanvasLayer
## Fenêtre de dialogue en bas de l'écran : nom du personnage et ses répliques.
## F (ou un clic) passe à la réplique suivante ; Échap ferme.
## Un personnage (Pnj) l'ouvre avec ouvrir(). Le signal « termine » prévient
## quand le joueur a lu toutes les répliques (utile pour les quêtes).

signal termine(id_pnj: String)

var _panneau: PanelContainer
var _nom: Label
var _texte: Label
var _suite: Label
var _repliques: PackedStringArray = []
var _index := 0
var _id := ""


func _ready() -> void:
	add_to_group("dialogue")
	layer = 5
	_panneau = PanelContainer.new()
	_panneau.anchor_left = 0.5
	_panneau.anchor_right = 0.5
	_panneau.anchor_top = 1.0
	_panneau.anchor_bottom = 1.0
	_panneau.offset_left = -380
	_panneau.offset_right = 380
	_panneau.offset_top = -330
	_panneau.offset_bottom = -170
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.88)
	style.border_color = Color(0.55, 0.45, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panneau.add_theme_stylebox_override("panel", style)
	add_child(_panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	_panneau.add_child(colonne)
	_nom = Label.new()
	_nom.add_theme_font_size_override("font_size", 20)
	_nom.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0))
	colonne.add_child(_nom)
	_texte = Label.new()
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.add_theme_font_size_override("font_size", 18)
	_texte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(_texte)
	_suite = Label.new()
	_suite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_suite.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	colonne.add_child(_suite)
	_panneau.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			suivant())
	visible = false


func est_ouvert() -> bool:
	return visible


func ouvrir(id_pnj: String, nom: String, repliques: PackedStringArray) -> void:
	if repliques.is_empty():
		return
	_id = id_pnj
	_nom.text = nom
	_repliques = repliques
	_index = 0
	visible = true
	_afficher()


func suivant() -> void:
	if not visible:
		return
	_index += 1
	if _index >= _repliques.size():
		fermer()
		termine.emit(_id)
		return
	_afficher()


func fermer() -> void:
	visible = false


func _afficher() -> void:
	_texte.text = _repliques[_index]
	var dernier := _index == _repliques.size() - 1
	_suite.text = "F : fermer" if dernier else "F : suite (%d/%d)" % [_index + 1, _repliques.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interagir"):
		suivant()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("annuler"):
		fermer()
		get_viewport().set_input_as_handled()
