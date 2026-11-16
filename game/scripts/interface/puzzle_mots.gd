extends CanvasLayer
## Puzzle de mots (île de Rome) : « renouer » un Égaré en remettant sa phrase dans
## l'ordre. La fracture a brouillé ses mots ; on clique dessus (ou on tape leur
## numéro) dans le bon ordre. Une erreur fait trembler la phrase et la remet à zéro.
##
## La quête l'ouvre avec ouvrir(titre, phrase, rappel) : « rappel » est appelé quand la
## phrase est remise en ordre. Échap referme sans rien faire.

signal resolu
signal ferme

const VIOLET := Color(0.55, 0.45, 1.0, 0.9)
const OR := Color(1.0, 0.82, 0.35)

var _panneau: PanelContainer
var _titre: Label
var _phrase: Label
var _aide: Label
var _boutons: HFlowContainer
var _mots: PackedStringArray = []
var _ordre: Array[int] = []
var _place := 0
var _rappel: Callable
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("puzzle_mots")
	layer = 6
	_panneau = PanelContainer.new()
	_panneau.anchor_left = 0.5
	_panneau.anchor_right = 0.5
	_panneau.anchor_top = 0.5
	_panneau.anchor_bottom = 0.5
	_panneau.offset_left = -420
	_panneau.offset_right = 420
	_panneau.offset_top = -150
	_panneau.offset_bottom = 150
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.92)
	style.border_color = VIOLET
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	_panneau.add_theme_stylebox_override("panel", style)
	add_child(_panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	_panneau.add_child(colonne)
	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 20)
	_titre.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0))
	colonne.add_child(_titre)
	_phrase = Label.new()
	_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phrase.add_theme_font_size_override("font_size", 22)
	_phrase.add_theme_color_override("font_color", OR)
	_phrase.custom_minimum_size = Vector2(0, 36)
	colonne.add_child(_phrase)
	_boutons = HFlowContainer.new()
	_boutons.add_theme_constant_override("h_separation", 10)
	_boutons.add_theme_constant_override("v_separation", 10)
	_boutons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(_boutons)
	_aide = Label.new()
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_aide.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_aide.text = "Clique les mots dans l'ordre (ou tape leur numéro) · Échap : laisser"
	colonne.add_child(_aide)
	visible = false


func est_ouvert() -> bool:
	return visible


## Ouvre le puzzle sur une phrase. Les mots sont mélangés (jamais dans le bon ordre).
func ouvrir(titre: String, phrase: String, rappel: Callable = Callable()) -> void:
	_mots = phrase.strip_edges().split(" ", false)
	if _mots.is_empty():
		return
	_rappel = rappel
	_titre.text = titre
	_place = 0
	_ordre.clear()
	for i in _mots.size():
		_ordre.append(i)
	_hasard.randomize()
	for essai in 8:
		_melanger()
		if _mots.size() < 2 or not _dans_l_ordre():
			break
	_remplir()
	visible = true


func fermer() -> void:
	if not visible:
		return
	visible = false
	ferme.emit()


## Pour les tests : remet la phrase en ordre d'un coup.
func resoudre() -> void:
	while visible and _place < _mots.size():
		for k in _ordre.size():
			if _ordre[k] == _place:
				choisir(k)
				break


## Le joueur choisit le mot affiché à la position « k ».
func choisir(k: int) -> void:
	if not visible or k < 0 or k >= _ordre.size():
		return
	var bouton := _boutons.get_child(k) as Button
	if bouton == null or bouton.disabled:
		return
	if _ordre[k] == _place:
		bouton.disabled = true
		_place += 1
		_phrase.text = " ".join(_mots.slice(0, _place))
		if _place >= _mots.size():
			_reussir()
		return
	# Mauvais mot : la phrase tremble et on recommence.
	_place = 0
	_phrase.text = ""
	for b in _boutons.get_children():
		(b as Button).disabled = false
	var depart := _panneau.position
	var t := create_tween()
	for i in 4:
		t.tween_property(_panneau, "position:x", depart.x + (10.0 if i % 2 == 0 else -10.0), 0.04)
	t.tween_property(_panneau, "position:x", depart.x, 0.04)


func _reussir() -> void:
	_aide.text = "Les mots retrouvent leur place."
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_callback(func():
		visible = false
		_aide.text = "Clique les mots dans l'ordre (ou tape leur numéro) · Échap : laisser"
		resolu.emit()
		if _rappel.is_valid():
			_rappel.call())


func _melanger() -> void:
	for i in range(_ordre.size() - 1, 0, -1):
		var j := _hasard.randi_range(0, i)
		var t := _ordre[i]
		_ordre[i] = _ordre[j]
		_ordre[j] = t


func _dans_l_ordre() -> bool:
	for i in _ordre.size():
		if _ordre[i] != i:
			return false
	return true


func _remplir() -> void:
	for b in _boutons.get_children():
		_boutons.remove_child(b)
		b.queue_free()
	_phrase.text = ""
	for k in _ordre.size():
		var b := Button.new()
		b.text = "%d · %s" % [k + 1, _mots[_ordre[k]]] if k < 9 else _mots[_ordre[k]]
		b.add_theme_font_size_override("font_size", 19)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(choisir.bind(k))
		_boutons.add_child(b)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("annuler"):
		fermer()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var touche := (event as InputEventKey).physical_keycode
		var k := -1
		if touche >= KEY_1 and touche <= KEY_9:
			k = touche - KEY_1
		elif touche >= KEY_KP_1 and touche <= KEY_KP_9:
			k = touche - KEY_KP_1
		if k >= 0:
			choisir(k)
			get_viewport().set_input_as_handled()
