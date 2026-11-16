"""Habits d'époque des figurants et PNJ (Préhistoire, Égypte, Grèce…).

Ce programme « coud » des vêtements autour du corps MakeHuman sans vêtements
(tools/personnages/corps_nus/) et les attache au squelette Mixamo des personnages
du jeu (game/assets/personnages/<sexe>/immobile.fbx), pour qu'ils suivent toutes les
animations (marcher, s'asseoir, creuser…).

Méthode (aucune retouche à la main) :
  1. Le corps nu reçoit les poids d'os du personnage rigué (copiés depuis le corps,
     la tenue moderne et les chaussures du FBX Mixamo, au point le plus proche).
  2. Pour chaque pièce (tunique, jupe, manche, pantalon…), on découpe le corps en
     tranches le long d'un axe (vertical pour le tronc, l'os pour un bras ou une jambe),
     on prend l'enveloppe convexe de chaque tranche (le tissu passe par-dessus les creux)
     et on l'agrandit (aisance, plis, évasement, blousant au-dessus de la ceinture).
  3. Chaque point du tissu prend les poids du point de corps le plus proche ; en bas
     d'une robe, il suit les jambes en partie (sinon les jambes traversent le tissu).
  4. Les parties du corps cachées sous le tissu sont retirées (rien ne dépasse quand
     le personnage bouge).
  5. Sortie : un fichier JSON par sexe et par habit, converti ensuite en maillage Godot
     (.res) par tools/personnages/habits_vers_godot.gd.

Lancement (Blender 5.2, ou le module Python « bpy » + numpy + scipy) :
    blender --background --python tools/personnages/habits_epoque.py -- [habits...]
    python tools/personnages/habits_epoque.py [habits...]
puis :
    godot --headless --path game -s res://../tools/personnages/habits_vers_godot.gd
(voir docs/guides/habits-d-epoque.md).

Repère de sortie : celui du squelette dans Godot (mètres, Y en haut, le personnage
regarde vers +Z, sa gauche est +X).
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree
from scipy.spatial import ConvexHull, cKDTree

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.normpath(os.path.join(ICI, "..", ".."))
SORTIE = os.path.join(ICI, "habits_json")
EPAISSEUR = 0.004
rng = np.random.default_rng(431)


def g(v):
    """Blender (Z en haut, mètres) → repère du squelette Godot."""
    return np.array([v[0], v[2], -v[1]])


# ---------------------------------------------------------------------------
# Lecture des personnages
# ---------------------------------------------------------------------------
def _triangles(obj):
    me = obj.data
    me.calc_loop_triangles()
    tris = np.array([t.vertices[:] for t in me.loop_triangles], dtype=np.int64)
    tri_loops = np.array([t.loops[:] for t in me.loop_triangles], dtype=np.int64)
    return tris, tri_loops


def _poids(obj, noms_os):
    index = {n: i for i, n in enumerate(noms_os)}
    groupes = {vg.index: index.get(vg.name.replace(":", "_"), -1) for vg in obj.vertex_groups}
    w = np.zeros((len(obj.data.vertices), len(noms_os)))
    for v in obj.data.vertices:
        for ge in v.groups:
            b = groupes.get(ge.group, -1)
            if b >= 0:
                w[v.index, b] += ge.weight
    return w


def lire_rig(sexe):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(DEPOT, "game", "assets", "personnages", sexe, "immobile.fbx"))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    noms = [b.name.replace(":", "_") for b in arm.data.bones]
    os_pos = {b.name.replace(":", "_"): g(arm.matrix_world @ b.head_local) for b in arm.data.bones}
    soupe_p, soupe_w = [], []
    yeux = None
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        mw = o.matrix_world
        p = np.array([g(mw @ v.co) for v in o.data.vertices])
        if o.name.startswith("low-poly"):
            yeux = p
        if not any(k in o.name for k in ("1591", "1605", "suit", "shoes")):
            continue
        tris, _ = _triangles(o)
        w = _poids(o, noms)
        soupe_p.append(p[tris])
        soupe_w.append(w[tris])
    return {"noms": noms, "os": os_pos, "tri_p": np.concatenate(soupe_p), "tri_w": np.concatenate(soupe_w), "yeux": yeux}


def lire_corps_nu(sexe):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ICI, "corps_nus", "corps_nu_%s_makehuman_brut.fbx" % sexe))
    corps = yeux = None
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        if any(k in o.name for k in ("1591", "1605")):
            corps = o
        elif o.name.startswith("low-poly"):
            yeux = np.array([g(o.matrix_world @ v.co) for v in o.data.vertices])
    mw = corps.matrix_world
    p = np.array([g(mw @ v.co) for v in corps.data.vertices])
    tris, tri_loops = _triangles(corps)
    uv = np.array([d.uv[:] for d in corps.data.uv_layers.active.data])
    return {"p": p, "tris": tris, "tri_loops": tri_loops, "uv_boucles": uv, "yeux": yeux}


def aligner(nu, rig):
    """Met le corps nu exactement à la place du corps rigué (les yeux servent de repère)."""
    a, b = nu["yeux"], rig["yeux"]
    if a is not None and b is not None and len(a) == len(b):
        ca, cb = a.mean(0), b.mean(0)
        s = math.sqrt(((b - cb) ** 2).sum() / max(1e-12, ((a - ca) ** 2).sum()))
        residu = np.abs((a - ca) * s + cb - b).max()
        print("  alignement : échelle %.4f, décalage %s, écart max %.4f m" % (s, np.round(cb - ca * s, 4), residu))
        if residu < 0.01:
            nu["p"] = (nu["p"] - ca) * s + cb
            return
    print("  alignement par les yeux impossible : corps laissé tel quel")


def transferer_poids(nu, rig):
    """Poids d'os du corps nu = ceux de la surface riguée la plus proche."""
    tp = rig["tri_p"]
    n = len(tp)
    verts = tp.reshape(-1, 3)
    arbre = BVHTree.FromPolygons([tuple(v) for v in verts], [(3 * i, 3 * i + 1, 3 * i + 2) for i in range(n)])
    w = np.zeros((len(nu["p"]), len(rig["noms"])))
    loin = np.zeros(len(nu["p"]), dtype=bool)
    for i, p in enumerate(nu["p"]):
        loc, _, k, d = arbre.find_nearest(tuple(p))
        a, b, c = tp[k]
        loc = np.array(loc)
        v0, v1, v2 = b - a, c - a, loc - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = max(1e-12, d00 * d11 - d01 * d01)
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        bu = 1.0 - bv - bw
        w[i] = rig["tri_w"][k][0] * bu + rig["tri_w"][k][1] * bv + rig["tri_w"][k][2] * bw
        loin[i] = d > 0.004
    voisins = _voisins(len(nu["p"]), nu["tris"])
    for _ in range(4):
        w2 = w.copy()
        for i in np.nonzero(loin)[0]:
            w2[i] = 0.5 * w[i] + 0.5 * w[voisins[i]].mean(0)
        w = w2
    w = np.clip(w, 0, None)
    w /= np.maximum(1e-9, w.sum(1, keepdims=True))
    nu["w"] = w
    print("  poids : %d sommets copiés, %d interpolés" % ((~loin).sum(), loin.sum()))


def _voisins(n, tris):
    v = [set() for _ in range(n)]
    for a, b, c in tris:
        v[a].update((b, c))
        v[b].update((a, c))
        v[c].update((a, b))
    return [np.array(sorted(s)) for s in v]


def echantillonner(nu, par_tri=24):
    """Nuage de points dense sur la peau, avec ses poids d'os."""
    p, w, t = nu["p"], nu["w"], nu["tris"]
    r1 = rng.random((len(t), par_tri, 1))
    r2 = rng.random((len(t), par_tri, 1))
    s = np.sqrt(r1)
    a, b, c = (1 - s), s * (1 - r2), s * r2
    pts = a * p[t[:, 0]][:, None] + b * p[t[:, 1]][:, None] + c * p[t[:, 2]][:, None]
    ws = a * w[t[:, 0]][:, None] + b * w[t[:, 1]][:, None] + c * w[t[:, 2]][:, None]
    pts = np.concatenate([pts.reshape(-1, 3), p])
    ws = np.concatenate([ws.reshape(-1, w.shape[1]), w])
    return pts, ws


# ---------------------------------------------------------------------------
# Tranches : l'enveloppe du corps le long d'un axe
# ---------------------------------------------------------------------------
N_ANGLES = 96


class Gaine:
    """Enveloppe convexe du corps tranche par tranche le long d'un chemin (axe).

    Repère de chaque tranche : origine o, direction t (axe), e1 (devant), e2 (gauche).
    Une direction d'angle θ vaut cos θ·e1 + sin θ·e2 : θ = 0 devant, θ = 90° à gauche.
    """

    def __init__(self, points, chemin, pas=0.01, epaisseur_tranche=0.009, rayon_max=0.6):
        chemin = np.asarray(chemin, dtype=float)
        longueurs = np.linalg.norm(np.diff(chemin, axis=0), axis=1)
        total = longueurs.sum()
        self.longueur = total
        self.s = np.arange(0.0, total + 1e-9, pas)
        cumul = np.concatenate([[0], np.cumsum(longueurs)])
        self.o = np.array([[np.interp(s, cumul, chemin[:, k]) for k in range(3)] for s in self.s])
        t = np.gradient(self.o, axis=0)
        t /= np.linalg.norm(t, axis=1, keepdims=True)
        # Lisse la direction aux coudes du chemin.
        for _ in range(6):
            t[1:-1] = (t[:-2] + 2 * t[1:-1] + t[2:]) / 4
        t /= np.linalg.norm(t, axis=1, keepdims=True)
        devant = np.array([0.0, 0.0, 1.0])
        e1 = devant - (t @ devant)[:, None] * t
        e1[np.linalg.norm(e1, axis=1) < 1e-3] = [0, -1, 0]
        e1 /= np.linalg.norm(e1, axis=1, keepdims=True)
        e2 = np.cross(t, e1)
        # Pour le tronc vertical (t = +Y) : e2 = Y × Z = +X (la gauche). Pour un membre on garde la même main.
        self.t, self.e1, self.e2 = t, e1, e2
        self.theta = np.linspace(0, 2 * np.pi, N_ANGLES, endpoint=False)
        R = np.full((len(self.s), N_ANGLES), np.nan)
        C = np.zeros((len(self.s), 2))
        for i in range(len(self.s)):
            d = points - self.o[i]
            h = d @ self.t[i]
            m = np.abs(h) < epaisseur_tranche
            if m.sum() < 6:
                continue
            q = np.stack([d[m] @ self.e1[i], d[m] @ self.e2[i]], axis=1)
            q = q[np.linalg.norm(q, axis=1) < rayon_max]
            if len(q) < 6:
                continue
            try:
                hull = ConvexHull(q)
            except Exception:
                continue
            poly = q[hull.vertices]
            c = _centre_polygone(poly)
            C[i] = c
            R[i] = _rayons(poly - c, self.theta)
        ok = ~np.isnan(R[:, 0])
        if not ok.any():
            raise RuntimeError("gaine vide")
        idx = np.arange(len(self.s))
        for j in range(N_ANGLES):
            R[:, j] = np.interp(idx, idx[ok], R[ok, j])
        for k in range(2):
            C[:, k] = np.interp(idx, idx[ok], C[ok, k])
        # Lissage le long de l'axe (le tissu ne suit pas chaque bosse).
        C = _lisser_1d(C, 5)
        R = _lisser_1d(R, 2)
        self.R, self.C = R, C

    def indice(self, s):
        return np.clip(s / (self.s[1] - self.s[0]), 0, len(self.s) - 1.0001)

    def rayon(self, s, theta):
        f = self.indice(s)
        i = np.floor(f).astype(int)
        a = f - i
        tj = (np.mod(theta, 2 * np.pi) / (2 * np.pi)) * N_ANGLES
        j = np.floor(tj).astype(int) % N_ANGLES
        b = tj - np.floor(tj)
        j2 = (j + 1) % N_ANGLES
        r0 = self.R[i, j] * (1 - b) + self.R[i, j2] * b
        r1 = self.R[i + 1, j] * (1 - b) + self.R[i + 1, j2] * b
        return r0 * (1 - a) + r1 * a

    def repere(self, s):
        f = self.indice(s)
        i = np.floor(f).astype(int)
        a = (f - i)[..., None]
        o = self.o[i] * (1 - a) + self.o[i + 1] * a
        e1 = self.e1[i] * (1 - a) + self.e1[i + 1] * a
        e2 = self.e2[i] * (1 - a) + self.e2[i + 1] * a
        c = self.C[i] * (1 - a) + self.C[i + 1] * a
        return o, e1, e2, c

    def point(self, s, theta, r):
        o, e1, e2, c = self.repere(s)
        ct, st = np.cos(theta)[..., None], np.sin(theta)[..., None]
        return o + e1 * (c[..., 0:1] + r[..., None] * ct) + e2 * (c[..., 1:2] + r[..., None] * st)

    def coordonnees(self, p):
        """Pour des points du corps : (s, θ, distance au centre de la tranche)."""
        d = p[:, None, :] - self.o[None, :, :]
        h = np.einsum("nsk,sk->ns", d, self.t)
        # La tranche la plus proche dont le plan passe près du point.
        dist = np.abs(h) + 0.05 * np.linalg.norm(d - h[..., None] * self.t[None], axis=2)
        i = np.argmin(dist, axis=1)
        dd = d[np.arange(len(p)), i]
        x = np.einsum("nk,nk->n", dd, self.e1[i]) - self.C[i, 0]
        y = np.einsum("nk,nk->n", dd, self.e2[i]) - self.C[i, 1]
        hh = h[np.arange(len(p)), i]
        return self.s[i] + hh, np.mod(np.arctan2(y, x), 2 * np.pi), np.hypot(x, y)


def _centre_polygone(p):
    x, y = p[:, 0], p[:, 1]
    x2, y2 = np.roll(x, -1), np.roll(y, -1)
    cr = x * y2 - x2 * y
    a = cr.sum() / 2
    if abs(a) < 1e-9:
        return p.mean(0)
    return np.array([((x + x2) * cr).sum() / (6 * a), ((y + y2) * cr).sum() / (6 * a)])


def _rayons(poly, theta):
    """Distance du centre (0,0) au bord du polygone convexe, dans chaque direction."""
    a = poly
    b = np.roll(poly, -1, axis=0)
    d = np.stack([np.cos(theta), np.sin(theta)], axis=1)
    e = b - a
    # Résout t·d = a + u·e  pour chaque direction et chaque côté.
    den = d[:, None, 0] * e[None, :, 1] - d[:, None, 1] * e[None, :, 0]
    with np.errstate(divide="ignore", invalid="ignore"):
        t = (a[None, :, 0] * e[None, :, 1] - a[None, :, 1] * e[None, :, 0]) / den
        u = (a[None, :, 0] * d[:, None, 1] - a[None, :, 1] * d[:, None, 0]) / den
    t = np.where((u >= -1e-6) & (u <= 1 + 1e-6) & (t > 0), t, np.inf)
    r = t.min(axis=1)
    r[~np.isfinite(r)] = np.nanmax(np.where(np.isfinite(r), r, np.nan)) if np.isfinite(r).any() else 0.1
    return r


def _lisser_1d(a, rayon):
    if rayon <= 0:
        return a
    noyau = np.ones(2 * rayon + 1) / (2 * rayon + 1)
    pad = np.concatenate([np.repeat(a[:1], rayon, 0), a, np.repeat(a[-1:], rayon, 0)])
    out = np.empty_like(a)
    for k in range(a.shape[1]):
        out[:, k] = np.convolve(pad[:, k], noyau, mode="valid")
    return out


# ---------------------------------------------------------------------------
# Pièces de tissu
# ---------------------------------------------------------------------------
class Piece:
    """Un morceau de maillage avec sa matière et son rôle de couleur."""

    def __init__(self, matiere, role):
        self.matiere = matiere
        self.role = role
        self.p = np.zeros((0, 3))
        self.n = np.zeros((0, 3))
        self.uv = np.zeros((0, 2))
        self.w = None
        self.f = np.zeros((0, 3), dtype=np.int64)

    def ajouter(self, p, n, uv, w, f):
        base = len(self.p)
        self.p = np.concatenate([self.p, p])
        self.n = np.concatenate([self.n, n])
        self.uv = np.concatenate([self.uv, uv])
        self.w = w if self.w is None else np.concatenate([self.w, w])
        self.f = np.concatenate([self.f, f + base])


def grille_faces(lignes, colonnes, ferme):
    f = []
    cmax = colonnes if ferme else colonnes - 1
    for i in range(lignes - 1):
        for j in range(cmax):
            a = i * colonnes + j
            b = i * colonnes + (j + 1) % colonnes
            c = (i + 1) * colonnes + j
            d = (i + 1) * colonnes + (j + 1) % colonnes
            f.append((a, c, b))
            f.append((b, c, d))
    return np.array(f, dtype=np.int64).reshape(-1, 3)


def normales_grille(P, ferme):
    """Normales d'une grille (lignes × colonnes), sans couture sur un tube fermé."""
    if ferme:
        dj = np.roll(P, -1, axis=1) - np.roll(P, 1, axis=1)
    else:
        dj = np.gradient(P, axis=1)
    di = np.gradient(P, axis=0)
    n = np.cross(dj, di)
    n /= np.maximum(1e-9, np.linalg.norm(n, axis=2, keepdims=True))
    return n


def lisser_poids_grille(W, lignes, colonnes, ferme, fois=4, force=0.5):
    W = W.reshape(lignes, colonnes, -1)
    for _ in range(fois):
        if ferme:
            g_ = (np.roll(W, 1, 1) + np.roll(W, -1, 1)) * 0.5
        else:
            g_ = W.copy()
            g_[:, 1:-1] = (W[:, :-2] + W[:, 2:]) * 0.5
        v = W.copy()
        v[1:-1] = (W[:-2] + W[2:]) * 0.5
        W = W * (1 - force) + (g_ * 0.6 + v * 0.4) * force
    return W.reshape(lignes * colonnes, -1)


class Atelier:
    """Fabrique les habits d'un sexe : garde le corps, ses poids, ses gaines."""

    def __init__(self, sexe):
        self.sexe = sexe
        print("== %s" % sexe)
        rig = lire_rig(sexe)
        nu = lire_corps_nu(sexe)
        aligner(nu, rig)
        transferer_poids(nu, rig)
        self.noms = rig["noms"]
        self.os = rig["os"]
        self.nu = nu
        self.pts, self.pts_w = echantillonner(nu)
        self.ib = {n: i for i, n in enumerate(self.noms)}
        bras = [i for n, i in self.ib.items() if "Arm" in n or "Hand" in n]
        self.poids_bras = self.pts_w[:, bras].sum(1)
        self.cache_gaines = {}
        self.arbre_tout = cKDTree(self.pts)
        p = nu["p"]
        self.y_sol = p[:, 1].min()
        self.y_haut = p[:, 1].max()
        hanches = self.os["mixamorig_Hips"]
        self.y_hanches = hanches[1]
        self.y_genou = 0.5 * (self.os["mixamorig_LeftLeg"][1] + self.os["mixamorig_RightLeg"][1])
        self.y_cheville = 0.5 * (self.os["mixamorig_LeftFoot"][1] + self.os["mixamorig_RightFoot"][1])
        self.y_cou = self.os["mixamorig_Neck"][1]
        self.y_epaule = 0.5 * (self.os["mixamorig_LeftArm"][1] + self.os["mixamorig_RightArm"][1])
        self.y_poitrine = self.os["mixamorig_Spine2"][1]
        self.y_taille = self.os["mixamorig_Spine1"][1] - 0.02
        # Entrejambe : point le plus haut entre les deux jambes.
        m = (np.abs(p[:, 0]) < 0.02) & (p[:, 1] < self.y_hanches) & (p[:, 1] > self.y_genou)
        self.y_entrejambe = p[m, 1].min() if m.any() else self.y_hanches - 0.1
        print("  repères : sol %.2f cheville %.2f genou %.2f entrejambe %.2f hanches %.2f taille %.2f poitrine %.2f épaules %.2f cou %.2f" % (
            self.y_sol, self.y_cheville, self.y_genou, self.y_entrejambe, self.y_hanches, self.y_taille,
            self.y_poitrine, self.y_epaule, self.y_cou))
        self.pieces = []
        self.caches = []  # fonctions p -> booléen (sommet du corps caché par le tissu)

    def poids_os(self, *noms):
        return self.pts_w[:, [self.ib[n] for n in noms if n in self.ib]].sum(1)

    # -- gaines ------------------------------------------------------------
    def gaine_tronc(self):
        if "tronc" not in self.cache_gaines:
            m = self.poids_bras < 0.3
            pts = self.pts[m]
            self.cache_gaines["tronc"] = (Gaine(pts, [[0, 0, 0], [0, self.y_cou + 0.06, 0]]), cKDTree(pts), self.pts_w[m])
        return self.cache_gaines["tronc"]

    def gaine_membre(self, cote, membre):
        cle = cote + membre
        if cle not in self.cache_gaines:
            C = "Left" if cote == "g" else "Right"
            if membre == "bras":
                chemin = [self.os["mixamorig_%sShoulder" % C] * 0.8 + self.os["mixamorig_%sArm" % C] * 0.2,
                          self.os["mixamorig_%sArm" % C], self.os["mixamorig_%sForeArm" % C],
                          self.os["mixamorig_%sHand" % C]]
                m = self.poids_os(*["mixamorig_%s%s" % (C, n) for n in ("Arm", "ForeArm", "Hand")]) > 0.5
            else:
                chemin = [self.os["mixamorig_%sUpLeg" % C], self.os["mixamorig_%sLeg" % C],
                          self.os["mixamorig_%sFoot" % C]]
                m = self.poids_os(*["mixamorig_%s%s" % (C, n) for n in ("UpLeg", "Leg", "Foot", "ToeBase")]) > 0.5
            pts = self.pts[m]
            self.cache_gaines[cle] = (Gaine(pts, chemin, rayon_max=0.2), cKDTree(pts), self.pts_w[m])
        return self.cache_gaines[cle]

    # -- outils ------------------------------------------------------------
    def _poids_proches(self, arbre, poids, P, k=6):
        d, i = arbre.query(P, k=k)
        a = 1.0 / np.maximum(d, 0.004) ** 2
        a /= a.sum(1, keepdims=True)
        return np.einsum("nk,nkb->nb", a, poids[i])

    def _os(self, nom):
        w = np.zeros(len(self.noms))
        w[self.ib[nom]] = 1.0
        return w

    def tube(self, gaine, s_bas, s_haut, aisance, matiere, role, lignes=44, colonnes=72, suivre_jambes=None,
             cacher=True, marge_cache=0.02, ferme=True, theta=None, epais=EPAISSEUR, uv_mul=1.0, poids_fn=None):
        """Tube de tissu autour d'une gaine, de s_bas(θ) à s_haut(θ).

        aisance(s, θ) → écart au corps en mètres (tableau). s_bas / s_haut : tableaux (une
        valeur par colonne) ou nombres. suivre_jambes(s) → part des poids prise aux jambes
        (0 = tout aux hanches) pour le bas des robes.
        """
        G, arbre, poids = gaine
        if theta is None:
            theta = np.linspace(0, 2 * np.pi, colonnes, endpoint=False)
        colonnes = len(theta)
        s_bas = np.broadcast_to(np.asarray(s_bas, dtype=float), (colonnes,))
        s_haut = np.broadcast_to(np.asarray(s_haut, dtype=float), (colonnes,))
        t = np.linspace(0, 1, lignes)[:, None]
        S = s_bas[None, :] * (1 - t) + s_haut[None, :] * t
        TH = np.broadcast_to(theta[None, :], S.shape)
        R = G.rayon(S, TH) + aisance(S, TH)
        P = G.point(S, TH, R)
        N = normales_grille(P, ferme)
        # Le tissu doit tourner sa face vers l'extérieur.
        o, e1, e2, c = G.repere(S)
        dehors = P - (o + e1 * c[..., 0:1] + e2 * c[..., 1:2])
        if (np.einsum("ijk,ijk->ij", N, dehors) < 0).mean() > 0.5:
            N = -N
            inverse = True
        else:
            inverse = False
        # UV en mètres : u le long du tour (moyenne des rayons), v le long de l'axe.
        r_moy = R.mean()
        U = TH * r_moy * uv_mul
        V = -S * uv_mul
        if ferme:
            # Colonne de couture (u = 2π r) : on duplique la première colonne.
            P = np.concatenate([P, P[:, :1]], axis=1)
            N = np.concatenate([N, N[:, :1]], axis=1)
            U = np.concatenate([U, np.full((lignes, 1), 2 * np.pi * r_moy * uv_mul)], axis=1)
            V = np.concatenate([V, V[:, :1]], axis=1)
            S = np.concatenate([S, S[:, :1]], axis=1)
            colonnes_g = colonnes + 1
        else:
            colonnes_g = colonnes
        flat_p = P.reshape(-1, 3)
        W = self._poids_proches(arbre, poids, flat_p) if poids_fn is None else poids_fn(flat_p, S.reshape(-1))
        if suivre_jambes is not None:
            a = np.clip(suivre_jambes(S.reshape(-1)), 0, 1)[:, None]
            jambes = W.copy()
            # Dans la jupe : moitié gauche → jambe gauche, moitié droite → jambe droite.
            W = W * a + self._os("mixamorig_Hips")[None, :] * (1 - a)
            del jambes
        W = lisser_poids_grille(W, lignes, colonnes_g, False, fois=3)
        f = grille_faces(lignes, colonnes_g, False)
        if inverse:
            f = f[:, [0, 2, 1]]
        uv = np.stack([U.reshape(-1), V.reshape(-1)], axis=1)
        piece = Piece(matiere, role)
        piece.ajouter(flat_p, N.reshape(-1, 3), uv, W, f)
        if epais > 0:
            self._epaissir(piece, lignes, colonnes_g, epais)
        self.pieces.append(piece)
        if cacher:
            sb, sh = s_bas.copy(), s_haut.copy()

            def cache(p, G=G, sb=sb, sh=sh, theta=theta, aisance=aisance, marge=marge_cache):
                s, th, r = G.coordonnees(p)
                j = np.clip(np.round(th / (2 * np.pi) * len(theta)).astype(int) % len(theta), 0, len(theta) - 1)
                lo, hi = np.minimum(sb[j], sh[j]), np.maximum(sb[j], sh[j])
                dedans = (s > lo + marge) & (s < hi - marge)
                return dedans & (r < G.rayon(s, th) + aisance(s, th) + 0.01)
            self.caches.append(cache)
        return piece, P[:, :colonnes], W

    def _epaissir(self, piece, lignes, colonnes, e):
        """Double face : une couche intérieure et un ourlet sur les bords."""
        n0 = len(piece.p)
        p_in = piece.p - piece.n * e
        f_in = piece.f[:, [0, 2, 1]] + n0
        piece.p = np.concatenate([piece.p, p_in])
        piece.n = np.concatenate([piece.n, -piece.n])
        piece.uv = np.concatenate([piece.uv, piece.uv])
        piece.w = np.concatenate([piece.w, piece.w])
        bords = []
        for ligne, sens in ((0, 1), (lignes - 1, -1)):
            for j in range(colonnes - 1):
                a = ligne * colonnes + j
                b = a + 1
                if sens > 0:
                    bords += [(a, b + n0, b), (a, a + n0, b + n0)]
                else:
                    bords += [(a, b, b + n0), (a, b + n0, a + n0)]
        piece.f = np.concatenate([piece.f, f_in, np.array(bords, dtype=np.int64)])

    def cordon(self, chemin_p, chemin_w, rayon, matiere, role, ferme=True, aplati=1.0, segments=8, decale=0.0,
               normales=None):
        """Corde / ceinture / bourrelet le long d'un chemin de points (avec leurs poids)."""
        P = np.asarray(chemin_p)
        n = len(P)
        if ferme:
            tg = np.roll(P, -1, 0) - np.roll(P, 1, 0)
        else:
            tg = np.gradient(P, axis=0)
        tg /= np.maximum(1e-9, np.linalg.norm(tg, axis=1, keepdims=True))
        if normales is None:
            centre = P.mean(0)
            dehors = P - centre
            dehors -= (np.einsum("nk,nk->n", dehors, tg))[:, None] * tg
        else:
            dehors = np.asarray(normales).copy()
        dehors /= np.maximum(1e-9, np.linalg.norm(dehors, axis=1, keepdims=True))
        b = np.cross(tg, dehors)
        a = np.linspace(0, 2 * np.pi, segments + 1)
        pts, nrm, uvs, ws = [], [], [], []
        longueur = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
        for i in range(n):
            for k in range(segments + 1):
                d = dehors[i] * np.cos(a[k]) + b[i] * np.sin(a[k]) * aplati
                pts.append(P[i] + dehors[i] * (rayon + decale) + d * rayon)
                nn = dehors[i] * np.cos(a[k]) + b[i] * np.sin(a[k]) / max(aplati, 0.2)
                nrm.append(nn / np.linalg.norm(nn))
                uvs.append((longueur[i], a[k] * rayon))
                ws.append(chemin_w[i])
        cols = segments + 1
        f = []
        lignes = n + (1 if ferme else 0)
        for i in range(lignes - 1):
            i2 = (i + 1) % n
            for k in range(segments):
                p0, p1 = i * cols + k, i * cols + k + 1
                q0, q1 = i2 * cols + k, i2 * cols + k + 1
                f += [(p0, p1, q0), (p1, q1, q0)]
        piece = Piece(matiere, role)
        f = np.array(f, dtype=np.int64)
        # Orientation : normales vers l'extérieur.
        P_ = np.array(pts)
        tri = P_[f]
        nf = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        if (np.einsum("nk,nk->n", nf, np.array(nrm)[f[:, 0]]) < 0).mean() > 0.5:
            f = f[:, [0, 2, 1]]
        piece.ajouter(P_, np.array(nrm), np.array(uvs), np.array(ws), f)
        self.pieces.append(piece)
        return piece

    def coque(self, masque_sommets, ecart, matiere, role, lisser=3, aplatir_sol=None, cacher=True):
        """Coque collée au corps (chaussures, bandes) : faces du corps gonflées."""
        p, t, w = self.nu["p"], self.nu["tris"], self.nu["w"]
        garder = masque_sommets[t].all(1)
        tris = t[garder]
        idx = np.unique(tris)
        remap = -np.ones(len(p), dtype=np.int64)
        remap[idx] = np.arange(len(idx))
        f = remap[tris]
        n = _normales_sommets(p, t)[idx]
        q = p[idx] + n * ecart
        voisins = _voisins(len(idx), f)
        for _ in range(lisser):
            q = 0.5 * q + 0.5 * np.array([q[v].mean(0) if len(v) else q[i] for i, v in enumerate(voisins)])
        q = q + n * 0.002
        if aplatir_sol is not None:
            q[:, 1] = np.maximum(q[:, 1], aplatir_sol)
        uv = np.stack([q[:, 0] + q[:, 2], q[:, 1]], axis=1)
        piece = Piece(matiere, role)
        piece.ajouter(q, n, uv, w[idx], f)
        self.pieces.append(piece)
        if cacher:
            cache_idx = set(idx.tolist())
            self.caches.append(lambda pp, c=cache_idx: np.array([i in c for i in range(len(pp))]))
        return piece

    # -- sortie --------------------------------------------------------------
    def corps_visible(self):
        """Faces du corps qui restent (les autres sont sous le tissu)."""
        p = self.nu["p"]
        cache = np.zeros(len(p), dtype=bool)
        for c in self.caches:
            cache |= c(p)
        t = self.nu["tris"]
        garder = ~cache[t].all(1)
        return garder

    def exporter(self, nom, description):
        nu = self.nu
        garder = self.corps_visible()
        tris = nu["tris"][garder]
        loops = nu["tri_loops"][garder]
        # Un sommet par couple (sommet, UV) : les coutures d'UV sont séparées.
        cles = {}
        pv, uvv, wv, nv, f = [], [], [], [], []
        normales = _normales_sommets(nu["p"], nu["tris"])
        for tri, lp in zip(tris, loops):
            face = []
            for v, l in zip(tri, lp):
                uv = nu["uv_boucles"][l]
                cle = (int(v), round(float(uv[0]), 5), round(float(uv[1]), 5))
                if cle not in cles:
                    cles[cle] = len(pv)
                    pv.append(nu["p"][v])
                    nv.append(normales[v])
                    uvv.append((uv[0], 1.0 - uv[1]))
                    wv.append(nu["w"][v])
                face.append(cles[cle])
            f.append(face)
        corps = Piece("peau", "peau")
        corps.ajouter(np.array(pv), np.array(nv), np.array(uvv), np.array(wv), np.array(f, dtype=np.int64))
        surfaces = []
        for piece in [corps] + self.pieces:
            # Godot : triangles dans le sens horaire vu de face → on inverse l'ordre.
            os_i, os_w = _quatre_poids(piece.w)
            surfaces.append({
                "matiere": piece.matiere, "role": piece.role,
                "p": np.round(piece.p, 5).reshape(-1).tolist(),
                "n": np.round(piece.n, 4).reshape(-1).tolist(),
                "uv": np.round(piece.uv, 5).reshape(-1).tolist(),
                "os": os_i.reshape(-1).tolist(),
                "poids": np.round(os_w, 4).reshape(-1).tolist(),
                "f": piece.f[:, [0, 2, 1]].reshape(-1).tolist(),
            })
        os.makedirs(SORTIE, exist_ok=True)
        chemin = os.path.join(SORTIE, "%s_%s.json" % (nom, self.sexe))
        with open(chemin, "w", encoding="utf-8") as fic:
            json.dump({"nom": nom, "sexe": self.sexe, "description": description, "os": self.noms,
                       "surfaces": surfaces}, fic, separators=(",", ":"))
        nb = sum(len(s["p"]) // 3 for s in surfaces)
        print("  %s : %d surfaces, %d sommets, corps %d/%d faces visibles" % (
            os.path.basename(chemin), len(surfaces), nb, garder.sum(), len(garder)))
        self.pieces = []
        self.caches = []


def _normales_sommets(p, t):
    n = np.zeros_like(p)
    fn = np.cross(p[t[:, 1]] - p[t[:, 0]], p[t[:, 2]] - p[t[:, 0]])
    for k in range(3):
        np.add.at(n, t[:, k], fn)
    return n / np.maximum(1e-9, np.linalg.norm(n, axis=1, keepdims=True))


def _quatre_poids(w):
    idx = np.argsort(-w, axis=1)[:, :4]
    val = np.take_along_axis(w, idx, axis=1)
    val = np.clip(val, 0, None)
    val /= np.maximum(1e-9, val.sum(1, keepdims=True))
    return idx.astype(int), val


# ---------------------------------------------------------------------------
# Les habits
# ---------------------------------------------------------------------------
def lisse(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def suivre(at, s, bas):
    """Part des poids « proches » (jambes) pour un point de jupe à la hauteur s :
    1 au-dessus des hanches (le tissu suit le tronc), ~0,3 à l'entrejambe (surtout les
    hanches, pour ne pas se déchirer entre les jambes), puis `bas` aux chevilles."""
    s = np.asarray(s)
    haut = lisse(at.y_entrejambe, at.y_hanches, s)
    bas_ = 0.45 + (bas - 0.45) * np.clip((at.y_entrejambe - s) / max(0.2, at.y_entrejambe - at.y_cheville), 0, 1)
    return np.where(s > at.y_entrejambe, 0.45 + 0.55 * haut, bas_)


def plis(theta, nombre, graine, irregulier=0.35):
    r = np.random.default_rng(graine)
    phase = r.uniform(0, 2 * np.pi, 3)
    return (np.sin(theta * nombre + phase[0]) + irregulier * np.sin(theta * (nombre * 0.5 + 1) + phase[1])
            + 0.5 * irregulier * np.sin(theta * (nombre * 1.7) + phase[2])) / (1 + 1.5 * irregulier)


class Patron:
    """Recettes : assemble les pièces d'un habit sur un Atelier."""

    def __init__(self, at: Atelier):
        self.at = at

    # Robe / tunique d'une seule pièce, du cou (ou de la poitrine) à l'ourlet.
    def robe(self, ourlet, haut="cou", matiere="lin", role="principal", aisance=0.012, evase=0.10, nb_plis=16,
             amplitude_plis=0.010, ceinture=None, blousant=0.0, effrange=0.0, une_epaule=None, bretelles=False,
             graine=1, colonnes=80, lignes=56, col_v=0.0):
        at = self.at
        G = at.gaine_tronc()
        theta = np.linspace(0, 2 * np.pi, colonnes, endpoint=False)
        y_haut = np.full(colonnes, at.y_cou + 0.005)
        if haut == "poitrine":
            y_haut[:] = at.y_poitrine + 0.05
        if une_epaule == "gauche":
            # Exomis : attachée sur l'épaule gauche, l'épaule et le pectoral droits restent nus.
            f = lisse(-0.55, 0.35, np.sin(theta))  # 0 à droite, 1 à gauche
            bas_ = at.y_poitrine - 0.04
            y_haut = bas_ + (at.y_cou + 0.005 - bas_) * f
        if bretelles:
            bande = np.zeros(colonnes)
            for centre in (0.42, np.pi - 0.42, np.pi + 0.42, 2 * np.pi - 0.42):
                d = np.angle(np.exp(1j * (theta - centre)))
                bande = np.maximum(bande, 1 - lisse(0.09, 0.16, np.abs(d)))
            y_haut = at.y_poitrine - 0.01 + (at.y_cou + 0.005 - (at.y_poitrine - 0.01)) * bande
        if col_v > 0:
            # Encolure en V devant.
            y_haut = y_haut - col_v * np.exp(-(np.angle(np.exp(1j * theta)) / 0.38) ** 2)
        r = np.random.default_rng(graine)
        bruit_ourlet = np.zeros(colonnes)
        if effrange > 0:
            k = np.arange(colonnes)
            bruit_ourlet = effrange * (0.6 * np.sin(k * 0.9 + r.uniform(0, 6)) + 0.4 * r.uniform(-1, 1, colonnes))
        y_bas = ourlet + bruit_ourlet + 0.01 * np.cos(theta)  # un peu plus bas devant
        y_ceint = ceinture if ceinture is not None else None
        hanches = at.y_hanches

        def ais(s, th):
            a = np.full(s.shape, aisance)
            # Évasement sous les hanches (jupe).
            a += evase * np.clip((hanches - s) / max(0.3, hanches - at.y_cheville), 0, 1.4) ** 1.2 * (hanches - at.y_cheville)
            # Plis verticaux, plus marqués vers le bas.
            depuis = y_ceint if y_ceint is not None else at.y_poitrine
            prof = np.clip((depuis - s) / 0.5, 0, 1) ** 0.8
            a += amplitude_plis * prof * (plis(th, nb_plis, graine) * 0.5 + 0.5)
            # Petits plis du haut qui partent des épaules.
            a += 0.003 * np.clip((s - at.y_poitrine) / 0.2, 0, 1) * (plis(th, 9, graine + 5) * 0.5 + 0.5)
            if y_ceint is not None:
                # Serré à la ceinture, blousant juste au-dessus (kolpos).
                serre = np.exp(-((s - y_ceint) / 0.025) ** 2)
                a = a * (1 - 0.8 * serre) + 0.002 * serre
                a += blousant * np.exp(-((s - (y_ceint + 0.045)) / 0.03) ** 2) * (0.7 + 0.3 * (plis(th, 11, graine + 2) * 0.5 + 0.5))
            return a

        def jambes(s):
            return suivre(at, s, 0.85)

        piece, P, W = at.tube(G, y_bas, y_haut, ais, matiere, role, lignes=lignes, theta=theta, suivre_jambes=jambes,
                              uv_mul=1.0)
        return piece, P, W, y_bas, y_haut, ais

    def ceinture(self, y, matiere="corde", role="ceinture", rayon=0.007, aplati=1.0, au_dessus=0.0, segments=8):
        at = self.at
        G, arbre, poids = at.gaine_tronc()
        theta = np.linspace(0, 2 * np.pi, 64, endpoint=False)
        s = np.full(64, y)
        r = G.rayon(s, theta) + 0.006 + au_dessus
        P = G.point(s, theta, r)
        W = at._poids_proches(arbre, poids, P)
        return at.cordon(P, W, rayon, matiere, role, ferme=True, aplati=aplati, segments=segments)

    def ourlet_cordon(self, P_ligne, W_ligne, rayon, matiere, role, aplati=0.6):
        return self.at.cordon(P_ligne, W_ligne, rayon, matiere, role, ferme=True, aplati=aplati)

    def manche(self, cote, longueur, matiere="lin", role="principal", aisance=0.012, evase=0.015, tombe=0.035,
               nb_plis=6, effrange=0.0, graine=3):
        """Manche (ou pan) autour du bras, depuis l'épaule ; longueur en m le long du bras.
        tombe : le tissu pend sous le bras (gravité), surtout vers le bout de la manche."""
        at = self.at
        G = at.gaine_membre(cote, "bras")
        colonnes = 40
        theta = np.linspace(0, 2 * np.pi, colonnes, endpoint=False)
        r = np.random.default_rng(graine)
        fin = np.full(colonnes, longueur) + effrange * r.uniform(-1, 1, colonnes)

        def ais(s, th, G=G[0]):
            _, e1, e2, _ = G.repere(s)
            bas = -(np.cos(th) * e1[..., 1] + np.sin(th) * e2[..., 1])
            t = np.clip(s / max(0.05, longueur), 0, 1)
            # Près de l'épaule, un peu plus d'ampleur pour bien couvrir le deltoïde.
            racine = 0.022 * (1 - lisse(0.06, 0.16, s))
            return (aisance + racine + evase * t + tombe * t ** 1.5 * np.clip(bas, 0, 1) ** 1.5
                    + 0.005 * (plis(th, nb_plis, graine) * 0.5 + 0.5))

        def poids(P, S, G=G):
            # À la racine de la manche, le tissu suit aussi l'épaule et le tronc (sinon il
            # se soulève au-dessus de l'épaule quand le bras descend).
            tout = at._poids_proches(at.arbre_tout, at.pts_w, P, k=10)
            bras = at._poids_proches(G[1], G[2], P)
            t = lisse(0.0, 0.14, S)[:, None]
            return tout * (1 - t) + bras * t

        return at.tube(G, np.zeros(colonnes), fin, ais, matiere, role, lignes=16, theta=theta, marge_cache=0.06,
                       poids_fn=poids)

    def jambiere(self, cote, s_debut, s_fin, matiere, role, aisance=0.012, graine=4):
        at = self.at
        G = at.gaine_membre(cote, "jambe")

        def ais(s, th):
            return aisance + 0.004 * (plis(th, 7, graine) * 0.5 + 0.5)
        return at.tube(G, s_debut, s_fin, ais, matiere, role, lignes=20, colonnes=36, marge_cache=0.02)

    def pieds(self, matiere, role, hauteur=0.11, ecart=0.006, sandale=False):
        at = self.at
        p, w = at.nu["p"], at.nu["w"]
        pied = sum(w[:, at.ib[n]] for n in ("mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase",
                                             "mixamorig_RightToeBase", "mixamorig_LeftToe_End", "mixamorig_RightToe_End")
                   if n in at.ib)
        masque = (p[:, 1] < at.y_sol + hauteur) & (pied + w[:, at.ib["mixamorig_LeftLeg"]] + w[:, at.ib["mixamorig_RightLeg"]] > 0.3)
        if sandale:
            # Semelle + lanières : bandes à certaines hauteurs seulement.
            h = p[:, 1] - at.y_sol
            masque &= (h < 0.018) | ((h > 0.045) & (h < 0.06)) | ((h > 0.085) & (h < 0.1))
            return at.coque(masque, ecart, matiere, role, lisser=1, aplatir_sol=at.y_sol - 0.008, cacher=False)
        return at.coque(masque, ecart, matiere, role, lisser=2, aplatir_sol=at.y_sol - 0.006)

    def bord(self, P, W, s_index, rayon, matiere, role, aplati=0.55):
        """Bourrelet (fourrure, bordure) le long d'une ligne de la grille d'un tube."""
        ligne = P[s_index]
        poids = W.reshape(P.shape[0], P.shape[1] + 1, -1)[s_index, :-1]
        return self.at.cordon(ligne, poids, rayon, matiere, role, ferme=True, aplati=aplati)


# ---------------------------------------------------------------------------
# Catalogue
# ---------------------------------------------------------------------------
def chiton_court(at: Atelier, pa: Patron, exomis=False):
    yc = at.y_taille
    piece, P, W, *_ = pa.robe(at.y_genou + 0.06, ceinture=yc, blousant=0.018, nb_plis=18, amplitude_plis=0.012,
                              evase=0.10, une_epaule="gauche" if exomis else None, graine=11)
    if not exomis:
        pa.manche("g", 0.13)
        pa.manche("d", 0.13)
    else:
        pa.manche("g", 0.10)
    pa.ceinture(yc, rayon=0.006)


def chiton_long(at: Atelier, pa: Patron, himation=True):
    yc = at.y_taille
    pa.robe(at.y_sol + 0.03, ceinture=yc, blousant=0.014, nb_plis=22, amplitude_plis=0.014, evase=0.06, graine=12)
    pa.manche("g", 0.16)
    pa.manche("d", 0.16)
    pa.ceinture(yc, rayon=0.006)
    if himation:
        himation_drape(at, pa)


def himation_drape(at: Atelier, pa: Patron, bas=None, dessous=0.0):
    """Manteau drapé : passe sur l'épaule gauche, sous le bras droit, descend aux mollets."""
    G = at.gaine_tronc()
    colonnes = 80
    theta = np.linspace(0, 2 * np.pi, colonnes, endpoint=False)
    gauche = np.sin(theta)  # +1 gauche
    haut = at.y_poitrine - 0.08 + (at.y_cou + 0.01 - (at.y_poitrine - 0.08)) * lisse(-0.1, 0.75, gauche)
    if bas is None:
        bas = at.y_genou - 0.14
    y_bas = bas + 0.12 * lisse(-0.6, 0.9, gauche) + 0.02 * np.cos(theta * 3)

    def ais(s, th):
        a = 0.032 + dessous + 0.07 * np.clip((at.y_hanches - s) / 0.5, 0, 1)
        a += 0.016 * (plis(th, 9, 21, 0.6) * 0.5 + 0.5) * np.clip((at.y_poitrine - s) / 0.3, 0.2, 1)
        return a

    def jambes(s):
        return suivre(at, s, 0.7)

    piece, P, W = at.tube(G, y_bas, haut, ais, "laine", "drape", lignes=46, theta=theta, suivre_jambes=jambes,
                          marge_cache=0.04)
    # Le bord roulé du drapé, en écharpe sur la poitrine.
    pa.bord(P, W, -1, 0.016, "laine", "drape", aplati=0.6)
    pa.manche("g", 0.24, matiere="laine", role="drape", nb_plis=5)


def peplos(at: Atelier, pa: Patron, himation=False):
    yc = at.y_taille + 0.01
    pa.robe(at.y_sol + 0.02, ceinture=yc, blousant=0.01, nb_plis=24, amplitude_plis=0.014, evase=0.07, graine=13)
    # Le rabat (apoptygma) : deuxième épaisseur du cou jusqu'aux hanches.
    G = at.gaine_tronc()
    theta = np.linspace(0, 2 * np.pi, 80, endpoint=False)

    def ais(s, th):
        return 0.026 + 0.03 * np.clip((at.y_taille - s) / 0.2, 0, 1) + 0.008 * (plis(th, 14, 31) * 0.5 + 0.5)
    at.tube(G, at.y_hanches - 0.06 + 0.015 * np.cos(theta * 2), at.y_cou + 0.008, ais, "lin", "principal", lignes=30,
            theta=theta, cacher=False)
    pa.manche("g", 0.12)
    pa.manche("d", 0.12)
    pa.ceinture(yc, rayon=0.006, au_dessus=0.03)
    if himation:
        himation_drape(at, pa, bas=at.y_genou - 0.2, dessous=0.035)


def scythe(at: Atelier, pa: Patron):
    """Archer scythe : tunique à manches longues, pantalon, bonnet."""
    yc = at.y_taille
    pa.robe(at.y_hanches - 0.2, ceinture=yc, blousant=0.008, nb_plis=10, amplitude_plis=0.006, evase=0.09,
            aisance=0.03, matiere="laine", graine=14)
    for c in ("g", "d"):
        G = at.gaine_membre(c, "bras")[0]
        pa.manche(c, G.longueur - 0.04, matiere="laine", nb_plis=4)
        J = at.gaine_membre(c, "jambe")[0]
        pa.jambiere(c, 0.07, J.longueur - 0.02, "laine", "drape", aisance=0.016)
    pa.ceinture(yc, matiere="cuir", rayon=0.012, aplati=0.35)
    pa.pieds("cuir", "chaussures")


def shendyt(at: Atelier, pa: Patron, longueur="genou"):
    """Pagne de lin égyptien (torse nu), plissé, ceinture de tissu."""
    yc = at.y_hanches + 0.06
    ourlet = {"court": at.y_entrejambe - 0.12, "genou": at.y_genou + 0.04, "long": at.y_genou - 0.16}[longueur]
    G = at.gaine_tronc()
    theta = np.linspace(0, 2 * np.pi, 96, endpoint=False)
    devant = np.cos(theta)
    y_bas = ourlet + 0.03 * lisse(0.3, 1.0, devant)  # le pan de devant remonte un peu (rabat croisé)

    def ais(s, th):
        a = 0.006 + 0.10 * np.clip((yc - s) / max(0.2, yc - at.y_genou), 0, 1.3) ** 1.3 * 0.5
        a += 0.004 * (np.sin(th * 46) * 0.5 + 0.5) * np.clip((yc - s) / 0.1, 0, 1)  # plissé fin
        return a

    def jambes(s):
        return suivre(at, s, 0.8)
    at.tube(G, y_bas, yc + 0.015, ais, "lin", "principal", lignes=30, theta=theta, suivre_jambes=jambes)
    pa.ceinture(yc, matiere="lin", role="ceinture", rayon=0.016, aplati=0.3)


def kalasiris(at: Atelier, pa: Patron):
    """Robe-fourreau de lin égyptienne, encolure en V, jusqu'aux chevilles."""
    pa.robe(at.y_sol + 0.06, aisance=0.006, evase=0.035, nb_plis=26, amplitude_plis=0.005, graine=15, col_v=0.09)
    pa.ceinture(at.y_taille - 0.01, matiere="lin", role="ceinture", rayon=0.012, aplati=0.35)


def tunique_nomade(at: Atelier, pa: Patron):
    """Robe longue de laine à manches (nomades du désert)."""
    yc = at.y_taille
    pa.robe(at.y_sol + 0.06, ceinture=yc, blousant=0.012, nb_plis=14, amplitude_plis=0.012, evase=0.07,
            matiere="laine", graine=16)
    for c in ("g", "d"):
        G = at.gaine_membre(c, "bras")[0]
        pa.manche(c, G.longueur * 0.62, matiere="laine", nb_plis=5)
    pa.ceinture(yc, matiere="laine", role="ceinture", rayon=0.014, aplati=0.4)
    pa.pieds("cuir", "chaussures", sandale=True)


def peaux(at: Atelier, pa: Patron, femme=False):
    """Préhistoire : tunique de peau à bord effrangé, liseré de fourrure, jambières et mocassins."""
    ourlet = at.y_genou - 0.08 if femme else at.y_genou + 0.10
    piece, P, W, *_ = pa.robe(ourlet, matiere="cuir", aisance=0.014, evase=0.07, nb_plis=7, amplitude_plis=0.010,
                              ceinture=at.y_taille + 0.02, blousant=0.008, effrange=0.035,
                              une_epaule=None if femme else "gauche", graine=17)
    pa.bord(P, W, -1, 0.02, "fourrure", "fourrure", aplati=0.7)
    pa.ceinture(at.y_taille + 0.02, matiere="corde", role="ceinture", rayon=0.008)
    if femme:
        pa.manche("g", 0.12, matiere="cuir", effrange=0.02)
        pa.manche("d", 0.12, matiere="cuir", effrange=0.02)
    else:
        pa.manche("g", 0.10, matiere="fourrure", role="fourrure", effrange=0.02)
    for c in ("g", "d"):
        J = at.gaine_membre(c, "jambe")[0]
        genou = np.linalg.norm(at.os["mixamorig_LeftLeg"] - at.os["mixamorig_LeftUpLeg"])
        pa.jambiere(c, genou + 0.08, J.longueur - 0.03, "fourrure", "fourrure", aisance=0.02)
    pa.pieds("cuir", "chaussures", hauteur=0.10, ecart=0.012)


CATALOGUE = {
    # nom : (fonction, sexes, description)
    "chiton_court": (lambda at, pa: chiton_court(at, pa), ("homme",), "Grèce : chiton court ceinturé (travailleurs, marins)"),
    "exomis": (lambda at, pa: chiton_court(at, pa, exomis=True), ("homme",), "Grèce : exomis, tunique attachée sur une épaule (dockers, artisans)"),
    "chiton_himation": (lambda at, pa: chiton_long(at, pa, True), ("homme",), "Grèce : chiton long et manteau drapé (citoyens, vieillards)"),
    "peplos": (lambda at, pa: peplos(at, pa), ("femme",), "Grèce : péplos à rabat, ceinturé"),
    "peplos_himation": (lambda at, pa: peplos(at, pa, True), ("femme",), "Grèce : péplos et manteau drapé"),
    "scythe": (scythe, ("homme",), "Grèce : archer scythe (tunique à manches, pantalon)"),
    "shendyt": (lambda at, pa: shendyt(at, pa, "genou"), ("homme",), "Égypte : pagne de lin plissé"),
    "shendyt_court": (lambda at, pa: shendyt(at, pa, "court"), ("homme",), "Égypte : pagne court des ouvriers"),
    "shendyt_long": (lambda at, pa: shendyt(at, pa, "long"), ("homme",), "Égypte : pagne long des scribes"),
    "kalasiris": (kalasiris, ("femme",), "Égypte : robe-fourreau à bretelles"),
    "robe_nomade": (tunique_nomade, ("homme", "femme"), "Désert : robe de laine à manches"),
    "peaux": (lambda at, pa: peaux(at, pa, False), ("homme",), "Préhistoire : tunique de peau sur une épaule, fourrure"),
    "peaux_femme": (lambda at, pa: peaux(at, pa, True), ("femme",), "Préhistoire : robe de peau, fourrure"),
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    voulus = [a for a in args if a in CATALOGUE] or list(CATALOGUE)
    for sexe in ("homme", "femme"):
        a_faire = [n for n in voulus if sexe in CATALOGUE[n][1]]
        if not a_faire:
            continue
        at = Atelier(sexe)
        pa = Patron(at)
        for nom in a_faire:
            fn, _, description = CATALOGUE[nom]
            fn(at, pa)
            at.exporter(nom, description)


if __name__ == "__main__":
    main()
