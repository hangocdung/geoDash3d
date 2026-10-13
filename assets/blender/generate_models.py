"""Generate GeoDash3D decor models with Blender (bpy) and export them as .glb.

  blender -b --factory-startup -P assets/blender/generate_models.py -- --out assets/models [--preview DIR]

Material naming contract (read by src/presentation/meshes/neon_model.gd):
  "Body"     dark solid surface          → dark metallic material in Godot
  "Glow"     primary neon light strips   → emissive neon shader (color set per use)
  "GlowAlt"  secondary accent lights     → emissive neon shader (accent color)
Axes: Blender Z-up is exported as Godot Y-up. Models are built so that in Godot the track direction is +X.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, emission_strength=0.0):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.6
    bsdf.inputs["Roughness"].default_value = 0.3
    if emission_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def body():
    return material("Body", (0.03, 0.03, 0.07))


def glow():
    return material("Glow", (0.3, 0.9, 1.0), 4.0)


def glow_alt():
    return material("GlowAlt", (1.0, 0.3, 0.85), 4.0)


def new_object(name, bm, materials):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for mat in materials:
        obj.data.materials.append(mat)
    return obj


def add_box(bm, corners, material_index):
    """corners: 8 vertices (4 front, 4 back) of a convex hexahedron, same winding front and back."""
    verts = [bm.verts.new(c) for c in corners]
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    for f in faces:
        face = bm.faces.new([verts[i] for i in f])
        face.material_index = material_index
    return verts


def add_torus(bm, major, minor, major_segments, minor_segments, material_index, matrix=Matrix()):
    rings = []
    for i in range(major_segments):
        u = 2 * math.pi * i / major_segments
        ring = []
        for j in range(minor_segments):
            v = 2 * math.pi * j / minor_segments
            p = Vector(((major + minor * math.cos(v)) * math.cos(u), (major + minor * math.cos(v)) * math.sin(u),
                        minor * math.sin(v)))
            ring.append(bm.verts.new(matrix @ p))
        rings.append(ring)
    for i in range(major_segments):
        for j in range(minor_segments):
            a, b = rings[i][j], rings[(i + 1) % major_segments][j]
            c, d = rings[(i + 1) % major_segments][(j + 1) % minor_segments], rings[i][(j + 1) % minor_segments]
            face = bm.faces.new((a, b, c, d))
            face.material_index = material_index


def portal_ring():
    """Segmented octagon-ish ring the player runs through. Built in Blender XY, turned to face +X."""
    bm = bmesh.new()
    inner, outer, half_depth, segments, gap = 4.6, 5.3, 0.3, 12, math.radians(3.0)
    for i in range(segments):
        a0 = 2 * math.pi * i / segments + gap / 2
        a1 = 2 * math.pi * (i + 1) / segments - gap / 2
        pts = []
        for z in (half_depth, -half_depth):
            pts += [Vector((r * math.cos(a), r * math.sin(a), z)) for r, a in ((inner, a0), (outer, a0), (outer, a1), (inner, a1))]
        add_box(bm, pts, 0)
        # Glowing accent cap on every third segment, sitting on the outer rim.
        if i % 3 == 0:
            mid = (a0 + a1) / 2
            span = (a1 - a0) * 0.25
            cap = []
            for z in (half_depth * 0.6, -half_depth * 0.6):
                cap += [Vector((r * math.cos(a), r * math.sin(a), z)) for r, a in
                        ((outer, mid - span), (outer + 0.25, mid - span), (outer + 0.25, mid + span), (outer, mid + span))]
            add_box(bm, cap, 2)
    for z in (half_depth + 0.02, -half_depth - 0.02):
        add_torus(bm, (inner + outer) / 2, 0.07, 96, 6, 1, Matrix.Translation((0, 0, z)))
    add_torus(bm, inner - 0.05, 0.05, 96, 6, 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = new_object("PortalRing", bm, [body(), glow(), glow_alt()])
    obj.matrix_world = Matrix.Rotation(math.radians(90), 4, "Y")
    return obj


def spiked_mace():
    """Spiked ball hanging from a chain. Origin = top of the chain (pivot for swinging)."""
    bm = bmesh.new()
    core_radius, spike_length, chain_links, link_step = 1.0, 0.85, 9, 0.34
    core = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=core_radius)
    for face in {f for v in core["verts"] for f in v.link_faces}:
        face.material_index = 0
    guide = bmesh.new()
    bmesh.ops.create_icosphere(guide, subdivisions=1, radius=1.0)
    guide.faces.ensure_lookup_table()
    for face in guide.faces:
        direction = face.calc_center_median().normalized()
        rotation = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
        placement = Matrix.Translation(direction * (core_radius + spike_length * 0.5 - 0.08)) @ rotation
        cone = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.2, radius2=0.0,
                                     depth=spike_length, matrix=placement)
        for f in {f for v in cone["verts"] for f in v.link_faces}:
            f.material_index = 0
    guide.free()
    add_torus(bm, core_radius + 0.03, 0.06, 64, 6, 1)  # glowing equator band
    eye = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.28,
                                     matrix=Matrix.Translation((0, -core_radius + 0.12, 0)))
    for face in {f for v in eye["verts"] for f in v.link_faces}:
        face.material_index = 2
    top = core_radius + 0.15
    for i in range(chain_links):
        z = top + i * link_step + 0.17
        turn = Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Rotation(math.radians(90 * (i % 2)), 4, "Y")
        add_torus(bm, 0.17, 0.045, 16, 6, 0, Matrix.Translation((0, 0, z)) @ turn)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    pivot = top + chain_links * link_step + 0.1
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -pivot))
    return new_object("SpikedMace", bm, [body(), glow(), glow_alt()])


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    print("EXPORTED", path, len(obj.data.vertices), "verts")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = argv[argv.index("--out") + 1] if "--out" in argv else "assets/models"
    os.makedirs(out_dir, exist_ok=True)
    for name, builder in (("portal_ring", portal_ring), ("spiked_mace", spiked_mace)):
        reset_scene()
        export(builder(), os.path.abspath(os.path.join(out_dir, name + ".glb")))


main()
