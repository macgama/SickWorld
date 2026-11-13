extends RefCounted
## Thème commun aux menus (écran titre, options, menu de jeu) :
## verre sombre, liseré cyan de la Vigie, police NotoSansJP.
## S'utilise avec preload("res://scripts/interface/style_menu.gd").theme().

const CYAN := Color(0.35, 0.88, 0.95)
const VIOLET := Color(0.72, 0.42, 1.0)
const TEXTE := Color(0.92, 0.95, 1.0)
const TEXTE_DOUX := Color(0.7, 0.78, 0.88)
const FOND := Color(0.03, 0.05, 0.08, 0.82)
const POLICE := "res://assets/polices/NotoSansJP-Bold-hub.ttf"

static var _theme: Theme


static func police() -> Font:
	if ResourceLoader.exists(POLICE):
		return load(POLICE)
	return ThemeDB.fallback_font


static func boite(fond: Color, bord: Color = Color(0, 0, 0, 0), largeur_bord := 0, rayon := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(largeur_bord)
	s.set_corner_radius_all(rayon)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = police()
	t.default_font_size = 17
	# Boutons : verre sombre, liseré cyan au survol.
	var normal := boite(Color(0.06, 0.09, 0.13, 0.78), Color(1, 1, 1, 0.08), 1)
	var survol := boite(Color(0.08, 0.17, 0.22, 0.9), CYAN, 1)
	var appui := boite(Color(0.05, 0.25, 0.3, 0.95), CYAN, 2)
	var inactif := boite(Color(0.05, 0.06, 0.08, 0.5), Color(1, 1, 1, 0.04), 1)
	var focus := boite(Color(0, 0, 0, 0), Color(CYAN, 0.6), 1)
	for type in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, survol)
		t.set_stylebox("pressed", type, appui)
		t.set_stylebox("hover_pressed", type, appui)
		t.set_stylebox("disabled", type, inactif)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXTE)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(TEXTE_DOUX, 0.4))
	for type in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", type, boite(Color(0, 0, 0, 0)))
		t.set_stylebox("pressed", type, boite(Color(0, 0, 0, 0)))
		t.set_stylebox("hover", type, boite(Color(1, 1, 1, 0.04)))
		t.set_stylebox("hover_pressed", type, boite(Color(1, 1, 1, 0.04)))
	t.set_color("font_color", "Label", TEXTE)
	t.set_stylebox("normal", "LineEdit", boite(Color(0.02, 0.03, 0.05, 0.9), Color(1, 1, 1, 0.12), 1, 4))
	t.set_stylebox("focus", "LineEdit", boite(Color(0, 0, 0, 0), CYAN, 1, 4))
	t.set_stylebox("panel", "PanelContainer", boite(FOND, Color(CYAN, 0.25), 1, 10))
	t.set_stylebox("panel", "PopupMenu", boite(Color(0.04, 0.06, 0.09, 0.98), Color(CYAN, 0.3), 1, 6))
	# Onglets.
	t.set_stylebox("panel", "TabContainer", boite(Color(0, 0, 0, 0)))
	t.set_stylebox("tab_selected", "TabContainer", boite(Color(0.06, 0.2, 0.25, 0.9), CYAN, 0, 4))
	t.set_stylebox("tab_unselected", "TabContainer", boite(Color(0.04, 0.06, 0.09, 0.6), Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("tab_hovered", "TabContainer", boite(Color(0.06, 0.12, 0.16, 0.8), Color(0, 0, 0, 0), 0, 4))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", TEXTE_DOUX)
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	# Curseurs.
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(1, 1, 1, 0.12)
	rail.set_corner_radius_all(3)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var rempli := rail.duplicate() as StyleBoxFlat
	rempli.bg_color = Color(CYAN, 0.8)
	t.set_stylebox("slider", "HSlider", rail)
	t.set_stylebox("grabber_area", "HSlider", rempli)
	t.set_stylebox("grabber_area_highlight", "HSlider", rempli)
	_theme = t
	return t


## Petit titre de section (majuscules espacées, cyan).
static func titre_section(texte: String) -> Label:
	var l := Label.new()
	l.text = texte.to_upper()
	l.add_theme_color_override("font_color", CYAN)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_constant_override("outline_size", 0)
	return l
