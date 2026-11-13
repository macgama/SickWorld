extends Node
## Déclare les touches du jeu au démarrage.
##
## On utilise la POSITION physique des touches : les touches à gauche du clavier
## donnent donc Z Q S D sur un clavier français (AZERTY) et W A S D sur un
## clavier anglais (QWERTY), sans aucun réglage.
##
## Les noms ci-dessous (KEY_W, KEY_A…) désignent la position sur un clavier
## QWERTY. Sur AZERTY : KEY_W = Z, KEY_A = Q, KEY_Q = A.

const TOUCHES := {
	"avancer": [KEY_W, KEY_UP],          # Z (AZERTY) / W (QWERTY) / flèche haut
	"reculer": [KEY_S, KEY_DOWN],        # S / flèche bas
	"tourner_gauche": [KEY_A, KEY_LEFT], # Q (AZERTY) / A (QWERTY) / flèche gauche
	"tourner_droite": [KEY_D, KEY_RIGHT],# D / flèche droite
	"pas_gauche": [KEY_Q],               # A (AZERTY) / Q (QWERTY) : pas de côté
	"pas_droite": [KEY_E],               # E : pas de côté
	"sauter": [KEY_SPACE],               # Espace
	"esquive": [KEY_SHIFT],              # Maj : roulade d'esquive
	"aide": [KEY_F1],                    # F1 : afficher / cacher l'aide
}


func _ready() -> void:
	for action: String in TOUCHES:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for touche: Key in TOUCHES[action]:
			var evenement := InputEventKey.new()
			evenement.physical_keycode = touche
			InputMap.action_add_event(action, evenement)
