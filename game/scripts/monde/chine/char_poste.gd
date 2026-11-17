extends Node3D
## Le char de poste impérial (île de la Chine) : un petit char à deux roues sous un parasol
## rond, attelé à un cheval. F pour partir vers une autre zone (Luoyang <-> mont Li). Le
## char n'accepte de partir qu'une fois la quête arrivée assez loin (étape « condition »).

const ApparenceMonture := preload("res://scripts/joueur/apparence_monture.gd")
const PORTEE := 3.6

## La zone où le char emmène (ex. « mont_li »), et son nom affiché.
@export var destination := ""
@export var nom_destination := ""
## Étape de la quête à partir de laquelle le char peut partir.
@export var condition := ""

var _invite: Label3D


func _ready() -> void:
	add_to_group("chars_poste")
	_construire()
	_invite = Label3D.new()
	_invite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_invite.font_size = 36
	_invite.pixel_size = 0.005
	_invite.outline_size = 10
	_invite.position = Vector3(0, 3.2, 0)
	_invite.visible = false
	add_child(_invite)


func _mat(couleur: Color, rugosite := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	return m


func _piece(maillage: Mesh, materiau: Material, p: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = p
	mi.rotation = rot
	add_child(mi)
	return mi


func _construire() -> void:
	var bois := _mat(Color(0.32, 0.18, 0.1), 0.7)
	var laque := _mat(Color(0.5, 0.08, 0.06), 0.35)
	var noir := _mat(Color(0.06, 0.05, 0.05), 0.4)
	var soie := _mat(Color(0.62, 0.12, 0.08), 0.9)
	# La caisse, posée sur l'essieu, et ses deux grandes roues à rayons.
	var caisse := BoxMesh.new()
	caisse.size = Vector3(1.4, 0.5, 1.2)
	_piece(caisse, laque, Vector3(0, 1.05, 0.4))
	var essieu := CylinderMesh.new()
	essieu.top_radius = 0.05
	essieu.bottom_radius = 0.05
	essieu.height = 2.2
	_piece(essieu, bois, Vector3(0, 0.75, 0.4), Vector3(0, 0, PI / 2))
	for c in [-1.0, 1.0]:
		var jante := TorusMesh.new()
		jante.inner_radius = 0.66
		jante.outer_radius = 0.74
		jante.rings = 24
		_piece(jante, noir, Vector3(c * 0.95, 0.75, 0.4), Vector3(0, 0, PI / 2))
		for k in 8:
			var rayon := BoxMesh.new()
			rayon.size = Vector3(0.04, 1.36, 0.04)
			_piece(rayon, bois, Vector3(c * 0.95, 0.75, 0.4), Vector3(k * PI / 8.0, 0, 0))
	# Le timon, qui monte vers le cheval, et le parasol rond sur son mât.
	var timon := BoxMesh.new()
	timon.size = Vector3(0.08, 0.08, 2.6)
	_piece(timon, bois, Vector3(0, 1.0, -1.6), Vector3(-0.12, 0, 0))
	var mat_parasol := CylinderMesh.new()
	mat_parasol.top_radius = 0.03
	mat_parasol.bottom_radius = 0.03
	mat_parasol.height = 1.7
	_piece(mat_parasol, bois, Vector3(0, 2.1, 0.4))
	var parasol := CylinderMesh.new()
	parasol.top_radius = 0.05
	parasol.bottom_radius = 1.25
	parasol.height = 0.35
	parasol.radial_segments = 20
	_piece(parasol, soie, Vector3(0, 3.0, 0.4))
	# Le cheval de poste (le vrai modèle, s'il est là).
	var fiche: Dictionary = {}
	var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/montures.json"))
	if lu is Dictionary:
		fiche = (lu.get("montures", {}) as Dictionary).get("cheval", {})
	if not fiche.is_empty() and ResourceLoader.exists(String(fiche.get("modele", ""))):
		var cheval := ApparenceMonture.new()
		cheval.name = "Cheval"
		cheval.reglages = fiche
		cheval.position = Vector3(0, 0, -3.0)
		add_child(cheval)
	else:
		var corps := CapsuleMesh.new()
		corps.radius = 0.35
		corps.height = 1.6
		_piece(corps, _mat(Color(0.35, 0.22, 0.14)), Vector3(0, 1.2, -3.0), Vector3(PI / 2, 0, 0))
	# Une collision simple (la caisse et les roues), pour ne pas traverser le char.
	var corps_statique := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(2.0, 1.4, 1.6)
	forme.shape = boite
	forme.position = Vector3(0, 0.8, 0.4)
	corps_statique.add_child(forme)
	add_child(corps_statique)


func ouvert() -> bool:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or condition == "":
		return true
	return quete.has_method("etape_atteinte") and quete.etape_atteinte(condition)


func _joueur_proche() -> bool:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	return joueur != null and joueur.global_position.distance_to(global_position + global_transform.basis * Vector3(0, 0, 0.4)) < PORTEE


func _process(_delta: float) -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var occupe: bool = dialogue != null and dialogue.est_ouvert()
	_invite.visible = _joueur_proche() and not occupe
	_invite.text = ("[F] Prendre le char de poste vers " + nom_destination) if ouvert() \
			else "Le cocher attend un ordre du palais."


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagir") or not _joueur_proche() or not ouvert():
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null and dialogue.est_ouvert():
		return
	get_viewport().set_input_as_handled()
	partir()


func partir() -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and destination != "":
		quete.changer_de_zone(destination)
