# Ajoute les paliers 5 à 7 des voies de talents (niveau max 60) dans game/data/progression.json,
# sans reformater le reste du fichier. Usage : python3 tools/progression/ajouter_talents_60.py
import json, re, sys
CHEMIN = "game/data/progression.json"

def t(id, nom, palier, rangs, texte, stats=None, competences=None):
    d = {"id": id, "nom": nom, "palier": palier, "rangs": rangs, "texte": texte}
    if stats: d["stats"] = stats
    if competences: d["competences"] = competences
    return d

NOUVEAUX = {
 # --- Lame
 "fureur": [
  t("fer_trempe", "Fer trempé", 5, 3, "Taille rapide et Frappe tournoyante : +3 dégâts par rang.",
    competences={"taille_rapide": {"degats": 3}, "frappe_tournoyante": {"degats": 3}}),
  t("rage_du_duelliste", "Rage du duelliste", 6, 3, "+3 % de dégâts par rang.", stats={"degats_pourcent": 3}),
  t("lame_des_siecles", "Lame des siècles", 7, 1, "Exécution : utilisable dès 35 % de vie de la cible (avec Coup de grâce), +20 dégâts et 2 s de recharge en moins.",
    competences={"execution": {"pv_cible_max_pourcent": 5, "degats": 20, "recharge": -2}}),
 ],
 "saignee": [
  t("hemorragie", "Hémorragie", 5, 3, "Entaille : +2 dégâts, et le saignement fait +2 dégâts par seconde par rang.",
    competences={"entaille": {"degats": 2, "saignement.degats_par_seconde": 2}}),
  t("soif_de_sang", "Soif de sang", 6, 3, "Tu regagnes 2 % des dégâts que tu infliges en vie, par rang.", stats={"vol_de_vie_pourcent": 2}),
  t("mille_entailles", "Mille entailles", 7, 1, "+8 % de coups critiques ; Entaille coûte 5 d'Élan de moins et le saignement dure 4 s de plus.",
    stats={"critique_pourcent": 8}, competences={"entaille": {"cout": -5, "saignement.duree": 4}}),
 ],
 "mouvement": [
  t("garde_haute", "Garde haute", 5, 3, "+3 % de protection par rang.", stats={"reduction_pourcent": 3}),
  t("endurance_du_voyageur", "Endurance du voyageur", 6, 3, "+50 points de vie par rang.", stats={"pv": 50}),
  t("ombre_insaisissable", "Ombre insaisissable", 7, 1, "+100 points de vie, Bond se recharge 4 s plus vite, et étourdissements, immobilisations et ralentissements durent 30 % de moins sur toi.",
    stats={"pv": 100, "resistance_controles_pourcent": 30}, competences={"bond": {"recharge": -4}}),
 ],
 # --- Rempart
 "bastion": [
  t("peau_de_bronze", "Peau de bronze", 5, 3, "+3 % de protection par rang.", stats={"reduction_pourcent": 3}),
  t("colosse", "Colosse", 6, 3, "+80 points de vie par rang.", stats={"pv": 80}),
  t("rempart_eternel", "Rempart éternel", 7, 1, "Mur de bouclier : dure 3 s de plus et se recharge 5 s plus vite ; +5 % de protection.",
    stats={"reduction_pourcent": 5}, competences={"mur_de_bouclier": {"duree": 3, "recharge": -5}}),
 ],
 "defi": [
  t("coup_retentissant", "Coup retentissant", 5, 3, "Coup de bouclier : +3 dégâts et +1 de menace par rang.",
    competences={"coup_de_bouclier": {"degats": 3, "menace": 1}}),
  t("onde_ecrasante", "Onde écrasante", 6, 3, "Onde de choc : +5 dégâts et 1 s de recharge en moins par rang.",
    competences={"onde_de_choc": {"degats": 5, "recharge": -1}}),
  t("defi_absolu", "Défi absolu", 7, 1, "Provocation : 3 s de recharge en moins et dure 2 s de plus ; les contrôles durent 25 % de moins sur toi.",
    stats={"resistance_controles_pourcent": 25}, competences={"provocation": {"recharge": -3, "duree": 2}}),
 ],
 "gardien": [
  t("main_lourde", "Main lourde", 5, 3, "+3 % de dégâts par rang.", stats={"degats_pourcent": 3}),
  t("sang_froid", "Sang-froid", 6, 3, "Tu regagnes 2 % des dégâts que tu infliges en vie, par rang.", stats={"vol_de_vie_pourcent": 2}),
  t("bouclier_des_innocents", "Bouclier des innocents", 7, 1, "+150 points de vie ; Charge protectrice se recharge 6 s plus vite et protège l'allié 4 s de plus.",
    stats={"pv": 150}, competences={"charge_protectrice": {"recharge": -6, "duree": 4}}),
 ],
 # --- Traqueur
 "precision": [
  t("pointes_d_acier", "Pointes d'acier", 5, 3, "Tir rapide : +3 dégâts par rang.", competences={"tir_rapide": {"degats": 3}}),
  t("oeil_de_lynx", "Œil de lynx", 6, 3, "+2 % de coups critiques et +1 % de dégâts par rang.", stats={"critique_pourcent": 2, "degats_pourcent": 1}),
  t("tir_de_legende", "Tir de légende", 7, 1, "Tir visé : +20 dégâts, se prépare 0,3 s plus vite et se recharge 2 s plus vite.",
    competences={"tir_vise": {"degats": 20, "incantation": -0.3, "recharge": -2}}),
 ],
 "venins": [
  t("venin_concentre", "Venin concentré", 5, 3, "Flèche empoisonnée : le poison fait +2 dégâts par seconde par rang.",
    competences={"fleche_empoisonnee": {"poison.degats_par_seconde": 2}}),
  t("dard_barbele", "Dard barbelé", 6, 3, "Flèche empoisonnée : +3 dégâts, et le poison dure 1 s de plus par rang.",
    competences={"fleche_empoisonnee": {"degats": 3, "poison.duree": 1}}),
  t("fleau_des_epoques", "Fléau des époques", 7, 1, "+8 % de dégâts ; le poison fait +4 dégâts par seconde et Flèche empoisonnée coûte 5 de Concentration de moins.",
    stats={"degats_pourcent": 8}, competences={"fleche_empoisonnee": {"poison.degats_par_seconde": 4, "cout": -5}}),
 ],
 "survie": [
  t("cuir_de_chasse", "Cuir de chasse", 5, 3, "+3 % de protection par rang.", stats={"reduction_pourcent": 3}),
  t("instinct_de_survie", "Instinct de survie", 6, 3, "+50 points de vie par rang.", stats={"pv": 50}),
  t("ombre_de_la_steppe", "Ombre de la steppe", 7, 1, "Repli : 4 s de recharge en moins, les ennemis restent ralentis 2 s de plus ; les contrôles durent 25 % de moins sur toi.",
    stats={"resistance_controles_pourcent": 25}, competences={"repli": {"recharge": -4, "ralenti.duree": 2}}),
 ],
 # --- Tisseur
 "renouveau": [
  t("fils_dores", "Fils dorés", 5, 3, "+4 % de soins donnés par rang.", stats={"soins_pourcent": 4}),
  t("tisserand", "Tisserand", 6, 3, "Fil de vie : soigne 6 points de plus par rang.", competences={"fil_de_vie": {"soin": 6}}),
  t("trame_de_vie", "Trame de vie", 7, 1, "Fil de vie : se tisse 0,3 s plus vite et coûte 4 de Flux de moins ; Accélération soigne 4 points de plus par seconde.",
    competences={"fil_de_vie": {"incantation": -0.3, "cout": -4}, "acceleration": {"soin_par_seconde": 4}}),
 ],
 "paradoxe": [
  t("eclat_brulant", "Éclat brûlant", 5, 3, "Éclat temporel : +3 dégâts par rang.", competences={"eclat_temporel": {"degats": 3}}),
  t("faille_ouverte", "Faille ouverte", 6, 3, "+3 % de dégâts par rang.", stats={"degats_pourcent": 3}),
  t("paradoxe_parfait", "Paradoxe parfait", 7, 1, "+6 % de coups critiques ; Éclat temporel fait +10 dégâts et Bulle lente se recharge 5 s plus vite.",
    stats={"critique_pourcent": 6}, competences={"eclat_temporel": {"degats": 10}, "bulle_lente": {"recharge": -5}}),
 ],
 "chronomancie": [
  t("sablier_de_verre", "Sablier de verre", 5, 3, "+3 % de protection par rang.", stats={"reduction_pourcent": 3}),
  t("eternite", "Éternité", 6, 3, "+40 points de vie par rang.", stats={"pv": 40}),
  t("boucle_temporelle", "Boucle temporelle", 7, 1, "Retour en arrière : 6 s de recharge en moins et rend au moins 10 % de vie de plus ; les contrôles durent 20 % de moins sur toi.",
    stats={"resistance_controles_pourcent": 20}, competences={"retour_en_arriere": {"recharge": -6, "soin_minimum_pourcent": 10}}),
 ],
}

def ligne(d):
    tete = '\t\t\t\t\t{ "id": %s, "nom": %s, "palier": %d, "rangs": %d,\n\t\t\t\t\t\t"texte": %s' % (
        json.dumps(d["id"]), json.dumps(d["nom"], ensure_ascii=False), d["palier"], d["rangs"], json.dumps(d["texte"], ensure_ascii=False))
    autres = []
    for cle in ("stats", "competences"):
        if cle in d:
            autres.append('"%s": %s' % (cle, json.dumps(d[cle], ensure_ascii=False, separators=(", ", ": "))))
    if autres:
        tete += ",\n\t\t\t\t\t\t" + ",\n\t\t\t\t\t\t".join(autres)
    return tete + " }"

s = open(CHEMIN, encoding="utf-8").read()
for voie, liste in NOUVEAUX.items():
    debut = s.index('"id": "%s", "nom"' % voie)
    fin = s.index("\n\t\t\t\t]", debut)
    bloc = s[debut:fin]
    if any('"id": "%s"' % x["id"] in bloc for x in liste):
        continue
    s = s[:fin] + ",\n" + ",\n".join(ligne(x) for x in liste) + s[fin:]
s = s.replace('"points_par_palier": [0, 3, 6, 8],', '"points_par_palier": [0, 3, 6, 8, 10, 13, 16],')
json.loads(s)
open(CHEMIN, "w", encoding="utf-8").write(s)
print("ok")
