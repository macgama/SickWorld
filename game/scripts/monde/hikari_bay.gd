@tool
class_name HikariBay
extends Node3D
## Hub Hikari Bay, premier quartier : la Place Hikari, en « maquette de blocs ».
##
## Tout est construit par le code avec des formes simples (boîtes, cylindres),
## aux bonnes dimensions, pour tester les distances et l'ambiance avant de
## remplacer les blocs par de vrais décors (Fab, Poly Haven, Blender).
## Voir docs/HUB.md pour le plan complet de la ville.
##
## Repères (en mètres) : la statue est au centre (0, 0) ; le nord est vers -Z
## (la tour de la Vigie et son écran géant) ; la mer est au sud (+Z).
## Le bouton « Reconstruire la place » de l'Inspecteur refait tout.

## Chargés directement (et non par nom de classe) : le jeu fonctionne même si
## l'éditeur Godot était ouvert pendant la mise à jour du dossier.
const QgVigie := preload("res://scripts/monde/qg_vigie.gd")
const Pnj := preload("res://scripts/monde/pnj.gd")
const Immeubles := preload("res://scripts/monde/immeubles_hikari.gd")
const Ambiance := preload("res://scripts/monde/ambiance_hikari.gd")
const QuartierMarche := preload("res://scripts/monde/quartier_marche.gd")
const QuartierArtisans := preload("res://scripts/monde/quartier_artisans.gd")
const QuartierMusee := preload("res://scripts/monde/quartier_musee.gd")
const FrontDeMer := preload("res://scripts/monde/quartier_front_de_mer.gd")
const Residences := preload("res://scripts/monde/quartier_residences.gd")
const Arene := preload("res://scripts/monde/quartier_arene.gd")

## Quand c'est coché, la Préhistoire est réparée : la statue du Gardien est
## intacte. Sinon, elle est fissurée et entourée d'éclats de fracture.
@export var prehistoire_reparee := false:
	set(valeur):
		prehistoire_reparee = valeur
		_mettre_a_jour_fracture()
## Pluie (décocher si le jeu rame).
@export var pluie := true:
	set(valeur):
		pluie = valeur
		_demander_reconstruction()
## Nombre de gouttes de pluie affichées en même temps (en qualité Ultra ;
## réduit automatiquement aux niveaux de qualité inférieurs).
@export var gouttes := 14000:
	set(valeur):
		gouttes = valeur
		_demander_reconstruction()
## Point d'arrivée des joueurs (x, z), face à la statue et à l'écran géant.
@export var point_apparition := Vector2(0, 22)

@export_tool_button("Reconstruire la place", "Reload") var _bouton := reconstruire

const SHADER_FACADE := preload("res://shaders/facade_nuit.gdshader")
const SHADER_ECRAN := preload("res://shaders/ecran_geant.gdshader")
const SHADER_SOL := preload("res://shaders/sol_mouille.gdshader")
const SHADER_EAU := preload("res://shaders/eau.gdshader")
const SHADER_VITRINE := preload("res://shaders/vitrine.gdshader")
## Police des enseignes (japonais + alphabet latin). Pour ajouter des kanji :
## voir tools/hub/police_enseignes.py.
const POLICE := preload("res://assets/polices/NotoSansJP-Bold-hub.ttf")

## Demi-largeur de la place (elle fait 60 m × 60 m).
const PLACE := 30.0
## Demi-largeur des rues (elles font 12 m de large).
const RUE := 6.0
## Les rues sont fermées par des barrières de chantier à cette distance du centre.
const FIN_RUES := 56.0
## Bord du quai (au-delà : la mer).
const QUAI := 74.0
## Trou de l'escalier de la station Asahi (x min, x max, z début, z bas de l'escalier).
const ESCALIER := Rect2(-26.0, 12.0, 6.0, 12.0)
const PROFONDEUR_STATION := 4.0

var _contenu: Node3D
var _sol: StaticBody3D
var _fracture: Node3D
var _statue_intacte: Node3D
var _metro: Node3D
var _roue: Node3D
var _reconstruction_demandee := false
var _porte_qg: MeshInstance3D
var _porte_qg_ferme_x := 0.0
var _collision_porte: CollisionShape3D
## Éléments du QG de la Vigie (portails...), remplis par QgVigie.construire().
var qg := {}
var _materiaux := {}


## Vrai quand le joueur revient d'une île : il apparaît devant les portails du QG.
var _arrivee_qg := false


func _ready() -> void:
	# Retour d'une île : l'île fait Reseau.set_meta("arrivee_hub", "portails") avant
	# de recharger le hub, et le joueur apparaît dans la salle des portails.
	var reseau := get_node_or_null("/root/Reseau")
	if not Engine.is_editor_hint() and reseau != null and reseau.get_meta("arrivee_hub", "") == "portails":
		reseau.remove_meta("arrivee_hub")
		_arrivee_qg = true
		point_apparition = Vector2(QgVigie.PORTAILS.position.x + 5.0, QgVigie.PORTAILS.end.y - 11.0)
	# Retour de la Côte Gelée avec la montre à gousset (chapitre 5 de la Préhistoire) :
	# la visite guidée du QG commence (mission automatique « montre », data/hub_quetes.json).
	if not Engine.is_editor_hint() and reseau != null and reseau.get_meta("visite_guidee_qg", false):
		reseau.remove_meta("visite_guidee_qg")
		_lancer_visite_guidee.call_deferred()
	reconstruire()


func _process(delta: float) -> void:
	_animer_porte_qg(delta)
	QgVigie.animer(self, delta)
	if _roue != null:
		_roue.rotate_z(delta * 0.05)
	if _metro != null:
		# Une rame passe toutes les 40 secondes environ sur le métro aérien.
		_metro.position.x += delta * 30.0
		if _metro.position.x > 260.0:
			_metro.position.x = -900.0


## La porte du QG s'ouvre (en glissant) quand un joueur est tout près.
func _animer_porte_qg(delta: float) -> void:
	if _porte_qg == null or not is_instance_valid(_porte_qg):
		return
	var ouverte := false
	if not Engine.is_editor_hint():
		for j in get_tree().get_nodes_in_group("joueur"):
			if (j as Node3D).global_position.distance_to(_porte_qg.global_position) < 4.5:
				ouverte = true
		var local := get_tree().get_first_node_in_group("joueur_local") as Node3D
		if local != null and local.global_position.distance_to(_porte_qg.global_position) < 4.5:
			ouverte = true
	var cible := _porte_qg_ferme_x + (3.1 if ouverte else 0.0)
	_porte_qg.position.x = move_toward(_porte_qg.position.x, cible, delta * 4.0)
	_collision_porte.disabled = absf(_porte_qg.position.x - _porte_qg_ferme_x) > 2.0


## Un joueur entre dans un portail actif de la salle des portails.
signal portail_franchi(epoque: String)


func _sur_portail(corps: Node3D, zone: Area3D) -> void:
	if not corps.is_in_group("joueur_local"):
		return
	var epoque: String = zone.get_meta("epoque", "")
	portail_franchi.emit(epoque)
	# Le voyage est géré par l'intro (IntroHub, groupe « voyage ») ; sans elle, ou
	# si elle refuse, on prévient et on fait reculer le joueur.
	var lignes := PackedStringArray(["Le portail bourdonne, mais refuse de s'ouvrir."])
	var voyage := get_tree().get_first_node_in_group("voyage")
	if voyage != null:
		lignes = voyage.demander_voyage(epoque)
		if lignes.is_empty():
			return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null:
		dialogue.ouvrir("portail", "Portail · " + epoque, lignes)
	if corps.has_method("teleporter"):
		corps.teleporter(corps.global_position + zone.global_transform.basis.z * -3.0, corps.rotation.y)


## Hauteur du sol à une position x, z (utilisé pour poser les joueurs et la balise).
func hauteur(_x: float, _z: float) -> float:
	return QgVigie.SOL if _arrivee_qg else 0.0


func _demander_reconstruction() -> void:
	if not is_inside_tree() or _reconstruction_demandee:
		return
	_reconstruction_demandee = true
	reconstruire.call_deferred()


func reconstruire() -> void:
	_reconstruction_demandee = false
	if _contenu != null:
		_contenu.free()
	_materiaux.clear()
	_contenu = Node3D.new()
	_contenu.name = "Maquette"
	add_child(_contenu)
	_sol = StaticBody3D.new()
	_sol.name = "Collisions"
	_contenu.add_child(_sol)
	_construire_sol()
	_construire_immeubles()
	_construire_statue()
	_construire_recruteur()
	_construire_station_asahi()
	QgVigie.construire(self)
	QuartierMarche.construire(self)
	QuartierArtisans.construire(self)
	QuartierMusee.construire(self)
	FrontDeMer.construire(self)
	Residences.construire(self)
	Arene.construire(self)
	if not Engine.is_editor_hint():
		for zone: Area3D in qg.get("portails", []):
			zone.body_entered.connect(_sur_portail.bind(zone))
	_construire_mobilier()
	_construire_enseignes()
	_construire_barrieres()
	_construire_front_de_mer()
	_construire_horizon()
	_construire_ambiance()
	_mettre_a_jour_fracture()


# --- Matériaux -----------------------------------------------------------

func _mat(nom: String) -> Material:
	if _materiaux.has(nom):
		return _materiaux[nom]
	if nom.begins_with("eau"):
		# Eau animée (vagues et ronds de pluie) ; « eau_calme » pour la fontaine.
		var eau := ShaderMaterial.new()
		eau.shader = SHADER_EAU
		eau.set_shader_parameter("houle", 0.0 if nom == "eau_calme" else 1.0)
		_materiaux[nom] = eau
		return eau
	var m := StandardMaterial3D.new()
	match nom:
		"asphalte":
			m.albedo_color = Color(0.07, 0.075, 0.085)
			m.roughness = 0.18 # sol mouillé : il reflète les néons
		"dalles":
			m.albedo_color = Color(0.2, 0.2, 0.22)
			m.roughness = 0.22
		"trottoir":
			m.albedo_color = Color(0.16, 0.16, 0.17)
			m.roughness = 0.3
		"beton":
			m.albedo_color = Color(0.32, 0.32, 0.34)
			m.roughness = 0.8
		"metal":
			m.albedo_color = Color(0.18, 0.19, 0.21)
			m.metallic = 0.85
			m.roughness = 0.35
		"carrelage":
			m.albedo_color = Color(0.62, 0.6, 0.52)
			m.roughness = 0.4
		"tronc":
			m.albedo_color = Color(0.17, 0.12, 0.08)
		"feuillage":
			m.albedo_color = Color(0.06, 0.16, 0.07)
			m.roughness = 0.9
		"bois":
			m.albedo_color = Color(0.3, 0.2, 0.12)
		"eau":
			m.albedo_color = Color(0.01, 0.03, 0.06)
			m.metallic = 0.4
			m.roughness = 0.04
		"chantier":
			m.albedo_color = Color(0.95, 0.45, 0.05)
			m.emission_enabled = true
			m.emission = Color(0.95, 0.45, 0.05)
			m.emission_energy_multiplier = 0.25
		"blanc":
			m.albedo_color = Color(0.9, 0.9, 0.9)
		"pierre":
			m.albedo_color = Color(0.55, 0.53, 0.5)
			m.roughness = 0.7
		"fracture":
			m.albedo_color = Color(0.55, 0.25, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.45, 0.35, 1.0)
			m.emission_energy_multiplier = 4.0
			m.roughness = 0.1
		_:
			m.albedo_color = Color.MAGENTA
	_materiaux[nom] = m
	return m


func _neon(couleur: Color, energie := 4.0) -> StandardMaterial3D:
	var cle := "neon_%s_%s" % [couleur.to_html(), energie]
	if _materiaux.has(cle):
		return _materiaux[cle]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = couleur * energie
	_materiaux[cle] = m
	return m


func _facade(graine: float, part_allumee := 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_FACADE
	m.set_shader_parameter("part_allumee", part_allumee)
	var teinte := Color(0.09, 0.1, 0.12).lerp(Color(0.16, 0.15, 0.15), fmod(graine * 0.37, 1.0))
	m.set_shader_parameter("couleur_mur", teinte)
	# Mur texturé (Poly Haven), si les ressources sont téléchargées.
	var id: String = TEXTURES_FACADES[int(graine) % TEXTURES_FACADES.size()]
	var couleur := _texture(id, "Diffuse")
	if couleur != null:
		m.set_shader_parameter("avec_texture", true)
		m.set_shader_parameter("texture_mur", couleur)
		m.set_shader_parameter("relief_mur", _texture(id, "nor_gl"))
		m.set_shader_parameter("couleur_mur", Color(0.16, 0.16, 0.17).lerp(Color(0.24, 0.22, 0.21), fmod(graine * 0.37, 1.0)))
	return m


## Vitre de boutique : on voit une vraie boutique en profondeur derrière
## (shader vitrine : plafond lumineux, rayonnages colorés).
func _vitrine(couleur: Color) -> Material:
	var cle := "vitrine_%s" % couleur.to_html()
	if _materiaux.has(cle):
		return _materiaux[cle]
	var m := ShaderMaterial.new()
	m.shader = SHADER_VITRINE
	m.set_shader_parameter("couleur", couleur)
	m.set_shader_parameter("graine", float(_materiaux.size()))
	_materiaux[cle] = m
	return m


# --- Ressources réalistes (Poly Haven, voir docs/CREDITS.md) ------------

const DOSSIER_RESSOURCES := "res://assets/hub/"
const TEXTURES_FACADES := ["concrete_tile_facade", "rectangular_facade_tiles", "concrete_wall_008",
		"brushed_concrete", "white_rough_plaster"]

var _bruit_flaques: NoiseTexture2D


## Une carte de texture Poly Haven (Diffuse, nor_gl ou arm), ou null si absente.
func _texture(id: String, carte: String) -> Texture2D:
	var chemin := DOSSIER_RESSOURCES + "textures/%s/%s_%s.jpg" % [id, id, carte]
	if not ResourceLoader.exists(chemin):
		return null
	return load(chemin)


## Sol mouillé réaliste ; revient au matériau simple si la texture manque.
func _mat_sol(id: String, taille_motif: float, simple: String, humidite := 0.6) -> Material:
	var cle := "sol_%s_%s" % [id, humidite]
	if _materiaux.has(cle):
		return _materiaux[cle]
	var couleur := _texture(id, "Diffuse")
	if couleur == null:
		return _mat(simple)
	if _bruit_flaques == null:
		var bruit := FastNoiseLite.new()
		bruit.frequency = 0.02
		bruit.fractal_octaves = 3
		_bruit_flaques = NoiseTexture2D.new()
		_bruit_flaques.noise = bruit
		_bruit_flaques.seamless = true
		_bruit_flaques.width = 512
		_bruit_flaques.height = 512
	var m := ShaderMaterial.new()
	m.shader = SHADER_SOL
	m.set_shader_parameter("texture_couleur", couleur)
	m.set_shader_parameter("texture_relief", _texture(id, "nor_gl"))
	m.set_shader_parameter("texture_arm", _texture(id, "arm"))
	m.set_shader_parameter("bruit_flaques", _bruit_flaques)
	m.set_shader_parameter("taille_motif", taille_motif)
	m.set_shader_parameter("humidite", humidite)
	_materiaux[cle] = m
	return m


## Matériau réaliste plaqué en « triplanaire » (pour les boîtes : murs, socles...).
func _mat_pbr(id: String, taille_motif: float, simple: String, teinte := Color.WHITE) -> Material:
	var cle := "pbr_%s_%s" % [id, teinte.to_html()]
	if _materiaux.has(cle):
		return _materiaux[cle]
	var couleur := _texture(id, "Diffuse")
	if couleur == null:
		return _mat(simple)
	var m := ORMMaterial3D.new()
	m.albedo_texture = couleur
	m.albedo_color = teinte
	m.normal_enabled = true
	m.normal_texture = _texture(id, "nor_gl")
	m.orm_texture = _texture(id, "arm")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / taille_motif
	_materiaux[cle] = m
	return m


## Place un modèle 3D Poly Haven ; ne fait rien si le modèle n'est pas téléchargé.
func _modele(id: String, position_m: Vector3, angle_y := 0.0, echelle := 1.0, parent: Node3D = null, exclure: Array = []) -> Node3D:
	var chemin := DOSSIER_RESSOURCES + "modeles/%s/%s.gltf" % [id, id]
	if not ResourceLoader.exists(chemin):
		return null
	var scene: PackedScene = load(chemin)
	var instance := scene.instantiate() as Node3D
	# Certains fichiers contiennent plusieurs variantes : on retire celles qu'on ne veut pas.
	for m in instance.find_children("*", "MeshInstance3D", true, false):
		if not is_instance_valid(m):
			continue
		for mot in exclure:
			if mot in String(m.name):
				m.free()
				break
	instance.position = position_m
	instance.rotation.y = angle_y
	instance.scale = Vector3.ONE * echelle
	(parent if parent != null else _contenu).add_child(instance)
	return instance


# --- Briques de base -----------------------------------------------------

## Ajoute une boîte (dimensions, centre) ; avec collision si demandé.
func _boite(taille: Vector3, centre: Vector3, materiau: Material, collision := true, parent: Node3D = null) -> MeshInstance3D:
	var maillage := BoxMesh.new()
	maillage.size = taille
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = centre
	(parent if parent != null else _contenu).add_child(mi)
	if collision:
		_collision_boite(taille, Transform3D(Basis(), centre))
	return mi


func _collision_boite(taille: Vector3, transformation: Transform3D) -> void:
	var forme := BoxShape3D.new()
	forme.size = taille
	var cs := CollisionShape3D.new()
	cs.shape = forme
	cs.transform = transformation
	_sol.add_child(cs)


## Boîte définie par ses coins (x1, z1) - (x2, z2), entre les hauteurs y1 et y2.
func _bloc(x1: float, z1: float, x2: float, z2: float, y1: float, y2: float, materiau: Material, collision := true) -> MeshInstance3D:
	return _boite(Vector3(absf(x2 - x1), y2 - y1, absf(z2 - z1)),
			Vector3((x1 + x2) * 0.5, (y1 + y2) * 0.5, (z1 + z2) * 0.5), materiau, collision)


func _cylindre(rayon_haut: float, rayon_bas: float, hauteur_c: float, centre: Vector3, materiau: Material, collision := true) -> MeshInstance3D:
	var maillage := CylinderMesh.new()
	maillage.top_radius = rayon_haut
	maillage.bottom_radius = rayon_bas
	maillage.height = hauteur_c
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = centre
	_contenu.add_child(mi)
	if collision:
		var forme := CylinderShape3D.new()
		forme.radius = maxf(rayon_haut, rayon_bas)
		forme.height = hauteur_c
		var cs := CollisionShape3D.new()
		cs.shape = forme
		cs.position = centre
		_sol.add_child(cs)
	return mi


func _lumiere(position_l: Vector3, couleur: Color, energie: float, portee: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = position_l
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = 1.4
	_contenu.add_child(l)
	return l


func _texte(texte: String, position_t: Vector3, couleur: Color, taille_police := 96, angle_y := 0.0, energie := 3.0) -> Label3D:
	var l := Label3D.new()
	l.text = texte
	l.position = position_t
	l.rotation.y = angle_y
	l.font = POLICE
	l.font_size = taille_police
	l.pixel_size = 0.01
	l.modulate = Color(couleur.r * energie, couleur.g * energie, couleur.b * energie)
	l.outline_size = 0
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenu.add_child(l)
	return l


# --- Sol -----------------------------------------------------------------

func _construire_sol() -> void:
	var asphalte := _mat_sol("asphalt_02", 6.0, "asphalte", 0.7)
	var dalles := _mat_sol("concrete_pavers_02", 3.0, "dalles", 0.5)
	# La ville autour de la place (4 morceaux, la place est faite à part).
	_bloc(-200, -200, 200, -PLACE, -1, 0, asphalte)
	_bloc(-200, PLACE, 200, QUAI, -1, 0, asphalte)
	_bloc(-200, -PLACE, -PLACE, PLACE, -1, 0, asphalte)
	_bloc(PLACE, -PLACE, 200, PLACE, -1, 0, asphalte)
	# La place, avec un trou pour l'escalier de la station Asahi.
	var e := ESCALIER
	var e_fin := e.position.y + e.size.y + 2.0 # le trou continue au-dessus du couloir
	_bloc(-PLACE, -PLACE, e.position.x, PLACE, -1, 0, dalles)
	_bloc(e.end.x, -PLACE, PLACE, PLACE, -1, 0, dalles)
	_bloc(e.position.x, -PLACE, e.end.x, e.position.y, -1, 0, dalles)
	_bloc(e.position.x, e_fin, e.end.x, PLACE, -1, 0, dalles)
	# Bordure de trottoir autour de la place (marque la limite piétonne).
	var bord := _mat_pbr("brushed_concrete", 2.0, "trottoir")
	for cote in [-1.0, 1.0]:
		_bloc(-PLACE - 4, cote * PLACE - 0.3, PLACE + 4, cote * PLACE + 0.3, 0, 0.06, bord, false)
		_bloc(cote * PLACE - 0.3, -PLACE, cote * PLACE + 0.3, PLACE, 0, 0.06, bord, false)
	# Passages piétons blancs à la sortie de chaque rue.
	var blanc := _mat("blanc")
	for i in 6:
		var x := -RUE + 1.0 + i * 2.0
		_bloc(x - 0.4, PLACE + 1, x + 0.4, PLACE + 4, 0, 0.02, blanc, false)
		_bloc(-PLACE - 4, x - 0.4, -PLACE - 1, x + 0.4, 0, 0.02, blanc, false)
		_bloc(PLACE + 1, x - 0.4, PLACE + 4, x + 0.4, 0, 0.02, blanc, false)


# --- Immeubles -----------------------------------------------------------

## [x1, z1, x2, z2, hauteur, part de fenêtres allumées]
const IMMEUBLES := [
	# Nord : la tour de la Vigie (déguisée en immeuble de bureaux), entre les deux rues du nord.
	[-14, -70, 14, -34, 96, 0.5],
	# Nord-ouest (vers le Marché de nuit) et ouest.
	[-70, -70, -26, -34, 34, 0.4],
	[-70, -34, -34, -6, 22, 0.3],
	[-46, -70, -26, -50, 58, 0.35],
	# Nord-est (vers les Artisans) et est.
	[26, -70, 70, -34, 28, 0.3],
	[34, -34, 70, -6, 40, 0.35],
	# Est-sud et ouest-sud.
	[34, 6, 70, 34, 26, 0.3],
	[-70, 6, -34, 34, 30, 0.35],
	# Sud, de part et d'autre de la rue qui descend vers la mer.
	[-70, 34, -6, 62, 18, 0.25],
	[6, 34, 70, 62, 24, 0.3],
	[-30, 40, -6, 62, 52, 0.3],
	[6, 38, 26, 62, 70, 0.4],
	# Marché de nuit (voir quartier_marche.gd) : petites maisons-boutiques le long
	# des ruelles et tours derrière.
	[-70, -97, -23, -70, 9, 0.45],
	[-66, -96, -40, -88, 38, 0.35],
	[-17, -135, -8, -70, 8, 0.5],
	[-8, -125, 12, -96, 62, 0.35],
	[-80, -135, -52, -97, 12, 0.4],
	[-78, -132, -60, -110, 46, 0.3],
	[-80, -165, -8, -133, 14, 0.4],
	[-60, -165, -28, -142, 66, 0.3],
	# (Les blocs autour des salles visitables s'arrêtent au dos de leurs murs,
	# pour que leurs façades ne transparaissent pas à l'intérieur.)
	[-48, -111.7, -31.3, -102, 10, 0.4],
	[-35.7, -128, -23, -116.3, 11, 0.4],
	[-48, -128, -36, -126.3, 10, 0.3],
	[-31, -103.7, -23, -102, 9, 0.3],
	[-35.7, -116, -31.3, -112, 9, 0.3],
	# Quartier des Artisans (voir quartier_artisans.gd) : entrepôts sous le métro aérien.
	[12, -140, 16, -70, 9, 0.4],
	[24, -140, 25.7, -89, 9, 0.3],
	[24, -77, 84, -70, 7, 0.3],
	[24, -140, 84, -107.3, 12, 0.35],
	[30, -160, 60, -145, 58, 0.3],
	[12, -165, 90, -140, 18, 0.35],
	[48.3, -107.3, 51.7, -89, 9, 0.3],
	[72.3, -107.3, 84, -89, 10, 0.35],
	[84, -112, 100, -70, 16, 0.3],
	# Esplanade du Musée et Jardins suspendus (voir quartier_musee.gd) : tours tout autour.
	[70, -70, 140, -30, 30, 0.35],
	[100, -100, 140, -70, 60, 0.3],
	[130, -30, 150, 30, 44, 0.3],
	[70, 30, 72, 62, 12, 0.3],
	[100, 30, 140, 62, 26, 0.35],
	# Résidences (voir quartier_residences.gd) : immeubles d'habitation autour de la place.
	[-130, -70, -70, -30, 26, 0.5],
	[-150, -30, -128.6, 30, 40, 0.45],
	[-140, 30, -100, 62, 22, 0.5],
	[-72, 30, -70, 62, 18, 0.4],
	# Fonds des rues (ferment la vue derrière les barrières).
	[72, 30, 100, 74, 30, 0.3],
	[-100, 30, -72, 74, 34, 0.3],
]


func _construire_immeubles() -> void:
	# Vrais immeubles (soubassement, tour en retrait, corniche, toit équipé) :
	# voir immeubles_hikari.gd. La tour de la Vigie (la première) garde une
	# façade droite car l'écran géant et l'enseigne y sont accrochés.
	var i := 0
	for b in IMMEUBLES:
		Immeubles.batiment(self, minf(b[0], b[2]), minf(b[1], b[3]), maxf(b[0], b[2]), maxf(b[1], b[3]),
				b[4], b[5], i, true, Immeubles.Style.VERRE if i == 0 else -1, i != 0)
		i += 1
	Immeubles.enseignes_verticales(self)
	# Écran géant sur la façade sud de la tour de la Vigie.
	var ecran := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(24, 11)
	ecran.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_ECRAN
	ecran.material_override = mat
	ecran.position = Vector3(0, 19, -33.9)
	_contenu.add_child(ecran)
	var titre := _texte("光ベイ HIKARI BAY", Vector3(0, 21.5, -33.8), Color(1, 1, 1), 300, 0.0, 1.6)
	var stabilite := _texte("Stabilité de la Préhistoire : 12 %", Vector3(0, 16.5, -33.8), Color(0.75, 0.95, 1.0), 110, 0.0, 1.6)
	stabilite.name = "TexteStabilite"
	for l in [titre, stabilite]:
		l.outline_size = 24
	_lumiere(Vector3(0, 16, -28), Color(0.7, 0.45, 1.0), 6.0, 34.0)
	# Enseigne au sommet de la tour.
	_texte("KAIRO HOLDINGS", Vector3(0, 90, -33.8), Color(0.4, 0.9, 1.0), 600, 0.0, 2.0)


# --- Kenji Duval, l'agent qui recrute le joueur (intro) ------------------

func _construire_recruteur() -> void:
	var pnj := Pnj.new()
	pnj.identifiant = "recruteur"
	pnj.name = "Pnj_recruteur"
	pnj.position = Vector3(-5.5, 0, 10.0)
	# Tourné vers le point d'arrivée des joueurs.
	var vers := Vector3(point_apparition.x, 0, point_apparition.y) - pnj.position
	pnj.rotation.y = atan2(-vers.x, -vers.z)
	_contenu.add_child(pnj)


# --- Statue du Gardien ---------------------------------------------------

func _construire_statue() -> void:
	var pierre := _mat_pbr("granite_tile", 2.0, "pierre", Color(0.8, 0.8, 0.8))
	# Bassin de la fontaine.
	_cylindre(7.0, 7.2, 0.7, Vector3(0, 0.35, 0), pierre)
	var eau := _cylindre(6.5, 6.5, 0.1, Vector3(0, 0.6, 0), _mat("eau_calme"), false)
	eau.name = "EauFontaine"
	_cylindre(1.6, 1.8, 3.0, Vector3(0, 1.5, 0), pierre)
	# Le Gardien : silhouette debout tenant un sablier (forme provisoire).
	_statue_intacte = Node3D.new()
	_statue_intacte.name = "Gardien"
	_contenu.add_child(_statue_intacte)
	# Statue réaliste (modèle Poly Haven, provisoire en attendant le vrai Gardien).
	var statue := _modele("gothic_statue", Vector3(-0.1, 3.0, 1.1), 0.0, 2.6, _statue_intacte)
	if statue != null:
		_lumiere(Vector3(0, 2.5, 3.5), Color(1.0, 0.85, 0.65), 3.0, 12.0)
		_construire_eclats()
		return
	var corps := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.75
	capsule.height = 4.4
	corps.mesh = capsule
	corps.material_override = pierre
	corps.position = Vector3(0, 5.2, 0)
	_statue_intacte.add_child(corps)
	var tete := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	tete.mesh = sphere
	tete.material_override = pierre
	tete.position = Vector3(0, 7.9, 0)
	_statue_intacte.add_child(tete)
	var sablier := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.0
	cone.height = 0.7
	sablier.mesh = cone
	sablier.material_override = _neon(Color(1.0, 0.8, 0.45), 2.0)
	sablier.position = Vector3(0, 8.9, 0.0)
	_statue_intacte.add_child(sablier)
	_lumiere(Vector3(0, 2.5, 3.5), Color(1.0, 0.85, 0.65), 3.0, 12.0)
	_construire_eclats()


## Les éclats de fracture (visibles tant que la Préhistoire est malade).
func _construire_eclats() -> void:
	_fracture = Node3D.new()
	_fracture.name = "EclatsDeFracture"
	_contenu.add_child(_fracture)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	for i in 9:
		var eclat := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(0.5, hasard.randf_range(1.0, 2.4), 0.5)
		eclat.mesh = prisme
		eclat.material_override = _mat("fracture")
		var angle := i * TAU / 9.0 + hasard.randf() * 0.4
		eclat.position = Vector3(cos(angle) * 1.6, hasard.randf_range(3.4, 7.5), sin(angle) * 1.6)
		eclat.rotation = Vector3(hasard.randf_range(-0.6, 0.6), hasard.randf() * TAU, hasard.randf_range(-0.6, 0.6))
		_fracture.add_child(eclat)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.55, 0.4, 1.0)
	lueur.light_energy = 3.0
	lueur.omni_range = 10.0
	lueur.position = Vector3(0, 5, 0)
	_fracture.add_child(lueur)


func _lancer_visite_guidee() -> void:
	var quetes := get_tree().get_first_node_in_group("quetes")
	if quetes != null:
		quetes.accepter("montre")


func _mettre_a_jour_fracture() -> void:
	if _fracture == null or _statue_intacte == null:
		return
	_fracture.visible = not prehistoire_reparee
	# Statue « malade » : penchée, comme sur le point de se briser.
	_statue_intacte.rotation = Vector3.ZERO if prehistoire_reparee else Vector3(0.0, 0.0, 0.06)
	# Au Musée, les fresques de la salle Préhistoire reviennent une fois l'époque réparée.
	var fresques := _contenu.find_child("FresquesPrehistoire", false, false)
	if fresques != null:
		fresques.visible = prehistoire_reparee
	var effacees := _contenu.find_child("FresquesEffacees", false, false)
	if effacees != null:
		effacees.visible = not prehistoire_reparee


# --- Station Asahi (entrée du QG) ----------------------------------------

func _construire_station_asahi() -> void:
	var e := ESCALIER
	var x1 := e.position.x
	var x2 := e.end.x
	var z_haut := e.position.y
	var z_bas := e.end.y
	var fond := -PROFONDEUR_STATION
	var z_porte := z_bas + 16.0
	var carrelage := _mat_pbr("square_tiled_wall", 1.5, "carrelage")
	var sol_station := _mat_pbr("terrazzo_tiles", 2.0, "carrelage")
	var metal := _mat_pbr("metal_plate", 1.5, "metal")
	# Marches (visuelles) et pente (pour marcher dessus sans accrocher).
	var marches := 20
	for i in marches:
		var z := z_haut + (i + 0.5) * e.size.y / marches
		var y := -(i + 1.0) * PROFONDEUR_STATION / marches
		_bloc(x1, z - e.size.y / marches * 0.5, x2, z + e.size.y / marches * 0.5, y - 0.3, y + PROFONDEUR_STATION / marches, _mat_pbr("brushed_concrete", 1.5, "beton"), false)
	var longueur := Vector2(e.size.y, PROFONDEUR_STATION).length()
	var pente := atan2(PROFONDEUR_STATION, e.size.y)
	var t := Transform3D(Basis(Vector3.RIGHT, pente), Vector3((x1 + x2) * 0.5, -PROFONDEUR_STATION * 0.5 - 0.1, (z_haut + z_bas) * 0.5))
	_collision_boite(Vector3(x2 - x1, 0.2, longueur), t)
	# Couloir carrelé jusqu'à la porte du QG.
	_bloc(x1, z_bas, x2, z_porte, fond - 0.5, fond, sol_station)
	_bloc(x1 - 0.5, z_haut, x1, z_porte, fond, 0, carrelage)
	_bloc(x2, z_haut, x2 + 0.5, z_porte, fond, 0, carrelage)
	# Mur du fond, percé de la porte blindée de la Vigie (elle s'ouvre devant les agents).
	var xm := (x1 + x2) * 0.5
	_bloc(x1, z_porte, xm - 1.5, z_porte + 0.5, fond, 0, carrelage)
	_bloc(xm + 1.5, z_porte, x2, z_porte + 0.5, fond, 0, carrelage)
	_bloc(xm - 1.5, z_porte, xm + 1.5, z_porte + 0.5, fond + 2.8, 0, carrelage)
	_porte_qg = _bloc(xm - 1.5, z_porte + 0.05, xm + 1.5, z_porte + 0.45, fond, fond + 2.8,
			_mat_pbr("painted_metal_shutter", 2.0, "metal", Color(0.5, 0.5, 0.55)), false)
	_porte_qg.name = "PorteQG"
	_porte_qg_ferme_x = xm
	_collision_porte = CollisionShape3D.new()
	var forme := BoxShape3D.new()
	forme.size = Vector3(3.0, 2.8, 0.4)
	_collision_porte.shape = forme
	_collision_porte.position = Vector3(xm, fond + 1.4, z_porte + 0.25)
	_sol.add_child(_collision_porte)
	_texte("VIGIE · ACCÈS RESTREINT", Vector3(xm, fond + 3.2, z_porte - 0.05), Color(0.75, 0.55, 1.0), 40, PI, 2.0)
	_lumiere(Vector3((x1 + x2) * 0.5, fond + 2.6, z_porte - 3.0), Color(0.65, 0.5, 1.0), 2.0, 9.0)
	_lumiere(Vector3((x1 + x2) * 0.5, fond + 2.6, z_bas + 2.0), Color(0.9, 0.95, 1.0), 1.0, 7.0)
	# Rambardes autour du trou.
	for x in [x1, x2]:
		_bloc(x - 0.06, z_haut, x + 0.06, z_bas + 2.0, 0, 1.1, metal)
	_bloc(x1, z_bas + 1.94, x2, z_bas + 2.06, 0, 1.1, metal)
	# Panneau de la station, au-dessus de l'entrée.
	for x in [x1 + 0.3, x2 - 0.3]:
		_bloc(x - 0.1, z_haut - 0.4, x + 0.1, z_haut - 0.2, 0, 3.4, metal)
	_bloc(x1, z_haut - 0.45, x2, z_haut - 0.15, 2.6, 3.6, metal, false)
	_texte("旭駅 STATION ASAHI", Vector3((x1 + x2) * 0.5, 3.25, z_haut - 0.5), Color(0.75, 0.55, 1.0), 60, PI, 2.5)
	_texte("fermée au public", Vector3((x1 + x2) * 0.5, 2.85, z_haut - 0.5), Color(1, 1, 1), 32, PI, 1.2)


# --- Mobilier urbain (modèles Poly Haven quand ils sont téléchargés) ----

func _construire_mobilier() -> void:
	var granit := _mat_pbr("granite_tile", 2.0, "pierre", Color(0.75, 0.75, 0.75))
	var metal := _mat_pbr("metal_plate", 1.5, "metal")
	var terre := _mat("tronc")
	# Grands bacs de granit plantés, le long des bords de la place.
	var bacs: Array[Vector2] = []
	for z in [-22.0, -12.0, 12.0, 22.0]:
		bacs.append(Vector2(-24, z))
		bacs.append(Vector2(24, z))
	for x in [-22.0, -10.0, 10.0, 22.0]:
		bacs.append(Vector2(x, -24))
	# Pas de bac à l'endroit de l'escalier de la station Asahi.
	bacs = bacs.filter(func(p: Vector2): return not (p.x < 0 and p.y > 0))
	bacs.append(Vector2(-14, 24))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 11
	for p in bacs:
		_bloc(p.x - 1.3, p.y - 1.3, p.x + 1.3, p.y + 1.3, 0, 0.6, granit)
		_bloc(p.x - 1.15, p.y - 1.15, p.x + 1.15, p.y + 1.15, 0.6, 0.62, terre, false)
		# Plante en pot enfoncée dans le bac (on ne voit que le feuillage).
		var plante := _modele("potted_plant_01", Vector3(p.x, -0.45, p.y), hasard.randf() * TAU,
				hasard.randf_range(2.6, 3.2))
		if plante == null:
			# Sans les modèles : arbre simplifié.
			_cylindre(0.22, 0.3, 4.0, Vector3(p.x, 2.0, p.y), terre)
			var houppier := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 2.4
			sphere.height = 3.6
			houppier.mesh = sphere
			houppier.material_override = _mat("feuillage")
			houppier.position = Vector3(p.x, 5.2, p.y)
			_contenu.add_child(houppier)
	# Bancs de granit (assise en bois) entre les bacs, et poubelles à côté.
	for z in [-17.0, 17.0]:
		for x in [-24.0, 24.0]:
			if x < 0 and z > 0:
				continue # emplacement de l'escalier
			_bloc(x - 0.4, z - 1.4, x + 0.4, z + 1.4, 0, 0.42, granit)
			_bloc(x - 0.42, z - 1.42, x + 0.42, z + 1.42, 0.42, 0.48, _mat("bois"), false)
			_modele("metal_trash_can", Vector3(x, 0, z + 2.2), PI / 2, 0.75, null, ["rust"])
	# Éclairage d'ambiance de la place (projecteurs cachés sur les façades).
	for p in [Vector3(-16, 9, -10), Vector3(16, 9, -10), Vector3(0, 9, 14)]:
		_lumiere(p, Color(0.75, 0.7, 1.0), 2.0, 26.0)
	# Lampadaires aux coins de la place et le long de la rue du sud.
	var lampes: Array[Vector2] = [
		Vector2(-28, -28), Vector2(28, -28), Vector2(-28, 28), Vector2(28, 28),
		Vector2(-28, 0), Vector2(28, 0), Vector2(-7, 44), Vector2(7, 54),
	]
	for p in lampes:
		var lampe := _modele("street_lamp_01", Vector3(p.x, 0, p.y), atan2(-p.x, -p.y), 1.5)
		if lampe == null:
			_cylindre(0.08, 0.12, 6.0, Vector3(p.x, 3.0, p.y), metal)
			_boite(Vector3(0.6, 0.2, 0.6), Vector3(p.x, 6.1, p.y), _neon(Color(1.0, 0.85, 0.65), 3.0), false)
		else:
			_collision_boite(Vector3(0.3, 5.8, 0.3), Transform3D(Basis(), Vector3(p.x, 2.9, p.y)))
		_lumiere(Vector3(p.x, 5.4, p.y), Color(1.0, 0.82, 0.6), 4.0, 22.0)
	# Petits détails de rue.
	_modele("fire_hydrant", Vector3(-31.5, 0, -8.5), PI / 2, 1.0, null, ["aged"])
	_modele("fire_hydrant", Vector3(31.5, 0, 8.5), -PI / 2, 1.0, null, ["aged"])
	_modele("utility_box_01", Vector3(-31.8, 0, -31.8), PI / 4, 1.2)
	_modele("utility_box_01", Vector3(31.8, 0, 31.8), -PI * 0.75, 1.2)
	for p in [Vector3(-20, 0.01, -42), Vector3(20, 0.01, -45), Vector3(-42, 0.01, 0), Vector3(0, 0.01, 46)]:
		_modele("water_manhole_cover", p, 0.0, 1.3)
	_modele("korean_public_payphone_01", Vector3(33.75, 1.3, 25.5), -PI / 2, 1.0)
	# Climatiseurs accrochés aux façades (un classique des villes asiatiques).
	var climatiseurs := [
		[Vector3(-44, 7, -33.8), 0.0], [Vector3(-58, 10.5, -33.8), 0.0], [Vector3(-38, 14, -33.8), 0.0],
		[Vector3(46, 7, -33.8), 0.0], [Vector3(58, 14, -33.8), 0.0],
		[Vector3(-33.8, 7, -28), PI / 2], [Vector3(-33.8, 10.5, -12), PI / 2],
		[Vector3(33.8, 7, 12), -PI / 2], [Vector3(33.8, 14, 28), -PI / 2],
		[Vector3(-40, 7, 33.8), PI], [Vector3(-52, 10.5, 33.8), PI], [Vector3(40, 10.5, 33.8), PI],
	]
	for c in climatiseurs:
		_modele("exterior_aircon_unit", c[0], c[1], 1.0, null, ["rusted"])
	# Caméras de surveillance de la Vigie (discrètes) aux coins de sa tour.
	for x in [-13.8, 13.8]:
		_modele("security_camera_01", Vector3(x, 6, -33.6), PI, 1.0)
	_modele("security_light", Vector3(-23, 4.2, 11.6), PI, 1.2)
	# Devant le sushi bar (côté sud) : caisses et sacs-poubelle.
	for d in [[Vector3(-30, 0, 35.4), "plastic_crate_01", 0.3], [Vector3(-30.4, 0.26, 35.5), "plastic_crate_01", 0.1],
			[Vector3(-28.5, 0, 35.6), "trashbag", 0.0], [Vector3(-27.8, 0, 35.3), "trashbag", 1.2],
			[Vector3(-31.4, 0, 35.2), "cardboard_box_01", 0.5]]:
		_modele(d[1], d[0], d[2], 1.0)
	_construire_vitrines()


## Rez-de-chaussée des immeubles : vitrines éclairées (boutiques ouvertes)
## et rideaux de fer baissés (boutiques fermées pour la nuit).
func _construire_vitrines() -> void:
	# [centre, angle (face vers la place), ouverte ?, couleur de l'intérieur]
	var vitrines := [
		[Vector3(-40, 0, -34), 0.0, true, Color(1.0, 0.75, 0.5)],
		[Vector3(-52, 0, -34), 0.0, false, Color()],
		[Vector3(-62, 0, -34), 0.0, true, Color(0.6, 0.85, 1.0)],
		[Vector3(44, 0, -34), 0.0, true, Color(1.0, 0.8, 0.55)],
		[Vector3(56, 0, -34), 0.0, false, Color()],
		[Vector3(-34, 0, -20), PI / 2, true, Color(0.7, 1.0, 0.7)],
		[Vector3(-34, 0, -28), PI / 2, false, Color()],
		[Vector3(34, 0, -20), -PI / 2, true, Color(0.95, 0.9, 1.0)],
		[Vector3(34, 0, 20), -PI / 2, true, Color(0.9, 1.0, 1.0)],
		[Vector3(34, 0, 28), -PI / 2, false, Color()],
		[Vector3(-34, 0, 26), PI / 2, false, Color()],
		[Vector3(-24, 0, 34), PI, true, Color(1.0, 0.7, 0.6)],
		[Vector3(-14, 0, 34), PI, false, Color()],
		[Vector3(22, 0, 34), PI, true, Color(0.7, 0.85, 1.0)],
		[Vector3(32, 0, 34), PI, false, Color()],
	]
	for v in vitrines:
		var centre: Vector3 = v[0]
		var angle: float = v[1]
		var avant := Vector3(sin(angle), 0, cos(angle))
		if v[2]:
			# Vitre éclairée de l'intérieur.
			var vitre := _boite(Vector3(5.0, 3.0, 0.08), centre + avant * 0.02 + Vector3(0, 1.6, 0),
					_vitrine(v[3]), false)
			vitre.rotation.y = angle
			# Encadrement et auvent au-dessus de la vitrine.
			var auvent := _boite(Vector3(5.6, 0.12, 1.2), centre + avant * 0.6 + Vector3(0, 3.3, 0), _mat_pbr("metal_plate", 1.5, "metal"), false)
			auvent.rotation.y = angle
			_lumiere(centre + avant * 2.0 + Vector3(0, 2.0, 0), v[3], 1.2, 7.0)
		else:
			var rideau := _modele("rollershutter_window_01", centre + avant * 0.05, angle, 1.0)
			if rideau == null:
				var b := _boite(Vector3(5.0, 3.0, 0.08), centre + avant * 0.02 + Vector3(0, 1.6, 0), _mat("metal"), false)
				b.rotation.y = angle


# --- Enseignes et néons --------------------------------------------------

func _construire_enseignes() -> void:
	var rose := Color(1.0, 0.3, 0.7)
	var bleu := Color(0.3, 0.65, 1.0)
	var cyan := Color(0.3, 1.0, 0.95)
	var orange := Color(1.0, 0.6, 0.2)
	var vert := Color(0.35, 1.0, 0.55)
	# [texte, position, angle, couleur, taille]
	# Les façades donnant sur la place : nord à z = -34, sud à z = 34, ouest à x = -34, est à x = 34.
	var enseignes := [
		["ラーメン RAMEN", Vector3(-40, 6, -33.8), 0.0, rose, 110],
		["カラオケ KARAOKE STAR", Vector3(-52, 9, -33.8), 0.0, cyan, 90],
		["夜市 · Marché de nuit", Vector3(-20, 5.4, -32.8), 0.0, rose, 70],
		["職人街 · Quartier des Artisans", Vector3(20, 5.4, -32.8), 0.0, orange, 70],
		["喫茶 CAFÉ 24/7", Vector3(44, 5, -33.8), 0.0, orange, 90],
		["パチンコ PACHINKO", Vector3(-33.8, 8, -20), PI / 2, vert, 120],
		["博物館 · Musée & Jardins", Vector3(33.8, 4, -13.0), -PI / 2, vert, 60],
		["ホテル HOTEL LUMEN", Vector3(33.8, 12, -20), -PI / 2, bleu, 120],
		["コンビニ KONBINI", Vector3(33.8, 4.5, 20), -PI / 2, cyan, 110],
		["住宅街 · Résidences & Guildes", Vector3(-33.8, 4, 13.0), PI / 2, orange, 60],
		["海辺 · Front de mer", Vector3(-14.0, 4, 33.8), PI, bleu, 60],
		["寿司 SUSHI BAR", Vector3(-24, 5, 33.8), PI, rose, 100],
		["ゲームセンター ARCADE", Vector3(22, 7, 33.8), PI, cyan, 130],
	]
	# Portiques métalliques au-dessus des deux rues du nord (portent les panneaux).
	for x in [-20.0, 20.0]:
		_bloc(x - RUE, -33.3, x + RUE, -32.9, 4.7, 4.9, _mat("metal"), false)
		_bloc(x - RUE, -33.3, x - RUE + 0.3, -32.9, 0, 4.9, _mat("metal"))
		_bloc(x + RUE - 0.3, -33.3, x + RUE, -32.9, 0, 4.9, _mat("metal"))
	for e in enseignes:
		var p: Vector3 = e[1]
		var angle: float = e[2]
		var couleur: Color = e[3]
		_texte(e[0], p, couleur, int(e[4] * 1.6), angle, 4.0)
		# Un panneau sombre derrière le texte et une lumière colorée devant.
		var avant := Vector3(sin(angle), 0, cos(angle))
		_lumiere(p + avant * 2.5, couleur, 2.5, 12.0)
	# Bandeaux lumineux au-dessus des boutiques (rez-de-chaussée).
	var bandeaux := [
		[Vector3(-50, 4.2, -33.9), Vector3(30, 0.15, 0.1), rose],
		[Vector3(50, 4.2, -33.9), Vector3(30, 0.15, 0.1), orange],
		[Vector3(-38, 4.2, 33.9), Vector3(56, 0.15, 0.1), cyan],
		[Vector3(38, 4.2, 33.9), Vector3(56, 0.15, 0.1), rose],
		[Vector3(-33.9, 4.2, -20), Vector3(0.1, 0.15, 26), bleu],
		[Vector3(33.9, 4.2, 20), Vector3(0.1, 0.15, 26), vert],
	]
	for b in bandeaux:
		_boite(b[1], b[0], _neon(b[2], 5.0), false)


# --- Barrières de chantier ----------------------------------------------

func _construire_barrieres() -> void:
	# [centre, largeur, angle, panneau]
	var barrieres := [
		[Vector3(-70, 0, (62 + QUAI) * 0.5), QUAI - 62, PI / 2, "TRAVAUX"],
	]
	for b in barrieres:
		var centre: Vector3 = b[0]
		var largeur: float = b[1]
		var angle: float = b[2]
		var pivot := Node3D.new()
		pivot.position = centre
		pivot.rotation.y = angle
		_contenu.add_child(pivot)
		var t := pivot.transform
		# Rangée de blocs de béton (ou palissade orange et blanche sans les modèles).
		var nombre := int(largeur / 1.6)
		var blocs_ok := true
		for i in nombre:
			var x := -largeur * 0.5 + 0.8 + i * largeur / nombre
			if _modele("concrete_road_barrier", Vector3(x, 0, 0), (i % 3 - 1) * 0.05, 1.05, pivot) == null:
				blocs_ok = false
				break
		# Panneau de chantier orange et blanc au-dessus des blocs.
		_boite(Vector3(minf(largeur, 6.0), 0.9, 0.06), Vector3(0, 2.0, -0.1), _mat("chantier"), false, pivot)
		for x in [-minf(largeur, 6.0) * 0.45, minf(largeur, 6.0) * 0.45]:
			_boite(Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, -0.15), _mat("metal"), false, pivot)
		for i in (0 if blocs_ok else int(largeur / 2.0)):
			var x := -largeur * 0.5 + 1.0 + i * 2.0
			_boite(Vector3(1.9, 1.1, 0.15), Vector3(x, 0.75, 0), _mat("chantier") if i % 2 == 0 else _mat("blanc"), false, pivot)
		_collision_boite(Vector3(largeur, 3.0, 0.4), t.translated_local(Vector3(0, 1.5, 0)))
		var panneau := _texte(b[3], centre + Vector3(0, 2.0, 0) + t.basis.z * -0.05, Color(0.05, 0.05, 0.05), 40, angle, 1.0)
		panneau.double_sided = true


# --- Front de mer --------------------------------------------------------

func _construire_front_de_mer() -> void:
	var metal := _mat("metal")
	# Mer.
	var mer := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(1600, 900)
	mer.mesh = plan
	mer.material_override = _mat("eau")
	mer.position = Vector3(0, -1.6, QUAI + 450)
	_contenu.add_child(mer)
	# Mur du quai et garde-corps.
	_bloc(-200, QUAI, 200, QUAI + 1, -3, 0, _mat("beton"))
	# Garde-corps, ouvert devant les jetées (voir quartier_front_de_mer.gd).
	var debut := -70.0
	var troncons := []
	for o in FrontDeMer.OUVERTURES_QUAI:
		troncons.append([debut, o[0]])
		debut = o[1]
	troncons.append([debut, 70.0])
	for t in troncons:
		var x1: float = t[0]
		var x2: float = t[1]
		_bloc(x1, QUAI - 0.1, x2, QUAI + 0.1, 0.9, 1.0, metal, false)
		_collision_boite(Vector3(x2 - x1, 4, 0.4), Transform3D(Basis(), Vector3((x1 + x2) * 0.5, 2, QUAI)))
		for i in int((x2 - x1) / 5.0) + 1:
			var x := minf(x1 + i * 5.0, x2)
			_bloc(x - 0.05, QUAI - 0.05, x + 0.05, QUAI + 0.05, 0, 0.95, metal, false)
	# Grande roue (décor, au bout d'une jetée à l'est).
	_bloc(40, QUAI, 70, QUAI + 50, -1.2, 0, _mat("beton"))
	_roue = Node3D.new()
	_roue.name = "GrandeRoue"
	_roue.position = Vector3(55, 28, QUAI + 42)
	_contenu.add_child(_roue)
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 23.4
	tore.outer_radius = 24.0
	tore.rings = 96
	anneau.mesh = tore
	anneau.material_override = _neon(Color(0.3, 0.7, 1.0), 3.0)
	anneau.rotation.x = PI / 2
	_roue.add_child(anneau)
	for i in 12:
		var rayon := MeshInstance3D.new()
		var tige := BoxMesh.new()
		tige.size = Vector3(0.2, 48, 0.2)
		rayon.mesh = tige
		rayon.material_override = _neon(Color(1.0, 0.35, 0.75), 1.5) if i % 2 == 0 else metal
		rayon.rotation.z = i * PI / 12
		_roue.add_child(rayon)
	for cote in [-1.0, 1.0]:
		var pied := _boite(Vector3(0.8, 30, 0.8), Vector3(55 + cote * 8, 14, QUAI + 42), metal, false)
		pied.rotation.z = cote * 0.27
	# Au large : la lumière de l'île de la Préhistoire.
	var ile := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.0
	sphere.height = 6.0
	ile.mesh = sphere
	ile.material_override = _neon(Color(0.6, 0.85, 1.0), 6.0)
	ile.position = Vector3(-60, 6, QUAI + 420)
	_contenu.add_child(ile)


# --- Ville au loin et métro aérien --------------------------------------

func _construire_horizon() -> void:
	# Une couronne de gratte-ciel (sans collision : on ne peut pas y aller),
	# au-delà des futurs quartiers du hub. Voir immeubles_hikari.gd.
	Immeubles.horizon(self)
	# Métro aérien : un viaduc au nord, au-dessus du Quartier des Artisans.
	var z_metro := -82.0
	var beton := _mat("beton")
	_boite(Vector3(500, 1.4, 9), Vector3(0, 12, z_metro), beton, false)
	for i in 21:
		_boite(Vector3(2, 12, 2), Vector3(-250 + i * 25, 6, z_metro), beton, false)
	_metro = Node3D.new()
	_metro.name = "RameDeMetro"
	_metro.position = Vector3(-400, 0, 0)
	_contenu.add_child(_metro)
	for i in 4:
		_boite(Vector3(19, 3.4, 3.2), Vector3(i * 20.0, 14.5, z_metro), _mat("metal"), false, _metro)
		_boite(Vector3(18, 0.8, 3.25), Vector3(i * 20.0, 15.0, z_metro), _neon(Color(1.0, 0.95, 0.8), 2.5), false, _metro)


# --- Ambiance : pluie, éclairs, finition de l'image -------------------

## Voir ambiance_hikari.gd (la pluie suit la caméra, s'arrête sous les toits).
func _construire_ambiance() -> void:
	var ambiance := Ambiance.new()
	ambiance.gouttes = gouttes if pluie else 0
	ambiance.environnement = get_node_or_null("Environnement") as WorldEnvironment
	ambiance.lune = get_node_or_null("Lune") as DirectionalLight3D
	_contenu.add_child(ambiance)
