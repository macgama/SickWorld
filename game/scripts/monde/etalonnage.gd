extends RefCounted
## Étalonnage des couleurs « cinéma » (comme dans les grands jeux) : chaque canal
## (rouge, vert, bleu) suit sa propre courbe. Les ombres sont légèrement teintées
## (bleu froid, ou sarcelle la nuit), les hautes lumières réchauffées, et une
## courbe en S donne du contraste sans boucher les noirs.
##
## Utilisation : Etalonnage.appliquer(environment, "nuit_neon")
## Styles : nuit_neon (Hikari Bay), hiver (Préhistoire), desert (Égypte), mediterranee (Grèce).

## Pour chaque style : [luminance d'entrée, couleur de sortie] (5 points).
const STYLES := {
	# Nuit pluvieuse : ombres sarcelle, néons qui gardent leur éclat, peau neutre.
	"nuit_neon": [
		[0.0, Color(0.0, 0.012, 0.022)],
		[0.18, Color(0.15, 0.18, 0.21)],
		[0.45, Color(0.45, 0.46, 0.47)],
		[0.75, Color(0.79, 0.76, 0.74)],
		[1.0, Color(1.0, 0.97, 0.94)],
	],
	# Hiver glaciaire : ombres bleues, lumière du soleil bas dorée.
	"hiver": [
		[0.0, Color(0.0, 0.008, 0.025)],
		[0.2, Color(0.17, 0.19, 0.23)],
		[0.5, Color(0.51, 0.5, 0.5)],
		[0.78, Color(0.82, 0.78, 0.73)],
		[1.0, Color(1.0, 0.97, 0.92)],
	],
	# Désert : chaleur générale, ombres légèrement bleutées (ciel), blancs crème.
	"desert": [
		[0.0, Color(0.008, 0.008, 0.022)],
		[0.2, Color(0.2, 0.185, 0.19)],
		[0.5, Color(0.52, 0.5, 0.465)],
		[0.78, Color(0.82, 0.79, 0.735)],
		[1.0, Color(1.0, 0.975, 0.93)],
	],
	# Été méditerranéen : ombres bleu-sarcelle (reflet de la mer), mi-tons neutres,
	# lumière dorée sur le marbre et la chaux, contraste franc du plein soleil.
	"mediterranee": [
		[0.0, Color(0.0, 0.012, 0.03)],
		[0.2, Color(0.16, 0.19, 0.22)],
		[0.5, Color(0.52, 0.51, 0.49)],
		[0.78, Color(0.84, 0.8, 0.74)],
		[1.0, Color(1.0, 0.98, 0.93)],
	],
}


static func texture(style: String) -> GradientTexture1D:
	var points: Array = STYLES.get(style, STYLES["hiver"])
	var g := Gradient.new()
	# Un Gradient neuf a deux points : on les remplace.
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for p in points:
		g.add_point(p[0], p[1])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	t.use_hdr = false
	return t


static func appliquer(env: Environment, style: String) -> void:
	if env == null:
		return
	env.adjustment_enabled = true
	env.adjustment_color_correction = texture(style)
