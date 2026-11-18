extends SceneTree
## Fabrique les images des affiches (data/affiches.json) avec les scripts de capture
## de chaque zone : pour chaque image, « source » = « zone:vue » veut dire « la vue
## <vue> de tests/capture_<zone>.gd ». Chaque script est lancé une fois (fenêtre
## visible, pas en --headless), puis les images sont copiées dans game/images/affiches/.
## Lancement : godot --path game -s res://tests/capture_affiches.gd -- [zone1,zone2…]
## (sans argument : toutes les zones).

const DONNEES := "res://data/affiches.json"
const SORTIE := "res://images/affiches"


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var seulement := PackedStringArray()
	if args.size() > 0:
		seulement = args[0].split(",")
	var d = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	# zone -> [[vue, fichier de sortie], …]
	var par_zone := {}
	for id in d["affiches"]:
		for image in d["affiches"][id].get("images", []):
			var source := String(image.get("source", ""))
			if not ":" in source:
				continue
			var zone := source.get_slice(":", 0)
			if not seulement.is_empty() and not seulement.has(zone):
				continue
			if not par_zone.has(zone):
				par_zone[zone] = []
			par_zone[zone].append([source.get_slice(":", 1), String(image["fichier"])])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))
	# Images sans interface (mini-carte, titres…) : voir Options._process.
	OS.set_environment("SICKWORLD_SANS_INTERFACE", "1")
	var projet := ProjectSettings.globalize_path("res://")
	var manquantes := PackedStringArray()
	for zone in par_zone:
		var tmp := ProjectSettings.globalize_path("user://capture_affiches/" + zone)
		DirAccess.make_dir_recursive_absolute(tmp)
		for ancien in DirAccess.get_files_at(tmp):
			DirAccess.remove_absolute(tmp.path_join(ancien))
		var vues := PackedStringArray()
		for v in par_zone[zone]:
			vues.append(v[0])
		print("== ", zone, " : ", ", ".join(vues))
		var sortie := []
		# Arguments de chaque script : capture_hub veut la qualité avant les vues,
		# capture_grotte une vue par argument ; les autres « vue1,vue2 ».
		var arguments := ["--path", projet, "-s", "res://tests/capture_%s.gd" % zone, "--", tmp]
		match zone:
			"hub":
				arguments.append_array(["-", ",".join(vues)])
			"grotte":
				arguments.append_array(vues)
			_:
				arguments.append(",".join(vues))
		OS.execute(OS.get_executable_path(), arguments, sortie, true)
		var fichiers := DirAccess.get_files_at(tmp)
		for v in par_zone[zone]:
			var trouve := ""
			for f in fichiers:
				var nom := f.get_basename()
				if f.get_extension() == "jpg" and (nom == v[0] or nom.ends_with("_" + v[0])):
					trouve = tmp.path_join(f)
			if trouve == "":
				manquantes.append(zone + ":" + v[0])
				continue
			var img := Image.load_from_file(trouve)
			img.save_jpg(ProjectSettings.globalize_path(String(v[1])), 0.9)
			print("   ", v[0], " -> ", v[1])
	if not manquantes.is_empty():
		print("Vues introuvables : ", ", ".join(manquantes))
	print("Fini.")
	quit()
