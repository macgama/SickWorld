extends Node3D
## Missions secondaires de Hikari Bay (voir data/hub_quetes.json).
##
## Un « ! » doré flotte au-dessus d'un personnage qui propose une mission, un
## « ? » au-dessus de celui qu'il faut aller voir. La mission suivie s'affiche
## en haut à gauche ; la touche J ouvre le journal des missions.
## L'avancement est gardé dans user://progression.cfg (section « quetes »).

signal quete_acceptee(id: String)
signal quete_terminee(id: String)
signal etape_avancee(id: String, etape: int)

const Pnj := preload("res://scripts/monde/pnj.gd")
const DONNEES := "res://data/hub_quetes.json"
const OR := Color(1.0, 0.82, 0.35)
## Distance (mètres) pour ramasser ou utiliser un objet de mission.
const PORTEE_OBJET := 2.4

@export var fichier_progression := "user://progression.cfg"

var quetes: Array = []
## id -> {"etat": "active" | "terminee", "etape": int, "faits": [numéros d'objets]}
var etats := {}

var _marques := {} # id de personnage -> Label3D (« ! » ou « ? »)
var _objets := {} # "quete:numero" -> Node3D
var _invite: Label3D
var _suivi: PanelContainer
var _suivi_titre: Label
var _suivi_objectif: Label
var _journal: PanelContainer
var _journal_texte: RichTextLabel
var _annonce: Label
var _temps := 0.0


func _ready() -> void:
	add_to_group("quetes")
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		quetes = lu.get("quetes", [])
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	_charger()
	_construire_interface()
	_invite = Label3D.new()
	_invite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_invite.font_size = 36
	_invite.pixel_size = 0.005
	_invite.outline_size = 10
	_invite.no_depth_test = true
	_invite.visible = false
	add_child(_invite)
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null:
		dialogue.termine.connect(_sur_dialogue_termine)
	_placer_donneurs.call_deferred()
	_mettre_a_jour_objets.call_deferred()
	_mettre_a_jour_suivi.call_deferred()


# --- Données et sauvegarde ----------------------------------------------------

func quete(id: String) -> Dictionary:
	for q in quetes:
		if q.get("id", "") == id:
			return q
	return {}


func etat(id: String) -> String:
	return etats.get(id, {}).get("etat", "disponible")


func etape_de(id: String) -> Dictionary:
	var q := quete(id)
	var n: int = etats.get(id, {}).get("etape", 0)
	var liste: Array = q.get("etapes", [])
	return liste[n] if n < liste.size() else {}


func _charger() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(fichier_progression) != OK:
		return
	for q in quetes:
		var v = cfg.get_value("quetes", q["id"]) if cfg.has_section_key("quetes", q["id"]) else null
		if v is Dictionary:
			etats[q["id"]] = v


func _sauver() -> void:
	var cfg := ConfigFile.new()
	cfg.load(fichier_progression)
	for id in etats:
		cfg.set_value("quetes", id, etats[id])
	cfg.save(fichier_progression)


# --- Avancement -----------------------------------------------------------------

func accepter(id: String) -> void:
	if etat(id) != "disponible":
		return
	etats[id] = {"etat": "active", "etape": 0, "faits": []}
	_sauver()
	quete_acceptee.emit(id)
	_annoncer("Nouvelle mission : " + quete(id).get("titre", id))
	_apres_changement()


func _avancer(id: String) -> void:
	var e: Dictionary = etats[id]
	e["etape"] = int(e["etape"]) + 1
	e["faits"] = []
	if e["etape"] >= quete(id).get("etapes", []).size():
		e["etat"] = "terminee"
		_sauver()
		quete_terminee.emit(id)
		_annoncer("Mission accomplie : %s\nRécompense : %s" % [quete(id).get("titre", id), quete(id).get("recompense", "")])
	else:
		_sauver()
		etape_avancee.emit(id, e["etape"])
	_apres_changement()


func _apres_changement() -> void:
	_mettre_a_jour_objets()
	_mettre_a_jour_suivi()
	if _journal.visible:
		_remplir_journal()


func _sur_dialogue_termine(id_pnj: String) -> void:
	for q in quetes:
		var id: String = q["id"]
		match etat(id):
			"disponible":
				if q.get("donneur", "") == id_pnj:
					accepter(id)
					return
			"active":
				if etape_de(id).get("parler", "") == id_pnj:
					_avancer(id)
					return


## Le joueur utilise l'objet numéro n de l'étape en cours.
func utiliser_objet(id: String, n: int) -> void:
	if etat(id) != "active":
		return
	var e: Dictionary = etats[id]
	if n in e["faits"]:
		return
	e["faits"].append(n)
	var total: int = etape_de(id).get("objets", {}).get("positions", []).size()
	if e["faits"].size() >= total:
		_avancer(id)
	else:
		_sauver()
		_mettre_a_jour_objets()
		_mettre_a_jour_suivi()


# --- Chaque image ---------------------------------------------------------------

func _process(delta: float) -> void:
	_temps += delta
	_mettre_a_jour_pnj()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	var proche := _objet_proche(joueur)
	_invite.visible = proche != null and not _dialogue_ouvert()
	if proche != null:
		_invite.text = "[F] " + String(proche.get_meta("verbe"))
		_invite.global_position = proche.global_position + Vector3(0, 0.9, 0)
	for o in _objets.values():
		var fleche: Node3D = o.get_node_or_null("Fleche")
		if fleche != null:
			fleche.position.y = 1.3 + sin(_temps * 3.0) * 0.12
			fleche.rotation.y = _temps * 1.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		_journal.visible = not _journal.visible
		if _journal.visible:
			_remplir_journal()
		get_viewport().set_input_as_handled()
		return
	if _journal.visible and event.is_action_pressed("ui_cancel"):
		_journal.visible = false
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interagir") or _dialogue_ouvert():
		return
	var proche := _objet_proche(get_tree().get_first_node_in_group("joueur_local") as Node3D)
	if proche != null:
		get_viewport().set_input_as_handled()
		utiliser_objet(proche.get_meta("quete"), proche.get_meta("numero"))


func _dialogue_ouvert() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	return dialogue != null and dialogue.est_ouvert()


func _objet_proche(joueur: Node3D) -> Node3D:
	if joueur == null:
		return null
	for o in _objets.values():
		var ecart: Vector3 = o.global_position - joueur.global_position
		if Vector2(ecart.x, ecart.z).length() < PORTEE_OBJET and absf(ecart.y) < 2.5:
			return o
	return null


func _trouver_pnj(id: String) -> Pnj:
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if pnj is Pnj and pnj.identifiant == id:
			return pnj
	return null


## Répliques et marques « ! » / « ? » au-dessus des personnages concernés.
func _mettre_a_jour_pnj() -> void:
	var voulu := {} # id pnj -> [marque, répliques]
	for q in quetes:
		var id: String = q["id"]
		match etat(id):
			"disponible":
				voulu[q["donneur"]] = ["!", q.get("proposition", [])]
			"active":
				var e := etape_de(id)
				if e.has("parler"):
					voulu[e["parler"]] = ["?", e.get("repliques", [])]
			"terminee":
				if not voulu.has(q["donneur"]) and q.has("apres"):
					voulu[q["donneur"]] = ["", q["apres"]]
	for pnj_id in voulu.keys():
		var pnj := _trouver_pnj(pnj_id)
		if pnj == null:
			continue
		var repliques := PackedStringArray(voulu[pnj_id][1])
		if pnj.repliques_speciales != repliques:
			pnj.repliques_speciales = repliques
		var marque: Label3D = _marques.get(pnj_id)
		if marque == null:
			marque = _creer_marque()
			_marques[pnj_id] = marque
		marque.text = voulu[pnj_id][0]
		marque.visible = marque.text != ""
		marque.global_position = pnj.global_position + Vector3(0, 2.75 + sin(_temps * 2.5) * 0.06, 0)
	for pnj_id in _marques.keys():
		if not voulu.has(pnj_id):
			_marques[pnj_id].visible = false
			var pnj := _trouver_pnj(pnj_id)
			if pnj != null and not pnj.repliques_speciales.is_empty():
				pnj.repliques_speciales = PackedStringArray()


func _creer_marque() -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 120
	l.pixel_size = 0.005
	l.outline_size = 18
	l.modulate = OR
	l.outline_modulate = Color(0.25, 0.12, 0.0)
	add_child(l)
	return l


# --- Personnages et objets placés par les missions ---------------------------

## Crée les donneurs qui n'existent pas déjà dans la ville (champ « position_donneur »).
func _placer_donneurs() -> void:
	for q in quetes:
		if not q.has("position_donneur") or _trouver_pnj(q["donneur"]) != null:
			continue
		var p: Array = q["position_donneur"]
		var pnj := Pnj.new()
		pnj.identifiant = q["donneur"]
		pnj.name = "Pnj_" + q["donneur"]
		pnj.position = Vector3(p[0], p[1], p[2])
		pnj.rotation.y = p[3] if p.size() > 3 else 0.0
		add_child(pnj)


func _mettre_a_jour_objets() -> void:
	var voulus := {}
	for q in quetes:
		var id: String = q["id"]
		if etat(id) != "active":
			continue
		var o: Dictionary = etape_de(id).get("objets", {})
		var faits: Array = etats[id].get("faits", [])
		var positions: Array = o.get("positions", [])
		for n in positions.size():
			if not (n in faits):
				voulus["%s:%d" % [id, n]] = [id, n, o, positions[n]]
	for cle in _objets.keys():
		if not voulus.has(cle):
			_objets[cle].queue_free()
			_objets.erase(cle)
	for cle in voulus.keys():
		if _objets.has(cle):
			continue
		var v: Array = voulus[cle]
		var objet := _creer_objet(v[2].get("type", ""), v[3])
		objet.set_meta("quete", v[0])
		objet.set_meta("numero", v[1])
		objet.set_meta("verbe", v[2].get("verbe", "Utiliser"))
		_objets[cle] = objet


func _creer_objet(type: String, p: Array) -> Node3D:
	var racine := Node3D.new()
	racine.position = Vector3(p[0], p[1], p[2])
	racine.rotation.y = p[3] if p.size() > 3 else 0.0
	add_child(racine)
	match type:
		"affiche":
			# Affiche « chien perdu » collée au mur, légèrement éclairée.
			var papier := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.6, 0.85)
			papier.mesh = q
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.95, 0.93, 0.85)
			m.emission_enabled = true
			m.emission = Color(1, 0.95, 0.8)
			m.emission_energy_multiplier = 0.35
			papier.material_override = m
			racine.add_child(papier)
			var texte := Label3D.new()
			texte.text = "犬を探しています\nCHIEN PERDU\n\nKuro · shiba roux\nRécompense !"
			texte.font_size = 22
			texte.pixel_size = 0.004
			texte.modulate = Color(0.1, 0.05, 0.05)
			texte.outline_size = 0
			texte.position = Vector3(0, 0, 0.01)
			texte.shaded = false
			racine.add_child(texte)
			racine.position.y = p[1]
		"capteur":
			# Cercle lumineux au sol : l'endroit où poser le capteur.
			var anneau := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.42
			t.outer_radius = 0.5
			anneau.mesh = t
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.3, 1.0, 0.95) * 2.0
			anneau.material_override = m
			anneau.position.y = 0.05
			racine.add_child(anneau)
			var lumiere := OmniLight3D.new()
			lumiere.light_color = Color(0.3, 1.0, 0.95)
			lumiere.light_energy = 1.0
			lumiere.omni_range = 3.0
			lumiere.position.y = 0.6
			racine.add_child(lumiere)
	# Petite flèche dorée qui tourne au-dessus (visible à travers les murs).
	var fleche := MeshInstance3D.new()
	fleche.name = "Fleche"
	var pointe := CylinderMesh.new()
	pointe.top_radius = 0.18
	pointe.bottom_radius = 0.0
	pointe.height = 0.32
	pointe.radial_segments = 4
	pointe.rings = 1
	fleche.mesh = pointe
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = OR
	mf.no_depth_test = true
	mf.render_priority = 10
	fleche.material_override = mf
	fleche.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(fleche)
	return racine


# --- Interface : mission suivie, annonces, journal --------------------------------

func _construire_interface() -> void:
	var ecran := CanvasLayer.new()
	ecran.layer = 3
	add_child(ecran)
	_suivi = PanelContainer.new()
	_suivi.offset_left = 22
	_suivi.offset_top = 140
	_suivi.offset_right = 340
	_suivi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.7)
	style.border_color = Color(OR, 0.7)
	style.border_width_left = 3
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)
	_suivi.add_theme_stylebox_override("panel", style)
	ecran.add_child(_suivi)
	var colonne := VBoxContainer.new()
	_suivi.add_child(colonne)
	_suivi_titre = Label.new()
	_suivi_titre.add_theme_color_override("font_color", OR)
	_suivi_titre.add_theme_font_size_override("font_size", 15)
	colonne.add_child(_suivi_titre)
	_suivi_objectif = Label.new()
	_suivi_objectif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_suivi_objectif.add_theme_font_size_override("font_size", 14)
	colonne.add_child(_suivi_objectif)
	var aide := Label.new()
	aide.text = "J : journal des missions"
	aide.add_theme_font_size_override("font_size", 11)
	aide.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
	colonne.add_child(aide)
	# Annonce au centre (nouvelle mission, mission accomplie).
	_annonce = Label.new()
	_annonce.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_annonce.anchor_left = 0.25
	_annonce.anchor_right = 0.75
	_annonce.offset_top = 190
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.add_theme_font_size_override("font_size", 26)
	_annonce.add_theme_color_override("font_color", OR)
	_annonce.add_theme_constant_override("outline_size", 8)
	_annonce.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_annonce.modulate.a = 0.0
	_annonce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ecran.add_child(_annonce)
	# Journal (touche J).
	_journal = PanelContainer.new()
	_journal.anchor_left = 0.5
	_journal.anchor_right = 0.5
	_journal.anchor_top = 0.5
	_journal.anchor_bottom = 0.5
	_journal.offset_left = -330
	_journal.offset_right = 330
	_journal.offset_top = -250
	_journal.offset_bottom = 250
	var sj := StyleBoxFlat.new()
	sj.bg_color = Color(0.03, 0.04, 0.08, 0.94)
	sj.border_color = Color(OR, 0.9)
	sj.set_border_width_all(2)
	sj.set_corner_radius_all(8)
	sj.set_content_margin_all(18)
	_journal.add_theme_stylebox_override("panel", sj)
	ecran.add_child(_journal)
	_journal_texte = RichTextLabel.new()
	_journal_texte.bbcode_enabled = true
	_journal_texte.scroll_active = true
	_journal_texte.add_theme_font_size_override("normal_font_size", 16)
	_journal_texte.add_theme_font_size_override("bold_font_size", 18)
	_journal.add_child(_journal_texte)
	_journal.visible = false


func _texte_objectif(id: String) -> String:
	var e := etape_de(id)
	var texte: String = e.get("objectif", "")
	if e.has("objets"):
		var total: int = e["objets"].get("positions", []).size()
		texte += " (%d/%d)" % [etats[id].get("faits", []).size(), total]
	return texte


func _mettre_a_jour_suivi() -> void:
	for q in quetes:
		if etat(q["id"]) == "active":
			_suivi_titre.text = "MISSION · " + q.get("titre", "")
			_suivi_objectif.text = _texte_objectif(q["id"])
			_suivi.visible = true
			return
	_suivi.visible = false


func _remplir_journal() -> void:
	var t := "[center][b]JOURNAL DES MISSIONS[/b]  ·  [color=#aaaaaa]J ou Échap pour fermer[/color][/center]\n\n"
	var en_cours := ""
	var finies := ""
	var souvenirs := ""
	var a_trouver := 0
	for q in quetes:
		var id: String = q["id"]
		match etat(id):
			"active":
				en_cours += "[b][color=#ffd15a]%s[/color][/b]\n%s\n→ %s\n\n" % [q["titre"], q.get("resume", ""), _texte_objectif(id)]
			"terminee":
				finies += "✓ %s\n" % q["titre"]
				souvenirs += "• %s\n" % q.get("recompense", "")
			_:
				a_trouver += 1
	t += "[b]En cours[/b]\n" + (en_cours if en_cours != "" else "Aucune. Cherche les « ! » au-dessus des habitants.\n\n")
	if finies != "":
		t += "[b]Accomplies[/b]\n" + finies + "\n[b]Souvenirs rapportés[/b]\n" + souvenirs + "\n"
	if a_trouver > 0:
		t += "[color=#aaaaaa]%d mission(s) attendent encore quelqu'un en ville.[/color]" % a_trouver
	_journal_texte.text = t


func _annoncer(texte: String) -> void:
	_annonce.text = texte
	var anim := create_tween()
	anim.tween_property(_annonce, "modulate:a", 1.0, 0.4)
	anim.tween_interval(3.0)
	anim.tween_property(_annonce, "modulate:a", 0.0, 0.8)
