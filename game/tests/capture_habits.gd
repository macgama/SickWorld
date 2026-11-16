extends SceneTree
## Planche des habits d'époque (fenêtre visible, pas en --headless).
## Lancement :
##   godot --path game -s res://tests/capture_habits.gd -- <sortie.jpg> [animation] [instant] [habit:sexe ...]
## animation : immobile (défaut), marcher, assis, creuser, a_genoux… ; instant en secondes.
## Sans liste d'habits : tous les habits de assets/personnages/vetements/.

const HabitEpoque := preload("res://scripts/personnage/habit_epoque.gd")
const COULEURS := {
	"chiton_court": {"principal": Color("#e4dac4")}, "exomis": {"principal": Color("#a8916c")},
	"chiton_himation": {"principal": Color("#ece4d2"), "drape": Color("#3a4a6a")},
	"peplos": {"principal": Color("#8a4a3a")}, "peplos_himation": {"principal": Color("#4a5a7a"), "drape": Color("#d8ccb0")},
	"scythe": {"principal": Color("#8a3a2a"), "drape": Color("#3a4a6a")},
	"shendyt": {"principal": Color("#efe8d6")}, "shendyt_court": {"principal": Color("#ddd2b8")},
	"shendyt_long": {"principal": Color("#f4efe2")}, "kalasiris": {"principal": Color("#f2ecdc")},
	"robe_nomade": {"principal": Color("#6a5442"), "ceinture": Color("#a83a2e")},
	"peaux": {"principal": Color("#c8a07a")}, "peaux_femme": {"principal": Color("#d0aa84")},
}
const PEAU := {"shendyt": "#8f5f3e", "shendyt_court": "#87583a", "shendyt_long": "#94633f", "kalasiris": "#9b6a46",
	"robe_nomade": "#7a4f33", "peaux": "#b08260", "peaux_femme": "#b88a66"}


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var sortie: String = args[0] if args.size() > 0 else "/tmp/habits.jpg"
	var anim: String = args[1] if args.size() > 1 else "immobile"
	var instant := float(args[2]) if args.size() > 2 else 0.4
	var liste: Array = args.slice(3)
	if liste.is_empty():
		for sexe in ["homme", "femme"]:
			for f in DirAccess.get_files_at(HabitEpoque.DOSSIER + sexe):
				if f.ends_with(".res"):
					liste.append(f.get_basename() + ":" + sexe)
	root.size = Vector2i(maxi(900, 300 * liste.size()), 720)
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.45, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-42, -35, 0)
	soleil.light_energy = 1.25
	soleil.shadow_enabled = true
	monde.add_child(soleil)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	sol.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.55, 0.5, 0.42)
	sol.material_override = ms
	monde.add_child(sol)
	var largeur := 1.1
	for k in liste.size():
		var habit := String(liste[k]).get_slice(":", 0)
		var sexe := String(liste[k]).get_slice(":", 1)
		var a = (load("res://scenes/joueur/apparence_agent.tscn") as PackedScene).instantiate()
		a.set("modele", sexe)
		monde.add_child(a)
		a.position = Vector3((k - (liste.size() - 1) * 0.5) * largeur, 0, 0)
		a.rotation.y = PI  # face à la caméra (le jeu regarde vers -Z)
		a.appliquer({"sexe": sexe, "taille_cm": 172.0 if sexe == "homme" else 162.0,
				"peau": Color(PEAU.get(habit, "#b98c66"))})
		var ok: bool = a.porter_habit(habit, COULEURS.get(habit, {}))
		print(habit, " ", sexe, " → ", ok)
	await _attendre(3)
	for a in monde.get_children():
		if a.has_method("porter_habit"):
			a._jouer(anim, 0.0)
			a._lecteur.seek(instant, true)
			a._lecteur.speed_scale = 0.0
	var cam := Camera3D.new()
	monde.add_child(cam)
	cam.position = Vector3(0, 1.3 if liste.size() < 2 else 1.0, 0.9 + liste.size() * 0.75)
	cam.fov = 40
	cam.look_at(Vector3(0, 0.9, 0))
	cam.make_current()
	await _attendre(30)
	root.get_texture().get_image().save_jpg(sortie, 0.88)
	print("Capture : ", sortie)
	quit()
