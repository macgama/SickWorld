extends Node
## Les GUILDES de SickWorld : des agents qui voyagent ensemble, sous une même bannière.
##
## - FONDER : au registraire de la Maison des guildes (quartier des Résidences), une fois
##   la mission « Trois signatures » finie. Nom (3 à 24 lettres) + couleur de bannière.
## - MEMBRES ET RANGS : Maître de guilde, Officier, Membre, Recrue (data/guildes.json dit
##   qui peut inviter, exclure, promouvoir, écrire le message de guilde, sortir des objets).
##   Inviter : /ginviter Nom, ou cibler le joueur puis « Inviter dans la guilde ».
## - BANQUE : un coffre partagé dans la Maison des guildes. Tout le monde peut déposer ;
##   on sort des objets selon son rang (nombre par jour). Tout est écrit dans le journal.
## - CONTRATS DE LA SEMAINE : 3 objectifs communs (vaincre des fractures, récolter, rendre
##   des missions…), tirés chaque lundi. Toute la guilde avance ensemble ; chaque contrat
##   accompli donne des SCEAUX DE GUILDE à ceux qui ont aidé (à échanger chez Mei Takahara,
##   l'intendante) et de l'XP de guilde. Le NIVEAU de la guilde agrandit la banque, le
##   nombre de membres, et ouvre de nouvelles pièces chez l'intendante.
##
## Comme pour tout le reste, c'est le SERVEUR qui décide. Il garde les guildes dans
## user://sauvegardes/guildes.json (dans son profil). En jeu « seul », ton PC est son propre serveur :
## ta guilde vit sur ton PC. Les serveurs de donjon (instances) ne gèrent pas les guildes :
## ce que tu y fais est gardé chez toi (fichier user://guilde.cfg de ton profil) et compté
## pour ta guilde dès ton retour en ville. Pareil sur les îles en solo si ta guilde est en ligne.
##
## Fenêtre : touche G (ou /guilde). Réglages : data/guildes.json.

const R := preload("res://scripts/guildes/regles_guildes.gd")
const SCRIPT_INTERFACE := "res://scripts/interface/fenetre_guilde.gd"
const FICHIER_SERVEUR := "user://sauvegardes/guildes.json"
const FICHIER_CLIENT := "user://guilde.cfg"
const VUE_JOURNAL := 40

## Chez le joueur : la vue de notre guilde a changé (voir « guilde »).
signal change
## Chez le joueur : quelqu'un nous invite (de = "" : plus d'invitation).
signal invitation_changee(de: String, nom_guilde: String)
## Chez le joueur : réponse du serveur à « Fonder la guilde » ("" = c'est fait, sinon l'erreur).
signal fondation_repondue(erreur: String)
## Chez le joueur : la liste des guildes du serveur (tableau de recrutement).
signal annuaire_recu(liste: Array)
## Chez le joueur : une grande nouvelle de la guilde (contrat accompli, niveau…).
signal annonce(titre: String, texte: String)

var d := {}

# --- Chez le joueur ---
## Notre guilde, envoyée par le serveur (vide = pas de guilde sur ce serveur).
## {nom, couleur, niveau, xp, avancement, membres_max, places_banque, mon_rang, nom_rang, droits,
##  retraits_restants, membres: [...], banque: [...], journal: [...], message, contrats, rangs}
var guilde := {}
## Notre guilde vit sur un autre serveur : {nom} (vide sinon).
var ailleurs := {}
## Le serveur ne gère pas les guildes ici (donjon).
var en_donjon := false
var invitation := {}
## Fichier du joueur (nom de la guilde, couleur, serveur, contributions en attente).
var fichier_client := FICHIER_CLIENT
## Ancienne sauvegarde où la guilde était rangée avant (lue une seule fois).
var fichier_ancien := "user://progression.cfg"
var _interface: Node
var _partie_annoncee := 0
var _minuteur := 0.0

# --- Sur le serveur ---
var fichier_serveur := FICHIER_SERVEUR
## cle de guilde -> guilde (voir RèglesGuildes)
var _guildes := {}
## cle du nom d'un membre -> cle de sa guilde
var _index := {}
var _chemin_charge := ""
var _modifie := false
var _a_diffuser := {}
var _prochaine_sauvegarde := 0.0
var _prochaine_diffusion := 0.0
## Invitations : cle du nom de l'invité -> {guilde, de, fin}
var _invitations := {}
## Tests sans réseau seulement : fait comme si la demande venait de ce joueur (0 = normal).
var expediteur_force := 0
## Tests : désactive la vérification de distance au coffre.
var coffre_partout := false


func _ready() -> void:
	d = R.donnees()
	Reseau.joueur_parti.connect(_sur_depart)
	multiplayer.server_disconnected.connect(_oublier)


func _process(delta: float) -> void:
	_minuteur += delta
	if _minuteur >= 0.5:
		_minuteur = 0.0
		_installer_interface()
		_annoncer_si_besoin()
	if actif_ici():
		var t := Regles.maintenant()
		if t >= _prochaine_diffusion:
			_prochaine_diffusion = t + 1.5
			_nettoyer_invitations()
			for cg in _a_diffuser.keys():
				_diffuser(String(cg))
			_a_diffuser.clear()
		if _modifie and t >= _prochaine_sauvegarde:
			_prochaine_sauvegarde = t + 4.0
			sauvegarder()


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST or quoi == NOTIFICATION_PREDELETE:
		if _modifie:
			sauvegarder()


## Ce programme est le serveur des guildes (seul, hébergé, dédié ; pas un donjon).
func actif_ici() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server() and not Reseau.instance


static func maintenant_unix() -> int:
	return int(Time.get_unix_time_from_system())


func semaine() -> int:
	return Recompenses.periode_actuelle("hebdomadaire")


func jour() -> int:
	return Recompenses.periode_actuelle("quotidienne")


## Secondes avant le prochain tirage des contrats (lundi, même heure que les missions du jour).
func fin_de_semaine_dans() -> int:
	var t := maintenant_unix()
	t += int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	t -= int(Recompenses.lire("quetes_du_jour").get("reglages", {}).get("heure_renouvellement", 6)) * 3600
	var debut_prochaine := (semaine() + 1) * 7 - 3
	return maxi(0, debut_prochaine * 86400 - t)


func couleur(n: int) -> Color:
	return R.couleur(d, n)


func noms_couleurs() -> Array:
	return (d.get("couleurs", []) as Array).map(func(c): return String(c[0]))


# =============================================================================
# Chez le joueur : ce que l'interface appelle
# =============================================================================

func a_une_guilde() -> bool:
	return not guilde.is_empty()


func droit(nom_droit: String) -> bool:
	return bool((guilde.get("droits", {}) as Dictionary).get(nom_droit, false))


## Niveau de notre guilde (0 = pas de guilde ici).
func mon_niveau() -> int:
	return int(guilde.get("niveau", 0))


func est_dans_ma_guilde(nom: String) -> bool:
	for m in guilde.get("membres", []):
		if String(m["nom"]).to_lower() == nom.to_lower():
			return true
	return false


func fonder(nom: String, numero_couleur: int) -> void:
	_demander_au_serveur("fonder", [nom, numero_couleur])


## Tableau de recrutement : demande la liste des guildes du serveur (réponse : annuaire_recu).
func demander_annuaire() -> void:
	_demander_au_serveur("annuaire", [])


## Ouvre ou ferme le recrutement de sa guilde, avec une devise (officiers et maître).
func changer_recrutement(ouvert: bool, devise: String) -> void:
	_demander_au_serveur("recrutement", [ouvert, devise])


func changer_blason(forme: int, symbole: int) -> void:
	_demander_au_serveur("blason", [forme, symbole])


## Rejoindre une guilde dont le recrutement est ouvert (sans invitation).
func rejoindre(nom_guilde: String) -> void:
	_demander_au_serveur("rejoindre", [nom_guilde])


func inviter(nom: String) -> void:
	if nom.strip_edges() == "":
		Social._systeme("Pour inviter dans ta guilde : /ginviter Nom (ou cible le joueur et clique sur « Inviter dans la guilde »).")
		return
	_demander_au_serveur("inviter", [nom.strip_edges()])


func repondre_invitation(accepter: bool) -> void:
	invitation = {}
	invitation_changee.emit("", "")
	_demander_au_serveur("repondre", [accepter])


func quitter() -> void:
	_demander_au_serveur("quitter", [])


func exclure(nom: String) -> void:
	_demander_au_serveur("exclure", [nom])


func promouvoir(nom: String) -> void:
	_demander_au_serveur("promouvoir", [nom])


func retrograder(nom: String) -> void:
	_demander_au_serveur("retrograder", [nom])


func nommer_maitre(nom: String) -> void:
	_demander_au_serveur("maitre", [nom])


func ecrire_message(texte: String) -> void:
	_demander_au_serveur("message", [texte])


## Dépose dans la banque la pile de la case « index » de nos sacs.
func deposer(index: int) -> void:
	_demander_au_serveur("deposer", [index])


## Sort de la banque la pile de la place « index ».
func retirer(index: int) -> void:
	_demander_au_serveur("retirer", [index])


func rafraichir() -> void:
	_demander_au_serveur("vue", [])


func basculer_fenetre(onglet := -1) -> void:
	if _interface != null and is_instance_valid(_interface):
		_interface.basculer(onglet)


func ouvrir_fenetre(onglet := -1) -> void:
	if _interface != null and is_instance_valid(_interface):
		_interface.ouvrir(onglet)


func _demander_au_serveur(action: String, arguments: Array) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	Regles.au_serveur(self, "_demander", [action, arguments])


# --- Fichier du joueur (guilde connue, contributions en attente) ------------------------

func _cache() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(fichier_client))
	# Ancienne sauvegarde : la guilde était rangée dans progression.cfg (section [guilde]).
	if not cfg.has_section_key("guilde", "migre"):
		var ancien := ConfigFile.new()
		if ancien.load(Profil.chemin(fichier_ancien)) == OK and ancien.has_section_key("guilde", "nom"):
			cfg.set_value("guilde", "nom", String(ancien.get_value("guilde", "nom")))
			cfg.set_value("guilde", "couleur", int(ancien.get_value("guilde", "couleur", 0)))
			cfg.set_value("guilde", "origine", "")
		cfg.set_value("guilde", "migre", true)
		_sauver_cache(cfg)
	return cfg


func _sauver_cache(cfg: ConfigFile) -> void:
	DirAccess.make_dir_recursive_absolute(Profil.chemin(fichier_client).get_base_dir())
	cfg.save(Profil.chemin(fichier_client))


## Nom de notre guilde, tel que gardé sur ce PC ("" = aucune). Sert à la bannière et à la discussion.
func nom_local() -> String:
	return String(_cache().get_value("guilde", "nom", ""))


func couleur_locale() -> int:
	return int(_cache().get_value("guilde", "couleur", 0))


func attente() -> Dictionary:
	var a = _cache().get_value("guilde", "attente", {})
	return a if a is Dictionary else {}


func _ecrire_cache(nom: String, numero_couleur: int, origine: String) -> void:
	var cfg := _cache()
	var avant := String(cfg.get_value("guilde", "nom", "")) + str(cfg.get_value("guilde", "couleur", 0))
	cfg.set_value("guilde", "nom", nom)
	cfg.set_value("guilde", "couleur", numero_couleur)
	cfg.set_value("guilde", "origine", origine)
	_sauver_cache(cfg)
	if avant != nom + str(numero_couleur):
		_bannieres()


func _effacer_cache() -> void:
	var cfg := _cache()
	for cle_ in ["nom", "couleur", "origine", "attente"]:
		if cfg.has_section_key("guilde", cle_):
			cfg.erase_section_key("guilde", cle_)
	_sauver_cache(cfg)
	_bannieres()


func _bannieres() -> void:
	var appart := get_tree().get_first_node_in_group("appartement") if is_inside_tree() else null
	if appart != null and appart.has_method("_afficher_bannieres"):
		appart._afficher_bannieres()


## Le serveur où l'on joue, vu d'ici (« seul », ou adresse:port de la ville).
func serveur_id() -> String:
	if Reseau.mode == Reseau.Mode.SEUL:
		return "seul"
	var p: int = Reseau.port_hub if Reseau.en_instance() and Reseau.port_hub > 0 else Reseau.port
	return "%s:%d" % [Reseau.adresse, p]


# --- Annonce au serveur à chaque arrivée dans une partie ----------------------------------

func _annoncer_si_besoin() -> void:
	if not Reseau.a_un_joueur_local() or multiplayer.multiplayer_peer == null:
		return
	var partie := get_tree().get_first_node_in_group("partie")
	if partie == null or get_tree().get_first_node_in_group("joueur_local") == null:
		return
	if partie.get_instance_id() == _partie_annoncee:
		return
	_partie_annoncee = partie.get_instance_id()
	annoncer()


## Dit au serveur qui on est côté guilde (et lui donne ce qui a été fait ailleurs).
func annoncer() -> void:
	var cfg := _cache()
	_demander_au_serveur("annonce", [String(cfg.get_value("guilde", "nom", "")), int(cfg.get_value("guilde", "couleur", 0)),
			String(cfg.get_value("guilde", "origine", "")), serveur_id(), attente()])


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
	_interface.name = "FenetreGuilde"
	partie.add_child(_interface)


func _oublier() -> void:
	guilde = {}
	invitation = {}
	_partie_annoncee = 0
	change.emit()


# =============================================================================
# Chez le joueur : ce que le serveur nous envoie
# =============================================================================

func _vient_du_serveur() -> bool:
	return multiplayer.get_remote_sender_id() in [0, 1]


## statut : « membre », « aucune », « ailleurs », « exclu » (on n'en fait plus partie), « donjon ».
@rpc("authority", "call_remote", "reliable")
func _recevoir_vue(vue: Dictionary, statut: String) -> void:
	if not _vient_du_serveur():
		return
	en_donjon = statut == "donjon"
	match statut:
		"membre":
			guilde = vue
			ailleurs = {}
			_ecrire_cache(String(vue.get("nom", "")), int(vue.get("couleur", 0)), serveur_id())
		"exclu":
			guilde = {}
			ailleurs = {}
			_effacer_cache()
		"ailleurs":
			guilde = {}
			ailleurs = {"nom": nom_local()}
		"donjon":
			pass
		_:
			guilde = {}
			ailleurs = {}
	change.emit()


@rpc("authority", "call_remote", "reliable")
func _recevoir_annuaire(liste: Array) -> void:
	if not _vient_du_serveur():
		return
	annuaire_recu.emit(liste)


@rpc("authority", "call_remote", "reliable")
func _recevoir_info(texte: String, titre: String) -> void:
	if not _vient_du_serveur():
		return
	Social._systeme(texte)
	if titre != "":
		annonce.emit(titre, texte)


@rpc("authority", "call_remote", "reliable")
func _recevoir_invitation(de: String, nom_guilde: String) -> void:
	if not _vient_du_serveur():
		return
	invitation = {"de": de, "guilde": nom_guilde}
	invitation_changee.emit(de, nom_guilde)
	Social._systeme("%s t'invite dans la guilde « %s »." % [de, nom_guilde])


@rpc("authority", "call_remote", "reliable")
func _reponse_fondation(erreur: String) -> void:
	if _vient_du_serveur():
		fondation_repondue.emit(erreur)


## Le serveur ne peut pas compter cette action pour notre guilde (donjon, autre serveur) :
## on la garde et on la donnera à notre guilde au prochain passage en ville.
@rpc("authority", "call_remote", "reliable")
func _mettre_en_attente(type: String, n: int) -> void:
	if not _vient_du_serveur() or n <= 0:
		return
	var cfg := _cache()
	if String(cfg.get_value("guilde", "nom", "")) == "":
		return
	var a = cfg.get_value("guilde", "attente", {})
	if not a is Dictionary:
		a = {}
	a[type] = int(a.get(type, 0)) + n
	cfg.set_value("guilde", "attente", a)
	_sauver_cache(cfg)


@rpc("authority", "call_remote", "reliable")
func _attente_acceptee() -> void:
	if not _vient_du_serveur():
		return
	var cfg := _cache()
	if cfg.has_section_key("guilde", "attente"):
		cfg.erase_section_key("guilde", "attente")
		_sauver_cache(cfg)


# =============================================================================
# Sur le serveur : les guildes
# =============================================================================

func _charger_si_besoin() -> void:
	var chemin := Profil.chemin(fichier_serveur)
	if chemin == _chemin_charge:
		return
	if _modifie and _chemin_charge != "":
		sauvegarder()
	_chemin_charge = chemin
	_guildes = {}
	_index = {}
	_modifie = false
	var lu = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
	if lu is Dictionary:
		for cg in (lu.get("guildes", {}) as Dictionary):
			var g = lu["guildes"][cg]
			if g is Dictionary and g.has("nom") and g.get("membres") is Dictionary and not (g["membres"] as Dictionary).is_empty():
				_guildes[String(cg)] = _remettre_d_aplomb(g)
	_reindexer()


## Les nombres lus dans un fichier JSON sont des nombres à virgule : on les remet en entiers.
func _remettre_d_aplomb(g: Dictionary) -> Dictionary:
	g["cle"] = R.cle(String(g["nom"]))
	g["couleur"] = int(g.get("couleur", 0))
	g["xp"] = int(g.get("xp", 0))
	g["fondee"] = int(g.get("fondee", 0))
	var banque: Array = []
	for c in g.get("banque", []):
		if c is Dictionary and c.has("id") and Objets.existe(Donnees.objets, String(c["id"])):
			banque.append({"id": String(c["id"]), "n": maxi(1, int(c.get("n", 1)))})
		else:
			banque.append({})
	g["banque"] = banque
	R.ajuster_banque(d, g)
	for c in g["membres"]:
		var m: Dictionary = g["membres"][c]
		for champ in ["depuis", "vu", "total", "semaine"]:
			m[champ] = int(m.get(champ, 0))
		var r: Dictionary = m.get("retraits", {})
		m["retraits"] = {"jour": int(r.get("jour", 0)), "n": int(r.get("n", 0))}
	if not g.get("journal") is Array:
		g["journal"] = []
	if not g.get("a_donner") is Dictionary:
		g["a_donner"] = {}
	for c in g["a_donner"]:
		g["a_donner"][c] = (g["a_donner"][c] as Array).map(func(o): return {"id": String(o["id"]), "n": int(o["n"])})
	var contrats = g.get("contrats", {})
	if contrats is Dictionary and contrats.has("liste"):
		contrats["semaine"] = int(contrats["semaine"])
		for c in contrats["liste"]:
			c["nombre"] = int(c["nombre"])
			c["compte"] = int(c["compte"])
		for k in contrats.get("aides", {}):
			for qui in contrats["aides"][k]:
				contrats["aides"][k][qui] = int(contrats["aides"][k][qui])
	else:
		g["contrats"] = {}
	g["message"] = String(g.get("message", ""))
	if g.has("blason"):
		g["blason"] = R.blason(g)
	if g.has("recrutement"):
		g["recrutement"] = R.recrutement(g)
	return g


func _reindexer() -> void:
	_index = {}
	for cg in _guildes:
		for c in _guildes[cg]["membres"]:
			_index[c] = cg


func sauvegarder() -> void:
	if _chemin_charge == "":
		return
	DirAccess.make_dir_recursive_absolute(_chemin_charge.get_base_dir())
	var f := FileAccess.open(_chemin_charge, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"guildes": _guildes}, "\t"))
		_modifie = false


func _changer(g: Dictionary) -> void:
	_modifie = true
	_a_diffuser[String(g["cle"])] = true


## Serveur : la guilde d'un joueur (vide s'il n'en a pas sur ce serveur).
func guilde_de(nom: String) -> Dictionary:
	if not actif_ici():
		return {}
	_charger_si_besoin()
	var cg := String(_index.get(R.cle(nom), ""))
	return _guildes.get(cg, {})


## Serveur : niveau de la guilde d'un joueur (0 = pas de guilde ici).
func niveau_du_joueur(nom: String) -> int:
	var g := guilde_de(nom)
	return R.niveau(d, int(g["xp"])) if not g.is_empty() else 0


## Serveur : les numéros réseau des membres de la guilde de ce joueur qui sont en ligne.
func ids_en_ligne_de_la_guilde_de(nom: String) -> Array:
	var g := guilde_de(nom)
	var ids: Array = []
	if g.is_empty():
		return ids
	for c in g["membres"]:
		var id := Social._id_de(String(g["membres"][c]["nom"]))
		if id != 0:
			ids.append(id)
	return ids


## Pour les tests et l'administration : toutes les guildes du serveur.
func toutes() -> Dictionary:
	_charger_si_besoin()
	return _guildes


func _info(id: int, texte: String, titre := "") -> void:
	if id != 0:
		Regles.chez(id, self, "_recevoir_info", [texte, titre])


func _a_toute_la_guilde(g: Dictionary, texte: String, titre := "") -> void:
	for c in g["membres"]:
		_info(Social._id_de(String(g["membres"][c]["nom"])), texte, titre)


func _envoyer_vue(id: int, nom: String) -> void:
	if id == 0:
		return
	var g := guilde_de(nom)
	if g.is_empty():
		Regles.chez(id, self, "_recevoir_vue", [{}, "aucune"])
	else:
		Regles.chez(id, self, "_recevoir_vue", [_vue(g, nom), "membre"])


func _diffuser(cg: String) -> void:
	var g: Dictionary = _guildes.get(cg, {})
	if g.is_empty():
		return
	for c in g["membres"]:
		var nom := String(g["membres"][c]["nom"])
		var id := Social._id_de(nom)
		if id != 0:
			Regles.chez(id, self, "_recevoir_vue", [_vue(g, nom), "membre"])


## Ce que voit un membre de sa guilde.
func _vue(g: Dictionary, nom: String) -> Dictionary:
	var moi := R.membre(g, nom)
	var rang := String(moi.get("rang", ""))
	var membres: Array = []
	for c in g["membres"]:
		var m: Dictionary = g["membres"][c]
		membres.append({"nom": m["nom"], "rang": m["rang"], "nom_rang": R.nom_rang(d, String(m["rang"])),
				"ordre": R.ordre(d, String(m["rang"])), "en_ligne": Social._id_de(String(m["nom"])) != 0,
				"vu": int(m["vu"]), "semaine": int(m["semaine"]), "total": int(m["total"]), "depuis": int(m["depuis"])})
	membres.sort_custom(func(a, b): return a["ordre"] < b["ordre"] if a["ordre"] != b["ordre"] else String(a["nom"]).naturalnocasecmp_to(String(b["nom"])) < 0)
	var journal: Array = g["journal"]
	var contrats: Dictionary = g.get("contrats", {})
	var infos_rangs: Array = R.rangs(d).map(func(r): return {"id": r["id"], "nom": r["nom"]})
	return {"nom": g["nom"], "couleur": g["couleur"], "xp": g["xp"], "niveau": R.niveau(d, int(g["xp"])),
			"avancement": R.avancement(d, int(g["xp"])), "membres_max": R.membres_max(d, g),
			"places_banque": R.places_banque(d, g), "mon_rang": rang, "nom_rang": R.nom_rang(d, rang),
			"droits": {"inviter": R.peut(d, rang, "inviter"), "exclure": R.peut(d, rang, "exclure"),
					"promouvoir": R.peut(d, rang, "promouvoir"), "message": R.peut(d, rang, "message"),
					"maitre": rang == "maitre"},
			"retraits_restants": R.retraits_restants(d, g, nom, jour()),
			"membres": membres, "banque": g["banque"], "message": g["message"],
			"journal": journal.slice(maxi(0, journal.size() - VUE_JOURNAL)),
			"contrats": {"liste": contrats.get("liste", []), "semaine_complete": contrats.get("semaine_complete", false),
					"fin_dans": fin_de_semaine_dans(), "mes_aides": int(moi.get("semaine", 0))},
			"sceaux_par_contrat": R.sceaux_par_contrat(d, g), "sceaux_semaine": int(R.reglage(d, "sceaux_semaine_complete", 20)),
			"rangs": infos_rangs, "fondee": g["fondee"], "blason": R.blason(g), "recrutement": R.recrutement(g)}


func _sur_depart(_id: int, nom: String) -> void:
	if not actif_ici():
		return
	var g := guilde_de(nom)
	if not g.is_empty():
		g["membres"][R.cle(nom)]["vu"] = maintenant_unix()
		_changer(g)
	_invitations.erase(R.cle(nom))


func _nettoyer_invitations() -> void:
	var t := Regles.maintenant()
	for c in _invitations.keys():
		if t > float(_invitations[c]["fin"]):
			_invitations.erase(c)


# --- Les demandes des joueurs -------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _demander(action: String, arguments: Array) -> void:
	if not multiplayer.is_server():
		return
	var id := expediteur_force if expediteur_force != 0 else Regles.expediteur()
	if Reseau.instance:
		Regles.chez(id, self, "_recevoir_vue", [{}, "donjon"])
		return
	_charger_si_besoin()
	var nom := String(Reseau.noms.get(id, ""))
	if nom == "":
		return
	var raison := ""
	match action:
		"annonce":
			if arguments.size() == 5:
				_annonce(id, nom, String(arguments[0]), int(arguments[1]), String(arguments[2]), String(arguments[3]),
						arguments[4] if arguments[4] is Dictionary else {})
			return
		"vue":
			_envoyer_vue(id, nom)
			return
		"annuaire":
			Regles.chez(id, self, "_recevoir_annuaire", [_annuaire()])
			return
		"recrutement":
			raison = _changer_recrutement(nom, bool(arguments[0]) if arguments.size() > 0 else false,
					String(arguments[1]) if arguments.size() > 1 else "")
		"blason":
			raison = _changer_blason(nom, int(arguments[0]) if arguments.size() > 0 else 0, int(arguments[1]) if arguments.size() > 1 else 0)
		"rejoindre":
			raison = _rejoindre(id, nom, String(arguments[0]) if arguments.size() > 0 else "")
		"fonder":
			raison = _fonder(id, nom, String(arguments[0]) if arguments.size() > 0 else "", int(arguments[1]) if arguments.size() > 1 else 0)
			Regles.chez(id, self, "_reponse_fondation", [raison])
			return
		"inviter":
			raison = _inviter(id, nom, String(arguments[0]) if arguments.size() > 0 else "")
		"repondre":
			raison = _repondre(id, nom, bool(arguments[0]) if arguments.size() > 0 else false)
		"quitter":
			raison = _quitter(id, nom)
		"exclure":
			raison = _exclure(nom, String(arguments[0]) if arguments.size() > 0 else "")
		"promouvoir", "retrograder":
			var g := guilde_de(nom)
			if g.is_empty():
				raison = "Tu n'as pas de guilde."
			else:
				raison = R.changer_rang(d, g, nom, String(arguments[0]) if arguments.size() > 0 else "", -1 if action == "promouvoir" else 1, maintenant_unix())
				if raison == "":
					_changer(g)
		"maitre":
			var g := guilde_de(nom)
			raison = "Tu n'as pas de guilde." if g.is_empty() else R.nommer_maitre(d, g, nom, String(arguments[0]) if arguments.size() > 0 else "", maintenant_unix())
			if raison == "":
				_changer(g)
				_a_toute_la_guilde(g, "%s est le nouveau maître de la guilde « %s »." % [R.maitre(g), g["nom"]])
		"message":
			raison = _message(nom, String(arguments[0]) if arguments.size() > 0 else "")
		"deposer":
			raison = _deposer(id, nom, int(arguments[0]) if arguments.size() > 0 else -1)
		"retirer":
			raison = _retirer(id, nom, int(arguments[0]) if arguments.size() > 0 else -1)
		_:
			raison = "Action inconnue"
	if raison != "":
		_info(id, raison)


func _annonce(id: int, nom: String, nom_cache: String, couleur_cache: int, origine: String, serveur_vu: String, en_attente: Dictionary) -> void:
	var g := guilde_de(nom)
	if g.is_empty() and nom_cache.strip_edges() != "":
		if origine in ["", "seul"]:
			# Guilde fondée en jeu solo (ou avant que le serveur gère les guildes) : on
			# l'enregistre ici, si le nom est libre.
			var raison := R.raison_nom(d, nom_cache, _noms_pris())
			if raison == "":
				g = _creer(nom, nom_cache, couleur_cache)
				_info(id, "Ta guilde « %s » est maintenant enregistrée sur ce serveur. Tu en es le maître." % g["nom"])
			elif origine == "" or serveur_vu == "seul":
				Regles.chez(id, self, "_recevoir_vue", [{}, "exclu"])
				_info(id, "Le nom de ta guilde « %s » ne peut pas être gardé ici (%s) Tu peux en fonder une autre au registraire." % [nom_cache, raison.trim_suffix(".") + "."])
				return
			else:
				Regles.chez(id, self, "_recevoir_vue", [{}, "ailleurs"])
				return
		elif origine == serveur_vu:
			Regles.chez(id, self, "_recevoir_vue", [{}, "exclu"])
			_info(id, "Tu ne fais plus partie de la guilde « %s »." % nom_cache)
			return
		else:
			Regles.chez(id, self, "_recevoir_vue", [{}, "ailleurs"])
			return
	if g.is_empty():
		Regles.chez(id, self, "_recevoir_vue", [{}, "aucune"])
		return
	g["membres"][R.cle(nom)]["vu"] = maintenant_unix()
	R.verifier_semaine(d, g, semaine())
	_changer(g)
	if not en_attente.is_empty():
		_appliquer_attente(g, nom, en_attente)
		Regles.chez(id, self, "_attente_acceptee", [])
	_livrer(g, nom)
	_envoyer_vue(id, nom)
	if String(g["message"]) != "":
		_info(id, "Message de la guilde : %s" % g["message"])


func _noms_pris() -> Array:
	return _guildes.values().map(func(g): return String(g["nom"]))


func _creer(fondateur: String, nom_guilde: String, numero_couleur: int) -> Dictionary:
	var g := R.nouvelle(d, nom_guilde, numero_couleur, fondateur, maintenant_unix())
	R.verifier_semaine(d, g, semaine())
	_guildes[String(g["cle"])] = g
	_index[R.cle(fondateur)] = String(g["cle"])
	_invitations.erase(R.cle(fondateur))
	_changer(g)
	sauvegarder()
	return g


func _fonder(id: int, nom: String, nom_guilde: String, numero_couleur: int) -> String:
	if not guilde_de(nom).is_empty():
		return "Tu fais déjà partie d'une guilde."
	var raison := R.raison_nom(d, nom_guilde, _noms_pris())
	if raison != "":
		return raison
	var g := _creer(nom, nom_guilde, numero_couleur)
	_envoyer_vue(id, nom)
	_info(id, "Guilde fondée : « %s ». Invite tes amis avec /ginviter Nom, ou ouvre la fenêtre Guilde (touche G)." % g["nom"],
			"Guilde fondée")
	return ""


func _inviter(id: int, nom: String, nom_cible: String) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde. Fonde-la au registraire de la Maison des guildes."
	if not R.peut(d, R.rang_de(g, nom), "inviter"):
		return "Ton rang (%s) ne permet pas d'inviter." % R.nom_rang(d, R.rang_de(g, nom))
	var cible := Social._id_de(nom_cible)
	if cible == 0:
		return "Personne ne s'appelle « %s » sur ce serveur." % nom_cible.left(24)
	var vrai_nom := String(Reseau.noms[cible])
	if cible == id:
		return "Tu fais déjà partie de ta guilde !"
	if not guilde_de(vrai_nom).is_empty():
		return "%s fait déjà partie d'une guilde." % vrai_nom
	if R.nombre_membres(g) >= R.membres_max(d, g):
		return "Ta guilde est complète (%d membres). Elle pourra en accueillir plus en montant de niveau." % R.membres_max(d, g)
	_invitations[R.cle(vrai_nom)] = {"guilde": g["cle"], "de": nom,
			"fin": Regles.maintenant() + float(R.reglage(d, "invitation_duree", 90))}
	Regles.chez(cible, self, "_recevoir_invitation", [nom, g["nom"]])
	_info(id, "Invitation dans la guilde envoyée à %s." % vrai_nom)
	return ""


func _repondre(id: int, nom: String, accepter: bool) -> String:
	var inv: Dictionary = _invitations.get(R.cle(nom), {})
	_invitations.erase(R.cle(nom))
	if inv.is_empty():
		return "Cette invitation a expiré." if accepter else ""
	var g: Dictionary = _guildes.get(String(inv["guilde"]), {})
	var id_hote := Social._id_de(String(inv["de"]))
	if not accepter:
		_info(id_hote, "%s refuse de rejoindre la guilde." % nom)
		return ""
	if g.is_empty():
		return "Cette guilde n'existe plus."
	if not guilde_de(nom).is_empty():
		return "Tu fais déjà partie d'une guilde."
	if R.nombre_membres(g) >= R.membres_max(d, g):
		return "La guilde « %s » est complète." % g["nom"]
	R.ajouter_membre(d, g, nom, String(d.get("rang_nouveau_membre", "recrue")), maintenant_unix())
	_index[R.cle(nom)] = String(g["cle"])
	R.noter(d, g, "%s rejoint la guilde (invité par %s)." % [nom, inv["de"]], maintenant_unix())
	_changer(g)
	sauvegarder()
	_a_toute_la_guilde(g, "%s rejoint la guilde « %s » !" % [nom, g["nom"]])
	_info(id, "Bienvenue dans la guilde « %s » ! Touche G pour voir les membres, la banque et les contrats." % g["nom"], "Nouvelle guilde")
	_envoyer_vue(id, nom)
	return ""


## La liste des guildes pour le tableau de recrutement : ouvertes d'abord, puis par taille.
func _annuaire() -> Array:
	var liste: Array = []
	for cg in _guildes:
		var g: Dictionary = _guildes[cg]
		liste.append(R.fiche_annuaire(d, g, ids_en_ligne_de_la_guilde_de(R.maitre(g)).size() if R.maitre(g) != "" else 0))
	liste.sort_custom(func(a, b):
		if a["ouvert"] != b["ouvert"]:
			return a["ouvert"]
		if a["membres"] != b["membres"]:
			return a["membres"] > b["membres"]
		return String(a["nom"]).naturalnocasecmp_to(String(b["nom"])) < 0)
	return liste


func _changer_recrutement(nom: String, ouvert: bool, devise: String) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde."
	if not R.peut(d, R.rang_de(g, nom), "inviter"):
		return "Seuls les officiers et le maître de guilde peuvent changer le recrutement."
	g["recrutement"] = {"ouvert": ouvert, "devise": R.devise_propre(d, devise)}
	R.noter(d, g, "%s %s le recrutement." % [nom, "ouvre" if ouvert else "ferme"], maintenant_unix())
	_changer(g)
	sauvegarder()
	return ""


func _changer_blason(nom: String, forme: int, symbole: int) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde."
	if not R.peut(d, R.rang_de(g, nom), "promouvoir"):
		return "Seuls les officiers et le maître de guilde peuvent changer le blason."
	g["blason"] = {"forme": posmod(forme, R.NB_FORMES), "symbole": posmod(symbole, R.NB_SYMBOLES)}
	_changer(g)
	sauvegarder()
	return ""


func _rejoindre(id: int, nom: String, nom_guilde: String) -> String:
	if not guilde_de(nom).is_empty():
		return "Tu fais déjà partie d'une guilde."
	var g: Dictionary = _guildes.get(R.cle(nom_guilde), {})
	if g.is_empty():
		return "Cette guilde n'existe plus."
	if not R.recrutement(g)["ouvert"]:
		return "La guilde « %s » ne recrute pas en ce moment : demande une invitation à un officier." % g["nom"]
	if R.nombre_membres(g) >= R.membres_max(d, g):
		return "La guilde « %s » est complète." % g["nom"]
	R.ajouter_membre(d, g, nom, String(d.get("rang_nouveau_membre", "recrue")), maintenant_unix())
	_index[R.cle(nom)] = String(g["cle"])
	_invitations.erase(R.cle(nom))
	R.noter(d, g, "%s rejoint la guilde (tableau de recrutement)." % nom, maintenant_unix())
	_changer(g)
	sauvegarder()
	_a_toute_la_guilde(g, "%s rejoint la guilde « %s » !" % [nom, g["nom"]])
	_info(id, "Bienvenue dans la guilde « %s » ! Touche G pour voir les membres, la banque et les contrats." % g["nom"], "Nouvelle guilde")
	_envoyer_vue(id, nom)
	return ""


func _quitter(id: int, nom: String) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde."
	if R.nombre_membres(g) == 1:
		for c in g["banque"]:
			if not (c as Dictionary).is_empty():
				return "Tu es le dernier membre : vide d'abord la banque de la guilde avant de la dissoudre."
		_guildes.erase(String(g["cle"]))
		_index.erase(R.cle(nom))
		_modifie = true
		sauvegarder()
		Regles.chez(id, self, "_recevoir_vue", [{}, "exclu"])
		_info(id, "La guilde « %s » est dissoute." % g["nom"])
		return ""
	var nouveau := R.retirer_membre(d, g, nom)
	_index.erase(R.cle(nom))
	R.noter(d, g, "%s quitte la guilde." % nom, maintenant_unix())
	if nouveau != "":
		R.noter(d, g, "%s devient maître de guilde." % nouveau, maintenant_unix())
	_changer(g)
	sauvegarder()
	Regles.chez(id, self, "_recevoir_vue", [{}, "exclu"])
	_info(id, "Tu as quitté la guilde « %s »." % g["nom"])
	_a_toute_la_guilde(g, "%s a quitté la guilde.%s" % [nom, (" %s devient maître de guilde." % nouveau) if nouveau != "" else ""])
	return ""


func _exclure(nom: String, nom_cible: String) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde."
	if not R.peut(d, R.rang_de(g, nom), "exclure"):
		return "Ton rang ne permet pas d'exclure."
	if not R.est_membre(g, nom_cible):
		return "%s n'est pas dans la guilde." % nom_cible
	if not R.au_dessus(d, g, nom, nom_cible):
		return "Tu ne peux exclure que les membres en dessous de toi."
	var vrai_nom := String(R.membre(g, nom_cible)["nom"])
	R.retirer_membre(d, g, vrai_nom)
	_index.erase(R.cle(vrai_nom))
	R.noter(d, g, "%s exclut %s de la guilde." % [nom, vrai_nom], maintenant_unix())
	_changer(g)
	sauvegarder()
	var id_cible := Social._id_de(vrai_nom)
	if id_cible != 0:
		Regles.chez(id_cible, self, "_recevoir_vue", [{}, "exclu"])
		_info(id_cible, "%s t'a exclu de la guilde « %s »." % [nom, g["nom"]])
	_a_toute_la_guilde(g, "%s a été exclu de la guilde." % vrai_nom)
	return ""


func _message(nom: String, texte: String) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde."
	if not R.peut(d, R.rang_de(g, nom), "message"):
		return "Ton rang ne permet pas de changer le message de guilde."
	texte = Social._nettoyer_texte(texte).left(int(R.reglage(d, "message_max", 160)))
	g["message"] = texte
	R.noter(d, g, "%s change le message de guilde." % nom, maintenant_unix())
	_changer(g)
	if texte != "":
		_a_toute_la_guilde(g, "Message de la guilde : %s" % texte)
	return ""


# --- Banque ---------------------------------------------------------------------------------

func _pres_du_coffre(id: int) -> bool:
	if coffre_partout:
		return true
	var p := Social._personnage(id)
	if p == null:
		return false
	var portee := float(R.reglage(d, "banque_distance", 6.0))
	for c in get_tree().get_nodes_in_group("coffre_guilde"):
		if c is Node3D and (c as Node3D).global_position.distance_to(p.global_position) <= portee:
			return true
	return false


func _inventaire(id: int) -> Node:
	var p := Social._personnage(id)
	return p.get_node_or_null("Inventaire") if p != null else null


func _deposer(id: int, nom: String, index: int) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde."
	if not _pres_du_coffre(id):
		return "Approche-toi du coffre de guilde (Maison des guildes, quartier des Résidences)."
	var inv := _inventaire(id)
	if inv == null or (inv.etat as Dictionary).is_empty():
		return "?"
	var cases: Array = inv.etat["cases"]
	if index < 0 or index >= cases.size() or (cases[index] as Dictionary).is_empty():
		return "Rien à déposer dans cette case."
	var c: Dictionary = cases[index]
	var objet := String(c["id"])
	var n := int(c["n"])
	var reste := R.deposer(Donnees.objets, d, g, objet, n)
	if reste >= n:
		return "La banque de la guilde est pleine."
	cases[index] = {"id": objet, "n": reste} if reste > 0 else {}
	inv._appliquer()
	R.noter(d, g, "%s dépose %s." % [nom, _nom_objet(objet, n - reste)], maintenant_unix())
	_changer(g)
	return ""


func _retirer(id: int, nom: String, index: int) -> String:
	var g := guilde_de(nom)
	if g.is_empty():
		return "Tu n'as pas de guilde."
	if not _pres_du_coffre(id):
		return "Approche-toi du coffre de guilde (Maison des guildes, quartier des Résidences)."
	var banque: Array = g["banque"]
	if index < 0 or index >= banque.size() or (banque[index] as Dictionary).is_empty():
		return "Cette place de la banque est vide."
	var restants := R.retraits_restants(d, g, nom, jour())
	if restants == 0:
		var limite := int(R.infos_rang(d, R.rang_de(g, nom)).get("retraits_par_jour", 0))
		if limite == 0:
			return "Ton rang (%s) permet de déposer, pas encore de sortir des objets. Demande à un officier de te promouvoir." % R.nom_rang(d, R.rang_de(g, nom))
		return "Tu as sorti %d objets aujourd'hui : c'est le maximum pour ton rang." % limite
	var inv := _inventaire(id)
	if inv == null or (inv.etat as Dictionary).is_empty():
		return "?"
	var o: Dictionary = banque[index]
	var objet := String(o["id"])
	var n := int(o["n"])
	var reste := Objets.ajouter(Donnees.objets, inv.etat, objet, n)
	if reste >= n:
		return "Tes sacs sont pleins."
	banque[index] = {"id": objet, "n": reste} if reste > 0 else {}
	R.noter_retrait(g, nom, jour())
	inv._appliquer()
	R.noter(d, g, "%s sort %s." % [nom, _nom_objet(objet, n - reste)], maintenant_unix())
	_changer(g)
	return ""


func _nom_objet(id: String, n: int) -> String:
	var nom := String(Objets.objet(Donnees.objets, id).get("nom", id))
	return "%s × %d" % [nom, n] if n > 1 else nom


# --- Contributions aux contrats ---------------------------------------------------------------

## Serveur : un joueur a fait quelque chose qui compte pour sa guilde (« ennemi », « recolte »…).
## Si sa guilde n'est pas gérée ici (donjon, autre serveur), c'est gardé chez lui pour plus tard.
func contribuer(joueur: Node, type: String, n := 1) -> void:
	if joueur == null or n <= 0 or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if not (d.get("xp_par_action", {}) as Dictionary).has(type):
		return
	var id: int = joueur.id_reseau()
	var nom := String(Reseau.noms.get(id, joueur.get("nom")))
	if actif_ici():
		var g := guilde_de(nom)
		if not g.is_empty():
			_appliquer_contribution(g, nom, type, n)
			return
	Regles.chez(id, self, "_mettre_en_attente", [type, n])


## Serveur : un ennemi vaincu compte comme « ennemi », et aussi « fracture » ou « chef »
## (et « donjon » pour le chef d'un donjon).
func ennemi_vaincu(joueur: Node, type_ennemi: String) -> void:
	contribuer(joueur, "ennemi")
	var t := R.type_ennemi(d, type_ennemi)
	if t != "ennemi":
		contribuer(joueur, t)
	if t == "chef" and Reseau.instance:
		contribuer(joueur, "donjon")


func _appliquer_attente(g: Dictionary, nom: String, en_attente: Dictionary) -> void:
	var maxi := int(R.reglage(d, "attente_max_par_type", 400))
	for type in en_attente:
		if (d.get("xp_par_action", {}) as Dictionary).has(String(type)):
			_appliquer_contribution(g, nom, String(type), clampi(int(en_attente[type]), 0, maxi))


func _appliquer_contribution(g: Dictionary, nom: String, type: String, n: int) -> void:
	if n <= 0:
		return
	var res := R.contribuer(d, g, nom, type, n, semaine())
	_changer(g)
	for titre in res["contrats_finis"]:
		R.noter(d, g, "Contrat accompli : %s." % titre, maintenant_unix())
		_a_toute_la_guilde(g, "Contrat de guilde accompli : %s ! Ceux qui ont aidé reçoivent %d Sceaux de guilde." % [titre, R.sceaux_par_contrat(d, g)],
				"Contrat de guilde accompli")
	if res["semaine_complete"]:
		R.noter(d, g, "Tous les contrats de la semaine sont accomplis !", maintenant_unix())
		_a_toute_la_guilde(g, "Tous les contrats de la semaine sont accomplis ! Bonus : %d Sceaux de guilde pour chaque membre qui a aidé." % int(R.reglage(d, "sceaux_semaine_complete", 20)),
				"Semaine accomplie")
	if int(res["niveau"]) > int(res["niveau_avant"]):
		R.noter(d, g, "La guilde passe au niveau %d." % res["niveau"], maintenant_unix())
		_a_toute_la_guilde(g, "La guilde « %s » passe au niveau %d ! Banque : %d places, jusqu'à %d membres." % [g["nom"], res["niveau"], R.places_banque(d, g), R.membres_max(d, g)],
				"Guilde niveau %d" % res["niveau"])
	for c in (res["recompenses"] as Dictionary):
		_livrer(g, String(g["membres"][c]["nom"]))


## Donne à un membre (s'il est là) les sceaux qu'il a gagnés. Ce qui ne rentre pas attend.
func _livrer(g: Dictionary, nom: String) -> void:
	var liste: Array = (g.get("a_donner", {}) as Dictionary).get(R.cle(nom), [])
	if liste.is_empty():
		return
	var id := Social._id_de(nom)
	var inv := _inventaire(id) if id != 0 else null
	if inv == null or (inv.etat as Dictionary).is_empty():
		return
	var restants: Array = inv.recevoir(liste)
	var donnes := 0
	for o in liste:
		donnes += int(o["n"])
	for o in restants:
		donnes -= int(o["n"])
	if restants.is_empty():
		g["a_donner"].erase(R.cle(nom))
	else:
		g["a_donner"][R.cle(nom)] = restants
	_changer(g)
	if donnes > 0:
		_info(id, "Tu reçois %d Sceaux de guilde (contrats de la semaine). Mei Takahara les échange à la Maison des guildes." % donnes)
	if not restants.is_empty():
		_info(id, "Sacs pleins : le reste de tes sceaux de guilde t'attend (fais de la place).")
