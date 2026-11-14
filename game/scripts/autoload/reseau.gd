extends Node
## Gère la connexion entre les joueurs.
##
## Trois façons de jouer :
## - « seul » : tout se passe sur ton PC, sans réseau ;
## - « héberger » : ton PC lance un serveur (sans fenêtre, en arrière-plan) et tu
##   le rejoins aussitôt ; tes amis te rejoignent à ton adresse IP ;
## - « rejoindre » : tu te connectes au serveur d'un autre joueur (son adresse IP).
## Un serveur « dédié » (sans fenêtre, sans joueur) se lance avec :
##   godot --headless --path game -- --serveur [--port=7777] [--statut=fichier.json]
## Donjons en groupe : le serveur de la ville lance lui-même un serveur « d'instance »
## par groupe (« --instance --scene=… », ports suivants : 7778, 7779…), voir Social.
## (« --statut » : le serveur y écrit le nombre de joueurs connectés, lu par les
## scripts du serveur Oracle Cloud pour ne pas redémarrer pendant une partie.)
##
## Règle d'or : le SERVEUR décide de tout ce qui compte (vie, dégâts, loups).
## Chaque joueur envoie seulement ses déplacements et ses demandes (« je lance
## telle compétence »), et le serveur vérifie qu'elles sont permises.

signal statut_change(texte: String)
## Serveur : un joueur vient d'arriver (il a donné son nom) / vient de partir.
signal joueur_arrive(id: int, nom: String)
signal joueur_parti(id: int, nom: String)

enum Mode { SEUL, HEBERGER, REJOINDRE, SERVEUR_DEDIE }

const PORT_PAR_DEFAUT := 7777
const JOUEURS_MAX := 32
const SCENE_MONDE := "res://scenes/monde/colline_de_test.tscn"
const SCENE_MENU := "res://scenes/interface/menu.tscn"
## On commence en ville (Hikari Bay) : intro, QG de la Vigie, puis portail vers l'île.
const SCENE_HUB := "res://scenes/monde/hikari_bay.tscn"
## Adresses du serveur officiel (Oracle Cloud), remplies une fois le serveur allumé.
const FICHIER_OFFICIEL := "res://data/serveur_officiel.json"

var mode := Mode.SEUL
var adresse := "127.0.0.1"
var port := PORT_PAR_DEFAUT
var nom_joueur := "Agent"
## Scène où la partie commence : la ville. L'option « --colline » (tests, serveur
## de combat) démarre directement sur la colline de test.
var scene_depart := SCENE_HUB
## Fiche du personnage de ce PC (voir FichePersonnage), envoyée au serveur en arrivant.
var fiche := {}
## Sur le serveur : identifiant réseau -> nom du joueur.
var noms := {}
## Sur le serveur : identifiant réseau -> fiche du personnage (déjà vérifiée).
var fiches := {}
## Serveur dédié : fichier où écrire l'état (nombre de joueurs), vide = aucun.
var fichier_statut := ""

# --- Donjons en groupe (instances) ---
## Ce programme est un serveur d'« instance » : un donjon privé lancé par la ville
## pour un groupe (option « --instance »). Il s'éteint tout seul quand il est vide.
var instance := false
## Serveur d'instance : le groupe attendu ({chef, membres}), reçu par « --groupe= ».
var groupe_instance := {}
## Chez le joueur : port du serveur de la ville, pour y revenir après un donjon.
var port_hub := 0
## Chez le joueur : scène du donjon où l'on est ("" = on n'est pas en donjon).
var scene_instance := ""
## Nom du donjon où l'on est (affiché dans l'interface).
var nom_instance := ""
## Joueurs partis en donjon depuis cette ville (comptés dans le fichier d'état).
var joueurs_ailleurs := 0
## « Héberger » : numéro du serveur lancé en arrière-plan sur ce PC (-1 = aucun).
var _processus_serveur := -1
## Serveur lancé par « Héberger » (option « --auto-arret ») : il s'arrête tout seul
## une minute après le départ du dernier joueur.
var arret_automatique := false
## Le client réessaie de se connecter jusqu'à ce moment (serveur en train de démarrer).
var _reessayer_jusqua := 0.0
var _vide_depuis := 0.0
var _a_eu_un_joueur := false


func _ready() -> void:
	fiche = FichePersonnage.charger(Donnees.creation)
	if not fiche.is_empty():
		nom_joueur = fiche["nom"]
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--port="):
			port = int(argument.get_slice("=", 1))
		elif argument.begins_with("--nom="):
			nom_joueur = argument.get_slice("=", 1)
		elif argument.begins_with("--statut="):
			fichier_statut = argument.get_slice("=", 1)
		elif argument.begins_with("--rejoindre="):
			mode = Mode.REJOINDRE
			adresse = argument.get_slice("=", 1)
		elif argument.begins_with("--scene="):
			var scene := argument.get_slice("=", 1)
			if scene.begins_with("res://scenes/monde/") and ResourceLoader.exists(scene):
				scene_depart = scene
		elif argument.begins_with("--groupe="):
			var lu = JSON.parse_string(Marshalls.base64_to_utf8(argument.get_slice("=", 1)))
			if lu is Dictionary:
				groupe_instance = lu
	if "--colline" in arguments:
		scene_depart = SCENE_MONDE
	if "--serveur" in arguments:
		mode = Mode.SERVEUR_DEDIE
		instance = "--instance" in arguments
		arret_automatique = instance or "--auto-arret" in arguments
		# Le serveur range ses fichiers à part, jamais dans la sauvegarde d'un joueur
		# de ce PC (« Héberger » lance un serveur sur le PC du joueur).
		var profil := "serveur"
		for argument in arguments:
			if argument.begins_with("--profil="):
				profil = argument.get_slice("=", 1).validate_filename()
		Profil.activer(profil)
	multiplayer.peer_connected.connect(_sur_pair_connecte)
	multiplayer.peer_disconnected.connect(_sur_pair_deconnecte)
	multiplayer.connected_to_server.connect(func(): statut_change.emit("Connecté"))
	multiplayer.connection_failed.connect(_sur_echec)
	multiplayer.server_disconnected.connect(_sur_serveur_perdu)


## Le serveur officiel : {"nom", "jeu" (adresse IP), "port", "comptes" (adresse
## du serveur de comptes)}. « jeu » vide = pas encore de serveur officiel.
func serveur_officiel() -> Dictionary:
	if not FileAccess.file_exists(FICHIER_OFFICIEL):
		return {}
	var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_OFFICIEL))
	return lu if lu is Dictionary else {}


func a_un_serveur_officiel() -> bool:
	return String(serveur_officiel().get("jeu", "")) != ""


func est_serveur() -> bool:
	return multiplayer.is_server()


## Vrai si ce programme affiche le jeu pour un joueur (faux pour un serveur dédié).
func a_un_joueur_local() -> bool:
	return mode != Mode.SERVEUR_DEDIE


## Appelé par le monde une fois chargé : ouvre le serveur ou se connecte.
func demarrer() -> Error:
	match mode:
		Mode.SEUL:
			multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		Mode.HEBERGER:
			# Le serveur tourne dans un programme à part (sans fenêtre) sur ce PC, et
			# on s'y connecte comme les autres : on peut ainsi partir en donjon avec
			# son groupe sans fermer la ville pour tout le monde.
			_choisir_port_pour_la_scene()
			if scene_instance == "" and not _demarrer_serveur_local():
				statut_change.emit("Impossible de lancer le serveur sur ce PC")
				return FAILED
			return _connecter_client("127.0.0.1", true)
		Mode.SERVEUR_DEDIE:
			var pair := ENetMultiplayerPeer.new()
			var erreur := pair.create_server(port, JOUEURS_MAX)
			if erreur != OK:
				statut_change.emit("Impossible d'ouvrir le port %d (déjà utilisé ?)" % port)
				return erreur
			multiplayer.multiplayer_peer = pair
			print("Serveur SickWorld ouvert sur le port %d" % port)
			_ecrire_statut()
		Mode.REJOINDRE:
			return _connecter_client(adresse, false)
	if a_un_joueur_local() and est_serveur():
		noms[1] = nom_joueur
		fiches[1] = fiche_a_envoyer()
	return OK


## Client : se connecte au bon serveur (la ville, ou le donjon où l'on va).
func _connecter_client(hote: String, attendre_le_serveur: bool) -> Error:
	_choisir_port_pour_la_scene()
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_client(hote, port)
	if erreur != OK:
		statut_change.emit("Adresse invalide")
		return erreur
	multiplayer.multiplayer_peer = pair
	# Un serveur qu'on vient de lancer met quelques secondes à s'ouvrir : on réessaie.
	_reessayer_jusqua = Time.get_ticks_msec() / 1000.0 + (90.0 if attendre_le_serveur else 0.0)
	if scene_instance != "":
		_reessayer_jusqua = Time.get_ticks_msec() / 1000.0 + 20.0
	statut_change.emit("Connexion à %s…" % (nom_instance if scene_instance != "" else hote))
	return OK


## En donjon, on se connecte au serveur du donjon ; ailleurs, à celui de la ville.
func _choisir_port_pour_la_scene() -> void:
	if scene_instance == "":
		return
	if _scene_courante() != scene_instance:
		# On a quitté le donjon (sortie, retour au QG…) : retour au serveur de la ville.
		scene_instance = ""
		nom_instance = ""
		port = port_hub


func _scene_courante() -> String:
	var partie := get_tree().get_first_node_in_group("partie")
	if partie != null and partie.get_parent() != null:
		return partie.get_parent().scene_file_path
	return get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""


## Vrai si on joue dans un donjon privé avec son groupe.
func en_instance() -> bool:
	return scene_instance != ""


## Chez le joueur : part dans le donjon ouvert par la ville sur « port_donjon ».
func aller_en_instance(port_donjon: int, scene: String, nom_donjon: String) -> void:
	if scene_instance == "":
		port_hub = port
	scene_instance = scene
	nom_instance = nom_donjon
	port = port_donjon
	_fermer_connexion()
	get_tree().change_scene_to_file(scene)


## Chez le joueur : quitte le donjon et revient au QG de la Vigie, en ville.
func quitter_instance() -> void:
	if scene_instance == "":
		return
	scene_instance = ""
	nom_instance = ""
	port = port_hub
	set_meta("arrivee_hub", "portails")
	_fermer_connexion()
	get_tree().change_scene_to_file(SCENE_HUB)


func _fermer_connexion() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Arguments pour lancer un autre programme du jeu sans fenêtre (serveur, donjon).
func arguments_serveur(port_serveur: int, en_plus: Array = []) -> PackedStringArray:
	var liste := PackedStringArray(["--headless"])
	if OS.has_feature("editor"):
		# Lancé depuis Godot (F5) ou par le serveur Oracle : il faut dire où est le projet.
		liste.append_array(["--path", ProjectSettings.globalize_path("res://")])
	liste.append_array(["--max-fps", "30", "--", "--serveur", "--port=%d" % port_serveur])
	for a in en_plus:
		liste.append(String(a))
	return liste


## Vrai si personne n'écoute sur ce port de ce PC.
static func port_libre(numero: int) -> bool:
	var essai := ENetMultiplayerPeer.new()
	var libre := essai.create_server(numero, 1) == OK
	essai.close()
	return libre


## « Héberger » : lance le serveur sans fenêtre sur ce PC (s'il ne tourne pas déjà).
func _demarrer_serveur_local() -> bool:
	if _processus_serveur > 0 and OS.is_process_running(_processus_serveur):
		return true
	if not port_libre(port):
		# Un serveur tourne déjà sur ce port (lancé par une autre fenêtre) : on le rejoint.
		return true
	_processus_serveur = OS.create_process(OS.get_executable_path(), arguments_serveur(port, ["--auto-arret"]))
	print("Serveur lancé en arrière-plan (port %d, processus %d)" % [port, _processus_serveur])
	return _processus_serveur > 0


func _arreter_serveur_local() -> void:
	if _processus_serveur > 0 and OS.is_process_running(_processus_serveur):
		OS.kill(_processus_serveur)
	_processus_serveur = -1


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST or quoi == NOTIFICATION_PREDELETE:
		_arreter_serveur_local()
		if instance and fichier_statut != "":
			DirAccess.remove_absolute(fichier_statut)


func _process(delta: float) -> void:
	if mode != Mode.SERVEUR_DEDIE:
		return
	# Donjon (ou serveur de « Héberger ») : il s'éteint quand il est vide depuis un
	# moment (30 s pour un donjon, 1 min sinon ; 3 min si personne n'est jamais venu).
	if arret_automatique:
		if noms.is_empty():
			_vide_depuis += delta
			if _vide_depuis > ((30.0 if instance else 60.0) if _a_eu_un_joueur else 180.0):
				print("Serveur vide : arrêt.")
				if fichier_statut != "":
					DirAccess.remove_absolute(fichier_statut)
				get_tree().quit()
		else:
			_vide_depuis = 0.0
			_a_eu_un_joueur = true


## La fiche de ce PC, complétée si besoin (personnage par défaut pour les tests
## et le serveur dédié) et avec le nom choisi.
func fiche_a_envoyer() -> Dictionary:
	var f := FichePersonnage.valider(fiche, Donnees.creation)
	if FichePersonnage.erreur_nom(nom_joueur) == "":
		f["nom"] = FichePersonnage.nettoyer_nom(nom_joueur)
	return f


func quitter() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_arreter_serveur_local()
	scene_instance = ""
	nom_instance = ""
	if port_hub != 0:
		port = port_hub
		port_hub = 0
	noms.clear()
	fiches.clear()
	get_tree().change_scene_to_file(SCENE_MENU)


func _sur_pair_connecte(id: int) -> void:
	# Le nouveau venu donne son nom au serveur dès qu'il est connecté.
	if id == 1 and not est_serveur():
		_se_presenter.rpc_id(1, nom_joueur, fiche_a_envoyer())


@rpc("any_peer", "call_remote", "reliable")
func _se_presenter(nom: String, fiche_recue: Dictionary) -> void:
	if not est_serveur():
		return
	var id := multiplayer.get_remote_sender_id()
	noms[id] = nom.strip_edges().left(20) if nom.strip_edges() != "" else "Agent %d" % id
	# Deux joueurs ne portent jamais le même nom (la discussion et les groupes s'en
	# servent) : le second « Léa » devient « Léa 2 ».
	var base: String = noms[id]
	var numero := 2
	while _nom_pris(noms[id], id):
		noms[id] = "%s %d" % [base.left(17), numero]
		numero += 1
	# Le serveur ne fait pas confiance à la fiche reçue : il la vérifie.
	fiches[id] = FichePersonnage.valider(fiche_recue, Donnees.creation)
	print("%s a rejoint la partie (%d joueurs)" % [noms[id], noms.size()])
	_ecrire_statut()
	joueur_arrive.emit(id, noms[id])
	var monde := get_tree().get_first_node_in_group("partie")
	if monde != null and monde.has_method("ajouter_joueur"):
		monde.ajouter_joueur(id, noms[id])


func _nom_pris(nom: String, sauf: int) -> bool:
	for autre in noms:
		if autre != sauf and String(noms[autre]).to_lower() == nom.to_lower():
			return true
	return false


func _sur_pair_deconnecte(id: int) -> void:
	if not est_serveur():
		return
	if noms.has(id):
		print("%s a quitté la partie" % noms[id])
		joueur_parti.emit(id, noms[id])
	noms.erase(id)
	fiches.erase(id)
	_ecrire_statut()
	var monde := get_tree().get_first_node_in_group("partie")
	if monde != null and monde.has_method("retirer_joueur"):
		monde.retirer_joueur(id)


## Serveur dédié : écrit le nombre de joueurs connectés (voir « --statut »).
func ecrire_statut() -> void:
	_ecrire_statut()


func _ecrire_statut() -> void:
	if fichier_statut == "" or mode != Mode.SERVEUR_DEDIE:
		return
	var f := FileAccess.open(fichier_statut, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"joueurs": noms.size() + joueurs_ailleurs,
			"en_ville": noms.size(), "en_donjon": joueurs_ailleurs,
			"noms": noms.values(), "heure": Time.get_datetime_string_from_system(true)}))


func _sur_echec() -> void:
	if Time.get_ticks_msec() / 1000.0 < _reessayer_jusqua:
		# Le serveur démarre encore : on retente dans une seconde.
		statut_change.emit("Le serveur démarre…")
		get_tree().create_timer(1.0).timeout.connect(func():
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				var pair := ENetMultiplayerPeer.new()
				if pair.create_client("127.0.0.1" if mode == Mode.HEBERGER else adresse, port) == OK:
					multiplayer.multiplayer_peer = pair)
		return
	if scene_instance != "":
		# Le donjon ne répond plus : retour en ville.
		push_warning("Le donjon ne répond plus : retour en ville.")
		quitter_instance()
		return
	statut_change.emit("Connexion impossible")
	_retour_menu(("Aucun serveur ne répond à %s:%d. Pour jouer à plusieurs, un joueur doit "
			+ "d'abord cliquer sur « Héberger » ; pour jouer seul, clique sur « Jouer seul ».") % [adresse, port])


func _sur_serveur_perdu() -> void:
	if scene_instance != "":
		quitter_instance()
		return
	_retour_menu("Le serveur a fermé la partie.")


func _retour_menu(raison: String) -> void:
	push_warning(raison)
	set_meta("message_menu", raison)
	quitter()
