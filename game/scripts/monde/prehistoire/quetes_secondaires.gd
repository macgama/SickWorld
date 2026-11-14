extends Node
## Les quêtes secondaires de l'île de la Préhistoire (data/prehistoire_secondaires.json).
##
## Plusieurs quêtes peuvent être en cours en même temps, dans n'importe quelle zone.
## Un personnage qui a une quête à proposer porte un « ! » doré au-dessus de la tête ;
## on lui parle, et la quête commence. Un « ? » indique qu'on doit revenir lui parler.
## Les quêtes en cours sont listées à droite de l'écran, sous la carte.
##
## Ce nœud est créé par la quête principale (quete.gd), dont il réutilise la barre
## d'action, les annonces, les récompenses et l'apparition des ennemis.

const DONNEES := "res://data/prehistoire_secondaires.json"
const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")
const SECTION := "prehistoire_secondaires"
const PAS_COMMENCEE := -1
const FINIE := 999
const OR := Color(1.0, 0.82, 0.35)
const NOMS_ZONES := {
	"cote_gelee": "Côte Gelée",
	"steppe": "Steppe des Mammouths",
	"foret": "Forêt des Bouleaux",
	"falaises": "Falaises Peintes",
	"grotte": "Grande Grotte",
}
## Objets détruits quand on les utilise (les objets modernes semés par les fractures).
const FORMES_CONSOMMEES := ["canette", "telephone", "lunettes"]

signal quete_changee(id: String)

var quetes: Array = []
var objets_def: Array = []
## id de quête → numéro d'étape (PAS_COMMENCEE, 0…n-1, FINIE).
var etat := {}
var compteurs := {}
var ramasses := {}
var titres: PackedStringArray = []

var _quete: Node
var _objets := {}
## id de personnage → id de la quête qui lui a donné ses répliques.
var _pnj_utilises := {}
var _marques := {}
var _cadre: PanelContainer
var _liste: VBoxContainer
var _minuterie := 0.0


func _ready() -> void:
	add_to_group("quetes_secondaires")
	_quete = get_parent()
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		quetes = lu.get("quetes", [])
		objets_def = lu.get("objets", [])
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	for q in quetes:
		etat[q.id] = PAS_COMMENCEE
		compteurs[q.id] = 0
	if not bool(_quete.get("toujours_recommencer")):
		_charger()
	_construire_ecran()
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null:
		dialogue.termine.connect(_sur_dialogue_termine)
	var loups := get_tree().get_first_node_in_group("dossier_loups")
	if loups != null:
		loups.child_entered_tree.connect(_sur_nouvel_ennemi)
		for n in loups.get_children():
			_sur_nouvel_ennemi(n)
	if _quete.has_signal("etape_changee"):
		_quete.etape_changee.connect(func(_id): _rafraichir.call_deferred())
	_installer.call_deferred()


func _zone() -> String:
	var ile := get_tree().get_first_node_in_group("ile")
	return String(ile.get("identifiant_zone")) if ile != null else ""


# --- Sauvegarde -------------------------------------------------------------------

func _charger() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_fichier()) != OK:
		return
	for q in quetes:
		etat[q.id] = int(cfg.get_value(SECTION, "etat_" + q.id, PAS_COMMENCEE))
		compteurs[q.id] = int(cfg.get_value(SECTION, "compteur_" + q.id, 0))
	for o in objets_def:
		if cfg.get_value(SECTION, "ramasse_" + o.id, false):
			ramasses[o.id] = true
	titres = PackedStringArray(cfg.get_value(SECTION, "titres", PackedStringArray()))


func _sauvegarder() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_fichier())
	for q in quetes:
		cfg.set_value(SECTION, "etat_" + q.id, etat[q.id])
		cfg.set_value(SECTION, "compteur_" + q.id, compteurs[q.id])
	for id in ramasses:
		cfg.set_value(SECTION, "ramasse_" + id, true)
	cfg.set_value(SECTION, "titres", titres)
	cfg.save(_fichier())


func _fichier() -> String:
	return Profil.chemin(String(_quete.get("fichier_progression")))


# --- État des quêtes ----------------------------------------------------------------

func quete(id: String) -> Dictionary:
	for q in quetes:
		if q.id == id:
			return q
	return {}


func etat_quete(id: String) -> int:
	return int(etat.get(id, PAS_COMMENCEE))


func en_cours(q: Dictionary) -> bool:
	var n := etat_quete(q.id)
	return n >= 0 and n < (q.etapes as Array).size()


func etape_de(q: Dictionary) -> Dictionary:
	return q.etapes[etat_quete(q.id)] if en_cours(q) else {}


## La quête principale est-elle assez avancée pour proposer cette quête ?
func debloquee(q: Dictionary) -> bool:
	var principale := int(_quete.get("etape"))
	var apres := String(q.get("apres", ""))
	if apres == "":
		return true
	if principale < 0:
		return true
	if apres == "fin":
		return false
	var etapes_principales: Array = _quete.get("etapes")
	for i in etapes_principales.size():
		if etapes_principales[i].get("id", "") == apres:
			return principale > i
	return false


func _ici(e: Dictionary) -> bool:
	return String(e.get("ou", "")) in ["", _zone()]


# --- Mise en place dans la zone -------------------------------------------------------

func _installer() -> void:
	var ile := get_tree().get_first_node_in_group("ile") as Node3D
	if ile == null:
		return
	for o in objets_def:
		if o.get("ou", "") != _zone():
			continue
		var objet := ObjetQuete.new()
		objet.name = "Secondaire_" + String(o.id)
		objet.identifiant = o.id
		objet.groupe = o.get("groupe", "")
		objet.forme = o.get("forme", "")
		objet.invite = o.get("invite", "[F] Utiliser")
		objet.set_meta("secondaire", true)
		var p: Array = o.position
		objet.position = Vector3(p[0], ile.hauteur(p[0], p[1]), p[1])
		ile.add_child(objet)
		_objets[o.id] = objet
		if ramasses.has(o.id):
			objet.ramasse = true
			if objet.forme in FORMES_CONSOMMEES or objet.groupe != "":
				objet.cacher()
	# Le monde garde la trace des étapes déjà faites (feu rallumé, main sur la paroi…).
	for q in quetes:
		var n := etat_quete(q.id)
		for i in mini(n, (q.etapes as Array).size()):
			_appliquer_effet(q.etapes[i], false)
		if en_cours(q):
			_commencer_etape(q, false)
	_rafraichir()


func _commencer_etape(q: Dictionary, _annonce: bool) -> void:
	var e := etape_de(q)
	if e.has("apparition") and _ici(e) and multiplayer.is_server():
		_quete._faire_apparaitre(e["apparition"], true)


# --- Chaque image ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_minuterie -= delta
	if _minuterie > 0.0:
		return
	_minuterie = 0.5
	_rafraichir()


## Met à jour les personnages (répliques, « ! » et « ? »), les objets utilisables
## et la liste à l'écran.
func _rafraichir() -> void:
	if _cadre != null and _cadre.visible:
		_placer_sous_l_aide()
	if not is_inside_tree():
		return
	var principal := String(_quete.etape_actuelle().get("pnj", "")) if _quete.has_method("etape_actuelle") else ""
	var voulus := {}
	for q in quetes:
		var id_pnj := ""
		var lignes: Array = []
		var signe := ""
		if etat_quete(q.id) == PAS_COMMENCEE and debloquee(q):
			id_pnj = q.donneur
			lignes = q.offre
			signe = "!"
		elif en_cours(q) and etape_de(q).has("pnj"):
			id_pnj = etape_de(q).pnj
			lignes = etape_de(q).get("repliques", [])
			signe = "?"
		if id_pnj == "" or id_pnj == principal or voulus.has(id_pnj):
			continue
		voulus[id_pnj] = [q.id, lignes, signe]
	# On rend leurs répliques aux personnages qu'on n'utilise plus.
	for id_pnj in _pnj_utilises.keys():
		if not voulus.has(id_pnj):
			var ancien = _quete._trouver_pnj(id_pnj)
			if ancien != null and id_pnj != principal:
				ancien.repliques_speciales = PackedStringArray()
			_pnj_utilises.erase(id_pnj)
	for id_pnj in voulus:
		var pnj = _quete._trouver_pnj(id_pnj)
		if pnj == null:
			continue
		var lignes := PackedStringArray(voulus[id_pnj][1])
		if pnj.repliques_speciales != lignes:
			pnj.repliques_speciales = lignes
		_pnj_utilises[id_pnj] = voulus[id_pnj][0]
	_mettre_marques(voulus)
	# Objets utilisables.
	for id in _objets:
		var objet = _objets[id]
		if not is_instance_valid(objet):
			continue
		var voulu := false
		if not objet.ramasse:
			for q in quetes:
				var e := etape_de(q)
				if e.is_empty() or not _ici(e):
					continue
				if (e.has("recolter") and e.recolter == objet.groupe) or e.get("objet", "") == id:
					voulu = true
		if objet.actif != voulu:
			objet.actif = voulu
	_mettre_a_jour_liste()


func _mettre_marques(voulus: Dictionary) -> void:
	for id_pnj in _marques.keys():
		if not voulus.has(id_pnj) or not is_instance_valid(_marques[id_pnj]):
			if is_instance_valid(_marques[id_pnj]):
				_marques[id_pnj].queue_free()
			_marques.erase(id_pnj)
	for id_pnj in voulus:
		var pnj := _quete._trouver_pnj(id_pnj) as Node3D
		if pnj == null:
			continue
		var marque: Label3D = _marques.get(id_pnj)
		if marque == null:
			marque = Label3D.new()
			marque.name = "MarqueQueteSecondaire"
			marque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marque.font_size = 120
			marque.pixel_size = 0.005
			marque.outline_size = 18
			marque.modulate = OR
			marque.position = Vector3(0, 2.75, 0)
			pnj.add_child(marque)
			_marques[id_pnj] = marque
		marque.text = voulus[id_pnj][2]


# --- Événements du jeu ------------------------------------------------------------------

func _sur_dialogue_termine(id_pnj: String) -> void:
	if not _pnj_utilises.has(id_pnj):
		return
	var q := quete(_pnj_utilises[id_pnj])
	if q.is_empty():
		return
	if etat_quete(q.id) == PAS_COMMENCEE:
		etat[q.id] = 0
		compteurs[q.id] = 0
		_sauvegarder()
		_quete.annoncer("Nouvelle quête", q.titre)
		_commencer_etape(q, true)
		quete_changee.emit(q.id)
		_rafraichir()
	elif en_cours(q) and etape_de(q).get("pnj", "") == id_pnj:
		_terminer_etape(q)


func _sur_nouvel_ennemi(n: Node) -> void:
	var combat := n.get_node_or_null("Combat")
	if combat == null or not combat.has_signal("mort"):
		return
	combat.mort.connect(func(_tueur): _sur_ennemi_vaincu(n))


func _sur_ennemi_vaincu(n: Node) -> void:
	var type := String(n.get("type_ennemi"))
	for q in quetes:
		var e := etape_de(q)
		if not e.has("tuer") or not _ici(e) or not type.begins_with(String(e.tuer)):
			continue
		compteurs[q.id] = int(compteurs[q.id]) + 1
		if compteurs[q.id] >= int(e.get("nombre", 1)):
			_terminer_etape(q)
		else:
			_sauvegarder()
			_mettre_a_jour_liste()


## Appelé par un objet de quête secondaire quand on appuie sur F à côté.
func utiliser_objet(objet: Node3D) -> void:
	for q in quetes:
		var e := etape_de(q)
		if e.is_empty() or not _ici(e):
			continue
		var bon: bool = (e.has("recolter") and e.recolter == objet.get("groupe")) or e.get("objet", "") == objet.get("identifiant")
		if not bon:
			continue
		var fin := func(o: Node3D): _objet_fini(q, o)
		var duree := float(e.get("duree", 0.0))
		if duree > 0.0:
			_quete.canaliser(objet, duree, String(e.get("action", "…")), fin)
		else:
			fin.call(objet)
		return


func _objet_fini(q: Dictionary, objet: Node3D) -> void:
	var e := etape_de(q)
	var id := String(objet.get("identifiant"))
	ramasses[id] = true
	objet.set("ramasse", true)
	objet.set("actif", false)
	if e.has("recolter") or String(objet.get("forme")) in FORMES_CONSOMMEES:
		objet.cacher()
	if e.has("recolter"):
		compteurs[q.id] = int(compteurs[q.id]) + 1
		if compteurs[q.id] >= int(e.get("nombre", 1)):
			_terminer_etape(q)
		else:
			_sauvegarder()
			_rafraichir()
		return
	_terminer_etape(q)


func _terminer_etape(q: Dictionary) -> void:
	var e := etape_de(q)
	_appliquer_effet(e, true)
	etat[q.id] = etat_quete(q.id) + 1
	compteurs[q.id] = 0
	if etat_quete(q.id) >= (q.etapes as Array).size():
		etat[q.id] = FINIE
		if q.has("recompense"):
			_quete._donner_recompense(q.recompense)
		if q.has("titre_obtenu") and not titres.has(q.titre_obtenu):
			titres.append(q.titre_obtenu)
			_quete.annoncer("Titre obtenu", "« %s »" % q.titre_obtenu)
		_quete.annoncer("Quête terminée", q.titre)
	else:
		_commencer_etape(q, true)
	_sauvegarder()
	quete_changee.emit(q.id)
	_rafraichir()


## Ce qu'une étape change dans le monde quand elle est faite.
func _appliquer_effet(e: Dictionary, _anime: bool) -> void:
	if not _ici(e) or not e.has("objet"):
		return
	var objet = _objets.get(e.objet)
	var ile := get_tree().get_first_node_in_group("ile")
	if objet == null or ile == null:
		return
	match String(e.get("effet", "")):
		"allumer":
			if objet.get_node_or_null("FeuRallume") == null and ile.has_method("_feu"):
				var avant := ile.get_child_count()
				ile._feu(ile, Vector2(objet.global_position.x, objet.global_position.z), 1.0)
				if ile.get_child_count() > avant:
					var feu := ile.get_child(ile.get_child_count() - 1)
					feu.reparent(objet)
					feu.name = "FeuRallume"
		"main":
			if objet.get_node_or_null("Main") == null and ile.has_method("_texture_main"):
				var main := Decal.new()
				main.name = "Main"
				main.texture_albedo = ile._texture_main()
				main.modulate = Color(0.62, 0.2, 0.08)
				main.albedo_mix = 0.9
				main.size = Vector3(0.9, 10.0, 0.9)
				objet.add_child(main)
				main.position = Vector3(0, 1.55, 0)
				main.look_at_from_position(main.global_position, main.global_position + Vector3(0, 0, -1), Vector3.UP)
				main.rotate_object_local(Vector3.RIGHT, -PI / 2)


# --- Liste à l'écran --------------------------------------------------------------------

func _construire_ecran() -> void:
	var ecran := CanvasLayer.new()
	ecran.layer = 4
	add_child(ecran)
	_cadre = PanelContainer.new()
	_cadre.anchor_left = 1.0
	_cadre.anchor_right = 1.0
	_cadre.offset_left = -340
	_cadre.offset_right = -14
	_cadre.offset_top = 268
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.03, 0.6)
	style.border_color = Color(OR, 0.5)
	style.border_width_left = 2
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_cadre.add_theme_stylebox_override("panel", style)
	ecran.add_child(_cadre)
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 6)
	_cadre.add_child(_liste)
	_cadre.visible = false


func _mettre_a_jour_liste() -> void:
	if _liste == null:
		return
	for enfant in _liste.get_children():
		enfant.queue_free()
	var nombre := 0
	var titre_liste := _etiquette("QUÊTES SECONDAIRES", 12, OR)
	_liste.add_child(titre_liste)
	for q in quetes:
		if not en_cours(q):
			continue
		nombre += 1
		var e := etape_de(q)
		_liste.add_child(_etiquette("◆ " + String(q.titre), 15, Color(1, 0.93, 0.75)))
		var texte := String(e.get("objectif", ""))
		if e.has("tuer") or e.has("recolter"):
			texte += " (%d/%d)" % [int(compteurs[q.id]), int(e.get("nombre", 1))]
		var ou := String(e.get("ou", ""))
		if e.has("pnj"):
			var pnj := _quete._trouver_pnj(e.pnj) as Node3D
			if pnj == null:
				texte += " · ailleurs sur l'île"
		if ou != "" and ou != _zone():
			texte += " · " + String(NOMS_ZONES.get(ou, ou))
		else:
			var d := _distance(q)
			if d >= 0.0:
				texte += " · %d m" % roundi(d)
		var ligne := _etiquette(texte, 13, Color(0.85, 0.85, 0.88))
		ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ligne.custom_minimum_size.x = 300
		_liste.add_child(ligne)
	_cadre.visible = nombre > 0
	_placer_sous_l_aide()


## L'aide des touches (F1) occupe le même coin : la liste se range juste en dessous.
func _placer_sous_l_aide() -> void:
	var hud := _quete.get_parent().get_node_or_null("Interface") if _quete.get_parent() != null else null
	var aide = hud.get("_aide") if hud != null else null
	var haut := 268.0
	if aide is Control and aide.is_visible_in_tree():
		haut = maxf(haut, aide.get_global_rect().end.y + 10.0)
	_cadre.offset_top = haut


func _distance(q: Dictionary) -> float:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return -1.0
	var e := etape_de(q)
	var meilleure := -1.0
	var cibles: Array[Vector3] = []
	if e.has("pnj"):
		var pnj := _quete._trouver_pnj(e.pnj) as Node3D
		if pnj != null:
			cibles.append(pnj.global_position)
	for id in _objets:
		var objet = _objets[id]
		if is_instance_valid(objet) and objet.actif:
			if (e.has("recolter") and e.recolter == objet.groupe) or e.get("objet", "") == id:
				cibles.append(objet.global_position)
	if e.has("apparition"):
		var p: Array = e.apparition.position
		cibles.append(Vector3(p[0], joueur.global_position.y, p[1]))
	for c in cibles:
		var d := joueur.global_position.distance_to(c)
		if meilleure < 0.0 or d < meilleure:
			meilleure = d
	return meilleure


func _etiquette(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
