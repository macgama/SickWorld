extends PanelContainer
## Fenêtre d'artisanat : s'ouvre quand on a fini de parler à un artisan du hub
## (Maître Tetsuo ou Mika à la forge Hinode, Léa ou Kofi chez Fil & Fibre).
##
## À gauche, les recettes de l'artisan, rangées par catégorie (onglets en haut).
## À droite, l'objet choisi, ses matériaux (ce que tu as / ce qu'il faut) et le
## bouton « Fabriquer ». Rien n'est décidé ici : le bouton envoie une demande au
## serveur (Inventaire.fabriquer), qui vérifie et range l'objet dans les sacs.
## Les recettes sont dans data/artisanat.json.

const Artisanat := preload("res://scripts/objets/artisanat.gd")
const TAILLE_LIGNE := 44
const VERT := Color(0.4, 0.9, 0.45)
const ROUGE := Color(1.0, 0.45, 0.4)

var inventaire: Node
var id_artisan := ""
var recette_choisie := ""
var categorie := ""

var _titre: Label
var _accueil: Label
var _onglets: HBoxContainer
var _liste: VBoxContainer
var _grande_icone: TextureRect
var _nom: Label
var _details: Label
var _materiaux: VBoxContainer
var _raison: Label
var _bouton: Button
var _style: StyleBoxFlat


func _ready() -> void:
	visible = false
	add_to_group("fenetre_artisanat")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.05, 0.06, 0.08, 1.0)
	_style.border_color = Color(1.0, 0.55, 0.25, 0.6)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(8)
	_style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", _style)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	add_child(colonne)

	var haut := HBoxContainer.new()
	colonne.add_child(haut)
	var textes := VBoxContainer.new()
	textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(textes)
	_titre = _texte("", 22)
	textes.add_child(_titre)
	_accueil = _texte("", 13)
	_accueil.modulate.a = 0.75
	textes.add_child(_accueil)
	var aide := _texte("Échap : fermer", 12)
	aide.modulate.a = 0.5
	haut.add_child(aide)
	var fermer := Button.new()
	fermer.text = "  ✕  "
	fermer.focus_mode = Control.FOCUS_NONE
	fermer.pressed.connect(fermer_fenetre)
	haut.add_child(fermer)

	_onglets = HBoxContainer.new()
	_onglets.add_theme_constant_override("separation", 6)
	colonne.add_child(_onglets)

	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 16)
	colonne.add_child(corps)

	var defile := ScrollContainer.new()
	defile.custom_minimum_size = Vector2(330, 430)
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corps.add_child(defile)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 4)
	defile.add_child(_liste)

	corps.add_child(_construire_details())


func _construire_details() -> Control:
	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = Vector2(420, 430)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.04)
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(12)
	cadre.add_theme_stylebox_override("panel", fond)
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 8)
	cadre.add_child(boite)

	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", 12)
	boite.add_child(entete)
	_grande_icone = TextureRect.new()
	_grande_icone.custom_minimum_size = Vector2(96, 96)
	_grande_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grande_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	entete.add_child(_grande_icone)
	_nom = _texte("", 18)
	_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entete.add_child(_nom)

	_details = _texte("", 13)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(396, 0)
	boite.add_child(_details)

	var titre := _texte("Matériaux à apporter", 15)
	titre.modulate = Color(1.0, 0.75, 0.45)
	boite.add_child(titre)
	_materiaux = VBoxContainer.new()
	_materiaux.add_theme_constant_override("separation", 4)
	boite.add_child(_materiaux)

	var espace := Control.new()
	espace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boite.add_child(espace)
	_raison = _texte("", 13)
	_raison.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_raison.custom_minimum_size = Vector2(396, 0)
	boite.add_child(_raison)
	_bouton = Button.new()
	_bouton.text = "Fabriquer"
	_bouton.custom_minimum_size = Vector2(0, 42)
	_bouton.focus_mode = Control.FOCUS_NONE
	_bouton.add_theme_font_size_override("font_size", 17)
	_bouton.pressed.connect(fabriquer)
	boite.add_child(_bouton)
	return cadre


func _texte(contenu: String, taille := 14) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	return l


# --- Ouverture ------------------------------------------------------------------

func relier(inv: Node) -> void:
	inventaire = inv
	inventaire.change.connect(rafraichir)
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null and dialogue.has_signal("termine"):
		dialogue.termine.connect(_sur_dialogue_termine)


## Après la discussion avec un artisan, son établi s'ouvre (sauf pendant une mission :
## ses répliques sont alors celles de la mission).
func _sur_dialogue_termine(id_pnj: String) -> void:
	var a := Artisanat.artisan_du_pnj(Donnees.artisanat, id_pnj)
	if a == "":
		return
	var quetes := get_tree().get_first_node_in_group("quetes")
	if quetes != null and quetes.has_method("pnj_occupe_par_mission"):
		if quetes.pnj_occupe_par_mission(id_pnj):
			return
	else:
		for n in get_tree().get_nodes_in_group("pnj"):
			if String(n.get("identifiant")) == id_pnj and not (n.get("repliques_speciales") as PackedStringArray).is_empty():
				return
	ouvrir(a)


func ouvrir(artisan: String) -> void:
	var fiche := Artisanat.artisan(Donnees.artisanat, artisan)
	if fiche.is_empty():
		return
	id_artisan = artisan
	var couleur := Color.from_string(String(fiche.get("couleur", "#ff8a3a")), Color.ORANGE)
	_style.border_color = Color(couleur, 0.65)
	_titre.text = String(fiche.get("titre", fiche.get("nom", artisan)))
	_titre.modulate = couleur
	_accueil.text = String(fiche.get("accueil", ""))
	_construire_onglets(fiche.get("categories", []))
	recette_choisie = ""
	visible = true
	rafraichir()
	_centrer.call_deferred()


func fermer_fenetre() -> void:
	visible = false


func est_ouverte() -> bool:
	return visible


func _centrer() -> void:
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).floor()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("annuler"):
		fermer_fenetre()
		get_viewport().set_input_as_handled()


## Se ferme quand le joueur s'éloigne de l'artisan.
func _process(_delta: float) -> void:
	if not visible or inventaire == null:
		return
	var joueur := inventaire.get_parent() as Node3D
	if joueur == null:
		return
	var marge: Dictionary = Donnees.artisanat.duplicate()
	marge["distance"] = float(marge.get("distance", 4.5)) + 2.0
	if not Artisanat.artisan_proche(get_tree(), marge, id_artisan, joueur.global_position):
		fermer_fenetre()


func _construire_onglets(categories: Array) -> void:
	for enfant in _onglets.get_children():
		enfant.queue_free()
	var noms: Dictionary = Donnees.artisanat.get("categories", {})
	var groupe := ButtonGroup.new()
	categorie = ""
	var premier := true
	for c in categories:
		if Artisanat.recettes_de(Donnees.artisanat, id_artisan, String(c)).is_empty():
			continue
		var b := Button.new()
		b.text = "  %s  " % noms.get(c, c)
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = premier
		b.pressed.connect(func(): choisir_categorie(String(c)))
		_onglets.add_child(b)
		if premier:
			categorie = String(c)
			premier = false


func choisir_categorie(c: String) -> void:
	categorie = c
	recette_choisie = ""
	rafraichir()


func choisir(id_recette: String) -> void:
	recette_choisie = id_recette
	rafraichir()


func fabriquer() -> void:
	if inventaire != null and recette_choisie != "":
		inventaire.fabriquer(recette_choisie)


# --- Affichage -------------------------------------------------------------------

func rafraichir() -> void:
	if not visible or inventaire == null or inventaire.etat.is_empty():
		return
	var cat: Dictionary = Donnees.objets
	var art: Dictionary = Donnees.artisanat
	var etat: Dictionary = inventaire.etat
	var recettes := Artisanat.recettes_de(art, id_artisan, categorie)
	if not recette_choisie in recettes:
		recette_choisie = String(recettes[0]) if not recettes.is_empty() else ""

	for enfant in _liste.get_children():
		_liste.remove_child(enfant)
		enfant.queue_free()
	for id in recettes:
		_liste.add_child(_ligne_recette(cat, art, etat, String(id)))

	if recette_choisie == "":
		_nom.text = "Rien à fabriquer ici"
		_details.text = ""
		_grande_icone.texture = null
		_bouton.disabled = true
		return
	var r := Artisanat.recette(art, recette_choisie)
	var donne := String(r.get("donne", ""))
	var o := Objets.objet(cat, donne)
	_grande_icone.texture = Objets.icone(donne)
	var n := maxi(1, int(r.get("quantite", 1)))
	_nom.text = String(o.get("nom", donne)) + (" × %d" % n if n > 1 else "")
	_nom.modulate = Objets.couleur_rarete(cat, donne)
	var lignes := Objets.description(cat, donne).split("\n")
	lignes.remove_at(0)
	var base := Artisanat.objet_ameliore(cat, art, recette_choisie)
	var texte := "\n".join(lignes).strip_edges()
	if base != "":
		texte = "Amélioration de « %s » : les bonus augmentent de moitié.\n%s" % [
				Objets.objet(cat, base).get("nom", base), texte]
	_details.text = texte

	for enfant in _materiaux.get_children():
		_materiaux.remove_child(enfant)
		enfant.queue_free()
	for ing in Artisanat.ingredients(art, etat, recette_choisie):
		_materiaux.add_child(_ligne_materiau(cat, ing))

	var raison := Artisanat.raison_impossible(cat, art, etat, recette_choisie)
	_bouton.disabled = raison != ""
	_bouton.text = "Améliorer" if base != "" else "Fabriquer"
	_raison.text = raison
	_raison.modulate = ROUGE if raison != "" else VERT


func _ligne_recette(cat: Dictionary, art: Dictionary, etat: Dictionary, id: String) -> Button:
	var r := Artisanat.recette(art, id)
	var donne := String(r.get("donne", ""))
	var possible := Artisanat.raison_impossible(cat, art, etat, id) == ""
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, TAILLE_LIGNE)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = Objets.icone(donne)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", TAILLE_LIGNE - 8)
	b.add_theme_constant_override("h_separation", 10)
	b.text = String(Objets.objet(cat, donne).get("nom", donne)) + ("   ✓" if possible else "")
	b.clip_text = true
	var couleur := Objets.couleur_rarete(cat, donne)
	if not possible:
		couleur = couleur.darkened(0.35)
	b.add_theme_color_override("font_color", couleur)
	b.add_theme_color_override("font_hover_color", couleur.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", couleur)
	b.toggle_mode = true
	b.button_pressed = id == recette_choisie
	b.tooltip_text = "Tu as tout ce qu'il faut" if possible else "Il manque des matériaux"
	b.pressed.connect(func(): choisir(id))
	return b


func _ligne_materiau(cat: Dictionary, ing: Dictionary) -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	var icone := TextureRect.new()
	icone.custom_minimum_size = Vector2(36, 36)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture = Objets.icone(String(ing["id"]))
	icone.tooltip_text = Objets.description(cat, String(ing["id"]))
	icone.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(icone)
	var nom := _texte(String(Objets.objet(cat, String(ing["id"])).get("nom", ing["id"])), 14)
	nom.modulate = Objets.couleur_rarete(cat, String(ing["id"]))
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ligne.add_child(nom)
	var compte := _texte("%d / %d" % [mini(int(ing["a"]), 999), int(ing["faut"])], 15)
	compte.modulate = VERT if int(ing["a"]) >= int(ing["faut"]) else ROUGE
	compte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ligne.add_child(compte)
	return ligne
