"""Crée les personnages de SickWorld avec MakeHuman, prêts pour Mixamo.

Lancement (une seule commande, depuis n'importe quel dossier) :

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background ^
        --python tools\\personnages\\creer_personnage.py -- [noms...]

Sans nom, tous les personnages de PERSONNAGES sont fabriqués.

Étapes pour chaque personnage :
  1. MakeHuman (installé sur le PC) est lancé avec le plugin
     makehuman_auto/9_sickworld_auto.py : morphologie, peau, yeux, cheveux,
     vêtements, topologie allégée, pas de squelette, puis export
     FBX + textures/ et sauvegarde <nom>.mhm.
  2. Blender importe ce FBX (gardé sous <nom>_makehuman_brut.fbx), corrige
     les normales (aspect facetté) et la transparence (cils, sourcils,
     cheveux), réexporte un <nom>.fbx propre (mètres, textures embarquées),
     enregistre <nom>.blend et rend deux aperçus EEVEE (face et 3/4).
  3. <nom>.zip = <nom>.fbx + textures/ : c'est le fichier à téléverser sur
     mixamo.com (Upload Character).

Licence : les modèles exportés de MakeHuman et ses assets système sont CC0.
"""
import json
import math
import os
import shutil
import subprocess
import sys
import zipfile

# ---------------------------------------------------------------------------
# Paramètres
# ---------------------------------------------------------------------------
DOSSIER_SORTIE = os.path.join(os.path.expanduser("~"), "Desktop", "SickWorld_personnage")
MAKEHUMAN = os.path.join(os.environ.get("LOCALAPPDATA", ""), "makehuman-community")
# Dossier utilisateur MakeHuman (créé au premier lancement).
MAKEHUMAN_UTILISATEUR = os.path.join(os.path.expanduser("~"), "Documents", "makehuman", "v1py3")
APERCU_PX = 1024
# Copie des aperçus dans le dépôt (None pour ne pas copier).
DEPOT_APERCUS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "images", "personnages"))

# sexe : 0 = femme, 1 = homme. muscle / poids / proportions : 0..1 (0.5 = moyen).
# Assets : noms des dossiers de makehuman/data/<type>/.
PERSONNAGES = {
    "agent_vigie_homme": {
        "morphologie": {"sexe": 1.0, "age_ans": 30, "taille_cm": 178, "muscle": 0.55, "poids": 0.5,
                        "proportions": 0.6, "origine": {"caucasian": 0.8, "african": 0.1, "asian": 0.1}},
        "assets": {"peau": "young_caucasian_male", "yeux": "low-poly", "couleur_yeux": "brown",
                   "sourcils": "eyebrow001", "cils": "eyelashes01", "cheveux": "short02",
                   "topologie": "male1591", "vetements": ["male_casualsuit05", "shoes03"]},
    },
    "agent_vigie_femme": {
        "morphologie": {"sexe": 0.0, "age_ans": 30, "taille_cm": 168, "muscle": 0.5, "poids": 0.5,
                        "proportions": 0.6, "origine": {"caucasian": 0.8, "african": 0.1, "asian": 0.1}},
        "assets": {"peau": "young_caucasian_female", "yeux": "low-poly", "couleur_yeux": "green",
                   "sourcils": "eyebrow009", "cils": "eyelashes02", "cheveux": "ponytail01",
                   "topologie": "female1605", "vetements": ["female_casualsuit01", "shoes06"]},
    },
}

PLUGIN = "9_sickworld_auto"
PLUGIN_SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "makehuman_auto", PLUGIN + ".py")


# ---------------------------------------------------------------------------
# Étape 1 : MakeHuman
# ---------------------------------------------------------------------------
def installer_plugin():
    """Copie le plugin dans le dossier utilisateur MakeHuman et l'active."""
    plugins = os.path.join(MAKEHUMAN_UTILISATEUR, "plugins")
    os.makedirs(plugins, exist_ok=True)
    shutil.copy2(PLUGIN_SRC, os.path.join(plugins, PLUGIN + ".py"))
    ini = os.path.join(MAKEHUMAN_UTILISATEUR, "settings.ini")
    settings = {}
    if os.path.exists(ini):
        with open(ini, encoding="utf-8") as f:
            settings = json.load(f)
    if not settings.get("version"):
        with open(os.path.join(MAKEHUMAN, "makehuman", "makehuman.py"), encoding="utf-8") as f:
            for line in f:
                if line.startswith("__version__"):
                    settings["version"] = line.split('"')[1]
                    break
    actifs = settings.setdefault("activeUserPlugins", [])
    if PLUGIN not in actifs:
        actifs.append(PLUGIN)
        with open(ini, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=4, ensure_ascii=False)


def lancer_makehuman(noms):
    installer_plugin()
    os.makedirs(DOSSIER_SORTIE, exist_ok=True)
    job = {"personnages": [], "rapport": os.path.join(DOSSIER_SORTIE, "rapport_makehuman.json")}
    for nom in noms:
        spec = dict(PERSONNAGES[nom])
        spec["nom"] = nom
        spec["dossier"] = os.path.join(DOSSIER_SORTIE, nom)
        if os.path.isdir(os.path.join(spec["dossier"], "textures")):
            shutil.rmtree(os.path.join(spec["dossier"], "textures"))
        job["personnages"].append(spec)
    job_path = os.path.join(DOSSIER_SORTIE, "job_makehuman.json")
    with open(job_path, "w", encoding="utf-8") as f:
        json.dump(job, f, indent=2, ensure_ascii=False)
    if os.path.exists(job["rapport"]):
        os.remove(job["rapport"])
    env = dict(os.environ, SICKWORLD_MH_JOB=job_path)
    mh_dir = os.path.join(MAKEHUMAN, "makehuman")
    subprocess.run([os.path.join(MAKEHUMAN, "Python", "python.exe"), "makehuman.py"], cwd=mh_dir, env=env, timeout=900)
    if not os.path.exists(job["rapport"]):
        err = job_path + ".erreur.txt"
        raise RuntimeError("MakeHuman n'a pas produit de rapport. " + (open(err, encoding="utf-8").read() if os.path.exists(err) else ""))
    with open(job["rapport"], encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Étape 2 : Blender (.blend + aperçus)
# ---------------------------------------------------------------------------
def corriger_materiaux(bpy):
    """Branche l'alpha des textures (cils, sourcils, cheveux) et règle le rendu."""
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        bsdf.inputs["Roughness"].default_value = 0.7
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.2
        # Cartes de normales : données, pas couleurs (sinon motif en blocs).
        for n in nodes:
            if n.type == "NORMAL_MAP":
                src = [l.from_node for l in n.inputs["Color"].links if l.from_node.type == "TEX_IMAGE"]
                for t in src:
                    if t.image:
                        t.image.colorspace_settings.name = "Non-Color"
                if not src:
                    # Nœud vide laissé par l'import : on le retire.
                    for l in list(bsdf.inputs["Normal"].links):
                        links.remove(l)
        tex = None
        for link in list(bsdf.inputs["Base Color"].links):
            if link.from_node.type == "TEX_IMAGE":
                tex = link.from_node
        if tex is None:
            continue
        low = mat.name.lower()
        if any(k in low for k in ("hair", "eyebrow", "eyelash", "ponytail", "short0", "bob0")):
            for l in list(bsdf.inputs["Alpha"].links):
                links.remove(l)
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            if hasattr(mat, "surface_render_method"):
                mat.surface_render_method = "DITHERED"
            elif hasattr(mat, "blend_method"):
                mat.blend_method = "HASHED"
        else:
            for l in list(bsdf.inputs["Alpha"].links):
                links.remove(l)
            bsdf.inputs["Alpha"].default_value = 1.0


def regarder(obj, cible):
    from mathutils import Vector
    d = Vector(cible) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def etape_blender(nom):
    import bpy
    from mathutils import Vector

    dossier = os.path.join(DOSSIER_SORTIE, nom)
    fbx = os.path.join(dossier, nom + ".fbx")
    # Le FBX brut de MakeHuman est gardé à part ; <nom>.fbx sera réécrit par Blender.
    brut = os.path.join(dossier, nom + "_makehuman_brut.fbx")
    os.replace(fbx, brut)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=brut)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # Les normales personnalisées écrites par MakeHuman donnent un aspect
    # facetté : on les supprime et on lisse.
    for o in meshes:
        if o.data.has_custom_normals:
            with bpy.context.temp_override(object=o, active_object=o, selected_editable_objects=[o]):
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
        o.data.shade_smooth()
    # Boîte englobante du personnage.
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
    hauteur = zmax - zmin
    corriger_materiaux(bpy)
    bpy.ops.file.find_missing_files(directory=os.path.join(dossier, "textures"))

    # FBX propre pour Mixamo : maillages seuls, mètres, textures embarquées.
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, global_scale=1.0, use_mesh_modifiers=True,
                             mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False,
                             path_mode="COPY", embed_textures=True)

    scene = bpy.context.scene
    for moteur in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = moteur
            break
        except TypeError:
            continue
    scene.render.resolution_x = scene.render.resolution_y = APERCU_PX
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    world = bpy.data.worlds.new("Fond")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.34, 0.37, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world

    # Sol neutre.
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, zmin))
    sol = bpy.context.object
    m = bpy.data.materials.new("Sol")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.25, 0.25, 1)
    sol.data.materials.append(m)

    centre = (0, 0, zmin + hauteur * 0.5)
    for nom_l, pos, energie in (("Cle", (-2.5, -3.5, zmin + hauteur * 1.3), 900),
                                ("Remplissage", (3.0, -3.0, zmin + hauteur * 0.8), 350),
                                ("Contre", (1.0, 3.5, zmin + hauteur * 1.4), 600)):
        ld = bpy.data.lights.new(nom_l, "AREA")
        ld.energy = energie
        ld.size = 2.5
        lo = bpy.data.objects.new(nom_l, ld)
        lo.location = pos
        scene.collection.objects.link(lo)
        regarder(lo, centre)

    cd = bpy.data.cameras.new("Camera")
    cd.lens = 70
    cam = bpy.data.objects.new("Camera", cd)
    scene.collection.objects.link(cam)
    scene.camera = cam
    dist = hauteur * 3.2

    apercus = []
    for suffixe, angle in (("face", 0.0), ("3-4", 35.0)):
        a = math.radians(angle)
        cam.location = (dist * math.sin(a), -dist * math.cos(a), zmin + hauteur * 0.55)
        regarder(cam, centre)
        out = os.path.join(dossier, "%s_apercu_%s.png" % (nom, suffixe))
        scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        apercus.append(out)

    cam.location = (0, -dist, zmin + hauteur * 0.55)
    regarder(cam, centre)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(dossier, nom + ".blend"), compress=True)
    return apercus, hauteur


# ---------------------------------------------------------------------------
# Étape 3 : ZIP pour Mixamo
# ---------------------------------------------------------------------------
def creer_zip(nom):
    dossier = os.path.join(DOSSIER_SORTIE, nom)
    zpath = os.path.join(dossier, nom + ".zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(dossier, nom + ".fbx"), nom + ".fbx")
        tex = os.path.join(dossier, "textures")
        for f in sorted(os.listdir(tex)):
            z.write(os.path.join(tex, f), "textures/" + f)
    return zpath


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    noms = [a for a in args if a in PERSONNAGES] or list(PERSONNAGES)
    rapport = lancer_makehuman(noms)
    print("MAKEHUMAN", json.dumps(rapport, indent=2, ensure_ascii=False))
    for r in rapport:
        if not r.get("ok"):
            print("ECHEC", r["nom"], r.get("erreur"))
            continue
        nom = r["nom"]
        apercus, hauteur = etape_blender(nom)
        zpath = creer_zip(nom)
        print("OK", nom, "hauteur %.3f m" % hauteur, zpath)
        if DEPOT_APERCUS:
            os.makedirs(DEPOT_APERCUS, exist_ok=True)
            for a in apercus:
                shutil.copy2(a, os.path.join(DEPOT_APERCUS, os.path.basename(a)))


if __name__ == "__main__" and os.environ.get("SICKWORLD_SANS_MAIN") != "1":
    main()
