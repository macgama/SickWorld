extends SceneTree
## Capture du menu avec le panneau de compte (hors ligne, puis formulaire de création).
## godot --path game --rendering-driver opengl3 -s res://tests/capture_menu_compte.gd -- <dossier>

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	change_scene_to_file("res://scenes/interface/menu.tscn")
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_jpg(dossier + "/menu-compte.jpg", 0.9)
	var panneau = _trouver(root)
	if panneau != null:
		panneau._changer_mode(true)
		for i in 10:
			await process_frame
		root.get_viewport().get_texture().get_image().save_jpg(dossier + "/menu-compte-creation.jpg", 0.9)
	quit()


func _trouver(n: Node):
	if n.get_script() != null and String(n.get_script().resource_path).ends_with("panneau_compte.gd"):
		return n
	for e in n.get_children():
		var r = _trouver(e)
		if r != null:
			return r
	return null
