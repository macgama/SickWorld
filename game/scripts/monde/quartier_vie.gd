extends RefCounted
## Petits détails de vie de Hikari Bay : volées de pigeons (voir volee_pigeons.gd)
## et bouches d'égout qui fument. Décrits dans data/hub_vie.json.

const DONNEES := "res://data/hub_vie.json"
const Volee := preload("res://scripts/monde/volee_pigeons.gd")
const Marche := preload("res://scripts/monde/quartier_marche.gd")


static func construire(hub: HikariBay) -> void:
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if not lu is Dictionary:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
		return
	var fonte := StandardMaterial3D.new()
	fonte.albedo_color = Color(0.09, 0.09, 0.1)
	fonte.metallic = 0.6
	fonte.roughness = 0.45
	for xz: Array in lu.get("plaques", []):
		var p := Vector3(float(xz[0]), 0.0, float(xz[1]))
		hub._cylindre(0.42, 0.42, 0.025, p + Vector3(0, 0.012, 0), fonte, false)
		Marche._vapeur(hub, p + Vector3(0, 0.08, 0))
	# Les pigeons ne vivent qu'en jeu (dans l'éditeur, le décor reste immobile).
	if Engine.is_editor_hint():
		return
	var dossier := Node3D.new()
	dossier.name = "Pigeons"
	hub._contenu.add_child(dossier)
	var n := 0
	for fiche: Dictionary in lu.get("pigeons", []):
		var v := Node3D.new()
		v.set_script(Volee)
		v.name = "Volee%d" % n
		v.sol = _vec3(fiche.get("sol", [0, 0, 0]))
		v.perchoir = _vec3(fiche.get("perchoir", [0, 1, 0]))
		var e: Array = fiche.get("etendue", [1, 0])
		v.etendue_perchoir = Vector3(float(e[0]), 0, float(e[1]))
		v.nombre = int(fiche.get("nombre", 7))
		dossier.add_child(v)
		n += 1


static func _vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
