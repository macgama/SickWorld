@tool
class_name ZoneCarte
extends Node3D
## Une zone de la carte : un rectangle du monde qui a sa propre carte
## (par exemple « Place Hikari », « QG de la Vigie », « Île de la Préhistoire »).
##
## Pose ce nœud dans une scène, au centre de la zone, et règle sa taille :
## la boîte violette visible dans l'éditeur montre ce qui sera sur la carte.
## La carte est dessinée toute seule au premier passage du joueur (vue de
## dessus + relief), et le brouillard se lève là où le joueur est allé.
##
## Plusieurs zones peuvent se superposer (un intérieur sous une ville, par
## exemple) : c'est la plus petite qui contient le joueur qui s'affiche.
## La rotation du nœud est ignorée : le nord de la carte est toujours vers -Z.

## Identifiant unique, utilisé pour la sauvegarde (sans espace ni accent).
@export var identifiant := "zone"
## Nom affiché en haut de la carte et quand on entre dans la zone.
@export var nom_affiche := "Zone"
## Taille de la zone en mètres : largeur (x), hauteur (y), profondeur (z).
@export var taille := Vector3(100, 40, 100):
	set(valeur):
		taille = valeur.max(Vector3.ONE)
		_mettre_a_jour_apercu()
## Rayon (mètres) dévoilé autour du joueur. 0 = valeur par défaut (30 m).
@export var rayon_decouverte := 0.0
## Taille d'une case du brouillard, en mètres (plus petit = plus précis).
@export var metres_par_case := 2.0
## Décocher pour une zone déjà connue (pas de brouillard).
@export var brouillard := true
## Image de carte dessinée à la main (facultatif). Sinon, elle est générée.
@export var image: Texture2D
## Couleur des endroits sans sol (mer, vide).
@export var couleur_vide := Color(0.05, 0.12, 0.2)

var _apercu: MeshInstance3D


func _ready() -> void:
	add_to_group("zones_carte")
	_mettre_a_jour_apercu()


## Boîte englobante de la zone, dans le monde.
func boite() -> AABB:
	return AABB(global_position - taille * 0.5, taille)


func contient(point: Vector3) -> bool:
	return boite().has_point(point)


func volume() -> float:
	return taille.x * taille.y * taille.z


## Position sur la carte (0..1, 0..1) d'un point du monde. (0, 0) = coin nord-ouest.
func vers_carte(point: Vector3) -> Vector2:
	var b := boite()
	return Vector2((point.x - b.position.x) / b.size.x, (point.z - b.position.z) / b.size.z)


func rayon() -> float:
	return rayon_decouverte if rayon_decouverte > 0.0 else 30.0


## Taille (en cases) de l'image du brouillard.
func taille_brouillard() -> Vector2i:
	var m := maxf(metres_par_case, 0.25)
	return Vector2i(maxi(1, ceili(taille.x / m)), maxi(1, ceili(taille.z / m)))


func _mettre_a_jour_apercu() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _apercu == null:
		_apercu = MeshInstance3D.new()
		var materiau := StandardMaterial3D.new()
		materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		materiau.albedo_color = Color(0.62, 0.48, 1.0, 0.08)
		materiau.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apercu.material_override = materiau
		add_child(_apercu)  # pas de propriétaire : n'est pas enregistré dans la scène
	var boite_maillage := BoxMesh.new()
	boite_maillage.size = taille
	_apercu.mesh = boite_maillage
