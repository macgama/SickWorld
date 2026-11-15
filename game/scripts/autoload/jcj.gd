extends Node
## L'ARÈNE JcJ (joueur contre joueur) de Hikari Bay : des DUELS (1 contre 1) et des
## ESCARMOUCHES (2 contre 2) sur le terrain de l'Arène de la baie.
##
## Deux façons de trouver un adversaire :
## - DÉFIER un joueur : le cibler puis cliquer sur « Défier » (ou taper /duel Nom).
##   Si on est en groupe de 2 et lui aussi (dans un autre groupe), c'est un 2 contre 2 ;
## - S'INSCRIRE dans une FILE D'ATTENTE : borne à l'entrée de l'Arène, touche H ou /arene.
##   Pour le 2 contre 2, il faut être en groupe de 2 : tout le groupe s'inscrit ensemble.
##
## Déroulement d'un combat : les combattants sont amenés sur le terrain, soignés,
## figés pendant un compte à rebours (3… 2… 1…), puis « COMBAT ! ». Une équipe gagne
## quand tous ses adversaires sont désynchronisés (ou ont quitté le terrain). Au bout
## de 3 minutes, l'équipe qui a gardé le plus de vie gagne. À la fin, tout le monde
## est soigné SANS pénalité et ramené là où il était. Le classement compte les victoires.
##
## Les spectateurs (tous les autres joueurs) ne peuvent ni frapper ni soigner les
## combattants, et les combattants ne peuvent pas les toucher : pendant le combat,
## chaque équipe porte une faction « arene_0 » / « arene_1 » (voir Combattant.est_hostile).
##
## Comme pour tout le reste, c'est le SERVEUR qui décide (défis, files, vainqueur).
## Réglages : data/arene.json.

## Chez le joueur : l'état du combat en cours a changé (voir « etat »).
signal etat_change
## Chez le joueur : quelqu'un nous défie ("" = le défi est fini).
signal defi_change(de: String, format: String)
## Chez le joueur : notre inscription dans une file a changé ("" = pas inscrit).
signal file_change(format: String)
## Chez le joueur : le classement demandé est arrivé.
signal classement_recu(liste: Array)

const FICHIER_REGLAGES := "res://data/arene.json"
const SCRIPT_INTERFACE := "res://scripts/interface/interface_arene.gd"
const FORMATS := ["1c1", "2c2"]

var reglages := {}
## Serveur : fichier du classement (nombre de victoires de chaque joueur).
var fichier_classement := "user://arene.cfg"

# --- Chez le joueur ---
## Le combat en cours, envoyé par le serveur à tous les joueurs :
## {format, equipes: [[noms], [noms]], phase: "preparation"|"combat"|"resultat",
##  temps (secondes restantes dans la phase), vainqueur (-1 inconnu, 0 ou 1, 2 = égalité),
##  elimines: [noms]}. Vide = pas de combat.
var etat := {}
## Moment (temps de jeu) où la phase en cours se termine, d'après « temps ».
var fin_phase_locale := 0.0
var defi_de := ""
var defi_format := ""
var ma_file := ""
var classement: Array = []
var _interface: Node

# --- Sur le serveur ---
## Défis envoyés : nom de l'invité (minuscules) -> {de, format, equipes, fin}.
var _defis := {}
## Files d'attente : format -> liste d'équipes (chaque équipe = liste de noms).
var _files := {"1c1": [], "2c2": []}
## Combats formés (défi accepté) qui attendent que l'arène se libère : [{format, equipes}].
var _prets: Array = []
## Le combat en cours (vide = arène libre).
var _match := {}
var _minuteur := 0.0
var _prochaine_diffusion := 0.0
## Tests sans réseau seulement : fait comme si la demande venait de ce joueur (0 = normal).
var expediteur_force := 0


func _ready() -> void:
	var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_REGLAGES)) if FileAccess.file_exists(FICHIER_REGLAGES) else null
	reglages = lu if lu is Dictionary else {}
	Reseau.joueur_parti.connect(_sur_depart)
	multiplayer.server_disconnected.connect(_oublier)


func _process(delta: float) -> void:
	_minuteur += delta
	if _minuteur >= 0.5:
		_minuteur = 0.0
		_installer_interface()
		if _serveur_actif():
			_nettoyer()
	if _serveur_actif():
		_avancer()


func _serveur_actif() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func reglage(cle: String, defaut: float) -> float:
	return float(reglages.get(cle, defaut))


func nom_format(format: String) -> String:
	var f: Dictionary = reglages.get("formats", {}).get(format, {})
	return "%s (%s)" % [f.get("nom", format), f.get("detail", format)]


func joueurs_par_equipe(format: String) -> int:
	return int(reglages.get("formats", {}).get(format, {}).get("joueurs_par_equipe", 1))


# =============================================================================
# Côté joueur : ce que l'interface appelle
# =============================================================================

## Défie un joueur (format "" = choisi par le serveur : 2c2 si les deux groupes ont 2 joueurs).
func defier(nom: String, format := "") -> void:
	if nom.strip_edges() == "":
		Social._systeme("Pour défier quelqu'un : /duel Nom (ou cible le joueur et clique sur « Défier »).")
		return
	Regles.au_serveur(self, "_demander_defi", [nom.strip_edges(), format])


func repondre_defi(accepter: bool) -> void:
	defi_de = ""
	defi_format = ""
	defi_change.emit("", "")
	Regles.au_serveur(self, "_demander_reponse_defi", [accepter])


func inscrire(format: String) -> void:
	Regles.au_serveur(self, "_demander_inscription", [format])


func desinscrire() -> void:
	Regles.au_serveur(self, "_demander_desinscription", [])


func demander_classement() -> void:
	Regles.au_serveur(self, "_demander_classement", [])


func basculer_fenetre() -> void:
	if _interface != null and is_instance_valid(_interface):
		_interface.basculer_fenetre()


## Vrai s'il y a un combat dans l'arène en ce moment.
func combat_en_cours() -> bool:
	return not etat.is_empty()


## Vrai si ce joueur (par son nom) se bat dans l'arène en ce moment (chez le joueur).
func se_bat(nom: String) -> bool:
	return equipe_de(nom) >= 0


## Numéro de l'équipe de ce joueur dans le combat en cours (-1 = il ne se bat pas).
func equipe_de(nom: String) -> int:
	var equipes: Array = etat.get("equipes", [])
	for i in equipes.size():
		for n in equipes[i]:
			if String(n).to_lower() == nom.to_lower():
				return i
	return -1


func je_me_bats() -> bool:
	return se_bat(Social.mon_nom())


## Secondes restantes dans la phase en cours (compte à rebours, temps du combat…).
func temps_restant() -> float:
	return maxf(0.0, fin_phase_locale - Regles.maintenant())


## Texte court du combat : « Alice contre Bob », « Alice & Léa contre Bob & Tom ».
static func titre_combat(equipes: Array) -> String:
	var parts: Array[String] = []
	for e in equipes:
		parts.append(" & ".join(PackedStringArray(e)))
	return " contre ".join(PackedStringArray(parts))


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
	_interface.name = "InterfaceArene"
	partie.add_child(_interface)
	_mettre_a_jour_ecran()


func _oublier() -> void:
	etat = {}
	defi_de = ""
	ma_file = ""
	etat_change.emit()
	defi_change.emit("", "")
	file_change.emit("")


## Le grand écran au-dessus des tribunes montre le combat en cours.
func _mettre_a_jour_ecran() -> void:
	var ecran := get_tree().get_first_node_in_group("ecran_arene") as Label3D
	if ecran == null:
		return
	if etat.is_empty():
		ecran.text = "ARÈNE · アリーナ\nDuels 1c1 · Escarmouches 2c2\nInscription à l'entrée (touche H)"
		return
	var phase := String(etat.get("phase", ""))
	var ligne := "EN DIRECT"
	if phase == "preparation":
		ligne = "Le combat va commencer…"
	elif phase == "resultat":
		var v := int(etat.get("vainqueur", -1))
		var equipes: Array = etat.get("equipes", [])
		ligne = "Égalité !" if v == 2 or v < 0 or v >= equipes.size() \
				else "Victoire : " + " & ".join(PackedStringArray(equipes[v]))
	ecran.text = "%s · %s\n%s\n%s" % [nom_format(String(etat.get("format", ""))).to_upper(), "アリーナ",
			titre_combat(etat.get("equipes", [])), ligne]


# =============================================================================
# Chez le joueur : ce que le serveur nous envoie
# =============================================================================

func _vient_du_serveur() -> bool:
	return multiplayer.get_remote_sender_id() in [0, 1]


@rpc("authority", "call_remote", "reliable")
func _recevoir_etat(nouvel_etat: Dictionary) -> void:
	if not _vient_du_serveur():
		return
	etat = nouvel_etat
	fin_phase_locale = Regles.maintenant() + float(etat.get("temps", 0.0))
	etat_change.emit()
	_mettre_a_jour_ecran()


@rpc("authority", "call_remote", "reliable")
func _recevoir_defi(de: String, format: String) -> void:
	if not _vient_du_serveur():
		return
	defi_de = de
	defi_format = format
	defi_change.emit(de, format)


@rpc("authority", "call_remote", "reliable")
func _recevoir_file(format: String) -> void:
	if not _vient_du_serveur():
		return
	ma_file = format
	file_change.emit(format)


@rpc("authority", "call_remote", "reliable")
func _recevoir_classement(liste: Array) -> void:
	if not _vient_du_serveur():
		return
	classement = liste
	classement_recu.emit(liste)


# =============================================================================
# Côté serveur : les demandes des joueurs
# =============================================================================

## Le terrain de l'arène dans la scène du serveur (null = pas d'arène ici).
func _expediteur() -> int:
	return expediteur_force if expediteur_force != 0 else Regles.expediteur()


func _terrain() -> Node3D:
	return get_tree().get_first_node_in_group("arene_jcj") as Node3D


func _rayon() -> float:
	var t := _terrain()
	return float(t.get_meta("rayon", 17.0)) if t != null else 17.0


func _personnage_de(nom: String) -> Node3D:
	return Social._personnage(Social._id_de(nom))


func _combattant_de(nom: String) -> Combattant:
	var p := _personnage_de(nom)
	return p.get_node_or_null("Combat") as Combattant if p != null else null


func _message(nom: String, texte: String) -> void:
	Social._au_joueur_systeme(Social._id_de(nom), "[Arène] " + texte)


func _message_equipes(equipes: Array, texte: String) -> void:
	for e in equipes:
		for nom in e:
			_message(String(nom), texte)


## Où en est ce joueur avec l'arène : "" (libre), "combat", "attente" (combat prêt), "file".
func _occupation(nom: String) -> String:
	var cle := nom.to_lower()
	for e in _match.get("equipes", []):
		for n in e:
			if String(n).to_lower() == cle:
				return "combat"
	for m in _prets:
		for e in m["equipes"]:
			for n in e:
				if String(n).to_lower() == cle:
					return "attente"
	for format in _files:
		for e in _files[format]:
			for n in e:
				if String(n).to_lower() == cle:
					return format
	return ""


## Vrai si ce joueur se bat dans l'arène (serveur ; utilisé pour bloquer la réapparition).
func participe(id_joueur: int) -> bool:
	return _occupation(Social._nom_de(id_joueur)) == "combat"


## L'équipe d'un joueur pour un 2 contre 2 : son groupe s'il a exactement 2 membres.
func _equipe_groupe(nom: String, taille: int) -> Array:
	var numero: int = Social.groupe_du_joueur(nom)
	if numero == 0:
		return []
	var membres: Array = Social.membres_du_groupe(numero)
	return membres if membres.size() == taille else []


func _tous_presents(equipe: Array) -> bool:
	for nom in equipe:
		if _personnage_de(String(nom)) == null:
			return false
	return true


@rpc("any_peer", "call_remote", "reliable")
func _demander_defi(nom_cible: String, format: String) -> void:
	if not multiplayer.is_server():
		return
	var id := _expediteur()
	var moi := Social._nom_de(id)
	if _terrain() == null:
		_message(moi, "L'Arène est à Hikari Bay, au bout du front de mer (sud-est).")
		return
	var id_cible := Social._id_de(nom_cible)
	if id_cible == 0:
		_message(moi, "Personne ne s'appelle « %s » ici." % nom_cible)
		return
	var cible := Social._nom_de(id_cible)
	if id_cible == id:
		_message(moi, "Tu ne peux pas te défier toi-même. Essaie plutôt la championne Akane !")
		return
	var equipes: Array = [[moi], [cible]]
	if format == "" or format == "2c2":
		var a := _equipe_groupe(moi, 2)
		var b := _equipe_groupe(cible, 2)
		if not a.is_empty() and not b.is_empty() and Social.groupe_du_joueur(moi) != Social.groupe_du_joueur(cible):
			equipes = [a, b]
			format = "2c2"
		elif format == "2c2":
			_message(moi, "Pour un 2 contre 2, il faut être en groupe de 2, et ton adversaire aussi.")
			return
	if format == "":
		format = "1c1"
	if not FORMATS.has(format):
		return
	for e in equipes:
		for nom in e:
			if not _tous_presents([nom]):
				_message(moi, "%s n'est pas à Hikari Bay en ce moment." % nom)
				return
			if _occupation(String(nom)) in ["combat", "attente"]:
				_message(moi, "%s a déjà un combat à l'Arène." % nom)
				return
	if _defis.has(cible.to_lower()):
		_message(moi, "%s a déjà un défi en attente." % cible)
		return
	_defis[cible.to_lower()] = {"de": moi, "format": format, "equipes": equipes,
			"fin": Regles.maintenant() + reglage("duree_defi", 30.0)}
	Regles.chez(id_cible, self, "_recevoir_defi", [moi, format])
	_message(moi, "Défi envoyé à %s : %s." % [cible, nom_format(format)])


@rpc("any_peer", "call_remote", "reliable")
func _demander_reponse_defi(accepter: bool) -> void:
	if not multiplayer.is_server():
		return
	var moi := Social._nom_de(_expediteur())
	var d: Dictionary = _defis.get(moi.to_lower(), {})
	_defis.erase(moi.to_lower())
	if d.is_empty():
		return
	if not accepter:
		_message(String(d["de"]), "%s refuse ton défi." % moi)
		return
	var equipes: Array = d["equipes"]
	for e in equipes:
		if not _tous_presents(e):
			_message_equipes(equipes, "Combat annulé : quelqu'un n'est plus là.")
			return
		for nom in e:
			if _occupation(String(nom)) in ["combat", "attente"]:
				_message_equipes(equipes, "Combat annulé : %s a déjà un combat." % nom)
				return
	# Un défi accepté passe avant les files : on sort ces joueurs des files.
	for e in equipes:
		for nom in e:
			_retirer_de_la_file(String(nom), "")
	_prets.append({"format": String(d["format"]), "equipes": equipes})
	var texte := "%s accepte ! %s : %s." % [moi, nom_format(String(d["format"])), titre_combat(equipes)]
	if not _match.is_empty() or _prets.size() > 1:
		texte += " L'arène est occupée : vous passez juste après."
	_message_equipes(equipes, texte)


@rpc("any_peer", "call_remote", "reliable")
func _demander_inscription(format: String) -> void:
	if not multiplayer.is_server() or not FORMATS.has(format):
		return
	var moi := Social._nom_de(_expediteur())
	if _terrain() == null:
		_message(moi, "L'Arène est à Hikari Bay, au bout du front de mer (sud-est).")
		return
	var equipe: Array = [moi]
	if format == "2c2":
		equipe = _equipe_groupe(moi, 2)
		if equipe.is_empty():
			_message(moi, "Pour le 2 contre 2, forme d'abord un groupe de 2 joueurs (/inviter Nom).")
			return
		if not _tous_presents(equipe):
			_message(moi, "Ton coéquipier doit être à Hikari Bay.")
			return
	for nom in equipe:
		var occ := _occupation(String(nom))
		if occ in ["combat", "attente"]:
			_message(moi, "%s a déjà un combat à l'Arène." % nom)
			return
		if occ != "":
			_retirer_de_la_file(String(nom), "")
	_files[format].append(equipe)
	for nom in equipe:
		Regles.chez(Social._id_de(String(nom)), self, "_recevoir_file", [format])
	var texte := "Inscription : %s. Recherche d'adversaires…" % nom_format(format)
	if format == "2c2":
		texte = "%s inscrit ton groupe : %s. Recherche d'adversaires…" % [moi, nom_format(format)]
	_message_equipes([equipe], texte)


@rpc("any_peer", "call_remote", "reliable")
func _demander_desinscription() -> void:
	if not multiplayer.is_server():
		return
	var moi := Social._nom_de(_expediteur())
	if not _retirer_de_la_file(moi, "%s a quitté la file d'attente de l'Arène." % moi):
		_message(moi, "Tu n'es inscrit dans aucune file.")


## Retire de sa file l'équipe d'un joueur (toute l'équipe). Rend vrai s'il y était.
func _retirer_de_la_file(nom: String, texte: String) -> bool:
	for format in _files:
		var liste: Array = _files[format]
		for i in liste.size():
			var equipe: Array = liste[i]
			if equipe.any(func(n): return String(n).to_lower() == nom.to_lower()):
				liste.remove_at(i)
				for n in equipe:
					Regles.chez(Social._id_de(String(n)), self, "_recevoir_file", [""])
					if texte != "":
						_message(String(n), texte)
				return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func _demander_classement() -> void:
	if not multiplayer.is_server():
		return
	Regles.chez(_expediteur(), self, "_recevoir_classement", [meilleurs(10)])


## Un joueur se déconnecte : il quitte les files ; en combat, il est éliminé (voir _avancer).
func _sur_depart(_id: int, nom: String) -> void:
	_defis.erase(nom.to_lower())
	_retirer_de_la_file(nom, "Ton coéquipier est parti : vous quittez la file d'attente.")


## Toutes les demi-secondes : les défis trop vieux expirent, les absents quittent les files.
func _nettoyer() -> void:
	var t := Regles.maintenant()
	for cle in _defis.keys():
		var d: Dictionary = _defis[cle]
		if t > float(d["fin"]):
			_defis.erase(cle)
			_message(String(d["de"]), "Ton défi n'a pas eu de réponse.")
			var id := Social._id_de(String(cle))
			Regles.chez(id, self, "_recevoir_defi", ["", ""])
	for format in _files:
		for equipe in _files[format].duplicate():
			if not _tous_presents(equipe):
				_retirer_de_la_file(String(equipe[0]), "Quelqu'un de ton équipe n'est plus là : vous quittez la file.")


# =============================================================================
# Côté serveur : le déroulement d'un combat
# =============================================================================

func _avancer() -> void:
	if _match.is_empty():
		_lancer_le_suivant()
		return
	var t := Regles.maintenant()
	match String(_match["phase"]):
		"preparation":
			_verifier_combattants(false)
			if _match.is_empty() or String(_match["phase"]) != "preparation":
				return
			if t >= float(_match["fin_phase"]):
				_match["phase"] = "combat"
				_match["fin_phase"] = t + reglage("duree_max_combat", 180.0)
				var equipes: Array = _match["equipes"]
				for i in equipes.size():
					for nom in equipes[i]:
						var c := _combattant_de(String(nom))
						if c != null:
							c.faction = "arene_%d" % i
				_diffuser()
		"combat":
			_verifier_combattants(true)
			if not _match.is_empty() and String(_match["phase"]) == "combat" and t >= float(_match["fin_phase"]):
				_conclure(_vainqueur_aux_points())
		"resultat":
			if t >= float(_match["fin_phase"]):
				_liberer()
				return
	if not _match.is_empty() and t >= _prochaine_diffusion:
		_diffuser()


## Arène libre : un défi accepté passe en premier, sinon deux équipes d'une même file.
func _lancer_le_suivant() -> void:
	if _terrain() == null:
		return
	var m := {}
	if not _prets.is_empty():
		m = _prets.pop_front()
	else:
		for format in FORMATS:
			var liste: Array = _files[format]
			if liste.size() >= 2:
				var a: Array = liste.pop_front()
				var b: Array = liste.pop_front()
				m = {"format": format, "equipes": [a, b]}
				for n in a + b:
					Regles.chez(Social._id_de(String(n)), self, "_recevoir_file", [""])
				break
	if m.is_empty():
		return
	var equipes: Array = m["equipes"]
	for e in equipes:
		if not _tous_presents(e):
			_message_equipes(equipes, "Combat annulé : quelqu'un n'est plus là.")
			return
	_commencer(String(m["format"]), equipes)


func _commencer(format: String, equipes: Array) -> void:
	var terrain := _terrain()
	var centre := terrain.global_position
	centre.y = 0.0
	var ecart := reglage("ecart_depart", 9.0)
	var compte := reglage("compte_a_rebours", 5.0)
	var retours := {}
	for i in equipes.size():
		var e: Array = equipes[i]
		for j in e.size():
			var nom := String(e[j])
			var p := _personnage_de(nom)
			retours[nom.to_lower()] = [p.global_position, p.rotation.y]
			var cote := -1.0 if i == 0 else 1.0
			var position := centre + Vector3(cote * ecart, 0.0, (j - (e.size() - 1) * 0.5) * 3.0)
			# Face à l'adversaire : l'équipe 0 (ouest) regarde vers l'est, l'équipe 1 vers l'ouest.
			_placer(p, position, -PI / 2.0 if i == 0 else PI / 2.0)
			_remettre_en_forme(p)
			var c := p.get_node("Combat") as Combattant
			c.ajouter_effet("immobilise", compte)
	_match = {"format": format, "equipes": equipes, "phase": "preparation",
			"fin_phase": Regles.maintenant() + compte, "elimines": {}, "retours": retours, "vainqueur": -1}
	_diffuser()
	for id in Reseau.noms:
		Social._au_joueur_systeme(int(id), "[Arène] DJ Volt : « %s à l'Arène de la baie : %s ! »"
				% [nom_format(format), titre_combat(equipes)])


## Soigne complètement, sans pénalité, et remet la ressource (Élan…) au départ.
func _remettre_en_forme(p: Node3D) -> void:
	var c := p.get_node("Combat") as Combattant
	c.reanimer(100.0)
	c.menace.clear()
	var cj = p.get_node_or_null("CombatJoueur")
	if cj != null:
		cj.cible = null
		cj.attaque_auto = false
		cj.elan = float(cj.ressource().get("depart", 0))
	_renvoyer_invocations(p)


## Les loups appelés par un Traqueur repartent (ils ne passent pas d'un camp à l'autre).
func _renvoyer_invocations(p: Node3D) -> void:
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	if dossier == null:
		return
	for loup in dossier.get_children():
		if loup.get("maitre") == p:
			loup.queue_free()


func _placer(p: Node3D, position: Vector3, orientation: float) -> void:
	if p.has_method("placer"):
		p.placer(position, orientation)
	Regles.chez(p.get_multiplayer_authority(), p, "teleporter", [position, orientation])


## Élimine les combattants partis, désynchronisés ou sortis du terrain.
func _verifier_combattants(en_combat: bool) -> void:
	var terrain := _terrain()
	if terrain == null:
		_conclure(2)
		return
	var centre := terrain.global_position
	var limite := _rayon() + reglage("marge_sortie", 1.5)
	var elimines: Dictionary = _match["elimines"]
	var equipes: Array = _match["equipes"]
	var debout := [0, 0]
	for i in equipes.size():
		for nom in equipes[i]:
			var cle := String(nom).to_lower()
			if elimines.has(cle):
				continue
			var p := _personnage_de(String(nom))
			var raison := ""
			if p == null:
				raison = "%s a quitté Hikari Bay." % nom
			elif en_combat and not (p.get_node("Combat") as Combattant).est_vivant():
				raison = "%s est désynchronisé !" % nom
			elif en_combat and Vector2(p.global_position.x - centre.x, p.global_position.z - centre.z).length() > limite:
				raison = "%s a quitté le terrain : abandon." % nom
				(p.get_node("Combat") as Combattant).faction = "joueur"
			if raison != "":
				elimines[cle] = true
				_message_equipes(equipes, raison)
				_prochaine_diffusion = 0.0
			else:
				debout[i] += 1
	if debout[0] == 0 and debout[1] == 0:
		_conclure(2)
	elif debout[0] == 0:
		_conclure(1)
	elif debout[1] == 0:
		_conclure(0)


## Temps écoulé : l'équipe qui a gardé le plus de vie (en %) gagne.
func _vainqueur_aux_points() -> int:
	var scores := [0.0, 0.0]
	var equipes: Array = _match["equipes"]
	for i in equipes.size():
		for nom in equipes[i]:
			var c := _combattant_de(String(nom))
			if c != null and not _match["elimines"].has(String(nom).to_lower()):
				scores[i] += c.pourcentage_pv()
	if absf(scores[0] - scores[1]) < 1.0:
		return 2
	return 0 if scores[0] > scores[1] else 1


## vainqueur : 0 ou 1 (numéro de l'équipe), 2 = égalité.
func _conclure(vainqueur: int) -> void:
	if _match.is_empty() or String(_match["phase"]) == "resultat":
		return
	_match["phase"] = "resultat"
	_match["vainqueur"] = vainqueur
	_match["fin_phase"] = Regles.maintenant() + reglage("duree_resultat", 4.0)
	var equipes: Array = _match["equipes"]
	var format := String(_match["format"])
	for i in equipes.size():
		for nom in equipes[i]:
			var p := _personnage_de(String(nom))
			if p != null:
				(p.get_node("Combat") as Combattant).faction = "joueur"
				_remettre_en_forme(p)
			if vainqueur != 2:
				_noter_resultat(String(nom), format, i == vainqueur)
	_diffuser()
	var texte := "Égalité entre %s !" % titre_combat(equipes)
	if vainqueur != 2:
		texte = "Victoire de %s !" % " & ".join(PackedStringArray(equipes[vainqueur]))
	for id in Reseau.noms:
		Social._au_joueur_systeme(int(id), "[Arène] DJ Volt : « %s »" % texte)


## Fin de l'affichage du résultat : chacun retourne là où il était avant le combat.
func _liberer() -> void:
	var terrain := _terrain()
	var centre := terrain.global_position if terrain != null else Vector3.ZERO
	var retours: Dictionary = _match["retours"]
	for e in _match["equipes"]:
		for nom in e:
			var p := _personnage_de(String(nom))
			var r: Array = retours.get(String(nom).to_lower(), [])
			if p == null or r.is_empty():
				continue
			var position: Vector3 = r[0]
			# Venu du terrain lui-même : on le pose près de l'entrée, à l'intérieur.
			if terrain != null and Vector2(position.x - centre.x, position.z - centre.z).length() < _rayon() + 1.0:
				position = Vector3(centre.x - _rayon() + 3.0, 0.0, centre.z + randf_range(-3.0, 3.0))
			_placer(p, position, float(r[1]))
	_match = {}
	_diffuser()


## Envoie l'état du combat à tous les joueurs (et à nous-même si on joue sur ce PC).
func _diffuser() -> void:
	_prochaine_diffusion = Regles.maintenant() + 1.0
	var e := {}
	if not _match.is_empty():
		e = {"format": _match["format"], "equipes": _match["equipes"], "phase": _match["phase"],
				"temps": maxf(0.0, float(_match["fin_phase"]) - Regles.maintenant()),
				"vainqueur": _match["vainqueur"], "elimines": _match["elimines"].keys()}
	if Reseau.a_un_joueur_local() and not Reseau.noms.has(multiplayer.get_unique_id()):
		_recevoir_etat(e)
	for id in Reseau.noms:
		Regles.chez(int(id), self, "_recevoir_etat", [e])


# --- Classement (serveur) -------------------------------------------------------------

func _cle_joueur(nom: String) -> String:
	return nom.to_lower().md5_text()


func _noter_resultat(nom: String, format: String, victoire: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(fichier_classement))
	var fiche: Dictionary = cfg.get_value("joueurs", _cle_joueur(nom), {})
	fiche["nom"] = nom
	var cle := ("victoires_" if victoire else "defaites_") + format
	fiche[cle] = int(fiche.get(cle, 0)) + 1
	cfg.set_value("joueurs", _cle_joueur(nom), fiche)
	cfg.save(Profil.chemin(fichier_classement))


## Les meilleurs joueurs : [{nom, victoires, defaites, victoires_1c1, …}], triés par victoires.
func meilleurs(nombre: int) -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(Profil.chemin(fichier_classement)) != OK or not cfg.has_section("joueurs"):
		return []
	var liste: Array = []
	for cle in cfg.get_section_keys("joueurs"):
		var f: Dictionary = cfg.get_value("joueurs", cle, {})
		var ligne := {"nom": String(f.get("nom", "?")), "victoires": 0, "defaites": 0}
		for format in FORMATS:
			ligne["victoires_" + format] = int(f.get("victoires_" + format, 0))
			ligne["defaites_" + format] = int(f.get("defaites_" + format, 0))
			ligne["victoires"] += ligne["victoires_" + format]
			ligne["defaites"] += ligne["defaites_" + format]
		liste.append(ligne)
	liste.sort_custom(func(a, b): return a["victoires"] > b["victoires"] \
			or (a["victoires"] == b["victoires"] and a["defaites"] < b["defaites"]))
	return liste.slice(0, nombre)


## Bilan d'un joueur (serveur) : {victoires_1c1, defaites_1c1, …}.
func bilan(nom: String) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(fichier_classement))
	return cfg.get_value("joueurs", _cle_joueur(nom), {})
