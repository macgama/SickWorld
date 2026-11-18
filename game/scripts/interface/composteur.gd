extends CanvasLayer
## Le petit jeu de la composition (île de Mayence) : délivrer un « Scellé » en composant,
## avec des lettres de plomb, la phrase qui le libère. Comme les vrais typographes de
## Gutenberg, on prend les lettres une à une dans la casse et on les range dans le
## composteur. Piège : une lettre de plomb est gravée À L'ENVERS (en miroir), pour être
## à l'endroit une fois imprimée. Un « b » de plomb ressemble donc à un « d », un « p » à
## un « q »… Dans la casse, il y a les bonnes lettres et quelques lettres pièges.
##
## On clique (ou on tape le numéro) de la lettre suivante de la phrase. Une bonne lettre
## se range dans le composteur ; une erreur fait trembler la casse (ce qui est rangé reste).
## Après deux erreurs, la bonne lettre brille un peu. Quand la phrase est composée, on
## encre et on presse : la feuille sort, à l'endroit.
##
## La quête l'ouvre avec ouvrir(titre, phrase, rappel) : « rappel » est appelé quand la
## phrase est imprimée. Échap referme sans rien faire.

signal resolu
signal ferme

const PLOMB := Color(0.55, 0.56, 0.58)
const PLOMB_SOMBRE := Color(0.3, 0.31, 0.33)
const BOIS := Color(0.36, 0.24, 0.14)
const ENCRE := Color(0.06, 0.05, 0.05)
const PAPIER := Color(0.93, 0.89, 0.8)
const OR := Color(0.95, 0.78, 0.35)
const AIDE := "Clique la lettre qui vient ensuite (ou tape son numéro) · Échap : laisser"
const REGLE := "Les lettres de plomb sont gravées à l'envers, comme dans un miroir : un « b » de plomb ressemble à un « d ». Elles se remettront à l'endroit sur le papier."
## Les lettres qui se confondent en miroir : on en met comme pièges.
const PIEGES := {"b": "d", "d": "b", "p": "q", "q": "p", "n": "u", "u": "n", "m": "w", "w": "m",
		"s": "z", "z": "s", "e": "a", "a": "e", "i": "l", "l": "i", "o": "c", "c": "o", "r": "t", "t": "r"}
## Nombre de cases de la casse au plus.
const CASES_MAX := 12

var _panneau: PanelContainer
var _titre: Label
var _sens: Label
var _aide: Label
var _planche: Control
## La phrase à composer, et ses lettres sans les espaces (ce qu'on va chercher dans la casse).
var _phrase := ""
var _lettres: Array[String] = []
## La casse : les lettres proposées (bonnes et pièges), mélangées.
var _casse: Array[String] = []
## Nombre de lettres déjà rangées dans le composteur.
var _place := 0
var _erreurs := 0
var _temps := 0.0
var _presse := 0.0
var _rappel: Callable
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("composteur")
	layer = 6
	_panneau = PanelContainer.new()
	_panneau.anchor_left = 0.5
	_panneau.anchor_right = 0.5
	_panneau.anchor_top = 0.5
	_panneau.anchor_bottom = 0.5
	_panneau.offset_left = -380
	_panneau.offset_right = 380
	_panneau.offset_top = -280
	_panneau.offset_bottom = 280
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.95)
	style.border_color = OR.darkened(0.2)
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
	_titre.add_theme_color_override("font_color", OR)
	colonne.add_child(_titre)
	_sens = Label.new()
	_sens.add_theme_font_size_override("font_size", 17)
	_sens.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	colonne.add_child(_sens)
	_planche = Control.new()
	_planche.custom_minimum_size = Vector2(700, 340)
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


## La phrase en cours.
func phrase() -> String:
	return _phrase


## Ouvre la casse sur une phrase (en minuscules ; si elle est vide, on prend « lire »).
func ouvrir(titre: String, phrase_voulue: String, rappel: Callable = Callable()) -> void:
	_phrase = phrase_voulue.strip_edges().to_lower()
	if _phrase == "":
		_phrase = "lire"
	_lettres.clear()
	for k in _phrase.length():
		var c := _phrase[k]
		if c != " ":
			_lettres.append(c)
	_rappel = rappel
	_titre.text = titre
	_sens.text = "Compose : « %s » · %d lettres" % [_phrase, _lettres.size()]
	_place = 0
	_erreurs = 0
	_presse = 0.0
	_hasard.randomize()
	_remplir_casse()
	_aide.text = AIDE
	visible = true
	_planche.queue_redraw()


func fermer() -> void:
	if not visible:
		return
	visible = false
	ferme.emit()


## Pour les tests : compose toute la phrase d'un coup.
func resoudre() -> void:
	var garde := 0
	while visible and _place < _lettres.size() and garde < 200:
		garde += 1
		choisir(bonne_case())


## La case de la casse qui contient la lettre suivante (pour les tests et l'aide).
func bonne_case() -> int:
	if _place >= _lettres.size():
		return -1
	return _casse.find(_lettres[_place])


## Le joueur choisit la case « k » de la casse.
func choisir(k: int) -> void:
	if not visible or _place >= _lettres.size() or k < 0 or k >= _casse.size():
		return
	if _casse[k] == _lettres[_place]:
		_place += 1
		_erreurs = 0
		# Les lettres de plomb ne s'épuisent pas : la casse garde ses cases, on les remélange
		# un peu seulement quand la lettre suivante n'y est plus.
		if _place < _lettres.size() and not _casse.has(_lettres[_place]):
			_remplir_casse()
		_planche.queue_redraw()
		if _place >= _lettres.size():
			_reussir()
		return
	_erreurs += 1
	_planche.queue_redraw()
	var depart := _panneau.position
	var t := create_tween()
	for i in 4:
		t.tween_property(_panneau, "position:x", depart.x + (10.0 if i % 2 == 0 else -10.0), 0.04)
	t.tween_property(_panneau, "position:x", depart.x, 0.04)


func _reussir() -> void:
	_aide.text = "On encre, on serre la presse… la feuille sort, à l'endroit."
	var t := create_tween()
	t.tween_property(self, "_presse", 1.0, 0.8)
	t.tween_interval(0.7)
	t.tween_callback(func():
		visible = false
		_aide.text = AIDE
		resolu.emit()
		if _rappel.is_valid():
			_rappel.call())


## La casse : toutes les lettres différentes de la phrase qui restent à composer, plus
## leurs lettres pièges (miroirs), plus quelques lettres au hasard, mélangées.
func _remplir_casse() -> void:
	_casse.clear()
	for k in range(_place, _lettres.size()):
		var c := _lettres[k]
		if not _casse.has(c) and _casse.size() < CASES_MAX:
			_casse.append(c)
	var pieges: Array[String] = []
	for c in _casse:
		var p: String = PIEGES.get(c, "")
		if p != "" and not _casse.has(p) and not pieges.has(p):
			pieges.append(p)
	for p in pieges:
		if _casse.size() < CASES_MAX:
			_casse.append(p)
	var alphabet := "abcdefghilmnoprstuv"
	var garde := 0
	while _casse.size() < mini(CASES_MAX, maxi(8, _casse.size())) and garde < 50:
		garde += 1
		var c := alphabet[_hasard.randi_range(0, alphabet.length() - 1)]
		if not _casse.has(c):
			_casse.append(c)
	for i in range(_casse.size() - 1, 0, -1):
		var j := _hasard.randi_range(0, i)
		var t := _casse[i]
		_casse[i] = _casse[j]
		_casse[j] = t


func _process(delta: float) -> void:
	if visible:
		_temps += delta
		_planche.queue_redraw()


# --- Dessin -------------------------------------------------------------------------

## La case k de la casse (4 colonnes, en haut de la planche).
func _cadre_case(k: int) -> Rect2:
	var cote := 70.0
	var colonnes := 6
	var x0 := (_planche.size.x - colonnes * (cote + 12.0) + 12.0) * 0.5
	return Rect2(Vector2(x0 + (k % colonnes) * (cote + 12.0), 8.0 + (k / colonnes) * (cote + 26.0)), Vector2(cote, cote))


## Le composteur : une réglette de bois, en bas de la planche.
func _cadre_composteur() -> Rect2:
	return Rect2(Vector2(20, _planche.size.y - 118.0), Vector2(_planche.size.x - 40.0, 54.0))


## Une lettre de plomb : un petit bloc gris avec la lettre gravée en miroir.
func _type_plomb(cadre: Rect2, lettre: String, taille: int, encree := false) -> void:
	_planche.draw_rect(cadre, PLOMB_SOMBRE)
	_planche.draw_rect(cadre.grow(-3.0), PLOMB)
	# Le cran du typographe, sur le côté (pour savoir dans quel sens tenir la lettre).
	_planche.draw_rect(Rect2(cadre.position + Vector2(0, cadre.size.y * 0.7), Vector2(cadre.size.x, 3.0)), PLOMB_SOMBRE)
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size(lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var centre := cadre.get_center()
	# En miroir : on retourne le dessin de gauche à droite autour du centre de la case.
	_planche.draw_set_transform(Vector2(centre.x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
	_planche.draw_string(police, Vector2(centre.x - largeur * 0.5, centre.y + taille * 0.35), lettre,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, ENCRE if encree else Color(0.16, 0.16, 0.18))
	_planche.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dessiner() -> void:
	if _lettres.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(_temps * 5.0)
	var police := ThemeDB.fallback_font
	# La casse : un casier de bois, une lettre de plomb par case.
	if _casse.size() > 0:
		var haut := _cadre_case(0)
		var bas := _cadre_case(_casse.size() - 1)
		var fond := Rect2(Vector2(haut.position.x - 10.0, haut.position.y - 6.0),
				Vector2(_cadre_case(mini(5, _casse.size() - 1)).end.x - haut.position.x + 20.0, bas.end.y - haut.position.y + 26.0))
		_planche.draw_rect(fond, BOIS)
	var aide := _erreurs >= 2
	var bonne := bonne_case()
	for k in _casse.size():
		var cadre := _cadre_case(k)
		_planche.draw_rect(cadre.grow(3.0), BOIS.darkened(0.4))
		if aide and k == bonne:
			_planche.draw_rect(cadre.grow(5.0), Color(OR.r, OR.g, OR.b, 0.35 + 0.35 * pulse))
		_type_plomb(cadre, _casse[k], 44)
		_planche.draw_circle(cadre.position + Vector2(-2, -2), 11.0, OR)
		_planche.draw_string(police, cadre.position + Vector2(-7, 4), str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ENCRE)
	# Le composteur : les lettres rangées de GAUCHE à droite, gravées à l'envers.
	var c := _cadre_composteur()
	_planche.draw_rect(c.grow(4.0), BOIS.darkened(0.3))
	_planche.draw_rect(c, BOIS.lightened(0.1))
	var pas := minf(34.0, (c.size.x - 16.0) / maxf(1.0, float(_phrase.length())))
	var n := 0
	for k in _phrase.length():
		var lettre := _phrase[k]
		var cadre := Rect2(Vector2(c.position.x + 8.0 + k * pas, c.position.y + 6.0), Vector2(pas - 3.0, c.size.y - 12.0))
		if lettre == " ":
			continue
		if n < _place:
			_type_plomb(cadre, lettre, int(minf(30.0, pas)), true)
		elif n == _place:
			_planche.draw_rect(cadre, Color(1, 1, 1, 0.08 + 0.14 * pulse))
		n += 1
	# La feuille imprimée, qui sort quand tout est composé : à l'endroit, enfin.
	if _presse > 0.0:
		var feuille := Rect2(Vector2(c.position.x + 60.0, c.position.y + 58.0 - 90.0 * _presse), Vector2(c.size.x - 120.0, 50.0))
		_planche.draw_rect(feuille, PAPIER)
		var largeur := police.get_string_size(_phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		_planche.draw_string(police, Vector2(feuille.get_center().x - largeur * 0.5, feuille.get_center().y + 10.0), _phrase,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(ENCRE.r, ENCRE.g, ENCRE.b, _presse))


func _clic_planche(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for k in _casse.size():
		if _cadre_case(k).has_point((event as InputEventMouseButton).position):
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
		elif touche == KEY_0:
			k = 9
		elif touche >= KEY_KP_1 and touche <= KEY_KP_9:
			k = touche - KEY_KP_1
		if k >= 0:
			choisir(k)
			get_viewport().set_input_as_handled()
