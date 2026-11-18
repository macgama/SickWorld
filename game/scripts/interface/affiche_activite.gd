extends CanvasLayer
## L'AFFICHE d'une activité : la fiche illustrée qui s'ouvre devant chaque entrée
## (portails du QG, Arène, Maison des guildes, donjons) pour donner envie d'y aller.
##
## - une grande image du jeu qui bouge doucement (effet « Ken Burns »), le titre,
##   l'époque et une phrase d'accroche ;
## - « Ta prochaine étape » : où le joueur en est (chapitre, île terminée…) ;
## - ce qu'on y fait et ce qu'on y gagne ;
## - un gros bouton (Voyager, S'inscrire, Entrer…) et la BANDE-ANNONCE : 25 secondes
##   d'images en plein écran avec bandes noires, titres et musique.
##
## Les textes et les images sont dans data/affiches.json ; les images dans
## game/images/affiches/ (faites avec les scripts tests/capture_<zone>.gd).
## Utilisation : AfficheActivite.ouvrir(get_tree(), "ile_grece", func(): partir())
## (renvoie null sans écran, par exemple en --headless : l'appelant agit alors tout de suite).

const Style := preload("res://scripts/interface/style_menu.gd")
const DONNEES := "res://data/affiches.json"
const MOI := "res://scripts/interface/affiche_activite.gd"
const FICHIER_VUES := "user://affiches.cfg"
const OR := Color(1.0, 0.82, 0.42)
const VERT := Color(0.55, 0.95, 0.6)
const ORANGE := Color(1.0, 0.62, 0.3)
## Secondes par image dans la fiche (l'image change toute seule).
const DUREE_IMAGE_FICHE := 6.5
const FONDU := 0.9

signal action_choisie
signal fermee

static var _cache := {}

var id := ""
var fiche := {}
var _action: Callable
var _texte_bouton := ""
var _textures: Array[Texture2D] = []

# Fiche
var _voile: ColorRect
var _panneau: PanelContainer
var _cadre_image: Control
var _images: Array[TextureRect] = []
var _bouton_action: Button
var _image_fiche := 0
var _temps_image := 0.0
var _plan_fiche := {}

# Bande-annonce
var _film: Control
var _film_images: Array[TextureRect] = []
var _film_titre: Label
var _film_sous_titre: Label
var _film_texte: Label
var _film_barre: ColorRect
var _plans: Array = []
var _plan := -1
var _temps_plan := 0.0
var _duree_film := 0.0
var _temps_film := 0.0
var _musique_avant := ""
var _carton_final := false


# --- Utilisation -------------------------------------------------------------

static func donnees() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(DONNEES, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_cache = d
	return _cache.get("affiches", {})


static func existe(id_affiche: String) -> bool:
	return donnees().has(id_affiche)


## L'affiche du portail d'une époque (« Grèce antique » → « ile_grece »), ou "".
static func id_du_portail(epoque: String) -> String:
	var toutes := donnees()
	for cle in toutes:
		if String(toutes[cle].get("portail", "")) == epoque:
			return String(cle)
	return ""


## Ouvre l'affiche `id_affiche`. `action` est appelée par le gros bouton.
## Renvoie null si aucune affiche ne peut s'ouvrir (pas d'écran, affiche inconnue).
static func ouvrir(arbre: SceneTree, id_affiche: String, action: Callable = Callable(), texte_bouton := "") -> CanvasLayer:
	if DisplayServer.get_name() == "headless" or not existe(id_affiche):
		return null
	for ancienne in arbre.get_nodes_in_group("affiche_activite"):
		ancienne.queue_free()
	var a: CanvasLayer = load(MOI).new()
	a.id = id_affiche
	a._action = action
	a._texte_bouton = texte_bouton
	arbre.root.add_child(a)
	noter_vue(id_affiche)
	return a


## Vrai si ce personnage a déjà vu cette affiche (pour ne la montrer d'office qu'une fois).
static func deja_vue(id_affiche: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(Profil.chemin(FICHIER_VUES)) != OK:
		return false
	return bool(cfg.get_value("vues", id_affiche, false))


static func noter_vue(id_affiche: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(FICHIER_VUES))
	cfg.set_value("vues", id_affiche, true)
	cfg.save(Profil.chemin(FICHIER_VUES))


static func est_ouverte(arbre: SceneTree) -> bool:
	return arbre.has_group("affiche_activite")


# --- Où en est le joueur ---------------------------------------------------------

## L'avancée de l'histoire sur une île, lue dans user://progression.cfg :
## {etat: "nouvelle" | "en_cours" | "a_suivre" | "terminee", chapitre, total, titre}.
static func avancee_ile(ile: String, fichier := "user://progression.cfg") -> Dictionary:
	var resultat := {"etat": "nouvelle", "chapitre": 1, "total": 0, "titre": ""}
	var f := FileAccess.open("res://data/%s_quete.json" % ile, FileAccess.READ)
	if f == null:
		return resultat
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return resultat
	var chapitres: Array = d.get("chapitres", [])
	resultat["total"] = chapitres.size()
	if not chapitres.is_empty():
		resultat["titre"] = String(chapitres[0].get("titre", ""))
	var cfg := ConfigFile.new()
	if cfg.load(Profil.chemin(fichier)) != OK or not cfg.has_section_key(ile, "etape"):
		return resultat
	var etape := String(cfg.get_value(ile, "etape", ""))
	if etape == "fin":
		# 8 chapitres = l'histoire complète ; moins = la suite arrive plus tard.
		resultat["etat"] = "terminee" if chapitres.size() >= 8 else "a_suivre"
		resultat["chapitre"] = chapitres.size()
		if not chapitres.is_empty():
			resultat["titre"] = String(chapitres[-1].get("titre", ""))
		return resultat
	for c in chapitres:
		for e in c.get("etapes", []):
			if String(e.get("id", "")) == etape:
				resultat["etat"] = "en_cours"
				resultat["chapitre"] = int(c.get("numero", 1))
				resultat["titre"] = String(c.get("titre", ""))
				# La toute première étape seulement : l'île n'est pas vraiment commencée.
				if c == chapitres[0] and e == c["etapes"][0]:
					resultat["etat"] = "nouvelle"
				return resultat
	return resultat


## Les récompenses d'une île tirées des données du jeu : panoplies de l'Arsenal
## (data/arsenal.json) et montures (data/montures.json) de cette époque.
static func recompenses_ile(ile: String) -> PackedStringArray:
	var lignes := PackedStringArray()
	var noms := PackedStringArray()
	var a = _lire_json("res://data/arsenal.json")
	if a is Dictionary:
		for cle in a.get("ensembles", {}):
			if String(cle).begins_with("arsenal_%s_" % ile):
				noms.append(String(a["ensembles"][cle].get("nom", "")))
	if not noms.is_empty():
		lignes.append("Panoplies de l'Arsenal : " + ", ".join(noms))
	var montures := PackedStringArray()
	var m = _lire_json("res://data/montures.json")
	if m is Dictionary:
		for cle in m.get("montures", {}):
			var monture: Dictionary = m["montures"][cle]
			if String(monture.get("epoque", "")) == ile:
				montures.append(String(monture.get("nom", "")))
	if not montures.is_empty():
		lignes.append(("Monture : " if montures.size() == 1 else "Montures : ") + ", ".join(montures))
	return lignes


static func _lire_json(chemin: String) -> Variant:
	var f := FileAccess.open(chemin, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else null


static func niveau_du_joueur(arbre: SceneTree) -> int:
	var joueur := arbre.get_first_node_in_group("joueur_local")
	if joueur == null:
		return 0
	var progression := joueur.get_node_or_null("Progression")
	if progression != null and progression.has_method("niveau"):
		return int(progression.niveau())
	return 0


# --- Construction ----------------------------------------------------------------

func _ready() -> void:
	layer = 60
	add_to_group("affiche_activite")
	# Le personnage ne bouge pas pendant qu'on lit l'affiche.
	add_to_group("cinematique_en_cours")
	process_mode = Node.PROCESS_MODE_ALWAYS
	fiche = donnees().get(id, {})
	for image in fiche.get("images", []):
		var chemin := String(image.get("fichier", "")) if image is Dictionary else String(image)
		var t := _charger_image(chemin)
		if t != null:
			_textures.append(t)
	if _textures.is_empty():
		_textures.append(_image_de_secours())
	_construire_fiche()
	_audio("ouvrir")


func _charger_image(chemin: String) -> Texture2D:
	if chemin == "":
		return null
	if ResourceLoader.exists(chemin):
		var r = load(chemin)
		if r is Texture2D:
			return r
	# Image ajoutée sans passer par l'import de Godot (rare) : on la lit directement.
	if FileAccess.file_exists(chemin):
		var img := Image.load_from_file(chemin)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _image_de_secours() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.12, 0.18))
	g.set_color(1, Color(0.2, 0.08, 0.3))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 1)
	t.width = 640
	t.height = 360
	return t


func _construire_fiche() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.theme = Style.theme()
	racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(racine)
	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 0.62)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(_voile)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(centre)
	_panneau = PanelContainer.new()
	var largeur := clampf(get_viewport().get_visible_rect().size.x - 120.0, 760.0, 1180.0)
	_panneau.custom_minimum_size = Vector2(largeur, 0)
	var boite := Style.boite(Color(0.025, 0.04, 0.065, 0.97), Color(Style.CYAN, 0.45), 1, 12)
	boite.content_margin_left = 0
	boite.content_margin_right = 0
	boite.content_margin_top = 0
	boite.content_margin_bottom = 0
	_panneau.add_theme_stylebox_override("panel", boite)
	centre.add_child(_panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	_panneau.add_child(colonne)

	# Grande image animée, avec le titre par-dessus.
	_cadre_image = Control.new()
	_cadre_image.custom_minimum_size = Vector2(largeur, minf(largeur * 0.42, get_viewport().get_visible_rect().size.y * 0.5))
	_cadre_image.clip_contents = true
	colonne.add_child(_cadre_image)
	for i in 2:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate.a = 0.0
		_cadre_image.add_child(tr)
		_images.append(tr)
	_images[0].texture = _textures[0]
	_images[0].modulate.a = 1.0
	_plan_fiche = _cadrage_fiche(0)
	var degrade := TextureRect.new()
	degrade.texture = _degrade_bas()
	degrade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	degrade.stretch_mode = TextureRect.STRETCH_SCALE
	degrade.set_anchors_preset(Control.PRESET_FULL_RECT)
	degrade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre_image.add_child(degrade)

	var textes := VBoxContainer.new()
	textes.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	textes.offset_left = 34
	textes.offset_right = -34
	textes.offset_bottom = -20
	textes.grow_vertical = Control.GROW_DIRECTION_BEGIN
	textes.add_theme_constant_override("separation", 2)
	textes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre_image.add_child(textes)
	var surtitre := Style.titre_section(_surtitre())
	surtitre.add_theme_font_size_override("font_size", 14)
	textes.add_child(surtitre)
	var titre := Label.new()
	titre.text = String(fiche.get("titre", id))
	titre.add_theme_font_size_override("font_size", 52)
	titre.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	titre.add_theme_constant_override("shadow_offset_y", 3)
	textes.add_child(titre)
	var epoque := Label.new()
	epoque.text = String(fiche.get("epoque", ""))
	epoque.add_theme_font_size_override("font_size", 19)
	epoque.add_theme_color_override("font_color", OR)
	textes.add_child(epoque)
	var accroche := Label.new()
	accroche.text = String(fiche.get("accroche", ""))
	accroche.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accroche.add_theme_font_size_override("font_size", 17)
	accroche.add_theme_color_override("font_color", Color(0.9, 0.93, 0.97))
	accroche.custom_minimum_size = Vector2(largeur * 0.62, 0)
	accroche.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	textes.add_child(accroche)
	var bandeau := _bandeau_etat()
	if bandeau != null:
		_cadre_image.add_child(bandeau)

	# Les trois cartes : prochaine étape, l'aventure, à gagner.
	var marge := MarginContainer.new()
	for cote in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + cote, 26)
	marge.add_theme_constant_override("margin_top", 18)
	marge.add_theme_constant_override("margin_bottom", 8)
	colonne.add_child(marge)
	var cartes := HBoxContainer.new()
	cartes.add_theme_constant_override("separation", 16)
	marge.add_child(cartes)
	cartes.add_child(_carte_etape())
	cartes.add_child(_carte_liste("L'AVENTURE", fiche.get("points", []), Style.TEXTE, "•"))
	var gains := PackedStringArray()
	if fiche.get("type", "") == "ile":
		gains.append_array(recompenses_ile(String(fiche.get("ile", ""))))
	for r in fiche.get("recompenses", []):
		gains.append(String(r))
	cartes.add_child(_carte_liste("À GAGNER", gains, OR, "★"))

	# Les boutons.
	var marge_b := MarginContainer.new()
	for cote in ["left", "right"]:
		marge_b.add_theme_constant_override("margin_" + cote, 26)
	marge_b.add_theme_constant_override("margin_top", 10)
	marge_b.add_theme_constant_override("margin_bottom", 22)
	colonne.add_child(marge_b)
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 12)
	marge_b.add_child(boutons)
	if not fiche.get("bande_annonce", []).is_empty():
		var ba := Button.new()
		ba.text = "▶  Bande-annonce  (B)"
		ba.custom_minimum_size = Vector2(0, 46)
		ba.pressed.connect(lancer_bande_annonce)
		boutons.add_child(ba)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boutons.add_child(vide)
	var plus_tard := Button.new()
	plus_tard.text = "Plus tard  (Échap)"
	plus_tard.custom_minimum_size = Vector2(0, 46)
	plus_tard.pressed.connect(fermer)
	boutons.add_child(plus_tard)
	_bouton_action = Button.new()
	_bouton_action.text = (_texte_bouton if _texte_bouton != "" else String(fiche.get("bouton", "Y aller"))).to_upper() + "  (Entrée)"
	_bouton_action.custom_minimum_size = Vector2(250, 52)
	_bouton_action.add_theme_font_size_override("font_size", 19)
	_bouton_action.add_theme_stylebox_override("normal", Style.boite(Color(0.07, 0.36, 0.42, 0.95), Style.CYAN, 2, 8))
	_bouton_action.add_theme_stylebox_override("hover", Style.boite(Color(0.1, 0.5, 0.58, 1.0), Color.WHITE, 2, 8))
	_bouton_action.add_theme_stylebox_override("pressed", Style.boite(Color(0.05, 0.6, 0.68, 1.0), Color.WHITE, 2, 8))
	_bouton_action.pressed.connect(_agir)
	_bouton_action.visible = _action.is_valid()
	boutons.add_child(_bouton_action)
	if _action.is_valid():
		_bouton_action.grab_focus.call_deferred()

	# Petite entrée en scène.
	_panneau.modulate.a = 0.0
	_voile.modulate.a = 0.0
	var anim := create_tween().set_parallel()
	anim.tween_property(_panneau, "modulate:a", 1.0, 0.35)
	anim.tween_property(_voile, "modulate:a", 1.0, 0.35)


func _surtitre() -> String:
	match String(fiche.get("type", "")):
		"ile":
			return "Île n°%d · Époque à visiter" % int(fiche.get("numero", 0))
		"arene":
			return "Joueur contre joueur"
		"guildes":
			return "Jouer ensemble"
		"donjon":
			return "Donjon de groupe"
	return "Activité"


## Un ruban en haut à gauche de l'image : NOUVEAU, EN COURS, TERMINÉE…
func _bandeau_etat() -> Control:
	var texte := ""
	var couleur := Style.CYAN
	if fiche.get("type", "") == "ile":
		var av := avancee_ile(String(fiche.get("ile", "")))
		match String(av["etat"]):
			"nouvelle":
				texte = "NOUVELLE ÉPOQUE"
				couleur = OR
			"en_cours":
				texte = "EN COURS · CHAPITRE %d" % int(av["chapitre"])
			"a_suivre":
				texte = "LA SUITE ARRIVE BIENTÔT"
				couleur = Style.VIOLET
			"terminee":
				texte = "HISTOIRE TERMINÉE ✓"
				couleur = VERT
	elif fiche.get("type", "") == "guildes":
		var g := get_tree().root.get_node_or_null("Guildes")
		if g != null and g.a_une_guilde():
			texte = "TA GUILDE : " + String(g.nom_local()).to_upper()
			couleur = VERT
		else:
			texte = "TROUVE TA GUILDE"
			couleur = OR
	if texte == "":
		return null
	var p := PanelContainer.new()
	var s := Style.boite(Color(couleur, 0.92), Color(0, 0, 0, 0), 0, 4)
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", s)
	p.position = Vector2(26, 22)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.02, 0.03, 0.05))
	p.add_child(l)
	return p


func _carte(titre: String) -> Array:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", Style.boite(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08), 1, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(Style.titre_section(titre))
	return [p, v]


func _carte_liste(titre: String, lignes: Array, couleur: Color, puce: String) -> Control:
	var c := _carte(titre)
	for ligne in lignes:
		var l := Label.new()
		l.text = puce + "  " + String(ligne)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(200, 0)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", couleur)
		c[1].add_child(l)
	return c[0]


func _carte_etape() -> Control:
	var c := _carte("TA PROCHAINE ÉTAPE")
	var v: VBoxContainer = c[1]
	var grand := Label.new()
	grand.add_theme_font_size_override("font_size", 20)
	var petit := Label.new()
	petit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	petit.custom_minimum_size = Vector2(200, 0)
	petit.add_theme_font_size_override("font_size", 15)
	petit.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	v.add_child(grand)
	v.add_child(petit)
	var type := String(fiche.get("type", ""))
	if type == "ile":
		var av := avancee_ile(String(fiche.get("ile", "")))
		var total := maxi(1, int(av["total"]))
		match String(av["etat"]):
			"nouvelle":
				grand.text = "Chapitre 1 : " + String(av["titre"])
				petit.text = "Tout commence ici. Traverse le portail."
			"en_cours":
				grand.text = "Chapitre %d : %s" % [int(av["chapitre"]), String(av["titre"])]
				petit.text = "Reprends là où tu t'étais arrêté."
			"a_suivre":
				grand.text = "Chapitres 1 à %d terminés" % int(av["total"])
				petit.text = "Bravo ! La suite de l'histoire arrive bientôt. Les quêtes secondaires et les événements t'attendent."
			"terminee":
				grand.text = "Histoire terminée"
				petit.text = "Reviens pour les quêtes secondaires, les événements publics et les panoplies renforcées."
		var fait := float(av["chapitre"] - 1) / total
		if String(av["etat"]) in ["terminee", "a_suivre"]:
			fait = float(av["chapitre"]) / maxf(8.0, total) if av["etat"] == "a_suivre" else 1.0
		v.add_child(_barre(fait))
		v.add_child(_ligne_niveau())
	elif type == "arene":
		var jcj := get_tree().root.get_node_or_null("JcJ")
		grand.text = "Ton premier duel"
		petit.text = "Inscris-toi à la file (touche H) ou défie quelqu'un avec /duel Nom."
		if jcj != null and jcj.has_method("je_me_bats") and jcj.je_me_bats():
			grand.text = "Combat en cours"
	elif type == "guildes":
		var g := get_tree().root.get_node_or_null("Guildes")
		if g != null and g.a_une_guilde():
			grand.text = "Les contrats de la semaine"
			petit.text = "Ta guilde compte sur toi. Les contrats sont au tableau, juste ici."
		else:
			grand.text = "Fonder ou rejoindre"
			petit.text = "Le tableau de recrutement, dans la Maison des guildes, montre les guildes qui t'attendent. Pour fonder la tienne, parle au registraire."
	elif type == "donjon":
		var niveaux: Array = fiche.get("niveaux", [])
		grand.text = "Forme ton groupe"
		petit.text = "Jusqu'à 5 joueurs. Le chef de groupe choisit le donjon (touche K)."
		if not niveaux.is_empty():
			v.add_child(_ligne_niveau())
	return c[0]


func _barre(fait: float) -> Control:
	var fond := ColorRect.new()
	fond.color = Color(1, 1, 1, 0.1)
	fond.custom_minimum_size = Vector2(0, 6)
	var plein := ColorRect.new()
	plein.color = Style.CYAN
	plein.anchor_bottom = 1.0
	plein.anchor_right = clampf(fait, 0.0, 1.0)
	fond.add_child(plein)
	return fond


func _ligne_niveau() -> Control:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 14)
	var niveaux: Array = fiche.get("niveaux", [])
	if niveaux.size() < 2:
		return l
	var mien := niveau_du_joueur(get_tree())
	var texte := "Niveaux %d à %d" % [int(niveaux[0]), int(niveaux[1])] if niveaux[0] != niveaux[1] else "Niveau %d conseillé" % int(niveaux[0])
	if mien > 0:
		texte += " · toi : niveau %d" % mien
		l.add_theme_color_override("font_color", VERT if mien >= int(niveaux[0]) - 1 else ORANGE)
		if mien < int(niveaux[0]) - 1:
			texte += " (ce sera difficile)"
	l.text = texte
	return l


func _degrade_bas() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.03, 0.05, 0.0), Color(0.02, 0.03, 0.05, 0.25), Color(0.025, 0.04, 0.065, 0.97)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 256
	return t


# --- Animation des images ----------------------------------------------------------

## Cadrage de la fiche : un lent travelling différent pour chaque image.
func _cadrage_fiche(n: int) -> Dictionary:
	var sens := 1.0 if n % 2 == 0 else -1.0
	return {"de": [0.5 - 0.12 * sens, 0.5, 1.08], "a": [0.5 + 0.12 * sens, 0.45, 1.2], "duree": DUREE_IMAGE_FICHE + FONDU}


## Place une image dans son cadre : focus x, y (0 à 1) et zoom (1 = image entière).
static func cadrer(image: TextureRect, cadre: Vector2, plan: Dictionary, t: float) -> void:
	var de: Array = plan.get("de", [0.5, 0.5, 1.0])
	var a: Array = plan.get("a", de)
	var k := clampf(t, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65 # presque linéaire, adouci aux bouts
	var zoom := maxf(1.0, lerpf(float(de[2]), float(a[2]), k))
	var focus := Vector2(lerpf(float(de[0]), float(a[0]), k), lerpf(float(de[1]), float(a[1]), k))
	image.size = cadre * zoom
	image.position = (cadre - image.size) * focus


func _process(delta: float) -> void:
	if _film != null and _film.visible:
		_avancer_film(delta)
		return
	if _cadre_image == null:
		return
	_temps_image += delta
	var duree := float(_plan_fiche.get("duree", DUREE_IMAGE_FICHE))
	for i in _images.size():
		if _images[i].modulate.a > 0.0:
			var depart := float(_images[i].get_meta("depart", 0.0))
			cadrer(_images[i], _cadre_image.size, _images[i].get_meta("plan", _plan_fiche), (_temps_image - depart) / duree)
	if _textures.size() > 1 and _temps_image >= float(_images[0].get_meta("depart", 0.0)) + DUREE_IMAGE_FICHE:
		_image_suivante_fiche()


func _image_suivante_fiche() -> void:
	_image_fiche = (_image_fiche + 1) % _textures.size()
	var ancienne := _images[0]
	var nouvelle := _images[1]
	nouvelle.texture = _textures[_image_fiche]
	_plan_fiche = _cadrage_fiche(_image_fiche)
	nouvelle.set_meta("plan", _plan_fiche)
	nouvelle.set_meta("depart", _temps_image)
	nouvelle.modulate.a = 0.0
	_cadre_image.move_child(nouvelle, 1)
	var anim := create_tween()
	anim.tween_property(nouvelle, "modulate:a", 1.0, FONDU)
	anim.tween_callback(func(): ancienne.modulate.a = 0.0)
	_images = [nouvelle, ancienne]


# --- Bande-annonce ---------------------------------------------------------------

func lancer_bande_annonce() -> void:
	_plans = fiche.get("bande_annonce", [])
	if _plans.is_empty():
		return
	if _film == null:
		_construire_film()
	_duree_film = 0.0
	for p in _plans:
		_duree_film += float(p.get("duree", 4.0))
	_temps_film = 0.0
	_plan = -1
	_carton_final = false
	_panneau.visible = false
	_voile.color = Color(0, 0, 0, 1)
	_film.visible = true
	_film.modulate.a = 0.0
	create_tween().tween_property(_film, "modulate:a", 1.0, 0.6)
	var audio := get_tree().root.get_node_or_null("Audio")
	if audio != null:
		_musique_avant = audio.liste_musique()
		audio.musique("bande_annonce")
	_plan_suivant()


func _construire_film() -> void:
	_film = Control.new()
	_film.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film.mouse_filter = Control.MOUSE_FILTER_STOP
	_film.clip_contents = true
	_film.theme = Style.theme()
	_film.visible = false
	add_child(_film)
	var noir := ColorRect.new()
	noir.color = Color.BLACK
	noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film.add_child(noir)
	for i in 2:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate.a = 0.0
		_film.add_child(tr)
		_film_images.append(tr)
	# Bandes noires du cinéma.
	for haut in [true, false]:
		var bande := ColorRect.new()
		bande.color = Color.BLACK
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.anchor_right = 1.0
		if haut:
			bande.anchor_bottom = 0.1
		else:
			bande.anchor_top = 0.9
			bande.anchor_bottom = 1.0
		_film.add_child(bande)
	_film_titre = _label_film(64, Color.WHITE)
	_placer(_film_titre, Rect2(0.0, 0.5, 1.0, 0.5), -80, 10)
	_film_sous_titre = _label_film(24, OR)
	_placer(_film_sous_titre, Rect2(0.0, 0.5, 1.0, 0.5), 16, 60)
	_film_texte = _label_film(24, Color(0.95, 0.96, 1.0))
	_placer(_film_texte, Rect2(0.12, 0.76, 0.88, 0.89), 0, 0)
	_film_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var aide := Label.new()
	aide.text = "Espace : passer"
	aide.add_theme_font_size_override("font_size", 14)
	aide.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	aide.anchor_left = 1.0
	aide.anchor_right = 1.0
	aide.offset_left = -170
	aide.offset_top = 18
	_film.add_child(aide)
	_film_barre = ColorRect.new()
	_film_barre.color = Color(Style.CYAN, 0.7)
	_film_barre.anchor_top = 0.9
	_film_barre.anchor_bottom = 0.9
	_film_barre.offset_bottom = 2
	_film.add_child(_film_barre)


## Ancres (gauche, haut, droite, bas dans un Rect2) et décalages verticaux en pixels.
func _placer(c: Control, ancres: Rect2, haut: float, bas: float) -> void:
	c.anchor_left = ancres.position.x
	c.anchor_top = ancres.position.y
	c.anchor_right = ancres.size.x
	c.anchor_bottom = ancres.size.y
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = haut
	c.offset_bottom = bas


func _label_film(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	_film.add_child(l)
	return l


func _plan_suivant() -> void:
	_plan += 1
	if _plan >= _plans.size():
		_montrer_carton_final()
		return
	var p: Dictionary = _plans[_plan]
	var n := clampi(int(p.get("image", 0)), 0, _textures.size() - 1)
	var ancienne := _film_images[0]
	var nouvelle := _film_images[1]
	nouvelle.texture = _textures[n]
	nouvelle.set_meta("plan", p)
	nouvelle.set_meta("depart", _temps_film)
	nouvelle.modulate.a = 0.0
	_film.move_child(nouvelle, 2)
	var anim := create_tween()
	anim.tween_property(nouvelle, "modulate:a", 1.0, FONDU if _plan > 0 else 1.4)
	anim.tween_callback(func(): ancienne.modulate.a = 0.0)
	_film_images = [nouvelle, ancienne]
	_temps_plan = 0.0
	var duree := float(p.get("duree", 4.0))
	_montrer_texte(_film_titre, String(p.get("titre", "")), duree, 0.5)
	_montrer_texte(_film_sous_titre, String(p.get("sous_titre", "")), duree, 1.1)
	_montrer_texte(_film_texte, String(p.get("texte", "")), duree, 0.6)


func _montrer_texte(l: Label, texte: String, duree: float, retard: float) -> void:
	var anim := l.create_tween()
	if l.modulate.a > 0.0:
		anim.tween_property(l, "modulate:a", 0.0, 0.3)
	anim.tween_callback(func(): l.text = texte)
	if texte == "":
		return
	anim.tween_interval(retard)
	anim.tween_property(l, "modulate:a", 1.0, 0.7)
	anim.tween_interval(maxf(0.5, duree - retard - 1.8))
	anim.tween_property(l, "modulate:a", 0.0, 0.6)


func _avancer_film(delta: float) -> void:
	_temps_film += delta
	_temps_plan += delta
	for image in _film_images:
		if image.modulate.a > 0.0 and image.has_meta("plan"):
			var p: Dictionary = image.get_meta("plan")
			var duree := float(p.get("duree", 4.0)) + FONDU
			cadrer(image, _film.size, p, (_temps_film - float(image.get_meta("depart", 0.0))) / duree)
	if _duree_film > 0.0:
		_film_barre.anchor_right = clampf(_temps_film / _duree_film, 0.0, 1.0)
	if _carton_final:
		return
	if _plan >= 0 and _plan < _plans.size() and _temps_plan >= float(_plans[_plan].get("duree", 4.0)):
		_plan_suivant()


## Dernier carton : le titre et l'invitation à y aller, puis retour à la fiche.
func _montrer_carton_final() -> void:
	_carton_final = true
	var t := 1.2
	_montrer_texte(_film_texte, "", 0.0, 0.0)
	_montrer_texte(_film_titre, String(fiche.get("titre", "")).to_upper(), 3.6, 0.3)
	var bouton := String(fiche.get("bouton", ""))
	_montrer_texte(_film_sous_titre, ("Entrée : " + bouton.to_lower()) if _action.is_valid() and bouton != "" else String(fiche.get("epoque", "")), 3.6, 0.8)
	var image := _film_images[0]
	var anim := create_tween()
	anim.tween_property(image, "modulate", Color(0.45, 0.45, 0.5, 1.0), t)
	anim.tween_interval(2.6)
	anim.tween_callback(_finir_bande_annonce)


func _finir_bande_annonce() -> void:
	if _film == null or not _film.visible:
		return
	var audio := get_tree().root.get_node_or_null("Audio")
	if audio != null:
		audio.musique(_musique_avant)
	var anim := create_tween()
	anim.tween_property(_film, "modulate:a", 0.0, 0.5)
	anim.tween_callback(func():
		_film.visible = false
		for image in _film_images:
			image.modulate = Color(1, 1, 1, 0)
		_voile.color = Color(0, 0, 0, 0.62)
		_panneau.visible = true
		if _bouton_action.visible:
			_bouton_action.grab_focus())


func bande_annonce_en_cours() -> bool:
	return _film != null and _film.visible


# --- Actions ---------------------------------------------------------------------

func _agir() -> void:
	if not _action.is_valid():
		return
	_audio("valider")
	var action := _action
	action_choisie.emit()
	_fermer_sans_son()
	action.call()


func fermer() -> void:
	_audio("fermer")
	_fermer_sans_son()


func _fermer_sans_son() -> void:
	if is_queued_for_deletion():
		return
	if bande_annonce_en_cours():
		var audio := get_tree().root.get_node_or_null("Audio")
		if audio != null:
			audio.musique(_musique_avant)
	remove_from_group("cinematique_en_cours")
	remove_from_group("affiche_activite")
	fermee.emit()
	queue_free()


func _audio(nom: String) -> void:
	var audio := get_tree().root.get_node_or_null("Audio")
	if audio != null and audio.has_method("interface"):
		audio.interface(nom)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var touche := (event as InputEventKey).keycode
	if bande_annonce_en_cours():
		if touche in [KEY_SPACE, KEY_ESCAPE]:
			_finir_bande_annonce()
		elif touche in [KEY_ENTER, KEY_KP_ENTER] and _carton_final:
			_agir()
	elif touche == KEY_ESCAPE:
		fermer()
	elif touche in [KEY_ENTER, KEY_KP_ENTER]:
		_agir()
	elif touche == KEY_B:
		lancer_bande_annonce()
	get_viewport().set_input_as_handled()
