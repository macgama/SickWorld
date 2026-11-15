"""Recopie les lignes « POINTS zone [...] » affichées par tests/outil_points_recolte.gd
dans game/data/recolte.json (partie « zones »), un point par ligne.

  python tools/recolte_points.py journal1.log journal2.log ...
"""
import json
import re
import sys
from pathlib import Path

FICHIER = Path(__file__).resolve().parent.parent / "game" / "data" / "recolte.json"


def ecrire(donnees: dict) -> None:
    texte = json.dumps(donnees, indent="\t", ensure_ascii=False)
    # Chaque point [source, x, z] tient sur une seule ligne.
    texte = re.sub(r'\[\s*("[a-z_]+"),\s*(-?[0-9.]+),\s*(-?[0-9.]+)\s*\]', r"[\1, \2, \3]", texte)
    FICHIER.write_text(texte + "\n", encoding="utf-8")


def main() -> None:
    donnees = json.loads(FICHIER.read_text(encoding="utf-8"))
    for chemin in sys.argv[1:]:
        for ligne in Path(chemin).read_text(encoding="utf-8", errors="replace").splitlines():
            if ligne.startswith("POINTS "):
                _, zone, points = ligne.split(" ", 2)
                donnees["zones"][zone] = json.loads(points)
                print(zone, len(donnees["zones"][zone]), "points")
    ecrire(donnees)


if __name__ == "__main__":
    main()
