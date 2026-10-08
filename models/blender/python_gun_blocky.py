"""Shoot an Animal: the cartoon "Python" revolver in the chunky beveled-block style (Blender 5.x, headless).

  blender.exe --background --factory-startup --python python_gun_blocky.py -- <output folder>

Beveled boxes, flat saturated colours, big readable iron sight. 1 Blender unit = 1 Roblox stud. Pointing +Y, Z up
(FBX export -> Roblox -Z forward / Y up). Origin = centre of the bounding box.
Outputs: Python_Revolver.fbx / .obj(.mtl) / .blend (colours as materials AND vertex colour attribute "Col"),
preview_3q / preview_front3q / preview_side / preview_sights PNGs.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv
out_dir = argv[argv.index("--") + 1] if "--" in argv else os.path.join(os.path.dirname(__file__), "gun_blocky")
os.makedirs(out_dir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(h):
    h = h.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


PALETTE = {
    "navy": ("#2a3f73", 0.4),     # blued steel
    "steel": ("#8fa4d0", 0.4),    # lighter steel (drum, side plate)
    "wood": ("#c0804d", 0.55),    # grip
    "wood2": ("#8e5a33", 0.55),   # grip inlay
    "brass": ("#ffc83d", 0.3),    # medallion, muzzle ring, screws, butt cap
    "orange": ("#ff5a1f", 0.4),   # front sight post
    "white": ("#ffffff", 0.35),   # rear sight marks
    "black": ("#15171c", 0.3),    # chamber holes, muzzle hole
}
ORDER = list(PALETTE.keys())
main = bmesh.new()


def add(tmp, mat):
    idx = ORDER.index(mat)
    for f in tmp.faces:
        f.material_index = idx
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    main.from_mesh(me)
    bpy.data.meshes.remove(me)


def box(mat, centre, size, rot=(0, 0, 0), bevel=0.1, taper=None):
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
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bevel, min(size) * 0.45), offset_type="OFFSET",
                        segments=1, profile=0.5, affect="EDGES")
    add(tmp, mat)


# ---------------------------------------------------------------- the gun (forward = +Y, up = +Z)
# frame + top strap
box("navy", (0, -0.9, 0.55), (0.95, 1.8, 1.7), bevel=0.14)
box("navy", (0, 0.1, 1.3), (0.85, 3.7, 0.42), bevel=0.12)
box("steel", (0.5, -0.8, 0.5), (0.1, 1.3, 1.0), bevel=0.04)       # side plates
box("steel", (-0.5, -0.8, 0.5), (0.1, 1.3, 1.0), bevel=0.04)
# drum (chamfered chunky block) + six chamber holes on its front face
box("steel", (0, 0.75, 0.5), (1.95, 1.55, 1.95), bevel=0.5)
for i in range(6):
    a = math.radians(60 * i + 30)
    box("black", (0.58 * math.cos(a), 1.55, 0.5 + 0.58 * math.sin(a)), (0.36, 0.16, 0.36), bevel=0.0)
# barrel, top rib, underlug, muzzle ring
box("navy", (0, 3.35, 0.95), (0.85, 3.7, 0.85), bevel=0.16)
box("navy", (0, 3.35, 1.52), (0.32, 3.7, 0.24), bevel=0.05)
box("navy", (0, 2.9, 0.38), (0.72, 2.7, 0.55), bevel=0.12)
box("brass", (0, 5.15, 0.95), (1.1, 0.34, 1.1), bevel=0.1)
box("black", (0, 5.34, 0.95), (0.38, 0.12, 0.38), bevel=0.0)
# ---- iron sights: tops level at z = 2.55 so the post sits level in the notch
box("navy", (0, -1.2, 1.62), (1.05, 0.7, 0.25), bevel=0.05)               # rear sight base
box("navy", (-0.38, -1.2, 2.2), (0.3, 0.55, 0.72), bevel=0.05)            # rear uprights (notch 0.46 wide)
box("navy", (0.38, -1.2, 2.2), (0.3, 0.55, 0.72), bevel=0.05)
box("white", (-0.38, -1.5, 2.25), (0.16, 0.05, 0.42), bevel=0.0)          # white marks on the rear faces
box("white", (0.38, -1.5, 2.25), (0.16, 0.05, 0.42), bevel=0.0)
box("navy", (0, 4.7, 1.67), (0.55, 0.85, 0.3), bevel=0.05)                # front ramp
box("orange", (0, 4.88, 2.1), (0.24, 0.24, 0.9), bevel=0.04)              # front post (top z 2.55)
# hammer
box("navy", (0, -1.95, 1.0), (0.38, 0.75, 1.1), rot=(15, 0, 0), bevel=0.06)     # sits against the back of the frame
box("navy", (0, -2.2, 1.58), (0.54, 0.55, 0.24), rot=(15, 0, 0), bevel=0.05)
box("navy", (0, -1.75, 0.75), (0.5, 0.4, 0.7), bevel=0.05)                       # hammer base block
# square trigger guard + trigger
box("navy", (0, -0.45, -0.6), (0.34, 1.7, 0.3), bevel=0.06)
box("navy", (0, 0.35, -0.1), (0.34, 0.34, 1.0), bevel=0.06)
box("navy", (0, -1.25, -0.1), (0.34, 0.34, 1.0), bevel=0.06)
box("navy", (0, -0.45, -0.05), (0.22, 0.22, 0.75), rot=(-15, 0, 0), bevel=0.04)
# grip, inlays, brass cap, medallions, screws
box("wood", (0, -2.1, -0.95), (0.98, 1.55, 2.8), rot=(-22, 0, 0), bevel=0.22)
box("brass", (0, -2.62, -2.2), (1.04, 1.62, 0.3), rot=(-22, 0, 0), bevel=0.08)
for s in (-1, 1):
    box("wood2", (0.5 * s, -2.1, -0.95), (0.1, 1.05, 2.0), rot=(-22, 0, 0), bevel=0.04)
    box("brass", (0.58 * s, -2.1, -0.85), (0.12, 0.55, 0.55), rot=(-22, 0, 0), bevel=0.05)
    box("brass", (0.52 * s, -1.0, 0.75), (0.1, 0.3, 0.3), bevel=0.03)

# ---------------------------------------------------------------- finish: centre, triangulate, materials, vertex colours
bmesh.ops.recalc_face_normals(main, faces=main.faces[:])
bmesh.ops.triangulate(main, faces=main.faces[:])
lo = Vector((min(v.co.x for v in main.verts), min(v.co.y for v in main.verts), min(v.co.z for v in main.verts)))
hi = Vector((max(v.co.x for v in main.verts), max(v.co.y for v in main.verts), max(v.co.z for v in main.verts)))
CENTER = (lo + hi) / 2
bmesh.ops.translate(main, vec=-CENTER, verts=main.verts)
me = bpy.data.meshes.new("Python_Revolver")
main.to_mesh(me)
main.free()
for key, (hx, rough) in PALETTE.items():
    m = bpy.data.materials.new("Python_" + key)
    c = rgb(hx)
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
gun = bpy.data.objects.new("Python_Revolver", me)
scene.collection.objects.link(gun)
d = gun.dimensions
print("GUN STATS: %d tris, size (X,Y,Z) = %.2f x %.2f x %.2f studs" % (len(me.polygons), d.x, d.y, d.z))

bpy.ops.object.select_all(action="DESELECT")
gun.select_set(True)
bpy.context.view_layer.objects.active = gun
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "Python_Revolver.blend"))
bpy.ops.export_scene.fbx(filepath=os.path.join(out_dir, "Python_Revolver.fbx"), use_selection=True, add_leaf_bones=False)
bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, "Python_Revolver.obj"), export_selected_objects=True)

# ---------------------------------------------------------------- previews (camera positions are in design space)
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.resolution_x = 1100
scene.render.resolution_y = 700
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*rgb("#a9d4f5"), 1)
scene.world = world
gz = -d.z / 2                                            # ground plane under the gun's lowest point
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, gz))
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
fd.energy = 500
fd.size = 12
fill = bpy.data.objects.new("Fill", fd)
fill.location = (-5, 12, 9)
fill.rotation_euler = (math.radians(55), 0, math.radians(-15))
scene.collection.objects.link(fill)


def shoot(name, cam_loc, look_at, lens):
    cam_loc = Vector(cam_loc) - CENTER
    look_at = Vector(look_at) - CENTER
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cam = bpy.data.objects.new(name, cd)
    scene.collection.objects.link(cam)
    cam.location = cam_loc
    cam.rotation_euler = (look_at - cam_loc).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)


shoot("preview_3q", (6.2, -7.5, 3.6), (0, 0.6, 0.2), 42)
shoot("preview_front3q", (7.0, 10.5, 3.2), (0, 1.2, 0.3), 40)
shoot("preview_side", (14.0, 1.2, 0.6), (0, 1.2, 0.2), 40)
shoot("preview_sights", (0, -8.0, 3.2), (0, 5.0, 2.2), 42)
print("DONE")
