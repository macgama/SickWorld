extends CanvasLayer
## Interface de l'Arène JcJ (créée toute seule par l'autoload JcJ dans chaque partie) :
## - le bouton « Défier » sous le cadre de la cible quand on cible un autre joueur ;
## - le DÉFI reçu (Accepter / Refuser) ;
## - pendant un combat : le bandeau en haut (qui contre qui, temps restant), le compte
##   à rebours 3… 2… 1… « COMBAT ! » et le résultat (Victoire, Défaite, Égalité) ;
## - la fenêtre de l'ARÈNE (touche H, /arene ou la borne de l'entrée) : files
##   d'attente 1 contre 1 et 2 contre 2, combat en cours, classement.

const Style := preload("res://scripts/interface/style_menu.gd")
## On voit le bandeau du combat jusqu'à cette distance du terrain (mètres).
const DISTANCE_SPECTATEUR := 70.0
const VERT := Color(0.45, 1.0, 0.55)
const ROUGE := Color(1.0, 0.38, 0.32)
const OR := Color(1.0, 0.84, 0.35)

var _racine: Control
var _bouton_defier: Button
var _defi: PanelContainer
var _texte_defi: Label
var _bandeau: PanelContainer
var _titre_bandeau: Label
var _temps_bandeau: Label
var _annonce: Label
var _fenetre: PanelContainer
var _etat_fenetre: Label
var _boutons_files: Dictionary = {}
var _bouton_quitter_file: Button
var _liste_classement: VBoxContainer
var _derniere_phase := ""
var _annonce_fin := 0.0


func _ready() -> void:
	layer = 7
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.theme = Style.theme()
	add_child(_racine)
	_construire_bandeau()
	_construire_annonce()
	_construire_defi()
	_construire_fenetre()
	_bouton_defier = _petit_bouton("Défier en duel", func():
		var cible := _joueur_cible()
		if cible != null:
			JcJ.defier(String(cible.get_node("Combat").nom_affiche)))
	_bouton_defier.position = Vector2(312, 136)
	_bouton_defier.visible = false
	_racine.add_child(_bouton_defier)
	JcJ.etat_change.connect(_sur_etat)
	JcJ.defi_change.connect(_sur_defi)
	JcJ.file_change.connect(func(_f): _rafraichir_fenetre())
	JcJ.classement_recu.connect(_remplir_classement)
	_sur_etat()
	if JcJ.defi_de != "":
		_sur_defi(JcJ.defi_de, JcJ.defi_format)


func _petit_bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(action)
	return b


func _etiquette(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _joueur_cible() -> Node:
	var local := get_tree().get_first_node_in_group("joueur_local")
	if local == null:
		return null
	var cible = local.get_node("CombatJoueur").cible
	if cible == null or not is_instance_valid(cible):
		return null
	var acteur: Node = cible.acteur()
	if acteur is Joueur and acteur != local:
		return acteur
	return null


func _arene_ici() -> bool:
	return get_tree().get_first_node_in_group("arene_jcj") != null


## Vrai si notre personnage est près du terrain (on regarde le combat).
func _spectateur_proche() -> bool:
	var terrain := get_tree().get_first_node_in_group("arene_jcj") as Node3D
	var local := get_tree().get_first_node_in_group("joueur_local") as Node3D
	return terrain != null and local != null \
			and local.global_position.distance_to(terrain.global_position) < DISTANCE_SPECTATEUR


# --- Bandeau et annonces du combat ---------------------------------------------------

func _construire_bandeau() -> void:
	_bandeau = PanelContainer.new()
	_bandeau.add_theme_stylebox_override("panel", Style.boite(Color(0.05, 0.02, 0.03, 0.85), Color(ROUGE, 0.7), 1, 8))
	_bandeau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bandeau.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bandeau.position.y = 64
	_bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bandeau.visible = false
	_racine.add_child(_bandeau)
	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	_bandeau.add_child(colonne)
	_titre_bandeau = _etiquette("", 16, Style.TEXTE)
	_titre_bandeau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_titre_bandeau)
	_temps_bandeau = _etiquette("", 22, OR)
	_temps_bandeau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_temps_bandeau)


func _construire_annonce() -> void:
	_annonce = Label.new()
	_annonce.set_anchors_preset(Control.PRESET_CENTER)
	_annonce.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_annonce.grow_vertical = Control.GROW_DIRECTION_BOTH
	_annonce.position.y -= 120
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.add_theme_font_size_override("font_size", 64)
	_annonce.add_theme_constant_override("outline_size", 12)
	_annonce.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_annonce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_annonce.visible = false
	_racine.add_child(_annonce)


func _sur_etat() -> void:
	var phase := String(JcJ.etat.get("phase", ""))
	if phase != _derniere_phase:
		_derniere_phase = phase
		if phase == "combat":
			_annoncer("COMBAT !", OR, 1.5)
		elif phase == "resultat":
			_annoncer_resultat()
	_rafraichir_fenetre()


func _annoncer(texte: String, couleur: Color, duree: float) -> void:
	if not JcJ.je_me_bats() and not _spectateur_proche():
		return
	_annonce.text = texte
	_annonce.add_theme_color_override("font_color", couleur)
	_annonce.visible = true
	_annonce_fin = Regles.maintenant() + duree


func _annoncer_resultat() -> void:
	var v := int(JcJ.etat.get("vainqueur", -1))
	var equipes: Array = JcJ.etat.get("equipes", [])
	var mon_equipe := JcJ.equipe_de(Social.mon_nom())
	if v == 2 or v < 0 or v >= equipes.size():
		_annoncer("ÉGALITÉ", Style.CYAN, 3.5)
	elif mon_equipe >= 0:
		_annoncer("VICTOIRE !" if mon_equipe == v else "DÉFAITE", VERT if mon_equipe == v else ROUGE, 3.5)
	else:
		_annoncer("Victoire de\n" + " & ".join(PackedStringArray(equipes[v])), OR, 3.5)


## Le texte du compte à rebours (« 3 », « 2 », « 1 ») ou "" hors préparation.
func texte_compte() -> String:
	if String(JcJ.etat.get("phase", "")) != "preparation":
		return ""
	return str(maxi(1, ceili(JcJ.temps_restant())))


func _process(_delta: float) -> void:
	var e: Dictionary = JcJ.etat
	var visible_ici := not e.is_empty() and (JcJ.je_me_bats() or _spectateur_proche())
	_bandeau.visible = visible_ici
	if visible_ici:
		var phase := String(e.get("phase", ""))
		_titre_bandeau.text = "%s  ·  %s" % [JcJ.nom_format(String(e.get("format", ""))).to_upper(),
				JcJ.titre_combat(e.get("equipes", []))]
		var t := JcJ.temps_restant()
		match phase:
			"preparation":
				_temps_bandeau.text = "Préparez-vous…"
			"combat":
				_temps_bandeau.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
			_:
				_temps_bandeau.text = "Combat terminé"
		var compte := texte_compte()
		if compte != "" and (JcJ.je_me_bats() or _spectateur_proche()):
			_annonce.text = compte
			_annonce.add_theme_color_override("font_color", Style.TEXTE)
			_annonce.visible = true
			_annonce_fin = Regles.maintenant() + 0.3
	if _annonce.visible and Regles.maintenant() > _annonce_fin:
		_annonce.visible = false
	var cible := _joueur_cible()
	_bouton_defier.visible = cible != null and _arene_ici() and not JcJ.je_me_bats() \
			and not JcJ.se_bat(String(cible.get_node("Combat").nom_affiche))
	if _bouton_defier.visible:
		var deux := Social.groupe.size() == 2
		_bouton_defier.text = "Défier (2 contre 2 si vous êtes deux groupes de 2)" if deux else "Défier en duel"


# --- Défi reçu --------------------------------------------------------------------------

func _construire_defi() -> void:
	_defi = PanelContainer.new()
	_defi.add_theme_stylebox_override("panel", Style.boite(Style.FOND, Color(ROUGE, 0.8), 1, 8))
	_defi.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_defi.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_defi.position.y = 300
	_defi.visible = false
	_racine.add_child(_defi)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_defi.add_child(colonne)
	_texte_defi = Label.new()
	_texte_defi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_texte_defi)
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", 12)
	colonne.add_child(ligne)
	ligne.add_child(_petit_bouton("Accepter", func(): JcJ.repondre_defi(true)))
	ligne.add_child(_petit_bouton("Refuser", func(): JcJ.repondre_defi(false)))


func _sur_defi(de: String, format: String) -> void:
	_defi.visible = de != ""
	_texte_defi.text = "⚔  %s te défie à l'Arène de la baie !\n%s" % [de, JcJ.nom_format(format)]
	if format == "2c2":
		_texte_defi.text += " : ton groupe contre le sien."


# --- Fenêtre de l'Arène (touche H) ---------------------------------------------------------

func _construire_fenetre() -> void:
	_fenetre = PanelContainer.new()
	_fenetre.set_anchors_preset(Control.PRESET_CENTER)
	_fenetre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fenetre.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fenetre.custom_minimum_size = Vector2(580, 0)
	_fenetre.visible = false
	_racine.add_child(_fenetre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_fenetre.add_child(colonne)
	colonne.add_child(_etiquette("ARÈNE DE LA BAIE · 闘技場", 22, ROUGE))
	var aide := _etiquette("Affronte d'autres agents sans rien risquer : à la fin du combat, tout le monde est soigné, "
			+ "sans pénalité. Gagne en désynchronisant tous tes adversaires (ou en gardant le plus de vie après 3 minutes). "
			+ "Pour défier un joueur précis : cible-le, puis « Défier » (ou /duel Nom).", 14, Style.TEXTE_DOUX)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.custom_minimum_size.x = 540
	colonne.add_child(aide)
	_etat_fenetre = _etiquette("", 15, Style.TEXTE)
	_etat_fenetre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_fenetre.custom_minimum_size.x = 540
	colonne.add_child(_etat_fenetre)
	colonne.add_child(Style.titre_section("Files d'attente"))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	colonne.add_child(ligne)
	for format in JcJ.FORMATS:
		var b := _petit_bouton("S'inscrire : " + JcJ.nom_format(format), JcJ.inscrire.bind(format))
		_boutons_files[format] = b
		ligne.add_child(b)
	_bouton_quitter_file = _petit_bouton("Quitter la file", JcJ.desinscrire)
	colonne.add_child(_bouton_quitter_file)
	_bouton_quitter_file.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	colonne.add_child(Style.titre_section("Classement (victoires)"))
	_liste_classement = VBoxContainer.new()
	_liste_classement.add_theme_constant_override("separation", 2)
	colonne.add_child(_liste_classement)
	var fermer := _petit_bouton("Fermer (H)", basculer_fenetre)
	fermer.size_flags_horizontal = Control.SIZE_SHRINK_END
	colonne.add_child(fermer)


func basculer_fenetre() -> void:
	_fenetre.visible = not _fenetre.visible
	if _fenetre.visible:
		_rafraichir_fenetre()
		JcJ.demander_classement()


func fenetre_ouverte() -> bool:
	return _fenetre.visible


func _rafraichir_fenetre() -> void:
	if _fenetre == null or not _fenetre.visible:
		return
	var lignes: Array[String] = []
	if not _arene_ici():
		lignes.append("L'Arène se trouve à Hikari Bay, au bout du front de mer (sud-est).")
	if JcJ.combat_en_cours():
		lignes.append("En ce moment : %s — %s." % [JcJ.nom_format(String(JcJ.etat.get("format", ""))),
				JcJ.titre_combat(JcJ.etat.get("equipes", []))])
	else:
		lignes.append("L'arène est libre.")
	if JcJ.ma_file != "":
		lignes.append("Tu es inscrit : %s. Recherche d'adversaires…" % JcJ.nom_format(JcJ.ma_file))
	if Social.groupe.size() != 2:
		lignes.append("Le 2 contre 2 se joue en groupe de 2 (/inviter Nom).")
	_etat_fenetre.text = "\n".join(PackedStringArray(lignes))
	for format in _boutons_files:
		var b: Button = _boutons_files[format]
		b.disabled = JcJ.ma_file == format or JcJ.je_me_bats() or not _arene_ici() \
				or (format == "2c2" and Social.groupe.size() != 2)
	_bouton_quitter_file.visible = JcJ.ma_file != ""


func _remplir_classement(liste: Array) -> void:
	for enfant in _liste_classement.get_children():
		enfant.free()
	if liste.is_empty():
		_liste_classement.add_child(_etiquette("Personne n'a encore gagné de combat. La place est à prendre !", 14, Style.TEXTE_DOUX))
		return
	for i in liste.size():
		var l: Dictionary = liste[i]
		var texte := "%d.  %s   —   %d victoire%s, %d défaite%s   (duels %d-%d · 2c2 %d-%d)" % [i + 1, l["nom"],
				l["victoires"], "s" if int(l["victoires"]) > 1 else "", l["defaites"], "s" if int(l["defaites"]) > 1 else "",
				l["victoires_1c1"], l["defaites_1c1"], l["victoires_2c2"], l["defaites_2c2"]]
		_liste_classement.add_child(_etiquette(texte, 14, OR if i == 0 else Style.TEXTE))


# --- Touches ------------------------------------------------------------------------------

func _discussion_ouverte() -> bool:
	var s = Social.get("_interface")
	return s != null and is_instance_valid(s) and s.discussion_ouverte()


func _unhandled_input(evenement: InputEvent) -> void:
	if not (evenement is InputEventKey and evenement.pressed and not evenement.echo):
		return
	if _discussion_ouverte():
		return
	var touche := evenement as InputEventKey
	if touche.keycode == KEY_H:
		basculer_fenetre()
		get_viewport().set_input_as_handled()
	elif touche.keycode == KEY_ESCAPE and _fenetre.visible:
		basculer_fenetre()
		get_viewport().set_input_as_handled()
