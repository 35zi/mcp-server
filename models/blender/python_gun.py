"""Cartoon "Python" revolver for Shoot an Animal.

Run headless with the installed Blender:
  blender.exe --background --factory-startup --python python_gun.py -- <output folder>

Builds a chunky low-poly revolver from beveled boxes/cylinders (1 Blender unit = 1 Roblox stud),
pointing along +Y with Z up. Exports Python_Revolver.fbx / .obj / .blend (colors are stored as a
vertex-color attribute "Col" and as materials) and renders two previews:
  preview_3q.png     - three-quarter view
  preview_sights.png - the view along the iron sights (rear notch + front post)
"""
import math
import sys
import os
import bpy
from mathutils import Vector

argv = sys.argv
out_dir = argv[argv.index("--") + 1] if "--" in argv else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(out_dir, exist_ok=True)

# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


PALETTE = {
    "navy": "#25365c",   # blued steel (barrel, frame)
    "steel": "#8da2c8",  # lighter steel (cylinder)
    "wood": "#b97a4a",   # grip
    "brass": "#ffc83d",  # medallion, muzzle ring, screws
    "orange": "#ff5a1f",  # front sight post
    "white": "#ffffff",  # rear sight marks
    "black": "#15171c",  # chamber holes, muzzle
}
MATS = {}
for name, hx in PALETTE.items():
    m = bpy.data.materials.new("gun_" + name)
    r, g, b = hex_rgb(hx)
    m.diffuse_color = (r, g, b, 1.0)
    try:
        m.use_nodes = True
    except Exception:
        pass
    if m.node_tree:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
            bsdf.inputs["Roughness"].default_value = 0.4
    MATS[name] = m

parts = []


def finish(obj, mat, bevel):
    obj.data.materials.append(MATS[mat])
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    obj.select_set(False)
    parts.append(obj)
    return obj


def box(name, size, loc, mat, rot=(0, 0, 0), bevel=0.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    return finish(o, mat, bevel)


def cyl(name, radius, length, loc, mat, axis="Y", bevel=0.03, verts=24):
    """Cylinder whose long axis is X, Y or Z."""
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=length, vertices=verts, location=loc)
    o = bpy.context.active_object
    o.name = name
    if axis == "Y":
        o.rotation_euler = (math.radians(90), 0, 0)
    elif axis == "X":
        o.rotation_euler = (0, math.radians(90), 0)
    return finish(o, mat, bevel)


# ---------------------------------------------------------------- the gun (forward = +Y, up = +Z)
# frame + top strap
box("FrameBack", (0.62, 1.5, 1.4), (0, -0.85, 0.5), "navy")
box("TopStrap", (0.6, 3.0, 0.3), (0, -0.1, 1.1), "navy")
# cylinder (drum) + chamber holes on its face
cyl("Drum", 0.78, 1.3, (0, 0.55, 0.45), "steel", "Y", 0.05, 32)
for i in range(6):
    a = math.radians(60 * i + 30)
    cyl("Chamber%d" % i, 0.19, 0.08, (0.5 * math.cos(a), 1.2, 0.45 + 0.5 * math.sin(a)), "black", "Y", 0.0, 16)
# barrel, underlug, top rib, muzzle
cyl("Barrel", 0.38, 3.1, (0, 2.75, 0.85), "navy", "Y", 0.04, 28)
box("Underlug", (0.5, 2.4, 0.34), (0, 2.45, 0.33), "navy")
box("TopRib", (0.2, 3.0, 0.14), (0, 2.75, 1.3), "navy", bevel=0.03)
cyl("MuzzleRing", 0.43, 0.25, (0, 4.175, 0.85), "brass", "Y", 0.03, 28)
cyl("MuzzleHole", 0.17, 0.06, (0, 4.31, 0.85), "black", "Y", 0.0, 16)
# ---- iron sights (tops aligned at z = 1.85 so the post sits level in the notch)
# rear sight: base + two uprights leaving a 0.26-wide notch, with white marks on the rear faces
box("RearSightBase", (0.7, 0.5, 0.15), (0, -1.2, 1.325), "navy", bevel=0.03)
box("RearSightL", (0.24, 0.3, 0.45), (-0.25, -1.2, 1.625), "navy", bevel=0.03)
box("RearSightR", (0.24, 0.3, 0.45), (0.25, -1.2, 1.625), "navy", bevel=0.03)
box("RearMarkL", (0.1, 0.03, 0.3), (-0.25, -1.36, 1.65), "white", bevel=0.0)
box("RearMarkR", (0.1, 0.03, 0.3), (0.25, -1.36, 1.65), "white", bevel=0.0)
# front sight: ramp + tall orange post
box("FrontRamp", (0.3, 0.6, 0.16), (0, 4.0, 1.45), "navy", bevel=0.03)
box("FrontPost", (0.16, 0.16, 0.34), (0, 4.1, 1.68), "orange", bevel=0.02)
# hammer, trigger guard, trigger
box("Hammer", (0.24, 0.45, 0.8), (0, -1.78, 0.95), "navy", rot=(22, 0, 0), bevel=0.04)
box("HammerSpur", (0.34, 0.4, 0.16), (0, -1.9, 1.3), "navy", rot=(22, 0, 0), bevel=0.03)
bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.09, major_segments=24, minor_segments=10, location=(0, -0.45, -0.35), rotation=(0, math.radians(90), 0))
tg = bpy.context.active_object
tg.name = "TriggerGuard"
finish(tg, "navy", 0)
box("Trigger", (0.14, 0.14, 0.45), (0, -0.35, -0.1), "navy", rot=(-15, 0, 0), bevel=0.03)
# grip + brass medallions + screws
box("Grip", (0.72, 1.2, 2.4), (0, -1.9, -0.95), "wood", rot=(-22, 0, 0), bevel=0.12)
box("GripCap", (0.78, 1.26, 0.2), (0, -2.45, -2.0), "brass", rot=(-22, 0, 0), bevel=0.05)
for s in (-1, 1):
    cyl("Medallion%d" % s, 0.26, 0.06, (0.37 * s, -1.9, -0.8), "brass", "X", 0.0, 20)
    cyl("Screw%d" % s, 0.09, 0.05, (0.32 * s, -0.9, 0.55), "brass", "X", 0.0, 12)

# ---------------------------------------------------------------- join into one mesh
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
gun = bpy.context.active_object
gun.name = "Python_Revolver"
_corners = [gun.matrix_world @ Vector(c) for c in gun.bound_box]
CENTER = (Vector((min(c.x for c in _corners), min(c.y for c in _corners), min(c.z for c in _corners))) +
          Vector((max(c.x for c in _corners), max(c.y for c in _corners), max(c.z for c in _corners)))) / 2
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
gun.location = (0, 0, 0)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# vertex colors from the material of each face (colors survive importers that drop materials)
me = gun.data
attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
for poly in me.polygons:
    mc = me.materials[poly.material_index].diffuse_color
    for li in poly.loop_indices:
        attr.data[li].color = (mc[0], mc[1], mc[2], 1.0)

# triangulate for clean export
bpy.context.view_layer.objects.active = gun
tri = gun.modifiers.new("Tri", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tri.name)

dims = gun.dimensions
stats = "tris: %d  verts: %d  size (X,Y,Z) = %.2f x %.2f x %.2f" % (len(me.polygons), len(me.vertices), dims.x, dims.y, dims.z)
print("GUN STATS:", stats)

# ---------------------------------------------------------------- exports
gun.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "Python_Revolver.blend"))
bpy.ops.export_scene.fbx(filepath=os.path.join(out_dir, "Python_Revolver.fbx"), use_selection=True, add_leaf_bones=False)
bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, "Python_Revolver.obj"), export_selected_objects=True)

# ---------------------------------------------------------------- preview renders
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_cavity = True
sh.cavity_type = "BOTH"
sh.show_object_outline = True
sh.object_outline_color = (0.05, 0.05, 0.08)
scene.render.resolution_x = 1100
scene.render.resolution_y = 700
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.62, 0.78, 0.95)


def shoot(name, cam_loc, look_at, lens=50):
    # camera coordinates below are given in the gun's design space; the mesh origin is now its bounds centre
    cam_loc = Vector(cam_loc) - CENTER
    look_at = Vector(look_at) - CENTER
    cam_data = bpy.data.cameras.new(name)
    cam_data.lens = lens
    cam = bpy.data.objects.new(name, cam_data)
    scene.collection.objects.link(cam)
    cam.location = cam_loc
    d = Vector(look_at) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)


bpy.ops.object.select_all(action="DESELECT")
shoot("preview_3q", (5.8, -7.2, 3.2), (0, 0, 0.1), 42)
shoot("preview_front3q", (6.5, 9.5, 3.0), (0, 1.0, 0.3), 40)
shoot("preview_side", (13.0, 0.9, 0.5), (0, 0.9, 0.3), 40)
shoot("preview_sights", (0, -7.5, 2.7), (0, 4, 1.4), 42)
print("DONE")
