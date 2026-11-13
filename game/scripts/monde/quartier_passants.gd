extends RefCounted
## Les passants de Hikari Bay (voir passant.gd et data/hub_passants.json).
## Seulement en jeu : dans l'éditeur, la ville reste vide pour bien voir le décor.

const DONNEES := "res://data/hub_passants.json"
const Passant := preload("res://scripts/monde/passant.gd")


static func construire(hub: HikariBay) -> void:
	if Engine.is_editor_hint():
		return
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if not lu is Dictionary:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
		return
	var dossier := Node3D.new()
	dossier.name = "Passants"
	hub._contenu.add_child(dossier)
	var couleurs: Array = lu.get("parapluies", [])
	var n := 0
	for fiche: Dictionary in lu.get("passants", []):
		var p := Node3D.new()
		p.set_script(Passant)
		p.name = "Passant%d" % n
		p.modele = fiche.get("modele", "homme")
		p.vitesse = float(fiche.get("vitesse", 2.4))
		p.taille_cm = float(fiche.get("taille", 175.0 if p.modele == "homme" else 165.0))
		p.orientation = deg_to_rad(float(fiche.get("regarde", 0.0)))
		var points := PackedVector3Array()
		for xz: Array in fiche.get("chemin", []):
			points.append(Vector3(float(xz[0]), 0.0, float(xz[1])))
		p.chemin = points
		var parapluie = fiche.get("parapluie", -1)
		if parapluie is float and int(parapluie) >= 0 and couleurs.size() > 0:
			p.parapluie = Color(String(couleurs[int(parapluie) % couleurs.size()]))
		var peaux := [Color(0.85, 0.68, 0.55), Color(0.72, 0.55, 0.42), Color(0.55, 0.38, 0.28), Color(0.9, 0.75, 0.62)]
		p.peau = peaux[n % peaux.size()]
		dossier.add_child(p)
		n += 1
