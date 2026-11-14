extends Node
## Gère la connexion entre les joueurs.
##
## Trois façons de jouer :
## - « seul » : tout se passe sur ton PC, sans réseau ;
## - « héberger » : ton PC est le serveur ET tu joues dessus, tes amis te rejoignent ;
## - « rejoindre » : tu te connectes au serveur d'un autre joueur (son adresse IP).
## Un serveur « dédié » (sans fenêtre, sans joueur) se lance avec :
##   godot --headless --path game -- --serveur [--port=7777] [--statut=fichier.json]
## (« --statut » : le serveur y écrit le nombre de joueurs connectés, lu par les
## scripts du serveur Oracle Cloud pour ne pas redémarrer pendant une partie.)
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
	if "--colline" in arguments:
		scene_depart = SCENE_MONDE
	if "--serveur" in arguments:
		mode = Mode.SERVEUR_DEDIE
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
		Mode.HEBERGER, Mode.SERVEUR_DEDIE:
			var pair := ENetMultiplayerPeer.new()
			var erreur := pair.create_server(port, JOUEURS_MAX)
			if erreur != OK:
				statut_change.emit("Impossible d'ouvrir le port %d (déjà utilisé ?)" % port)
				return erreur
			multiplayer.multiplayer_peer = pair
			print("Serveur SickWorld ouvert sur le port %d" % port)
			_ecrire_statut()
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
		fiches[1] = fiche_a_envoyer()
	return OK


## La fiche de ce PC, complétée si besoin (personnage par défaut pour les tests
## et le serveur dédié) et avec le nom choisi.
func fiche_a_envoyer() -> Dictionary:
	var f := FichePersonnage.valider(fiche, Donnees.creation)
	if FichePersonnage.erreur_nom(nom_joueur) == "":
		f["nom"] = FichePersonnage.nettoyer_nom(nom_joueur)
	return f


func quitter() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
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
	# Le serveur ne fait pas confiance à la fiche reçue : il la vérifie.
	fiches[id] = FichePersonnage.valider(fiche_recue, Donnees.creation)
	print("%s a rejoint la partie (%d joueurs)" % [noms[id], noms.size()])
	_ecrire_statut()
	var monde := get_tree().get_first_node_in_group("partie")
	if monde != null and monde.has_method("ajouter_joueur"):
		monde.ajouter_joueur(id, noms[id])


func _sur_pair_deconnecte(id: int) -> void:
	if not est_serveur():
		return
	if noms.has(id):
		print("%s a quitté la partie" % noms[id])
	noms.erase(id)
	fiches.erase(id)
	_ecrire_statut()
	var monde := get_tree().get_first_node_in_group("partie")
	if monde != null and monde.has_method("retirer_joueur"):
		monde.retirer_joueur(id)


## Serveur dédié : écrit le nombre de joueurs connectés (voir « --statut »).
func _ecrire_statut() -> void:
	if fichier_statut == "" or mode != Mode.SERVEUR_DEDIE:
		return
	var f := FileAccess.open(fichier_statut, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"joueurs": noms.size(),
			"noms": noms.values(), "heure": Time.get_datetime_string_from_system(true)}))


func _sur_echec() -> void:
	statut_change.emit("Connexion impossible")
	_retour_menu(("Aucun serveur ne répond à %s:%d. Pour jouer à plusieurs, un joueur doit "
			+ "d'abord cliquer sur « Héberger » ; pour jouer seul, clique sur « Jouer seul ».") % [adresse, port])


func _sur_serveur_perdu() -> void:
	_retour_menu("Le serveur a fermé la partie.")


func _retour_menu(raison: String) -> void:
	push_warning(raison)
	set_meta("message_menu", raison)
	quitter()
