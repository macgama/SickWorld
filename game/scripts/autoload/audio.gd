extends Node
## Son du jeu (autoload « Audio ») : musiques, ambiances et bruitages.
##
## Tout se règle dans data/audio.json (voir docs/guides/le-son.md) :
## - chaque scène (menu, Hikari Bay, zones de la Préhistoire…) a sa liste de
##   musiques, ses boucles d'ambiance (pluie, vent…) et ses sons ponctuels
##   (klaxons, hurlements de loups…) joués au hasard autour du joueur ;
## - les pas, les coups, les cris des bêtes sont ajoutés tout seuls à chaque
##   personnage (voir scripts/audio/bruiteur.gd) ;
## - tous les boutons du jeu font un petit bruit au clic et au survol.
##
## Bus audio (default_bus_layout.tres) : Musique, Ambiance (dont Exterieur,
## étouffé quand on passe sous un toit), Effets (écho dans les grottes) et
## Interface. Les curseurs de volume des Options règlent ces bus par leur nom.
##
## Depuis un autre script :  Audio.effet("coup", position)  ou
## Audio.interface("valider")  ou  Audio.jouer_3d("combat/lame", position).

const FICHIER_DONNEES := "res://data/audio.json"
const DOSSIER := "res://audio/"
const BRUITEUR := preload("res://scripts/audio/bruiteur.gd")
const FONDU_MUSIQUE := 2.5
const FONDU_AMBIANCE := 2.0

## Faux sur un serveur dédié (aucun son à jouer).
var actif := true
var donnees: Dictionary = {}
## Réglages de la scène en cours (copie de data/audio.json > scenes > <nom>).
var reglages_scene: Dictionary = {}
var nom_scene := ""
## Vrai quand la caméra est sous un toit (ambiances extérieures étouffées).
var interieur := false
## Derniers sons joués (pour les tests et pour comprendre ce qui se passe).
var historique: Array[String] = []

var _cache := {}
var _musique: AudioStreamPlayer
var _musique_sortante: AudioStreamPlayer
var _liste_musique := ""
var _derniere_piste := ""
var _prochaine_piste := -1.0
var _en_lecture := false
var _ambiances := {}
var _ponctuels: Array = []
var _temps := 0.0
var _scene_vue: Node
var _calme_jusqua := 0.0
var _prochain_test_toit := 0.0
var _feux_vus := {}
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hasard.randomize()
	if "--serveur" in OS.get_cmdline_user_args():
		actif = false
		return
	var resultat = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_DONNEES))
	if resultat is Dictionary:
		donnees = resultat
	else:
		push_error("Impossible de lire %s : vérifie qu'il ne manque pas une virgule ou un guillemet." % FICHIER_DONNEES)
	_musique = _nouveau_lecteur("Musique")
	_musique_sortante = _nouveau_lecteur("Musique")
	get_tree().node_added.connect(_sur_noeud_ajoute)


func _process(delta: float) -> void:
	if not actif:
		return
	_temps += delta
	var scene := get_tree().current_scene
	if scene != _scene_vue:
		_scene_vue = scene
		if scene != null:
			_changer_de_scene(scene)
	if _en_lecture and not _musique.playing:
		_en_lecture = false
		_fin_de_piste()
	if _prochaine_piste >= 0.0 and _temps >= _prochaine_piste:
		_prochaine_piste = -1.0
		_lancer_piste()
	_jouer_ponctuels()
	if _temps >= _prochain_test_toit:
		_prochain_test_toit = _temps + 0.3
		_tester_toit()


# ---------------------------------------------------------------------------
# Bruitages
# ---------------------------------------------------------------------------

## Toutes les variantes d'un son ("combat/coup" -> combat/coup_1.ogg, coup_2.ogg…).
func variantes(nom: String) -> Array:
	if _cache.has(nom):
		return _cache[nom]
	var liste := []
	var seul := DOSSIER + nom + ".ogg"
	if ResourceLoader.exists(seul):
		liste.append(load(seul))
	var i := 1
	while ResourceLoader.exists("%s%s_%d.ogg" % [DOSSIER, nom, i]):
		liste.append(load("%s%s_%d.ogg" % [DOSSIER, nom, i]))
		i += 1
	if liste.is_empty():
		push_warning("Son introuvable : %s (dossier audio/)" % nom)
	_cache[nom] = liste
	return liste


func son_au_hasard(nom: String) -> AudioStream:
	var liste := variantes(nom)
	return null if liste.is_empty() else liste[_hasard.randi() % liste.size()]


## Réglages d'un bruitage de data/audio.json (section « effets »).
func reglage_effet(id: String) -> Dictionary:
	return donnees.get("effets", {}).get(id, {})


## Joue un bruitage décrit dans la section « effets » de data/audio.json.
## lieu : une position (Vector3) ou un nœud 3D que le son suit.
func effet(id: String, lieu = null, remplacements := {}) -> AudioStreamPlayer3D:
	var r := reglage_effet(id)
	if r.is_empty():
		return null
	return jouer_reglage(r, lieu, remplacements)


## Joue un son à partir d'un dictionnaire { son, volume_db, variation, hauteur, chance, portee }.
func jouer_reglage(r: Dictionary, lieu = null, remplacements := {}) -> AudioStreamPlayer3D:
	if not actif or r.is_empty() or _hasard.randf() > float(r.get("chance", 1.0)):
		return null
	var nom := String(r.get("son", ""))
	for cle in remplacements:
		nom = nom.replace("{%s}" % cle, String(remplacements[cle]))
	var lecteur := jouer_3d(nom, lieu, float(r.get("volume_db", 0.0)), float(r.get("variation", 0.05)),
			float(r.get("portee", 12.0)))
	if lecteur != null:
		lecteur.pitch_scale *= float(r.get("hauteur", 1.0))
		if r.has("en_plus"):
			jouer_3d(String(r["en_plus"]), lieu, float(r.get("volume_db", 0.0)) - 4.0)
	return lecteur


## Joue un son placé dans le monde (il s'atténue avec la distance).
func jouer_3d(nom: String, lieu = null, volume_db := 0.0, variation := 0.05, portee := 12.0,
		bus := "Effets") -> AudioStreamPlayer3D:
	if not actif:
		return null
	var flux := son_au_hasard(nom)
	var scene := get_tree().current_scene
	if flux == null or scene == null:
		return null
	_noter(nom)
	var lecteur := AudioStreamPlayer3D.new()
	lecteur.stream = flux
	lecteur.bus = bus
	lecteur.volume_db = volume_db
	lecteur.unit_size = portee
	lecteur.max_db = 3.0
	lecteur.pitch_scale = 1.0 + _hasard.randf_range(-variation, variation)
	lecteur.attenuation_filter_cutoff_hz = 12000.0
	lecteur.attenuation_filter_db = -12.0
	if lieu is Node3D and is_instance_valid(lieu):
		lieu.add_child(lecteur)
	else:
		scene.add_child(lecteur)
		if lieu is Vector3:
			lecteur.global_position = lieu
		else:
			var camera := get_viewport().get_camera_3d()
			if camera != null:
				lecteur.global_position = camera.global_position
	lecteur.finished.connect(lecteur.queue_free)
	lecteur.play()
	return lecteur


## Joue un son d'interface (section « interface » de data/audio.json, ou un nom de fichier).
func interface(id: String) -> void:
	if not actif or _temps < _calme_jusqua:
		return
	var r: Dictionary = donnees.get("interface", {}).get(id, {"son": "interface/" + id})
	var flux := son_au_hasard(String(r.get("son", "")))
	if flux == null:
		return
	_noter(String(r.get("son", "")))
	var lecteur := _nouveau_lecteur("Interface")
	lecteur.stream = flux
	lecteur.volume_db = float(r.get("volume_db", -8.0))
	lecteur.pitch_scale = 1.0 + _hasard.randf_range(-0.03, 0.03)
	lecteur.finished.connect(lecteur.queue_free)
	lecteur.play()


# ---------------------------------------------------------------------------
# Musique
# ---------------------------------------------------------------------------

## Change la liste de musiques (data/audio.json > musiques). "" = silence.
func musique(liste: String) -> void:
	if liste == _liste_musique:
		return
	_liste_musique = liste
	_prochaine_piste = -1.0
	_en_lecture = false
	if _musique.playing:
		# L'ancienne piste s'éteint doucement pendant que la nouvelle arrive.
		var ancienne := _musique
		_musique = _musique_sortante
		_musique_sortante = ancienne
		var sortie := ancienne.create_tween()
		sortie.tween_property(ancienne, "volume_db", -60.0, FONDU_MUSIQUE)
		sortie.tween_callback(ancienne.stop)
	if liste != "":
		_prochaine_piste = _temps + 1.0


func liste_musique() -> String:
	return _liste_musique


func piste_en_cours() -> String:
	return _derniere_piste if _musique.playing else ""


func _lancer_piste() -> void:
	var r: Dictionary = donnees.get("musiques", {}).get(_liste_musique, {})
	var pistes: Array = r.get("pistes", [])
	if pistes.is_empty():
		return
	var choix := String(pistes[_hasard.randi() % pistes.size()])
	if pistes.size() > 1:
		while choix == _derniere_piste:
			choix = String(pistes[_hasard.randi() % pistes.size()])
	var flux := son_au_hasard(choix)
	if flux == null:
		return
	_derniere_piste = choix
	_musique.stream = flux
	var volume := float(r.get("volume_db", -10.0))
	_musique.volume_db = -40.0
	_musique.play()
	_en_lecture = true
	_musique.create_tween().tween_property(_musique, "volume_db", volume, FONDU_MUSIQUE)


func _fin_de_piste() -> void:
	var r: Dictionary = donnees.get("musiques", {}).get(_liste_musique, {})
	if r.is_empty():
		return
	_prochaine_piste = _temps + Donnees.entre(r.get("silence", [20, 60]))


# ---------------------------------------------------------------------------
# Scènes et ambiances
# ---------------------------------------------------------------------------

func _changer_de_scene(scene: Node) -> void:
	nom_scene = scene.scene_file_path.get_file().get_basename()
	reglages_scene = donnees.get("scenes", {}).get(nom_scene, {})
	_calme_jusqua = _temps + 1.5
	_feux_vus.clear()
	musique(String(reglages_scene.get("musique", "")))
	# Ambiances : on garde celles qui continuent, on éteint les autres en fondu.
	var voulues := {}
	for a in reglages_scene.get("ambiances", []):
		voulues[String(a["son"])] = a
	for nom in _ambiances.keys():
		if not voulues.has(nom):
			var lecteur: AudioStreamPlayer = _ambiances[nom]
			_ambiances.erase(nom)
			var sortie := lecteur.create_tween()
			sortie.tween_property(lecteur, "volume_db", -60.0, FONDU_AMBIANCE)
			sortie.tween_callback(lecteur.queue_free)
	for nom in voulues:
		var a: Dictionary = voulues[nom]
		var lecteur: AudioStreamPlayer = _ambiances.get(nom)
		if lecteur == null:
			var flux := son_au_hasard(nom)
			if flux == null:
				continue
			if flux is AudioStreamOggVorbis:
				flux.loop = true
			lecteur = _nouveau_lecteur("Exterieur" if a.get("exterieur", false) else "Ambiance")
			lecteur.stream = flux
			lecteur.volume_db = -60.0
			lecteur.play(_hasard.randf() * flux.get_length())
			_ambiances[nom] = lecteur
		lecteur.create_tween().tween_property(lecteur, "volume_db", float(a.get("volume_db", -10.0)), FONDU_AMBIANCE)
	_ponctuels.clear()
	for p in reglages_scene.get("ponctuels", []):
		var copie: Dictionary = p.duplicate()
		copie["prochain"] = _temps + Donnees.entre(p.get("intervalle", [30, 60])) * _hasard.randf_range(0.3, 1.0)
		_ponctuels.append(copie)
	var reverb := AudioServer.get_bus_index("Effets")
	if reverb >= 0 and AudioServer.get_bus_effect_count(reverb) > 0:
		AudioServer.set_bus_effect_enabled(reverb, 0, bool(reglages_scene.get("reverberation", false)))
	interieur = false
	_appliquer_toit(true)
	_ajouter_feux.call_deferred(scene)


func _jouer_ponctuels() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for p in _ponctuels:
		if _temps < float(p["prochain"]):
			continue
		p["prochain"] = _temps + Donnees.entre(p.get("intervalle", [30, 60]))
		var angle := _hasard.randf() * TAU
		var distance := Donnees.entre(p.get("distance", [40, 80]))
		var lieu := camera.global_position + Vector3(cos(angle) * distance, _hasard.randf_range(0, 8), sin(angle) * distance)
		jouer_3d(String(p["son"]), lieu, float(p.get("volume_db", -10.0)), 0.06, distance * 0.6,
				"Exterieur" if p.get("exterieur", true) else "Ambiance")


## Sous un toit (un objet juste au-dessus de la caméra) : la pluie et la ville s'étouffent.
func _tester_toit() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not camera.is_inside_tree():
		return
	var monde := camera.get_world_3d()
	if monde == null:
		return
	var depart := camera.global_position + Vector3.UP * 0.3
	var requete := PhysicsRayQueryParameters3D.create(depart, depart + Vector3.UP * 30.0)
	requete.collide_with_areas = false
	var touche := monde.direct_space_state.intersect_ray(requete)
	var dessous := not touche.is_empty()
	if dessous != interieur:
		interieur = dessous
		_appliquer_toit(false)


func _appliquer_toit(immediat: bool) -> void:
	var bus := AudioServer.get_bus_index("Exterieur")
	if bus < 0:
		return
	var coupure := 650.0 if interieur else 20000.0
	var volume := -7.0 if interieur else 0.0
	var filtre := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	if immediat or filtre == null:
		if filtre != null:
			filtre.cutoff_hz = coupure
		AudioServer.set_bus_volume_db(bus, volume)
		return
	var t := create_tween().set_parallel()
	t.tween_method(func(v: float): filtre.cutoff_hz = v, filtre.cutoff_hz, coupure, 0.6)
	t.tween_method(func(v: float): AudioServer.set_bus_volume_db(bus, v), AudioServer.get_bus_volume_db(bus), volume, 0.6)


## Feux de camp des zones de la Préhistoire : un crépitement à chacun.
func _ajouter_feux(scene: Node) -> void:
	var r: Dictionary = reglages_scene.get("feux", {})
	if r.is_empty() or not is_instance_valid(scene):
		return
	var feux = scene.get("_feux")
	if not feux is Array:
		return
	for feu in feux:
		if feu is Node3D and is_instance_valid(feu) and not _feux_vus.has(feu):
			_feux_vus[feu] = true
			var lecteur := boucle_3d(String(r["son"]), feu, float(r.get("volume_db", -4.0)), float(r.get("portee", 14.0)))
			if lecteur != null:
				lecteur.position = Vector3.ZERO


## Boucle placée dans le monde (feu, zone de feu…), attachée à un nœud.
func boucle_3d(nom: String, parent: Node3D, volume_db := 0.0, portee := 12.0) -> AudioStreamPlayer3D:
	if not actif or parent == null:
		return null
	var flux := son_au_hasard(nom)
	if flux == null:
		return null
	if flux is AudioStreamOggVorbis:
		flux.loop = true
	var lecteur := AudioStreamPlayer3D.new()
	lecteur.stream = flux
	lecteur.bus = "Effets"
	lecteur.volume_db = volume_db
	lecteur.unit_size = portee
	lecteur.max_distance = portee * 6.0
	parent.add_child(lecteur)
	lecteur.play(_hasard.randf() * flux.get_length())
	return lecteur


# ---------------------------------------------------------------------------
# Branchements automatiques
# ---------------------------------------------------------------------------

func _sur_noeud_ajoute(n: Node) -> void:
	if not actif:
		return
	if n is BaseButton:
		_brancher_bouton(n)
	elif n.has_method("est_en_esquive") or (n.name == "Combat" and n.has_signal("degats_recus")):
		_ajouter_bruiteur.call_deferred(n)
	elif n.has_signal("quete_terminee") or n.has_signal("etape_changee") or n.has_signal("portail_franchi"):
		_brancher_quetes(n)
	elif n.get_script() != null and String(n.get_script().resource_path).ends_with("zone_de_feu.gd"):
		_ajouter_feu_de_combat.call_deferred(n)


func _brancher_bouton(b: BaseButton) -> void:
	if b.has_meta("sans_son"):
		return
	b.pressed.connect(func(): interface("clic"))
	b.mouse_entered.connect(func():
		if not b.disabled:
			interface("survol"))


func _ajouter_bruiteur(n: Node) -> void:
	if not is_instance_valid(n):
		return
	var acteur: Node = n if n.has_method("est_en_esquive") else n.get_parent()
	if acteur == null or acteur.has_node("Bruiteur") or not acteur is Node3D:
		return
	var b: Node = BRUITEUR.new()
	b.name = "Bruiteur"
	acteur.add_child(b)


func _brancher_quetes(n: Node) -> void:
	if n.has_signal("quete_acceptee"):
		n.quete_acceptee.connect(func(_id): interface("quete_acceptee"))
	if n.has_signal("quete_terminee"):
		n.quete_terminee.connect(func(_id): interface("quete_terminee"))
	if n.has_signal("etape_avancee"):
		n.etape_avancee.connect(func(_id, _e): interface("quete_etape"))
	if n.has_signal("etape_changee"):
		n.etape_changee.connect(func(_id): interface("quete_etape"))
	if n.has_signal("portail_franchi"):
		n.portail_franchi.connect(func(_e): interface("portail"))


func _ajouter_feu_de_combat(zone: Node) -> void:
	if not is_instance_valid(zone) or not zone is Node3D:
		return
	effet("embrasement", zone.global_position)
	var r := reglage_effet("feu")
	boucle_3d(String(r.get("son", "combat/feu")), zone, float(r.get("volume_db", -2.0)), float(r.get("portee", 10.0)))


func _noter(nom: String) -> void:
	historique.append(nom)
	if historique.size() > 60:
		historique.remove_at(0)


func _nouveau_lecteur(bus: String) -> AudioStreamPlayer:
	var lecteur := AudioStreamPlayer.new()
	lecteur.bus = bus
	add_child(lecteur)
	return lecteur
