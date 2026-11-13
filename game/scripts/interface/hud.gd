extends CanvasLayer
## Interface affichée par-dessus le jeu : aide des touches, endurance, images par seconde.

const TEXTE_AIDE := """[b]Contrôles[/b]  (F1 pour cacher)
[b]Z Q S D[/b] ou [b]W A S D[/b] : avancer, tourner, reculer
[b]A / E[/b] : pas de côté
[b]Clic droit maintenu[/b] : orienter le personnage à la souris
[b]Clic gauche maintenu[/b] : tourner la caméra
[b]Les deux clics[/b] : avancer
[b]Molette[/b] : zoom
[b]Espace[/b] : sauter     [b]Maj[/b] : roulade d'esquive"""

var _aide: RichTextLabel
var _endurance: ProgressBar
var _images: Label


func _ready() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)

	var fond := PanelContainer.new()
	fond.position = Vector2(16, 16)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.7)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	fond.add_theme_stylebox_override("panel", style)
	racine.add_child(fond)
	_aide = RichTextLabel.new()
	_aide.bbcode_enabled = true
	_aide.fit_content = true
	_aide.custom_minimum_size = Vector2(430, 0)
	_aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aide.text = TEXTE_AIDE
	fond.add_child(_aide)

	_endurance = ProgressBar.new()
	_endurance.show_percentage = false
	_endurance.custom_minimum_size = Vector2(260, 12)
	_endurance.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_endurance.position = Vector2(-130, -40)
	_endurance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(0.95, 0.75, 0.25)
	plein.set_corner_radius_all(4)
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color(0, 0, 0, 0.55)
	vide.set_corner_radius_all(4)
	_endurance.add_theme_stylebox_override("fill", plein)
	_endurance.add_theme_stylebox_override("background", vide)
	racine.add_child(_endurance)

	_images = Label.new()
	_images.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_images.position = Vector2(-110, 16)
	_images.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_images)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("aide"):
		_aide.get_parent().visible = not _aide.get_parent().visible


func _process(_delta: float) -> void:
	_images.text = "%d images/s" % Engine.get_frames_per_second()
	var joueur := get_tree().get_first_node_in_group("joueur")
	if joueur != null:
		_endurance.max_value = joueur.endurance_max
		_endurance.value = joueur.endurance
		_endurance.modulate.a = 0.35 if joueur.endurance >= joueur.endurance_max else 1.0
