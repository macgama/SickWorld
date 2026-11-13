@tool
extends "res://scripts/monde/pnj.gd"
## Personnage non joueur d'une île (ici la Préhistoire).
## Fonctionne comme les personnages du hub (on s'approche, F pour parler), mais
## son nom et ses répliques viennent de data/prehistoire_pnj.json.
## Un personnage « blessé » est allongé au sol jusqu'à ce qu'on le soigne.

const DONNEES_EPOQUE := "res://data/prehistoire_pnj.json"

## Allongé au sol (blessé) ou debout.
@export var blesse := false:
	set(valeur):
		blesse = valeur
		_appliquer_posture()

static var _donnees_epoque := {}
var _etiquette: Label3D


static func donnees_epoque() -> Dictionary:
	if _donnees_epoque.is_empty():
		var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES_EPOQUE))
		if lu is Dictionary:
			_donnees_epoque = lu
		else:
			push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES_EPOQUE)
	return _donnees_epoque


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	var fiche: Dictionary = donnees_epoque().get(identifiant, {})
	nom = fiche.get("nom", identifiant)
	role = fiche.get("role", "")
	repliques = PackedStringArray(fiche.get("repliques", []))
	if ResourceLoader.exists(SCENE_APPARENCE):
		_apparence = (load(SCENE_APPARENCE) as PackedScene).instantiate()
		_apparence.set("modele", fiche.get("modele", "homme"))
		add_child(_apparence)
		_habiller.call_deferred(fiche)
	_etiquette = Label3D.new()
	_etiquette.text = nom + ("\n" + role if role != "" else "")
	_etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiquette.font_size = 40
	_etiquette.pixel_size = 0.005
	_etiquette.outline_size = 10
	_etiquette.modulate = Color(1.0, 0.92, 0.55)
	add_child(_etiquette)
	_invite = Label3D.new()
	_invite.text = "[F] Parler"
	_invite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_invite.font_size = 36
	_invite.pixel_size = 0.005
	_invite.outline_size = 10
	_invite.visible = false
	add_child(_invite)
	_appliquer_posture()


## Tenue d'époque (objets de data/objets.json, ex. la cape de fourrure) et teinte de peau.
func _habiller(fiche: Dictionary) -> void:
	if _apparence == null or not is_instance_valid(_apparence):
		return
	if fiche.has("peau") and _apparence.has_method("appliquer"):
		_apparence.appliquer({"sexe": fiche.get("modele", "homme"),
				"taille_cm": fiche.get("taille_cm", 175 if fiche.get("modele", "homme") == "homme" else 165),
				"peau": Color.from_string(String(fiche["peau"]), Color.WHITE)})
	if fiche.has("habits"):
		_teindre_habits(Color.from_string(String(fiche["habits"]), Color.WHITE))
	if not fiche.has("tenue") or not _apparence.has_method("equiper"):
		return
	var objets: Dictionary = _catalogue().get("objets", {})
	var visuels := {}
	for id in fiche["tenue"]:
		var o: Dictionary = objets.get(id, {})
		if o.has("visuel") and o.has("emplacement"):
			visuels[o["emplacement"]] = o["visuel"]
	_apparence.equiper(visuels)


## Teint les vêtements du modèle (t-shirt, pantalon, chaussures) en couleurs de peau
## tannée, pour qu'un habitant de l'époque ne porte pas un jean bleu.
## La peau, les yeux et les cheveux ne changent pas.
func _teindre_habits(teinte: Color) -> void:
	for n in _apparence.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as StandardMaterial3D
		if m == null or m.subsurf_scatter_enabled or m.roughness < 0.2 \
				or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var gris := m.duplicate() as StandardMaterial3D
		gris.albedo_color = teinte
		gris.roughness = 0.9
		(n as MeshInstance3D).material_override = gris


static var _objets := {}


static func _catalogue() -> Dictionary:
	if _objets.is_empty():
		var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/objets.json"))
		if lu is Dictionary:
			_objets = lu
	return _objets


func _appliquer_posture() -> void:
	if _etiquette == null or not is_instance_valid(_etiquette):
		return
	_etiquette.position = Vector3(0, 1.1 if blesse else 2.15, 0)
	_invite.position = Vector3(0, 0.6 if blesse else 1.0, 0)
	if _apparence == null or Engine.is_editor_hint():
		return
	# L'animation « mort » du personnage le laisse allongé : parfait pour un blessé.
	if blesse:
		_apparence.call_deferred("mourir")
	else:
		_apparence.call_deferred("revivre")


## Répliques à dire maintenant (celles de la quête d'abord, puis celles du blessé).
func repliques_du_moment() -> PackedStringArray:
	if not repliques_speciales.is_empty():
		return repliques_speciales
	if blesse:
		return PackedStringArray(donnees_epoque().get(identifiant, {}).get("repliques_blesse", repliques))
	return repliques


## Quand une action de quête est possible au même endroit (par exemple soigner
## ce personnage), F sert à cette action et non à parler.
func _action_de_quete_proche() -> bool:
	for objet in get_tree().get_nodes_in_group("objet_quete"):
		if objet.get("actif") and (objet as Node3D).global_position.distance_to(global_position) < PORTEE:
			return true
	return false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _invite == null:
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var occupe: bool = dialogue != null and dialogue.est_ouvert()
	_invite.visible = is_visible_in_tree() and _joueur_proche() and not occupe and not _action_de_quete_proche() \
			and not repliques_du_moment().is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed("interagir"):
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue == null or dialogue.est_ouvert() or not is_visible_in_tree() or not _joueur_proche() \
			or _action_de_quete_proche():
		return
	get_viewport().set_input_as_handled()
	parler()


func parler() -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue == null:
		return
	dialogue.ouvrir(identifiant, nom, repliques_du_moment())
	parle.emit(identifiant)
