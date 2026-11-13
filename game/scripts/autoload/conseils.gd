extends Node
## Conseils pour les nouveaux joueurs (autoload « Conseils »).
##
## Petites bulles qui apparaissent à gauche de l'écran au bon moment
## (arrivée en ville, près d'un personnage, premier ennemi…). Chaque conseil
## ne s'affiche qu'une fois ; ceux déjà vus sont notés dans user://conseils.cfg
## (rangé dans le profil du joueur par Profil.chemin).
## Les textes et les moments viennent de data/conseils.json.
## On peut les couper dans Options > Jeu (Options.conseils).

const DONNEES := "res://data/conseils.json"
const FICHIER := "user://conseils.cfg"
const Style := preload("res://scripts/interface/style_menu.gd")

var conseils: Array = []
var _vus := {}
var _file: Array[Dictionary] = []
var _actuel := {}
var _temps_restant := 0.0
var _depart_bouge := Vector3.ZERO
var _attente := 0.0
var _scene_vue: Node
var _temps_scene := 0.0
var _verif := 0.0
var _profil_charge := ""

var _calque: CanvasLayer
var _bulle: PanelContainer
var _titre: Label
var _texte: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		conseils = lu.get("conseils", [])
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	_charger_vus()
	_construire()


## Les conseils vus suivent le personnage (profil hors ligne ou compte en ligne).
func _charger_vus() -> void:
	_profil_charge = Profil.nom
	_vus.clear()
	var cfg := ConfigFile.new()
	if cfg.load(Profil.chemin(FICHIER)) == OK and cfg.has_section("vus"):
		for id in cfg.get_section_keys("vus"):
			_vus[id] = true


# --- Vus / pas vus ----------------------------------------------------------

func deja_vu(id: String) -> bool:
	return _vus.has(id)


func marquer_vu(id: String) -> void:
	_vus[id] = true
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(FICHIER))
	cfg.set_value("vus", id, true)
	cfg.save(Profil.chemin(FICHIER))


## Options > Jeu > « Revoir tous les conseils ».
func tout_revoir() -> void:
	_vus.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profil.chemin(FICHIER)))
	Options.conseils = true
	Options.sauver()


func conseil(id: String) -> Dictionary:
	for c: Dictionary in conseils:
		if c.get("id", "") == id:
			return c
	return {}


## Affiche un conseil (s'il n'a pas déjà été vu et que les conseils sont activés).
## Utilisable depuis n'importe quel script : Conseils.montrer("mon_conseil").
func montrer(id: String) -> void:
	if not Options.conseils or deja_vu(id) or _actuel.get("id", "") == id:
		return
	for c in _file:
		if c.get("id", "") == id:
			return
	var c := conseil(id)
	if c.is_empty():
		return
	_file.append(c)


# --- Déclencheurs -----------------------------------------------------------

func _process(delta: float) -> void:
	if Profil.nom != _profil_charge:
		_charger_vus()
	var scene := get_tree().current_scene
	if scene != _scene_vue:
		_scene_vue = scene
		_temps_scene = 0.0
		_effacer()
	_temps_scene += delta
	_mettre_a_jour_bulle(delta)
	if not Options.conseils:
		return
	_verif -= delta
	if _verif > 0.0:
		return
	_verif = 0.25
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null or Options.menu_jeu_ouvert():
		return
	for c: Dictionary in conseils:
		var id: String = c.get("id", "")
		if deja_vu(id) or _actuel.get("id", "") == id:
			continue
		if _condition(String(c.get("quand", "")), joueur):
			montrer(id)


func _condition(quand: String, joueur: Node3D) -> bool:
	var intro := get_tree().get_first_node_in_group("voyage")
	var etape_intro := ""
	if intro != null and intro.has_method("etape_actuelle"):
		etape_intro = String(intro.etape_actuelle().get("id", ""))
	if quand.begins_with("apres:"):
		return deja_vu(quand.substr(6)) and _actuel.is_empty() and _file.is_empty()
	if quand.begins_with("etape:"):
		return etape_intro == quand.substr(6)
	match quand:
		"hub_debut":
			# L'ouverture de l'intro (écran noir, titre) dure environ 10 secondes.
			if intro == null:
				return false
			return _temps_scene > (11.0 if etape_intro != "" else 3.0)
		"hub_libre":
			return intro != null and etape_intro == "" and _temps_scene > 20.0
		"ile":
			return get_tree().get_first_node_in_group("ile") != null and _temps_scene > 4.0
		"pres_pnj":
			for p in get_tree().get_nodes_in_group("pnj"):
				if p is Node3D and (p as Node3D).is_visible_in_tree() \
						and (p as Node3D).global_position.distance_to(joueur.global_position) < 4.0:
					return true
			return false
		"ennemi_proche":
			for c in get_tree().get_nodes_in_group("combattants"):
				var acteur := c as Node3D
				if acteur == null or acteur.is_in_group("joueur") or acteur.is_in_group("pnj"):
					continue
				var combat = acteur.get_node_or_null("Combat")
				if combat != null and combat.has_method("est_vivant") and not combat.est_vivant():
					continue
				if acteur.global_position.distance_to(joueur.global_position) < 22.0:
					return true
			return false
		"premiere_cible":
			var cj := joueur.get_node_or_null("CombatJoueur")
			return cj != null and cj.get("cible") != null
		"pv_bas":
			var combat := joueur.get_node_or_null("Combat")
			if combat == null:
				return false
			var pv_max := float(combat.get("pv_max"))
			return pv_max > 0.0 and float(combat.get("pv")) > 0.0 and float(combat.get("pv")) < pv_max * 0.5
	return false


# --- Bulle ------------------------------------------------------------------

func _mettre_a_jour_bulle(delta: float) -> void:
	if not _actuel.is_empty():
		var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
		if _actuel.get("jusqua", "") == "bouge":
			if joueur != null and joueur.global_position.distance_to(_depart_bouge) > 6.0 and _temps_restant < 100.0:
				_temps_restant = minf(_temps_restant, 1.5)
		if not get_tree().paused:
			_temps_restant -= delta
		if _temps_restant <= 0.0:
			_cacher()
		return
	_attente -= delta
	if _attente > 0.0 or _file.is_empty() or not Options.conseils:
		return
	_afficher(_file.pop_front())


func _afficher(c: Dictionary) -> void:
	var id: String = c.get("id", "")
	if deja_vu(id):
		return
	_actuel = c
	marquer_vu(id)
	_titre.text = String(c.get("titre", "Conseil")).to_upper()
	_texte.text = remplacer_touches(String(c.get("texte", "")))
	# Le temps de lecture dépend de la longueur du texte.
	_temps_restant = clampf(5.0 + _texte.get_parsed_text().length() * 0.06, 7.0, 14.0)
	if c.get("jusqua", "") == "bouge":
		_temps_restant = 30.0
		var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
		_depart_bouge = joueur.global_position if joueur != null else Vector3.ZERO
	_bulle.visible = true
	_bulle.modulate.a = 0.0
	_bulle.position.x = -40.0
	var anim := create_tween().set_parallel()
	anim.tween_property(_bulle, "modulate:a", 1.0, 0.35)
	anim.tween_property(_bulle, "position:x", 24.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _cacher() -> void:
	_actuel = {}
	_attente = 1.2
	var anim := create_tween()
	anim.tween_property(_bulle, "modulate:a", 0.0, 0.4)
	anim.tween_callback(_cacher_bulle_si_libre)


func _cacher_bulle_si_libre() -> void:
	if _actuel.is_empty():
		_bulle.visible = false


func _effacer() -> void:
	_actuel = {}
	_file.clear()
	if _bulle != null:
		_bulle.visible = false


## Remplace {interagir}, {deplacement}… par les touches du joueur, en encadré.
func remplacer_touches(texte: String) -> String:
	var r := texte.replace("{deplacement}", _touche(Options.touches_deplacement()))
	r = r.replace("{echap}", _touche("Échap"))
	for a in Options.ACTIONS_MODIFIABLES:
		r = r.replace("{%s}" % a[0], _touche(Options.nom_touche(a[0])))
	return r


func _touche(nom: String) -> String:
	return "[bgcolor=#1d3a44][color=#8ff0ff][b] %s [/b][/color][/bgcolor]" % nom


func _construire() -> void:
	_calque = CanvasLayer.new()
	_calque.layer = 8
	add_child(_calque)
	_bulle = PanelContainer.new()
	_bulle.visible = false
	_bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle.custom_minimum_size = Vector2(380, 0)
	_bulle.anchor_top = 0.36
	_bulle.anchor_bottom = 0.36
	_bulle.position = Vector2(24, 0)
	var fond := Style.boite(Color(0.02, 0.04, 0.07, 0.86), Color(Style.CYAN, 0.5), 0, 8)
	fond.border_width_left = 3
	fond.content_margin_left = 16
	fond.content_margin_top = 10
	fond.content_margin_bottom = 12
	_bulle.add_theme_stylebox_override("panel", fond)
	_calque.add_child(_bulle)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle.add_child(colonne)
	_titre = Label.new()
	_titre.add_theme_font_override("font", Style.police())
	_titre.add_theme_font_size_override("font_size", 13)
	_titre.add_theme_color_override("font_color", Style.CYAN)
	colonne.add_child(_titre)
	_texte = RichTextLabel.new()
	_texte.bbcode_enabled = true
	_texte.fit_content = true
	_texte.scroll_active = false
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte.custom_minimum_size = Vector2(360, 0)
	_texte.add_theme_font_size_override("normal_font_size", 16)
	_texte.add_theme_font_size_override("bold_font_size", 16)
	_texte.add_theme_constant_override("line_separation", 4)
	colonne.add_child(_texte)
