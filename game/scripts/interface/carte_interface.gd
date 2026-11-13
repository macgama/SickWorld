extends CanvasLayer
## Affichage de la carte : mini-carte ronde en haut à droite, grande carte
## (touche M ou clic sur la mini-carte) et nom de la zone quand on y entre.
## Les données (zone, brouillard, repères) viennent de l'autoload Cartographe.

const SHADER := preload("res://shaders/carte.gdshader")
## Rayons (mètres) visibles sur la mini-carte, du plus proche au plus loin.
const ZOOMS := [30.0, 55.0, 90.0, 150.0]
const TAILLE_MINI := 196.0
const VIOLET := Color(0.62, 0.48, 1.0)
const COULEURS := {
	0: Color(0.92, 0.94, 1.0),   # lieu
	1: Color(1.0, 0.82, 0.2),    # quête
	2: Color(1.0, 0.82, 0.2),    # quête à rendre
	3: Color(0.98, 0.9, 0.45),   # personnage
	4: Color(1.0, 0.6, 0.25),    # marchand
	5: Color(0.72, 0.55, 1.0),   # portail
	6: Color(1.0, 0.3, 0.25),    # danger
	7: Color(0.35, 0.85, 1.0),   # balise
}
const NOMS_TYPES := ["Lieu", "Quête", "Quête à rendre", "Personnage", "Marchand", "Portail", "Danger", "Balise"]

var cartographe: Node
var _zoom := 1
var _mini: Control
var _mini_dessin: ColorRect
var _mini_reperes: Control
var _mini_nom: Label
var _grande: Control
var _grande_dessin: ColorRect
var _grande_reperes: Control
var _grande_titre: Label
var _grande_pied: Label
var _annonce: Label
var _annonce_tween: Tween
var _derniere_annonce := ""


func _ready() -> void:
	layer = 3
	cartographe = get_parent()
	_construire_mini()
	_construire_grande()
	_construire_annonce()
	cartographe.zone_changee.connect(_sur_zone_changee)
	_sur_zone_changee(null)


func _materiau(rond: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("rond", rond)
	return m


func _texte(taille: int, couleur := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _construire_mini() -> void:
	_mini = Control.new()
	_mini.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mini.position = Vector2(-TAILLE_MINI - 18, 34)
	_mini.size = Vector2(TAILLE_MINI, TAILLE_MINI + 26)
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mini)

	_mini_dessin = ColorRect.new()
	_mini_dessin.size = Vector2(TAILLE_MINI, TAILLE_MINI)
	_mini_dessin.material = _materiau(true)
	_mini_dessin.tooltip_text = "Carte (M)\nMolette : zoom"
	_mini_dessin.gui_input.connect(_sur_clic_mini)
	_mini.add_child(_mini_dessin)

	_mini_reperes = Control.new()
	_mini_reperes.size = _mini_dessin.size
	_mini_reperes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_reperes.draw.connect(_dessiner_mini)
	_mini.add_child(_mini_reperes)

	_mini_nom = _texte(15, Color(0.88, 0.85, 1.0))
	_mini_nom.position = Vector2(0, TAILLE_MINI + 2)
	_mini_nom.size = Vector2(TAILLE_MINI, 22)
	_mini_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mini.add_child(_mini_nom)

	for i in 2:
		var bouton := Button.new()
		bouton.text = "+" if i == 0 else "−"
		bouton.tooltip_text = "Zoomer" if i == 0 else "Dézoomer"
		bouton.focus_mode = Control.FOCUS_NONE
		bouton.size = Vector2(26, 26)
		bouton.position = Vector2(TAILLE_MINI - 26, TAILLE_MINI - 58 + i * 30)
		bouton.pressed.connect(_zoomer.bind(-1 if i == 0 else 1))
		_mini.add_child(bouton)


func _construire_grande() -> void:
	_grande = Control.new()
	_grande.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grande.visible = false
	_grande.mouse_filter = Control.MOUSE_FILTER_STOP
	_grande.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			afficher_grande_carte(false))
	add_child(_grande)
	var fond := ColorRect.new()
	fond.color = Color(0.01, 0.015, 0.03, 0.72)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grande.add_child(fond)

	_grande_dessin = ColorRect.new()
	_grande_dessin.material = _materiau(false)
	_grande_dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grande.add_child(_grande_dessin)
	_grande_reperes = Control.new()
	_grande_reperes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grande_reperes.draw.connect(_dessiner_grande)
	_grande.add_child(_grande_reperes)

	_grande_titre = _texte(30, Color(0.92, 0.88, 1.0))
	_grande_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grande.add_child(_grande_titre)
	_grande_pied = _texte(15, Color(0.8, 0.82, 0.9))
	_grande_pied.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grande.add_child(_grande_pied)
	get_viewport().size_changed.connect(_placer_grande)


func _construire_annonce() -> void:
	_annonce = _texte(36, Color(1.0, 0.9, 0.6))
	_annonce.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_annonce.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.position.y = 110
	_annonce.modulate.a = 0.0
	add_child(_annonce)


func _sur_zone_changee(zone: Node3D) -> void:
	visible = zone != null
	if zone == null:
		_grande.visible = false
		return
	_mini_nom.text = zone.nom_affiche
	_grande_titre.text = zone.nom_affiche
	for dessin in [_mini_dessin, _grande_dessin]:
		var m := dessin.material as ShaderMaterial
		m.set_shader_parameter("carte", cartographe.texture_carte)
		m.set_shader_parameter("relief", cartographe.texture_relief)
		m.set_shader_parameter("brouillard", cartographe.texture_brouillard)
	_placer_grande()
	if zone.identifiant != _derniere_annonce:
		_derniere_annonce = zone.identifiant
		_annoncer(zone.nom_affiche)


func _annoncer(texte: String) -> void:
	_annonce.text = texte
	if _annonce_tween != null:
		_annonce_tween.kill()
	_annonce_tween = create_tween()
	_annonce_tween.tween_property(_annonce, "modulate:a", 1.0, 0.6)
	_annonce_tween.tween_interval(2.2)
	_annonce_tween.tween_property(_annonce, "modulate:a", 0.0, 1.2)


func _zoomer(sens: int) -> void:
	_zoom = clampi(_zoom + sens, 0, ZOOMS.size() - 1)


func _sur_clic_mini(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_LEFT:
				if (e.position - _mini_dessin.size * 0.5).length() < TAILLE_MINI * 0.5:
					afficher_grande_carte(true)
					_mini_dessin.accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				_zoomer(-1)
				_mini_dessin.accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoomer(1)
				_mini_dessin.accept_event()


func afficher_grande_carte(oui: bool) -> void:
	_grande.visible = oui and cartographe.zone != null
	_placer_grande()


func grande_carte_ouverte() -> bool:
	return _grande.visible


func _unhandled_input(event: InputEvent) -> void:
	if cartographe.zone == null:
		return
	if event.is_action_pressed("carte"):
		afficher_grande_carte(not _grande.visible)
		get_viewport().set_input_as_handled()
	elif _grande.visible and event.is_action_pressed("annuler"):
		afficher_grande_carte(false)
		get_viewport().set_input_as_handled()


func _placer_grande() -> void:
	var zone: Node3D = cartographe.zone
	if zone == null:
		return
	var ecran := get_viewport().get_visible_rect().size
	var place := ecran * Vector2(0.8, 0.72)
	var rapport: float = zone.taille.x / zone.taille.z
	var taille := Vector2(place.y * rapport, place.y)
	if taille.x > place.x:
		taille = Vector2(place.x, place.x / rapport)
	var coin := (ecran - taille) * 0.5 - Vector2(0, 20)
	_grande_dessin.position = coin
	_grande_dessin.size = taille
	_grande_reperes.position = coin
	_grande_reperes.size = taille
	_grande_titre.position = Vector2(0, coin.y - 74)
	_grande_titre.size = Vector2(ecran.x, 40)
	_grande_pied.position = Vector2(0, coin.y - 32)
	_grande_pied.size = Vector2(ecran.x, 24)


func _process(_delta: float) -> void:
	var zone: Node3D = cartographe.zone
	if zone == null:
		return
	var joueur: Node3D = cartographe.joueur_local()
	var centre := Vector2(0.5, 0.5)
	if joueur != null:
		centre = zone.vers_carte(joueur.global_position)
	var rayon: float = ZOOMS[_zoom]
	var m := _mini_dessin.material as ShaderMaterial
	m.set_shader_parameter("centre", centre)
	m.set_shader_parameter("etendue", Vector2(2.0 * rayon / zone.taille.x, 2.0 * rayon / zone.taille.z))
	# La photo de la zone peut arriver un peu après l'entrée dans la zone.
	if m.get_shader_parameter("carte") != cartographe.texture_carte:
		_sur_zone_changee(zone)
	_mini_reperes.queue_redraw()
	if _grande.visible:
		_grande_pied.text = "Exploré : %d %%     ·     M ou Échap : fermer" % roundi(cartographe.part_exploree() * 100.0)
		_grande_reperes.queue_redraw()


# --- Dessin des repères ----------------------------------------------------------

func _dessiner_mini() -> void:
	var zone: Node3D = cartographe.zone
	var joueur: Node3D = cartographe.joueur_local()
	if zone == null or joueur == null:
		return
	var taille := _mini_reperes.size
	var centre: Vector2 = zone.vers_carte(joueur.global_position)
	var rayon: float = ZOOMS[_zoom]
	var etendue := Vector2(2.0 * rayon / zone.taille.x, 2.0 * rayon / zone.taille.z)
	var police := ThemeDB.fallback_font
	_mini_reperes.draw_string_outline(police, Vector2(taille.x * 0.5 - 5, 17), "N",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	_mini_reperes.draw_string(police, Vector2(taille.x * 0.5 - 5, 17), "N",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.85, 1.0))
	for r in cartographe.marqueurs():
		if not r["mini"]:
			continue
		var local: Vector2 = (zone.vers_carte(r["position"]) - centre) / etendue
		if local.length() > 0.44:
			if not r["toujours"]:
				continue
			local = local.normalized() * 0.44
		_icone(_mini_reperes, (local + Vector2(0.5, 0.5)) * taille, r["type"], 6.0)
	_dessiner_autres_joueurs(_mini_reperes, func(p: Vector3):
		var l: Vector2 = (zone.vers_carte(p) - centre) / etendue
		return (l + Vector2(0.5, 0.5)) * taille if l.length() < 0.45 else Vector2.INF)
	_fleche(_mini_reperes, taille * 0.5, joueur, 9.0)


func _dessiner_grande() -> void:
	var zone: Node3D = cartographe.zone
	if zone == null:
		return
	var taille := _grande_reperes.size
	var police := ThemeDB.fallback_font
	var vers_ecran := func(p: Vector3) -> Vector2: return zone.vers_carte(p) * taille
	var types_vus := {}
	for r in cartographe.marqueurs():
		var point: Vector2 = vers_ecran.call(r["position"])
		_icone(_grande_reperes, point, r["type"], 8.0)
		types_vus[r["type"]] = true
		if r["libelle"] != "":
			var largeur := police.get_string_size(r["libelle"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var ou := point + Vector2(-largeur * 0.5, -13)
			_grande_reperes.draw_string_outline(police, ou, r["libelle"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
			_grande_reperes.draw_string(police, ou, r["libelle"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COULEURS[r["type"]].lightened(0.3))
	_dessiner_autres_joueurs(_grande_reperes, vers_ecran)
	var joueur: Node3D = cartographe.joueur_local()
	if joueur != null:
		_fleche(_grande_reperes, vers_ecran.call(joueur.global_position), joueur, 12.0)
	# Légende des repères présents.
	var y := 8.0
	for type in types_vus.keys():
		_icone(_grande_reperes, Vector2(taille.x + 22, y + 8), type, 7.0)
		_grande_reperes.draw_string_outline(police, Vector2(taille.x + 36, y + 13), NOMS_TYPES[type],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		_grande_reperes.draw_string(police, Vector2(taille.x + 36, y + 13), NOMS_TYPES[type],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.92))
		y += 24.0


func _dessiner_autres_joueurs(sur: Control, vers_ecran: Callable) -> void:
	for j in get_tree().get_nodes_in_group("joueur"):
		if j is Node3D and not j.is_in_group("joueur_local") and cartographe.zone.contient(j.global_position):
			var point: Vector2 = vers_ecran.call(j.global_position)
			if point != Vector2.INF:
				sur.draw_circle(point, 5.0, Color(0.1, 0.1, 0.15))
				sur.draw_circle(point, 3.8, Color(0.35, 0.65, 1.0))


func _fleche(sur: Control, point: Vector2, joueur: Node3D, taille: float) -> void:
	var avant3 := -joueur.global_transform.basis.z
	var avant := Vector2(avant3.x, avant3.z)
	avant = avant.normalized() if avant.length() > 0.01 else Vector2.UP
	var cote := Vector2(-avant.y, avant.x)
	var pointe := point + avant * taille
	var gauche := point - avant * taille * 0.7 + cote * taille * 0.75
	var droite := point - avant * taille * 0.7 - cote * taille * 0.75
	var creux := point - avant * taille * 0.3
	var forme := PackedVector2Array([pointe, gauche, creux, droite])
	sur.draw_colored_polygon(forme, Color(1.0, 0.92, 0.55))
	sur.draw_polyline(PackedVector2Array([pointe, gauche, creux, droite, pointe]), Color(0.1, 0.08, 0.02), 1.5, true)


func _icone(sur: Control, p: Vector2, type: int, t: float) -> void:
	var c: Color = COULEURS.get(type, Color.WHITE)
	var sombre := Color(0.05, 0.05, 0.08, 0.9)
	var police := ThemeDB.fallback_font
	match type:
		1, 2, 4:
			var signe: String = {1: "!", 2: "?", 4: "¥"}[type]
			sur.draw_circle(p, t + 1.5, sombre)
			sur.draw_circle(p, t, c.darkened(0.55))
			var l := police.get_string_size(signe, HORIZONTAL_ALIGNMENT_LEFT, -1, int(t * 2.0)).x
			sur.draw_string(police, p + Vector2(-l * 0.5, t * 0.7), signe, HORIZONTAL_ALIGNMENT_LEFT, -1, int(t * 2.0), c)
		3:
			sur.draw_circle(p, t * 0.75, sombre)
			sur.draw_circle(p, t * 0.55, c)
		5:
			sur.draw_circle(p, t + 1.0, sombre)
			sur.draw_arc(p, t * 0.8, 0.0, TAU, 20, c, 2.5, true)
			sur.draw_circle(p, t * 0.35, c.lightened(0.4))
		6:
			var tri := PackedVector2Array([p + Vector2(0, -t), p + Vector2(t * 0.95, t * 0.75), p + Vector2(-t * 0.95, t * 0.75)])
			sur.draw_colored_polygon(tri, c)
			sur.draw_polyline(tri + PackedVector2Array([tri[0]]), sombre, 1.5, true)
		_:
			var losange := PackedVector2Array([p + Vector2(0, -t), p + Vector2(t * 0.8, 0), p + Vector2(0, t), p + Vector2(-t * 0.8, 0)])
			sur.draw_colored_polygon(losange, c)
			sur.draw_polyline(losange + PackedVector2Array([losange[0]]), sombre, 1.5, true)
