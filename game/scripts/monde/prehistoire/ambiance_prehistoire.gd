extends Node
## Ambiance « grandiose » des zones de la Préhistoire : soleil bas d'hiver,
## ciel doré et nuageux, brume bleutée au loin, rayons de lumière dans la
## brume, contraste et couleurs. S'applique au WorldEnvironment « Environnement »
## et à la lumière « Soleil » de la zone.
##
## Utilisation (une ligne dans le script de la zone) :
##   AmbiancePrehistoire.appliquer(self, "cote_gelee")
## Les réglages de chaque zone sont dans CLIMATS ci-dessous.

## Multiplicateur général de saturation (couleurs vives sans être criardes).
const VIVACITE := 1.22
const SHADER_CIEL := preload("res://shaders/ciel_polaire.gdshader")
const SHADER_POST := preload("res://shaders/post_traitement.gdshader")
const Etalonnage := preload("res://scripts/monde/etalonnage.gd")

## Réglages par zone. soleil = (direction horizontale en degrés, hauteur en degrés).
const CLIMATS := {
	"cote_gelee": {
		"soleil": Vector2(-62.0, 13.0),
		"couleur_soleil": Color(1.0, 0.87, 0.72),
		"energie_soleil": 2.4,
		"couverture": 0.55,
		"brume": Color(0.56, 0.66, 0.8),
		"densite_brume": 0.0014,
		"brume_volume": 0.0035,
		"ambiance": 0.55,
	},
	"foret": {
		"soleil": Vector2(-100.0, 16.0),
		"couleur_soleil": Color(1.0, 0.85, 0.68),
		"energie_soleil": 2.5,
		"couverture": 0.45,
		"brume": Color(0.6, 0.68, 0.78),
		"densite_brume": 0.0025,
		"brume_volume": 0.006,
		"ambiance": 0.6,
	},
	"falaises": {
		"soleil": Vector2(-150.0, 14.0),
		"couleur_soleil": Color(1.0, 0.82, 0.62),
		"energie_soleil": 2.5,
		"couverture": 0.5,
		"brume": Color(0.6, 0.66, 0.76),
		"densite_brume": 0.0018,
		"brume_volume": 0.004,
		"ambiance": 0.6,
	},
	# Île d'Égypte : soleil haut et blanc du matin, ciel limpide, brume de chaleur dorée.
	"port_des_marais": {
		"etalonnage": "desert",
		"soleil": Vector2(112.0, 34.0),
		"couleur_soleil": Color(1.0, 0.93, 0.8),
		"energie_soleil": 3.0,
		"couverture": 0.08,
		"brume": Color(0.86, 0.8, 0.68),
		"densite_brume": 0.0016,
		"brume_volume": 0.0025,
		"albedo_brume": Color(1.0, 0.95, 0.85),
		"ambiance": 0.75,
		"zenith": Color(0.16, 0.34, 0.66),
		"horizon": Color(0.86, 0.84, 0.76),
		"horizon_soleil": Color(1.0, 0.9, 0.7),
		"nuage_ombre": Color(0.62, 0.6, 0.58),
		"nuage_lumiere": Color(1.0, 0.97, 0.9),
		"saturation": 1.02,
	},
	# Île de Grèce : grand soleil d'été méditerranéen, ciel bleu profond, air limpide et salé.
	"le_piree": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(140.0, 52.0),
		"couleur_soleil": Color(1.0, 0.95, 0.86),
		"energie_soleil": 3.0,
		"couverture": 0.12,
		"brume": Color(0.68, 0.79, 0.92),
		"densite_brume": 0.0009,
		"brume_volume": 0.002,
		"albedo_brume": Color(0.95, 0.97, 1.0),
		"ambiance": 0.75,
		"zenith": Color(0.05, 0.2, 0.56),
		"horizon": Color(0.6, 0.74, 0.88),
		# Air limpide : la brume ne voile presque pas le ciel.
		"brume_ciel": 0.12,
		"horizon_soleil": Color(1.0, 0.93, 0.78),
		"nuage_ombre": Color(0.66, 0.68, 0.72),
		"nuage_lumiere": Color(1.0, 0.98, 0.94),
		"saturation": 1.06,
	},
	# Île de Rome : fin d'après-midi d'été sur la campagne romaine, lumière dorée, air chaud.
	"voie_appienne": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(250.0, 30.0),
		"couleur_soleil": Color(1.0, 0.88, 0.7),
		"energie_soleil": 2.7,
		"couverture": 0.18,
		"brume": Color(0.8, 0.78, 0.72),
		"densite_brume": 0.0012,
		"brume_volume": 0.003,
		"albedo_brume": Color(1.0, 0.95, 0.88),
		"ambiance": 0.7,
		"zenith": Color(0.12, 0.26, 0.55),
		"horizon": Color(0.82, 0.8, 0.74),
		"brume_ciel": 0.18,
		"horizon_soleil": Color(1.0, 0.82, 0.58),
		"nuage_ombre": Color(0.68, 0.64, 0.62),
		"nuage_lumiere": Color(1.0, 0.94, 0.84),
		"saturation": 1.04,
	},
	# La campagne romaine : plein après-midi, ciel plus haut, lumière franche sur les arches.
	"campagne": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(230.0, 42.0),
		"couleur_soleil": Color(1.0, 0.88, 0.7),
		"energie_soleil": 2.9,
		"couverture": 0.14,
		"brume": Color(0.8, 0.78, 0.72),
		"densite_brume": 0.0012,
		"brume_volume": 0.003,
		"albedo_brume": Color(1.0, 0.95, 0.88),
		"ambiance": 0.7,
		"zenith": Color(0.12, 0.26, 0.55),
		"horizon": Color(0.82, 0.8, 0.74),
		"brume_ciel": 0.18,
		"horizon_soleil": Color(1.0, 0.82, 0.58),
		"nuage_ombre": Color(0.68, 0.64, 0.62),
		"nuage_lumiere": Color(1.0, 0.94, 0.84),
		"saturation": 1.04,
	},
	# Les carrières de Berchères (Moyen Âge) : un matin d'été, lumière blanche sur la pierre,
	# un peu de brume sous les chênes.
	# Chartres (Moyen Âge) : une fin d'après-midi d'été, lumière dorée sur la pierre blonde,
	# un voile de fumée grise qui traîne encore au-dessus de la butte.
	"chartres": {
		"soleil": Vector2(250.0, 32.0),
		"couleur_soleil": Color(1.0, 0.88, 0.72),
		"energie_soleil": 2.4,
		"couverture": 0.4,
		"brume": Color(0.78, 0.76, 0.74),
		"densite_brume": 0.0022,
		"brume_volume": 0.007,
		"albedo_brume": Color(0.92, 0.9, 0.88),
		"ambiance": 0.8,
		"zenith": Color(0.2, 0.36, 0.66),
		"horizon": Color(0.8, 0.8, 0.82),
		"brume_ciel": 0.24,
		"horizon_soleil": Color(1.0, 0.82, 0.62),
		"nuage_ombre": Color(0.62, 0.62, 0.66),
		"nuage_lumiere": Color(1.0, 0.94, 0.86),
		"saturation": 1.02,
	},
	# Le chantier de la cathédrale (Moyen Âge) : un matin clair au-dessus des murs noircis,
	# la poussière de calcaire et la fumée des fours qui flottent dans la nef sans toit.
	"chantier": {
		"soleil": Vector2(120.0, 40.0),
		"couleur_soleil": Color(1.0, 0.92, 0.8),
		"energie_soleil": 2.5,
		"couverture": 0.3,
		"brume": Color(0.8, 0.78, 0.74),
		"densite_brume": 0.002,
		"brume_volume": 0.008,
		"albedo_brume": Color(0.94, 0.92, 0.88),
		"ambiance": 0.82,
		"zenith": Color(0.22, 0.4, 0.7),
		"horizon": Color(0.82, 0.82, 0.84),
		"brume_ciel": 0.22,
		"horizon_soleil": Color(1.0, 0.86, 0.68),
		"nuage_ombre": Color(0.64, 0.64, 0.68),
		"nuage_lumiere": Color(1.0, 0.95, 0.88),
		"saturation": 1.02,
	},
	"bercheres": {
		"soleil": Vector2(120.0, 40.0),
		"couleur_soleil": Color(1.0, 0.95, 0.86),
		"energie_soleil": 2.6,
		"couverture": 0.35,
		"brume": Color(0.8, 0.84, 0.86),
		"densite_brume": 0.0018,
		"brume_volume": 0.006,
		"albedo_brume": Color(0.95, 0.96, 0.94),
		"ambiance": 0.85,
		"zenith": Color(0.22, 0.4, 0.72),
		"horizon": Color(0.76, 0.84, 0.9),
		"brume_ciel": 0.2,
		"horizon_soleil": Color(1.0, 0.9, 0.74),
		"nuage_ombre": Color(0.66, 0.68, 0.74),
		"nuage_lumiere": Color(1.0, 0.98, 0.94),
		"saturation": 1.04,
	},
	# La Beauce (Moyen Âge) : un après-midi d'été, grand ciel bleu, gros nuages blancs,
	# lumière dorée sur le blé ; un voile de fumée vers Chartres.
	"beauce": {
		"soleil": Vector2(210.0, 48.0),
		"couleur_soleil": Color(1.0, 0.94, 0.82),
		"energie_soleil": 2.8,
		"couverture": 0.42,
		"brume": Color(0.78, 0.82, 0.86),
		"densite_brume": 0.0012,
		"brume_volume": 0.003,
		"albedo_brume": Color(0.95, 0.95, 0.92),
		"ambiance": 0.85,
		"zenith": Color(0.2, 0.38, 0.72),
		"horizon": Color(0.74, 0.82, 0.9),
		"brume_ciel": 0.18,
		"horizon_soleil": Color(1.0, 0.9, 0.72),
		"nuage_ombre": Color(0.66, 0.68, 0.74),
		"nuage_lumiere": Color(1.0, 0.98, 0.94),
		"saturation": 1.08,
	},
	# Le Rheingau (Mayence) : un après-midi d'octobre, soleil doré assez bas, quelques nuages,
	# une brume légère qui monte du Rhin.
	"rheingau": {
		"soleil": Vector2(200.0, 32.0),
		"couleur_soleil": Color(1.0, 0.86, 0.66),
		"energie_soleil": 2.6,
		"couverture": 0.36,
		"brume": Color(0.78, 0.82, 0.86),
		"densite_brume": 0.0016,
		"brume_volume": 0.005,
		"albedo_brume": Color(0.95, 0.95, 0.92),
		"ambiance": 0.85,
		"zenith": Color(0.2, 0.38, 0.72),
		"horizon": Color(0.74, 0.82, 0.9),
		"brume_ciel": 0.18,
		"horizon_soleil": Color(1.0, 0.8, 0.58),
		"nuage_ombre": Color(0.66, 0.68, 0.74),
		"nuage_lumiere": Color(1.0, 0.98, 0.94),
		"saturation": 1.12,
	},
	# La Porte de Jade (Chine) : un matin d'hiver dans le désert, soleil bas et pâle,
	# ciel laiteux, un voile de poussière soulevé par le vent.
	"porte_de_jade": {
		"soleil": Vector2(150.0, 22.0),
		"couleur_soleil": Color(1.0, 0.86, 0.68),
		"energie_soleil": 2.4,
		"couverture": 0.3,
		"brume": Color(0.82, 0.76, 0.66),
		"densite_brume": 0.0022,
		"brume_volume": 0.005,
		"albedo_brume": Color(1.0, 0.92, 0.8),
		"ambiance": 0.75,
		"zenith": Color(0.24, 0.36, 0.56),
		"horizon": Color(0.86, 0.8, 0.7),
		"brume_ciel": 0.28,
		"horizon_soleil": Color(1.0, 0.8, 0.58),
		"nuage_ombre": Color(0.62, 0.6, 0.6),
		"nuage_lumiere": Color(1.0, 0.94, 0.86),
		"saturation": 0.96,
	},
	# Le Fleuve Jaune et les terres de lœss (Chine) : un après-midi d'hiver clair et vif,
	# soleil bas et doré sur la terre jaune, un peu de neige sur les terrasses.
	"fleuve_jaune": {
		"soleil": Vector2(205.0, 26.0),
		"couleur_soleil": Color(1.0, 0.88, 0.7),
		"energie_soleil": 2.5,
		"couverture": 0.25,
		"brume": Color(0.8, 0.78, 0.72),
		"densite_brume": 0.0016,
		"brume_volume": 0.004,
		"albedo_brume": Color(1.0, 0.95, 0.86),
		"ambiance": 0.8,
		"zenith": Color(0.22, 0.38, 0.62),
		"horizon": Color(0.84, 0.82, 0.76),
		"brume_ciel": 0.22,
		"horizon_soleil": Color(1.0, 0.82, 0.6),
		"nuage_ombre": Color(0.6, 0.6, 0.62),
		"nuage_lumiere": Color(1.0, 0.95, 0.88),
		"saturation": 1.0,
	},
	# Luoyang (Chine) : une fin de matinée d'hiver, ciel pâle et voilé, fumée des braseros
	# qui traîne entre les toits de tuiles grises.
	"luoyang": {
		"soleil": Vector2(160.0, 30.0),
		"couleur_soleil": Color(1.0, 0.9, 0.76),
		"energie_soleil": 2.2,
		"couverture": 0.4,
		"brume": Color(0.78, 0.77, 0.74),
		"densite_brume": 0.0022,
		"brume_volume": 0.006,
		"albedo_brume": Color(0.96, 0.94, 0.9),
		"ambiance": 0.85,
		"zenith": Color(0.3, 0.42, 0.6),
		"horizon": Color(0.82, 0.82, 0.8),
		"brume_ciel": 0.3,
		"horizon_soleil": Color(1.0, 0.86, 0.68),
		"nuage_ombre": Color(0.6, 0.6, 0.64),
		"nuage_lumiere": Color(0.98, 0.96, 0.92),
		"saturation": 0.95,
	},
	# Le mont Li (Chine) : la nuit. Une lune froide et basse, un ciel d'encre, un peu de
	# brume au ras des champs ; la lumière vient surtout des torches et des feux.
	"mont_li": {
		# Nuit de pleine lune (18/11 : trop sombre, on n'y voyait rien) : lune plus forte,
		# ciel et brume plus clairs, lumière ambiante bleutée.
		"soleil": Vector2(250.0, 30.0),
		"couleur_soleil": Color(0.66, 0.76, 1.0),
		"energie_soleil": 1.7,
		"couverture": 0.3,
		"brume": Color(0.2, 0.23, 0.33),
		"densite_brume": 0.0022,
		"brume_volume": 0.006,
		"albedo_brume": Color(0.55, 0.58, 0.72),
		"ambiance": 1.15,
		"zenith": Color(0.06, 0.09, 0.2),
		"horizon": Color(0.27, 0.31, 0.45),
		"brume_ciel": 0.3,
		"horizon_soleil": Color(0.36, 0.41, 0.6),
		"nuage_ombre": Color(0.09, 0.1, 0.14),
		"nuage_lumiere": Color(0.42, 0.45, 0.56),
		"saturation": 0.85,
	},
	# Rome : un matin d'été, soleil déjà haut, poussière dorée entre les immeubles.
	"rome": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(120.0, 48.0),
		"couleur_soleil": Color(1.0, 0.9, 0.74),
		"energie_soleil": 2.8,
		"couverture": 0.12,
		"brume": Color(0.8, 0.82, 0.84),
		"densite_brume": 0.001,
		"brume_volume": 0.0025,
		"albedo_brume": Color(1.0, 0.94, 0.84),
		"ambiance": 0.72,
		"zenith": Color(0.13, 0.27, 0.55),
		"horizon": Color(0.78, 0.82, 0.86),
		"brume_ciel": 0.2,
		"horizon_soleil": Color(1.0, 0.84, 0.6),
		"nuage_ombre": Color(0.68, 0.64, 0.62),
		"nuage_lumiere": Color(1.0, 0.94, 0.84),
		"saturation": 1.08,
	},
	# L'intérieur du Colisée : le même grand soleil d'été, moins de brume (on est dans la cuvette).
	"colisee": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(120.0, 48.0),
		"couleur_soleil": Color(1.0, 0.9, 0.74),
		"energie_soleil": 2.8,
		"couverture": 0.12,
		"brume": Color(0.84, 0.8, 0.72),
		"densite_brume": 0.0008,
		"brume_volume": 0.002,
		"albedo_brume": Color(1.0, 0.94, 0.84),
		"ambiance": 0.72,
		"zenith": Color(0.13, 0.27, 0.55),
		"horizon": Color(0.84, 0.8, 0.72),
		"brume_ciel": 0.2,
		"horizon_soleil": Color(1.0, 0.84, 0.6),
		"nuage_ombre": Color(0.68, 0.64, 0.62),
		"nuage_lumiere": Color(1.0, 0.94, 0.84),
		"saturation": 1.04,
	},
	# Pompéi : un ciel bas et gris, voilé par la cendre du Vésuve ; le soleil n'est qu'une
	# tache pâle.
	"pompei": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(200.0, 35.0),
		"couleur_soleil": Color(0.95, 0.86, 0.74),
		"energie_soleil": 1.6,
		"couverture": 0.75,
		"brume": Color(0.62, 0.6, 0.58),
		"densite_brume": 0.004,
		"brume_volume": 0.012,
		"albedo_brume": Color(0.7, 0.68, 0.66),
		"ambiance": 0.6,
		"zenith": Color(0.32, 0.33, 0.36),
		"horizon": Color(0.62, 0.6, 0.57),
		"brume_ciel": 0.45,
		"horizon_soleil": Color(0.85, 0.7, 0.55),
		"nuage_ombre": Color(0.42, 0.41, 0.4),
		"nuage_lumiere": Color(0.75, 0.72, 0.68),
		"saturation": 0.7,
	},
	"oliveraies": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(140.0, 52.0),
		"couleur_soleil": Color(1.0, 0.95, 0.86),
		"energie_soleil": 3.0,
		"couverture": 0.12,
		"brume": Color(0.68, 0.79, 0.92),
		"densite_brume": 0.0009,
		"brume_volume": 0.002,
		"albedo_brume": Color(0.95, 0.97, 1.0),
		"ambiance": 0.75,
		"zenith": Color(0.05, 0.2, 0.56),
		"horizon": Color(0.6, 0.74, 0.88),
		# Air limpide : la brume ne voile presque pas le ciel.
		"brume_ciel": 0.12,
		"horizon_soleil": Color(1.0, 0.93, 0.78),
		"nuage_ombre": Color(0.66, 0.68, 0.72),
		"nuage_lumiere": Color(1.0, 0.98, 0.94),
		"saturation": 1.06,
	},
	"athenes": {
		"etalonnage": "mediterranee",
		"soleil": Vector2(140.0, 52.0),
		"couleur_soleil": Color(1.0, 0.95, 0.86),
		"energie_soleil": 3.0,
		"couverture": 0.12,
		"brume": Color(0.68, 0.79, 0.92),
		"densite_brume": 0.0009,
		"brume_volume": 0.002,
		"albedo_brume": Color(0.95, 0.97, 1.0),
		"ambiance": 0.75,
		"zenith": Color(0.05, 0.2, 0.56),
		"horizon": Color(0.6, 0.74, 0.88),
		# Air limpide : la brume ne voile presque pas le ciel.
		"brume_ciel": 0.12,
		"horizon_soleil": Color(1.0, 0.93, 0.78),
		"nuage_ombre": Color(0.66, 0.68, 0.72),
		"nuage_lumiere": Color(1.0, 0.98, 0.94),
		"saturation": 1.06,
	},
	"laurion": {
		"etalonnage": "mediterranee",
		# Fin d'après-midi : soleil plus bas, lumière dorée sur la poussière des fours.
		"soleil": Vector2(-120.0, 34.0),
		"couleur_soleil": Color(1.0, 0.88, 0.7),
		"energie_soleil": 2.8,
		"couverture": 0.18,
		"brume": Color(0.74, 0.7, 0.62),
		"densite_brume": 0.0028,
		"brume_volume": 0.006,
		"albedo_brume": Color(0.92, 0.86, 0.76),
		"ambiance": 0.7,
		"zenith": Color(0.12, 0.26, 0.52),
		"horizon": Color(0.78, 0.74, 0.66),
		# L'air chargé de poussière et de fumée voile l'horizon.
		"brume_ciel": 0.35,
		"horizon_soleil": Color(1.0, 0.82, 0.6),
		"nuage_ombre": Color(0.6, 0.58, 0.56),
		"nuage_lumiere": Color(1.0, 0.94, 0.86),
		"saturation": 0.98,
	},
	"carrieres_toura": {
		"etalonnage": "desert",
		# Soleil de l'après-midi à l'ouest : il éclaire de face la falaise blanche.
		"soleil": Vector2(-118.0, 38.0),
		"couleur_soleil": Color(1.0, 0.94, 0.84),
		"energie_soleil": 3.0,
		"couverture": 0.05,
		"brume": Color(0.88, 0.83, 0.72),
		"densite_brume": 0.0014,
		"brume_volume": 0.003,
		"albedo_brume": Color(1.0, 0.96, 0.88),
		"ambiance": 0.8,
		"zenith": Color(0.17, 0.36, 0.68),
		"horizon": Color(0.88, 0.86, 0.78),
		"horizon_soleil": Color(1.0, 0.9, 0.7),
		"nuage_ombre": Color(0.64, 0.62, 0.6),
		"nuage_lumiere": Color(1.0, 0.97, 0.9),
		"saturation": 1.0,
	},
	"village_batisseurs": {
		"etalonnage": "desert",
		# Fin d'après-midi : soleil doré à l'ouest-sud-ouest, la pyramide se découpe au nord.
		"soleil": Vector2(-150.0, 30.0),
		"couleur_soleil": Color(1.0, 0.9, 0.74),
		"energie_soleil": 2.9,
		"couverture": 0.06,
		"brume": Color(0.88, 0.8, 0.66),
		"densite_brume": 0.0013,
		"brume_volume": 0.003,
		"albedo_brume": Color(1.0, 0.94, 0.82),
		"ambiance": 0.78,
		"zenith": Color(0.17, 0.35, 0.66),
		"horizon": Color(0.9, 0.84, 0.72),
		"horizon_soleil": Color(1.0, 0.86, 0.62),
		"nuage_ombre": Color(0.64, 0.6, 0.56),
		"nuage_lumiere": Color(1.0, 0.95, 0.86),
		"saturation": 1.03,
	},
	"desert_rouge": {
		# Plein après-midi : soleil écrasant, brume de chaleur rousse au ras des dunes.
		"soleil": Vector2(-140.0, 48.0),
		"couleur_soleil": Color(1.0, 0.9, 0.76),
		"energie_soleil": 3.2,
		"couverture": 0.02,
		"brume": Color(0.9, 0.74, 0.58),
		"densite_brume": 0.0018,
		"brume_volume": 0.004,
		"albedo_brume": Color(1.0, 0.88, 0.74),
		"ambiance": 0.8,
		"zenith": Color(0.2, 0.36, 0.64),
		"horizon": Color(0.92, 0.8, 0.66),
		"horizon_soleil": Color(1.0, 0.84, 0.6),
		"nuage_ombre": Color(0.66, 0.58, 0.52),
		"nuage_lumiere": Color(1.0, 0.94, 0.84),
		"saturation": 1.05,
	},
	"steppe": {
		"soleil": Vector2(-125.0, 21.0),
		"couleur_soleil": Color(1.0, 0.84, 0.62),
		"energie_soleil": 2.6,
		"couverture": 0.4,
		"brume": Color(0.62, 0.68, 0.76),
		"densite_brume": 0.0011,
		"brume_volume": 0.0015,
		"ambiance": 0.6,
	},
}


static func appliquer(zone: Node, climat := "cote_gelee") -> void:
	var r: Dictionary = CLIMATS.get(climat, CLIMATS["cote_gelee"])
	var we := zone.get_node_or_null("Environnement") as WorldEnvironment
	var soleil := zone.get_node_or_null("Soleil") as DirectionalLight3D
	if soleil != null:
		var s: Vector2 = r["soleil"]
		# La lumière vient de cette direction (azimut, hauteur) et éclaire vers l'opposé.
		var az := deg_to_rad(s.x)
		var haut := deg_to_rad(s.y)
		var vers_soleil := Vector3(sin(az) * cos(haut), sin(haut), -cos(az) * cos(haut))
		soleil.global_transform = Transform3D(Basis.looking_at(-vers_soleil, Vector3.UP), soleil.global_position)
		soleil.light_color = r["couleur_soleil"]
		soleil.light_energy = r["energie_soleil"]
		soleil.light_angular_distance = 0.8
		soleil.light_volumetric_fog_energy = 1.2
		soleil.shadow_enabled = true
		soleil.shadow_blur = 1.2
		soleil.directional_shadow_max_distance = 260.0
		soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		soleil.light_bake_mode = Light3D.BAKE_DYNAMIC
	if we == null:
		return
	var env := we.environment
	var ciel := ShaderMaterial.new()
	ciel.shader = SHADER_CIEL
	ciel.set_shader_parameter("couverture", r["couverture"])
	ciel.set_shader_parameter("couleur_soleil", r["couleur_soleil"])
	# Couleurs du ciel propres à la zone (sinon, celles du ciel polaire).
	for cle in [["zenith", "couleur_zenith"], ["horizon", "horizon_froid"], ["horizon_soleil", "horizon_soleil"],
			["nuage_ombre", "nuage_ombre"], ["nuage_lumiere", "nuage_lumiere"]]:
		if r.has(cle[0]):
			ciel.set_shader_parameter(cle[1], r[cle[0]])
	var sky := Sky.new()
	sky.sky_material = ciel
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = r["ambiance"]
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.ssr_enabled = true
	env.ssr_max_steps = 80
	env.ssr_fade_out = 4.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.sdfgi_enabled = true
	env.sdfgi_cascades = 6
	env.sdfgi_min_cell_size = 0.4
	env.sdfgi_use_occlusion = true
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2
	# Brume : bleutée au loin (perspective atmosphérique), dorée vers le soleil.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = r["brume"]
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = r["densite_brume"]
	# La perspective aérienne lit la carte de reflets du ciel (basse résolution) :
	# trop forte, elle dessinait des bandes carrées autour du soleil.
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = r.get("brume_ciel", 0.35)
	# Brouillard en volume : rayons de soleil.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = r["brume_volume"]
	env.volumetric_fog_albedo = r.get("albedo_brume", Color(0.92, 0.95, 1.0))
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_ambient_inject = 0.1
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	# Couleurs plus franches (17/11/2026 : le rendu AgX délavait tout). VIVACITE multiplie
	# la saturation propre à chaque climat ; le contraste donne du relief à la lumière.
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = r.get("saturation", 1.08) * VIVACITE
	# Étalonnage « cinéma » : ombres teintées, hautes lumières réchauffées.
	Etalonnage.appliquer(env, r.get("etalonnage", "hiver"))
	# Une fois les réglages « au maximum » posés, la qualité graphique allège.
	if env.has_meta("qualite_max"):
		env.remove_meta("qualite_max")
	var qualite := zone.get_node_or_null("/root/QualiteGraphique")
	if qualite != null:
		qualite.appliquer()
	_ajouter_post(zone)


static func _ajouter_post(zone: Node) -> void:
	if Engine.is_editor_hint() or zone.has_node("PostTraitement"):
		return
	var couche := CanvasLayer.new()
	couche.name = "PostTraitement"
	couche.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER_POST
	m.set_shader_parameter("vignettage", 0.25)
	m.set_shader_parameter("grain", 0.02)
	rect.material = m
	couche.add_child(rect)
	zone.add_child(couche)
