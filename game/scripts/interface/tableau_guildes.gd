extends CanvasLayer
## Le TABLEAU DE RECRUTEMENT de la Maison des guildes : toutes les guildes du serveur,
## avec leur blason, leur devise, leur taille. On rejoint en un clic une guilde dont le
## recrutement est ouvert (sinon, sur invitation). Les officiers et le maître y règlent
## le blason, la devise et l'ouverture du recrutement de leur guilde.
## Ouverture : TableauGuildes.ouvrir(get_tree()) (le liège « Recrutement » de la Maison
## des guildes, [F]). Tout passe par le serveur (autoload Guildes).

const Style := preload("res://scripts/interface/style_menu.gd")
const Blason := preload("res://scripts/interface/dessin_blason.gd")
const R := preload("res://scripts/guildes/regles_guildes.gd")
const MOI := "res://scripts/interface/tableau_guildes.gd"
const OR := Color(1.0, 0.82, 0.42)

var _liste: VBoxContainer
var _ma_guilde: VBoxContainer
var _vide: Label
var _apercu: Control
var _forme := 0
var _symbole := 0
var _ouvert: CheckButton
var _devise: LineEdit
var _d := {}


static func ouvrir(arbre: SceneTree) -> CanvasLayer:
	for ancien in arbre.get_nodes_in_group("tableau_guildes"):
		ancien.queue_free()
	var t: CanvasLayer = load(MOI).new()
	arbre.root.add_child(t)
	return t


func _ready() -> void:
	layer = 55
	add_to_group("tableau_guildes")
	add_to_group("cinematique_en_cours")
	_d = R.donnees()
	_construire()
	var g := _guildes()
	if g != null:
		g.annuaire_recu.connect(_remplir)
		g.change.connect(_sur_changement)
		g.demander_annuaire()
	_remplir_ma_guilde()
	var audio := get_tree().root.get_node_or_null("Audio")
	if audio != null:
		audio.interface("ouvrir")


func _guildes() -> Node:
	return get_tree().root.get_node_or_null("Guildes")


func _construire() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.theme = Style.theme()
	add_child(racine)
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(centre)
	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(1040, 640)
	var boite := Style.boite(Color(0.035, 0.03, 0.025, 0.97), Color(OR, 0.5), 1, 12)
	boite.content_margin_left = 26
	boite.content_margin_right = 26
	boite.content_margin_top = 20
	boite.content_margin_bottom = 18
	panneau.add_theme_stylebox_override("panel", boite)
	centre.add_child(panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	panneau.add_child(colonne)
	var titre := Label.new()
	titre.text = "TABLEAU DE RECRUTEMENT · 募集"
	titre.add_theme_font_size_override("font_size", 28)
	titre.add_theme_color_override("font_color", OR)
	colonne.add_child(titre)
	var aide := Label.new()
	aide.text = "Rejoins en un clic une guilde au recrutement ouvert. Les autres acceptent sur invitation : écris à un de leurs officiers."
	aide.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	aide.add_theme_font_size_override("font_size", 15)
	colonne.add_child(aide)
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 18)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(corps)
	# Gauche : ma guilde (blason, devise, recrutement) ou comment en fonder une.
	var gauche := PanelContainer.new()
	gauche.custom_minimum_size = Vector2(330, 0)
	gauche.add_theme_stylebox_override("panel", Style.boite(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08), 1, 8))
	corps.add_child(gauche)
	_ma_guilde = VBoxContainer.new()
	_ma_guilde.add_theme_constant_override("separation", 10)
	gauche.add_child(_ma_guilde)
	# Droite : les guildes du serveur.
	var defile := ScrollContainer.new()
	defile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corps.add_child(defile)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 10)
	defile.add_child(_liste)
	_vide = Label.new()
	_vide.text = "Le tableau se remplit…"
	_vide.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	_liste.add_child(_vide)
	var bas := HBoxContainer.new()
	colonne.add_child(bas)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(vide)
	var fermer := Button.new()
	fermer.text = "Fermer  (Échap)"
	fermer.pressed.connect(fermer_tableau)
	bas.add_child(fermer)


func _couleur(n: int) -> Color:
	return R.couleur(_d, n)


func _blason(b: Dictionary, couleur: int, taille: float) -> Control:
	var c: Control = Blason.new()
	c.custom_minimum_size = Vector2(taille, taille)
	c.forme = int(b.get("forme", 0))
	c.symbole = int(b.get("symbole", 0))
	c.couleur = _couleur(couleur)
	return c


func _remplir(liste: Array) -> void:
	for enfant in _liste.get_children():
		enfant.queue_free()
	var g := _guildes()
	var a_une_guilde: bool = g != null and g.a_une_guilde()
	var autres := 0
	for fiche in liste:
		if g != null and String(fiche.get("nom", "")) == String(g.guilde.get("nom", "")):
			continue
		autres += 1
		_liste.add_child(_carte(fiche, a_une_guilde))
	if autres == 0:
		var l := Label.new()
		l.text = "Aucune autre guilde sur ce serveur pour l'instant.\nSois le premier : fonde la tienne au registraire, au fond de la salle, et ouvre son recrutement !"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Style.TEXTE_DOUX)
		l.add_theme_font_size_override("font_size", 16)
		_liste.add_child(l)


func _carte(f: Dictionary, a_une_guilde: bool) -> Control:
	var p := PanelContainer.new()
	var ouvert := bool(f.get("ouvert", false))
	p.add_theme_stylebox_override("panel", Style.boite(Color(1, 1, 1, 0.045 if ouvert else 0.025),
			Color(OR, 0.45) if ouvert else Color(1, 1, 1, 0.07), 1, 8))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 14)
	p.add_child(ligne)
	ligne.add_child(_blason(f.get("blason", {}), int(f.get("couleur", 0)), 84))
	var infos := VBoxContainer.new()
	infos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infos.add_theme_constant_override("separation", 2)
	ligne.add_child(infos)
	var nom := Label.new()
	nom.text = String(f.get("nom", ""))
	nom.add_theme_font_size_override("font_size", 22)
	nom.add_theme_color_override("font_color", _couleur(int(f.get("couleur", 0))).lightened(0.45))
	infos.add_child(nom)
	var details := Label.new()
	details.text = "Niveau %d  ·  %d / %d membres  ·  %d en ligne  ·  maître : %s" % [int(f.get("niveau", 1)),
			int(f.get("membres", 0)), int(f.get("membres_max", 0)), int(f.get("en_ligne", 0)), String(f.get("maitre", "?"))]
	details.add_theme_font_size_override("font_size", 14)
	details.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	infos.add_child(details)
	var devise := String(f.get("devise", ""))
	if devise != "":
		var l := Label.new()
		l.text = "« %s »" % devise
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", OR)
		infos.add_child(l)
	var plein := int(f.get("membres", 0)) >= int(f.get("membres_max", 0))
	if ouvert and not plein:
		var b := Button.new()
		b.text = "REJOINDRE"
		b.custom_minimum_size = Vector2(140, 44)
		b.disabled = a_une_guilde
		b.tooltip_text = "Tu fais déjà partie d'une guilde." if a_une_guilde else "Rejoindre « %s » tout de suite." % f.get("nom", "")
		b.add_theme_stylebox_override("normal", Style.boite(Color(0.35, 0.25, 0.06, 0.95), OR, 1, 6))
		b.add_theme_stylebox_override("hover", Style.boite(Color(0.5, 0.36, 0.08, 1.0), Color.WHITE, 1, 6))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func():
			var g := _guildes()
			if g != null:
				g.rejoindre(String(f.get("nom", "")))
			b.disabled = true)
		ligne.add_child(b)
	else:
		var l := Label.new()
		l.text = "Complète" if plein else "Sur invitation"
		l.add_theme_color_override("font_color", Style.TEXTE_DOUX)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(l)
	return p


func _sur_changement() -> void:
	_remplir_ma_guilde()
	var g := _guildes()
	if g != null:
		g.demander_annuaire()


func _remplir_ma_guilde() -> void:
	for enfant in _ma_guilde.get_children():
		enfant.queue_free()
	_ouvert = null
	_devise = null
	_ma_guilde.add_child(Style.titre_section("Ma guilde"))
	var g := _guildes()
	if g == null or not g.a_une_guilde():
		var l := Label.new()
		l.text = "Tu n'as pas encore de guilde.\n\nRejoins-en une à droite, ou fonde la tienne : parle au registraire, au fond de la salle (après la mission « Trois signatures » d'Ayaka Mori).\n\nTa guilde aura son nom, sa couleur, son blason et sa devise."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(290, 0)
		l.add_theme_font_size_override("font_size", 15)
		_ma_guilde.add_child(l)
		return
	var v: Dictionary = g.guilde
	var b: Dictionary = v.get("blason", {"forme": 0, "symbole": 0})
	_forme = int(b.get("forme", 0))
	_symbole = int(b.get("symbole", 0))
	var nom := Label.new()
	nom.text = String(v.get("nom", ""))
	nom.add_theme_font_size_override("font_size", 22)
	nom.add_theme_color_override("font_color", _couleur(int(v.get("couleur", 0))).lightened(0.45))
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ma_guilde.add_child(nom)
	var centre := CenterContainer.new()
	_ma_guilde.add_child(centre)
	_apercu = _blason(b, int(v.get("couleur", 0)), 150)
	centre.add_child(_apercu)
	var droits: Dictionary = v.get("droits", {})
	var peut_blason := bool(droits.get("promouvoir", false))
	var peut_recruter := bool(droits.get("inviter", false))
	if peut_blason:
		_ma_guilde.add_child(_choix("Forme", func(sens: int):
			_forme = posmod(_forme + sens, R.NB_FORMES)
			_apercu.forme = _forme))
		_ma_guilde.add_child(_choix("Symbole", func(sens: int):
			_symbole = posmod(_symbole + sens, R.NB_SYMBOLES)
			_apercu.symbole = _symbole))
	var rec: Dictionary = v.get("recrutement", {})
	if peut_recruter:
		_ouvert = CheckButton.new()
		_ouvert.text = "Recrutement ouvert"
		_ouvert.button_pressed = bool(rec.get("ouvert", false))
		_ma_guilde.add_child(_ouvert)
		_devise = LineEdit.new()
		_devise.placeholder_text = "Votre devise (ex. « Ensemble contre l'oubli »)"
		_devise.text = String(rec.get("devise", ""))
		_devise.max_length = int(R.reglage(_d, "devise_max", 90))
		_ma_guilde.add_child(_devise)
	if peut_blason or peut_recruter:
		var enregistrer := Button.new()
		enregistrer.text = "Enregistrer"
		enregistrer.pressed.connect(_enregistrer.bind(peut_blason, peut_recruter))
		_ma_guilde.add_child(enregistrer)
	else:
		var l := Label.new()
		l.text = ("Recrutement ouvert" if rec.get("ouvert", false) else "Recrutement sur invitation") + \
				("\n« %s »" % rec["devise"] if String(rec.get("devise", "")) != "" else "")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", OR)
		_ma_guilde.add_child(l)


func _choix(titre: String, changer: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = titre
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for sens in [-1, 1]:
		var b := Button.new()
		b.text = "◀" if sens < 0 else "▶"
		b.custom_minimum_size = Vector2(44, 34)
		b.pressed.connect(changer.bind(sens))
		h.add_child(b)
	return h


func _enregistrer(blason: bool, recrutement: bool) -> void:
	var g := _guildes()
	if g == null:
		return
	if blason:
		g.changer_blason(_forme, _symbole)
	if recrutement and _ouvert != null:
		g.changer_recrutement(_ouvert.button_pressed, _devise.text)
	var audio := get_tree().root.get_node_or_null("Audio")
	if audio != null:
		audio.interface("valider")


func fermer_tableau() -> void:
	remove_from_group("cinematique_en_cours")
	remove_from_group("tableau_guildes")
	var audio := get_tree().root.get_node_or_null("Audio")
	if audio != null:
		audio.interface("fermer")
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		fermer_tableau()
		get_viewport().set_input_as_handled()
