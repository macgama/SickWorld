"""Textures de tissus d'époque pour les habits des figurants (lin, laine, fourrure).

Fabriquées par calcul (bruit périodique, tissage) : aucune image téléchargée, donc
aucune licence à suivre. Les textures sont en niveaux de gris clairs : le jeu les
teinte avec la couleur de l'habit. Elles se répètent sans couture (tuilables).

Lancement (Python avec numpy + Pillow) :
    python tools/personnages/textures_tissus.py
Sortie : game/assets/personnages/vetements/textures/<tissu>_albedo.webp et _normal.webp
(WebP : hors Git LFS, le cloud peut les pousser).
"""
import os
import numpy as np
from PIL import Image

N = 512
SORTIE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets",
                      "personnages", "vetements", "textures")
rng = np.random.default_rng(1438)


def bruit(echelle_px, n=N, anisotropie=(1.0, 1.0)):
    """Bruit périodique (filtré dans l'espace de Fourier), moyenne 0, écart-type 1."""
    f = np.fft.fft2(rng.standard_normal((n, n)))
    ky = np.fft.fftfreq(n)[:, None] * anisotropie[1]
    kx = np.fft.fftfreq(n)[None, :] * anisotropie[0]
    k = np.sqrt(kx * kx + ky * ky)
    filtre = np.exp(-(k * echelle_px) ** 2 * 4.0)
    b = np.real(np.fft.ifft2(f * filtre))
    return (b - b.mean()) / (b.std() + 1e-9)


def normale(hauteur, force):
    gx = (np.roll(hauteur, -1, 1) - np.roll(hauteur, 1, 1)) * 0.5 * force
    gy = (np.roll(hauteur, -1, 0) - np.roll(hauteur, 1, 0)) * 0.5 * force
    n = np.dstack([-gx, gy, np.ones_like(gx)])  # convention OpenGL (Godot)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def tissage(fils, sergé=False):
    """Hauteur d'un tissage : fils de chaîne (verticaux) et de trame (horizontaux)."""
    y, x = np.mgrid[0:N, 0:N] / N * fils
    iy, ix = np.floor(y).astype(int), np.floor(x).astype(int)
    fy, fx = y - iy, x - ix
    # Irrégularités du fil (« flammes » du lin) : épaisseur qui varie le long du fil.
    epais_c = 0.75 + 0.25 * bruit(18, anisotropie=(8.0, 0.3))
    epais_t = 0.75 + 0.25 * bruit(18, anisotropie=(0.3, 8.0))
    profil_c = np.clip(1.0 - np.abs(fx - 0.5) * 2.0 / np.clip(epais_c, 0.3, 1.2), 0, 1) ** 0.6
    profil_t = np.clip(1.0 - np.abs(fy - 0.5) * 2.0 / np.clip(epais_t, 0.3, 1.2), 0, 1) ** 0.6
    if sergé:
        dessus_chaine = ((ix + iy) % 4) < 2
    else:
        dessus_chaine = ((ix + iy) % 2) == 0
    # Le fil du dessus est bombé le long de sa longueur.
    bosse_c = np.sin(fy * np.pi)
    bosse_t = np.sin(fx * np.pi)
    h = np.where(dessus_chaine, profil_c * (0.6 + 0.4 * bosse_c), profil_t * (0.6 + 0.4 * bosse_t))
    h = np.maximum(h, np.where(dessus_chaine, profil_t * 0.35, profil_c * 0.35))
    return h, epais_c, epais_t


def enregistrer(nom, albedo, norm):
    os.makedirs(SORTIE, exist_ok=True)
    a = (np.clip(albedo, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(a, "L").convert("RGB").save(os.path.join(SORTIE, nom + "_albedo.webp"), quality=90)
    Image.fromarray(norm, "RGB").save(os.path.join(SORTIE, nom + "_normal.webp"), quality=92)
    print("écrit", nom)


def lin():
    # 64 fils par tuile ; la tuile couvre 12 cm dans le jeu → fil ≈ 2 mm (lin grossier, visible de près).
    h, ec, et = tissage(64)
    taches = bruit(60) * 0.025 + bruit(8) * 0.02
    albedo = 0.84 + 0.045 * h + 0.03 * (ec - 1.0) + taches
    enregistrer("lin", albedo, normale(h + 0.15 * bruit(3), 1.1))


def laine():
    h, ec, et = tissage(40, sergé=True)
    duvet = bruit(1.5) * 0.25 + bruit(5) * 0.15
    h2 = h * 0.8 + duvet * 0.25
    albedo = 0.8 + 0.06 * h + 0.03 * duvet + bruit(70) * 0.03
    enregistrer("laine", albedo, normale(h2, 1.0))


def fourrure():
    # Poils : traits courts orientés vers le bas (v croissant), un peu ondulés.
    h = np.zeros((N, N))
    couleur = np.zeros((N, N))
    for _ in range(26000):
        x0, y0 = rng.uniform(0, N, 2)
        longueur = rng.uniform(10, 26)
        angle = np.pi / 2 + rng.normal(0, 0.22)
        t = np.linspace(0, 1, int(longueur))
        xs = (x0 + np.cos(angle) * longueur * t + np.sin(t * 3) * 1.5).astype(int) % N
        ys = (y0 + np.sin(angle) * longueur * t).astype(int) % N
        clair = rng.uniform(0.6, 1.0)
        h[ys, xs] = np.maximum(h[ys, xs], t * 0.7 + 0.3)
        couleur[ys, xs] = np.maximum(couleur[ys, xs], clair * (0.55 + 0.45 * t))
    flou = lambda img: (img + np.roll(img, 1, 1) + np.roll(img, -1, 1)) / 3.0
    h = flou(h)
    couleur = flou(couleur)
    plaques = bruit(40) * 0.08
    albedo = 0.35 + 0.55 * couleur + plaques
    enregistrer("fourrure", albedo, normale(h * 1.0 + bruit(2) * 0.1, 3.0))


if __name__ == "__main__":
    lin()
    laine()
    fourrure()
