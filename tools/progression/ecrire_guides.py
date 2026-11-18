# Réécrit les tableaux des guides à partir des données :
#  - docs/guides/la-progression.md : tableaux des talents (### Lame … ### Tisseur) et des titres
#  - docs/guides/l-arsenal-des-epoques.md : tableaux des panoplies de chaque île
# Usage : python3 tools/progression/ecrire_guides.py
import json, os, re
RACINE = os.path.join(os.path.dirname(__file__), "..", "..")
P = json.load(open(os.path.join(RACINE, "game/data/progression.json"), encoding="utf-8"))
A = json.load(open(os.path.join(RACINE, "game/data/arsenal.json"), encoding="utf-8"))
O = json.load(open(os.path.join(RACINE, "game/data/objets.json"), encoding="utf-8"))["objets"]
NOMS_CLASSES = {"lame": "Lame", "rempart": "Rempart", "traqueur": "Traqueur", "tisseur": "Tisseur"}

def talents():
    out = []
    for c, nom in NOMS_CLASSES.items():
        out.append("### %s\n\n" % nom)
        for v in P["talents"][c]:
            out.append("**%s** : %s\n\n| Palier | Talent | Rangs | Effet |\n|---|---|---|---|\n" % (v["nom"], v["description"]))
            for t in v["talents"]:
                out.append("| %d | %s | %d | %s |\n" % (t["palier"], t["nom"], t["rangs"], t["texte"]))
            out.append("\n")
    return "".join(out)

def titres():
    lignes = ["| Époque | Titre | Comment l'obtenir |\n|---|---|---|\n"]
    for t in P["titres"]["liste"]:
        lignes.append("| %s | « %s » | %s |\n" % (t["epoque"], t["nom"], t["comment"]))
    return "".join(lignes)

g = os.path.join(RACINE, "docs/guides/la-progression.md")
s = open(g, encoding="utf-8").read()
debut = s.index("### Lame")
fin = s.index("## Les titres")
s = s[:debut] + talents() + s[fin:]
debut = s.index("| Époque | Titre |")
fin = s.index("\n## Tout régler sans code")
s = s[:debut] + titres() + s[fin:]
open(g, "w", encoding="utf-8").write(s)

NOMS_STATS = {"pv": "vie", "degats_pourcent": "% dégâts", "critique_pourcent": "% critiques", "reduction_pourcent": "% protection",
              "soins_pourcent": "% soins", "vol_de_vie_pourcent": "% vol de vie", "resistance_controles_pourcent": "% résistance"}
def stats(d):
    return ", ".join(("+%d %s" % (v, NOMS_STATS[k])) for k, v in d.items())
EMP = [("arme", "Arme"), ("torse", "Torse"), ("jambes", "Jambes"), ("tete", "Tête"), ("mains", "Mains"), ("pieds", "Pieds"), ("bijou", "Bijou")]
ILES = [("prehistoire", "Préhistoire"), ("egypte", "Égypte"), ("grece", "Grèce"), ("rome", "Rome"), ("chine", "Chine"), ("moyen_age", "Moyen Âge")]
ROLES = [("assaut", "Assaut (Lame, Traqueur)"), ("garde", "Garde (Rempart)"), ("harmonie", "Harmonie (Tisseur)")]
recettes = A["recettes"]
def nom_ing(i):
    o = A["objets"].get(i) or O.get(i) or {}
    return o.get("nom", i)
out = []
for ile, nom_ile in ILES:
    exemple = recettes["arsenal_%s_assaut_torse" % ile]["ingredients"]
    arme = recettes["arsenal_%s_assaut_arme" % ile]["ingredients"]
    renf = recettes["arsenal_%s_assaut_torse_renforce" % ile]["ingredients"]
    niv = A["objets"]["arsenal_%s_assaut_torse" % ile]["niveau"]
    out.append("## %s (niveau %d, renforcé niveau %d)\n\n" % (nom_ile, niv, niv + 4))
    out.append("- Armures : %s.\n" % ", ".join("%d × %s" % (n, nom_ing(i)) for i, n in exemple.items()))
    out.append("- Arme et bijou : %s.\n" % ", ".join("%d × %s" % (n, nom_ing(i)) for i, n in arme.items()))
    out.append("- Renforcer une pièce : %s.\n\n" % ", ".join("%d × %s" % (n, nom_ing(i)) for i, n in renf.items() if not i.startswith("arsenal_")))
    for role, nom_role in ROLES:
        ens = A["ensembles"]["arsenal_%s_%s" % (ile, role)]
        out.append("**%s** — %s\n\n| Pièce | Nom | Normale | Renforcée |\n|---|---|---|---|\n" % (ens["nom"], nom_role))
        for e, nom_e in EMP:
            n = A["objets"]["arsenal_%s_%s_%s" % (ile, role, e)]
            r = A["objets"]["arsenal_%s_%s_%s_renforce" % (ile, role, e)]
            out.append("| %s | %s | %s | %s |\n" % (nom_e, n["nom"], stats(n["stats"]), stats(r["stats"])))
        out.append("\nBonus d'ensemble : " + " ; ".join("%s pièces : %s" % (k, v["texte"]) for k, v in ens["paliers"].items()) + ".\n\n")
g = os.path.join(RACINE, "docs/guides/l-arsenal-des-epoques.md")
s = open(g, encoding="utf-8").read()
debut = s.index("<!-- tableaux -->") + len("<!-- tableaux -->\n\n")
s = s[:debut] + "".join(out)
open(g, "w", encoding="utf-8").write(s)
print("guides écrits")
