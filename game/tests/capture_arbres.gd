extends SceneTree
## Planche de toutes les essences d'arbres réalistes (scripts/monde/vegetation/arbres.gd).
## Lancement : godot --path game -s res://tests/capture_arbres.gd -- [dossier_sortie] [essence1,essence2…]

const Arbres := preload("res://scripts/monde/vegetation/arbres.gd")


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	var essences: Array = Arbres.ESSENCES.keys()
	if args.size() > 1:
		essences = args[1].split(",")
	root.size = Vector2i(1600, 900)
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var ciel := ProceduralSkyMaterial.new()
	e.sky = Sky.new()
	e.sky.sky_material = ciel
	e.background_mode = Environment.BG_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ssao_enabled = true
	env.environment = e
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-38, -35, 0)
	soleil.shadow_enabled = true
	soleil.light_energy = 1.3
	monde.add_child(soleil)
	var sol := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(400, 400)
	sol.mesh = p
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.32, 0.3, 0.22)
	sol.material_override = ms
	monde.add_child(sol)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 4
	var camera := Camera3D.new()
	camera.fov = 55
	monde.add_child(camera)
	camera.make_current()
	for essence in essences:
		for n in monde.get_children():
			if n is MeshInstance3D and n != sol:
				n.free()
		for k in 3:
			var pas := 3.0 if essence in ["papyrus", "buisson", "buisson_sec", "buisson_hiver"] else 9.0
			Arbres.planter(monde, Vector3((k - 1) * pas, 0, -k * pas / 3.0), essence, hasard, 1.0, null, false)
		var haut: float = 6.0 if essence in ["olivier", "tamaris", "murier", "peuplier_desert", "saule"] else 10.0
		var ecart := 3.0
		if essence in ["papyrus", "buisson", "buisson_sec", "buisson_hiver"]:
			haut = 2.5
			ecart = 1.2
		camera.position = Vector3(0, haut * 0.45, ecart * (4.3 + haut * 0.4))
		camera.look_at(Vector3(0, haut * 0.5, -ecart))
		for i in 6:
			await process_frame
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("arbre_%s.jpg" % essence)
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
