extends "res://tests/test_partie_complete.gd"
## Test « partie complète » de l'Égypte ou de la Grèce : même principe que
## test_partie_complete.gd (vrais changements de scène, vraies sauvegardes dans un
## profil de test), mais après l'intro le joueur prend le portail de l'île choisie et
## joue ses 8 chapitres dans l'ordre, missions du QG comprises, jusqu'au retour au hub.
## Lancement : godot --headless --path game -s res://tests/test_partie_iles.gd -- --ile=egypte
##             (ou --ile=grece ; option --classe=rempart|lame|traqueur|tisseur)

var ILE := "egypte"
const PORTAILS_HUB := {"egypte": 1, "grece": 2}
const ARRIVEES := {
	"egypte": "res://scenes/monde/egypte/port_des_marais.tscn",
	"grece": "res://scenes/monde/grece/le_piree.tscn",
}
var _missions_faites: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ile="):
			ILE = arg.trim_prefix("--ile=")
	_profil_test = "_test_ile_%s_%d" % [ILE, OS.get_process_id()]
	super._initialize()


func _portail_hub(index: int):
	var liste: Array = _scene.qg["portails"]
	return liste[mini(index, liste.size() - 1)]


func _franchir_portail(index: int) -> void:
	var portail = _portail_hub(index)
	await _placer(portail.global_position + Vector3(0, -3.0, -4.0), PI)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")


## L'intro du hub, jusqu'au portail : on prend celui de l'île choisie.
func _intro() -> void:
	print("2. Intro dans Hikari Bay")
	await _attendre(60 * 6)
	_verifier(await _parler_hub("recruteur") >= 5, "Kenji Duval recrute le joueur")
	await _placer(Vector3(-23, -3.7, 30), PI)
	await _attendre(5)
	_verifier(await _parler_hub("commandante") >= 6, "la commandante donne la mission")
	_verifier(await _parler_hub("technicienne") >= 3, "Yuki prépare le portail")
	# Le premier voyage de l'intro mène toujours à la Préhistoire : on y fait un saut,
	# on revient par le portail de la Côte Gelée, puis on prend celui de l'île choisie.
	await _franchir_portail(0)
	_verifier(await _attendre_scene("res://scenes/monde/prehistoire/cote_gelee.tscn"), "le premier voyage mène à la Côte Gelée")
	await _attendre(60 * 4)
	var portail: Vector2 = get_first_node_in_group("ile").PORTAIL
	await _placer_sol(portail.x, portail.y + 14.0)
	await _placer_sol(portail.x, portail.y)
	await _attendre(30)
	var q = _quete()
	if q != null and not q._en_voyage:
		_secours.append("portail de la Côte Gelée sans effet (retour)")
		q.rentrer_au_hub()
	_verifier(await _attendre_scene("res://scenes/monde/hikari_bay.tscn"), "retour au QG")
	await _attendre(60)
	await _franchir_portail(PORTAILS_HUB[ILE])
	if _dialogue != null and _dialogue.est_ouvert():
		print("    (le portail répond : %s)" % [_dialogue._repliques])
	_verifier(await _attendre_scene(ARRIVEES[ILE]), "le portail « %s » du QG mène à l'île" % ILE)


## Comme dans la partie complète, mais au bon étage (salles de la pyramide, Acropole) :
## on ne se pose jamais sous la cible.
func _utiliser(cible: Node3D, ecart := 1.4) -> void:
	var p := cible.global_position
	var x := p.x
	var z := p.z + ecart
	var ile := get_first_node_in_group("ile")
	var y := p.y if ile == null else (maxf(_hauteur(x, z), p.y) if ile.is_in_group("donjon") else _hauteur(x, z))
	await _placer(Vector3(x, y + 0.4, z), 0.0)
	# On attend d'être posé : une action longue s'interrompt si l'on bouge (même en tombant).
	for i in 60:
		if _joueur.is_on_floor():
			break
		await _attendre(1)
	await _attendre(3)
	await _appuyer_f()


func _portail_ile() -> Vector2:
	var ile := get_first_node_in_group("ile")
	var p = ile.get("portail")
	if p is Vector2 and p != Vector2.INF:
		return p
	return ile.get("PORTAIL")


## Une mission du QG lancée par le portail (« mission_hub ») ou la visite guidée.
func _mission_qg() -> void:
	var quetes = _scene.get_node("Quetes")
	await _attendre(60)
	var mission := ""
	for id in ["carnet", "archives", "montre"]:
		if quetes.etat(id) == "active" and not id in _missions_faites:
			mission = id
	_verifier(mission != "", "une mission du QG commence au retour")
	if mission == "":
		return
	print("   Mission du QG : %s" % mission)
	var tours := 0
	while quetes.etat(mission) == "active" and tours < 10:
		tours += 1
		await _parler_hub(String(quetes.etape_de(mission).get("parler", "")))
	_verifier(quetes.etat(mission) == "terminee", "mission « %s » terminée" % mission)
	_missions_faites.append(mission)
	await _franchir_portail(PORTAILS_HUB[ILE])
	_verifier(await _attendre_scene(ARRIVEES[ILE]), "le portail ramène sur l'île")


func _faire_etape(q) -> void:
	var e: Dictionary = q.etape_actuelle()
	if e.get("portail", false) and q._ici(e):
		var portail := _portail_ile()
		await _placer_sol(portail.x, portail.y + 14.0)
		await _placer_sol(portail.x, portail.y)
		for i in 30:
			await _attendre(1)
			if q._en_voyage:
				break
		if not q._en_voyage:
			_secours.append("portail de %s sans effet" % q._zone())
			q.rentrer_au_hub()
		_verifier(await _attendre_scene("res://scenes/monde/hikari_bay.tscn"), "le portail de l'île ramène au QG")
		await _mission_qg()
		return
	# Un boss à phases : on le blesse par paliers ; s'il ne descend plus (mécanique
	# de boss : mur, égide…), on le note et on l'achève.
	if e.has("tuer") and e.has("phases") and q._ici(e):
		var cibles := _ennemis(String(e["tuer"]))
		if not cibles.is_empty():
			var boss = cibles[0]
			var combat = _joueur.get_node("Combat")
			await _placer_sol(boss.global_position.x + 4.0, boss.global_position.z + 4.0)
			var avant: float = boss.combat.pv
			boss.combat.subir(boss.combat.pv_max * 0.2, combat)
			await _attendre(20)
			if is_instance_valid(boss) and boss.combat.est_vivant() and boss.combat.pv >= avant - 1.0:
				if not ("boss %s : protégé (mécanique de boss), achevé par le test" % e["tuer"]) in _secours:
					_secours.append("boss %s : protégé (mécanique de boss), achevé par le test" % e["tuer"])
				# Les renforts (Masque…) protègent le boss : on les écarte d'abord.
				for bete in get_nodes_in_group("loups"):
					if bete != boss and bete.combat.est_vivant() and bete.global_position.distance_to(boss.global_position) < 40.0:
						bete.combat.subir(99999.0, combat)
				await _attendre(10)
				for effet in ["evite", "enfoui"]:
					if boss.combat.a_effet(effet):
						boss.combat.retirer_effet(effet)
				boss.combat.pv = 1.0
				boss.combat.subir(99999.0, combat)
				await _attendre(10)
			return
	# « Assomme-les, puis rends-leur leur nom » : rien à récolter tant qu'on n'a pas
	# assommé les créatures de l'étape (Oubliés) ; on va les voir d'abord.
	if e.has("recolter") and e.has("apparition") and q._ici(e) and q._position_cible(e) == null:
		var a: Dictionary = e["apparition"]
		await _placer_sol(float(a["position"][0]) + 3.0, float(a["position"][1]) + 3.0)
		await _nettoyer_autour(float(a.get("rayon", 6)) + 12.0)
		await _attendre(30)
		if q._position_cible(e) == null:
			_verifier(false, "[%s] rien à récolter après avoir assommé les créatures" % e["id"])
		return
	# La Paralos (Grèce, ch. 2) : on reste à bord et on rame en cadence.
	if String(e.get("objet", "")) == "triere_cadence" and q._ici(e):
		var triere = _scene.find_child("Paralos", true, false)
		var images := 0
		while triere != null and triere.en_route and images < 6000:
			if triere.en_cadence():
				triere.ramer()
			_soigner()
			await _attendre(1)
			images += 1
		await _attendre(60)
		await _lire_dialogue()
		return
	var avant := _id(q)
	await super._faire_etape(q)
	if e.has("objet") and is_instance_valid(q) and _id(q) == avant and q._ici(e):
		var o = q._trouver_objet(e["objet"])
		var hostiles := []
		for bete in get_nodes_in_group("loups"):
			if bete.combat.est_vivant() and bete.global_position.distance_to(_joueur.global_position) < 25.0:
				hostiles.append("%s à %.0f m" % [bete.type_ennemi, bete.global_position.distance_to(_joueur.global_position)])
		var butin = get_first_node_in_group("butin")
		if butin == null:
			butin = _scene.find_child("Butin", true, false)
		if butin != null:
			print("    butin à portée : %s ; sacs : %s" % [butin.sac_a_portee(), butin.get("_visibles").values().map(func(v): return [v.get("texte"), v.has("plein")])])
		print("    effets %s ; canalisation %s ; dialogue ouvert %s ; cinématique %s" % [_joueur.combat.effets.keys(), q.get("_canalisation"), _dialogue.est_ouvert() if _dialogue else "?", has_group("cinematique_en_cours")])
		for pnj in get_nodes_in_group("pnj"):
			if pnj is Node3D and pnj.global_position.distance_to(_joueur.global_position) < 6.0:
				print("    PNJ proche : %s (%s) visible=%s à %.1f m" % [pnj.name, pnj.get("identifiant"), pnj.is_visible_in_tree(), pnj.global_position.distance_to(_joueur.global_position)])
		for n in get_nodes_in_group("objet_quete"):
			if n.global_position.distance_to(_joueur.global_position) < 6.0:
				print("    objet proche : %s actif=%s visible=%s portee=%s meta=%s" % [n.name, n.get("actif"), n.is_visible_in_tree(), n.get("portee"), n.get_meta_list()])
		print("    [%s] pas fini : objet %s actif=%s à %.1f m ; joueur %s au sol=%s ; pv %d/%d ; autour : %s" % [e["id"], o, o.get("actif") if o else "?",
				o.global_position.distance_to(_joueur.global_position) if o else -1.0, _joueur.global_position, _joueur.is_on_floor(),
				_joueur.combat.pv, _joueur.combat.pv_max, hostiles])


func _jouer_ile() -> void:
	print("3. Île : %s" % ILE)
	var q = _quete()
	_zones_vues.append(String(q._zone()))
	var actions := 0
	var derniere := ""
	var meme := 0
	while actions < MAX_ACTIONS:
		q = _quete()
		if q == null:
			# Au hub (mission en cours) : la boucle reprend sur l'île.
			await _attendre(30)
			actions += 1
			continue
		if q.etape < 0:
			break
		actions += 1
		_soigner()
		var id: String = _id(q)
		if id != derniere:
			print("   étape : %s (chapitre %d, %s)" % [id, q.etape_actuelle().get("chapitre", 0), q._zone()])
			derniere = id
			meme = 0
		else:
			meme += 1
			if meme > 40:
				_verifier(false, "bloqué à l'étape « %s »" % id)
				return
		await _faire_etape(q)
	q = _quete()
	_verifier(q != null and q.etape == -1, "l'île %s est finie (8 chapitres, %d actions)" % [ILE, actions])
	print("   zones visitées : %s" % [_zones_vues])


func _retour_au_hub() -> void:
	print("4. Retour au hub")
	var q = _quete()
	await _attendre(60 * 6)
	var depart: String = String(q.donnees["zones"].keys()[0])
	var essais := 0
	while q._zone() != depart and essais < 4:
		essais += 1
		await _aller_vers_zone(q, depart)
		q = _quete()
	var portail := _portail_ile()
	await _placer_sol(portail.x, portail.y + 14.0)
	await _placer_sol(portail.x, portail.y)
	await _attendre(30)
	if not q._en_voyage:
		_secours.append("portail de fin sans effet")
		q.rentrer_au_hub()
	_verifier(await _attendre_scene("res://scenes/monde/hikari_bay.tscn"), "retour à Hikari Bay par le portail")
	await _attendre(120)
	var p: Vector3 = _joueur.global_position
	_verifier(p.y > -20.0 and _joueur.is_on_floor(), "le joueur est debout au QG (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z])
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin("user://progression.cfg"))
	_verifier(String(cfg.get_value(ILE, "etape", "")) == "fin", "la progression enregistrée dit « %s finie » (%s)" % [ILE, cfg.get_value(ILE, "etape", "")])
	var inv = _joueur.get_node("Inventaire")
	var prog = _joueur.get_node_or_null("Progression")
	var niveau = (prog.niveau() if prog.has_method("niveau") else prog.get("niveau")) if prog != null else null
	print("   niveau atteint : %s" % [niveau])


func _lancer() -> void:
	print("Test : une partie complète sur l'île %s (classe : %s)" % [ILE, CLASSE])
	Profil.activer(_profil_test)
	var debut := Time.get_ticks_msec()
	await _menu_et_creation()
	if _scene != null and _scene.scene_file_path.ends_with("hikari_bay.tscn"):
		await _intro()
	if _quete() != null:
		await _jouer_ile()
		if _quete() != null and _quete().etape < 0:
			await _retour_au_hub()
	if not _secours.is_empty():
		print("Passages forcés (à vérifier) :")
		for s in _secours:
			print("   - ", s)
	print("Durée : %d s" % ((Time.get_ticks_msec() - debut) / 1000))
	_effacer_profil_test()
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
