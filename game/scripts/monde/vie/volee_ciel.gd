extends MultiMeshInstance3D
## Une volée d'oiseaux dans le ciel (vie ambiante des zones) : corbeaux qui tournent,
## goélands qui planent, oies sauvages en V, ibis au ras du fleuve, vautours très haut,
## hirondelles qui virevoltent… Décrite dans data/vie_ambiante.json (clé « oiseaux »).
##
## Tous les oiseaux d'une volée sont un seul MultiMesh (un seul appel de dessin) et
## les ailes battent dans le shader : une volée de 30 oiseaux ne coûte presque rien.
## Les oiseaux ne sont calculés que si la caméra est à moins de DISTANCE_CALCUL.

const SHADER := preload("res://shaders/oiseau_vol.gdshader")
const DISTANCE_CALCUL := 420.0

## Caractéristiques de chaque espèce : envergure (m), couleurs, battements par seconde,
## part du temps passée à planer (0 = bat toujours des ailes), vitesse (m/s).
const ESPECES := {
	"corbeau": {"envergure": 1.0, "dos": "#141416", "ventre": "#1c1c20", "bouts": "#0a0a0c", "frequence": 5.0, "plane": 0.35, "vitesse": 9.0, "cri": "corbeau"},
	"choucas": {"envergure": 0.7, "dos": "#1e1e22", "ventre": "#2a2a2e", "bouts": "#101012", "frequence": 6.5, "plane": 0.2, "vitesse": 9.0, "cri": "corbeau"},
	"goeland": {"envergure": 1.35, "dos": "#a9adb3", "ventre": "#e9ebee", "bouts": "#222326", "frequence": 3.0, "plane": 0.7, "vitesse": 8.0},
	"mouette": {"envergure": 1.0, "dos": "#c4c8cd", "ventre": "#f2f3f5", "bouts": "#2a2b2e", "frequence": 3.8, "plane": 0.55, "vitesse": 8.0},
	"oie": {"envergure": 1.6, "dos": "#5e564b", "ventre": "#9b9284", "bouts": "#2e2a25", "frequence": 3.4, "plane": 0.05, "vitesse": 14.0},
	"cygne": {"envergure": 2.2, "dos": "#ecebe6", "ventre": "#f4f3ee", "bouts": "#d8d6cf", "frequence": 2.6, "plane": 0.05, "vitesse": 15.0},
	"ibis": {"envergure": 1.05, "dos": "#ece9e1", "ventre": "#f2efe8", "bouts": "#18181a", "frequence": 4.0, "plane": 0.3, "vitesse": 10.0},
	"heron": {"envergure": 1.75, "dos": "#7d838a", "ventre": "#b8bcc0", "bouts": "#2a2c30", "frequence": 2.3, "plane": 0.2, "vitesse": 8.0},
	"vautour": {"envergure": 2.6, "dos": "#4a3c30", "ventre": "#6a5a48", "bouts": "#1e1a16", "frequence": 1.6, "plane": 0.92, "vitesse": 7.0},
	"milan": {"envergure": 1.6, "dos": "#6b4630", "ventre": "#9a7050", "bouts": "#1e1814", "frequence": 2.5, "plane": 0.8, "vitesse": 8.0},
	"aigle": {"envergure": 2.1, "dos": "#3e3026", "ventre": "#5a4838", "bouts": "#18140f", "frequence": 1.8, "plane": 0.9, "vitesse": 9.0},
	"hirondelle": {"envergure": 0.32, "dos": "#1a1e30", "ventre": "#e8e2d8", "bouts": "#101218", "frequence": 9.0, "plane": 0.35, "vitesse": 11.0},
	"etourneau": {"envergure": 0.38, "dos": "#1a1a1e", "ventre": "#26262a", "bouts": "#101012", "frequence": 10.0, "plane": 0.1, "vitesse": 12.0},
	"pigeon": {"envergure": 0.65, "dos": "#6a6f78", "ventre": "#8a8f98", "bouts": "#2a2c30", "frequence": 6.0, "plane": 0.15, "vitesse": 10.0},
}

## Espèce (clé de ESPECES).
var espece := "corbeau"
## Comportement : « cercle » (tournent autour du centre), « formation » (traversent
## le ciel en V, puis repartent), « nuee » (virevoltent ensemble autour d'un point qui
## dérive lentement).
var comportement := "cercle"
var centre := Vector3(0, 30, 0)
## Rayon du cercle (cercle, nuee) ou demi-longueur de la traversée (formation).
var rayon := 40.0
## Écart d'altitude entre les oiseaux (m).
var ecart_altitude := 8.0
var nombre := 8
## Direction de la traversée (formation), en degrés (0 = vers le nord).
var direction_deg := 30.0
## Pause entre deux traversées (formation), en secondes.
var pause_formation := 25.0
var graine := 1

var _fiche: Dictionary
var _oiseaux: Array[Dictionary] = []
var _temps := 0.0
var _hasard := RandomNumberGenerator.new()
var _cri: AudioStreamPlayer3D
var _prochain_cri := 8.0


func _ready() -> void:
	add_to_group("vie_ambiante")
	_hasard.seed = graine
	_fiche = ESPECES.get(espece, ESPECES["corbeau"])
	var env := float(_fiche["envergure"])
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("couleur_dos", Color(String(_fiche["dos"])))
	mat.set_shader_parameter("couleur_ventre", Color(String(_fiche["ventre"])))
	mat.set_shader_parameter("couleur_bouts", Color(String(_fiche["bouts"])))
	mat.set_shader_parameter("frequence", float(_fiche["frequence"]) * TAU / 2.0)
	mat.set_shader_parameter("amplitude", 0.75 if env > 1.2 else 0.95)
	var forme := maillage_oiseau(env, espece in ["ibis", "heron", "cygne", "oie"])
	forme.surface_set_material(0, mat)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = forme
	multimesh.instance_count = nombre
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Le MultiMesh bouge partout autour du centre : grande boîte pour ne pas le perdre.
	custom_aabb = AABB(centre + Vector3(-rayon - 300, -80, -rayon - 300), Vector3(rayon * 2 + 600, 160, rayon * 2 + 600))
	var vitesse := float(_fiche["vitesse"])
	for i in nombre:
		var o := {
			"angle": _hasard.randf() * TAU,
			"rayon": rayon * _hasard.randf_range(0.45, 1.0),
			"haut": _hasard.randf_range(-ecart_altitude, ecart_altitude) * 0.5,
			"vitesse": vitesse * _hasard.randf_range(0.85, 1.15),
			"sens": 1.0 if comportement != "cercle" or _hasard.randf() < 0.8 else -1.0,
			"phase": _hasard.randf(),
			"plane": 0.0,
			"bat": 1.0,
			"teinte": _hasard.randf(),
			"bruit": _hasard.randf() * 100.0,
		}
		_oiseaux.append(o)
	_temps = _hasard.randf() * 60.0
	if _fiche.has("cri"):
		_cri = AudioStreamPlayer3D.new()
		_cri.bus = "Ambiance" if AudioServer.get_bus_index("Ambiance") >= 0 else "Master"
		_cri.max_distance = 140.0
		_cri.unit_size = 18.0
		_cri.volume_db = -6.0
		add_child(_cri)
	_mettre_a_jour(0.0)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_to(centre) > DISTANCE_CALCUL + rayon:
		visible = false
		return
	visible = true
	_mettre_a_jour(delta)
	if _cri != null:
		_prochain_cri -= delta
		if _prochain_cri <= 0.0:
			_prochain_cri = _hasard.randf_range(7.0, 22.0)
			_crier()


func _mettre_a_jour(delta: float) -> void:
	_temps += delta
	match comportement:
		"formation":
			_formation()
		"nuee":
			_nuee(delta)
		_:
			_cercle(delta)


## Chaque oiseau tourne sur son propre cercle, monte et descend un peu, et alterne
## battements et vol plané (le rapport dépend de l'espèce).
func _cercle(delta: float) -> void:
	var part_plane := float(_fiche["plane"])
	for i in _oiseaux.size():
		var o := _oiseaux[i]
		var r: float = o["rayon"] + 6.0 * sin(_temps * 0.05 + o["bruit"])
		o["angle"] += o["sens"] * o["vitesse"] / maxf(r, 4.0) * delta
		var a: float = o["angle"]
		var p: Vector3 = centre + Vector3(cos(a) * r, o["haut"] + 2.5 * sin(_temps * 0.3 + o["bruit"]), sin(a) * r)
		# Tangente au cercle = sens du vol ; on penche dans le virage.
		var avant: Vector3 = Vector3(-sin(a), 0, cos(a)) * float(o["sens"])
		_basculer_plane(o, part_plane, delta)
		_poser(i, p, avant, 0.35 * o["sens"], o)


## Les oiseaux virevoltent en groupe autour d'un point qui se promène.
func _nuee(delta: float) -> void:
	var c := centre + Vector3(sin(_temps * 0.07) * rayon, 0, cos(_temps * 0.053) * rayon)
	for i in _oiseaux.size():
		var o := _oiseaux[i]
		var r: float = 3.0 + 6.0 * (0.5 + 0.5 * sin(_temps * 0.4 + o["bruit"]))
		o["angle"] += o["vitesse"] / r * delta * (1.0 if i % 3 else -1.0)
		var a: float = o["angle"]
		var p: Vector3 = c + Vector3(cos(a) * r, o["haut"] + 2.0 * sin(_temps * 1.3 + o["bruit"]), sin(a * 1.3) * r)
		var avant := Vector3(-sin(a), 0.2 * cos(_temps + o["bruit"]), cos(a) * 1.3).normalized() * (1.0 if i % 3 else -1.0)
		_basculer_plane(o, float(_fiche["plane"]), delta)
		_poser(i, p, avant, 0.6, o)


## Vol en V : la volée traverse le ciel en ligne droite, disparaît, puis repasse.
func _formation() -> void:
	var dir := Vector3(sin(deg_to_rad(direction_deg)), 0, -cos(deg_to_rad(direction_deg)))
	var cote := Vector3(dir.z, 0, -dir.x)
	var vitesse := float(_fiche["vitesse"])
	var trajet := rayon * 2.0 + 400.0
	var cycle := trajet / vitesse + pause_formation
	var t := fmod(_temps, cycle)
	var avance := -rayon - 200.0 + t * vitesse
	var en_pause := t * vitesse > trajet
	for i in _oiseaux.size():
		var o := _oiseaux[i]
		# Rang dans le V : 0 en tête, puis alternativement à gauche et à droite.
		var rang := (i + 1) / 2
		var cote_v := 0.0 if i == 0 else (1.0 if i % 2 else -1.0)
		var p: Vector3 = centre + dir * (avance - rang * 2.6) + cote * cote_v * rang * 2.4
		p.y += sin(_temps * 0.8 + rang) * 0.4 + o["haut"] * 0.15
		o["bat"] = 1.0
		_poser(i, p if not en_pause else Vector3(0, -500, 0), dir, 0.0, o)


func _basculer_plane(o: Dictionary, part_plane: float, delta: float) -> void:
	o["plane"] -= delta
	if o["plane"] <= 0.0:
		var plane := _hasard.randf() < part_plane
		o["cible_bat"] = 0.0 if plane else 1.0
		o["plane"] = _hasard.randf_range(1.5, 5.0) if plane else _hasard.randf_range(0.8, 2.5)
	o["bat"] = move_toward(o["bat"], o.get("cible_bat", 1.0), delta * 2.5)


func _poser(i: int, p: Vector3, avant: Vector3, penche: float, o: Dictionary) -> void:
	var b := Basis.looking_at(avant.normalized() if avant.length() > 0.01 else Vector3.FORWARD, Vector3.UP)
	b = b * Basis(Vector3.FORWARD, penche)
	var t := Transform3D(b, p)
	multimesh.set_instance_transform(i, t)
	multimesh.set_instance_custom_data(i, Color(o["phase"], o["bat"], o["teinte"], 0))


func _crier() -> void:
	if _oiseaux.is_empty():
		return
	var flux := _charger_son("res://audio/ambiances/%s_%d.ogg" % [_fiche["cri"], _hasard.randi_range(1, 3)])
	if flux == null:
		return
	var o := _oiseaux[_hasard.randi() % _oiseaux.size()]
	_cri.position = multimesh.get_instance_transform(_oiseaux.find(o)).origin
	_cri.stream = flux
	_cri.pitch_scale = _hasard.randf_range(0.9, 1.1)
	_cri.play()


static func _charger_son(chemin: String) -> AudioStream:
	return load(chemin) as AudioStream if ResourceLoader.exists(chemin) else null


## Maillage d'oiseau vu de loin : corps fuselé, ailes effilées, queue. Le dessus
## regarde +Y, l'avant -Z. Couleur rouge des sommets = bouts des ailes (plus foncés).
## long_cou : cou et pattes tendus (ibis, hérons, oies, cygnes).
static func maillage_oiseau(envergure: float, long_cou := false) -> ArrayMesh:
	var e := envergure * 0.5
	var corps := envergure * (0.42 if long_cou else 0.34)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, bout := Vector3.ZERO) -> void:
		var n := (b - a).cross(c - a).normalized()
		if n.y < 0.0:
			var tmp := b
			b = c
			c = tmp
			bout = Vector3(bout.x, bout.z, bout.y)
			n = -n
		st.set_normal(n)
		st.set_color(Color(bout.x, 0, 0))
		st.add_vertex(a)
		st.set_color(Color(bout.y, 0, 0))
		st.add_vertex(b)
		st.set_color(Color(bout.z, 0, 0))
		st.add_vertex(c)
	for cote: float in [1.0, -1.0]:
		# Aile : bord d'attaque légèrement en avant, pointe effilée vers l'arrière.
		var racine_av := Vector3(0.03 * cote, 0, -corps * 0.12)
		var racine_ar := Vector3(0.03 * cote, 0, corps * 0.22)
		var coude := Vector3(e * 0.5 * cote, 0.01, -corps * 0.1)
		var coude_ar := Vector3(e * 0.48 * cote, 0.01, corps * 0.26)
		var pointe := Vector3(e * cote, 0.0, corps * 0.22)
		tri.call(racine_av, coude, racine_ar)
		tri.call(racine_ar, coude, coude_ar)
		tri.call(coude, pointe, coude_ar, Vector3(0.3, 1.0, 0.3))
		# Corps (deux pans en toit pour avoir un peu de volume).
		var nez := Vector3(0, 0, -corps * (0.9 if long_cou else 0.5))
		var dos := Vector3(0, 0.035 * envergure, 0)
		var croupion := Vector3(0, 0, corps * 0.45)
		var flanc := Vector3(0.045 * envergure * cote, 0, 0)
		tri.call(nez, dos, flanc)
		tri.call(dos, croupion, flanc)
		var ventre := Vector3(0, -0.03 * envergure, 0)
		tri.call(nez, flanc, ventre)
		tri.call(ventre, flanc, croupion)
		# Queue en éventail.
		tri.call(croupion, Vector3(0.07 * envergure * cote, 0, corps * 0.75), Vector3(0, 0, corps * 0.8))
		if long_cou:
			# Pattes tendues derrière.
			tri.call(croupion, Vector3(0.01 * cote, -0.01, corps * 1.15), Vector3(0.0, 0.0, corps * 1.1))
	return st.commit()
