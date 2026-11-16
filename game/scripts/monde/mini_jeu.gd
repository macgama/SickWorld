extends CanvasLayer
## Petits jeux d'adresse des quêtes (kottabos, javelot, dressage, chœur…).
##
## Deux sortes, réglées dans les fichiers de quêtes (clé « mini_jeu » d'une étape) :
## - « jauge » : un curseur file d'un bout à l'autre d'une barre ; on appuie sur F quand il
##   passe dans la zone verte. Quelques essais, il faut en réussir un certain nombre.
##   (Le kottabos : lancer la dernière goutte de sa coupe sur la cible ; le javelot ;
##   calmer un poulain au bon moment.)
## - « rythme » : le chœur danse ; une flèche s'affiche et un cercle se resserre dessus.
##   On appuie sur la bonne direction (Z Q S D ou les flèches) quand le cercle touche la flèche.
##
## Réglages possibles : titre, consigne, essais, reussites, vitesse (allers-retours par
## seconde), zone (largeur de la zone verte, de 0 à 1), nombre (pas de danse), periode
## (secondes par pas), reussite / echec (textes de fin).
## Pendant le jeu, le personnage ne bouge pas ; Échap abandonne.

signal fini(reussi: bool)

const VERT := Color(0.35, 0.85, 0.45)
const OR := Color(1.0, 0.82, 0.35)
const ROUGE := Color(0.95, 0.35, 0.3)
const DIRECTIONS := {
	"avancer": ["↑", "Z"],
	"reculer": ["↓", "S"],
	"tourner_gauche": ["←", "Q"],
	"tourner_droite": ["→", "D"],
}

var config: Dictionary = {}
var type := "jauge"
## Réussites et essais faits jusqu'ici.
var score := 0
var faits := 0
var termine := false

var _essais := 3
var _reussites := 2
# Jauge.
var _curseur := 0.0
var _sens := 1.0
var _vitesse := 0.8
var _centre := 0.5
var _largeur := 0.16
# Rythme.
var _pas: Array[String] = []
var _temps_pas := 0.0
var _periode := 1.0
var _attend := true
var _resultats: Array[bool] = []
# Petit message après chaque essai (« Dans la coupe ! »).
var _pause := 0.0
var _hasard := RandomNumberGenerator.new()

var _titre: Label
var _consigne: Label
var _dessin: Control
var _resultat: Label
var _compte: Label


## Ouvre un mini-jeu à l'écran ; « fini » dit si on l'a réussi.
static func lancer(arbre: SceneTree, reglages: Dictionary) -> Node:
	var jeu = load("res://scripts/monde/mini_jeu.gd").new()
	jeu.config = reglages
	arbre.root.add_child(jeu)
	return jeu


static func en_cours(arbre: SceneTree) -> bool:
	return arbre.has_group("mini_jeu_en_cours")


func _ready() -> void:
	layer = 12
	add_to_group("mini_jeu_en_cours")
	_hasard.randomize()
	type = String(config.get("type", "jauge"))
	_essais = int(config.get("essais", 3 if type == "jauge" else 8))
	_reussites = int(config.get("reussites", 2 if type == "jauge" else 6))
	_vitesse = float(config.get("vitesse", 0.8))
	_largeur = float(config.get("zone", 0.16))
	_periode = float(config.get("periode", 1.0))
	if type == "rythme":
		_essais = int(config.get("nombre", _essais))
		for i in _essais:
			_pas.append(DIRECTIONS.keys()[_hasard.randi() % DIRECTIONS.size()])
	_construire()
	_nouvel_essai()


func _construire() -> void:
	var cadre := PanelContainer.new()
	cadre.anchor_left = 0.5
	cadre.anchor_right = 0.5
	cadre.anchor_top = 0.62
	cadre.anchor_bottom = 0.62
	cadre.offset_left = -260
	cadre.offset_right = 260
	cadre.offset_top = -10
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.82)
	style.border_color = Color(OR, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	cadre.add_theme_stylebox_override("panel", style)
	add_child(cadre)
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 8)
	cadre.add_child(liste)
	_titre = _etiquette(String(config.get("titre", "")), 20, OR)
	liste.add_child(_titre)
	_consigne = _etiquette(_texte_consigne(), 14, Color(0.9, 0.9, 0.9))
	_consigne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consigne.custom_minimum_size.x = 480
	liste.add_child(_consigne)
	_dessin = Control.new()
	_dessin.custom_minimum_size = Vector2(480, 120 if type == "rythme" else 46)
	_dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dessin.draw.connect(_dessiner)
	liste.add_child(_dessin)
	_resultat = _etiquette("", 17, Color.WHITE)
	_resultat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	liste.add_child(_resultat)
	_compte = _etiquette("", 13, Color(0.8, 0.8, 0.8))
	liste.add_child(_compte)
	_maj_compte()


func _texte_consigne() -> String:
	if config.has("consigne"):
		return String(config.consigne)
	if type == "rythme":
		return "Appuie sur la bonne direction (Z Q S D ou les flèches) quand le cercle touche la flèche."
	return "Appuie sur F quand le curseur passe dans la zone verte."


func _maj_compte() -> void:
	if _compte != null:
		_compte.text = "Réussis : %d / %d   ·   Essais : %d / %d   ·   Échap : abandonner" % [score, _reussites, faits, _essais]


func _nouvel_essai() -> void:
	if type == "jauge":
		_centre = _hasard.randf_range(0.15 + _largeur * 0.5, 0.85 - _largeur * 0.5)
		_curseur = 0.0
		_sens = 1.0
	else:
		_temps_pas = 0.0
		_attend = true
	if _dessin != null:
		_dessin.queue_redraw()


func _process(delta: float) -> void:
	if termine:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_apres_essai()
		return
	if type == "jauge":
		_curseur += _sens * delta * _vitesse * 2.0
		if _curseur >= 1.0:
			_curseur = 1.0
			_sens = -1.0
		elif _curseur <= 0.0:
			_curseur = 0.0
			_sens = 1.0
	else:
		_temps_pas += delta
		# Trop tard : le cercle est passé.
		if _attend and _temps_pas > _periode * 1.2:
			_noter(false, "Trop tard…")
	_dessin.queue_redraw()


func _input(event: InputEvent) -> void:
	if termine:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		abandonner()
		return
	if _pause > 0.0:
		if event.is_action_pressed("interagir"):
			get_viewport().set_input_as_handled()
		return
	if type == "jauge" and event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		valider()
	elif type == "rythme":
		for action: String in DIRECTIONS:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				appuyer(action)
				return
		if event.is_action_pressed("interagir"):
			get_viewport().set_input_as_handled()


## Jauge : on lance (comme F).
func valider() -> void:
	if termine or _pause > 0.0 or type != "jauge":
		return
	var dedans := absf(_curseur - _centre) <= _largeur * 0.5
	_noter(dedans, String(config.get("touche", "Dans le mille !")) if dedans else String(config.get("rate", "À côté…")))


## Rythme : on appuie sur une direction.
func appuyer(action: String) -> void:
	if termine or _pause > 0.0 or type != "rythme" or not _attend:
		return
	var ecart := absf(_temps_pas - _periode)
	var bon := action == _pas[faits] and ecart <= _periode * 0.2
	_noter(bon, "Parfait !" if bon and ecart < _periode * 0.08 else ("Bien !" if bon else ("Pas en rythme…" if action == _pas[faits] else "Mauvais pas…")))


## Pour les tests : place le curseur au milieu de la zone verte (ou en attend le bon moment).
func viser_parfait() -> void:
	if type == "jauge":
		_curseur = _centre
	else:
		_temps_pas = _periode


func pas_attendu() -> String:
	return _pas[faits] if type == "rythme" and faits < _pas.size() else ""


func _noter(reussi: bool, texte: String) -> void:
	_attend = false
	_resultats.append(reussi)
	faits += 1
	if reussi:
		score += 1
	_resultat.text = texte
	_resultat.add_theme_color_override("font_color", VERT if reussi else ROUGE)
	_maj_compte()
	_pause = 0.45 if type == "rythme" else 0.9


func _apres_essai() -> void:
	_resultat.text = ""
	if score >= _reussites:
		_finir(true)
	elif _reussites - score > _essais - faits:
		_finir(false)
	else:
		# Un peu plus vite à chaque fois.
		_vitesse *= float(config.get("acceleration", 1.12))
		_nouvel_essai()


func abandonner() -> void:
	_finir(false)


func _finir(reussi: bool) -> void:
	if termine:
		return
	termine = true
	remove_from_group("mini_jeu_en_cours")
	fini.emit(reussi)
	queue_free()


# --- Dessin ---------------------------------------------------------------------------------

func _dessiner() -> void:
	var taille := _dessin.size
	if type == "jauge":
		var barre := Rect2(10, 12, taille.x - 20, 22)
		_dessin.draw_rect(barre, Color(1, 1, 1, 0.12))
		var zone := Rect2(barre.position.x + barre.size.x * (_centre - _largeur * 0.5), barre.position.y,
				barre.size.x * _largeur, barre.size.y)
		_dessin.draw_rect(zone, Color(VERT, 0.75))
		var x := barre.position.x + barre.size.x * _curseur
		_dessin.draw_rect(Rect2(x - 2.5, barre.position.y - 6, 5, barre.size.y + 12), OR)
		_dessin.draw_rect(barre, Color(1, 1, 1, 0.4), false, 1.5)
		return
	# Rythme : la flèche au centre, et le cercle qui se resserre.
	var centre := taille * 0.5
	if faits < _pas.size():
		var dir: Array = DIRECTIONS[_pas[faits]]
		var police := ThemeDB.fallback_font
		var texte := "%s  %s" % [dir[0], dir[1]]
		var largeur_texte := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		_dessin.draw_string(police, centre + Vector2(-largeur_texte * 0.5, 14), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
		_dessin.draw_arc(centre, 40.0, 0.0, TAU, 48, Color(OR, 0.9), 3.0)
		if _attend:
			var reste := clampf(1.0 - _temps_pas / _periode, -0.2, 1.0)
			_dessin.draw_arc(centre, 40.0 + 70.0 * maxf(reste, 0.0), 0.0, TAU, 48, Color(VERT, 0.8), 2.5)
	# Les pas déjà faits, en petits points.
	for i in _pas.size():
		var couleur := Color(1, 1, 1, 0.25)
		if i < _resultats.size():
			couleur = Color(VERT, 0.9) if _resultats[i] else Color(ROUGE, 0.9)
		_dessin.draw_circle(Vector2(centre.x - (_pas.size() - 1) * 9.0 + i * 18.0, taille.y - 8), 4.0, couleur)


func _etiquette(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
