"""Generate GeoDash3D decor models with Blender (bpy) and export them as .glb.

  blender -b --factory-startup -P assets/blender/generate_models.py -- --out assets/models [--preview DIR]

Faces are modelled with three roles (material slots while building): "Body" dark solid surface, "Glow" primary
neon light strips, "GlowAlt" secondary accent lights. On export the roles are baked into the vertex color
(Body = black, Glow = red, GlowAlt = green) and every face gets the single material "Neon", so each model is
one draw call; src/presentation/meshes/neon_model.gd (neon_model.gdshader) turns the colors into the neon look.
Axes: Blender Z-up is exported as Godot Y-up. Models are built so that in Godot the track direction is +X
(Blender +Y ends up on Godot -Z, the background side). Obstacle models (GD3-104) use only Body + Glow so each
instance is a single draw call; their sizes mirror GameplayConfig.create_default() hitboxes.
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


ROLE_COLORS = {"Body": (0.0, 0.0, 0.0, 1.0), "Glow": (1.0, 0.0, 0.0, 1.0), "GlowAlt": (0.0, 1.0, 0.0, 1.0)}


def new_object(name, bm, materials):
    """`materials` lists the role of each material index used while building (Body / Glow / GlowAlt)."""
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    colors = mesh.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
    for polygon in mesh.polygons:
        role = materials[polygon.material_index].name
        for loop_index in polygon.loop_indices:
            colors.data[loop_index].color = ROLE_COLORS[role]
        polygon.material_index = 0
    mesh.color_attributes.active_color = colors
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material("Neon", (0.5, 0.5, 0.5)))
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


def add_prism(bm, radius, z0, z1, sides, material_index, center=(0.0, 0.0)):
    """Upright regular prism (hexagonal post when sides = 6)."""
    cx, cy = center
    ring = [(cx + radius * math.cos(2 * math.pi * i / sides), cy + radius * math.sin(2 * math.pi * i / sides))
            for i in range(sides)]
    bottom = [bm.verts.new((x, y, z0)) for x, y in ring]
    top = [bm.verts.new((x, y, z1)) for x, y in ring]
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((bottom[i], bottom[j], top[j], top[i])).material_index = material_index
    bm.faces.new(list(reversed(bottom))).material_index = material_index
    bm.faces.new(top).material_index = material_index


def add_cuboid(bm, center, size, material_index):
    cx, cy, cz = center
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    corners = [(cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz), (cx + hx, cy + hy, cz - hz),
               (cx - hx, cy + hy, cz - hz), (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
               (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz)]
    add_box(bm, [Vector(c) for c in corners], material_index)


def spiky_ball(bm, core_radius, spike_length, spike_radius, material_index, spike_material_index, matrix=Matrix()):
    core = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=core_radius, matrix=matrix)
    for face in {f for v in core["verts"] for f in v.link_faces}:
        face.material_index = material_index
    guide = bmesh.new()
    bmesh.ops.create_icosphere(guide, subdivisions=0, radius=1.0)
    for vert in guide.verts:
        direction = vert.co.normalized()
        rotation = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
        placement = matrix @ Matrix.Translation(direction * (core_radius + spike_length * 0.5 - 0.03)) @ rotation
        cone = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=5, radius1=spike_radius,
                                     radius2=0.0, depth=spike_length, matrix=placement)
        for f in {f for v in cone["verts"] for f in v.link_faces}:
            f.material_index = spike_material_index
    guide.free()


def add_laser_post(bm, y, height, lens_heights):
    """Hexagonal emitter post at lateral `y` with glowing lens rings (and cap) at the beam heights."""
    add_prism(bm, 0.13, 0.0, height, 6, 0, center=(0.0, y))
    add_prism(bm, 0.2, 0.0, 0.08, 6, 0, center=(0.0, y))
    add_prism(bm, 0.15, height, height + 0.07, 6, 1, center=(0.0, y))
    for lens in lens_heights:
        add_torus(bm, 0.135, 0.03, 12, 4, 1, Matrix.Translation((0, y, lens)))


def laser_fence():
    """Low laser fence across the whole road (3.6 wide): two emitter posts and two beams at 0.25 / 0.55, one
    mesh with Body + Glow (two draw calls). Origin on the road at the fence's center."""
    bm = bmesh.new()
    half, beams = 1.8, (0.25, 0.55)
    for y in (-half, half):
        add_laser_post(bm, y, 0.85, beams)
    for z in beams:
        add_cuboid(bm, (0, 0, z), (0.07, half * 2.0, 0.07), 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("LaserFence", bm, [body(), glow()])


def laser_wall():
    """Laser grid over two lanes (2 wide, 3.2 tall): end posts and five beams, one mesh with Body + Glow.
    Origin on the road at the grid's center."""
    bm = bmesh.new()
    half, height = 1.0, 3.2
    beams = [0.35 + i * (height - 0.55) / 4 for i in range(5)]
    for y in (-half, half):
        add_laser_post(bm, y, height, beams)
    for z in beams:
        add_cuboid(bm, (0, 0, z), (0.07, half * 2.0, 0.07), 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("LaserWall", bm, [body(), glow()])


PENDULUM_PIVOT = 4.2
PENDULUM_HALF_SPAN = 2.0


def pendulum_frame():
    """Gantry over the road (legs at both sides, beam on top, pivot hub in the middle). Origin on the road."""
    bm = bmesh.new()
    for side in (-1, 1):
        add_cuboid(bm, (0, side * PENDULUM_HALF_SPAN, PENDULUM_PIVOT / 2 + 0.15), (0.3, 0.3, PENDULUM_PIVOT + 0.3), 0)
        add_cuboid(bm, (0.16, side * PENDULUM_HALF_SPAN, PENDULUM_PIVOT / 2), (0.04, 0.12, PENDULUM_PIVOT - 0.4), 1)
    add_cuboid(bm, (0, 0, PENDULUM_PIVOT + 0.3), (0.34, PENDULUM_HALF_SPAN * 2 + 0.3, 0.3), 0)
    add_cuboid(bm, (0.18, 0, PENDULUM_PIVOT + 0.3), (0.04, PENDULUM_HALF_SPAN * 2 - 0.4, 0.08), 1)
    hub = Matrix.Translation((0, 0, PENDULUM_PIVOT)) @ Matrix.Rotation(math.radians(90), 4, "X")
    add_torus(bm, 0.22, 0.06, 16, 6, 1, hub)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("PendulumFrame", bm, [body(), glow()])


def pendulum_blade():
    """Arm and crescent axe swinging along the track (Blender XZ plane), all Glow (one draw call). Origin at the
    pivot; the cutting edge reaches 0.15 above the road when it hangs straight down."""
    bm = bmesh.new()
    reach = PENDULUM_PIVOT - 0.15
    radius = 0.7
    center_z = -(reach - radius)
    add_cuboid(bm, (0, 0, center_z / 2), (0.12, 0.1, -center_z), 0)
    segments = 10
    # Single material: the whole axe glows in the hazard color.
    half_depth = 0.07
    for i in range(segments):
        a0 = math.pi + math.pi * i / segments
        a1 = math.pi + math.pi * (i + 1) / segments
        for r_in, r_out, material_index in ((0.25, radius - 0.08, 0), (radius - 0.08, radius, 0)):
            pts = []
            for y in (half_depth, -half_depth):
                pts += [Vector((r * math.cos(a), y, center_z + r * math.sin(a))) for r, a in
                        ((r_in, a0), (r_out, a0), (r_out, a1), (r_in, a1))]
            add_box(bm, pts, material_index)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("PendulumBlade", bm, [glow()])


def spike_mine():
    """Floating spiked mine: dark core, glowing spikes and two glowing bands. Origin at its center, about 0.8
    across (scaled up in Godot, ObstacleModels.MINE_SCALE)."""
    bm = bmesh.new()
    spiky_ball(bm, 0.24, 0.22, 0.07, 0, 1)
    add_torus(bm, 0.25, 0.035, 24, 4, 1)
    add_torus(bm, 0.25, 0.035, 24, 4, 1, Matrix.Rotation(math.radians(90), 4, "X"))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("SpikeMine", bm, [body(), glow()])


def crusher():
    """Hydraulic press over the whole road: slab with teeth underneath and two piston rods going up.
    Origin at the tips of the teeth (placed at the ceiling hazard's bottom)."""
    bm = bmesh.new()
    length, width, slab, teeth = 4.8, 3.4, 0.55, 0.35
    add_cuboid(bm, (0, 0, teeth + slab / 2), (length, width, slab), 0)
    for side in (-1, 1):
        add_cuboid(bm, (0, side * (width / 2 + 0.01), teeth + slab / 2), (length - 0.3, 0.02, 0.12), 1)
    for x in (-length / 2 + 0.3, length / 2 - 0.3):
        add_cuboid(bm, (x, 0, teeth + slab / 2), (0.02, width - 0.3, 0.12), 1)
    columns, rows = 8, 3
    for ix in range(columns):
        for iy in range(rows):
            x = -length / 2 + (ix + 0.5) * length / columns
            y = -width / 2 + (iy + 0.5) * width / rows
            half = min(length / columns, width / rows) * 0.38
            apex = bm.verts.new((x, y, 0.0))
            quad = [bm.verts.new(c) for c in ((x - half, y - half, teeth), (x + half, y - half, teeth),
                                               (x + half, y + half, teeth), (x - half, y + half, teeth))]
            for k in range(4):
                bm.faces.new((apex, quad[(k + 1) % 4], quad[k])).material_index = 0
    for y in (-0.9, 0.9):
        add_prism(bm, 0.16, teeth + slab, teeth + slab + 6.0, 8, 0, center=(0.0, y))
        add_torus(bm, 0.2, 0.04, 12, 4, 1, Matrix.Translation((0, y, teeth + slab + 0.4)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("Crusher", bm, [body(), glow()])


def ring_gate():
    """Ring standing across the road, facing the track (Blender YZ plane), glowing rims front and back and
    eight glowing studs. Origin at the ring's center (placed 2.2 above the road)."""
    bm = bmesh.new()
    turn = Matrix.Rotation(math.radians(90), 4, "Y")
    add_torus(bm, 2.15, 0.17, 48, 8, 0, turn)
    for x in (0.17, -0.17):
        add_torus(bm, 2.15, 0.04, 48, 4, 1, Matrix.Translation((x, 0, 0)) @ turn)
    for i in range(8):
        angle = 2 * math.pi * i / 8
        add_cuboid(bm, (0, 2.42 * math.cos(angle), 2.42 * math.sin(angle)), (0.3, 0.22, 0.22), 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("RingGate", bm, [body(), glow()])


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_vertex_color="ACTIVE")
    print("EXPORTED", path, len(obj.data.vertices), "verts")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = argv[argv.index("--out") + 1] if "--out" in argv else "assets/models"
    os.makedirs(out_dir, exist_ok=True)
    builders = (("portal_ring", portal_ring), ("spiked_mace", spiked_mace), ("laser_fence", laser_fence),
                ("laser_wall", laser_wall),
                ("pendulum_frame", pendulum_frame), ("pendulum_blade", pendulum_blade), ("spike_mine", spike_mine),
                ("crusher", crusher), ("ring_gate", ring_gate))
    for name, builder in builders:
        reset_scene()
        export(builder(), os.path.abspath(os.path.join(out_dir, name + ".glb")))


main()
