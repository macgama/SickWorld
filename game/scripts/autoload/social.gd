extends Node
## La vie sociale entre joueurs, façon World of Warcraft : la DISCUSSION (chat)
## et les GROUPES (jusqu'à 5 joueurs), et l'entrée en DONJON avec son groupe.
##
## Discussion — touche Entrée pour écrire, Entrée pour envoyer, Échap pour annuler.
## Canaux (on change de canal en commençant le message par sa commande) :
##   /d  Dire       les joueurs à moins de 40 m (une bulle apparaît au-dessus de la tête)
##   /z  Zone       les joueurs du même quartier (Place Hikari, QG de la Vigie…)
##   /1  Général    tous les joueurs du serveur
##   /gr Groupe     les membres de son groupe
##   /gu Guilde     les membres de sa guilde (fondée au registraire de la Maison des guildes)
##   /w Nom texte   chuchoter (message privé) ; /r texte : répondre au dernier qui a chuchoté
## Groupes : /inviter Nom, /quitter, /chef Nom, /exclure Nom (ou les boutons à l'écran).
## Donjons : touche K (le chef choisit le donjon, tout le groupe y part ensemble).
##
## Comme pour le combat, c'est le SERVEUR qui décide : il vérifie chaque message
## (longueur, rythme anti-spam), choisit qui le reçoit, et tient la liste des groupes.
## Les joueurs ne font qu'envoyer des demandes.
##
## Les réglages (taille des groupes, donjons proposés) sont dans data/donjons.json.

## Chez le joueur : un message vient d'arriver dans la discussion.
signal message_recu(canal: String, auteur: String, texte: String)
## Chez le joueur : la composition du groupe a changé.
signal groupe_change
## Chez le joueur : quelqu'un nous invite dans son groupe ("" = l'invitation est finie).
signal invitation_changee(de: String)
## Chez le joueur : le groupe part en donjon (pour le fondu à l'écran).
signal depart_en_donjon(nom_donjon: String)
## Chez le joueur : un joueur proche parle (« Dire ») : bulle au-dessus de sa tête.
signal bulle(id_joueur: int, texte: String)

const FICHIER_DONJONS := "res://data/donjons.json"
const SCRIPT_INTERFACE := "res://scripts/interface/interface_sociale.gd"

## Nom et couleur de chaque canal (les couleurs sont celles de WoW).
const CANAUX := {
	"dire": {"nom": "Dire", "couleur": Color(1, 1, 1)},
	"zone": {"nom": "Zone", "couleur": Color(1, 0.75, 0.6)},
	"general": {"nom": "Général", "couleur": Color(0.95, 0.82, 0.5)},
	"groupe": {"nom": "Groupe", "couleur": Color(0.55, 0.7, 1)},
	"guilde": {"nom": "Guilde", "couleur": Color(0.37, 0.88, 0.37)},
	"prive": {"nom": "Chuchoter", "couleur": Color(1, 0.5, 1)},
	"systeme": {"nom": "", "couleur": Color(1, 0.88, 0.3)},
}
## Commandes tapées au début d'un message -> canal.
const COMMANDES_CANAUX := {
	"d": "dire", "dire": "dire", "s": "dire", "say": "dire",
	"z": "zone", "zone": "zone",
	"1": "general", "g": "general", "general": "general", "général": "general",
	"gr": "groupe", "p": "groupe", "groupe": "groupe", "party": "groupe",
	"gu": "guilde", "guilde": "guilde", "guild": "guilde",
}
## Distance (mètres) jusqu'à laquelle on entend « Dire ».
const PORTEE_DIRE := 40.0
## Distance (mètres) jusqu'à laquelle les membres du groupe partagent le butin.
const PORTEE_BUTIN := 60.0
const LONGUEUR_MAX := 200
## Anti-spam : au plus MESSAGES_MAX messages par FENETRE_SPAM secondes.
const MESSAGES_MAX := 6
const FENETRE_SPAM := 8.0
const DUREE_INVITATION := 60.0
## Un membre déconnecté reste dans le groupe 5 minutes (4 heures s'il est en donjon).
const ABSENCE_MAX := 300.0
const ABSENCE_DONJON := 4.0 * 3600.0
const HISTORIQUE_MAX := 120

var donnees := {}
var taille_max_groupe := 5

# --- Chez le serveur ---
## numéro -> {"chef": nom, "membres": [noms], "absents": {clé: fin}, "donjon": {clé: nom du donjon}}
var _groupes := {}
## clé (nom en minuscules) -> numéro du groupe
var _groupe_de := {}
## clé de l'invité -> {"de": nom, "fin": temps}
var _invitations := {}
## identifiant réseau -> nom de sa guilde
var _guildes := {}
## identifiant réseau -> temps de ses derniers messages (anti-spam)
var _envois := {}
var _compteur_groupes := 0
var _instances: Node
var _minuteur := 0.0

# --- Chez le joueur ---
## Les membres du groupe : [{nom, chef, id (0 = pas sur ce serveur), classe, etat}]
## etat : "ici", "ailleurs" (déconnecté), "donjon" (parti dans un donjon).
var groupe: Array = []
## Les derniers messages : [{canal, auteur, texte}]
var historique: Array = []
var dernier_chuchoteur := ""
## Qui nous invite en ce moment ("" = personne).
var invitation_de := ""
## Canal utilisé quand on n'en précise pas (le dernier utilisé, comme dans WoW).
var canal_actif := "dire"
var _interface: Node
var _guilde_annoncee := ""


func _ready() -> void:
	var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_DONJONS)) if FileAccess.file_exists(FICHIER_DONJONS) else null
	donnees = lu if lu is Dictionary else {}
	taille_max_groupe = int(donnees.get("reglages", {}).get("joueurs_max", 5))
	Reseau.joueur_arrive.connect(_sur_arrivee)
	Reseau.joueur_parti.connect(_sur_depart)
	_instances = preload("res://scripts/social/instances.gd").new()
	_instances.name = "Instances"
	add_child(_instances)
	multiplayer.server_disconnected.connect(_oublier_le_groupe)


func _process(delta: float) -> void:
	_minuteur += delta
	if _minuteur < 0.5:
		return
	_minuteur = 0.0
	_installer_interface()
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_nettoyer()


# =============================================================================
# Côté joueur : ce que l'interface appelle
# =============================================================================

## Liste des donjons proposés (data/donjons.json).
func donjons() -> Array:
	return donnees.get("donjons", [])


func donjon(id: String) -> Dictionary:
	for d in donjons():
		if String(d.get("id", "")) == id:
			return d
	return {}


## Notre nom de joueur.
func mon_nom() -> String:
	# Le nom vu par le serveur (celui de la plaque au-dessus de la tête).
	var joueur := get_tree().get_first_node_in_group("joueur_local")
	var combat = joueur.get_node_or_null("Combat") if joueur != null else null
	if combat != null and String(combat.nom_affiche) not in ["", "?"]:
		return String(combat.nom_affiche)
	return Reseau.nom_joueur


func est_dans_un_groupe() -> bool:
	return groupe.size() > 1


func suis_chef() -> bool:
	for m in groupe:
		if bool(m.get("chef", false)):
			return String(m["nom"]).to_lower() == mon_nom().to_lower()
	return false


func est_membre(nom: String) -> bool:
	for m in groupe:
		if String(m["nom"]).to_lower() == nom.to_lower():
			return true
	return false


## Ce que le joueur a tapé dans la zone de discussion (texte ou commande « /… »).
func saisir(texte: String) -> void:
	texte = texte.strip_edges()
	if texte == "":
		return
	if not texte.begins_with("/"):
		envoyer(canal_actif, texte)
		return
	var commande := texte.substr(1).get_slice(" ", 0).to_lower()
	var reste := texte.substr(commande.length() + 2).strip_edges() if texte.length() > commande.length() + 1 else ""
	var premier := reste.get_slice(" ", 0)
	var apres_premier := reste.substr(premier.length()).strip_edges()
	if COMMANDES_CANAUX.has(commande):
		canal_actif = COMMANDES_CANAUX[commande]
		if reste != "":
			envoyer(canal_actif, reste)
		return
	match commande:
		"w", "mp", "chuchoter", "whisper", "t", "tell":
			if premier == "" or apres_premier == "":
				_systeme("Pour chuchoter : /w Nom message")
			else:
				envoyer("prive", apres_premier, premier)
		"r", "repondre", "répondre", "reply":
			if dernier_chuchoteur == "":
				_systeme("Personne ne t'a encore chuchoté de message.")
			elif reste != "":
				envoyer("prive", reste, dernier_chuchoteur)
		"inviter", "invite", "inv":
			inviter(premier)
		"quitter", "leave":
			quitter_le_groupe()
		"chef", "lead":
			nommer_chef(premier)
		"exclure", "kick":
			exclure(premier)
		"duel", "defier", "défier", "defi", "défi":
			JcJ.defier(premier)
		"arene", "arène", "jcj", "pvp":
			JcJ.basculer_fenetre()
		"donjon", "donjons":
			if _interface != null and _interface.has_method("basculer_donjons"):
				_interface.basculer_donjons()
		"aide", "help", "?":
			_systeme(_texte_aide())
		_:
			_systeme("Commande inconnue : /%s (tape /aide pour la liste)" % commande)


func _texte_aide() -> String:
	return ("Canaux : /d Dire (40 m) · /z Zone · /1 Général · /gr Groupe · /gu Guilde · /w Nom message (chuchoter) · /r répondre\n"
			+ "Groupe : /inviter Nom · /quitter · /chef Nom · /exclure Nom · K : donjons\n"
			+ "Arène : /duel Nom (défier) · /arene ou H : files d'attente 1c1 / 2c2 et classement")


func envoyer(canal: String, texte: String, destinataire := "") -> void:
	if not CANAUX.has(canal) or canal == "systeme":
		return
	Regles.au_serveur(self, "_demander_envoi", [canal, texte.left(LONGUEUR_MAX), destinataire])


func inviter(nom: String) -> void:
	if nom.strip_edges() == "":
		_systeme("Pour inviter : /inviter Nom (ou cible le joueur et clique sur « Inviter »).")
		return
	Regles.au_serveur(self, "_demander_invitation", [nom.strip_edges()])


func repondre_invitation(accepter: bool) -> void:
	invitation_de = ""
	invitation_changee.emit("")
	Regles.au_serveur(self, "_demander_reponse", [accepter])


func quitter_le_groupe() -> void:
	Regles.au_serveur(self, "_demander_depart", [])


func nommer_chef(nom: String) -> void:
	Regles.au_serveur(self, "_demander_chef", [nom.strip_edges()])


func exclure(nom: String) -> void:
	Regles.au_serveur(self, "_demander_exclusion", [nom.strip_edges()])


## Le chef (ou un joueur seul) demande à entrer dans un donjon avec son groupe.
func entrer_en_donjon(id_donjon: String) -> void:
	if Reseau.mode == Reseau.Mode.SEUL:
		_systeme("Les donjons en groupe se font en multijoueur (Héberger ou Rejoindre). En solo, passe par le portail du QG de la Vigie.")
		return
	if Reseau.en_instance():
		_systeme("Tu es déjà dans un donjon. Quitte-le d'abord.")
		return
	Regles.au_serveur(self, "_demander_donjon", [id_donjon, _ma_progression()])


func quitter_le_donjon() -> void:
	Reseau.quitter_instance()


## Notre progression dans l'histoire (le donjon suit celle du chef). Seulement des
## valeurs simples (textes, nombres) : le serveur n'accepte rien d'autre.
func _ma_progression() -> Dictionary:
	var cfg := ConfigFile.new()
	var sortie := {}
	if cfg.load(Profil.chemin("user://progression.cfg")) != OK:
		return sortie
	for section in cfg.get_sections():
		var valeurs := {}
		for cle in cfg.get_section_keys(section):
			var v = cfg.get_value(section, cle)
			if typeof(v) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
				valeurs[cle] = v
		sortie[section] = valeurs
	return sortie


## Nom de notre guilde (fondée dans l'appartement, section [guilde] de la sauvegarde).
func ma_guilde() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(Profil.chemin("user://progression.cfg")) != OK:
		return ""
	return String(cfg.get_value("guilde", "nom", ""))


func _systeme(texte: String) -> void:
	_ajouter("systeme", "", texte)


func _ajouter(canal: String, auteur: String, texte: String) -> void:
	historique.append({"canal": canal, "auteur": auteur, "texte": texte})
	if historique.size() > HISTORIQUE_MAX:
		historique.pop_front()
	message_recu.emit(canal, auteur, texte)


## L'interface (discussion + cadres du groupe) apparaît dans chaque partie.
func _installer_interface() -> void:
	if _interface != null and is_instance_valid(_interface):
		return
	_interface = null
	if not Reseau.a_un_joueur_local():
		return
	var partie := get_tree().get_first_node_in_group("partie")
	if partie == null or get_tree().get_first_node_in_group("joueur_local") == null:
		return
	_interface = load(SCRIPT_INTERFACE).new()
	_interface.name = "InterfaceSociale"
	partie.add_child(_interface)
	# On redit au serveur le nom de notre guilde (il a pu changer, ou c'est un nouveau serveur).
	_guilde_annoncee = ma_guilde()
	Regles.au_serveur(self, "_annoncer_guilde", [_guilde_annoncee])
	if historique.is_empty():
		_systeme("Bienvenue. Appuie sur Entrée pour discuter, tape /aide pour les commandes.")
	if Reseau.en_instance():
		_systeme("Tu entres dans %s avec ton groupe. Cette copie du donjon n'appartient qu'à vous." % Reseau.nom_instance)


func _oublier_le_groupe() -> void:
	if Reseau.en_instance():
		return
	groupe = []
	groupe_change.emit()


# =============================================================================
# Chez le joueur : ce que le serveur nous envoie
# =============================================================================

func _vient_du_serveur() -> bool:
	return multiplayer.get_remote_sender_id() in [0, 1]


@rpc("authority", "call_remote", "reliable")
func _recevoir(canal: String, auteur: String, texte: String, id_auteur: int) -> void:
	if not _vient_du_serveur():
		return
	if canal == "prive":
		dernier_chuchoteur = auteur
	_ajouter(canal, auteur, texte)
	if canal == "dire":
		bulle.emit(id_auteur, texte)


@rpc("authority", "call_remote", "reliable")
func _recevoir_groupe(membres: Array) -> void:
	if not _vient_du_serveur():
		return
	groupe = membres
	groupe_change.emit()


@rpc("authority", "call_remote", "reliable")
func _recevoir_invitation(de: String) -> void:
	if not _vient_du_serveur():
		return
	invitation_de = de
	invitation_changee.emit(de)
	_systeme("%s t'invite dans son groupe." % de)


@rpc("authority", "call_remote", "reliable")
func _partir_en_donjon(port: int, scene: String, nom_donjon: String) -> void:
	if not _vient_du_serveur() or not scene.begins_with("res://scenes/monde/"):
		return
	depart_en_donjon.emit(nom_donjon)
	# Un court fondu au noir (géré par l'interface), puis le voyage.
	get_tree().create_timer(1.2).timeout.connect(func(): Reseau.aller_en_instance(port, scene, nom_donjon))


# =============================================================================
# Côté serveur : les demandes des joueurs
# =============================================================================

func _nom_de(id: int) -> String:
	return String(Reseau.noms.get(id, ""))


func _id_de(nom: String) -> int:
	var cle := nom.strip_edges().to_lower()
	for id in Reseau.noms:
		if String(Reseau.noms[id]).to_lower() == cle:
			return int(id)
	return 0


func _au_joueur(id: int, canal: String, auteur: String, texte: String, id_auteur := 0) -> void:
	if id > 0:
		Regles.chez(id, self, "_recevoir", [canal, auteur, texte, id_auteur])


func _au_joueur_systeme(id: int, texte: String) -> void:
	_au_joueur(id, "systeme", "", texte)


## Le personnage d'un joueur dans la partie (pour savoir où il est).
func _personnage(id: int) -> Node3D:
	for j in get_tree().get_nodes_in_group("joueur"):
		if j.name == str(id):
			return j as Node3D
	return null


func _nettoyer_texte(texte: String) -> String:
	var propre := ""
	for i in texte.length():
		var c := texte.unicode_at(i)
		if c >= 32 and c != 127:
			propre += texte[i]
	return propre.strip_edges().left(LONGUEUR_MAX)


func _trop_de_messages(id: int) -> bool:
	var t := Regles.maintenant()
	var liste: Array = _envois.get(id, [])
	liste = liste.filter(func(x): return t - float(x) < FENETRE_SPAM)
	if liste.size() >= MESSAGES_MAX:
		_envois[id] = liste
		return true
	liste.append(t)
	_envois[id] = liste
	return false


@rpc("any_peer", "call_remote", "reliable")
func _demander_envoi(canal: String, texte: String, destinataire: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	var auteur := _nom_de(id)
	texte = _nettoyer_texte(texte)
	if auteur == "" or texte == "" or not CANAUX.has(canal) or canal == "systeme":
		return
	if _trop_de_messages(id):
		_au_joueur_systeme(id, "Doucement ! Attends quelques secondes avant d'envoyer un autre message.")
		return
	var destinataires: Array = []
	match canal:
		"dire":
			var moi := _personnage(id)
			for autre in Reseau.noms:
				var p := _personnage(int(autre))
				if moi == null or (p != null and p.global_position.distance_to(moi.global_position) <= PORTEE_DIRE):
					destinataires.append(int(autre))
		"zone":
			var ma_zone := _zone_de(id)
			for autre in Reseau.noms:
				if _zone_de(int(autre)) == ma_zone:
					destinataires.append(int(autre))
		"general":
			destinataires = Reseau.noms.keys()
		"groupe":
			var numero := int(_groupe_de.get(auteur.to_lower(), 0))
			if numero == 0:
				_au_joueur_systeme(id, "Tu n'es pas dans un groupe.")
				return
			for nom in _groupes[numero]["membres"]:
				var autre := _id_de(nom)
				if autre != 0:
					destinataires.append(autre)
		"guilde":
			var ma_guilde: String = _guildes.get(id, "")
			if ma_guilde == "":
				_au_joueur_systeme(id, "Tu n'as pas de guilde. Fonde-la au registraire de la Maison des guildes.")
				return
			for autre in _guildes:
				if String(_guildes[autre]).to_lower() == ma_guilde.to_lower() and Reseau.noms.has(autre):
					destinataires.append(int(autre))
		"prive":
			var cible := _id_de(destinataire)
			if cible == 0:
				_au_joueur_systeme(id, "Personne ne s'appelle « %s » sur ce serveur." % _nettoyer_texte(destinataire).left(24))
				return
			_au_joueur(cible, "prive", auteur, texte, id)
			if cible != id:
				_au_joueur(id, "prive_envoye", _nom_de(cible), texte, id)
			return
	for autre in destinataires:
		_au_joueur(int(autre), canal, auteur, texte, id)


## Le quartier où se trouve un joueur (zones de la carte), pour le canal « Zone ».
func _zone_de(id: int) -> String:
	var p := _personnage(id)
	if p == null:
		return ""
	var zone: Node3D = Cartographe.zone_pour(p.global_position)
	return String(zone.get("identifiant")) if zone != null else ""


@rpc("any_peer", "call_remote", "reliable")
func _annoncer_guilde(nom_guilde: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	nom_guilde = _nettoyer_texte(nom_guilde).left(24)
	if nom_guilde == "":
		_guildes.erase(id)
	else:
		_guildes[id] = nom_guilde


# --- Groupes (serveur) ---------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _demander_invitation(nom: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	var moi := _nom_de(id)
	var cible := _id_de(nom)
	if moi == "":
		return
	if cible == 0:
		_au_joueur_systeme(id, "Personne ne s'appelle « %s » sur ce serveur." % _nettoyer_texte(nom).left(24))
		return
	if cible == id:
		_au_joueur_systeme(id, "Tu ne peux pas t'inviter toi-même.")
		return
	var invite := _nom_de(cible)
	var numero := int(_groupe_de.get(moi.to_lower(), 0))
	if _groupe_de.has(invite.to_lower()):
		_au_joueur_systeme(id, "%s fait déjà partie d'un groupe." % invite)
		return
	if numero != 0:
		var g: Dictionary = _groupes[numero]
		if String(g["chef"]).to_lower() != moi.to_lower():
			_au_joueur_systeme(id, "Seul le chef du groupe peut inviter.")
			return
		if g["membres"].size() >= taille_max_groupe:
			_au_joueur_systeme(id, "Ton groupe est complet (%d joueurs)." % taille_max_groupe)
			return
	_invitations[invite.to_lower()] = {"de": moi, "fin": Regles.maintenant() + DUREE_INVITATION}
	Regles.chez(cible, self, "_recevoir_invitation", [moi])
	_au_joueur_systeme(id, "Tu as invité %s dans ton groupe." % invite)


@rpc("any_peer", "call_remote", "reliable")
func _demander_reponse(accepter: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	var moi := _nom_de(id)
	var invitation: Dictionary = _invitations.get(moi.to_lower(), {})
	_invitations.erase(moi.to_lower())
	if invitation.is_empty():
		return
	var chef := String(invitation["de"])
	var id_chef := _id_de(chef)
	if not accepter:
		_au_joueur_systeme(id_chef, "%s a refusé ton invitation." % moi)
		return
	if _groupe_de.has(moi.to_lower()):
		return
	var numero := int(_groupe_de.get(chef.to_lower(), 0))
	if numero == 0:
		if id_chef == 0:
			_au_joueur_systeme(id, "%s n'est plus là." % chef)
			return
		numero = creer_groupe(chef, [chef])
	var g: Dictionary = _groupes[numero]
	if g["membres"].size() >= taille_max_groupe:
		_au_joueur_systeme(id, "Le groupe de %s est déjà complet." % chef)
		return
	g["membres"].append(moi)
	_groupe_de[moi.to_lower()] = numero
	_annoncer_au_groupe(numero, "%s rejoint le groupe." % moi)
	_diffuser_groupe(numero)


## Crée un groupe (serveur). Rend son numéro.
func creer_groupe(chef: String, membres: Array) -> int:
	_compteur_groupes += 1
	_groupes[_compteur_groupes] = {"chef": chef, "membres": [], "absents": {}, "donjon": {}}
	for nom in membres:
		_groupes[_compteur_groupes]["membres"].append(String(nom))
		_groupe_de[String(nom).to_lower()] = _compteur_groupes
	return _compteur_groupes


@rpc("any_peer", "call_remote", "reliable")
func _demander_depart() -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	var moi := _nom_de(id)
	if not _groupe_de.has(moi.to_lower()):
		_au_joueur_systeme(id, "Tu n'es pas dans un groupe.")
		return
	_retirer_du_groupe(moi, "%s a quitté le groupe.")
	_au_joueur_systeme(id, "Tu as quitté le groupe.")


@rpc("any_peer", "call_remote", "reliable")
func _demander_chef(nom: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	var moi := _nom_de(id)
	var numero := int(_groupe_de.get(moi.to_lower(), 0))
	if numero == 0 or String(_groupes[numero]["chef"]).to_lower() != moi.to_lower():
		_au_joueur_systeme(id, "Seul le chef du groupe peut nommer un nouveau chef.")
		return
	var vrai_nom := _nom_dans_groupe(numero, nom)
	if vrai_nom == "":
		_au_joueur_systeme(id, "%s n'est pas dans ton groupe." % _nettoyer_texte(nom).left(24))
		return
	_groupes[numero]["chef"] = vrai_nom
	_annoncer_au_groupe(numero, "%s est maintenant le chef du groupe." % vrai_nom)
	_diffuser_groupe(numero)


@rpc("any_peer", "call_remote", "reliable")
func _demander_exclusion(nom: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	var moi := _nom_de(id)
	var numero := int(_groupe_de.get(moi.to_lower(), 0))
	if numero == 0 or String(_groupes[numero]["chef"]).to_lower() != moi.to_lower():
		_au_joueur_systeme(id, "Seul le chef du groupe peut exclure quelqu'un.")
		return
	var vrai_nom := _nom_dans_groupe(numero, nom)
	if vrai_nom == "" or vrai_nom.to_lower() == moi.to_lower():
		_au_joueur_systeme(id, "%s n'est pas dans ton groupe." % _nettoyer_texte(nom).left(24))
		return
	_au_joueur_systeme(_id_de(vrai_nom), "Tu as été exclu du groupe.")
	_retirer_du_groupe(vrai_nom, "%s a été exclu du groupe.")


func _nom_dans_groupe(numero: int, nom: String) -> String:
	for m in _groupes[numero]["membres"]:
		if String(m).to_lower() == nom.strip_edges().to_lower():
			return String(m)
	return ""


## Retire un joueur de son groupe ; un groupe d'une seule personne est dissous.
func _retirer_du_groupe(nom: String, annonce: String) -> void:
	var cle := nom.to_lower()
	var numero := int(_groupe_de.get(cle, 0))
	if numero == 0:
		return
	_groupe_de.erase(cle)
	var g: Dictionary = _groupes[numero]
	var membres: Array = g["membres"]
	for i in membres.size():
		if String(membres[i]).to_lower() == cle:
			membres.remove_at(i)
			break
	g["absents"].erase(cle)
	g["donjon"].erase(cle)
	var id_parti := _id_de(nom)
	if id_parti != 0:
		Regles.chez(id_parti, self, "_recevoir_groupe", [[]])
	if membres.size() <= 1:
		for reste in membres:
			_groupe_de.erase(String(reste).to_lower())
			_au_joueur_systeme(_id_de(reste), "Le groupe est dissous.")
			Regles.chez(_id_de(reste), self, "_recevoir_groupe", [[]])
		_groupes.erase(numero)
		return
	if String(g["chef"]).to_lower() == cle:
		g["chef"] = _premier_present(numero)
		annonce += "\n%s devient le chef du groupe." % g["chef"]
	_annoncer_au_groupe(numero, annonce % nom)
	_diffuser_groupe(numero)


func _premier_present(numero: int) -> String:
	var g: Dictionary = _groupes[numero]
	for m in g["membres"]:
		if _id_de(m) != 0:
			return String(m)
	return String(g["membres"][0])


func _annoncer_au_groupe(numero: int, texte: String) -> void:
	for nom in _groupes.get(numero, {}).get("membres", []):
		_au_joueur_systeme(_id_de(nom), texte)


## Envoie à chaque membre présent la liste à jour du groupe.
func _diffuser_groupe(numero: int) -> void:
	if not _groupes.has(numero):
		return
	var g: Dictionary = _groupes[numero]
	var liste: Array = []
	for nom in g["membres"]:
		var id := _id_de(nom)
		var etat := "ici"
		if id == 0:
			etat = "donjon" if g["donjon"].has(String(nom).to_lower()) else "ailleurs"
		var classe := ""
		if id != 0:
			classe = String(Reseau.fiches.get(id, {}).get("classe", ""))
		liste.append({"nom": nom, "chef": String(nom).to_lower() == String(g["chef"]).to_lower(),
				"id": id, "classe": classe, "etat": etat,
				"donjon": String(g["donjon"].get(String(nom).to_lower(), ""))})
	for m in liste:
		if int(m["id"]) != 0:
			Regles.chez(int(m["id"]), self, "_recevoir_groupe", [liste])


func _sur_arrivee(id: int, nom: String) -> void:
	if not multiplayer.is_server():
		return
	# Serveur de donjon : le premier membre arrivé recrée le groupe attendu.
	if Reseau.instance and not Reseau.groupe_instance.is_empty() and _groupes.is_empty():
		var membres: Array = Reseau.groupe_instance.get("membres", [])
		var chef := String(Reseau.groupe_instance.get("chef", nom))
		if membres.size() > 1:
			var numero := creer_groupe(chef, membres)
			for m in membres:
				_groupes[numero]["absents"][String(m).to_lower()] = Regles.maintenant() + ABSENCE_MAX
	var numero := int(_groupe_de.get(nom.to_lower(), 0))
	if numero != 0:
		_groupes[numero]["absents"].erase(nom.to_lower())
		_groupes[numero]["donjon"].erase(nom.to_lower())
		_diffuser_groupe(numero)


func _sur_depart(id: int, nom: String) -> void:
	if not multiplayer.is_server():
		return
	_guildes.erase(id)
	_envois.erase(id)
	var cle := nom.to_lower()
	var numero := int(_groupe_de.get(cle, 0))
	if numero == 0:
		return
	var g: Dictionary = _groupes[numero]
	var en_donjon: bool = g["donjon"].has(cle)
	g["absents"][cle] = Regles.maintenant() + (ABSENCE_DONJON if en_donjon else ABSENCE_MAX)
	# Le nom n'est retiré de Reseau.noms qu'après ce signal : on rediffuse juste après.
	_diffuser_groupe.call_deferred(numero)


## Serveur : enlève les membres absents depuis trop longtemps et les vieilles invitations.
func _nettoyer() -> void:
	var t := Regles.maintenant()
	for cle in _invitations.keys():
		if t > float(_invitations[cle]["fin"]):
			_invitations.erase(cle)
	for numero in _groupes.keys():
		if not _groupes.has(numero):
			continue
		var absents: Dictionary = _groupes[numero]["absents"]
		for cle in absents.keys():
			if t > float(absents[cle]) and _groupes.has(numero):
				var nom := _nom_dans_groupe(numero, cle)
				if nom != "":
					_retirer_du_groupe(nom, "%s est parti depuis trop longtemps : il quitte le groupe.")


## Serveur : les membres du groupe d'un joueur, présents et proches d'un endroit
## (partage du butin : chacun reçoit son propre butin, comme le joueur qui a frappé).
func membres_proches(id: int, endroit: Vector3, rayon := PORTEE_BUTIN) -> Array:
	var resultat: Array = []
	var numero := int(_groupe_de.get(_nom_de(id).to_lower(), 0))
	if numero == 0:
		return resultat
	for nom in _groupes[numero]["membres"]:
		var autre := _id_de(nom)
		if autre == 0 or autre == id:
			continue
		var p := _personnage(autre)
		if p != null and p.global_position.distance_to(endroit) <= rayon:
			resultat.append(autre)
	return resultat


## Serveur : numéro du groupe d'un joueur (0 = aucun), pour les tests.
func groupe_du_joueur(nom: String) -> int:
	return int(_groupe_de.get(nom.to_lower(), 0))


func membres_du_groupe(numero: int) -> Array:
	return _groupes.get(numero, {}).get("membres", []).duplicate()


# --- Donjons (serveur) -----------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _demander_donjon(id_donjon: String, progression: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := Regles.expediteur()
	var moi := _nom_de(id)
	if moi == "":
		return
	if Reseau.instance:
		_au_joueur_systeme(id, "Tu es déjà dans un donjon.")
		return
	var d := donjon(id_donjon)
	if d.is_empty() or not ResourceLoader.exists(String(d.get("scene", ""))):
		_au_joueur_systeme(id, "Ce donjon n'existe pas encore.")
		return
	var numero := int(_groupe_de.get(moi.to_lower(), 0))
	var partants: Array = [moi]
	var chef := moi
	if numero != 0:
		var g: Dictionary = _groupes[numero]
		if String(g["chef"]).to_lower() != moi.to_lower():
			_au_joueur_systeme(id, "Seul le chef du groupe peut choisir le donjon.")
			return
		partants = []
		for nom in g["membres"]:
			if _id_de(nom) != 0:
				partants.append(String(nom))
	var port: int = _instances.lancer(d, {"chef": chef, "membres": partants}, _progression_propre(progression))
	if port <= 0:
		_au_joueur_systeme(id, "Tous les donjons du serveur sont occupés. Réessaie dans un moment.")
		return
	for nom in partants:
		_au_joueur_systeme(_id_de(nom), "Ouverture de %s pour ton groupe… (quelques secondes)" % d.get("nom", id_donjon))
	_attendre_le_donjon(port, d, partants, numero)


func _attendre_le_donjon(port: int, d: Dictionary, partants: Array, numero: int) -> void:
	var limite := Regles.maintenant() + 90.0
	while not _instances.prete(port):
		await get_tree().create_timer(0.5).timeout
		if Regles.maintenant() > limite or not _instances.tourne(port):
			for nom in partants:
				_au_joueur_systeme(_id_de(nom), "Le donjon n'a pas pu s'ouvrir. Réessaie.")
			_instances.arreter(port)
			return
	for nom in partants:
		var autre := _id_de(nom)
		if autre == 0:
			continue
		if numero != 0 and _groupes.has(numero):
			_groupes[numero]["donjon"][String(nom).to_lower()] = String(d.get("nom", ""))
		Regles.chez(autre, self, "_partir_en_donjon", [port, String(d["scene"]), String(d.get("nom", ""))])


## Ne garde de la progression reçue que des valeurs simples, en quantité raisonnable.
func _progression_propre(progression: Dictionary) -> Dictionary:
	var propre := {}
	for section in progression.keys().slice(0, 64):
		if not progression[section] is Dictionary:
			continue
		var valeurs := {}
		for cle in progression[section].keys().slice(0, 400):
			var v = progression[section][cle]
			if typeof(v) == TYPE_STRING:
				valeurs[String(cle).left(64)] = String(v).left(200)
			elif typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
				valeurs[String(cle).left(64)] = v
		propre[String(section).left(64)] = valeurs
	return propre
