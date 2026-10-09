# Shoot an Animal - the six treadmill designs, built in Blender out of blocks (like the Yeti) and exported to Roblox.
#
# Run in Blender's Python (Scripting tab, or via MCP):
#     exec(open(r"C:/cl/m/models/speed/blender/treadmills.py").read())
#     build_all()                                      # (re)builds collection "Treadmills" with Tier1..Tier6
#     export_all(r"C:/cl/m/models/speed/designs")      # writes Tier1.lua .. Tier6.lua (Roblox ModuleScript data)
#
# Units: 1 Blender metre = 1 Roblox stud. Every piece is a box (one shared unit cube mesh, scaled). The tiers stand in a
# row along Blender X, SPACING apart; each tier's origin is the treadmill Spot on the floor. Shapes are written below in
# ROBLOX axes (x right, y up, z back; the runner faces -z towards the front piece) and converted to Blender axes
# (Blender x = x, Blender y = -z, Blender z = y). Export reads the real Blender objects, so pieces moved or recoloured
# by hand in Blender are exported as they are now.
# Custom properties per object: rname (Roblox part name: Belt, Slat, Glow, Fx*... see TreadmillClient), collide.
# Material properties: rbx (Roblox material), hex (colour), transp (transparency).
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

SPACING = 18.0
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))  # Blender -> Roblox axes
CT = C.transposed()
CUR = {"tier": 1, "coll": None, "count": 0}


def _cube_mesh():
    m = bpy.data.meshes.get("RbxUnitCube")
    if m is None:
        m = bpy.data.meshes.new("RbxUnitCube")
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bm.to_mesh(m)
        bm.free()
        m.materials.append(None)
    return m


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _input(node, ident):
    for i in node.inputs:
        if i.identifier == ident or i.name == ident:
            return i
    return None


def material(hexcol, rbx="SmoothPlastic", transp=0.0):
    name = "%s_%s_%d" % (rbx, hexcol, round(transp * 100))
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    rgb = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [_lin(c) for c in rgb]
    m.diffuse_color = (*lin, 1.0 - transp)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    i = _input(bsdf, "Base Color")
    if i:
        i.default_value = (*lin, 1)
    if rbx == "Neon":
        i = _input(bsdf, "Emission Color")
        if i:
            i.default_value = (*lin, 1)
        i = _input(bsdf, "Emission Strength")
        if i:
            i.default_value = 3.0
    if transp > 0:
        i = _input(bsdf, "Alpha")
        if i:
            i.default_value = 1.0 - transp
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    i = _input(bsdf, "Roughness")
    if i:
        i.default_value = 0.08 if rbx == "Glass" else 0.45
    m["rbx"] = rbx
    m["hex"] = hexcol
    m["transp"] = transp
    return m


def rot_matrix(rot):
    # same as Roblox CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz
    return Euler((math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])), "ZYX").to_matrix()


def box(name, hexcol, pos, size, rot=(0, 0, 0), rbx="SmoothPlastic", transp=0.0, col=None):
    t = CUR["tier"]
    x, y, z = pos
    a, b, c = size
    rb = CT @ rot_matrix(rot) @ C
    ob = bpy.data.objects.new("T%d_%s_%03d" % (t, name, CUR["count"]), _cube_mesh())
    CUR["count"] += 1
    CUR["coll"].objects.link(ob)
    ob.parent = CUR["root"]
    ob.matrix_world = Matrix.LocRotScale(Vector((x + (t - 1) * SPACING, -z, y)), rb.to_quaternion(), Vector((a, c, b)))
    ob.material_slots[0].link = "OBJECT"
    ob.material_slots[0].material = material(hexcol, rbx, transp)
    if col is None:
        col = min(size) >= 0.4 and rbx not in ("Neon", "Glass") and transp == 0
    ob["rname"] = name
    ob["collide"] = bool(col)
    return ob


def fx(kind, hexcol, pos, size):
    # an invisible anchor; TreadmillClient puts the particles + light of this kind on it
    ob = box(kind, hexcol, pos, size, transp=1.0, col=False)
    ob.display_type = "WIRE"
    ob.hide_render = True
    return ob


def along(pos, rot, dist):
    # a point dist studs along the (rotated) up axis from pos
    up = rot_matrix(rot) @ Vector((0, 1, 0))
    return (pos[0] + up.x * dist, pos[1] + up.y * dist, pos[2] + up.z * dist)


def begin(tier, label):
    root = bpy.data.collections.get("Treadmills")
    if root is None:
        root = bpy.data.collections.new("Treadmills")
        bpy.context.scene.collection.children.link(root)
    for coll in list(root.children):
        if coll.get("tier") == tier:
            for ob in list(coll.objects):
                bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.collections.remove(coll)
    coll = bpy.data.collections.new("Tier%d_%s" % (tier, label))
    root.children.link(coll)
    coll["tier"] = tier
    coll["label"] = label
    root_ob = bpy.data.objects.new("Tier%d_%s" % (tier, label), None)  # empty at the Spot: select it to move the whole tier
    root_ob.empty_display_type = "ARROWS"
    root_ob.matrix_world = Matrix.Translation(Vector(((tier - 1) * SPACING, 0, 0)))  # matrix_world, not location: children are placed against it right away
    coll.objects.link(root_ob)
    CUR.update(tier=tier, coll=coll, count=0, root=root_ob)
    random.seed(1000 + tier)


################################################################ the treadmill itself (same shape every tier)
# Belt: centre (0, 0.8, 0), size (5.8, 0.2, 12.6) -> must match SpeedData.Belt. Front piece stands on the plinth at
# z -7.1 .. -11.1 (BuildTreadmills keeps 12 studs to the pen fence).
def base(P):
    for x in (-3.2, 3.2):
        for z in (-6.2, 6.2):
            box("Foot", P["dark"], (x, 0.12, z), (1.1, 0.24, 1.1))
    box("Deck", P["deck"], (0, 0.47, 0), (7.6, 0.46, 14.4))
    box("DeckLip", P["shade"], (0, 0.3, 0), (7.8, 0.14, 14.6), col=False)
    box("Belt", P["belt"], (0, 0.8, 0), (5.8, 0.2, 12.6), col=True)
    for z in (-6.55, 6.55):
        box("Roller", P["roller"], (0, 0.86, z), (5.9, 0.42, 0.5))
        box("RollerBand", P["dark"], (0, 0.86, z), (6.0, 0.18, 0.54), col=False)
    for i in range(14):
        z = -6.3 + (i + 0.5) * 12.6 / 14
        box("Slat", P["slats"][i % len(P["slats"])], (0, 0.92, z), (5.7, 0.04, 0.38), col=False)
    for s in (-1, 1):
        box("Rail", P["rail"], (s * 3.35, 0.97, 0), (0.9, 0.54, 14.4))
        box("RailTop", P["railTop"], (s * 3.35, 1.27, 0), (0.94, 0.08, 14.44), col=False)
        box("RailInner", P["shade"], (s * 2.9, 0.95, 0), (0.06, 0.14, 12.8), col=False)
        box(P.get("trimName", "Trim"), P["trim"], (s * 3.83, 0.62, 0), (0.06, 0.16, 13.6), rbx="Neon", col=False)
        for z in (-5.4, -1.8, 1.8, 5.4):
            box("Bolt", P["bolt"], (s * 3.82, 0.95, z), (0.08, 0.22, 0.22), col=False)
        for z in (-7.0, 7.0):
            box("Cap", P["accent"], (s * 3.35, 1.0, z), (1.0, 0.62, 0.5))
            box("CapTop", P["railTop"], (s * 3.35, 1.33, z), (1.02, 0.06, 0.52), col=False)
    box("Step", P["deck"], (0, 0.22, 7.75), (5.8, 0.44, 1.1))
    box("StepEdge", P["accent"], (0, 0.45, 8.27), (5.8, 0.06, 0.08), col=False)
    box("Plinth", P["shade"], (0, 0.35, -9.1), (7.6, 0.7, 4.0))
    box("PlinthTop", P["deck"], (0, 0.74, -9.1), (7.4, 0.08, 3.8), col=False)
    box("PlinthBand", P["accent"], (0, 0.36, -7.08), (7.6, 0.12, 0.06), col=False)


################################################################ 1: Basic - a plain gym treadmill (console, handlebars, motor hood)
def tier1():
    begin(1, "Basic")
    G, Gs, Gd, K = "c9d1dc", "9aa5b5", "5b6270", "23262d"
    base(dict(deck="8e98a8", shade="6f7a8b", dark="3a404c", belt=K, roller="5b6270", slats=["3d4250", "4b5263"],
              rail=G, railTop="e3e8ef", trim="4fc3ff", bolt="8a93a3", accent="4fc3ff"))
    # motor hood on the plinth, with vent slits and a stripe
    box("Hood", Gs, (0, 1.3, -8.4), (6.6, 1.1, 2.2))
    box("HoodTop", G, (0, 1.88, -8.4), (6.4, 0.08, 2.0), col=False)
    box("HoodStripe", "4fc3ff", (0, 1.3, -7.29), (6.6, 0.14, 0.04), rbx="Neon", col=False)
    for i in range(6):
        box("Vent", Gd, (-1.75 + i * 0.7, 1.05, -7.29), (0.4, 0.12, 0.05), col=False)
    # two uprights, leaning back towards the runner
    for s in (-1, 1):
        box("Upright", Gd, (s * 2.95, 3.3, -8.3), (0.5, 3.6, 0.5), rot=(-14, 0, 0))
        box("UprightCap", G, (s * 2.95, 1.6, -8.75), (0.7, 0.3, 0.7))
        # handlebars along the sides, with black foam grips
        box("Handlebar", G, (s * 2.95, 4.25, -6.0), (0.3, 0.3, 3.4))
        box("Grip", K, (s * 2.95, 4.25, -5.2), (0.38, 0.38, 1.4), col=False)
        box("BarEnd", "ff5a5a", (s * 2.95, 4.25, -4.25), (0.36, 0.36, 0.16), col=False)
    # console tilted towards the runner: dark screen with a glowing graph, buttons, a cup holder and a water bottle
    tilt = (-28, 0, 0)
    cpos = (0, 5.05, -7.75)
    box("Console", Gd, cpos, (6.2, 1.5, 0.9), rot=tilt)
    box("ConsoleTop", G, along(cpos, tilt, 0.78), (6.2, 0.08, 0.9), rot=tilt, col=False)
    face = (0, 5.0, -7.3)
    box("Screen", "0b1622", face, (3.0, 0.95, 0.06), rot=tilt, col=False)
    for i, h in enumerate((0.25, 0.4, 0.55, 0.35, 0.65, 0.5, 0.75)):
        box("Graph", "4fc3ff", (-1.1 + i * 0.36, 4.82 + h / 2 * 0.88, -7.21 + h / 2 * 0.47), (0.2, h, 0.04), rot=tilt, rbx="Neon", col=False)
    for i, c in enumerate(("5bff63", "ffd93b", "ff5a5a")):
        box("Button", c, (2.0 + (i % 2) * 0.45, 5.15 - (i // 2) * 0.4, -7.27 + (i // 2) * 0.2), (0.3, 0.3, 0.06), rot=tilt, rbx="Neon", col=False)
    box("Button", "ffffff", (-2.25, 4.95, -7.3), (0.6, 0.6, 0.06), rot=tilt, col=False)
    box("CupHolder", K, (2.5, 5.75, -7.6), (0.7, 0.3, 0.7))
    box("Bottle", "6fd0ff", (2.5, 6.25, -7.6), (0.42, 0.8, 0.42), rbx="Glass", transp=0.25, col=False)
    box("BottleCap", "2f6fe0", (2.5, 6.73, -7.6), (0.3, 0.16, 0.3), col=False)
    box("Towel", "ff8fb1", (-2.6, 5.62, -7.4), (0.9, 0.12, 0.7), rot=(-28, 10, 0), col=False)
    fx("FxGlow", "4fc3ff", (0, 5.0, -7.2), (0.4, 0.4, 0.4))


################################################################ the wooden upgrade sign (stands by your treadmill)
# Origin = the ground under the sign; the sign faces -z. "Board" is an invisible front plate: TreadmillClient draws the
# price + Speed text and the button on its front face.
def sign():
    begin(0, "Sign")
    W1, W2, W3, Wd = "c8935a", "b98450", "d6a46a", "6b4426"
    for s in (-1, 1):
        box("Post", Wd, (s * 2.3, 2.6, 0.4), (0.5, 5.2, 0.5))  # behind the planks
        box("PostCap", "5a381f", (s * 2.3, 5.28, 0.4), (0.62, 0.18, 0.62), col=False)
        box("PostShade", "5a381f", (s * 2.3, 0.25, 0.4), (0.56, 0.5, 0.56), col=False)
    box("Back", "7a4f2b", (0, 3.7, 0.16), (5.4, 3.2, 0.16), col=False)
    for i, (y, c, r) in enumerate(((4.75, W1, 0.8), (3.7, W2, -0.6), (2.65, W3, 0.5))):
        box("Plank", c, (0, y, -0.02), (5.7, 0.98, 0.26), rot=(0, 0, r), rbx="Wood")
        for g in (-0.22, 0.2):
            box("Grain", Wd, (random.uniform(-1.0, 1.0), y + g, -0.16), (random.uniform(1.4, 2.6), 0.04, 0.02), rot=(0, 0, r), col=False)
        for s in (-1, 1):
            box("Nail", "3b3b40", (s * 2.3, y, -0.17), (0.13, 0.13, 0.04), col=False)
    box("TopTrim", Wd, (0, 5.3, 0.1), (6.0, 0.22, 0.6), rbx="Wood", col=False)
    for x in (-2.7, -2.0, 2.0, 2.6):
        box("Grass", "4cbb5a", (x, 0.18, random.uniform(-0.25, 0.25)), (0.22, 0.36, 0.22), rot=(0, random.uniform(0, 90), random.uniform(-15, 15)), col=False)
    board = box("Board", "ffffff", (0, 3.7, -0.17), (5.5, 3.1, 0.02), transp=1.0, col=False)
    board.display_type = "WIRE"
    board.hide_render = True


################################################################ 2: Storm - a thunder cloud on two posts
def tier2():
    begin(2, "Storm")
    W, Ws, Wd, Y, B = "f3f6fb", "c3cfe0", "9aa9bf", "fff36b", "59c7ff"
    base(dict(deck="eef4fb", shade="c6d6ea", dark="2e3b52", belt="1a2233", roller="44526b", slats=["2f6fe0", "e9f2ff"],
              rail="ffffff", railTop="9fd4ff", trim=B, bolt="7f93b3", accent="2f6fe0"))
    for s in (-1, 1):
        box("Post", "8ea3c0", (s * 3.3, 3.8, -9.3), (0.8, 6.2, 0.8))
        box("PostShade", "6f84a3", (s * 3.3, 1.05, -9.3), (0.86, 0.6, 0.86), col=False)
        for y in (2.6, 4.2, 5.8):
            box("PostBand", "2f6fe0", (s * 3.3, y, -9.3), (0.88, 0.16, 0.88), col=False)
        box("Orb", B, (s * 3.3, 3.4, -8.82), (0.42, 0.42, 0.16), rbx="Neon", col=False)
    for pos, size in (((0, 7.6, -9.3), (7.2, 1.8, 2.6)), ((-2.2, 8.45, -9.3), (2.4, 2.0, 2.4)), ((0.4, 8.75, -9.1), (2.9, 2.5, 2.7)),
                      ((2.6, 8.25, -9.5), (2.1, 1.7, 2.2)), ((-3.7, 7.85, -9.1), (1.6, 1.4, 1.8)), ((3.95, 7.75, -9.1), (1.5, 1.3, 1.6)),
                      ((-1.0, 9.6, -9.4), (1.6, 1.1, 1.6)), ((1.4, 9.7, -9.2), (1.3, 0.9, 1.3))):
        box("Cloud", W, pos, size)
    box("CloudBelly", Ws, (0, 6.66, -9.3), (6.8, 0.36, 2.5), col=False)
    for x in (-2.6, -0.8, 1.2, 3.0):
        box("CloudDark", Wd, (x, 6.55, -8.1), (1.0, 0.3, 0.3), col=False)
    for x, y in ((-2.0, 9.3), (0.5, 10.1), (2.4, 9.15)):
        box("CloudLight", "ffffff", (x, y, -8.15), (0.8, 0.2, 0.2), col=False)
    for s in (-1, 1):  # two big zig-zag bolts striking down (yellow with a white-hot core)
        x0 = s * 1.45
        for (dx, y, h, r) in ((0.0, 5.75, 1.9, 24), (-0.5, 4.3, 1.6, -30), (0.05, 2.95, 1.6, 24), (-0.4, 1.85, 1.0, -30)):
            box("Bolt", Y, (x0 + s * dx, y, -8.5), (0.62, h, 0.36), rot=(0, 0, s * r), rbx="Neon", col=False)
            box("BoltCore", "ffffff", (x0 + s * dx, y, -8.3), (0.2, h * 0.8, 0.06), rot=(0, 0, s * r), rbx="Neon", col=False)
    for y in (3.3, 5.1):  # electric arcs jumping between the posts
        for i, x in enumerate((-2.4, -1.2, 0.0, 1.2, 2.4)):
            box("Arc", B, (x, y + (0.25 if i % 2 == 0 else -0.25), -9.3), (1.3, 0.14, 0.14), rot=(0, 0, 22 if i % 2 == 0 else -22), rbx="Neon", col=False)
    for x, y, w in ((-2.9, 6.4, 1.4), (-0.3, 6.35, 2.0), (2.4, 6.42, 1.6)):  # storm-dark puffs hanging under the cloud
        box("CloudDark", "7d8ca6", (x, y, -9.3), (w, 0.5, 2.2), col=False)
    for x, y in ((-3.0, 5.6), (-0.4, 5.9), (2.2, 5.5), (3.6, 6.0), (-2.2, 4.8), (2.9, 4.6)):
        box("Rain", "9fd4ff", (x, y, -9.0 + random.uniform(-0.6, 0.6)), (0.12, 0.5, 0.12), rbx="Glass", transp=0.2, col=False)
    box("Emblem", Y, (0, 1.0, -7.06), (0.5, 0.22, 0.06), rbx="Neon", col=False)
    fx("FxSpark", B, (0, 7.3, -9.0), (5.5, 1.0, 1.5))


################################################################ 3: Frost - ice crystals and snow (the Yeti's colours)
def crystal(x, z, h, w, rot, glass="bcf1ff"):
    pos = (x, 0.78 + h / 2 - 0.3, z)
    pos = along((x, 0.78 - 0.3, z), rot, h / 2)
    box("Crystal", glass, pos, (w, h, w), rot=rot, rbx="Glass", transp=0.18)
    box("CrystalCore", "a0f9ff", pos, (w * 0.35, h * 0.8, w * 0.35), rot=rot, rbx="Neon", col=False)
    box("CrystalTip", glass, along((x, 0.48, z), rot, h + w * 0.2), (w * 0.62, w * 0.5, w * 0.62), rot=rot, rbx="Glass", transp=0.18, col=False)
    box("CrystalTip", "e8fcff", along((x, 0.48, z), rot, h + w * 0.55), (w * 0.3, w * 0.35, w * 0.3), rot=rot, rbx="Glass", transp=0.1, col=False)


def tier3():
    begin(3, "Frost")
    S, S2, S3, D = "f6faff", "ddeaf9", "b3c4dd", "596581"
    base(dict(deck=S2, shade=S3, dark=D, belt="2a3446", roller="6b7896", slats=["bcf1ff", "f6faff"],
              rail=S, railTop="ffffff", trim="a0f9ff", bolt="95a4bf", accent="7fd6f5"))
    for s in (-1, 1):  # snow on the rails + icicles
        for z, w in ((-5.6, 2.2), (-2.4, 1.6), (0.8, 2.6), (4.2, 1.8)):
            box("Snow", "ffffff", (s * 3.35, 1.38, z), (0.96, 0.16, w), col=False)
        for z in (-6.0, -4.3, -2.9, -0.8, 1.5, 3.2, 5.0, 6.3):
            l = random.uniform(0.3, 0.6)
            box("Icicle", "bcf1ff", (s * 3.86, 0.7 - l / 2 + 0.25, z), (0.14, l, 0.14), rbx="Glass", transp=0.15, col=False)
    for pos, size in (((0, 1.0, -9.2), (6.4, 0.5, 3.4)), ((-1.6, 1.35, -9.4), (2.8, 0.4, 2.4)), ((1.9, 1.3, -9.0), (2.4, 0.35, 2.2))):
        box("SnowMound", S, pos, size)
    box("SnowShade", S3, (0, 0.8, -9.2), (6.6, 0.1, 3.5), col=False)
    crystal(0, -9.4, 6.2, 1.7, (0, 45, 0))
    crystal(-1.9, -9.0, 4.2, 1.2, (8, 30, 18))
    crystal(2.0, -9.1, 4.6, 1.25, (-6, 15, -16))
    crystal(-3.0, -8.4, 2.6, 0.9, (14, 20, 28))
    crystal(3.1, -8.5, 2.9, 0.95, (12, 40, -30))
    crystal(-0.9, -8.0, 2.4, 0.8, (24, 10, 10))
    crystal(1.1, -10.4, 3.4, 0.9, (-18, 25, -8))
    crystal(-1.6, -10.5, 2.8, 0.8, (-20, 50, 12))
    for x, z in ((-2.4, -7.6), (0.5, -7.4), (2.6, -7.7), (-3.4, -10.4), (3.3, -10.2)):
        box("SnowLump", "ffffff", (x, 1.25, z), (random.uniform(0.6, 0.9), 0.3, random.uniform(0.5, 0.8)), col=False)
    for x, z in ((-0.4, -7.35), (1.6, -7.5)):
        box("IceChunk", "bcf1ff", (x, 1.3, z), (0.4, 0.4, 0.4), rot=(30, 45, 0), rbx="Glass", transp=0.15, col=False)
    fx("FxSnow", "ffffff", (0, 7.0, -9.2), (6.0, 0.6, 3.0))


################################################################ 4: Void - a purple portal
def tier4():
    begin(4, "Void")
    P, Pd, Pl, PN, PN2 = "5a24b8", "2b1650", "c38bff", "8f4bff", "ff6bf0"
    base(dict(deck="2a1840", shade="1a0f2b", dark="0e0818", belt="120a1e", roller="3a2160", slats=["7b3cff", "2b1650"],
              rail="4a2a78", railTop="8f5bff", trim="b46bff", bolt="6b4aa0", accent="8f4bff"))
    cy, cz = 5.0, -9.3
    box("PortalBase", Pd, (0, 1.2, cz), (3.2, 0.9, 1.8))
    box("PortalBaseTop", PN, (0, 1.68, cz), (3.0, 0.08, 1.6), rbx="Neon", col=False)
    for s in (-1, 1):
        box("Pillar", "3a2160", (s * 3.95, 3.0, cz), (0.9, 4.6, 0.9))
        box("PillarCap", Pl, (s * 3.95, 5.4, cz), (1.1, 0.3, 1.1))
        box("PillarRune", PN, (s * 3.95, 3.2, cz + 0.47), (0.3, 1.4, 0.06), rbx="Neon", col=False)
        box("PillarFoot", Pd, (s * 3.95, 0.95, cz), (1.2, 0.4, 1.2))
    n = 22
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = 3.0 * math.cos(a), cy + 3.0 * math.sin(a)
        box("Ring", (P, Pl, P)[i % 3], (x, y, cz), (0.75, 1.0, 1.0), rot=(0, 0, math.degrees(a)))
        if i % 2 == 0:
            box("RingOuter", Pd, (3.6 * math.cos(a), cy + 3.6 * math.sin(a), cz), (0.5, 0.6, 0.8), rot=(0, 0, math.degrees(a)), col=False)
        box("RingGlow", PN, (2.48 * math.cos(a), cy + 2.48 * math.sin(a), cz + 0.15), (0.3, 0.6, 0.3), rot=(0, 0, math.degrees(a)), rbx="Neon", col=False)
    box("Void", "0b0612", (0, cy, cz - 0.05), (4.1, 4.1, 0.3), rot=(0, 0, 45), col=False)
    box("Void", "0b0612", (0, cy, cz - 0.04), (4.6, 2.5, 0.28), col=False)
    box("Void", "0b0612", (0, cy, cz - 0.03), (2.5, 4.6, 0.28), col=False)
    for i in range(20):
        r, a = 0.35 + i * 0.1, i * 0.72
        box("Swirl", PN if i % 2 == 0 else PN2, (r * math.cos(a), cy + r * math.sin(a), cz + 0.18), (0.26, 0.26, 0.06), rot=(0, 0, math.degrees(a)), rbx="Neon", col=False)
    for x, y, z in ((-4.2, 7.9, -8.6), (4.4, 7.4, -9.8), (-2.6, 8.9, -10.0), (2.4, 9.0, -8.7), (0.0, 9.5, -9.4), (-4.8, 2.0, -8.4), (4.7, 2.3, -10.1)):
        box("Shard", Pl, (x, y, z), (random.uniform(0.4, 0.7), random.uniform(0.7, 1.2), 0.4), rot=(random.uniform(-40, 40), random.uniform(0, 90), random.uniform(-40, 40)), rbx="Glass", transp=0.15, col=False)
    fx("FxVoid", PN, (0, cy, cz + 0.4), (4.0, 4.0, 0.4))


################################################################ 5: Inferno - a black hole in a ring of fire
def tier5():
    begin(5, "Inferno")
    O, Y, R, K = "ff8a1f", "ffd84a", "ff3d1a", "050505"
    base(dict(deck="1d1b1f", shade="121114", dark="08080a", belt="141215", roller="2b2428", slats=["ff7a1a", "1a1a1a"],
              rail="2b2428", railTop="ff9a2e", trim="ff7a1a", bolt="4a3c3c", accent="ff6a00"))
    cy, cz = 5.2, -9.3
    for pos, size, rot in (((0, 1.25, cz), (3.4, 1.0, 2.4), (0, 0, 0)), ((-2.2, 1.1, -8.6), (1.6, 0.8, 1.4), (0, 25, 0)),
                           ((2.3, 1.05, -9.9), (1.7, 0.7, 1.5), (0, -20, 0))):
        box("Rock", "2b2428", pos, size, rot=rot)
    for x, z, r in ((-1.2, -8.08, 10), (0.9, -8.1, -12), (-2.4, -7.95, 30), (2.0, -9.17, 0)):
        box("Lava", O, (x, 1.3, z), (0.9, 0.08, 0.1), rot=(0, r, 0), rbx="Neon", col=False)
    box("Stem", "2b2428", (0, 2.2, cz), (1.0, 1.4, 1.0))
    for size, rot in (((4.4, 2.6, 3.0), (0, 0, 0)), ((3.7, 3.9, 3.0), (0, 0, 0)), ((2.6, 4.4, 3.0), (0, 0, 0)), ((3.4, 3.4, 2.95), (0, 0, 45))):
        box("Hole", K, (0, cy, cz), size, rot=rot)
    n = 24
    for i in range(n):
        a = 2 * math.pi * i / n
        box("Horizon", (O, Y)[i % 2], (2.55 * math.cos(a), cy + 2.55 * math.sin(a), cz + 0.9), (0.55, 0.75, 0.4), rot=(0, 0, math.degrees(a)), rbx="Neon", col=False)
    for i in range(18):
        a = 2 * math.pi * i / 18 + random.uniform(-0.08, 0.08)
        L = random.uniform(1.0, 2.2)
        r = 3.0 + L / 2
        col = (R, O, Y)[i % 3]
        box("Flame", col, (r * math.cos(a), cy + r * math.sin(a), cz + 0.4), (0.55, L, 0.5), rot=(0, 0, math.degrees(a) - 90), rbx="Neon", col=False)
        box("FlameTip", Y, ((r + L / 2 + 0.2) * math.cos(a), cy + (r + L / 2 + 0.2) * math.sin(a), cz + 0.4), (0.3, 0.3, 0.3), rot=(0, 0, 45), rbx="Neon", col=False)
    for i in range(10):
        a = random.uniform(0, 2 * math.pi)
        r = random.uniform(4.4, 5.4)
        box("Ember", (O, Y)[i % 2], (r * math.cos(a), max(1.6, cy + r * math.sin(a)), cz + random.uniform(-1, 1)), (0.18, 0.18, 0.18), rot=(45, 45, 0), rbx="Neon", col=False)
    fx("FxFire", O, (0, cy, cz + 0.6), (5.5, 5.5, 0.5))


################################################################ 6: Rainbow - an explosion of rainbow blocks
RAINBOW = ["ff5aa5", "ffd93b", "4be3ff", "7dff6a", "b77bff", "ff8a3d"]


def tier6():
    begin(6, "Rainbow")
    base(dict(deck="ffffff", shade="e7e2f5", dark="b9b2cf", belt="2b2b33", roller="d6d0ea", slats=RAINBOW,
              rail="ffffff", railTop="f4f0ff", trim="ff5aa5", trimName="Glow", bolt="cfc8e6", accent="ff5aa5"))
    for s in (-1, 1):  # rainbow stripes along the rails
        for i in range(6):
            box("Glow", RAINBOW[i], (s * 3.84, 1.0, -6.0 + i * 2.4), (0.06, 0.3, 2.3), rbx="Neon", col=False)
    cy, cz = 5.2, -9.3
    box("Stand", "ffffff", (0, 1.6, cz), (1.6, 1.8, 1.6))
    box("StandBand", "ff5aa5", (0, 2.3, cz), (1.7, 0.2, 1.7), rbx="Neon", col=False)
    box("Core", "ffffff", (0, cy, cz), (2.0, 2.0, 2.0), rot=(45, 45, 0), rbx="Neon", col=False)
    box("CoreShell", "fff3fb", (0, cy, cz), (2.4, 2.4, 2.4), rot=(20, 10, 30), rbx="Glass", transp=0.5, col=False)
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n + random.uniform(-0.1, 0.1)
        for k in range(4):
            r = 1.6 + k * 1.05 + random.uniform(-0.15, 0.15)
            sz = 1.05 - k * 0.2
            name = "Glow" if k == 0 else "Burst"
            box(name, RAINBOW[(i + k) % 6], (r * math.cos(a), cy + r * math.sin(a), cz + random.uniform(-0.6, 0.6)), (sz, sz, sz),
                rot=(random.uniform(0, 90), random.uniform(0, 90), random.uniform(0, 90)), rbx="Neon" if k == 0 else "SmoothPlastic", col=False)
    for i in range(18):  # confetti flying out towards the runner
        a = random.uniform(0, 2 * math.pi)
        r = random.uniform(2.0, 5.0)
        box("Confetti", RAINBOW[i % 6], (r * math.cos(a), max(1.4, cy + r * math.sin(a)), cz + random.uniform(0.8, 2.0)), (0.3, 0.3, 0.08),
            rot=(random.uniform(0, 90), random.uniform(0, 90), random.uniform(0, 90)), col=False)
    for i, (x, z) in enumerate(((-2.6, -8.0), (-1.4, -10.4), (2.4, -8.2), (1.6, -10.5), (-3.2, -9.6), (3.1, -9.7), (0.2, -7.6))):
        box("Pile", RAINBOW[i % 6], (x, 1.05, z), (0.6, 0.6, 0.6), rot=(0, random.uniform(0, 90), 0))
    fx("FxRainbow", "ffffff", (0, cy, cz), (6.0, 6.0, 1.0))


def build_all():
    for f in (sign, tier1, tier2, tier3, tier4, tier5, tier6):
        f()
    return {c.name: len(c.objects) - 1 for c in bpy.data.collections["Treadmills"].children}


################################################################ export to Roblox (ModuleScript data, read by TreadmillClient)
def _num(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def export_tier(coll):
    t = coll["tier"]
    colors, mats, rows = [], [], []
    origin = next((o for o in coll.objects if o.type == "EMPTY"), None)
    offset = origin.matrix_world.translation.copy() if origin else Vector(((t - 1) * SPACING, 0, 0))
    for ob in sorted(coll.objects, key=lambda o: o.name):
        if ob.type != "MESH":
            continue
        loc, q, sc = ob.matrix_world.decompose()
        rr = C @ q.to_matrix() @ CT
        p = C @ (loc - offset)
        size = (sc.x, sc.z, sc.y)
        m = ob.material_slots[0].material
        hexcol, rbx, transp = m.get("hex", "ffffff"), m.get("rbx", "SmoothPlastic"), float(m.get("transp", 0))
        if hexcol not in colors:
            colors.append(hexcol)
        if rbx not in mats:
            mats.append(rbx)
        row = ['"%s"' % ob.get("rname", "Part"), str(colors.index(hexcol) + 1), str(mats.index(rbx) + 1), _num(transp),
               "1" if ob.get("collide") else "0"] + [_num(v) for v in (p.x, p.y, p.z)] + [_num(v) for v in size]
        rq = rr.to_quaternion()
        if abs(rq.w) < 0.99999:
            if rq.w < 0:
                rq = -rq
            row += [_num(rq.x), _num(rq.y), _num(rq.z), _num(rq.w)]
        rows.append("{" + ",".join(row) + "},")
    lines = [
        "-- Tier%d %s design: generated in Blender by models/speed/blender/treadmills.py (do not edit by hand)." % (t, coll["label"]),
        "-- part = { name, colour, material, transparency, collide, x, y, z, sizeX, sizeY, sizeZ [, qx, qy, qz, qw] }",
        "-- (Roblox studs, relative to the treadmill Spot; the runner faces -z)",
        "return {",
        '\tname = "%s",' % coll["label"],
        "\tcolors = { " + ", ".join('"%s"' % c for c in colors) + " },",
        "\tmaterials = { " + ", ".join('"%s"' % m for m in mats) + " },",
        "\tparts = {",
    ] + ["\t\t" + r for r in rows] + ["\t},", "}", ""]
    return "\n".join(lines), len(rows)


def export_all(folder):
    import os
    os.makedirs(folder, exist_ok=True)
    out = {}
    for coll in bpy.data.collections["Treadmills"].children:
        text, n = export_tier(coll)
        path = os.path.join(folder, ("Tier%d.lua" % coll["tier"]) if coll["tier"] > 0 else (coll["label"] + ".lua"))
        with open(path, "w", newline="\n", encoding="utf-8") as f:
            f.write(text)
        out[coll.name] = n
    return out
