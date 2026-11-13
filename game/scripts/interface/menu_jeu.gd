extends CanvasLayer
## Menu de jeu, ouvert par Échap pendant la partie (créé par l'autoload Options).
## En solo, le jeu se met en pause pendant que le menu est ouvert ; en ligne,
## le monde continue (comme dans les MMO).

const Style := preload("res://scripts/interface/style_menu.gd")
const PanneauOptions := preload("res://scripts/interface/panneau_options.gd")

var _voile: ColorRect
var _centre: CenterContainer
var _boutons: PanelContainer
var _options: PanneauOptions
var _a_mis_en_pause := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_voile = ColorRect.new()
	_voile.color = Color(0.0, 0.01, 0.03, 0.6)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_voile)
	_centre = CenterContainer.new()
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centre.theme = Style.theme()
	add_child(_centre)

	_boutons = PanelContainer.new()
	_boutons.custom_minimum_size = Vector2(340, 0)
	_centre.add_child(_boutons)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_boutons.add_child(colonne)
	var titre := Label.new()
	titre.text = "Menu"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 26)
	colonne.add_child(titre)
	colonne.add_child(_bouton("Reprendre", fermer))
	colonne.add_child(_bouton("Options", _ouvrir_options))
	colonne.add_child(_bouton("Aide des contrôles (F1)", func():
		fermer()
		var ev := InputEventAction.new()
		ev.action = "aide"
		ev.pressed = true
		Input.parse_input_event(ev)))
	colonne.add_child(HSeparator.new())
	colonne.add_child(_bouton("Retour au menu principal", func():
		fermer()
		Reseau.quitter()))
	colonne.add_child(_bouton("Quitter le jeu", func(): get_tree().quit()))

	_options = PanneauOptions.new()
	_options.visible = false
	_options.ferme.connect(_fermer_options)
	_centre.add_child(_options)


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	return b


func basculer() -> void:
	if not visible:
		ouvrir()
	elif _options.visible:
		_options.fermer_options()
	else:
		fermer()


func ouvrir() -> void:
	visible = true
	_boutons.visible = true
	_options.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Reseau.mode == Reseau.Mode.SEUL and not get_tree().paused:
		get_tree().paused = true
		_a_mis_en_pause = true


func fermer() -> void:
	visible = false
	if _a_mis_en_pause:
		get_tree().paused = false
		_a_mis_en_pause = false


func _ouvrir_options() -> void:
	_boutons.visible = false
	_options.visible = true


func _fermer_options() -> void:
	_options.visible = false
	_boutons.visible = true
