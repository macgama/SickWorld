extends Control
## Le BLASON d'une guilde, dessiné en vectoriel : une forme (écu, rond, losange, fanion),
## la couleur de la guilde, un liseré doré et un symbole (étoile, sablier, flamme…).
## Les formes et les symboles sont listés dans data/guildes.json (section « blason »).
## S'utilise comme un Control : régler forme, symbole et couleur.

const OR := Color(0.95, 0.78, 0.38)
const OR_SOMBRE := Color(0.55, 0.4, 0.15)
const FORMES := ["ecu", "rond", "losange", "fanion"]
const SYMBOLES := ["etoile", "sablier", "flamme", "croissant", "epee", "couronne", "tour", "cle", "eclair", "oeil", "soleil", "montagne"]

@export var forme := 0:
	set(v):
		forme = v
		queue_redraw()
@export var symbole := 0:
	set(v):
		symbole = v
		queue_redraw()
@export var couleur := Color(0.5, 0.12, 0.35):
	set(v):
		couleur = v
		queue_redraw()


func _draw() -> void:
	var cote := minf(size.x, size.y)
	var r := Rect2((size - Vector2(cote, cote)) * 0.5, Vector2(cote, cote))
	dessiner(self, r, forme, symbole, couleur)


## Dessine un blason dans le carré « r » de n'importe quel CanvasItem.
static func dessiner(ci: CanvasItem, r: Rect2, n_forme: int, n_symbole: int, fond: Color) -> void:
	var contour := _contour(String(FORMES[posmod(n_forme, FORMES.size())]), r)
	# Ombre, fond, reflet, liseré doré.
	var ombre := PackedVector2Array()
	for p in contour:
		ombre.append(p + Vector2(0, r.size.y * 0.025))
	ci.draw_colored_polygon(ombre, Color(0, 0, 0, 0.45))
	ci.draw_colored_polygon(contour, fond)
	var haut := PackedVector2Array()
	var c := r.get_center()
	for p in contour:
		haut.append(c + (p - c) * 0.86 + Vector2(0, -r.size.y * 0.03))
	ci.draw_colored_polygon(haut, fond.lightened(0.12))
	var ferme := contour.duplicate()
	ferme.append(contour[0])
	ci.draw_polyline(ferme, OR, maxf(2.0, r.size.x * 0.045), true)
	ci.draw_polyline(ferme, OR_SOMBRE, maxf(1.0, r.size.x * 0.012), true)
	# Le symbole, en or, au centre (un peu plus haut pour l'écu et le fanion).
	var centre := c + Vector2(0, -r.size.y * (0.05 if n_forme in [0, 3] else 0.0))
	_symbole(ci, String(SYMBOLES[posmod(n_symbole, SYMBOLES.size())]), centre, r.size.x * 0.27)


static func _contour(nom: String, r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	match nom:
		"ecu":
			pts.append(Vector2(x0 + w * 0.12, y0 + h * 0.08))
			pts.append(Vector2(x0 + w * 0.88, y0 + h * 0.08))
			pts.append(Vector2(x0 + w * 0.88, y0 + h * 0.5))
			for i in range(1, 12):
				var t := float(i) / 12.0
				# Bas arrondi qui finit en pointe.
				var a := lerpf(0.0, PI * 0.5, t)
				pts.append(Vector2(x0 + w * (0.5 + 0.38 * cos(a)), y0 + h * (0.5 + 0.42 * sin(a))))
			pts.append(Vector2(x0 + w * 0.5, y0 + h * 0.94))
			for i in range(11, 0, -1):
				var a := lerpf(0.0, PI * 0.5, float(i) / 12.0)
				pts.append(Vector2(x0 + w * (0.5 - 0.38 * cos(a)), y0 + h * (0.5 + 0.42 * sin(a))))
			pts.append(Vector2(x0 + w * 0.12, y0 + h * 0.5))
		"rond":
			for i in 40:
				var a := TAU * i / 40.0
				pts.append(r.get_center() + Vector2(cos(a), sin(a)) * w * 0.44)
		"losange":
			pts.append(Vector2(x0 + w * 0.5, y0 + h * 0.04))
			pts.append(Vector2(x0 + w * 0.94, y0 + h * 0.5))
			pts.append(Vector2(x0 + w * 0.5, y0 + h * 0.96))
			pts.append(Vector2(x0 + w * 0.06, y0 + h * 0.5))
		_: # fanion : bannière qui finit en queue d'aronde
			pts.append(Vector2(x0 + w * 0.16, y0 + h * 0.04))
			pts.append(Vector2(x0 + w * 0.84, y0 + h * 0.04))
			pts.append(Vector2(x0 + w * 0.84, y0 + h * 0.95))
			pts.append(Vector2(x0 + w * 0.5, y0 + h * 0.76))
			pts.append(Vector2(x0 + w * 0.16, y0 + h * 0.95))
	return pts


static func _poly(ci: CanvasItem, c: Vector2, s: float, points: Array, couleur := OR) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(c + Vector2(p[0], p[1]) * s)
	ci.draw_colored_polygon(pts, couleur)


static func _symbole(ci: CanvasItem, nom: String, c: Vector2, s: float) -> void:
	match nom:
		"etoile":
			var pts := []
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				var k := 1.0 if i % 2 == 0 else 0.42
				pts.append([cos(a) * k, sin(a) * k])
			_poly(ci, c, s, pts)
		"sablier":
			_poly(ci, c, s, [[-0.62, -0.9], [0.62, -0.9], [0.08, 0.0], [0.62, 0.9], [-0.62, 0.9], [-0.08, 0.0]])
			ci.draw_rect(Rect2(c + Vector2(-0.8, -1.0) * s, Vector2(1.6, 0.16) * s), OR)
			ci.draw_rect(Rect2(c + Vector2(-0.8, 0.84) * s, Vector2(1.6, 0.16) * s), OR)
		"flamme":
			_poly(ci, c, s, [[0.0, -1.05], [0.28, -0.6], [0.55, -0.3], [0.68, 0.12], [0.55, 0.55], [0.22, 0.88], [-0.22, 0.88],
					[-0.55, 0.58], [-0.68, 0.18], [-0.55, -0.22], [-0.32, 0.02], [-0.3, -0.42], [-0.12, -0.62]])
			_poly(ci, c, s, [[0.02, -0.15], [0.3, 0.2], [0.3, 0.55], [0.0, 0.75], [-0.3, 0.55], [-0.25, 0.25], [-0.08, 0.32]], Color(1.0, 0.95, 0.75))
		"croissant":
			# Disque moins un autre disque décalé : on garde les bords qui forment le croissant.
			var o := Vector2(0.42, -0.28)
			var ri := 0.78
			var dehors: Array = []
			var dedans: Array = []
			for i in 72:
				var a := TAU * i / 72.0
				var p := Vector2(cos(a), sin(a))
				dehors.append([(p - o).length() > ri, p])
				var q := o + p * ri
				dedans.append([q.length() < 1.0, q])
			var pts := PackedVector2Array()
			var debut := 0
			for i in 72:
				if not dehors[i][0] and dehors[(i + 1) % 72][0]:
					debut = (i + 1) % 72
			for k in 72:
				var e: Array = dehors[(debut + k) % 72]
				if not e[0]:
					break
				pts.append(c + e[1] * s * 0.9)
			var debut_in := 0
			for i in 72:
				if not dedans[i][0] and dedans[(i + 1) % 72][0]:
					debut_in = (i + 1) % 72
			var arc: Array = []
			for k in 72:
				var e: Array = dedans[(debut_in + k) % 72]
				if not e[0]:
					break
				arc.append(e[1])
			arc.reverse()
			for q in arc:
				pts.append(c + q * s * 0.9)
			if pts.size() >= 3:
				ci.draw_colored_polygon(pts, OR)
		"epee":
			_poly(ci, c, s, [[-0.1, -1.0], [0.0, -1.15], [0.1, -1.0], [0.1, 0.45], [-0.1, 0.45]])
			ci.draw_rect(Rect2(c + Vector2(-0.5, 0.42) * s, Vector2(1.0, 0.16) * s), OR)
			ci.draw_rect(Rect2(c + Vector2(-0.08, 0.58) * s, Vector2(0.16, 0.38) * s), OR)
			ci.draw_circle(c + Vector2(0, 1.02) * s, s * 0.12, OR)
		"couronne":
			_poly(ci, c, s, [[-0.9, 0.6], [-0.9, -0.5], [-0.45, 0.05], [0.0, -0.75], [0.45, 0.05], [0.9, -0.5], [0.9, 0.6]])
			for x in [-0.9, 0.0, 0.9]:
				ci.draw_circle(c + Vector2(x, -0.62 if x != 0.0 else -0.88) * s, s * 0.14, OR)
		"tour":
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.55) * s, Vector2(1.1, 1.5) * s), OR)
			for x in [-0.55, -0.12, 0.31]:
				ci.draw_rect(Rect2(c + Vector2(x, -0.85) * s, Vector2(0.24, 0.32) * s), OR)
			ci.draw_rect(Rect2(c + Vector2(-0.18, 0.45) * s, Vector2(0.36, 0.5) * s), Color(0.08, 0.06, 0.05, 0.8))
		"cle":
			ci.draw_arc(c + Vector2(0, -0.55) * s, s * 0.38, 0, TAU, 32, OR, s * 0.18, true)
			ci.draw_rect(Rect2(c + Vector2(-0.09, -0.2) * s, Vector2(0.18, 1.15) * s), OR)
			ci.draw_rect(Rect2(c + Vector2(0.05, 0.62) * s, Vector2(0.38, 0.14) * s), OR)
			ci.draw_rect(Rect2(c + Vector2(0.05, 0.84) * s, Vector2(0.28, 0.14) * s), OR)
		"eclair":
			_poly(ci, c, s, [[0.15, -1.0], [-0.55, 0.12], [-0.05, 0.12], [-0.3, 1.0], [0.55, -0.2], [0.05, -0.2], [0.35, -1.0]])
		"oeil":
			var pts := []
			for i in 33:
				var a := TAU * i / 32.0
				pts.append([cos(a) * 1.0, sin(a) * 0.5 * (1.0 if sin(a) > 0 else 1.0)])
			_poly(ci, c, s, pts)
			ci.draw_circle(c, s * 0.36, Color(0.08, 0.06, 0.05, 0.9))
			ci.draw_circle(c, s * 0.16, OR)
		"soleil":
			ci.draw_circle(c, s * 0.5, OR)
			for i in 12:
				var a := TAU * i / 12.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				var pts := PackedVector2Array([c + d * s * 0.6 + n * s * 0.12, c + d * s * 1.0, c + d * s * 0.6 - n * s * 0.12])
				ci.draw_colored_polygon(pts, OR)
		"montagne":
			_poly(ci, c, s, [[-1.0, 0.75], [-0.35, -0.45], [-0.05, 0.05], [0.3, -0.85], [1.0, 0.75]])
			_poly(ci, c, s, [[0.3, -0.85], [0.47, -0.5], [0.36, -0.42], [0.25, -0.52], [0.14, -0.45]], Color(1, 1, 1, 0.9))
