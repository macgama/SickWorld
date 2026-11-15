extends Node3D
## Une trière à l'entraînement dans le bassin du Pirée (île de Grèce, chapitre 2).
##
## La quête l'appelle ({"appeler": "triere_paralos", "methode": "partir"}) : le joueur
## est posé sur le pont, et le joueur rame avec l'équipage. Un joueur de flûte (l'aulète)
## donne la cadence : il faut appuyer sur F au moment où la note tombe (quand la jauge
## est pleine). Un coup en cadence fait bien avancer le navire, un coup à contretemps
## presque pas. Au bout du tour du bassin, l'étape « triere_cadence » est terminée.
##
## La trière a les mêmes règles que le halage de l'Égypte : plus on est en rythme,
## plus on avance. (En multijoueur, plus tard : chaque joueur à bord compterait.)

## L'identifiant de l'étape de quête terminée à la fin du tour.
var identifiant := "triere_cadence"
## Points (x, z) que la trière suit (un tour du bassin, retour au quai).
var chemin: Array = []
## Une note de flûte toutes les « battement » secondes.
var battement := 1.3
## Marge (secondes) autour de la note pour un coup en cadence.
var tolerance := 0.3
## Mètres gagnés par un coup en cadence, et par un coup raté.
var avance_cadence := 7.0
var avance_ratee := 1.5
## Le nœud de la trière (fabriqué par la zone) dont on anime les rames.
var navire: Node3D
## Ce que crie l'équipage : [part du trajet (0 à 1), titre, texte].
var paroles: Array = []

var en_route := false
var coups_en_cadence := 0
var coups_rates := 0
var _phase := 0.0
var _frappe_ce_battement := false
var _parcouru := 0.0
var _cible := 0.0
var _longueur_chemin := 0.0
var _temps := 0.0
var _coup := 0.0
var _paroles_dites := 0
var _pont: AnimatableBody3D
var _interface: CanvasLayer
var _jauge: ProgressBar
var _texte: Label
var _score: Label


func _ready() -> void:
	set_meta("identifiant", "triere_paralos")
	add_to_group("decor_quete")
	_pont = AnimatableBody3D.new()
	_pont.name = "Pont"
	_pont.sync_to_physics = true
	var formes := [
		[Vector3(5.0, 0.3, 26.0), Vector3(0, 2.2, -0.5)],
		# Bastingages invisibles : on ne tombe pas par mégarde.
		[Vector3(0.2, 1.6, 26.0), Vector3(-2.6, 3.0, -0.5)],
		[Vector3(0.2, 1.6, 26.0), Vector3(2.6, 3.0, -0.5)],
		[Vector3(5.2, 1.6, 0.2), Vector3(0, 3.0, -13.5)],
		[Vector3(5.2, 1.6, 0.2), Vector3(0, 3.0, 12.5)],
	]
	for f in formes:
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = f[0]
		forme.shape = boite
		forme.position = f[1]
		_pont.add_child(forme)
	add_child(_pont)
	_longueur_chemin = 0.0
	for i in range(1, chemin.size()):
		_longueur_chemin += (chemin[i] as Vector2).distance_to(chemin[i - 1])


## Appelé par la quête. anime = faux quand on recharge une partie : rien à faire.
func partir(anime: bool) -> void:
	if not anime or en_route or chemin.size() < 2:
		return
	en_route = true
	_parcouru = 0.0
	_cible = 0.0
	_phase = 0.0
	_paroles_dites = 0
	coups_en_cadence = 0
	coups_rates = 0
	_monter_a_bord()
	_construire_interface()


func _monter_a_bord() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	joueur.set_meta("a_bord", true)
	var p := global_transform * Vector3(0, 2.7, 4.0)
	if joueur.has_method("teleporter"):
		joueur.teleporter(p, rotation.y)
	else:
		joueur.global_position = p


## Vrai si un coup donné maintenant tomberait en cadence.
func en_cadence() -> bool:
	return minf(_phase, battement - _phase) <= tolerance and not _frappe_ce_battement


## Un coup de rame (F). Renvoie vrai s'il était en cadence.
func ramer() -> bool:
	if not en_route:
		return false
	var bon := en_cadence()
	_frappe_ce_battement = true
	_coup = 0.6
	if bon:
		coups_en_cadence += 1
		_cible += avance_cadence
		_texte.text = ["En cadence !", "Ensemble !", "Rho-ppa-pai !", "Bien !"][coups_en_cadence % 4]
		_texte.modulate = Color(0.6, 1.0, 0.7)
	else:
		coups_rates += 1
		_cible += avance_ratee
		_texte.text = "À contretemps… attends la note de la flûte."
		_texte.modulate = Color(1.0, 0.7, 0.5)
	_score.text = "Coups en cadence : %d" % coups_en_cadence
	return bon


func _unhandled_input(event: InputEvent) -> void:
	if not en_route or not event.is_action_pressed("interagir"):
		return
	get_viewport().set_input_as_handled()
	ramer()


func _physics_process(delta: float) -> void:
	_temps += delta
	if not en_route:
		rotation.z = sin(_temps * 0.8) * 0.006
		position.y = -0.15 + sin(_temps * 1.1) * 0.03
		return
	var avant := _phase
	_phase = fmod(_phase + delta, battement)
	if _phase < avant:
		# Une nouvelle note : on peut frapper à nouveau.
		_frappe_ce_battement = false
	# Une note passée sans coup de rame : un coup « raté » de l'équipage seul.
	if avant < battement * 0.5 and _phase >= battement * 0.5 and not _frappe_ce_battement:
		_cible += avance_ratee * 0.5
	if _jauge != null:
		_jauge.value = (_phase / battement) * 100.0 if _phase > tolerance else 100.0
	_parcouru = move_toward(_parcouru, _cible, delta * maxf(2.0, (_cible - _parcouru) * 1.6))
	var p := _point(_parcouru)
	var devant := _point(_parcouru + 6.0)
	var direction := devant - p
	global_position = Vector3(p.x, -0.15 + sin(_temps * 1.3) * 0.04, p.y)
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.y), clampf(delta * 1.2, 0.0, 1.0))
	rotation.z = sin(_temps * 0.9) * 0.012
	_animer_rames(delta)
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null and joueur.global_position.distance_to(global_transform * Vector3(0, 2.7, 0)) > 15.0:
		_monter_a_bord()
	var part := _parcouru / maxf(_longueur_chemin, 1.0)
	while _paroles_dites < paroles.size() and part >= float(paroles[_paroles_dites][0]):
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("_annoncer"):
			quete._annoncer(String(paroles[_paroles_dites][1]), String(paroles[_paroles_dites][2]))
		_paroles_dites += 1
	if _parcouru >= _longueur_chemin - 0.5:
		_arriver()


func _animer_rames(delta: float) -> void:
	if navire == null:
		return
	_coup = maxf(0.0, _coup - delta)
	# Le coup de rame : la pale plonge et tire vers l'arrière, puis revient.
	var f := sin((1.0 - _coup / 0.6) * PI) if _coup > 0.0 else 0.0
	for pivot in navire.get_meta("rames", []):
		var cote: float = pivot.get_meta("cote", 1.0)
		pivot.rotation.y = -cote * (f * 0.5 - 0.15)
		pivot.rotation.x = f * 0.12


func _arriver() -> void:
	en_route = false
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.remove_meta("a_bord")
	if _interface != null:
		_interface.queue_free()
		_interface = null
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and quete.has_method("utiliser_objet"):
		quete.utiliser_objet(self)


func _point(distance: float) -> Vector2:
	var reste := maxf(distance, 0.0)
	for i in range(1, chemin.size()):
		var a: Vector2 = chemin[i - 1]
		var b: Vector2 = chemin[i]
		var l := a.distance_to(b)
		if reste <= l:
			return a.lerp(b, reste / maxf(l, 0.001))
		reste -= l
	return chemin[-1]


func _construire_interface() -> void:
	if _interface != null:
		return
	_interface = CanvasLayer.new()
	_interface.name = "Cadence"
	add_child(_interface)
	var cadre := PanelContainer.new()
	cadre.anchor_left = 0.5
	cadre.anchor_right = 0.5
	cadre.anchor_top = 1.0
	cadre.anchor_bottom = 1.0
	cadre.offset_left = -260
	cadre.offset_right = 260
	cadre.offset_top = -210
	cadre.offset_bottom = -110
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.82)
	style.border_color = Color(0.85, 0.7, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	cadre.add_theme_stylebox_override("panel", style)
	_interface.add_child(cadre)
	var boite := VBoxContainer.new()
	cadre.add_child(boite)
	var titre := Label.new()
	titre.text = "Rame en cadence : appuie sur F quand la jauge est pleine (la note de la flûte)"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite.add_child(titre)
	_jauge = ProgressBar.new()
	_jauge.show_percentage = false
	_jauge.custom_minimum_size = Vector2(0, 16)
	boite.add_child(_jauge)
	_texte = Label.new()
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(_texte)
	_score = Label.new()
	_score.text = "Coups en cadence : 0"
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.modulate = Color(0.85, 0.85, 0.85)
	boite.add_child(_score)
