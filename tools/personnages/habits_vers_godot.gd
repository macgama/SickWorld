extends SceneTree
## Convertit les habits d'époque (JSON produits par habits_epoque.py) en maillages Godot.
##
## Lancement, depuis la racine du dépôt :
##   godot --headless --path game -s ../tools/personnages/habits_vers_godot.gd
## Entrée : tools/personnages/habits_json/<habit>_<sexe>.json
## Sortie : game/assets/personnages/vetements/<sexe>/<habit>.res (ArrayMesh binaire,
## hors Git LFS). Chaque surface s'appelle « matière:rôle » (peau:peau, lin:principal,
## laine:drape, corde:ceinture…) ; la liste des os est rangée dans la méta « os ».

const ENTREE := "res://../tools/personnages/habits_json/"
const SORTIE := "res://assets/personnages/vetements/"


func _init() -> void:
	var dossier := ProjectSettings.globalize_path("res://").path_join("../tools/personnages/habits_json")
	var d := DirAccess.open(dossier)
	if d == null:
		push_error("Dossier introuvable : " + dossier)
		quit(1)
		return
	var n := 0
	for fichier in d.get_files():
		if not fichier.ends_with(".json"):
			continue
		var donnees = JSON.parse_string(FileAccess.get_file_as_string(dossier.path_join(fichier)))
		if not donnees is Dictionary:
			push_error("JSON illisible : " + fichier)
			continue
		var mesh := convertir(donnees)
		var sortie: String = SORTIE + String(donnees["sexe"]) + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
		var chemin: String = sortie + String(donnees["nom"]) + ".res"
		var err := ResourceSaver.save(mesh, chemin, ResourceSaver.FLAG_COMPRESS)
		print("%s → %s (%d surfaces) %s" % [fichier, chemin, mesh.get_surface_count(), "ok" if err == OK else "ERREUR %d" % err])
		n += 1
	print("%d habits convertis" % n)
	quit()


static func convertir(donnees: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s: Dictionary in donnees["surfaces"]:
		var p: Array = s["p"]
		var nrm: Array = s["n"]
		var uv: Array = s["uv"]
		var os: Array = s["os"]
		var poids: Array = s["poids"]
		var f: Array = s["f"]
		var nb := p.size() / 3
		var sommets := PackedVector3Array()
		var normales := PackedVector3Array()
		var uvs := PackedVector2Array()
		var b := PackedInt32Array()
		var w := PackedFloat32Array()
		sommets.resize(nb)
		normales.resize(nb)
		uvs.resize(nb)
		for i in nb:
			sommets[i] = Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2])
			normales[i] = Vector3(nrm[3 * i], nrm[3 * i + 1], nrm[3 * i + 2])
			uvs[i] = Vector2(uv[2 * i], uv[2 * i + 1])
		for v in os:
			b.append(int(v))
		for v in poids:
			w.append(float(v))
		var indices := PackedInt32Array()
		for v in f:
			indices.append(int(v))
		var tableaux := []
		tableaux.resize(Mesh.ARRAY_MAX)
		tableaux[Mesh.ARRAY_VERTEX] = sommets
		tableaux[Mesh.ARRAY_NORMAL] = normales
		tableaux[Mesh.ARRAY_TEX_UV] = uvs
		tableaux[Mesh.ARRAY_BONES] = b
		tableaux[Mesh.ARRAY_WEIGHTS] = w
		tableaux[Mesh.ARRAY_INDEX] = indices
		# Tangentes (pour les cartes de relief du tissu).
		var st := SurfaceTool.new()
		st.create_from_arrays(tableaux)
		st.generate_tangents()
		var arr := st.commit_to_arrays()
		arr[Mesh.ARRAY_BONES] = b
		arr[Mesh.ARRAY_WEIGHTS] = w
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "%s:%s" % [s["matiere"], s["role"]])
	mesh.set_meta("os", PackedStringArray(donnees["os"]))
	mesh.set_meta("description", String(donnees.get("description", "")))
	return mesh
