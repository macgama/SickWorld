extends SceneTree
## Captures du chien errant, du molosse et du poulpe du Pirée, et du lion de Rome (vrais modèles),
## dans un petit studio : à l'arrêt, au pas, à la course, en mordant, et morts.
## Lancement (fenêtre visible, pas en --headless) :
##   godot --path game -s res://tests/capture_animaux_grece.gd -- dossier [chien|molosse|poulpe|lion]...

const ApparenceLoup := preload("res://scripts/ennemis/apparence_loup.gd")

var _porteur_script: GDScript


func _initialize() -> void:
	_lancer.call_deferred()


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


## Un faux ennemi : apparence_loup.gd lit seulement « type_ennemi » sur son parent.
func _porteur(type: String) -> Node3D:
	if _porteur_script == null:
		_porteur_script = GDScript.new()
		_porteur_script.source_code = "extends Node3D\nvar type_ennemi := \"\"\n"
		_porteur_script.reload()
	var n := Node3D.new()
	n.set_script(_porteur_script)
	n.set("type_ennemi", type)
	return n


func _studio(eau: bool) -> Node3D:
	var s := Node3D.new()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.82)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	s.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 35, 0)
	soleil.light_energy = 1.4
	soleil.shadow_enabled = true
	s.add_child(soleil)
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(40, 40)
	sol.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.64, 0.5) if not eau else Color(0.62, 0.58, 0.5)
	sol.material_override = m
	sol.position.y = -0.3 if eau else 0.0
	s.add_child(sol)
	if eau:
		var mer := MeshInstance3D.new()
		var p2 := PlaneMesh.new()
		p2.size = Vector2(40, 40)
		mer.mesh = p2
		var me := StandardMaterial3D.new()
		me.albedo_color = Color(0.15, 0.45, 0.55, 0.55)
		me.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		me.roughness = 0.1
		mer.material_override = me
		mer.position.y = 0.05
		s.add_child(mer)
	return s


func _capturer(type: String, dossier: String, prefixe: String, eau := false, recul := 1.0) -> void:
	var studio := _studio(eau)
	root.add_child(studio)
	var porteur := _porteur(type)
	studio.add_child(porteur)
	var apparence := Node3D.new()
	apparence.set_script(ApparenceLoup)
	apparence.name = "Apparence"
	porteur.add_child(apparence)
	var camera := Camera3D.new()
	camera.fov = 50.0
	studio.add_child(camera)
	camera.make_current()
	await _attendre(5)
	# [nom, vitesse, morsure, mort, position de la caméra]
	var etats := [
		["repos", 0.0, false, false, Vector3(3.2, 1.2, -1.2)],
		["profil", 0.0, false, false, Vector3(3.6, 0.9, 0.0)],
		["pas", 2.0, false, false, Vector3(3.6, 0.9, 0.0)],
		["course", 7.0, false, false, Vector3(3.6, 0.9, 0.0)],
		["morsure", 0.0, true, false, Vector3(2.4, 1.0, -2.4)],
		["mort", 0.0, false, true, Vector3(3.0, 1.6, -1.5)],
	]
	for etat in etats:
		var frames := 50
		for i in frames:
			if etat[2] and i == frames - 9:
				apparence.mordre()
			apparence.animer(1.0 / 60.0, float(etat[1]), bool(etat[3]))
			await process_frame
		camera.global_position = (etat[4] as Vector3) * recul
		camera.look_at(Vector3(0, 0.45 * recul, 0))
		await _attendre(2)
		var sortie := dossier.path_join("%s_%s.jpg" % [prefixe, etat[0]])
		root.get_texture().get_image().save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	studio.queue_free()
	await _attendre(3)


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(960, 540)
	var choix := args.slice(1)
	if choix.is_empty() or "chien" in choix:
		await _capturer("chien_fracture", dossier, "chien", false, 0.45)
	if choix.is_empty() or "molosse" in choix:
		await _capturer("molosse_fracture", dossier, "molosse", false, 1.4)
	if choix.is_empty() or "poulpe" in choix:
		await _capturer("poulpe_fracture", dossier, "poulpe", true, 2.6)
	if "lion" in choix:
		# Le lion de l'île de Rome (même studio).
		await _capturer("lion_fracture", dossier, "lion", false, 1.5)
	quit()
