"""Exporte les coiffures MakeHuman, ajustées aux deux agents de la Vigie, pour Godot.

Lancement (depuis le dossier du dépôt) :

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background ^
        --python tools\\personnages\\exporter_coiffures.py

Pour chaque agent (homme, femme) et chaque coiffure de COIFFURES :
  1. MakeHuman fabrique l'agent (même morphologie que creer_personnage.py) avec
     cette coiffure, et l'exporte en FBX (mètres, pieds au sol).
  2. Blender en extrait seulement les cheveux, lisse les normales et les
     enregistre en .glb dans game/assets/personnages/coiffures/<sexe>/<id>.glb
     (texture incluse).
Les coiffures absentes de MakeHuman sont signalées et ignorées.

Le jeu accroche ensuite ces cheveux à l'os de la tête (voir apparence_agent.gd).
Licence : assets système MakeHuman, CC0.
"""
import json
import os
import shutil
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
os.environ["SICKWORLD_SANS_MAIN"] = "1"
import creer_personnage as cp  # noqa: E402

# id de l'écran de création -> dossier MakeHuman (data/hair/<nom>/)
COIFFURES = {
    "tres_courte": "short04",
    "courte": "short02",
    "courte_2": "short01",
    "mi_longue": "bob02",
    "carre": "bob01",
    "longue": "long01",
    "queue": "ponytail01",
    "tresse": "braid01",
    "afro": "afro01",
}
SORTIE = os.path.normpath(os.path.join(ICI, "..", "..", "game", "assets", "personnages", "coiffures"))
TRAVAIL = os.path.join(cp.DOSSIER_SORTIE, "coiffures")


def cheveux_disponibles():
    dispo = {}
    for ident, nom in COIFFURES.items():
        for racine in (os.path.join(cp.MAKEHUMAN, "makehuman", "data", "hair"),
                       os.path.join(cp.MAKEHUMAN_UTILISATEUR, "data", "hair")):
            if os.path.exists(os.path.join(racine, nom, nom + ".mhclo")):
                dispo[ident] = nom
                break
        else:
            print("ABSENTE", ident, nom)
    return dispo


def lancer_makehuman(dispo):
    cp.installer_plugin()
    os.makedirs(TRAVAIL, exist_ok=True)
    job = {"personnages": [], "rapport": os.path.join(TRAVAIL, "rapport.json")}
    for perso, base in cp.PERSONNAGES.items():
        for ident, nom in dispo.items():
            spec = json.loads(json.dumps(base))
            spec["assets"]["cheveux"] = nom
            spec["nom"] = "%s__%s" % (perso, ident)
            spec["dossier"] = os.path.join(TRAVAIL, spec["nom"])
            job["personnages"].append(spec)
    chemin = os.path.join(TRAVAIL, "job.json")
    with open(chemin, "w", encoding="utf-8") as f:
        json.dump(job, f, indent=2, ensure_ascii=False)
    if os.path.exists(job["rapport"]):
        os.remove(job["rapport"])
    import subprocess
    env = dict(os.environ, SICKWORLD_MH_JOB=chemin)
    subprocess.run([os.path.join(cp.MAKEHUMAN, "Python", "python.exe"), "makehuman.py"],
                   cwd=os.path.join(cp.MAKEHUMAN, "makehuman"), env=env, timeout=3600)
    with open(job["rapport"], encoding="utf-8") as f:
        return json.load(f)


def extraire_cheveux(nom_job, nom_cheveux, sortie):
    import bpy
    dossier = os.path.join(TRAVAIL, nom_job)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(dossier, nom_job + ".fbx"))
    bpy.ops.file.find_missing_files(directory=os.path.join(dossier, "textures"))
    cheveux = [o for o in bpy.context.scene.objects
               if o.type == "MESH" and o.name.lower().startswith(nom_cheveux.lower())]
    if not cheveux:
        raise RuntimeError("cheveux introuvables dans " + nom_job + " : "
                           + ", ".join(o.name for o in bpy.context.scene.objects))
    cp.corriger_materiaux(bpy)
    bpy.ops.object.select_all(action="DESELECT")
    for o in cheveux:
        if o.data.has_custom_normals:
            with bpy.context.temp_override(object=o, active_object=o, selected_editable_objects=[o]):
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
        o.data.shade_smooth()
        o.select_set(True)
    bpy.context.view_layer.objects.active = cheveux[0]
    os.makedirs(os.path.dirname(sortie), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=sortie, use_selection=True, export_format="GLB",
                              export_yup=True, export_apply=True)
    # Repère pour vérifier l'alignement dans Godot : hauteur totale du personnage.
    from mathutils import Vector
    pts = [o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type == "MESH" for c in o.bound_box]
    return {"zmin": min(p.z for p in pts), "zmax": max(p.z for p in pts)}


def main():
    dispo = cheveux_disponibles()
    rapport = lancer_makehuman(dispo)
    bilan = {}
    for r in rapport:
        if not r.get("ok"):
            print("ECHEC", r["nom"], r.get("erreur"))
            continue
        perso, ident = r["nom"].split("__")
        sexe = "femme" if perso.endswith("femme") else "homme"
        sortie = os.path.join(SORTIE, sexe, ident + ".glb")
        try:
            bilan[r["nom"]] = extraire_cheveux(r["nom"], dispo[ident], sortie)
            print("OK", sortie)
        except Exception as e:
            print("ECHEC", r["nom"], e)
    with open(os.path.join(SORTIE, "bilan.json"), "w", encoding="utf-8") as f:
        json.dump({"coiffures": dispo, "personnages": bilan}, f, indent=2)


main()
