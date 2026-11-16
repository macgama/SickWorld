@tool
extends Node3D
## Apparence d'un « Oublié » (île d'Égypte) : un ouvrier qui a perdu son nom.
## C'est un vrai personnage (le même corps que les habitants), vêtu de lin, avec
## une petite amulette violette au cou qui grésille. Quand on le met à terre, il
## reste allongé, assommé, jusqu'à ce qu'on lui rende son nom (voir carrieres_toura.gd).
##
## Appelé par apparence_loup.gd (même interface : animer, mordre, colorer).

const SCENE_APPARENCE := "res://scenes/joueur/apparence_agent.tscn"
const PEAUX := ["#9a6a48", "#8f5f3e", "#a07048", "#87583a", "#94643f"]
const HABITS := ["#e2d8c0", "#d8cdb2", "#ddd2b8", "#cfc3a6"]

## Pour varier les visages d'un oublié à l'autre.
@export var graine := 0
## « oublie » (un ouvrier sans nom) ou « garde » (un mercenaire de l'Effaceuse :
## lin brun, coiffe sombre, masse de cuivre, et une diode rouge cachée à la ceinture).
## « masque » (île de Grèce) : un Masqué, partisan muet de l'Effaceur.
## « petrifie » (île de Grèce) : un Athénien à moitié changé en marbre. Quand on le
## met à terre, la gangue de pierre se brise et il reste assommé, jusqu'à ce qu'on lui
## rende la voix (voir athenes.gd).
@export var variante := "oublie"
## Pour un Masqué : le chef (Masque lui-même), plus grand, au masque doré.
var chef := false

const HABITS_GRECS := ["#e9e2d0", "#c9b48a", "#9b4a34", "#5d6b7a", "#b8a98a", "#7a2a22"]
const PEAUX_GRECQUES := ["#a87a56", "#b07f5a", "#9c6e4b", "#b58660", "#a5764f"]
## La gangue de marbre : un voile de pierre qui monte des pieds jusqu'à la poitrine,
## avec une lisière violette qui grésille (là où la fracture gagne encore).
const SHADER_GANGUE := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform float niveau = 1.25;
varying vec3 monde;
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float h = monde.y - NODE_POSITION_WORLD.y;
	float bord = niveau + sin(monde.x * 9.0) * 0.06 + sin(monde.z * 11.0 + monde.x * 5.0) * 0.05;
	if (h > bord) {
		discard;
	}
	// Le grain de la pierre (un bruit de valeurs) et des veines grises qui serpentent.
	vec3 q = monde * 18.0;
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float b = fract(sin(dot(i + vec3(1.0, 0.0, 0.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float c = fract(sin(dot(i + vec3(0.0, 1.0, 0.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float d = fract(sin(dot(i + vec3(0.0, 0.0, 1.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float grain = mix(mix(a, b, f.x), mix(c, d, f.x), f.y * 0.5 + f.z * 0.5);
	float veine = smoothstep(0.78, 1.0, sin(monde.x * 11.0 + sin(monde.y * 7.0 + monde.z * 5.0) * 3.0 + grain * 2.0) * 0.5 + 0.5);
	vec3 marbre = mix(vec3(0.72, 0.71, 0.69), vec3(0.88, 0.87, 0.84), grain);
	ALBEDO = mix(marbre, vec3(0.42, 0.4, 0.44), veine * 0.75);
	// Des fissures sombres, plus nombreuses près de la lisière (la pierre craque).
	float fissure = smoothstep(0.97, 1.0, sin(monde.y * 40.0 + grain * 6.0 + monde.x * 9.0) * 0.5 + 0.5);
	ALBEDO *= 1.0 - fissure * 0.45;
	float lisiere = smoothstep(0.09, 0.0, bord - h);
	EMISSION = vec3(0.6, 0.3, 1.0) * lisiere * 2.0;
	ROUGHNESS = 0.42 + grain * 0.2;
	SPECULAR = 0.6;
}
"""

var _gangue: ShaderMaterial
var _eclats: Array[Node3D] = []

var _corps: Node3D
var _amulette: MeshInstance3D
var _mort := false
var _temps := 0.0


func _ready() -> void:
	for enfant in get_children():
		enfant.free()
	if not ResourceLoader.exists(SCENE_APPARENCE):
		return
	_corps = (load(SCENE_APPARENCE) as PackedScene).instantiate()
	_corps.set("modele", "femme" if variante == "petrifie" and graine % 3 == 1 else "homme")
	add_child(_corps)
	_habiller.call_deferred()
	if variante == "petrifie":
		_preparer_gangue()
		return
	if variante == "masque":
		return
	# L'amulette offerte par la « prêtresse de Memphis » : un scarabée qui luit.
	# Le garde, lui, cache sous sa ceinture une petite diode rouge (une radio moderne).
	var garde := variante == "garde" or variante == "mercenaire"
	_amulette = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.015 if garde else 0.035
	s.height = 0.02 if garde else 0.05
	_amulette.mesh = s
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = Color(0.8, 0.1, 0.05) if garde else Color(0.45, 0.25, 0.85)
	lueur.emission_enabled = true
	lueur.emission = Color(1.0, 0.1, 0.05) if garde else Color(0.6, 0.3, 1.0)
	lueur.emission_energy_multiplier = 3.0 if garde else 2.5
	_amulette.material_override = lueur
	_amulette.position = Vector3(0.12, 0.98, -0.1) if garde else Vector3(0, 1.42, -0.13)
	add_child(_amulette)


func _habiller() -> void:
	if _corps == null or not is_instance_valid(_corps):
		return
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine * 7 + 3
	if variante == "petrifie":
		_habiller_athenien(hasard)
		return
	if variante == "masque":
		_habiller_masque(hasard)
		return
	if variante == "mercenaire":
		_habiller_mercenaire(hasard)
		return
	if _corps.has_method("appliquer"):
		_corps.appliquer({"sexe": "homme", "taille_cm": hasard.randi_range(166, 180),
				"peau": Color.from_string(PEAUX[hasard.randi() % PEAUX.size()], Color.WHITE)})
	var teinte := Color.from_string(HABITS[hasard.randi() % HABITS.size()], Color.WHITE)
	if variante == "garde":
		teinte = Color.from_string(["#7a5c3e", "#6b5038", "#84603f"][hasard.randi() % 3], Color.WHITE) * Color(1.087, 1.111, 1.136)
	# Comme les habitants (pnj_epoque.gd) : les vêtements modernes deviennent du lin.
	var cible = _corps
	if cible.has_method("teindre_tenue"):
		cible.teindre_tenue(teinte * Color(0.92, 0.9, 0.88))
	for n in cible.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as StandardMaterial3D
		if m == null or m.subsurf_scatter_enabled or m.roughness < 0.2 \
				or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var lin := m.duplicate() as StandardMaterial3D
		# Il ne reste que les chaussures : des sandales ou des mocassins de cuir, unis.
		lin.albedo_texture = null
		lin.albedo_color = teinte.lerp(Color(0.4, 0.28, 0.18), 0.7)
		lin.roughness = 0.9
		(n as MeshInstance3D).material_override = lin
	# Vrai pagne de lin (voir habit_epoque.gd) quand il existe.
	if _corps.has_method("porter_habit"):
		_corps.porter_habit("shendyt" if variante == "garde" else "shendyt_court", {"principal": teinte})
	if _corps.has_method("equiper"):
		if variante == "garde":
			_corps.equiper({"tete": {"forme": "bandeau", "couleur": "#2e2620"},
					"arme_principale": {"forme": "massue", "couleur": "#b87333"}})
		else:
			_corps.equiper({"tete": {"forme": "bandeau", "couleur": "#d8cdb2"}})


## Un Athénien ordinaire : chiton de laine teinte, puis la gangue de marbre par-dessus.
func _habiller_athenien(hasard: RandomNumberGenerator) -> void:
	var femme := graine % 3 == 1
	if _corps.has_method("appliquer"):
		_corps.appliquer({"sexe": "femme" if femme else "homme",
				"taille_cm": hasard.randi_range(158, 168) if femme else hasard.randi_range(166, 180),
				"peau": Color.from_string(PEAUX_GRECQUES[hasard.randi() % PEAUX_GRECQUES.size()], Color.WHITE)})
	var teinte := Color.from_string(HABITS_GRECS[hasard.randi() % HABITS_GRECS.size()], Color.WHITE)
	if _corps.has_method("teindre_tenue"):
		_corps.teindre_tenue(teinte * Color(0.92, 0.9, 0.88))
	if _corps.has_method("porter_habit"):
		_corps.porter_habit("peplos" if femme else "chiton_court", {"principal": teinte})
	_gangue.set_shader_parameter("niveau", hasard.randf_range(1.05, 1.4) * (0.94 if femme else 1.0))
	_poser_gangue(true)


## Un Masqué (partisan de l'Effaceur, île de Grèce) : manteau sombre, visage caché
## derrière un masque de théâtre blanc, une courte épée de bronze. Il ne dit jamais rien.
func _habiller_masque(hasard: RandomNumberGenerator) -> void:
	if _corps.has_method("appliquer"):
		_corps.appliquer({"sexe": "homme", "taille_cm": 188 if chef else hasard.randi_range(170, 184),
				"peau": Color.from_string(PEAUX_GRECQUES[hasard.randi() % PEAUX_GRECQUES.size()], Color.WHITE)})
	var teinte := Color.from_string(["#34303a", "#2c2a2e", "#3d3530"][hasard.randi() % 3], Color.WHITE)
	if chef:
		teinte = Color("#4a1d24")
	if _corps.has_method("teindre_tenue"):
		_corps.teindre_tenue(teinte)
	if _corps.has_method("porter_habit"):
		_corps.porter_habit("chiton_himation", {"principal": teinte.lightened(0.15), "drape": teinte})
	if _corps.has_method("equiper"):
		_corps.equiper({"tete": {"forme": "masque_theatre", "couleur": "#d8b65a" if chef else "#ece6da"},
				"arme_principale": {"forme": "lame", "couleur": "#a8743a"}})


## Un mercenaire de Masque (île de Grèce) : un hoplite au casque de bronze, au grand
## bouclier rond et à la lance. Sous la tunique, une radio moderne (la diode rouge).
func _habiller_mercenaire(hasard: RandomNumberGenerator) -> void:
	if _corps.has_method("appliquer"):
		_corps.appliquer({"sexe": "homme", "taille_cm": hasard.randi_range(172, 186),
				"peau": Color.from_string(PEAUX_GRECQUES[hasard.randi() % PEAUX_GRECQUES.size()], Color.WHITE)})
	var teinte := Color.from_string(["#7a2a1e", "#6a2a22", "#5e3a2a"][hasard.randi() % 3], Color.WHITE)
	if _corps.has_method("teindre_tenue"):
		_corps.teindre_tenue(teinte)
	if _corps.has_method("porter_habit"):
		_corps.porter_habit("chiton_court", {"principal": teinte})
	if _corps.has_method("equiper"):
		_corps.equiper({"tete": {"forme": "casque_hoplite", "couleur": "#b0813e"},
				"arme_principale": {"forme": "lance", "couleur": "#6b5034"},
				"arme_secondaire": {"forme": "bouclier_rond", "couleur": "#a8743a"}})


func _preparer_gangue() -> void:
	var shader := Shader.new()
	shader.code = SHADER_GANGUE
	_gangue = ShaderMaterial.new()
	_gangue.shader = shader
	# Des éclats de cristal violet plantés dans l'épaule et le dos.
	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(0.5, 0.3, 0.9, 0.85)
	cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.emission_enabled = true
	cristal.emission = Color(0.55, 0.3, 1.0)
	cristal.emission_energy_multiplier = 2.2
	cristal.roughness = 0.1
	for k in 3:
		var e := MeshInstance3D.new()
		var prisme := CylinderMesh.new()
		prisme.top_radius = 0.0
		prisme.bottom_radius = 0.03 + k * 0.008
		prisme.height = 0.16 + k * 0.05
		prisme.radial_segments = 5
		e.mesh = prisme
		e.material_override = cristal
		e.position = [Vector3(0.17, 1.38, -0.04), Vector3(-0.08, 1.2, -0.14), Vector3(0.05, 0.85, 0.12)][k]
		e.rotation = Vector3(0.5 - k * 0.4, k * 1.3, 0.6 - k * 0.5)
		add_child(e)
		_eclats.append(e)


## Met (ou retire) la gangue de marbre sur tout le corps.
func _poser_gangue(oui: bool) -> void:
	if _corps == null or _gangue == null:
		return
	for n in _corps.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_overlay = _gangue if oui else null
	for e in _eclats:
		e.visible = oui


## La gangue se brise : des morceaux de marbre tombent autour de lui.
func _briser_gangue() -> void:
	_poser_gangue(false)
	var marbre := StandardMaterial3D.new()
	marbre.albedo_color = Color(0.86, 0.85, 0.82)
	marbre.roughness = 0.4
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 91
	for k in 9:
		var morceau := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(hasard.randf_range(0.06, 0.16), hasard.randf_range(0.04, 0.1), hasard.randf_range(0.06, 0.14))
		morceau.mesh = b
		morceau.material_override = marbre
		morceau.position = Vector3(hasard.randf_range(-0.25, 0.25), hasard.randf_range(0.4, 1.3), hasard.randf_range(-0.25, 0.25))
		morceau.rotation = Vector3(hasard.randf() * TAU, hasard.randf() * TAU, 0)
		add_child(morceau)
		var sol := Vector3(morceau.position.x * 3.0, 0.03, morceau.position.z * 3.0)
		var chute := morceau.create_tween()
		chute.tween_property(morceau, "position", sol, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func colorer(_allie: bool) -> void:
	pass


func mordre() -> void:
	if _corps != null and _corps.has_method("attaquer"):
		_corps.attaquer()


## Un oublié assommé se relève-t-il ? Non : il reste à terre (voir carrieres_toura.gd).
func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _corps == null:
		return
	_temps += delta
	if _amulette != null:
		_amulette.visible = not mort or fmod(_temps, 1.4) < 1.0
		_amulette.position.y = 0.25 if mort else (0.98 if variante == "garde" else 1.42)
	if mort and not _mort:
		_mort = true
		_corps.mourir()
		if variante == "petrifie":
			_briser_gangue()
	elif not mort and _mort:
		_mort = false
		_corps.revivre()
		if variante == "petrifie":
			_poser_gangue(true)
	if mort:
		return
	# Un Pétrifié marche raide, à petits pas (la pierre pèse).
	_corps.animer(delta, Vector3(0, 0, -vitesse * (0.7 if variante == "petrifie" else 1.0)), true, -1.0, Vector3.ZERO)
