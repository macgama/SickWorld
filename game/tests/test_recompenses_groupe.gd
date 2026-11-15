extends SceneTree
## Test des récompenses en multijoueur : chaque joueur reçoit SES récompenses de quête,
## même quand il n'est pas l'hôte (ici : un client d'un serveur dédié).
## À lancer comme CLIENT pendant qu'un serveur dédié tourne (on peut lancer deux
## clients en même temps, avec deux noms, pour un « groupe ») :
##   godot --headless --path game -- --serveur --colline --port=7791
##   godot --headless --path game -s res://tests/test_recompenses_groupe.gd -- --port=7791 --nom=Alice
##   godot --headless --path game -s res://tests/test_recompenses_groupe.gd -- --port=7791 --nom=Bruno
## Le test demande au serveur les récompenses d'une étape de la quête principale, d'une
## quête secondaire, d'un événement, d'une mission du hub et d'une mission du jour, puis
## vérifie : objets dans NOS sacs, XP gagnée, rien en double, et les demandes truquées refusées.

const _Artisanat := preload("res://scripts/objets/artisanat.gd")

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _secondes(s: float) -> void:
	await create_timer(s).timeout


func _initialize() -> void:
	_lancer.call_deferred()


func _combien(inv, id: String) -> int:
	return _Artisanat.compter(inv.etat, id)


## Attend (au plus 3 s) que la condition devienne vraie.
func _attendre(condition: Callable) -> void:
	for i in 30:
		if condition.call():
			return
		await _secondes(0.1)


func _lancer() -> void:
	var reseau = root.get_node("Reseau")
	reseau.mode = reseau.Mode.REJOINDRE
	reseau.adresse = "127.0.0.1"
	var nom: String = reseau.nom_joueur
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene

	print("Test des récompenses en groupe (%s)" % nom)
	var joueur = null
	for i in 60:
		await _secondes(0.2)
		joueur = get_first_node_in_group("joueur_local")
		if joueur != null:
			break
	_verifier(joueur != null, "le serveur a créé notre personnage")
	if joueur == null:
		quit(1)
		return
	await _secondes(1.5)
	_verifier(not root.multiplayer.is_server(), "on est un client, pas l'hôte")
	var inv = joueur.get_node("Inventaire")
	var prog = joueur.get_node("Progression")
	await _attendre(func(): return not inv.etat.is_empty() and prog.etat.has("xp"))
	_verifier(not inv.etat.is_empty() and prog.etat.has("xp"), "le serveur nous envoie nos sacs et notre progression")

	# 1. Étape de la quête principale avec un objet (Toran donne sa lance).
	var lances := _combien(inv, "lance_silex")
	var xp := int(prog.etat["xp"])
	prog.etape_faite("prehistoire", {"id": "toran_confiance"})
	await _attendre(func(): return _combien(inv, "lance_silex") > lances)
	_verifier(_combien(inv, "lance_silex") == lances + 1, "quête principale : la lance de silex arrive dans NOS sacs")
	_verifier(int(prog.etat["xp"]) > xp, "quête principale : on gagne l'XP de l'étape (%d → %d)" % [xp, int(prog.etat["xp"])])
	prog.etape_faite("prehistoire", {"id": "toran_confiance"})
	await _secondes(1.0)
	_verifier(_combien(inv, "lance_silex") == lances + 1, "quête principale : la même étape ne rapporte pas deux fois")

	# 2. Quête secondaire « Le premier collier » (3 étapes ; la dernière donne le collier).
	var colliers := _combien(inv, "collier_du_clan")
	xp = int(prog.etat["xp"])
	prog.secondaire_faite("prehistoire", "premier_collier", 0, false)
	await _attendre(func(): return int(prog.etat["xp"]) > xp)
	_verifier(int(prog.etat["xp"]) > xp, "quête secondaire : une étape rapporte de l'XP")
	_verifier(_combien(inv, "collier_du_clan") == colliers, "quête secondaire : pas d'objet avant la fin")
	prog.secondaire_faite("prehistoire", "premier_collier", 2, true)
	await _attendre(func(): return _combien(inv, "collier_du_clan") > colliers)
	_verifier(_combien(inv, "collier_du_clan") == colliers + 1, "quête secondaire : le collier du clan arrive dans NOS sacs")
	_verifier("secondaire:premier_collier" in prog.etat["faits"], "quête secondaire : le serveur la note comme finie")
	prog.secondaire_faite("prehistoire", "premier_collier", 2, true)
	await _secondes(1.0)
	_verifier(_combien(inv, "collier_du_clan") == colliers + 1, "quête secondaire : pas de deuxième collier")

	# 3. Événement public (palier or) : les éclats de fracture sont toujours donnés.
	var eclats := _combien(inv, "eclat_de_fracture")
	xp = int(prog.etat["xp"])
	var recu := [""]
	prog.recompense_recue.connect(func(t): recu[0] = t)
	prog.evenement_fait("prehistoire", "faille_s_ouvre", "or", true)
	await _attendre(func(): return _combien(inv, "eclat_de_fracture") > eclats)
	_verifier(_combien(inv, "eclat_de_fracture") == eclats + 4, "événement : 4 éclats de fracture dans NOS sacs")
	_verifier(int(prog.etat["xp"]) > xp, "événement : on gagne de l'XP")
	_verifier("clat" in String(recu[0]), "événement : le serveur nous dit ce qu'on a reçu (%s)" % recu[0])
	prog.evenement_fait("prehistoire", "faille_s_ouvre", "or", true)
	await _secondes(1.0)
	_verifier(_combien(inv, "eclat_de_fracture") == eclats + 4, "événement : pas de deuxième récompense juste après")

	# 4. Mission d'un habitant du hub : de l'XP, une seule fois.
	xp = int(prog.etat["xp"])
	prog.mission_faite("kuro")
	await _attendre(func(): return int(prog.etat["xp"]) > xp)
	_verifier(int(prog.etat["xp"]) > xp, "mission du hub : on gagne de l'XP")
	xp = int(prog.etat["xp"])
	prog.mission_faite("kuro")
	await _secondes(1.0)
	_verifier(int(prog.etat["xp"]) == xp, "mission du hub : une seule fois")

	# 5. Mission du jour rendue : insignes de la Vigie + peaux + crocs.
	var periode := Recompenses.periode_actuelle("quotidienne")
	var insignes := _combien(inv, "insigne_vigie")
	var crocs := _combien(inv, "croc_loup")
	prog.mission_du_jour_rendue("meute_de_la_steppe", periode)
	await _attendre(func(): return _combien(inv, "insigne_vigie") > insignes)
	_verifier(_combien(inv, "insigne_vigie") == insignes + 2, "mission du jour : 2 insignes de la Vigie dans NOS sacs")
	_verifier(_combien(inv, "croc_loup") == crocs + 2, "mission du jour : 2 crocs de loup aussi")
	prog.mission_du_jour_rendue("meute_de_la_steppe", periode)
	await _secondes(1.0)
	_verifier(_combien(inv, "insigne_vigie") == insignes + 2, "mission du jour : une seule récompense par jour")

	# 6. Triche : demandes inventées ou trop anciennes.
	insignes = _combien(inv, "insigne_vigie")
	xp = int(prog.etat["xp"])
	prog.mission_du_jour_rendue("meute_de_la_steppe", periode - 400)
	prog.mission_du_jour_rendue("mission_inventee", periode)
	prog.etape_faite("prehistoire", {"id": "etape_inventee"})
	prog.etape_faite("atlantide", {"id": "toran_confiance"})
	prog.secondaire_faite("prehistoire", "premier_collier", 99, true)
	prog.evenement_fait("prehistoire", "faille_s_ouvre", "diamant", true)
	# Demande envoyée au nom de quelqu'un d'autre : refusée (Regles.expediteur).
	for autre in get_nodes_in_group("joueur"):
		if autre != joueur:
			autre.get_node("Progression").rpc_id(1, "_demander", "etape", ["prehistoire", "peinture"])
	await _secondes(1.5)
	_verifier(_combien(inv, "insigne_vigie") == insignes, "triche : une vieille mission ou une mission inventée ne rapporte rien")
	_verifier(int(prog.etat["xp"]) == xp, "triche : étapes, îles, quêtes et paliers inventés ne rapportent rien")

	print("Récompenses en groupe (%s) : %s" % [nom, "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs])
	quit(0 if _echecs == 0 else 1)
