extends Node
## Gère la connexion entre les joueurs.
##
## Trois façons de jouer :
## - « seul » : tout se passe sur ton PC, sans réseau ;
## - « héberger » : ton PC est le serveur ET tu joues dessus, tes amis te rejoignent ;
## - « rejoindre » : tu te connectes au serveur d'un autre joueur (son adresse IP).
## Un serveur « dédié » (sans fenêtre, sans joueur) se lance avec :
##   godot --headless --path game -- --serveur [--port=7777]
##
## Règle d'or : le SERVEUR décide de tout ce qui compte (vie, dégâts, loups).
## Chaque joueur envoie seulement ses déplacements et ses demandes (« je lance
## telle compétence »), et le serveur vérifie qu'elles sont permises.

signal statut_change(texte: String)

enum Mode { SEUL, HEBERGER, REJOINDRE, SERVEUR_DEDIE }

const PORT_PAR_DEFAUT := 7777
const JOUEURS_MAX := 32
const SCENE_MONDE := "res://scenes/monde/colline_de_test.tscn"
const SCENE_MENU := "res://scenes/interface/menu.tscn"

var mode := Mode.SEUL
var adresse := "127.0.0.1"
var port := PORT_PAR_DEFAUT
var nom_joueur := "Agent"
## Sur le serveur : identifiant réseau -> nom du joueur.
var noms := {}


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--port="):
			port = int(argument.get_slice("=", 1))
		elif argument.begins_with("--nom="):
			nom_joueur = argument.get_slice("=", 1)
		elif argument.begins_with("--rejoindre="):
			mode = Mode.REJOINDRE
			adresse = argument.get_slice("=", 1)
	if "--serveur" in arguments:
		mode = Mode.SERVEUR_DEDIE
	multiplayer.peer_connected.connect(_sur_pair_connecte)
	multiplayer.peer_disconnected.connect(_sur_pair_deconnecte)
	multiplayer.connected_to_server.connect(func(): statut_change.emit("Connecté"))
	multiplayer.connection_failed.connect(_sur_echec)
	multiplayer.server_disconnected.connect(_sur_serveur_perdu)


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
		Mode.HEBERGER, Mode.SERVEUR_DEDIE:
			var pair := ENetMultiplayerPeer.new()
			var erreur := pair.create_server(port, JOUEURS_MAX)
			if erreur != OK:
				statut_change.emit("Impossible d'ouvrir le port %d (déjà utilisé ?)" % port)
				return erreur
			multiplayer.multiplayer_peer = pair
			print("Serveur SickWorld ouvert sur le port %d" % port)
		Mode.REJOINDRE:
			var pair := ENetMultiplayerPeer.new()
			var erreur := pair.create_client(adresse, port)
			if erreur != OK:
				statut_change.emit("Adresse invalide")
				return erreur
			multiplayer.multiplayer_peer = pair
			statut_change.emit("Connexion à %s…" % adresse)
	if a_un_joueur_local() and est_serveur():
		noms[1] = nom_joueur
	return OK


func quitter() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	noms.clear()
	get_tree().change_scene_to_file(SCENE_MENU)


func _sur_pair_connecte(id: int) -> void:
	# Le nouveau venu donne son nom au serveur dès qu'il est connecté.
	if id == 1 and not est_serveur():
		_se_presenter.rpc_id(1, nom_joueur)


@rpc("any_peer", "call_remote", "reliable")
func _se_presenter(nom: String) -> void:
	if not est_serveur():
		return
	var id := multiplayer.get_remote_sender_id()
	noms[id] = nom.strip_edges().left(20) if nom.strip_edges() != "" else "Agent %d" % id
	print("%s a rejoint la partie (%d joueurs)" % [noms[id], noms.size()])
	var monde := get_tree().get_first_node_in_group("partie")
	if monde != null and monde.has_method("ajouter_joueur"):
		monde.ajouter_joueur(id, noms[id])


func _sur_pair_deconnecte(id: int) -> void:
	if not est_serveur():
		return
	if noms.has(id):
		print("%s a quitté la partie" % noms[id])
	noms.erase(id)
	var monde := get_tree().get_first_node_in_group("partie")
	if monde != null and monde.has_method("retirer_joueur"):
		monde.retirer_joueur(id)


func _sur_echec() -> void:
	statut_change.emit("Connexion impossible")
	_retour_menu("Impossible de joindre le serveur %s:%d." % [adresse, port])


func _sur_serveur_perdu() -> void:
	_retour_menu("Le serveur a fermé la partie.")


func _retour_menu(raison: String) -> void:
	push_warning(raison)
	set_meta("message_menu", raison)
	quitter()
