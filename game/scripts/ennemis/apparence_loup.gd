@tool
extends Node3D
## Apparence des animaux : loup, renne (élan de Sketchfab recoloré) et ours.
## Les vrais modèles 3D (CC-BY, voir assets/animaux/CREDITS.md) sont utilisés
## quand ils sont présents ; sinon on retombe sur une silhouette en formes simples.
## Le loup n'a pas de squelette : on lui en fabrique un ici (pattes, tête, queue).

const MODELES := {
	"loup": "res://assets/animaux/loup/loup.glb",
	"renne": "res://assets/animaux/elan/elan.glb",
	"ours": "res://assets/animaux/ours/ours.glb",
}
## Le loup de Sketchfab est 6 fois trop grand et regarde vers -X.
const ECHELLE_LOUP := 0.16
const SOL_LOUP := 2.05

var _corps: Node3D
var _tete: Node3D
var _pattes: Array[Node3D] = []
var _queue: Node3D
var _phase := 0.0
var _morsure := 0.0
var _materiaux: Array[StandardMaterial3D] = []
var _hauteur_corps := 0.62

# Vrai modèle 3D.
var espece := "loup"
var _modele: Node3D
var _pivot: Node3D
var _anim: AnimationPlayer
var _squelette: Skeleton3D
var _anim_courante := ""
var _mort_jouee := false
var _attaque := 0.0
var _vitesses_ref := {}
static var _maillage_loup: ArrayMesh
static var _os_loup: Array = []
static var _textures_renne := {}
const ApparenceNil := preload("res://scripts/ennemis/apparence_nil.gd")
const ApparenceOublie := preload("res://scripts/ennemis/apparence_oublie.gd")
const ApparenceSerpent := preload("res://scripts/ennemis/apparence_serpent.gd")
const ApparencePoulpe := preload("res://scripts/ennemis/apparence_poulpe.gd")
const ApparenceChien := preload("res://scripts/ennemis/apparence_chien.gd")
const ApparenceHautParleurs := preload("res://scripts/ennemis/apparence_haut_parleurs.gd")
## Apparence d'une autre famille d'animaux à qui tout est confié (bêtes du Nil).
var _delegue: Node3D


func _ready() -> void:
	for enfant in get_children():
		enfant.queue_free()
	var parent := get_parent()
	var type := str(parent.get("type_ennemi")) if parent != null else ""
	# L'anomalie de la Faille de l'Agora (île de Grèce) : une tour de haut-parleurs vivante.
	if type.begins_with("mur_haut_parleurs"):
		espece = "oublie"
		_delegue = ApparenceHautParleurs.new()
		_delegue.name = "HautParleurs"
		add_child(_delegue)
		return
	# Les bêtes du Nil (île d'Égypte) ont leur propre apparence, sculptée en code.
	if type.begins_with("pirate") or type.begins_with("athlete") or type.begins_with("pilleur") or type.begins_with("pillard"):
		# Les pirates de l'Égée et les athlètes de la palestre (île de Grèce).
		espece = "oublie"
		_delegue = ApparenceOublie.new()
		_delegue.name = "Oublie"
		_delegue.graine = parent.get_instance_id() % 997
		_delegue.variante = "athlete" if type.begins_with("athlete") else "pirate"
		_delegue.chef = type.contains("chef") or type.contains("champion")
		add_child(_delegue)
		return
	if type.begins_with("carrefour") or type.begins_with("feu_tricolore"):
		# L'anomalie du Carrefour fou (île de Rome) et ses petits feux tricolores.
		espece = "oublie"
		_delegue = preload("res://scripts/ennemis/apparence_carrefour.gd").new()
		_delegue.name = "Carrefour"
		_delegue.petit = type.begins_with("feu_tricolore")
		add_child(_delegue)
		return
	if type.begins_with("colosse"):
		# Le cœur de cristal du Colosse (boss du donjon du Colisée, île de Rome).
		espece = "colosse"
		_delegue = preload("res://scripts/ennemis/apparence_coeur_colosse.gd").new()
		_delegue.name = "CoeurColosse"
		add_child(_delegue)
		return
	if type.begins_with("gladiateur"):
		# Les gladiateurs des jeux du Colisée (île de Rome) : Priscus le mirmillon, Verus
		# le Thrace, et le champion fracturé de Domitien.
		espece = "oublie"
		_delegue = ApparenceOublie.new()
		_delegue.name = "Oublie"
		_delegue.graine = parent.get_instance_id() % 997
		_delegue.variante = "gladiateur"
		_delegue.style = "thrace" if type.contains("verus") or type.contains("thrace") \
				else ("retiaire" if type.contains("retiaire") else "mirmillon")
		_delegue.chef = type.contains("champion")
		add_child(_delegue)
		return
	if type.begins_with("oublie") or type.begins_with("garde") or type.begins_with("petrifie") \
			or type.begins_with("masque") or type.begins_with("mercenaire") or type.begins_with("statue") \
			or type.begins_with("meduse") or type.begins_with("pretorien"):
		# Pas « "" » : ce serait un agent de la Vigie pour le bruiteur (pas, esquives…).
		espece = "oublie"
		_delegue = ApparenceOublie.new()
		_delegue.name = "Oublie"
		_delegue.graine = parent.get_instance_id() % 997
		_delegue.variante = "garde" if type.begins_with("garde") else ("petrifie" if type.begins_with("petrifie") \
				else ("masque" if type.begins_with("masque") else ("mercenaire" if type.begins_with("mercenaire") \
				else ("statue" if type.begins_with("statue") else ("gorgone" if type.begins_with("meduse") \
				else ("pretorien" if type.begins_with("pretorien") else "oublie"))))))
		_delegue.chef = type == "masque_effaceur" or type == "masque_acropole"
		add_child(_delegue)
		return
	if type.begins_with("cobra") or type.begins_with("isfet") or type.begins_with("vipere") or type.begins_with("serpent_gorgone"):
		espece = "serpent"
		_delegue = ApparenceSerpent.new()
		_delegue.name = "Serpent"
		_delegue.espece = "isfet" if type.begins_with("isfet") else ("vipere" if type.begins_with("vipere") \
				else ("gorgone" if type.begins_with("serpent_gorgone") else "cobra"))
		if type.begins_with("serpent_gorgone"):
			# Les serpents de la Gorgone sont bien plus gros qu'une vipère.
			_delegue.scale = Vector3.ONE * 2.2
		add_child(_delegue)
		return
	if type.begins_with("crocodile") or type.begins_with("hippopotame") or type.begins_with("babouin") \
			or type.begins_with("sanglier") or type.begins_with("rhinoceros"):
		espece = "hippopotame" if type.begins_with("hippopotame") else ("babouin" if type.begins_with("babouin") \
				else "sanglier" if type.begins_with("sanglier") else "rhinoceros" if type.begins_with("rhinoceros") else "crocodile")
		_delegue = ApparenceNil.new()
		_delegue.name = "Nil"
		_delegue.espece = espece
		add_child(_delegue)
		if type.contains("geant") or type.contains("enrage"):
			scale = Vector3.ONE * 1.35
		elif type.contains("hymette"):
			# Le grand sanglier de l'Hymette, qui ravage les vignes.
			scale = Vector3.ONE * 1.6
		return
	if type.begins_with("poulpe"):
		# Le poulpe de la crique du Pirée (île de Grèce).
		espece = "poulpe"
		_delegue = ApparencePoulpe.new()
		_delegue.name = "Poulpe"
		add_child(_delegue)
		if type.contains("fracture"):
			scale = Vector3.ONE * 1.5
		return
	if (type.begins_with("chien") or type.begins_with("molosse")) \
			and ApparenceChien.disponible("molosse" if type.begins_with("molosse") else "chien"):
		# Les chiens du port du Pirée (île de Grèce) : vrais modèles de chiens.
		# « espece » reste « loup » pour les bruits (grondements, morsures).
		_delegue = ApparenceChien.new()
		_delegue.name = "Chien"
		_delegue.espece = "molosse" if type.begins_with("molosse") else "chien"
		add_child(_delegue)
		return
	if type.begins_with("renne"):
		espece = "renne"
	elif type.begins_with("ours"):
		espece = "ours"
	if ResourceLoader.exists(MODELES[espece]):
		_construire_modele()
		if type.begins_with("ours_sans"):
			scale = Vector3.ONE * 2.4
		elif type.begins_with("chien") or type.begins_with("molosse"):
			# Les chiens du port du Pirée : plus trapus et plus sombres qu'un loup ;
			# le molosse (le grand chien de garde des Grecs) est massif.
			scale = Vector3(1.05, 1.0, 0.95) if type.begins_with("molosse") else Vector3(0.78, 0.76, 0.74)
			_en_chien(type.begins_with("molosse"))
		elif type.begins_with("chacal"):
			# Le chacal doré d'Égypte : un petit loup fin, au pelage fauve.
			scale = Vector3(0.72, 0.74, 0.7)
			_en_chacal()
		elif type.begins_with("leopard"):
			# Le léopard des jeux (île de Rome) : un félin plus fin que le lion, sans crinière,
			# au pelage doré tacheté de noir.
			scale = Vector3(1.0, 0.95, 1.15)
			_en_leopard()
		elif type.begins_with("tigre"):
			# Le tigre du parc impérial de Luoyang (île de la Chine) : un grand félin orange
			# rayé de noir (sur la silhouette du loup, en attendant un vrai modèle de tigre).
			scale = Vector3(1.35, 1.25, 1.45)
			_en_tigre()
		elif type.begins_with("lion"):
			# Le lion évadé du vivarium (île de Rome) : un grand félin fauve à crinière
			# sombre (sur la silhouette du loup, en attendant un vrai modèle de lion).
			scale = Vector3(1.3, 1.25, 1.35)
			_en_lion()
		elif type.contains("alpha"):
			scale = Vector3.ONE * 1.5
		return
	_construire()
	if espece == "ours":
		_en_ours()


## Un vrai animal : le modèle de Sketchfab, tourné pour regarder vers -Z.
func _construire_modele() -> void:
	_materiaux.clear()
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	if espece == "loup":
		_construire_loup_squelette()
		return
	_modele = (load(MODELES[espece]) as PackedScene).instantiate()
	_modele.rotation.y = PI
	if espece == "renne":
		# Un renne est plus petit qu'un élan, au pelage plus gris.
		_modele.scale = Vector3.ONE * 0.78
	_pivot.add_child(_modele)
	if espece == "renne":
		_en_renne()
	var lecteurs := _modele.find_children("*", "AnimationPlayer", true, false)
	if lecteurs.is_empty():
		return
	_anim = lecteurs[0]
	for nom in _anim.get_animation_list():
		var a := _anim.get_animation(nom)
		var boucle: bool = not (nom.begins_with("Death") or nom.begins_with("Attack") or nom.begins_with("Hit")
				or nom.begins_with("Trans") or nom.begins_with("Jump"))
		a.loop_mode = Animation.LOOP_LINEAR if boucle else Animation.LOOP_NONE
		_retirer_deplacement(a)
		_vitesses_ref[nom] = float(a.get_meta("vitesse_ref", 0.0)) * (1.2 if espece == "ours" else 1.0)
	_jouer(_nom_repos())


## Pelage brun-gris des chiens errants, noir du molosse (on teinte la texture du loup).
func _en_chien(molosse: bool) -> void:
	if _pivot == null:
		return
	for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if m == null:
			continue
		var pelage := m.duplicate() as StandardMaterial3D
		pelage.albedo_color = Color(0.42, 0.38, 0.36) if molosse else Color(1.05, 0.86, 0.66)
		(mi as MeshInstance3D).material_override = pelage


## Pelage fauve et dos plus sombre du chacal (on teinte la texture du loup).
func _en_chacal() -> void:
	if _pivot == null:
		return
	for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if m == null:
			continue
		var fauve := m.duplicate() as StandardMaterial3D
		fauve.albedo_color = Color(1.35, 1.02, 0.66)
		(mi as MeshInstance3D).material_override = fauve


## Pelage fauve du lion, et sa crinière : une grosse touffe brun sombre autour du cou,
## accrochée à l'os de la tête (elle suit ses mouvements).
func _en_leopard() -> void:
	if _pivot == null:
		return
	var taches := NoiseTexture2D.new()
	taches.width = 128
	taches.height = 128
	taches.seamless = true
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_CELLULAR
	bruit.frequency = 0.09
	bruit.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	taches.noise = bruit
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.12, 0.08, 0.04))
	degrade.set_color(1, Color(1.0, 0.95, 0.85))
	degrade.add_point(0.22, Color(0.12, 0.08, 0.04))
	degrade.add_point(0.3, Color(1.0, 0.95, 0.85))
	taches.color_ramp = degrade
	for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if m == null:
			continue
		var robe := m.duplicate() as StandardMaterial3D
		robe.albedo_color = Color(1.5, 1.08, 0.5)
		robe.detail_enabled = true
		robe.detail_albedo = taches
		robe.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		robe.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
		(mi as MeshInstance3D).material_override = robe


## Le tigre : une robe orange vif, des rayures noires (du bruit étiré en bandes).
func _en_tigre() -> void:
	if _pivot == null:
		return
	var rayures := NoiseTexture2D.new()
	rayures.width = 256
	rayures.height = 32
	rayures.seamless = true
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.05
	bruit.fractal_octaves = 2
	rayures.noise = bruit
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.06, 0.04, 0.03))
	degrade.set_color(1, Color(1.0, 0.96, 0.9))
	degrade.add_point(0.42, Color(0.06, 0.04, 0.03))
	degrade.add_point(0.5, Color(1.0, 0.96, 0.9))
	rayures.color_ramp = degrade
	for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if m == null:
			continue
		var robe := m.duplicate() as StandardMaterial3D
		robe.albedo_color = Color(1.7, 0.86, 0.32)
		robe.detail_enabled = true
		robe.detail_albedo = rayures
		robe.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		robe.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
		(mi as MeshInstance3D).material_override = robe


func _en_lion() -> void:
	if _pivot == null:
		return
	for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if m == null:
			continue
		var fauve := m.duplicate() as StandardMaterial3D
		fauve.albedo_color = Color(1.45, 1.08, 0.62)
		(mi as MeshInstance3D).material_override = fauve
	var squelette := _pivot.find_child("Squelette", true, false) as Skeleton3D
	if squelette == null or squelette.find_bone("tete") < 0:
		return
	var attache := BoneAttachment3D.new()
	attache.name = "Criniere"
	attache.bone_name = "tete"
	squelette.add_child(attache)
	var crins := StandardMaterial3D.new()
	crins.albedo_color = Color(0.32, 0.2, 0.1)
	crins.roughness = 1.0
	var bruit := NoiseTexture2D.new()
	bruit.width = 64
	bruit.height = 64
	bruit.seamless = true
	bruit.as_normal_map = true
	bruit.bump_strength = 10.0
	var n := FastNoiseLite.new()
	n.frequency = 0.35
	bruit.noise = n
	crins.normal_enabled = true
	crins.normal_texture = bruit
	for k in 3:
		var touffe := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.75 - k * 0.12
		sphere.height = 1.25 - k * 0.15
		touffe.mesh = sphere
		touffe.material_override = crins
		# Dans le repère de l'os : la tête regarde vers -x ; la crinière part vers le cou (+x).
		touffe.position = Vector3(0.35 + k * 0.45, -0.05 - k * 0.12, 0)
		attache.add_child(touffe)


## Les animations font avancer l'os racine (« root motion ») : c'est le jeu qui
## déplace l'animal, donc on retire ce déplacement et on note sa vitesse.
func _retirer_deplacement(a: Animation) -> void:
	if a.has_meta("vitesse_ref"):
		return
	var vitesse := 0.0
	for t in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(a.track_get_path(t)).ends_with(":RigRoot_01"):
			continue
		var n := a.track_get_key_count(t)
		if n > 1:
			var debut: Vector3 = a.track_get_key_value(t, 0)
			var fin: Vector3 = a.track_get_key_value(t, n - 1)
			vitesse = Vector2(fin.x - debut.x, fin.z - debut.z).length() * 0.01 / maxf(a.length, 0.01)
		a.remove_track(t)
	a.set_meta("vitesse_ref", vitesse)


func _nom_repos() -> String:
	return "Stand_Eating_01" if espece == "renne" and get_instance_id() % 3 == 0 else "Stand_Idle_01" \
			if espece == "ours" else "Stand_Breathing_01"


func _jouer(nom: String, fondu := 0.25, vitesse := 1.0) -> void:
	if _anim == null or not _anim.has_animation(nom):
		return
	_anim.speed_scale = vitesse
	if nom == _anim_courante:
		return
	_anim_courante = nom
	_anim.play(nom, fondu)


## L'élan devient un renne : pelage gris-brun, moins roux, un peu plus clair.
func _en_renne() -> void:
	for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
		var maille := (mi as MeshInstance3D).mesh
		for i in maille.get_surface_count():
			var m := maille.surface_get_material(i) as BaseMaterial3D
			if m == null or m.albedo_texture == null:
				continue
			var cle := m.albedo_texture.resource_path + str(m.albedo_texture.get_rid())
			if not _textures_renne.has(cle):
				var image := m.albedo_texture.get_image()
				if image == null:
					continue
				if image.is_compressed():
					image.decompress()
				image.adjust_bcs(1.12, 0.95, 0.38)
				image.generate_mipmaps()
				_textures_renne[cle] = ImageTexture.create_from_image(image)
			var copie := m.duplicate() as BaseMaterial3D
			copie.albedo_texture = _textures_renne[cle]
			(mi as MeshInstance3D).set_surface_override_material(i, copie)


## Teinte le pelage (multiplie la texture par une couleur).
func teinter(couleur: Color) -> void:
	if _pivot == null:
		for m in _materiaux.slice(0, 1):
			m.albedo_color = couleur
		return
	for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
		var maille := (mi as MeshInstance3D).mesh
		for i in maille.get_surface_count():
			var m := maille.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			var copie := m.duplicate() as BaseMaterial3D
			copie.albedo_color = m.albedo_color * couleur
			(mi as MeshInstance3D).set_surface_override_material(i, copie)


## Le loup de Sketchfab n'a qu'un maillage figé : on lui pose un squelette
## (corps, tête, queue, quatre pattes) et on répartit les sommets entre les os.
func _construire_loup_squelette() -> void:
	if _maillage_loup == null:
		_preparer_maillage_loup()
	_squelette = Skeleton3D.new()
	_squelette.name = "Squelette"
	_squelette.rotation.y = -PI / 2
	_squelette.scale = Vector3.ONE * ECHELLE_LOUP
	_squelette.position.y = SOL_LOUP * ECHELLE_LOUP
	_pivot.add_child(_squelette)
	var skin := Skin.new()
	for i in _os_loup.size():
		var os: Dictionary = _os_loup[i]
		_squelette.add_bone(os.nom)
		var parent_os: int = os.parent
		_squelette.set_bone_parent(i, parent_os)
		var origine: Vector3 = os.position
		if parent_os >= 0:
			origine -= (_os_loup[parent_os] as Dictionary).position
		_squelette.set_bone_rest(i, Transform3D(Basis(), origine))
		skin.add_bind(i, Transform3D(Basis(), os.position).affine_inverse())
	_squelette.reset_bone_poses()
	var mi := MeshInstance3D.new()
	mi.name = "Loup"
	mi.mesh = _maillage_loup
	mi.skin = skin
	_squelette.add_child(mi)
	mi.skeleton = NodePath("..")


func _preparer_maillage_loup() -> void:
	var source := (load(MODELES.loup) as PackedScene).instantiate()
	var origine := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var tableaux: Array = origine.mesh.surface_get_arrays(0)
	var materiau := origine.get_active_material(0)
	source.free()
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	# Où sont les pattes ? On regarde les sommets proches du sol.
	var sommes := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var nombres := [0, 0, 0, 0]
	for p in sommets:
		if p.y < -1.0:
			var k := (0 if p.x < 0.5 else 2) + (0 if p.z < 0.0 else 1)
			sommes[k] += p
			nombres[k] += 1
	var hanches: Array[Vector3] = []
	for k in 4:
		var c: Vector3 = sommes[k] / maxf(nombres[k], 1)
		hanches.append(Vector3(c.x, 0.9, c.z))
	var corps := Vector3(0, 1.2, 0)
	_os_loup = [
		{"nom": "corps", "parent": -1, "position": corps},
		{"nom": "tete", "parent": 0, "position": Vector3(-2.7, 1.8, 0)},
		{"nom": "queue", "parent": 0, "position": Vector3(3.7, 1.3, 0)},
	]
	for k in 4:
		_os_loup.append({"nom": "patte%d" % k, "parent": 0, "position": hanches[k]})
	var os := PackedInt32Array()
	var poids := PackedFloat32Array()
	os.resize(sommets.size() * 4)
	poids.resize(sommets.size() * 4)
	for i in sommets.size():
		var p := sommets[i]
		var meilleur := 0
		var w := 0.0
		var w_tete := smoothstep(-2.3, -3.2, p.x) * smoothstep(0.5, 1.3, p.y)
		if w_tete > w:
			meilleur = 1
			w = w_tete
		var w_queue := smoothstep(3.5, 4.2, p.x) * smoothstep(0.1, 0.7, p.y)
		if w_queue > w:
			meilleur = 2
			w = w_queue
		var k := (0 if p.x < 0.5 else 2) + (0 if p.z < 0.0 else 1)
		var ecart := absf(p.x - hanches[k].x)
		var w_patte := smoothstep(1.1, -0.3, p.y) * smoothstep(1.8, 1.2, ecart)
		if w_patte > w:
			meilleur = 3 + k
			w = w_patte
		os[i * 4] = meilleur
		os[i * 4 + 1] = 0
		poids[i * 4] = w
		poids[i * 4 + 1] = 1.0 - w
	var nouveaux := []
	nouveaux.resize(Mesh.ARRAY_MAX)
	for t in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		nouveaux[t] = tableaux[t]
	nouveaux[Mesh.ARRAY_BONES] = os
	nouveaux[Mesh.ARRAY_WEIGHTS] = poids
	_maillage_loup = ArrayMesh.new()
	_maillage_loup.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, nouveaux)
	_maillage_loup.surface_set_material(0, materiau)


## L'Ours Sans Mémoire : la même silhouette, massive, au pelage brun sombre.
func _en_ours() -> void:
	scale = Vector3(2.5, 2.4, 2.2)
	if _materiaux.size() >= 2:
		_materiaux[0].albedo_color = Color(0.2, 0.14, 0.1)
		_materiaux[1].albedo_color = Color(0.3, 0.22, 0.15)
	if _queue != null:
		_queue.scale = Vector3.ONE * 0.3


func _mat(couleur: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.9
	_materiaux.append(m)
	return m


func _forme(parent: Node3D, maillage: Mesh, materiau: Material, pos: Vector3, echelle := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = pos
	mi.scale = echelle
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _construire() -> void:
	if espece == "renne":
		_construire_renne()
		return
	var pelage := _mat(Color(0.42, 0.38, 0.33))
	var clair := _mat(Color(0.62, 0.58, 0.52))
	var sombre := _mat(Color(0.08, 0.07, 0.06))

	_corps = Node3D.new()
	_corps.position = Vector3(0, 0.62, 0)
	add_child(_corps)
	var tronc := CapsuleMesh.new()
	tronc.radius = 0.22
	tronc.height = 1.1
	_forme(_corps, tronc, pelage, Vector3.ZERO, Vector3(1, 1, 1.0), Vector3(PI / 2, 0, 0))
	_forme(_corps, tronc, clair, Vector3(0, -0.06, -0.05), Vector3(0.85, 0.8, 0.8), Vector3(PI / 2, 0, 0))

	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.18, -0.55)
	_corps.add_child(_tete)
	var crane := SphereMesh.new()
	crane.radius = 0.16
	crane.height = 0.3
	_forme(_tete, crane, pelage, Vector3.ZERO)
	var museau := BoxMesh.new()
	museau.size = Vector3(0.12, 0.11, 0.24)
	_forme(_tete, museau, clair, Vector3(0, -0.04, -0.18))
	var truffe := SphereMesh.new()
	truffe.radius = 0.035
	truffe.height = 0.07
	_forme(_tete, truffe, sombre, Vector3(0, -0.01, -0.31))
	var oreille := PrismMesh.new()
	oreille.size = Vector3(0.08, 0.12, 0.04)
	_forme(_tete, oreille, pelage, Vector3(-0.08, 0.15, 0.02))
	_forme(_tete, oreille, pelage, Vector3(0.08, 0.15, 0.02))
	var oeil := SphereMesh.new()
	oeil.radius = 0.022
	oeil.height = 0.044
	var yeux := _mat(Color(0.9, 0.7, 0.2))
	yeux.emission_enabled = true
	yeux.emission = Color(0.9, 0.6, 0.1)
	yeux.emission_energy_multiplier = 0.6
	_forme(_tete, oeil, yeux, Vector3(-0.07, 0.04, -0.12))
	_forme(_tete, oeil, yeux, Vector3(0.07, 0.04, -0.12))

	var patte := CapsuleMesh.new()
	patte.radius = 0.05
	patte.height = 0.55
	for pos in [Vector3(-0.12, -0.05, -0.38), Vector3(0.12, -0.05, -0.38),
			Vector3(-0.12, -0.05, 0.38), Vector3(0.12, -0.05, 0.38)]:
		var hanche := Node3D.new()
		hanche.position = pos
		_corps.add_child(hanche)
		_forme(hanche, patte, pelage, Vector3(0, -0.27, 0))
		_pattes.append(hanche)

	_queue = Node3D.new()
	_queue.position = Vector3(0, 0.08, 0.55)
	_corps.add_child(_queue)
	var q := CapsuleMesh.new()
	q.radius = 0.05
	q.height = 0.5
	_forme(_queue, q, pelage, Vector3(0, -0.12, 0.18), Vector3.ONE, Vector3(-0.9, 0, 0))


## Renne : plus grand, longues pattes, cou épais au poitrail clair, bois ramifiés.
func _construire_renne() -> void:
	var pelage := _mat(Color(0.36, 0.3, 0.24))
	var clair := _mat(Color(0.74, 0.7, 0.62))
	var sombre := _mat(Color(0.07, 0.06, 0.05))
	var bois := _mat(Color(0.55, 0.47, 0.36))
	bois.roughness = 0.7
	_corps = Node3D.new()
	_corps.position = Vector3(0, 1.0, 0)
	add_child(_corps)
	var tronc := CapsuleMesh.new()
	tronc.radius = 0.3
	tronc.height = 1.45
	_forme(_corps, tronc, pelage, Vector3.ZERO, Vector3(1, 1.05, 1), Vector3(PI / 2, 0, 0))
	_forme(_corps, tronc, clair, Vector3(0, -0.09, 0.05), Vector3(0.88, 0.8, 0.82), Vector3(PI / 2, 0, 0))
	# Cou épais et crinière claire.
	var cou := CapsuleMesh.new()
	cou.radius = 0.15
	cou.height = 0.7
	_forme(_corps, cou, clair, Vector3(0, 0.25, -0.62), Vector3.ONE, Vector3(-0.75, 0, 0))
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.5, -0.88)
	_corps.add_child(_tete)
	var crane := CapsuleMesh.new()
	crane.radius = 0.11
	crane.height = 0.5
	_forme(_tete, crane, pelage, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(PI / 2 + 0.35, 0, 0))
	var truffe := SphereMesh.new()
	truffe.radius = 0.06
	truffe.height = 0.1
	_forme(_tete, truffe, sombre, Vector3(0, -0.11, -0.33))
	var oreille := PrismMesh.new()
	oreille.size = Vector3(0.07, 0.14, 0.03)
	_forme(_tete, oreille, pelage, Vector3(-0.1, 0.08, 0.06), Vector3.ONE, Vector3(0, 0, 0.9))
	_forme(_tete, oreille, pelage, Vector3(0.1, 0.08, 0.06), Vector3.ONE, Vector3(0, 0, -0.9))
	var oeil := SphereMesh.new()
	oeil.radius = 0.02
	oeil.height = 0.04
	_forme(_tete, oeil, sombre, Vector3(-0.09, 0.0, -0.1))
	_forme(_tete, oeil, sombre, Vector3(0.09, 0.0, -0.1))
	# Bois : une perche courbée de chaque côté, avec des andouillers.
	var perche := CylinderMesh.new()
	perche.top_radius = 0.015
	perche.bottom_radius = 0.03
	perche.height = 0.55
	var pointe := CylinderMesh.new()
	pointe.top_radius = 0.008
	pointe.bottom_radius = 0.02
	pointe.height = 0.24
	for cote in [-1.0, 1.0]:
		var base := Node3D.new()
		base.position = Vector3(0.07 * cote, 0.1, 0.05)
		base.rotation = Vector3(0.5, 0, -0.45 * cote)
		_tete.add_child(base)
		_forme(base, perche, bois, Vector3(0, 0.27, 0))
		var haut := Node3D.new()
		haut.position = Vector3(0, 0.52, 0)
		haut.rotation = Vector3(-0.9, 0, 0.2 * cote)
		base.add_child(haut)
		_forme(haut, perche, bois, Vector3(0, 0.25, 0), Vector3(0.8, 0.9, 0.8))
		for k in 3:
			var andouiller := Node3D.new()
			andouiller.position = Vector3(0, 0.15 + k * 0.17, 0)
			andouiller.rotation = Vector3(-0.9 + k * 0.25, 0, (0.6 + k * 0.15) * cote)
			(base if k < 2 else haut).add_child(andouiller)
			_forme(andouiller, pointe, bois, Vector3(0, 0.11, 0))
		# Andouiller de front (la « pelle »).
		var pelle := Node3D.new()
		pelle.position = Vector3(0, 0.08, 0)
		pelle.rotation = Vector3(-1.6, 0, 0)
		base.add_child(pelle)
		_forme(pelle, pointe, bois, Vector3(0, 0.11, 0))
	var patte := CapsuleMesh.new()
	patte.radius = 0.055
	patte.height = 0.95
	for pos in [Vector3(-0.16, -0.08, -0.5), Vector3(0.16, -0.08, -0.5),
			Vector3(-0.16, -0.08, 0.5), Vector3(0.16, -0.08, 0.5)]:
		var hanche := Node3D.new()
		hanche.position = pos
		_corps.add_child(hanche)
		_forme(hanche, patte, pelage, Vector3(0, -0.45, 0))
		var sabot := CylinderMesh.new()
		sabot.top_radius = 0.06
		sabot.bottom_radius = 0.08
		sabot.height = 0.08
		_forme(hanche, sabot, sombre, Vector3(0, -0.9, 0))
		_pattes.append(hanche)
	_queue = Node3D.new()
	_queue.position = Vector3(0, 0.12, 0.72)
	_corps.add_child(_queue)
	var q := SphereMesh.new()
	q.radius = 0.08
	q.height = 0.16
	_forme(_queue, q, clair, Vector3(0, 0, 0.04))
	_hauteur_corps = 1.0


## Loups invoqués : pelage plus clair et lueur bleue de la Vigie.
func colorer(allie: bool) -> void:
	if _delegue != null:
		_delegue.colorer(allie)
		return
	if not allie:
		return
	if _pivot != null:
		var lueur := StandardMaterial3D.new()
		lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lueur.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		lueur.albedo_color = Color(0.1, 0.35, 0.45)
		for mi in _pivot.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = lueur
		return
	if _materiaux.is_empty():
		return
	_materiaux[0].albedo_color = Color(0.75, 0.78, 0.82)
	_materiaux[0].emission_enabled = true
	_materiaux[0].emission = Color(0.2, 0.7, 0.9)
	_materiaux[0].emission_energy_multiplier = 0.4


func mordre() -> void:
	if _delegue != null:
		_delegue.mordre()
		return
	_morsure = 0.3
	_attaque = 0.9
	if _anim != null and espece == "ours":
		var nom := "Attack_StandAngry_01_High" if randf() < 0.5 else "Attack_StandAngry_01_Low"
		_anim_courante = nom
		_anim.play(nom, 0.1)
		_anim.speed_scale = 1.3


## Le Mur de haut-parleurs prend son souffle, puis crie (événement de la Faille de l'Agora).
func preparer_cri() -> void:
	if _delegue != null and _delegue.has_method("preparer_cri"):
		_delegue.preparer_cri()


func crier() -> void:
	if _delegue != null and _delegue.has_method("crier"):
		_delegue.crier()


func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _delegue != null:
		_delegue.animer(delta, vitesse, mort)
		return
	if _pivot != null:
		_animer_modele(delta, vitesse, mort)
		return
	if _corps == null:
		return
	if mort:
		# Couché sur le flanc.
		_corps.rotation.z = lerpf(_corps.rotation.z, PI / 2, 0.15)
		_corps.position.y = lerpf(_corps.position.y, 0.25 * _hauteur_corps / 0.62, 0.15)
		return
	_corps.rotation.z = lerpf(_corps.rotation.z, 0.0, 0.2)
	_corps.position.y = _hauteur_corps
	_phase += delta * (3.0 + vitesse * 2.2)
	var allure := clampf(vitesse / 6.0, 0.0, 1.0)
	var swing := sin(_phase) * 0.7 * allure
	_pattes[0].rotation.x = swing
	_pattes[1].rotation.x = -swing
	_pattes[2].rotation.x = -swing
	_pattes[3].rotation.x = swing
	_corps.position.y += absf(sin(_phase)) * 0.05 * allure
	_queue.rotation.y = sin(_phase * 0.5) * 0.3
	_morsure = maxf(0.0, _morsure - delta)
	_tete.rotation.x = sin(_morsure / 0.3 * PI) * 0.5
	if _hauteur_corps < 0.7:
		_tete.position.z = -0.55 - sin(_morsure / 0.3 * PI) * 0.15


func _animer_modele(delta: float, vitesse: float, mort: bool) -> void:
	_attaque = maxf(0.0, _attaque - delta)
	if _squelette != null:
		_animer_loup(delta, vitesse, mort)
		return
	if _anim == null:
		return
	if mort:
		if not _mort_jouee:
			_mort_jouee = true
			_jouer("Death_Stand_R01", 0.15)
		return
	if _mort_jouee:
		_mort_jouee = false
	if _attaque > 0.0 and espece == "ours":
		return
	# Vitesses de référence des animations (mètres par seconde, à taille réelle).
	var taille := scale.x * (_modele.scale.x if _modele != null else 1.0)
	var marche := float(_vitesses_ref.get("Walk", 1.4)) * taille
	var course := float(_vitesses_ref.get("Run", 6.0)) * taille
	if vitesse < 0.3:
		_jouer(_nom_repos(), 0.4)
	elif vitesse < (marche + course) * 0.45:
		_jouer("Walk", 0.3, clampf(vitesse / maxf(marche, 0.1), 0.6, 1.8))
	else:
		_jouer("Run", 0.3, clampf(vitesse / maxf(course, 0.1), 0.6, 1.8))


## Le loup : on bouge nous-mêmes les os qu'on lui a posés.
func _animer_loup(delta: float, vitesse: float, mort: bool) -> void:
	if mort:
		_pivot.rotation.z = lerpf(_pivot.rotation.z, PI / 2, 0.15)
		_pivot.position.y = lerpf(_pivot.position.y, 0.28, 0.15)
		return
	_pivot.rotation.z = lerpf(_pivot.rotation.z, 0.0, 0.2)
	_pivot.position.y = 0.0
	var allure := clampf(vitesse / 6.0, 0.0, 1.0)
	_phase += delta * (2.0 + vitesse * 1.6)
	# Au galop, les pattes avant et arrière vont ensemble ; au pas, en diagonale.
	var amplitude := (0.12 + 0.45 * allure) * minf(vitesse / 0.5, 1.0)
	var decalage := lerpf(PI, 0.6, allure)
	# Ordre des pattes : avant gauche, avant droite, arrière gauche, arrière droite.
	var phases := [0.0, PI, decalage, decalage + PI]
	for k in 4:
		_squelette.set_bone_pose_rotation(3 + k, Quaternion(Vector3.BACK, sin(_phase + phases[k]) * amplitude))
	var respire := sin(Time.get_ticks_msec() * 0.003) * 0.03
	var rebond := absf(sin(_phase)) * 0.25 * allure
	_squelette.set_bone_pose_position(0, (_os_loup[0] as Dictionary).position + Vector3(0, rebond + respire, 0))
	_squelette.set_bone_pose_rotation(0, Quaternion(Vector3.BACK, sin(_phase * 2.0) * 0.03 * allure))
	_morsure = maxf(0.0, _morsure - delta)
	var mord := sin(_morsure / 0.3 * PI)
	var tete_repos := 0.05 * sin(Time.get_ticks_msec() * 0.0011) - 0.1 * allure
	_squelette.set_bone_pose_rotation(1, Quaternion(Vector3.BACK, tete_repos + mord * 0.45))
	_squelette.set_bone_pose_position(1, (_os_loup[1] as Dictionary).position - (_os_loup[0] as Dictionary).position
			+ Vector3(-mord * 0.6, 0, 0))
	var queue := sin(_phase * 0.7) * (0.25 + 0.2 * allure)
	_squelette.set_bone_pose_rotation(2, Quaternion(Vector3.UP, queue) * Quaternion(Vector3.BACK, 0.2 * allure))
