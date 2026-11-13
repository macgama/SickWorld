extends Node
## La carte du joueur : sait dans quelle zone il est, lève le brouillard là où
## il passe, dessine la carte de chaque zone et garde tout ça en mémoire pour
## chaque personnage (dans user://cartes/, en attendant les comptes en ligne).
##
## Ne fait rien tant qu'il n'y a pas de ZoneCarte dans la scène ou de joueur
## local (menu, création de personnage, serveur dédié).
## L'affichage (mini-carte, grande carte avec M) est dans carte_interface.gd.

signal zone_changee(zone: Node3D)
## Émis quand de nouvelles cases du brouillard ont été dévoilées.
signal brouillard_change

const INTERFACE := preload("res://scripts/interface/carte_interface.gd")
const DOSSIER := "user://cartes"
## Nombre maximal de mesures de hauteur par côté pour dessiner le relief.
const RESOLUTION_RELIEF := 256
## Nombre maximal de pixels par côté pour la vue de dessus.
const RESOLUTION_VUE := 1024
## Lumière du relief : vient du nord-ouest, comme sur les cartes papier.
const LUMIERE := Vector3(-1.0, 1.6, -1.0)

## Zone où se trouve le joueur (null s'il n'est dans aucune zone).
var zone: Node3D
## Carte de la zone (couleurs), relief (ombrage) et brouillard (blanc = découvert).
var texture_carte: Texture2D
var texture_relief: ImageTexture
var texture_brouillard: ImageTexture
## Personnage dont on affiche la carte (son nom, nettoyé).
var personnage := ""
## Mettre à false pour ne jamais faire la vue de dessus (tests, PC lents).
var vue_de_dessus := true

var _brouillard: Image
var _cases_decouvertes := 0
var _sauvegarde := ConfigFile.new()
var _modifie := false
var _minuteur := 0.0
var _depuis_sauvegarde := 0.0
## Cartes déjà dessinées pendant cette partie : identifiant -> [carte, relief].
var _cartes := {}
var _personnage_force := ""
var _interface: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_interface = INTERFACE.new()
	add_child(_interface)


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST or quoi == NOTIFICATION_PREDELETE:
		sauver()


func _process(delta: float) -> void:
	_depuis_sauvegarde += delta
	_minuteur += delta
	if _minuteur < 0.15:
		return
	_minuteur = 0.0
	var joueur := joueur_local()
	if joueur == null:
		if zone != null:
			_changer_zone(null)
		return
	var cle := _personnage_force if _personnage_force != "" else _cle_personnage(joueur)
	if cle != personnage:
		_changer_personnage(cle)
	var z := zone_pour(joueur.global_position)
	if z != zone:
		_changer_zone(z)
	if zone != null:
		reveler(joueur.global_position, zone.rayon())
	if _modifie and _depuis_sauvegarde > 15.0:
		sauver()


func joueur_local() -> Node3D:
	if not is_inside_tree():
		return null
	var j := get_tree().get_first_node_in_group("joueur_local") as Node3D
	return j if j != null and j.is_inside_tree() else null


## La plus petite zone qui contient ce point (ou null).
func zone_pour(point: Vector3) -> Node3D:
	var meilleure: Node3D = null
	for z in get_tree().get_nodes_in_group("zones_carte"):
		if z.is_inside_tree() and z.contient(point):
			if meilleure == null or z.volume() < meilleure.volume():
				meilleure = z
	return meilleure


## Pour les tests : impose le personnage (sinon, c'est le nom du joueur local).
func forcer_personnage(nom: String) -> void:
	_personnage_force = _nettoyer(nom)


# --- Brouillard ---------------------------------------------------------------

## Dévoile un disque de la carte autour de « point » (rayon en mètres).
func reveler(point: Vector3, rayon: float) -> void:
	if zone == null or _brouillard == null or not zone.brouillard:
		return
	var b: AABB = zone.boite()
	var taille := _brouillard.get_size()
	var m := b.size.x / taille.x
	var cx := (point.x - b.position.x) / m
	var cz := (point.z - b.position.z) / m
	var r := rayon / m
	var bord := maxf(r * 0.3, 1.0)
	var change := false
	for y in range(maxi(0, floori(cz - r)), mini(taille.y, ceili(cz + r) + 1)):
		for x in range(maxi(0, floori(cx - r)), mini(taille.x, ceili(cx + r) + 1)):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cz).length()
			if d > r:
				continue
			var valeur := clampf((r - d) / bord, 0.0, 1.0)
			var avant := _brouillard.get_pixel(x, y).r
			if valeur > avant + 0.01:
				_brouillard.set_pixel(x, y, Color(valeur, valeur, valeur))
				if avant < 0.5 and valeur >= 0.5:
					_cases_decouvertes += 1
				change = true
	if change:
		_modifie = true
		texture_brouillard.update(_brouillard)
		brouillard_change.emit()


## Dévoile toute la zone actuelle.
func reveler_tout() -> void:
	if _brouillard == null:
		return
	_brouillard.fill(Color.WHITE)
	_cases_decouvertes = _brouillard.get_width() * _brouillard.get_height()
	_modifie = true
	texture_brouillard.update(_brouillard)
	brouillard_change.emit()


## Le joueur a-t-il déjà vu cet endroit ?
func est_decouvert(point: Vector3) -> bool:
	if zone == null or not zone.contient(point):
		return false
	if not zone.brouillard or _brouillard == null:
		return true
	var uv: Vector2 = zone.vers_carte(point)
	var x := clampi(int(uv.x * _brouillard.get_width()), 0, _brouillard.get_width() - 1)
	var y := clampi(int(uv.y * _brouillard.get_height()), 0, _brouillard.get_height() - 1)
	return _brouillard.get_pixel(x, y).r >= 0.5


## Part de la zone actuelle déjà explorée (0 à 1).
func part_exploree() -> float:
	if zone == null:
		return 0.0
	if not zone.brouillard or _brouillard == null:
		return 1.0
	return float(_cases_decouvertes) / float(_brouillard.get_width() * _brouillard.get_height())


# --- Marqueurs ----------------------------------------------------------------

## Repères de la zone actuelle que le joueur a le droit de voir :
## [{position, type, libelle, mini}], type étant un MarqueurCarte.Type.
func marqueurs() -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	if zone == null:
		return liste
	var vus := {}
	for m in get_tree().get_nodes_in_group("marqueur_carte"):
		if m is Node3D and m.is_inside_tree():
			vus[m.get_parent()] = true
			_ajouter_repere(liste, m.global_position, m.type, m.libelle, m.toujours_visible, m.sur_mini_carte)
	for p in get_tree().get_nodes_in_group("pnj"):
		if p is Node3D and p.is_inside_tree() and not vus.has(p) and p.visible:
			var texte := String(p.get("nom")) if p.get("nom") != null else String(p.name)
			_ajouter_repere(liste, p.global_position, 3, texte, false, true)
	for p in get_tree().get_nodes_in_group("portail_actif"):
		if p is Node3D and p.is_inside_tree() and not vus.has(p):
			_ajouter_repere(liste, p.global_position, 5,
					"Portail : " + String(p.name).trim_prefix("Portail_"), false, true)
	for p in get_tree().get_nodes_in_group("balises"):
		if p is Node3D and p.is_inside_tree() and not vus.has(p):
			_ajouter_repere(liste, p.global_position, 7, "Balise de la Vigie", false, true)
	return liste


func _ajouter_repere(liste: Array[Dictionary], position: Vector3, type: int, libelle: String,
		toujours: bool, mini: bool) -> void:
	if not zone.contient(position):
		return
	if not toujours and not est_decouvert(position):
		return
	liste.append({"position": position, "type": type, "libelle": libelle, "mini": mini,
			"toujours": toujours})


# --- Changement de zone et de personnage --------------------------------------

func _changer_zone(nouvelle: Node3D) -> void:
	if zone != null and _modifie:
		sauver()
	if zone != null and is_instance_valid(zone) and zone.tree_exiting.is_connected(_sur_zone_quittee):
		zone.tree_exiting.disconnect(_sur_zone_quittee)
	zone = nouvelle
	_brouillard = null
	texture_carte = null
	texture_relief = null
	texture_brouillard = null
	if zone != null:
		zone.tree_exiting.connect(_sur_zone_quittee)
		_charger_brouillard()
		_preparer_carte()
	zone_changee.emit(zone)


func _sur_zone_quittee() -> void:
	sauver()
	_changer_zone.call_deferred(null)


func _changer_personnage(cle: String) -> void:
	sauver()
	personnage = cle
	_sauvegarde = ConfigFile.new()
	_sauvegarde.load(_fichier())
	if zone != null:
		_charger_brouillard()
		zone_changee.emit(zone)


func _cle_personnage(joueur: Node) -> String:
	var fiche := joueur.get_node_or_null("Fiche")
	if fiche != null and fiche.get("donnees") is Dictionary:
		return _nettoyer(String(fiche.donnees.get("nom", "")))
	return _nettoyer(String(joueur.get("nom")) if joueur.get("nom") != null else "")


func _nettoyer(nom: String) -> String:
	var propre := nom.strip_edges().to_lower().validate_filename().replace(" ", "_")
	return propre if propre != "" else "agent"


# --- Sauvegarde -------------------------------------------------------------

func _fichier() -> String:
	return Profil.chemin("%s/%s.cfg" % [DOSSIER, personnage])


func _charger_brouillard() -> void:
	var taille: Vector2i = zone.taille_brouillard()
	_brouillard = Image.create(taille.x, taille.y, false, Image.FORMAT_L8)
	var id := String(zone.identifiant)
	var octets = _sauvegarde.get_value("brouillard", id) if _sauvegarde.has_section_key("brouillard", id) else null
	var taille_lue = _sauvegarde.get_value("taille", id) if _sauvegarde.has_section_key("taille", id) else null
	if octets is PackedByteArray and taille_lue is Vector2i:
		var brut: PackedByteArray = octets.decompress(taille_lue.x * taille_lue.y, FileAccess.COMPRESSION_ZSTD)
		if brut.size() == taille_lue.x * taille_lue.y:
			var lue := Image.create_from_data(taille_lue.x, taille_lue.y, false, Image.FORMAT_L8, brut)
			if taille_lue != taille:
				lue.resize(taille.x, taille.y, Image.INTERPOLATE_BILINEAR)
			_brouillard = lue
	if not zone.brouillard:
		_brouillard.fill(Color.WHITE)
	_cases_decouvertes = 0
	var donnees := _brouillard.get_data()
	for v in donnees:
		if v >= 128:
			_cases_decouvertes += 1
	texture_brouillard = ImageTexture.create_from_image(_brouillard)
	_modifie = false


## Enregistre le brouillard de la zone actuelle sur le disque.
func sauver() -> void:
	_depuis_sauvegarde = 0.0
	if zone == null or _brouillard == null or personnage == "" or not _modifie:
		return
	var id := String(zone.identifiant)
	_sauvegarde.set_value("taille", id, _brouillard.get_size())
	_sauvegarde.set_value("brouillard", id, _brouillard.get_data().compress(FileAccess.COMPRESSION_ZSTD))
	DirAccess.make_dir_recursive_absolute(Profil.chemin(DOSSIER))
	if _sauvegarde.save(_fichier()) == OK:
		_modifie = false


## Efface la carte d'un personnage (quand on le supprime, par exemple).
func effacer_personnage(nom: String) -> void:
	var chemin := Profil.chemin("%s/%s.cfg" % [DOSSIER, _nettoyer(nom)])
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	if _nettoyer(nom) == personnage:
		_sauvegarde = ConfigFile.new()
		if zone != null:
			_modifie = false
			_charger_brouillard()


# --- Dessin de la carte ---------------------------------------------------------

func _preparer_carte() -> void:
	var id := String(zone.identifiant)
	if _cartes.has(id):
		texture_carte = _cartes[id][0]
		texture_relief = _cartes[id][1]
		return
	var resultat := _mesurer_relief(zone)
	texture_relief = ImageTexture.create_from_image(resultat[1])
	texture_carte = zone.image if zone.image != null else ImageTexture.create_from_image(resultat[0])
	_cartes[id] = [texture_carte, texture_relief]
	if zone.image == null and vue_de_dessus and DisplayServer.get_name() != "headless":
		_photographier(zone)


## Mesure la hauteur du sol sur une grille (rayons vers le bas) et en tire
## une carte de couleurs (selon l'altitude) et un ombrage du relief.
func _mesurer_relief(z: Node3D) -> Array[Image]:
	var b: AABB = z.boite()
	var pas := maxf(0.5, maxf(b.size.x, b.size.z) / RESOLUTION_RELIEF)
	var l := maxi(2, ceili(b.size.x / pas))
	var h := maxi(2, ceili(b.size.z / pas))
	var hauteurs := PackedFloat32Array()
	hauteurs.resize(l * h)
	var espace := z.get_world_3d().direct_space_state
	var rayon := PhysicsRayQueryParameters3D.new()
	rayon.collision_mask = 1
	var bas := INF
	var haut := -INF
	for y in h:
		for x in l:
			var px := b.position.x + (x + 0.5) * pas
			var pz := b.position.z + (y + 0.5) * pas
			rayon.from = Vector3(px, b.end.y, pz)
			rayon.to = Vector3(px, b.position.y, pz)
			var touche := espace.intersect_ray(rayon)
			var valeur := NAN
			if not touche.is_empty():
				valeur = touche.position.y
				bas = minf(bas, valeur)
				haut = maxf(haut, valeur)
			hauteurs[y * l + x] = valeur
	if bas == INF:
		bas = 0.0
		haut = 1.0
	var couleurs := Image.create(l, h, false, Image.FORMAT_RGB8)
	var relief := Image.create(l, h, false, Image.FORMAT_L8)
	var lumiere := LUMIERE.normalized()
	var ecart := maxf(haut - bas, 1.0)
	for y in h:
		for x in l:
			var v := hauteurs[y * l + x]
			if is_nan(v):
				couleurs.set_pixel(x, y, z.couleur_vide)
				relief.set_pixel(x, y, Color(0.5, 0.5, 0.5))
				continue
			var t := (v - bas) / ecart
			couleurs.set_pixel(x, y, Color(0.24, 0.33, 0.22).lerp(Color(0.62, 0.58, 0.48), t))
			var dx := (_hauteur(hauteurs, l, h, x + 1, y, v) - _hauteur(hauteurs, l, h, x - 1, y, v)) / (2.0 * pas)
			var dz := (_hauteur(hauteurs, l, h, x, y + 1, v) - _hauteur(hauteurs, l, h, x, y - 1, v)) / (2.0 * pas)
			var normale := Vector3(-dx, 1.0, -dz).normalized()
			var ombre := clampf(normale.dot(lumiere) / lumiere.y, 0.35, 1.5)
			relief.set_pixel(x, y, Color(ombre * 0.5, 0, 0))
	return [couleurs, relief]


func _hauteur(hauteurs: PackedFloat32Array, l: int, h: int, x: int, y: int, defaut: float) -> float:
	if x < 0 or y < 0 or x >= l or y >= h:
		return defaut
	var v := hauteurs[y * l + x]
	return defaut if is_nan(v) else v


## Prend une photo de la zone vue du ciel (sans lumière, sans les joueurs ni
## la pluie) pour avoir les vraies couleurs du sol, des toits et des routes.
func _photographier(z: Node3D) -> void:
	var b: AABB = z.boite()
	var echelle := minf(RESOLUTION_VUE / b.size.x, RESOLUTION_VUE / b.size.z)
	var vue := SubViewport.new()
	vue.size = Vector2i(maxi(16, int(b.size.x * echelle)), maxi(16, int(b.size.z * echelle)))
	vue.world_3d = z.get_world_3d()
	vue.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	vue.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = b.size.z
	camera.near = 0.05
	camera.far = b.size.y
	var fond := Environment.new()
	fond.background_mode = Environment.BG_COLOR
	fond.background_color = z.couleur_vide
	camera.environment = fond
	vue.add_child(camera)
	camera.position = Vector3(b.get_center().x, b.end.y, b.get_center().z)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	# Cache ce qui bouge le temps de la photo.
	var caches: Array[Node3D] = []
	for groupe in ["joueur", "joueur_local", "loups", "pnj"]:
		for n in get_tree().get_nodes_in_group(groupe):
			if n is Node3D and n.visible:
				n.visible = false
				caches.append(n)
	var scene := get_tree().current_scene
	if scene != null:
		for n in scene.find_children("*", "GPUParticles3D", true, false):
			if n.visible:
				n.visible = false
				caches.append(n)
	add_child(vue)
	camera.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for n in caches:
		if is_instance_valid(n):
			n.visible = true
	var photo := vue.get_texture().get_image() if is_instance_valid(vue) else null
	vue.queue_free()
	if photo == null or photo.is_empty() or not is_instance_valid(z):
		return
	photo.convert(Image.FORMAT_RGB8)
	var texture := ImageTexture.create_from_image(photo)
	var id := String(z.identifiant)
	if _cartes.has(id):
		_cartes[id][0] = texture
	if zone == z:
		texture_carte = texture
		zone_changee.emit(zone)
