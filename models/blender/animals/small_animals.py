"""Shoot an Animal: five small animals, detailed cartoon style (Blender 5.x, run headless).

  blender.exe --background --factory-startup --python small_animals.py -- <output folder>

Smooth sculpted shapes (ellipsoids, tubes, spines) instead of blocks. 1 Blender unit = 1 Roblox stud.
Every animal: feet on z = 0, centred on x = 0 / y = 0, FACING +Y, Z up (the FBX exporter turns that into
Roblox's -Z-forward / Y-up). Outputs per animal: <Name>.fbx, <Name>.obj/.mtl (colours are materials AND a vertex
colour attribute "Col"), plus Small_Animals.blend and preview renders (one per animal + a lineup).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv
out_dir = argv[argv.index("--") + 1] if "--" in argv else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(out_dir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------------------------------------------------------------- colour helpers
def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


# ---------------------------------------------------------------- mesh builder
RES = {"L": (24, 12), "M": (16, 8), "S": (10, 6)}  # (segments, rings) per size tier


class Builder:
    def __init__(self, name, palette):
        self.name = name
        self.bm = bmesh.new()
        self.palette = palette          # {material name: (hex, roughness)}
        self.order = list(palette.keys())
        self.tris = 0

    def _faces_of(self, verts):
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        return faces

    def blob(self, mat, centre, radii, rot=(0, 0, 0), res="M"):
        """Smooth ellipsoid. rot in degrees (X, Y, Z)."""
        seg, rings = RES[res]
        m = (Matrix.Translation(centre) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
             @ Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0)))
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0, matrix=m)
        idx = self.order.index(mat)
        for f in self._faces_of(r["verts"]):
            f.material_index = idx

    def cone(self, mat, base, direction, length, radius, sides=6):
        """Cone from `base` pointing along `direction` (spines, claws...)."""
        d = Vector(direction).normalized()
        q = d.to_track_quat("Z", "Y")
        m = Matrix.Translation(Vector(base) + d * (length / 2)) @ q.to_matrix().to_4x4()
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius,
                                  radius2=0.0, depth=length, matrix=m)
        idx = self.order.index(mat)
        for f in self._faces_of(r["verts"]):
            f.material_index = idx

    def tube(self, mat, pts, radii, sides=8):
        """Tapered tube along a polyline (tails, whiskers, mouth lines) with rounded ends."""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        idx = self.order.index(mat)
        rings = []
        prev_b = None
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
            if prev_b is None:
                up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
                a = t.cross(up).normalized()
                b = t.cross(a).normalized()
            else:                                    # parallel transport: no twisting between rings
                b = (prev_b - t * prev_b.dot(t)).normalized()
                a = t.cross(b).normalized()
            prev_b = b
            rings.append([self.bm.verts.new(p + (a * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * radii[i])
                          for k in range(sides)])
        for i in range(n - 1):
            for k in range(sides):
                f = self.bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
                f.material_index = idx
        for ring in (rings[0], rings[-1]):
            f = self.bm.faces.new(ring)
            f.material_index = idx
        # round the ends with a small sphere
        for p, r in ((pts[0], radii[0]), (pts[-1], radii[-1])):
            self.blob(mat, p, (r, r, r), res="S")

    def finish(self):
        bm = self.bm
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
        try:
            me.shade_smooth()
        except Exception:
            for p in me.polygons:
                p.use_smooth = True
        attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        for poly in me.polygons:
            c = me.materials[poly.material_index].diffuse_color
            for li in poly.loop_indices:
                attr.data[li].color = (c[0], c[1], c[2], 1.0)
        obj = bpy.data.objects.new(self.name, me)
        scene.collection.objects.link(obj)
        self.tris = len(me.polygons)
        return obj


def surface_z(centre, radii, x, y):
    """Z of an ellipsoid's top surface above (x, y): used to sit spots / marks on a body."""
    t = 1.0 - ((x - centre[0]) / radii[0]) ** 2 - ((y - centre[1]) / radii[1]) ** 2
    return centre[2] + radii[2] * math.sqrt(max(t, 0.0))


def eyes(b, head, x, z, size=(0.17, 0.12, 0.21), mat="black", hl="white"):
    """A pair of glossy eyes with a catch-light each, sitting ON the front surface of the head ellipsoid
    `head` = (centre, radii): eye at sideways offset x, height z."""
    c, r = head
    t = 1.0 - (x / r[0]) ** 2 - ((z - c[2]) / r[2]) ** 2
    y = c[1] + r[1] * math.sqrt(max(t, 0.02)) - size[1] * 0.35
    for s in (-1, 1):
        b.blob(mat, (x * s, y, z), size, res="S")
        b.blob(hl, (x * s * 0.8, y + size[1] * 0.8, z + size[2] * 0.45), (size[0] * 0.38, size[1] * 0.3, size[2] * 0.38), res="S")


EYE = ("#14161c", 0.15)
HILITE = ("#ffffff", 0.3)

# ---------------------------------------------------------------- FROG
def build_frog():
    P = {"skin": ("#58b947", 0.55), "dark": ("#3e8f35", 0.6), "belly": ("#f0f2b8", 0.6), "pink": ("#ff9fb7", 0.6),
         "white": ("#ffffff", 0.3), "black": EYE, "mouth": ("#2a3d24", 0.5)}
    b = Builder("Frog", P)
    body = ((0, -0.2, 1.7), (1.8, 2.1, 1.5))
    b.blob("skin", body[0], body[1], res="L")
    b.blob("belly", (0, 0.1, 1.0), (1.4, 1.7, 0.8), res="M")
    b.blob("skin", (0, 1.3, 2.1), (1.7, 1.3, 1.05), res="L")                   # wide flat head
    b.blob("belly", (0, 1.95, 1.4), (0.9, 0.7, 0.5), res="M")                  # throat
    for s in (-1, 1):
        b.blob("skin", (0.95 * s, 1.2, 3.0), (0.62, 0.62, 0.62), res="M")      # eye bump
        b.blob("white", (0.95 * s, 1.62, 3.05), (0.46, 0.4, 0.46), res="M")
        b.blob("black", (0.95 * s, 1.97, 3.08), (0.27, 0.1, 0.34), res="S")
        b.blob("white", (0.85 * s, 2.05, 3.22), (0.08, 0.05, 0.08), res="S")
        b.blob("pink", (1.25 * s, 2.1, 2.05), (0.28, 0.1, 0.2), res="S")        # cheek
        b.blob("dark", (0.35 * s, 2.45, 2.5), (0.1, 0.06, 0.08), res="S")       # nostril
        # hind leg: thigh, shin, webbed foot with three toes
        b.blob("skin", (1.9 * s, -1.1, 1.1), (0.85, 1.7, 1.0), rot=(0, 0, -10 * s), res="M")
        b.blob("dark", (2.1 * s, -0.2, 0.5), (0.55, 1.5, 0.45), rot=(0, 0, 8 * s), res="M")
        b.blob("dark", (2.1 * s, 1.0, 0.2), (0.85, 0.85, 0.17), res="M")
        for dx in (-0.5, 0, 0.5):
            b.blob("dark", (2.1 * s + dx, 1.7, 0.18), (0.2, 0.5, 0.14), res="S")
        # front leg + hand with toes
        b.blob("skin", (1.15 * s, 1.1, 0.9), (0.4, 0.45, 0.85), res="M")
        b.blob("dark", (1.2 * s, 1.6, 0.18), (0.55, 0.6, 0.16), res="M")
        for dx in (-0.3, 0, 0.3):
            b.blob("dark", (1.2 * s + dx, 2.05, 0.16), (0.14, 0.3, 0.12), res="S")
    # wide smiling mouth line
    b.tube("mouth", [(-1.4, 2.12, 1.98), (-0.75, 2.48, 1.86), (0, 2.6, 1.83), (0.75, 2.48, 1.86), (1.4, 2.12, 1.98)],
           [0.05, 0.065, 0.07, 0.065, 0.05], sides=6)
    for (x, y, r) in ((-0.8, -0.9, 0.38), (0.85, -0.5, 0.33), (0.15, -1.5, 0.3), (-0.25, 0.3, 0.28), (1.0, -1.5, 0.22)):
        z = surface_z(body[0], body[1], x, y) - 0.04
        b.blob("dark", (x, y, z), (r, r, 0.1), res="S")
    return b


# ---------------------------------------------------------------- MOUSE
def build_mouse():
    P = {"fur": ("#b8b4c4", 0.7), "light": ("#e9e5f0", 0.7), "pink": ("#ffa3b5", 0.6), "nose": ("#ff7f9e", 0.4),
         "white": ("#ffffff", 0.35), "black": EYE}
    b = Builder("Mouse", P)
    b.blob("fur", (0, -0.5, 1.3), (1.05, 1.6, 1.1), res="L")
    b.blob("light", (0, -0.1, 0.85), (0.8, 1.2, 0.6), res="M")
    b.blob("fur", (0, 1.0, 1.7), (0.85, 0.95, 0.8), res="L")
    b.blob("fur", (0, 1.8, 1.55), (0.45, 0.6, 0.4), res="M")                   # snout
    b.blob("nose", (0, 2.35, 1.62), (0.2, 0.15, 0.17), res="S")
    for dx in (-0.1, 0.1):
        b.blob("white", (dx, 2.12, 1.22), (0.09, 0.05, 0.17), res="S")          # buck teeth
    eyes(b, ((0, 1.0, 1.7), (0.85, 0.95, 0.8)), 0.42, 1.95)
    for s in (-1, 1):
        b.blob("fur", (0.85 * s, 0.55, 2.5), (0.62, 0.14, 0.62), rot=(0, 0, -30 * s), res="M")       # big round ears
        b.blob("pink", (0.9 * s, 0.68, 2.5), (0.42, 0.1, 0.42), rot=(0, 0, -30 * s), res="M")
        b.blob("fur", (0.55 * s, 1.35, 0.8), (0.18, 0.25, 0.45), res="S")                            # arms
        b.blob("pink", (0.55 * s, 1.6, 0.4), (0.2, 0.25, 0.15), res="S")
        b.blob("fur", (0.85 * s, -1.0, 0.9), (0.5, 0.8, 0.7), res="M")                               # haunch
        b.blob("pink", (0.8 * s, -0.35, 0.14), (0.35, 0.6, 0.12), res="S")                           # foot
        for k, dz in enumerate((-0.12, 0.0, 0.14)):                                                  # whiskers
            b.tube("white", [(0.25 * s, 2.0, 1.55 + dz * 0.4), (0.75 * s, 2.2, 1.55 + dz * 1.2), (1.35 * s, 2.15, 1.55 + dz * 2.4)],
                   [0.022, 0.018, 0.012], sides=4)
    b.tube("pink", [(0, -2.0, 0.9), (0.15, -2.8, 0.7), (-0.15, -3.6, 0.9), (0.1, -4.3, 1.4), (0, -4.7, 2.0)],
           [0.14, 0.12, 0.1, 0.075, 0.05], sides=8)
    return b


# ---------------------------------------------------------------- SQUIRREL
def build_squirrel():
    P = {"fur": ("#c9733a", 0.7), "dark": ("#8f4a22", 0.7), "cream": ("#f4e2c4", 0.7), "pink": ("#ffa3b5", 0.6),
         "acorn": ("#8a5a2b", 0.5), "cap": ("#5f3b25", 0.6), "white": ("#ffffff", 0.3), "black": EYE}
    b = Builder("Squirrel", P)
    b.blob("fur", (0, -0.2, 1.9), (1.1, 1.2, 1.7), res="L")
    b.blob("cream", (0, 0.5, 1.7), (0.75, 0.7, 1.3), res="M")
    b.blob("fur", (0, 0.5, 3.7), (0.95, 0.95, 0.85), res="L")                  # head
    b.blob("cream", (0, 1.3, 3.45), (0.5, 0.5, 0.4), res="M")                  # muzzle
    b.blob("black", (0, 1.78, 3.55), (0.15, 0.12, 0.12), res="S")
    eyes(b, ((0, 0.5, 3.7), (0.95, 0.95, 0.85)), 0.45, 3.95, (0.17, 0.12, 0.22))
    for s in (-1, 1):
        b.blob("pink", (0.75 * s, 1.15, 3.4), (0.22, 0.1, 0.18), res="S")
        b.blob("fur", (0.62 * s, 0.1, 4.55), (0.32, 0.2, 0.5), rot=(0, 0, 15 * s), res="M")        # ear
        b.blob("cream", (0.62 * s, 0.28, 4.5), (0.2, 0.1, 0.34), rot=(0, 0, 15 * s), res="S")
        b.blob("dark", (0.7 * s, 0.1, 5.05), (0.1, 0.09, 0.24), rot=(0, 0, 15 * s), res="S")       # ear tuft
        b.blob("fur", (0.75 * s, 0.9, 2.35), (0.28, 0.3, 0.75), rot=(20, 0, 0), res="M")           # arm
        b.blob("cream", (0.38 * s, 1.35, 2.65), (0.22, 0.2, 0.18), res="S")                       # hand
        b.blob("dark", (1.0 * s, -0.2, 1.0), (0.55, 0.9, 0.7), res="M")                             # thigh
        b.blob("cream", (0.9 * s, 0.7, 0.14), (0.35, 0.7, 0.14), res="M")                           # foot
        for dx in (-0.14, 0.14):
            b.cone("dark", (0.9 * s + dx, 1.35, 0.12), (0, 1, 0), 0.22, 0.05, sides=5)              # claws
    # acorn held in the hands
    b.blob("acorn", (0, 1.5, 2.5), (0.38, 0.38, 0.45), res="M")
    b.blob("cap", (0, 1.5, 2.88), (0.42, 0.42, 0.2), res="M")
    b.blob("cap", (0, 1.5, 3.1), (0.06, 0.06, 0.12), res="S")
    # big bushy S-curved tail: one smooth tube (Catmull-Rom through the control points, radius profile),
    # cream tip as a second overlapping tube, dark tufts along the back edge
    path = [((0, -1.0, 1.0), 0.72), ((0, -2.0, 1.8), 0.88), ((0, -2.8, 3.0), 1.0), ((0, -2.8, 4.4), 1.08),
            ((0, -2.0, 5.5), 0.98), ((0, -1.0, 6.1), 0.8), ((0, -0.1, 6.2), 0.55)]
    cps = [Vector(p) for p, _ in path]
    rads = [r for _, r in path]
    pts, radii = [], []
    per = 8
    for i in range(len(cps) - 1):
        p0, p1, p2, p3 = cps[max(i - 1, 0)], cps[i], cps[i + 1], cps[min(i + 2, len(cps) - 1)]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            pts.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
            radii.append(rads[i] + (rads[i + 1] - rads[i]) * t)
    pts.append(cps[-1])
    radii.append(rads[-1])
    cut = int(len(pts) * 0.78)
    b.tube("fur", pts[:cut + 2], radii[:cut + 2], sides=16)
    tip_r = radii[cut:]
    b.tube("cream", pts[cut:], [r * (0.9 + 0.16 * i / max(len(tip_r) - 1, 1)) for i, r in enumerate(tip_r)], sides=16)  # starts hidden inside the fur, then swells out
    for i in range(3, cut, 4):                                # fur tufts on the back edge of the tail
        p, r = pts[i], radii[i]
        b.blob("dark", p + Vector((0, -r * 0.7, r * 0.12)), (r * 0.4, r * 0.28, r * 0.5), res="S")
    return b


# ---------------------------------------------------------------- HEDGEHOG
def build_hedgehog():
    P = {"spine": ("#5a3d30", 0.7), "tip": ("#b38a6a", 0.6), "face": ("#e3bf94", 0.7), "belly": ("#f1dcb8", 0.7),
         "pink": ("#ffa3b5", 0.6), "white": ("#ffffff", 0.3), "black": EYE}
    b = Builder("Hedgehog", P)
    body = ((0, -0.4, 1.7), (1.9, 2.4, 1.5))
    b.blob("spine", body[0], body[1], res="L")
    b.blob("belly", (0, 0.6, 0.8), (1.3, 1.7, 0.65), res="M")
    b.blob("face", (0, 1.9, 1.3), (0.95, 1.05, 0.8), res="L")                  # head
    b.blob("face", (0, 2.8, 1.15), (0.5, 0.7, 0.45), res="M")                  # snout
    b.blob("black", (0, 3.45, 1.2), (0.22, 0.2, 0.2), res="S")                 # nose
    eyes(b, ((0, 1.9, 1.3), (0.95, 1.05, 0.8)), 0.5, 1.58, (0.22, 0.14, 0.27))
    for s in (-1, 1):
        b.blob("face", (0.8 * s, 1.5, 2.0), (0.3, 0.2, 0.32), rot=(0, 0, 20 * s), res="M")
        b.blob("pink", (0.8 * s, 1.62, 2.0), (0.18, 0.1, 0.2), rot=(0, 0, 20 * s), res="S")
        b.blob("pink", (0.7 * s, 2.3, 1.1), (0.2, 0.1, 0.15), res="S")          # cheek
        b.blob("face", (0.9 * s, 1.2, 0.18), (0.4, 0.55, 0.18), res="M")        # front paw
        b.blob("face", (1.0 * s, -1.5, 0.18), (0.45, 0.6, 0.18), res="M")       # hind paw
    # ~250 spines over the back and sides (random but spaced), pointing up and back
    rnd = random.Random(7)
    placed = []
    tries = 0
    while len(placed) < 320 and tries < 40000:
        tries += 1
        th = rnd.uniform(0, 2 * math.pi)
        ph = rnd.uniform(0.0, math.pi * 0.62)         # from the top down to a bit below the equator
        n = Vector((math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)))
        pos = Vector((body[0][0] + body[1][0] * n.x, body[0][1] + body[1][1] * n.y, body[0][2] + body[1][2] * n.z))
        if pos.y > 1.1:                                # keep the face clear
            continue
        if pos.z < 1.0:
            continue
        if any((pos - q).length < 0.36 for q in placed):
            continue
        placed.append(pos)
        sn = Vector((n.x / body[1][0], n.y / body[1][1], n.z / body[1][2])).normalized()   # true surface normal
        d = (sn * 0.85 + Vector((0, -0.45, 0.25))).normalized()
        b.cone("spine", pos - sn * 0.12, d, 0.68, 0.17, sides=6)
        b.cone("tip", pos - sn * 0.12 + d * 0.4, d, 0.38, 0.09, sides=6)
    return b


# ---------------------------------------------------------------- DUCKLING
def build_duckling():
    P = {"down": ("#ffd93d", 0.75), "wing": ("#f2bb1f", 0.7), "beak": ("#ff8a1f", 0.45), "beak2": ("#e8710f", 0.45),
         "feet": ("#ff7a1a", 0.5), "pink": ("#ffa3b5", 0.6), "white": ("#ffffff", 0.3), "black": EYE}
    b = Builder("Duckling", P)
    b.blob("down", (0, -0.3, 1.6), (1.35, 1.6, 1.3), res="L")
    b.blob("down", (0, 0.9, 3.1), (1.0, 1.0, 0.95), res="L")                   # head
    b.blob("beak", (0, 1.95, 2.95), (0.55, 0.7, 0.18), res="M")                # upper beak
    b.blob("beak2", (0, 1.85, 2.72), (0.48, 0.55, 0.13), res="M")              # lower beak
    eyes(b, ((0, 0.9, 3.1), (1.0, 1.0, 0.95)), 0.55, 3.4, (0.18, 0.13, 0.22))
    for s in (-1, 1):
        b.blob("pink", (0.82 * s, 1.35, 2.92), (0.24, 0.1, 0.17), res="S")
        b.blob("wing", (1.35 * s, -0.3, 1.7), (0.22, 0.85, 0.7), rot=(0, 0, 8 * s), res="M")
        b.blob("down", (1.28 * s, 0.35, 1.95), (0.18, 0.4, 0.4), rot=(0, 0, 8 * s), res="S")       # wing shoulder fluff
        b.blob("feet", (0.5 * s, 0.2, 0.4), (0.1, 0.1, 0.42), res="S")                              # leg
        b.blob("feet", (0.5 * s, 0.55, 0.1), (0.42, 0.55, 0.07), res="M")                           # webbed foot
        for dx in (-0.22, 0.0, 0.22):
            b.blob("feet", (0.5 * s + dx, 1.0, 0.09), (0.09, 0.28, 0.06), res="S")
    for dx, rz in ((-0.18, -25), (0.0, 0), (0.18, 25)):                         # head tuft
        b.blob("down", (dx, 0.55, 4.0), (0.1, 0.09, 0.3), rot=(0, 0, rz), res="S")
    b.blob("down", (0, -1.9, 1.9), (0.4, 0.55, 0.4), rot=(30, 0, 0), res="M")  # tail
    return b


BUILDERS = [build_frog, build_mouse, build_squirrel, build_hedgehog, build_duckling]
objs = []
stats = []
for fn in BUILDERS:
    bld = fn()
    obj = bld.finish()
    objs.append(obj)

# ---------------------------------------------------------------- export (each at the origin)
for obj in objs:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    dims = obj.dimensions
    stats.append("%s: %d tris, %.1f x %.1f x %.1f studs" % (obj.name, len(obj.data.polygons), dims.x, dims.y, dims.z))
    bpy.ops.export_scene.fbx(filepath=os.path.join(out_dir, obj.name + ".fbx"), use_selection=True, add_leaf_bones=False)
    bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, obj.name + ".obj"), export_selected_objects=True)
print("STATS:\n" + "\n".join(stats))

# ---------------------------------------------------------------- lineup + previews
for obj, x in zip(objs, (-9, -4.5, 0, 4.5, 9)):
    obj.location.x = x
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "Small_Animals.blend"))

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
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (*rgb("#a9d4f5"), 1)
bg.inputs["Strength"].default_value = 1.0
scene.world = world

bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
ground = bpy.context.active_object
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb("#35d450"), 1)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
ground.data.materials.append(gm)

sun_d = bpy.data.lights.new("Sun", "SUN")
sun_d.energy = 3.2
sun_d.angle = math.radians(8)
sun = bpy.data.objects.new("Sun", sun_d)
sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(150))
scene.collection.objects.link(sun)
fill_d = bpy.data.lights.new("Fill", "AREA")
fill_d.energy = 600
fill_d.size = 16
fill = bpy.data.objects.new("Fill", fill_d)
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


for obj in objs:                                           # one 3/4-front portrait each
    for o in objs:
        o.hide_render = (o is not obj)
    d = obj.dimensions
    centre = Vector((obj.location.x, 0.0, d.z * 0.5))
    dist = max(d.x, d.y, d.z) * 2.5 + 3
    shoot("preview_" + obj.name, centre + Vector((dist * 0.55, dist * 0.8, dist * 0.35)), centre, 50)
for o in objs:
    o.hide_render = False
shoot("preview_lineup", (0, 27, 7), (0, 0, 2.6), 35)
print("DONE")
