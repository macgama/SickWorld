extends Node
## Serveur de la ville : lance et surveille les donjons privés des groupes.
##
## Chaque groupe qui entre dans un donjon reçoit sa propre copie (une « instance ») :
## un autre programme du jeu, sans fenêtre, lancé sur le même ordinateur que la ville,
## sur le port suivant (7778, 7779…). Il s'éteint tout seul quand le groupe est reparti.
## Le donjon suit l'avancée du chef dans l'histoire : sa progression est recopiée
## dans le dossier du donjon (user://profils/instance_<port>/). Les sacs et la
## progression de chaque personnage restent ceux de la ville (« --personnages= ») :
## ce qu'on gagne dans le donjon est gardé en sortant.

const DOSSIER_ETATS := "user://instances/"

## port -> {"pid", "statut" (fichier d'état), "donjon" (nom), "debut"}
var _actives := {}
var _minuteur := 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER_ETATS)


func _exit_tree() -> void:
	for port in _actives.keys():
		arreter(port)


## Lance le donjon pour un groupe. Rend le port choisi, ou -1 si tout est occupé.
func lancer(donjon: Dictionary, groupe: Dictionary, progression: Dictionary) -> int:
	var nombre := int(get_parent().donnees.get("reglages", {}).get("ports_instances", 20))
	for k in range(1, nombre + 1):
		var port: int = Reseau.port + k
		if _actives.has(port) or not Reseau.port_libre(port):
			continue
		var profil := "instance_%d" % port
		var dossier := Profil.dossier(profil)
		DirAccess.make_dir_recursive_absolute(dossier)
		var cfg := ConfigFile.new()
		for section in progression:
			for cle in progression[section]:
				cfg.set_value(section, cle, progression[section][cle])
		cfg.save(dossier + "progression.cfg")
		var statut := ProjectSettings.globalize_path(DOSSIER_ETATS + "%d.json" % port)
		DirAccess.remove_absolute(statut)
		var groupe_texte := Marshalls.utf8_to_base64(JSON.stringify(groupe))
		var arguments := Reseau.arguments_serveur(port, ["--instance", "--scene=" + String(donjon["scene"]),
				"--profil=" + profil, "--personnages=" + Profil.nom, "--statut=" + statut,
				"--groupe=" + groupe_texte])
		var pid := OS.create_process(OS.get_executable_path(), arguments)
		if pid <= 0:
			return -1
		print("Donjon « %s » lancé pour %s (port %d, processus %d)" % [donjon.get("nom", ""),
				", ".join(groupe.get("membres", [])), port, pid])
		_actives[port] = {"pid": pid, "statut": statut, "donjon": String(donjon.get("nom", "")),
				"debut": Time.get_ticks_msec()}
		return port
	return -1


## Le donjon est prêt à recevoir le groupe (il a écrit son fichier d'état).
func prete(port: int) -> bool:
	return _actives.has(port) and FileAccess.file_exists(_actives[port]["statut"])


func tourne(port: int) -> bool:
	return _actives.has(port) and OS.is_process_running(int(_actives[port]["pid"]))


func arreter(port: int) -> void:
	if not _actives.has(port):
		return
	if OS.is_process_running(int(_actives[port]["pid"])):
		OS.kill(int(_actives[port]["pid"]))
	DirAccess.remove_absolute(_actives[port]["statut"])
	_actives.erase(port)


## Nombre de donjons ouverts en ce moment.
func nombre() -> int:
	return _actives.size()


## Nombre de joueurs dans tous les donjons (lu dans leurs fichiers d'état).
func joueurs() -> int:
	var total := 0
	for port in _actives:
		var texte := FileAccess.get_file_as_string(_actives[port]["statut"])
		var lu = JSON.parse_string(texte) if texte != "" else null
		if lu is Dictionary:
			total += int(lu.get("joueurs", 0))
	return total


func _process(delta: float) -> void:
	if _actives.is_empty():
		return
	_minuteur += delta
	if _minuteur < 2.0:
		return
	_minuteur = 0.0
	for port in _actives.keys():
		if not OS.is_process_running(int(_actives[port]["pid"])):
			print("Donjon « %s » (port %d) fermé." % [_actives[port]["donjon"], port])
			DirAccess.remove_absolute(_actives[port]["statut"])
			_actives.erase(port)
	# Le fichier d'état de la ville compte aussi les joueurs en donjon (le serveur
	# Oracle ne se met pas à jour tant que quelqu'un joue).
	var en_donjon := joueurs()
	if en_donjon != Reseau.joueurs_ailleurs:
		Reseau.joueurs_ailleurs = en_donjon
		Reseau.ecrire_statut()
