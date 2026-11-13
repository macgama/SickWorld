"""Plugin MakeHuman (1.2 / Community 1.3) : fabrique les personnages de SickWorld.

Ne fait RIEN si la variable d'environnement SICKWORLD_MH_JOB n'existe pas :
MakeHuman s'utilise donc normalement à la main même avec ce plugin installé.

Quand SICKWORLD_MH_JOB pointe vers un fichier JSON (écrit par
tools/personnages/creer_personnage.py), le plugin, une fois MakeHuman démarré :
  - règle la morphologie (sexe, âge, carrure, taille visée en cm, origine) ;
  - choisit peau, yeux, sourcils, cils, cheveux, vêtements, topologie allégée ;
  - ne met aucun squelette (Mixamo ajoutera le sien) ;
  - enregistre le .mhm et exporte un FBX binaire (mètres, pieds au sol)
    avec ses textures dans un dossier « textures » à côté ;
  - écrit un rapport JSON puis ferme MakeHuman sans toucher à ses réglages.
"""
import json
import os
import traceback

JOB_ENV = "SICKWORLD_MH_JOB"


def _data(rel):
    import getpath
    return getpath.getSysDataPath(rel)


def _geometry_tasks():
    from core import G
    tasks = {}
    cat = G.app.getCategory("Geometries")
    for t in cat.tasks:
        name = getattr(t, "proxyName", None)
        if name:
            tasks[name] = t
    return tasks


def _set_height(h, target_cm):
    """Recherche par dichotomie la valeur du curseur « Height » qui donne target_cm."""
    lo, hi = 0.0, 1.0
    for _ in range(18):
        mid = (lo + hi) / 2.0
        h.setHeight(mid)
        h.applyAllTargets()
        if h.getHeightCm() < target_cm:
            lo = mid
        else:
            hi = mid
    h.setHeight((lo + hi) / 2.0)
    h.applyAllTargets()
    return h.getHeightCm()


def _build(spec, report):
    from core import G
    import material

    h = G.app.selectedHuman
    h.resetMeshValues()
    h.setSubdivided(False)

    m = spec["morphologie"]
    h.setGender(m["sexe"])
    h.setAgeYears(m["age_ans"])
    h.setMuscle(m["muscle"])
    h.setWeight(m["poids"])
    h.setBodyProportions(m["proportions"])
    origine = m.get("origine", {"caucasian": 1.0})
    h.setCaucasian(origine.get("caucasian", 0.0), sync=False)
    h.setAfrican(origine.get("african", 0.0), sync=False)
    h.setAsian(origine.get("asian", 0.0), sync=False)
    h.applyAllTargets()
    report["taille_cm"] = round(_set_height(h, m["taille_cm"]), 1)

    tasks = _geometry_tasks()
    report["taches"] = sorted(tasks)

    def choose(kind, name):
        t = tasks[kind]
        path = _data("%s/%s/%s.mhclo" % (kind, name, name))
        if not os.path.exists(os.path.splitext(path)[0] + ".mhpxy") and not os.path.exists(path):
            raise RuntimeError("asset introuvable : %s" % path)
        t.selectProxy(path)
        report.setdefault("assets", []).append("%s/%s" % (kind, name))

    # Retire ce que le modèle par défaut a pu ajouter.
    if "clothes" in tasks:
        for pxy in list(tasks["clothes"].getSelection()):
            tasks["clothes"].deselectProxy(pxy.file, suppressSignal=True)

    a = spec["assets"]
    choose("eyes", a["yeux"])
    choose("eyebrows", a["sourcils"])
    choose("eyelashes", a["cils"])
    if a.get("cheveux"):
        choose("hair", a["cheveux"])
    if a.get("topologie"):
        choose("proxymeshes", a["topologie"])
    for c in a["vetements"]:
        choose("clothes", c)
    for kind in ("teeth", "tongue"):
        if kind in tasks:
            try:
                tasks[kind].selectProxy(None)
            except Exception:
                pass

    h.material = material.fromFile(_data("skins/%s/%s.mhmat" % (a["peau"], a["peau"])))
    eyes = h.getEyesProxy()
    if eyes is not None and getattr(eyes, "object", None) is not None:
        eyes.object.material = material.fromFile(_data("eyes/materials/%s.mhmat" % a["couleur_yeux"]))

    # Pas de squelette, pose de repos (A-pose MakeHuman).
    try:
        h.setSkeleton(None)
    except Exception:
        pass
    h.applyAllTargets()

    out_dir = spec["dossier"]
    os.makedirs(out_dir, exist_ok=True)
    nom = spec["nom"]
    mhm = os.path.join(out_dir, nom + ".mhm")
    h.save(mhm)
    report["mhm"] = mhm

    plug = G.app.getPlugin("9_export_fbx")
    import importlib
    mh2fbx = importlib.import_module(plug.__name__ + ".mh2fbx")
    cfg = plug.FbxConfig()
    cfg.setHuman(h)
    cfg.feetOnGround = True
    cfg.scale = 1.0          # identique à l'option « Scale units : meter » de l'interface (0.1 x 10)
    cfg.unit = "meter"
    cfg.binary = True
    cfg.hiddenGeom = False
    cfg.useRelPaths = True
    fbx = os.path.join(out_dir, nom + ".fbx")
    mh2fbx.exportFbx(fbx, cfg)
    report["fbx"] = fbx


def _run():
    from core import G
    job_path = os.environ[JOB_ENV]
    with open(job_path, encoding="utf-8") as f:
        job = json.load(f)
    results = []
    for spec in job["personnages"]:
        report = {"nom": spec["nom"]}
        try:
            _build(spec, report)
            report["ok"] = True
        except Exception:
            report["ok"] = False
            report["erreur"] = traceback.format_exc()
        results.append(report)
    with open(job["rapport"], "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    # Sortie directe : on n'écrase pas les réglages MakeHuman de l'utilisateur.
    os._exit(0)


def load(app):
    if not os.environ.get(JOB_ENV):
        return
    from PyQt5 import QtCore
    from core import G

    state = {"tries": 0}

    def tick():
        state["tries"] += 1
        ready = getattr(G.app, "selectedHuman", None) is not None and G.app.mainwin is not None
        try:
            ready = ready and G.app.getCategory("Geometries") is not None and G.app.getPlugin("9_export_fbx") is not None
        except Exception:
            ready = False
        if not ready and state["tries"] < 120:
            QtCore.QTimer.singleShot(1000, tick)
            return
        try:
            _run()
        except Exception:
            try:
                with open(os.environ[JOB_ENV] + ".erreur.txt", "w", encoding="utf-8") as f:
                    f.write(traceback.format_exc())
            finally:
                os._exit(1)

    QtCore.QTimer.singleShot(8000, tick)


def unload(app):
    pass
