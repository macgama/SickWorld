extends Node
## Réglages du joueur (autoload « Options »), enregistrés dans user://options.cfg.
##
## - Son : volume de chaque bus audio (Master, Musique, Ambiance, Effets, Interface).
##   Les bus sont créés par le son (default_bus_layout.tres) ; un bus qui
##   n'existe pas encore est simplement ignoré, puis réglé dès qu'il apparaît.
## - Affichage : plein écran, synchronisation verticale, limite d'images/seconde.
## - Caméra : sensibilité de la souris et champ de vision (appliqués à chaque
##   caméra de joueur qui apparaît).
## - Touches : une touche principale par action, qui remplace celle de
##   l'autoload Controles (les touches secondaires, comme les flèches, restent).
## - Conseils : afficher ou non les conseils pour débutants (autoload Conseils).
##
## Échap en jeu ouvre le menu de jeu (Reprendre, Options, Menu principal, Quitter),
## sauf si Échap a déjà servi à autre chose (enlever la cible, fermer une fenêtre).

signal change

const FICHIER := "user://options.cfg"
const MENU_JEU := "res://scripts/interface/menu_jeu.gd"

## [nom du bus, nom affiché]
const BUS := [
	["Master", "Volume général"],
	["Musique", "Musique"],
	["Ambiance", "Ambiance (pluie, vent, ville)"],
	["Effets", "Effets (combat, pas)"],
	["Interface", "Interface (clics)"],
]

## Actions que le joueur peut changer : [action, nom affiché].
const ACTIONS_MODIFIABLES := [
	["avancer", "Avancer"],
	["reculer", "Reculer"],
	["tourner_gauche", "Tourner à gauche"],
	["tourner_droite", "Tourner à droite"],
	["pas_gauche", "Pas de côté à gauche"],
	["pas_droite", "Pas de côté à droite"],
	["sauter", "Sauter"],
	["esquive", "Roulade d'esquive"],
	["interagir", "Parler / ramasser"],
	["cible_suivante", "Cibler l'ennemi suivant"],
	["journal", "Journal des missions"],
	["carte", "Carte"],
	["personnage", "Personnage et sacs"],
	["aide", "Aide des contrôles"],
	["competence_1", "Compétence 1"], ["competence_2", "Compétence 2"],
	["competence_3", "Compétence 3"], ["competence_4", "Compétence 4"],
	["competence_5", "Compétence 5"], ["competence_6", "Compétence 6"],
	["competence_7", "Compétence 7"], ["competence_8", "Compétence 8"],
]

const MODES_ECRAN := ["Fenêtre", "Plein écran (fenêtre sans bordure)", "Plein écran exclusif"]
const LIMITES_IMAGES := [0, 30, 60, 120, 144, 165, 240]

var volumes := {"Master": 0.8, "Musique": 0.7, "Ambiance": 0.8, "Effets": 0.9, "Interface": 0.7}
var mode_ecran := 0
var vsync := true
var limite_images := 0
var sensibilite := 0.25
var champ_de_vision := 70.0
var conseils := true
## action -> touche physique choisie par le joueur (Key)
var touches := {}

var _menu_jeu
## Touches d'origine (Controles) gardées pour « Touches par défaut ».
var _touches_origine := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	charger()
	for a in ACTIONS_MODIFIABLES:
		var ev := premiere_touche(a[0])
		if ev != null:
			_touches_origine[a[0]] = ev.duplicate()
	for action: String in touches:
		_poser_touche(action, int(touches[action]))
	AudioServer.bus_layout_changed.connect(appliquer_son)
	get_tree().node_added.connect(_sur_noeud_ajoute)
	appliquer_son()
	if DisplayServer.get_name() != "headless":
		appliquer_affichage.call_deferred()
	_menu_jeu = load(MENU_JEU).new()
	add_child(_menu_jeu)


# --- Lecture / écriture ---------------------------------------------------

func charger() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) != OK:
		return
	for b in BUS:
		volumes[b[0]] = clampf(float(cfg.get_value("son", b[0], volumes[b[0]])), 0.0, 1.0)
	mode_ecran = clampi(int(cfg.get_value("affichage", "mode", mode_ecran)), 0, 2)
	vsync = bool(cfg.get_value("affichage", "vsync", vsync))
	limite_images = int(cfg.get_value("affichage", "limite_images", limite_images))
	sensibilite = clampf(float(cfg.get_value("camera", "sensibilite", sensibilite)), 0.05, 1.0)
	champ_de_vision = clampf(float(cfg.get_value("camera", "champ_de_vision", champ_de_vision)), 50.0, 110.0)
	conseils = bool(cfg.get_value("jeu", "conseils", conseils))
	if cfg.has_section("touches"):
		for action in cfg.get_section_keys("touches"):
			touches[action] = int(cfg.get_value("touches", action))


func sauver() -> void:
	var cfg := ConfigFile.new()
	for b in BUS:
		cfg.set_value("son", b[0], volumes[b[0]])
	cfg.set_value("affichage", "mode", mode_ecran)
	cfg.set_value("affichage", "vsync", vsync)
	cfg.set_value("affichage", "limite_images", limite_images)
	cfg.set_value("camera", "sensibilite", sensibilite)
	cfg.set_value("camera", "champ_de_vision", champ_de_vision)
	cfg.set_value("jeu", "conseils", conseils)
	for action: String in touches:
		cfg.set_value("touches", action, touches[action])
	cfg.save(FICHIER)
	change.emit()


# --- Son ------------------------------------------------------------------

func regler_volume(bus: String, valeur: float) -> void:
	volumes[bus] = clampf(valeur, 0.0, 1.0)
	appliquer_son()


func appliquer_son() -> void:
	for b in BUS:
		var i := AudioServer.get_bus_index(b[0])
		if i < 0:
			continue
		var v: float = volumes[b[0]]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# --- Affichage ------------------------------------------------------------

func appliquer_affichage() -> void:
	match mode_ecran:
		0:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = limite_images


# --- Caméra ---------------------------------------------------------------

func _sur_noeud_ajoute(n: Node) -> void:
	if n is Camera3D and "sensibilite" in n and "distance_max" in n:
		_regler_camera.call_deferred(n)


func _regler_camera(c: Camera3D) -> void:
	if not is_instance_valid(c):
		return
	c.set("sensibilite", sensibilite)
	c.fov = champ_de_vision


func appliquer_camera() -> void:
	for c in get_tree().root.find_children("*", "Camera3D", true, false):
		if "sensibilite" in c and "distance_max" in c:
			_regler_camera(c)


# --- Touches --------------------------------------------------------------

func premiere_touche(action: String) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev
	return null


## Nom lisible de la touche principale d'une action (ex. « Z » sur AZERTY).
func nom_touche(action: String) -> String:
	return nom_evenement(premiere_touche(action))


func nom_evenement(ev: InputEventKey) -> String:
	if ev == null:
		return "—"
	var code: Key = ev.keycode
	if ev.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
		code = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
		if code == KEY_NONE:
			code = ev.physical_keycode
	elif ev.physical_keycode != KEY_NONE:
		code = ev.physical_keycode
	return traduire_touche(OS.get_keycode_string(code))


## Les quatre touches de déplacement, dans l'ordre du clavier (ex. « Z Q S D »).
func touches_deplacement() -> String:
	return "%s %s %s %s" % [nom_touche("avancer"), nom_touche("tourner_gauche"),
			nom_touche("reculer"), nom_touche("tourner_droite")]


func traduire_touche(t: String) -> String:
	const NOMS := {"Space": "Espace", "Shift": "Maj", "Escape": "Échap", "Enter": "Entrée",
		"Up": "Flèche haut", "Down": "Flèche bas", "Left": "Flèche gauche", "Right": "Flèche droite",
		"Ctrl": "Ctrl", "Backspace": "Retour arrière", "Tab": "Tab", "CapsLock": "Verr. Maj"}
	return NOMS.get(t, t)


## Change la touche principale d'une action. Renvoie le nom de l'autre action
## qui utilisait déjà cette touche (elle la perd), ou "" si aucune.
func changer_touche(action: String, physique: int) -> String:
	var ancienne := ""
	for a in ACTIONS_MODIFIABLES:
		if a[0] == action:
			continue
		var ev := premiere_touche(a[0])
		if ev != null and _code_physique(ev) == physique:
			ancienne = a[1]
			# L'autre action récupère l'ancienne touche de celle-ci (échange).
			var mienne := premiere_touche(action)
			if mienne != null:
				touches[a[0]] = _code_physique(mienne)
				_poser_touche(a[0], _code_physique(mienne))
	touches[action] = physique
	_poser_touche(action, physique)
	sauver()
	return ancienne


func touches_par_defaut() -> void:
	touches.clear()
	for action: String in _touches_origine:
		var ev: InputEventKey = _touches_origine[action]
		var actuelle := premiere_touche(action)
		if actuelle != null:
			InputMap.action_erase_event(action, actuelle)
		_inserer_en_premier(action, ev.duplicate())
	sauver()


func _code_physique(ev: InputEventKey) -> int:
	if ev.physical_keycode != KEY_NONE:
		return ev.physical_keycode
	return ev.keycode


func _poser_touche(action: String, physique: int) -> void:
	if not InputMap.has_action(action):
		return
	var actuelle := premiere_touche(action)
	if actuelle != null:
		InputMap.action_erase_event(action, actuelle)
	var ev := InputEventKey.new()
	ev.physical_keycode = physique as Key
	_inserer_en_premier(action, ev)


func _inserer_en_premier(action: String, ev: InputEvent) -> void:
	var autres := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for e in autres:
		InputMap.action_add_event(action, e)


# --- Menu de jeu (Échap) ----------------------------------------------------

func _unhandled_input(evenement: InputEvent) -> void:
	if not evenement.is_action_pressed("annuler"):
		return
	if get_tree().get_first_node_in_group("joueur_local") == null:
		return
	_menu_jeu.basculer()
	get_viewport().set_input_as_handled()


func menu_jeu_ouvert() -> bool:
	return _menu_jeu != null and _menu_jeu.visible
