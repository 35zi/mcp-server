"""Shoot an Animal: five small animals in the chunky beveled-block "voxel creature" style (Blender 5.x, headless).

  blender.exe --background --factory-startup --python small_animals_blocky.py -- <output folder>

Hard-edged beveled boxes, tapered wedges, 4-sided spikes, stepped limbs, flat saturated colours, big boxy heads,
square eyes with catch-lights. 1 Blender unit = 1 Roblox stud. Every animal: feet on z = 0, centred on x = 0 / y = 0,
FACING +Y, Z up (the FBX exporter turns that into Roblox's -Z-forward / Y-up).
Outputs per animal: <Name>.fbx, <Name>.obj/.mtl (colours = materials AND a vertex colour attribute "Col"),
Small_Animals_Blocky.blend and Cycles preview renders (one per animal + a lineup).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv
out_dir = argv[argv.index("--") + 1] if "--" in argv else os.path.join(os.path.dirname(__file__), "out_blocky")
os.makedirs(out_dir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


class Builder:
    def __init__(self, name, palette):
        self.name = name
        self.palette = palette
        self.order = list(palette.keys())
        self.main = bmesh.new()

    def _append(self, tmp, mat):
        """Add a finished temp bmesh (all faces get material `mat`) to the animal."""
        idx = self.order.index(mat)
        for f in tmp.faces:
            f.material_index = idx
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.main.from_mesh(me)
        bpy.data.meshes.remove(me)

    def box(self, mat, centre, size, rot=(0, 0, 0), bevel=0.1, taper=None):
        """Beveled box. size = (x, y, z); rot in degrees; taper = (tx, ty): scale of the TOP face (wedge/chamfered block)."""
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        if taper:
            for v in tmp.verts:
                if v.co.z > 0:
                    v.co.x *= taper[0]
                    v.co.y *= taper[1]
        m = (Matrix.Translation(centre) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
             @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        if bevel > 0:
            lim = min(size) * 0.45
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bevel, lim), offset_type="OFFSET", segments=1,
                            profile=0.5, affect="EDGES")
        self._append(tmp, mat)

    def bar(self, mat, a, b, thick, bevel=0.06, thick2=None):
        """Box running from point a to point b (tails, whiskers, limbs)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        q = d.normalized().to_track_quat("Y", "Z")
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        m = (Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
             @ Matrix.Diagonal((thick, L, thick2 or thick, 1.0)))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        if bevel > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bevel, thick * 0.4), offset_type="OFFSET", segments=1,
                            profile=0.5, affect="EDGES")
        self._append(tmp, mat)

    def spike(self, mat, base, direction, length, radius):
        """Square pyramid (blocky spine): axis-aligned square base, pointing along `direction`."""
        d = Vector(direction).normalized()
        q = d.to_track_quat("Z", "Y")
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=4, radius1=radius, radius2=0.0, depth=length,
                              matrix=Matrix.Translation(Vector(base) + d * (length / 2)) @ q.to_matrix().to_4x4()
                              @ Euler((0, 0, math.radians(45)), "XYZ").to_matrix().to_4x4())
        self._append(tmp, mat)

    def eye(self, x, y, z, s=0.55, white=True):
        """Square eye on the face plane y: white block, black pupil, catch-light. x is the sideways offset (both sides)."""
        for sx in (-1, 1):
            if white:
                self.box("white", (x * sx, y, z), (s * 1.15, 0.18, s * 1.25), bevel=0.04)
            self.box("black", (x * sx, y + 0.1, z - s * 0.05), (s * 0.7, 0.2, s * 0.95), bevel=0.04)
            self.box("white", (x * sx * 0.92, y + 0.22, z + s * 0.28), (s * 0.24, 0.12, s * 0.24), bevel=0.0)

    def finish(self):
        bm = self.main
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for key, (hexc, rough) in self.palette.items():
            m = bpy.data.materials.new("%s_%s" % (self.name, key))
            c = rgb(hexc)
            m.diffuse_color = (c[0], c[1], c[2], 1.0)
            try:
                m.use_nodes = True
            except Exception:
                pass
            if m.node_tree:
                b = m.node_tree.nodes.get("Principled BSDF")
                if b:
                    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
                    b.inputs["Roughness"].default_value = rough
            me.materials.append(m)
        attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        for poly in me.polygons:
            c = me.materials[poly.material_index].diffuse_color
            for li in poly.loop_indices:
                attr.data[li].color = (c[0], c[1], c[2], 1.0)
        obj = bpy.data.objects.new(self.name, me)
        scene.collection.objects.link(obj)
        return obj


COMMON = {"black": ("#15171c", 0.25), "white": ("#ffffff", 0.35), "pink": ("#ff8fae", 0.55)}


def pal(**kw):
    p = dict(COMMON)
    for k, v in kw.items():
        p[k] = v
    return p


# ---------------------------------------------------------------- FROG
def build_frog():
    b = Builder("Frog", pal(skin=("#4fcf4f", 0.55), dark=("#2f9e3a", 0.55), belly=("#e0f5a4", 0.55), mouth=("#26331f", 0.5)))
    b.box("skin", (0, -0.4, 2.2), (4.0, 4.2, 2.8), bevel=0.2)                    # body
    b.box("belly", (0, 0.0, 1.0), (3.4, 3.6, 0.6), bevel=0.12)
    b.box("skin", (0, 1.9, 2.4), (4.4, 2.8, 2.0), bevel=0.2)                     # wide head
    b.box("belly", (0, 2.2, 1.3), (2.6, 1.8, 0.6), bevel=0.1)                    # throat
    b.box("mouth", (0, 3.32, 2.0), (3.6, 0.14, 0.2), bevel=0.0)
    for sx in (-1, 1):
        b.box("white", (1.2 * sx, 3.33, 1.84), (0.32, 0.14, 0.32), bevel=0.0)    # little teeth
        b.box("mouth", (0.5 * sx, 3.32, 2.78), (0.22, 0.14, 0.22), bevel=0.0)    # nostrils
        b.box("pink", (1.85 * sx, 3.32, 2.3), (0.6, 0.14, 0.42), bevel=0.04)     # cheeks
        b.box("skin", (1.35 * sx, 1.5, 3.75), (1.5, 1.5, 1.2), bevel=0.15)       # raised eye blocks
        # hind leg: thigh, shin, big shoe-foot with 3 toes
        b.box("skin", (2.35 * sx, -1.3, 1.7), (1.3, 2.8, 2.3), rot=(0, 0, -8 * sx), bevel=0.18)
        b.box("dark", (2.7 * sx, 0.5, 0.8), (1.1, 2.4, 1.0), bevel=0.15)
        b.box("dark", (2.8 * sx, 1.5, 0.28), (1.6, 2.2, 0.56), bevel=0.12)
        for dx in (-0.55, 0, 0.55):
            b.box("dark", (2.8 * sx + dx, 2.8, 0.22), (0.45, 0.9, 0.44), bevel=0.08)
        # front leg + hand + toes
        b.box("skin", (1.7 * sx, 1.2, 1.0), (0.95, 1.0, 1.9), bevel=0.14)
        b.box("dark", (1.75 * sx, 2.1, 0.25), (1.4, 1.7, 0.5), bevel=0.1)
        for dx in (-0.4, 0, 0.4):
            b.box("dark", (1.75 * sx + dx, 3.05, 0.2), (0.34, 0.7, 0.4), bevel=0.06)
    # eyes on the raised blocks (face plane y ~ 2.3)
    for sx in (-1, 1):
        b.box("white", (1.35 * sx, 2.28, 3.8), (1.05, 0.18, 1.0), bevel=0.04)
        b.box("black", (1.35 * sx, 2.38, 3.78), (0.55, 0.2, 0.75), bevel=0.04)
        b.box("white", (1.2 * sx, 2.5, 4.05), (0.2, 0.12, 0.2), bevel=0.0)
    for (x, y) in ((-0.9, -1.2), (1.0, -0.6), (0.1, -1.9), (-0.3, 0.5), (1.3, -1.9)):
        b.box("dark", (x, y, 3.62), (0.85, 0.85, 0.18), bevel=0.05)             # back spots
    return b


# ---------------------------------------------------------------- MOUSE
def build_mouse():
    b = Builder("Mouse", pal(fur=("#b6b2c8", 0.6), light=("#e8e4f2", 0.6), inner=("#ff9fb8", 0.55), nose=("#ff6f94", 0.4)))
    b.box("fur", (0, -0.6, 1.6), (2.6, 3.8, 2.4), bevel=0.2)
    b.box("light", (0, -0.2, 1.0), (2.0, 3.0, 0.6), bevel=0.1)
    b.box("fur", (0, 1.4, 2.0), (2.4, 2.4, 2.0), bevel=0.18)                     # head
    b.box("fur", (0, 2.95, 1.8), (1.5, 1.5, 1.3), taper=(0.7, 0.7), bevel=0.12)  # snout
    b.box("nose", (0, 3.7, 1.95), (0.55, 0.35, 0.45), bevel=0.06)
    for sx in (-1, 1):
        b.box("white", (0.2 * sx, 3.5, 1.3), (0.3, 0.15, 0.5), bevel=0.0)         # buck teeth
        b.box("fur", (1.45 * sx, 0.95, 3.5), (1.7, 0.4, 1.7), rot=(0, 0, 25 * sx), bevel=0.1)    # big ears
        b.box("inner", (1.5 * sx, 1.2, 3.5), (1.2, 0.2, 1.2), rot=(0, 0, 25 * sx), bevel=0.06)
        b.box("fur", (1.0 * sx, 2.0, 1.15), (0.55, 0.6, 1.3), bevel=0.08)           # arms
        b.box("inner", (1.0 * sx, 2.4, 0.4), (0.7, 0.9, 0.4), bevel=0.06)
        b.box("fur", (1.5 * sx, -1.4, 1.15), (1.1, 2.0, 1.7), bevel=0.15)           # haunches
        b.box("inner", (1.45 * sx, -0.2, 0.22), (0.95, 1.9, 0.44), bevel=0.08)      # feet
        for k, dz in enumerate((-0.18, 0.0, 0.2)):                                  # whiskers
            b.bar("white", (0.45 * sx, 3.3, 1.95 + dz), (1.9 * sx, 3.7, 1.95 + dz * 3.0), 0.09, bevel=0.0)
    b.eye(0.8, 2.62, 2.55, s=0.5, white=False)
    pts = [(0, -2.5, 1.0), (0, -3.6, 0.8), (0, -4.7, 1.1), (0, -5.7, 1.7), (0, -6.3, 2.5)]  # blocky segmented tail
    for p0, p1, t in zip(pts, pts[1:], (0.42, 0.36, 0.3, 0.24)):
        b.bar("inner", p0, p1, t, bevel=0.06)
    return b


# ---------------------------------------------------------------- SQUIRREL
def build_squirrel():
    b = Builder("Squirrel", pal(fur=("#d9772f", 0.6), dark=("#9a4d1f", 0.6), cream=("#f6e4c4", 0.6),
                                 acorn=("#8a5a2b", 0.5), cap=("#5a3a22", 0.55)))
    b.box("fur", (0, -0.3, 2.6), (2.8, 2.6, 3.6), bevel=0.2)                      # body
    b.box("cream", (0, 1.0, 2.4), (1.9, 0.3, 2.6), bevel=0.1)                     # belly patch
    b.box("fur", (0, 0.6, 5.0), (2.6, 2.4, 2.2), bevel=0.18)                      # head
    b.box("cream", (0, 1.95, 4.7), (1.6, 1.2, 1.3), taper=(0.8, 0.8), bevel=0.12)
    b.box("black", (0, 2.62, 4.85), (0.5, 0.3, 0.4), bevel=0.05)                  # nose
    b.eye(0.82, 1.82, 5.3, s=0.5, white=False)
    for sx in (-1, 1):
        b.box("pink", (1.12 * sx, 1.83, 4.65), (0.5, 0.14, 0.4), bevel=0.04)
        b.box("fur", (0.95 * sx, 0.3, 6.5), (0.85, 0.65, 1.3), bevel=0.1)           # ears
        b.box("dark", (0.95 * sx, 0.3, 7.25), (0.5, 0.4, 0.8), taper=(0.4, 0.4), bevel=0.04)   # ear tufts
        b.box("fur", (1.3 * sx, 1.0, 3.3), (0.75, 0.9, 1.8), rot=(20, 0, 0), bevel=0.1)         # arms
        b.box("cream", (0.75 * sx, 1.75, 3.0), (0.65, 0.75, 0.55), bevel=0.06)                   # hands
        b.box("dark", (1.6 * sx, -0.3, 1.3), (1.05, 2.1, 1.9), bevel=0.15)                       # thighs
        b.box("cream", (1.4 * sx, 0.9, 0.25), (0.95, 2.1, 0.5), bevel=0.08)                      # feet
        for dx in (-0.25, 0.25):
            b.box("dark", (1.4 * sx + dx, 2.05, 0.15), (0.2, 0.3, 0.2), bevel=0.0)             # claws
    b.box("acorn", (0, 1.8, 3.1), (0.95, 0.95, 1.05), taper=(0.8, 0.8), bevel=0.1)               # acorn
    b.box("cap", (0, 1.8, 3.72), (1.1, 1.1, 0.4), bevel=0.06)
    b.box("cap", (0, 1.8, 4.0), (0.2, 0.2, 0.25), bevel=0.0)
    segs = [((0, -1.9, 1.6), (1.7, 1.6, 1.6), 0, "fur"), ((0, -2.9, 3.0), (1.9, 1.8, 2.2), 10, "fur"),
            ((0, -3.3, 4.8), (2.1, 2.0, 2.4), 5, "fur"), ((0, -2.8, 6.6), (2.0, 2.0, 2.3), -15, "fur"),
            ((0, -1.8, 8.0), (1.8, 1.9, 1.9), -30, "fur"), ((0, -0.7, 8.6), (1.4, 1.5, 1.5), -50, "cream")]
    for c, s, rx, mat in segs:                                                                  # stepped S-tail
        b.box(mat, c, s, rot=(rx, 0, 0), bevel=0.22)
    for z in (3.95, 5.7, 7.35):
        b.box("dark", (0, -3.25 + (0.35 if z > 6 else 0), z), (2.2, 2.1, 0.28), rot=(0, 0, 0), bevel=0.05)
    return b


# ---------------------------------------------------------------- HEDGEHOG
def build_hedgehog():
    b = Builder("Hedgehog", pal(spine=("#5a3d30", 0.65), tip=("#c39a74", 0.55), face=("#e8c18f", 0.6), belly=("#f3dfbb", 0.6)))
    b.box("spine", (0, -0.6, 2.3), (4.6, 5.0, 2.6), bevel=0.25)                  # lower body
    b.box("spine", (0, -0.9, 4.0), (4.1, 4.6, 1.5), taper=(0.85, 0.88), bevel=0.22)   # stepped dome back
    b.box("belly", (0, 0.5, 1.0), (3.6, 4.0, 0.8), bevel=0.12)
    b.box("face", (0, 2.5, 1.9), (2.3, 2.3, 2.0), bevel=0.2)                      # smaller head
    b.box("face", (0, 4.15, 1.7), (1.4, 2.2, 1.1), taper=(0.55, 0.55), bevel=0.12)   # long pointed snout
    b.box("black", (0, 5.3, 1.8), (0.6, 0.4, 0.5), bevel=0.06)                    # nose
    b.eye(0.75, 3.66, 2.45, s=0.6, white=True)
    for sx in (-1, 1):
        b.box("pink", (1.0 * sx, 3.66, 1.75), (0.5, 0.14, 0.4), bevel=0.04)
        b.box("face", (1.15 * sx, 1.9, 3.15), (0.75, 0.55, 0.75), bevel=0.1)        # ears
        b.box("pink", (1.15 * sx, 2.2, 3.15), (0.45, 0.2, 0.45), bevel=0.04)
        b.box("face", (1.5 * sx, 1.6, 0.3), (1.2, 1.7, 0.6), bevel=0.1)             # front feet
        b.box("face", (1.8 * sx, -2.4, 0.3), (1.3, 1.9, 0.6), bevel=0.1)            # hind feet

    def spine(base, direction, big=1.0):
        b.spike("spine", base, direction, 1.0 * big, 0.62 * big)
        b.spike("tip", Vector(base) + Vector(direction).normalized() * 0.55 * big, direction, 0.6 * big, 0.36 * big)

    # spines: big two-tone pyramids over the dome, the back and the sides, leaning backwards
    for iy in range(8):
        for ix in range(-3, 4):
            x = ix * 0.72 + (0.36 if iy % 2 else 0)
            if abs(x) > 1.7:
                continue
            spine((x, -3.0 + iy * 0.62, 4.7), (0, -0.4, 1.0), 1.0 if iy < 7 else 0.8)
    for sx in (-1, 1):
        for iy in range(6):                                               # sides of the dome and lower body
            spine((2.05 * sx, -3.0 + iy * 0.8, 4.2), (sx, -0.4, 0.55), 0.9)
            spine((2.3 * sx, -2.8 + iy * 0.8 + 0.4, 3.0), (sx, -0.4, 0.2), 0.9)
            spine((2.3 * sx, -2.8 + iy * 0.8, 1.9), (sx, -0.4, 0.0), 0.85)
    for ix in range(-2, 3):                                               # back face
        for z in (2.0, 3.0, 4.1):
            spine((ix * 0.85, -3.1, z), (0, -1.0, 0.3), 0.85)
    return b


# ---------------------------------------------------------------- DUCKLING
def build_duckling():
    b = Builder("Duckling", pal(down=("#ffd93d", 0.6), wing=("#f1b81c", 0.6), beak=("#ff8a1f", 0.5), beak2=("#e06a0c", 0.5),
                                 feet=("#ff7a1a", 0.5)))
    b.box("down", (0, -0.4, 2.1), (3.2, 3.6, 2.8), bevel=0.22)                    # body
    b.box("down", (0, 1.2, 4.1), (2.6, 2.5, 2.4), bevel=0.2)                      # head
    b.box("beak", (0, 2.85, 3.95), (1.8, 1.2, 0.5), taper=(0.8, 0.8), bevel=0.08) # beak
    b.box("beak2", (0, 2.7, 3.55), (1.5, 0.95, 0.32), bevel=0.06)
    b.eye(0.92, 2.48, 4.55, s=0.55, white=False)
    for sx in (-1, 1):
        b.box("pink", (1.18 * sx, 2.48, 3.8), (0.5, 0.14, 0.4), bevel=0.04)
        b.box("wing", (1.8 * sx, -0.4, 2.3), (0.55, 2.2, 1.7), rot=(0, 0, 10 * sx), bevel=0.12)
        b.box("feet", (0.85 * sx, 0.4, 0.55), (0.38, 0.38, 1.0), bevel=0.05)                    # legs
        b.box("feet", (0.85 * sx, 0.95, 0.15), (1.2, 1.6, 0.3), bevel=0.06)                      # webbed feet
        for dx in (-0.4, 0, 0.4):
            b.box("feet", (0.85 * sx + dx, 1.95, 0.12), (0.32, 0.6, 0.25), bevel=0.04)
    for dx, rz in ((-0.3, -20), (0, 0), (0.3, 20)):                                              # head tuft
        b.box("down", (dx, 0.9, 5.55), (0.3, 0.3, 0.75), rot=(0, 0, rz), bevel=0.04)
    b.box("down", (0, -2.3, 2.9), (1.1, 1.0, 0.9), rot=(25, 0, 0), bevel=0.1)                    # tail
    return b


BUILDERS = [build_frog, build_mouse, build_squirrel, build_hedgehog, build_duckling]
objs, stats = [], []
for fn in BUILDERS:
    objs.append(fn().finish())

for obj in objs:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    d = obj.dimensions
    stats.append("%s: %d tris, %.1f x %.1f x %.1f studs" % (obj.name, len(obj.data.polygons), d.x, d.y, d.z))
    bpy.ops.export_scene.fbx(filepath=os.path.join(out_dir, obj.name + ".fbx"), use_selection=True, add_leaf_bones=False)
    bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, obj.name + ".obj"), export_selected_objects=True)
print("STATS:\n" + "\n".join(stats))

for obj, x in zip(objs, (-9, -4.5, 0, 4.5, 9)):
    obj.location.x = x
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "Small_Animals_Blocky.blend"))

# ---------------------------------------------------------------- previews
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 760
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*rgb("#a9d4f5"), 1)
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
ground = bpy.context.active_object
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb("#35d450"), 1)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
ground.data.materials.append(gm)
sd = bpy.data.lights.new("Sun", "SUN")
sd.energy = 3.4
sd.angle = math.radians(8)
sun = bpy.data.objects.new("Sun", sd)
sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(150))
scene.collection.objects.link(sun)
fd = bpy.data.lights.new("Fill", "AREA")
fd.energy = 600
fd.size = 16
fill = bpy.data.objects.new("Fill", fd)
fill.location = (-6, 22, 14)
fill.rotation_euler = (math.radians(55), 0, math.radians(-15))
scene.collection.objects.link(fill)


def shoot(name, cam_loc, look_at, lens):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cam = bpy.data.objects.new(name, cd)
    scene.collection.objects.link(cam)
    cam.location = cam_loc
    cam.rotation_euler = (Vector(look_at) - Vector(cam_loc)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)


for obj in objs:
    for o in objs:
        o.hide_render = (o is not obj)
    d = obj.dimensions
    centre = Vector((obj.location.x, 0.0, d.z * 0.5))
    dist = max(d.x, d.y, d.z) * 2.5 + 3
    shoot("preview_" + obj.name, centre + Vector((dist * 0.55, dist * 0.8, dist * 0.35)), centre, 50)
for o in objs:
    o.hide_render = False
shoot("preview_lineup", (0, 27, 7), (0, 0, 2.8), 35)
print("DONE")
