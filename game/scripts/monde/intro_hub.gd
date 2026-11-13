extends Node
## Introduction du jeu dans Hikari Bay (environ 5 minutes) et voyage vers les îles.
##
## La première fois, le joueur est recruté près de la fontaine, descend au QG
## de la Vigie par la station Asahi, reçoit sa mission de la commandante, puis
## traverse le portail de la Préhistoire. Une fois l'intro terminée, ce nœud
## sert seulement à voyager : traverser un portail allumé mène à l'île.
##
## Les textes et les étapes viennent de data/hub_intro.json.
## L'avancement est gardé dans user://progression.cfg.

## Chargés directement (et non par nom de classe) : le jeu fonctionne même si
## l'éditeur Godot était ouvert pendant la mise à jour du dossier.
const Pnj := preload("res://scripts/monde/pnj.gd")

signal etape_changee(id: String)
## Émis quand le joueur part vers une île (avant le changement de scène).
signal voyage_demande(epoque: String, scene: String)

const DONNEES := "res://data/hub_intro.json"
const OR := Color(1.0, 0.82, 0.35)

## Coche pour rejouer l'introduction à chaque lancement (pratique pour la tester).
@export var toujours_rejouer := false
## Décoche pour rester dans le hub au lieu de charger l'île (utilisé par les tests).
@export var voyage_reel := true
@export var fichier_progression := "user://progression.cfg"

var donnees := {}
var etapes: Array = []
## Numéro de l'étape en cours (-1 : intro terminée ou désactivée).
var etape := -1

var _ecran: CanvasLayer
var _objectif: PanelContainer
var _texte_objectif: Label
var _distance: Label
var _voile: ColorRect
var _titre: Label
var _sous_titre: Label
var _recit: Label
var _repere: Node3D
var _cone: MeshInstance3D
var _faisceau: MeshInstance3D
var _temps := 0.0
var _en_voyage := false


func _ready() -> void:
	add_to_group("voyage")
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		donnees = lu
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	etapes = donnees.get("etapes", [])
	_construire_ecran()
	_construire_repere()
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null:
		dialogue.termine.connect(_sur_dialogue_termine)
	if toujours_rejouer or not intro_terminee():
		_ouverture.call_deferred()
		_aller_a.call_deferred(0)
	else:
		_aller_a.call_deferred(-1)


# --- Progression ---------------------------------------------------------

func intro_terminee() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(fichier_progression) != OK:
		return false
	return bool(cfg.get_value("intro", "terminee", false))


func _marquer_intro_terminee() -> void:
	var cfg := ConfigFile.new()
	cfg.load(fichier_progression)
	cfg.set_value("intro", "terminee", true)
	cfg.save(fichier_progression)


func etape_actuelle() -> Dictionary:
	return etapes[etape] if etape >= 0 and etape < etapes.size() else {}


func _aller_a(numero: int) -> void:
	# On rend leurs répliques normales aux personnages de l'étape précédente.
	var avant := etape_actuelle()
	if avant.has("pnj"):
		var pnj := _trouver_pnj(avant["pnj"])
		if pnj != null:
			pnj.repliques_speciales = PackedStringArray()
	etape = numero if numero >= 0 and numero < etapes.size() else -1
	var e := etape_actuelle()
	if e.has("pnj") and e.has("repliques"):
		var pnj := _trouver_pnj(e["pnj"])
		if pnj != null:
			pnj.repliques_speciales = PackedStringArray(e["repliques"])
	_objectif.visible = etape >= 0
	if etape >= 0:
		_texte_objectif.text = e.get("objectif", "")
		var anim := create_tween()
		_objectif.modulate.a = 0.0
		anim.tween_property(_objectif, "modulate:a", 1.0, 0.6)
	etape_changee.emit(e.get("id", ""))


func _suivante() -> void:
	_aller_a(etape + 1)


func _trouver_pnj(id: String) -> Pnj:
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if pnj is Pnj and pnj.identifiant == id:
			return pnj
	return null


func _sur_dialogue_termine(id_pnj: String) -> void:
	var e := etape_actuelle()
	if e.get("pnj", "") == id_pnj:
		_suivante()


# --- Chaque image ---------------------------------------------------------

func _process(delta: float) -> void:
	_temps += delta
	var e := etape_actuelle()
	var cible = _position_cible(e)
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	_repere.visible = cible != null and not _en_voyage
	if cible == null:
		_distance.text = ""
		return
	# Le pnj a pu être reconstruit (bouton « Reconstruire ») : on lui redonne ses répliques.
	if e.has("pnj") and e.has("repliques"):
		var pnj := _trouver_pnj(e["pnj"])
		if pnj != null and pnj.repliques_speciales.is_empty():
			pnj.repliques_speciales = PackedStringArray(e["repliques"])
	_repere.global_position = cible
	# Sous terre, le faisceau s'arrête au plafond.
	var hauteur := 7.0 if cible.y < -2.0 else 30.0
	(_faisceau.mesh as CylinderMesh).height = hauteur
	_faisceau.position.y = hauteur * 0.5
	_cone.position.y = 2.7 + sin(_temps * 3.0) * 0.15
	_cone.rotation.y = _temps * 1.5
	if joueur == null:
		return
	var ecart := joueur.global_position.distance_to(cible)
	_distance.text = "%d m" % roundi(ecart)
	if e.has("zone") and ecart < float(e.get("rayon", 4.0)):
		_suivante()


func _position_cible(e: Dictionary):
	if e.has("pnj"):
		var pnj := _trouver_pnj(e["pnj"])
		return pnj.global_position if pnj != null else null
	if e.has("zone"):
		var z: Array = e["zone"]
		return Vector3(z[0], z[1], z[2])
	if e.has("portail"):
		for zone in get_tree().get_nodes_in_group("portail_actif"):
			if zone.get_meta("epoque", "") == e["portail"]:
				return (zone as Node3D).global_position + Vector3(0, -2.5, 0)
	return null


# --- Voyage ---------------------------------------------------------------

## Appelé par le hub quand le joueur entre dans un portail allumé.
## Renvoie les répliques à afficher si le portail refuse (vide = départ accepté).
func demander_voyage(epoque: String) -> PackedStringArray:
	if _en_voyage:
		return PackedStringArray()
	var e := etape_actuelle()
	if etape >= 0 and e.get("portail", "") != epoque:
		return PackedStringArray(donnees.get("portail_verrouille", ["Le portail refuse de s'ouvrir."]))
	var destination: Dictionary = donnees.get("destinations", {}).get(epoque, {})
	var scene: String = destination.get("scene", "")
	if scene == "" or not ResourceLoader.exists(scene):
		return PackedStringArray(["Le portail bourdonne, mais l'île de cette époque n'est pas encore prête."])
	if Reseau.mode != Reseau.Mode.SEUL:
		return PackedStringArray(["Le portail bourdonne, mais refuse de s'ouvrir.",
				"(Le voyage en groupe vers les îles arrive bientôt. Pour l'instant, il se fait en solo.)"])
	if etape >= 0:
		_marquer_intro_terminee()
		_aller_a(-1)
	_partir(epoque, scene, destination)
	return PackedStringArray()


func _partir(epoque: String, scene: String, destination: Dictionary) -> void:
	_en_voyage = true
	voyage_demande.emit(epoque, scene)
	_titre.text = destination.get("titre", epoque)
	_sous_titre.text = destination.get("sous_titre", "")
	_recit.text = ""
	var anim := create_tween()
	anim.tween_property(_voile, "color:a", 1.0, 1.2)
	anim.parallel().tween_property(_titre, "modulate:a", 1.0, 1.2).set_delay(0.6)
	anim.parallel().tween_property(_sous_titre, "modulate:a", 1.0, 1.2).set_delay(1.0)
	anim.tween_interval(1.8)
	if voyage_reel:
		anim.tween_callback(func(): get_tree().change_scene_to_file(scene))
	else:
		anim.tween_callback(func(): _en_voyage = false)


# --- Ouverture (écran noir puis la ville apparaît) -------------------------

func _ouverture() -> void:
	var o: Dictionary = donnees.get("ouverture", {})
	_titre.text = o.get("titre", "Hikari Bay")
	_sous_titre.text = o.get("sous_titre", "")
	_recit.text = o.get("texte", "")
	_voile.color.a = 1.0
	_titre.modulate.a = 0.0
	_sous_titre.modulate.a = 0.0
	_recit.modulate.a = 0.0
	var anim := create_tween()
	anim.tween_property(_titre, "modulate:a", 1.0, 1.2)
	anim.tween_property(_sous_titre, "modulate:a", 1.0, 1.0)
	anim.tween_property(_recit, "modulate:a", 1.0, 1.2)
	anim.tween_interval(3.5)
	anim.tween_property(_titre, "modulate:a", 0.0, 1.0)
	anim.parallel().tween_property(_sous_titre, "modulate:a", 0.0, 1.0)
	anim.parallel().tween_property(_recit, "modulate:a", 0.0, 1.0)
	anim.tween_property(_voile, "color:a", 0.0, 2.0)


# --- Construction de l'interface et du repère ------------------------------

func _construire_ecran() -> void:
	_ecran = CanvasLayer.new()
	_ecran.layer = 4
	add_child(_ecran)
	# Objectif en haut au centre.
	_objectif = PanelContainer.new()
	_objectif.anchor_left = 0.5
	_objectif.anchor_right = 0.5
	_objectif.offset_left = -250
	_objectif.offset_right = 250
	_objectif.offset_top = 14
	_objectif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.75)
	style.border_color = Color(OR, 0.8)
	style.border_width_bottom = 2
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_objectif.add_theme_stylebox_override("panel", style)
	_ecran.add_child(_objectif)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	_objectif.add_child(colonne)
	var entete := Label.new()
	entete.text = "OBJECTIF"
	entete.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entete.add_theme_font_size_override("font_size", 13)
	entete.add_theme_color_override("font_color", OR)
	colonne.add_child(entete)
	_texte_objectif = Label.new()
	_texte_objectif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte_objectif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte_objectif.add_theme_font_size_override("font_size", 19)
	colonne.add_child(_texte_objectif)
	_distance = Label.new()
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distance.add_theme_font_size_override("font_size", 14)
	_distance.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	colonne.add_child(_distance)
	_objectif.visible = false
	# Voile noir et textes pour l'ouverture et les voyages.
	var cinema := CanvasLayer.new()
	cinema.layer = 20
	add_child(cinema)
	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 0)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema.add_child(_voile)
	_titre = _texte_cinema(cinema, 54, -90, Color(1, 1, 1))
	_sous_titre = _texte_cinema(cinema, 22, -20, OR)
	_recit = _texte_cinema(cinema, 20, 40, Color(0.8, 0.8, 0.88))


func _texte_cinema(parent: Node, taille: int, decalage: float, couleur: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.anchor_left = 0.2
	l.anchor_right = 0.8
	l.offset_left = 0
	l.offset_right = 0
	l.offset_top = decalage
	l.offset_bottom = decalage + taille * 3
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	parent.add_child(l)
	return l


func _construire_repere() -> void:
	_repere = Node3D.new()
	_repere.name = "RepereObjectif"
	add_child(_repere)
	var lumineux := StandardMaterial3D.new()
	lumineux.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lumineux.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lumineux.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lumineux.albedo_color = Color(OR, 0.12)
	lumineux.cull_mode = BaseMaterial3D.CULL_DISABLED
	_faisceau = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.25
	tube.bottom_radius = 0.45
	tube.height = 30.0
	tube.cap_top = false
	tube.cap_bottom = false
	_faisceau.mesh = tube
	_faisceau.material_override = lumineux
	_faisceau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_repere.add_child(_faisceau)
	# Petite flèche dorée qui flotte au-dessus de la cible (visible à travers les murs).
	var fleche := StandardMaterial3D.new()
	fleche.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fleche.albedo_color = OR
	fleche.no_depth_test = true
	fleche.render_priority = 10
	_cone = MeshInstance3D.new()
	var pointe := CylinderMesh.new()
	pointe.top_radius = 0.3
	pointe.bottom_radius = 0.0
	pointe.height = 0.55
	pointe.radial_segments = 4
	pointe.rings = 1
	_cone.mesh = pointe
	_cone.material_override = fleche
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_repere.add_child(_cone)
	_repere.visible = false
