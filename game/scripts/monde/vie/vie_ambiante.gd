extends Node3D
## La vie ambiante d'une zone : oiseaux dans le ciel, insectes et poussière dans l'air,
## figurants qui vaquent à leurs occupations, petits objets semés sur le sol.
## Tout est décrit dans data/vie_ambiante.json, une section par zone (même nom que
## identifiant_zone de la zone, ex. « steppe », « port_des_marais »). Gaël peut ajouter
## un oiseau ou un villageois en recopiant une ligne, sans toucher au code.
##
## Rien n'est créé dans l'éditeur ni sur le serveur (purement visuel). Réglages :
## l'option F10 « Qualité » réduit le nombre d'objets semés et d'insectes en Bas.

const DONNEES := "res://data/vie_ambiante.json"
const Volee := preload("res://scripts/monde/vie/volee_ciel.gd")
const Insectes := preload("res://scripts/monde/vie/insectes.gd")
const Figurant := preload("res://scripts/monde/vie/figurant.gd")
const Disperser := preload("res://scripts/monde/vie/disperser.gd")
const VieHub := preload("res://scripts/monde/vie/vie_hub.gd")

var ile: Node3D
var section := ""
## Nombre d'objets semés (pour les tests).
var objets_semes := 0

static var _donnees := {}


static func donnees() -> Dictionary:
	if _donnees.is_empty():
		var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
		if lu is Dictionary:
			_donnees = lu
		else:
			push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	return _donnees


## Ajoute la vie ambiante de la zone `nom` à `zone` (une île ou le hub). Ne fait rien
## dans l'éditeur, sur un serveur dédié, ou si la zone n'a pas de section.
static func installer(zone: Node3D, nom: String) -> Node3D:
	if Engine.is_editor_hint() or "--serveur" in OS.get_cmdline_user_args() or "--sans-vie" in OS.get_cmdline_user_args():
		return null
	if not donnees().has(nom):
		return null
	var ancien := zone.get_node_or_null("VieAmbiante")
	if ancien != null:
		ancien.free()
	var v := new()
	v.name = "VieAmbiante"
	v.ile = zone
	v.section = nom
	zone.add_child(v)
	return v


func _ready() -> void:
	# Le sol doit exister côté physique avant de semer : on attend deux images.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var fiche: Dictionary = donnees().get(section, {})
	var qualite := _facteur_qualite()
	_semer(fiche.get("disperser", []), qualite)
	_oiseaux(fiche.get("oiseaux", []))
	_insectes(fiche.get("insectes", []), qualite)
	_figurants(fiche.get("figurants", []))
	if fiche.has("bateaux") or fiche.has("pont") or fiche.has("avions") or fiche.has("objets"):
		var ville := Node3D.new()
		ville.set_script(VieHub)
		ville.name = "Ville"
		ville.hub = ile
		ville.fiche = fiche
		add_child(ville)


func _facteur_qualite() -> float:
	var q := get_node_or_null("/root/QualiteGraphique")
	if q == null:
		return 1.0
	var niveau = q.get("niveau")
	if niveau is int:
		return [0.45, 0.75, 1.0, 1.0][clampi(niveau, 0, 3)]
	return 1.0


func _semer(liste: Array, qualite: float) -> void:
	var dossier := Node3D.new()
	dossier.name = "Seme"
	add_child(dossier)
	var n := 0
	for f: Dictionary in liste:
		var fiche := f.duplicate()
		fiche["nombre"] = int(float(fiche.get("nombre", 100)) * qualite)
		objets_semes += Disperser.semer(ile, dossier, fiche, hash(section) + n * 7919)
		n += 1


func _oiseaux(liste: Array) -> void:
	var n := 0
	for f: Dictionary in liste:
		var v := MultiMeshInstance3D.new()
		v.set_script(Volee)
		v.name = "Oiseaux_%s_%d" % [f.get("espece", "corbeau"), n]
		v.espece = String(f.get("espece", "corbeau"))
		v.comportement = String(f.get("comportement", "cercle"))
		var c: Array = f.get("centre", [0, 0])
		var y := float(f.get("altitude", 30.0))
		if ile.has_method("hauteur") and not f.get("altitude_absolue", false):
			y += ile.hauteur(float(c[0]), float(c[1]))
		v.centre = Vector3(float(c[0]), y, float(c[1]))
		v.rayon = float(f.get("rayon", 40.0))
		v.nombre = int(f.get("nombre", 8))
		v.ecart_altitude = float(f.get("ecart_altitude", 8.0))
		v.direction_deg = float(f.get("direction", 30.0))
		v.pause_formation = float(f.get("pause", 25.0))
		v.graine = hash(section) + n
		add_child(v)
		n += 1


func _insectes(liste: Array, qualite: float) -> void:
	for f: Dictionary in liste:
		var i := GPUParticles3D.new()
		i.set_script(Insectes)
		i.sorte = String(f.get("sorte", "moucherons"))
		i.autour = bool(f.get("autour", false))
		if f.has("nombre"):
			i.nombre_voulu = maxi(1, int(float(f["nombre"]) * qualite))
		if f.has("rayon"):
			i.rayon_voulu = float(f["rayon"])
		i.vent_deg = float(f.get("vent", 60.0))
		if f.has("position"):
			var p: Array = f["position"]
			var y := float(p[2]) if p.size() > 2 else 1.0
			if ile.has_method("hauteur"):
				y += ile.hauteur(float(p[0]), float(p[1]))
			i.position = Vector3(float(p[0]), y, float(p[1]))
		add_child(i)


func _figurants(liste: Array) -> void:
	var pnj: Dictionary = {}
	var script_pnj := load("res://scripts/monde/prehistoire/pnj_epoque.gd")
	if script_pnj != null:
		pnj = script_pnj.donnees_epoque()
	var modeles: Dictionary = donnees().get("modeles_figurants", {})
	var n := 0
	for f: Dictionary in liste:
		var g := Node3D.new()
		g.set_script(Figurant)
		g.name = "Figurant%d" % n
		# L'apparence vient d'un modèle commun (modeles_figurants), d'un personnage
		# connu (data/<île>_pnj.json) ou de la fiche elle-même.
		var apparence: Dictionary = {}
		var modele = f.get("comme", "")
		if modeles.has(modele):
			apparence = (modeles[modele] as Dictionary).duplicate()
		elif pnj.has(modele):
			apparence = (pnj[modele] as Dictionary).duplicate()
		for cle in ["modele", "taille_cm", "peau", "habits", "tenue"]:
			if f.has(cle):
				apparence[cle] = f[cle]
		# Petites variations pour que deux figurants du même modèle ne soient pas jumeaux.
		if apparence.has("taille_cm"):
			apparence["taille_cm"] = float(apparence["taille_cm"]) + float((n * 37) % 9) - 4.0
		g.fiche = apparence
		var points := PackedVector2Array()
		for xz: Array in f.get("chemin", []):
			points.append(Vector2(float(xz[0]), float(xz[1])))
		g.chemin = points
		g.boucle = bool(f.get("boucle", false))
		g.vitesse = float(f.get("vitesse", 1.3))
		var p: Array = f.get("pause", [3.0, 9.0])
		g.pause = Vector2(float(p[0]), float(p[1]))
		g.arrets = f.get("arrets", [])
		g.geste = String(f.get("geste", ""))
		g.porte = String(f.get("porte", ""))
		if f.has("regarde"):
			g.regarde = float(f["regarde"])
		if f.has("parapluie"):
			g.parapluie = Color.from_string(String(f["parapluie"]), Color(0.1, 0.1, 0.12))
		g.ile = ile
		add_child(g)
		n += 1
