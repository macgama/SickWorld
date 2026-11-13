class_name CombatJoueur
extends Node
## Le combat du joueur : ciblage (Tab, clic), barre de 8 compétences (touches 1 à 8),
## attaque automatique, temps de recharge, incantations, mort et réapparition.
##
## En multijoueur, ce script tourne à deux endroits :
## - chez le joueur : il lit les touches, choisit la cible et AFFICHE l'état
##   (recharges, Élan…) ;
## - sur le serveur : il VÉRIFIE chaque demande (portée, recharge, Élan…)
##   et applique les dégâts. C'est lui qui a le dernier mot.
##
## Les compétences sont décrites dans data/competences.json
## et la barre dans data/joueur.json.

signal cible_changee(cible: Combattant)
signal message(texte: String)
signal incantation_changee(nom: String, progression: float)
## La barre a changé (tenue de mission, nouvelle compétence d'époque).
signal barre_changee

const SCENE_LOUP := preload("res://scenes/ennemis/loup.tscn")
const PORTEE_CIBLAGE := 45.0

var cible: Combattant = null
var barre: Array[String] = []
## id de compétence -> moment où elle sera de nouveau disponible
var recharges := {}
var fin_recharge_globale := 0.0
## Élan : calculé par le serveur et envoyé au joueur (nœud Synchro).
var elan := 0.0
var elan_max := 100.0
var attaque_auto := false
## Bonus de l'équipement sur les compétences (ensembles, reliques), remplis par l'Inventaire :
## id de compétence -> { clé: valeur ajoutée }.
var modifs_competences := {}

var _reglages: Dictionary
var _prochaine_attaque_auto := 0.0
# Incantation (serveur)
var _incantation_id := ""
var _incantation_fin := 0.0
# Incantation (affichage chez le joueur)
var _barre_nom := ""
var _barre_debut := 0.0
var _barre_fin := 0.0
# Bond en cours (serveur)
var _bond_competence := ""
var _bond_cible: Combattant = null
var _bond_limite := 0.0
var _compteur_invocations := 0
var _anneau: MeshInstance3D

@onready var joueur: Joueur = get_parent()
@onready var combat: Combattant = get_parent().get_node("Combat")


func _ready() -> void:
	_reglages = Donnees.joueur
	for id in _reglages.get("barre", []):
		barre.append(String(id))
	elan_max = float(_reglages.get("elan_max", 100))
	combat.niveau = int(_reglages.get("niveau", 1))
	combat.faction = "joueur"
	combat.hauteur_centre = 1.1
	if multiplayer.is_server():
		combat.pv_max = float(_reglages.get("points_de_vie", 200))
		combat.pv = combat.pv_max
		combat.nom_affiche = joueur.nom
		combat.mort.connect(_sur_mort)
	if joueur.est_local():
		(joueur.get_node("CameraRig") as CameraJoueur).clic_simple.connect(_sur_clic)
		_creer_anneau()
	else:
		set_process_unhandled_input(false)


func _est_le_proprietaire() -> bool:
	return Regles.expediteur() == joueur.id_reseau()


# --- Commandes (chez le joueur) ---------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cible_suivante"):
		cibler_suivant()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("annuler"):
		# Échap annule l'incantation, sinon enlève la cible ; sans cible,
		# il laisse passer la touche pour ouvrir le menu de jeu.
		if _barre_nom != "":
			Regles.au_serveur(self, "_demander_annulation")
			get_viewport().set_input_as_handled()
		elif cible != null:
			changer_cible(null)
			get_viewport().set_input_as_handled()
	else:
		for i in 8:
			if event.is_action_pressed("competence_%d" % (i + 1)):
				utiliser(i)
				get_viewport().set_input_as_handled()
				return


func _sur_clic(bouton: int, position_ecran: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origine := camera.project_ray_origin(position_ecran)
	var fin := origine + camera.project_ray_normal(position_ecran) * 200.0
	var requete := PhysicsRayQueryParameters3D.create(origine, fin,
			Regles.COUCHE_MONDE | Regles.COUCHE_PERSONNAGES, [joueur.get_rid()])
	var touche := joueur.get_world_3d().direct_space_state.intersect_ray(requete)
	if touche.is_empty():
		return
	var c := (touche.collider as Node).get_node_or_null("Combat") as Combattant
	if c != null and c.est_vivant():
		# Clic droit sur un ennemi : on l'attaque, comme dans WoW.
		changer_cible(c, bouton == MOUSE_BUTTON_RIGHT and combat.est_hostile(c))


func changer_cible(nouvelle: Combattant, attaquer := false) -> void:
	if nouvelle == cible and not attaquer:
		return
	cible = nouvelle
	cible_changee.emit(cible)
	var chemin := cible.get_path() if cible != null else NodePath()
	Regles.au_serveur(self, "_choisir_cible", [chemin, attaquer])


## Touche Tab : passe à l'ennemi suivant, en commençant par les plus proches devant la caméra.
func cibler_suivant() -> void:
	var camera := get_viewport().get_camera_3d()
	var candidats: Array = []
	for c in Regles.hostiles_autour(combat, joueur.global_position, PORTEE_CIBLAGE):
		if camera != null and camera.is_position_behind(c.centre()):
			continue
		if not Regles.ligne_de_vue(combat, c):
			continue
		candidats.append(c)
	if candidats.is_empty():
		message.emit("Aucun ennemi en vue")
		return
	candidats.sort_custom(func(a, b): return Regles.distance(combat, a) < Regles.distance(combat, b))
	var index := candidats.find(cible)
	changer_cible(candidats[(index + 1) % candidats.size()])


## Touches 1 à 8 : on vérifie d'abord chez soi (pour répondre tout de suite),
## puis on demande au serveur, qui vérifie à nouveau.
func utiliser(index: int) -> bool:
	var raison := raison_impossible(index)
	if raison != "":
		message.emit(raison)
		return false
	Regles.au_serveur(self, "_demander_competence", [index])
	return true


func reapparaitre() -> void:
	Regles.au_serveur(self, "_demander_reapparition")


# --- Informations (partout) ---------------------------------------------------

func competence(index: int) -> Dictionary:
	if index < 0 or index >= barre.size():
		return {}
	return competence_par_id(barre[index])


## La compétence avec les bonus de l'équipement porté.
func competence_par_id(id: String) -> Dictionary:
	return Objets.competence_modifiee(Donnees.competence(id), modifs_competences.get(id, {}))


## Remplace la barre (appelé par l'Inventaire, sur le serveur et chez le joueur).
func definir_barre(liste: Array) -> void:
	var nouvelle: Array[String] = []
	for id in liste:
		nouvelle.append(String(id))
	if nouvelle.is_empty() or nouvelle == barre:
		barre_changee.emit()
		return
	barre = nouvelle
	barre_changee.emit()


## Temps restant avant de pouvoir réutiliser la compétence (secondes), et durée totale.
func recharge_restante(index: int) -> Vector2:
	if index >= barre.size():
		return Vector2.ZERO
	var t := Regles.maintenant()
	var propre := maxf(0.0, float(recharges.get(barre[index], 0.0)) - t)
	var globale := maxf(0.0, fin_recharge_globale - t)
	var duree := float(competence(index).get("recharge", 0.0))
	if propre >= globale:
		return Vector2(propre, duree)
	return Vector2(globale, float(_reglages.get("temps_de_recharge_global", 1.0)))


## Renvoie "" si la compétence peut être lancée maintenant, sinon la raison.
func raison_impossible(index: int) -> String:
	var c := competence(index)
	if c.is_empty():
		return "Emplacement vide"
	if not combat.est_vivant():
		return "Tu es désynchronisé"
	if _incantation_id != "" or _barre_nom != "":
		return "Déjà en train de préparer une compétence"
	if recharge_restante(index).x > 0.05:
		return "Pas encore prêt"
	if elan < float(c.get("cout_elan", 0)):
		return "Pas assez d'Élan"
	var type := String(c.get("type", ""))
	if type in ["melee", "distance", "bond"]:
		if cible == null or not is_instance_valid(cible) or not cible.est_vivant():
			return "Pas de cible"
		if not combat.est_hostile(cible):
			return "Cible invalide"
		var d := Regles.distance(combat, cible)
		# Le serveur accepte un peu plus de distance : les positions arrivent avec un léger retard.
		var marge := 1.5 if multiplayer.is_server() and not joueur.est_local() else 0.0
		if d > float(c.get("portee", 3.5)) + marge:
			return "Hors de portée"
		if d < float(c.get("portee_min", 0.0)) - marge:
			return "Trop près"
		if not Regles.ligne_de_vue(combat, cible):
			return "Cible non visible"
		if c.has("pv_cible_max_pourcent") and cible.pourcentage_pv() > float(c["pv_cible_max_pourcent"]):
			return "La cible a encore trop de vie"
	return ""


# --- Demandes reçues par le serveur -----------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _choisir_cible(chemin: NodePath, attaquer: bool) -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire():
		return
	var nouvelle := get_node_or_null(chemin) as Combattant if not chemin.is_empty() else null
	if nouvelle != cible:
		attaque_auto = false
	cible = nouvelle
	if attaquer and cible != null and combat.est_hostile(cible):
		attaque_auto = true


@rpc("any_peer", "call_remote", "reliable")
func _demander_competence(index: int) -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire():
		return
	var raison := raison_impossible(index)
	if raison != "":
		Regles.chez(joueur.id_reseau(), self, "_recevoir_message", [raison])
		return
	var c := competence(index)
	var gcd := float(_reglages.get("temps_de_recharge_global", 1.0))
	fin_recharge_globale = Regles.maintenant() + gcd
	Regles.chez(joueur.id_reseau(), self, "_recevoir_recharge", ["", 0.0, gcd])
	var incantation := float(c.get("incantation", 0.0))
	if incantation > 0.0:
		_incantation_id = barre[index]
		_incantation_fin = Regles.maintenant() + incantation
		Regles.chez(joueur.id_reseau(), self, "_recevoir_incantation", [String(c.get("nom", "")), incantation])
		return
	_executer(barre[index])


@rpc("any_peer", "call_remote", "reliable")
func _demander_annulation() -> void:
	if multiplayer.is_server() and _est_le_proprietaire() and _incantation_id != "":
		_interrompre("Annulé")


@rpc("any_peer", "call_remote", "reliable")
func _demander_reapparition() -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire() or combat.est_vivant():
		return
	var balise := get_tree().get_first_node_in_group("balises") as Node3D
	var p := joueur.global_position
	if balise != null and balise.has_method("point_de_reapparition"):
		p = balise.point_de_reapparition()
	combat.reanimer(100.0)
	var penalite: Dictionary = _reglages.get("penalite_reapparition", {})
	var reduction := float(penalite.get("reduction_degats_pourcent", 10)) / 100.0
	combat.ajouter_effet("desynchronisation", float(penalite.get("duree", 120)),
			{"degats_infliges": 1.0 - reduction})
	Regles.chez(joueur.id_reseau(), joueur, "teleporter", [p, joueur.rotation.y])


@rpc("any_peer", "call_remote", "reliable")
func _bond_arrive() -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire() or _bond_competence == "":
		return
	var c := competence_par_id(_bond_competence)
	_bond_competence = ""
	if is_instance_valid(_bond_cible) and Regles.distance(combat, _bond_cible) <= 4.5:
		_toucher(_bond_cible, c)


# --- Exécution (serveur) -----------------------------------------------------

func _executer(id: String) -> void:
	var c := competence_par_id(id)
	var recharge := float(c.get("recharge", 0.0))
	recharges[id] = Regles.maintenant() + recharge
	Regles.chez(joueur.id_reseau(), self, "_recevoir_recharge", [id, recharge, 0.0])
	elan = clampf(elan - float(c.get("cout_elan", 0)) + float(c.get("gain_elan", 0)), 0.0, elan_max)
	combat.noter_combat()
	_animer_attaque.rpc()

	match String(c.get("type", "")):
		"melee":
			_toucher(cible, c)
			attaque_auto = true
		"bond":
			_bond_competence = id
			_bond_cible = cible
			_bond_limite = Regles.maintenant() + 2.0
			attaque_auto = true
			Regles.chez(joueur.id_reseau(), self, "_recevoir_bond", [cible.get_path()])
		"distance":
			var victime := cible
			var duree := maxf(0.15, combat.centre().distance_to(victime.centre()) / 35.0)
			_effet_sagaie.rpc(victime.get_path(), duree)
			get_tree().create_timer(duree).timeout.connect(func(): _toucher(victime, c))
		"zone_autour":
			for ennemi in Regles.hostiles_autour(combat, joueur.global_position, float(c.get("rayon", 5))):
				_toucher(ennemi, c)
		"zone_au_sol":
			var zone := ZoneDeFeu.new()
			zone.lanceur = combat
			zone.reglages = c
			get_tree().current_scene.add_child(zone)
			zone.global_position = joueur.global_position
			_effet_feu.rpc(joueur.global_position, c)
		"invocation":
			_invoquer(c)
		"renfort":
			# Cri du clan (alliés autour) ou Peinture de guerre (soi-même).
			var cibles: Array[Combattant] = [combat]
			if float(c.get("rayon", 0)) > 0.0:
				cibles = Regles.allies_autour(combat, joueur.global_position, float(c["rayon"]))
			var effet := {}
			for cle in ["degats_infliges", "reduction_degats_subis"]:
				if c.has(cle):
					effet[cle] = float(c[cle])
			for allie in cibles:
				allie.ajouter_effet(String(c.get("effet", id)), float(c.get("duree", 8)), effet, combat)


func _toucher(victime: Combattant, c: Dictionary) -> void:
	if victime == null or not is_instance_valid(victime) or not victime.est_vivant():
		return
	Regles.infliger(combat, victime, Donnees.entre(c.get("degats", [0, 0])))
	if c.has("saignement") and victime.est_vivant():
		var s: Dictionary = c["saignement"]
		victime.ajouter_effet("saignement", float(s["duree"]),
				{"degats_par_seconde": float(s["degats_par_seconde"])}, combat)
	if c.has("ralenti") and victime.est_vivant():
		var r: Dictionary = c["ralenti"]
		victime.ajouter_effet("ralenti", float(r["duree"]), {"vitesse": float(r["facteur"])}, combat)


func _invoquer(c: Dictionary) -> void:
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	if dossier == null:
		return
	for i in int(c.get("nombre", 2)):
		_compteur_invocations += 1
		var loup: Loup = SCENE_LOUP.instantiate()
		loup.name = "Meute_%d_%d" % [joueur.id_reseau(), _compteur_invocations]
		loup.type_ennemi = "loup_allie"
		loup.faction = "joueur"
		loup.maitre = joueur
		loup.fin_invocation = Regles.maintenant() + float(c.get("duree", 20))
		var cote := -1.0 if i == 0 else 1.0
		loup.position = joueur.global_position + joueur.global_transform.basis.x * cote * 1.5 + Vector3.UP * 0.5
		dossier.add_child(loup)
		loup.camp = loup.global_position


func _interrompre(texte: String) -> void:
	_incantation_id = ""
	fin_recharge_globale = 0.0
	Regles.chez(joueur.id_reseau(), self, "_recevoir_incantation", ["", -1.0])
	Regles.chez(joueur.id_reseau(), self, "_recevoir_recharge", ["", 0.0, 0.0])
	Regles.chez(joueur.id_reseau(), self, "_recevoir_message", [texte])


func _sur_mort(_tueur: Combattant) -> void:
	if _incantation_id != "":
		_interrompre("Interrompu")
	cible = null
	attaque_auto = false
	elan = 0.0


# --- Messages reçus par le joueur --------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _recevoir_message(texte: String) -> void:
	message.emit(texte)


## id vide = temps de recharge global.
@rpc("authority", "call_remote", "reliable")
func _recevoir_recharge(id: String, duree: float, globale: float) -> void:
	var t := Regles.maintenant()
	if id != "":
		recharges[id] = t + duree
	if id == "" or globale > 0.0:
		fin_recharge_globale = t + globale


@rpc("authority", "call_remote", "reliable")
func _recevoir_incantation(nom: String, duree: float) -> void:
	_barre_nom = nom if duree > 0.0 else ""
	_barre_debut = Regles.maintenant()
	_barre_fin = _barre_debut + maxf(duree, 0.0)
	if _barre_nom == "":
		incantation_changee.emit("", -1.0)


@rpc("authority", "call_remote", "reliable")
func _recevoir_bond(chemin_cible: NodePath) -> void:
	var c := get_node_or_null(chemin_cible) as Combattant
	if c == null:
		return
	joueur.bondir_vers(c.acteur(), func(): Regles.au_serveur(self, "_bond_arrive"))


# --- Effets visibles par tous ------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _animer_attaque() -> void:
	Audio.effet("attaque", joueur)
	if joueur.apparence.has_method("attaquer"):
		joueur.apparence.attaquer()


@rpc("authority", "call_local", "reliable")
func _effet_sagaie(chemin_cible: NodePath, duree: float) -> void:
	var victime := get_node_or_null(chemin_cible) as Combattant
	if victime == null or DisplayServer.get_name() == "headless":
		return
	var sagaie := MeshInstance3D.new()
	var forme := CylinderMesh.new()
	forme.top_radius = 0.015
	forme.bottom_radius = 0.025
	forme.height = 1.4
	sagaie.mesh = forme
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.32, 0.2)
	sagaie.material_override = mat
	get_tree().current_scene.add_child(sagaie)
	var depart := combat.centre() + Vector3.UP * 0.4
	sagaie.global_position = depart
	var voler := func(t: float) -> void:
		if not is_instance_valid(victime) or not is_instance_valid(sagaie):
			return
		var p := depart.lerp(victime.centre(), t) + Vector3.UP * sin(t * PI) * 1.5
		var direction := p - sagaie.global_position
		sagaie.global_position = p
		if direction.length() > 0.001:
			sagaie.look_at(p + direction, Vector3.UP)
			sagaie.rotate_object_local(Vector3.RIGHT, PI / 2)
	Audio.effet("lancer", joueur)
	var animation := sagaie.create_tween()
	animation.tween_method(voler, 0.0, 1.0, duree)
	animation.tween_callback(func():
		if is_instance_valid(victime):
			Audio.effet("impact_sagaie", victime.centre()))
	animation.tween_callback(sagaie.queue_free)


## Le feu « pour de vrai » existe sur le serveur ; les joueurs reçoivent une copie juste visuelle.
@rpc("authority", "call_remote", "reliable")
func _effet_feu(position_monde: Vector3, reglages: Dictionary) -> void:
	var zone := ZoneDeFeu.new()
	zone.reglages = reglages
	get_tree().current_scene.add_child(zone)
	zone.global_position = position_monde


# --- Boucle ----------------------------------------------------------------

func _process(delta: float) -> void:
	var t := Regles.maintenant()

	# Chez le joueur : cible disparue, barre de préparation.
	if joueur.est_local():
		if cible != null and (not is_instance_valid(cible) or not cible.est_vivant()):
			cible = null
			cible_changee.emit(null)
		if _barre_nom != "":
			if t >= _barre_fin:
				_barre_nom = ""
				incantation_changee.emit("", -1.0)
			else:
				incantation_changee.emit(_barre_nom, (t - _barre_debut) / maxf(0.01, _barre_fin - _barre_debut))
		_mettre_a_jour_anneau()

	if multiplayer.is_server():
		_logique_serveur(delta, t)


func _logique_serveur(delta: float, t: float) -> void:
	if cible != null and (not is_instance_valid(cible) or not cible.est_vivant()):
		cible = null
		attaque_auto = false

	# Incantation en cours.
	if _incantation_id != "":
		var c := competence_par_id(_incantation_id)
		if joueur.bouge() or not combat.est_vivant():
			_interrompre("Interrompu")
		elif cible == null:
			_interrompre("Cible perdue")
		elif t >= _incantation_fin:
			var id := _incantation_id
			_incantation_id = ""
			if Regles.distance(combat, cible) <= float(c.get("portee", 30)) + 2.0:
				_executer(id)
			else:
				Regles.chez(joueur.id_reseau(), self, "_recevoir_message", ["Hors de portée"])

	if _bond_competence != "" and t > _bond_limite:
		_bond_competence = ""

	# Attaque automatique.
	var auto: Dictionary = _reglages.get("attaque_automatique", {})
	if attaque_auto and cible != null and combat.est_vivant() and t >= _prochaine_attaque_auto \
			and Regles.distance(combat, cible) <= float(auto.get("portee", 3.5)) + 1.0:
		_prochaine_attaque_auto = t + float(auto.get("intervalle", 2.0))
		Regles.infliger(combat, cible, Donnees.entre(auto.get("degats", [5, 8])))
		elan = minf(elan_max, elan + float(auto.get("gain_elan", 8)))
		_animer_attaque.rpc()

	# Hors combat : la vie remonte, l'Élan redescend.
	if combat.est_vivant() and not combat.en_combat():
		var regen := float(_reglages.get("regeneration_hors_combat_pourcent", 4)) / 100.0
		regen *= 1.0 + FichePersonnage.bonus(joueur.fiche.donnees, Donnees.creation,
				"regeneration_hors_combat_pourcent") / 100.0
		if combat.pv < combat.pv_max:
			combat.soigner(combat.pv_max * regen * delta)
		elan = maxf(0.0, elan - float(_reglages.get("perte_elan_hors_combat", 5)) * delta)


# --- Anneau de sélection sous la cible -------------------------------------

func _creer_anneau() -> void:
	_anneau = MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 0.7
	tore.outer_radius = 0.8
	tore.rings = 32
	_anneau.mesh = tore
	_anneau.scale = Vector3(1, 0.05, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.25, 0.2)
	_anneau.material_override = mat
	_anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anneau.top_level = true
	_anneau.visible = false
	add_child.call_deferred(_anneau)


func _mettre_a_jour_anneau() -> void:
	if _anneau == null or not _anneau.is_inside_tree():
		return
	_anneau.visible = cible != null
	if cible != null:
		var mat := _anneau.material_override as StandardMaterial3D
		mat.albedo_color = Color(1, 0.25, 0.2) if combat.est_hostile(cible) else Color(0.3, 1, 0.4)
		_anneau.global_position = cible.acteur().get_global_transform_interpolated().origin + Vector3.UP * 0.05
