extends Node
## Le butin des ennemis vaincus.
##
## Butin PERSONNEL : quand un ennemi meurt, le serveur tire un butin séparé pour
## chaque joueur qui a participé au combat. Chacun voit apparaître son propre petit
## sac lumineux (les autres ne le voient pas) et le ramasse avec F.
## Les tables de butin sont dans data/objets.json (partie « butin »).

## Serveur : numéro du sac -> { joueur, objets, position, fin }
var _sacs := {}
var _compteur := 0
var _hasard := RandomNumberGenerator.new()
## Chez le joueur : numéro du sac -> nœud affiché.
var _visibles := {}


func _ready() -> void:
	add_to_group("butin")
	_hasard.randomize()


func _cat() -> Dictionary:
	return Donnees.objets


# --- Serveur -----------------------------------------------------------------

## Appelé par un ennemi qui vient de mourir.
func ennemi_vaincu(ennemi: Combattant, type_ennemi: String, position_monde: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var gagnants := {}
	for source in ennemi.menace.keys():
		if not is_instance_valid(source):
			continue
		var acteur: Node = source.acteur()
		# Un loup invoqué fait gagner son maître.
		if acteur.get("maitre") is Node3D:
			acteur = acteur.maitre
		if acteur is Joueur and is_instance_valid(acteur):
			gagnants[acteur.id_reseau()] = acteur
	var n := 0
	for id_joueur in gagnants:
		var objets := Objets.tirer_butin(_cat(), type_ennemi, _hasard)
		if objets.is_empty():
			continue
		_compteur += 1
		# Les sacs de plusieurs joueurs sont un peu décalés, pour ne pas se superposer.
		var p := position_monde + Vector3(0.4 * n, 0.0, 0.3 * n)
		n += 1
		_sacs[_compteur] = {"joueur": id_joueur, "objets": objets, "position": p,
				"fin": Regles.maintenant() + float(Objets.reglage(_cat(), "duree_butin", 180))}
		Regles.chez(id_joueur, self, "_montrer", [_compteur, p, _resume(objets)])


## Sacs de butin d'un joueur (pour les tests et l'affichage serveur).
func sacs_de(id_joueur: int) -> Array:
	var liste: Array = []
	for numero in _sacs:
		if int(_sacs[numero]["joueur"]) == id_joueur:
			liste.append(numero)
	return liste


func _process(_delta: float) -> void:
	if not multiplayer.is_server() or _sacs.is_empty():
		return
	var t := Regles.maintenant()
	for numero in _sacs.keys():
		if t >= float(_sacs[numero]["fin"]):
			_fermer(numero)


@rpc("any_peer", "call_remote", "reliable")
func _demander_ramasser(numero: int) -> void:
	if not multiplayer.is_server() or not _sacs.has(numero):
		return
	var sac: Dictionary = _sacs[numero]
	var id_joueur := Regles.expediteur()
	if int(sac["joueur"]) != id_joueur:
		return
	var joueur := get_parent().get_node_or_null("Joueurs/%d" % id_joueur) as Joueur
	if joueur == null:
		return
	var distance := Vector2(joueur.global_position.x - sac["position"].x,
			joueur.global_position.z - sac["position"].z).length()
	if distance > float(Objets.reglage(_cat(), "distance_ramassage", 3.5)) + 1.5:
		Regles.chez(id_joueur, joueur.get_node("CombatJoueur"), "_recevoir_message", ["Trop loin"])
		return
	var inventaire := joueur.get_node("Inventaire")
	var avant: Array = sac["objets"]
	var restants: Array = inventaire.recevoir(avant)
	var pris: Array = []
	for o in avant:
		var reste := 0
		for r in restants:
			if r["id"] == o["id"]:
				reste = int(r["n"])
		if int(o["n"]) - reste > 0:
			pris.append({"id": o["id"], "n": int(o["n"]) - reste})
	var texte := ""
	if not pris.is_empty():
		texte = "Butin : " + _resume(pris)
	if restants.is_empty():
		_fermer(numero)
	else:
		sac["objets"] = restants
		texte += ("\n" if texte != "" else "") + "Tes sacs sont pleins"
		Regles.chez(id_joueur, self, "_montrer", [numero, sac["position"], _resume(restants)])
	Regles.chez(id_joueur, joueur.get_node("CombatJoueur"), "_recevoir_message", [texte])


func _fermer(numero: int) -> void:
	var id_joueur := int(_sacs[numero]["joueur"])
	_sacs.erase(numero)
	Regles.chez(id_joueur, self, "_cacher", [numero])


func _resume(objets: Array) -> String:
	var morceaux: Array[String] = []
	for o in objets:
		var nom := String(Objets.objet(_cat(), String(o["id"])).get("nom", o["id"]))
		morceaux.append(nom + (" x%d" % int(o["n"]) if int(o["n"]) > 1 else ""))
	return ", ".join(morceaux)


# --- Chez le joueur ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _montrer(numero: int, position_monde: Vector3, texte: String) -> void:
	if _visibles.has(numero):
		(_visibles[numero]["etiquette"] as Label3D).text = "Butin (F)\n" + texte
		_visibles[numero]["texte"] = texte
		return
	var noeud := Node3D.new()
	noeud.name = "SacDeButin%d" % numero
	add_child(noeud)
	noeud.global_position = position_monde
	var etiquette := Label3D.new()
	if DisplayServer.get_name() != "headless":
		_construire_sac(noeud)
		etiquette.text = "Butin (F)\n" + texte
		etiquette.font_size = 28
		etiquette.pixel_size = 0.0007
		etiquette.fixed_size = true
		etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiquette.outline_size = 6
		etiquette.modulate = Color(1, 0.88, 0.5)
		etiquette.position = Vector3.UP * 0.9
		etiquette.visible = false
		noeud.add_child(etiquette)
	_visibles[numero] = {"noeud": noeud, "etiquette": etiquette, "texte": texte, "position": position_monde}


@rpc("authority", "call_remote", "reliable")
func _cacher(numero: int) -> void:
	if _visibles.has(numero):
		(_visibles[numero]["noeud"] as Node).queue_free()
		_visibles.erase(numero)


## Le sac de butin le plus proche du joueur local, à portée de main (-1 si aucun).
func sac_a_portee() -> int:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return -1
	var meilleur := -1
	var distance_min := float(Objets.reglage(_cat(), "distance_ramassage", 3.5))
	for numero in _visibles:
		var p: Vector3 = _visibles[numero]["position"]
		var d := Vector2(joueur.global_position.x - p.x, joueur.global_position.z - p.z).length()
		if d <= distance_min:
			distance_min = d
			meilleur = numero
	return meilleur


func ramasser_le_plus_proche() -> bool:
	var numero := sac_a_portee()
	if numero < 0:
		return false
	Regles.au_serveur(self, "_demander_ramasser", [numero])
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interagir") and ramasser_le_plus_proche():
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	# Le nom du butin s'affiche quand on s'approche.
	if _visibles.is_empty():
		return
	var proche := sac_a_portee()
	for numero in _visibles:
		var e := _visibles[numero]["etiquette"] as Label3D
		if e.is_inside_tree():
			e.visible = numero == proche


## Un petit sac de cuir qui brille doucement (provisoire, en attendant un vrai modèle).
func _construire_sac(noeud: Node3D) -> void:
	var cuir := StandardMaterial3D.new()
	cuir.albedo_color = Color(0.42, 0.29, 0.17)
	cuir.roughness = 0.85
	cuir.emission_enabled = true
	cuir.emission = Color(1.0, 0.75, 0.3)
	cuir.emission_energy_multiplier = 0.25
	var corps := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.36
	corps.mesh = sphere
	corps.material_override = cuir
	corps.position.y = 0.18
	noeud.add_child(corps)
	var col := MeshInstance3D.new()
	var cylindre := CylinderMesh.new()
	cylindre.top_radius = 0.06
	cylindre.bottom_radius = 0.1
	cylindre.height = 0.12
	col.mesh = cylindre
	col.material_override = cuir
	col.position.y = 0.38
	noeud.add_child(col)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.8, 0.4)
	lumiere.light_energy = 0.8
	lumiere.omni_range = 2.5
	lumiere.position.y = 0.6
	noeud.add_child(lumiere)
	var anim := noeud.create_tween().set_loops()
	anim.tween_property(lumiere, "light_energy", 1.4, 0.8).set_trans(Tween.TRANS_SINE)
	anim.tween_property(lumiere, "light_energy", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
