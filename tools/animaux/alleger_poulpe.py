"""Allège le poulpe Sketchfab (Tripo, ~2 millions de triangles) pour le jeu.

Usage (Blender 5.2, sans interface) :
  blender -b --factory-startup --python tools/animaux/alleger_poulpe.py -- <scene.gltf> <poulpe.glb> [triangles=40000] [texture_max=2048]

Étapes : import glTF, fusion des 23 morceaux en un seul objet, transformations
appliquées, soudure des sommets en double sur les coutures, Decimate (Collapse)
jusqu'à ~40 000 triangles, un seul jeu d'UV (Godot n'en lit qu'un pour les
textures), textures réduites à 2048 px, export GLB (textures intégrées, +Y en
haut). Le poulpe regarde vers +X.
"""
import bpy
import sys

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
cible = int(args[2]) if len(args) > 2 else 40000
tex_max = int(args[3]) if len(args) > 3 else 2048

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
# Transformations appliquées aux morceaux (et à leurs parents vides), puis fusion
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
poulpe = bpy.context.view_layer.objects.active
poulpe.name = "poulpe"
poulpe.data.name = "poulpe"

# Supprime les vides restants (nœuds glTF)
for o in list(bpy.context.scene.objects):
    if o.type != 'MESH':
        bpy.data.objects.remove(o)

# Soudure des sommets en double (le modèle est découpé en morceaux)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=1e-5)
bpy.ops.object.mode_set(mode='OBJECT')


def triangles(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


avant = triangles(poulpe)
mod = poulpe.modifiers.new("Decimate", 'DECIMATE')
mod.decimate_type = 'COLLAPSE'
mod.ratio = min(1.0, cible / avant)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
apres = triangles(poulpe)
print(f"Triangles : {avant} -> {apres}")

# Le modèle d'origine a 3 jeux d'UV identiques et sa normal map lit le 2e
# (texCoord 1), ce que Godot ne gère pas : on ne garde que le premier.
uvs = poulpe.data.uv_layers
while len(uvs) > 1:
    uvs.remove(uvs[len(uvs) - 1])
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    for n in list(mat.node_tree.nodes):
        if n.type == 'UVMAP':
            mat.node_tree.nodes.remove(n)
        elif n.type == 'NORMAL_MAP':
            n.uv_map = ""

# Textures réduites (même format)
for img in bpy.data.images:
    w, h = img.size
    if max(w, h) > tex_max:
        f = tex_max / max(w, h)
        img.scale(int(w * f), int(h * f))
        img.pack()
        print(f"Texture {img.name} : {w}x{h} -> {img.size[0]}x{img.size[1]}")

bpy.ops.export_scene.gltf(
    filepath=dst,
    export_format='GLB',
    export_yup=True,
    export_image_format='AUTO',
    export_apply=True,
    export_animations=False,
)
print("Exporté :", dst)
