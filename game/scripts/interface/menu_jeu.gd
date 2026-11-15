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
## « Revoir une cinématique » : seulement sur une île qui en a dans cette zone.
var _bouton_cinematiques: Button
var _liste_cinematiques: VBoxContainer


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
	_bouton_cinematiques = _bouton("Revoir une cinématique", func():
		_liste_cinematiques.visible = not _liste_cinematiques.visible)
	colonne.add_child(_bouton_cinematiques)
	_liste_cinematiques = VBoxContainer.new()
	_liste_cinematiques.add_theme_constant_override("separation", 6)
	_liste_cinematiques.visible = false
	colonne.add_child(_liste_cinematiques)
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
	_remplir_cinematiques()
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


## Les cinématiques de la zone où l'on se trouve (voir scripts/monde/cinematiques.gd).
func _remplir_cinematiques() -> void:
	for b in _liste_cinematiques.get_children():
		b.queue_free()
	_liste_cinematiques.visible = false
	var quete := get_tree().get_first_node_in_group("quete")
	var cin = quete.get("cinematiques") if quete != null else null
	var liste: Array = cin.cinematiques_de_la_zone() if cin != null and Reseau.mode == Reseau.Mode.SEUL else []
	_bouton_cinematiques.visible = not liste.is_empty()
	for c in liste:
		var id := String(c.get("id", ""))
		var b := _bouton(String(c.get("titre", id)), func():
			fermer()
			cin.jouer(id))
		b.custom_minimum_size = Vector2(0, 36)
		_liste_cinematiques.add_child(b)
