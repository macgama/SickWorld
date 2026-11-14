extends Node
## Le compte en ligne du joueur (serveur Nakama) et la sauvegarde dans le « nuage ».
##
## Principe : le jeu sauvegarde toujours d'abord sur le PC, dans le dossier du
## profil actif (voir Profil). Quand un compte est connecté, ce dossier est
## recopié sur le serveur Nakama (une « boîte » par fichier, collection
## « sauvegarde ») toutes les 20 secondes et à la fermeture du jeu.
## Sur un autre PC, se connecter au même compte redescend le personnage.
##
## Sans compte, ou si le serveur ne répond pas, tout continue de marcher :
## « Jouer seul » utilise simplement les fichiers du PC.
##
## On parle à Nakama par son API web (REST) : pas de module à installer.

## Connexion, déconnexion, synchronisation : pour mettre l'écran à jour.
signal etat_change
## Le dossier de sauvegarde a changé (autre compte, ou fichiers redescendus
## du serveur) : le menu doit se reconstruire pour montrer le bon personnage.
signal profil_change

const FICHIER := "user://compte.cfg"
## Doit être la même que « server_key » dans serveur/nakama/config.yml.
const CLE_SERVEUR := "sickworld-cle-locale"
const COLLECTION := "sauvegarde"
const ADRESSE_PAR_DEFAUT := "127.0.0.1:7350"
const DELAI_REQUETE := 8.0
const INTERVALLE_SYNCHRO := 20.0
## Taille maximum d'un envoi (le serveur accepte 4 Mo).
const LOT_MAX_OCTETS := 3_000_000

## Adresse du serveur de comptes, ex. « 127.0.0.1:7350 » ou « https://jeu.exemple.fr ».
var adresse := ADRESSE_PAR_DEFAUT
## Un compte est choisi (il peut être momentanément hors connexion).
var a_un_compte := false
## Le serveur a répondu et la session est valide.
var en_ligne := false
var pseudo := ""
var email := ""
var id_utilisateur := ""
## Texte court pour le joueur (« Sauvegardé à 23:41 », « Serveur injoignable… »).
var etat := ""
## Heure (Unix) de la dernière synchronisation réussie.
var derniere_synchro := 0

var _jeton := ""
var _jeton_renouvellement := ""
var _expiration := 0
var _synchro_en_cours := false
var _minuteur: Timer
var _actif := true


func _ready() -> void:
	Profil.migrer_anciennes_sauvegardes()
	# Serveur dédié, tests, version sans écran : pas de compte, profil hors ligne.
	_actif = DisplayServer.get_name() != "headless" and not "--serveur" in OS.get_cmdline_user_args()
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	adresse = String(cfg.get_value("serveur", "adresse", adresse_par_defaut()))
	if _actif and cfg.has_section_key("session", "renouvellement"):
		a_un_compte = true
		_jeton_renouvellement = String(cfg.get_value("session", "renouvellement"))
		id_utilisateur = String(cfg.get_value("session", "id", ""))
		pseudo = String(cfg.get_value("session", "pseudo", ""))
		email = String(cfg.get_value("session", "email", ""))
		Profil.activer(_profil_du_compte())
		etat = "Connexion au serveur…"
		_reprendre_session.call_deferred()
	else:
		Profil.activer(Profil.HORS_LIGNE)
	_minuteur = Timer.new()
	_minuteur.wait_time = INTERVALLE_SYNCHRO
	_minuteur.timeout.connect(_au_minuteur)
	add_child(_minuteur)
	if _actif:
		_minuteur.start()
		get_tree().set_auto_accept_quit(false)


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST and _actif:
		# Dernier envoi avant de fermer (5 secondes au plus).
		if en_ligne:
			etat = "Sauvegarde en ligne avant de quitter…"
			etat_change.emit()
			get_tree().create_timer(5.0).timeout.connect(get_tree().quit)
			await synchroniser()
		get_tree().quit()


# --- Ce que le menu appelle ----------------------------------------------------

## Crée un compte puis s'y connecte. Renvoie "" si tout va bien, sinon le problème.
func creer_compte(e_mail: String, mot_de_passe: String, nom: String) -> String:
	var probleme := verifier(e_mail, mot_de_passe, nom, true)
	if probleme != "":
		return probleme
	var r := await _requete(HTTPClient.METHOD_POST,
			"/v2/account/authenticate/email?create=true&username=" + nom.uri_encode(),
			{"email": e_mail.strip_edges(), "password": mot_de_passe}, true)
	if not r.ok:
		return _message_erreur(r, true)
	return await _ouvrir_session(r.donnees, e_mail.strip_edges(), true)


## Se connecte à un compte existant. Renvoie "" si tout va bien, sinon le problème.
func se_connecter(e_mail: String, mot_de_passe: String) -> String:
	var probleme := verifier(e_mail, mot_de_passe, "", false)
	if probleme != "":
		return probleme
	var r := await _requete(HTTPClient.METHOD_POST, "/v2/account/authenticate/email?create=false",
			{"email": e_mail.strip_edges(), "password": mot_de_passe}, true)
	if not r.ok:
		return _message_erreur(r, false)
	return await _ouvrir_session(r.donnees, e_mail.strip_edges(), false)


## Revient au profil hors ligne. Les fichiers du compte restent sur le PC
## (ils seront comparés au serveur à la prochaine connexion).
func se_deconnecter() -> void:
	if en_ligne:
		await synchroniser()
	a_un_compte = false
	en_ligne = false
	_jeton = ""
	_jeton_renouvellement = ""
	pseudo = ""
	email = ""
	id_utilisateur = ""
	etat = ""
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	if cfg.has_section("session"):
		cfg.erase_section("session")
	cfg.save(FICHIER)
	Profil.activer(Profil.HORS_LIGNE)
	etat_change.emit()
	profil_change.emit()


## Le serveur de comptes officiel (Oracle Cloud, voir data/serveur_officiel.json)
## s'il existe, sinon celui de ce PC.
static func adresse_officielle() -> String:
	var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/serveur_officiel.json"))
	return String(lu.get("comptes", "")) if lu is Dictionary else ""


static func adresse_par_defaut() -> String:
	var officielle := adresse_officielle()
	return officielle if officielle != "" else ADRESSE_PAR_DEFAUT


func changer_adresse(nouvelle: String) -> void:
	nouvelle = nouvelle.strip_edges()
	adresse = nouvelle if nouvelle != "" else adresse_par_defaut()
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	cfg.set_value("serveur", "adresse", adresse)
	cfg.save(FICHIER)


## Contrôles simples avant d'envoyer au serveur.
static func verifier(e_mail: String, mot_de_passe: String, nom: String, creation: bool) -> String:
	e_mail = e_mail.strip_edges()
	var at := e_mail.find("@")
	if at < 1 or e_mail.find(".", at) < at + 2 or e_mail.ends_with("."):
		return "Cette adresse e-mail ne semble pas valide."
	if mot_de_passe.length() < 8:
		return "Le mot de passe doit faire au moins 8 caractères."
	if creation:
		var n := nom.strip_edges()
		if n.length() < 3 or n.length() > 20:
			return "Le pseudo doit faire entre 3 et 20 caractères."
		var regex := RegEx.create_from_string("^[A-Za-z0-9_\\-.À-ÿ]+$")
		if regex.search(n) == null:
			return "Le pseudo ne peut contenir que des lettres, des chiffres, « - », « _ » et « . »."
	return ""


## Compare le dossier du profil et le serveur, puis envoie ou redescend ce qui a changé.
## « connexion » = premier passage après s'être connecté : si un fichier a changé
## des deux côtés, c'est la version du serveur qui gagne (on a peut-être joué
## sur un autre PC). Ensuite, c'est la version du PC qui gagne.
## Renvoie true si des fichiers ont été redescendus du serveur.
func synchroniser(connexion := false) -> bool:
	if not en_ligne or _synchro_en_cours:
		return false
	_synchro_en_cours = true
	var redescendu := false
	var profil := Profil.nom
	var dossier := Profil.dossier()

	var distants = await _lister_distant()
	if distants == null:
		_synchro_en_cours = false
		return false
	var base := ConfigFile.new()
	base.load(dossier + Profil.FICHIER_SYNCHRO)
	var locaux := Profil.lister()

	var a_envoyer: Array = []
	var a_effacer: Array = []
	var tous := {}
	for relatif in locaux:
		tous[relatif] = true
	for relatif in distants:
		tous[relatif] = true

	for relatif in tous:
		var local_ := ""
		if FileAccess.file_exists(dossier + relatif):
			local_ = FileAccess.get_md5(dossier + relatif)
		var distant := String(distants[relatif]["empreinte"]) if distants.has(relatif) else ""
		var connu := String(base.get_value("empreintes", relatif, ""))
		if local_ == distant:
			if local_ != "":
				base.set_value("empreintes", relatif, local_)
			else:
				_oublier(base, relatif)
			continue
		var local_change := local_ != connu
		var distant_change := distant != connu
		if distant_change and (not local_change or connexion):
			# Le serveur a une version plus récente : on la redescend.
			if distant == "":
				DirAccess.remove_absolute(dossier + relatif)
				_oublier(base, relatif)
			else:
				_ecrire_local(dossier + relatif, distants[relatif])
				base.set_value("empreintes", relatif, distant)
			redescendu = true
		elif local_ == "":
			a_effacer.append(relatif)
		else:
			a_envoyer.append(relatif)

	var ok := true
	if not a_envoyer.is_empty():
		ok = await _envoyer(dossier, a_envoyer, base)
	if ok and not a_effacer.is_empty():
		var ids: Array = []
		for relatif in a_effacer:
			ids.append({"collection": COLLECTION, "key": _cle(relatif)})
		var r := await _requete(HTTPClient.METHOD_PUT, "/v2/storage/delete", {"object_ids": ids})
		ok = r.ok
		if ok:
			for relatif in a_effacer:
				_oublier(base, relatif)

	if profil == Profil.nom:
		base.save(dossier + Profil.FICHIER_SYNCHRO)
	if ok:
		derniere_synchro = int(Time.get_unix_time_from_system())
		etat = "Sauvegardé en ligne à " + Time.get_time_string_from_system().left(5)
	_synchro_en_cours = false
	etat_change.emit()
	if redescendu:
		profil_change.emit()
	return redescendu


# --- Session -------------------------------------------------------------------

func _ouvrir_session(donnees: Dictionary, e_mail: String, creation: bool) -> String:
	if not _lire_jetons(donnees):
		return "Réponse inattendue du serveur."
	email = e_mail
	a_un_compte = true
	en_ligne = true
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	cfg.set_value("session", "renouvellement", _jeton_renouvellement)
	cfg.set_value("session", "id", id_utilisateur)
	cfg.set_value("session", "pseudo", pseudo)
	cfg.set_value("session", "email", email)
	cfg.save(FICHIER)

	var profil := _profil_du_compte()
	var nouveau := not Profil.existe(profil) or Profil.lister(profil).is_empty()
	Profil.activer(profil)
	if nouveau:
		# Compte tout neuf (ou jamais utilisé sur ce PC) : si le serveur n'a rien,
		# on lui confie le personnage joué hors ligne, pour ne pas le perdre.
		var distants = await _lister_distant()
		if distants is Dictionary and distants.is_empty() and Profil.a_un_personnage(Profil.HORS_LIGNE):
			Profil.copier(Profil.HORS_LIGNE, profil)
	etat = "Connecté. Synchronisation…"
	etat_change.emit()
	await synchroniser(true)
	profil_change.emit()
	return ""


func _reprendre_session() -> void:
	var ok := await _renouveler()
	if ok:
		await synchroniser(true)
	etat_change.emit()


## Demande de nouveaux jetons au serveur. false si hors connexion ou refusé.
func _renouveler() -> bool:
	var r := await _requete(HTTPClient.METHOD_POST, "/v2/account/session/refresh",
			{"token": _jeton_renouvellement}, true)
	if r.ok and _lire_jetons(r.donnees):
		en_ligne = true
		var cfg := ConfigFile.new()
		cfg.load(FICHIER)
		cfg.set_value("session", "renouvellement", _jeton_renouvellement)
		cfg.save(FICHIER)
		return true
	en_ligne = false
	if r.code == 401:
		# Session trop ancienne ou compte supprimé : il faut se reconnecter.
		await se_deconnecter()
		etat = "Ta connexion a expiré : reconnecte-toi."
	else:
		etat = "Serveur de comptes injoignable : ta progression est gardée sur ce PC et sera envoyée plus tard."
	etat_change.emit()
	return false


func _lire_jetons(donnees) -> bool:
	if not donnees is Dictionary or not donnees.has("token"):
		return false
	_jeton = String(donnees["token"])
	if donnees.has("refresh_token"):
		_jeton_renouvellement = String(donnees["refresh_token"])
	var contenu := _decoder_jeton(_jeton)
	if contenu.is_empty():
		return false
	id_utilisateur = String(contenu.get("uid", id_utilisateur))
	pseudo = String(contenu.get("usn", pseudo))
	_expiration = int(contenu.get("exp", 0))
	return id_utilisateur != ""


static func _decoder_jeton(jeton: String) -> Dictionary:
	var parties := jeton.split(".")
	if parties.size() != 3:
		return {}
	var b64 := parties[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var lu = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	return lu if lu is Dictionary else {}


func _profil_du_compte() -> String:
	return "compte_" + id_utilisateur.validate_filename()


func _au_minuteur() -> void:
	if not a_un_compte:
		return
	if en_ligne:
		synchroniser()
	elif _jeton_renouvellement != "":
		# Le serveur était injoignable : on réessaie de temps en temps.
		if await _renouveler():
			synchroniser()


# --- Stockage --------------------------------------------------------------------

## { chemin relatif : {"empreinte", "donnees"} } ou null si le serveur ne répond pas.
func _lister_distant():
	var resultat := {}
	var curseur := ""
	while true:
		var url := "/v2/storage/%s?user_id=%s&limit=100" % [COLLECTION, id_utilisateur]
		if curseur != "":
			url += "&cursor=" + curseur.uri_encode()
		var r := await _requete(HTTPClient.METHOD_GET, url)
		if not r.ok:
			return null
		for objet in r.donnees.get("objects", []):
			var valeur = JSON.parse_string(String(objet.get("value", "")))
			if valeur is Dictionary:
				resultat[_relatif(String(objet.get("key", "")))] = valeur
		curseur = String(r.donnees.get("cursor", ""))
		if curseur == "":
			break
	return resultat


func _envoyer(dossier: String, fichiers: Array, base: ConfigFile) -> bool:
	var lot: Array = []
	var empreintes := {}
	var taille := 0
	for i in fichiers.size():
		var relatif: String = fichiers[i]
		var octets := FileAccess.get_file_as_bytes(dossier + relatif)
		var empreinte := FileAccess.get_md5(dossier + relatif)
		var valeur := {
			"empreinte": empreinte,
			"taille": octets.size(),
			"donnees": Marshalls.raw_to_base64(octets.compress(FileAccess.COMPRESSION_GZIP)),
		}
		var texte := JSON.stringify(valeur)
		lot.append({"collection": COLLECTION, "key": _cle(relatif), "value": texte,
				"permission_read": 1, "permission_write": 1})
		empreintes[relatif] = empreinte
		taille += texte.length()
		if taille > LOT_MAX_OCTETS or i == fichiers.size() - 1:
			var r := await _requete(HTTPClient.METHOD_PUT, "/v2/storage", {"objects": lot})
			if not r.ok:
				return false
			for rel in empreintes:
				base.set_value("empreintes", rel, empreintes[rel])
			lot = []
			empreintes = {}
			taille = 0
	return true


func _ecrire_local(chemin: String, valeur: Dictionary) -> void:
	var compresse := Marshalls.base64_to_raw(String(valeur.get("donnees", "")))
	var octets := compresse.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f != null:
		f.store_buffer(octets)


static func _oublier(base: ConfigFile, relatif: String) -> void:
	if base.has_section_key("empreintes", relatif):
		base.erase_section_key("empreintes", relatif)


## Les clés Nakama n'aiment pas les « / » : « cartes/lea.cfg » devient « cartes~lea.cfg ».
static func _cle(relatif: String) -> String:
	return relatif.replace("/", "~")


static func _relatif(cle: String) -> String:
	return cle.replace("~", "/")


# --- Requêtes web --------------------------------------------------------------

func _url_de_base() -> String:
	if adresse.begins_with("http://") or adresse.begins_with("https://"):
		return adresse.trim_suffix("/")
	return "http://" + adresse


## Envoie une requête à Nakama. Renvoie {ok, code, donnees, erreur}.
## « avec_cle » : authentification par la clé du serveur (connexion, création),
## sinon par le jeton de session (renouvelé automatiquement s'il va expirer).
func _requete(methode: int, chemin: String, corps = null, avec_cle := false) -> Dictionary:
	if not avec_cle and _expiration - int(Time.get_unix_time_from_system()) < 60:
		var r_renouv := await _requete(HTTPClient.METHOD_POST, "/v2/account/session/refresh",
				{"token": _jeton_renouvellement}, true)
		if not r_renouv.ok or not _lire_jetons(r_renouv.donnees):
			en_ligne = false
			etat = "Serveur de comptes injoignable : ta progression est gardée sur ce PC."
			etat_change.emit()
			return r_renouv
	var entetes := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if avec_cle:
		entetes.append("Authorization: Basic " + Marshalls.utf8_to_base64(CLE_SERVEUR + ":"))
	else:
		entetes.append("Authorization: Bearer " + _jeton)
	var http := HTTPRequest.new()
	http.timeout = DELAI_REQUETE
	add_child(http)
	var texte := "" if corps == null else JSON.stringify(corps)
	var erreur := http.request(_url_de_base() + chemin, entetes, methode, texte)
	if erreur != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "donnees": {}, "erreur": "adresse"}
	var reponse: Array = await http.request_completed
	http.queue_free()
	var resultat: int = reponse[0]
	var code: int = reponse[1]
	var json := JSON.new()
	var donnees: Dictionary = {}
	if json.parse((reponse[3] as PackedByteArray).get_string_from_utf8()) == OK and json.data is Dictionary:
		donnees = json.data
	if resultat != HTTPRequest.RESULT_SUCCESS:
		if a_un_compte and not avec_cle:
			en_ligne = false
			etat = "Serveur de comptes injoignable : ta progression est gardée sur ce PC."
		return {"ok": false, "code": 0, "donnees": {}, "erreur": "injoignable"}
	return {"ok": code >= 200 and code < 300, "code": code, "donnees": donnees,
			"erreur": String(donnees.get("message", ""))}


func _message_erreur(r: Dictionary, creation: bool) -> String:
	if r.code == 0:
		return "Le serveur de comptes ne répond pas (est-il démarré ?). Tu peux toujours jouer seul."
	var message := String(r.erreur).to_lower()
	if r.code == 404:
		return "Aucun compte avec cet e-mail. Clique sur « Créer un compte »."
	if r.code == 401:
		return "Ce compte existe déjà avec un autre mot de passe." if creation else "E-mail ou mot de passe incorrect."
	if r.code == 409 or message.contains("username"):
		return "Ce pseudo est déjà pris, choisis-en un autre."
	if message.contains("password"):
		return "Le mot de passe doit faire au moins 8 caractères."
	if message.contains("email"):
		return "Cette adresse e-mail ne semble pas valide."
	return "Le serveur a refusé (%d) : %s" % [r.code, r.erreur]
