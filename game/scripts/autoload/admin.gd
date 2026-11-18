extends Node
## Mode ADMIN (autoload « Admin ») : des raccourcis pour tester le jeu.
##
## Touche F9 en jeu : ouvre / ferme le panneau. On peut :
## - voyager directement vers n'importe quelle île et n'importe quelle zone
##   (sans avoir fini les îles d'avant, ni l'intro de Hikari Bay) ;
## - recommencer une île au début d'un chapitre au choix ;
## - choisir son niveau (1 à 70) ;
## - être invincible, tuer en un coup, courir trois fois plus vite.
##
## Réservé aux tests : le panneau n'existe que si le jeu est lancé depuis Godot
## (ou une version « debug ») ET en partie solo. La version publique du jeu
## (export « release ») et les parties en ligne ne l'ont pas : un joueur ne peut
## donc pas s'en servir, et le serveur ne sait rien de ces raccourcis (il décide
## seul de la vie, des dégâts et de l'XP en ligne).

const TOUCHE := KEY_F9
const OR := Color(1.0, 0.82, 0.35)
const ROUGE := Color(1.0, 0.45, 0.35)
const FICHIER_PROGRESSION := "user://progression.cfg"
## Les îles dans l'ordre des époques : identifiant (data/<id>_quete.json) et nom affiché.
const ILES := [
	["prehistoire", "Préhistoire"],
	["egypte", "Égypte antique"],
	["grece", "Grèce antique"],
	["rome", "Rome antique"],
	["chine", "Chine des Han"],
	["moyen_age", "Moyen Âge"],
	["mayence", "Mayence"],
]
## Noms lisibles des zones (sinon on affiche l'identifiant).
const NOMS_ZONES := {
	"cote_gelee": "Côte Gelée", "steppe": "Steppe", "foret": "Forêt", "falaises": "Falaises",
	"grotte": "Grande Grotte (donjon)",
	"port_des_marais": "Port des Marais", "carrieres_toura": "Carrières de Toura",
	"village_batisseurs": "Village des bâtisseurs", "desert_rouge": "Désert Rouge",
	"coeur_pyramide": "Cœur de la pyramide (donjon)",
	"le_piree": "Le Pirée", "oliveraies": "Oliveraies", "athenes": "Athènes", "laurion": "Laurion",
	"galeries_laurion": "Galeries du Laurion", "acropole": "Acropole (donjon)",
	"voie_appienne": "Voie Appienne", "campagne": "Campagne", "rome": "Rome", "pompei": "Pompéi",
	"colisee": "Colisée", "cloaca": "Cloaca Maxima (donjon)",
	"porte_de_jade": "Porte de Jade", "fleuve_jaune": "Fleuve Jaune", "luoyang": "Luoyang",
	"mont_li": "Mont Li", "tombeau": "Tombeau de l'empereur (donjon)",
	"beauce": "Beauce", "bercheres": "Berchères", "chartres": "Chartres", "chantier": "Chantier",
	"crypte": "Crypte (donjon)",
	"rheingau": "Rheingau", "rhin": "Rhin", "ville": "Mayence (ville)",
}

## Réglages de test, gardés d'une zone à l'autre (pas enregistrés sur le disque).
var invincible := false
var coups_mortels := false
var vitesse_rapide := false

var _calque: CanvasLayer
var _panneau: PanelContainer
var _message: Label
var _ile_voyage: OptionButton
var _zone_voyage: OptionButton
var _ile_chapitre: OptionButton
var _chapitre: OptionButton
var _niveau: SpinBox
var _niveau_actuel: Label
var _cases := {}
var _donnees_iles := {}
## Tests automatiques (sans fenêtre) : permet le mode admin malgré tout.
var forcer_pour_tests := false


## Vrai si le mode admin peut servir ici : jeu lancé depuis Godot (ou version debug),
## avec une fenêtre, en partie solo. Jamais dans la version publique ni en ligne.
func disponible() -> bool:
	if forcer_pour_tests:
		return OS.is_debug_build()
	if not OS.is_debug_build() or DisplayServer.get_name() == "headless":
		return false
	if "--serveur" in OS.get_cmdline_user_args():
		return false
	return Reseau.mode == Reseau.Mode.SEUL


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		return
	for ile in ILES:
		var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_quete.json" % ile[0]))
		_donnees_iles[ile[0]] = lu if lu is Dictionary else {}
	_construire()


func _unhandled_input(evenement: InputEvent) -> void:
	if _panneau == null:
		return
	if evenement is InputEventKey and evenement.pressed and not evenement.echo and evenement.keycode == TOUCHE:
		basculer()
		get_viewport().set_input_as_handled()
	elif _panneau.visible and evenement.is_action_pressed("annuler"):
		_panneau.visible = false
		get_viewport().set_input_as_handled()


func basculer() -> void:
	if not disponible():
		_panneau.visible = false
		return
	_panneau.visible = not _panneau.visible
	if _panneau.visible:
		_rafraichir()
		_dire("")


func _process(_delta: float) -> void:
	if _panneau == null:
		return
	# Les réglages s'appliquent au personnage local, même après un changement de zone.
	var j := _joueur()
	if j == null or not disponible():
		return
	var combat = j.get_node_or_null("Combat")
	if combat != null:
		combat.invincible = invincible
		combat.facteur_admin = 1000.0 if coups_mortels else 1.0
		if invincible and combat.est_vivant() and combat.pv < combat.pv_max:
			combat.pv = combat.pv_max
			combat.pv_changes.emit(combat.pv, combat.pv_max)
	j.set_meta("admin_vitesse", 3.0 if vitesse_rapide else 1.0)


func _joueur() -> Node:
	return get_tree().get_first_node_in_group("joueur_local") if is_inside_tree() else null


# --- Actions ------------------------------------------------------------------

## Va dans une zone d'une île (ou à Hikari Bay si ile == "hub").
func voyager(ile: String, zone: String) -> void:
	if _joueur() == null:
		_dire("Lance d'abord une partie (Jouer seul), puis appuie sur F9.", true)
		return
	_marquer_intro_terminee()
	var scene := ""
	if ile == "hub":
		scene = Reseau.SCENE_HUB
		if zone != "":
			Reseau.set_meta("arrivee_hub", zone)
		elif Reseau.has_meta("arrivee_hub"):
			Reseau.remove_meta("arrivee_hub")
	else:
		scene = String(_donnees_iles.get(ile, {}).get("zones", {}).get(zone, {}).get("scene", ""))
	if scene == "" or not ResourceLoader.exists(scene):
		_dire("Cette zone n'existe pas encore.", true)
		return
	_panneau.visible = false
	get_tree().change_scene_to_file(scene)


## L'île reprend au début du chapitre choisi (les chapitres d'avant comptent comme faits).
func commencer_chapitre(ile: String, numero: int) -> void:
	if _joueur() == null:
		_dire("Lance d'abord une partie (Jouer seul), puis appuie sur F9.", true)
		return
	for c in _donnees_iles.get(ile, {}).get("chapitres", []):
		if int(c.get("numero", 0)) != numero or c.get("etapes", []).is_empty():
			continue
		var premiere: Dictionary = c["etapes"][0]
		var cfg := ConfigFile.new()
		cfg.load(Profil.chemin(FICHIER_PROGRESSION))
		cfg.set_value(ile, "etape", premiere.get("id", ""))
		cfg.save(Profil.chemin(FICHIER_PROGRESSION))
		# Une première étape « arriver » se termine en entrant dans sa zone : on y va directement.
		var zone := String(premiere.get("arriver", premiere.get("ou", c.get("ou", ""))))
		voyager(ile, zone)
		return
	_dire("Chapitre introuvable.", true)


## Donne directement un niveau au personnage (1 à 70). Les talents sont rendus
## si on redescend en dessous des points déjà dépensés.
func choisir_niveau(n: int) -> void:
	var prog := _joueur().get_node_or_null("Progression") if _joueur() != null else null
	if prog == null or not multiplayer.is_server():
		_dire("Lance d'abord une partie (Jouer seul), puis appuie sur F9.", true)
		return
	var d: Dictionary = Progression.donnees()
	n = clampi(n, 1, Progression.niveau_max(d))
	prog.etat["xp"] = Progression.xp_total_pour(d, n)
	if Progression.points_libres(d, prog.etat) < 0:
		Progression.oublier_talents(prog.etat)
	prog._appliquer()
	prog.niveau_gagne.emit(n)
	_dire("Niveau %d" % n)
	_rafraichir()


func _marquer_intro_terminee() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(FICHIER_PROGRESSION))
	cfg.set_value("intro", "terminee", true)
	cfg.save(Profil.chemin(FICHIER_PROGRESSION))


# --- Panneau ------------------------------------------------------------------

func _construire() -> void:
	_calque = CanvasLayer.new()
	_calque.layer = 60
	add_child(_calque)
	_panneau = PanelContainer.new()
	_panneau.visible = false
	_panneau.mouse_filter = Control.MOUSE_FILTER_STOP
	_panneau.anchor_left = 1.0
	_panneau.anchor_right = 1.0
	_panneau.offset_left = -430
	_panneau.offset_right = -16
	_panneau.offset_top = 70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.96)
	style.border_color = Color(ROUGE, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	_panneau.add_theme_stylebox_override("panel", style)
	_calque.add_child(_panneau)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panneau.add_child(col)
	var haut := HBoxContainer.new()
	col.add_child(haut)
	var titre := _texte("Mode admin", 20, ROUGE)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(titre)
	haut.add_child(_texte("F9 : fermer", 12, Color(1, 1, 1, 0.55)))

	# Voyager
	col.add_child(_texte("Aller dans une zone", 15, OR))
	var ligne := HBoxContainer.new()
	col.add_child(ligne)
	_ile_voyage = OptionButton.new()
	_ile_voyage.add_item("Hikari Bay")
	for ile in ILES:
		_ile_voyage.add_item(ile[1])
	_ile_voyage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ile_voyage.item_selected.connect(func(_i): _remplir_zones())
	ligne.add_child(_ile_voyage)
	_zone_voyage = OptionButton.new()
	_zone_voyage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(_zone_voyage)
	var aller := Button.new()
	aller.text = "Y aller"
	aller.pressed.connect(_sur_voyager)
	col.add_child(aller)

	# Chapitre
	col.add_child(HSeparator.new())
	col.add_child(_texte("Commencer un chapitre", 15, OR))
	ligne = HBoxContainer.new()
	col.add_child(ligne)
	_ile_chapitre = OptionButton.new()
	for ile in ILES:
		_ile_chapitre.add_item(ile[1])
	_ile_chapitre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ile_chapitre.item_selected.connect(func(_i): _remplir_chapitres())
	ligne.add_child(_ile_chapitre)
	_chapitre = OptionButton.new()
	_chapitre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapitre.fit_to_longest_item = false
	_chapitre.clip_text = true
	_chapitre.custom_minimum_size.x = 190
	ligne.add_child(_chapitre)
	var commencer := Button.new()
	commencer.text = "Commencer ce chapitre"
	commencer.pressed.connect(func():
		commencer_chapitre(ILES[_ile_chapitre.selected][0], _chapitre.get_item_id(_chapitre.selected)))
	col.add_child(commencer)

	# Niveau
	col.add_child(HSeparator.new())
	ligne = HBoxContainer.new()
	col.add_child(ligne)
	var t := _texte("Niveau", 15, OR)
	ligne.add_child(t)
	_niveau_actuel = _texte("", 13, Color(1, 1, 1, 0.6))
	_niveau_actuel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(_niveau_actuel)
	_niveau = SpinBox.new()
	_niveau.min_value = 1
	_niveau.max_value = Progression.niveau_max(Progression.donnees())
	_niveau.value = 10
	# Pas de saisie au clavier : les chiffres lanceraient des compétences.
	_niveau.get_line_edit().editable = false
	ligne.add_child(_niveau)
	var appliquer := Button.new()
	appliquer.text = "Appliquer"
	appliquer.pressed.connect(func(): choisir_niveau(int(_niveau.value)))
	ligne.add_child(appliquer)
	var raccourcis := HBoxContainer.new()
	col.add_child(raccourcis)
	for i in ILES.size():
		var b := Button.new()
		b.text = str(i * 10 + 1)
		b.tooltip_text = "Niveau de début de l'île : " + ILES[i][1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := i * 10 + 1
		b.pressed.connect(func():
			_niveau.value = n
			choisir_niveau(n))
		raccourcis.add_child(b)

	# Cases
	col.add_child(HSeparator.new())
	for c in [["invincible", "Invincible (la vie reste pleine)"], ["coups_mortels", "Tuer en un coup"],
			["vitesse_rapide", "Courir 3 fois plus vite"]]:
		var case := CheckBox.new()
		case.text = c[1]
		var nom: String = c[0]
		case.toggled.connect(func(oui: bool): set(nom, oui))
		col.add_child(case)
		_cases[nom] = case

	_message = _texte("", 13, OR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 380
	col.add_child(_message)
	col.add_child(_texte("Réservé aux tests (lancé depuis Godot, en solo).", 11, Color(1, 1, 1, 0.4)))
	_remplir_zones()
	_remplir_chapitres()


func _remplir_zones() -> void:
	_zone_voyage.clear()
	if _ile_voyage.selected <= 0:
		_zone_voyage.add_item("Place Hikari")
		_zone_voyage.set_item_metadata(0, "")
		_zone_voyage.add_item("Salle des portails (QG)")
		_zone_voyage.set_item_metadata(1, "portails")
		return
	var ile: String = ILES[_ile_voyage.selected - 1][0]
	for zone in _donnees_iles.get(ile, {}).get("zones", {}).keys():
		_zone_voyage.add_item(String(NOMS_ZONES.get(zone, zone)))
		_zone_voyage.set_item_metadata(_zone_voyage.item_count - 1, zone)


func _remplir_chapitres() -> void:
	_chapitre.clear()
	var ile: String = ILES[_ile_chapitre.selected][0]
	for c in _donnees_iles.get(ile, {}).get("chapitres", []):
		var n := int(c.get("numero", 0))
		_chapitre.add_item("%d. %s" % [n, c.get("titre", "")], n)


func _sur_voyager() -> void:
	var ile := "hub" if _ile_voyage.selected <= 0 else String(ILES[_ile_voyage.selected - 1][0])
	voyager(ile, String(_zone_voyage.get_item_metadata(_zone_voyage.selected)))


func _rafraichir() -> void:
	for nom in _cases:
		_cases[nom].set_pressed_no_signal(get(nom))
	var prog := _joueur().get_node_or_null("Progression") if _joueur() != null else null
	_niveau_actuel.text = "(actuel : %d)" % prog.niveau() if prog != null else ""


func _dire(texte: String, erreur := false) -> void:
	_message.text = texte
	_message.modulate = ROUGE if erreur else Color.WHITE


func _texte(contenu: String, taille: int, couleur := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	l.modulate = couleur
	return l
