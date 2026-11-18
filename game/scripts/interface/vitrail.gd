extends CanvasLayer
## Le puzzle du vitrail (île du Moyen Âge) : rendre courage à un « Las » en remettant en
## place les morceaux d'un petit vitrail. La fenêtre est dessinée vide, en plomb noir ;
## une case clignote ; à droite, les morceaux de verre de couleur, mélangés et numérotés.
## On clique (ou on tape le numéro) du morceau qui va dans la case qui clignote : même
## forme, même couleur. Un bon morceau se pose et la lumière passe ; une erreur fait
## trembler la fenêtre (les morceaux déjà posés restent). Après deux erreurs, le bon
## morceau brille un peu, pour aider. Quand tout est posé, le soleil traverse le vitrail.
##
## La quête l'ouvre avec ouvrir(titre, motif, rappel) : « rappel » est appelé quand
## le vitrail est fini. Échap referme sans rien faire.

signal resolu
signal ferme

const PLOMB := Color(0.09, 0.09, 0.1)
const PIERRE := Color(0.62, 0.57, 0.48)
const OR := Color(0.95, 0.78, 0.35)
const AIDE := "Clique le morceau qui va dans la case qui brille (ou tape son numéro) · Échap : laisser"
const REGLE := "Regarde la forme et la couleur : chaque morceau n'a qu'une place. Le bleu de Chartres d'abord, disaient les verriers."

## Les couleurs des verriers de Chartres.
const VERRES := {
	"bleu": Color(0.1, 0.24, 0.72), "rouge": Color(0.72, 0.08, 0.1), "jaune": Color(0.92, 0.72, 0.16),
	"vert": Color(0.12, 0.5, 0.26), "blanc": Color(0.86, 0.86, 0.8), "pourpre": Color(0.42, 0.12, 0.42),
	"ciel": Color(0.36, 0.58, 0.86),
}

## Les motifs connus : leur nom et leurs cases (polygones dans un carré de 0 à 1, y vers
## le bas), chacune avec sa couleur de verre.
const MOTIFS := {
	"fleur": {"nom": "une fleur de lys", "cases": [
		{"verre": "bleu", "points": [Vector2(0.2, 0.2), Vector2(0.5, 0.05), Vector2(0.8, 0.2), Vector2(0.5, 0.45)]},
		{"verre": "jaune", "points": [Vector2(0.2, 0.2), Vector2(0.5, 0.45), Vector2(0.2, 0.7)]},
		{"verre": "rouge", "points": [Vector2(0.8, 0.2), Vector2(0.8, 0.7), Vector2(0.5, 0.45)]},
		{"verre": "vert", "points": [Vector2(0.2, 0.7), Vector2(0.5, 0.45), Vector2(0.8, 0.7), Vector2(0.5, 0.95)]}]},
	"lancette": {"nom": "une fenêtre en lancette", "cases": [
		{"verre": "bleu", "points": [Vector2(0.25, 0.3), Vector2(0.5, 0.05), Vector2(0.75, 0.3)]},
		{"verre": "rouge", "points": [Vector2(0.25, 0.3), Vector2(0.75, 0.3), Vector2(0.75, 0.5), Vector2(0.25, 0.5)]},
		{"verre": "jaune", "points": [Vector2(0.25, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.95), Vector2(0.25, 0.95)]},
		{"verre": "ciel", "points": [Vector2(0.5, 0.5), Vector2(0.75, 0.5), Vector2(0.75, 0.95), Vector2(0.5, 0.95)]},
		{"verre": "vert", "points": [Vector2(0.38, 0.62), Vector2(0.5, 0.56), Vector2(0.62, 0.62), Vector2(0.5, 0.8)]}]},
	"rose": {"nom": "une petite rose", "cases": [
		{"verre": "rouge", "points": [Vector2(0.5, 0.5), Vector2(0.5, 0.08), Vector2(0.8, 0.2)]},
		{"verre": "bleu", "points": [Vector2(0.5, 0.5), Vector2(0.8, 0.2), Vector2(0.92, 0.5)]},
		{"verre": "jaune", "points": [Vector2(0.5, 0.5), Vector2(0.92, 0.5), Vector2(0.8, 0.8)]},
		{"verre": "vert", "points": [Vector2(0.5, 0.5), Vector2(0.8, 0.8), Vector2(0.5, 0.92)]},
		{"verre": "pourpre", "points": [Vector2(0.5, 0.5), Vector2(0.5, 0.92), Vector2(0.2, 0.8)]},
		{"verre": "ciel", "points": [Vector2(0.5, 0.5), Vector2(0.2, 0.8), Vector2(0.08, 0.5), Vector2(0.2, 0.2), Vector2(0.5, 0.08)]}]},
	"belle_verriere": {"nom": "la Vierge de la Belle Verrière", "cases": [
		{"verre": "bleu", "points": [Vector2(0.22, 0.3), Vector2(0.5, 0.04), Vector2(0.78, 0.3)]},
		{"verre": "jaune", "points": [Vector2(0.4, 0.3), Vector2(0.6, 0.3), Vector2(0.6, 0.44), Vector2(0.4, 0.44)]},
		{"verre": "ciel", "points": [Vector2(0.22, 0.3), Vector2(0.4, 0.3), Vector2(0.4, 0.95), Vector2(0.22, 0.95)]},
		{"verre": "rouge", "points": [Vector2(0.6, 0.3), Vector2(0.78, 0.3), Vector2(0.78, 0.95), Vector2(0.6, 0.95)]},
		{"verre": "blanc", "points": [Vector2(0.4, 0.44), Vector2(0.6, 0.44), Vector2(0.6, 0.66), Vector2(0.4, 0.66)]},
		{"verre": "pourpre", "points": [Vector2(0.4, 0.66), Vector2(0.6, 0.66), Vector2(0.6, 0.95), Vector2(0.4, 0.95)]}]},
}

var _panneau: PanelContainer
var _titre: Label
var _sens: Label
var _aide: Label
var _planche: Control
var _motif := ""
var _cases: Array = []
## Les morceaux mélangés : _ordre[k] = numéro de la case du morceau k.
var _ordre: Array[int] = []
## Les cases déjà posées, dans l'ordre de la fenêtre (on pose de haut en bas).
var _place := 0
var _erreurs := 0
var _temps := 0.0
var _lumiere := 0.0
var _rappel: Callable
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("vitrail")
	layer = 6
	_panneau = PanelContainer.new()
	_panneau.anchor_left = 0.5
	_panneau.anchor_right = 0.5
	_panneau.anchor_top = 0.5
	_panneau.anchor_bottom = 0.5
	_panneau.offset_left = -360
	_panneau.offset_right = 360
	_panneau.offset_top = -270
	_panneau.offset_bottom = 270
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	style.border_color = VERRES["bleu"].lightened(0.3)
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
	_titre.add_theme_color_override("font_color", Color(0.7, 0.82, 1.0))
	colonne.add_child(_titre)
	_sens = Label.new()
	_sens.add_theme_font_size_override("font_size", 17)
	_sens.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	colonne.add_child(_sens)
	_planche = Control.new()
	_planche.custom_minimum_size = Vector2(660, 330)
	_planche.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_planche.draw.connect(_dessiner)
	_planche.gui_input.connect(_clic_planche)
	colonne.add_child(_planche)
	var regle := Label.new()
	regle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regle.add_theme_font_size_override("font_size", 14)
	regle.add_theme_color_override("font_color", Color(0.72, 0.72, 0.7))
	regle.text = REGLE
	colonne.add_child(regle)
	_aide = Label.new()
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_aide.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_aide.text = AIDE
	colonne.add_child(_aide)
	visible = false


func est_ouvert() -> bool:
	return visible


## Le motif en cours.
func motif() -> String:
	return _motif


## Ouvre la fenêtre sur un motif (s'il est inconnu, on prend « fleur »).
func ouvrir(titre: String, motif_voulu: String, rappel: Callable = Callable()) -> void:
	_motif = motif_voulu if MOTIFS.has(motif_voulu) else "fleur"
	var fiche: Dictionary = MOTIFS[_motif]
	_cases = fiche["cases"]
	_rappel = rappel
	_titre.text = titre
	_sens.text = "Le vitrail : %s · %d morceaux" % [fiche["nom"], _cases.size()]
	_place = 0
	_erreurs = 0
	_lumiere = 0.0
	_ordre.clear()
	for i in _cases.size():
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


## Pour les tests : pose tout le vitrail d'un coup.
func resoudre() -> void:
	while visible and _place < _cases.size():
		choisir(_ordre.find(_place))


## Le morceau qui va dans la case qui brille (pour les tests).
func bon_morceau() -> int:
	return _ordre.find(_place)


## Le joueur choisit le morceau « k ».
func choisir(k: int) -> void:
	if not visible or k < 0 or k >= _ordre.size() or _ordre[k] < _place:
		return
	if _ordre[k] == _place:
		_place += 1
		_planche.queue_redraw()
		if _place >= _cases.size():
			_reussir()
		return
	# Mauvais morceau : la fenêtre tremble, on garde ce qui est posé.
	_erreurs += 1
	_planche.queue_redraw()
	var depart := _panneau.position
	var t := create_tween()
	for i in 4:
		t.tween_property(_panneau, "position:x", depart.x + (10.0 if i % 2 == 0 else -10.0), 0.04)
	t.tween_property(_panneau, "position:x", depart.x, 0.04)


func _reussir() -> void:
	_aide.text = "La lumière traverse le vitrail."
	var t := create_tween()
	t.tween_property(self, "_lumiere", 1.0, 0.6)
	t.tween_interval(0.5)
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


func _process(delta: float) -> void:
	if visible:
		_temps += delta
		_planche.queue_redraw()


# --- Dessin -------------------------------------------------------------------------

## La fenêtre, à gauche de la planche.
func _cadre_fenetre() -> Rect2:
	var cote := minf(_planche.size.y - 10.0, 320.0)
	return Rect2(Vector2(20, (_planche.size.y - cote) * 0.5), Vector2(cote, cote))


## La case du morceau k, à droite (deux colonnes).
func _cadre_morceau(k: int) -> Rect2:
	var f := _cadre_fenetre()
	var cote := 96.0
	var x0 := f.end.x + 50.0
	var colonne := k % 3
	var ligne := k / 3
	return Rect2(Vector2(x0 + colonne * (cote + 14.0), f.position.y + 10.0 + ligne * (cote + 40.0)), Vector2(cote, cote))


func _polygone(points: Array, cadre: Rect2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for q: Vector2 in points:
		p.append(cadre.position + q * cadre.size)
	return p


func _dessiner() -> void:
	if _cases.is_empty():
		return
	var f := _cadre_fenetre()
	# L'embrasure de pierre et le fond sombre de la fenêtre vide.
	_planche.draw_rect(f.grow(12.0), PIERRE)
	_planche.draw_rect(f, Color(0.03, 0.03, 0.05))
	var police := ThemeDB.fallback_font
	var pulse := 0.5 + 0.5 * sin(_temps * 5.0)
	for i in _cases.size():
		var c: Dictionary = _cases[i]
		var poly := _polygone(c["points"], f)
		var verre: Color = VERRES.get(c["verre"], Color.WHITE)
		if i < _place:
			# Verre posé : la lumière passe (plus claire à la fin).
			_planche.draw_colored_polygon(poly, verre.lightened(0.15 + 0.35 * _lumiere))
		elif i == _place:
			_planche.draw_colored_polygon(poly, Color(1, 1, 1, 0.08 + 0.12 * pulse))
		var contour := poly.duplicate()
		contour.append(poly[0])
		_planche.draw_polyline(contour, OR.lerp(Color.WHITE, pulse) if i == _place else PLOMB, 6.0 if i == _place else 5.0, true)
	# Les morceaux à poser, à droite.
	for k in _ordre.size():
		var i := _ordre[k]
		if i < _place:
			continue
		var cadre := _cadre_morceau(k)
		var c: Dictionary = _cases[i]
		var aide := i == _place and _erreurs >= 2
		_planche.draw_rect(cadre, Color(0.95, 0.8, 0.4, 0.25 + 0.25 * pulse) if aide else Color(0.14, 0.14, 0.16))
		# Le morceau, recadré sur sa propre forme.
		var mini := Vector2.ONE
		var maxi := Vector2.ZERO
		for q: Vector2 in c["points"]:
			mini = mini.min(q)
			maxi = maxi.max(q)
		var etendue := maxi - mini
		var echelle := (cadre.size.x - 16.0) / maxf(etendue.x, etendue.y)
		var poly := PackedVector2Array()
		for q: Vector2 in c["points"]:
			poly.append(cadre.get_center() + (q - (mini + maxi) * 0.5) * echelle)
		_planche.draw_colored_polygon(poly, VERRES.get(c["verre"], Color.WHITE))
		var contour := poly.duplicate()
		contour.append(poly[0])
		_planche.draw_polyline(contour, PLOMB, 3.0, true)
		_planche.draw_circle(cadre.position + Vector2(14, 14), 13.0, OR)
		_planche.draw_string(police, cadre.position + Vector2(9, 20), str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PLOMB)


func _clic_planche(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for k in _ordre.size():
		if _ordre[k] >= _place and _cadre_morceau(k).has_point((event as InputEventMouseButton).position):
			choisir(k)
			return


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
