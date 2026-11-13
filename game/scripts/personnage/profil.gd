class_name Profil
extends RefCounted
## Où sont rangées les sauvegardes du joueur sur ce PC.
##
## Chaque profil a son propre dossier :
##   user://profils/hors_ligne/        « Jouer seul » sans compte
##   user://profils/compte_<id>/       un compte en ligne (copie locale, que
##                                      l'autoload Compte envoie au serveur Nakama)
##
## Les scripts qui sauvegardent gardent leurs chemins habituels
## (ex. "user://progression.cfg") et passent simplement par Profil.chemin(),
## qui les range dans le dossier du profil actif.
##
## Pour ajouter une NOUVELLE sauvegarde du personnage (qui doit suivre le compte) :
## mettre son nom dans FICHIERS ou DOSSIERS ci-dessous, et toujours ouvrir le
## fichier avec Profil.chemin("user://…").
## Les réglages du PC (graphismes, adresse du serveur…) restent hors profil.

const RACINE := "user://profils/"
const HORS_LIGNE := "hors_ligne"
## Fichier interne du profil (état de la dernière synchronisation) : jamais envoyé.
const FICHIER_SYNCHRO := "_synchro.cfg"

## Fichiers à la racine de user:// qui appartiennent au personnage.
const FICHIERS := ["personnage.json", "progression.cfg", "conseils.cfg"]
## Dossiers de user:// qui appartiennent au personnage.
const DOSSIERS := ["sauvegardes", "cartes"]

## Nom du profil actif ("" = aucun : les chemins restent tels quels).
static var nom := ""


## Le chemin réel d'une sauvegarde dans le profil actif.
static func chemin(p: String) -> String:
	if nom == "" or not p.begins_with("user://"):
		return p
	var relatif := p.trim_prefix("user://")
	if _appartient_au_profil(relatif):
		return dossier() + relatif
	return p


static func dossier(profil := "") -> String:
	return RACINE + (profil if profil != "" else nom) + "/"


static func activer(profil: String) -> void:
	nom = profil
	DirAccess.make_dir_recursive_absolute(dossier())


static func existe(profil: String) -> bool:
	return DirAccess.dir_exists_absolute(dossier(profil))


## Le profil contient-il un personnage ?
static func a_un_personnage(profil := "") -> bool:
	return FileAccess.file_exists(dossier(profil) + "personnage.json")


## Range les sauvegardes d'avant les profils (directement dans user://)
## dans le profil hors ligne. Ne fait rien si c'est déjà fait.
static func migrer_anciennes_sauvegardes() -> void:
	if existe(HORS_LIGNE):
		return
	DirAccess.make_dir_recursive_absolute(dossier(HORS_LIGNE))
	for relatif in FICHIERS + DOSSIERS:
		var ancien: String = "user://" + relatif
		if FileAccess.file_exists(ancien) or DirAccess.dir_exists_absolute(ancien):
			DirAccess.rename_absolute(ancien, dossier(HORS_LIGNE) + relatif)


## Tous les fichiers du profil, en chemins relatifs (« cartes/lea.cfg »…).
static func lister(profil := "") -> PackedStringArray:
	var liste := PackedStringArray()
	_lister_dossier(dossier(profil), "", liste)
	return liste


## Copie tous les fichiers d'un profil dans un autre (sans rien effacer).
static func copier(de: String, vers: String) -> void:
	for relatif in lister(de):
		var cible := dossier(vers) + relatif
		DirAccess.make_dir_recursive_absolute(cible.get_base_dir())
		DirAccess.copy_absolute(dossier(de) + relatif, cible)


static func _appartient_au_profil(relatif: String) -> bool:
	if relatif in FICHIERS:
		return true
	for d in DOSSIERS:
		if relatif == d or relatif.begins_with(d + "/"):
			return true
	return false


static func _lister_dossier(racine: String, sous: String, liste: PackedStringArray) -> void:
	var d := DirAccess.open(racine + sous)
	if d == null:
		return
	for f in d.get_files():
		var relatif := sous + f
		if relatif != FICHIER_SYNCHRO and _appartient_au_profil(relatif):
			liste.append(relatif)
	for sd in d.get_directories():
		_lister_dossier(racine, sous + sd + "/", liste)
