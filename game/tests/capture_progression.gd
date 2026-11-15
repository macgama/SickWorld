extends SceneTree
## Captures de la progression (fenêtre visible, pas en --headless) :
## un personnage niveau 12 avec des talents, la fenêtre Talents ou Titres, la barre d'XP.
## Lancement : godot --path game -s res://tests/capture_progression.gd -- [talents|titres|niveau] [chemin.jpg] [classe]

const TALENTS := {
	"lame": ["lame_affutee", "lame_affutee", "lame_affutee", "taille_eclair", "taille_eclair", "taille_eclair",
		"tourbillon_acier", "tourbillon_acier", "oeil_du_bretteur", "oeil_du_bretteur", "peau_tannee"],
	"tisseur": ["mains_apaisantes", "mains_apaisantes", "mains_apaisantes", "tissage_rapide", "tissage_rapide",
		"tissage_rapide", "flux_econome", "flux_econome", "second_fil", "constance", "constance"],
}


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var vue := args[0] if args.size() > 0 else "talents"
	var sortie := args[1] if args.size() > 1 else "/tmp/progression.jpg"
	var classe := args[2] if args.size() > 2 else "lame"
	root.size = Vector2i(1600, 900)
	root.get_node("Reseau").nom_joueur = "Capture"
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/progression/capture.json"))
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/capture.json"))
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	var joueur = get_first_node_in_group("joueur_local")
	if classe != "lame":
		var fiche: Dictionary = joueur.get_node("Fiche").donnees.duplicate(true)
		fiche["classe"] = classe
		joueur.get_node("Fiche").donnees = fiche
		await _attendre(5)
	var prog = joueur.get_node("Progression")
	var d := Progression.donnees()
	prog.etat["xp"] = Progression.xp_total_pour(d, 12) + 1650
	for f in ["etape:prehistoire:vers_le_camp", "etape:prehistoire:fresque_finale", "secondaire:main_sur_la_paroi",
			"etape:egypte:fin_chapitre_1"]:
		prog.etat["faits"].append(f)
	prog.etat["tues"]["loup_fracture"] = 41
	Progression.nouveaux_titres(d, prog.etat, {})
	prog.etat["titre"] = "gardien_des_murs"
	for t in TALENTS.get(classe, []):
		Progression.prendre_talent(d, classe, prog.etat, t)
	prog._appliquer()
	await _attendre(10)
	var hud: Node = null
	for n in scene.find_children("*", "CanvasLayer", true, false):
		if n.has_method("basculer_talents"):
			hud = n
	var rig = joueur.get_node("CameraRig")
	rig.retour_automatique = 0.0
	rig.lacet = deg_to_rad(160.0)
	await _attendre(40)
	match vue:
		"talents":
			hud._fenetre_progression.montrer_onglet(0)
		"titres":
			hud._fenetre_progression.montrer_onglet(1)
		"niveau":
			hud._sur_xp_gagnee(240, "Quête")
			hud._sur_niveau_gagne(12)
	await _attendre(3 if vue == "niveau" else 50)
	var image := root.get_texture().get_image()
	image.save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/progression/capture.json"))
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/capture.json"))
	quit()
