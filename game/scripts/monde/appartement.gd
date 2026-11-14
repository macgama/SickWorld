extends Node3D
## L'appartement 1204 du joueur (Résidence Sakura) et la fondation de sa guilde.
##
## - Ascenseur : le bouton du hall monte au 12e étage, celui de l'appartement
##   redescend. Il faut d'abord la clé, donnée par la mission « courrier ».
## - Souvenirs : chaque mission accomplie pose un objet sur l'étagère.
## - Guilde : quand la mission « guilde » est finie, le registraire propose de
##   fonder sa guilde (nom + couleur). Elle est gardée dans la sauvegarde locale
##   (section [guilde]) en attendant que le serveur s'en occupe.
## La géométrie est construite par quartier_residences.gd.

const Residences := preload("res://scripts/monde/quartier_residences.gd")
const PointInteraction := preload("res://scripts/monde/point_interaction.gd")

const OR := Color(1.0, 0.82, 0.35)
## Couleurs proposées pour la bannière : [nom, couleur].
const COULEURS := [
	["Pourpre", Color(0.5, 0.12, 0.35)],
	["Azur", Color(0.15, 0.4, 0.8)],
	["Jade", Color(0.12, 0.5, 0.35)],
	["Ambre", Color(0.85, 0.5, 0.1)],
	["Nuit", Color(0.12, 0.12, 0.2)],
]
## Apparence des souvenirs : id de mission -> [forme, couleur].
const SOUVENIRS := {
	"kuro": ["affiche", Color(0.9, 0.2, 0.2)],
	"kaminari": ["bol", Color(0.85, 0.25, 0.2)],
	"ecran": ["cle_usb", Color(0.3, 0.6, 1.0)],
	"ferraille": ["lingot", Color(0.7, 0.72, 0.75)],
	"louche": ["badge", Color(0.3, 0.9, 0.6)],
	"fresques": ["cadre", Color(0.8, 0.6, 0.4)],
	"jardins": ["graine", Color(0.4, 0.8, 0.3)],
	"lanternes": ["lanterne", Color(1.0, 0.55, 0.25)],
	"billet": ["billet", Color(0.9, 0.85, 0.7)],
	"courrier": ["cle", Color(0.85, 0.7, 0.3)],
	"guilde": ["rouleau", Color(0.95, 0.92, 0.8)],
	"montre": ["montre", Color(0.9, 0.75, 0.35)],
	"projecteurs": ["casque", Color(1.0, 0.8, 0.1)],
	"affiche": ["billet", Color(1.0, 0.8, 0.3)],
	"hanafuda": ["carte", Color(0.75, 0.12, 0.1)],
	"grande_roue": ["boulon", Color(0.7, 0.72, 0.75)],
	"colis": ["badge", Color(0.25, 0.55, 0.95)],
}

var _bouton_hall: Node3D
var _bouton_appart: Node3D
var _voile: ColorRect
var _en_voyage := false
var _etagere: Node3D
var _compteur: Label3D
var _fenetre: PanelContainer
var _champ_nom: LineEdit
var _apercu: Label
var _erreur: Label
var _couleur_choisie := 0
var _boutons_couleur: Array[Button] = []


func _ready() -> void:
	add_to_group("appartement")
	_bouton_hall = _creer_bouton(Residences.ASCENSEUR_HALL, "Monter à l'appartement 1204", _monter)
	_bouton_appart = _creer_bouton(Residences.ASCENSEUR_APPART, "Redescendre au hall", _descendre)
	_etagere = Node3D.new()
	_etagere.name = "Souvenirs"
	add_child(_etagere)
	_compteur = Label3D.new()
	_compteur.position = Vector3(Residences.APPART.position.x + 0.05, Residences.SOL_APPART + 2.58, Residences.APPART.position.y + 4.2)
	_compteur.rotation.y = PI / 2
	_compteur.font_size = 22
	_compteur.pixel_size = 0.004
	_compteur.modulate = Color(0.9, 0.85, 0.75)
	add_child(_compteur)
	_construire_interface()
	var quetes := _quetes()
	if quetes != null:
		quetes.quete_terminee.connect(func(_id: String): ranger_souvenirs())
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null:
		dialogue.termine.connect(_sur_dialogue_termine)
	ranger_souvenirs.call_deferred()
	_afficher_bannieres.call_deferred()


func _quetes() -> Node:
	return get_tree().get_first_node_in_group("quetes")


func _creer_bouton(p: Vector3, texte: String, action: Callable) -> Node3D:
	var b := Node3D.new()
	b.set_script(PointInteraction)
	b.texte = texte
	b.position = p
	add_child(b)
	b.utilise.connect(action)
	return b


# --- Ascenseur --------------------------------------------------------------------

## Vrai quand le joueur a la clé (mission « Courrier égaré » accomplie).
func a_la_cle() -> bool:
	var quetes := _quetes()
	return quetes != null and quetes.etat("courrier") == "terminee"


func _monter() -> void:
	if not a_la_cle():
		var dialogue := get_tree().get_first_node_in_group("dialogue")
		if dialogue != null:
			dialogue.ouvrir("ascenseur", "Ascenseur · Résidence Sakura", PackedStringArray([
				"Le bouton s'allume, puis s'éteint aussitôt. Un petit écran affiche : « Badge résident requis ».",
				"Madame Fujimoto, la concierge, saura sûrement quoi faire. Son comptoir est juste à côté."]))
		return
	ranger_souvenirs()
	_voyager(Residences.ARRIVEE_APPART, 0.0)


func _descendre() -> void:
	_voyager(Residences.ARRIVEE_HALL, 0.0)


## Fondu au noir, téléportation, puis retour de l'image.
func _voyager(destination: Vector3, angle: float) -> void:
	if _en_voyage:
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local")
	if joueur == null:
		return
	_en_voyage = true
	var anim := create_tween()
	anim.tween_property(_voile, "color:a", 1.0, 0.35)
	anim.tween_callback(func():
		if is_instance_valid(joueur):
			joueur.teleporter(destination, angle))
	anim.tween_interval(0.4)
	anim.tween_property(_voile, "color:a", 0.0, 0.45)
	anim.tween_callback(func(): _en_voyage = false)


# --- Souvenirs --------------------------------------------------------------------

## Pose un souvenir sur l'étagère pour chaque mission accomplie.
func ranger_souvenirs() -> void:
	for enfant in _etagere.get_children():
		enfant.free()
	var quetes := _quetes()
	if quetes == null:
		return
	var i := 0
	var total := 0
	for q in quetes.quetes:
		total += 1
		if quetes.etat(q["id"]) != "terminee" or i >= Residences.SOUVENIRS_COLONNES * Residences.SOUVENIRS_RANGEES:
			continue
		var place := Node3D.new()
		place.name = "Souvenir_" + String(q["id"])
		place.position = Residences.emplacement_souvenir(i)
		_etagere.add_child(place)
		var apparence: Array = SOUVENIRS.get(q["id"], ["boite", OR])
		_creer_objet(place, apparence[0], apparence[1])
		var etiquette := Label3D.new()
		etiquette.text = _nom_souvenir(q.get("recompense", q.get("titre", "")))
		etiquette.position = Vector3(0.23, -0.1, 0)
		etiquette.rotation.y = PI / 2
		etiquette.font_size = 20
		etiquette.pixel_size = 0.0028
		etiquette.width = 400
		etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiquette.outline_size = 6
		etiquette.modulate = Color(1.0, 0.95, 0.85)
		place.add_child(etiquette)
		i += 1
	_compteur.text = "%d / %d" % [i, total]


## « Bol de ramen Kaminari (bonus de vie, bientôt) » -> « Bol de ramen Kaminari ».
func _nom_souvenir(recompense: String) -> String:
	var p := recompense.find(" (")
	return recompense.substr(0, p) if p > 0 else recompense


func _materiau(couleur: Color, lumineux := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.5
	if lumineux:
		m.emission_enabled = true
		m.emission = couleur
		m.emission_energy_multiplier = 2.0
	return m


func _forme(parent: Node3D, maillage: Mesh, p: Vector3, m: Material, rotation_m := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.position = p
	mi.rotation = rotation_m
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _creer_objet(parent: Node3D, forme: String, couleur: Color) -> void:
	var m := _materiau(couleur)
	match forme:
		"affiche", "cadre":
			var b := BoxMesh.new()
			b.size = Vector3(0.03, 0.42, 0.3)
			_forme(parent, b, Vector3(-0.08, 0.21, 0), _materiau(Color(0.15, 0.12, 0.1)), Vector3(0, 0, -0.15))
			var image := BoxMesh.new()
			image.size = Vector3(0.01, 0.36, 0.24)
			_forme(parent, image, Vector3(-0.06, 0.21, 0), _materiau(couleur, forme == "affiche"), Vector3(0, 0, -0.15))
		"bol":
			var c := CylinderMesh.new()
			c.top_radius = 0.12
			c.bottom_radius = 0.06
			c.height = 0.1
			_forme(parent, c, Vector3(0, 0.05, 0), m)
			var bouillon := CylinderMesh.new()
			bouillon.top_radius = 0.11
			bouillon.bottom_radius = 0.11
			bouillon.height = 0.01
			_forme(parent, bouillon, Vector3(0, 0.095, 0), _materiau(Color(0.85, 0.6, 0.3)))
		"lingot":
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.07, 0.24)
			var acier := _materiau(couleur)
			acier.metallic = 0.5
			acier.roughness = 0.35
			_forme(parent, b, Vector3(0, 0.035, 0), acier)
		"graine":
			var pot := CylinderMesh.new()
			pot.top_radius = 0.08
			pot.bottom_radius = 0.06
			pot.height = 0.12
			_forme(parent, pot, Vector3(0, 0.06, 0), _materiau(Color(0.6, 0.35, 0.25)))
			var pousse := SphereMesh.new()
			pousse.radius = 0.05
			pousse.height = 0.1
			_forme(parent, pousse, Vector3(0, 0.15, 0), m)
		"lanterne":
			var s := SphereMesh.new()
			s.radius = 0.1
			s.height = 0.26
			_forme(parent, s, Vector3(0, 0.14, 0), _materiau(couleur, true))
			var l := OmniLight3D.new()
			l.light_color = couleur
			l.light_energy = 0.4
			l.omni_range = 1.5
			l.position = Vector3(0.15, 0.15, 0)
			parent.add_child(l)
		"montre":
			var c := CylinderMesh.new()
			c.top_radius = 0.1
			c.bottom_radius = 0.1
			c.height = 0.03
			var or_m := _materiau(couleur)
			or_m.metallic = 0.5
			or_m.roughness = 0.3
			_forme(parent, c, Vector3(-0.05, 0.11, 0), or_m, Vector3(0, 0, PI / 2 - 0.3))
			var cadran := CylinderMesh.new()
			cadran.top_radius = 0.085
			cadran.bottom_radius = 0.085
			cadran.height = 0.005
			_forme(parent, cadran, Vector3(-0.03, 0.115, 0), _materiau(Color(0.95, 0.93, 0.85)), Vector3(0, 0, PI / 2 - 0.3))
		"casque":
			var s := SphereMesh.new()
			s.radius = 0.13
			s.height = 0.13
			s.is_hemisphere = true
			_forme(parent, s, Vector3(0, 0.0, 0), m)
		"rouleau":
			var c := CylinderMesh.new()
			c.top_radius = 0.045
			c.bottom_radius = 0.045
			c.height = 0.32
			_forme(parent, c, Vector3(0, 0.045, 0), m, Vector3(PI / 2, 0, 0))
			var ruban := CylinderMesh.new()
			ruban.top_radius = 0.048
			ruban.bottom_radius = 0.048
			ruban.height = 0.03
			_forme(parent, ruban, Vector3(0, 0.045, 0), _materiau(Color(0.75, 0.15, 0.15)), Vector3(PI / 2, 0, 0))
		"cle", "cle_usb":
			var b := BoxMesh.new()
			b.size = Vector3(0.06, 0.03, 0.2)
			_forme(parent, b, Vector3(0, 0.015, 0), _materiau(couleur, forme == "cle_usb"))
			var anneau := TorusMesh.new()
			anneau.inner_radius = 0.035
			anneau.outer_radius = 0.06
			_forme(parent, anneau, Vector3(0, 0.015, -0.14), _materiau(couleur, true))
		"carte":
			var b := BoxMesh.new()
			b.size = Vector3(0.015, 0.2, 0.13)
			_forme(parent, b, Vector3(-0.08, 0.1, 0), _materiau(couleur), Vector3(0, 0, -0.2))
		"boulon":
			var tete := CylinderMesh.new()
			tete.top_radius = 0.06
			tete.bottom_radius = 0.06
			tete.height = 0.05
			tete.radial_segments = 6
			var acier := _materiau(couleur)
			acier.metallic = 0.5
			_forme(parent, tete, Vector3(0, 0.025, 0), acier)
			var tige := CylinderMesh.new()
			tige.top_radius = 0.025
			tige.bottom_radius = 0.025
			tige.height = 0.2
			_forme(parent, tige, Vector3(0, 0.05, 0.12), acier, Vector3(PI / 2, 0, 0))
		"billet", "badge":
			var b := BoxMesh.new()
			b.size = Vector3(0.02, 0.1, 0.2) if forme == "billet" else Vector3(0.02, 0.14, 0.1)
			_forme(parent, b, Vector3(-0.08, 0.06, 0), _materiau(couleur, forme == "badge"), Vector3(0, 0, -0.2))
		_:
			var b := BoxMesh.new()
			b.size = Vector3(0.14, 0.14, 0.14)
			_forme(parent, b, Vector3(0, 0.07, 0), m)


# --- Guilde -------------------------------------------------------------------------

## La guilde du joueur : {} s'il n'en a pas encore, sinon {nom, couleur}.
func guilde() -> Dictionary:
	var quetes := _quetes()
	if quetes == null:
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(Profil.chemin(quetes.fichier_progression)) != OK or not cfg.has_section_key("guilde", "nom"):
		return {}
	return {"nom": String(cfg.get_value("guilde", "nom")), "couleur": int(cfg.get_value("guilde", "couleur", 0))}


func peut_fonder() -> bool:
	var quetes := _quetes()
	return quetes != null and quetes.etat("guilde") == "terminee" and guilde().is_empty()


func _sur_dialogue_termine(id_pnj: String) -> void:
	# Le registraire propose la fondation (une fois la mission « Trois signatures » finie).
	if id_pnj == "registraire" and peut_fonder():
		ouvrir_fondation.call_deferred()


func ouvrir_fondation() -> void:
	if not peut_fonder():
		return
	_erreur.text = ""
	_champ_nom.text = ""
	_choisir_couleur(_couleur_choisie)
	_fenetre.visible = true
	_champ_nom.grab_focus()


func fondation_ouverte() -> bool:
	return _fenetre.visible


func fermer_fondation() -> void:
	_fenetre.visible = false
	_champ_nom.release_focus()


## Vérifie le nom et enregistre la guilde. Rend "" si tout va bien, sinon l'erreur.
func fonder_guilde(nom: String, couleur: int) -> String:
	nom = nom.strip_edges()
	if nom.length() < 3:
		return "Le nom doit faire au moins 3 lettres."
	if nom.length() > 24:
		return "Le nom doit faire 24 lettres au plus."
	for prise in ["Les Veilleurs", "Ordre du Loup", "Les Cartographes", "Le Brasier"]:
		if nom.to_lower() == String(prise).to_lower():
			return "Ce nom est déjà pris par une guilde de la ville."
	var quetes := _quetes()
	if quetes == null:
		return "Le registre est fermé."
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(quetes.fichier_progression))
	cfg.set_value("guilde", "nom", nom)
	cfg.set_value("guilde", "couleur", clampi(couleur, 0, COULEURS.size() - 1))
	cfg.save(Profil.chemin(quetes.fichier_progression))
	_afficher_bannieres()
	if quetes.has_method("_annoncer"):
		quetes._annoncer("Guilde fondée : %s\nTa bannière flotte dans la Maison des guildes." % nom)
	return ""


func _valider() -> void:
	var erreur := fonder_guilde(_champ_nom.text, _couleur_choisie)
	if erreur != "":
		_erreur.text = erreur
		return
	fermer_fondation()


func _choisir_couleur(n: int) -> void:
	_couleur_choisie = n
	for k in _boutons_couleur.size():
		_boutons_couleur[k].button_pressed = k == n
	_mettre_a_jour_apercu()


func _mettre_a_jour_apercu(_texte := "") -> void:
	var nom := _champ_nom.text.strip_edges()
	_apercu.text = nom if nom != "" else "Nom de ta guilde"
	var style := StyleBoxFlat.new()
	style.bg_color = COULEURS[_couleur_choisie][1]
	style.border_color = OR
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_apercu.add_theme_stylebox_override("normal", style)


## Bannière de la guilde dans la Maison des guildes et dans l'appartement.
func _afficher_bannieres() -> void:
	for nom_noeud in ["BanniereGuildeMaison", "BanniereGuildeAppart"]:
		var ancienne := get_node_or_null(nom_noeud)
		if ancienne != null:
			ancienne.free()
	var g := guilde()
	if g.is_empty():
		return
	_creer_banniere("BanniereGuildeMaison", Residences.BANNIERE_MAISON, 0.0, Vector2(2.0, 4.5), g, 30)
	_creer_banniere("BanniereGuildeAppart", Residences.BANNIERE_APPART, -PI / 2, Vector2(0.9, 1.2), g, 24)


func _creer_banniere(nom_noeud: String, p: Vector3, angle: float, taille: Vector2, g: Dictionary, police: int) -> void:
	var b := Node3D.new()
	b.name = nom_noeud
	b.position = p
	b.rotation.y = angle
	add_child(b)
	var tissu := StandardMaterial3D.new()
	tissu.albedo_color = COULEURS[clampi(g["couleur"], 0, COULEURS.size() - 1)][1]
	tissu.roughness = 0.9
	var boite := BoxMesh.new()
	boite.size = Vector3(taille.x, taille.y, 0.04)
	_forme(b, boite, Vector3.ZERO, tissu)
	var barre := CylinderMesh.new()
	barre.top_radius = 0.03
	barre.bottom_radius = 0.03
	barre.height = taille.x + 0.3
	_forme(b, barre, Vector3(0, taille.y * 0.5 + 0.03, 0.02), _materiau(OR), Vector3(0, 0, PI / 2))
	var texte := Label3D.new()
	texte.text = g["nom"]
	texte.position = Vector3(0, taille.y * 0.12, 0.03)
	texte.font_size = police
	texte.pixel_size = 0.01 if taille.x >= 2.0 else 0.005
	texte.width = int(taille.x * 0.9 / texte.pixel_size)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.modulate = Color(1.0, 0.92, 0.75)
	texte.outline_size = 6
	b.add_child(texte)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.8, 0.55)
	lumiere.light_energy = 1.6
	lumiere.omni_range = taille.y * 1.6
	lumiere.position = Vector3(0, taille.y * 0.3, taille.y * 0.5)
	b.add_child(lumiere)
	var embleme := SphereMesh.new()
	embleme.radius = taille.x * 0.16
	embleme.height = 0.02
	_forme(b, embleme, Vector3(0, -taille.y * 0.22, 0.03), _materiau(OR, true), Vector3(PI / 2, 0, 0))


# --- Interface (voile noir de l'ascenseur, fenêtre de fondation) ---------------------

func _construire_interface() -> void:
	var ecran := CanvasLayer.new()
	ecran.layer = 6
	add_child(ecran)
	_voile = ColorRect.new()
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.color = Color(0, 0, 0, 0)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ecran.add_child(_voile)
	_fenetre = PanelContainer.new()
	_fenetre.anchor_left = 0.5
	_fenetre.anchor_right = 0.5
	_fenetre.anchor_top = 0.5
	_fenetre.anchor_bottom = 0.5
	_fenetre.offset_left = -260
	_fenetre.offset_right = 260
	_fenetre.offset_top = -210
	_fenetre.offset_bottom = 210
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.95)
	style.border_color = Color(OR, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	_fenetre.add_theme_stylebox_override("panel", style)
	ecran.add_child(_fenetre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_fenetre.add_child(colonne)
	var titre := Label.new()
	titre.text = "FONDER UNE GUILDE · ギルド設立"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 22)
	titre.add_theme_color_override("font_color", OR)
	colonne.add_child(titre)
	var aide := Label.new()
	aide.text = "Choisis le nom et la couleur de ta bannière. Elle sera accrochée dans la Maison des guildes et chez toi."
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.add_theme_font_size_override("font_size", 14)
	colonne.add_child(aide)
	_champ_nom = LineEdit.new()
	_champ_nom.placeholder_text = "Nom de la guilde (3 à 24 lettres)"
	_champ_nom.max_length = 24
	_champ_nom.text_changed.connect(_mettre_a_jour_apercu)
	_champ_nom.text_submitted.connect(func(_t: String): _valider())
	colonne.add_child(_champ_nom)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	colonne.add_child(ligne)
	for k in COULEURS.size():
		var b := Button.new()
		b.text = COULEURS[k][0]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fond := StyleBoxFlat.new()
		fond.bg_color = COULEURS[k][1]
		fond.set_corner_radius_all(4)
		fond.set_content_margin_all(6)
		var choisi := fond.duplicate() as StyleBoxFlat
		choisi.border_color = OR
		choisi.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", fond)
		b.add_theme_stylebox_override("hover", fond)
		b.add_theme_stylebox_override("pressed", choisi)
		b.add_theme_stylebox_override("hover_pressed", choisi)
		b.pressed.connect(_choisir_couleur.bind(k))
		ligne.add_child(b)
		_boutons_couleur.append(b)
	_apercu = Label.new()
	_apercu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apercu.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apercu.custom_minimum_size = Vector2(0, 70)
	_apercu.add_theme_font_size_override("font_size", 22)
	_apercu.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	colonne.add_child(_apercu)
	_erreur = Label.new()
	_erreur.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_erreur.add_theme_font_size_override("font_size", 14)
	colonne.add_child(_erreur)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	colonne.add_child(actions)
	var fonder := Button.new()
	fonder.text = "Fonder la guilde"
	fonder.pressed.connect(_valider)
	actions.add_child(fonder)
	var annuler := Button.new()
	annuler.text = "Plus tard"
	annuler.pressed.connect(fermer_fondation)
	actions.add_child(annuler)
	_fenetre.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _fenetre.visible and event.is_action_pressed("ui_cancel"):
		fermer_fondation()
		get_viewport().set_input_as_handled()
