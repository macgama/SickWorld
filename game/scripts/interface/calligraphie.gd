extends CanvasLayer
## Calligraphie (île de la Chine) : rendre la mémoire à un Figé en traçant les traits
## d'un caractère chinois dans le bon ordre. Les traits sont dessinés en gris pâle,
## chacun avec une pastille (A, B, C…) ; on clique les pastilles (ou on tape 1, 2, 3…)
## dans l'ordre où le pinceau doit passer. Un bon trait se remplit d'encre noire ; une
## erreur fait trembler la feuille et efface tout. Après deux erreurs, le trait suivant
## brille un peu, pour aider.
##
## La quête l'ouvre avec ouvrir(titre, caractere, rappel) : « rappel » est appelé quand
## le caractère est tracé. Échap referme sans rien faire.

signal resolu
signal ferme

const ROUGE := Color(0.72, 0.16, 0.1, 0.95)
const ENCRE := Color(0.06, 0.05, 0.05)
const PAPIER := Color(0.93, 0.89, 0.8)
const AIDE := "Clique les pastilles dans l'ordre du pinceau (ou tape leur numéro) · Échap : laisser"
const REGLE := "Le pinceau va d'abord de haut en bas, de gauche à droite, et l'horizontal passe avant le vertical qui le croise."

## Les caractères connus : leur sens et leurs traits, dans le bon ordre. Chaque trait
## est une ligne de points, dans un carré de 0 à 1 (y vers le bas).
const CARACTERES := {
	"人": {"sens": "l'homme", "traits": [
		[Vector2(0.5, 0.12), Vector2(0.42, 0.45), Vector2(0.15, 0.88)],
		[Vector2(0.47, 0.42), Vector2(0.65, 0.66), Vector2(0.88, 0.88)]]},
	"大": {"sens": "grand", "traits": [
		[Vector2(0.15, 0.38), Vector2(0.85, 0.38)],
		[Vector2(0.5, 0.1), Vector2(0.46, 0.52), Vector2(0.15, 0.9)],
		[Vector2(0.52, 0.48), Vector2(0.7, 0.72), Vector2(0.9, 0.9)]]},
	"山": {"sens": "la montagne", "traits": [
		[Vector2(0.5, 0.1), Vector2(0.5, 0.84)],
		[Vector2(0.18, 0.34), Vector2(0.18, 0.84), Vector2(0.82, 0.84)],
		[Vector2(0.82, 0.34), Vector2(0.82, 0.84)]]},
	"木": {"sens": "l'arbre", "traits": [
		[Vector2(0.12, 0.34), Vector2(0.88, 0.34)],
		[Vector2(0.5, 0.08), Vector2(0.5, 0.92)],
		[Vector2(0.47, 0.38), Vector2(0.3, 0.62), Vector2(0.1, 0.8)],
		[Vector2(0.53, 0.38), Vector2(0.7, 0.62), Vector2(0.9, 0.8)]]},
	"天": {"sens": "le ciel", "traits": [
		[Vector2(0.22, 0.2), Vector2(0.78, 0.2)],
		[Vector2(0.12, 0.44), Vector2(0.88, 0.44)],
		[Vector2(0.5, 0.2), Vector2(0.45, 0.6), Vector2(0.15, 0.9)],
		[Vector2(0.52, 0.55), Vector2(0.7, 0.76), Vector2(0.9, 0.9)]]},
	"火": {"sens": "le feu", "traits": [
		[Vector2(0.22, 0.34), Vector2(0.32, 0.52)],
		[Vector2(0.8, 0.3), Vector2(0.68, 0.5)],
		[Vector2(0.5, 0.08), Vector2(0.48, 0.5), Vector2(0.15, 0.9)],
		[Vector2(0.5, 0.55), Vector2(0.7, 0.75), Vector2(0.9, 0.9)]]},
	"文": {"sens": "l'écriture", "traits": [
		[Vector2(0.46, 0.06), Vector2(0.55, 0.18)],
		[Vector2(0.14, 0.3), Vector2(0.86, 0.3)],
		[Vector2(0.72, 0.32), Vector2(0.45, 0.7), Vector2(0.14, 0.92)],
		[Vector2(0.3, 0.36), Vector2(0.6, 0.72), Vector2(0.9, 0.92)]]},
	"中": {"sens": "le milieu (la Chine est « le pays du milieu »)", "traits": [
		[Vector2(0.2, 0.3), Vector2(0.2, 0.68)],
		[Vector2(0.2, 0.3), Vector2(0.8, 0.3), Vector2(0.8, 0.68)],
		[Vector2(0.2, 0.66), Vector2(0.8, 0.66)],
		[Vector2(0.5, 0.06), Vector2(0.5, 0.95)]]},
	"水": {"sens": "l'eau", "traits": [
		[Vector2(0.5, 0.06), Vector2(0.5, 0.88), Vector2(0.42, 0.82)],
		[Vector2(0.14, 0.36), Vector2(0.4, 0.36), Vector2(0.14, 0.78)],
		[Vector2(0.84, 0.24), Vector2(0.58, 0.46)],
		[Vector2(0.56, 0.44), Vector2(0.72, 0.68), Vector2(0.9, 0.86)]]},
}

var _panneau: PanelContainer
var _titre: Label
var _sens: Label
var _aide: Label
var _planche: Control
var _caractere := ""
var _traits: Array = []
## Les pastilles mélangées : _ordre[k] = numéro du trait marqué par la pastille k.
var _ordre: Array[int] = []
var _place := 0
var _erreurs := 0
var _rappel: Callable
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("calligraphie")
	layer = 6
	_panneau = PanelContainer.new()
	_panneau.anchor_left = 0.5
	_panneau.anchor_right = 0.5
	_panneau.anchor_top = 0.5
	_panneau.anchor_bottom = 0.5
	_panneau.offset_left = -300
	_panneau.offset_right = 300
	_panneau.offset_top = -260
	_panneau.offset_bottom = 260
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.04, 0.94)
	style.border_color = ROUGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	_panneau.add_theme_stylebox_override("panel", style)
	add_child(_panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_panneau.add_child(colonne)
	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 20)
	_titre.add_theme_color_override("font_color", Color(1.0, 0.72, 0.6))
	colonne.add_child(_titre)
	_sens = Label.new()
	_sens.add_theme_font_size_override("font_size", 17)
	_sens.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
	colonne.add_child(_sens)
	_planche = Control.new()
	_planche.custom_minimum_size = Vector2(320, 320)
	_planche.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_planche.draw.connect(_dessiner)
	_planche.gui_input.connect(_clic_planche)
	colonne.add_child(_planche)
	var regle := Label.new()
	regle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regle.add_theme_font_size_override("font_size", 14)
	regle.add_theme_color_override("font_color", Color(0.75, 0.7, 0.66))
	regle.text = REGLE
	colonne.add_child(regle)
	_aide = Label.new()
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_aide.add_theme_color_override("font_color", Color(0.7, 0.68, 0.66))
	_aide.text = AIDE
	colonne.add_child(_aide)
	visible = false


func est_ouvert() -> bool:
	return visible


## Le caractère qu'on trace en ce moment.
func caractere() -> String:
	return _caractere


## Ouvre la feuille sur un caractère (s'il est inconnu, on prend « 人 »).
func ouvrir(titre: String, caractere_voulu: String, rappel: Callable = Callable()) -> void:
	_caractere = caractere_voulu if CARACTERES.has(caractere_voulu) else "人"
	var fiche: Dictionary = CARACTERES[_caractere]
	_traits = fiche["traits"]
	_rappel = rappel
	_titre.text = titre
	_sens.text = "%s : %s · %d traits" % [_caractere, fiche["sens"], _traits.size()]
	_place = 0
	_erreurs = 0
	_ordre.clear()
	for i in _traits.size():
		_ordre.append(i)
	_hasard.randomize()
	for essai in 8:
		_melanger()
		if not _dans_l_ordre():
			break
	_aide.text = AIDE
	visible = true
	_planche.queue_redraw()


func fermer() -> void:
	if not visible:
		return
	visible = false
	ferme.emit()


## Pour les tests : trace tout le caractère d'un coup.
func resoudre() -> void:
	while visible and _place < _traits.size():
		choisir(_ordre.find(_place))


## Le joueur choisit la pastille « k ».
func choisir(k: int) -> void:
	if not visible or k < 0 or k >= _ordre.size() or _ordre[k] < _place:
		return
	if _ordre[k] == _place:
		_place += 1
		_planche.queue_redraw()
		if _place >= _traits.size():
			_reussir()
		return
	# Mauvais trait : l'encre s'efface, on recommence.
	_place = 0
	_erreurs += 1
	_planche.queue_redraw()
	var depart := _panneau.position
	var t := create_tween()
	for i in 4:
		t.tween_property(_panneau, "position:x", depart.x + (10.0 if i % 2 == 0 else -10.0), 0.04)
	t.tween_property(_panneau, "position:x", depart.x, 0.04)


func _reussir() -> void:
	_aide.text = "Le caractère est tracé : la mémoire revient."
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_callback(func():
		visible = false
		_aide.text = AIDE
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
	return _ordre.size() > 1


# --- Dessin -------------------------------------------------------------------------

func _vers_planche(p: Vector2) -> Vector2:
	var s := _planche.size
	var cote := minf(s.x, s.y) - 30.0
	var origine := (s - Vector2(cote, cote)) * 0.5
	return origine + p * cote


## La pastille d'un trait : un peu avant le milieu de sa ligne (pour ne pas cacher le
## départ, qui donnerait la réponse).
func _place_pastille(trait_id: int) -> Vector2:
	var points: Array = _traits[trait_id]
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	var m := a.lerp(b, 0.55)
	# Un petit décalage sur le côté, perpendiculaire au trait.
	var n := (b - a).orthogonal().normalized() * 0.05
	return _vers_planche(m + n)


func _dessiner() -> void:
	var s := _planche.size
	var cote := minf(s.x, s.y) - 30.0
	var origine := (s - Vector2(cote, cote)) * 0.5
	var cadre := Rect2(origine - Vector2(10, 10), Vector2(cote + 20, cote + 20))
	_planche.draw_rect(cadre, PAPIER)
	# La grille « en forme de riz » des cahiers d'écriture, en rouge pâle.
	var grille := Color(0.75, 0.3, 0.25, 0.35)
	_planche.draw_rect(Rect2(origine, Vector2(cote, cote)), grille, false, 2.0)
	_planche.draw_dashed_line(origine + Vector2(cote * 0.5, 0), origine + Vector2(cote * 0.5, cote), grille, 1.0, 6.0)
	_planche.draw_dashed_line(origine + Vector2(0, cote * 0.5), origine + Vector2(cote, cote * 0.5), grille, 1.0, 6.0)
	_planche.draw_dashed_line(origine, origine + Vector2(cote, cote), grille, 1.0, 6.0)
	_planche.draw_dashed_line(origine + Vector2(cote, 0), origine + Vector2(0, cote), grille, 1.0, 6.0)
	if _traits.is_empty():
		return
	var police := ThemeDB.fallback_font
	for i in _traits.size():
		var points := PackedVector2Array()
		for p: Vector2 in _traits[i]:
			points.append(_vers_planche(p))
		var trace := i < _place
		var aide := not trace and i == _place and _erreurs >= 2
		var couleur := ENCRE if trace else (Color(0.95, 0.55, 0.25, 0.8) if aide else Color(0.55, 0.52, 0.48, 0.5))
		_planche.draw_polyline(points, couleur, 18.0 if trace else 12.0, true)
		for p in points:
			_planche.draw_circle(p, (9.0 if trace else 6.0), couleur)
	for k in _ordre.size():
		var t := _ordre[k]
		if t < _place:
			continue
		var c := _place_pastille(t)
		_planche.draw_circle(c, 15.0, ROUGE)
		_planche.draw_string(police, c + Vector2(-5, 6), str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _clic_planche(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var meilleure := -1
	var distance := 26.0
	for k in _ordre.size():
		if _ordre[k] < _place:
			continue
		var d := (event as InputEventMouseButton).position.distance_to(_place_pastille(_ordre[k]))
		if d < distance:
			distance = d
			meilleure = k
	if meilleure >= 0:
		choisir(meilleure)


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
